import Foundation

public struct WidgetFriendData: Codable {
    public var friends: [WidgetFriend]
    public var lastSyncedAt: Date

    public init(friends: [WidgetFriend], lastSyncedAt: Date = Date()) {
        self.friends = friends
        self.lastSyncedAt = lastSyncedAt
    }
}

public struct WidgetFriend: Codable, Identifiable {
    public var id: String
    public var name: String
    public var photoURL: String?
    public var emoji: String?
    public var avatarColor: String
    public var city: String
    public var countryFlag: String
    public var lastUpdated: Date
    public var isGhost: Bool

    public init(id: String, name: String, photoURL: String? = nil, emoji: String? = nil, avatarColor: String = "#007AFF", city: String, countryFlag: String, lastUpdated: Date, isGhost: Bool = false) {
        self.id = id
        self.name = name
        self.photoURL = photoURL
        self.emoji = emoji
        self.avatarColor = avatarColor
        self.city = city
        self.countryFlag = countryFlag
        self.lastUpdated = lastUpdated
        self.isGhost = isGhost
    }
}
