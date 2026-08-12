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

    func testCityIdentityIgnoresCaseWhitespaceAndDiacriticsButHonorsKnownCountry() {
        XCTAssertTrue(
            CityIdentity.matches(
                city: "  São   Paulo ",
                countryCode: "BR",
                otherCity: "sao paulo",
                otherCountryCode: nil
            )
        )
        XCTAssertFalse(
            CityIdentity.matches(
                city: "London",
                countryCode: "GB",
                otherCity: "London",
                otherCountryCode: "CA"
            )
        )
    }

    func testProfileValidationNormalizesSafeValues() throws {
        let update = try ProfileUpdate(
            displayName: "  Wang Yang  ",
            username: "@Wang_Yang",
            avatarPalette: 99
        ).validated()

        XCTAssertEqual(update.displayName, "Wang Yang")
        XCTAssertEqual(update.username, "wang_yang")
        XCTAssertEqual(update.avatarPalette, 6)
        XCTAssertThrowsError(
            try ProfileUpdate(displayName: "Name", username: "bad-name", avatarPalette: 1).validated()
        )
    }

    func testInviteLinkParserSupportsAppAndUniversalLinks() {
        let appLink = URL(string: "whereismyfriend://invite/Jamie")!
        let universalLink = URL(string: "https://example.com/invite/priya")!

        XCTAssertEqual(InviteLinkParser.parse(appLink)?.username, "jamie")
        XCTAssertEqual(InviteLinkParser.parse(universalLink)?.username, "priya")
        XCTAssertNil(InviteLinkParser.parse(URL(string: "https://example.com/profile/jamie")!))
        XCTAssertNil(InviteLinkParser.parse(URL(string: "whereismyfriend://invite/bad-name")!))
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
        initial.colocationSessions = []
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)

        let first = try await repository.updateCurrentCity(city: "New York", countryCode: "US", source: .manual)
        let second = try await repository.updateCurrentCity(city: "New York", countryCode: "US", source: .manual)

        XCTAssertEqual(first.colocationEvents.count, 1)
        XCTAssertEqual(second.colocationEvents.count, 1)
        XCTAssertEqual(first.colocationEvents.first?.deduplicationKey, second.colocationEvents.first?.deduplicationKey)
    }

    func testColocationRequiresExitAndCooldownBeforeAnotherEvent() throws {
        let enteredAt = Date(timeIntervalSince1970: 1_900_000_000)
        var snapshot = DemoData.initialSnapshot(now: enteredAt)
        let friendID = try XCTUnwrap(snapshot.friends.first?.id)
        snapshot.friends = [try XCTUnwrap(snapshot.friends.first)]
        snapshot.friends[0].city = "New York"
        snapshot.friends[0].countryCode = "US"
        snapshot.friends[0].updatedAt = enteredAt.addingTimeInterval(-60)
        snapshot.friendPreferences = [
            FriendAccessPreference(friendID: friendID, sharesMyCity: true, sameCityAlertEnabled: true)
        ]
        snapshot.currentPresence = CurrentUserPresence(
            city: "New York",
            countryCode: "US",
            updatedAt: enteredAt,
            source: .manual
        )
        snapshot.colocationEvents = []
        snapshot.colocationSessions = []

        ColocationEvaluator.evaluate(snapshot: &snapshot, now: enteredAt)
        XCTAssertEqual(snapshot.colocationEvents.count, 1)
        XCTAssertEqual(snapshot.colocationSessions.filter(\.isActive).count, 1)

        snapshot.friends[0].city = "Tokyo"
        ColocationEvaluator.evaluate(snapshot: &snapshot, now: enteredAt.addingTimeInterval(60 * 60))
        XCTAssertEqual(snapshot.colocationSessions.filter(\.isActive).count, 0)

        snapshot.friends[0].city = "New York"
        snapshot.friends[0].updatedAt = enteredAt.addingTimeInterval(2 * 60 * 60)
        ColocationEvaluator.evaluate(snapshot: &snapshot, now: enteredAt.addingTimeInterval(2 * 60 * 60))
        XCTAssertEqual(snapshot.colocationEvents.count, 1)

        snapshot.friends[0].updatedAt = enteredAt.addingTimeInterval(7 * 60 * 60)
        snapshot.currentPresence.updatedAt = enteredAt.addingTimeInterval(7 * 60 * 60)
        ColocationEvaluator.evaluate(snapshot: &snapshot, now: enteredAt.addingTimeInterval(7 * 60 * 60))
        XCTAssertEqual(snapshot.colocationEvents.count, 2)
    }

    func testProfileBlockAndUnblockLifecycle() async throws {
        let initial = DemoData.initialSnapshot()
        let friend = try XCTUnwrap(initial.friends.first)
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)

        let profile = try await repository.updateProfile(
            ProfileUpdate(displayName: "New Name", username: "new_name", avatarPalette: 4)
        )
        XCTAssertEqual(profile.currentUser.username, "new_name")

        let blocked = try await repository.blockUser(id: friend.id)
        XCTAssertFalse(blocked.friends.contains(where: { $0.id == friend.id }))
        XCTAssertTrue(blocked.blockedPeople.contains(where: { $0.id == friend.id }))
        XCTAssertFalse(blocked.colocationEvents.contains(where: { $0.friendIDs.contains(friend.id) }))

        let unblocked = try await repository.unblockUser(id: friend.id)
        XCTAssertFalse(unblocked.blockedUserIDs.contains(friend.id))
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

final class OfflineMutationQueueTests: XCTestCase {
    func testQueueCoalescesAndBacksOffFailedMutations() async throws {
        let suiteName = "OfflineMutationQueueTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let queue = OfflineMutationQueue(defaults: defaults, storageKey: "queue")
        let now = Date(timeIntervalSince1970: 2_000_000_000)

        await queue.enqueue(
            .presence(PendingPresenceUpload(city: "London", countryCode: "GB", source: .manual, clientUpdatedAt: now)),
            now: now
        )
        await queue.enqueue(
            .presence(PendingPresenceUpload(city: "Tokyo", countryCode: "JP", source: .visit, clientUpdatedAt: now)),
            now: now
        )
        await queue.enqueue(.pushToken("token"), now: now)

        let queuedCount = await queue.count()
        XCTAssertEqual(queuedCount, 2)
        let due = await queue.due(at: now)
        XCTAssertEqual(due.count, 2)
        guard let presence = due.first(where: { $0.payload.coalescingKey == "presence" }) else {
            return XCTFail("Expected a coalesced presence mutation")
        }
        if case .presence(let upload) = presence.payload {
            XCTAssertEqual(upload.city, "Tokyo")
        } else {
            XCTFail("Expected a presence mutation")
        }

        await queue.markFailed(id: presence.id, now: now)
        let tooEarly = await queue.due(at: now.addingTimeInterval(14))
        let retryReady = await queue.due(at: now.addingTimeInterval(15))
        XCTAssertFalse(tooEarly.contains(where: { $0.id == presence.id }))
        XCTAssertTrue(retryReady.contains(where: { $0.id == presence.id }))
        defaults.removePersistentDomain(forName: suiteName)
    }
}
