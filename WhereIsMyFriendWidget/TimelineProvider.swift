import WidgetKit
import SwiftUI

public struct FriendEntry: TimelineEntry {
    public let date: Date
    public let friends: [WidgetFriend]

    public static var placeholder: [WidgetFriend] {
        [
            WidgetFriend(id: "1", name: "Alex", emoji: "🧑‍💻", city: "Shanghai", countryFlag: "🇨🇳", lastUpdated: Date()),
            WidgetFriend(id: "2", name: "Sarah", emoji: "👩‍🎨", city: "Tokyo", countryFlag: "🇯🇵", lastUpdated: Date().addingTimeInterval(-3600)),
            WidgetFriend(id: "3", name: "Michael", emoji: "🦊", city: "New York", countryFlag: "🇺🇸", lastUpdated: Date().addingTimeInterval(-7200))
        ]
    }
}

public struct TimelineProvider: WidgetKit.TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> FriendEntry {
        FriendEntry(date: Date(), friends: FriendEntry.placeholder)
    }

    public func getSnapshot(in context: Context, completion: @escaping (FriendEntry) -> Void) {
        let entry = loadFriendsFromAppGroup()
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<FriendEntry>) -> Void) {
        let entry = loadFriendsFromAppGroup()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadFriendsFromAppGroup() -> FriendEntry {
        guard let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupId),
              let data = sharedDefaults.data(forKey: AppConstants.widgetDataKey),
              let widgetData = try? JSONDecoder().decode(WidgetFriendData.self, from: data) else {
            return FriendEntry(date: Date(), friends: FriendEntry.placeholder)
        }

        let visibleFriends = widgetData.friends.filter { !$0.isGhost }
        return FriendEntry(date: Date(), friends: visibleFriends.isEmpty ? FriendEntry.placeholder : visibleFriends)
    }
}
