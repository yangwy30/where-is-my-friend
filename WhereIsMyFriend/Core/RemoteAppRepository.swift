import Foundation
import Security

struct APIConfiguration: Sendable {
    let baseURL: URL

    static func fromBundle() -> APIConfiguration? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "WIFAPIBaseURL") as? String,
            let url = URL(string: rawValue),
            url.scheme == "https",
            url.host != "api.example.invalid"
        else { return nil }
        return APIConfiguration(baseURL: url)
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

    private let client: RESTClient
    private let tokenStore = KeychainSessionTokenStore()
    private let mutationQueue: OfflineMutationQueue

    init(configuration: APIConfiguration, mutationQueue: OfflineMutationQueue = .shared) {
        client = RESTClient(baseURL: configuration.baseURL)
        self.mutationQueue = mutationQueue
    }

    func loadSnapshot() async throws -> AppSnapshot {
        do {
            try await flushPendingOperations()
            return try await requestSnapshot(path: "/v1/bootstrap", method: "GET", body: Optional<EmptyBody>.none)
        } catch where isRetryable(error) {
            guard var cached = SharedAppStateStore.load(expectedOrigin: RepositoryMode.remote.rawValue),
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
        tokenStore.save(envelope.accessToken)
        return envelope.snapshot
    }

    func signOut() async throws -> AppSnapshot {
        do {
            let snapshot = try await requestSnapshot(path: "/v1/auth/logout", method: "POST", body: EmptyBody())
            tokenStore.clear()
            await mutationQueue.reset()
            return snapshot
        } catch where isRetryable(error) {
            tokenStore.clear()
            await mutationQueue.reset()
            return DemoData.signedOutSnapshot()
        }
    }

    func deleteAccount() async throws -> AppSnapshot {
        let snapshot = try await requestSnapshot(path: "/v1/account", method: "DELETE", body: EmptyBody())
        tokenStore.clear()
        await mutationQueue.reset()
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
        try await requestSnapshot(path: "/v1/sharing", method: "PATCH", body: preferences)
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
            await mutationQueue.enqueue(.presence(upload))
            var cached = SharedAppStateStore.load(expectedOrigin: RepositoryMode.remote.rawValue)
                ?? DemoData.signedOutSnapshot()
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
        } catch where isRetryable(error) {
            await mutationQueue.enqueue(.pushToken(pushToken))
        }
    }

    func retryPendingOperations() async throws -> AppSnapshot {
        try await flushPendingOperations(force: true)
        return try await requestSnapshot(path: "/v1/bootstrap", method: "GET", body: Optional<EmptyBody>.none)
    }

    func pendingOperationCount() async -> Int { await mutationQueue.count() }

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
        try await client.request(path: path, method: method, body: body, bearerToken: try token())
    }

    private func flushPendingOperations(force: Bool = false) async throws {
        guard tokenStore.load() != nil else { return }
        let pending = force ? await mutationQueue.all() : await mutationQueue.due()
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
                }
                await mutationQueue.remove(id: mutation.id)
            } catch {
                await mutationQueue.markFailed(id: mutation.id)
                throw error
            }
        }
    }

    private func isRetryable(_ error: Error) -> Bool {
        guard let repositoryError = error as? RepositoryError else { return false }
        return repositoryError == .networkUnavailable
            || repositoryError == .serverTemporarilyUnavailable
    }
}

private struct EmptyResponse: Decodable {}

private actor RESTClient {
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

private final class KeychainSessionTokenStore: @unchecked Sendable {
    private let service = "com.yangwy30.whereismyfriend.session"
    private let account = "access-token"

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
