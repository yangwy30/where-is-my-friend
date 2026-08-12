import SwiftUI

public struct FriendsListView: View {
    @State private var viewModel = FriendsListViewModel()
    @State private var showingAddFriend = false

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.friends) { friend in
                        FriendRowView(friend: friend)
                    }
                } header: {
                    Text("Friends Cities (\(viewModel.friends.count)/\(AppConstants.maxFriends))")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Where's My Friend")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView()
            }
        }
    }
}
