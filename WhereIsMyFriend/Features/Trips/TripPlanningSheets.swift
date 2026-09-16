import SwiftUI

/// Trip notifications settings sheet
struct TripNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @ObservedObject var library: TripLibrary
    let trip: TripPlan
    @State private var isChangingAlerts = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Friends' flight alerts", isOn: Binding(get: { trip.flightAlertsEnabled ?? false }, set: { enabled in
                        isChangingAlerts = true
                        Task {
                            let saved = await library.setFlightAlerts(enabled, tripID: trip.id)
                            if saved && enabled { await store.requestNotificationAuthorization() }
                            isChangingAlerts = false
                        }
                    }))
                    .disabled(library.isSaving || isChangingAlerts)
                    .tint(WIFTheme.fresh)
                    .accessibilityIdentifier("tripFlightAlertsToggle")
                } footer: {
                    Text("For this trip only: arrival delays of 30+ minutes, cancellations and landings.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(WIFTheme.canvas)
            .navigationTitle("Trip Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(WIFTheme.fresh)
        .presentationDetents([.medium])
    }
}

struct TripPlanningSheet: View {
    @Environment(\.dismiss) private var dismiss
    let existing: TripPlan?
    let onSave: (String, String, TripDay, TripDay, Int?) async -> Bool
    @State private var initialRevision: Int?
    let isCloud: Bool
    let saveError: () -> String?
    @State private var isSaving = false
    @State private var name: String
    @State private var isCustomName: Bool
    @State private var destination: String
    @State private var start: Date
    @State private var end: Date
    @State private var showsSaveError = false
    @State private var showsDestinationSheet = false
    @State private var showsDatePicker = false
    @FocusState private var nameFocused: Bool

    init(existing: TripPlan? = nil, isCloud: Bool = false, saveError: @escaping () -> String? = { nil }, onSave: @escaping (String, String, TripDay, TripDay, Int?) async -> Bool) {
        self.saveError = saveError
        _initialRevision = State(initialValue: existing?.revision)
        self.isCloud = isCloud
        self.existing = existing
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _isCustomName = State(initialValue: existing != nil)
        _destination = State(initialValue: existing?.destinationAirport ?? "")
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        _start = State(initialValue: existing?.startDay.pickerDate ?? nextWeek)
        _end = State(initialValue: existing?.endDay.pickerDate ?? (Calendar.current.date(byAdding: .day, value: 3, to: nextWeek) ?? nextWeek))
    }

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var defaultGeneratedName: String {
        guard !destination.isEmpty else { return "" }
        let cityName = AirportLocation.location(for: destination)?.city ?? destination
        return "\(cityName) trip"
    }

    private var effectiveName: String {
        if !cleanName.isEmpty { return cleanName }
        return defaultGeneratedName
    }

    private var canSave: Bool {
        !destination.isEmpty && !effectiveName.isEmpty && effectiveName.count <= 60 && TripDay(start) <= TripDay(end)
    }

    private var dateSummary: String {
        let cal = Calendar.current
        let startYear = cal.component(.year, from: start)
        let endYear = cal.component(.year, from: end)
        let df = DateFormatter()
        if startYear == endYear {
            df.dateFormat = "MMM d"
            let startPart = df.string(from: start)
            df.dateFormat = "MMM d, yyyy"
            let endPart = df.string(from: end)
            return "\(startPart) – \(endPart)"
        } else {
            df.dateFormat = "MMM d, yyyy"
            return "\(df.string(from: start)) – \(df.string(from: end))"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        showsDestinationSheet = true
                    } label: {
                        HStack {
                            Text("Destination")
                                .foregroundStyle(WIFTheme.primaryText)
                            Spacer()
                            if destination.isEmpty {
                                Text("Select city or airport")
                                    .foregroundStyle(WIFTheme.secondaryText)
                            } else {
                                let loc = AirportLocation.location(for: destination)
                                let cityName = loc?.city ?? destination
                                Text("\(cityName) (\(destination))")
                                    .foregroundStyle(WIFTheme.primaryText)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WIFTheme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tripDestinationPicker")
                } header: {
                    Text("Where to?")
                }
                .listRowBackground(WIFTheme.surface)

                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsDatePicker.toggle()
                        }
                    } label: {
                        HStack {
                            Text("Dates")
                                .foregroundStyle(WIFTheme.primaryText)
                            Spacer()
                            Text(dateSummary)
                                .foregroundStyle(WIFTheme.primaryText)
                            Image(systemName: showsDatePicker ? "chevron.down" : "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WIFTheme.secondaryText)
                        }
                    }
                    .buttonStyle(.plain)


                } header: {
                    Text("When?")
                }
                .listRowBackground(WIFTheme.surface)

                Section {
                    TextField(defaultGeneratedName.isEmpty ? "e.g. Palm Springs trip" : defaultGeneratedName, text: $name)
                        .font(.body)
                        .focused($nameFocused).submitLabel(.done)
                        .onSubmit { nameFocused = false }
                        .onChange(of: name) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty && trimmed != defaultGeneratedName {
                                isCustomName = true
                            }
                        }
                        .accessibilityIdentifier("tripNameField")
                } header: {
                    Text("Trip name · Optional")
                }
                .listRowBackground(WIFTheme.surface)
            }
            .scrollContentBackground(.hidden)
            .disabled(isSaving)
            .scrollDismissesKeyboard(.interactively)
            .background(WIFTheme.canvas)
            .sheet(isPresented: $showsDatePicker) {
                TravelDateRangePicker(startDay: TripDay(start).value, endDay: TripDay(end).value, futurePlansOnly: false) {
                    start = TripDay(value: $0).pickerDate; end = TripDay(value: $1).pickerDate
                }
            }
            .navigationTitle(existing == nil ? "New trip" : "Edit trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        isSaving = true
                        Task {
                            if await onSave(effectiveName, destination, TripDay(start), TripDay(end), initialRevision) { dismiss() }
                            else { showsSaveError = true }
                            isSaving = false
                        }
                    } label: {
                        Text(existing == nil ? "Create trip" : "Save changes").font(.headline)
                            .frame(maxWidth: .infinity).frame(minHeight: 52)
                            .foregroundStyle(canSave ? WIFTheme.canvas : WIFTheme.secondaryText)
                            .background(canSave ? WIFTheme.fresh : WIFTheme.border.opacity(0.25), in: Capsule())
                    }
                    .buttonStyle(.plain).disabled(!canSave || isSaving)
                    .accessibilityIdentifier("saveTripButton")
                    Text(isSaving ? "Saving…" : (isCloud ? "Saved to your account · available across devices" : "Demo · saved on this device"))
                        .font(.caption2).foregroundStyle(WIFTheme.secondaryText)
                }
                .padding(20).background(WIFTheme.canvas)
            }
            .onChange(of: start) { _, newStart in if end < newStart { end = newStart } }
            .onChange(of: destination) { _, newDest in
                nameFocused = false
                if !isCustomName || name.isEmpty {
                    if let city = AirportLocation.location(for: newDest)?.city {
                        name = "\(city) trip"
                    }
                }
            }
            .alert("Couldn't save trip", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError() ?? "Please check the details and try again. Existing trips have not been changed.")
            }
            .sheet(isPresented: $showsDestinationSheet) {
                DestinationSearchSheet(selectedDestination: $destination)
            }
        }
        .tint(WIFTheme.fresh)
        .presentationDetents([.large])
        .interactiveDismissDisabled(isSaving)
    }
}

struct DestinationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDestination: String
    @State private var searchText = ""

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [AirportLocation] {
        AirportLocation.search(trimmedSearch)
    }

    var body: some View {
        NavigationStack {
            List {
                if searchResults.isEmpty {
                    ContentUnavailableView(
                        "No airports found",
                        systemImage: "airplane",
                        description: Text("Try searching for a city name (e.g. Palm Springs) or 3-letter airport code (e.g. PSP).")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(searchResults) { item in
                            Button {
                                selectedDestination = item.code
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Text(item.flag)
                                        .font(.title2)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                                            Text(item.city)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(WIFTheme.primaryText)
                                            Text(item.code)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(WIFTheme.secondaryText)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1)
                                                .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 4))
                                        }
                                        Text("\(item.name) · \(item.country)")
                                            .font(.caption)
                                            .foregroundStyle(WIFTheme.secondaryText)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if selectedDestination == item.code {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(WIFTheme.fresh)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("\(item.city) (\(item.code))")
                        }
                    } header: {
                        if trimmedSearch.isEmpty {
                            Text("Popular destinations")
                        } else {
                            Text("Results (\(searchResults.count))")
                        }
                    }
                    .listRowBackground(WIFTheme.surface)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search city or airport")
            .scrollContentBackground(.hidden)
            .background(WIFTheme.canvas)
            .navigationTitle("Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(WIFTheme.fresh)
    }
}

struct TripPeopleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @ObservedObject var library: TripLibrary
    let trip: TripPlan
    let currentUserID: String?
    var isCloud = false
    @State private var outgoing: [TripInvitation] = []
    @State private var isWorking = false
    @State private var message: String?
    @State private var revokeTarget: TripInvitation?
    @State private var removeTarget: TripParticipant?
    @State private var removalRevision: Int?

    private var currentTrip: TripPlan { library.trips.first { $0.id == trip.id } ?? trip }
    private var canInvite: Bool { isCloud && library.canEdit(currentTrip) }

    var body: some View {
        NavigationStack {
            Form {
                Section("In this trip") {
                    ForEach(currentTrip.participants) { person in
                        HStack {
                            Label(person.name, systemImage: "person.crop.circle")
                            Spacer()
                            Text(person.userID != nil && person.userID == currentUserID ? "You" :
                                 (trip.isExample ? "Example" : (person.userID == nil ? "Unclaimed" : "Member")))
                                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                            if library.canManage(currentTrip), person.userID == nil || person.userID != currentUserID {
                                Button(role: .destructive) {
                                    removalRevision = currentTrip.revision
                                    removeTarget = person
                                } label: {
                                    Image(systemName: "person.crop.circle.badge.minus")
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                                .disabled(isWorking || library.isSaving)
                                .accessibilityLabel("Remove \(person.name)")
                                .accessibilityIdentifier("removeTripMember-\(person.id)")
                            }
                        }
                    }
                }
                .listRowBackground(WIFTheme.surface)
                if !outgoing.isEmpty {
                    Section("Pending invitations") {
                        ForEach(outgoing) { invitation in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(invitation.recipient_name).font(.headline)
                                Text("Invited · expires \(CloudTrip.timestamp(invitation.expires_at)?.formatted(date: .abbreviated, time: .omitted) ?? "soon")")
                                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                                HStack {
                                    ShareLink(item: TripInvitationLink.make(id: invitation.id),
                                        subject: Text("Join \(trip.name)"),
                                        message: Text("\(trip.destinationName) · \(trip.dateLabel). Open AcrossUs and sign in with your invited account to join.")) {
                                        Label("Share invite", systemImage: "square.and.arrow.up")
                                    }
                                    Spacer()
                                    Button("Revoke", role: .destructive) { revokeTarget = invitation }
                                }.font(.subheadline).buttonStyle(.borderless)
                            }.padding(.vertical, 6)
                        }
                    }
                    .listRowBackground(WIFTheme.surface)
                }
                if canInvite {
                    Section("Invite a friend") {
                        let available = store.friends.filter { friend in
                            !currentTrip.participants.contains { $0.userID?.lowercased() == friend.id.uuidString.lowercased() }
                            && !outgoing.contains { $0.recipient_id == friend.id }
                        }
                        if available.isEmpty {
                            Text("All available friends are already joined or invited. You can add friends from the Friends tab.")
                                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                        }
                        ForEach(available) { friend in
                            Button {
                                isWorking = true
                                Task {
                                    do {
                                        _ = try await store.tripRepository.inviteToTrip(id: trip.id, username: friend.username)
                                        outgoing = try await store.tripRepository.tripInvitations(tripID: trip.id)
                                    } catch { message = error.localizedDescription }
                                    isWorking = false
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(friend.displayName).foregroundStyle(WIFTheme.primaryText)
                                        Text("@\(friend.username)").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "person.badge.plus")
                                }
                            }.disabled(isWorking || library.isSaving)
                        }
                    }.listRowBackground(WIFTheme.surface)
                }
            }
            .scrollContentBackground(.hidden).background(WIFTheme.canvas)
            .navigationTitle("People").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .tint(WIFTheme.fresh)
        .task {
            guard canInvite else { return }
            do { outgoing = try await store.tripRepository.tripInvitations(tripID: trip.id) }
            catch { message = error.localizedDescription }
        }
        .interactiveDismissDisabled(isWorking || library.isSaving)
        .onChange(of: library.trips.map(\.id)) { _, ids in if !ids.contains(trip.id) { dismiss() } }
        .alert("Trip people", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
        .alert("Remove this member?", isPresented: Binding(get: { removeTarget != nil }, set: { if !$0 { removeTarget = nil } }), presenting: removeTarget) { person in
            Button("Remove member", role: .destructive) {
                isWorking = true
                Task {
                    let saved = await library.changeLifecycle(.removeMember, tripID: trip.id, participantID: person.id, revision: removalRevision)
                    if !saved {
                        message = library.errorMessage ?? String(localized: "The member could not be removed. Refresh and try again.")
                        library.errorMessage = nil
                    }
                    isWorking = false
                }
            }
            Button("Keep member", role: .cancel) {}
        } message: { person in
            Text("\(person.name) will lose access to this trip. Their shared flights will be removed, and they will need a new invitation to rejoin.")
        }
        .confirmationDialog("Revoke this invitation?", isPresented: Binding(get: { revokeTarget != nil }, set: { if !$0 { revokeTarget = nil } }), titleVisibility: .visible) {
            Button("Revoke invitation", role: .destructive) {
                guard let target = revokeTarget else { return }
                Task {
                    do {
                        try await store.tripRepository.dismissTripInvitation(id: target.id, revoke: true)
                        outgoing.removeAll { $0.id == target.id }
                    } catch { message = error.localizedDescription }
                    revokeTarget = nil
                }
            }
        } message: { Text("The shared link will stop working. This does not remove anyone who already joined.") }
    }
}

struct TripInvitationCard: View {
    let invitation: TripInvitation
    @ObservedObject var library: TripLibrary
    var onJoined: () -> Void = {}
    @State private var confirmsDecline = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("\(invitation.inviter_name) invited you", systemImage: "person.badge.plus")
                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
            Text(invitation.trip_name).font(.title3.bold())
            Text("\(invitation.destination_airport) · \(TripDay(value: invitation.start_date).label) – \(TripDay(value: invitation.end_date).label)")
                .font(.subheadline)
            Text("Joining shares your trip flights with these members. Only you can edit your flights.")
                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
            HStack {
                Button("Join trip") {
                    Task { if await library.accept(invitation) { onJoined() } }
                }.buttonStyle(.borderedProminent).tint(WIFTheme.fresh)
                Button("Decline", role: .destructive) { confirmsDecline = true }.buttonStyle(.borderless)
            }.disabled(library.isSaving)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
            .confirmationDialog("Decline this invitation?", isPresented: $confirmsDecline, titleVisibility: .visible) {
                Button("Decline invitation", role: .destructive) { Task { await library.decline(invitation) } }
            }
    }
}

struct TripInvitationLanding: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var library = TripLibrary()
    let invitationID: UUID
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let invitation = library.invitations.first(where: { $0.id == invitationID }) {
                    TripInvitationCard(invitation: invitation, library: library) { store.discardTripInvitationLink() }
                } else if !loaded {
                    ProgressView("Checking invitation…")
                } else {
                    ContentUnavailableView("Invitation unavailable", systemImage: "envelope",
                        description: Text(library.syncFailed ? "Couldn't connect. Try again when online." : "This link may have expired, been revoked, or been accepted already. Make sure you signed in with the invited account."))
                    Button("Try again") { Task { await library.refresh() } }
                }
                if let error = library.errorMessage { Text(error).font(.caption).foregroundStyle(WIFTheme.destructive) }
            }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity).background(WIFTheme.canvas)
            .navigationTitle("Trip invitation").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { store.discardTripInvitationLink() } } }
        }
        .task(id: store.snapshot.currentUser.id) {
            let id = store.snapshot.currentUser.id.uuidString
            library.connect(store.tripRepository)
            library.load(scope: "\(store.tripRepository.storageScope)-\(id)", userID: id)
            await library.refresh()
            loaded = true
        }
    }
}
