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

    private var sharedPlans: [FriendTravelPlan] {
        let allowed = Set(store.friends.map(\.id)).subtracting(store.snapshot.blockedUserIDs)
        return travelPlans.visibleFriendPlans(friendIDs: allowed, at: referenceDate)
            .filter { $0.friendID == friend.id }
    }

    private var currentFriend: FriendPresence {
        store.friend(id: friend.id) ?? friend
    }

    private var preference: FriendAccessPreference {
        store.preference(for: friend.id)
    }

    var body: some View {
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

                if !sharedPlans.isEmpty { sharedPlansSection.padding(.top, 24) }
                citySurface.padding(.top, 20)

                sectionLabel("Between you two").padding(.top, 24)

                VStack(spacing: 0) {
                    Toggle(isOn: sharesMyCityBinding) {
                        settingLabel("Share my city", note: "\(currentFriend.displayName) can see your latest city")
                    }
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
        .wifAmbientBackground()
        .navigationTitle(currentFriend.displayName.components(separatedBy: " ").first ?? currentFriend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .refreshable { await store.refresh(); referenceDate = Date() }
        .task {
            await store.preparePushRegistrationIfAuthorized()
            while !Task.isCancelled {
                referenceDate = Date()
                if scenePhase == .active { await travelPlans.refresh() }
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { referenceDate = Date(); await travelPlans.refresh() } }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
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
            store.preference(for: currentFriend.id).sharesMyCity
        } set: { newValue in
            var updated = store.preference(for: currentFriend.id)
            updated.sharesMyCity = newValue
            Task { await store.setFriendPreference(updated) }
        }
    }

    private var sharedPlansSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Travel plans")
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
        }
    }

    private var sameCityAlertBinding: Binding<Bool> {
        Binding {
            store.preference(for: currentFriend.id).sameCityAlertEnabled
        } set: { newValue in
            var updated = store.preference(for: currentFriend.id)
            updated.sameCityAlertEnabled = newValue
            Task { await store.setFriendPreference(updated) }
        }
    }

    private var citySurface: some View {
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
