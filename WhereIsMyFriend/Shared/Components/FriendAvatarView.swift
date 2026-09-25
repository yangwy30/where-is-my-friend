import SwiftUI

struct FriendAvatarView: View {
    let friend: FriendPresence
    var size: CGFloat = 46

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
            .fill(
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Text(friend.initials)
                    .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
    }
}

/// A brief pulse announces a visible shared plan without moving the friend card.
struct FriendPlanBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let planID: UUID
    let isActive: Bool
    @State private var pulse = false

    var body: some View {
        Image(systemName: "calendar")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(WIFTheme.canvas)
            .frame(width: 26, height: 26)
            .background(WIFTheme.fresh, in: Circle())
            .overlay { Circle().stroke(WIFTheme.surface, lineWidth: 2) }
            .background {
                Circle().stroke(WIFTheme.fresh.opacity(pulse ? 0 : 0.35), lineWidth: 2)
                    .scaleEffect(pulse ? 1.65 : 1)
            }
            .task(id: isActive && !reduceMotion ? planID : nil) {
                pulse = false
                guard isActive, !reduceMotion else { return }
                withAnimation(.easeOut(duration: 0.9).repeatCount(2, autoreverses: false)) {
                    pulse = true
                }
            }
            .accessibilityHidden(true)
    }
}
