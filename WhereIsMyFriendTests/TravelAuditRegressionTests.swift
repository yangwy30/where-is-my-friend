import Foundation
import XCTest
@testable import WhereIsMyFriend

@MainActor
final class TravelAuditRegressionTests: XCTestCase {
    private let ownerID = "10000000-0000-0000-0000-000000000001"

    private func makeRepository() -> TravelAuditRepository {
        TravelAuditRepository(ownerID: ownerID)
    }

    private func makeLibrary(_ repository: TravelAuditRepository) async -> (TripLibrary, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TravelAudit-\(UUID())")
        let library = TripLibrary(directory: directory)
        library.connect(repository)
        library.load(scope: "audit-\(UUID())", userID: ownerID)
        await library.refresh()
        return (library, directory)
    }

    func testFlightDraftIgnoresNumberFormattingButTracksDateAndRouteChanges() {
        let day = TripDay(value: "2026-10-12")
        let baseline = FlightDraftState(number: "UA353", day: day, candidateID: nil)
        XCTAssertEqual(baseline, FlightDraftState(number: " ua 353 ", day: day, candidateID: nil))
        XCTAssertNotEqual(baseline, FlightDraftState(number: "UA353", day: TripDay(value: "2026-10-13"), candidateID: nil))
        XCTAssertNotEqual(baseline, FlightDraftState(number: "UA354", day: day, candidateID: nil))
        XCTAssertNotEqual(baseline, FlightDraftState(number: "UA353", day: day, candidateID: "route"))
    }

    func testNoOpEditKeepsVerifiedFlightWithoutReusingExpiredCandidate() async throws {
        let repository = makeRepository()
        let (library, directory) = await makeLibrary(repository)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try XCTUnwrap(library.trips.first?.flights.first)
        // Mirrors the editor's number/date-only submission when no new search was selected.
        var submitted = TripFlight(id: original.id, traveler: original.traveler, flightNumber: "ua 353",
            airline: "Not verified", origin: "—", destination: "LAX", departureTime: "—", arrivalTime: "—",
            date: original.calendarDay.pickerDate, terminal: "Not available", status: .unverified,
            direction: .outbound, travelerID: original.travelerID, revision: original.revision)
        submitted.departureDay = original.calendarDay.value
        let saved = await library.saveFlight(submitted, tripID: "trip", editing: true, candidateID: nil)
        XCTAssertTrue(saved)
        let mutations = await repository.mutations()
        XCTAssertTrue(mutations.isEmpty)
        let current = try XCTUnwrap(library.trips.first?.flights.first)
        XCTAssertEqual(current.candidateID, "provider-route")
        XCTAssertEqual(current.verifiedAt, original.verifiedAt)
        XCTAssertEqual(current.status, .scheduled)
        XCTAssertEqual(current.origin, "EWR")
        XCTAssertEqual(current.trackingState, original.trackingState)
    }

    func testChangedDayAndExplicitCandidateStillSubmitAnEdit() async throws {
        let repository = makeRepository()
        let (library, directory) = await makeLibrary(repository)
        defer { try? FileManager.default.removeItem(at: directory) }
        var flight = try XCTUnwrap(library.trips.first?.flights.first)
        flight.departureDay = "2026-10-13"
        let saved = await library.saveFlight(flight, tripID: "trip", editing: true, candidateID: nil)
        XCTAssertTrue(saved)
        var mutations = await repository.mutations()
        XCTAssertEqual(mutations.count, 1)
        XCTAssertEqual(mutations.first?.payload.date, "2026-10-13")
        XCTAssertNil(mutations.first?.payload.candidateID)
        flight = try XCTUnwrap(library.trips.first?.flights.first)
        let savedCandidate = await library.saveFlight(flight, tripID: "trip", editing: true, candidateID: "new-route")
        XCTAssertTrue(savedCandidate)
        mutations = await repository.mutations()
        XCTAssertEqual(mutations.count, 2)
        XCTAssertEqual(mutations.last?.payload.candidateID, "new-route")
    }

    func testReturnFlightDefaultsToTripEndAndExistingDayWins() async throws {
        let trip = await makeRepository().trip().plan(userID: ownerID)
        XCTAssertEqual(TripDay(trip.initialFlightDate()).value, "2026-10-12")
        XCTAssertEqual(TripDay(trip.initialFlightDate(direction: .inbound)).value, "2026-10-19")
        var existing = try XCTUnwrap(trip.flights.first)
        existing.departureDay = "2026-10-20"
        XCTAssertEqual(TripDay(trip.initialFlightDate(existing: existing, direction: .inbound)).value, "2026-10-20")
    }

    func testFlightCalendarDaySurvivesCacheRoundTripAcrossDateLine() async throws {
        let trip = await makeRepository().trip().plan(userID: ownerID)
        let flight = try XCTUnwrap(trip.flights.first)
        XCTAssertEqual(flight.departureDay, "2026-10-12")
        let data = try JSONEncoder().encode(flight)
        let restored = try JSONDecoder().decode(TripFlight.self, from: data)
        for zone in ["America/Los_Angeles", "Asia/Tokyo", "Pacific/Kiritimati"] {
            XCTAssertEqual(restored.resolvedDepartureDay(fallbackTimeZone: try XCTUnwrap(TimeZone(identifier: zone))).value, "2026-10-12")
        }
    }

    func testLegacyFlightCacheStillDecodesAndVerifiedScheduleRecoversDay() async throws {
        let trip = await makeRepository().trip().plan(userID: ownerID)
        let flight = try XCTUnwrap(trip.flights.first)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(flight)) as? [String: Any])
        json.removeValue(forKey: "departureDay")
        let legacy = try JSONDecoder().decode(TripFlight.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.departureDay)
        XCTAssertEqual(legacy.resolvedDepartureDay(fallbackTimeZone: try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))).value, "2026-10-12")
        // An unverified legacy row has no original timezone. It remains readable using the old interpretation.
        json.removeValue(forKey: "scheduledDeparture")
        let unverifiedLegacy = try JSONDecoder().decode(TripFlight.self, from: JSONSerialization.data(withJSONObject: json))
        let zone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertEqual(unverifiedLegacy.resolvedDepartureDay(fallbackTimeZone: zone), TripDay(unverifiedLegacy.date, timeZone: zone))
    }

    func testSuccessfulDeclineCannotBeUndoneByOlderInvitationRead() async throws {
        let repository = makeRepository()
        let (library, directory) = await makeLibrary(repository)
        defer { try? FileManager.default.removeItem(at: directory) }
        let invitation = try XCTUnwrap(library.invitations.first)
        await repository.holdNextInvitationRead()
        let refresh = Task { await library.refresh() }
        await repository.waitForHeldInvitationRead()
        await library.decline(invitation)
        XCTAssertTrue(library.invitations.isEmpty)
        await repository.releaseInvitationRead()
        await refresh.value
        XCTAssertTrue(library.invitations.isEmpty)
        XCTAssertFalse(library.isSaving)
    }

    func testFailedDeclineKeepsInvitationAndAllowsRetry() async throws {
        let repository = makeRepository()
        let (library, directory) = await makeLibrary(repository)
        defer { try? FileManager.default.removeItem(at: directory) }
        let invitation = try XCTUnwrap(library.invitations.first)
        await repository.failWrites(true)
        await library.decline(invitation)
        XCTAssertEqual(library.invitations.map(\.id), [invitation.id])
        XCTAssertNotNil(library.errorMessage)
        XCTAssertFalse(library.isSaving)
        await repository.failWrites(false)
        await library.decline(invitation)
        XCTAssertTrue(library.invitations.isEmpty)
        XCTAssertNil(library.errorMessage)
    }

    func testFailedNotificationWritePreservesAcknowledgedPreferences() async throws {
        let repository = makeRepository()
        let (library, directory) = await makeLibrary(repository)
        defer { try? FileManager.default.removeItem(at: directory) }
        await repository.failWrites(true)
        let flightResult = await library.setFlightAlerts(true, tripID: "trip")
        XCTAssertFalse(flightResult)
        XCTAssertEqual(library.trips.first?.flightAlertsEnabled, false)
        let planningResult = await library.setPlanningReminders(false, tripID: "trip")
        XCTAssertFalse(planningResult)
        XCTAssertEqual(library.trips.first?.planningRemindersEnabled, true)
        XCTAssertNotNil(library.errorMessage)
        XCTAssertFalse(library.isSaving)
    }
}

private actor TravelAuditRepository: AppRepository {
    nonisolated let mode: RepositoryMode = .remote
    nonisolated let storageScope = "test:travel-audit"
    let ownerID: String
    private var submitted: [TripMutation] = []
    private var shouldFail = false
    private var holdNextRead = false
    private var heldRead: CheckedContinuation<Void, Never>?
    private var heldReadWaiter: CheckedContinuation<Void, Never>?
    private var pendingInvitations: [TripInvitation]

    init(ownerID: String) {
        self.ownerID = ownerID
        pendingInvitations = [.init(id: UUID(), trip_name: "Invitation", trip_id: "invited-trip", destination_airport: "LAX",
            start_date: "2026-10-12", end_date: "2026-10-19", inviter_name: "Friend", recipient_name: "Owner",
            recipient_id: UUID(uuidString: ownerID)!, expires_at: "2026-10-20T00:00:00Z")]
    }

    func trip() -> CloudTrip {
        CloudTrip(id: "trip", name: "Flight regression", destination_airport: "LAX", start_date: "2026-10-12", end_date: "2026-10-19",
            completed_at: nil, my_role: "owner", revision: 1,
            participants: [.init(id: "person", name: "Owner", user_id: ownerID)],
            flights: [.init(id: "flight", participant_id: "person", flight_number: "UA353", date: "2026-10-12", direction: "outbound",
                airline: "United", departure: .init(code: "EWR", scheduledTime: .init(local: "2026-10-12T18:30:00", utc: "2026-10-12T22:30:00Z")),
                arrival: .init(code: "LAX", scheduledTime: .init(local: "2026-10-12T21:33:00", utc: "2026-10-13T04:33:00Z")),
                status: "scheduled", revision: 2, candidate_id: "provider-route", verified_at: "2026-10-10T12:00:00Z", tracking_state: "pending")],
            flight_alerts_enabled: false, planning_reminders_enabled: true)
    }
    func mutations() -> [TripMutation] { submitted }
    func failWrites(_ value: Bool) { shouldFail = value }
    func fetchTrips() async throws -> [CloudTrip] { [trip()] }
    func mutateTrip(id: String, mutation: TripMutation) async throws -> CloudTrip {
        submitted.append(mutation)
        if shouldFail { throw RepositoryError.networkUnavailable }
        return trip()
    }
    func updateTripCollaboration(id: String, action: String, payload: TripCollaborationPayload) async throws -> CloudTrip {
        if shouldFail { throw RepositoryError.networkUnavailable }
        return trip()
    }
    func updateTripReminderContext(_ context: TripReminderContext) async throws {}
    func holdNextInvitationRead() { holdNextRead = true }
    func waitForHeldInvitationRead() async {
        if heldRead != nil { return }
        await withCheckedContinuation { heldReadWaiter = $0 }
    }
    func releaseInvitationRead() { heldRead?.resume(); heldRead = nil }
    func tripInvitations(tripID: String?) async throws -> [TripInvitation] {
        let result = pendingInvitations
        if holdNextRead {
            holdNextRead = false
            await withCheckedContinuation { continuation in
                heldRead = continuation
                heldReadWaiter?.resume(); heldReadWaiter = nil
            }
        }
        return result
    }
    func dismissTripInvitation(id: UUID, revoke: Bool) async throws {
        if shouldFail { throw RepositoryError.networkUnavailable }
        pendingInvitations.removeAll { $0.id == id }
    }

    func loadSnapshot() async throws -> AppSnapshot { DemoData.initialSnapshot() }
    func signInDemo() async throws -> AppSnapshot { try await loadSnapshot() }
    func sendEmailSignInCode(to email: String) async throws {}
    func signIn(_ credential: SignInCredential) async throws -> AppSnapshot { try await loadSnapshot() }
    func signOut() async throws -> AppSnapshot { DemoData.signedOutSnapshot() }
    func deleteAccount() async throws -> AppSnapshot { DemoData.signedOutSnapshot() }
    func updateProfile(_ update: ProfileUpdate) async throws -> AppSnapshot { try await loadSnapshot() }
    func sendFriendRequest(username: String) async throws -> AppSnapshot { try await loadSnapshot() }
    func respond(to requestID: UUID, response: FriendRequestResponse) async throws -> AppSnapshot { try await loadSnapshot() }
    func removeFriend(id: UUID) async throws -> AppSnapshot { try await loadSnapshot() }
    func blockUser(id: UUID) async throws -> AppSnapshot { try await loadSnapshot() }
    func unblockUser(id: UUID) async throws -> AppSnapshot { try await loadSnapshot() }
    func setFavorite(friendID: UUID, isFavorite: Bool) async throws -> AppSnapshot { try await loadSnapshot() }
    func setFriendPreference(_ preference: FriendAccessPreference) async throws -> AppSnapshot { try await loadSnapshot() }
    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot { try await loadSnapshot() }
    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource, observedAt: Date, administrativeArea: String?) async throws -> AppSnapshot { try await loadSnapshot() }
    func registerPushToken(_ token: String) async throws {}
    func retryPendingOperations() async throws -> AppSnapshot { try await loadSnapshot() }
    func pendingOperationCount() async -> Int { 0 }
    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot { try await loadSnapshot() }
}
