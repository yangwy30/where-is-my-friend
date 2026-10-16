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
    @State private var showsSameCityFriends = false
    @StateObject private var invitationDraft = FriendInvitationDraft()
    @State private var isScreenVisible = false
    @State private var isHeaderCollapsed = false
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
                SameCityReunionCard(referenceDate: referenceDate, eventID: $selectedSameCityEventID)
                    .id("sameCityReunion")
                if store.snapshot.syncState == .offline || store.pendingOperationCount > 0 {
                    synchronizationStatus.padding(.top, 12)
                }
                if showsLocationReminder {
                    locationReminderCard
                        .padding(.top, 16)
                } else if sharingIsEnabled && (!hasCurrentCity || !isCurrentCityRecent) {
                    cityRecoveryCard
                        .padding(.top, 16)
                }
                if !showsLocationReminder, showsNotificationPrompt {
                    NotificationPromptCard(service: store.notificationService,
                                           ownerID: store.snapshot.currentUser.id) {
                        await store.requestNotificationAuthorization()
                    }
                    .padding(.top, 16)
                }
                if store.incomingRequestCount > 0 {
                    InvitationNotificationStatusView(service: store.notificationService)
                        .padding(.top, 12)
                }

                UpcomingTogetherCard(selectedID: $selectedUpcomingID)
                    .id("upcomingTogether")

                if !friends.isEmpty {
                    worldSectionHeader
                        .padding(.top, 22)
                        .padding(.bottom, 9)
                        .padding(.leading, 3)
                }

                if friends.isEmpty {
                    ContentUnavailableView {
                        Label("No friends yet", systemImage: "person.2.slash")
                    } description: {
                        Text("Invite someone you know to share cities and find time together.")
                    } actions: {
                        ShareLink(item: InviteURLFactory.make(username: store.snapshot.currentUser.username)) {
                            Label("Invite your first friend", systemImage: "square.and.arrow.up")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                                .foregroundStyle(WIFTheme.onFresh)
                                .background(WIFTheme.fresh, in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("inviteFirstFriend")
                        Button("Add by username") { invitationDraft.reset(); isAddingFriend = true }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier("addFirstFriendByUsername")
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
                            .contextMenu { friendCardMenu(friend) }
                            .accessibilityIdentifier("friendCard-\(friend.id)")
                        }
                    }
                }
            }
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 24)
        }
        // Once the large title scrolls away, a compact bar keeps the title and Add friend in reach.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 64
        } action: { _, collapsed in
            withAnimation(.easeOut(duration: 0.18)) { isHeaderCollapsed = collapsed }
        }
        .overlay(alignment: .top) {
            if isHeaderCollapsed { compactHeader.transition(.opacity) }
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
        .sheet(isPresented: $showsSameCityFriends) {
            SameCityFriendsSheet(friends: sameCityFriends, presence: store.snapshot.currentPresence, referenceDate: referenceDate)
        }
        .sheet(isPresented: $isAddingFriend) {
            AddFriendView(draft: invitationDraft)
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
                guard selectedSameCityEventID == id, isHeaderCollapsed else { return }
                proxy.scrollTo("sameCityReunion", anchor: UnitPoint(x: 0.5, y: 0.12))
            }
        }
        .task(id: isHomeVisible) {
            guard isHomeVisible else { return }
            while !Task.isCancelled {
                referenceDate = Date()
                refreshLocationReminder()
                if scenePhase == .active { await store.refresh(minimumInterval: 15) }
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .onChange(of: selectedUpcomingID, initial: true) { _, id in
            guard let id else { return }
            Task {
                guard selectedUpcomingID == id, isHeaderCollapsed else { return }
                proxy.scrollTo("upcomingTogether", anchor: UnitPoint(x: 0.5, y: 0.12))
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

    /// Live accounts only: demo-mode UI tests start with an undecided permission too.
    private var showsNotificationPrompt: Bool {
        var isLiveAccount = store.repositoryMode == .remote
        #if DEBUG
        isLiveAccount = isLiveAccount || ProcessInfo.processInfo.arguments.contains("-testNotificationPrompt")
        #endif
        return isLiveAccount && store.snapshot.isAuthenticated
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
            Text(locationService.authorizationStatus == .authorizedWhenInUse
                 ? "Choose Always to spot same-city friends while the app is closed."
                 : "Turn on location to spot friends in the same city.")
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
            let status = locationService.authorizationStatus
            let action = LocationPermissionReminderPolicy.action(for: status)
            let owner = store.snapshot.currentUser.id
            locationReminders.dismiss(for: owner)
            switch action {
            case .requestPermission: locationService.requestForegroundCity()
            case .openSettings:
                Task {
                    if status == .authorizedWhenInUse && !store.snapshot.sharingPreferences.backgroundUpdatesEnabled {
                        var preferences = store.snapshot.sharingPreferences
                        preferences.backgroundUpdatesEnabled = true
                        guard await store.setSharingPreferences(preferences) else { return }
                    }
                    guard store.snapshot.isAuthenticated, store.snapshot.currentUser.id == owner else { return }
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
            case .none: break
            }
        } label: {
            Text(locationService.authorizationStatus == .authorizedWhenInUse ? "Choose Always"
                 : locationService.authorizationStatus == .denied ? "Open Settings" : "Enable location")
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
        let count = travelPlans.friendPlanCount(friendIDs: allowed, at: referenceDate)
        return NavigationLink { FriendTravelPlansView() } label: {
            HStack(spacing: 5) {
                Text("Friends’ travel plans")
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
                    cityStatus
                    addFriendButton()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            } else {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        title
                        cityStatus
                    }

                    Spacer()

                    addFriendButton()
                }
            }
        }
        .padding(.top, 12)
    }

    private var compactHeader: some View {
        HStack {
            Text("Friends")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(WIFTheme.primaryText)
                // The large title is still in the accessibility tree; don't announce it twice.
                .accessibilityHidden(true)
            Spacer()
            addFriendButton(identifier: "addFriendButtonCompact")
        }
        .padding(.horizontal, WIFTheme.screenInset)
        .padding(.bottom, 6)
        .background {
            WIFTheme.canvas.opacity(0.72)
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        }
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

    private var sameCityFriends: [FriendPresence] {
        SameCityPresencePolicy.currentFriends(in: store.snapshot, at: referenceDate)
            .sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
    }

    private func firstName(_ friend: FriendPresence) -> String {
        friend.displayName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? friend.displayName
    }

    /// Names while they fit in one glance; a count once a list would be needed.
    private var sameCityLine: String {
        let names = sameCityFriends.map(firstName)
        switch names.count {
        case 0: return ""
        case 1: return String(localized: "\(names[0]) is here too")
        case 2: return String(localized: "\(names[0]) and \(names[1]) are here too")
        default: return String(localized: "\(names.count) friends are here too")
        }
    }

    private var sameCityChip: some View {
        HStack(spacing: 8) {
            HStack(spacing: -4) {
                ForEach(Array(sameCityFriends.prefix(3))) { friend in
                    FriendAvatarView(friend: friend, size: 24)
                        .overlay(Circle().stroke(WIFTheme.surface, lineWidth: 1.5))
                }
                if sameCityFriends.count > 3 {
                    Text("+\(sameCityFriends.count - 3)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.fresh)
                        .frame(width: 24, height: 24)
                        .background(WIFTheme.freshSurface, in: Circle())
                        .overlay(Circle().stroke(WIFTheme.surface, lineWidth: 1.5))
                }
            }
            .accessibilityHidden(true)
            Text(sameCityLine)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .opacity(0.6)
                .accessibilityHidden(true)
        }
        .foregroundStyle(WIFTheme.fresh)
        .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
        .background(WIFTheme.surface.opacity(0.85), in: Capsule())
        .overlay(Capsule().strokeBorder(WIFTheme.border, lineWidth: 0.5))
        // The capsule stays compact. Its tap target reaches 44 pt by growing down only:
        // growing upward put it close enough to the city line that taps there opened a friend.
        .padding(.bottom, 12)
        .contentShape(Rectangle())
    }

    private var cityStatus: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cityStatusText)
                .font(.subheadline)
                .accessibilityIdentifier("homeCityStatus")
            if let friend = sameCityFriends.first {
                Group {
                    if sameCityFriends.count == 1 {
                        NavigationLink(value: friend) { sameCityChip }
                    } else {
                        Button { showsSameCityFriends = true } label: { sameCityChip }
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .accessibilityIdentifier("sameCitySummaryTitle")
            }
            if !sharingIsEnabled {
                Text(store.snapshot.syncState == .offline ? "City sharing is off on this device" : "City sharing is paused")
                    .font(.caption)
                    .accessibilityIdentifier("homeSharingPaused")
            }
        }
        .foregroundStyle(WIFTheme.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var synchronizationStatus: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(store.pendingOperationCount > 0 ? "Changes waiting to sync" : "Couldn’t refresh cities", systemImage: "arrow.triangle.2.circlepath")
                .font(.subheadline.weight(.medium))
            Text(store.pendingOperationCount > 0
                 ? "Your changes are saved on this device but haven’t been confirmed by the server."
                 : "Showing the last saved cities. Check your connection and try again.")
                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if let synced = store.snapshot.lastSyncedAt {
                Text("Last synced \(synced.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
            }
            Button {
                Task { await store.retryPendingOperations(); await store.refresh() }
            } label: {
                Text("Try again").font(.subheadline.weight(.medium))
                    .frame(minHeight: 44).contentShape(Rectangle())
            }
            .disabled(store.isWorking)
            .accessibilityIdentifier("retryHomeSync")
        }
        .foregroundStyle(WIFTheme.primaryText)
        .padding(14)
        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeSyncStatus")
    }

    private func addFriendButton(identifier: String = "addFriendButton") -> some View {
        WIFGlassEffectGroup(spacing: 10) {
            Button {
                invitationDraft.reset()
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
                            .foregroundStyle(WIFTheme.onDestructive)
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
            .accessibilityIdentifier(identifier)
        }
    }

    private var sharingIsEnabled: Bool {
        store.snapshot.sharingPreferences.citySharingEnabled
    }

    private var hasCurrentCity: Bool {
        CityIdentity.presenceKey(city: store.currentCity,
                                countryCode: store.snapshot.currentPresence.countryCode,
                                administrativeArea: store.snapshot.currentPresence.administrativeArea) != nil
    }

    private var isCurrentCityRecent: Bool {
        PresenceMatchPolicy.isRecent(store.snapshot.currentPresence.updatedAt, at: referenceDate)
    }

    private var cityStatusText: LocalizedStringKey {
        guard hasCurrentCity else { return "Your city isn’t set yet" }
        let city = store.snapshot.currentPresence.cityDisplay
        return isCurrentCityRecent ? "You’re in \(city)" : "Last shared city: \(city)"
    }

    private var cityRecoveryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if locationService.isResolving {
                // Opening the app already starts a city check; asking for a manual
                // update while it runs made a working app look stuck.
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Updating your city…")
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("homeCityUpdating")
            } else {
                Text(hasCurrentCity ? "Update your city to check who’s nearby." : "Choose a city to find same-city friends.")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onOpenCitySharing) {
                    Text(hasCurrentCity ? "Update your city" : "Set your city")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WIFTheme.fresh)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("homeCityRecoveryButton")
            }
        }
        .animation(.easeOut(duration: 0.2), value: locationService.isResolving)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wifContentSurface(tint: WIFTheme.surface.opacity(0.08),
                           in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
    }

    private func nextPlan(for friend: FriendPresence) -> FriendTravelPlan? {
        travelPlans.visibleFriendPlans(
            friendIDs: Set(friends.map(\.id)).subtracting(store.snapshot.blockedUserIDs), at: referenceDate
        ).first { $0.friendID == friend.id }
    }

    /// Long-press shortcuts so the common actions don't require opening the detail page.
    @ViewBuilder
    private func friendCardMenu(_ friend: FriendPresence) -> some View {
        Button {
            Task { await store.setFavorite(friendID: friend.id, isFavorite: !friend.isFavorite) }
        } label: {
            Label(friend.isFavorite ? "Remove favorite" : "Add favorite",
                  systemImage: friend.isFavorite ? "star.slash" : "star")
        }
    }

    private func friendCard(_ friend: FriendPresence) -> some View {
        let freshness = friend.freshness(at: referenceDate)
        let isSameCity = isFriendInSameCity(friend)
        let nextPlan = nextPlan(for: friend)

        return VStack(spacing: 6) {
            CityEmblemView(friend: friend, size: 88)
                .padding(.top, 9)

            VStack(spacing: 2) {
                Text(friend.displayName)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)

                Text(friend.cityDisplay)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.82)

                // Green is reserved for the live same-city state; a recent update is the
                // normal case and stays quiet, while an old one earns a clock.
                HStack(spacing: 4) {
                    if isSameCity {
                        Circle()
                            .fill(WIFTheme.fresh)
                            .frame(width: 5, height: 5)

                        Text("Same city")
                            .foregroundStyle(WIFTheme.fresh)

                        Text("·")
                            .foregroundStyle(WIFTheme.secondaryText.opacity(0.72))
                    } else if freshness != .fresh {
                        Image(systemName: "clock")
                            .imageScale(.small)
                            .foregroundStyle(WIFTheme.secondaryText)
                    }

                    Text(friend.relativeUpdateText(at: referenceDate))
                        .foregroundStyle(isSameCity ? WIFTheme.fresh : WIFTheme.secondaryText)
                }
                .font(.caption2.weight(.medium))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
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
        .overlay(alignment: .topTrailing) {
            if let nextPlan {
                FriendPlanBadge(planID: nextPlan.id, isActive: isHomeVisible && scenePhase == .active)
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(friend.displayName), \(friend.cityDisplay), \(isSameCity ? "\(String(localized: "Same city")), " : "")\(friend.relativeUpdateLongText(at: referenceDate))\(nextPlan != nil ? ", \(String(localized: "Has shared travel plans"))" : "")"
        )
    }

}

/// Accounts that never met a notification prompt have no push device, so trip
/// reminders and same-city alerts can't reach them. Offered once, until decided.
private struct NotificationPromptCard: View {
    @ObservedObject var service: LocalNotificationService
    let ownerID: UUID
    let onEnable: () async -> Void
    @State private var dismissed: Bool

    init(service: LocalNotificationService, ownerID: UUID, onEnable: @escaping () async -> Void) {
        self.service = service
        self.ownerID = ownerID
        self.onEnable = onEnable
        _dismissed = State(initialValue: UserDefaults.standard.bool(forKey: Self.dismissalKey(ownerID)))
    }

    private static func dismissalKey(_ ownerID: UUID) -> String { "notifications.homePrompt.dismissed.\(ownerID.uuidString)" }
    private var dismissalKey: String { Self.dismissalKey(ownerID) }

    var body: some View {
        if service.authorizationStatus == .notDetermined, !dismissed {
            VStack(alignment: .leading, spacing: 8) {
                Label("Turn on notifications", systemImage: "bell.badge")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                Text("Hear when a friend is in your city, and get trip reminders from your group.")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 16) {
                    Button("Turn on") { Task { await onEnable() } }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WIFTheme.fresh)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("homeEnableNotifications")
                    Button("Not now") {
                        UserDefaults.standard.set(true, forKey: dismissalKey)
                        dismissed = true
                    }
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("homeDismissNotifications")
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .wifContentSurface(tint: WIFTheme.fresh.opacity(0.07),
                               in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("homeNotificationPrompt")
        }
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

/// Everyone sharing your city, opened from the Friends header when there's more than one.
private struct SameCityFriendsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let friends: [FriendPresence]
    let presence: CurrentUserPresence
    let referenceDate: Date

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Here with you")
                                .font(.caption2.weight(.semibold)).textCase(.uppercase).tracking(1.2)
                                .foregroundStyle(WIFTheme.secondaryText)
                            Text(presence.city ?? "")
                                .font(.system(size: 38, weight: .regular, design: .serif)).tracking(-0.8)
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text("\(friends.count) friends")
                                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                        }
                        Spacer(minLength: 0)
                        CityEmblemView(city: presence.city, countryCode: presence.countryCode,
                                       administrativeArea: presence.administrativeArea, size: 104)
                            .frame(width: 96, height: 96)
                    }
                    VStack(spacing: 0) {
                        ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                            if index > 0 { Divider().overlay(WIFTheme.border).padding(.leading, 70) }
                            NavigationLink(value: friend) {
                                HStack(spacing: 14) {
                                    FriendAvatarView(friend: friend, size: 40)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(friend.displayName).font(.headline)
                                        Text(friend.relativeUpdateLongText(at: referenceDate))
                                            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                        .foregroundStyle(WIFTheme.secondaryText).accessibilityHidden(true)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("sameCityFriend-\(friend.username)")
                        }
                    }
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous))
                }
                .foregroundStyle(WIFTheme.primaryText)
                .padding(WIFTheme.screenInset)
            }
            .wifAmbientBackground()
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: FriendPresence.self) { FriendDetailView(friend: $0) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
