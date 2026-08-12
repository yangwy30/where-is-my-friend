import SwiftUI

private enum AppTab: Hashable {
    case friends
    case sharing
    case profile
}

struct AppShellView: View {
    let onReplayOnboarding: () -> Void
    @State private var selection: AppTab = .friends
    @State private var friendsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $friendsPath) {
                FriendsView()
            }
            .tabItem {
                Label("Friends", systemImage: "person.2.fill")
            }
            .tag(AppTab.friends)

            NavigationStack {
                SharingView()
            }
            .tabItem {
                Label("Sharing", systemImage: "location.circle.fill")
            }
            .tag(AppTab.sharing)

            NavigationStack {
                ProfileView(onReplayOnboarding: onReplayOnboarding)
            }
            .tabItem {
                Label("You", systemImage: "person.crop.circle")
            }
            .tag(AppTab.profile)
        }
        .onOpenURL(perform: openDeepLink)
    }

    private func openDeepLink(_ url: URL) {
        guard
            url.scheme == "whereismyfriend",
            url.host == "friend",
            let idText = url.pathComponents.dropFirst().first,
            let id = UUID(uuidString: idText),
            let friend = SharedPresenceStore.load().first(where: { $0.id == id })
        else { return }

        selection = .friends
        friendsPath = NavigationPath()
        friendsPath.append(friend)
    }
}

#Preview {
    AppShellView(onReplayOnboarding: {})
}
