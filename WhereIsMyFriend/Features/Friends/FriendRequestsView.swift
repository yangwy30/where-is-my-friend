import SwiftUI

public struct FriendRequestsView: View {
    public var body: some View {
        List {
            ContentUnavailableView("No Pending Requests", systemImage: "person.crop.circle.badge.checkmark", description: Text("New friend requests will appear here."))
        }
        .navigationTitle("Friend Requests")
    }
}
