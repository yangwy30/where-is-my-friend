import WidgetKit
import SwiftUI

@main
struct WhereIsMyFriendWidget: Widget {
    let kind: String = "WhereIsMyFriendWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimelineProvider()) { entry in
            FriendWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Where's My Friend")
        .description("View where your friends are in the world at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
