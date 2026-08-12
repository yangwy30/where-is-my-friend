import SwiftUI

@main
struct WhereIsMyFriendApp: App {
    init() {
        SharedPresenceStore.seedIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .tint(WIFTheme.fresh)
        }
    }
}
