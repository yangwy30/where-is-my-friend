import Foundation

enum RepositoryMode: String, Sendable {
    case localDemo
    case remote
}

enum FriendRequestResponse: String, Codable, Sendable {
    case accept
    case decline
}

enum DemoScenario: String, CaseIterable, Identifiable, Sendable {
    case friendArrives
    case ageLocations
    case incomingRequest
    case restoreDefaults

    var id: String { rawValue }
}

struct AppleSignInPayload: Codable, Sendable {
    let appleUserID: String
    let identityToken: String
    let displayName: String?
}

enum RepositoryError: LocalizedError, Equatable {
    case notAuthenticated
    case userNotFound
    case alreadyFriends
    case requestAlreadyExists
    case cannotInviteYourself
    case requestNotFound
    case friendNotFound
    case alreadyBlocked
    case blockedUserNotFound
    case serverNotConfigured
    case unsupportedInCurrentMode
    case invalidServerResponse
    case networkUnavailable
    case serverTemporarilyUnavailable
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Please sign in first."
        case .userNotFound: "No demo user has that username. Try jamie, priya, leo, or emma."
        case .alreadyFriends: "You are already friends."
        case .requestAlreadyExists: "An invitation already exists."
        case .cannotInviteYourself: "You cannot invite yourself."
        case .requestNotFound: "That friend request no longer exists."
        case .friendNotFound: "That friend is no longer available."
        case .alreadyBlocked: "That person is already blocked."
        case .blockedUserNotFound: "That blocked person is no longer available."
        case .serverNotConfigured: "The production server URL has not been configured."
        case .unsupportedInCurrentMode: "This action is only available in the local demo."
        case .invalidServerResponse: "The server returned an invalid response."
        case .networkUnavailable: "You appear to be offline. The city update was saved and will retry automatically."
        case .serverTemporarilyUnavailable: "The server is temporarily unavailable. Please try again shortly."
        case .message(let message): message
        }
    }
}

protocol AppRepository: Sendable {
    var mode: RepositoryMode { get }

    func loadSnapshot() async throws -> AppSnapshot
    func signInDemo() async throws -> AppSnapshot
    func signInWithApple(_ payload: AppleSignInPayload) async throws -> AppSnapshot
    func signOut() async throws -> AppSnapshot
    func deleteAccount() async throws -> AppSnapshot
    func updateProfile(_ update: ProfileUpdate) async throws -> AppSnapshot

    func sendFriendRequest(username: String) async throws -> AppSnapshot
    func respond(to requestID: UUID, response: FriendRequestResponse) async throws -> AppSnapshot
    func removeFriend(id: UUID) async throws -> AppSnapshot
    func blockUser(id: UUID) async throws -> AppSnapshot
    func unblockUser(id: UUID) async throws -> AppSnapshot
    func setFavorite(friendID: UUID, isFavorite: Bool) async throws -> AppSnapshot
    func setFriendPreference(_ preference: FriendAccessPreference) async throws -> AppSnapshot

    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot
    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource) async throws -> AppSnapshot
    func registerPushToken(_ token: String) async throws
    func retryPendingOperations() async throws -> AppSnapshot
    func pendingOperationCount() async -> Int

    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot
}

enum AppEnvironment {
    static func makeRepository() -> any AppRepository {
        let configuredDemoValue = Bundle.main.object(forInfoDictionaryKey: "WIFAllowsLocalDemo")
        let allowsDemo = (configuredDemoValue as? Bool)
            ?? ((configuredDemoValue as? String)?.uppercased() == "YES")
        if let configuration = APIConfiguration.fromBundle(),
           ProcessInfo.processInfo.arguments.contains("-useRemoteAPI") || !allowsDemo {
            return RemoteAppRepository(configuration: configuration)
        }
        return allowsDemo ? LocalDemoRepository() : UnavailableAppRepository()
    }
}

actor UnavailableAppRepository: AppRepository {
    nonisolated let mode: RepositoryMode = .remote

    private func unavailable() throws -> Never { throw RepositoryError.serverNotConfigured }
    func loadSnapshot() async throws -> AppSnapshot { try unavailable() }
    func signInDemo() async throws -> AppSnapshot { try unavailable() }
    func signInWithApple(_ payload: AppleSignInPayload) async throws -> AppSnapshot { try unavailable() }
    func signOut() async throws -> AppSnapshot { try unavailable() }
    func deleteAccount() async throws -> AppSnapshot { try unavailable() }
    func updateProfile(_ update: ProfileUpdate) async throws -> AppSnapshot { try unavailable() }
    func sendFriendRequest(username: String) async throws -> AppSnapshot { try unavailable() }
    func respond(to requestID: UUID, response: FriendRequestResponse) async throws -> AppSnapshot { try unavailable() }
    func removeFriend(id: UUID) async throws -> AppSnapshot { try unavailable() }
    func blockUser(id: UUID) async throws -> AppSnapshot { try unavailable() }
    func unblockUser(id: UUID) async throws -> AppSnapshot { try unavailable() }
    func setFavorite(friendID: UUID, isFavorite: Bool) async throws -> AppSnapshot { try unavailable() }
    func setFriendPreference(_ preference: FriendAccessPreference) async throws -> AppSnapshot { try unavailable() }
    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot { try unavailable() }
    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource) async throws -> AppSnapshot { try unavailable() }
    func registerPushToken(_ token: String) async throws { try unavailable() }
    func retryPendingOperations() async throws -> AppSnapshot { try unavailable() }
    func pendingOperationCount() async -> Int { 0 }
    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot { try unavailable() }
}
