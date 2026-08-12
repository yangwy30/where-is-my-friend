import Foundation
import SwiftUI
import Observation

@Observable
public class ProfileViewModel {
    public var user: AppUser? {
        AuthService.shared.currentUserProfile
    }

    public var inviteCode: String {
        user?.inviteCode ?? "N/A"
    }

    public func copyInviteCode() {
        UIPasteboard.general.string = inviteCode
    }
}
