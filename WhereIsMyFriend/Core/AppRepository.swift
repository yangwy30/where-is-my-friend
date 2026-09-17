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
    let nonce: String
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
    case sessionExpired
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: String(localized: "Please sign in first.")
        case .userNotFound: String(localized: "No demo user has that username. Try jamie, priya, leo, or emma.")
        case .alreadyFriends: String(localized: "You are already friends.")
        case .requestAlreadyExists: String(localized: "An invitation already exists.")
        case .cannotInviteYourself: String(localized: "You cannot invite yourself.")
        case .requestNotFound: String(localized: "That friend request no longer exists.")
        case .friendNotFound: String(localized: "That friend is no longer available.")
        case .alreadyBlocked: String(localized: "That person is already blocked.")
        case .blockedUserNotFound: String(localized: "That blocked person is no longer available.")
        case .serverNotConfigured: String(localized: "The production server URL has not been configured.")
        case .unsupportedInCurrentMode: String(localized: "This action is only available in the local demo.")
        case .invalidServerResponse: String(localized: "The server returned an invalid response.")
        case .networkUnavailable: String(localized: "You appear to be offline. The city update was saved and will retry automatically.")
        case .serverTemporarilyUnavailable: String(localized: "The server is temporarily unavailable. Please try again shortly.")
        case .sessionExpired: String(localized: "Your session expired. Please sign in again.")
        case .message(let message): message
        }
    }
}

protocol AppRepository: Sendable {
    func fetchTravelPlans() async throws -> TravelPlanSnapshot
    func saveTravelPlan(_ plan: PersonalTravelPlan) async throws -> TravelPlanSnapshot
    func deleteTravelPlan(id: UUID, revision: Int) async throws -> TravelPlanSnapshot
    func fetchTrips() async throws -> [CloudTrip]
    func createTrip(_ payload: TripPayload) async throws -> CloudTrip
    func mutateTrip(id: String, mutation: TripMutation) async throws -> CloudTrip
    func changeTripLifecycle(id: String, payload: TripLifecyclePayload) async throws -> TripLifecycleResult
    func updateTripReminderContext(_ context: TripReminderContext) async throws
    func remindTripMember(tripID: String, participantID: String) async throws -> TripReminderResult
    func updateTripCollaboration(id: String, action: String, payload: TripCollaborationPayload) async throws -> CloudTrip
    func tripInvitations(tripID: String?) async throws -> [TripInvitation]
    func inviteToTrip(id: String, username: String) async throws -> CreatedTripInvitation
    func acceptTripInvitation(id: UUID) async throws -> CloudTrip
    func dismissTripInvitation(id: UUID, revoke: Bool) async throws
    var mode: RepositoryMode { get }
    var storageScope: String { get }

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
    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource, observedAt: Date, administrativeArea: String?) async throws -> AppSnapshot
    func registerPushToken(_ token: String) async throws
    func retryPendingOperations() async throws -> AppSnapshot
    func pendingOperationCount() async -> Int
    func isPushRegistrationPending() async -> Bool

    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot
    func lookupFlight(tripID: String, flightNumber: String, date: String) async throws -> [FlightCandidate]
}

extension AppRepository {
    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource, observedAt: Date = Date()) async throws -> AppSnapshot {
        try await updateCurrentCity(city: city, countryCode: countryCode, source: source, observedAt: observedAt, administrativeArea: nil)
    }
    func fetchTravelPlans() async throws -> TravelPlanSnapshot { throw RepositoryError.unsupportedInCurrentMode }
    func saveTravelPlan(_ plan: PersonalTravelPlan) async throws -> TravelPlanSnapshot { throw RepositoryError.unsupportedInCurrentMode }
    func deleteTravelPlan(id: UUID, revision: Int) async throws -> TravelPlanSnapshot { throw RepositoryError.unsupportedInCurrentMode }
    func fetchTrips() async throws -> [CloudTrip] { throw RepositoryError.unsupportedInCurrentMode }
    func createTrip(_ payload: TripPayload) async throws -> CloudTrip { throw RepositoryError.unsupportedInCurrentMode }
    func mutateTrip(id: String, mutation: TripMutation) async throws -> CloudTrip { throw RepositoryError.unsupportedInCurrentMode }
    func changeTripLifecycle(id: String, payload: TripLifecyclePayload) async throws -> TripLifecycleResult { throw RepositoryError.unsupportedInCurrentMode }
    func updateTripReminderContext(_ context: TripReminderContext) async throws { throw RepositoryError.unsupportedInCurrentMode }
    func remindTripMember(tripID: String, participantID: String) async throws -> TripReminderResult { throw RepositoryError.unsupportedInCurrentMode }
    func updateTripCollaboration(id: String, action: String, payload: TripCollaborationPayload) async throws -> CloudTrip { throw RepositoryError.unsupportedInCurrentMode }
    func tripInvitations(tripID: String?) async throws -> [TripInvitation] { throw RepositoryError.unsupportedInCurrentMode }
    func inviteToTrip(id: String, username: String) async throws -> CreatedTripInvitation { throw RepositoryError.unsupportedInCurrentMode }
    func acceptTripInvitation(id: UUID) async throws -> CloudTrip { throw RepositoryError.unsupportedInCurrentMode }
    func dismissTripInvitation(id: UUID, revoke: Bool) async throws { throw RepositoryError.unsupportedInCurrentMode }
}

extension AppRepository {
    func isPushRegistrationPending() async -> Bool { false }
    func lookupFlight(tripID: String, flightNumber: String, date: String) async throws -> [FlightCandidate] { [] }
}

enum AppEnvironment {
    static func makeRepository() -> any AppRepository {
        let configuredDemoValue = Bundle.main.object(forInfoDictionaryKey: "WIFAllowsLocalDemo")
        let allowsDemo = (configuredDemoValue as? Bool)
            ?? ((configuredDemoValue as? String)?.uppercased() == "YES")
        let wantsRemote = ProcessInfo.processInfo.arguments.contains("-useRemoteAPI") || !allowsDemo
        if wantsRemote {
            guard
                let configuration = APIConfiguration.fromBundle(),
                let supabaseConfiguration = SupabaseConfiguration.fromBundle()
            else { return UnavailableAppRepository() }
            return RemoteAppRepository(
                configuration: configuration,
                supabaseConfiguration: supabaseConfiguration
            )
        }
        return LocalDemoRepository()
    }
}

actor UnavailableAppRepository: AppRepository {
    nonisolated let mode: RepositoryMode = .remote
    nonisolated let storageScope = "remote:unconfigured"

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
    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource, observedAt: Date, administrativeArea: String?) async throws -> AppSnapshot { try unavailable() }
    func registerPushToken(_ token: String) async throws { try unavailable() }
    func retryPendingOperations() async throws -> AppSnapshot { try unavailable() }
    func pendingOperationCount() async -> Int { 0 }
    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot { try unavailable() }
    func lookupFlight(tripID: String, flightNumber: String, date: String) async throws -> [FlightCandidate] { try unavailable() }
}
