import SwiftUI
import WidgetKit

struct FriendWidgetEntry: TimelineEntry {
    let date: Date
    let friends: [FriendPresence]
    let currentCity: String
    let currentCountryCode: String?
    let snapshotUpdatedAt: Date?
    let privacyMode: WidgetPrivacyMode
}

struct FriendTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FriendWidgetEntry {
        FriendWidgetEntry(
            date: Date(),
            friends: MockFriendData.friends,
            currentCity: MockFriendData.currentUserCity,
            currentCountryCode: "US",
            snapshotUpdatedAt: Date(),
            privacyMode: .full
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendWidgetEntry) -> Void) {
        completion(
            FriendWidgetEntry(
                date: Date(),
                friends: SharedPresenceStore.load(),
                currentCity: SharedPresenceStore.loadCurrentCity(),
                currentCountryCode: SharedPresenceStore.loadCurrentCountryCode(),
                snapshotUpdatedAt: SharedPresenceStore.loadLastUpdatedAt(),
                privacyMode: SharedWidgetPreferences.privacyMode()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendWidgetEntry>) -> Void) {
        let now = Date()
        let entry = FriendWidgetEntry(
            date: now,
            friends: SharedPresenceStore.load(),
            currentCity: SharedPresenceStore.loadCurrentCity(),
            currentCountryCode: SharedPresenceStore.loadCurrentCountryCode(),
            snapshotUpdatedAt: SharedPresenceStore.loadLastUpdatedAt(),
            privacyMode: SharedWidgetPreferences.privacyMode()
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct FriendWidget: Widget {
    static let kind = "WhereIsMyFriend.FriendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: FriendTimelineProvider()) { entry in
            FriendWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    FriendWidgetBackground()
                }
        }
        .configurationDisplayName("Where they are")
        .description("See the latest city your friends have chosen to share.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular
        ])
    }
}

private struct FriendWidgetBackground: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular, .accessoryCircular:
            Color.clear
        default:
            WIFTheme.ambientGradient
        }
    }
}

#Preview(as: .systemMedium) {
    FriendWidget()
} timeline: {
    FriendWidgetEntry(
        date: .now,
        friends: MockFriendData.friends,
        currentCity: MockFriendData.currentUserCity,
        currentCountryCode: "US",
        snapshotUpdatedAt: .now,
        privacyMode: .full
    )
}

#Preview("Lock Screen — Friends", as: .accessoryRectangular) {
    FriendWidget()
} timeline: {
    FriendWidgetEntry(
        date: .now,
        friends: MockFriendData.friends,
        currentCity: MockFriendData.currentUserCity,
        currentCountryCode: "US",
        snapshotUpdatedAt: .now,
        privacyMode: .full
    )
}

#Preview("Lock Screen — Same City", as: .accessoryCircular) {
    FriendWidget()
} timeline: {
    FriendWidgetEntry(
        date: .now,
        friends: MockFriendData.friends,
        currentCity: MockFriendData.currentUserCity,
        currentCountryCode: "US",
        snapshotUpdatedAt: .now,
        privacyMode: .full
    )
}
