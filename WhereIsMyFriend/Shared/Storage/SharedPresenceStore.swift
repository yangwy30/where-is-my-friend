import Foundation

enum SharedPresenceStore {
    static let appGroupIdentifier = "group.com.yangwy30.whereismyfriend"
    private static let friendsKey = "prototype.friend-presence.snapshot"
    private static let currentCityKey = "widget.current-user-city"
    private static let lastUpdatedKey = "widget.snapshot-updated-at"

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
            let decoded = try? JSONDecoder().decode([FriendPresence].self, from: data)
        else {
            return []
        }
        return decoded
    }

    static func loadCurrentCity() -> String {
        defaults.string(forKey: currentCityKey) ?? ""
    }

    static func loadLastUpdatedAt() -> Date? {
        defaults.object(forKey: lastUpdatedKey) as? Date
    }

    static func save(_ friends: [FriendPresence]) {
        guard let data = try? JSONEncoder().encode(friends) else { return }
        defaults.set(data, forKey: friendsKey)
    }

    static func save(_ friends: [FriendPresence], currentCity: String?, updatedAt: Date = Date()) {
        save(friends)
        if let currentCity {
            defaults.set(currentCity, forKey: currentCityKey)
        } else {
            defaults.removeObject(forKey: currentCityKey)
        }
        defaults.set(updatedAt, forKey: lastUpdatedKey)
    }

    static func resetPrototypeData() {
        defaults.removeObject(forKey: friendsKey)
        defaults.removeObject(forKey: currentCityKey)
        defaults.removeObject(forKey: lastUpdatedKey)
    }
}

enum SharedAppStateStore {
    private static let snapshotKey = "app.snapshot.v1"
    private static let originKey = "app.snapshot-origin.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedPresenceStore.appGroupIdentifier) ?? .standard
    }

    static func load(expectedOrigin: String? = nil) -> AppSnapshot? {
        if let expectedOrigin {
            let storedOrigin = defaults.string(forKey: originKey)
            guard storedOrigin == expectedOrigin
                    || (storedOrigin == nil && expectedOrigin == "localDemo") else {
                return nil
            }
        }
        guard let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }

    static func save(_ snapshot: AppSnapshot, origin: String = "localDemo") {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        defaults.set(origin, forKey: originKey)
        SharedPresenceStore.save(
            snapshot.isAuthenticated ? snapshot.friends : [],
            currentCity: snapshot.isAuthenticated ? snapshot.currentPresence.city : nil,
            updatedAt: snapshot.lastSyncedAt ?? Date()
        )
    }

    static func reset() {
        defaults.removeObject(forKey: snapshotKey)
        defaults.removeObject(forKey: originKey)
        SharedPresenceStore.resetPrototypeData()
    }
}

enum SharedWidgetPreferences {
    private static let privacyModeKey = "widget.privacy-mode.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedPresenceStore.appGroupIdentifier) ?? .standard
    }

    static func privacyMode() -> WidgetPrivacyMode {
        guard let rawValue = defaults.string(forKey: privacyModeKey),
              let mode = WidgetPrivacyMode(rawValue: rawValue) else { return .full }
        return mode
    }

    static func setPrivacyMode(_ mode: WidgetPrivacyMode) {
        defaults.set(mode.rawValue, forKey: privacyModeKey)
    }
}
