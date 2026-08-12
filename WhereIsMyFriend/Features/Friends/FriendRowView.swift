import SwiftUI

public struct FriendRowView: View {
    public var friend: FriendLocation

    public var body: some View {
        HStack(spacing: 14) {
            AvatarView(
                name: friend.displayName,
                photoURL: friend.photoURL,
                emoji: friend.avatarEmoji,
                avatarColor: friend.avatarColor,
                size: 50
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(friend.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if friend.isGhost {
                        Text("🌙 Ghost Mode")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.secondary.opacity(0.2)))
                    }
                }

                if friend.isGhost {
                    Text("Location hidden")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Text(friend.countryFlag)
                        Text(friend.city)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if !friend.isGhost {
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundColor(.blue)

                    Text(friend.lastUpdated.relativeFormatted)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}
