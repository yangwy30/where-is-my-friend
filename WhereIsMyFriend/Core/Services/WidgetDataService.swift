import Foundation
import WidgetKit

public class WidgetDataService {
    public static let shared = WidgetDataService()

    private init() {}

    public func syncFriendsToWidget(friends: [FriendLocation] = []) async {
        let widgetFriends = friends.map { friend in
            WidgetFriend(
                id: friend.id,
                name: friend.displayName,
                photoURL: friend.photoURL,
                emoji: friend.avatarEmoji,
                avatarColor: friend.avatarColor,
                city: friend.city,
                countryFlag: friend.countryFlag,
                lastUpdated: friend.lastUpdated,
                isGhost: friend.isGhost
            )
        }

        let widgetData = WidgetFriendData(friends: widgetFriends, lastSyncedAt: Date())

        if let sharedDefaults = UserDefaults(suiteName: AppConstants.appGroupId),
           let encodedData = try? JSONEncoder().encode(widgetData) {
            sharedDefaults.set(encodedData, forKey: AppConstants.widgetDataKey)
            print("[WidgetDataService] Synced \(widgetFriends.count) friends to App Group container.")
            
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            print("[WidgetDataService] Failed to access shared App Group container.")
        }
    }
}
