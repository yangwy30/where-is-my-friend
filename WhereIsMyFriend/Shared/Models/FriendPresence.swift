import Foundation

enum PresenceSharingState: String, Codable, Hashable, Sendable {
    case active
    case paused
    case unavailable
}

enum PresenceFreshness: String, Codable, Hashable, Sendable {
    case fresh
    case aging
    case stale
    case unavailable
}

struct FriendPresence: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var username: String
    var city: String?
    var countryCode: String?
    var updatedAt: Date?
    var sharingState: PresenceSharingState
    var avatarPalette: Int
    var isFavorite: Bool

    init(
        id: UUID = UUID(),
        displayName: String,
        username: String,
        city: String?,
        countryCode: String?,
        updatedAt: Date?,
        sharingState: PresenceSharingState = .active,
        avatarPalette: Int = 0,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.city = city
        self.countryCode = countryCode
        self.updatedAt = updatedAt
        self.sharingState = sharingState
        self.avatarPalette = avatarPalette
        self.isFavorite = isFavorite
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "?" : String(letters)
    }

    var countryFlag: String {
        guard let countryCode, countryCode.count == 2 else { return "" }
        let base: UInt32 = 127_397
        return countryCode.uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(base + scalar.value).map(String.init)
        }.joined()
    }

    var cityDisplay: String {
        switch sharingState {
        case .paused:
            return String(localized: "Sharing paused")
        case .unavailable:
            return String(localized: "Location unavailable")
        case .active:
            guard let city else { return String(localized: "Location unavailable") }
            return [countryFlag, city].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    func freshness(at referenceDate: Date = Date()) -> PresenceFreshness {
        guard sharingState == .active, let updatedAt else { return .unavailable }
        let age = max(0, referenceDate.timeIntervalSince(updatedAt))
        if age < 2 * 60 * 60 { return .fresh }
        if age < 24 * 60 * 60 { return .aging }
        return .stale
    }

    func isSameCityEligible(at referenceDate: Date = Date()) -> Bool {
        sharingState == .active && city != nil && freshness(at: referenceDate) == .fresh
    }

    func relativeUpdateText(at referenceDate: Date = Date()) -> String {
        guard sharingState == .active, let updatedAt else { return "—" }
        let seconds = max(0, referenceDate.timeIntervalSince(updatedAt))
        let minutes = Int(seconds / 60)
        if minutes < 1 { return String(localized: "Now") }
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }

    func relativeUpdateLongText(at referenceDate: Date = Date()) -> String {
        guard sharingState == .active, let updatedAt else {
            return sharingState == .paused
                ? String(localized: "Sharing paused")
                : String(localized: "Location unavailable")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return String(localized: "Updated \(formatter.localizedString(for: updatedAt, relativeTo: referenceDate))")
    }
}
