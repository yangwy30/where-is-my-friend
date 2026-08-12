import Foundation
import Observation

@Observable
public class FriendsListViewModel {
    public var friends: [FriendLocation] = []
    public var isLoading: Bool = false
    public var errorMessage: String?

    public init() {
        loadMockFriends()
    }

    public func loadMockFriends() {
        self.friends = [
            FriendLocation(id: "1", displayName: "Alex", avatarEmoji: "🧑‍💻", avatarColor: "#007AFF", city: "Shanghai", country: "China", countryFlag: "CN".countryFlag, lastUpdated: Date().addingTimeInterval(-300)),
            FriendLocation(id: "2", displayName: "Sarah", avatarEmoji: "👩‍🎨", avatarColor: "#FF6B6B", city: "Tokyo", country: "Japan", countryFlag: "JP".countryFlag, lastUpdated: Date().addingTimeInterval(-7200)),
            FriendLocation(id: "3", displayName: "Michael", avatarEmoji: "🦊", avatarColor: "#4ECDC4", city: "New York", country: "USA", countryFlag: "US".countryFlag, lastUpdated: Date().addingTimeInterval(-86400)),
            FriendLocation(id: "4", displayName: "Elena", avatarEmoji: "💃", avatarColor: "#9B59B6", city: "Paris", country: "France", countryFlag: "FR".countryFlag, lastUpdated: Date().addingTimeInterval(-1800), isGhost: true)
        ]

        Task {
            await WidgetDataService.shared.syncFriendsToWidget(friends: self.friends)
        }
    }

    public func refresh() async {
        isLoading = true
        // Simulate network fetch
        try? await Task.sleep(nanoseconds: 500_000_000)
        loadMockFriends()
        isLoading = false
    }
}
