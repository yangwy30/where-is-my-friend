import Foundation

enum SharedAppLink {
    static var urlScheme: String {
        guard let configured = Bundle.main.object(forInfoDictionaryKey: "WIFURLScheme") as? String,
              !configured.isEmpty,
              !configured.contains("$(") else {
            return "whereismyfriend"
        }
        return configured.lowercased()
    }

    static func make(host: String, path: String? = nil) -> URL {
        var value = "\(urlScheme)://\(host)"
        if let path { value += "/\(path)" }
        return URL(string: value)!
    }
}

enum SharedPresenceStore {
    static var appGroupIdentifier: String {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "WIFAppGroupIdentifier") as? String,
           !configured.isEmpty,
           !configured.contains("$(") {
            return configured
        }
        return Bundle.main.bundleIdentifier?.contains(".staging") == true
            ? "group.com.yangwy30.whereismyfriend.staging"
            : "group.com.yangwy30.whereismyfriend"
    }
    private static let friendsKey = "prototype.friend-presence.snapshot"
    private static let currentCityKey = "widget.current-user-city"
    private static let currentCountryCodeKey = "widget.current-user-country-code"
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

    static func loadCurrentCountryCode() -> String? {
        defaults.string(forKey: currentCountryCodeKey)
    }

    static func loadLastUpdatedAt() -> Date? {
        defaults.object(forKey: lastUpdatedKey) as? Date
    }

    static func save(_ friends: [FriendPresence]) {
        guard let data = try? JSONEncoder().encode(friends) else { return }
        defaults.set(data, forKey: friendsKey)
    }

    static func save(
        _ friends: [FriendPresence],
        currentCity: String?,
        currentCountryCode: String? = nil,
        updatedAt: Date = Date()
    ) {
        save(friends)
        if let currentCity {
            defaults.set(currentCity, forKey: currentCityKey)
        } else {
            defaults.removeObject(forKey: currentCityKey)
        }
        if let currentCountryCode {
            defaults.set(currentCountryCode, forKey: currentCountryCodeKey)
        } else {
            defaults.removeObject(forKey: currentCountryCodeKey)
        }
        defaults.set(updatedAt, forKey: lastUpdatedKey)
    }

    static func resetPrototypeData() {
        defaults.removeObject(forKey: friendsKey)
        defaults.removeObject(forKey: currentCityKey)
        defaults.removeObject(forKey: currentCountryCodeKey)
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
            currentCountryCode: snapshot.isAuthenticated ? snapshot.currentPresence.countryCode : nil,
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
              let mode = WidgetPrivacyMode(rawValue: rawValue) else { return .hideAll }
        return mode
    }

    static func setPrivacyMode(_ mode: WidgetPrivacyMode) {
        defaults.set(mode.rawValue, forKey: privacyModeKey)
    }
}
