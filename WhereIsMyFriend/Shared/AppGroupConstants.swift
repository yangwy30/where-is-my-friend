import Foundation

public enum AppConstants {
    /// Maximum allowed friends per user (soft limit for scalability)
    public static let maxFriends = 50
    
    /// Shared App Group identifier for main app & Widget extension
    public static let appGroupId = "group.com.yourname.whereismyfriend"
    
    /// UserDefaults key for sharing friend locations with Widget
    public static let widgetDataKey = "widgetFriendData"
}
