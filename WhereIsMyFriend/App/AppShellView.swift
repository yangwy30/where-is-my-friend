import SwiftUI

private enum AppTab: Hashable {
    case friends
    case profile
}

private enum ProfileRoute: Hashable {
    case events
}

struct AppShellView: View {
    @EnvironmentObject private var store: AppStore
    let onReplayOnboarding: () -> Void
    @State private var selection: AppTab = .friends
    @State private var friendsPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @State private var showsCitySharing = false

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $friendsPath) {
                FriendsView {
                    showsCitySharing = true
                }
            }
            .tabItem {
                Label("Friends", systemImage: "person.2.fill")
                    .accessibilityIdentifier("friendsTab")
            }
            .tag(AppTab.friends)

            NavigationStack(path: $profilePath) {
                ProfileView(
                    onReplayOnboarding: onReplayOnboarding,
                    onOpenCitySharing: { showsCitySharing = true }
                )
                    .navigationDestination(for: ProfileRoute.self) { route in
                        switch route {
                        case .events: NotificationHistoryView()
                        }
                    }
            }
            .tabItem {
                Label("You", systemImage: "person.fill")
                    .accessibilityIdentifier("profileTab")
            }
            .tag(AppTab.profile)
        }
        .wifTabBarMinimizeOnScroll()
        .onOpenURL(perform: openDeepLink)
        .sheet(isPresented: $showsCitySharing) {
            CitySharingSheet()
        }
    }

    private func openDeepLink(_ url: URL) {
        if url.scheme == SharedAppLink.urlScheme, url.host == "home" {
            selection = .friends
            friendsPath = NavigationPath()
            return
        }

        if url.scheme == SharedAppLink.urlScheme, url.host == "sharing" {
            selection = .friends
            friendsPath = NavigationPath()
            showsCitySharing = true
            return
        }

        if url.scheme == SharedAppLink.urlScheme, url.host == "events" {
            selection = .profile
            profilePath = NavigationPath()
            profilePath.append(ProfileRoute.events)
            return
        }

        guard
            url.scheme == SharedAppLink.urlScheme,
            url.host == "friend",
            let idText = url.pathComponents.dropFirst().first,
            let id = UUID(uuidString: idText),
            let friend = store.friend(id: id)
        else { return }

        selection = .friends
        friendsPath = NavigationPath()
        friendsPath.append(friend)
    }
}

#Preview {
    AppShellView(onReplayOnboarding: {})
        .environmentObject(AppStore())
        .environmentObject(CityLocationService())
}
