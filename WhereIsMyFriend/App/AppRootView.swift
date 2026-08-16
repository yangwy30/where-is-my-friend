import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("prototype.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var store = AppStore()
    @StateObject private var locationService = CityLocationService()

    private var skipsOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-skipOnboarding")
    }

    var body: some View {
        Group {
            if !(hasCompletedOnboarding || skipsOnboarding) {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            } else if !store.snapshot.isAuthenticated {
                AuthenticationView()
            } else {
                AppShellView {
                    hasCompletedOnboarding = false
                }
            }
        }
        .environmentObject(store)
        .environmentObject(locationService)
        .preferredColorScheme(nil)
        .task {
            await store.refresh()
            await store.preparePushRegistrationIfAuthorized()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.preparePushRegistrationIfAuthorized() }
        }
        .onChange(of: backgroundUpdatesShouldRun, initial: true) { _, shouldRun in
            locationService.setBackgroundUpdatesEnabled(shouldRun)
        }
        .onOpenURL { _ = store.handleIncomingURL($0) }
        .onReceive(locationService.$latestCity.compactMap { $0 }.removeDuplicates()) { update in
            Task {
                await store.updateCurrentCity(
                    city: update.city,
                    countryCode: update.countryCode,
                    source: update.source
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
        .sheet(item: authenticatedInvite) { invite in
            IncomingInviteView(invite: invite)
        }
    }

    private var backgroundUpdatesShouldRun: Bool {
        store.snapshot.isAuthenticated
            && store.snapshot.sharingPreferences.backgroundUpdatesEnabled
    }

    private var authenticatedInvite: Binding<PendingInvite?> {
        Binding {
            store.snapshot.isAuthenticated ? store.pendingInvite : nil
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
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 58))
                    .foregroundStyle(WIFTheme.fresh)
                Text("Connect with @\(invite.username)?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("This invite link will send a friend request. Your city stays private until both people accept and sharing is enabled.")
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                Button {
                    Task {
                        await store.acceptPendingInvite()
                        if store.pendingInvite == nil { dismiss() }
                    }
                } label: {
                    if store.isWorking {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text("Send friend request").frame(maxWidth: .infinity)
                    }
                }
                .wifGlassButton(tint: WIFTheme.fresh.opacity(0.28), prominent: true)
                .disabled(store.isWorking)
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
