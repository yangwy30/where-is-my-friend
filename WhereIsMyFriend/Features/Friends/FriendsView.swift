import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        return MockFriendData.sameCityFriends(
            from: friends,
            currentCity: city,
            currentCountryCode: store.snapshot.currentPresence.countryCode,
            now: referenceDate
        )
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
                        Text(store.repositoryMode == .localDemo
                             ? "Accept a request or invite a demo user by username."
                             : "Share your username or invite someone by theirs.")
                    } actions: {
                        Button("Add friends") { isAddingFriend = true }
                            .wifGlassButton(tint: WIFTheme.fresh.opacity(0.28), prominent: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .wifGlassSurface(
                        tint: WIFTheme.surface.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
                    )
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
                    .wifGlassSurface(
                        tint: WIFTheme.surface.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
                    )
                }
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 24)
        }
        .wifAmbientBackground()
        .toolbar(.hidden, for: .navigationBar)
        .refreshable {
            await store.refresh(showErrors: true)
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
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    title
                    friendCount
                    addFriendButton
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        title
                        friendCount
                    }

                    Spacer()

                    addFriendButton
                }
            }
        }
        .padding(.top, 12)
    }

    private var title: some View {
        Text("Friends")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .foregroundStyle(WIFTheme.primaryText)
    }

    private var friendCount: some View {
        Text("\(friends.count) friends · \(uniqueCityCount) cities")
            .font(.subheadline)
            .foregroundStyle(WIFTheme.secondaryText)
    }

    private var addFriendButton: some View {
        WIFGlassEffectGroup(spacing: 10) {
            Button {
                isAddingFriend = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "person.badge.plus")
                        .font(.headline)
                        .foregroundStyle(WIFTheme.fresh)
                        .frame(width: 44, height: 44)

                    if store.incomingRequestCount > 0 {
                        Text("\(store.incomingRequestCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(WIFTheme.destructive, in: Circle())
                            .offset(x: 5, y: -5)
                    }
                }
            }
            .buttonStyle(.plain)
            .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.16), interactive: true, in: Circle())
            .accessibilityLabel("Add a friend")
            .accessibilityIdentifier("addFriendButton")
        }
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
