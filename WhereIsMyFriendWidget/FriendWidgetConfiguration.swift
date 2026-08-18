import AppIntents
import Foundation

struct FriendWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose Friends"
    static var description = IntentDescription("Choose which friends appear first in this Widget.")

    @Parameter(title: "First friend")
    var firstFriend: WidgetFriendEntity?

    @Parameter(title: "Second friend")
    var secondFriend: WidgetFriendEntity?

    var selectedFriendIDs: [UUID] {
        var seen = Set<UUID>()
        return [firstFriend?.id, secondFriend?.id]
            .compactMap { $0 }
            .filter { seen.insert($0).inserted }
    }
}

struct WidgetFriendEntity: AppEntity, Hashable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Friend")
    static var defaultQuery = WidgetFriendEntityQuery()

    let id: UUID
    let displayName: String
    let cityDisplay: String

    init(friend: FriendPresence) {
        id = friend.id
        displayName = friend.displayName
        cityDisplay = friend.cityDisplay
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayName)",
            subtitle: "\(cityDisplay)"
        )
    }
}

struct WidgetFriendEntityQuery: EntityStringQuery {
    func entities(for identifiers: [WidgetFriendEntity.ID]) async throws -> [WidgetFriendEntity] {
        let identifiers = Set(identifiers)
        return availableFriends()
            .filter { identifiers.contains($0.id) }
            .map(WidgetFriendEntity.init(friend:))
    }

    func entities(matching string: String) async throws -> [WidgetFriendEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return availableFriends()
            .filter { friend in
                query.isEmpty
                    || friend.displayName.localizedCaseInsensitiveContains(query)
                    || friend.username.localizedCaseInsensitiveContains(query)
                    || friend.cityDisplay.localizedCaseInsensitiveContains(query)
            }
            .map(WidgetFriendEntity.init(friend:))
    }

    func suggestedEntities() async throws -> [WidgetFriendEntity] {
        availableFriends().map(WidgetFriendEntity.init(friend:))
    }

    private func availableFriends() -> [FriendPresence] {
        SharedPresenceStore.load().sorted { first, second in
            if first.isFavorite != second.isFavorite {
                return first.isFavorite
            }
            return first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
        }
    }
}

enum FriendWidgetOrdering {
    static func ordered(
        _ friends: [FriendPresence],
        currentCity: String,
        currentCountryCode: String?,
        selectedFriendIDs: [UUID],
        now: Date
    ) -> [FriendPresence] {
        let sameCityIDs = Set(
            MockFriendData.sameCityFriends(
                from: friends,
                currentCity: currentCity,
                currentCountryCode: currentCountryCode,
                now: now
            ).map(\.id)
        )

        let defaultOrder = friends.sorted { first, second in
            let firstIsSameCity = sameCityIDs.contains(first.id)
            let secondIsSameCity = sameCityIDs.contains(second.id)
            if firstIsSameCity != secondIsSameCity {
                return firstIsSameCity
            }
            if first.isFavorite != second.isFavorite {
                return first.isFavorite
            }
            if first.updatedAt != second.updatedAt {
                return (first.updatedAt ?? .distantPast) > (second.updatedAt ?? .distantPast)
            }
            return first.displayName.localizedStandardCompare(second.displayName) == .orderedAscending
        }

        let friendsByID = Dictionary(uniqueKeysWithValues: friends.map { ($0.id, $0) })
        let selected = selectedFriendIDs.compactMap { friendsByID[$0] }
        let selectedIDs = Set(selected.map(\.id))
        return selected + defaultOrder.filter { !selectedIDs.contains($0.id) }
    }
}
