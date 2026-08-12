import Foundation

enum SharedPresenceStore {
    static let appGroupIdentifier = "group.com.yangwy30.whereismyfriend"
    private static let friendsKey = "prototype.friend-presence.snapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func seedIfNeeded() {
        guard defaults.data(forKey: friendsKey) == nil else { return }
        save(MockFriendData.friends)
    }

    static func load() -> [FriendPresence] {
        guard
            let data = defaults.data(forKey: friendsKey),
            let decoded = try? JSONDecoder().decode([FriendPresence].self, from: data),
            !decoded.isEmpty
        else {
            return MockFriendData.friends
        }
        return decoded
    }

    static func save(_ friends: [FriendPresence]) {
        guard let data = try? JSONEncoder().encode(friends) else { return }
        defaults.set(data, forKey: friendsKey)
    }

    static func resetPrototypeData() {
        defaults.removeObject(forKey: friendsKey)
        seedIfNeeded()
    }
}
