import Foundation
import Observation

@Observable
public class SettingsViewModel {
    public var isGhostMode: Bool = false {
        didSet {
            Task {
                await FirestoreService.shared.setGhostMode(isGhost: isGhostMode)
            }
        }
    }

    public var notificationsEnabled: Bool = true

    public func signOut() {
        try? AuthService.shared.signOut()
    }
}
