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

    private func isFriendInSameCity(_ friend: FriendPresence) -> Bool {
        guard let myCity = store.currentCity, !myCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return CityIdentity.matches(
            city: friend.city,
            countryCode: friend.countryCode,
            otherCity: myCity,
            otherCountryCode: store.snapshot.currentPresence.countryCode
        ) && friend.isSameCityEligible(at: referenceDate)
    }

    private var friends: [FriendPresence] {
        store.friends.sorted { lhs, rhs in
            let lhsTogether = isFriendInSameCity(lhs)
            let rhsTogether = isFriendInSameCity(rhs)
            if lhsTogether != rhsTogether {
                return lhsTogether // 🟢 Bump Together / Same-city friends to the very top!
            }
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite
            }
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

    private var friendGridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        return [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                cityContextCard
                    .padding(.top, 16)

                Text("Around the world")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 22)
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
                    LazyVGrid(
                        columns: friendGridColumns,
                        spacing: 12
                    ) {
                        ForEach(friends) { friend in
                            NavigationLink(value: friend) {
                                friendCard(friend)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
            .font(
                dynamicTypeSize.isAccessibilitySize
                    ? .largeTitle.bold()
                    : .system(size: 44, weight: .bold, design: .rounded)
            )
            .tracking(-0.8)
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

    private var cityContextCard: some View {
        Button(action: onOpenCitySharing) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Your city")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(1.35)
                        .foregroundStyle(WIFTheme.fresh)

                    Text(currentCityLabel)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(WIFTheme.border.opacity(0.62))
                    .frame(width: 1, height: 48)
                    .padding(.horizontal, 16)

                cityContextMetric

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.secondaryText.opacity(0.72))
                    .padding(.leading, 12)
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .frame(minHeight: 98)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .wifGlassSurface(
            tint: WIFTheme.fresh.opacity(0.11),
            interactive: true,
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityLabel("Your city, \(currentCityLabel), \(cityContextText)")
        .accessibilityIdentifier("myCitySharingCard")
    }

    @ViewBuilder
    private var cityContextMetric: some View {
        if sharingIsEnabled, store.currentCity != nil {
            HStack(alignment: .center, spacing: 7) {
                Text(verbatim: "\(sameCityFriends.count)")
                    .font(.system(size: 39, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(WIFTheme.fresh)
                    .contentTransition(.numericText())

                VStack(alignment: .leading, spacing: 1) {
                    Text(sameCityFriendUnit)
                    Text(sameCityLocationPhrase)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WIFTheme.secondaryText)
                .lineLimit(1)
            }
        } else {
            HStack(spacing: 7) {
                Image(systemName: sharingIsEnabled ? "location" : "location.slash")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WIFTheme.fresh)

                Text(sharingMetricLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .frame(maxWidth: 118, alignment: .leading)
        }
    }

    private var currentCityLabel: String {
        store.currentCity ?? String(localized: "Location unavailable")
    }

    private var sameCityFriendUnit: LocalizedStringKey {
        sameCityFriends.count == 1 ? "friend" : "friends"
    }

    private var sameCityLocationPhrase: LocalizedStringKey {
        sameCityFriends.isEmpty ? "in your city" : "here too"
    }

    private var sharingMetricLabel: LocalizedStringKey {
        sharingIsEnabled ? "Choose a city to start sharing" : "Sharing paused"
    }

    private var sharingIsEnabled: Bool {
        store.snapshot.sharingPreferences.citySharingEnabled
    }

    private var cityContextText: String {
        guard sharingIsEnabled else { return String(localized: "Friends cannot see your city") }
        guard store.currentCity != nil else { return String(localized: "Choose a city to start sharing") }

        if sameCityFriends.count == 1, let friend = sameCityFriends.first {
            return String(
                format: String(localized: "%@ is in your city"),
                friend.displayName
            )
        }

        if sameCityFriends.count > 1 {
            return String(
                format: String(localized: "%lld friends are in your city"),
                Int64(sameCityFriends.count)
            )
        }

        let update = store.snapshot.currentPresence.updatedAt?
            .formatted(date: .omitted, time: .shortened) ?? "—"
        return String(format: String(localized: "Updated %@ · City only"), update)
    }

    private func friendCard(_ friend: FriendPresence) -> some View {
        let freshness = friend.freshness(at: referenceDate)
        let isSameCity = isFriendInSameCity(friend)

        return VStack(spacing: 6) {
            CityEmblemView(city: friend.city, countryCode: friend.countryCode, size: 88)
                .padding(.top, 9)

            VStack(spacing: 2) {
                Text(friend.displayName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(friend.cityDisplay)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(isSameCity ? WIFTheme.fresh : freshnessDotColor(freshness))
                        .frame(width: 5, height: 5)

                    if isSameCity {
                        Text("Same city")
                            .foregroundStyle(WIFTheme.fresh)

                        Text("·")
                            .foregroundStyle(WIFTheme.secondaryText.opacity(0.72))
                    }

                    Text(friend.relativeUpdateText(at: referenceDate))
                        .foregroundStyle(freshness == .fresh ? WIFTheme.fresh : WIFTheme.secondaryText)
                }
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .padding(.top, 3)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .wifGlassSurface(
            tint: isSameCity ? WIFTheme.fresh.opacity(0.12) : WIFTheme.surface.opacity(0.07),
            interactive: true,
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(friend.displayName), \(friend.cityDisplay), \(isSameCity ? "\(String(localized: "Same city")), " : "")\(friend.relativeUpdateLongText(at: referenceDate))"
        )
    }

    private func freshnessDotColor(_ freshness: PresenceFreshness) -> Color {
        freshness == .fresh ? WIFTheme.fresh : WIFTheme.secondaryText.opacity(0.42)
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
