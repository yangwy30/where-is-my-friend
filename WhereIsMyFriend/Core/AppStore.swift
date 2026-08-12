import Foundation
import WidgetKit

struct AppNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

private struct PendingCityUpdate: Sendable {
    let city: String
    let countryCode: String?
    let source: PresenceSource
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var snapshot: AppSnapshot
    @Published private(set) var isWorking = false
    @Published private(set) var pendingOperationCount = 0
    @Published var pendingInvite: PendingInvite?
    @Published private(set) var widgetPrivacyMode: WidgetPrivacyMode
    @Published var notice: AppNotice?

    let repositoryMode: RepositoryMode
    let notificationService: LocalNotificationService

    private let repository: any AppRepository
    private var pendingCityUpdate: PendingCityUpdate?

    init(repository: (any AppRepository)? = nil) {
        if ProcessInfo.processInfo.arguments.contains("-resetDemoData") {
            SharedAppStateStore.reset()
        }
        let selectedRepository = repository ?? AppEnvironment.makeRepository()
        self.repository = selectedRepository
        repositoryMode = selectedRepository.mode
        notificationService = LocalNotificationService()
        snapshot = SharedAppStateStore.load(expectedOrigin: selectedRepository.storageScope)
            ?? (selectedRepository.mode == .localDemo ? DemoData.initialSnapshot() : DemoData.signedOutSnapshot())
        pendingInvite = PendingInviteStore.load()
        widgetPrivacyMode = SharedWidgetPreferences.privacyMode()
        synchronizeWidget()
    }

    var currentCity: String? { snapshot.currentPresence.city }
    var friends: [FriendPresence] { snapshot.friends }
    var incomingRequestCount: Int { snapshot.incomingRequests.count }

    func friend(id: UUID) -> FriendPresence? {
        snapshot.friends.first { $0.id == id }
    }

    func preference(for friendID: UUID) -> FriendAccessPreference {
        snapshot.preference(for: friendID)
    }

    func refresh() async {
        await perform(successMessage: nil) {
            try await self.repository.loadSnapshot()
        }
    }

    func updateProfile(_ update: ProfileUpdate) async -> Bool {
        await perform(successMessage: "Profile updated.") {
            try await self.repository.updateProfile(update)
        }
    }

    func signInDemo() async {
        await perform(successMessage: "Demo account is ready.") {
            try await self.repository.signInDemo()
        }
    }

    func signInWithApple(_ payload: AppleSignInPayload) async {
        await perform(successMessage: "Signed in with Apple.") {
            try await self.repository.signInWithApple(payload)
        }
    }

    func signOut() async {
        await perform(successMessage: nil) {
            try await self.repository.signOut()
        }
    }

    func deleteAccount() async {
        await perform(successMessage: nil) {
            try await self.repository.deleteAccount()
        }
    }

    @discardableResult
    func sendFriendRequest(username: String) async -> Bool {
        await perform(successMessage: "Invitation created for @\(normalized(username)).") {
            try await self.repository.sendFriendRequest(username: username)
        }
    }

    func respond(to requestID: UUID, response: FriendRequestResponse) async {
        let message = response == .accept ? "Friend request accepted." : "Friend request declined."
        await perform(successMessage: message) {
            try await self.repository.respond(to: requestID, response: response)
        }
    }

    func removeFriend(id: UUID) async {
        await perform(successMessage: "Friend removed and sharing stopped.") {
            try await self.repository.removeFriend(id: id)
        }
    }

    func blockUser(id: UUID) async {
        await perform(successMessage: "Person blocked. Sharing stopped both ways.") {
            try await self.repository.blockUser(id: id)
        }
    }

    func unblockUser(id: UUID) async {
        await perform(successMessage: "Person unblocked.") {
            try await self.repository.unblockUser(id: id)
        }
    }

    func setFavorite(friendID: UUID, isFavorite: Bool) async {
        await perform(successMessage: nil) {
            try await self.repository.setFavorite(friendID: friendID, isFavorite: isFavorite)
        }
    }

    func setFriendPreference(_ preference: FriendAccessPreference) async {
        await perform(successMessage: nil) {
            try await self.repository.setFriendPreference(preference)
        }
    }

    @discardableResult
    func setSharingPreferences(_ preferences: SharingPreferences) async -> Bool {
        await perform(successMessage: nil) {
            try await self.repository.setSharingPreferences(preferences)
        }
    }

    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource) async {
        if isWorking {
            pendingCityUpdate = PendingCityUpdate(city: city, countryCode: countryCode, source: source)
            return
        }
        await perform(successMessage: source == .manual ? "Your shared city is now \(city)." : nil) {
            try await self.repository.updateCurrentCity(
                city: city,
                countryCode: countryCode,
                source: source
            )
        }
    }

    func runDemoScenario(_ scenario: DemoScenario) async {
        let message: String
        switch scenario {
        case .friendArrives: message = "A friend arrived in your city."
        case .ageLocations: message = "Friend locations are now stale."
        case .incomingRequest: message = "A new incoming request was added."
        case .restoreDefaults: message = "Demo data was restored."
        }
        await perform(successMessage: message) {
            try await self.repository.runDemoScenario(scenario)
        }
    }

    func registerPushToken(_ token: String) async {
        do {
            try await repository.registerPushToken(token)
            await refreshPendingOperationCount()
        } catch {
            applySessionExpirationIfNeeded(error)
            await refreshPendingOperationCount()
            notice = AppNotice(title: "Push registration", message: error.localizedDescription)
        }
    }

    func retryPendingOperations() async {
        await perform(successMessage: "Sync completed.") {
            try await self.repository.retryPendingOperations()
        }
    }

    @discardableResult
    func handleIncomingURL(_ url: URL) -> Bool {
        guard let invite = InviteLinkParser.parse(url) else { return false }
        PendingInviteStore.save(invite)
        pendingInvite = invite
        return true
    }

    func acceptPendingInvite() async {
        guard let invite = pendingInvite else { return }
        if await sendFriendRequest(username: invite.username) {
            discardPendingInvite()
        }
    }

    func discardPendingInvite() {
        PendingInviteStore.clear()
        pendingInvite = nil
    }

    func setWidgetPrivacyMode(_ mode: WidgetPrivacyMode) {
        widgetPrivacyMode = mode
        SharedWidgetPreferences.setPrivacyMode(mode)
        WidgetCenter.shared.reloadAllTimelines()
    }

    @discardableResult
    private func perform(
        successMessage: String?,
        operation: @escaping () async throws -> AppSnapshot
    ) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        let existingEventIDs = Set(snapshot.colocationEvents.map(\.id))
        if repositoryMode == .remote, snapshot.isAuthenticated {
            snapshot.syncState = .syncing
        }
        let result: Bool
        do {
            var updated = try await operation()
            if repositoryMode == .remote, updated.syncState != .offline {
                updated.syncState = .synced
            }
            snapshot = updated
            SharedAppStateStore.save(updated, origin: repository.storageScope)
            synchronizeWidget()
            await deliverNewNotifications(excluding: existingEventIDs)
            await refreshPendingOperationCount()
            if let successMessage {
                notice = AppNotice(title: "Done", message: successMessage)
            }
            result = true
        } catch {
            applySessionExpirationIfNeeded(error)
            if repositoryMode == .remote, snapshot.isAuthenticated {
                snapshot.syncState = .failed
            }
            await refreshPendingOperationCount()
            notice = AppNotice(title: "Couldn’t complete that", message: error.localizedDescription)
            result = false
        }
        isWorking = false
        await flushPendingCityUpdateIfNeeded()
        return result
    }

    private func flushPendingCityUpdateIfNeeded() async {
        guard !isWorking, snapshot.isAuthenticated, let pending = pendingCityUpdate else { return }
        pendingCityUpdate = nil
        await updateCurrentCity(
            city: pending.city,
            countryCode: pending.countryCode,
            source: pending.source
        )
    }

    private func applySessionExpirationIfNeeded(_ error: Error) {
        guard error as? RepositoryError == .sessionExpired else { return }
        snapshot = DemoData.signedOutSnapshot()
        SharedAppStateStore.save(snapshot, origin: repository.storageScope)
        synchronizeWidget()
    }

    private func refreshPendingOperationCount() async {
        pendingOperationCount = await repository.pendingOperationCount()
    }

    private func deliverNewNotifications(excluding existingEventIDs: Set<UUID>) async {
        guard snapshot.sharingPreferences.notificationPreviewEnabled else { return }
        for event in snapshot.colocationEvents where !existingEventIDs.contains(event.id) {
            await notificationService.schedule(event)
        }
    }

    private func synchronizeWidget() {
        SharedPresenceStore.save(
            snapshot.isAuthenticated ? snapshot.friends : [],
            currentCity: snapshot.isAuthenticated ? snapshot.currentPresence.city : nil,
            currentCountryCode: snapshot.isAuthenticated ? snapshot.currentPresence.countryCode : nil,
            updatedAt: snapshot.lastSyncedAt ?? Date()
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func normalized(_ username: String) -> String {
        username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
    }
}
