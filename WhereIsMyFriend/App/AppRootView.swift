import SwiftUI
import WidgetKit
import CoreLocation

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("prototype.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("location.hasSeenSetup.v1") private var hasSeenLocationSetup = false
    @State private var finishedLocationSetupThisLaunch = false
    private let runtime: CityUpdateRuntime
    @StateObject private var store: AppStore
    @StateObject private var locationService: CityLocationService
    @StateObject private var locationReminders = LocationPermissionReminderStore()
    @StateObject private var appearanceController = WIFAppearanceController()
    @StateObject private var incomingInviteDraft = FriendInvitationDraft()
    @StateObject private var toastWindow = ToastWindowHost()

    init(runtime: CityUpdateRuntime) {
        self.runtime = runtime
        _store = StateObject(wrappedValue: runtime.store)
        _locationService = StateObject(wrappedValue: runtime.locationService)
    }

    private var skipsOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-skipOnboarding")
    }

    private var previewsWidgets: Bool {
        ProcessInfo.processInfo.arguments.contains("-previewWidgets")
    }

    private var previewsOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-previewOnboarding")
    }

    private var onboardingPreviewStep: Int {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix("-previewOnboardingStep=")
        }), let value = Int(argument.split(separator: "=").last ?? "0") else {
            return 0
        }
        return value
    }

    var body: some View {
        Group {
            if previewsWidgets {
                HomeScreenWidgetMarketingView()
            } else if previewsOnboarding {
                OnboardingView(initialStep: onboardingPreviewStep, onComplete: {})
            } else if store.snapshot.isAuthenticated {
                if needsLocationSetup {
                    LocationSetupView {
                        locationReminders.deferAfterInitialSetup(for: store.snapshot.currentUser.id)
                        hasSeenLocationSetup = true
                        finishedLocationSetupThisLaunch = true
                    }
                } else {
                    AppShellView(onReplayOnboarding: { hasCompletedOnboarding = false })
                }
            } else if !(hasCompletedOnboarding || skipsOnboarding) {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            } else {
                AuthenticationView()
            }
        }
        .tint(WIFTheme.fresh)
        .preferredColorScheme(appearanceController.appearance.colorScheme)
        .task {
            guard scenePhase == .active, store.snapshot.isAuthenticated else { return }
            await store.preparePushRegistrationIfAuthorized()
            await store.refresh(minimumInterval: 15)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-previewFriendRequestNotification"),
               let request = store.snapshot.incomingRequests.first {
                _ = store.handleIncomingURL(SharedAppLink.make(host: "friend-requests", path: request.id.uuidString))
            }
            #endif
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            runtime.setActive(phase == .active)
            guard phase == .active, store.snapshot.isAuthenticated else { return }
            Task {
                await store.preparePushRegistrationIfAuthorized()
                await store.refresh(minimumInterval: 15)
            }
        }
        .onChange(of: store.snapshot.isAuthenticated ? store.snapshot.currentUser.id : nil) { _, ownerID in
            if locationReminders.presentedOwnerID != ownerID {
                locationReminders.prepare(ownerID: nil, eligible: false)
            }
        }
        .task(id: cityLocationContext) {
            guard cityLocationContext.isActive, cityLocationContext.automaticAllowed else { return }
            while !Task.isCancelled {
                locationService.refreshIfNeeded()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .onChange(of: locationService.authorizationStatus) { _, status in
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                hasSeenLocationSetup = true
                finishedLocationSetupThisLaunch = true
            }
        }
        .onChange(of: appearanceController.appearance) { _, _ in
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onOpenURL { _ = store.handleIncomingURL($0) }
        .onChange(of: store.pendingInvite) { _, _ in incomingInviteDraft.reset() }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { _ = store.handleIncomingURL(url) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushTokenUpdated)) { notification in
            guard store.snapshot.isAuthenticated, let token = notification.object as? String else { return }
            Task { await store.registerPushToken(token) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushRegistrationFailed)) { _ in
            guard store.snapshot.isAuthenticated else { return }
            store.handlePushRegistrationFailure()
        }
        .alert(item: $store.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .overlay(alignment: .top) {
            if store.snapshot.isAuthenticated, scenePhase == .active,
               let event = store.sameCityBannerEvent {
                SameCityAlertBanner(event: event)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            } else if store.snapshot.isAuthenticated, scenePhase == .active, let overlap = store.upcomingBanner {
                UpcomingAlertBanner(overlap: overlap)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { toastWindow.attach(store: store, appearance: appearanceController.appearance) }
        }
        .onChange(of: appearanceController.appearance) { _, appearance in
            toastWindow.attach(store: store, appearance: appearance)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.84), value: store.upcomingBanner?.id)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.84),
                   value: store.sameCityBannerEventID)
        .sheet(item: authenticatedInvite) { invite in
            IncomingInviteView(invite: invite, draft: incomingInviteDraft)
        }
        .sheet(isPresented: Binding(get: { store.snapshot.isAuthenticated && !needsLocationSetup && store.pendingTripInvitationID != nil },
                                   set: { if !$0 { store.discardTripInvitationLink() } })) {
            if let id = store.pendingTripInvitationID { TripInvitationLanding(invitationID: id) }
        }
        // Inject above the presentation modifiers so both the main content and
        // restored/deep-linked sheets inherit the same live dependencies.
        .sheet(isPresented: Binding(get: { store.snapshot.isAuthenticated && !needsLocationSetup && store.pendingFriendRequestID != nil },
                                   set: { if !$0 { store.discardFriendRequestLink() } })) {
            if let id = store.pendingFriendRequestID { FriendRequestNotificationSheet(requestID: id) }
        }
        .environmentObject(store)
        .environmentObject(store.travelPlans)
        .environmentObject(locationService)
        .environmentObject(locationReminders)
        .environmentObject(appearanceController)
    }

    private var cityLocationContext: CityLocationContext {
        CityLocationContext(
            ownerID: store.snapshot.isAuthenticated && store.repositoryMode == .remote ? store.snapshot.currentUser.id : nil,
            isActive: scenePhase == .active,
            automaticAllowed: CityLocationPolicy.automaticAllowed(
                sharingEnabled: store.snapshot.sharingPreferences.citySharingEnabled,
                presence: store.snapshot.currentPresence),
            backgroundEnabled: store.snapshot.sharingPreferences.backgroundUpdatesEnabled)
    }

    private var needsLocationSetup: Bool {
        // Reviewing an invitation does not require sharing a location.
        if store.pendingFriendRequestID != nil || store.pendingTripInvitationID != nil { return false }
        var isTest = false
        #if DEBUG
        isTest = ProcessInfo.processInfo.arguments.contains("-testLocationSetup")
        #endif
        return LocationSetupPolicy.shouldPresent(
            isAuthenticated: store.snapshot.isAuthenticated,
            hasSeenSetup: (hasSeenLocationSetup && !isTest) || finishedLocationSetupThisLaunch,
            isLiveAccount: store.repositoryMode == .remote || isTest,
            status: locationService.authorizationStatus
        )
    }

    private var authenticatedInvite: Binding<PendingInvite?> {
        Binding {
            store.snapshot.isAuthenticated && !needsLocationSetup && store.pendingTripInvitationID == nil ? store.pendingInvite : nil
        } set: { newValue in
            if newValue == nil { store.discardPendingInvite() }
        }
    }
}

private struct IncomingInviteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @EnvironmentObject private var store: AppStore
    let invite: PendingInvite
    @ObservedObject var draft: FriendInvitationDraft

    /// Opening your own link (for example, testing it after sharing) must not offer a request to yourself.
    private var isOwnLink: Bool {
        invite.username.caseInsensitiveCompare(store.snapshot.currentUser.username) == .orderedSame
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isOwnLink {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 58))
                            .foregroundStyle(WIFTheme.fresh)
                        Text("This is your invite link")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Share it with friends so they can send you a friend request.")
                            .foregroundStyle(WIFTheme.secondaryText)
                            .multilineTextAlignment(.center)
                        Button {
                            store.discardPendingInvite()
                            dismiss()
                        } label: {
                            Text("Done").foregroundStyle(WIFTheme.primaryText)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .wifGlassButton(tint: WIFTheme.fresh.opacity(0.28), prominent: true)
                        .accessibilityIdentifier("dismissOwnInvite")
                    } else {
                        Image(systemName: "link.badge.plus")
                            .font(.system(size: 58))
                            .foregroundStyle(WIFTheme.fresh)
                        Text("Connect with @\(invite.username)?")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("Send a friend request to connect.")
                            .foregroundStyle(WIFTheme.secondaryText)
                            .multilineTextAlignment(.center)
                        Button {
                            draft.inviteError = nil
                            Task {
                                await store.acceptPendingInvite(onFailure: { message in
                                    guard store.snapshot.isAuthenticated, store.pendingInvite == invite else { return }
                                    draft.inviteError = message
                                })
                                if store.pendingInvite == nil { dismiss() }
                            }
                        } label: {
                            if store.isSendingFriendRequest {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                Text("Send friend request").foregroundStyle(WIFTheme.primaryText)
                                .frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                        .wifGlassButton(tint: WIFTheme.fresh.opacity(0.28), prominent: true)
                        .disabled(store.isSendingFriendRequest)
                        .accessibilityIdentifier("acceptIncomingInvite")
                        if let inviteError = draft.inviteError {
                            Text(inviteError).font(.subheadline).foregroundStyle(WIFTheme.destructive)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("incomingInviteError")
                        }
                        Button("Not now", role: .cancel) {
                            store.discardPendingInvite()
                            dismiss()
                        }
                        .disabled(store.isSendingFriendRequest)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("dismissIncomingInvite")
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            .wifAmbientBackground()
            .navigationTitle("Friend invite")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .interactiveDismissDisabled(store.isSendingFriendRequest)
    }
}

/// Hosts the success toast in its own pass-through window above sheets. As a root
/// overlay it sat underneath any open sheet, so confirmations for actions taken in
/// Add friends or the editors were never seen.
@MainActor
final class ToastWindowHost: ObservableObject {
    private var window: UIWindow?

    func attach(store: AppStore, appearance: WIFAppearance) {
        let style: UIUserInterfaceStyle = switch appearance.colorScheme {
        case .light: .light
        case .dark: .dark
        default: .unspecified
        }
        if let window {
            window.overrideUserInterfaceStyle = style
            return
        }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        let host = UIHostingController(rootView: ToastOverlay().environmentObject(store))
        host.view.backgroundColor = .clear
        let window = UIWindow(windowScene: scene)
        window.rootViewController = host
        window.windowLevel = .normal + 1
        window.isUserInteractionEnabled = false
        window.overrideUserInterfaceStyle = style
        window.isHidden = false
        self.window = window
    }
}

private struct ToastOverlay: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        VStack {
            if let toast = store.toast {
                Label(toast.message, systemImage: toast.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.20), in: Capsule())
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("successToast")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.22), value: store.toast)
        .sensoryFeedback(.success, trigger: store.toast?.id) { _, id in id != nil }
        .onChange(of: store.toast?.id) { _, id in
            guard id != nil, let message = store.toast?.message else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

#Preview {
    AppRootView(runtime: CityUpdateRuntime())
}
