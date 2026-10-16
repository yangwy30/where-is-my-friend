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

    private func overlapsMine(_ plan: FriendTravelPlan) -> Bool {
        library.plans.contains {
            $0.city == plan.city && $0.countryCode == plan.countryCode && $0.startDay <= plan.endDay && $0.endDay >= plan.startDay
        }
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
                    Text("Friends’ upcoming cities").font(.headline).padding(.leading, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                            if index > 0 { Divider().overlay(WIFTheme.border).padding(.leading, 86) }
                            FriendTravelPlanRow(plan: plan, isAlsoMine: overlapsMine(plan)) {
                                editing = PersonalPlanDraft(plan: plan.privateDraft(), source: .friend(plan.friendName))
                            }
                        }
                    }
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous))
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

private struct FriendTravelPlanRow: View {
    @EnvironmentObject private var store: AppStore
    let plan: FriendTravelPlan
    let isAlsoMine: Bool
    let onCopy: () -> Void

    private var firstName: String {
        plan.friendName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? plan.friendName
    }

    var body: some View {
        HStack(spacing: 8) {
            NavigationLink {
                FriendTravelPlanDetailView(planID: plan.id)
            } label: {
                HStack(spacing: 14) {
                    CityEmblemView(city: plan.city, countryCode: plan.countryCode, administrativeArea: plan.region, size: 56)
                        .frame(width: 56, height: 56)
                        .overlay(alignment: .bottomTrailing) {
                            if let friend = store.friend(id: plan.friendID) {
                                FriendAvatarView(friend: friend, size: 24)
                                    .overlay(Circle().stroke(WIFTheme.surface, lineWidth: 2))
                                    .offset(x: 5, y: 3)
                            }
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(plan.city).font(.system(size: 23, weight: .regular, design: .serif)).tracking(-0.4).lineLimit(1)
                            if isAlsoMine {
                                Text("You’re there too")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(WIFTheme.fresh)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(WIFTheme.fresh.opacity(0.14), in: Capsule())
                            }
                        }
                        Text("\(firstName) · \(plan.dateLabel)")
                            .font(.subheadline).foregroundStyle(WIFTheme.secondaryText).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityIdentifier("friendPlan-\(plan.id)")
            .contextMenu {
                Button(action: onCopy) { Label("Add to my travel plans", systemImage: "calendar.badge.plus") }
            }
            if isAlsoMine {
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.secondaryText).frame(width: 32).accessibilityHidden(true)
            } else {
                Button(action: onCopy) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.body).foregroundStyle(WIFTheme.fresh)
                        .frame(width: 44, height: 44)
                        .background(WIFTheme.fresh.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add to my travel plans")
                .accessibilityIdentifier("copyFriendPlan-\(plan.id)")
            }
        }
        .padding(.leading, 16).padding(.trailing, 12).padding(.vertical, 14)
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

