import SwiftUI

struct SameCityMomentCard: View {
    let friends: [FriendPresence]
    let referenceDate: Date

    private var names: String {
        friends.prefix(3).map(\.displayName).joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: -10) {
                ForEach(friends.prefix(3)) { friend in
                    FriendAvatarView(friend: friend, size: 38)
                        .overlay {
                            Circle().stroke(WIFTheme.freshSurface, lineWidth: 2)
                        }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Together in \(MockFriendData.currentUserCity)")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)

                Text("You and \(names)")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(WIFTheme.eventGradient, in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
        .overlay {
            RoundedRectangle(cornerRadius: WIFTheme.largeRadius)
                .stroke(WIFTheme.border.opacity(0.8), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
