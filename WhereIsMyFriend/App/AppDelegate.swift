import UIKit
import UserNotifications

public class AppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[AppDelegate] App launched.")

        // Check if launched by Significant Location Change wakeup
        if launchOptions?[.location] != nil {
            print("[AppDelegate] App woken up by Significant Location Change.")
            LocationService.shared.startMonitoring()
        }

        return true
    }

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[AppDelegate] APNs Token received: \(tokenString)")
        Task {
            await FirestoreService.shared.updateFCMToken(tokenString)
        }
    }
}
