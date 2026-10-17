import MapKit
import SwiftUI

struct TravelPlansView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var library: TravelPlanLibrary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSharedTrips) private var openSharedTrips
    @State private var editing: PersonalPlanDraft?
    @State private var deleting: PersonalTravelPlan?
    @State private var showsPast = false
    @State private var importingTrip = false

    private var visiblePlans: [PersonalTravelPlan] { library.plans.filter { $0.isPast() == showsPast } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Tell friends where you’ll be, and when.")
                    .font(.title2.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Picker("Travel plan dates", selection: $showsPast) {
                    Text("Upcoming").tag(false); Text("Past").tag(true)
                }.pickerStyle(.segmented)
                if let error = library.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        Button("Try again") { Task { await library.refreshOwnPlans() } }
                    }
                }
                if visiblePlans.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "calendar.badge.plus").font(.title).foregroundStyle(WIFTheme.fresh)
                        Text(showsPast ? "No past plans" : "A city. A few dates.\nA chance to meet.").font(.title2.weight(.semibold))
                        if !showsPast {
                            Text("Choose when you’ll be somewhere and who can see your plan.")
                                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                            Button("Add a travel plan") { editing = newPlan() }
                                .buttonStyle(TravelPrimaryButtonStyle())
                                .accessibilityIdentifier("addTravelPlan")
                        }
                    }
                    .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 26))
                }
                ForEach(visiblePlans) { plan in
                    VStack(alignment: .leading, spacing: 12) {
                        Button { editing = PersonalPlanDraft(plan: plan) } label: {
                            HStack(spacing: 16) {
                                CityEmblemView(city: plan.city, countryCode: plan.countryCode, administrativeArea: plan.region, size: 68)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(plan.city).font(.title3.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
                                    Text(plan.dateLabel).font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                                    Group {
                                        if plan.audience.isEmpty {
                                            Text("Only you")
                                        } else if plan.allowFriendBrowsing {
                                            Text("Visible to \(plan.audience.count) friends")
                                        } else {
                                            Text("Can match with \(plan.audience.count) friends")
                                        }
                                    }
                                    .font(.caption).foregroundStyle(WIFTheme.fresh)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                            }
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("travelPlan-\(plan.id)")
                        Button("Delete plan", role: .destructive) { deleting = plan }
                            .font(.caption).frame(minHeight: 44)
                    }
                    .padding(18).background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 25))
                }
                Button { importingTrip = true } label: { Label("Use dates from a shared trip", systemImage: "airplane") }
                    .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("importSharedTripDates")
                Button {
                    dismiss()
                    openSharedTrips()
                } label: {
                    TravelPurposeLink(title: "Coordinating flights with friends?", subtitle: "Go to Shared trips", symbol: "person.2")
                }
                .buttonStyle(.plain).accessibilityIdentifier("openSharedTrips")
                Text("Plans don’t change your current city. Only the friends you choose can match with you.")
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
            }
            .padding(WIFTheme.screenInset)
        }
        .wifAmbientBackground()
        .navigationTitle("My travel plans").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editing = newPlan() } label: { Image(systemName: "plus") }.accessibilityLabel("Add travel plan")
        } }
        .refreshable { await library.refreshOwnPlans() }
        .task { await library.refreshOwnPlans() }
        .sheet(item: $editing) { draft in PersonalPlanEditor(plan: draft.plan, source: draft.source) }
        .sheet(isPresented: $importingTrip) { TravelTripPicker() }
        .confirmationDialog("Delete this plan?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete plan", role: .destructive) {
                guard let plan = deleting else { return }
                Task { _ = await library.delete(plan); deleting = nil }
            }
        } message: { Text("Its shared dates and upcoming matches will be removed.") }
        .accessibilityIdentifier("travelPlansScreen")
    }

    private func newPlan() -> PersonalPlanDraft {
        PersonalPlanDraft(plan: PersonalTravelPlan(city: "", countryCode: "", region: "", timeZone: TimeZone.current.identifier,
                           startDay: TripDay(Date()).value, endDay: TripDay(Date().addingTimeInterval(3 * 86400)).value))
    }
}

struct TravelPurposeLink: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                text.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 14) {
                    Image(systemName: symbol).font(.title3).accessibilityHidden(true)
                    text
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                }
            }
        }
        .multilineTextAlignment(.leading)
        .foregroundStyle(WIFTheme.fresh).padding(18)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(WIFTheme.fresh.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
        .contentShape(Rectangle())
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.subheadline.weight(.semibold))
            Text(subtitle).font(.caption).foregroundStyle(WIFTheme.secondaryText)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct TravelPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(WIFTheme.canvas)
            .background(WIFTheme.fresh.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

struct PersonalPlanEditor: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var library: TravelPlanLibrary
    @Environment(\.dismiss) private var dismiss
    @State var plan: PersonalTravelPlan
    var source: PersonalPlanDraft.Source? = nil
    @State private var choosingCity = false
    @State private var choosingAudience = false
    @State private var choosingDates = false
    @State private var error: String?
    @State private var initializedAudience = false
    @State private var customizedAudience = false
    @State private var initialPlan: PersonalTravelPlan?
    @State private var confirmsDiscard = false

    private var hasUnsavedChanges: Bool {
        guard var baseline = initialPlan else { return false }
        var current = plan
        // Audience order is presentation detail, not a change to who can see the plan.
        guard Set(baseline.audience) == Set(current.audience) else { return true }
        baseline.audience = []
        current.audience = []
        return baseline != current
    }

    private var allFriendIDs: [UUID] {
        TravelPlanAudiencePolicy.defaultAudience(friendIDs: store.friends.map(\.id), blockedIDs: store.snapshot.blockedUserIDs)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("I’ll be in…").font(.largeTitle.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
                        if let source {
                            Group {
                                switch source {
                                case .friend(let name): Text("City and dates copied from \(name)")
                                case .sharedTrip(let name): Text("Using dates from “\(name)”")
                                }
                            }
                            .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("travelPlanCopySource")
                        }
                    }

                    // City, dates and audience read as one plan, so they share one card.
                    VStack(spacing: 0) {
                        Button { choosingCity = true } label: {
                            planRow(symbol: "mappin", title: "City",
                                    value: plan.city.isEmpty ? String(localized: "Search a city") : plan.city,
                                    detail: plan.city.isEmpty ? nil : plan.destination.subtitle,
                                    valueIsPlaceholder: plan.city.isEmpty)
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("travelPlanCity")
                        rowDivider
                        Button { choosingDates = true } label: {
                            planRow(symbol: "calendar", title: "Dates", value: plan.dateLabel,
                                    detail: plan.city.isEmpty ? nil : String(localized: "Local dates in \(plan.city)"))
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("travelPlanDates")
                        rowDivider
                        Button { choosingAudience = true } label: {
                            planRow(symbol: "person.2", title: "Share with", value: audienceSummary,
                                    detail: plan.revision == 0 && !customizedAudience
                                        ? String(localized: "All current friends are selected by default. Deselect anyone before saving.") : nil)
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("travelPlanAudience")
                    }
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(spacing: 0) {
                        Toggle(isOn: $plan.allowFriendBrowsing) {
                            toggleLabel("Show in friends’ travel plans", detail: plan.audience.isEmpty
                                ? String(localized: "Choose friends to show them this plan.")
                                : plan.allowFriendBrowsing
                                    ? String(localized: "Selected friends can see its city and dates.")
                                    : String(localized: "Selected friends can still see a match when your dates overlap."))
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .accessibilityIdentifier("travelPlanBrowsing")
                        rowDivider
                        Toggle(isOn: $plan.alertsEnabled) {
                            toggleLabel("Remind me about overlaps",
                                        detail: String(localized: "Get a reminder up to 14 days before your plans overlap."))
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                        .accessibilityIdentifier("travelPlanAlerts")
                    }
                    .tint(WIFTheme.fresh)
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Group {
                        if case .sharedTrip = source {
                            Text("This plan is saved separately. Update it yourself if the shared trip’s dates change.")
                        } else {
                            Text("This saves your own travel plan. It doesn’t join a shared trip.")
                        }
                    }
                    .font(.footnote).foregroundStyle(WIFTheme.secondaryText)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("travelPlanBoundary")
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            // Save stays on screen instead of below five paragraphs of settings; errors sit beside it.
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    if let error { Text(error).font(.caption).foregroundStyle(WIFTheme.destructive).accessibilityIdentifier("travelPlanError") }
                    if plan.audience.count > 100 {
                        Text("Choose up to 100 friends for this plan.").font(.caption).foregroundStyle(WIFTheme.destructive)
                    }
                    Button {
                        Task {
                            if await library.save(plan) {
                                if plan.alertsEnabled { await store.requestNotificationAuthorization() }
                                dismiss()
                            } else { error = library.errorMessage }
                        }
                    } label: {
                        if library.isSaving { ProgressView() } else { Text("Save travel plan") }
                    }
                    .buttonStyle(TravelPrimaryButtonStyle())
                    .disabled(plan.city.isEmpty || plan.audience.count > 100 || library.isSaving)
                    .opacity(plan.city.isEmpty ? 0.5 : 1)
                    .accessibilityIdentifier("saveTravelPlan")
                }
                .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 8)
                .background(WIFTheme.canvas.opacity(0.72).background(.ultraThinMaterial).ignoresSafeArea(edges: .bottom))
            }
            .wifAmbientBackground().navigationTitle(plan.revision == 0 ? "New travel plan" : "Edit travel plan").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                if !choosingCity {
                    Button("Cancel") {
                        if hasUnsavedChanges { confirmsDiscard = true } else { dismiss() }
                    }.disabled(library.isSaving).accessibilityIdentifier("personalPlanCancel")
                }
            } }
            .sheet(isPresented: $choosingDates) {
                TravelDateRangePicker(startDay: plan.startDay, endDay: plan.endDay, timeZone: plan.timeZone) {
                    plan.startDay = $0; plan.endDay = $1
                }
            }
            .sheet(isPresented: $choosingCity) {
                NavigationStack {
                    TravelCityPicker(showsTripDestinations: true) { city in
                        plan.city = city.name; plan.countryCode = city.countryCode
                        plan.region = city.region; plan.timeZone = city.timeZone
                    }
                }
                .presentationDetents([.height(620), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
            }
            .navigationDestination(isPresented: $choosingAudience) {
                List {
                    Section {
                        Button("Select all friends") { customizedAudience = true; plan.audience = allFriendIDs }
                            .accessibilityIdentifier("selectAllTravelAudience")
                        Button("Clear selection") { customizedAudience = true; plan.audience = [] }
                            .accessibilityIdentifier("clearTravelAudience")
                    }
                    Section {
                        ForEach(store.friends.filter { !store.snapshot.blockedUserIDs.contains($0.id) }) { friend in
                            Toggle(isOn: Binding(get: { plan.audience.contains(friend.id) }, set: { value in
                                customizedAudience = true
                                plan.audience.removeAll { $0 == friend.id }
                                if value { plan.audience.append(friend.id) }
                            })) {
                                HStack(spacing: 10) { FriendAvatarView(friend: friend, size: 32); Text(friend.displayName) }
                            }.frame(minHeight: 46).accessibilityIdentifier("travelAudience-\(friend.username)")
                        }
                    } footer: {
                        Text("Selected friends can match with this plan. If you enable plan browsing, they can also see its full city and dates. Changes take effect when you save the plan.")
                    }
                }
                .scrollContentBackground(.hidden).background(WIFTheme.canvas)
                .navigationTitle("Share with friends").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { choosingAudience = false }.accessibilityIdentifier("travelAudienceDone")
                } }
            }
            .onAppear {
                guard !initializedAudience else { return }
                initializedAudience = true
                if plan.revision == 0 { plan.audience = allFriendIDs }
                initialPlan = plan
            }
            .onChange(of: allFriendIDs) { _, ids in
                // A cold launch may finish loading friends after the editor opens.
                // Never refill a selection the user has already customized.
                if initializedAudience, plan.revision == 0, !customizedAudience {
                    plan.audience = ids
                    initialPlan?.audience = ids
                }
            }
            .alert("Discard changes?", isPresented: $confirmsDiscard) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            } message: { Text("Your unsaved changes will be lost.") }
            .interactiveDismissDisabled(library.isSaving || hasUnsavedChanges)
        }
    }

    private var audienceSummary: String {
        plan.audience.isEmpty ? String(localized: "Only me · choose friends")
            : Set(plan.audience) == Set(allFriendIDs) ? String(localized: "All friends (\(plan.audience.count))")
            : String(localized: "\(plan.audience.count) selected friends")
    }

    private var rowDivider: some View { Divider().overlay(WIFTheme.border).padding(.leading, 62) }

    private func planRow(symbol: String, title: LocalizedStringKey, value: String, detail: String?,
                         valueIsPlaceholder: Bool = false) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium)).foregroundStyle(WIFTheme.fresh)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                Text(value).font(.body.weight(.semibold))
                    .foregroundStyle(valueIsPlaceholder ? WIFTheme.secondaryText : WIFTheme.primaryText)
                if let detail {
                    Text(detail).font(.footnote).foregroundStyle(WIFTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(WIFTheme.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func toggleLabel(_ title: LocalizedStringKey, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.body).foregroundStyle(WIFTheme.primaryText)
            Text(detail).font(.footnote).foregroundStyle(WIFTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct TravelCityPicker: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var library: TravelPlanLibrary
    @State private var query = ""
    @State private var cities: [TravelCity] = []
    @State private var tripShortcuts: [TripCityShortcut] = []
    @State private var shortcutsOwnerID: UUID?
    @State private var isSearching = false
    @State private var error: String?
    let showsCancelButton: Bool
    let showsTripDestinations: Bool
    let dismissOnSelect: Bool
    let onSelect: (TravelCity) -> Void

    private struct TripCityShortcut: Identifiable {
        let id: String
        let city: String
        let country: String
        let countryCode: String
    }

    init(initialQuery: String = "", showsCancelButton: Bool = true, showsTripDestinations: Bool = false, dismissOnSelect: Bool = true,
         onSelect: @escaping (TravelCity) -> Void) {
        _query = State(initialValue: initialQuery)
        self.showsCancelButton = showsCancelButton
        self.showsTripDestinations = showsTripDestinations
        self.dismissOnSelect = dismissOnSelect
        self.onSelect = onSelect
    }

    private var ownPlaces: [TravelCity] {
        guard store.snapshot.isAuthenticated else { return [] }
        let recent = TravelCityHistory.recent(origin: store.tripRepository.storageScope, ownerID: store.snapshot.currentUser.id)
        let planned = library.plans.sorted { $0.startDay > $1.startDay }.map(\.destination)
        var seen = Set<String>()
        var places: [TravelCity] = []
        for city in recent + planned where places.count < 3 {
            if seen.insert(city.id).inserted { places.append(city) }
        }
        return places
    }

    private var visibleTripShortcuts: [TripCityShortcut] {
        guard shortcutsOwnerID == store.snapshot.currentUser.id else { return [] }
        var seen = Set(ownPlaces.map { "\($0.name.lowercased())|\($0.countryCode)" })
        var shortcuts: [TripCityShortcut] = []
        for shortcut in tripShortcuts where shortcuts.count < 2 {
            if seen.insert("\(shortcut.city.lowercased())|\(shortcut.countryCode)").inserted {
                shortcuts.append(shortcut)
            }
        }
        return shortcuts
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if query.isEmpty { startingContent }
                else { searchContent }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .wifAmbientBackground()
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City or town")
        .navigationTitle("Choose a city").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsCancelButton {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .task(id: store.snapshot.currentUser.id) { await library.refreshOwnPlans(); await loadTripShortcuts() }
        .task(id: query) {
            cities = []; error = nil; isSearching = false
            let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 2 else { return }
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                isSearching = true
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = text
                request.resultTypes = .address
                let result = try await MKLocalSearch(request: request).start()
                guard !Task.isCancelled else { return }
                var seen = Set<String>()
                var resolved: [TravelCity] = []
                var placesWithoutCity: [CLLocation] = []
                for item in result.mapItems {
                    if let value = TravelCitySearchPolicy.resolve(name: item.name,
                        locality: item.placemark.locality, region: item.placemark.administrativeArea,
                        countryCode: item.placemark.isoCountryCode,
                        timeZone: (item.timeZone ?? item.placemark.timeZone)?.identifier) {
                        if seen.insert(value.id).inserted { resolved.append(value) }
                    } else if placesWithoutCity.count < 2, let location = item.placemark.location {
                        placesWithoutCity.append(location)
                    }
                }
                // Islands, counties and regions (e.g. a Kauai trip from its LIH airport) come back
                // without a city. Offer the city at that spot instead of "No city found".
                if resolved.isEmpty {
                    for location in placesWithoutCity {
                        guard !Task.isCancelled,
                              let place = try? await CLGeocoder().reverseGeocodeLocation(location).first,
                              let value = TravelCitySearchPolicy.resolve(name: place.name, locality: place.locality,
                                  region: place.administrativeArea, countryCode: place.isoCountryCode,
                                  timeZone: place.timeZone?.identifier) else { continue }
                        if seen.insert(value.id).inserted { resolved.append(value) }
                    }
                }
                guard !Task.isCancelled else { return }
                cities = resolved
                if cities.isEmpty { error = String(localized: "No city found. Try adding the country or region.") }
                isSearching = false
            } catch is CancellationError { } catch {
                guard !Task.isCancelled else { return }
                isSearching = false
                self.error = String(localized: "City search is unavailable. Check your connection and try again.")
            }
        }
    }

    @ViewBuilder
    private var startingContent: some View {
        if !ownPlaces.isEmpty {
            sectionHeading(String(localized: "Your places"))
            cityRows(ownPlaces)
        }
        if showsTripDestinations && !visibleTripShortcuts.isEmpty {
            sectionHeading(String(localized: "From your shared trips"))
            tripShortcutRows
        }
        if library.isDemo && ownPlaces.isEmpty && visibleTripShortcuts.isEmpty {
            sectionHeading(String(localized: "Demo cities"))
            cityRows(TravelCity.examples)
        }
        if ownPlaces.isEmpty && visibleTripShortcuts.isEmpty && !library.isDemo {
            Text("Search for a city or town. Results include its region and country.")
                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                .padding(.top, 20)
        }
    }

    @ViewBuilder
    private var searchContent: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            Text("Keep typing to search.").font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                .padding(.top, 20)
        }
        if isSearching { ProgressView("Searching cities…").padding(.top, 20) }
        cityRows(cities)
        if let error {
            Text(error).font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                .padding(.top, 20)
        }
    }

    private var tripShortcutRows: some View {
        ForEach(visibleTripShortcuts) { shortcut in
            Button { query = "\(shortcut.city), \(shortcut.country)" } label: {
                HStack(spacing: 12) {
                    locationLabel(city: shortcut.city,
                                  detail: Locale.current.localizedString(forRegionCode: shortcut.countryCode) ?? shortcut.country)
                    Spacer(minLength: 0)
                    Text("Find").font(.caption.weight(.semibold)).foregroundStyle(WIFTheme.fresh)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tripCity-\(shortcut.id)")
            Divider().overlay(WIFTheme.border.opacity(0.4))
        }
    }

    private func sectionHeading(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1.5)
            .foregroundStyle(WIFTheme.secondaryText)
            .padding(.top, 25)
            .padding(.bottom, 12)
    }

    private func loadTripShortcuts() async {
        tripShortcuts = []
        shortcutsOwnerID = nil
        guard showsTripDestinations, store.snapshot.isAuthenticated else { return }
        let ownerID = store.snapshot.currentUser.id
        let available: [TripPlan]
        do {
            if store.repositoryMode == .localDemo {
                available = TripPlan.examples(owner: .init(id: ownerID.uuidString,
                    name: store.snapshot.currentUser.displayName, userID: ownerID.uuidString))
            } else {
                available = try await store.tripRepository.fetchTrips().map { $0.plan(userID: ownerID.uuidString) }
            }
        } catch { return } // These are optional shortcuts; search remains available.
        guard !Task.isCancelled, store.snapshot.currentUser.id == ownerID else { return }
        var seen = Set<String>()
        var shortcuts: [TripCityShortcut] = []
        let relevant = available.filter { $0.phase() != .past }.sorted { $0.startDay < $1.startDay }
        for trip in relevant where shortcuts.count < 3 {
            guard let destination = trip.destination,
                  seen.insert("\(destination.city.lowercased())|\(destination.countryCode)").inserted else { continue }
            shortcuts.append(.init(id: trip.id, city: destination.city,
                                   country: destination.country, countryCode: destination.countryCode))
        }
        tripShortcuts = shortcuts
        shortcutsOwnerID = ownerID
    }

    private func cityRows(_ values: [TravelCity]) -> some View {
        ForEach(values) { city in
            Button { select(city) } label: {
                HStack(spacing: 12) {
                    locationLabel(city: city.name, detail: cityDetail(city))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("travelCity-\(city.name)")
            Divider().overlay(WIFTheme.border.opacity(0.4))
        }
    }

    private func locationLabel(city: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(city).font(.body.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
            Text(detail).font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cityDetail(_ city: TravelCity) -> String {
        let region = city.region.trimmingCharacters(in: .whitespacesAndNewlines)
        guard region.localizedCaseInsensitiveCompare(city.name) == .orderedSame else { return city.subtitle }
        return Locale.current.localizedString(forRegionCode: city.countryCode) ?? city.countryCode
    }

    private func select(_ city: TravelCity) {
        if store.snapshot.isAuthenticated {
            TravelCityHistory.remember(city, origin: store.tripRepository.storageScope,
                                       ownerID: store.snapshot.currentUser.id)
        }
        onSelect(city)
        if dismissOnSelect { dismiss() }
    }
}

struct UpcomingAlertBanner: View {
    @EnvironmentObject private var store: AppStore
    let overlap: TravelOverlap

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button { store.openUpcomingOverlap(overlap.id) } label: {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Together soon · Across Us", systemImage: "bell.badge")
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    Text(store.snapshot.sharingPreferences.notificationPreviewEnabled
                         ? "You + \(overlap.friendName), in \(overlap.city)." : "Your travel plans overlap")
                        .font(.headline).foregroundStyle(WIFTheme.primaryText)
                    Text(store.snapshot.sharingPreferences.notificationPreviewEnabled
                         ? overlap.dateLabel : "Open Across Us to see your shared dates.")
                        .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("upcomingAlertBanner")
            Button { store.dismissUpcomingBanner() } label: {
                Image(systemName: "xmark").font(.caption.weight(.semibold)).frame(width: 44, height: 44)
            }.foregroundStyle(WIFTheme.secondaryText).accessibilityLabel("Dismiss upcoming alert")
        }
        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 25))
        .shadow(color: WIFTheme.primaryText.opacity(0.12), radius: 18, y: 7)
        .padding(.horizontal, WIFTheme.screenInset).padding(.top, 8)
    }
}

private struct TravelTripPicker: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var trips: [TripPlan] = []
    @State private var selected: TripPlan?
    @State private var error: String?
    @State private var isLoading = true
    var body: some View {
        if let selected {
            TripPersonalPlanSheet(trip: selected)
        } else {
          NavigationStack {
            List {
                Text("Choose a shared trip, then confirm the city, your own dates and who can see your plan.").font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                if isLoading { ProgressView("Loading trips…") }
                if let error { Text(error) }
                ForEach(trips) { trip in
                    Button { selected = trip } label: { VStack(alignment: .leading) { Text(trip.name); Text(trip.dateLabel).font(.caption) } }
                        .accessibilityIdentifier("importTrip-\(trip.id)")
                }
                if !isLoading && trips.isEmpty && error == nil { Text("No ongoing or upcoming trips.") }
            }
            .navigationTitle("Use shared trip dates").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task {
                isLoading = true
                defer { isLoading = false }
                let ownerID = store.snapshot.currentUser.id
                do {
                    let available: [TripPlan]
                    if store.repositoryMode == .localDemo {
                        let local = TripLibrary()
                        local.load(scope: TripLibrary.storageScope(repository: store.tripRepository, ownerID: ownerID.uuidString), userID: ownerID.uuidString)
                        available = local.trips
                    } else {
                        available = try await store.tripRepository.fetchTrips().map { $0.plan(userID: ownerID.uuidString) }
                    }
                    guard !Task.isCancelled, store.snapshot.currentUser.id == ownerID else { return }
                    trips = available.filter { $0.phase() != .past }
                } catch is CancellationError { } catch {
                    guard !Task.isCancelled, store.snapshot.currentUser.id == ownerID else { return }
                    self.error = error.localizedDescription
                }
            }
          }
        }
    }
}

/// A trip names an airport; resolve its city before using it for city-level matching.
struct TripPlanCityPicker: View {
    let trip: TripPlan
    var dismissOnSelect = true
    let onSelect: (PersonalPlanDraft) -> Void

    var body: some View {
        TravelCityPicker(initialQuery: trip.destination.map { "\($0.city), \($0.country)" } ?? "", dismissOnSelect: dismissOnSelect) { city in
            onSelect(.copying(trip, city: city))
        }
    }
}

struct TripPersonalPlanSheet: View {
    let trip: TripPlan
    @State private var draft: PersonalPlanDraft?

    var body: some View {
        if let draft {
            PersonalPlanEditor(plan: draft.plan, source: draft.source)
        } else {
            NavigationStack {
                TripPlanCityPicker(trip: trip, dismissOnSelect: false) { draft = $0 }
            }
        }
    }
}

struct TripDatesToPersonalPlanButton: View {
    let trip: TripPlan
    @State private var showsPlan = false

    var body: some View {
        Button { showsPlan = true } label: {
            TravelPurposeLink(title: "Use these dates for my travel plan",
                              subtitle: "Choose your own dates and who to share them with.", symbol: "calendar.badge.plus")
        }
        .buttonStyle(.plain).accessibilityIdentifier("tripDatesToPersonalPlan")
        .sheet(isPresented: $showsPlan) { TripPersonalPlanSheet(trip: trip) }
    }
}

struct UpcomingTogetherCard: View {
    @EnvironmentObject private var library: TravelPlanLibrary
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selectedID: String?
    @State private var expanded = false
    @State private var showsPlans = false
    private var overlaps: [TravelOverlap] {
        library.overlaps.filter { !$0.isPast() && store.friend(id: $0.friendID) != nil && !store.snapshot.blockedUserIDs.contains($0.friendID) }
    }
    private var overlapCount: Int { library.overlapsFullyLoaded ? overlaps.count : library.overlapCount }
    private var isLoading: Bool { library.isLoading || library.isLoadingOverlaps || (selectedID.map { library.resolvingOverlapIDs.contains($0) } ?? false) }
    private var selected: TravelOverlap? { overlaps.first { $0.id == selectedID } }
    /// Collapsed, a single overlap previews itself instead of a count.
    private var preview: TravelOverlap? { !expanded && overlapCount == 1 && overlaps.count == 1 ? overlaps[0] : nil }
    private func firstName(_ name: String) -> String { name.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? name }
    private func myPlan(for overlap: TravelOverlap) -> (start: String, end: String)? {
        library.plans.first { $0.city == overlap.city && $0.startDay <= overlap.startDay && $0.endDay >= overlap.endDay }
            .map { ($0.startDay, $0.endDay) }
    }
    private func friendPlan(for overlap: TravelOverlap) -> (start: String, end: String)? {
        library.friendPlans.first { $0.friendID == overlap.friendID && $0.city == overlap.city && $0.startDay <= overlap.startDay && $0.endDay >= overlap.endDay }
            .map { ($0.startDay, $0.endDay) }
    }
    var body: some View {
        // An explicitly opened notification keeps its unavailable state until dismissed.
        // Otherwise, an empty match list must not occupy space on Friends.
        if overlapCount > 0 || selectedID != nil {
            card.padding(.top, 12)
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.84)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    if let preview {
                        CityEmblemView(city: preview.city, countryCode: preview.countryCode, administrativeArea: preview.region, size: 44)
                            .frame(width: 40, height: 40)
                    } else {
                        Image(systemName: "calendar.badge.clock").foregroundStyle(WIFTheme.fresh)
                            .frame(width: 40, height: 40).background(WIFTheme.fresh.opacity(0.12), in: Circle())
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Together soon").font(.subheadline.weight(.semibold))
                        Text(preview.map { "\(firstName($0.friendName)) · \($0.city) · \(OverlapTimeline.shortRange($0.startDay, $0.endDay))" } ?? (overlapCount == 0
                             ? (isLoading ? String(localized: "Loading shared dates…") : String(localized: "This overlap is no longer available"))
                             : (overlapCount == 1 ? String(localized: "1 upcoming overlap") : String(localized: "\(overlapCount) upcoming overlaps"))))
                            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption).rotationEffect(.degrees(expanded ? 180 : 0))
                }.padding(16).foregroundStyle(WIFTheme.primaryText).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("upcomingTogetherToggle")
            if expanded {
                VStack(spacing: 16) {
                    if let selected {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(selected.city)
                                    .font(.system(size: 38, weight: .regular, design: .serif)).tracking(-0.8)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text("with \(firstName(selected.friendName)) · \(selected.daysTogether) days together")
                                    .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                            }
                            Spacer(minLength: 0)
                            CityEmblemView(city: selected.city, countryCode: selected.countryCode, administrativeArea: selected.region, size: 104)
                                .frame(width: 96, height: 96)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("upcomingOverlapDetail")
                        OverlapTimeline(overlap: selected, mine: myPlan(for: selected), theirs: friendPlan(for: selected),
                                        friendName: firstName(selected.friendName))
                        HStack {
                            if overlapCount > 1 { Button("All overlaps") { selectedID = nil } }
                            Spacer()
                            Button("My travel plans") { showsPlans = true }
                        }
                        .font(.caption).frame(minHeight: 36)
                    } else if selectedID != nil {
                        if isLoading { ProgressView() }
                        else if let error = library.overlapError {
                            Text(error).font(.subheadline).multilineTextAlignment(.center)
                            Button("Try again") { if let selectedID { Task { await library.resolveOverlap(selectedID, minimumInterval: 0) } } }
                        }
                        else { Text("This overlap is no longer available. Plans or sharing may have changed.").font(.subheadline).multilineTextAlignment(.center) }
                    } else {
                        if library.isLoadingOverlaps { ProgressView().accessibilityIdentifier("loadingAllOverlaps") }
                        if let error = library.overlapError {
                            Text(error).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                            Button("Try again") { Task { await library.loadAllOverlaps() } }
                        }
                        ForEach(overlaps) { overlap in
                            Button { selectedID = overlap.id } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("\(overlap.friendName) · \(overlap.city)").font(.subheadline.weight(.medium))
                                        Text(overlap.dateLabel).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                                    }
                                    Spacer(); Image(systemName: "chevron.right").font(.caption)
                                }.padding(.vertical, 10).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("upcomingOverlap-\(overlap.id)")
                        }
                    }
                    if selected == nil {
                        Button("My travel plans") { showsPlans = true }.font(.caption).frame(minHeight: 44)
                    }
                    Button("Back to Friends") {
                        expanded = false
                        selectedID = nil
                    }
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText).frame(minHeight: 44)
                    .accessibilityIdentifier("closeUpcomingTogether")
                }
                .padding(.horizontal, 18).padding(.bottom, 16)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 25)).clipped()
        .onChange(of: selectedID, initial: true) { _, id in
            if let id { expanded = true; Task { await library.resolveOverlap(id) } }
            else if expanded { Task { await library.loadAllOverlaps() } }
        }
        .onChange(of: expanded) { _, open in
            if open && selectedID == nil {
                // A single overlap needs no list to pick from.
                if overlaps.count == 1 { selectedID = overlaps[0].id } else { Task { await library.loadAllOverlaps() } }
            }
        }
        .onChange(of: library.overlapVersion) { _, _ in
            guard expanded else { return }
            Task { if let selectedID { await library.resolveOverlap(selectedID) } else { await library.loadAllOverlaps() } }
        }
        .sheet(isPresented: $showsPlans) { NavigationStack { TravelPlansView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showsPlans = false } } } } }
    }
}

/// Two stays on one day axis, with the shared days drawn solid.
struct OverlapTimeline: View {
    let overlap: TravelOverlap
    let mine: (start: String, end: String)?
    let theirs: (start: String, end: String)?
    let friendName: String

    private static func day(_ value: String) -> Double {
        (PersonalTravelPlan.parseDay(value)?.timeIntervalSince1970 ?? 0) / 86400
    }
    static func shortRange(_ start: String, _ end: String) -> String {
        guard let a = PersonalTravelPlan.parseDay(start), let b = PersonalTravelPlan.parseDay(end) else { return "" }
        if a >= b {
            var style = Date.FormatStyle(date: .omitted, time: .omitted).month(.abbreviated).day()
            style.timeZone = .gmt
            return a.formatted(style)
        }
        var style = Date.IntervalFormatStyle().month(.abbreviated).day()
        style.timeZone = .gmt
        return (a..<b).formatted(style)
    }
    private static func short(_ value: String) -> String { shortRange(value, value) }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private struct Day: Identifiable {
        let id: String
        let date: Date
        let mine: Bool
        let theirs: Bool
        let shared: Bool
    }

    /// The union of both stays, trimmed to at most ten days centred on the shared ones.
    private var days: [Day] {
        let myStart = mine?.start ?? overlap.startDay, myEnd = mine?.end ?? overlap.endDay
        let theirStart = theirs?.start ?? overlap.startDay, theirEnd = theirs?.end ?? overlap.endDay
        guard var cursor = PersonalTravelPlan.parseDay(min(myStart, theirStart)),
              let last = PersonalTravelPlan.parseDay(max(myEnd, theirEnd)) else { return [] }
        var result: [Day] = []
        while cursor <= last, result.count < 60 {
            let key = Self.dayFormatter.string(from: cursor)
            result.append(Day(id: key, date: cursor,
                              mine: key >= myStart && key <= myEnd,
                              theirs: key >= theirStart && key <= theirEnd,
                              shared: key >= overlap.startDay && key <= overlap.endDay))
            cursor = cursor.addingTimeInterval(86400)
        }
        guard result.count > 10, let first = result.firstIndex(where: \.shared) else { return result }
        let lower = max(0, min(first - 2, result.count - 10))
        return Array(result[lower..<min(result.count, lower + 10)])
    }

    private var monthLabel: String {
        guard let first = days.first?.date else { return "" }
        var style = Date.FormatStyle(date: .omitted, time: .omitted).month(.wide).year()
        style.timeZone = .gmt
        return first.formatted(style)
    }

    var body: some View {
        let friendTint = WIFPersonPalette.fill(for: overlap.friendName)
        VStack(alignment: .leading, spacing: 10) {
            Text(monthLabel)
                .font(.caption2.weight(.semibold)).textCase(.uppercase).tracking(1.2)
                .foregroundStyle(WIFTheme.secondaryText)
            HStack(spacing: 5) {
                ForEach(days) { day in
                    VStack(spacing: 5) {
                        Text(day.date.formatted(Date.FormatStyle(timeZone: .gmt).weekday(.narrow)))
                            .font(.caption2).foregroundStyle(WIFTheme.secondaryText)
                        Text(day.date.formatted(Date.FormatStyle(locale: Locale(identifier: "en_US_POSIX"), timeZone: .gmt).day()))
                            .font(.subheadline.weight(day.shared ? .semibold : .regular).monospacedDigit())
                            .foregroundStyle(day.shared ? WIFTheme.onFresh : (day.mine || day.theirs ? WIFTheme.primaryText : WIFTheme.secondaryText))
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(day.shared ? WIFTheme.fresh : WIFTheme.fresh.opacity(day.mine || day.theirs ? 0.08 : 0))
                            }
                        HStack(spacing: 3) {
                            Circle().fill(WIFTheme.fresh).frame(width: 5, height: 5).opacity(day.mine ? 1 : 0)
                            Circle().fill(friendTint).frame(width: 5, height: 5).opacity(day.theirs ? 1 : 0)
                        }
                    }
                }
            }
            HStack(spacing: 14) {
                legend(String(localized: "You"), WIFTheme.fresh)
                legend(friendName, friendTint)
                Spacer()
            }
            .padding(.top, 2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Shared days \(overlap.dateLabel)"))
    }

    private func legend(_ label: String, _ tint: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(label).font(.caption).foregroundStyle(WIFTheme.secondaryText)
        }
    }
}
