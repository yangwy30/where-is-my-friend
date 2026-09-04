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

struct ProfileUpdate: Codable, Hashable, Sendable {
    var displayName: String
    var username: String
    var avatarPalette: Int

    func validated() throws -> ProfileUpdate {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let handle = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
            .lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        guard (1...40).contains(name.count) else { throw ProfileValidationError.invalidDisplayName }
        guard (3...20).contains(handle.count),
              handle.unicodeScalars.allSatisfy(allowed.contains) else {
            throw ProfileValidationError.invalidUsername
        }
        return ProfileUpdate(
            displayName: name,
            username: handle,
            avatarPalette: max(0, min(6, avatarPalette))
        )
    }
}

enum ProfileValidationError: LocalizedError, Equatable {
    case invalidDisplayName
    case invalidUsername

    var errorDescription: String? {
        switch self {
        case .invalidDisplayName: "Display name must contain 1–40 characters."
        case .invalidUsername: "Username must contain 3–20 lowercase letters, numbers, or underscores."
        }
    }
}

struct BlockedPerson: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var username: String
    var avatarPalette: Int
    var blockedAt: Date
}

enum WidgetPrivacyMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case full
    case hideNames
    case hideAll

    var id: String { rawValue }
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

struct ColocationSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let friendID: UUID
    let cityKey: String
    var enteredAt: Date
    var leftAt: Date?

    var isActive: Bool { leftAt == nil }
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
    var colocationSessions: [ColocationSession]
    var blockedPeople: [BlockedPerson]
    var lastSyncedAt: Date?
    var syncState: SyncState

    var blockedUserIDs: [UUID] { blockedPeople.map(\.id) }

    init(
        schemaVersion: Int,
        isAuthenticated: Bool,
        currentUser: AppUser,
        currentPresence: CurrentUserPresence,
        sharingPreferences: SharingPreferences,
        friends: [FriendPresence],
        friendRequests: [FriendRequest],
        friendPreferences: [FriendAccessPreference],
        colocationEvents: [ColocationEvent],
        colocationSessions: [ColocationSession] = [],
        blockedPeople: [BlockedPerson] = [],
        lastSyncedAt: Date?,
        syncState: SyncState
    ) {
        self.schemaVersion = schemaVersion
        self.isAuthenticated = isAuthenticated
        self.currentUser = currentUser
        self.currentPresence = currentPresence
        self.sharingPreferences = sharingPreferences
        self.friends = friends
        self.friendRequests = friendRequests
        self.friendPreferences = friendPreferences
        self.colocationEvents = colocationEvents
        self.colocationSessions = colocationSessions
        self.blockedPeople = blockedPeople
        self.lastSyncedAt = lastSyncedAt
        self.syncState = syncState
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, isAuthenticated, currentUser, currentPresence, sharingPreferences
        case friends, friendRequests, friendPreferences, colocationEvents, colocationSessions
        case blockedPeople, blockedUserIDs, lastSyncedAt, syncState
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        isAuthenticated = try values.decode(Bool.self, forKey: .isAuthenticated)
        currentUser = try values.decode(AppUser.self, forKey: .currentUser)
        currentPresence = try values.decode(CurrentUserPresence.self, forKey: .currentPresence)
        sharingPreferences = try values.decode(SharingPreferences.self, forKey: .sharingPreferences)
        friends = try values.decodeIfPresent([FriendPresence].self, forKey: .friends) ?? []
        friendRequests = try values.decodeIfPresent([FriendRequest].self, forKey: .friendRequests) ?? []
        friendPreferences = try values.decodeIfPresent([FriendAccessPreference].self, forKey: .friendPreferences) ?? []
        colocationEvents = try values.decodeIfPresent([ColocationEvent].self, forKey: .colocationEvents) ?? []
        colocationSessions = try values.decodeIfPresent([ColocationSession].self, forKey: .colocationSessions) ?? []
        if let decodedPeople = try values.decodeIfPresent([BlockedPerson].self, forKey: .blockedPeople) {
            blockedPeople = decodedPeople
        } else {
            let legacyIDs = try values.decodeIfPresent([UUID].self, forKey: .blockedUserIDs) ?? []
            blockedPeople = legacyIDs.map {
                BlockedPerson(id: $0, displayName: "Blocked user", username: "blocked", avatarPalette: 4, blockedAt: Date())
            }
        }
        lastSyncedAt = try values.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
        syncState = try values.decodeIfPresent(SyncState.self, forKey: .syncState) ?? .synced
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(max(schemaVersion, 2), forKey: .schemaVersion)
        try values.encode(isAuthenticated, forKey: .isAuthenticated)
        try values.encode(currentUser, forKey: .currentUser)
        try values.encode(currentPresence, forKey: .currentPresence)
        try values.encode(sharingPreferences, forKey: .sharingPreferences)
        try values.encode(friends, forKey: .friends)
        try values.encode(friendRequests, forKey: .friendRequests)
        try values.encode(friendPreferences, forKey: .friendPreferences)
        try values.encode(colocationEvents, forKey: .colocationEvents)
        try values.encode(colocationSessions, forKey: .colocationSessions)
        try values.encode(blockedPeople, forKey: .blockedPeople)
        try values.encodeIfPresent(lastSyncedAt, forKey: .lastSyncedAt)
        try values.encode(syncState, forKey: .syncState)
    }

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
        let sameCity = MockFriendData.sameCityFriends(
            from: friends,
            currentCountryCode: "US",
            now: now
        )
        let initialEvent = ColocationEvent(
            id: UUID(),
            deduplicationKey: "seed-new-york",
            city: MockFriendData.currentUserCity,
            friendIDs: sameCity.map(\.id),
            friendNames: sameCity.map(\.displayName),
            createdAt: now.addingTimeInterval(-14 * 24 * 3600),
            wasNotified: true
        )
        let pastTokyoEvent = ColocationEvent(
            id: UUID(),
            deduplicationKey: "seed-tokyo",
            city: "Tokyo",
            friendIDs: [UUID(uuidString: "10000000-0000-0000-0000-000000000002")!],
            friendNames: ["Lin Zhao"],
            createdAt: now.addingTimeInterval(-45 * 24 * 3600),
            wasNotified: true
        )
        let pastParisEvent = ColocationEvent(
            id: UUID(),
            deduplicationKey: "seed-paris",
            city: "Paris",
            friendIDs: [UUID(uuidString: "10000000-0000-0000-0000-000000000003")!],
            friendNames: ["Chloe Martin"],
            createdAt: now.addingTimeInterval(-90 * 24 * 3600),
            wasNotified: true
        )

        let initialSessions = sameCity.map { friend in
            ColocationSession(
                id: UUID(),
                friendID: friend.id,
                cityKey: CityIdentity.key(city: MockFriendData.currentUserCity, countryCode: "US"),
                enteredAt: now.addingTimeInterval(-14 * 24 * 3600),
                leftAt: nil
            )
        }

        let allColocationEvents = (sameCity.isEmpty ? [] : [initialEvent]) + [pastTokyoEvent, pastParisEvent]

        return AppSnapshot(
            schemaVersion: 2,
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
            colocationEvents: allColocationEvents,
            colocationSessions: initialSessions,
            blockedPeople: [],
            lastSyncedAt: now,
            syncState: .synced
        )
    }

    static func signedOutSnapshot() -> AppSnapshot {
        var snapshot = initialSnapshot()
        snapshot.isAuthenticated = false
        snapshot.friends = []
        snapshot.friendRequests = []
        snapshot.friendPreferences = []
        snapshot.colocationEvents = []
        snapshot.colocationSessions = []
        snapshot.blockedPeople = []
        snapshot.sharingPreferences = SharingPreferences(
            citySharingEnabled: false,
            backgroundUpdatesEnabled: false,
            notificationPreviewEnabled: false
        )
        snapshot.currentPresence = CurrentUserPresence(city: nil, countryCode: nil, updatedAt: nil, source: .demo)
        return snapshot
    }
}

enum CityIdentity {
    static func normalize(_ city: String) -> String {
        cityNameKey(city)
    }

    static func canonicalCity(_ city: String) -> String {
        let primaryPart = city.components(separatedBy: ",").first ?? city
        return primaryPart.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func key(city: String, countryCode: String?) -> String {
        let country = normalizedCountryCode(countryCode) ?? "--"
        return "\(country)|\(cityNameKey(city))"
    }

    static func matches(
        city: String?,
        countryCode: String?,
        otherCity: String?,
        otherCountryCode: String?
    ) -> Bool {
        guard let city, let otherCity else { return false }
        let c1 = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let c2 = otherCity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !c1.isEmpty, !c2.isEmpty else { return false }

        // If both have explicit non-empty country codes that differ, reject
        if let country1 = normalizedCountryCode(countryCode),
           let country2 = normalizedCountryCode(otherCountryCode),
           country1 != country2 {
            return false
        }

        // Direct key equality
        if cityNameKey(c1) == cityNameKey(c2) {
            return true
        }

        // Emblem alias matching (e.g. "NYC" vs "New York", "SF" vs "San Francisco")
        let emblem1 = CityEmblem.resolve(city: c1, countryCode: countryCode)
        let emblem2 = CityEmblem.resolve(city: c2, countryCode: otherCountryCode)
        if emblem1.cityID != "unknown" && emblem1.cityID == emblem2.cityID {
            return true
        }

        // Base name matching (e.g. "New York, NY" vs "New York")
        let base1 = canonicalCity(c1)
        let base2 = canonicalCity(c2)
        if cityNameKey(base1) == cityNameKey(base2) {
            return true
        }

        return false
    }

    private static func normalizedCountryCode(_ code: String?) -> String? {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            return nil
        }
        return code.uppercased()
    }

    private static func cityNameKey(_ city: String) -> String {
        canonicalCity(city)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased()
    }
}

enum ColocationEvaluator {
    static let defaultCooldown: TimeInterval = 6 * 60 * 60

    static func evaluate(
        snapshot: inout AppSnapshot,
        now: Date = Date(),
        cooldown: TimeInterval = defaultCooldown
    ) {
        guard snapshot.sharingPreferences.citySharingEnabled,
              let currentCity = snapshot.currentPresence.city,
              !currentCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            closeActiveSessions(snapshot: &snapshot, now: now)
            return
        }

        let cityKey = CityIdentity.key(
            city: currentCity,
            countryCode: snapshot.currentPresence.countryCode
        )
        let matches = snapshot.friends.filter { friend in
            snapshot.preference(for: friend.id).sharesMyCity
                && snapshot.preference(for: friend.id).sameCityAlertEnabled
                && friend.isSameCityEligible(at: now)
                && CityIdentity.matches(
                    city: friend.city,
                    countryCode: friend.countryCode,
                    otherCity: currentCity,
                    otherCountryCode: snapshot.currentPresence.countryCode
                )
        }
        let matchingIDs = Set(matches.map(\.id))

        for index in snapshot.colocationSessions.indices
        where snapshot.colocationSessions[index].isActive
            && (!matchingIDs.contains(snapshot.colocationSessions[index].friendID)
                || snapshot.colocationSessions[index].cityKey != cityKey) {
            snapshot.colocationSessions[index].leftAt = now
        }

        var enteredFriends: [FriendPresence] = []
        var enteredSessionIDs: [UUID] = []
        for friend in matches {
            let isAlreadyActive = snapshot.colocationSessions.contains {
                $0.friendID == friend.id && $0.cityKey == cityKey && $0.isActive
            }
            guard !isAlreadyActive else { continue }

            let lastExit = snapshot.colocationSessions
                .filter { $0.friendID == friend.id && $0.cityKey == cityKey }
                .compactMap(\.leftAt)
                .max()
            if let lastExit, now.timeIntervalSince(lastExit) < cooldown { continue }

            let session = ColocationSession(
                id: UUID(),
                friendID: friend.id,
                cityKey: cityKey,
                enteredAt: now,
                leftAt: nil
            )
            snapshot.colocationSessions.append(session)
            enteredFriends.append(friend)
            enteredSessionIDs.append(session.id)
        }

        snapshot.colocationSessions.removeAll { session in
            guard let leftAt = session.leftAt else { return false }
            return now.timeIntervalSince(leftAt) > 30 * 24 * 60 * 60
        }

        guard !enteredFriends.isEmpty else { return }
        let key = ([cityKey] + enteredSessionIDs.map(\.uuidString).sorted()).joined(separator: "|")
        snapshot.colocationEvents.insert(
            ColocationEvent(
                id: UUID(),
                deduplicationKey: key,
                city: CityIdentity.canonicalCity(currentCity),
                friendIDs: enteredFriends.map(\.id),
                friendNames: enteredFriends.map(\.displayName),
                createdAt: now,
                wasNotified: false
            ),
            at: 0
        )
    }

    private static func closeActiveSessions(snapshot: inout AppSnapshot, now: Date) {
        for index in snapshot.colocationSessions.indices where snapshot.colocationSessions[index].isActive {
            snapshot.colocationSessions[index].leftAt = now
        }
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
