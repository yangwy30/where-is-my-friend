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
        .wifTabBarMinimizeOnScroll()
        .safeAreaInset(edge: .top, spacing: 0) {
            if showsSyncBanner {
                syncBanner
            }
        }
        .onOpenURL(perform: openDeepLink)
    }

    private var showsSyncBanner: Bool {
        store.repositoryMode == .remote
            && (store.snapshot.syncState == .offline
                || store.snapshot.syncState == .failed
                || store.pendingOperationCount > 0)
    }

    private var syncBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: store.snapshot.syncState == .offline ? "wifi.slash" : "arrow.triangle.2.circlepath")
                .foregroundStyle(WIFTheme.fresh)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.snapshot.syncState == .offline ? "Working offline" : "Sync needs attention")
                    .font(.caption.weight(.semibold))
                Text(store.pendingOperationCount == 0
                     ? "Showing the last saved update"
                     : "\(store.pendingOperationCount) update(s) waiting")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            Spacer()
            Button("Retry") { Task { await store.retryPendingOperations() } }
                .font(.caption.weight(.semibold))
                .disabled(store.isWorking)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .wifGlassSurface(
            tint: store.snapshot.syncState == .offline ? Color.orange.opacity(0.14) : WIFTheme.fresh.opacity(0.12),
            in: Capsule()
        )
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private func openDeepLink(_ url: URL) {
        if url.scheme == SharedAppLink.urlScheme, url.host == "home" {
            selection = .friends
            friendsPath = NavigationPath()
            return
        }

        if url.scheme == SharedAppLink.urlScheme, url.host == "sharing" {
            selection = .sharing
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
