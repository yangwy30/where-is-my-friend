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

        XCTAssertEqual(InviteLinkParser.parse(appLink, appScheme: "whereismyfriend")?.username, "jamie")
        XCTAssertEqual(
            InviteLinkParser.parse(universalLink, trustedInviteHosts: ["example.com"])?.username,
            "priya"
        )
        XCTAssertNil(InviteLinkParser.parse(universalLink, trustedInviteHosts: ["friends.example.com"]))
        XCTAssertNil(
            InviteLinkParser.parse(
                URL(string: "https://example.com/profile/jamie")!,
                trustedInviteHosts: ["example.com"]
            )
        )
        XCTAssertNil(InviteLinkParser.parse(URL(string: "whereismyfriend://invite/bad-name")!))
    }

    func testPrivacyPolicyConfigurationRequiresARealHTTPSURL() {
        XCTAssertNil(PrivacyPolicyConfiguration.validated(rawValue: nil))
        XCTAssertNil(PrivacyPolicyConfiguration.validated(rawValue: "http://example.com/privacy"))
        XCTAssertNil(PrivacyPolicyConfiguration.validated(rawValue: "https://example.invalid/privacy"))
        XCTAssertEqual(
            PrivacyPolicyConfiguration.validated(rawValue: "https://example.com/privacy")?.absoluteString,
            "https://example.com/privacy"
        )
    }

    func testSameCityListHonorsCountryCode() {
        let londonCanada = makeFriend(
            name: "Canadian Friend",
            city: "London",
            countryCode: "CA",
            updatedAt: now
        )
        XCTAssertTrue(
            MockFriendData.sameCityFriends(
                from: [londonCanada],
                currentCity: "London",
                currentCountryCode: "GB",
                now: now
            ).isEmpty
        )
    }

    func testAPIConfigurationRejectsPlaceholderAndInsecureOrigins() {
        XCTAssertNil(APIConfiguration.validated(rawValue: "https://api.example.invalid"))
        XCTAssertNil(APIConfiguration.validated(rawValue: "https://staging-api.example.invalid"))
        XCTAssertNil(APIConfiguration.validated(rawValue: "http://api.example.com"))
        XCTAssertEqual(
            APIConfiguration.validated(rawValue: "https://api.example.com")?.baseURL,
            URL(string: "https://api.example.com")
        )
        #if DEBUG
        XCTAssertEqual(
            APIConfiguration.validated(rawValue: "http://127.0.0.1:54321/functions/v1/api")?.baseURL,
            URL(string: "http://127.0.0.1:54321/functions/v1/api")
        )
        #endif
    }

    func testAPIConfigurationPreservesEdgeFunctionPrefixWhenBuildingEndpoint() throws {
        let configuration = try XCTUnwrap(
            APIConfiguration.validated(rawValue: "https://project.supabase.co/functions/v1/api")
        )
        XCTAssertEqual(
            configuration.endpoint(path: "/v1/friends/requests")?.absoluteString,
            "https://project.supabase.co/functions/v1/api/v1/friends/requests"
        )
    }

    func testSupabaseConfigurationRejectsSecretKeys() {
        XCTAssertNil(
            SupabaseConfiguration.validated(
                projectURL: "https://project.supabase.co",
                publishableKey: "sb_" + "secret_do-not-ship"
            )
        )
        XCTAssertNotNil(
            SupabaseConfiguration.validated(
                projectURL: "https://project.supabase.co",
                publishableKey: "sb_publishable_test"
            )
        )
    }

    func testAppleSignInNonceIsRandomAndHashable() throws {
        let first = try AppleSignInNonce.make()
        let second = try AppleSignInNonce.make()
        XCTAssertEqual(first.count, 32)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(
            AppleSignInNonce.sha256("test"),
            "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        )
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
        let ownerID = UUID()

        await queue.enqueue(
            .presence(PendingPresenceUpload(city: "London", countryCode: "GB", source: .manual, clientUpdatedAt: now)),
            ownerID: ownerID,
            now: now
        )
        await queue.enqueue(
            .presence(PendingPresenceUpload(city: "Tokyo", countryCode: "JP", source: .visit, clientUpdatedAt: now)),
            ownerID: ownerID,
            now: now
        )
        await queue.enqueue(.pushToken("token"), ownerID: ownerID, now: now)

        let queuedCount = await queue.count(ownerID: ownerID)
        XCTAssertEqual(queuedCount, 2)
        let due = await queue.due(ownerID: ownerID, at: now)
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
        let tooEarly = await queue.due(ownerID: ownerID, at: now.addingTimeInterval(14))
        let retryReady = await queue.due(ownerID: ownerID, at: now.addingTimeInterval(15))
        XCTAssertFalse(tooEarly.contains(where: { $0.id == presence.id }))
        XCTAssertTrue(retryReady.contains(where: { $0.id == presence.id }))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testQueueNeverReturnsAnotherAccountsMutations() async throws {
        let suiteName = "OfflineMutationQueueIsolationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let queue = OfflineMutationQueue(defaults: defaults, storageKey: "queue")
        let firstOwner = UUID()
        let secondOwner = UUID()

        await queue.enqueue(.pushToken("first"), ownerID: firstOwner)
        await queue.enqueue(.pushToken("second"), ownerID: secondOwner)

        let firstMutations = await queue.all(ownerID: firstOwner)
        let secondMutations = await queue.all(ownerID: secondOwner)
        XCTAssertEqual(firstMutations.count, 1)
        XCTAssertEqual(secondMutations.count, 1)
        XCTAssertEqual(firstMutations.first?.ownerID, firstOwner)
        XCTAssertEqual(secondMutations.first?.ownerID, secondOwner)
        defaults.removePersistentDomain(forName: suiteName)
    }
}

final class RemoteAppRepositoryTests: XCTestCase {
    private let installationID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!

    override func tearDown() {
        StubURLProtocol.setHandler(nil)
        SharedAppStateStore.reset()
        super.tearDown()
    }

    func testExpiredSessionClearsToken() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        StubURLProtocol.setHandler { _ in .response(statusCode: 401, data: Data()) }

        do {
            _ = try await setup.repository.loadSnapshot()
            XCTFail("Expected the expired session to fail")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .sessionExpired)
        }
        XCTAssertNil(setup.tokenStore.load())
    }

    func testExpiredSessionDuringPushRegistrationClearsToken() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        StubURLProtocol.setHandler { _ in .response(statusCode: 403, data: Data()) }

        do {
            try await setup.repository.registerPushToken("push-token")
            XCTFail("Expected the expired session to fail")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .sessionExpired)
        }
        XCTAssertNil(setup.tokenStore.load())
    }

    func testAccountDeletionUsesDeleteEndpointAndClearsLocalSession() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let response = try encoder.encode(DemoData.signedOutSnapshot())
        var capturedMethod: String?
        var capturedPath: String?
        StubURLProtocol.setHandler { request in
            capturedMethod = request.httpMethod
            capturedPath = request.url?.path
            return .response(statusCode: 200, data: response)
        }

        let snapshot = try await setup.repository.deleteAccount()

        XCTAssertEqual(capturedMethod, "DELETE")
        XCTAssertEqual(capturedPath, "/v1/account")
        XCTAssertFalse(snapshot.isAuthenticated)
        XCTAssertNil(setup.tokenStore.load())
    }

    func testPushRegistrationSendsStableInstallationAndSandboxEnvironment() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        var requestBody: [String: Any] = [:]
        StubURLProtocol.setHandler { request in
            if let data = requestBodyData(request),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                requestBody = object
            }
            return .response(statusCode: 204, data: Data())
        }

        try await setup.repository.registerPushToken(String(repeating: "ab", count: 32))

        XCTAssertEqual(requestBody["token"] as? String, String(repeating: "ab", count: 32))
        XCTAssertEqual(requestBody["platform"] as? String, "ios")
        XCTAssertEqual(requestBody["environment"] as? String, "sandbox")
        XCTAssertEqual(
            (requestBody["installationID"] as? String)?.lowercased(),
            installationID.uuidString.lowercased()
        )
        let isPending = await setup.repository.isPushRegistrationPending()
        XCTAssertFalse(isPending)
    }

    func testOfflinePushRegistrationReportsThatItIsWaitingForNetwork() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        StubURLProtocol.setHandler { _ in .failure(URLError(.notConnectedToInternet)) }

        try await setup.repository.registerPushToken(String(repeating: "cd", count: 32))

        let isPending = await setup.repository.isPushRegistrationPending()
        XCTAssertTrue(isPending)
    }

    func testTerminalQueuedMutationIsRemovedInsteadOfBlockingFutureSync() async throws {
        let setup = try makeRepository()
        let snapshot = DemoData.initialSnapshot()
        SharedAppStateStore.save(snapshot, origin: setup.repository.storageScope)
        await setup.queue.enqueue(
            .sharingPreferences(snapshot.sharingPreferences),
            ownerID: snapshot.currentUser.id
        )
        StubURLProtocol.setHandler { _ in
            .response(statusCode: 400, data: Data(#"{"message":"invalid preference"}"#.utf8))
        }

        do {
            _ = try await setup.repository.retryPendingOperations()
            XCTFail("Expected a terminal server error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .message("invalid preference"))
        }
        let pendingCount = await setup.queue.count(ownerID: snapshot.currentUser.id)
        XCTAssertEqual(pendingCount, 0)
    }

    func testOfflinePauseSharingAppliesLocallyAndQueuesRetry() async throws {
        let setup = try makeRepository()
        var snapshot = DemoData.initialSnapshot()
        snapshot.sharingPreferences.citySharingEnabled = true
        SharedAppStateStore.save(snapshot, origin: setup.repository.storageScope)
        StubURLProtocol.setHandler { _ in .failure(URLError(.notConnectedToInternet)) }

        var pausedPreferences = snapshot.sharingPreferences
        pausedPreferences.citySharingEnabled = false
        let paused = try await setup.repository.setSharingPreferences(pausedPreferences)

        XCTAssertFalse(paused.sharingPreferences.citySharingEnabled)
        XCTAssertEqual(paused.syncState, .offline)
        let pendingCount = await setup.queue.count(ownerID: snapshot.currentUser.id)
        XCTAssertEqual(pendingCount, 1)
    }

    private func makeRepository() throws -> (
        repository: RemoteAppRepository,
        queue: OfflineMutationQueue,
        tokenStore: InMemoryTokenStore
    ) {
        let configuration = try XCTUnwrap(APIConfiguration.validated(rawValue: "https://api.test"))
        let supabaseConfiguration = try XCTUnwrap(
            SupabaseConfiguration.validated(
                projectURL: "https://project.supabase.co",
                publishableKey: "sb_publishable_test"
            )
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [StubURLProtocol.self]
        let tokenStore = InMemoryTokenStore(token: "token")
        let suiteName = "RemoteAppRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let queue = OfflineMutationQueue(defaults: defaults, storageKey: "queue")
        let repository = RemoteAppRepository(
            configuration: configuration,
            supabaseConfiguration: supabaseConfiguration,
            mutationQueue: queue,
            session: URLSession(configuration: sessionConfiguration),
            authentication: tokenStore,
            pushConfiguration: APNsRegistrationConfiguration(
                environment: .sandbox,
                installationID: installationID
            )
        )
        return (repository, queue, tokenStore)
    }
}

@MainActor
final class AppStoreReliabilityTests: XCTestCase {
    override func tearDown() {
        SharedAppStateStore.reset()
        super.tearDown()
    }

    func testLocationUpdateWaitsForInFlightRefreshInsteadOfBeingDropped() async {
        let repository = SlowTestRepository()
        let store = AppStore(repository: repository)

        let refresh = Task { await store.refresh() }
        try? await Task.sleep(for: .milliseconds(40))
        await store.updateCurrentCity(city: "London", countryCode: "GB", source: .significantChange)
        await refresh.value

        let uploadedCities = await repository.uploadedCities()
        XCTAssertEqual(uploadedCities, ["London"])
        XCTAssertEqual(store.snapshot.currentPresence.city, "London")
    }
}

private actor SlowTestRepository: AppRepository {
    nonisolated let mode: RepositoryMode = .localDemo
    nonisolated let storageScope = "test:slow-repository"
    private var snapshot = DemoData.initialSnapshot()
    private var cities: [String] = []

    func loadSnapshot() async throws -> AppSnapshot {
        try await Task.sleep(for: .milliseconds(180))
        return snapshot
    }

    func uploadedCities() -> [String] { cities }
    func signInDemo() async throws -> AppSnapshot { snapshot }
    func signInWithApple(_ payload: AppleSignInPayload) async throws -> AppSnapshot { snapshot }
    func signOut() async throws -> AppSnapshot { DemoData.signedOutSnapshot() }
    func deleteAccount() async throws -> AppSnapshot { DemoData.signedOutSnapshot() }
    func updateProfile(_ update: ProfileUpdate) async throws -> AppSnapshot { snapshot }
    func sendFriendRequest(username: String) async throws -> AppSnapshot { snapshot }
    func respond(to requestID: UUID, response: FriendRequestResponse) async throws -> AppSnapshot { snapshot }
    func removeFriend(id: UUID) async throws -> AppSnapshot { snapshot }
    func blockUser(id: UUID) async throws -> AppSnapshot { snapshot }
    func unblockUser(id: UUID) async throws -> AppSnapshot { snapshot }
    func setFavorite(friendID: UUID, isFavorite: Bool) async throws -> AppSnapshot { snapshot }
    func setFriendPreference(_ preference: FriendAccessPreference) async throws -> AppSnapshot { snapshot }
    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot { snapshot }

    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource) async throws -> AppSnapshot {
        cities.append(city)
        snapshot.currentPresence = CurrentUserPresence(
            city: city,
            countryCode: countryCode,
            updatedAt: Date(),
            source: source
        )
        return snapshot
    }

    func registerPushToken(_ token: String) async throws {}
    func retryPendingOperations() async throws -> AppSnapshot { snapshot }
    func pendingOperationCount() async -> Int { 0 }
    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot { snapshot }
}

private func requestBodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 { return nil }
        if count == 0 { break }
        result.append(buffer, count: count)
    }
    return result
}

private final class InMemoryTokenStore: RemoteAuthenticationProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?

    init(token: String?) { self.token = token }

    func save(_ token: String) {
        lock.lock()
        self.token = token
        lock.unlock()
    }

    func load() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    func clear() {
        lock.lock()
        token = nil
        lock.unlock()
    }

    func accessToken() async throws -> String {
        guard let token = load() else { throw RepositoryError.notAuthenticated }
        return token
    }

    func signInWithApple(_ payload: AppleSignInPayload) async throws -> String {
        guard let token = load() else { throw RepositoryError.notAuthenticated }
        return token
    }

    func refreshAccessToken() async throws -> String {
        throw RepositoryError.sessionExpired
    }

    func signOut() async throws {
        clear()
    }
}

private final class StubURLProtocol: URLProtocol {
    enum Outcome {
        case response(statusCode: Int, data: Data)
        case failure(Error)
    }

    private static let lock = NSLock()
    private static var handler: ((URLRequest) -> Outcome)?

    static func setHandler(_ handler: ((URLRequest) -> Outcome)?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handler
        Self.lock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        switch handler(request) {
        case .response(let statusCode, let data):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
