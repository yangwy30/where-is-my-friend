import SwiftUI

struct FriendRowView: View {
    let friend: FriendPresence
    let referenceDate: Date

    private var freshness: PresenceFreshness {
        friend.freshness(at: referenceDate)
    }

    var body: some View {
        HStack(spacing: 12) {
            FriendAvatarView(friend: friend)

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.displayName)
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)

                Text(friend.cityDisplay)
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(friend.relativeUpdateText(at: referenceDate))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(freshness == .fresh ? WIFTheme.fresh : WIFTheme.secondaryText)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(friend.displayName), \(friend.cityDisplay), \(friend.relativeUpdateLongText(at: referenceDate))"
        )
    }
}
