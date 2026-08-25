import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isAddingFriend = false
    @State private var referenceDate = Date()
    let onOpenCitySharing: () -> Void

    init(onOpenCitySharing: @escaping () -> Void = {}) {
        self.onOpenCitySharing = onOpenCitySharing
    }

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
                myCityCard.padding(.top, 20)

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

    private var myCityCard: some View {
        Button(action: onOpenCitySharing) {
            HStack(spacing: 12) {
                Image(systemName: sharingIsEnabled ? "location.fill" : "location.slash.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WIFTheme.fresh)
                    .frame(width: 46, height: 46)
                    .background(WIFTheme.fresh.opacity(0.14), in: Circle())
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 4) {
                    Text("You · \(store.snapshot.currentPresence.cityDisplay)")
                        .font(.body.weight(.bold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)
                    Text(myCityStatusText)
                        .font(.caption)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(sharingIsEnabled ? "Sharing" : "Paused")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(sharingIsEnabled ? WIFTheme.fresh : WIFTheme.secondaryText)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        (sharingIsEnabled ? WIFTheme.fresh : WIFTheme.secondaryText).opacity(0.12),
                        in: Capsule()
                    )

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            .padding(15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .wifGlassSurface(
            tint: WIFTheme.fresh.opacity(0.17),
            interactive: true,
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityIdentifier("myCitySharingCard")
    }

    private var sharingIsEnabled: Bool {
        store.snapshot.sharingPreferences.citySharingEnabled
    }

    private var myCityStatusText: String {
        guard sharingIsEnabled else { return String(localized: "Friends cannot see your city") }
        guard store.currentCity != nil else { return String(localized: "Choose a city to start sharing") }
        let update = store.snapshot.currentPresence.updatedAt?
            .formatted(date: .omitted, time: .shortened) ?? "—"
        return String(format: String(localized: "Updated %@ · City only"), update)
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
