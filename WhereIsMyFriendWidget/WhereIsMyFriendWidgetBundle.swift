import SwiftUI
import WidgetKit

@main
struct WhereIsMyFriendWidgetBundle: WidgetBundle {
    var body: some Widget {
        FriendWidget()
        SameCityWidget()
    }
}
