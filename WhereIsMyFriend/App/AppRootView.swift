import SwiftUI
import WidgetKit
import CoreLocation

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("prototype.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("location.hasSeenSetup.v1") private var hasSeenLocationSetup = false
    @State private var finishedLocationSetupThisLaunch = false
    @StateObject private var store = AppStore()
    @StateObject private var locationService = CityLocationService()
    @StateObject private var appearanceController = WIFAppearanceController()

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
            guard store.snapshot.isAuthenticated else { return }
            await store.preparePushRegistrationIfAuthorized()
            await store.refresh()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-previewFriendRequestNotification"),
               let request = store.snapshot.incomingRequests.first {
                _ = store.handleIncomingURL(SharedAppLink.make(host: "friend-requests", path: request.id.uuidString))
            }
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, store.snapshot.isAuthenticated else { return }
            Task {
                await store.preparePushRegistrationIfAuthorized()
                await store.refresh()
            }
        }
        .onChange(of: cityLocationContext, initial: true) { _, context in
            locationService.configure(context)
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
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { _ = store.handleIncomingURL(url) }
        }
        .onReceive(locationService.$latestCity.compactMap { $0 }.removeDuplicates()) { update in
            guard store.snapshot.isAuthenticated, update.ownerID == cityLocationContext.ownerID else { return }
            Task {
                await store.updateCurrentCity(
                    city: update.city,
                    countryCode: update.countryCode,
                    source: update.source,
                    observedAt: update.observedAt,
                    automaticOwnerID: update.isAutomatic ? update.ownerID : nil,
                    expectedOwnerID: update.ownerID,
                    administrativeArea: update.administrativeArea
                )
            }
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
            } else if let toast = store.toast {
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
        .animation(.easeInOut(duration: 0.22), value: store.toast)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.84), value: store.upcomingBanner?.id)
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.84),
                   value: store.sameCityBannerEventID)
        .sheet(item: authenticatedInvite) { invite in
            IncomingInviteView(invite: invite)
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
    @EnvironmentObject private var store: AppStore
    let invite: PendingInvite

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
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
                    Task {
                        await store.acceptPendingInvite()
                        if store.pendingInvite == nil { dismiss() }
                    }
                } label: {
                    if store.isSendingFriendRequest {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Send friend request").frame(maxWidth: .infinity)
                    }
                }
                .wifGlassButton(tint: WIFTheme.fresh.opacity(0.28), prominent: true)
                .disabled(store.isSendingFriendRequest)
                Button("Not now", role: .cancel) {
                    store.discardPendingInvite()
                    dismiss()
                }
            }
            .padding(28)
            .wifAmbientBackground()
            .navigationTitle("Friend invite")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    AppRootView()
}
