import XCTest
@testable import WhereIsMyFriend

final class CoreOfflineIntentRegressionTests: XCTestCase {
    override func tearDown() {
        CoreAuditURLProtocol.setHandler(nil)
        SharedAppStateStore.reset()
        super.tearDown()
    }

    func testBootstrapDuringBackoffPreservesPendingPauseAndManualCity() async throws {
        let setup = try makeRepository()
        let server = DemoData.initialSnapshot()
        var local = server
        local.sharingPreferences.citySharingEnabled = false
        local.currentPresence = CurrentUserPresence(administrativeArea: "England", city: "London", countryCode: "GB",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000), source: .manual)
        local.syncState = .offline
        SharedAppStateStore.save(local, origin: setup.repository.storageScope)
        try await queueLocalIntent(local, queue: setup.queue)
        var received = server
        received.currentUser.displayName = "Fresh server name"
        let encoded = try encode(received)
        CoreAuditURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.path, "/v1/auth/bootstrap")
            return .response(200, encoded)
        }

        let refreshed = try await setup.repository.loadSnapshot()
        XCTAssertFalse(refreshed.sharingPreferences.citySharingEnabled)
        XCTAssertEqual(refreshed.currentPresence, local.currentPresence)
        XCTAssertEqual(refreshed.currentUser.displayName, "Fresh server name")
        XCTAssertEqual(refreshed.syncState, .offline)
        let pending = await setup.queue.count(ownerID: local.currentUser.id)
        XCTAssertEqual(pending, 2, "Reading an old server snapshot must not acknowledge queued writes")
    }

    func testUnrelatedFavoriteResponseCannotReenablePendingSharingOrReplaceManualCity() async throws {
        let setup = try makeRepository()
        var local = DemoData.initialSnapshot()
        local.sharingPreferences.citySharingEnabled = false
        local.currentPresence = CurrentUserPresence(administrativeArea: "Tokyo", city: "Tokyo", countryCode: "JP",
            updatedAt: Date(timeIntervalSince1970: 1_800_000_001), source: .manual)
        SharedAppStateStore.save(local, origin: setup.repository.storageScope)
        try await queueLocalIntent(local, queue: setup.queue)
        var server = DemoData.initialSnapshot()
        let friend = try XCTUnwrap(server.friends.first)
        server.friends[0].isFavorite.toggle()
        let encoded = try encode(server)
        CoreAuditURLProtocol.setHandler { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertTrue(request.url?.path.hasSuffix("/favorite") == true)
            return .response(200, encoded)
        }

        let updated = try await setup.repository.setFavorite(friendID: friend.id, isFavorite: !friend.isFavorite)
        XCTAssertFalse(updated.sharingPreferences.citySharingEnabled)
        XCTAssertEqual(updated.currentPresence, local.currentPresence)
        XCTAssertEqual(updated.friends.first?.isFavorite, !friend.isFavorite)
        XCTAssertEqual(updated.syncState, .offline)
    }

    func testQueuedIntentFromAnotherAccountNeverOverlaysCurrentAccount() async throws {
        let setup = try makeRepository()
        var former = DemoData.initialSnapshot()
        former.sharingPreferences.citySharingEnabled = false
        try await queueLocalIntent(former, queue: setup.queue)
        var current = DemoData.initialSnapshot()
        current.currentUser = AppUser(id: UUID(), displayName: "Other account", username: "other_account")
        current.currentPresence = CurrentUserPresence(administrativeArea: "NY", city: "New York", countryCode: "US",
            updatedAt: Date(), source: .foregroundLocation)
        SharedAppStateStore.save(current, origin: setup.repository.storageScope)
        let encoded = try encode(current)
        CoreAuditURLProtocol.setHandler { _ in .response(200, encoded) }

        let refreshed = try await setup.repository.loadSnapshot()
        XCTAssertEqual(refreshed.currentUser.id, current.currentUser.id)
        XCTAssertTrue(refreshed.sharingPreferences.citySharingEnabled)
        XCTAssertEqual(refreshed.currentPresence.city, "New York")
        XCTAssertEqual(refreshed.syncState, current.syncState)
        let oldCount = await setup.queue.count(ownerID: former.currentUser.id)
        XCTAssertEqual(oldCount, 2)
    }

    func testExpiredSessionNeverReturnsAnOptimisticOfflineSnapshot() async throws {
        let setup = try makeRepository()
        var local = DemoData.initialSnapshot()
        local.sharingPreferences.citySharingEnabled = false
        SharedAppStateStore.save(local, origin: setup.repository.storageScope)
        try await queueLocalIntent(local, queue: setup.queue)
        CoreAuditURLProtocol.setHandler { _ in .response(401, Data(#"{"message":"expired"}"#.utf8)) }

        do {
            _ = try await setup.repository.loadSnapshot()
            XCTFail("An expired session must not be treated as a successful offline refresh")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .sessionExpired)
        }
    }

    func testReplayAcknowledgesPauseBeforePublishingQueuedCity() async throws {
        let setup = try makeRepository()
        var server = DemoData.initialSnapshot()
        SharedAppStateStore.save(server, origin: setup.repository.storageScope)
        let observed = Date(timeIntervalSince1970: 1_800_000_002)
        _ = await setup.queue.enqueue(.presence(PendingPresenceUpload(administrativeArea: "England", city: "London",
            countryCode: "GB", source: .manual, clientUpdatedAt: observed)), ownerID: server.currentUser.id,
            now: Date().addingTimeInterval(-10))
        var pause = server.sharingPreferences
        pause.citySharingEnabled = false
        _ = await setup.queue.enqueue(.sharingPreferences(pause), ownerID: server.currentUser.id)
        var paths: [String] = []
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        CoreAuditURLProtocol.setHandler { request in
            let path = request.url!.path
            paths.append(path)
            if path == "/v1/sharing" { server.sharingPreferences = pause }
            if path == "/v1/presence/current" {
                XCTAssertFalse(server.sharingPreferences.citySharingEnabled)
                server.currentPresence = CurrentUserPresence(administrativeArea: "England", city: "London",
                    countryCode: "GB", updatedAt: observed, source: .manual)
            }
            return .response(200, try! encoder.encode(server))
        }

        let updated = try await setup.repository.loadSnapshot()
        XCTAssertEqual(paths, ["/v1/sharing", "/v1/presence/current", "/v1/auth/bootstrap"])
        XCTAssertFalse(updated.sharingPreferences.citySharingEnabled)
        XCTAssertEqual(updated.currentPresence.city, "London")
        XCTAssertEqual(updated.syncState, .synced)
        let count = await setup.queue.count(ownerID: server.currentUser.id)
        XCTAssertEqual(count, 0)
    }

    func testCityWaitsThroughPauseBackoffButPushRegistrationCanRetry() async throws {
        let setup = try makeRepository()
        let owner = UUID(), now = Date()
        let city = await setup.queue.enqueue(.presence(PendingPresenceUpload(city: "London", countryCode: "GB",
            source: .manual, clientUpdatedAt: now)), ownerID: owner, now: now.addingTimeInterval(-20))
        var paused = DemoData.initialSnapshot().sharingPreferences
        paused.citySharingEnabled = false
        let pause = await setup.queue.enqueue(.sharingPreferences(paused), ownerID: owner, now: now.addingTimeInterval(-10))
        let push = await setup.queue.enqueue(.pushToken("test-token"), ownerID: owner, now: now)
        await setup.queue.markFailed(id: pause, now: now)
        let backoff = await setup.queue.replayable(ownerID: owner, at: now.addingTimeInterval(5))
        XCTAssertEqual(backoff.map(\.id), [push])
        let retry = await setup.queue.replayable(ownerID: owner, at: now.addingTimeInterval(16))
        XCTAssertEqual(retry.map(\.id), [pause, city, push])
        let force = await setup.queue.replayable(ownerID: owner, force: true, at: now)
        XCTAssertEqual(force.map(\.id), [pause, city, push])
    }

    func testRejectedPauseRetainsPrivacyIntentAndNeverPublishesCityUntilExplicitRecovery() async throws {
        let setup = try makeRepository()
        var server = DemoData.initialSnapshot()
        var local = server
        local.sharingPreferences.citySharingEnabled = false
        local.syncState = .offline
        SharedAppStateStore.save(local, origin: setup.repository.storageScope)
        let owner = local.currentUser.id
        _ = await setup.queue.enqueue(.presence(PendingPresenceUpload(city: "London", countryCode: "GB",
            source: .manual, clientUpdatedAt: Date())), ownerID: owner, now: Date().addingTimeInterval(-10))
        _ = await setup.queue.enqueue(.sharingPreferences(local.sharingPreferences), ownerID: owner)
        var paths: [String] = []
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        CoreAuditURLProtocol.setHandler { request in
            paths.append(request.url!.path)
            if request.url!.path == "/v1/sharing" {
                return .response(400, Data(#"{"message":"Pause not permitted"}"#.utf8))
            }
            return .response(200, try! encoder.encode(server))
        }
        do {
            _ = try await setup.repository.loadSnapshot()
            XCTFail("A rejected pause must stop the replay batch")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .message("Pause not permitted"))
        }
        XCTAssertEqual(paths, ["/v1/sharing"])
        let retained = await setup.queue.count(ownerID: owner)
        XCTAssertEqual(retained, 2)
        let automatic = await setup.queue.replayable(ownerID: owner, at: Date().addingTimeInterval(86_400))
        XCTAssertTrue(automatic.isEmpty, "Terminal privacy failures await explicit recovery")
        let refreshed = try await setup.repository.loadSnapshot()
        XCTAssertFalse(refreshed.sharingPreferences.citySharingEnabled)
        XCTAssertEqual(refreshed.currentPresence.city, "London")
        XCTAssertEqual(refreshed.syncState, .offline)
        XCTAssertEqual(paths, ["/v1/sharing", "/v1/auth/bootstrap"])

        paths.removeAll()
        CoreAuditURLProtocol.setHandler { request in
            let path = request.url!.path
            paths.append(path)
            if path == "/v1/sharing" { server.sharingPreferences.citySharingEnabled = false }
            if path == "/v1/presence/current" { XCTAssertFalse(server.sharingPreferences.citySharingEnabled) }
            return .response(200, try! encoder.encode(server))
        }
        _ = try await setup.repository.retryPendingOperations()
        XCTAssertEqual(paths, ["/v1/sharing", "/v1/presence/current", "/v1/auth/bootstrap"])
        let cleared = await setup.queue.count(ownerID: owner)
        XCTAssertEqual(cleared, 0)
    }

    func testForbiddenPauseDoesNotPublishCityOrBypassSessionExpiration() async throws {
        let setup = try makeRepository()
        var local = DemoData.initialSnapshot()
        local.sharingPreferences.citySharingEnabled = false
        SharedAppStateStore.save(local, origin: setup.repository.storageScope)
        _ = await setup.queue.enqueue(.presence(PendingPresenceUpload(city: "London", countryCode: "GB",
            source: .manual, clientUpdatedAt: Date())), ownerID: local.currentUser.id, now: Date().addingTimeInterval(-10))
        _ = await setup.queue.enqueue(.sharingPreferences(local.sharingPreferences), ownerID: local.currentUser.id)
        var paths: [String] = []
        CoreAuditURLProtocol.setHandler { request in
            paths.append(request.url!.path)
            return .response(403, Data(#"{"message":"Forbidden"}"#.utf8))
        }
        do {
            _ = try await setup.repository.loadSnapshot()
            XCTFail("A failed credential refresh must invalidate the session")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .sessionExpired)
        }
        XCTAssertEqual(paths, ["/v1/sharing"])
        let pending = await setup.queue.count(ownerID: local.currentUser.id)
        XCTAssertEqual(pending, 2)
    }

    func testManualCityChangeCannotBypassAnUnconfirmedSharingPause() async throws {
        let setup = try makeRepository()
        var cached = DemoData.initialSnapshot()
        cached.sharingPreferences.citySharingEnabled = false
        SharedAppStateStore.save(cached, origin: setup.repository.storageScope)
        _ = await setup.queue.enqueue(.sharingPreferences(cached.sharingPreferences), ownerID: cached.currentUser.id)
        var networkRequests = 0
        let encoded = try encode(DemoData.initialSnapshot())
        CoreAuditURLProtocol.setHandler { _ in networkRequests += 1; return .response(200, encoded) }

        let updated = try await setup.repository.updateCurrentCity(city: "London", countryCode: "GB", source: .manual,
            observedAt: Date(timeIntervalSince1970: 1_800_000_003), administrativeArea: "England")
        XCTAssertEqual(networkRequests, 0)
        XCTAssertFalse(updated.sharingPreferences.citySharingEnabled)
        XCTAssertEqual(updated.currentPresence.city, "London")
        XCTAssertEqual(updated.syncState, .offline)
        let pending = await setup.queue.count(ownerID: cached.currentUser.id)
        XCTAssertEqual(pending, 2)
    }

    func testRejectedPausedPreferenceReplacementPreservesExistingPauseBarrier() async throws {
        let setup = try makeRepository()
        var server = DemoData.initialSnapshot()
        var local = server
        local.sharingPreferences.citySharingEnabled = false
        local.sharingPreferences.notificationPreviewEnabled = true
        local.syncState = .offline
        SharedAppStateStore.save(local, origin: setup.repository.storageScope)
        let owner = local.currentUser.id
        _ = await setup.queue.enqueue(.sharingPreferences(local.sharingPreferences), ownerID: owner)
        _ = await setup.queue.enqueue(.presence(PendingPresenceUpload(city: "London", countryCode: "GB",
            source: .manual, clientUpdatedAt: Date())), ownerID: owner)
        var replacement = local.sharingPreferences
        replacement.notificationPreviewEnabled = false
        var paths: [String] = []
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        CoreAuditURLProtocol.setHandler { request in
            paths.append(request.url!.path)
            if request.url!.path == "/v1/sharing" { return .response(400, Data(#"{"message":"Change rejected"}"#.utf8)) }
            return .response(200, try! encoder.encode(server))
        }
        do {
            _ = try await setup.repository.setSharingPreferences(replacement)
            XCTFail("The rejected replacement must be reported")
        } catch { XCTAssertEqual(error as? RepositoryError, .message("Change rejected")) }
        let barrier = await setup.queue.hasPendingSharingPause(ownerID: owner)
        XCTAssertTrue(barrier)
        let automatic = await setup.queue.replayable(ownerID: owner, at: Date().addingTimeInterval(86_400))
        XCTAssertTrue(automatic.isEmpty)
        let refreshed = try await setup.repository.loadSnapshot()
        XCTAssertFalse(refreshed.sharingPreferences.citySharingEnabled)
        XCTAssertTrue(refreshed.sharingPreferences.notificationPreviewEnabled, "Failed edits must not pretend to be saved")
        XCTAssertEqual(refreshed.currentPresence.city, "London")
        XCTAssertEqual(refreshed.syncState, .offline)
        XCTAssertEqual(paths, ["/v1/sharing", "/v1/auth/bootstrap"])

        CoreAuditURLProtocol.setHandler { request in
            XCTAssertEqual(request.url!.path, "/v1/sharing")
            server.sharingPreferences = replacement
            return .response(200, try! encoder.encode(server))
        }
        let saved = try await setup.repository.setSharingPreferences(replacement)
        XCTAssertFalse(saved.sharingPreferences.citySharingEnabled)
        XCTAssertFalse(saved.sharingPreferences.notificationPreviewEnabled, "An acknowledged replacement must not be overlaid by retired preferences")
        XCTAssertEqual(saved.currentPresence.city, "London")
        let remainingPause = await setup.queue.hasPendingSharingPause(ownerID: owner)
        XCTAssertFalse(remainingPause)
        let remaining = await setup.queue.count(ownerID: owner)
        XCTAssertEqual(remaining, 1)
    }

    func testExplicitResumeStillSupersedesPendingPauseAndAllowsCityReplay() async throws {
        let setup = try makeRepository()
        var local = DemoData.initialSnapshot()
        local.sharingPreferences.citySharingEnabled = false
        SharedAppStateStore.save(local, origin: setup.repository.storageScope)
        let owner = local.currentUser.id
        let pauseID = await setup.queue.enqueue(.sharingPreferences(local.sharingPreferences), ownerID: owner)
        await setup.queue.suspendUntilExplicitRetry(id: pauseID)
        _ = await setup.queue.enqueue(.presence(PendingPresenceUpload(city: "London", countryCode: "GB",
            source: .manual, clientUpdatedAt: Date())), ownerID: owner)
        var resumed = local.sharingPreferences
        resumed.citySharingEnabled = true
        var server = local
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var paths: [String] = []
        CoreAuditURLProtocol.setHandler { request in
            let path = request.url!.path
            paths.append(path)
            if path == "/v1/sharing" { server.sharingPreferences = resumed }
            return .response(200, try! encoder.encode(server))
        }
        let saved = try await setup.repository.setSharingPreferences(resumed)
        XCTAssertTrue(saved.sharingPreferences.citySharingEnabled)
        let barrier = await setup.queue.hasPendingSharingPause(ownerID: owner)
        XCTAssertFalse(barrier)
        _ = try await setup.repository.retryPendingOperations()
        XCTAssertEqual(paths, ["/v1/sharing", "/v1/presence/current", "/v1/auth/bootstrap"])
        let remaining = await setup.queue.count(ownerID: owner)
        XCTAssertEqual(remaining, 0)
    }

    private func queueLocalIntent(_ snapshot: AppSnapshot, queue: OfflineMutationQueue) async throws {
        let presence = snapshot.currentPresence
        let city = try XCTUnwrap(presence.city)
        let observed = try XCTUnwrap(presence.updatedAt)
        let privacyID = await queue.enqueue(.sharingPreferences(snapshot.sharingPreferences), ownerID: snapshot.currentUser.id)
        let cityID = await queue.enqueue(.presence(PendingPresenceUpload(administrativeArea: presence.administrativeArea,
            city: city, countryCode: presence.countryCode, source: presence.source, clientUpdatedAt: observed)), ownerID: snapshot.currentUser.id)
        // A fixed future retry window makes this independent of test execution speed.
        let backoff = Date().addingTimeInterval(3_600)
        await queue.markFailed(id: privacyID, now: backoff)
        await queue.markFailed(id: cityID, now: backoff)
    }

    private func encode(_ snapshot: AppSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private func makeRepository() throws -> (repository: RemoteAppRepository, queue: OfflineMutationQueue) {
        let config = try XCTUnwrap(APIConfiguration.validated(rawValue: "https://core-audit.test"))
        let auth = try XCTUnwrap(SupabaseConfiguration.validated(projectURL: "https://project.supabase.co", publishableKey: "sb_publishable_test"))
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "CoreAuditRegressionTests.\(UUID())"))
        let queue = OfflineMutationQueue(defaults: defaults, storageKey: "queue")
        let session = URLSessionConfiguration.ephemeral
        session.protocolClasses = [CoreAuditURLProtocol.self]
        return (RemoteAppRepository(configuration: config, supabaseConfiguration: auth, mutationQueue: queue,
            session: URLSession(configuration: session), authentication: CoreAuditAuthentication()), queue)
    }
}

@MainActor
final class CoreSnapshotOrderingRegressionTests: XCTestCase {
    override func tearDown() {
        SharedAppStateStore.reset()
        super.tearDown()
    }

    func testFriendActionFailureCallbacksStayLocalAndAllowRetry() async throws {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        let requestID = try XCTUnwrap(initial.incomingRequests.first?.id)
        for action in ["send", "respond", "withdraw"] {
            await repo.configureFriendActionError(.userNotFound)
            var receivedError: String?
            let handler: (String) -> Void = { receivedError = $0 }
            let succeeded: Bool
            switch action {
            case "send": succeeded = await store.sendFriendRequest(username: "unknown", onFailure: handler)
            case "respond": succeeded = await store.respond(to: requestID, response: .accept, onFailure: handler)
            default: succeeded = await store.cancelFriendRequest(id: requestID, onFailure: handler)
            }
            XCTAssertFalse(succeeded, action)
            XCTAssertEqual(receivedError, RepositoryError.userNotFound.localizedDescription, action)
            XCTAssertNil(store.notice, "A sheet-owned failure must not leave a hidden global alert")
            XCTAssertFalse(store.isSendingFriendRequest)
            XCTAssertFalse(store.isResponding(to: requestID))

            await repo.configureFriendActionError(nil)
            receivedError = nil
            let retried: Bool
            switch action {
            case "send": retried = await store.sendFriendRequest(username: "jamie", onFailure: handler)
            case "respond": retried = await store.respond(to: requestID, response: .accept, onFailure: handler)
            default: retried = await store.cancelFriendRequest(id: requestID, onFailure: handler)
            }
            XCTAssertTrue(retried, action)
            XCTAssertNil(receivedError)
            XCTAssertNil(store.notice)
        }
    }

    func testFriendActionDefaultFailureStillUsesGlobalNotice() async {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        await repo.configureFriendActionError(.userNotFound)
        let succeeded = await store.sendFriendRequest(username: "unknown")
        XCTAssertFalse(succeeded)
        XCTAssertEqual(store.notice?.message, RepositoryError.userNotFound.localizedDescription)
    }

    func testSheetOwnedFriendFailureStillClearsExpiredSession() async {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        store.pendingFriendViewID = UUID()
        await repo.configureFriendActionError(.sessionExpired)
        var receivedError: String?
        let succeeded = await store.sendFriendRequest(username: "jamie", onFailure: { receivedError = $0 })
        XCTAssertFalse(succeeded)
        XCTAssertFalse(store.snapshot.isAuthenticated)
        XCTAssertNil(store.pendingFriendViewID)
        XCTAssertEqual(receivedError, RepositoryError.sessionExpired.localizedDescription)
        XCTAssertEqual(store.notice?.message, RepositoryError.sessionExpired.localizedDescription,
            "The expired sheet disappears, so the sign-in page must explain the reset")
    }

    func testStaleSessionErrorCannotReplaceNewerSuccessWithALogoutNotice() async throws {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        let friend = try XCTUnwrap(initial.friends.first)
        var preference = initial.preference(for: friend.id)
        preference.sharesMyCity = false
        let staleWrite = Task { await store.setFriendPreference(preference) }
        await repo.waitForWrite()
        await store.setFavorite(friendID: friend.id, isFavorite: !friend.isFavorite)
        await repo.finishWrite(error: .sessionExpired)
        await staleWrite.value
        XCTAssertTrue(store.snapshot.isAuthenticated)
        XCTAssertEqual(store.friend(id: friend.id)?.isFavorite, !friend.isFavorite)
        XCTAssertNil(store.notice)
    }

    func testIncomingInviteFailureStaysLocalAndRetryClearsOnlyConfirmedInvite() async throws {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        defer { store.discardPendingInvite() }
        XCTAssertTrue(store.handleIncomingURL(SharedAppLink.make(host: "invite", path: "unknown")))
        await repo.configureFriendActionError(.userNotFound)
        var receivedError: String?
        await store.acceptPendingInvite(onFailure: { receivedError = $0 })
        XCTAssertEqual(receivedError, RepositoryError.userNotFound.localizedDescription)
        XCTAssertEqual(store.pendingInvite?.username, "unknown")
        XCTAssertNil(store.notice)
        await repo.configureFriendActionError(nil)
        receivedError = nil
        await store.acceptPendingInvite(onFailure: { receivedError = $0 })
        XCTAssertNil(receivedError)
        XCTAssertNil(store.pendingInvite)
        XCTAssertNil(PendingInviteStore.load())
    }

    func testExplicitFriendLinkClearsCompetingSheetsAndSurvivesSignIn() async throws {
        let repo = LocalDemoRepository(persistsChanges: false)
        let store = AppStore(repository: repo)
        let friendID = UUID()
        defer {
            store.discardPendingInvite()
            store.discardFriendRequestLink()
            store.discardTripInvitationLink()
        }
        for signedIn in [false, true] {
            await store.signOut()
            if signedIn { await store.signInDemo() }
            XCTAssertTrue(store.handleIncomingURL(SharedAppLink.make(host: "invite", path: "jamie")))
            store.pendingFriendRequestID = UUID()
            store.pendingTripInvitationID = UUID()
            UserDefaults.standard.set(store.pendingFriendRequestID?.uuidString, forKey: "pending-friend-request.v1")
            UserDefaults.standard.set(store.pendingTripInvitationID?.uuidString, forKey: "pending-trip-invitation.v1")
            store.pendingTripViewID = "old-trip"
            store.pendingSameCityEventID = UUID()
            store.pendingUpcomingID = String(repeating: "a", count: 32)

            XCTAssertTrue(store.handleIncomingURL(SharedAppLink.make(host: "friend", path: friendID.uuidString)))
            XCTAssertEqual(store.pendingFriendViewID, friendID)
            XCTAssertNil(store.pendingInvite)
            XCTAssertNil(PendingInviteStore.load())
            XCTAssertNil(store.pendingFriendRequestID)
            XCTAssertNil(store.pendingTripInvitationID)
            XCTAssertNil(UserDefaults.standard.string(forKey: "pending-friend-request.v1"))
            XCTAssertNil(UserDefaults.standard.string(forKey: "pending-trip-invitation.v1"))
            XCTAssertNil(store.pendingTripViewID)
            XCTAssertNil(store.pendingSameCityEventID)
            XCTAssertNil(store.pendingUpcomingID)
            if !signedIn {
                await store.signInDemo()
                XCTAssertEqual(store.pendingFriendViewID, friendID)
            }
        }
    }

    func testRefreshWaitsForFriendPrivacyWriteAndKeepsConfirmedPreference() async throws {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        let friendID = try XCTUnwrap(initial.friends.first?.id)
        var preference = initial.preference(for: friendID)
        preference.sharesMyCity = false
        let writing = Task { await store.setFriendPreference(preference) }
        await repo.waitForWrite()
        let readEntered = expectation(description: "refresh entered while write is pending")
        let reading = Task { readEntered.fulfill(); await store.refresh() }
        await fulfillment(of: [readEntered], timeout: 2)
        let prematureReads = await repo.readCount()
        XCTAssertEqual(prematureReads, 0, "A later read must wait for the privacy mutation")

        await repo.finishWrite()
        await writing.value
        await reading.value
        XCTAssertFalse(store.preference(for: friendID).sharesMyCity)
        XCTAssertFalse(store.isSavingFriendPreference(for: friendID))
        let reads = await repo.readCount()
        XCTAssertEqual(reads, 1)
    }

    func testFailedWriteReleasesWaitingRefreshAndAllowsRetry() async throws {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        let friendID = try XCTUnwrap(initial.friends.first?.id)
        var preference = initial.preference(for: friendID)
        preference.sharesMyCity = false
        let writing = Task { await store.setFriendPreference(preference) }
        await repo.waitForWrite()
        let readEntered = expectation(description: "waiting refresh entered")
        let reading = Task { readEntered.fulfill(); await store.refresh() }
        await fulfillment(of: [readEntered], timeout: 2)
        await repo.finishWrite(error: .networkUnavailable)
        await writing.value
        await reading.value
        XCTAssertTrue(store.preference(for: friendID).sharesMyCity)
        XCTAssertFalse(store.isWorking)
        let reads = await repo.readCount()
        XCTAssertEqual(reads, 1)
        let retry = Task { await store.setFriendPreference(preference) }
        await repo.waitForWrite()
        await repo.finishWrite()
        await retry.value
        XCTAssertFalse(store.preference(for: friendID).sharesMyCity)
    }

    func testSignOutInvalidatesRefreshWaitingBehindOldAccountWrite() async throws {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        let friendID = try XCTUnwrap(initial.friends.first?.id)
        var preference = initial.preference(for: friendID)
        preference.sharesMyCity = false
        let writing = Task { await store.setFriendPreference(preference) }
        await repo.waitForWrite()
        let readEntered = expectation(description: "waiting refresh entered")
        let reading = Task { readEntered.fulfill(); await store.refresh() }
        await fulfillment(of: [readEntered], timeout: 2)
        await store.signOut()
        await repo.finishWrite()
        await writing.value
        await reading.value
        XCTAssertFalse(store.snapshot.isAuthenticated)
        let reads = await repo.readCount()
        XCTAssertEqual(reads, 0)
    }

    func testOverlappingIndependentWritesReconcileOnceAfterAllConfirmations() async throws {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        let first = try XCTUnwrap(initial.friends.first)
        let second = try XCTUnwrap(initial.friends.dropFirst().first)
        var preference = initial.preference(for: first.id)
        preference.sharesMyCity = false
        let slowWrite = Task { await store.setFriendPreference(preference) }
        await repo.waitForWrite()
        await store.setFavorite(friendID: first.id, isFavorite: !first.isFavorite)
        await store.setFavorite(friendID: second.id, isFavorite: !second.isFavorite)
        let duringWrites = await repo.readCount()
        XCTAssertEqual(duringWrites, 0)
        await repo.finishWrite()
        await slowWrite.value

        XCTAssertFalse(store.preference(for: first.id).sharesMyCity)
        XCTAssertEqual(store.friend(id: first.id)?.isFavorite, !first.isFavorite)
        XCTAssertEqual(store.friend(id: second.id)?.isFavorite, !second.isFavorite)
        let afterWrites = await repo.readCount()
        XCTAssertEqual(afterWrites, 1, "One settled group should cause one reconciliation read")
    }

    func testReconciliationDoesNotReuseReadStartedBeforeOverlappingWrites() async throws {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        let first = try XCTUnwrap(initial.friends.first)
        await repo.holdNextSnapshotRead()
        let oldRead = Task { await store.refresh() }
        await repo.waitForHeldRead()
        var preference = initial.preference(for: first.id)
        preference.sharesMyCity = false
        let slowWrite = Task { await store.setFriendPreference(preference) }
        await repo.waitForWrite()
        await store.setFavorite(friendID: first.id, isFavorite: !first.isFavorite)
        await repo.finishWrite()
        await slowWrite.value
        XCTAssertFalse(store.preference(for: first.id).sharesMyCity)
        let afterWrites = await repo.readCount()
        XCTAssertEqual(afterWrites, 2, "The old read cannot satisfy post-write reconciliation")

        await repo.finishHeldRead()
        await oldRead.value
        XCTAssertFalse(store.preference(for: first.id).sharesMyCity)
        XCTAssertEqual(store.friend(id: first.id)?.isFavorite, !first.isFavorite)
    }

    func testSequentialWritesDoNotAddUnnecessaryReconciliationReads() async throws {
        let repo = CoreAuditGatedRepository()
        let initial = await repo.currentSnapshot()
        SharedAppStateStore.save(initial, origin: repo.storageScope)
        let store = AppStore(repository: repo)
        let first = try XCTUnwrap(initial.friends.first)
        var preference = initial.preference(for: first.id)
        preference.sharesMyCity = false
        let write = Task { await store.setFriendPreference(preference) }
        await repo.waitForWrite()
        await repo.finishWrite()
        await write.value
        await store.setFavorite(friendID: first.id, isFavorite: !first.isFavorite)
        let reads = await repo.readCount()
        XCTAssertEqual(reads, 0)
        XCTAssertFalse(store.preference(for: first.id).sharesMyCity)
        XCTAssertEqual(store.friend(id: first.id)?.isFavorite, !first.isFavorite)
    }
}

private actor CoreAuditGatedRepository: AppRepository {
    nonisolated let mode: RepositoryMode = .localDemo
    nonisolated let storageScope = "test:core-audit-\(UUID())"
    private var snapshot = DemoData.initialSnapshot()
    private var reads = 0
    private var writeStarted = false
    private var writeWaiters: [CheckedContinuation<Void, Never>] = []
    private var writeGate: CheckedContinuation<Void, Never>?
    private var writeError: RepositoryError?
    private var generation = 0
    private var shouldHoldNextRead = false
    private var readGate: CheckedContinuation<Void, Never>?
    private var readWaiter: CheckedContinuation<Void, Never>?
    private var friendActionError: RepositoryError?

    func currentSnapshot() -> AppSnapshot { snapshot }
    func configureFriendActionError(_ error: RepositoryError?) { friendActionError = error }
    func readCount() -> Int { reads }
    func waitForWrite() async {
        if writeStarted { return }
        await withCheckedContinuation { writeWaiters.append($0) }
    }
    func finishWrite(error: RepositoryError? = nil) {
        writeError = error
        writeStarted = false
        writeGate?.resume()
        writeGate = nil
    }
    func holdNextSnapshotRead() { shouldHoldNextRead = true }
    func waitForHeldRead() async {
        if readGate != nil { return }
        await withCheckedContinuation { readWaiter = $0 }
    }
    func finishHeldRead() { readGate?.resume(); readGate = nil }
    func loadSnapshot() async throws -> AppSnapshot {
        reads += 1
        let captured = snapshot
        if shouldHoldNextRead {
            shouldHoldNextRead = false
            await withCheckedContinuation { continuation in
                readGate = continuation
                readWaiter?.resume(); readWaiter = nil
            }
        }
        return captured
    }
    func setFriendPreference(_ preference: FriendAccessPreference) async throws -> AppSnapshot {
        let ticket = generation
        writeStarted = true
        await withCheckedContinuation { continuation in
            writeGate = continuation
            let waiters = writeWaiters
            writeWaiters.removeAll()
            for waiter in waiters { waiter.resume() }
        }
        guard generation == ticket else { throw CancellationError() }
        if let writeError { throw writeError }
        snapshot.friendPreferences.removeAll { $0.friendID == preference.friendID }
        snapshot.friendPreferences.append(preference)
        return snapshot
    }
    func signOut() async throws -> AppSnapshot { generation += 1; snapshot = DemoData.signedOutSnapshot(); return snapshot }
    func signInDemo() async throws -> AppSnapshot { snapshot }
    func signInWithApple(_ payload: AppleSignInPayload) async throws -> AppSnapshot { snapshot }
    func deleteAccount() async throws -> AppSnapshot { try await signOut() }
    func updateProfile(_ update: ProfileUpdate) async throws -> AppSnapshot { snapshot }
    func sendFriendRequest(username: String) async throws -> AppSnapshot {
        if let friendActionError { throw friendActionError }
        return snapshot
    }
    func respond(to requestID: UUID, response: FriendRequestResponse) async throws -> AppSnapshot {
        if let friendActionError { throw friendActionError }
        return snapshot
    }
    func cancelFriendRequest(id: UUID) async throws -> AppSnapshot {
        if let friendActionError { throw friendActionError }
        return snapshot
    }
    func removeFriend(id: UUID) async throws -> AppSnapshot { snapshot }
    func blockUser(id: UUID) async throws -> AppSnapshot { snapshot }
    func unblockUser(id: UUID) async throws -> AppSnapshot { snapshot }
    func setFavorite(friendID: UUID, isFavorite: Bool) async throws -> AppSnapshot {
        if let index = snapshot.friends.firstIndex(where: { $0.id == friendID }) {
            snapshot.friends[index].isFavorite = isFavorite
        }
        return snapshot
    }
    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot { snapshot }
    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource, observedAt: Date, administrativeArea: String?) async throws -> AppSnapshot { snapshot }
    func registerPushToken(_ token: String) async throws {}
    func retryPendingOperations() async throws -> AppSnapshot { snapshot }
    func pendingOperationCount() async -> Int { 0 }
    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot { snapshot }
    func fetchTravelPlans() async throws -> TravelPlanSnapshot { TravelPlanSnapshot() }
}

private actor CoreAuditAuthentication: RemoteAuthenticationProviding {
    private var signedOut = false
    func accessToken() async throws -> String {
        guard !signedOut else { throw RepositoryError.sessionExpired }
        return "test-token"
    }
    func signInWithApple(_ payload: AppleSignInPayload) async throws -> String { "test-token" }
    func refreshAccessToken() async throws -> String { throw RepositoryError.sessionExpired }
    func signOut() async throws { signedOut = true }
}

private final class CoreAuditURLProtocol: URLProtocol {
    enum Outcome { case response(Int, Data), failure(Error) }
    private static let lock = NSLock()
    private static var handler: ((URLRequest) -> Outcome)?
    static func setHandler(_ newHandler: ((URLRequest) -> Outcome)?) { lock.withLock { handler = newHandler } }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = Self.lock.withLock({ Self.handler }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        switch handler(request) {
        case .response(let status, let data):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error): client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
