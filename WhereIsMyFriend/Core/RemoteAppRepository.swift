import Foundation
import Security

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
            url.scheme?.lowercased() == "https",
            let host = url.host?.lowercased(),
            !host.isEmpty,
            !host.hasSuffix(".invalid")
        else { return nil }
        return APIConfiguration(baseURL: url)
    }

    static func fromBundle(bundle: Bundle = .main) -> APIConfiguration? {
        guard let rawValue = bundle.object(forInfoDictionaryKey: "WIFAPIBaseURL") as? String else {
            return nil
        }
        return validated(rawValue: rawValue)
    }
}

private struct EmptyBody: Encodable {}
private struct UsernameBody: Encodable { let username: String }
private struct RequestResponseBody: Encodable { let response: FriendRequestResponse }
private struct FavoriteBody: Encodable { let isFavorite: Bool }
private struct CityBody: Encodable {
    let city: String
    let countryCode: String?
    let source: PresenceSource
    let clientUpdatedAt: Date
}
private struct PushTokenBody: Encodable { let token: String; let platform = "ios" }
private struct AuthenticationEnvelope: Decodable { let accessToken: String; let snapshot: AppSnapshot }

actor RemoteAppRepository: AppRepository {
    nonisolated let mode: RepositoryMode = .remote
    nonisolated let storageScope: String

    private let client: RESTClient
    private let tokenStore: any SessionTokenStoring
    private let mutationQueue: OfflineMutationQueue

    init(
        configuration: APIConfiguration,
        mutationQueue: OfflineMutationQueue? = nil,
        session: URLSession = .shared,
        tokenStore: (any SessionTokenStoring)? = nil
    ) {
        storageScope = "remote:\(configuration.originKey)"
        client = RESTClient(baseURL: configuration.baseURL, session: session)
        self.mutationQueue = mutationQueue ?? OfflineMutationQueue(
            storageKey: "remote-mutation-queue.v2.\(configuration.originKey)"
        )
        self.tokenStore = tokenStore ?? KeychainSessionTokenStore(
            service: "com.yangwy30.whereismyfriend.session.\(configuration.originKey)"
        )
    }

    func loadSnapshot() async throws -> AppSnapshot {
        do {
            try await flushPendingOperations()
            return try await requestSnapshot(path: "/v1/bootstrap", method: "GET", body: Optional<EmptyBody>.none)
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
        let envelope: AuthenticationEnvelope = try await client.request(
            path: "/v1/auth/apple",
            method: "POST",
            body: payload,
            bearerToken: nil
        )
        let previousUserID = cachedSnapshot()?.currentUser.id
        if previousUserID != envelope.snapshot.currentUser.id {
            await mutationQueue.reset()
        }
        tokenStore.save(envelope.accessToken)
        return envelope.snapshot
    }

    func signOut() async throws -> AppSnapshot {
        let ownerID = cachedSnapshot()?.currentUser.id
        let result: AppSnapshot
        do {
            result = try await requestSnapshot(path: "/v1/auth/logout", method: "POST", body: EmptyBody())
        } catch {
            result = DemoData.signedOutSnapshot()
        }
        tokenStore.clear()
        await mutationQueue.reset(ownerID: ownerID)
        return result
    }

    func deleteAccount() async throws -> AppSnapshot {
        let ownerID = try activeUserID()
        let snapshot = try await requestSnapshot(path: "/v1/account", method: "DELETE", body: EmptyBody())
        tokenStore.clear()
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
            let _: EmptyResponse = try await client.request(
                path: "/v1/devices/push-token",
                method: "PUT",
                body: PushTokenBody(token: pushToken),
                bearerToken: try token()
            )
        } catch RepositoryError.sessionExpired {
            tokenStore.clear()
            throw RepositoryError.sessionExpired
        } catch where isRetryable(error) {
            await mutationQueue.enqueue(.pushToken(pushToken), ownerID: try activeUserID())
        }
    }

    func retryPendingOperations() async throws -> AppSnapshot {
        try await flushPendingOperations(force: true)
        return try await requestSnapshot(path: "/v1/bootstrap", method: "GET", body: Optional<EmptyBody>.none)
    }

    func pendingOperationCount() async -> Int {
        guard let ownerID = try? activeUserID() else { return 0 }
        return await mutationQueue.count(ownerID: ownerID)
    }

    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot {
        throw RepositoryError.unsupportedInCurrentMode
    }

    private func token() throws -> String {
        guard let token = tokenStore.load() else { throw RepositoryError.notAuthenticated }
        return token
    }

    private func requestSnapshot<Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> AppSnapshot {
        do {
            return try await client.request(path: path, method: method, body: body, bearerToken: try token())
        } catch RepositoryError.sessionExpired {
            tokenStore.clear()
            throw RepositoryError.sessionExpired
        }
    }

    private func flushPendingOperations(force: Bool = false) async throws {
        guard tokenStore.load() != nil, let ownerID = try? activeUserID() else { return }
        let pending = force
            ? await mutationQueue.all(ownerID: ownerID)
            : await mutationQueue.due(ownerID: ownerID)
        var terminalError: Error?
        for mutation in pending {
            do {
                switch mutation.payload {
                case .presence(let upload):
                    let _: AppSnapshot = try await client.request(
                        path: "/v1/presence/current",
                        method: "PUT",
                        body: CityBody(
                            city: upload.city,
                            countryCode: upload.countryCode,
                            source: upload.source,
                            clientUpdatedAt: upload.clientUpdatedAt
                        ),
                        bearerToken: try token()
                    )
                case .pushToken(let pushToken):
                    let _: EmptyResponse = try await client.request(
                        path: "/v1/devices/push-token",
                        method: "PUT",
                        body: PushTokenBody(token: pushToken),
                        bearerToken: try token()
                    )
                case .sharingPreferences(let preferences):
                    let _: AppSnapshot = try await client.request(
                        path: "/v1/sharing",
                        method: "PATCH",
                        body: preferences,
                        bearerToken: try token()
                    )
                }
                await mutationQueue.remove(id: mutation.id)
            } catch RepositoryError.sessionExpired {
                tokenStore.clear()
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
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
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
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw RepositoryError.serverNotConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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

protocol SessionTokenStoring: Sendable {
    func save(_ token: String)
    func load() -> String?
    func clear()
}

private final class KeychainSessionTokenStore: SessionTokenStoring, @unchecked Sendable {
    private let service: String
    private let account = "access-token"

    init(service: String) {
        self.service = service
    }

    func save(_ token: String) {
        clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
