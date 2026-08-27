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

struct FriendTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FriendWidgetEntry {
        FriendEntryFactory.makeEntry(
            date: Date(),
            sourceFriends: MockFriendData.friends,
            currentCity: MockFriendData.currentUserCity,
            currentCountryCode: "US",
            snapshotUpdatedAt: Date(),
            privacyMode: .full,
            selectedFriendIDs: []
        )
    }

    func snapshot(
        for configuration: FriendWidgetConfigurationIntent,
        in context: Context
    ) async -> FriendWidgetEntry {
        FriendEntryFactory.makeStoredEntry(
            date: Date(),
            selectedFriendIDs: configuration.selectedFriendIDs
        )
    }

    func timeline(
        for configuration: FriendWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<FriendWidgetEntry> {
        let now = Date()
        let entry = FriendEntryFactory.makeStoredEntry(
            date: now,
            selectedFriendIDs: configuration.selectedFriendIDs
        )
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1_800)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

}

private enum FriendEntryFactory {
    static func makeStoredEntry(date: Date, selectedFriendIDs: [UUID]) -> FriendWidgetEntry {
        makeEntry(
            date: date,
            sourceFriends: SharedPresenceStore.load(),
            currentCity: SharedPresenceStore.loadCurrentCity(),
            currentCountryCode: SharedPresenceStore.loadCurrentCountryCode(),
            snapshotUpdatedAt: SharedPresenceStore.loadLastUpdatedAt(),
            privacyMode: SharedWidgetPreferences.privacyMode(),
            selectedFriendIDs: selectedFriendIDs
        )
    }

    static func makeEntry(
        date: Date,
        sourceFriends: [FriendPresence],
        currentCity: String,
        currentCountryCode: String?,
        snapshotUpdatedAt: Date?,
        privacyMode: WidgetPrivacyMode,
        selectedFriendIDs: [UUID]
    ) -> FriendWidgetEntry {
        FriendWidgetEntry(
            date: date,
            friends: FriendWidgetOrdering.ordered(
                sourceFriends,
                currentCity: currentCity,
                currentCountryCode: currentCountryCode,
                selectedFriendIDs: selectedFriendIDs,
                now: date
            ),
            currentCity: currentCity,
            currentCountryCode: currentCountryCode,
            snapshotUpdatedAt: snapshotUpdatedAt,
            privacyMode: privacyMode
        )
    }
}

struct SameCityTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> FriendWidgetEntry {
        FriendEntryFactory.makeEntry(
            date: Date(),
            sourceFriends: MockFriendData.friends,
            currentCity: MockFriendData.currentUserCity,
            currentCountryCode: "US",
            snapshotUpdatedAt: Date(),
            privacyMode: .full,
            selectedFriendIDs: []
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendWidgetEntry) -> Void) {
        completion(FriendEntryFactory.makeStoredEntry(date: Date(), selectedFriendIDs: []))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendWidgetEntry>) -> Void) {
        let now = Date()
        let entry = FriendEntryFactory.makeStoredEntry(date: now, selectedFriendIDs: [])
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now)
            ?? now.addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct FriendWidget: Widget {
    static let kind = "WhereIsMyFriend.FriendWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: FriendWidgetConfigurationIntent.self,
            provider: FriendTimelineProvider()
        ) { entry in
            FriendWidgetEntryView(entry: entry)
                .environment(\.colorScheme, SharedAppearancePreference.appearance.colorScheme)
                .containerBackground(for: .widget) {
                    FriendWidgetBackground()
                        .environment(\.colorScheme, SharedAppearancePreference.appearance.colorScheme)
                }
        }
        .configurationDisplayName("City Stage")
        .description("See your friends as miniature city stages.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,
            .accessoryCircular
        ])
    }
}

struct SameCityWidget: Widget {
    static let kind = "WhereIsMyFriend.SameCityWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: Self.kind,
            provider: SameCityTimelineProvider()
        ) { entry in
            SameCityWidgetEntryView(entry: entry)
                .environment(\.colorScheme, SharedAppearancePreference.appearance.colorScheme)
                .containerBackground(for: .widget) {
                    FriendWidgetBackground()
                        .environment(\.colorScheme, SharedAppearancePreference.appearance.colorScheme)
                }
        }
        .configurationDisplayName("Together Moment")
        .description("A focused view for friends who are in your city now.")
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

#Preview("Together Moment", as: .systemMedium) {
    SameCityWidget()
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
