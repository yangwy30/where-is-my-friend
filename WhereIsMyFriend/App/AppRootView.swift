import SwiftUI

struct AppRootView: View {
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
        .task { await store.refresh() }
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
            guard let token = notification.object as? String else { return }
            Task { await store.registerPushToken(token) }
        }
        .alert(item: $store.notice) { notice in
            Alert(
                title: Text(notice.title),
                message: Text(notice.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

#Preview {
    AppRootView()
}
