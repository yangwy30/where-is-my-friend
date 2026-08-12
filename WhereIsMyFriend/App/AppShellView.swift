import SwiftUI

private enum AppTab: Hashable {
    case friends
    case sharing
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

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $friendsPath) {
                FriendsView()
            }
            .tabItem {
                Label("Friends", systemImage: "person.2.fill")
                    .accessibilityIdentifier("friendsTab")
            }
            .tag(AppTab.friends)

            NavigationStack {
                SharingView()
            }
            .tabItem {
                Label("Sharing", systemImage: "location.circle.fill")
                    .accessibilityIdentifier("sharingTab")
            }
            .tag(AppTab.sharing)

            NavigationStack(path: $profilePath) {
                ProfileView(onReplayOnboarding: onReplayOnboarding)
                    .navigationDestination(for: ProfileRoute.self) { route in
                        switch route {
                        case .events: NotificationHistoryView()
                        }
                    }
            }
            .tabItem {
                Label("You", systemImage: "person.crop.circle")
                    .accessibilityIdentifier("profileTab")
            }
            .tag(AppTab.profile)
        }
        .onOpenURL(perform: openDeepLink)
    }

    private func openDeepLink(_ url: URL) {
        if url.scheme == "whereismyfriend", url.host == "events" {
            selection = .profile
            profilePath = NavigationPath()
            profilePath.append(ProfileRoute.events)
            return
        }

        guard
            url.scheme == "whereismyfriend",
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
