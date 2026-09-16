import Foundation
import SwiftUI

/// A calendar day, not an instant. A trip must not change dates when the device changes time zone.
struct TripDay: Codable, Hashable, Comparable {
    let value: String

    init(value: String) { self.value = value }

    init(_ date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        value = String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    var pickerDate: Date {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return .distantPast }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) ?? .distantPast
    }

    var label: String { pickerDate.formatted(.dateTime.month(.abbreviated).day()) }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.value < rhs.value }
}

enum TripPhase: String, CaseIterable {
    case ongoing, upcoming, past
    var title: String {
        switch self {
        case .ongoing: "Ongoing"
        case .upcoming: "Upcoming"
        case .past: "Past"
        }
    }
}

struct TripParticipant: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    // Nil on legacy local rows: a matching name or participant ID is not account ownership.
    var userID: String? = nil
    var checkIn: TripCheckIn? = nil
    var checkInAt: Date? = nil
}

enum TripCheckIn: String, Codable, CaseIterable {
    case notSet = "not_set", landed, bagsCollected = "bags_collected", atMeetingPoint = "at_meeting_point"
    var title: String {
        switch self {
        case .notSet: "Not checked in"
        case .landed: "I've landed"
        case .bagsCollected: "Bags collected"
        case .atMeetingPoint: "At the meeting point"
        }
    }
}

struct TripArrivalOverview {
    let title: String
    let detail: String
    let progressCount: Int
}

struct TripPlan: Identifiable, Codable {
    let id: String
    var name: String
    var destinationAirport: String
    var startDay: TripDay
    var endDay: TripDay
    var participants: [TripParticipant]
    var flights: [TripFlight]
    var completedAt: Date?
    var isExample = false
    var creatorUserID: String? = nil
    var revision: Int? = nil
    var flightAlertsEnabled: Bool? = nil
    var meetingPoint: String? = nil

    var destination: AirportLocation? { AirportLocation.location(for: destinationAirport) }
    var destinationName: String { destination?.city ?? destinationAirport }

    func initialFlightDate(existing: TripFlight? = nil) -> Date {
        // Use the trip's calendar day, not today or a UTC midnight conversion.
        existing?.date ?? startDay.pickerDate
    }

    var dateLabel: String {
        if startDay.value.prefix(4) == endDay.value.prefix(4) {
            return "\(startDay.label) – \(endDay.label), \(endDay.value.prefix(4))"
        }
        return "\(startDay.label), \(startDay.value.prefix(4)) – \(endDay.label), \(endDay.value.prefix(4))"
    }
    var addedTravelerCount: Int {
        Set(flights.filter { $0.direction == .outbound }.compactMap(\.travelerID)).count
    }

    func arrivalOverview(direction: TripDirection, at now: Date = Date()) -> TripArrivalOverview {
        let memberIDs = Set(participants.map(\.id))
        let flightsInDirection = flights.filter { $0.direction == direction }
        let added = Set(flightsInDirection.compactMap(\.travelerID)).intersection(memberIDs).count
        let missing = participants.count - added
        let waiting = missing == 0 ? "Everyone’s flight is added" :
            "Waiting on \(missing) \(missing == 1 ? "traveler" : "travelers")"
        if phase(at: now) == .past {
            return TripArrivalOverview(title: "Trip complete", detail: "Your people and flights are saved here", progressCount: added)
        }

        // Return planning stays useful during the trip, until that journey starts.
        let plannedDay = direction == .outbound ? startDay : endDay
        let firstFlightDay = flightsInDirection.map { TripDay($0.date) }.min() ?? plannedDay
        let journeyDay = min(plannedDay, firstFlightDay)
        let today = TripDay(now, timeZone: destination?.timeZone ?? .current)
        if today < journeyDay || flightsInDirection.isEmpty {
            return TripArrivalOverview(title: "\(added) of \(participants.count) flights added",
                                       detail: waiting, progressCount: added)
        }

        let relevant = flightsInDirection.filter { direction == .inbound || $0.destination == destinationAirport }
        let landed = Set(relevant.filter { $0.status == .landed && !$0.isStatusStale(at: now) }
            .compactMap(\.travelerID)).intersection(memberIDs).count
        let next = relevant.filter { ![.landed, .cancelled, .diverted].contains($0.status) && !$0.isStatusStale(at: now)
            && ($0.expectedArrival ?? .distantPast) > now }
            .min { ($0.expectedArrival ?? .distantFuture) < ($1.expectedArrival ?? .distantFuture) }
        let detail: String
        if let next {
            let date = next.arrivalDayLabel.map { "\($0), " } ?? ""
            let zone = next.arrivalTimeZoneLabel.map { " \($0)" } ?? ""
            detail = "Next: \(next.traveler) · \(date)\(next.arrivalTime)\(zone)"
        } else if relevant.contains(where: { $0.isStatusStale(at: now) }) {
            detail = "Flight updates delayed · check flight details"
        } else if missing > 0 {
            detail = "\(missing) \(missing == 1 ? "traveler hasn’t" : "travelers haven’t") added a flight"
        } else {
            detail = landed == participants.count ? "Everyone has arrived" : "All flights added · see schedules below"
        }
        return TripArrivalOverview(title: "\(landed) of \(participants.count) travelers arrived",
                                   detail: detail, progressCount: landed)
    }

    func phase(at now: Date = Date()) -> TripPhase {
        if completedAt != nil { return .past }
        let today = TripDay(now, timeZone: destination?.timeZone ?? .current)
        if today < startDay { return .upcoming }
        if today > endDay { return .past }
        return .ongoing
    }

    static func examples(owner: TripParticipant, now: Date = Date()) -> [TripPlan] {
        let calendar = Calendar.current
        func day(_ offset: Int) -> TripDay {
            TripDay(calendar.date(byAdding: .day, value: offset, to: now)!)
        }
        let members = [owner,
                       TripParticipant(id: "example-mia", name: "Mia Chen"),
                       TripParticipant(id: "example-david", name: "David Kim"),
                       TripParticipant(id: "example-lin", name: "Lin Zhao"),
                       TripParticipant(id: "example-alex", name: "Alex Rivera")]
        func flights(start: TripDay, end: TripDay) -> [TripFlight] {
            TripFlight.previewFlights.map { source in
                var flight = source
                if flight.id.hasPrefix("wang-") { flight.traveler = owner.name }
                let fixtureIDs = ["wang": owner.id, "mia": "example-mia", "david": "example-david", "alex": "example-alex"]
                flight.travelerID = fixtureIDs[String(flight.id.split(separator: "-").first ?? "")]
                flight.date = (flight.direction == .outbound ? start : end).pickerDate
                return flight
            }
        }
        let oldStart = TripDay(calendar.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 12))!)
        let oldEnd = TripDay(calendar.date(from: DateComponents(year: 2026, month: 4, day: 20, hour: 12))!)
        return [
            TripPlan(id: "example-west", name: "West Coast weekend", destinationAirport: "LAX",
                     startDay: day(-1), endDay: day(3), participants: members,
                     flights: flights(start: day(-1), end: day(3)), isExample: true),
            TripPlan(id: "example-new-york", name: "New York catch-up", destinationAirport: "JFK",
                     startDay: day(-1), endDay: day(2), participants: [owner, members[1]], flights: [], isExample: true),
            TripPlan(id: "example-tokyo", name: "Tokyo in autumn", destinationAirport: "NRT",
                     startDay: day(21), endDay: day(28), participants: [owner, members[3], members[4]], flights: [], isExample: true),
            TripPlan(id: "example-coachella", name: "Coachella 2026", destinationAirport: "LAX",
                     startDay: oldStart, endDay: oldEnd, participants: members,
                     flights: flights(start: oldStart, end: oldEnd), isExample: true)
        ].map { source in
            var trip = source
            trip.creatorUserID = owner.userID
            return trip
        }
    }
}

/// Cloud is authoritative in remote mode. JSON is an account/origin-scoped read cache.
/// Mutations are acknowledged by the server before they are shown as saved.
@MainActor
final class TripLibrary: ObservableObject {
    @Published private(set) var trips: [TripPlan] = []
    @Published private(set) var scope: String?
    @Published private(set) var currentUserID: String?
    @Published var errorMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSaving = false
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var syncFailed = false
    @Published private(set) var invitations: [TripInvitation] = []
    @Published private(set) var deviceDrafts: [TripPlan] = []
    private var remote: (any AppRepository)?
    private var generation = 0
    private var importedDraftIDs: Set<String> = []
    var isCloud: Bool { remote != nil }
    var syncLabel: String {
        if !isCloud { return "Demo · saved on this device" }
        if isSaving { return "Saving to your account…" }
        if isRefreshing { return "Updating trips…" }
        if syncFailed || lastSyncedAt == nil { return "Cached on this device · pull to retry sync" }
        return "Synced to your account"
    }

    func connect(_ repository: any AppRepository) { remote = repository.mode == .remote ? repository : nil }
    private let directory: URL
    private var fileURL: URL?
    private var canSave = false
    private var cacheEpoch = 0

    private struct Archive: Codable {
        let version: Int
        let trips: [TripPlan]
        var importedDraftIDs: [String]? = nil
    }

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TripLibrary", isDirectory: true)
    }

    func load(scope newScope: String, userID: String?) {
        guard scope != newScope || currentUserID != userID else { return }
        trips = []
        generation += 1
        errorMessage = nil
        scope = newScope
        cacheEpoch = AccountLocalData.epoch(for: newScope)
        currentUserID = userID
        canSave = false
        fileURL = nil
        invitations = []
        deviceDrafts = []
        importedDraftIDs = []
        lastSyncedAt = nil
        syncFailed = false
        guard userID != nil else { return }
        // Scope is supplied by the app (repository mode + UUID), never a user-entered path.
        let safeScope = newScope.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        fileURL = directory.appendingPathComponent("\(safeScope).json")
        guard let fileURL else { return }
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: fileURL))
                guard archive.version == 1 else { throw LibraryError.unsupportedVersion }
                trips = archive.trips
                importedDraftIDs = Set(archive.importedDraftIDs ?? [])
            }
            canSave = userID != nil
        } catch {
            errorMessage = "Your saved trips couldn't be opened. The original file has been preserved."
        }
    }

    func trips(in phase: TripPhase, at now: Date = Date()) -> [TripPlan] {
        trips.filter { $0.phase(at: now) == phase }.sorted {
            let lhs = phase == .past ? $0.endDay : $0.startDay
            let rhs = phase == .past ? $1.endDay : $1.startDay
            if lhs == rhs { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return phase == .past ? lhs > rhs : lhs < rhs
        }
    }

    @discardableResult
    func add(_ trip: TripPlan) -> Bool {
        guard let currentUserID, trip.creatorUserID == currentUserID,
              trip.participants.count == 1, trip.participants.first?.userID == currentUserID, trip.flights.isEmpty,
              !trips.contains(where: { $0.id == trip.id }), !trip.name.trimmingCharacters(in: .whitespaces).isEmpty,
              trip.startDay <= trip.endDay, trip.destination != nil else { return false }
        return save(trips + [trip])
    }

    @discardableResult
    private func update(_ id: String, mutation: (inout TripPlan) -> Void) -> Bool {
        guard let index = trips.firstIndex(where: { $0.id == id }) else { return false }
        var next = trips
        mutation(&next[index])
        guard next[index].startDay <= next[index].endDay, next[index].destination != nil,
              !next[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return save(next)
    }

    @discardableResult
    func addFlight(_ flight: TripFlight, to tripID: String) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripID }),
              !trip.flights.contains(where: { $0.id == flight.id }),
              owns(flight, in: trip) else { return false }
        return update(tripID) { $0.flights.append(flight) }
    }

    func selfParticipant(in trip: TripPlan) -> TripParticipant? {
        guard let currentUserID else { return nil }
        return trip.participants.first { $0.userID == currentUserID }
    }

    func canManage(_ trip: TripPlan) -> Bool {
        currentUserID != nil && trip.creatorUserID == currentUserID && selfParticipant(in: trip) != nil
    }

    func owns(_ flight: TripFlight, in trip: TripPlan) -> Bool {
        guard let person = selfParticipant(in: trip) else { return false }
        return flight.travelerID == person.id
    }

    @discardableResult
    func editFlight(_ flight: TripFlight, in tripID: String) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripID }), owns(flight, in: trip),
              let old = trip.flights.first(where: { $0.id == flight.id }), owns(old, in: trip) else { return false }
        return update(tripID) { plan in
            if let index = plan.flights.firstIndex(where: { $0.id == flight.id }) { plan.flights[index] = flight }
        }
    }

    @discardableResult
    func deleteFlight(_ id: String, in tripID: String) -> Bool {
        guard let trip = trips.first(where: { $0.id == tripID }),
              let flight = trip.flights.first(where: { $0.id == id }), owns(flight, in: trip) else { return false }
        return update(tripID) { $0.flights.removeAll { $0.id == id } }
    }

    @discardableResult
    func editTrip(_ id: String, name: String, airport: String, start: TripDay, end: TripDay) -> Bool {
        guard let trip = trips.first(where: { $0.id == id }), canManage(trip) else { return false }
        return update(id) { $0.name = name; $0.destinationAirport = airport; $0.startDay = start; $0.endDay = end }
    }

    @discardableResult
    func complete(_ id: String, at date: Date?) -> Bool {
        guard let trip = trips.first(where: { $0.id == id }), canManage(trip) else { return false }
        return update(id) { $0.completedAt = date }
    }

    func addExamples(owner: TripParticipant) {
        guard !isCloud, trips.isEmpty, let currentUserID, owner.userID == currentUserID else { return }
        _ = save(TripPlan.examples(owner: owner))
    }

    private func save(_ next: [TripPlan]) -> Bool {
        guard canSave, let fileURL, let scope, AccountLocalData.epoch(for: scope) == cacheEpoch else {
            errorMessage = "Trips are not ready to save. Your existing data has not been changed."
            return false
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(Archive(version: 1, trips: next, importedDraftIDs: importedDraftIDs.sorted()))
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            trips = next
            return true
        } catch {
            errorMessage = "This change couldn't be saved on your device. Please try again."
            return false
        }
    }

    private enum LibraryError: Error { case unsupportedVersion }

    func refresh() async {
        guard let remote, let userID = currentUserID, !isRefreshing, !isSaving else { return }
        let capturedScope = scope
        let capturedGeneration = generation
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let result = try await remote.fetchTrips()
            guard scope == capturedScope, currentUserID == userID, generation == capturedGeneration else { return }
            let plans = result.map { $0.plan(userID: userID) }
            if !save(plans) { trips = plans }
            lastSyncedAt = Date()
            syncFailed = false
            let incoming = try await remote.tripInvitations(tripID: nil)
            guard scope == capturedScope, currentUserID == userID, generation == capturedGeneration else { return }
            invitations = incoming
        } catch {
            guard scope == capturedScope, generation == capturedGeneration else { return }
            syncFailed = true
            if error as? RepositoryError == .sessionExpired || error as? RepositoryError == .notAuthenticated {
                trips = []
                invitations = []
            }
        }
    }

    private func cloudSave(_ operation: (any AppRepository) async throws -> CloudTrip) async -> Bool {
        guard let remote, let userID = currentUserID, !isSaving else { return false }
        let capturedScope = scope
        isSaving = true
        generation += 1
        defer { isSaving = false }
        do {
            let result = try await operation(remote)
            guard scope == capturedScope, currentUserID == userID else { return false }
            let plan = result.plan(userID: userID)
            let next = trips.filter { $0.id != plan.id } + [plan]
            if !save(next) { trips = next; errorMessage = "Saved to your account, but the offline cache couldn't be updated." }
            syncFailed = false
            lastSyncedAt = Date()
            return true
        } catch {
            guard scope == capturedScope else { return false }
            syncFailed = true
            let reason = error as? RepositoryError == .networkUnavailable ? "You're offline. Reconnect and try again; this change isn't queued." : error.localizedDescription
            errorMessage = "Cloud save wasn't confirmed. Your form has been kept. \(reason)"
            return false
        }
    }

    func create(_ trip: TripPlan) async -> Bool {
        guard isCloud else { return add(trip) }
        guard trip.creatorUserID == currentUserID, !trip.isExample else { return false }
        return await cloudSave { try await $0.createTrip(TripPayload(id: trip.id, name: trip.name,
            destinationAirport: trip.destinationAirport, startDate: trip.startDay.value, endDate: trip.endDay.value)) }
    }

    func setFlightAlerts(_ enabled: Bool, tripID: String) async -> Bool {
        guard isCloud else { return false }
        return await cloudSave { try await $0.updateTripCollaboration(id: tripID, action: "preferences", payload: .init(enabled: enabled)) }
    }

    func saveMeetingPoint(_ point: String, tripID: String, revision: Int?) async -> Bool {
        guard let trip = trips.first(where: { $0.id == tripID }), canManage(trip) else { return false }
        if !isCloud {
            var edited = trip; edited.meetingPoint = point
            return save(trips.map { $0.id == tripID ? edited : $0 })
        }
        return await cloudSave { try await $0.updateTripCollaboration(id: tripID, action: "meeting", payload: .init(point: point, revision: revision)) }
    }

    func checkIn(_ state: TripCheckIn, tripID: String) async -> Bool {
        guard let trip = trips.first(where: { $0.id == tripID }), let person = selfParticipant(in: trip) else { return false }
        if !isCloud {
            var edited = trip
            edited.participants = trip.participants.map { source in
                var next = source
                if source.id == person.id { next.checkIn = state; next.checkInAt = state == .notSet ? nil : Date() }
                return next
            }
            return save(trips.map { $0.id == tripID ? edited : $0 })
        }
        return await cloudSave { try await $0.updateTripCollaboration(id: tripID, action: "check-in", payload: .init(state: state.rawValue)) }
    }

    func saveDetails(_ id: String, name: String, airport: String, start: TripDay, end: TripDay, revision: Int?) async -> Bool {
        guard isCloud else { return editTrip(id, name: name, airport: airport, start: start, end: end) }
        guard let trip = trips.first(where: { $0.id == id }), canManage(trip) else { return false }
        return await cloudSave { try await $0.mutateTrip(id: id, mutation: TripMutation(kind: "details",
            payload: TripPayload(name: name, destinationAirport: airport, startDate: start.value, endDate: end.value), revision: revision)) }
    }

    func setComplete(_ id: String, at date: Date?) async -> Bool {
        guard isCloud else { return complete(id, at: date) }
        guard let trip = trips.first(where: { $0.id == id }), canManage(trip) else { return false }
        return await cloudSave { try await $0.mutateTrip(id: id, mutation: TripMutation(kind: "completion",
            payload: TripPayload(completed: date != nil), revision: trip.revision)) }
    }

    func saveFlight(_ flight: TripFlight, tripID: String, editing: Bool, candidateID: String?) async -> Bool {
        guard isCloud else { return editing ? editFlight(flight, in: tripID) : addFlight(flight, to: tripID) }
        guard let trip = trips.first(where: { $0.id == tripID }), owns(flight, in: trip) else { return false }
        return await cloudSave { try await $0.mutateTrip(id: tripID, mutation: TripMutation(kind: editing ? "editFlight" : "addFlight",
            payload: TripPayload(id: flight.id, flightNumber: flight.flightNumber, date: TripDay(flight.date).value,
                direction: flight.direction.rawValue, candidateID: candidateID), revision: flight.revision)) }
    }

    func removeFlight(_ id: String, tripID: String) async -> Bool {
        guard isCloud else { return deleteFlight(id, in: tripID) }
        guard let trip = trips.first(where: { $0.id == tripID }), let flight = trip.flights.first(where: { $0.id == id }), owns(flight, in: trip) else { return false }
        return await cloudSave { try await $0.mutateTrip(id: tripID, mutation: TripMutation(kind: "deleteFlight",
            payload: TripPayload(id: id), revision: flight.revision)) }
    }

    func accept(_ invitation: TripInvitation) async -> Bool {
        let success = await cloudSave { try await $0.acceptTripInvitation(id: invitation.id) }
        if success { invitations.removeAll { $0.id == invitation.id } }
        return success
    }

    func decline(_ invitation: TripInvitation) async {
        do {
            try await remote?.dismissTripInvitation(id: invitation.id, revoke: false)
            invitations.removeAll { $0.id == invitation.id }
        } catch { errorMessage = error.localizedDescription }
    }

    // Preserve old archives, never silently upload examples, guests, or another person's flights.
    func readDeviceDrafts(legacyScope: String) {
        guard isCloud, let currentUserID else { return }
        let safe = legacyScope.replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "_", options: .regularExpression)
        let url = directory.appendingPathComponent("\(safe).json")
        guard url != fileURL, let data = try? Data(contentsOf: url), let archive = try? JSONDecoder().decode(Archive.self, from: data) else { return }
        deviceDrafts = archive.trips.filter { !$0.isExample && $0.creatorUserID == currentUserID && !importedDraftIDs.contains($0.id) }
    }

    func importDraft(_ draft: TripPlan) async -> Bool {
        guard !draft.isExample, draft.creatorUserID == currentUserID else { return false }
        guard await create(draft) else { return false }
        for source in draft.flights where owns(source, in: draft) {
            guard let destination = trips.first(where: { $0.id == draft.id }), let person = selfParticipant(in: destination) else { return false }
            if destination.flights.contains(where: { $0.id == source.id }) { continue }
            var ownFlight = source
            ownFlight.travelerID = person.id
            // Old client snapshots aren't verified provider data: import number/date only.
            guard await saveFlight(ownFlight, tripID: draft.id, editing: false, candidateID: nil) else { return false }
        }
        if draft.completedAt != nil, !(await setComplete(draft.id, at: draft.completedAt)) { return false }
        deviceDrafts.removeAll { $0.id == draft.id }
        importedDraftIDs.insert(draft.id)
        _ = save(trips)
        return true
    }
}
