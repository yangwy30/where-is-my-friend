import SwiftUI

struct FriendDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var travelPlans: TravelPlanLibrary
    @Environment(\.scenePhase) private var scenePhase
    let friend: FriendPresence
    @State private var showsRemoveConfirmation = false
    @State private var showsBlockConfirmation = false
    @State private var referenceDate = Date()
    @StateObject private var planFeed = FriendPlanFeed()
    #if DEBUG
    @State private var simulatedRevocationOwner: UUID?
    #endif

    private var sharedPlans: [FriendTravelPlan] {
        let allowed = Set(store.friends.map(\.id)).subtracting(store.snapshot.blockedUserIDs)
        guard planFeed.matches(travelPlans) else { return [] }
        return planFeed.items.filter { $0.friendID == friend.id && allowed.contains($0.friendID) && !$0.isPast(at: referenceDate) }
    }

    private var currentFriend: FriendPresence? {
        guard store.snapshot.isAuthenticated,
              !store.snapshot.blockedUserIDs.contains(friend.id) else { return nil }
        // Navigation values are snapshots, not continuing permission to display
        // a friend's presence after a confirmed removal or block.
        return store.friend(id: friend.id)
    }

    private var preference: FriendAccessPreference {
        store.preference(for: friend.id)
    }

    var body: some View {
        Group {
            if let currentFriend {
                details(for: currentFriend)
            } else {
                ContentUnavailableView {
                    Label("Friend unavailable", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("This friend is no longer available for this account. Refresh your friends and try again.")
                } actions: {
                    Button("Try again") { Task { await store.refresh() } }
                        .frame(minHeight: 44)
                        .disabled(store.isWorking)
                }
                .accessibilityIdentifier("friendDetailUnavailable")
                .navigationTitle("Friend unavailable")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .wifAmbientBackground()
        .refreshable {
            await store.refresh()
            if currentFriend != nil { await planFeed.refresh() }
            referenceDate = Date()
        }
        .task(id: "\(travelPlans.accountScope ?? "")|\(travelPlans.accessRevision)") {
            planFeed.connect(travelPlans, friendID: friend.id)
            guard currentFriend != nil else { return }
            await store.preparePushRegistrationIfAuthorized()
            while !Task.isCancelled, currentFriend != nil {
                referenceDate = Date()
                if scenePhase == .active { await planFeed.refresh(minimumInterval: 15) }
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, currentFriend != nil {
                Task { referenceDate = Date(); await planFeed.refresh(minimumInterval: 15) }
            }
        }
        .onChange(of: currentFriend == nil) { _, unavailable in
            if unavailable {
                showsRemoveConfirmation = false
                showsBlockConfirmation = false
            }
        }
        #if DEBUG
        .task(id: store.snapshot.isAuthenticated ? store.snapshot.currentUser.id : nil) {
            guard store.repositoryMode == .localDemo,
                  ProcessInfo.processInfo.arguments.contains("-testFriendRevokedAfterOpen"),
                  store.snapshot.isAuthenticated, currentFriend != nil else { return }
            let owner = store.snapshot.currentUser.id
            guard simulatedRevocationOwner != owner else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard !Task.isCancelled, store.snapshot.isAuthenticated,
                  store.snapshot.currentUser.id == owner, currentFriend != nil else { return }
            simulatedRevocationOwner = owner
            // Simulate a remote removal reaching an already-open detail view.
            // Deliberately bypass its local Remove action, which normally pops.
            await store.removeFriend(id: friend.id)
        }
        #endif
    }

    private func details(for currentFriend: FriendPresence) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Text(currentFriend.displayName)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .padding(.top, 18)

                Text("@\(currentFriend.username)")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 3)

                citySurface(for: currentFriend).padding(.top, 20)
                // Where they are now comes first (F12). Plans load after the view appears, so they
                // also belong below the city: arriving late, they no longer shove it down the screen.
                if !sharedPlans.isEmpty || planFeed.isLoading || planFeed.errorMessage != nil { sharedPlansSection.padding(.top, 24) }

                sectionLabel("Between you two").padding(.top, 24)

                VStack(spacing: 0) {
                    Toggle(isOn: sharesMyCityBinding) {
                        settingLabel("Share my city", note: citySharingExplanation(for: currentFriend))
                    }
                    .accessibilityIdentifier("friendCitySharingToggle")
                    .disabled(store.isSavingFriendPreference(for: friend.id))
                    .tint(WIFTheme.fresh)
                    .padding(15)

                    Divider().overlay(WIFTheme.border).padding(.leading, 15)

                    Toggle(isOn: sameCityAlertBinding) {
                        settingLabel("Same-city alert", note: "Notify me when your cities overlap")
                    }
                    .disabled(store.isSavingFriendPreference(for: friend.id))
                    .tint(WIFTheme.fresh)
                    .padding(15)

                    if preference.sameCityAlertEnabled {
                        InvitationNotificationStatusView(service: store.notificationService, isSameCityContext: true)
                            .padding(.horizontal, 8)
                    }

                    Divider().overlay(WIFTheme.border).padding(.leading, 15)

                    Button(role: .destructive) { showsRemoveConfirmation = true } label: {
                        HStack {
                            settingLabel("Remove friend", note: "Stops sharing both ways")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WIFTheme.destructive)
                    .padding(15)
                    .accessibilityIdentifier("removeFriendButton")

                    Divider().overlay(WIFTheme.border).padding(.leading, 15)

                    Button(role: .destructive) { showsBlockConfirmation = true } label: {
                        HStack {
                            settingLabel("Block person", note: "Also removes the friendship and pending requests")
                            Spacer()
                            Image(systemName: "hand.raised.slash.fill").font(.caption.weight(.semibold))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WIFTheme.destructive)
                    .padding(15)
                    .accessibilityIdentifier("blockFriendButton")
                }
                .wifContentSurface(
                    tint: WIFTheme.surface.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius, style: .continuous)
                )
            }
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 28)
        }
        .navigationTitle(currentFriend.displayName.components(separatedBy: " ").first ?? currentFriend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        guard self.currentFriend != nil else { return }
                        await store.setFavorite(
                            friendID: currentFriend.id,
                            isFavorite: !currentFriend.isFavorite
                        )
                    }
                } label: {
                    Image(systemName: currentFriend.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(currentFriend.isFavorite ? "Remove favorite" : "Add favorite")
            }
        }
        .confirmationDialog(
            "Remove \(currentFriend.displayName)?",
            isPresented: $showsRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove friend", role: .destructive) {
                Task {
                    guard self.currentFriend != nil else { return }
                    await store.removeFriend(id: currentFriend.id)
                    if store.friend(id: currentFriend.id) == nil { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The friendship and per-friend sharing preferences will be removed.")
        }
        .confirmationDialog(
            "Block \(currentFriend.displayName)?",
            isPresented: $showsBlockConfirmation,
            titleVisibility: .visible
        ) {
            Button("Block person", role: .destructive) {
                Task {
                    guard self.currentFriend != nil else { return }
                    await store.blockUser(id: currentFriend.id)
                    if store.friend(id: currentFriend.id) == nil { dismiss() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will not be able to invite you or see your city. You can unblock them later in Privacy settings.")
        }
    }

    private var sharesMyCityBinding: Binding<Bool> {
        Binding {
            store.preference(for: friend.id).sharesMyCity
        } set: { newValue in
            guard currentFriend != nil else { return }
            var updated = store.preference(for: friend.id)
            updated.sharesMyCity = newValue
            Task { await store.setFriendPreference(updated) }
        }
    }

    private var sharedPlansSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Travel plans")
            if sharedPlans.isEmpty, planFeed.isLoading { ProgressView().padding(.vertical, 16) }
            if sharedPlans.isEmpty, let error = planFeed.errorMessage {
                Text(error).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                Button("Try again") { Task { await planFeed.refresh() } }.frame(minHeight: 44)
            }
            ForEach(sharedPlans) { plan in
                NavigationLink {
                    FriendTravelPlanDetailView(planID: plan.id)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(plan.city).font(.title3.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
                            Text(plan.privateDraft().destination.subtitle)
                                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                            Text(plan.dateLabel).font(.subheadline).foregroundStyle(WIFTheme.fresh)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                    .padding(.vertical, 15).frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("friendDetailPlan-\(plan.id)")
                Divider().overlay(WIFTheme.border.opacity(0.4))
            }
            if planFeed.nextCursor != nil {
                Button { Task { await planFeed.loadMore() } } label: { Text(planFeed.errorMessage == nil ? String(localized: "Load more") : String(localized: "Try again")) }
                    .frame(maxWidth: .infinity, minHeight: 44).disabled(planFeed.isLoading)
                    .accessibilityIdentifier("loadMoreProfilePlans")
            }
        }
    }

    private func citySharingExplanation(for currentFriend: FriendPresence) -> LocalizedStringKey {
        if !preference.sharesMyCity {
            return "\(currentFriend.displayName) can’t see your city"
        }
        if !store.snapshot.sharingPreferences.citySharingEnabled {
            return "City sharing is paused. Resume it to share with \(currentFriend.displayName)."
        }
        guard let city = store.currentCity, !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Set your city to start sharing with \(currentFriend.displayName)."
        }
        return "\(currentFriend.displayName) can see your latest city"
    }

    private var sameCityAlertBinding: Binding<Bool> {
        Binding {
            store.preference(for: friend.id).sameCityAlertEnabled
        } set: { newValue in
            guard currentFriend != nil else { return }
            var updated = store.preference(for: friend.id)
            updated.sameCityAlertEnabled = newValue
            Task { await store.setFriendPreference(updated) }
        }
    }

    private func citySurface(for currentFriend: FriendPresence) -> some View {
        VStack(spacing: 12) {
            CityEmblemView(friend: currentFriend, size: 84)

            VStack(spacing: 4) {
                Text(currentFriend.fullCityDisplay)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)

                Text(currentFriend.relativeUpdateLongText(at: referenceDate))
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            if currentFriend.freshness(at: referenceDate) == .stale {
                Label("This location is too old for same-city alerts", systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .wifContentSurface(
            tint: WIFTheme.eventBlue.opacity(0.20),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(WIFTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 3)
            .padding(.bottom, 8)
    }

    private func settingLabel(_ title: LocalizedStringKey, note: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.body.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
            Text(note).font(.caption).foregroundStyle(WIFTheme.secondaryText)
        }
    }
}

#Preview {
    let store = AppStore()
    NavigationStack { FriendDetailView(friend: MockFriendData.friends[0]) }
        .environmentObject(store)
        .environmentObject(store.travelPlans)
}
