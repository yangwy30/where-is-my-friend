import Foundation

public enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case blocked
}

public struct Friendship: Codable, Identifiable {
    public var id: String
    public var users: [String]
    public var status: FriendshipStatus
    public var requestedBy: String
    public var createdAt: Date

    public init(id: String, users: [String], status: FriendshipStatus, requestedBy: String, createdAt: Date = Date()) {
        self.id = id
        self.users = users
        self.status = status
        self.requestedBy = requestedBy
        self.createdAt = createdAt
    }

    /// Helper to generate deterministic friendship ID from two user IDs
    public static func makeId(user1: String, user2: String) -> String {
        return [user1, user2].sorted().joined(separator: "_")
    }
}
