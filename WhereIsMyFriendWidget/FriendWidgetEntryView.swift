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
            } else if entry.friends.isEmpty {
                WidgetEmptyState()
            } else if family == .systemSmall {
                SmallFriendWidget(entry: entry)
            } else if family == .systemLarge {
                LargeFriendWidget(entry: entry)
            } else {
                MediumFriendWidget(entry: entry)
            }
        }
    }
}

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

    private var accessibilitySummary: String {
        let format = String(localized: "%lld friends in %@")
        return String.localizedStringWithFormat(format, Int64(sameCityFriends.count), city)
    }

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Group {
                if entry.privacyMode == .hideAll {
                    LockScreenPrivateState(layout: .circular)
                } else if entry.friends.isEmpty || city.isEmpty {
                    LockScreenEmptyState(layout: .circular)
                } else {
                    VStack(spacing: -2) {
                        Text("\(sameCityFriends.count)")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .contentTransition(.numericText())
                        Text(LockScreenWidgetPresentation.compactCityCode(city))
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(.primary)
                    .widgetAccentable()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilitySummary)
                }
            }
        }
        .widgetURL(SharedAppLink.make(host: "home"))
    }
}

private enum LockScreenStateLayout {
    case rectangular
    case circular
}

private struct LockScreenPrivateState: View {
    let layout: LockScreenStateLayout

    var body: some View {
        switch layout {
        case .rectangular:
            Label("Friend locations hidden", systemImage: "eye.slash.fill")
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .widgetAccentable()
        case .circular:
            Image(systemName: "eye.slash.fill")
                .font(.title3.weight(.semibold))
                .widgetAccentable()
                .accessibilityLabel("Friend locations hidden")
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

private struct SmallFriendWidget: View {
    let entry: FriendWidgetEntry

    private var friend: FriendPresence {
        entry.friends.first
            ?? MockFriendData.featuredFriend
    }

    var body: some View {
        Link(destination: SharedAppLink.make(host: "friend", path: friend.id.uuidString)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Friends", systemImage: "location.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WIFTheme.fresh)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.12), in: Capsule())
                    Spacer()
                    Text(friend.countryFlag)
                }

                Spacer()

                HStack(spacing: 8) {
                    WidgetAvatar(friend: friend, size: 30, showsInitials: entry.privacyMode == .full)
                    Text(entry.privacyMode == .full
                         ? (friend.displayName.components(separatedBy: " ").first ?? friend.displayName)
                         : "Friend")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)
                }

                Text(friend.city ?? friend.cityDisplay)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.top, 8)

                Text(friend.relativeUpdateLongText(at: entry.date))
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
    }
}

private struct MediumFriendWidget: View {
    let entry: FriendWidgetEntry

    private var visibleFriends: [FriendPresence] {
        Array(entry.friends.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Where they are", systemImage: "location.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.fresh)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.12), in: Capsule())
                Spacer()
                Text(snapshotAgeText)
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            ForEach(visibleFriends) { friend in
                Link(destination: SharedAppLink.make(host: "friend", path: friend.id.uuidString)) {
                    WidgetFriendRow(friend: friend, referenceDate: entry.date, privacyMode: entry.privacyMode)
                }
            }
        }
    }

    private var snapshotAgeText: String {
        guard let updatedAt = entry.snapshotUpdatedAt else { return "Open app" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: entry.date)
    }
}

private struct LargeFriendWidget: View {
    let entry: FriendWidgetEntry

    private var sameCityFriends: [FriendPresence] {
        MockFriendData.sameCityFriends(
            from: entry.friends,
            currentCity: entry.currentCity,
            currentCountryCode: entry.currentCountryCode,
            now: entry.date
        )
    }

    private var otherFriends: [FriendPresence] {
        Array(entry.friends.filter { friend in
            !sameCityFriends.contains(where: { $0.id == friend.id })
        }.prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Friends", systemImage: "location.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.fresh)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.12), in: Capsule())
                Spacer()
                Text("\(Set(entry.friends.compactMap(\.city)).count) cities")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            if !sameCityFriends.isEmpty {
                WidgetSameCityMoment(
                    friends: sameCityFriends,
                    city: entry.currentCity,
                    privacyMode: entry.privacyMode
                )
            }

            VStack(spacing: 10) {
                ForEach(otherFriends) { friend in
                    Link(destination: SharedAppLink.make(host: "friend", path: friend.id.uuidString)) {
                        WidgetFriendRow(friend: friend, referenceDate: entry.date, privacyMode: entry.privacyMode)
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }
}

private struct WidgetFriendRow: View {
    let friend: FriendPresence
    let referenceDate: Date
    let privacyMode: WidgetPrivacyMode

    var body: some View {
        HStack(spacing: 9) {
            WidgetAvatar(friend: friend, size: 31, showsInitials: privacyMode == .full)

            VStack(alignment: .leading, spacing: 0) {
                Text(privacyMode == .full
                     ? (friend.displayName.components(separatedBy: " ").first ?? friend.displayName)
                     : "Friend")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
                Text(friend.cityDisplay)
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(friend.relativeUpdateText(at: referenceDate))
                .font(.caption2.weight(.medium))
                .foregroundStyle(
                    friend.freshness(at: referenceDate) == .fresh
                        ? WIFTheme.fresh
                        : WIFTheme.secondaryText
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(privacyMode == .full ? friend.displayName : "Friend"), \(friend.cityDisplay), \(friend.relativeUpdateLongText(at: referenceDate))")
    }
}

private struct WidgetSameCityMoment: View {
    let friends: [FriendPresence]
    let city: String
    let privacyMode: WidgetPrivacyMode

    var body: some View {
        HStack(spacing: 11) {
            HStack(spacing: -9) {
                ForEach(friends.prefix(3)) { friend in
                    WidgetAvatar(friend: friend, size: 34, showsInitials: privacyMode == .full)
                        .overlay { Circle().stroke(WIFTheme.freshSurface, lineWidth: 2) }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Together in \(city)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                Text(privacyMode == .full
                     ? "You and \(friends.prefix(3).map(\.displayName).joined(separator: ", "))"
                     : "Friends nearby")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .wifGlassSurface(
            tint: WIFTheme.fresh.opacity(0.18),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

}

private struct WidgetAvatar: View {
    let friend: FriendPresence
    let size: CGFloat
    var showsInitials = true

    private var colors: [Color] {
        let palettes: [[Color]] = [
            [.pink.opacity(0.72), .red.opacity(0.62)],
            [.mint.opacity(0.78), .teal.opacity(0.68)],
            [.purple.opacity(0.72), .indigo.opacity(0.68)],
            [.yellow.opacity(0.78), .orange.opacity(0.74)],
            [.gray.opacity(0.76), .secondary.opacity(0.72)],
            [.blue.opacity(0.72), .indigo.opacity(0.72)],
            [.orange.opacity(0.72), .pink.opacity(0.66)]
        ]
        return palettes[abs(friend.avatarPalette) % palettes.count]
    }

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                if showsInitials {
                    Text(friend.initials)
                        .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: size * 0.34, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityHidden(true)
    }
}

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
    var body: some View {
        Link(destination: SharedAppLink.make(host: "home")) {
            VStack(spacing: 8) {
                Image(systemName: "person.2.circle")
                    .font(.title)
                    .foregroundStyle(WIFTheme.fresh)
                    .padding(12)
                    .wifGlassSurface(tint: WIFTheme.eventBlue.opacity(0.14), in: Circle())
                Text("Open Where Is My Friend")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text("Sign in to refresh")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
