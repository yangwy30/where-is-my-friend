import SwiftUI
import WidgetKit

extension FriendWidgetEntry {
    var homeContent: HomeWidgetContent {
        HomeWidgetContent(date: date, friends: friends,
            currentPresence: CurrentUserPresence(administrativeArea: currentAdministrativeArea,
                city: currentCity, countryCode: currentCountryCode,
                updatedAt: currentPresenceUpdatedAt, source: .foregroundLocation),
            privacyMode: privacyMode)
    }
}

struct FriendWidgetEntryView: View {
    let entry: FriendWidgetEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        switch family {
        case .accessoryRectangular: LockScreenRectangularFriendWidget(entry: entry)
        case .accessoryCircular: LockScreenCircularFriendWidget(entry: entry)
        default: FriendDirectoryWidget(content: entry.homeContent, size: family == .systemSmall ? .small : (family == .systemLarge ? .large : .medium))
        }
    }
}

struct SameCityWidgetEntryView: View {
    let entry: FriendWidgetEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        switch family {
        case .accessoryRectangular: LockScreenRectangularFriendWidget(entry: entry)
        case .accessoryCircular: LockScreenCircularFriendWidget(entry: entry)
        default: TogetherHomeWidget(content: entry.homeContent, size: family == .systemSmall ? .small : (family == .systemLarge ? .large : .medium))
        }
    }
}

private enum WidgetCityPresentation {
    static func sameCityFriends(in entry: FriendWidgetEntry) -> [FriendPresence] { entry.homeContent.sameCityFriends }
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
        friend.cityDisplay
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
        WidgetCityPresentation.sameCityFriends(in: entry)
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
            Label("Widget content hidden", systemImage: "eye.slash.fill")
                .font(.caption2)
                .lineLimit(2)
                .widgetAccentable()
        case .circular:
            Image(systemName: "eye.slash.fill")
                .font(.title3.weight(.semibold))
                .widgetAccentable()
                .accessibilityLabel("Widget content hidden")
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
