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
    case serverNotConfigured
    case unsupportedInCurrentMode
    case invalidServerResponse
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
        case .serverNotConfigured: "The production server URL has not been configured."
        case .unsupportedInCurrentMode: "This action is only available in the local demo."
        case .invalidServerResponse: "The server returned an invalid response."
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

    func sendFriendRequest(username: String) async throws -> AppSnapshot
    func respond(to requestID: UUID, response: FriendRequestResponse) async throws -> AppSnapshot
    func removeFriend(id: UUID) async throws -> AppSnapshot
    func setFavorite(friendID: UUID, isFavorite: Bool) async throws -> AppSnapshot
    func setFriendPreference(_ preference: FriendAccessPreference) async throws -> AppSnapshot

    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot
    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource) async throws -> AppSnapshot
    func registerPushToken(_ token: String) async throws

    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot
}

enum AppEnvironment {
    static func makeRepository() -> any AppRepository {
        if ProcessInfo.processInfo.arguments.contains("-useRemoteAPI"),
           let configuration = APIConfiguration.fromBundle() {
            return RemoteAppRepository(configuration: configuration)
        }
        return LocalDemoRepository()
    }
}
