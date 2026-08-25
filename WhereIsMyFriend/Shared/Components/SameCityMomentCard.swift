import SwiftUI

struct SameCityMomentCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let friends: [FriendPresence]
    let city: String
    let referenceDate: Date

    private var names: String {
        friends.prefix(3).map(\.displayName).joined(separator: ", ")
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    avatars
                    description
                }
            } else {
                HStack(spacing: 14) {
                    avatars
                    description
                    Spacer(minLength: 0)
                    CityEmblemView(city: city, size: 48)
                }
            }
        }
        .padding(16)
        .wifGlassSurface(
            tint: WIFTheme.fresh.opacity(0.18),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var avatars: some View {
        HStack(spacing: -10) {
            ForEach(friends.prefix(3)) { friend in
                FriendAvatarView(friend: friend, size: 38)
                    .overlay {
                        Circle().stroke(WIFTheme.freshSurface, lineWidth: 2)
                    }
            }
        }
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Together in \(city)")
                .font(.headline)
                .foregroundStyle(WIFTheme.primaryText)

            Text("You and \(names)")
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
        }
    }
}
