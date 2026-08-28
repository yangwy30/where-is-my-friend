import SwiftUI
import WidgetKit

struct FriendWidgetEntryView: View {
    let entry: FriendWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularFriendWidget(entry: entry)
        case .accessoryCircular:
            LockScreenCircularFriendWidget(entry: entry)
        default:
            if entry.privacyMode == .hideAll {
                WidgetPrivateState()
            } else if family == .systemSmall {
                SmallFriendWidget(entry: entry)
            } else if entry.friends.isEmpty {
                WidgetEmptyState(entry: entry)
            } else if family == .systemLarge {
                LargeFriendWidget(entry: entry)
            } else {
                MediumFriendWidget(entry: entry)
            }
        }
    }
}

struct SameCityWidgetEntryView: View {
    let entry: FriendWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockScreenRectangularFriendWidget(entry: entry)
        case .accessoryCircular:
            LockScreenCircularFriendWidget(entry: entry)
        default:
            if entry.privacyMode == .hideAll {
                WidgetPrivateState()
            } else if family == .systemSmall {
                SmallSameCityWidget(entry: entry)
            } else if family == .systemLarge {
                LargeSameCityWidget(entry: entry)
            } else {
                MediumSameCityWidget(entry: entry)
            }
        }
    }
}

// MARK: - Solar Ambience (8-12% Subtle Edge Halo, No Weather Clutter)

enum SolarAmbience {
    case dawn
    case day
    case goldenHour
    case night

    static func current(for date: Date = Date()) -> SolarAmbience {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<9: return .dawn
        case 9..<17: return .day
        case 17..<20: return .goldenHour
        default: return .night
        }
    }

    var edgeTint: Color {
        switch self {
        case .dawn: return Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.12)
        case .day: return Color(red: 0.38, green: 0.68, blue: 0.96).opacity(0.10)
        case .goldenHour: return Color(red: 0.98, green: 0.58, blue: 0.24).opacity(0.12)
        case .night: return Color(red: 0.35, green: 0.45, blue: 0.88).opacity(0.12)
        }
    }
}

// MARK: - Presentation Helpers

enum WidgetCityPresentation {
    static func sameCityFriends(in entry: FriendWidgetEntry) -> [FriendPresence] {
        MockFriendData.sameCityFriends(
            from: entry.friends,
            currentCity: entry.currentCity,
            currentCountryCode: entry.currentCountryCode,
            now: entry.date
        )
    }

    static func firstName(_ friend: FriendPresence) -> String {
        friend.displayName.components(separatedBy: " ").first ?? friend.displayName
    }

    static func names(_ friends: [FriendPresence], privacyMode: WidgetPrivacyMode) -> String {
        guard privacyMode == .full else {
            return String(localized: "Friends")
        }
        return friends.prefix(2).map(firstName).joined(separator: " · ")
    }
}

// MARK: - Medium Widget (Dual Orbit: Smart Cross-City vs Same-City Merge)

private struct MediumFriendWidget: View {
    let entry: FriendWidgetEntry

    private var primaryFriend: FriendPresence? {
        entry.friends.first
    }

    private var sameCityFriends: [FriendPresence] {
        WidgetCityPresentation.sameCityFriends(in: entry)
    }

    private var userCity: String {
        entry.currentCity.isEmpty ? "New York" : entry.currentCity
    }

    private var isSameCity: Bool {
        guard let friend = primaryFriend else { return false }
        return CityIdentity.matches(
            city: friend.city,
            countryCode: friend.countryCode,
            otherCity: entry.currentCity,
            otherCountryCode: entry.currentCountryCode
        ) || !sameCityFriends.isEmpty
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            if isSameCity {
                sameCityMergedView
            } else if let friend = primaryFriend {
                crossCityOrbitView(friend: friend)
            } else {
                WidgetEmptyState(entry: entry)
            }
        }
    }

    // 🟢 Same-City: Single Unified Hero Stage (Zero Redundancy)
    private var sameCityMergedView: some View {
        let city = entry.currentCity.isEmpty ? "New York" : entry.currentCity
        let count = max(1, sameCityFriends.count)
        let friendNames = sameCityFriends.isEmpty
            ? (primaryFriend != nil ? WidgetCityPresentation.firstName(primaryFriend!) : "Friend")
            : WidgetCityPresentation.names(sameCityFriends, privacyMode: entry.privacyMode)

        return HStack(spacing: 16) {
            CityEmblemView(
                city: city,
                countryCode: entry.currentCountryCode,
                size: 86
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(city)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)

                Text(friendNames)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(WIFTheme.fresh)
                        .frame(width: 5, height: 5)

                    Text(count == 1 ? "Together" : "\(count) together")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WIFTheme.fresh)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(
                    Capsule()
                        .fill(WIFTheme.fresh.opacity(0.16))
                )
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(WIFTheme.fresh.opacity(0.08))
        )
    }

    // ✈️ Cross-City: Dual 3D Orbit (Clean Bridge)
    private func crossCityOrbitView(friend: FriendPresence) -> some View {
        let friendCity = friend.city ?? "Tokyo"
        let friendName = entry.privacyMode == .full
            ? WidgetCityPresentation.firstName(friend)
            : "Friend"

        return HStack(spacing: 0) {
            // Left: User City
            VStack(spacing: 4) {
                CityEmblemView(
                    city: userCity,
                    countryCode: entry.currentCountryCode,
                    size: 68
                )

                Text(userCity)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)

            // Center: Minimal Orbit Track
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(WIFTheme.secondaryText.opacity(0.35))
                        .frame(width: 3.5, height: 3.5)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    WIFTheme.secondaryText.opacity(0.20),
                                    WIFTheme.fresh.opacity(0.45),
                                    WIFTheme.secondaryText.opacity(0.20)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 28, height: 1.5)

                    Circle()
                        .fill(WIFTheme.fresh.opacity(0.75))
                        .frame(width: 3.5, height: 3.5)
                }
            }
            .padding(.horizontal, 4)

            // Right: Friend City
            VStack(spacing: 4) {
                CityEmblemView(
                    city: friend.city,
                    countryCode: friend.countryCode,
                    size: 68
                )

                VStack(spacing: 1) {
                    Text(friendCity)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)

                    Text(friendName)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(WIFTheme.fresh)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(10)
    }
}

// MARK: - Small Widget (Friend is the Hero Protagonist)

private struct SmallFriendWidget: View {
    let entry: FriendWidgetEntry

    private var targetFriend: FriendPresence? {
        entry.friends.first
    }

    private var sameCityFriends: [FriendPresence] {
        WidgetCityPresentation.sameCityFriends(in: entry)
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            if !sameCityFriends.isEmpty {
                // Same city state
                let city = entry.currentCity.isEmpty ? "New York" : entry.currentCity
                let name = WidgetCityPresentation.firstName(sameCityFriends[0])
                VStack(spacing: 3) {
                    CityEmblemView(
                        city: city,
                        countryCode: entry.currentCountryCode,
                        size: 70
                    )

                    Text(city)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)

                    Text("\(name) · Together")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.fresh)
                        .lineLimit(1)
                }
                .padding(8)
            } else if let friend = targetFriend {
                // Focus on friend's city
                let city = friend.city ?? friend.cityDisplay
                let name = entry.privacyMode == .full ? WidgetCityPresentation.firstName(friend) : "Friend"
                VStack(spacing: 3) {
                    CityEmblemView(
                        city: friend.city,
                        countryCode: friend.countryCode,
                        size: 70
                    )

                    Text(city)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)

                    Text(name)
                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(WIFTheme.fresh)
                        .lineLimit(1)
                }
                .padding(8)
            } else {
                WidgetEmptyState(entry: entry)
            }
        }
    }
}

// MARK: - Large Widget (Constellation: 1 Hero Stage + 3 Companion Nodes)

private struct LargeFriendWidget: View {
    let entry: FriendWidgetEntry

    private var heroFriend: FriendPresence? {
        entry.friends.first
    }

    private var companionFriends: [FriendPresence] {
        Array(entry.friends.dropFirst().prefix(3))
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            VStack(spacing: 12) {
                // Top Hero Centerpiece
                if let hero = heroFriend {
                    VStack(spacing: 4) {
                        CityEmblemView(
                            city: hero.city,
                            countryCode: hero.countryCode,
                            size: 80
                        )

                        Text(hero.city ?? hero.cityDisplay)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.primaryText)
                            .lineLimit(1)

                        Text(entry.privacyMode == .full ? hero.displayName : "Friend")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(WIFTheme.fresh)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }

                // Bottom Orbit Nodes (3 Companion Cities)
                if !companionFriends.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(companionFriends) { friend in
                            VStack(spacing: 2) {
                                CityEmblemView(
                                    city: friend.city,
                                    countryCode: friend.countryCode,
                                    size: 48
                                )

                                Text(friend.city ?? "—")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(WIFTheme.primaryText)
                                    .lineLimit(1)

                                Text(entry.privacyMode == .full ? WidgetCityPresentation.firstName(friend) : "Friend")
                                    .font(.system(size: 8.5, weight: .medium))
                                    .foregroundStyle(WIFTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                            )
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}

// MARK: - Same City Dedicated Widgets

private struct SmallSameCityWidget: View {
    let entry: FriendWidgetEntry

    private var friends: [FriendPresence] {
        WidgetCityPresentation.sameCityFriends(in: entry)
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            if friends.isEmpty {
                WidgetTogetherEmptyState(entry: entry)
            } else {
                let city = entry.currentCity.isEmpty ? "New York" : entry.currentCity
                VStack(spacing: 3) {
                    CityEmblemView(
                        city: entry.currentCity,
                        countryCode: entry.currentCountryCode,
                        size: 70
                    )

                    Text(city)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)

                    Text("\(WidgetCityPresentation.names(friends, privacyMode: entry.privacyMode)) · \(friends.count) together")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.fresh)
                        .lineLimit(1)
                }
                .padding(8)
            }
        }
    }
}

private struct MediumSameCityWidget: View {
    let entry: FriendWidgetEntry

    private var friends: [FriendPresence] {
        WidgetCityPresentation.sameCityFriends(in: entry)
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            if friends.isEmpty {
                WidgetTogetherEmptyState(entry: entry)
            } else {
                let city = entry.currentCity.isEmpty ? "New York" : entry.currentCity
                HStack(spacing: 16) {
                    CityEmblemView(
                        city: entry.currentCity,
                        countryCode: entry.currentCountryCode,
                        size: 86
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(city)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.primaryText)
                            .lineLimit(1)

                        Text(WidgetCityPresentation.names(friends, privacyMode: entry.privacyMode))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WIFTheme.secondaryText)
                            .lineLimit(1)

                        Text("\(friends.count) together")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WIFTheme.fresh)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(WIFTheme.fresh.opacity(0.16)))
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
    }
}

private struct LargeSameCityWidget: View {
    let entry: FriendWidgetEntry

    private var friends: [FriendPresence] {
        WidgetCityPresentation.sameCityFriends(in: entry)
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            if friends.isEmpty {
                WidgetTogetherEmptyState(entry: entry)
            } else {
                let city = entry.currentCity.isEmpty ? "New York" : entry.currentCity
                VStack(spacing: 8) {
                    CityEmblemView(
                        city: entry.currentCity,
                        countryCode: entry.currentCountryCode,
                        size: 112
                    )

                    Text(city)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)

                    Text(WidgetCityPresentation.names(friends, privacyMode: entry.privacyMode))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WIFTheme.secondaryText)
                        .lineLimit(1)

                    Text("\(friends.count) together")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WIFTheme.fresh)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(WIFTheme.fresh.opacity(0.16)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(14)
            }
        }
    }
}

private struct WidgetTogetherEmptyState: View {
    let entry: FriendWidgetEntry

    var body: some View {
        let city = entry.currentCity.isEmpty ? "New York" : entry.currentCity
        HStack(spacing: 12) {
            CityEmblemView(
                city: entry.currentCity,
                countryCode: entry.currentCountryCode,
                size: 68
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(city)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("No friends here yet")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Lock Screen & StandBy Accessories

private struct LockScreenRectangularFriendWidget: View {
    let entry: FriendWidgetEntry

    private var visibleFriends: [FriendPresence] {
        Array(entry.friends.prefix(2))
    }

    var body: some View {
        Group {
            if entry.privacyMode == .hideAll {
                LockScreenPrivateState(layout: .rectangular)
            } else if visibleFriends.isEmpty {
                LockScreenEmptyState(layout: .rectangular)
            } else {
                HStack(spacing: 8) {
                    if let firstFriend = visibleFriends.first {
                        LockScreenFriendColumn(
                            friend: firstFriend,
                            privacyMode: entry.privacyMode
                        )
                    }

                    if visibleFriends.count > 1 {
                        Divider()
                        LockScreenFriendColumn(
                            friend: visibleFriends[1],
                            privacyMode: entry.privacyMode
                        )
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .widgetURL(SharedAppLink.make(host: "home"))
    }
}

private struct LockScreenFriendColumn: View {
    let friend: FriendPresence
    let privacyMode: WidgetPrivacyMode

    private var shortName: String {
        guard privacyMode == .full else { return String(localized: "Friend") }
        return friend.displayName.components(separatedBy: " ").first ?? friend.displayName
    }

    private var location: String {
        friend.city ?? friend.cityDisplay
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(shortName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(location)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .widgetAccentable()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(shortName), \(location)")
    }
}

private struct LockScreenCircularFriendWidget: View {
    let entry: FriendWidgetEntry

    private var sameCityFriends: [FriendPresence] {
        MockFriendData.sameCityFriends(
            from: entry.friends,
            currentCity: entry.currentCity,
            currentCountryCode: entry.currentCountryCode,
            now: entry.date
        )
    }

    private var city: String {
        entry.currentCity.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Group {
                if entry.privacyMode == .hideAll {
                    Image(systemName: "eye.slash.fill")
                        .font(.headline)
                        .widgetAccentable()
                } else if !sameCityFriends.isEmpty {
                    VStack(spacing: 0) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2.weight(.bold))
                            .widgetAccentable()
                        Text("\(sameCityFriends.count)")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .widgetAccentable()
                    }
                } else {
                    VStack(spacing: 0) {
                        Text(LockScreenWidgetPresentation.compactCityCode(city))
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .widgetAccentable()
                        Text("\(entry.friends.count)")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .widgetURL(SharedAppLink.make(host: "home"))
    }
}

private struct LockScreenPrivateState: View {
    let layout: LockScreenStateLayout

    var body: some View {
        switch layout {
        case .rectangular:
            Label("Privacy mode active", systemImage: "eye.slash.fill")
                .font(.caption2)
                .lineLimit(2)
                .widgetAccentable()
        case .circular:
            Image(systemName: "eye.slash.fill")
                .font(.title3.weight(.semibold))
                .widgetAccentable()
                .accessibilityLabel("Privacy mode active")
        }
    }
}

private struct LockScreenEmptyState: View {
    let layout: LockScreenStateLayout

    var body: some View {
        switch layout {
        case .rectangular:
            Label("Open Across Us", systemImage: "person.2.fill")
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .widgetAccentable()
        case .circular:
            Image(systemName: "person.2.fill")
                .font(.title3.weight(.semibold))
                .widgetAccentable()
                .accessibilityLabel("Open Across Us")
        }
    }
}

private enum LockScreenStateLayout {
    case rectangular
    case circular
}

private enum LockScreenWidgetPresentation {
    static func compactCityCode(_ city: String) -> String {
        let words = city
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)

        guard let firstWord = words.first else { return "—" }
        if words.count == 1 {
            return String(firstWord.prefix(3)).uppercased()
        }
        return words.prefix(3).compactMap(\.first).map(String.init).joined().uppercased()
    }
}

// MARK: - Generic Empty / Private States

private struct WidgetPrivateState: View {
    var body: some View {
        Link(destination: SharedAppLink.make(host: "sharing")) {
            VStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                    .font(.title)
                    .foregroundStyle(WIFTheme.fresh)
                    .padding(12)
                    .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.14), in: Circle())
                Text("Friend locations hidden")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct WidgetEmptyState: View {
    let entry: FriendWidgetEntry

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            let city = entry.currentCity.isEmpty ? "New York" : entry.currentCity
            VStack(spacing: 6) {
                CityEmblemView(
                    city: city,
                    countryCode: entry.currentCountryCode,
                    size: 68
                )

                Text(city)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text("Friends will appear here")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
