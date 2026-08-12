import SwiftUI
import WidgetKit

struct FriendWidgetEntryView: View {
    let entry: FriendWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallFriendWidget(entry: entry)
        case .systemMedium:
            MediumFriendWidget(entry: entry)
        case .systemLarge:
            LargeFriendWidget(entry: entry)
        default:
            MediumFriendWidget(entry: entry)
        }
    }
}

private struct SmallFriendWidget: View {
    let entry: FriendWidgetEntry

    private var friend: FriendPresence {
        entry.friends.first(where: { $0.username == "lin" })
            ?? entry.friends.first
            ?? MockFriendData.featuredFriend
    }

    var body: some View {
        Link(destination: URL(string: "whereismyfriend://friend/\(friend.id.uuidString)")!) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("Friends", systemImage: "location.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WIFTheme.fresh)
                    Spacer()
                    Text(friend.countryFlag)
                }

                Spacer()

                HStack(spacing: 8) {
                    WidgetAvatar(friend: friend, size: 30)
                    Text(friend.displayName.components(separatedBy: " ").first ?? friend.displayName)
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
                Spacer()
                Text("Updated now")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            ForEach(visibleFriends) { friend in
                Link(destination: URL(string: "whereismyfriend://friend/\(friend.id.uuidString)")!) {
                    WidgetFriendRow(friend: friend, referenceDate: entry.date)
                }
            }
        }
    }
}

private struct LargeFriendWidget: View {
    let entry: FriendWidgetEntry

    private var sameCityFriends: [FriendPresence] {
        MockFriendData.sameCityFriends(
            from: entry.friends,
            currentCity: entry.currentCity,
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
                Spacer()
                Text("\(Set(entry.friends.compactMap(\.city)).count) cities")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            if !sameCityFriends.isEmpty {
                WidgetSameCityMoment(friends: sameCityFriends, city: entry.currentCity)
            }

            VStack(spacing: 10) {
                ForEach(otherFriends) { friend in
                    Link(destination: URL(string: "whereismyfriend://friend/\(friend.id.uuidString)")!) {
                        WidgetFriendRow(friend: friend, referenceDate: entry.date)
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

    var body: some View {
        HStack(spacing: 9) {
            WidgetAvatar(friend: friend, size: 31)

            VStack(alignment: .leading, spacing: 0) {
                Text(friend.displayName.components(separatedBy: " ").first ?? friend.displayName)
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
        .accessibilityLabel("\(friend.displayName), \(friend.cityDisplay), \(friend.relativeUpdateLongText(at: referenceDate))")
    }
}

private struct WidgetSameCityMoment: View {
    let friends: [FriendPresence]
    let city: String

    var body: some View {
        HStack(spacing: 11) {
            HStack(spacing: -9) {
                ForEach(friends.prefix(3)) { friend in
                    WidgetAvatar(friend: friend, size: 34)
                        .overlay { Circle().stroke(WIFTheme.freshSurface, lineWidth: 2) }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Together in \(city)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("You and \(friends.prefix(3).map(\.displayName).joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(WIFTheme.eventGradient, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct WidgetAvatar: View {
    let friend: FriendPresence
    let size: CGFloat

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
                Text(friend.initials)
                    .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}
