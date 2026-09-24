import MapKit
import SwiftUI

struct TravelPlansView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var library: TravelPlanLibrary
    @State private var editing: PersonalTravelPlan?
    @State private var deleting: PersonalTravelPlan?
    @State private var showsPast = false
    @State private var importingTrip = false
    @State private var importedPlan: PersonalTravelPlan?

    private var visiblePlans: [PersonalTravelPlan] { library.plans.filter { $0.isPast() == showsPast } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Where to next?").font(.largeTitle.bold()).foregroundStyle(WIFTheme.primaryText)
                Picker("Travel plan dates", selection: $showsPast) {
                    Text("Upcoming").tag(false); Text("Past").tag(true)
                }.pickerStyle(.segmented)
                if let error = library.errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(error).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        Button("Try again") { Task { await library.refresh() } }
                    }
                }
                if visiblePlans.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "calendar.badge.plus").font(.title).foregroundStyle(WIFTheme.fresh)
                        Text(showsPast ? "No past plans" : "A city. A few dates.\nA chance to meet.").font(.title2.weight(.semibold))
                        if !showsPast {
                            Text("Choose when you’ll be somewhere and who can see your plan.")
                                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                            Button("Add a plan") { editing = newPlan() }
                                .buttonStyle(TravelPrimaryButtonStyle())
                                .accessibilityIdentifier("addTravelPlan")
                        }
                    }
                    .padding(22).frame(maxWidth: .infinity, alignment: .leading)
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 26))
                }
                ForEach(visiblePlans) { plan in
                    VStack(alignment: .leading, spacing: 12) {
                        Button { editing = plan } label: {
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
                Button { importingTrip = true } label: { Label("Use dates from a Trip", systemImage: "airplane") }
                    .font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
                Text("Plans don’t change your current city. Only the friends you choose can match with you.")
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
            }
            .padding(WIFTheme.screenInset)
        }
        .wifAmbientBackground()
        .navigationTitle("Travel plans").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { editing = newPlan() } label: { Image(systemName: "plus") }.accessibilityLabel("Add travel plan")
        } }
        .refreshable { await library.refresh() }
        .task { await library.refresh() }
        .sheet(item: $editing) { plan in PersonalPlanEditor(plan: plan) }
        .sheet(isPresented: $importingTrip, onDismiss: {
            if let importedPlan { editing = importedPlan; self.importedPlan = nil }
        }) { TravelTripPicker { importedPlan = $0 } }
        .confirmationDialog("Delete this plan?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete plan", role: .destructive) {
                guard let plan = deleting else { return }
                Task { _ = await library.delete(plan); deleting = nil }
            }
        } message: { Text("Its shared dates and upcoming matches will be removed.") }
        .accessibilityIdentifier("travelPlansScreen")
    }

    private func newPlan() -> PersonalTravelPlan {
        PersonalTravelPlan(city: "", countryCode: "", region: "", timeZone: TimeZone.current.identifier,
                           startDay: TripDay(Date()).value, endDay: TripDay(Date().addingTimeInterval(3 * 86400)).value)
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
    @State private var choosingCity = false
    @State private var choosingAudience = false
    @State private var choosingDates = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("I’ll be in…").font(.largeTitle.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("City")
                        Button { choosingCity = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(plan.city.isEmpty ? "Search a city" : plan.city).font(.title3)
                                    if !plan.city.isEmpty { Text(plan.destination.subtitle).font(.caption).foregroundStyle(WIFTheme.secondaryText) }
                                }
                                Spacer(); Image(systemName: "chevron.right").font(.caption)
                            }.padding(18).frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                        .accessibilityIdentifier("travelPlanCity")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        fieldLabel("Dates")
                        Button { choosingDates = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar").foregroundStyle(WIFTheme.fresh)
                                Text(plan.dateLabel).font(.subheadline.weight(.medium)).foregroundStyle(WIFTheme.primaryText)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                            }
                            .padding(18).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 20)).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).accessibilityIdentifier("travelPlanDates")
                        if !plan.city.isEmpty { Text("Local dates in \(plan.city)").font(.caption).foregroundStyle(WIFTheme.secondaryText) }
                    }
                    Button { choosingAudience = true } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose friends").font(.subheadline)
                                Text(plan.audience.isEmpty ? "Only me · choose friends" : "\(plan.audience.count) selected friends")
                                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption)
                        }.padding(18).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityIdentifier("travelPlanAudience")
                    Toggle("Show plan in their Friend plans", isOn: $plan.allowFriendBrowsing)
                        .font(.subheadline).accessibilityIdentifier("travelPlanBrowsing")
                    Text(plan.audience.isEmpty
                         ? "Choose friends to show them this plan."
                         : plan.allowFriendBrowsing
                             ? "Selected friends can see its city and dates."
                             : "Selected friends can still see a match when your dates overlap.")
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    Toggle("Remind me about overlaps", isOn: $plan.alertsEnabled)
                        .font(.subheadline).accessibilityIdentifier("travelPlanAlerts")
                    Text("Get a reminder up to 14 days before your plans overlap.")
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    if let error { Text(error).font(.caption).foregroundStyle(WIFTheme.destructive).accessibilityIdentifier("travelPlanError") }
                    Button {
                        Task {
                            if await library.save(plan) {
                                if plan.alertsEnabled { await store.requestNotificationAuthorization() }
                                dismiss()
                            } else { error = library.errorMessage }
                        }
                    } label: {
                        if library.isSaving { ProgressView() } else { Text("Save plan") }
                    }
                    .buttonStyle(TravelPrimaryButtonStyle())
                    .disabled(plan.city.isEmpty || library.isSaving)
                    .opacity(plan.city.isEmpty ? 0.5 : 1)
                    .accessibilityIdentifier("saveTravelPlan")
                }
                .padding(24)
            }
            .wifAmbientBackground().navigationTitle(plan.revision == 0 ? "New plan" : "Edit plan").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                if !choosingCity { Button("Cancel") { dismiss() }.disabled(library.isSaving) }
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
                        ForEach(store.friends.filter { !store.snapshot.blockedUserIDs.contains($0.id) }) { friend in
                            Toggle(isOn: Binding(get: { plan.audience.contains(friend.id) }, set: { value in
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
            .interactiveDismissDisabled(library.isSaving)
        }
    }

    private func fieldLabel(_ title: LocalizedStringKey) -> some View { Text(title).font(.caption).foregroundStyle(WIFTheme.secondaryText).padding(.leading, 4) }
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
    let onSelect: (TravelCity) -> Void

    private struct TripCityShortcut: Identifiable {
        let id: String
        let city: String
        let country: String
        let countryCode: String
    }

    init(initialQuery: String = "", showsCancelButton: Bool = true, showsTripDestinations: Bool = false,
         onSelect: @escaping (TravelCity) -> Void) {
        _query = State(initialValue: initialQuery)
        self.showsCancelButton = showsCancelButton
        self.showsTripDestinations = showsTripDestinations
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
        .task(id: store.snapshot.currentUser.id) { await loadTripShortcuts() }
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
                cities = result.mapItems.compactMap { item in
                    guard let city = item.placemark.locality, let country = item.placemark.isoCountryCode,
                          let zone = item.timeZone?.identifier else { return nil }
                    let value = TravelCity(name: city, countryCode: country, region: item.placemark.administrativeArea ?? "", timeZone: zone)
                    return seen.insert(value.id).inserted ? value : nil
                }
                if cities.isEmpty { error = "No city found. Try adding the country or region." }
                isSearching = false
            } catch is CancellationError { } catch {
                guard !Task.isCancelled else { return }
                isSearching = false; self.error = "City search is unavailable. Check your connection and try again."
            }
        }
    }

    @ViewBuilder
    private var startingContent: some View {
        if !ownPlaces.isEmpty {
            sectionHeading("Your places")
            cityRows(ownPlaces)
        }
        if showsTripDestinations && !visibleTripShortcuts.isEmpty {
            sectionHeading("From your Trips")
            tripShortcutRows
        }
        if library.isDemo && ownPlaces.isEmpty && visibleTripShortcuts.isEmpty {
            sectionHeading("Demo cities")
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
                    locationLabel(city: shortcut.city, detail: shortcut.country)
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
        dismiss()
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
    let onSelect: (PersonalTravelPlan) -> Void
    var body: some View {
        NavigationStack {
            List {
                Text("Choose a trip, then confirm its city and who can see your personal dates.").font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                if isLoading { ProgressView("Loading trips…") }
                if let error { Text(error) }
                ForEach(trips) { trip in
                    Button { selected = trip } label: { VStack(alignment: .leading) { Text(trip.name); Text(trip.dateLabel).font(.caption) } }
                }
                if !isLoading && trips.isEmpty && error == nil { Text("No ongoing or upcoming trips.") }
            }
            .navigationTitle("Use a Trip").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task {
                isLoading = true
                defer { isLoading = false }
                let ownerID = store.snapshot.currentUser.id
                do {
                    let available: [TripPlan]
                    if store.repositoryMode == .localDemo {
                        available = TripPlan.examples(owner: TripParticipant(id: ownerID.uuidString,
                            name: store.snapshot.currentUser.displayName, userID: ownerID.uuidString))
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
            .sheet(item: $selected) { trip in
                NavigationStack {
                    TravelCityPicker(initialQuery: trip.destination.map { "\($0.city), \($0.country)" } ?? "") { city in
                        let plan = PersonalTravelPlan(city: city.name, countryCode: city.countryCode, region: city.region, timeZone: city.timeZone,
                            startDay: trip.startDay.value, endDay: trip.endDay.value)
                        // The new editor requires explicit audience/alert consent again.
                        selected = nil; dismiss(); onSelect(plan)
                    }
                }
            }
        }
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
    private var selected: TravelOverlap? { overlaps.first { $0.id == selectedID } }
    var body: some View {
        // An explicitly opened notification keeps its unavailable state until dismissed.
        // Otherwise, an empty match list must not occupy space on Friends.
        if !overlaps.isEmpty || selectedID != nil {
            card.padding(.top, 12)
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.84)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock").foregroundStyle(WIFTheme.fresh)
                        .frame(width: 40, height: 40).background(WIFTheme.fresh.opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Together soon").font(.subheadline.weight(.semibold))
                        Text(overlaps.isEmpty
                             ? (library.isLoading ? "Loading shared dates…" : "This overlap is no longer available")
                             : "\(overlaps.count) upcoming \(overlaps.count == 1 ? "overlap" : "overlaps")")
                            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption).rotationEffect(.degrees(expanded ? 180 : 0))
                }.padding(16).foregroundStyle(WIFTheme.primaryText).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("upcomingTogetherToggle")
            if expanded {
                VStack(spacing: 16) {
                    if let selected {
                        Button("All overlaps") { selectedID = nil }.font(.caption).frame(minHeight: 44)
                        CityEmblemView(city: selected.city, countryCode: selected.countryCode, administrativeArea: selected.region, size: 108)
                        Text("You + \(selected.friendName), in \(selected.city).")
                            .font(.title2.weight(.semibold)).multilineTextAlignment(.center)
                        Text(selected.dateLabel).font(.subheadline).foregroundStyle(WIFTheme.fresh)
                        Text("\(selected.daysTogether) days in common · local dates")
                            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        ShareLink(item: "We’ll both be in \(selected.city) on \(selected.dateLabel). Coffee?") {
                            Label("Say hello", systemImage: "bubble.left")
                        }.buttonStyle(TravelPrimaryButtonStyle()).accessibilityIdentifier("upcomingSayHello")
                    } else if selectedID != nil {
                        if library.isLoading { ProgressView() }
                        else { Text("This overlap is no longer available. Plans or sharing may have changed.").font(.subheadline).multilineTextAlignment(.center) }
                    } else {
                        ForEach(overlaps) { overlap in
                            Button { selectedID = overlap.id } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text("\(overlap.friendName) · \(overlap.city)").font(.subheadline.weight(.medium))
                                        Text(overlap.dateLabel).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                                    }
                                    Spacer(); Image(systemName: "chevron.right").font(.caption)
                                }.padding(.vertical, 10).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("upcomingOverlap-\(overlap.friendID)")
                        }
                    }
                    Button("Manage my plans") { showsPlans = true }.font(.caption).frame(minHeight: 44)
                    Button("Back to Friends") {
                        expanded = false
                        selectedID = nil
                    }
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText).frame(minHeight: 44)
                    .accessibilityIdentifier("closeUpcomingTogether")
                }
                .padding(.horizontal, 20).padding(.bottom, 16)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 25)).clipped()
        .onChange(of: selectedID, initial: true) { _, id in if id != nil { expanded = true } }
        .sheet(isPresented: $showsPlans) { NavigationStack { TravelPlansView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showsPlans = false } } } } }
    }
}
