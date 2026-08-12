import SwiftUI

public struct ContentView: View {
    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var authService = AuthService.shared

    public var body: some View {
        Group {
            if !onboardingCompleted {
                OnboardingView()
            } else if !authService.isAuthenticated {
                LoginView()
            } else {
                TabView {
                    FriendsListView()
                        .tabItem {
                            Label("Friends", systemImage: "map")
                        }

                    ProfileView()
                        .tabItem {
                            Label("Profile", systemImage: "person.circle")
                        }

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                }
            }
        }
    }
}
