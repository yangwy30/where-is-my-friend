import Foundation
import Supabase

struct APIConfiguration: Equatable, Sendable {
    let baseURL: URL

    var originKey: String {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        return components?.url?.absoluteString.lowercased() ?? baseURL.absoluteString.lowercased()
    }

    static func validated(rawValue: String) -> APIConfiguration? {
        guard
            let url = URL(string: rawValue),
            let scheme = url.scheme?.lowercased(),
            let host = url.host?.lowercased(),
            !host.isEmpty,
            !host.hasSuffix(".invalid")
        else { return nil }

        let isSecure = scheme == "https"
        #if DEBUG
        let isLocalDevelopment = scheme == "http"
            && ["localhost", "127.0.0.1", "::1"].contains(host)
        #else
        let isLocalDevelopment = false
        #endif
        guard isSecure || isLocalDevelopment else { return nil }
        return APIConfiguration(baseURL: url)
    }

    func endpoint(path: String) -> URL? {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let route = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !route.isEmpty else { return baseURL }
        return URL(string: "\(base)/\(route)")
    }

    static func fromBundle(bundle: Bundle = .main) -> APIConfiguration? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: "WIFAPIBaseURL") as? String else {
            return nil
        }
        return validated(rawValue: rawValue)
    }
}

struct SupabaseConfiguration: Equatable, Sendable {
    let projectURL: URL
    let publishableKey: String

    static func validated(projectURL rawURL: String, publishableKey rawKey: String) -> SupabaseConfiguration? {
        guard
            let url = URL(string: rawURL),
            url.scheme?.lowercased() == "https",
            let host = url.host,
            !host.isEmpty,
            !host.hasSuffix(".invalid")
        else { return nil }

        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.hasPrefix("sb_secret_") else { return nil }
        return SupabaseConfiguration(projectURL: url, publishableKey: key)
    }

    static func fromBundle(bundle: Bundle = .main) -> SupabaseConfiguration? {
        guard
            let rawURL = bundle.object(forInfoDictionaryKey: "WIFSupabaseURL") as? String,
            let rawKey = bundle.object(forInfoDictionaryKey: "WIFSupabasePublishableKey") as? String
        else { return nil }
        return validated(projectURL: rawURL, publishableKey: rawKey)
    }
}

enum APNsEnvironment: String, Codable, Sendable {
    case sandbox
    case production
}

struct APNsRegistrationConfiguration: Equatable, Sendable {
    let environment: APNsEnvironment
    let installationID: UUID
    var bundleID: String = "com.yangwy30.whereismyfriend"

    static func fromBundle(
        bundle: Bundle = .main,
        defaults: UserDefaults = UserDefaults(suiteName: SharedPresenceStore.appGroupIdentifier) ?? .standard
    ) -> APNsRegistrationConfiguration {
        let rawEnvironment = (bundle.object(forInfoDictionaryKey: "WIFAPSEnvironment") as? String)?.lowercased()
        let environment: APNsEnvironment = rawEnvironment == "production" ? .production : .sandbox
        let storageKey = "apns-installation-id.v1.\(environment.rawValue)"
        let installationID: UUID
        if let stored = defaults.string(forKey: storageKey), let existing = UUID(uuidString: stored) {
            installationID = existing
        } else {
            installationID = UUID()
            defaults.set(installationID.uuidString.lowercased(), forKey: storageKey)
        }
        return APNsRegistrationConfiguration(environment: environment, installationID: installationID,
                                             bundleID: bundle.bundleIdentifier ?? "com.yangwy30.whereismyfriend")
    }
}

private struct EmptyBody: Encodable {}
private struct BootstrapBody: Encodable { let displayName: String? }
private struct UsernameBody: Encodable { let username: String }
private struct RequestResponseBody: Encodable { let response: FriendRequestResponse }
private struct FavoriteBody: Encodable { let isFavorite: Bool }
private struct CityBody: Encodable {
    var administrativeArea: String? = nil
    let city: String
    let countryCode: String?
    let source: PresenceSource
    let clientUpdatedAt: Date
}
private struct PushTokenBody: Encodable {
    let token: String
    var bundleID: String = "com.yangwy30.whereismyfriend"
    let environment: APNsEnvironment
    let installationID: UUID
    let platform = "ios"
}
private struct PushTokenRemovalBody: Encodable {
    var bundleID: String = "com.yangwy30.whereismyfriend"
    let environment: APNsEnvironment
    let installationID: UUID
    let platform = "ios"
}

protocol RemoteAuthenticationProviding: Sendable {
    func accessToken() async throws -> String
    func signInWithApple(_ payload: AppleSignInPayload) async throws -> String
    func refreshAccessToken() async throws -> String
    func signOut() async throws
}

private actor SupabaseRemoteAuthentication: RemoteAuthenticationProviding {
    private let client: SupabaseClient

    init(configuration: SupabaseConfiguration, session: URLSession) {
        let options = SupabaseClientOptions(
            auth: .init(
                storageKey: "wif-\(configuration.projectURL.host ?? "supabase")-auth",
                autoRefreshToken: true
            ),
            global: .init(session: session)
        )
        client = SupabaseClient(
            supabaseURL: configuration.projectURL,
            supabaseKey: configuration.publishableKey,
            options: options
        )
    }

    func accessToken() async throws -> String {
        do {
            return try await client.auth.session.accessToken
        } catch {
            throw Self.sessionError(error)
        }
    }

    func signInWithApple(_ payload: AppleSignInPayload) async throws -> String {
        let session = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: payload.identityToken,
                nonce: payload.nonce
            )
        )
        if let displayName = payload.displayName {
            _ = try? await client.auth.update(
                user: UserAttributes(data: ["full_name": .string(displayName)])
            )
        }
        return session.accessToken
    }

    func refreshAccessToken() async throws -> String {
        do { return try await client.auth.refreshSession().accessToken }
        catch { throw Self.sessionError(error) }
    }

    private static func sessionError(_ error: Error) -> Error {
        if let auth = error as? AuthError,
           [.sessionNotFound, .refreshTokenNotFound, .refreshTokenAlreadyUsed, .userNotFound, .badJWT].contains(auth.errorCode) {
            return RepositoryError.sessionExpired
        }
        if let network = error as? URLError, network.code != .cancelled { return RepositoryError.networkUnavailable }
        return error
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}

actor RemoteAppRepository: AppRepository {
    nonisolated let mode: RepositoryMode = .remote
    nonisolated let storageScope: String

    private let client: RESTClient
    private let authentication: any RemoteAuthenticationProviding
    private let mutationQueue: OfflineMutationQueue
    private let pushConfiguration: APNsRegistrationConfiguration

    private var sessionGeneration = 0
    private var authenticationTransition = false
    private var sessionIsUsable = true
    private var sessionOwnerID: UUID?
    private var mutationLocked = false
    private var mutationWaiters: [CheckedContinuation<Void, Never>] = []

    private struct RequestContext {
        let generation: Int
        let ownerID: UUID?
        let isAuthentication: Bool
    }

    private func requestContext(authentication allowed: Bool = false) throws -> RequestContext {
        guard allowed || (!authenticationTransition && sessionIsUsable) else { throw CancellationError() }
        let owner = cachedSnapshot().flatMap { $0.isAuthenticated ? $0.currentUser.id : nil }
        if !allowed, let sessionOwnerID, sessionOwnerID != owner { throw CancellationError() }
        return RequestContext(generation: sessionGeneration, ownerID: owner, isAuthentication: allowed)
    }

    private func check(_ context: RequestContext) throws {
        try Task.checkCancellation()
        guard context.generation == sessionGeneration else { throw CancellationError() }
        if !context.isAuthentication {
            guard !authenticationTransition,
                  context.ownerID == cachedSnapshot().flatMap({ $0.isAuthenticated ? $0.currentUser.id : nil }),
                  sessionOwnerID == nil || sessionOwnerID == context.ownerID else { throw CancellationError() }
        }
    }

    private func lockMutations() async {
        if mutationLocked {
            await withCheckedContinuation { mutationWaiters.append($0) }
        } else { mutationLocked = true }
    }

    private func unlockMutations() {
        if mutationWaiters.isEmpty { mutationLocked = false }
        else { mutationWaiters.removeFirst().resume() }
    }

    private func queue(_ payload: PendingRemoteMutationPayload, context: RequestContext) async throws {
        try check(context)
        guard let owner = context.ownerID else { throw RepositoryError.notAuthenticated }
        let id = await mutationQueue.enqueue(payload, ownerID: owner)
        do { try check(context) }
        catch { await mutationQueue.remove(id: id); throw error }
    }

    init(
        configuration: APIConfiguration,
        supabaseConfiguration: SupabaseConfiguration,
        mutationQueue: OfflineMutationQueue? = nil,
        session: URLSession = .shared,
        authentication: (any RemoteAuthenticationProviding)? = nil,
        pushConfiguration: APNsRegistrationConfiguration = .fromBundle()
    ) {
        storageScope = "remote:\(configuration.originKey)"
        client = RESTClient(
            baseURL: configuration.baseURL,
            publishableKey: supabaseConfiguration.publishableKey,
            session: session
        )
        self.mutationQueue = mutationQueue ?? OfflineMutationQueue(
            storageKey: "remote-mutation-queue.v2.\(configuration.originKey)"
        )
        self.authentication = authentication ?? SupabaseRemoteAuthentication(
            configuration: supabaseConfiguration,
            session: session
        )
        self.pushConfiguration = pushConfiguration
    }

    func loadSnapshot() async throws -> AppSnapshot {
        let context = try requestContext()
        do {
            try await flushPendingOperations()
            return try await requestSnapshot(
                path: "/v1/auth/bootstrap",
                method: "POST",
                body: BootstrapBody(displayName: nil)
            )
        } catch where isRetryable(error) {
            try check(context)
            guard var cached = SharedAppStateStore.load(expectedOrigin: storageScope),
                  cached.isAuthenticated else { throw error }
            cached.syncState = .offline
            return cached
        }
    }

    func signInDemo() async throws -> AppSnapshot {
        throw RepositoryError.unsupportedInCurrentMode
    }

    func signInWithApple(_ payload: AppleSignInPayload) async throws -> AppSnapshot {
        guard !authenticationTransition else { throw CancellationError() }
        sessionGeneration += 1
        authenticationTransition = true
        sessionIsUsable = false
        defer { authenticationTransition = false }
        do {
            _ = try await authentication.signInWithApple(payload)
            let snapshot: AppSnapshot = try await authorizedRequest(
                path: "/v1/auth/bootstrap",
                method: "POST",
                body: BootstrapBody(displayName: payload.displayName), allowsAuthTransition: true
            )
            let previousUserID = cachedSnapshot()?.currentUser.id
            sessionOwnerID = snapshot.currentUser.id
            sessionIsUsable = true
            if previousUserID != snapshot.currentUser.id {
                await mutationQueue.reset()
            }
            return snapshot
        } catch {
            // An Auth exchange that succeeded without an application bootstrap
            // must not leave a new token paired with an old account cache.
            try? await authentication.signOut()
            sessionOwnerID = nil
            sessionIsUsable = false
            SharedAppStateStore.reset()
            throw error
        }
    }

    func signOut() async throws -> AppSnapshot {
        guard !authenticationTransition else { throw CancellationError() }
        sessionGeneration += 1
        authenticationTransition = true
        sessionIsUsable = false
        defer { authenticationTransition = false }
        let ownerID = cachedSnapshot()?.currentUser.id
        try? await unregisterPushDevice()
        let result: AppSnapshot
        do {
            result = try await requestSnapshot(path: "/v1/auth/logout", method: "POST", body: EmptyBody(), allowsAuthTransition: true)
        } catch {
            result = DemoData.signedOutSnapshot()
        }
        try? await authentication.signOut()
        await mutationQueue.reset(ownerID: ownerID)
        if let ownerID { AccountLocalData.clear(origin: storageScope, ownerID: ownerID) }
        sessionOwnerID = nil
        return result
    }

    func deleteAccount() async throws -> AppSnapshot {
        guard !authenticationTransition else { throw CancellationError() }
        let ownerID = try activeUserID()
        sessionGeneration += 1
        authenticationTransition = true
        defer { authenticationTransition = false }
        let snapshot = try await requestSnapshot(path: "/v1/account", method: "DELETE", body: EmptyBody(), allowsAuthTransition: true)
        // Supabase Auth deletes its local session before contacting the server.
        // The server identity has already been removed, so a 401/404 is expected
        // and handled by the SDK during this cleanup call.
        try? await authentication.signOut()
        await mutationQueue.reset(ownerID: ownerID)
        AccountLocalData.clear(origin: storageScope, ownerID: ownerID)
        sessionOwnerID = nil
        sessionIsUsable = false
        return snapshot
    }

    func updateProfile(_ update: ProfileUpdate) async throws -> AppSnapshot {
        try await requestSnapshot(path: "/v1/profile", method: "PATCH", body: try update.validated())
    }

    func sendFriendRequest(username: String) async throws -> AppSnapshot {
        try await requestSnapshot(
            path: "/v1/friends/requests",
            method: "POST",
            body: UsernameBody(username: username)
        )
    }

    func respond(to requestID: UUID, response: FriendRequestResponse) async throws -> AppSnapshot {
        try await requestSnapshot(
            path: "/v1/friends/requests/\(requestID.uuidString)",
            method: "PATCH",
            body: RequestResponseBody(response: response)
        )
    }

    func removeFriend(id: UUID) async throws -> AppSnapshot {
        try await requestSnapshot(
            path: "/v1/friends/\(id.uuidString)",
            method: "DELETE",
            body: EmptyBody()
        )
    }

    func blockUser(id: UUID) async throws -> AppSnapshot {
        try await requestSnapshot(
            path: "/v1/users/\(id.uuidString)/block",
            method: "PUT",
            body: EmptyBody()
        )
    }

    func unblockUser(id: UUID) async throws -> AppSnapshot {
        try await requestSnapshot(
            path: "/v1/users/\(id.uuidString)/block",
            method: "DELETE",
            body: EmptyBody()
        )
    }

    func setFavorite(friendID: UUID, isFavorite: Bool) async throws -> AppSnapshot {
        try await requestSnapshot(
            path: "/v1/friends/\(friendID.uuidString)/favorite",
            method: "PATCH",
            body: FavoriteBody(isFavorite: isFavorite)
        )
    }

    func setFriendPreference(_ preference: FriendAccessPreference) async throws -> AppSnapshot {
        try await requestSnapshot(
            path: "/v1/friends/\(preference.friendID.uuidString)/preferences",
            method: "PATCH",
            body: preference
        )
    }

    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot {
        let context = try requestContext()
        guard let owner = context.ownerID else { throw RepositoryError.notAuthenticated }
        await lockMutations()
        defer { unlockMutations() }
        try check(context)
        // Retire old intent before trying the new one, regardless of connectivity.
        await mutationQueue.removeSuperseded(ownerID: owner, key: "sharing-preferences")
        try check(context)
        do {
            return try await requestSnapshot(path: "/v1/sharing", method: "PATCH", body: preferences)
        } catch where isRetryable(error) {
            try await queue(.sharingPreferences(preferences), context: context)
            try check(context)
            var cached = try authenticatedCachedSnapshot()
            cached.sharingPreferences = preferences
            if !preferences.citySharingEnabled {
                ColocationEvaluator.evaluate(snapshot: &cached)
            }
            cached.syncState = .offline
            return cached
        }
    }

    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource, observedAt: Date, administrativeArea: String? = nil) async throws -> AppSnapshot {
        let context = try requestContext()
        guard let owner = context.ownerID else { throw RepositoryError.notAuthenticated }
        await lockMutations()
        defer { unlockMutations() }
        try check(context)
        await mutationQueue.removeSuperseded(ownerID: owner, key: "presence")
        try check(context)
        let upload = PendingPresenceUpload(
            administrativeArea: administrativeArea,
            city: CityIdentity.canonicalCity(city),
            countryCode: countryCode?.uppercased(),
            source: source,
            clientUpdatedAt: observedAt
        )
        do {
            return try await requestSnapshot(
                path: "/v1/presence/current",
                method: "PUT",
                body: CityBody(
                    administrativeArea: upload.administrativeArea,
                    city: upload.city,
                    countryCode: upload.countryCode,
                    source: upload.source,
                    clientUpdatedAt: upload.clientUpdatedAt
                )
            )
        } catch where isRetryable(error) {
            try await queue(.presence(upload), context: context)
            try check(context)
            var cached = try authenticatedCachedSnapshot()
            cached.currentPresence = CurrentUserPresence(
                administrativeArea: upload.administrativeArea,
                city: upload.city,
                countryCode: upload.countryCode,
                updatedAt: upload.clientUpdatedAt,
                source: upload.source
            )
            cached.syncState = .offline
            return cached
        }
    }

    func registerPushToken(_ pushToken: String) async throws {
        let context = try requestContext()
        guard let owner = context.ownerID else { throw RepositoryError.notAuthenticated }
        await lockMutations()
        defer { unlockMutations() }
        try check(context)
        await mutationQueue.removeSuperseded(ownerID: owner, key: "push-token")
        try check(context)
        do {
            let _: EmptyResponse = try await authorizedRequest(
                path: "/v1/devices/push-token",
                method: "PUT",
                body: PushTokenBody(
                    token: pushToken,
                    bundleID: pushConfiguration.bundleID,
                    environment: pushConfiguration.environment,
                    installationID: pushConfiguration.installationID
                )
            )
        } catch where isRetryable(error) {
            try await queue(.pushToken(pushToken), context: context)
        }
    }

    func retryPendingOperations() async throws -> AppSnapshot {
        try await flushPendingOperations(force: true)
        return try await requestSnapshot(
            path: "/v1/auth/bootstrap",
            method: "POST",
            body: BootstrapBody(displayName: nil)
        )
    }

    func pendingOperationCount() async -> Int {
        guard let ownerID = try? activeUserID() else { return 0 }
        return await mutationQueue.count(ownerID: ownerID)
    }

    func isPushRegistrationPending() async -> Bool {
        guard let ownerID = try? activeUserID() else { return false }
        return await mutationQueue
            .all(ownerID: ownerID)
            .contains { $0.payload.coalescingKey == "push-token" }
    }

    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot {
        throw RepositoryError.unsupportedInCurrentMode
    }

    func lookupFlight(tripID: String, flightNumber: String, date: String) async throws -> [FlightCandidate] {
        let cleanNumber = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().replacingOccurrences(of: " ", with: "")
        let response: FlightLookupResponse = try await authorizedRequest(
            path: "/v1/trips/\(tripID)/flight-lookup",
            method: "POST",
            body: FlightLookupRequestBody(flightNumber: cleanNumber, date: date)
        )
        return response.flights
    }

    func fetchTrips() async throws -> [CloudTrip] {
        let result: TripCloudList = try await authorizedRequest(path: "/v1/trips", method: "GET", body: Optional<EmptyBody>.none)
        return result.trips
    }

    func fetchTravelPlans() async throws -> TravelPlanSnapshot {
        try await authorizedRequest(path: "/v1/travel-plans", method: "GET", body: Optional<EmptyBody>.none)
    }

    func saveTravelPlan(_ plan: PersonalTravelPlan) async throws -> TravelPlanSnapshot {
        try await authorizedRequest(path: "/v1/travel-plans/\(plan.id.uuidString)", method: "PUT", body: TravelPlanPayload(plan))
    }

    func deleteTravelPlan(id: UUID, revision: Int) async throws -> TravelPlanSnapshot {
        struct DeleteBody: Encodable { let revision: Int }
        return try await authorizedRequest(path: "/v1/travel-plans/\(id.uuidString)", method: "DELETE", body: DeleteBody(revision: revision))
    }

    func createTrip(_ payload: TripPayload) async throws -> CloudTrip {
        try await authorizedRequest(path: "/v1/trips", method: "POST", body: payload)
    }

    func mutateTrip(id: String, mutation: TripMutation) async throws -> CloudTrip {
        try await authorizedRequest(path: "/v1/trips/\(id)/mutations", method: "POST", body: mutation)
    }

    func changeTripLifecycle(id: String, payload: TripLifecyclePayload) async throws -> TripLifecycleResult {
        try await authorizedRequest(path: "/v1/trips/\(id)/lifecycle", method: "POST", body: payload)
    }

    func updateTripCollaboration(id: String, action: String, payload: TripCollaborationPayload) async throws -> CloudTrip {
        guard ["preferences", "meeting", "check-in"].contains(action) else { throw RepositoryError.unsupportedInCurrentMode }
        return try await authorizedRequest(path: "/v1/trips/\(id)/\(action)", method: "POST", body: payload)
    }

    func tripInvitations(tripID: String?) async throws -> [TripInvitation] {
        let path = tripID.map { "/v1/trips/\($0)/invitations" } ?? "/v1/trip-invitations"
        let result: TripInvitationList = try await authorizedRequest(path: path, method: "GET", body: Optional<EmptyBody>.none)
        return result.invitations
    }

    func inviteToTrip(id: String, username: String) async throws -> CreatedTripInvitation {
        try await authorizedRequest(path: "/v1/trips/\(id)/invitations", method: "POST", body: UsernameBody(username: username))
    }

    func acceptTripInvitation(id: UUID) async throws -> CloudTrip {
        try await authorizedRequest(path: "/v1/trip-invitations/\(id.uuidString)/accept", method: "POST", body: EmptyBody())
    }

    func dismissTripInvitation(id: UUID, revoke: Bool) async throws {
        let _: TripActionResult = try await authorizedRequest(
            path: "/v1/trip-invitations/\(id.uuidString)/\(revoke ? "revoke" : "decline")", method: "POST", body: EmptyBody())
    }

    private func requestSnapshot<Body: Encodable & Sendable>(
        path: String, method: String, body: Body?, allowsAuthTransition: Bool = false
    ) async throws -> AppSnapshot {
        try await authorizedRequest(path: path, method: method, body: body, allowsAuthTransition: allowsAuthTransition)
    }

    private func authorizedRequest<Response: Decodable & Sendable, Body: Encodable & Sendable>(
        path: String, method: String, body: Body?, allowsAuthTransition: Bool = false
    ) async throws -> Response {
        let context = try requestContext(authentication: allowsAuthTransition)
        let token = try await authentication.accessToken()
        try check(context)
        do {
            let response: Response = try await client.request(path: path, method: method, body: body, bearerToken: token)
            try check(context)
            return response
        } catch RepositoryError.sessionExpired {
            try check(context)
            do {
                let refreshedToken = try await authentication.refreshAccessToken()
                try check(context)
                let response: Response = try await client.request(path: path, method: method, body: body, bearerToken: refreshedToken)
                try check(context)
                return response
            } catch RepositoryError.sessionExpired {
                try check(context)
                try? await authentication.signOut()
                try check(context)
                throw RepositoryError.sessionExpired
            } catch {
                try check(context)
                throw error
            }
        } catch {
            try check(context)
            throw error
        }
    }

    private func flushPendingOperations(force: Bool = false) async throws {
        let context = try requestContext()
        guard let ownerID = context.ownerID else { return }
        await lockMutations()
        defer { unlockMutations() }
        try check(context)
        guard (try? await authentication.accessToken()) != nil else { return }
        try check(context)
        let pending = force
            ? await mutationQueue.all(ownerID: ownerID)
            : await mutationQueue.due(ownerID: ownerID)
        var terminalError: Error?
        for mutation in pending {
            try check(context)
            do {
                switch mutation.payload {
                case .presence(let upload):
                    let _: AppSnapshot = try await authorizedRequest(
                        path: "/v1/presence/current",
                        method: "PUT",
                        body: CityBody(
                            administrativeArea: upload.administrativeArea,
                            city: upload.city,
                            countryCode: upload.countryCode,
                            source: upload.source,
                            clientUpdatedAt: upload.clientUpdatedAt
                        )
                    )
                case .pushToken(let pushToken):
                    let _: EmptyResponse = try await authorizedRequest(
                        path: "/v1/devices/push-token",
                        method: "PUT",
                        body: PushTokenBody(
                            token: pushToken,
                            bundleID: pushConfiguration.bundleID,
                            environment: pushConfiguration.environment,
                            installationID: pushConfiguration.installationID
                        )
                    )
                case .sharingPreferences(let preferences):
                    let _: AppSnapshot = try await authorizedRequest(
                        path: "/v1/sharing",
                        method: "PATCH",
                        body: preferences
                    )
                }
                await mutationQueue.remove(id: mutation.id)
            } catch RepositoryError.sessionExpired {
                throw RepositoryError.sessionExpired
            } catch {
                try check(context)
                if isRetryable(error) {
                    await mutationQueue.markFailed(id: mutation.id)
                    throw error
                }
                await mutationQueue.remove(id: mutation.id)
                terminalError = terminalError ?? error
            }
        }
        if let terminalError { throw terminalError }
    }

    private func unregisterPushDevice() async throws {
        let _: EmptyResponse = try await authorizedRequest(
            path: "/v1/devices/push-token",
            method: "DELETE",
            body: PushTokenRemovalBody(
                bundleID: pushConfiguration.bundleID,
                environment: pushConfiguration.environment,
                installationID: pushConfiguration.installationID
            ), allowsAuthTransition: true
        )
    }

    private func activeUserID() throws -> UUID {
        try authenticatedCachedSnapshot().currentUser.id
    }

    private func cachedSnapshot() -> AppSnapshot? {
        SharedAppStateStore.load(expectedOrigin: storageScope)
    }

    private func authenticatedCachedSnapshot() throws -> AppSnapshot {
        guard let cached = cachedSnapshot(), cached.isAuthenticated else {
            throw RepositoryError.notAuthenticated
        }
        return cached
    }

    private func isRetryable(_ error: Error) -> Bool {
        guard let repositoryError = error as? RepositoryError else { return false }
        return repositoryError == .networkUnavailable
            || repositoryError == .serverTemporarilyUnavailable
    }
}

struct EmptyResponse: Decodable {}

actor RESTClient {
    private let baseURL: URL
    private let publishableKey: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL, publishableKey: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.publishableKey = publishableKey
        self.session = session
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?,
        bearerToken: String?
    ) async throws -> Response {
        guard let url = APIConfiguration(baseURL: baseURL).endpoint(path: path) else {
            throw RepositoryError.serverNotConfigured
        }
        var request = URLRequest(url: url)
        if path == "/v1/profile" || path == "/v1/devices/push-token" { request.timeoutInterval = 15 }
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost,
                    .cannotFindHost, .dnsLookupFailed, .internationalRoamingOff:
                throw RepositoryError.networkUnavailable
            default:
                throw error
            }
        }
        guard let http = response as? HTTPURLResponse else {
            throw RepositoryError.invalidServerResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            // Trip 403 means membership/ownership denial, not an expired Auth session.
            if http.statusCode == 401 || (http.statusCode == 403 && !path.hasPrefix("/v1/trip")) {
                throw RepositoryError.sessionExpired
            }
            if http.statusCode == 408 || http.statusCode == 429 || (500..<600).contains(http.statusCode) {
                throw RepositoryError.serverTemporarilyUnavailable
            }
            let message = (try? decoder.decode(ServerErrorEnvelope.self, from: data).message)
                ?? "Server request failed (\(http.statusCode))."
            throw RepositoryError.message(message)
        }
        if let empty = EmptyResponse() as? Response, data.isEmpty {
            return empty
        }
        return try decoder.decode(Response.self, from: data)
    }
}

private struct ServerErrorEnvelope: Decodable { let message: String }
