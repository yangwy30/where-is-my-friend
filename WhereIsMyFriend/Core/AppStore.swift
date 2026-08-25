import Foundation
import UIKit
import WidgetKit

struct AppNotice: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

struct AppToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let systemImage: String
}

private struct PendingCityUpdate: Sendable {
    let city: String
    let countryCode: String?
    let source: PresenceSource
}

enum PushRegistrationState: Equatable {
    case notStarted
    case waitingForDeviceToken
    case registering
    case waitingForNetwork
    case registered(Date)
    case failed

    var isInProgress: Bool {
        switch self {
        case .waitingForDeviceToken, .registering:
            true
        default:
            false
        }
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var snapshot: AppSnapshot
    @Published private(set) var isWorking = false
    @Published private(set) var pendingOperationCount = 0
    @Published private(set) var pushRegistrationState: PushRegistrationState = .notStarted
    @Published private(set) var respondingRequestIDs: Set<UUID> = []
    @Published private(set) var isSendingFriendRequest = false
    @Published var pendingInvite: PendingInvite?
    @Published private(set) var widgetPrivacyMode: WidgetPrivacyMode
    @Published var notice: AppNotice?
    @Published var toast: AppToast?

    let repositoryMode: RepositoryMode
    let notificationService: LocalNotificationService

    private let repository: any AppRepository
    private var pendingCityUpdate: PendingCityUpdate?
    private var latestPushToken: String?
    private var celebratesNextPushRegistration = false
    private var activeOperationCount = 0
    private var visibleOperationCount = 0
    private var operationSequence = 0
    private var latestAppliedOperationSequence = 0
    private var refreshIsInFlight = false

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
        guard !refreshIsInFlight else { return }
        refreshIsInFlight = true
        defer { refreshIsInFlight = false }
        await perform(successMessage: nil, showsActivity: false, presentsErrors: false) {
            try await self.repository.loadSnapshot()
        }
    }

    func updateProfile(_ update: ProfileUpdate) async -> Bool {
        await perform(successMessage: String(localized: "Profile updated.")) {
            try await self.repository.updateProfile(update)
        }
    }

    func signInDemo() async {
        await perform(successMessage: nil) {
            try await self.repository.signInDemo()
        }
    }

    func signInWithApple(_ payload: AppleSignInPayload) async {
        let signedIn = await perform(successMessage: nil) {
            try await self.repository.signInWithApple(payload)
        }
        if signedIn { await preparePushRegistrationIfAuthorized() }
    }

    func signOut() async {
        let signedOut = await perform(successMessage: nil) {
            try await self.repository.signOut()
        }
        if signedOut {
            notificationService.unregisterRemoteNotifications()
            resetPushRegistration()
        }
    }

    func deleteAccount() async {
        let deleted = await perform(successMessage: nil) {
            try await self.repository.deleteAccount()
        }
        if deleted {
            notificationService.unregisterRemoteNotifications()
            resetPushRegistration()
        }
    }

    @discardableResult
    func sendFriendRequest(username: String) async -> Bool {
        guard !isSendingFriendRequest else { return false }
        isSendingFriendRequest = true
        defer { isSendingFriendRequest = false }
        let message = String(
            format: String(localized: "Request sent to @%@."),
            normalized(username)
        )
        return await perform(successMessage: message) {
            try await self.repository.sendFriendRequest(username: username)
        }
    }

    @discardableResult
    func respond(to requestID: UUID, response: FriendRequestResponse) async -> Bool {
        guard !respondingRequestIDs.contains(requestID) else { return false }
        respondingRequestIDs.insert(requestID)
        defer { respondingRequestIDs.remove(requestID) }
        let message = response == .accept
            ? String(localized: "Friend request accepted.")
            : String(localized: "Friend request declined.")
        return await perform(successMessage: message) {
            try await self.repository.respond(to: requestID, response: response)
        }
    }

    func isResponding(to requestID: UUID) -> Bool {
        respondingRequestIDs.contains(requestID)
    }

    func removeFriend(id: UUID) async {
        await perform(successMessage: String(localized: "Friend removed and sharing stopped.")) {
            try await self.repository.removeFriend(id: id)
        }
    }

    func blockUser(id: UUID) async {
        await perform(successMessage: String(localized: "Person blocked. Sharing stopped both ways.")) {
            try await self.repository.blockUser(id: id)
        }
    }

    func unblockUser(id: UUID) async {
        await perform(successMessage: String(localized: "Person unblocked.")) {
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
        if activeOperationCount > 0 {
            pendingCityUpdate = PendingCityUpdate(city: city, countryCode: countryCode, source: source)
            return
        }
        let message = source == .manual
            ? String(format: String(localized: "Your shared city is now %@."), city)
            : nil
        await perform(successMessage: message) {
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
        case .friendArrives: message = String(localized: "A friend arrived in your city.")
        case .ageLocations: message = String(localized: "Friend locations are now stale.")
        case .incomingRequest: message = String(localized: "A new incoming request was added.")
        case .restoreDefaults: message = String(localized: "Demo data was restored.")
        }
        await perform(successMessage: message) {
            try await self.repository.runDemoScenario(scenario)
        }
    }

    func requestNotificationAuthorization() async {
        celebratesNextPushRegistration = true
        let isAllowed = await notificationService.requestAuthorization()
        guard isAllowed else {
            celebratesNextPushRegistration = false
            pushRegistrationState = .notStarted
            return
        }
        await preparePushRegistrationIfAuthorized(force: true, userInitiated: true)
    }

    func preparePushRegistrationIfAuthorized(
        force: Bool = false,
        userInitiated: Bool = false
    ) async {
        guard snapshot.isAuthenticated else {
            resetPushRegistration()
            return
        }

        await notificationService.refreshAuthorizationStatus()
        guard notificationService.allowsNotifications else {
            if !pushRegistrationState.isInProgress {
                pushRegistrationState = .notStarted
            }
            return
        }

        if !force {
            switch pushRegistrationState {
            case .waitingForDeviceToken, .registering, .registered:
                return
            case .notStarted, .waitingForNetwork, .failed:
                break
            }
        }

        if userInitiated { celebratesNextPushRegistration = true }
        pushRegistrationState = .waitingForDeviceToken
        notificationService.registerForRemoteNotifications()
    }

    func retryPushRegistration() async {
        celebratesNextPushRegistration = true
        if let latestPushToken {
            await registerPushToken(latestPushToken)
        } else {
            await preparePushRegistrationIfAuthorized(force: true, userInitiated: true)
        }
    }

    func handlePushRegistrationFailure() {
        celebratesNextPushRegistration = false
        pushRegistrationState = .failed
    }

    func registerPushToken(_ token: String) async {
        latestPushToken = token
        pushRegistrationState = .registering
        do {
            try await repository.registerPushToken(token)
            await refreshPendingOperationCount()
            if await repository.isPushRegistrationPending() {
                pushRegistrationState = .waitingForNetwork
            } else {
                let registeredAt = Date()
                pushRegistrationState = .registered(registeredAt)
                if celebratesNextPushRegistration {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        } catch {
            applySessionExpirationIfNeeded(error)
            await refreshPendingOperationCount()
            pushRegistrationState = .failed
        }
        celebratesNextPushRegistration = false
    }

    func retryPendingOperations() async {
        let synced = await perform(successMessage: String(localized: "Sync completed.")) {
            try await self.repository.retryPendingOperations()
        }
        if synced,
           pushRegistrationState == .waitingForNetwork,
           !(await repository.isPushRegistrationPending()) {
            pushRegistrationState = .registered(Date())
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
        showsActivity: Bool = true,
        presentsErrors: Bool = true,
        operation: @escaping () async throws -> AppSnapshot
    ) async -> Bool {
        operationSequence += 1
        let currentOperationSequence = operationSequence
        activeOperationCount += 1
        if showsActivity {
            visibleOperationCount += 1
            isWorking = true
        }

        let result: Bool
        do {
            var updated = try await operation()
            if repositoryMode == .remote, updated.syncState != .offline {
                updated.syncState = .synced
            }
            if currentOperationSequence >= latestAppliedOperationSequence {
                latestAppliedOperationSequence = currentOperationSequence
                let existingEventIDs = Set(snapshot.colocationEvents.map(\.id))
                snapshot = updated
                SharedAppStateStore.save(updated, origin: repository.storageScope)
                synchronizeWidget()
                await deliverNewNotifications(excluding: existingEventIDs)
            }
            await refreshPendingOperationCount()
            if let successMessage {
                presentToast(successMessage)
            }
            result = true
        } catch {
            if error as? RepositoryError == .sessionExpired,
               currentOperationSequence >= latestAppliedOperationSequence {
                // A stale request must not sign the user out after a newer request
                // has already succeeded (for example, after a token refresh).
                latestAppliedOperationSequence = currentOperationSequence
                applySessionExpirationIfNeeded(error)
            }
            if repositoryMode == .remote,
               snapshot.isAuthenticated,
               isConnectivityError(error) {
                snapshot.syncState = .offline
                SharedAppStateStore.save(snapshot, origin: repository.storageScope)
            }
            await refreshPendingOperationCount()
            if presentsErrors {
                notice = AppNotice(
                    title: String(localized: "Couldn’t complete that"),
                    message: error.localizedDescription
                )
            }
            result = false
        }

        activeOperationCount = max(0, activeOperationCount - 1)
        if showsActivity {
            visibleOperationCount = max(0, visibleOperationCount - 1)
            isWorking = visibleOperationCount > 0
        }
        await flushPendingCityUpdateIfNeeded()
        return result
    }

    private func flushPendingCityUpdateIfNeeded() async {
        guard activeOperationCount == 0,
              snapshot.isAuthenticated,
              let pending = pendingCityUpdate
        else { return }
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
        // Remote same-city events are delivered by APNs. Re-scheduling events from
        // a bootstrap response would replay history on sign-in and duplicate pushes.
        guard repositoryMode == .localDemo else { return }
        guard snapshot.sharingPreferences.notificationPreviewEnabled else { return }
        for event in snapshot.colocationEvents where !existingEventIDs.contains(event.id) {
            await notificationService.schedule(event)
        }
    }

    private func presentToast(_ message: String, systemImage: String = "checkmark.circle.fill") {
        let newToast = AppToast(message: message, systemImage: systemImage)
        toast = newToast
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard self?.toast?.id == newToast.id else { return }
            self?.toast = nil
        }
    }

    private func isConnectivityError(_ error: Error) -> Bool {
        guard let repositoryError = error as? RepositoryError else { return false }
        return repositoryError == .networkUnavailable
            || repositoryError == .serverTemporarilyUnavailable
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

    private func resetPushRegistration() {
        latestPushToken = nil
        celebratesNextPushRegistration = false
        pushRegistrationState = .notStarted
    }
}
