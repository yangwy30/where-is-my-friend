import SwiftUI

private enum AppTab: Hashable {
    case friends
    case trips
    case profile
}

private enum ProfileRoute: Hashable {
    case events
}

private struct OpenSharedTripsKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openSharedTrips: () -> Void {
        get { self[OpenSharedTripsKey.self] }
        set { self[OpenSharedTripsKey.self] = newValue }
    }
}

struct AppShellView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var tripLibrary = TripLibrary()
    let onReplayOnboarding: () -> Void
    @State private var selection: AppTab = ProcessInfo.processInfo.arguments.contains("-previewTrips")
        ? .trips
        : .friends
    @State private var friendsPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @State private var tripsPath = NavigationPath()
    @State private var showsCitySharing = false
    @State private var sameCityEventID: UUID?
    @State private var upcomingID: String?
    @State private var sameCityPresentationID = UUID()

    init(onReplayOnboarding: @escaping () -> Void) {
        self.onReplayOnboarding = onReplayOnboarding
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $friendsPath) {
                FriendsView(selectedSameCityEventID: $sameCityEventID, selectedUpcomingID: $upcomingID,
                            isHomeVisible: selection == .friends && friendsPath.isEmpty && !showsCitySharing) {
                    showsCitySharing = true
                }
                .id(sameCityPresentationID)
            }
            .tabItem {
                Label("Friends", systemImage: "person.2.fill")
                    .accessibilityIdentifier("friendsTab")
            }
            .tag(AppTab.friends)

            NavigationStack(path: $tripsPath) {
                TripsView()
            }
            .tabItem {
                Label("Shared trips", systemImage: "airplane")
                    .accessibilityIdentifier("tripsTab")
            }
            .tag(AppTab.trips)

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
        .environmentObject(tripLibrary)
        .environment(\.openSharedTrips, {
            tripsPath = NavigationPath()
            selection = .trips
        })
        .wifTabBarMinimizeOnScroll()
        .onChange(of: store.pendingFriendViewID, initial: true) { _, id in
            guard let id else { return }
            let owner = store.snapshot.currentUser.id
            selection = .friends
            friendsPath = NavigationPath()
            showsCitySharing = false
            sameCityPresentationID = UUID()
            Task {
                await store.refresh()
                guard store.snapshot.isAuthenticated, store.snapshot.currentUser.id == owner,
                      store.pendingFriendViewID == id else { return }
                store.pendingFriendViewID = nil
                if let friend = store.friend(id: id), !store.snapshot.blockedUserIDs.contains(id) {
                    friendsPath.append(friend)
                } else {
                    store.notice = AppNotice(title: String(localized: "Friend unavailable"),
                        message: String(localized: "This friend is no longer available for this account. Refresh your friends and try again."))
                }
            }
        }
        .onChange(of: store.pendingSameCityEventID, initial: true) { _, id in
            if let id {
                selection = .friends
                friendsPath = NavigationPath()
                sameCityEventID = id
                upcomingID = nil
                sameCityPresentationID = UUID()
                store.pendingSameCityEventID = nil
            }
        }
        .onChange(of: store.pendingTripInvitationID, initial: true) { _, id in
            if id != nil { selection = .trips }
        }
        .onChange(of: store.pendingFriendRequestID, initial: true) { _, id in
            if id != nil { selection = .friends }
        }
        .onChange(of: store.pendingUpcomingID, initial: true) { _, id in
            if let id {
                selection = .friends; friendsPath = NavigationPath()
                sameCityEventID = nil; upcomingID = id; sameCityPresentationID = UUID()
                store.pendingUpcomingID = nil
            }
        }
        .onChange(of: store.pendingTripViewID, initial: true) { _, id in
            if let id {
                selection = .trips
                tripsPath = NavigationPath()
                tripsPath.append(id)
                store.pendingTripViewID = nil
            }
        }
        .onOpenURL(perform: openDeepLink)
        .sheet(isPresented: $showsCitySharing) {
            CitySharingSheet()
        }
    }

    private func openDeepLink(_ url: URL) {
        // AppStore routes event links even on a cold launch or before sign-in.
        if SameCityAlertLink.eventID(from: url) != nil || UpcomingTravelLink.parse(url) != nil || FriendDetailLink.parse(url) != nil { return }
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


    }
}

#Preview {
    let store = AppStore()
    AppShellView(onReplayOnboarding: {})
        .environmentObject(store)
        .environmentObject(store.travelPlans)
        .environmentObject(CityLocationService())
        .environmentObject(LocationPermissionReminderStore())
}
