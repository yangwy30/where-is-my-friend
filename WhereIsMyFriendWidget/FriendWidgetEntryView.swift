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

// MARK: - Solar Ambience Helper (10-15% Subtle Edge Mood)

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
        case .dawn: return Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.18)
        case .day: return Color(red: 0.38, green: 0.68, blue: 0.96).opacity(0.14)
        case .goldenHour: return Color(red: 0.98, green: 0.58, blue: 0.24).opacity(0.20)
        case .night: return Color(red: 0.35, green: 0.45, blue: 0.88).opacity(0.18)
        }
    }

    var symbol: String {
        switch self {
        case .dawn: return "sun.horizon.fill"
        case .day: return "sun.max.fill"
        case .goldenHour: return "sun.dust.fill"
        case .night: return "moon.stars.fill"
        }
    }
}

// MARK: - Presentation Helper

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
            return String(localized: "Friends are here too")
        }
        return friends.prefix(3).map(firstName).joined(separator: " · ")
    }
}

// MARK: - Medium Widget (Dual Orbit 3D 对望)

private struct MediumFriendWidget: View {
    let entry: FriendWidgetEntry

    private var primaryFriend: FriendPresence? {
        entry.friends.first
    }

    private var userCity: String {
        entry.currentCity.isEmpty ? "New York" : entry.currentCity
    }

    private var solarMood: SolarAmbience {
        SolarAmbience.current(for: entry.date)
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            if let friend = primaryFriend {
                dualOrbitView(friend: friend)
            } else {
                WidgetEmptyState(entry: entry)
            }
        }
    }

    @ViewBuilder
    private func dualOrbitView(friend: FriendPresence) -> some View {
        let friendCity = friend.city ?? "Tokyo"
        let isSameCity = CityIdentity.matches(
            city: friend.city,
            countryCode: friend.countryCode,
            otherCity: entry.currentCity,
            otherCountryCode: entry.currentCountryCode
        )

        HStack(spacing: 0) {
            // Left: User City Stage
            VStack(spacing: 3) {
                CityEmblemView(
                    city: userCity,
                    countryCode: entry.currentCountryCode,
                    size: 68
                )

                Text("Me")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WIFTheme.secondaryText)

                Text(userCity)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(solarMood.edgeTint.opacity(0.35))
            )

            // Center Connector: Minimal Orbit Arc
            VStack(spacing: 4) {
                if isSameCity {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                        Text("Together")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(WIFTheme.fresh)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(WIFTheme.fresh.opacity(0.18))
                            .overlay(Capsule().strokeBorder(WIFTheme.fresh.opacity(0.40), lineWidth: 1))
                    )
                } else {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(WIFTheme.secondaryText.opacity(0.40))
                            .frame(width: 4, height: 4)
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        WIFTheme.secondaryText.opacity(0.25),
                                        WIFTheme.fresh.opacity(0.50),
                                        WIFTheme.secondaryText.opacity(0.25)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 32, height: 1.5)
                        Circle()
                            .fill(WIFTheme.fresh.opacity(0.80))
                            .frame(width: 4, height: 4)
                    }

                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WIFTheme.secondaryText.opacity(0.60))
                }
            }
            .padding(.horizontal, 6)

            // Right: Featured Friend City Stage
            VStack(spacing: 3) {
                CityEmblemView(
                    city: friend.city,
                    countryCode: friend.countryCode,
                    size: 68
                )

                Text(entry.privacyMode == .full ? WidgetCityPresentation.firstName(friend) : "Friend")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WIFTheme.fresh)
                    .lineLimit(1)

                Text(friendCity)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSameCity ? WIFTheme.fresh.opacity(0.12) : Color.white.opacity(0.04))
            )
        }
        .padding(10)
    }
}

// MARK: - Small Widget (Hero Stage 3D 单人手办)

private struct SmallFriendWidget: View {
    let entry: FriendWidgetEntry

    private var sameCityFriends: [FriendPresence] {
        WidgetCityPresentation.sameCityFriends(in: entry)
    }

    private var displayCity: String {
        entry.currentCity.isEmpty ? "New York" : entry.currentCity
    }

    private var solarMood: SolarAmbience {
        SolarAmbience.current(for: entry.date)
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            VStack(spacing: 4) {
                HStack {
                    Label(displayCity, systemImage: "location.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: solarMood.symbol)
                        .font(.caption2)
                        .foregroundStyle(WIFTheme.secondaryText)
                }

                Spacer(minLength: 0)

                CityEmblemView(
                    city: entry.currentCity,
                    countryCode: entry.currentCountryCode,
                    size: 68
                )

                Spacer(minLength: 0)

                if !sameCityFriends.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 8.5, weight: .bold))
                        Text(sameCityFriends.count == 1
                             ? "\(WidgetCityPresentation.firstName(sameCityFriends[0])) here"
                             : "\(sameCityFriends.count) together")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(WIFTheme.fresh)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(WIFTheme.fresh.opacity(0.18))
                            .overlay(Capsule().strokeBorder(WIFTheme.fresh.opacity(0.35), lineWidth: 1))
                    )
                } else {
                    Text(entry.friends.isEmpty ? "No friends yet" : "\(entry.friends.count) friends around")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(WIFTheme.secondaryText)
                        .lineLimit(1)
                }
            }
            .padding(10)
        }
    }
}

// MARK: - Large Widget (Constellation 4-City Stage)

private struct LargeFriendWidget: View {
    let entry: FriendWidgetEntry

    private var visibleFriends: [FriendPresence] {
        Array(entry.friends.prefix(4))
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Friend Orbit")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                    Spacer()
                    Text("\(Set(entry.friends.compactMap(\.city)).count) cities")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(WIFTheme.secondaryText)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(visibleFriends) { friend in
                        WidgetCityStageCard(
                            friend: friend,
                            referenceDate: entry.date,
                            privacyMode: entry.privacyMode,
                            emblemSize: 66
                        )
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(10)
        }
    }
}

private struct WidgetCityStageCard: View {
    let friend: FriendPresence
    let referenceDate: Date
    let privacyMode: WidgetPrivacyMode
    let emblemSize: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            CityEmblemView(city: friend.city, countryCode: friend.countryCode, size: emblemSize)

            Text(privacyMode == .full ? WidgetCityPresentation.firstName(friend) : String(localized: "Friend"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(WIFTheme.primaryText)
                .lineLimit(1)

            Text(friend.city ?? friend.cityDisplay)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(WIFTheme.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }
}

// MARK: - Same City Widgets (Together Moments)

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
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WIFTheme.fresh)
                        Text(entry.currentCity)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WIFTheme.primaryText)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }

                    Spacer(minLength: 0)

                    CityEmblemView(
                        city: entry.currentCity,
                        countryCode: entry.currentCountryCode,
                        size: 68
                    )

                    Spacer(minLength: 0)

                    Text(WidgetCityPresentation.names(friends, privacyMode: entry.privacyMode))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.fresh)
                        .lineLimit(1)
                }
                .padding(10)
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
                HStack(spacing: 12) {
                    CityEmblemView(
                        city: entry.currentCity,
                        countryCode: entry.currentCountryCode,
                        size: 84
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Together in \(entry.currentCity)", systemImage: "sparkles")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.fresh)
                            .lineLimit(1)

                        Text("You and \(WidgetCityPresentation.names(friends, privacyMode: entry.privacyMode))")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(WIFTheme.primaryText)
                            .lineLimit(2)

                        Text(String(format: String(localized: "%lld friends in city now"), Int64(friends.count)))
                            .font(.caption2)
                            .foregroundStyle(WIFTheme.secondaryText)
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
                VStack(spacing: 8) {
                    Label("Together Moment", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WIFTheme.fresh)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.14), in: Capsule())

                    CityEmblemView(
                        city: entry.currentCity,
                        countryCode: entry.currentCountryCode,
                        size: 110
                    )

                    Text(entry.currentCity)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)

                    Text(WidgetCityPresentation.names(friends, privacyMode: entry.privacyMode))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WIFTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(String(format: String(localized: "%lld friends in your city"), Int64(friends.count)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WIFTheme.fresh)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
            }
        }
    }
}

private struct WidgetTogetherEmptyState: View {
    let entry: FriendWidgetEntry

    var body: some View {
        HStack(spacing: 12) {
            CityEmblemView(
                city: entry.currentCity,
                countryCode: entry.currentCountryCode,
                size: 68
            )

            VStack(alignment: .leading, spacing: 2) {
                Text("No friends here yet")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WIFTheme.primaryText)
                Text(entry.currentCity.isEmpty ? String(localized: "Open App to set city") : entry.currentCity)
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
            Label("Open Where Is My Friend", systemImage: "person.2.fill")
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .widgetAccentable()
        case .circular:
            Image(systemName: "person.2.fill")
                .font(.title3.weight(.semibold))
                .widgetAccentable()
                .accessibilityLabel("Open Where Is My Friend")
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

// MARK: - Generic States

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
                Text("Change Widget privacy in the App")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
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
            VStack(spacing: 8) {
                if entry.currentCity.isEmpty {
                    Image(systemName: "sparkles")
                        .font(.title)
                        .foregroundStyle(WIFTheme.fresh)
                        .padding(12)
                        .wifGlassSurface(tint: WIFTheme.eventBlue.opacity(0.14), in: Circle())
                } else {
                    CityEmblemView(
                        city: entry.currentCity,
                        countryCode: entry.currentCountryCode,
                        size: 78
                    )
                }

                Text(entry.currentCity.isEmpty ? String(localized: "Open Where Is My Friend") : entry.currentCity)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(entry.currentCity.isEmpty ? String(localized: "Sign in to refresh") : String(localized: "Friends will appear here"))
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
