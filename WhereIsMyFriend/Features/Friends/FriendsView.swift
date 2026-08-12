import SwiftUI

struct FriendsView: View {
    @State private var friends = SharedPresenceStore.load()
    @State private var isAddingFriend = false
    private let referenceDate = Date()

    private var sameCityFriends: [FriendPresence] {
        MockFriendData.sameCityFriends(from: friends, now: referenceDate)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header

                if !sameCityFriends.isEmpty {
                    SameCityMomentCard(friends: sameCityFriends, referenceDate: referenceDate)
                        .padding(.top, 20)
                }

                Text("Around the world")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 26)
                    .padding(.bottom, 9)
                    .padding(.leading, 3)

                LazyVStack(spacing: 0) {
                    ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                        NavigationLink(value: friend) {
                            FriendRowView(friend: friend, referenceDate: referenceDate)
                        }
                        .buttonStyle(.plain)

                        if index < friends.count - 1 {
                            Divider()
                                .overlay(WIFTheme.border)
                                .padding(.leading, 72)
                        }
                    }
                }
                .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: WIFTheme.largeRadius)
                        .stroke(WIFTheme.border, lineWidth: 1)
                }
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 24)
        }
        .background(WIFTheme.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: FriendPresence.self) { friend in
            FriendDetailView(friend: friend)
        }
        .sheet(isPresented: $isAddingFriend) {
            AddFriendView()
        }
        .accessibilityIdentifier("friendsScreen")
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Friends")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)

                Text("\(friends.count) friends · \(uniqueCityCount) cities")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer()

            Button {
                isAddingFriend = true
            } label: {
                Image(systemName: "person.badge.plus")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.fresh)
                    .frame(width: 42, height: 42)
                    .background(WIFTheme.freshSurface, in: Circle())
            }
            .accessibilityLabel("Add a friend")
            .accessibilityIdentifier("addFriendButton")
        }
        .padding(.top, 12)
    }

    private var uniqueCityCount: Int {
        Set(friends.compactMap(\.city)).count
    }
}

#Preview {
    NavigationStack {
        FriendsView()
    }
}
