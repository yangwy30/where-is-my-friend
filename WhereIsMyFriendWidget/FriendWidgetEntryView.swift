import SwiftUI
import WidgetKit

public struct FriendWidgetEntryView: View {
    var entry: FriendEntry
    @Environment(\.widgetFamily) var family

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("📍 Friends Cities")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            switch family {
            case .systemSmall:
                smallWidgetView
            case .systemMedium:
                mediumWidgetView
            case .systemLarge:
                largeWidgetView
            default:
                mediumWidgetView
            }
        }
        .padding()
    }

    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(entry.friends.prefix(2)) { friend in
                widgetRow(friend: friend, showTime: false)
            }
        }
    }

    private var mediumWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(entry.friends.prefix(3)) { friend in
                widgetRow(friend: friend, showTime: true)
            }
        }
    }

    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(entry.friends.prefix(6)) { friend in
                widgetRow(friend: friend, showTime: true)
            }
        }
    }

    private func widgetRow(friend: WidgetFriend, showTime: Bool) -> some View {
        HStack(spacing: 8) {
            Text(friend.emoji ?? "🧑")
                .font(.title3)
            
            Text(friend.name)
                .font(.subheadline.bold())
                .lineLimit(1)

            Spacer()

            Text(friend.countryFlag)
            Text(friend.city)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
}
