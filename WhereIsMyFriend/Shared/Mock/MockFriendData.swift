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
                displayName: "Chloe Martin",
                username: "chloe",
                city: "Paris",
                countryCode: "FR",
                updatedAt: now.addingTimeInterval(-25 * 60),
                avatarPalette: 2
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
                displayName: "David Kim",
                username: "david",
                city: "San Francisco",
                countryCode: "US",
                updatedAt: now.addingTimeInterval(-45 * 60),
                avatarPalette: 3
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
                displayName: "Alex Rivera",
                username: "alex",
                city: "London",
                countryCode: "GB",
                updatedAt: now.addingTimeInterval(-52 * 60),
                avatarPalette: 4
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
                displayName: "Hana Wang",
                username: "hana",
                city: "Beijing",
                countryCode: "CN",
                updatedAt: now.addingTimeInterval(-1 * 3600),
                avatarPalette: 5
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
                displayName: "Liam Miller",
                username: "liam",
                city: "Los Angeles",
                countryCode: "US",
                updatedAt: now.addingTimeInterval(-2 * 3600),
                avatarPalette: 6
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
                displayName: "Emma Davis",
                username: "emma",
                city: "Chicago",
                countryCode: "US",
                updatedAt: now.addingTimeInterval(-3 * 3600),
                avatarPalette: 0
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000009")!,
                displayName: "Lucas Rossi",
                username: "lucas",
                city: "Rome",
                countryCode: "IT",
                updatedAt: now.addingTimeInterval(-4 * 3600),
                avatarPalette: 1
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000010")!,
                displayName: "Oliver Smith",
                username: "oliver",
                city: "Sydney",
                countryCode: "AU",
                updatedAt: now.addingTimeInterval(-5 * 3600),
                avatarPalette: 2
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000011")!,
                displayName: "Jack Wilson",
                username: "jack",
                city: "Seattle",
                countryCode: "US",
                updatedAt: now.addingTimeInterval(-6 * 3600),
                avatarPalette: 3
            ),
            FriendPresence(
                id: UUID(uuidString: "10000000-0000-0000-0000-000000000012")!,
                displayName: "Amara Okafor",
                username: "amara",
                city: "Berlin",
                countryCode: "DE",
                updatedAt: now.addingTimeInterval(-7 * 3600),
                avatarPalette: 4
            )
        ].map { source in
            var friend = source
            let areas = ["New York":"NY","San Francisco":"CA","Seattle":"WA","Tokyo":"Tokyo","London":"England",
                         "Paris":"Île-de-France","Sydney":"New South Wales","Beijing":"Beijing","Berlin":"Berlin"]
            friend.administrativeArea = areas[friend.city ?? ""]
            return friend
        }
    }

    static var featuredFriend: FriendPresence {
        friends.first(where: { $0.username == "lin" }) ?? friends[0]
    }

    static func sameCityFriends(
        from friends: [FriendPresence],
        currentCity: String = currentUserCity,
        currentCountryCode: String? = nil,
        now: Date = Date(),
        currentAdministrativeArea: String? = nil,
        currentUpdatedAt: Date? = nil
    ) -> [FriendPresence] {
        let presence = CurrentUserPresence(administrativeArea: currentAdministrativeArea, city: currentCity,
            countryCode: currentCountryCode, updatedAt: currentUpdatedAt, source: .foregroundLocation)
        return friends.filter { PresenceMatchPolicy.matches(presence, $0, at: now) }
    }
}
