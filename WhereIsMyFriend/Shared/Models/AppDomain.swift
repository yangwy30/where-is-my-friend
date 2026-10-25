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
    var administrativeArea: String? = nil
    var artworkRegion: CityRegion? {
        CityRegionCatalog.bundled.resolve(city: city, countryCode: countryCode, administrativeArea: administrativeArea)
    }
    var city: String?
    var countryCode: String?
    var updatedAt: Date?
    var source: PresenceSource

    var cityDisplay: String {
        CityLocationLabel.compact(city: city, countryCode: countryCode, administrativeArea: administrativeArea)
            ?? String(localized: "Location unavailable")
    }

    var fullCityDisplay: String {
        CityLocationLabel.full(city: city, countryCode: countryCode, administrativeArea: administrativeArea)
            ?? String(localized: "Location unavailable")
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
    var cityKey: String? = nil
    let id: UUID
    let deduplicationKey: String
    let city: String
    let friendIDs: [UUID]
    let friendNames: [String]
    let createdAt: Date
    var wasNotified: Bool

    var title: String { String(localized: "Together in \(city)") }

    var message: String {
        let names = friendNames.joined(separator: ", ")
        return String(localized: "You and \(names) are now in the same city.")
    }
}

enum FriendDetailLink {
    static func parse(_ url: URL) -> UUID? {
        guard url.scheme == SharedAppLink.urlScheme, url.host == "friend", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        guard path.count == 1 else { return nil }
        return UUID(uuidString: path[0])
    }
}

/// Notification links contain an identifier, never trusted display/location data.
enum FriendRequestNotificationLink {
    static func parse(_ url: URL, scheme: String = SharedAppLink.urlScheme) -> UUID? {
        guard url.scheme == scheme, url.host == "friend-requests", url.user == nil, url.password == nil,
              url.port == nil, url.query == nil, url.fragment == nil else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        guard path.count == 1 else { return nil }
        return UUID(uuidString: path[0])
    }
}

enum SameCityAlertLink {
    static func eventID(from url: URL, scheme: String = SharedAppLink.urlScheme) -> UUID? {
        guard url.scheme?.lowercased() == scheme.lowercased(), url.host == "events",
              url.user == nil, url.password == nil, url.port == nil,
              url.query == nil, url.fragment == nil else { return nil }
        let path = url.pathComponents.filter { $0 != "/" }
        guard path.count == 1 else { return nil }
        return UUID(uuidString: path[0])
    }
}

/// The home summary describes shared cities even when notification delivery is muted.
enum SameCityPresencePolicy {
    static func currentFriends(in snapshot: AppSnapshot, at now: Date = Date()) -> [FriendPresence] {
        guard snapshot.isAuthenticated, snapshot.sharingPreferences.citySharingEnabled else { return [] }
        return snapshot.friends.filter {
            !snapshot.blockedUserIDs.contains($0.id)
                && snapshot.preference(for: $0.id).sharesMyCity
                && PresenceMatchPolicy.matches(snapshot.currentPresence, $0, at: now)
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}

enum SameCityAlertPolicy {
    // A saved city is not live location. Older updates remain in history, but do
    // not get the stronger "here together" treatment in the new alert UI.
    static let freshnessWindow: TimeInterval = PresenceMatchPolicy.freshnessWindow

    static func visibleFriends(in snapshot: AppSnapshot) -> [FriendPresence] {
        guard snapshot.isAuthenticated, snapshot.sharingPreferences.citySharingEnabled else { return [] }
        let blocked = Set(snapshot.blockedUserIDs)
        return snapshot.friends.filter {
            let preference = snapshot.preference(for: $0.id)
            return !blocked.contains($0.id) && $0.sharingState == .active
                && preference.sharesMyCity && preference.sameCityAlertEnabled
        }
    }

    static func currentFriends(in snapshot: AppSnapshot, at now: Date = Date()) -> [FriendPresence] {
        guard isRecent(snapshot.currentPresence.updatedAt, at: now) else { return [] }
        return visibleFriends(in: snapshot).filter { friend in
            PresenceMatchPolicy.matches(snapshot.currentPresence, friend, at: now)
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    static func event(_ id: UUID, in snapshot: AppSnapshot) -> ColocationEvent? {
        let visible = Set(visibleFriends(in: snapshot).map(\.id))
        guard let event = snapshot.colocationEvents.first(where: { $0.id == id }),
              !event.friendIDs.isEmpty, event.friendIDs.allSatisfy(visible.contains) else { return nil }
        return event
    }

    static func isCurrent(_ event: ColocationEvent, in snapshot: AppSnapshot, at now: Date = Date()) -> Bool {
        guard self.event(event.id, in: snapshot) != nil, isRecent(event.createdAt, at: now),
              let key = CityIdentity.presenceKey(city: snapshot.currentPresence.city,
                  countryCode: snapshot.currentPresence.countryCode, administrativeArea: snapshot.currentPresence.administrativeArea),
              event.cityKey == key else { return false }
        let current = Set(currentFriends(in: snapshot, at: now).map(\.id))
        return event.friendIDs.allSatisfy(current.contains)
    }

    private static func isRecent(_ date: Date?, at now: Date) -> Bool {
        guard let date else { return false }
        return date <= now.addingTimeInterval(60) && now.timeIntervalSince(date) < freshnessWindow
    }
}

struct ColocationSession: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let friendID: UUID
    let cityKey: String
    var enteredAt: Date
    var leftAt: Date?
    /// Display name sent by the server; older payloads leave it out.
    var cityName: String? = nil

    var isActive: Bool { leftAt == nil }
}

enum ColocationHistoryPolicy {
    static func currentStart(friendID: UUID, cityKey: String?, sessions: [ColocationSession], at now: Date) -> Date? {
        guard let cityKey else { return nil }
        return sessions.filter {
            $0.friendID == friendID && $0.cityKey == cityKey && $0.isActive && $0.enteredAt <= now
        }.map(\.enteredAt).max()
    }

    static func pastEvents(_ events: [ColocationEvent], currentCityKey: String?,
                           currentStarts: [UUID: Date], at now: Date) -> [ColocationEvent] {
        var seenIDs = Set<UUID>()
        return events.sorted { $0.createdAt > $1.createdAt }.filter { event in
            guard event.createdAt <= now, seenIDs.insert(event.id).inserted else { return false }
            // A current event must fall within every participant's current stay.
            let belongsToCurrentStay = currentCityKey != nil && event.cityKey == currentCityKey
                && !event.friendIDs.isEmpty && event.friendIDs.allSatisfy { friendID in
                    guard let start = currentStarts[friendID] else { return false }
                    return event.createdAt >= start
                }
            return !belongsToCurrentStay
        }
    }
}

/// Same-city history told per friend. Back-to-back stays merge into one trip even when
/// the city changes (a road trip), and short pass-throughs don't name the trip.
enum SameCityMomentsPolicy {
    /// Stays in different cities closer together than this are one trip (a road trip); matches the alert cooldown.
    static let tripGap: TimeInterval = 6 * 60 * 60
    /// Stays in the same city closer together than this are one period: friends who live nearby
    /// drop in and out of a match daily, and that history should read as one stretch, not a log.
    static let sameCityGap: TimeInterval = 7 * 24 * 60 * 60
    /// Shorter matches are usually a city-boundary blip, not time spent together.
    static let minimumTrip: TimeInterval = 60 * 60
    /// A city names the trip only after this long there together.
    static let namedStop: TimeInterval = 2 * 60 * 60

    struct Stop: Hashable {
        let cityKey: String
        let name: String
        let countryCode: String?
        let region: String?
        var duration: TimeInterval
    }

    struct Trip: Identifiable, Hashable {
        let id: UUID
        let start: Date
        let end: Date
        let isActive: Bool
        /// The cities that name the trip, in the order you reached them.
        let stops: [Stop]
        let days: Set<Date>
    }

    struct FriendHistory: Identifiable {
        let friend: FriendPresence
        /// Newest first.
        let trips: [Trip]
        let days: Set<Date>
        let isHereNow: Bool
        let currentCity: String?

        var id: UUID { friend.id }
        var lastTogether: Date? { trips.first?.end }
        /// Each city once, newest first, with how many trips included it.
        var cities: [(stop: Stop, trips: Int)] {
            var order: [String] = []
            var found: [String: (stop: Stop, trips: Int)] = [:]
            for stop in trips.flatMap(\.stops) {
                if let hit = found[stop.cityKey] { found[stop.cityKey] = (hit.stop, hit.trips + 1) }
                else { order.append(stop.cityKey); found[stop.cityKey] = (stop, 1) }
            }
            return order.compactMap { found[$0] }
        }
    }

    struct Summary {
        let friends: [FriendHistory]
        let days: Int
        let cityCount: Int
    }

    static func summary(in snapshot: AppSnapshot, at now: Date = Date(), calendar: Calendar = .current) -> Summary {
        let blocked = Set(snapshot.blockedUserIDs)
        let here = Dictionary(uniqueKeysWithValues: SameCityPresencePolicy.currentFriends(in: snapshot, at: now).map { ($0.id, $0) })
        let names = cityNames(in: snapshot)
        let friends = snapshot.friends.filter { !blocked.contains($0.id) }.compactMap { friend -> FriendHistory? in
            let sessions = snapshot.colocationSessions
                .filter { $0.friendID == friend.id && $0.enteredAt <= now }
                .sorted { $0.enteredAt < $1.enteredAt }
            let isHere = here[friend.id] != nil
            let trips = trips(from: sessions, names: names, isHere: isHere, friend: friend,
                              presence: snapshot.currentPresence, now: now, calendar: calendar)
            guard !trips.isEmpty || isHere else { return nil }
            return FriendHistory(friend: friend, trips: trips, days: trips.reduce(into: Set()) { $0.formUnion($1.days) },
                                 isHereNow: isHere, currentCity: isHere ? snapshot.currentPresence.city : nil)
        }.sorted { lhs, rhs in
            if lhs.isHereNow != rhs.isHereNow { return lhs.isHereNow }
            return (lhs.lastTogether ?? .distantPast) > (rhs.lastTogether ?? .distantPast)
        }
        let days = friends.reduce(into: Set<Date>()) { $0.formUnion($1.days) }
        let cities = Set(friends.flatMap { $0.trips.flatMap { $0.stops.map(\.cityKey) } })
        return Summary(friends: friends, days: days.count, cityCount: cities.count)
    }

    private static func trips(from sessions: [ColocationSession], names: [String: String], isHere: Bool,
                              friend: FriendPresence, presence: CurrentUserPresence,
                              now: Date, calendar: Calendar) -> [Trip] {
        // An open stay that no longer matches has no recorded exit; end it at the last update either side sent.
        let staleEnd = [presence.updatedAt, friend.updatedAt].compactMap { $0 }.min()
        var groups: [[(session: ColocationSession, end: Date)]] = []
        for session in sessions {
            let end = max(session.enteredAt, min(now, session.leftAt ?? (isHere ? now : staleEnd ?? session.enteredAt)))
            if let group = groups.last, let last = group.map(\.end).max(),
               session.enteredAt.timeIntervalSince(last)
                   <= (group.last?.session.cityKey == session.cityKey ? sameCityGap : tripGap) {
                groups[groups.count - 1].append((session, end))
            } else {
                groups.append([(session, end)])
            }
        }
        return Array(groups.compactMap { group -> Trip? in
            guard let first = group.first, let end = group.map(\.end).max() else { return nil }
            let isActive = isHere && group.contains { $0.session.isActive }
            guard isActive || end.timeIntervalSince(first.session.enteredAt) >= minimumTrip else { return nil }
            var stops: [Stop] = []
            for item in group {
                let duration = item.end.timeIntervalSince(item.session.enteredAt)
                if let index = stops.firstIndex(where: { $0.cityKey == item.session.cityKey }) {
                    stops[index].duration += duration
                } else {
                    stops.append(stop(for: item.session, duration: duration, names: names))
                }
            }
            let named = stops.filter { $0.duration >= namedStop }
            let longest = stops.max { $0.duration < $1.duration }.map { [$0] } ?? []
            return Trip(id: first.session.id, start: first.session.enteredAt, end: end, isActive: isActive,
                        stops: named.isEmpty ? longest : named,
                        days: group.reduce(into: Set()) { $0.formUnion(days(from: $1.session.enteredAt, to: $1.end, calendar: calendar)) })
        }.reversed())
    }

    private static func days(from start: Date, to end: Date, calendar: Calendar) -> Set<Date> {
        var days = Set<Date>()
        var day = calendar.startOfDay(for: start)
        while day <= end {
            days.insert(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    /// Keys look like `v2|US|ca|losangeles`; the readable name comes from the server or a matching event.
    private static func stop(for session: ColocationSession, duration: TimeInterval, names: [String: String]) -> Stop {
        let parts = session.cityKey.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        let fallback = parts.count == 4 ? parts[3].capitalized : session.cityKey
        return Stop(cityKey: session.cityKey, name: session.cityName ?? names[session.cityKey] ?? fallback,
                    countryCode: parts.count == 4 ? parts[1] : nil, region: parts.count == 4 ? parts[2] : nil,
                    duration: duration)
    }

    private static func cityNames(in snapshot: AppSnapshot) -> [String: String] {
        var names: [String: String] = [:]
        for event in snapshot.colocationEvents { if let key = event.cityKey { names[key] = event.city } }
        let presence = snapshot.currentPresence
        if let city = presence.city, let key = CityIdentity.presenceKey(city: city, countryCode: presence.countryCode,
                                                                         administrativeArea: presence.administrativeArea) {
            names[key] = CityIdentity.canonicalCity(city)
        }
        return names
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
            now: now, currentAdministrativeArea: "NY", currentUpdatedAt: now
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
                administrativeArea: "NY",
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

enum PresenceMatchPolicy {
    static let freshnessWindow: TimeInterval = 24 * 60 * 60
    static func isRecent(_ date: Date?, at now: Date) -> Bool {
        guard let date else { return false }
        return date <= now.addingTimeInterval(60) && now.timeIntervalSince(date) < freshnessWindow
    }
    static func matches(_ presence: CurrentUserPresence, _ friend: FriendPresence, at now: Date) -> Bool {
        guard friend.sharingState == .active,
              isRecent(presence.updatedAt, at: now), isRecent(friend.updatedAt, at: now),
              let lhs = CityIdentity.presenceKey(city: presence.city, countryCode: presence.countryCode, administrativeArea: presence.administrativeArea),
              let rhs = CityIdentity.presenceKey(city: friend.city, countryCode: friend.countryCode, administrativeArea: friend.administrativeArea)
        else { return false }
        return lhs == rhs
    }
}

enum CityIdentity {
    // Exact geographic identity, separate from artwork aliases. SQL uses the same alphanumeric normalization.
    static func presencePart(_ value: String) -> String {
        String(value.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
    }
    static func presenceKey(city: String?, countryCode: String?, administrativeArea: String?) -> String? {
        guard let city, let countryCode, let administrativeArea else { return nil }
        let country = countryCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let name = presencePart(canonicalCity(city))
        var area = presencePart(administrativeArea)
        area = CityRegionCatalog.bundled.administrativeAliases?[country]?[area] ?? area
        guard country.range(of: "^[A-Z]{2}$", options: .regularExpression) != nil, !name.isEmpty, !area.isEmpty else { return nil }
        return "v2|\(country)|\(area)|\(name)"
    }

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

        // Artwork aliases are presentation only, never evidence of co-location.

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

        guard let cityKey = CityIdentity.presenceKey(city: currentCity,
            countryCode: snapshot.currentPresence.countryCode,
            administrativeArea: snapshot.currentPresence.administrativeArea) else {
            closeActiveSessions(snapshot: &snapshot, now: now); return
        }
        let matches = snapshot.friends.filter { friend in
            snapshot.preference(for: friend.id).sharesMyCity
                && friend.sharingState == .active
                && CityIdentity.presenceKey(city: friend.city, countryCode: friend.countryCode,
                                           administrativeArea: friend.administrativeArea) == cityKey
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
            guard !isAlreadyActive,
                  PresenceMatchPolicy.matches(snapshot.currentPresence, friend, at: now) else { continue }

            let lastExit = snapshot.colocationSessions
                .filter { $0.friendID == friend.id && $0.cityKey == cityKey }
                .compactMap(\.leftAt)
                .max()
            if let lastExit, now.timeIntervalSince(lastExit) < cooldown { continue }

            // Arriving together in the next city of a trip is not news; only the first city alerts.
            let continuesTrip = snapshot.colocationSessions.contains {
                $0.friendID == friend.id && $0.cityKey != cityKey
                    && $0.leftAt.map { now.timeIntervalSince($0) <= SameCityMomentsPolicy.tripGap } == true
            }
            let session = ColocationSession(
                id: UUID(),
                friendID: friend.id,
                cityKey: cityKey,
                enteredAt: now,
                leftAt: nil,
                cityName: CityIdentity.canonicalCity(currentCity)
            )
            snapshot.colocationSessions.append(session)
            if snapshot.preference(for: friend.id).sameCityAlertEnabled && !continuesTrip {
                enteredFriends.append(friend)
                enteredSessionIDs.append(session.id)
            }
        }

        snapshot.colocationSessions.removeAll { session in
            guard let leftAt = session.leftAt else { return false }
            return now.timeIntervalSince(leftAt) > 400 * 24 * 60 * 60
        }

        guard !enteredFriends.isEmpty else { return }
        let key = ([cityKey] + enteredSessionIDs.map(\.uuidString).sorted()).joined(separator: "|")
        snapshot.colocationEvents.insert(
            ColocationEvent(
                cityKey: cityKey,
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
