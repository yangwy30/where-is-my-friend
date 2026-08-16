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
        return APNsRegistrationConfiguration(environment: environment, installationID: installationID)
    }
}

private struct EmptyBody: Encodable {}
private struct BootstrapBody: Encodable { let displayName: String? }
private struct UsernameBody: Encodable { let username: String }
private struct RequestResponseBody: Encodable { let response: FriendRequestResponse }
private struct FavoriteBody: Encodable { let isFavorite: Bool }
private struct CityBody: Encodable {
    let city: String
    let countryCode: String?
    let source: PresenceSource
    let clientUpdatedAt: Date
}
private struct PushTokenBody: Encodable {
    let token: String
    let environment: APNsEnvironment
    let installationID: UUID
    let platform = "ios"
}
private struct PushTokenRemovalBody: Encodable {
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
            throw RepositoryError.notAuthenticated
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
        try await client.auth.refreshSession().accessToken
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
        do {
            try await flushPendingOperations()
            return try await requestSnapshot(
                path: "/v1/auth/bootstrap",
                method: "POST",
                body: BootstrapBody(displayName: nil)
            )
        } catch where isRetryable(error) {
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
        _ = try await authentication.signInWithApple(payload)
        let snapshot: AppSnapshot = try await authorizedRequest(
            path: "/v1/auth/bootstrap",
            method: "POST",
            body: BootstrapBody(displayName: payload.displayName)
        )
        let previousUserID = cachedSnapshot()?.currentUser.id
        if previousUserID != snapshot.currentUser.id {
            await mutationQueue.reset()
        }
        return snapshot
    }

    func signOut() async throws -> AppSnapshot {
        let ownerID = cachedSnapshot()?.currentUser.id
        try? await unregisterPushDevice()
        let result: AppSnapshot
        do {
            result = try await requestSnapshot(path: "/v1/auth/logout", method: "POST", body: EmptyBody())
        } catch {
            result = DemoData.signedOutSnapshot()
        }
        try? await authentication.signOut()
        await mutationQueue.reset(ownerID: ownerID)
        return result
    }

    func deleteAccount() async throws -> AppSnapshot {
        let ownerID = try activeUserID()
        let snapshot = try await requestSnapshot(path: "/v1/account", method: "DELETE", body: EmptyBody())
        // Supabase Auth deletes its local session before contacting the server.
        // The server identity has already been removed, so a 401/404 is expected
        // and handled by the SDK during this cleanup call.
        try await authentication.signOut()
        await mutationQueue.reset(ownerID: ownerID)
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
        do {
            return try await requestSnapshot(path: "/v1/sharing", method: "PATCH", body: preferences)
        } catch where isRetryable(error) {
            let ownerID = try activeUserID()
            await mutationQueue.enqueue(.sharingPreferences(preferences), ownerID: ownerID)
            var cached = try authenticatedCachedSnapshot()
            cached.sharingPreferences = preferences
            if !preferences.citySharingEnabled {
                ColocationEvaluator.evaluate(snapshot: &cached)
            }
            cached.syncState = .offline
            return cached
        }
    }

    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource) async throws -> AppSnapshot {
        let upload = PendingPresenceUpload(
            city: CityIdentity.canonicalCity(city),
            countryCode: countryCode?.uppercased(),
            source: source,
            clientUpdatedAt: Date()
        )
        do {
            return try await requestSnapshot(
                path: "/v1/presence/current",
                method: "PUT",
                body: CityBody(
                    city: upload.city,
                    countryCode: upload.countryCode,
                    source: upload.source,
                    clientUpdatedAt: upload.clientUpdatedAt
                )
            )
        } catch where isRetryable(error) {
            let ownerID = try activeUserID()
            await mutationQueue.enqueue(.presence(upload), ownerID: ownerID)
            var cached = try authenticatedCachedSnapshot()
            cached.currentPresence = CurrentUserPresence(
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
        do {
            let _: EmptyResponse = try await authorizedRequest(
                path: "/v1/devices/push-token",
                method: "PUT",
                body: PushTokenBody(
                    token: pushToken,
                    environment: pushConfiguration.environment,
                    installationID: pushConfiguration.installationID
                )
            )
        } catch where isRetryable(error) {
            await mutationQueue.enqueue(.pushToken(pushToken), ownerID: try activeUserID())
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

    private func requestSnapshot<Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> AppSnapshot {
        try await authorizedRequest(path: path, method: method, body: body)
    }

    private func authorizedRequest<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        let token = try await authentication.accessToken()
        do {
            return try await client.request(path: path, method: method, body: body, bearerToken: token)
        } catch RepositoryError.sessionExpired {
            do {
                let refreshedToken = try await authentication.refreshAccessToken()
                return try await client.request(
                    path: path,
                    method: method,
                    body: body,
                    bearerToken: refreshedToken
                )
            } catch {
                try? await authentication.signOut()
                throw RepositoryError.sessionExpired
            }
        }
    }

    private func flushPendingOperations(force: Bool = false) async throws {
        guard (try? await authentication.accessToken()) != nil,
              let ownerID = try? activeUserID() else { return }
        let pending = force
            ? await mutationQueue.all(ownerID: ownerID)
            : await mutationQueue.due(ownerID: ownerID)
        var terminalError: Error?
        for mutation in pending {
            do {
                switch mutation.payload {
                case .presence(let upload):
                    let _: AppSnapshot = try await authorizedRequest(
                        path: "/v1/presence/current",
                        method: "PUT",
                        body: CityBody(
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
                environment: pushConfiguration.environment,
                installationID: pushConfiguration.installationID
            )
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
            if http.statusCode == 401 || http.statusCode == 403 {
                throw RepositoryError.sessionExpired
            }
            if http.statusCode == 408 || http.statusCode == 429 || (500..<600).contains(http.statusCode) {
                throw RepositoryError.serverTemporarilyUnavailable
            }
            let message = (try? decoder.decode(ServerErrorEnvelope.self, from: data).message)
                ?? "Server request failed (\(http.statusCode))."
            throw RepositoryError.message(message)
        }
        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }
        return try decoder.decode(Response.self, from: data)
    }
}

private struct ServerErrorEnvelope: Decodable { let message: String }
