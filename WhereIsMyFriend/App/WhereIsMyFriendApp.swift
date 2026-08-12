import SwiftUI

@main
struct WhereIsMyFriendApp: App {
    @UIApplicationDelegateAdaptor(PushRegistrationDelegate.self) private var pushDelegate

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .tint(WIFTheme.fresh)
        }
    }
}
