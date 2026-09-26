import SwiftUI
import WidgetKit

enum HomeWidgetSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var previewSize: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 360, height: 170)
        case .large: CGSize(width: 360, height: 376)
        }
    }
    var title: LocalizedStringKey {
        switch self { case .small: "Small"; case .medium: "Medium"; case .large: "Large" }
    }
}

/// A common presentation model for the extension and the in-app preview.
struct HomeWidgetContent {
    var date: Date
    var friends: [FriendPresence]
    var currentPresence: CurrentUserPresence
    var privacyMode: WidgetPrivacyMode

    var sameCityFriends: [FriendPresence] {
        friends.filter { PresenceMatchPolicy.matches(currentPresence, $0, at: date) }
    }
    func name(for friend: FriendPresence, short: Bool = false) -> String {
        guard privacyMode == .full else { return String(localized: "Friend") }
        return short ? (friend.displayName.split(separator: " ").first.map(String.init) ?? friend.displayName) : friend.displayName
    }
    func initials(for friend: FriendPresence) -> String? {
        privacyMode == .full ? friend.initials : nil
    }
    var togetherNames: String {
        let people = sameCityFriends
        if privacyMode == .full, people.count == 1, let friend = people.first {
            return String(localized: "You & \(name(for: friend, short: true))")
        }
        return people.count == 1 ? String(localized: "You & a friend") : String(localized: "You + \(people.count) friends")
    }
    var togetherUpdatedAt: Date? {
        // The oldest observation participating in the match is the honest freshness label.
        ([currentPresence.updatedAt] + sameCityFriends.map(\.updatedAt)).compactMap { $0 }.min()
    }
}

enum HomeWidgetPalette {
    private static func color(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: Double((value >> 16) & 255) / 255,
                           green: Double((value >> 8) & 255) / 255,
                           blue: Double(value & 255) / 255, alpha: 1)
        })
    }
    static let paper = color(0xFCFBF5, 0x202923)
    static let together = color(0xE8EDE2, 0x263D31)
    static let ink = color(0x20392D, 0xECF0DF)
    static let muted = color(0x657569, 0xA6B4A8)
    static let rule = color(0xE2E6DB, 0x3A453D)
    static let accent = color(0x247450, 0xA4CFB3)
    static let sage = color(0xE6ECDF, 0x36463A)
    static let rose = color(0xEDE3DF, 0x50423F)
    static let blue = color(0xE1E7E8, 0x35444C)
    static func avatar(_ index: Int) -> Color {
        switch (index % 3 + 3) % 3 { case 1: rose; case 2: blue; default: sage }
    }
}

struct FriendDirectoryWidget: View {
    let content: HomeWidgetContent
    let size: HomeWidgetSize
    @Environment(\.dynamicTypeSize) private var typeSize

    private var visibleFriends: [FriendPresence] { Array(content.friends.prefix(typeSize.isAccessibilitySize ? 3 : 4)) }
    private var sameCityIDs: Set<UUID> { Set(content.sameCityFriends.map(\.id)) }

    var body: some View {
        Group {
            if content.privacyMode == .hideAll {
                HomeWidgetPlaceholder(hidden: true)
            } else if let first = content.friends.first {
                Link(destination: SharedAppLink.make(host: "home")) {
                    switch size {
                    case .small: small(first)
                    case .medium: medium
                    case .large: large
                    }
                }
                .buttonStyle(.plain)
            } else {
                HomeWidgetPlaceholder(hidden: false)
            }
        }
        .foregroundStyle(HomeWidgetPalette.ink)
        .padding(4)
    }

    private func small(_ friend: FriendPresence) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HomeWidgetAvatar(initials: content.initials(for: friend), palette: friend.avatarPalette, size: 26)
                Spacer(minLength: 4)
                if sameCityIDs.contains(friend.id) { Image(systemName: "person.2").foregroundStyle(HomeWidgetPalette.accent).font(.caption) }
            }
            Spacer(minLength: 0)
            Text(content.name(for: friend, short: true)).font(.subheadline.weight(.semibold)).lineLimit(1)
            Text(friend.cityDisplay).font(.system(size: 21, weight: .semibold)).tracking(-0.6)
                .lineLimit(2).minimumScaleFactor(0.78).fixedSize(horizontal: false, vertical: true).layoutPriority(1)
            Spacer(minLength: 0)
            Text(sameCityIDs.contains(friend.id) ? String(localized: "Same city as you") : friend.relativeUpdateLongText(at: content.date))
                .font(.caption2).foregroundStyle(HomeWidgetPalette.muted).lineLimit(1).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(friend))
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeWidgetHeading(title: "ACROSS US", symbol: "person.2", isBrand: true)
            let people = Array(content.friends.prefix(4))
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 12) {
                ForEach(people) { friend in row(friend, compact: true) }
            }
            Spacer(minLength: 0)
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeWidgetHeading(title: "ACROSS US", symbol: "person.2", isBrand: true)
            Text("Friends,\nnear and far.")
                .font(.system(size: 28, weight: .semibold)).tracking(-0.9)
                .lineLimit(2).minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                ForEach(Array(visibleFriends.enumerated()), id: \.element.id) { index, friend in
                    if index > 0 { Rectangle().fill(HomeWidgetPalette.rule).frame(height: 0.5) }
                    row(friend, compact: false).frame(maxHeight: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            HStack {
                Text("Shared cities")
                Spacer()
                Text(content.friends.count == 1 ? String(localized: "1 friend") : String(localized: "\(content.friends.count) friends"))
            }
            .font(.caption2).foregroundStyle(HomeWidgetPalette.muted)
        }
    }

    private func row(_ friend: FriendPresence, compact: Bool) -> some View {
        HStack(spacing: compact ? 7 : 10) {
            HomeWidgetAvatar(initials: content.initials(for: friend), palette: friend.avatarPalette, size: compact ? 28 : 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(content.name(for: friend, short: compact)).font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold)).lineLimit(1)
                Text(friend.cityDisplay).font(.caption2).foregroundStyle(HomeWidgetPalette.muted).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !compact {
                if sameCityIDs.contains(friend.id) {
                    Text("Here too").font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .foregroundStyle(HomeWidgetPalette.accent).background(HomeWidgetPalette.sage, in: RoundedRectangle(cornerRadius: 5))
                        .fixedSize()
                } else {
                    Text(friend.relativeUpdateText(at: content.date)).font(.caption2).foregroundStyle(HomeWidgetPalette.muted).fixedSize()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(friend))
    }

    private func accessibilityLabel(_ friend: FriendPresence) -> String {
        [content.name(for: friend), friend.fullCityDisplay,
         sameCityIDs.contains(friend.id) ? String(localized: "Same city as you") : friend.relativeUpdateLongText(at: content.date)].joined(separator: ", ")
    }
}

struct TogetherHomeWidget: View {
    let content: HomeWidgetContent
    let size: HomeWidgetSize
    private var people: [FriendPresence] { content.sameCityFriends }
    private var city: String { content.currentPresence.city ?? "" }

    var body: some View {
        Group {
            if content.privacyMode == .hideAll {
                HomeWidgetPlaceholder(hidden: true)
            } else {
                Link(destination: SharedAppLink.make(host: "home")) {
                    if people.isEmpty { empty } else { populated }
                }.buttonStyle(.plain)
            }
        }
        .foregroundStyle(HomeWidgetPalette.ink).padding(4)
    }

    private var populated: some View {
        VStack(alignment: size == .medium ? .leading : .center, spacing: size == .large ? 14 : 5) {
            HomeWidgetHeading(title: "Here together", symbol: "arrow.up.right")
            if size == .medium {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        cityTitle
                        Text(content.togetherNames).font(.caption.weight(.medium)).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    avatars
                }.frame(maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
                cityTitle
                if size == .large {
                    Text(CityLocationLabel.full(city: city, countryCode: content.currentPresence.countryCode,
                        administrativeArea: content.currentPresence.administrativeArea) ?? city)
                        .font(.caption).foregroundStyle(HomeWidgetPalette.muted).lineLimit(2).multilineTextAlignment(.center)
                }
                avatars.padding(.top, size == .large ? 5 : 0)
                Text(content.togetherNames).font(.caption.weight(.medium)).lineLimit(2).multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            if size != .small {
                if size == .large { Rectangle().fill(HomeWidgetPalette.rule).frame(height: 0.5) }
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text("Same city. Good company.")
                        Spacer(minLength: 8)
                        updatedLabel
                    }
                    updatedLabel
                }
                .font(.caption2).foregroundStyle(HomeWidgetPalette.muted)
            }
        }
    }

    private var cityTitle: some View {
        Text(city).font(.system(size: size == .large ? 40 : (size == .medium ? 29 : 24), weight: .regular, design: .serif))
            .tracking(-0.7).lineLimit(2).minimumScaleFactor(0.72)
            .multilineTextAlignment(size == .medium ? .leading : .center)
            .widgetAccentable()
    }

    private var avatars: some View {
        let diameter: CGFloat = size == .large ? 52 : (size == .medium ? 38 : 26)
        return HStack(spacing: -7) {
            HomeWidgetAvatar(initials: nil, palette: 0, size: diameter, symbol: "person.fill", emphasized: true)
                .overlay(Circle().strokeBorder(HomeWidgetPalette.together, lineWidth: 2))
            ForEach(people.prefix(size == .small ? 1 : 2)) { friend in
                HomeWidgetAvatar(initials: content.initials(for: friend), palette: friend.avatarPalette + 1, size: diameter)
                    .overlay(Circle().strokeBorder(HomeWidgetPalette.together, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }

    private var updatedLabel: some View {
        let seconds = content.togetherUpdatedAt.map { max(0, content.date.timeIntervalSince($0)) } ?? 0
        let minutes = Int(seconds / 60)
        return Text(minutes < 1 ? String(localized: "Updated just now") : String(localized: "Updated \(minutes) min ago"))
            .lineLimit(1)
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 10) {
            HomeWidgetHeading(title: "Here together", symbol: "person.2")
            Spacer(minLength: 0)
            Text("More chances\nto meet.").font(.system(size: size == .small ? 22 : 28, weight: .regular, design: .serif)).lineLimit(2).minimumScaleFactor(0.8)
            Text("Friends in your city will appear here.").font(.caption).foregroundStyle(HomeWidgetPalette.muted).lineLimit(3)
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct HomeWidgetHeading: View {
    let title: LocalizedStringKey
    let symbol: String
    var isBrand = false
    var body: some View {
        HStack {
            Group {
                if isBrand { Text(verbatim: "ACROSS US") } else { Text(title) }
            }.textCase(.uppercase).tracking(1.4).font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            Image(systemName: symbol).font(.caption).widgetAccentable().accessibilityHidden(true)
        }.foregroundStyle(HomeWidgetPalette.muted)
    }
}

private struct HomeWidgetAvatar: View {
    let initials: String?
    let palette: Int
    let size: CGFloat
    var symbol = "person.fill"
    var emphasized = false
    var body: some View {
        Group {
            if let initials { Text(initials).font(.system(size: size * 0.3, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7) }
            else { Image(systemName: symbol).font(.system(size: size * 0.4)) }
        }
        .foregroundStyle(emphasized ? HomeWidgetPalette.paper : HomeWidgetPalette.ink)
        .frame(width: size, height: size).background(emphasized ? HomeWidgetPalette.accent : HomeWidgetPalette.avatar(palette), in: Circle())
        .accessibilityHidden(true)
    }
}

private struct HomeWidgetPlaceholder: View {
    let hidden: Bool
    var body: some View {
        Link(destination: SharedAppLink.make(host: hidden ? "sharing" : "home")) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: hidden ? "eye.slash" : "person.2").font(.title3).foregroundStyle(HomeWidgetPalette.accent)
                Text(hidden ? String(localized: "Friend locations hidden") : String(localized: "Friends will appear here"))
                    .font(.headline).lineLimit(3).minimumScaleFactor(0.8)
                Text("Open Across Us").font(.caption).foregroundStyle(HomeWidgetPalette.muted)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }.buttonStyle(.plain)
    }
}
