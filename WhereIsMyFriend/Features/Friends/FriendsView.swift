import SwiftUI
import CoreLocation
import UIKit

struct FriendsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationService: CityLocationService
    @EnvironmentObject private var locationReminders: LocationPermissionReminderStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isAddingFriend = false
    @State private var isScreenVisible = false
    @State private var referenceDate = Date()
    @Binding private var selectedSameCityEventID: UUID?
    @Binding private var selectedUpcomingID: String?
    @EnvironmentObject private var travelPlans: TravelPlanLibrary
    let onOpenCitySharing: () -> Void
    let isHomeVisible: Bool

    init(selectedSameCityEventID: Binding<UUID?> = .constant(nil), selectedUpcomingID: Binding<String?> = .constant(nil), isHomeVisible: Bool = true, onOpenCitySharing: @escaping () -> Void = {}) {
        self._selectedSameCityEventID = selectedSameCityEventID
        self._selectedUpcomingID = selectedUpcomingID
        self.onOpenCitySharing = onOpenCitySharing
        self.isHomeVisible = isHomeVisible
    }

    private func isFriendInSameCity(_ friend: FriendPresence) -> Bool {
        guard let myCity = store.currentCity, !myCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        return store.snapshot.sharingPreferences.citySharingEnabled
            && PresenceMatchPolicy.matches(store.snapshot.currentPresence, friend, at: referenceDate)
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
        guard store.currentCity != nil else { return [] }
        return store.snapshot.sharingPreferences.citySharingEnabled
            ? friends.filter { PresenceMatchPolicy.matches(store.snapshot.currentPresence, $0, at: referenceDate) } : []
    }

    private var friendGridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible())]
        }

        return [GridItem(.adaptive(minimum: 154, maximum: 220), spacing: 12)]
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                header
                Group {
                    if showsLocationReminder { locationReminderCard }
                    else { cityContextCard }
                }
                .padding(.top, 16)
                if store.snapshot.friends.isEmpty || store.incomingRequestCount > 0 {
                    InvitationNotificationStatusView(service: store.notificationService)
                        .padding(.top, 12)
                }

                SameCityReunionCard(referenceDate: referenceDate, eventID: $selectedSameCityEventID)
                    .id("sameCityReunion")
                UpcomingTogetherCard(selectedID: $selectedUpcomingID)
                    .id("upcomingTogether")

                worldSectionHeader
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
                    .wifContentSurface(
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
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
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
        .onAppear {
            isScreenVisible = true
            refreshLocationReminder()
        }
        .onDisappear {
            isScreenVisible = false
            refreshLocationReminder()
        }
        .onChange(of: locationReminderContext) { _, _ in refreshLocationReminder() }
        .onChange(of: selectedSameCityEventID, initial: true) { _, id in
            guard let id else { return }
            Task {
                await store.refresh()
                referenceDate = Date()
                guard selectedSameCityEventID == id else { return }
                proxy.scrollTo("sameCityReunion", anchor: .top)
            }
        }
        .task {
            while !Task.isCancelled {
                referenceDate = Date()
                refreshLocationReminder()
                await travelPlans.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .onChange(of: selectedUpcomingID, initial: true) { _, id in
            guard let id else { return }
            Task {
                await travelPlans.refresh()
                guard selectedUpcomingID == id else { return }
                proxy.scrollTo("upcomingTogether", anchor: .top)
            }
        }
        }
    }

    private struct ReminderContext: Equatable {
        let ownerID: UUID?
        let eligible: Bool
    }

    private var locationReminderContext: ReminderContext {
        var isLiveAccount = store.repositoryMode == .remote
        #if DEBUG
        isLiveAccount = isLiveAccount || ProcessInfo.processInfo.arguments.contains("-testLocationReminder")
        #endif
        let canPresent = isScreenVisible && isHomeVisible && scenePhase == .active && !isAddingFriend
            && store.pendingInvite == nil && store.pendingTripInvitationID == nil
            && store.pendingFriendRequestID == nil && store.notice == nil
            && selectedSameCityEventID == nil && selectedUpcomingID == nil
        return ReminderContext(
            ownerID: store.snapshot.isAuthenticated ? store.snapshot.currentUser.id : nil,
            eligible: LocationPermissionReminderPolicy.isEligible(
                isAuthenticated: store.snapshot.isAuthenticated, isLiveAccount: isLiveAccount,
                isHomeVisible: canPresent, sharingEnabled: store.snapshot.sharingPreferences.citySharingEnabled,
                presence: store.snapshot.currentPresence, status: locationService.authorizationStatus)
        )
    }

    private var showsLocationReminder: Bool {
        let context = locationReminderContext
        return context.eligible && context.ownerID != nil && locationReminders.presentedOwnerID == context.ownerID
    }

    private func refreshLocationReminder() {
        let context = locationReminderContext
        locationReminders.prepare(ownerID: context.ownerID, eligible: context.eligible)
    }

    private var locationReminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Keep your city up to date")
                .font(.headline).foregroundStyle(WIFTheme.primaryText)
            Text("Turn on location to spot friends in the same city.")
                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) { locationReminderActions }
            } else {
                HStack(spacing: 16) { locationReminderActions }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wifContentSurface(tint: WIFTheme.fresh.opacity(0.07),
                           in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("locationReminderCard")
    }

    @ViewBuilder
    private var locationReminderActions: some View {
        Button {
            let action = LocationPermissionReminderPolicy.action(for: locationService.authorizationStatus)
            locationReminders.dismiss(for: store.snapshot.currentUser.id)
            switch action {
            case .requestPermission: locationService.requestForegroundCity()
            case .openSettings:
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            case .none: break
            }
        } label: {
            Text(locationService.authorizationStatus == .denied ? "Open Settings" : "Enable location")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WIFTheme.canvas)
                .padding(.horizontal, 16).frame(minHeight: 44)
                .background(WIFTheme.fresh, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("enableLocationReminder")
        Button { locationReminders.dismiss(for: store.snapshot.currentUser.id) } label: {
            Text("Not now")
                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("dismissLocationReminder")
    }

    @ViewBuilder
    private var worldSectionHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            stackedWorldSectionHeader
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    worldSectionTitle
                    Spacer(minLength: 4)
                    friendPlansLink
                }
                stackedWorldSectionHeader
            }
        }
    }

    private var stackedWorldSectionHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            worldSectionTitle
            friendPlansLink
        }
    }

    private var worldSectionTitle: some View {
        Text("Around the world")
            .font(.caption.weight(.semibold)).textCase(.uppercase).tracking(1.1)
            .foregroundStyle(WIFTheme.secondaryText)
            .fixedSize(horizontal: !dynamicTypeSize.isAccessibilitySize, vertical: true)
    }

    private var friendPlansLink: some View {
        let allowed = Set(store.friends.map(\.id)).subtracting(store.snapshot.blockedUserIDs)
        let count = travelPlans.visibleFriendPlans(friendIDs: allowed, at: referenceDate).count
        return NavigationLink { FriendTravelPlansView() } label: {
            HStack(spacing: 5) {
                Text("Friend plans")
                if count > 0 {
                    Text(count, format: .number)
                        .font(.caption2).padding(.horizontal, 5).padding(.vertical, 2)
                        .background(WIFTheme.fresh.opacity(0.10), in: Capsule())
                }
                Image(systemName: "chevron.right").font(.caption2)
            }
            .font(.caption.weight(.medium)).foregroundStyle(WIFTheme.fresh)
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityIdentifier("friendPlansLink")
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
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .buttonStyle(.plain)
            .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.16), interactive: true, in: Circle())
            .accessibilityLabel("Add a friend")
            .accessibilityIdentifier("addFriendButton")
        }
    }

    private var cityContextCard: some View {
        Button(action: onOpenCitySharing) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    stackedCityContext
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 0) {
                            cityContextTitle.frame(maxWidth: .infinity, alignment: .leading)
                            Rectangle().fill(WIFTheme.border.opacity(0.62))
                                .frame(width: 1, height: 48).padding(.horizontal, 16)
                            cityContextMetric
                            cityContextChevron.padding(.leading, 12)
                        }
                        .frame(minWidth: 280)
                        stackedCityContext
                    }
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .frame(minHeight: 98)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .wifContentSurface(
            tint: WIFTheme.fresh.opacity(0.11),
            interactive: true,
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityLabel("Your city, \(currentCityLabel), \(cityContextText)")
        .accessibilityIdentifier("myCitySharingCard")
    }

    private var cityContextTitle: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Your city").font(.caption2.weight(.semibold)).textCase(.uppercase)
                .tracking(1.35).foregroundStyle(WIFTheme.fresh)
            Text(currentCityLabel).font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(WIFTheme.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1).minimumScaleFactor(0.82)
        }
    }

    private var cityContextChevron: some View {
        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            .foregroundStyle(WIFTheme.secondaryText.opacity(0.72))
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var stackedCityContext: some View {
        VStack(alignment: .leading, spacing: 12) {
            cityContextTitle.frame(maxWidth: .infinity, alignment: .leading)
            Divider().overlay(WIFTheme.border.opacity(0.4))
            HStack {
                cityContextMetric
                Spacer(minLength: 12)
                cityContextChevron
            }
        }
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
                .font(.caption.weight(.semibold))
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
        store.snapshot.currentPresence.cityDisplay
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
        if CityIdentity.presenceKey(city: store.currentCity, countryCode: store.snapshot.currentPresence.countryCode,
                                    administrativeArea: store.snapshot.currentPresence.administrativeArea) == nil
            || !PresenceMatchPolicy.isRecent(store.snapshot.currentPresence.updatedAt, at: referenceDate) {
            return String(localized: "Refresh location to check who’s here")
        }

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
        return String(format: String(localized: "Updated %@"), update)
    }

    private func friendCard(_ friend: FriendPresence) -> some View {
        let freshness = friend.freshness(at: referenceDate)
        let isSameCity = isFriendInSameCity(friend)

        return VStack(spacing: 6) {
            CityEmblemView(friend: friend, size: 88)
                .padding(.top, 9)

            VStack(spacing: 2) {
                Text(friend.displayName)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(friend.cityDisplay)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

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
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .padding(.top, 3)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .wifContentSurface(
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
    let store = AppStore()
    NavigationStack {
        FriendsView()
    }
    .environmentObject(store)
    .environmentObject(store.travelPlans)
}
