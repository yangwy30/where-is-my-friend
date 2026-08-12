import Foundation

struct AppUser: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var username: String
    var appleUserID: String?
    var avatarPalette: Int

    init(
        id: UUID = UUID(),
        displayName: String,
        username: String,
        appleUserID: String? = nil,
        avatarPalette: Int = 1
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.appleUserID = appleUserID
        self.avatarPalette = avatarPalette
    }

    var initials: String {
        let letters = displayName.split(separator: " ").prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters)
    }
}

enum PresenceSource: String, Codable, Hashable, Sendable {
    case demo
    case manual
    case foregroundLocation
    case significantChange
    case visit
}

struct CurrentUserPresence: Codable, Hashable, Sendable {
    var city: String?
    var countryCode: String?
    var updatedAt: Date?
    var source: PresenceSource

    var cityDisplay: String {
        guard let city else { return String(localized: "Location unavailable") }
        let flag = countryCode?.countryFlag ?? ""
        return [flag, city].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct SharingPreferences: Codable, Hashable, Sendable {
    var citySharingEnabled: Bool
    var backgroundUpdatesEnabled: Bool
    var notificationPreviewEnabled: Bool
}

struct FriendAccessPreference: Identifiable, Codable, Hashable, Sendable {
    var id: UUID { friendID }
    let friendID: UUID
    var sharesMyCity: Bool
    var sameCityAlertEnabled: Bool
}

enum FriendRequestDirection: String, Codable, Hashable, Sendable {
    case incoming
    case outgoing
}

struct FriendRequest: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let userID: UUID
    var displayName: String
    var username: String
    var direction: FriendRequestDirection
    var createdAt: Date
    var avatarPalette: Int
}

struct ColocationEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let deduplicationKey: String
    let city: String
    let friendIDs: [UUID]
    let friendNames: [String]
    let createdAt: Date
    var wasNotified: Bool

    var title: String { "Together in \(city)" }

    var message: String {
        let names = friendNames.joined(separator: ", ")
        return String(localized: "You and \(names) are now in the same city.")
    }
}

enum SyncState: String, Codable, Hashable, Sendable {
    case synced
    case syncing
    case offline
    case failed
}

struct AppSnapshot: Codable, Hashable, Sendable {
    var schemaVersion: Int
    var isAuthenticated: Bool
    var currentUser: AppUser
    var currentPresence: CurrentUserPresence
    var sharingPreferences: SharingPreferences
    var friends: [FriendPresence]
    var friendRequests: [FriendRequest]
    var friendPreferences: [FriendAccessPreference]
    var colocationEvents: [ColocationEvent]
    var blockedUserIDs: [UUID]
    var lastSyncedAt: Date?
    var syncState: SyncState

    func preference(for friendID: UUID) -> FriendAccessPreference {
        friendPreferences.first(where: { $0.friendID == friendID })
            ?? FriendAccessPreference(
                friendID: friendID,
                sharesMyCity: true,
                sameCityAlertEnabled: true
            )
    }

    var incomingRequests: [FriendRequest] {
        friendRequests.filter { $0.direction == .incoming }
    }

    var outgoingRequests: [FriendRequest] {
        friendRequests.filter { $0.direction == .outgoing }
    }
}

struct DirectoryPerson: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let username: String
    let city: String?
    let countryCode: String?
    let avatarPalette: Int

    var asPresence: FriendPresence {
        FriendPresence(
            id: id,
            displayName: displayName,
            username: username,
            city: city,
            countryCode: countryCode,
            updatedAt: city == nil ? nil : Date(),
            sharingState: city == nil ? .unavailable : .active,
            avatarPalette: avatarPalette
        )
    }
}

enum DemoData {
    static let currentUser = AppUser(
        id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
        displayName: "Wang Yang",
        username: "wangyang",
        avatarPalette: 1
    )

    static let directory: [DirectoryPerson] = [
        DirectoryPerson(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000010")!,
            displayName: "Jamie Park",
            username: "jamie",
            city: "Seoul",
            countryCode: "KR",
            avatarPalette: 3
        ),
        DirectoryPerson(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000011")!,
            displayName: "Priya Shah",
            username: "priya",
            city: "London",
            countryCode: "GB",
            avatarPalette: 2
        ),
        DirectoryPerson(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000012")!,
            displayName: "Leo Garcia",
            username: "leo",
            city: "Madrid",
            countryCode: "ES",
            avatarPalette: 5
        ),
        DirectoryPerson(
            id: UUID(uuidString: "20000000-0000-0000-0000-000000000013")!,
            displayName: "Emma Wilson",
            username: "emma",
            city: nil,
            countryCode: nil,
            avatarPalette: 6
        )
    ]

    static func person(username: String) -> DirectoryPerson? {
        let normalized = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
        return directory.first { $0.username == normalized }
    }

    static func initialSnapshot(now: Date = Date()) -> AppSnapshot {
        let friends = MockFriendData.friends
        let preferences = friends.map {
            FriendAccessPreference(friendID: $0.id, sharesMyCity: true, sameCityAlertEnabled: true)
        }
        let incoming = directory.prefix(2).map { person in
            FriendRequest(
                id: UUID(),
                userID: person.id,
                displayName: person.displayName,
                username: person.username,
                direction: .incoming,
                createdAt: now,
                avatarPalette: person.avatarPalette
            )
        }
        let sameCity = MockFriendData.sameCityFriends(from: friends, now: now)
        let initialEvent = ColocationEvent(
            id: UUID(),
            deduplicationKey: "seed-new-york",
            city: MockFriendData.currentUserCity,
            friendIDs: sameCity.map(\.id),
            friendNames: sameCity.map(\.displayName),
            createdAt: now,
            wasNotified: true
        )

        return AppSnapshot(
            schemaVersion: 1,
            isAuthenticated: true,
            currentUser: currentUser,
            currentPresence: CurrentUserPresence(
                city: MockFriendData.currentUserCity,
                countryCode: "US",
                updatedAt: now,
                source: .demo
            ),
            sharingPreferences: SharingPreferences(
                citySharingEnabled: true,
                backgroundUpdatesEnabled: false,
                notificationPreviewEnabled: true
            ),
            friends: friends,
            friendRequests: incoming,
            friendPreferences: preferences,
            colocationEvents: sameCity.isEmpty ? [] : [initialEvent],
            blockedUserIDs: [],
            lastSyncedAt: now,
            syncState: .synced
        )
    }
}

private extension String {
    var countryFlag: String {
        guard count == 2 else { return "" }
        let base: UInt32 = 127_397
        return uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(base + scalar.value).map(String.init)
        }.joined()
    }
}
