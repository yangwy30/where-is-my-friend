import SwiftUI

struct FriendTravelPlansView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var library: TravelPlanLibrary
    @Environment(\.scenePhase) private var scenePhase
    @State private var editing: PersonalPlanDraft?
    @StateObject private var feed = FriendPlanFeed()

    private var plans: [FriendTravelPlan] {
        guard feed.matches(library) else { return [] }
        let allowed = Set(store.friends.map(\.id)).subtracting(store.snapshot.blockedUserIDs)
        return feed.items.filter { allowed.contains($0.friendID) && !$0.isPast() }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                Button {
                    editing = PersonalPlanDraft(plan: PersonalTravelPlan(city: "", countryCode: "", region: "", timeZone: TimeZone.current.identifier,
                        startDay: TripDay(Date()).value, endDay: TripDay(Date().addingTimeInterval(3 * 86400)).value))
                } label: {
                    Label("Add a travel plan", systemImage: "calendar.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(WIFTheme.fresh).accessibilityIdentifier("addMyFriendPlan")

                if let error = feed.errorMessage, !feed.hasLoaded {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Shared plans are unavailable", systemImage: "calendar.badge.exclamationmark").font(.headline)
                        Text(error).font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                        Button("Try again") { Task { await feed.refresh() } }.frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("friendPlansError")
                } else if feed.isLoading && plans.isEmpty {
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
                        FriendTravelPlanCard(plan: plan) { editing = PersonalPlanDraft(plan: plan.privateDraft(), source: .friend(plan.friendName)) }
                    }
                    if feed.nextCursor != nil {
                        Button { Task { await feed.loadMore() } } label: { Text(feed.errorMessage == nil ? String(localized: "Load more") : String(localized: "Try again")) }
                            .frame(maxWidth: .infinity, minHeight: 44).disabled(feed.isLoading)
                            .accessibilityIdentifier("loadMoreFriendPlans")
                        if feed.isLoading { ProgressView() }
                    }
                }
            }
            .foregroundStyle(WIFTheme.primaryText).padding(WIFTheme.screenInset).padding(.bottom, 20)
        }
        .wifAmbientBackground()
        .navigationTitle("Friends’ travel plans").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { TravelPlansView() } label: { Image(systemName: "calendar") }
                    .accessibilityLabel("My travel plans").accessibilityIdentifier("manageOwnTravelPlans")
            }
        }
        .sheet(item: $editing) { PersonalPlanEditor(plan: $0.plan, source: $0.source) }
        .refreshable { await feed.refresh() }
        .task(id: "\(library.accountScope ?? "")|\(library.accessRevision)") {
            feed.connect(library)
            while !Task.isCancelled {
                if scenePhase == .active { await feed.refresh(minimumInterval: 15) }
                do { try await Task.sleep(for: .seconds(Double.random(in: 60...75))) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await feed.refresh(minimumInterval: 15) } }
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
            VStack(alignment: .leading, spacing: 4) {
                Button(action: onCopy) { Label("Add to my travel plans", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }
                    .accessibilityIdentifier("copyFriendPlan-\(plan.id)")
                ShareLink(item: greeting(for: plan)) { Label("Share a meetup invite", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle()) }
                    .accessibilityHint("Choose an app to send your invitation.")
                    .accessibilityIdentifier("shareFriendPlanInvite-\(plan.id)")
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
    @State private var draft: PersonalPlanDraft?
    @StateObject private var feed = FriendPlanFeed()

    private var plan: FriendTravelPlan? {
        guard feed.matches(library) else { return nil }
        let allowed = Set(store.friends.map(\.id)).subtracting(store.snapshot.blockedUserIDs)
        return feed.items.first { $0.id == planID && allowed.contains($0.friendID) && !$0.isPast() }
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
                    Button { draft = PersonalPlanDraft(plan: plan.privateDraft(), source: .friend(plan.friendName)) } label: {
                        Label("Add to my travel plans", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(TravelPrimaryButtonStyle()).accessibilityIdentifier("copyFriendPlanDetail")
                    ShareLink(item: greeting(for: plan)) { Label("Share a meetup invite", systemImage: "square.and.arrow.up") }
                        .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                        .accessibilityIdentifier("shareFriendPlanInvite")
                    Text("Copy the city and dates, then choose who can see your own plan.")
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText).multilineTextAlignment(.center)
                }
                .padding(WIFTheme.screenInset).padding(.top, 20)
            } else if feed.isLoading {
                ProgressView().padding(40)
            } else {
                ContentUnavailableView {
                    Label("This plan is unavailable", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("The plan may have ended, or its owner changed sharing. Connect to refresh.")
                } actions: {
                    Button("Try again") { Task { await feed.refresh() } }
                }
                .accessibilityIdentifier("friendPlanUnavailable")
            }
        }
        .wifAmbientBackground().foregroundStyle(WIFTheme.primaryText)
        .navigationTitle("Friend’s plan").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task(id: "\(library.accountScope ?? "")|\(library.accessRevision)") {
            feed.connect(library, planID: planID)
            while !Task.isCancelled {
                if scenePhase == .active { await feed.refresh(minimumInterval: 15) }
                do { try await Task.sleep(for: .seconds(Double.random(in: 60...75))) } catch { return }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await feed.refresh(minimumInterval: 15) } }
        }
        .sheet(item: $draft) { PersonalPlanEditor(plan: $0.plan, source: $0.source) }
        .accessibilityIdentifier("friendPlanDetail")
    }
}

private func greeting(for plan: FriendTravelPlan) -> String {
    String(localized: "I saw you’ll be in \(plan.city) on \(plan.dateLabel). Want to meet up?")
}
