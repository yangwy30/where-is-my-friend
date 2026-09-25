import Foundation
import Combine
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

/// A bounded UI request, including Auth token refresh. Late responses cannot
/// resume the waiter or apply a stale snapshot after a timeout/retry.
@MainActor
private final class ProfileSaveRequest {
    private var continuation: CheckedContinuation<AppSnapshot, Error>?
    private var request: Task<Void, Never>?
    private var timer: Task<Void, Never>?

    static func run(timeout: Duration, operation: @escaping @MainActor () async throws -> AppSnapshot) async throws -> AppSnapshot {
        let attempt = ProfileSaveRequest()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                attempt.continuation = continuation
                attempt.request = Task {
                    do { attempt.finish(.success(try await operation())) }
                    catch { attempt.finish(.failure(error)) }
                }
                attempt.timer = Task {
                    do {
                        try await Task.sleep(for: timeout)
                        attempt.finish(.failure(RepositoryError.message("Saving took too long. Your changes may have reached the server. Check your profile before trying again.")))
                    } catch { }
                }
                if Task.isCancelled { attempt.finish(.failure(CancellationError())) }
            }
        } onCancel: {
            Task { @MainActor in attempt.finish(.failure(CancellationError())) }
        }
    }

    private func finish(_ result: Result<AppSnapshot, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        request?.cancel(); timer?.cancel()
        request = nil; timer = nil
        continuation.resume(with: result)
    }
}

private struct PendingCityUpdate: Sendable {
    let city: String
    let countryCode: String?
    let source: PresenceSource
    let observedAt: Date
    let automaticOwnerID: UUID?
    let expectedOwnerID: UUID
    let administrativeArea: String?
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
    @Published private(set) var isSavingProfile = false
    @Published private(set) var profileSaveError: String?
    private let profileSaveTimeout: Duration
    @Published private(set) var pendingOperationCount = 0
    @Published private(set) var pushRegistrationState: PushRegistrationState = .notStarted
    @Published private(set) var pushRegistrationError: String?
    @Published private(set) var invitationRefreshRevision = 0
    private let pushRegistrationTimeout: Duration
    private var pushRegistrationGeneration = UUID()
    private var pushRegistrationDeadline: Task<Void, Never>?
    @Published private(set) var respondingRequestIDs: Set<UUID> = []
    @Published private(set) var isSendingFriendRequest = false
    @Published var pendingInvite: PendingInvite?
    @Published private(set) var widgetPrivacyMode: WidgetPrivacyMode
    @Published var notice: AppNotice?
    @Published var toast: AppToast?
    @Published var pendingSameCityEventID: UUID?
    @Published private(set) var sameCityBannerEventID: UUID?
    let travelPlans = TravelPlanLibrary()
    @Published var pendingUpcomingID: String?
    @Published private(set) var upcomingBanner: TravelOverlap?
    private var pendingUpcomingNotificationID: String?
    private var travelObservation: AnyCancellable?
    private var upcomingDismissTask: Task<Void, Never>?
    private var pendingForegroundSameCityIDs: Set<UUID> = []
    private var bannerDismissTask: Task<Void, Never>?
    private var sameCitySnapshotOwnerID: UUID?
    private var isAppActive = false

    let repositoryMode: RepositoryMode
    let notificationService: LocalNotificationService

    private let repository: any AppRepository
    var tripRepository: any AppRepository { repository }
    @Published var pendingTripInvitationID: UUID? = UserDefaults.standard.string(forKey: "pending-trip-invitation.v1").flatMap(UUID.init(uuidString:))
    @Published var pendingTripViewID: String?
    @Published var pendingFriendRequestID: UUID? = UserDefaults.standard.string(forKey: "pending-friend-request.v1").flatMap(UUID.init(uuidString:))
    private var pendingCityUpdate: PendingCityUpdate?
    private var latestPushToken: String?
    private var celebratesNextPushRegistration = false
    private var activeOperationCount = 0
    private var visibleOperationCount = 0
    private var operationSequence = 0
    private var latestAppliedOperationSequence = 0
    private var refreshIsInFlight = false

    init(repository: (any AppRepository)? = nil, profileSaveTimeout: Duration = .seconds(25), pushRegistrationTimeout: Duration = .seconds(20)) {
        self.pushRegistrationTimeout = pushRegistrationTimeout
        self.profileSaveTimeout = profileSaveTimeout
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
        notificationService.onSameCityForeground = { [weak self] id in
            self?.receiveSameCityNotification(id)
        }
        notificationService.onInvitationForeground = { [weak self] in
            guard let self, self.snapshot.isAuthenticated else { return }
            self.invitationRefreshRevision += 1
            Task { await self.refresh() }
        }
        notificationService.onNotificationOpen = { [weak self] url in
            self?.handleIncomingURL(url) ?? false
        }
        travelPlans.connect(repository: selectedRepository, userID: snapshot.isAuthenticated ? snapshot.currentUser.id : nil)
        notificationService.onUpcomingForeground = { [weak self] id in
            guard let self, snapshot.isAuthenticated else { return }
            pendingUpcomingNotificationID = id
            Task { await self.travelPlans.refresh() }
        }
        travelObservation = travelPlans.$overlaps.sink { [weak self] values in
            self?.reconcileUpcomingNotifications(values)
        }
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
        // A refresh started after a profile PATCH can return the pre-write snapshot
        // first, advance latestAppliedOperationSequence, and discard the save result.
        guard !refreshIsInFlight, !isSavingProfile, !isDeletingAccount else { return }
        refreshIsInFlight = true
        defer { refreshIsInFlight = false }
        await perform(successMessage: nil, showsActivity: false, presentsErrors: false) {
            try await self.repository.loadSnapshot()
        }
        await travelPlans.refresh()
    }

    func updateProfile(_ update: ProfileUpdate) async -> Bool {
        guard !isSavingProfile else { return false }
        isSavingProfile = true
        profileSaveError = nil
        defer { isSavingProfile = false }
        return await perform(successMessage: String(localized: "Profile updated."), showsActivity: false,
                             presentsErrors: false, waitsForPendingCityUpdate: false) {
            do {
                let validated = try update.validated()
                return try await ProfileSaveRequest.run(timeout: self.profileSaveTimeout) {
                    try await self.repository.updateProfile(validated)
                }
            } catch {
                self.profileSaveError = error as? RepositoryError == .networkUnavailable
                    ? "Couldn’t confirm your changes. Check your connection and try again."
                    : error.localizedDescription
                throw error
            }
        }
    }

    func clearProfileSaveError() { profileSaveError = nil }

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
        let previousOwner = snapshot.isAuthenticated ? snapshot.currentUser.id : nil
        pendingCityUpdate = nil
        notice = nil
        let signedOut = await perform(successMessage: nil, presentsErrors: false) {
            try await self.repository.signOut()
        }
        if signedOut {
            if repositoryMode == .localDemo, let previousOwner { AccountLocalData.clear(origin: repository.storageScope, ownerID: previousOwner) }
            notice = nil
            pendingCityUpdate = nil
            notificationService.unregisterRemoteNotifications()
            resetPushRegistration()
            SharedAppStateStore.reset()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    @Published private(set) var isDeletingAccount = false

    func deleteAccount() async {
        guard !isDeletingAccount else { return }
        let previousOwner = snapshot.isAuthenticated ? snapshot.currentUser.id : nil
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        pendingCityUpdate = nil
        notice = nil
        let deleted = await perform(successMessage: nil, presentsErrors: true, allowsDuringAccountDeletion: true) {
            try await self.repository.deleteAccount()
        }
        if deleted {
            if let previousOwner { LocationPermissionReminderStore.clearHistory(for: previousOwner) }
            if repositoryMode == .localDemo, let previousOwner { AccountLocalData.clear(origin: repository.storageScope, ownerID: previousOwner) }
            notice = nil
            pendingCityUpdate = nil
            notificationService.unregisterRemoteNotifications()
            resetPushRegistration()
            SharedAppStateStore.reset()
            WidgetCenter.shared.reloadAllTimelines()
        }
        if !deleted {
            notice = AppNotice(title: "Couldn’t confirm account deletion",
                message: notice?.message ?? "Please check your connection and try again. Your account deletion has not been confirmed.")
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
        guard friendPreferenceSaves[preference.friendID] == nil else { return }
        let saveID = UUID()
        friendPreferenceSaves[preference.friendID] = saveID
        defer {
            if friendPreferenceSaves[preference.friendID] == saveID { friendPreferenceSaves[preference.friendID] = nil }
        }
        await perform(successMessage: nil) {
            try await self.repository.setFriendPreference(preference)
        }
    }

    @Published private var friendPreferenceSaves: [UUID: UUID] = [:]
    func isSavingFriendPreference(for id: UUID) -> Bool { friendPreferenceSaves[id] != nil }

    @discardableResult
    func setSharingPreferences(_ preferences: SharingPreferences) async -> Bool {
        guard !isSavingSharingPreferences else { return false }
        let saveID = UUID()
        sharingSaveID = saveID
        isSavingSharingPreferences = true
        defer {
            if sharingSaveID == saveID { isSavingSharingPreferences = false; sharingSaveID = nil }
        }
        return await perform(successMessage: nil, showsActivity: false, waitsForPendingCityUpdate: false) {
            try await self.repository.setSharingPreferences(preferences)
        }
    }

    @Published private(set) var isSavingSharingPreferences = false
    private var sharingSaveID: UUID?

    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource,
                           observedAt: Date = Date(), automaticOwnerID: UUID? = nil,
                           expectedOwnerID: UUID? = nil, administrativeArea: String? = nil) async {
        guard snapshot.isAuthenticated else { return }
        let ownerID = expectedOwnerID ?? snapshot.currentUser.id
        guard ownerID == snapshot.currentUser.id else { return }
        if let automaticOwnerID {
            guard automaticOwnerID == snapshot.currentUser.id,
                  CityLocationPolicy.automaticAllowed(sharingEnabled: snapshot.sharingPreferences.citySharingEnabled,
                                                      presence: snapshot.currentPresence),
                  snapshot.currentPresence.updatedAt.map({ observedAt > $0 }) ?? true else { return }
        }
        if activeOperationCount > 0 {
            if automaticOwnerID != nil, let pending = pendingCityUpdate,
               pending.automaticOwnerID == nil || pending.observedAt >= observedAt { return }
            pendingCityUpdate = PendingCityUpdate(city: city, countryCode: countryCode, source: source,
                observedAt: observedAt, automaticOwnerID: automaticOwnerID, expectedOwnerID: ownerID, administrativeArea: administrativeArea)
            return
        }
        let message = source == .manual
            ? String(format: String(localized: "Your shared city is now %@."), city)
            : nil
        await perform(successMessage: message, showsActivity: automaticOwnerID == nil, presentsErrors: automaticOwnerID == nil) {
            try await self.repository.updateCurrentCity(
                city: city,
                countryCode: countryCode,
                source: source,
                observedAt: observedAt,
                administrativeArea: administrativeArea
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

    func lookupFlight(tripID: String, flightNumber: String, date: String) async throws -> [FlightCandidate] {
        try await repository.lookupFlight(tripID: tripID, flightNumber: flightNumber, date: date)
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
        guard snapshot.isAuthenticated, !isDeletingAccount else {
            resetPushRegistration()
            return
        }
        let owner = snapshot.currentUser.id
        await notificationService.refreshAuthorizationStatus()
        guard snapshot.isAuthenticated, snapshot.currentUser.id == owner else { return }
        guard notificationService.allowsNotifications else {
            resetPushRegistration()
            return
        }
        if !force {
            switch pushRegistrationState {
            case .waitingForDeviceToken, .registering: return
            case .registered(let time) where Date().timeIntervalSince(time) < 300: return
            default: break
            }
        }
        if userInitiated { celebratesNextPushRegistration = true }
        pushRegistrationState = .waitingForDeviceToken
        pushRegistrationError = nil
        beginPushDeadline(owner: owner)
        notificationService.registerForRemoteNotifications()
    }

    func retryPushRegistration() async {
        // Re-check permission and obtain the current device token, not just a cached one.
        await preparePushRegistrationIfAuthorized(force: true, userInitiated: true)
    }

    private func beginPushDeadline(owner: UUID) {
        pushRegistrationGeneration = UUID()
        let ticket = pushRegistrationGeneration
        pushRegistrationDeadline?.cancel()
        pushRegistrationDeadline = Task { [weak self] in
            guard let delay = self?.pushRegistrationTimeout else { return }
            do { try await Task.sleep(for: delay) } catch { return }
            guard let self, self.pushRegistrationGeneration == ticket,
                  self.snapshot.isAuthenticated, self.snapshot.currentUser.id == owner,
                  self.pushRegistrationState.isInProgress else { return }
            self.pushRegistrationGeneration = UUID()
            self.pushRegistrationError = self.pushRegistrationState == .waitingForDeviceToken
                ? "Couldn’t obtain a device token from Apple. Please retry."
                : "Device registration wasn’t confirmed in time. Please retry."
            self.pushRegistrationState = .failed
            self.celebratesNextPushRegistration = false
        }
    }

    func handlePushRegistrationFailure() {
        guard snapshot.isAuthenticated, pushRegistrationState == .waitingForDeviceToken else { return }
        pushRegistrationGeneration = UUID()
        pushRegistrationDeadline?.cancel()
        celebratesNextPushRegistration = false
        pushRegistrationError = "Couldn’t register this device for notifications. Please retry."
        pushRegistrationState = .failed
    }

    func registerPushToken(_ token: String) async {
        guard snapshot.isAuthenticated, !isDeletingAccount, !token.isEmpty else { return }
        if latestPushToken == token, pushRegistrationState == .registering { return }
        let owner = snapshot.currentUser.id
        latestPushToken = token
        pushRegistrationState = .registering
        pushRegistrationError = nil
        beginPushDeadline(owner: owner)
        let ticket = pushRegistrationGeneration
        do {
            try await repository.registerPushToken(token)
            guard ticket == pushRegistrationGeneration, snapshot.isAuthenticated, snapshot.currentUser.id == owner else { return }
            await refreshPendingOperationCount()
            let queued = await repository.isPushRegistrationPending()
            guard ticket == pushRegistrationGeneration, snapshot.isAuthenticated, snapshot.currentUser.id == owner else { return }
            pushRegistrationDeadline?.cancel()
            if queued {
                pushRegistrationState = .waitingForNetwork
                pushRegistrationError = "Device registration is waiting for a connection."
            } else {
                pushRegistrationState = .registered(Date())
                if celebratesNextPushRegistration { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            }
        } catch {
            guard ticket == pushRegistrationGeneration, snapshot.isAuthenticated, snapshot.currentUser.id == owner else { return }
            pushRegistrationDeadline?.cancel()
            applySessionExpirationIfNeeded(error)
            if snapshot.isAuthenticated {
                pushRegistrationError = "Couldn’t confirm notification setup. Please check your connection and retry."
                pushRegistrationState = .failed
            }
        }
        celebratesNextPushRegistration = false
    }

    func retryPendingOperations() async {
        let synced = await perform(successMessage: nil) {
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
        if let id = FriendRequestNotificationLink.parse(url) {
            discardTripInvitationLink()
            discardPendingInvite()
            pendingFriendRequestID = id
            UserDefaults.standard.set(id.uuidString, forKey: "pending-friend-request.v1")
            return true
        }
        if let id = UpcomingTravelLink.parse(url) {
            discardFriendRequestLink()
            pendingUpcomingID = id
            dismissUpcomingBanner()
            return true
        }
        if let id = SameCityAlertLink.eventID(from: url) {
            discardFriendRequestLink()
            pendingSameCityEventID = id
            dismissSameCityBanner()
            return true
        }
        if let id = TripInvitationLink.parseTripView(url) {
            discardFriendRequestLink()
            pendingTripViewID = id
            return true
        }
        if let id = TripInvitationLink.parse(url) {
            discardFriendRequestLink()
            UserDefaults.standard.set(id.uuidString, forKey: "pending-trip-invitation.v1")
            pendingTripInvitationID = id
            return true
        }
        guard let invite = InviteLinkParser.parse(url) else { return false }
        discardFriendRequestLink()
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

    func discardFriendRequestLink() {
        pendingFriendRequestID = nil
        UserDefaults.standard.removeObject(forKey: "pending-friend-request.v1")
    }

    func discardTripInvitationLink() {
        pendingTripInvitationID = nil
        UserDefaults.standard.removeObject(forKey: "pending-trip-invitation.v1")
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
        waitsForPendingCityUpdate: Bool = true,
        allowsDuringAccountDeletion: Bool = false,
        operation: @escaping () async throws -> AppSnapshot
    ) async -> Bool {
        // A later refresh/profile result must not supersede a confirmed account deletion.
        guard !isDeletingAccount || allowsDuringAccountDeletion else { return false }
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
                let previousOwner = snapshot.isAuthenticated ? snapshot.currentUser.id : nil
                snapshot = updated
                travelPlans.connect(repository: repository, userID: updated.isAuthenticated ? updated.currentUser.id : nil)
                if !updated.isAuthenticated || (previousOwner != nil && previousOwner != updated.currentUser.id) {
                    friendPreferenceSaves.removeAll()
                    sharingSaveID = nil
                    isSavingSharingPreferences = false
                    resetPushRegistration()
                    discardFriendRequestLink()
                    pendingSameCityEventID = nil
                    pendingForegroundSameCityIDs.removeAll()
                    dismissSameCityBanner()
                    pendingUpcomingID = nil
                    pendingUpcomingNotificationID = nil
                    dismissUpcomingBanner()
                }
                discoverNewSameCityEvents(excluding: existingEventIDs)
                reconcileSameCityBanner()
                if let banner = upcomingBanner,
                   friend(id: banner.friendID) == nil || snapshot.blockedUserIDs.contains(banner.friendID)
                    || !preference(for: banner.friendID).sameCityAlertEnabled {
                    dismissUpcomingBanner()
                }
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
            if presentsErrors && !(error is CancellationError) {
                let isUnauthenticated = (error as? RepositoryError) == .notAuthenticated
                if isUnauthenticated && !snapshot.isAuthenticated {
                    // Intentionally signed out; suppress notice
                } else {
                    notice = AppNotice(
                        title: String(localized: "Couldn’t complete that"),
                        message: error.localizedDescription
                    )
                }
            }
            result = false
        }

        activeOperationCount = max(0, activeOperationCount - 1)
        if showsActivity {
            visibleOperationCount = max(0, visibleOperationCount - 1)
            isWorking = visibleOperationCount > 0
        }
        if waitsForPendingCityUpdate {
            await flushPendingCityUpdateIfNeeded()
        } else {
            Task { await self.flushPendingCityUpdateIfNeeded() }
        }
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
            source: pending.source,
            observedAt: pending.observedAt,
            automaticOwnerID: pending.automaticOwnerID,
            expectedOwnerID: pending.expectedOwnerID,
            administrativeArea: pending.administrativeArea
        )
    }

    private func applySessionExpirationIfNeeded(_ error: Error) {
        guard error as? RepositoryError == .sessionExpired else { return }
        friendPreferenceSaves.removeAll()
        sharingSaveID = nil
        isSavingSharingPreferences = false
        resetPushRegistration()
        discardFriendRequestLink()
        snapshot = DemoData.signedOutSnapshot()
        travelPlans.connect(repository: repository, userID: nil)
        pendingUpcomingID = nil
        pendingUpcomingNotificationID = nil
        dismissUpcomingBanner()
        pendingSameCityEventID = nil
        sameCitySnapshotOwnerID = nil
        pendingForegroundSameCityIDs.removeAll()
        dismissSameCityBanner()
        SharedAppStateStore.save(snapshot, origin: repository.storageScope)
        synchronizeWidget()
    }

    private func refreshPendingOperationCount() async {
        guard snapshot.isAuthenticated else {
            pendingOperationCount = 0
            return
        }
        pendingOperationCount = await repository.pendingOperationCount()
    }

    private func deliverNewNotifications(excluding existingEventIDs: Set<UUID>) async {
        // Remote system notifications come from APNs; snapshot discovery only
        // presents an in-app banner, never a second scheduled system notification.
        guard repositoryMode == .localDemo else { return }
        for event in snapshot.colocationEvents where !existingEventIDs.contains(event.id) {
            guard SameCityAlertPolicy.isCurrent(event, in: snapshot) else { continue }
            await notificationService.schedule(event, previewsEnabled: snapshot.sharingPreferences.notificationPreviewEnabled)
        }
    }

    func setAppActive(_ active: Bool) {
        isAppActive = active
        if !active {
            pendingForegroundSameCityIDs.removeAll()
            dismissSameCityBanner()
        }
    }

    private func discoverNewSameCityEvents(excluding existingEventIDs: Set<UUID>) {
        guard repositoryMode == .remote else { return }
        guard snapshot.isAuthenticated else { sameCitySnapshotOwnerID = nil; return }
        guard snapshot.syncState != .offline else { return }
        let owner = snapshot.currentUser.id
        defer { sameCitySnapshotOwnerID = owner }
        // The first successful response establishes a baseline. Reopening/signing
        // in must not turn stored event history into a series of new banners.
        guard sameCitySnapshotOwnerID == owner, isAppActive else { return }
        let now = Date()
        let freshIDs = snapshot.colocationEvents.filter {
            !existingEventIDs.contains($0.id)
                && $0.createdAt <= now.addingTimeInterval(60)
                && now.timeIntervalSince($0.createdAt) < 5 * 60
        }.map(\.id)
        pendingForegroundSameCityIDs.formUnion(freshIDs)
    }

    var sameCityBannerEvent: ColocationEvent? {
        guard let id = sameCityBannerEventID,
              let event = SameCityAlertPolicy.event(id, in: snapshot),
              SameCityAlertPolicy.isCurrent(event, in: snapshot) else { return nil }
        return event
    }

    func dismissSameCityBanner() {
        bannerDismissTask?.cancel()
        bannerDismissTask = nil
        sameCityBannerEventID = nil
    }

    func openSameCityEvent(_ id: UUID) {
        dismissSameCityBanner()
        pendingSameCityEventID = id
    }

    private func receiveSameCityNotification(_ id: UUID) {
        guard snapshot.isAuthenticated, isAppActive else { return }
        pendingForegroundSameCityIDs.insert(id)
        let owner = snapshot.currentUser.id
        Task { [weak self] in
            guard let self else { return }
            await refresh()
            guard snapshot.isAuthenticated, snapshot.currentUser.id == owner else { return }
            reconcileSameCityBanner()
        }
    }

    private func reconcileSameCityBanner() {
        if sameCityBannerEventID != nil, sameCityBannerEvent == nil { dismissSameCityBanner() }
        guard snapshot.isAuthenticated, isAppActive else { return }
        let key = "same-city.seen.v1.\(repository.storageScope).\(snapshot.currentUser.id)"
        var seen = UserDefaults.standard.stringArray(forKey: key) ?? []
        let candidates = snapshot.colocationEvents.filter { pendingForegroundSameCityIDs.contains($0.id) }
            .sorted { $0.createdAt < $1.createdAt }
        for event in candidates {
            pendingForegroundSameCityIDs.remove(event.id)
            guard !seen.contains(event.id.uuidString) else { continue }
            seen.append(event.id.uuidString)
            guard SameCityAlertPolicy.isCurrent(event, in: snapshot) else { continue }
            dismissSameCityBanner()
            sameCityBannerEventID = event.id
            if !UIAccessibility.isVoiceOverRunning {
                bannerDismissTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(9)) } catch { return }
                    guard self?.sameCityBannerEventID == event.id else { return }
                    self?.sameCityBannerEventID = nil
                }
            }
        }
        UserDefaults.standard.set(Array(seen.suffix(100)), forKey: key)
    }

    func dismissUpcomingBanner() {
        upcomingDismissTask?.cancel()
        upcomingDismissTask = nil
        upcomingBanner = nil
    }

    func openUpcomingOverlap(_ id: String) {
        dismissUpcomingBanner()
        pendingUpcomingID = id
    }

    private func reconcileUpcomingNotifications(_ overlaps: [TravelOverlap]) {
        if let banner = upcomingBanner, !overlaps.contains(where: { $0.id == banner.id }) { dismissUpcomingBanner() }
        guard snapshot.isAuthenticated, let id = pendingUpcomingNotificationID,
              let overlap = overlaps.first(where: { $0.id == id && !$0.isPast() }),
              friend(id: overlap.friendID) != nil, !snapshot.blockedUserIDs.contains(overlap.friendID),
              preference(for: overlap.friendID).sameCityAlertEnabled else { return }
        pendingUpcomingNotificationID = nil
        let key = "upcoming.seen.v1.\(repository.storageScope).\(snapshot.currentUser.id)"
        var seen = UserDefaults.standard.stringArray(forKey: key) ?? []
        guard !seen.contains(id) else { return }
        seen.append(id); UserDefaults.standard.set(Array(seen.suffix(100)), forKey: key)
        dismissUpcomingBanner()
        upcomingBanner = overlap
        if !UIAccessibility.isVoiceOverRunning {
            upcomingDismissTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(9)) } catch { return }
                guard self?.upcomingBanner?.id == id else { return }
                self?.upcomingBanner = nil
            }
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
            updatedAt: snapshot.lastSyncedAt ?? Date(),
            currentAdministrativeArea: snapshot.isAuthenticated ? snapshot.currentPresence.administrativeArea : nil,
            currentPresenceUpdatedAt: snapshot.isAuthenticated && snapshot.sharingPreferences.citySharingEnabled ? snapshot.currentPresence.updatedAt : nil
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
        pushRegistrationGeneration = UUID()
        pushRegistrationDeadline?.cancel()
        pushRegistrationDeadline = nil
        pushRegistrationError = nil
        latestPushToken = nil
        celebratesNextPushRegistration = false
        pushRegistrationState = .notStarted
    }
}
