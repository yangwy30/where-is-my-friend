import Foundation
import Observation

@Observable
public class AuthViewModel {
    public var email = ""
    public var password = ""
    public var displayName = ""
    public var selectedEmoji = "🧑"
    public var errorMessage: String?
    public var isLoading = false

    public let availableEmojis = ["🧑", "👩", "🦊", "🐶", "🐱", "🦁", "🐼", "🐨", "🚀", "🌟"]

    public func login() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.shared.signInWithEmail(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            try await AuthService.shared.signUp(email: email, password: password, displayName: displayName, avatarEmoji: selectedEmoji)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
