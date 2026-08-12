import Foundation
import Observation

@Observable
public class AuthService {
    public static let shared = AuthService()

    public var isAuthenticated: Bool = false
    public var currentUserId: String? = nil
    public var currentUserProfile: AppUser? = nil

    private init() {
        // Will attach Firebase Auth listener in runtime implementation
    }

    public func signInWithEmail(email: String, password: String) async throws {
        // Firebase Auth sign in stub
        print("[AuthService] Sign in with email: \(email)")
        self.currentUserId = "mock_uid_\(UUID().uuidString.prefix(6))"
        self.isAuthenticated = true
    }

    public func signUp(email: String, password: String, displayName: String, avatarEmoji: String? = "🧑") async throws {
        print("[AuthService] Sign up with email: \(email)")
        let uid = "uid_\(UUID().uuidString.prefix(8))"
        let inviteCode = generateInviteCode()

        let newUser = AppUser(
            id: uid,
            displayName: displayName,
            email: email,
            avatarEmoji: avatarEmoji,
            inviteCode: inviteCode
        )

        self.currentUserId = uid
        self.currentUserProfile = newUser
        self.isAuthenticated = true
        
        await FirestoreService.shared.createUserProfile(user: newUser)
    }

    public func signOut() throws {
        self.currentUserId = nil
        self.currentUserProfile = nil
        self.isAuthenticated = false
    }

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
