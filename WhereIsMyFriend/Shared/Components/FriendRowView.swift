import SwiftUI

struct FriendRowView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let friend: FriendPresence
    let referenceDate: Date

    private var freshness: PresenceFreshness {
        friend.freshness(at: referenceDate)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(friend.displayName), @\(friend.username), \(friend.cityDisplay), \(friend.relativeUpdateLongText(at: referenceDate))"
        )
    }

    private var standardLayout: some View {
        HStack(spacing: 12) {
            FriendAvatarView(friend: friend)

            identity

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                updateText
                CityEmblemView(city: friend.city, countryCode: friend.countryCode, size: 36)
            }
        }
    }

    private var accessibilityLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            FriendAvatarView(friend: friend)

            VStack(alignment: .leading, spacing: 8) {
                identity
                updateText
            }
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(friend.displayName)
                .font(.headline)
                .foregroundStyle(WIFTheme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

            Text("@\(friend.username)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WIFTheme.fresh)
                .lineLimit(1)

            Text(friend.cityDisplay)
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
        }
    }

    private var updateText: some View {
        Text(friend.relativeUpdateText(at: referenceDate))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(freshness == .fresh ? WIFTheme.fresh : WIFTheme.secondaryText)
    }
}
