import SwiftUI

struct AppRootView: View {
    @AppStorage("prototype.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private var skipsOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-skipOnboarding")
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding || skipsOnboarding {
                AppShellView {
                    hasCompletedOnboarding = false
                }
            } else {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
            }
        }
        .preferredColorScheme(nil)
    }
}

#Preview {
    AppRootView()
}
