import Foundation
import Observation

@Observable
public class FirestoreService {
    public static let shared = FirestoreService()

    private init() {}

    public func createUserProfile(user: AppUser) async {
        print("[FirestoreService] Created user profile: \(user.displayName) (Code: \(user.inviteCode))")
    }

    public func updateUserLocation(city: String, country: String, countryCode: String, latitude: Double, longitude: Double) async {
        guard let userId = AuthService.shared.currentUserId else { return }
        print("[FirestoreService] Updated location for \(userId): \(city), \(country) (\(countryCode))")
        
        // Sync to Widget container after updating Firestore
        await WidgetDataService.shared.syncFriendsToWidget()
    }

    public func setGhostMode(isGhost: Bool) async {
        guard let userId = AuthService.shared.currentUserId else { return }
        print("[FirestoreService] User \(userId) ghost mode set to: \(isGhost)")
        AuthService.shared.currentUserProfile?.isGhost = isGhost
        
        await WidgetDataService.shared.syncFriendsToWidget()
    }

    public func addFriend(byInviteCode inviteCode: String) async throws -> String {
        print("[FirestoreService] Requesting friend with invite code: \(inviteCode)")
        return "Friend request sent successfully!"
    }

    public func updateFCMToken(_ token: String) async {
        guard let userId = AuthService.shared.currentUserId else { return }
        print("[FirestoreService] Updated FCM token for \(userId): \(token)")
    }
}
