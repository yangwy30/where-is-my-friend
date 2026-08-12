import SwiftUI
import WidgetKit

struct FriendWidgetEntry: TimelineEntry {
    let date: Date
    let friends: [FriendPresence]
    let currentCity: String
    let snapshotUpdatedAt: Date?
}

struct FriendTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FriendWidgetEntry {
        FriendWidgetEntry(
            date: Date(),
            friends: MockFriendData.friends,
            currentCity: MockFriendData.currentUserCity,
            snapshotUpdatedAt: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendWidgetEntry) -> Void) {
        completion(
            FriendWidgetEntry(
                date: Date(),
                friends: SharedPresenceStore.load(),
                currentCity: SharedPresenceStore.loadCurrentCity(),
                snapshotUpdatedAt: SharedPresenceStore.loadLastUpdatedAt()
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendWidgetEntry>) -> Void) {
        let now = Date()
        let entry = FriendWidgetEntry(
            date: now,
            friends: SharedPresenceStore.load(),
            currentCity: SharedPresenceStore.loadCurrentCity(),
            snapshotUpdatedAt: SharedPresenceStore.loadLastUpdatedAt()
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
                    WIFTheme.elevatedSurface
                }
        }
        .configurationDisplayName("Where they are")
        .description("See the latest city your friends have chosen to share.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    FriendWidget()
} timeline: {
    FriendWidgetEntry(
        date: .now,
        friends: MockFriendData.friends,
        currentCity: MockFriendData.currentUserCity,
        snapshotUpdatedAt: .now
    )
}
