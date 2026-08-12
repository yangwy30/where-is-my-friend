import SwiftUI

public struct AvatarView: View {
    public var name: String
    public var photoURL: String?
    public var emoji: String?
    public var avatarColor: String
    public var size: CGFloat

    public init(name: String, photoURL: String? = nil, emoji: String? = nil, avatarColor: String = "#007AFF", size: CGFloat = 48) {
        self.name = name
        self.photoURL = photoURL
        self.emoji = emoji
        self.avatarColor = avatarColor
        self.size = size
    }

    public var body: some View {
        Group {
            if let photoURL, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsView
                    }
                }
            } else if let emoji, !emoji.isEmpty {
                ZStack {
                    Circle()
                        .fill(Color(hex: avatarColor).opacity(0.2))
                    Text(emoji)
                        .font(.system(size: size * 0.55))
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.primary.opacity(0.1), lineWidth: 1))
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(Color(hex: avatarColor))
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
