import SwiftUI

struct FriendTravelPlansView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var library: TravelPlanLibrary
    @Environment(\.scenePhase) private var scenePhase
    @State private var editing: PersonalTravelPlan?

    private var plans: [FriendTravelPlan] {
        library.visibleFriendPlans(friendIDs: Set(store.friends.map(\.id)).subtracting(store.snapshot.blockedUserIDs))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where are friends going?").font(.largeTitle.bold())
                    Text("See where your friends are headed.")
                        .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                }

                Button {
                    editing = PersonalTravelPlan(city: "", countryCode: "", region: "", timeZone: TimeZone.current.identifier,
                        startDay: TripDay(Date()).value, endDay: TripDay(Date().addingTimeInterval(3 * 86400)).value)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.plus").font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Add my plan").font(.subheadline.weight(.semibold))
                            Text("Add a city and your dates.").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .padding(18).frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .background(WIFTheme.fresh.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(WIFTheme.fresh).accessibilityIdentifier("addMyFriendPlan")

                if let error = library.errorMessage, !library.hasSynced {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Shared plans are unavailable", systemImage: "calendar.badge.exclamationmark").font(.headline)
                        Text(error).font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                        Button("Try again") { Task { await library.refresh() } }.frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("friendPlansError")
                } else if library.isLoading && plans.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 32)
                } else if plans.isEmpty {
                    ContentUnavailableView {
                        Label("No shared plans yet", systemImage: "calendar")
                    } description: {
                        Text("Plans friends choose to show you will appear here.")
                    }
                    .accessibilityIdentifier("friendPlansEmpty")
                } else {
                    HStack {
                        Text("Friends’ upcoming cities").font(.headline)
                        Spacer()
                        Text("By start date").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    }
                    ForEach(plans) { plan in
                        FriendTravelPlanCard(plan: plan) { editing = plan.privateDraft() }
                    }
                }
            }
            .foregroundStyle(WIFTheme.primaryText).padding(WIFTheme.screenInset).padding(.bottom, 20)
        }
        .wifAmbientBackground()
        .navigationTitle("Friend plans").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink("My plans") { TravelPlansView() }.accessibilityIdentifier("manageOwnTravelPlans")
            }
        }
        .sheet(item: $editing) { PersonalPlanEditor(plan: $0) }
        .refreshable { await library.refresh() }
        .task {
            while !Task.isCancelled {
                if scenePhase == .active { await library.refresh() }
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await library.refresh() } }
        }
        .accessibilityIdentifier("friendPlansScreen")
    }
}

private struct FriendTravelPlanCard: View {
    @EnvironmentObject private var store: AppStore
    let plan: FriendTravelPlan
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let friend = store.friend(id: plan.friendID) { FriendAvatarView(friend: friend, size: 28) }
                Text(plan.friendName).font(.subheadline.weight(.medium))
                Spacer(minLength: 4)
            }
            NavigationLink {
                FriendTravelPlanDetailView(planID: plan.id)
            } label: {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(plan.city).font(.title2.weight(.semibold))
                        Text(plan.dateLabel).font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                    }
                    Spacer(minLength: 0)
                    CityEmblemView(city: plan.city, countryCode: plan.countryCode, administrativeArea: plan.region, size: 82)
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("friendPlan-\(plan.id)")
            Divider().overlay(WIFTheme.border)
            HStack(spacing: 18) {
                Button(action: onCopy) { Label("I’ll be there too", systemImage: "calendar.badge.plus") }
                    .accessibilityIdentifier("copyFriendPlan-\(plan.id)")
                ShareLink(item: greeting(for: plan)) { Label("Say hello", systemImage: "bubble.left") }
            }
            .font(.caption.weight(.medium)).buttonStyle(.plain).foregroundStyle(WIFTheme.fresh)
            .frame(minHeight: 44)
        }
        .padding(18).background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct FriendTravelPlanDetailView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var library: TravelPlanLibrary
    @Environment(\.scenePhase) private var scenePhase
    let planID: UUID
    @State private var draft: PersonalTravelPlan?

    private var plan: FriendTravelPlan? {
        library.visibleFriendPlans(friendIDs: Set(store.friends.map(\.id)).subtracting(store.snapshot.blockedUserIDs))
            .first { $0.id == planID }
    }

    var body: some View {
        ScrollView {
            if let plan {
                VStack(spacing: 20) {
                    Text(plan.friendName).font(.headline)
                    CityEmblemView(city: plan.city, countryCode: plan.countryCode, administrativeArea: plan.region, size: 145)
                    Text(plan.city).font(.largeTitle.bold())
                    Text(plan.dateLabel).font(.title3).foregroundStyle(WIFTheme.fresh)
                    Text("Local dates in \(plan.city)").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    Button { draft = plan.privateDraft() } label: {
                        Label("I’ll be there too", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(TravelPrimaryButtonStyle()).accessibilityIdentifier("copyFriendPlanDetail")
                    ShareLink(item: greeting(for: plan)) { Label("Say hello", systemImage: "bubble.left") }
                        .font(.subheadline).frame(minHeight: 44)
                    Text("Review your plan before saving.")
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText).multilineTextAlignment(.center)
                }
                .padding(WIFTheme.screenInset).padding(.top, 20)
            } else if library.isLoading {
                ProgressView().padding(40)
            } else {
                ContentUnavailableView {
                    Label("This plan is unavailable", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("The plan may have ended, or its owner changed sharing. Connect to refresh.")
                } actions: {
                    Button("Try again") { Task { await library.refresh() } }
                }
                .accessibilityIdentifier("friendPlanUnavailable")
            }
        }
        .wifAmbientBackground().foregroundStyle(WIFTheme.primaryText)
        .navigationTitle("Friend’s plan").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            while !Task.isCancelled {
                if scenePhase == .active { await library.refresh() }
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await library.refresh() } }
        }
        .sheet(item: $draft) { PersonalPlanEditor(plan: $0) }
        .accessibilityIdentifier("friendPlanDetail")
    }
}

private func greeting(for plan: FriendTravelPlan) -> String {
    String(localized: "I saw you’ll be in \(plan.city) on \(plan.dateLabel). Want to meet up?")
}
