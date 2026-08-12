import Foundation
import SwiftUI

public struct AppUser: Codable, Identifiable {
    public var id: String
    public var displayName: String
    public var email: String
    public var photoURL: String?
    public var avatarEmoji: String?
    public var avatarColor: String
    public var currentCity: String?
    public var currentCountry: String?
    public var countryCode: String?
    public var locationUpdatedAt: Date?
    public var isGhost: Bool
    public var fcmToken: String?
    public var inviteCode: String
    public var friendCount: Int
    public var createdAt: Date

    public init(
        id: String,
        displayName: String,
        email: String,
        photoURL: String? = nil,
        avatarEmoji: String? = "🧑",
        avatarColor: String = Color.randomAvatarColor,
        currentCity: String? = nil,
        currentCountry: String? = nil,
        countryCode: String? = nil,
        locationUpdatedAt: Date? = nil,
        isGhost: Bool = false,
        fcmToken: String? = nil,
        inviteCode: String,
        friendCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.photoURL = photoURL
        self.avatarEmoji = avatarEmoji
        self.avatarColor = avatarColor
        self.currentCity = currentCity
        self.currentCountry = currentCountry
        self.countryCode = countryCode
        self.locationUpdatedAt = locationUpdatedAt
        self.isGhost = isGhost
        self.fcmToken = fcmToken
        self.inviteCode = inviteCode
        self.friendCount = friendCount
        self.createdAt = createdAt
    }

    public enum AvatarType {
        case photo(URL)
        case emoji(String)
        case initials(String, Color)
    }

    public var avatarType: AvatarType {
        if let photoURL, let url = URL(string: photoURL) {
            return .photo(url)
        } else if let avatarEmoji, !avatarEmoji.isEmpty {
            return .emoji(avatarEmoji)
        } else {
            let initial = String(displayName.prefix(1)).uppercased()
            return .initials(initial, Color(hex: avatarColor))
        }
    }
}
