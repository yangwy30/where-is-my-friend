import Foundation
import SwiftUI

public struct FriendLocation: Identifiable {
    public var id: String
    public var displayName: String
    public var photoURL: String?
    public var avatarEmoji: String?
    public var avatarColor: String
    public var city: String
    public var country: String
    public var countryFlag: String
    public var lastUpdated: Date
    public var isGhost: Bool

    public init(id: String, displayName: String, photoURL: String? = nil, avatarEmoji: String? = nil, avatarColor: String = "#007AFF", city: String, country: String, countryFlag: String, lastUpdated: Date, isGhost: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.photoURL = photoURL
        self.avatarEmoji = avatarEmoji
        self.avatarColor = avatarColor
        self.city = city
        self.country = country
        self.countryFlag = countryFlag
        self.lastUpdated = lastUpdated
        self.isGhost = isGhost
    }
}
