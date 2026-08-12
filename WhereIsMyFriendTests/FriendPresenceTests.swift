import XCTest
@testable import WhereIsMyFriend

final class FriendPresenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFreshnessTransitions() {
        let fresh = makeFriend(updatedAt: now.addingTimeInterval(-30 * 60))
        let aging = makeFriend(updatedAt: now.addingTimeInterval(-3 * 60 * 60))
        let stale = makeFriend(updatedAt: now.addingTimeInterval(-25 * 60 * 60))

        XCTAssertEqual(fresh.freshness(at: now), .fresh)
        XCTAssertEqual(aging.freshness(at: now), .aging)
        XCTAssertEqual(stale.freshness(at: now), .stale)
    }

    func testPausedPresenceIsUnavailableAndNotSameCityEligible() {
        let paused = FriendPresence(
            displayName: "Mia Chen",
            username: "mia",
            city: "New York",
            countryCode: "US",
            updatedAt: now.addingTimeInterval(-60),
            sharingState: .paused
        )

        XCTAssertEqual(paused.freshness(at: now), .unavailable)
        XCTAssertFalse(paused.isSameCityEligible(at: now))
        XCTAssertFalse(paused.cityDisplay.isEmpty)
    }

    func testSameCityMatchingExcludesAgingAndOtherCities() {
        let freshNewYork = makeFriend(name: "Mia", city: "New York", updatedAt: now.addingTimeInterval(-60))
        let agingNewYork = makeFriend(name: "Alex", city: "New York", updatedAt: now.addingTimeInterval(-3 * 60 * 60))
        let freshTokyo = makeFriend(name: "Lin", city: "Tokyo", updatedAt: now.addingTimeInterval(-60))

        let matches = MockFriendData.sameCityFriends(
            from: [freshNewYork, agingNewYork, freshTokyo],
            currentCity: "new york",
            now: now
        )

        XCTAssertEqual(matches.map(\.displayName), ["Mia"])
    }

    func testCountryCodeBuildsFlag() {
        XCTAssertEqual(makeFriend(countryCode: "US", updatedAt: now).countryFlag, "🇺🇸")
        XCTAssertEqual(makeFriend(countryCode: nil, updatedAt: now).countryFlag, "")
    }

    private func makeFriend(
        name: String = "Test Friend",
        city: String = "New York",
        countryCode: String? = "US",
        updatedAt: Date
    ) -> FriendPresence {
        FriendPresence(
            displayName: name,
            username: name.lowercased().replacingOccurrences(of: " ", with: ""),
            city: city,
            countryCode: countryCode,
            updatedAt: updatedAt
        )
    }
}

final class LocalDemoRepositoryTests: XCTestCase {
    func testAcceptingIncomingRequestCreatesFriendAndPreferences() async throws {
        let initial = DemoData.initialSnapshot()
        let request = try XCTUnwrap(initial.incomingRequests.first)
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)

        let updated = try await repository.respond(to: request.id, response: .accept)

        XCTAssertTrue(updated.friends.contains(where: { $0.id == request.userID }))
        XCTAssertFalse(updated.friendRequests.contains(where: { $0.id == request.id }))
        XCTAssertTrue(updated.preference(for: request.userID).sharesMyCity)
    }

    func testSendingKnownUsernameCreatesOutgoingRequest() async throws {
        var initial = DemoData.initialSnapshot()
        initial.friendRequests.removeAll { $0.username == "leo" }
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)

        let updated = try await repository.sendFriendRequest(username: "@leo")

        XCTAssertTrue(updated.outgoingRequests.contains(where: { $0.username == "leo" }))
    }

    func testDuplicateAndUnknownInvitesAreRejected() async throws {
        let repository = LocalDemoRepository(snapshot: DemoData.initialSnapshot(), persistsChanges: false)

        do {
            _ = try await repository.sendFriendRequest(username: "mia")
            XCTFail("Expected an already-friends error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .alreadyFriends)
        }

        do {
            _ = try await repository.sendFriendRequest(username: "nobody")
            XCTFail("Expected a user-not-found error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .userNotFound)
        }
    }

    func testSameCityEventIsIdempotentForRepeatedPresenceUpload() async throws {
        var initial = DemoData.initialSnapshot()
        initial.colocationEvents = []
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)

        let first = try await repository.updateCurrentCity(city: "New York", countryCode: "US", source: .manual)
        let second = try await repository.updateCurrentCity(city: "New York", countryCode: "US", source: .manual)

        XCTAssertEqual(first.colocationEvents.count, 1)
        XCTAssertEqual(second.colocationEvents.count, 1)
        XCTAssertEqual(first.colocationEvents.first?.deduplicationKey, second.colocationEvents.first?.deduplicationKey)
    }

    func testSignOutClearsSensitiveWidgetSnapshotData() async throws {
        let repository = LocalDemoRepository(snapshot: DemoData.initialSnapshot(), persistsChanges: false)

        let signedOut = try await repository.signOut()

        XCTAssertFalse(signedOut.isAuthenticated)
        XCTAssertTrue(signedOut.friends.isEmpty)
        XCTAssertNil(signedOut.currentPresence.city)
        XCTAssertTrue(signedOut.colocationEvents.isEmpty)
    }

    func testFriendPreferencesAreIndependent() async throws {
        let initial = DemoData.initialSnapshot()
        let firstFriend = try XCTUnwrap(initial.friends.first)
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)
        let changed = FriendAccessPreference(
            friendID: firstFriend.id,
            sharesMyCity: false,
            sameCityAlertEnabled: false
        )

        let updated = try await repository.setFriendPreference(changed)

        XCTAssertEqual(updated.preference(for: firstFriend.id), changed)
        XCTAssertTrue(updated.friendPreferences.filter { $0.friendID != firstFriend.id }.allSatisfy(\.sharesMyCity))
    }
}
