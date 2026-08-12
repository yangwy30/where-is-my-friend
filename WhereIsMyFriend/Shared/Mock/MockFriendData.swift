import Foundation

enum MockFriendData {
    static let currentUserCity = "New York"

    static var friends: [FriendPresence] {
        let now = Date()
        return [
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
                displayName: "Mia Chen",
                username: "mia",
                city: "New York",
                countryCode: "US",
                updatedAt: now.addingTimeInterval(-8 * 60),
                avatarPalette: 0,
                isFavorite: true
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
                displayName: "Lin Zhao",
                username: "lin",
                city: "Tokyo",
                countryCode: "JP",
                updatedAt: now.addingTimeInterval(-18 * 60),
                avatarPalette: 1,
                isFavorite: true
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
                displayName: "Sofia Martins",
                username: "sofia",
                city: "Lisbon",
                countryCode: "PT",
                updatedAt: now.addingTimeInterval(-65 * 60),
                avatarPalette: 2
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                displayName: "Daniel Kim",
                username: "daniel",
                city: "Toronto",
                countryCode: "CA",
                updatedAt: now.addingTimeInterval(-3 * 60 * 60),
                avatarPalette: 3
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
                displayName: "Noah Williams",
                username: "noah",
                city: nil,
                countryCode: nil,
                updatedAt: nil,
                sharingState: .paused,
                avatarPalette: 4
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
                displayName: "Alex Rivera",
                username: "alex",
                city: "New York",
                countryCode: "US",
                updatedAt: now.addingTimeInterval(-32 * 60),
                avatarPalette: 5
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
                displayName: "Amara Okafor",
                username: "amara",
                city: "Berlin",
                countryCode: "DE",
                updatedAt: now.addingTimeInterval(-28 * 60 * 60),
                avatarPalette: 6
            )
        ]
    }

    static var featuredFriend: FriendPresence {
        friends.first(where: { $0.username == "lin" }) ?? friends[0]
    }

    static func sameCityFriends(
        from friends: [FriendPresence],
        currentCity: String = currentUserCity,
        now: Date = Date()
    ) -> [FriendPresence] {
        friends.filter { friend in
            friend.city?.caseInsensitiveCompare(currentCity) == .orderedSame
                && friend.isSameCityEligible(at: now)
        }
    }
}
