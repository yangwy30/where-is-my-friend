import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isAddingFriend = false
    @State private var referenceDate = Date()

    private var friends: [FriendPresence] {
        store.friends.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
            return (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
        }
    }

    private var sameCityFriends: [FriendPresence] {
        guard let city = store.currentCity else { return [] }
        return MockFriendData.sameCityFriends(from: friends, currentCity: city, now: referenceDate)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header

                if !sameCityFriends.isEmpty {
                    SameCityMomentCard(
                        friends: sameCityFriends,
                        city: store.currentCity ?? "",
                        referenceDate: referenceDate
                    )
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

                if friends.isEmpty {
                    ContentUnavailableView {
                        Label("No friends yet", systemImage: "person.2.slash")
                    } description: {
                        Text("Accept a request or invite a demo user by username.")
                    } actions: {
                        Button("Add friends") { isAddingFriend = true }
                            .buttonStyle(.borderedProminent)
                            .tint(WIFTheme.fresh)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
                } else {
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
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 24)
        }
        .background(WIFTheme.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await store.refresh()
            referenceDate = Date()
        }
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
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "person.badge.plus")
                        .font(.headline)
                        .foregroundStyle(WIFTheme.fresh)
                        .frame(width: 42, height: 42)
                        .background(WIFTheme.freshSurface, in: Circle())

                    if store.incomingRequestCount > 0 {
                        Text("\(store.incomingRequestCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(WIFTheme.destructive, in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
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
    .environmentObject(AppStore())
}
