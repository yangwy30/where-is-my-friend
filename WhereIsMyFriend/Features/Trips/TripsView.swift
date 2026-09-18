import MapKit
import SwiftUI

struct TripsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var library = TripLibrary()
    @State private var showsNewTrip = false
    @State private var showsPast = false
    @State private var now = Date()
    @State private var newTripID = UUID().uuidString

    private var owner: TripParticipant {
        TripParticipant(id: store.snapshot.currentUser.id.uuidString, name: store.snapshot.currentUser.displayName,
                        userID: store.snapshot.isAuthenticated ? store.snapshot.currentUser.id.uuidString : nil)
    }

    private var scope: String {
        var value = store.repositoryMode == .remote ? "\(store.tripRepository.storageScope)-\(owner.id)" : "\(store.repositoryMode.rawValue)-\(owner.id)"
        #if DEBUG
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-tripTestNamespace=") }) {
            value += "-" + String(argument.dropFirst("-tripTestNamespace=".count))
        }
        #endif
        return value
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Trips").font(.system(size: 44, weight: .bold, design: .rounded)).tracking(-0.8)
                        Text("More places. More time together.")
                            .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Button { showsNewTrip = true } label: {
                        Image(systemName: "plus").font(.headline)
                            .frame(width: 44, height: 44).contentShape(Circle())
                    }
                    .buttonStyle(.plain).foregroundStyle(WIFTheme.fresh)
                    .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.12), interactive: true, in: Circle())
                    .accessibilityLabel("New trip").accessibilityIdentifier("newTripButton")
                }

                if store.repositoryMode == .remote {
                    TripInvitationPermissionHint(service: store.notificationService)
                }
                if !library.invitations.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Invitations").font(.title3.bold())
                        ForEach(library.invitations) { invitation in
                            TripInvitationCard(invitation: invitation, library: library)
                        }
                    }
                }
                if !library.deviceDrafts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Device drafts").font(.title3.bold())
                        Text("Move the trip and your own flight numbers to your account. Other travelers must join themselves; example data stays on this device.")
                            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        ForEach(library.deviceDrafts) { draft in
                            Button("Move \(draft.name) to my account") {
                                Task { _ = await library.importDraft(draft) }
                            }.disabled(library.isSaving)
                        }
                    }
                }
                if library.scope != scope {
                    ProgressView()
                } else if library.trips.isEmpty {
                    emptyState
                } else {
                    tripSection(.ongoing)
                    tripSection(.upcoming)
                    let past = library.trips(in: .past, at: now)
                    if !past.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) { showsPast.toggle() }
                            } label: {
                                HStack {
                                    Text("Past").font(.title3.bold())
                                    Text("\(past.count)").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                                    Spacer()
                                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                                        .rotationEffect(.degrees(showsPast ? 180 : 0))
                                }
                                .frame(minHeight: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).accessibilityIdentifier("pastTripsToggle")
                            .accessibilityValue(showsPast ? "Expanded" : "Collapsed")
                            if showsPast {
                                ForEach(past) { trip in tripLink(trip) }
                            }
                        }
                    }
                }
            }
            .foregroundStyle(WIFTheme.primaryText)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.top, 12).padding(.bottom, 36)
        }
        .wifAmbientBackground()
        .navigationTitle("Trips")
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: String.self) { tripID in
            TripDetailView(library: library, tripID: tripID)
        }
        .sheet(isPresented: $showsNewTrip) {
            TripPlanningSheet(isCloud: library.isCloud, saveError: { library.errorMessage }) { name, destination, start, end, _ in
                let trip = TripPlan(id: newTripID, name: name, destinationAirport: destination,
                                    startDay: start, endDay: end, participants: [owner], flights: [], creatorUserID: owner.userID)
                return await library.create(trip)
            }
        }
        .task(id: scope) {
            library.connect(store.tripRepository)
            library.load(scope: scope, userID: owner.userID)
            library.readDeviceDrafts(legacyScope: "remote-\(owner.id)")
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-seedTripExamples") {
                library.addExamples(owner: owner)
            }
            #endif
            await library.refresh()
        }
        .refreshable { await library.refresh() }
        .onChange(of: store.invitationRefreshRevision) { _, _ in
            Task { await library.refresh() }
        }
        .onChange(of: store.pendingTripInvitationID) { _, id in
            if id == nil { Task { await library.refresh() } }
        }
        .onChange(of: showsNewTrip) { _, visible in if visible { newTripID = UUID().uuidString } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date(); Task { await library.refresh() } }
        }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                now = Date()
                if scenePhase == .active { await library.refresh() }
            }
        }
        .alert("Trips couldn't be saved", isPresented: Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
        .accessibilityIdentifier("tripsScreen")
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "suitcase.rolling")
                .font(.system(size: 40, weight: .light)).foregroundStyle(WIFTheme.fresh)
                .frame(width: 92, height: 92).background(WIFTheme.freshSurface.opacity(0.6), in: Circle())
            Text("Your next adventure\nstarts here.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Plan a trip, bring your people,\nand see everyone's journey in one place.")
                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText).multilineTextAlignment(.center)
            Button("Plan your first trip") { showsNewTrip = true }
                .font(.headline).foregroundStyle(WIFTheme.canvas)
                .padding(.horizontal, 28).frame(minHeight: 52)
                .background(WIFTheme.fresh, in: Capsule())
                .buttonStyle(.plain).accessibilityIdentifier("createFirstTripButton")
            if !library.isCloud {
              Button("Explore example trips") { library.addExamples(owner: owner) }
                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                .frame(minHeight: 44).buttonStyle(.plain)
                .accessibilityIdentifier("loadExampleTripsButton")
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 48)
    }

    @ViewBuilder
    private func tripSection(_ phase: TripPhase) -> some View {
        let trips = library.trips(in: phase, at: now)
        if !trips.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if phase == .ongoing {
                        Circle().fill(WIFTheme.fresh).frame(width: 6, height: 6)
                    }
                    Text(phase.title).font(.title3.bold())
                    Text("\(trips.count)").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                }
                ForEach(trips) { trip in tripLink(trip) }
            }
        }
    }

    private func tripLink(_ trip: TripPlan) -> some View {
        NavigationLink(value: trip.id) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(trip.name).font(.system(.title3, design: .rounded, weight: .bold))
                        Text("\(trip.destinationName) · \(trip.dateLabel)")
                            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Text(trip.destinationAirport)
                        .font(.caption.weight(.semibold)).foregroundStyle(WIFTheme.fresh)
                        .padding(9).background(WIFTheme.freshSurface.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                }
                HStack(spacing: 5) {
                    ForEach(trip.participants.prefix(4)) { person in
                        TripTravelerAvatar(name: person.name, color: TripFlight.color(for: person.name), size: 26)
                    }
                    if trip.participants.count > 4 {
                        Text("+\(trip.participants.count - 4)").font(.caption2).foregroundStyle(WIFTheme.secondaryText)
                    }
                    Spacer()
                    if trip.phase(at: now) == .past {
                        Text(trip.cancelledAt != nil ? String(localized: "Cancelled") : (trip.completedAt == nil ? "Finished" : "Marked complete"))
                            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    } else {
                        Text(trip.flights.isEmpty ? "Ready to plan" : "\(trip.addedTravelerCount) of \(trip.participants.count) flights added")
                            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    }
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                if trip.isExample {
                    Text("EXAMPLE").font(.system(size: 8, weight: .semibold)).tracking(1.0)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
            }
            .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(trip.phase(at: now) == .ongoing ? WIFTheme.eventBlue.opacity(0.65) : WIFTheme.surface.opacity(0.85),
                        in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tripCard-\(trip.id)")
    }
}

private struct TripInvitationPermissionHint: View {
    @ObservedObject var service: LocalNotificationService
    var body: some View { InvitationNotificationStatusView(service: service) }
}

private struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: TripLibrary
    let tripID: String
    @State private var addRequest: FlightRequest?
    @State private var showsPeople = false
    @State private var showsEdit = false
    @State private var showsNotifications = false
    @State private var showsCompleteConfirmation = false
    @State private var deleteRequest: TripFlight?
    @State private var lifecycleAction: TripLifecycleAction?
    @State private var lifecycleRevision: Int?

    private struct FlightRequest: Identifiable {
        let id = UUID()
        let direction: TripDirection
        var existing: TripFlight? = nil
    }

    var body: some View {
        if let trip = library.trips.first(where: { $0.id == tripID }) {
            FullTripArrivalBoard(library: library, trip: trip, selfParticipant: library.selfParticipant(in: trip), onAddFlight: { direction in
                addRequest = FlightRequest(direction: direction)
            }, onEditFlight: { flight in
                addRequest = FlightRequest(direction: flight.direction, existing: flight)
            }, onDeleteFlight: { deleteRequest = $0 }, onPeople: { showsPeople = true })
            .toolbar {
                if #available(iOS 27.0, *) {
                    ToolbarItem(placement: .topBarTrailing) { tripOptions(trip) }
                        .visibilityPriority(.high)
                } else {
                    ToolbarItem(placement: .topBarTrailing) { tripOptions(trip) }
                }
            }
            .refreshable { await library.refresh() }
            .alert(lifecycleTitle, isPresented: Binding(get: { lifecycleAction != nil }, set: { if !$0 { lifecycleAction = nil } }), presenting: lifecycleAction) { action in
                Button(lifecycleButton(action), role: .destructive) {
                    Task {
                        if await library.changeLifecycle(action, tripID: tripID, revision: lifecycleRevision), action == .leave || action == .delete {
                            dismiss()
                        }
                    }
                }
                Button("Keep trip", role: .cancel) {}
            } message: { action in
                Text(lifecycleMessage(action))
            }
            .overlay { if library.isSaving { ProgressView().padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) } }
            .confirmationDialog("Finish this trip?", isPresented: $showsCompleteConfirmation, titleVisibility: .visible) {
                Button("Mark complete") { Task { _ = await library.setComplete(tripID, at: Date()) } }
            } message: {
                Text("It will move to Past. All people and flights are kept, and you can undo this.")
            }
            .sheet(item: $addRequest) { request in
                if let person = library.selfParticipant(in: trip) {
                    AddTripFlightSheet(trip: trip, person: person, direction: request.direction, existing: request.existing, saveError: { library.errorMessage }) { number, date, candidate in
                        var flight: TripFlight
                        if let candidate {
                            flight = TripFlight(id: request.existing?.id ?? request.id.uuidString,
                                                traveler: person.name,
                                                flightNumber: candidate.flightNumber,
                                                airline: candidate.airline ?? "Airlines",
                                                origin: candidate.departure.code ?? (request.direction == .outbound ? "—" : trip.destinationAirport),
                                                destination: candidate.arrival.code ?? (request.direction == .outbound ? trip.destinationAirport : "—"),
                                                departureTime: candidate.departureTimeFormatted,
                                                arrivalTime: candidate.arrivalTimeFormatted,
                                                date: date,
                                                terminal: candidate.terminalFormatted,
                                                status: candidate.tripStatus,
                                                direction: request.direction,
                                                arrivalDayOffset: candidate.arrivalDayOffset,
                                                travelerID: person.id)
                        } else {
                            flight = TripFlight(id: request.existing?.id ?? request.id.uuidString,
                                                traveler: person.name,
                                                flightNumber: number,
                                                airline: "Not verified",
                                                origin: request.direction == .outbound ? "—" : trip.destinationAirport,
                                                destination: request.direction == .outbound ? trip.destinationAirport : "—",
                                                departureTime: "—",
                                                arrivalTime: "—",
                                                date: date,
                                                terminal: "Not available",
                                                status: .unverified,
                                                direction: request.direction,
                                                travelerID: person.id)
                        }
                        flight.revision = request.existing?.revision
                        return await library.saveFlight(flight, tripID: tripID, editing: request.existing != nil, candidateID: candidate?.id)
                    }
                }
            }
            .confirmationDialog("Delete your flight?", isPresented: Binding(get: { deleteRequest != nil }, set: { if !$0 { deleteRequest = nil } }), titleVisibility: .visible, presenting: deleteRequest) { flight in
                Button("Delete flight", role: .destructive) {
                    Task {
                        if await library.removeFlight(flight.id, tripID: tripID) { deleteRequest = nil }
                    }
                }
            } message: { _ in Text("This removes your flight from this trip. Other travelers' flights stay unchanged.") }
            .sheet(isPresented: $showsPeople) {
                TripPeopleSheet(library: library, trip: trip, currentUserID: library.currentUserID, isCloud: library.isCloud)
            }
            .sheet(isPresented: $showsEdit) {
                TripPlanningSheet(existing: trip, isCloud: library.isCloud, saveError: { library.errorMessage }) { name, airport, start, end, revision in
                    await library.saveDetails(tripID, name: name, airport: airport, start: start, end: end, revision: revision)
                }
            }
            .sheet(isPresented: $showsNotifications) {
                TripNotificationsSheet(library: library, trip: trip)
            }
        } else {
            ContentUnavailableView("Trip unavailable", systemImage: "suitcase",
                                   description: Text("Go back to Trips to choose a trip for this account."))
        }
    }

    private func tripOptions(_ trip: TripPlan) -> some View {
        Menu {
            Button("People", systemImage: "person.2") { showsPeople = true }
            if trip.cancelledAt == nil {
                Button("Notifications", systemImage: "bell") { showsNotifications = true }
            }
            if library.canEdit(trip) {
                Button("Edit trip", systemImage: "pencil") { showsEdit = true }
            }
            if library.canEdit(trip), trip.completedAt != nil {
                Button("Undo completion", systemImage: "arrow.uturn.backward") {
                    Task { _ = await library.setComplete(tripID, at: nil) }
                }
            } else if library.canEdit(trip), trip.phase() != .past {
                Button("Mark complete", systemImage: "checkmark.circle") { showsCompleteConfirmation = true }
            }
            Divider()
            if library.canManage(trip) {
                Button("Delete trip", systemImage: "trash", role: .destructive) {
                    lifecycleRevision = trip.revision; lifecycleAction = .delete
                }
                .accessibilityIdentifier("deleteTripButton")
            } else if library.selfParticipant(in: trip) != nil {
                Button("Leave trip", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                    lifecycleRevision = nil; lifecycleAction = .leave
                }
                .accessibilityIdentifier("leaveTripButton")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .accessibilityLabel("Trip options")
        .accessibilityIdentifier("tripOptionsButton")
        .disabled(library.isSaving)
    }

    private var lifecycleTitle: LocalizedStringKey {
        switch lifecycleAction {
        case .cancel: "Cancel this trip?"
        case .delete: "Delete this trip for everyone?"
        default: "Leave this trip?"
        }
    }

    private func lifecycleButton(_ action: TripLifecycleAction) -> LocalizedStringKey {
        switch action {
        case .cancel: "Cancel trip"
        case .delete: "Delete trip"
        default: "Leave trip"
        }
    }

    private func lifecycleMessage(_ action: TripLifecycleAction) -> LocalizedStringKey {
        switch action {
        case .cancel: "Everyone will see this trip as cancelled in Past. Records are kept, but editing, invitations and flight alerts stop. This does not cancel airline reservations."
        case .delete: "This permanently deletes the trip, shared flights and invitations for everyone. This cannot be undone and does not cancel airline reservations."
        default: "Your flights will be removed from this trip and you will lose access and stop receiving its alerts. You will need a new invitation to rejoin."
        }
    }
}

private struct FullTripArrivalBoard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var library: TripLibrary
    let trip: TripPlan
    let selfParticipant: TripParticipant?
    let onAddFlight: (TripDirection) -> Void
    let onEditFlight: (TripFlight) -> Void
    let onDeleteFlight: (TripFlight) -> Void
    let onPeople: () -> Void
    @State private var direction: TripDirection = .outbound
    @State private var selectedFlightID: String?
    @State private var showsMap = false

    private var visibleFlights: [TripFlight] {
        trip.flights.filter { $0.direction == direction }.sorted { $0.arrivalSortDate < $1.arrivalSortDate }
    }

    private var missingPeople: [TripParticipant] {
        trip.participants.filter { person in !visibleFlights.contains { $0.travelerID == person.id } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if trip.cancelledAt != nil {
                    Label("Trip cancelled · Read-only", systemImage: "xmark.circle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(WIFTheme.secondaryText)
                        .accessibilityIdentifier("cancelledTripStatus")
                } else if selfParticipant == nil {
                    Label("Read-only trip", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                }
                Picker("Journey", selection: $direction) {
                    ForEach(TripDirection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).accessibilityIdentifier("tripDirectionPicker")

                TimelineView(.periodic(from: .now, by: 60)) { context in
                    overview(at: context.date)
                }
                arrivalList

                if visibleFlights.isEmpty, library.canEdit(trip) {
                    Button(action: onPeople) {
                        Label("Invite friends", systemImage: "person.badge.plus")
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    }
                    .buttonStyle(.plain).foregroundStyle(WIFTheme.fresh)
                    .accessibilityIdentifier("inviteFriendsButton")
                } else {
                    TripRouteMapView(flights: visibleFlights, selectedFlightID: $selectedFlightID,
                                     direction: direction, destinationCode: trip.destinationAirport,
                                     onExpand: { showsMap = true })
                }
                if trip.isExample {
                    Text("Example itinerary · not live flight tracking.")
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(WIFTheme.primaryText)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.top, 8).padding(.bottom, 32)
        }
        .background(WIFTheme.canvas.ignoresSafeArea())
        .navigationTitle("").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .wifNavigationSurface()
        .wifPersistentTripNavigation()
        .toolbar {
            ToolbarItem(placement: WIFToolbarPlacement.primary) {
                if selfParticipant != nil, trip.cancelledAt == nil {
                    Button { onAddFlight(direction) } label: {
                        if #available(iOS 27.0, *) { Label("Add flight", systemImage: "plus") }
                        else { Text("Add flight") }
                    }
                        .font(.subheadline.weight(.medium))
                        .accessibilityLabel("Add my flight").accessibilityIdentifier("addBoardFlightButton")
                }
            }
        }
        .onChange(of: direction) { _, _ in selectedFlightID = nil }
        .fullScreenCover(isPresented: $showsMap) {
            TripImmersiveMap(flights: visibleFlights, selectedFlightID: $selectedFlightID,
                             direction: direction, tripName: trip.name, destinationCode: trip.destinationAirport)
        }
        .accessibilityIdentifier("fullTripArrivalBoard")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(trip.name)
                .font(.system(.title2, design: .rounded, weight: .bold)).tracking(-0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(trip.destinationName) · \(trip.destinationAirport)")
                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Text(trip.dateLabel).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        .fixedSize()
                    Spacer(minLength: 0)
                    peopleButton.fixedSize()
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(trip.dateLabel).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    peopleButton
                }
            }
        }
    }

    private var peopleButton: some View {
        Button(action: onPeople) {
            Label("\(trip.participants.count) \(trip.participants.count == 1 ? "person" : "people")", systemImage: "person.2")
                .font(.caption.weight(.medium)).frame(minHeight: 44)
        }
        .buttonStyle(.plain).foregroundStyle(WIFTheme.fresh)
        .accessibilityIdentifier("tripPeopleButton")
    }

    private func overview(at now: Date) -> some View {
        let summary = trip.arrivalOverview(direction: direction, at: now)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(summary.title).font(.subheadline.weight(.semibold))
                Text(summary.detail).font(.caption).foregroundStyle(WIFTheme.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !dynamicTypeSize.isAccessibilitySize, trip.participants.count <= 8 {
                HStack(spacing: 5) {
                    ForEach(0..<trip.participants.count, id: \.self) { index in
                        Circle().fill(index < summary.progressCount ? WIFTheme.fresh : WIFTheme.border.opacity(0.4))
                            .frame(width: 7, height: 7)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tripArrivalSummary")
    }

    private var arrivalList: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text(direction == .outbound ? "Arrivals" : "Heading home").font(.headline)
                    Spacer(minLength: 8)
                    arrivalTimeCaption.fixedSize()
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(direction == .outbound ? "Arrivals" : "Heading home").font(.headline)
                    arrivalTimeCaption
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(visibleFlights.enumerated()), id: \.element.id) { index, flight in
                    TripFlightCard(flight: flight, isExpanded: selectedFlightID == flight.id,
                                   isCurrentUser: flight.travelerID == selfParticipant?.id && selfParticipant != nil,
                                   showsArrivalTimeZone: direction == .inbound || flight.destination != trip.destinationAirport) {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88)) {
                            selectedFlightID = selectedFlightID == flight.id ? nil : flight.id
                        }
                    }
                    if trip.cancelledAt == nil, selectedFlightID == flight.id, let selfParticipant, flight.travelerID == selfParticipant.id {
                        HStack(spacing: 20) {
                            Button("Edit my flight", systemImage: "pencil") { onEditFlight(flight) }
                                .accessibilityIdentifier("editMyTripFlightButton")
                            Spacer(minLength: 0)
                            Button("Delete", systemImage: "trash", role: .destructive) { onDeleteFlight(flight) }
                                .accessibilityIdentifier("deleteMyTripFlightButton")
                        }
                        .font(.subheadline).buttonStyle(.plain).frame(minHeight: 44).padding(.bottom, 8)
                    }
                    if index < visibleFlights.count - 1 || !missingPeople.isEmpty { Divider().opacity(0.45) }
                }
                ForEach(Array(missingPeople.enumerated()), id: \.element.id) { index, person in
                    missingTraveler(person)
                    if index < missingPeople.count - 1 { Divider().opacity(0.45) }
                }
            }
            .padding(.horizontal, 14)
            .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        }
    }

    private var arrivalTimeCaption: some View {
        let usesDestinationTime = direction == .outbound && visibleFlights.allSatisfy { $0.destination == trip.destinationAirport }
        return Text(usesDestinationTime ? "\(trip.destinationName) time" : "Local arrival times")
            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
    }

    private func missingTraveler(_ person: TripParticipant) -> some View {
        HStack(spacing: 11) {
            TripTravelerAvatar(name: person.name, color: WIFTheme.secondaryText.opacity(0.5), size: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(person.name).font(.subheadline.weight(.medium))
                Text(person.id == selfParticipant?.id ? "Add your \(direction == .outbound ? "outbound" : "return") flight" : "Flight not added yet")
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            if person.id == selfParticipant?.id, trip.cancelledAt == nil {
                Button("Add flight") { onAddFlight(direction) }
                    .font(.caption.weight(.semibold)).foregroundStyle(WIFTheme.fresh)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("tripNeedsHelpCard")
            } else if direction == .outbound, library.canRemind(person, in: trip) {
                TripReminderButton(library: library, trip: trip, person: person)
            } else {
                Image(systemName: "clock").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("missingTraveler-\(person.id)")
    }
}

private struct TripArrivalSummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let flight: TripFlight
    let isExpanded: Bool
    var isCurrentUser = false
    var showsArrivalTimeZone = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if !dynamicTypeSize.isAccessibilitySize {
                TripTravelerAvatar(name: flight.traveler, color: flight.accent, size: 34)
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    travelerDetails
                    arrivalDetails
                }
                Spacer(minLength: 0)
            } else {
                travelerDetails
                Spacer(minLength: 4)
                arrivalDetails
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .foregroundStyle(WIFTheme.secondaryText)
        }
        .foregroundStyle(WIFTheme.primaryText)
    }

    private var travelerDetails: some View {
        VStack(alignment: .leading, spacing: 3) {
            (Text(flight.traveler).font(.subheadline.weight(.semibold)) +
             Text(isCurrentUser ? "  You" : "").font(.caption).foregroundColor(WIFTheme.secondaryText))
                .fixedSize(horizontal: false, vertical: true)
            Text("\(flight.origin) → \(flight.destination) · \(flight.flightNumber)")
                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(flight.isStatusStale(at: context.date) ? "Updates delayed" : flight.status.title)
                    .font(.caption2)
                    .foregroundStyle(flight.isStatusStale(at: context.date) ? WIFTheme.secondaryText : flight.status.accent)
            }
        }
    }

    private var arrivalDetails: some View {
        VStack(alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing, spacing: 3) {
            Text(flight.arrivalTime).font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
            if let day = flight.arrivalDayLabel {
                Text(day).font(.caption2).foregroundStyle(WIFTheme.secondaryText)
            }
            if showsArrivalTimeZone, let zone = flight.arrivalTimeZoneLabel {
                Text(zone).font(.caption2).foregroundStyle(WIFTheme.secondaryText)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct TripFlightCard: View {
    let flight: TripFlight
    let isExpanded: Bool
    var isCurrentUser = false
    var showsArrivalTimeZone = false
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                TripArrivalSummary(flight: flight, isExpanded: isExpanded, isCurrentUser: isCurrentUser,
                                   showsArrivalTimeZone: showsArrivalTimeZone)
                    .padding(.vertical, 13).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(flight.traveler), \(flight.flightNumber), \(flight.origin) to \(flight.destination), arrives \(flight.arrivalDayLabel ?? "date unconfirmed"), \(flight.arrivalTime) \(flight.arrivalTimeZoneLabel ?? ""), \(flight.status.title)")
            .accessibilityValue(isExpanded ? "Details expanded" : "Details collapsed")
            .accessibilityHint("Double tap to \(isExpanded ? "hide" : "show") flight details")
            .accessibilityIdentifier("flightCard-\(flight.id)")

            if isExpanded {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(alignment: .top) {
                        endpoint(flight.origin, time: flight.departureTime, caption: "Departure")
                        Spacer()
                        Image(systemName: "airplane").font(.subheadline).foregroundStyle(flight.accent).padding(.top, 22)
                        Spacer()
                        endpoint(flight.destination, time: flight.arrivalTime, caption: "Arrival", trailing: true)
                    }
                    .padding(14)
                    .background(WIFTheme.elevatedSurface.opacity(0.58), in: RoundedRectangle(cornerRadius: 16))
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(flight.flightNumber).font(.subheadline.weight(.semibold))
                            Text(flight.airline).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(flight.terminal).font(.subheadline.weight(.semibold))
                            Text(flight.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        }
                    }
                    if flight.status == .unverified {
                        Text("Search to confirm route and schedule")
                            .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    } else if flight.verifiedAt != nil {
                        TimelineView(.periodic(from: .now, by: 60)) { context in
                            Text(flight.freshnessLabel(at: context.date))
                                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        }
                    }
                }
                .padding(.bottom, 18)
                .accessibilityIdentifier("flightDetails-\(flight.id)")
                .transition(.opacity)
            }
        }
    }

    private func endpoint(_ code: String, time: String, caption: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 4) {
            Text(caption).font(.caption2).foregroundStyle(WIFTheme.secondaryText)
            Text("\(code)  \(time)").font(.system(.subheadline, design: .rounded, weight: .semibold)).monospacedDigit()
            Text(AirportLocation.location(for: code)?.city ?? "Awaiting lookup")
                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
        }
    }
}


private struct TripRouteMapView: View {
    let flights: [TripFlight]
    @Binding var selectedFlightID: String?
    let direction: TripDirection
    let destinationCode: String
    let onExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(direction == .outbound ? "Coming together" : "Heading home")
                    .font(.headline)
                Spacer(minLength: 8)
                Button(action: onExpand) {
                    Label("View map", systemImage: "arrow.up.right")
                        .font(.caption.weight(.medium)).frame(minHeight: 44)
                }
                .buttonStyle(.plain).foregroundStyle(WIFTheme.fresh)
                .accessibilityLabel("Expand map")
                .accessibilityIdentifier("expandTripMapButton")
            }
            TripGeographicMap(flights: flights, selectedFlightID: $selectedFlightID, isInteractive: false, destinationCode: destinationCode)
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .accessibilityIdentifier("tripRouteMapView")
            Text("Airport routes · not live aircraft positions")
                .font(.caption2).foregroundStyle(WIFTheme.secondaryText)
        }
    }
}

private struct TripImmersiveMap: View {
    @Environment(\.dismiss) private var dismiss
    let flights: [TripFlight]
    @Binding var selectedFlightID: String?
    let direction: TripDirection
    let tripName: String
    let destinationCode: String

    private var selectedFlight: TripFlight? {
        flights.count == 1 ? flights.first : flights.first { $0.id == selectedFlightID }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(direction == .outbound ? "Coming together" : "Heading home")
                        .font(.title2.bold())
                    Text(tripName).font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(WIFTheme.elevatedSurface, in: Circle())
                }
                .buttonStyle(.plain).accessibilityLabel("Close map")
                .accessibilityIdentifier("closeTripMapButton")
            }
            .padding(20)

            TripGeographicMap(flights: flights, selectedFlightID: $selectedFlightID, isInteractive: true, destinationCode: destinationCode)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .padding(.horizontal, 10)

            VStack(alignment: .leading, spacing: 16) {
                if flights.count > 1 {
                    TripMapTravelerPicker(flights: flights, selectedFlightID: $selectedFlightID)
                }
                if let flight = selectedFlight {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            TripTravelerAvatar(name: flight.traveler, color: flight.accent, size: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(flight.traveler).font(.headline)
                                Text("\(flight.flightNumber) · \(flight.status.title)")
                                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                            }
                            Spacer()
                            Text(flight.arrivalTime).font(.system(.title2, design: .rounded, weight: .semibold))
                        }
                        Text("\(flight.origin)  →  \(flight.destination)")
                            .font(.subheadline.weight(.medium)).foregroundStyle(WIFTheme.secondaryText)
                    }
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("mapSelectedFlight")
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(direction == .outbound ? "Different cities. Same destination." : "Until the next adventure.")
                            .font(.headline)
                        Text("Choose a friend to explore their journey.")
                            .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                    }
                    .padding(.horizontal, 20)
                }
                Text("Airport routes · not live aircraft positions")
                    .font(.caption2).foregroundStyle(WIFTheme.secondaryText)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 18).padding(.bottom, 16)
        }
        .foregroundStyle(WIFTheme.primaryText)
        .background(WIFTheme.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("immersiveTripMap")
    }
}

private struct TripMapTravelerPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let flights: [TripFlight]
    @Binding var selectedFlightID: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Everyone", id: nil, color: WIFTheme.fresh)
                ForEach(flights) { flight in
                    chip(flight.traveler.components(separatedBy: " ").first ?? flight.traveler,
                         id: flight.id, color: flight.accent)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(_ title: String, id: String?, color: Color) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.7)) { selectedFlightID = id }
        } label: {
            HStack(spacing: 6) {
                if let id, let flight = flights.first(where: { $0.id == id }) {
                    TripTravelerAvatar(name: flight.traveler, color: color, size: 22)
                } else {
                    Image(systemName: "person.2").font(.caption)
                }
                Text(title).font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background(selectedFlightID == id ? WIFTheme.freshSurface : WIFTheme.canvas.opacity(0.7), in: Capsule())
            .overlay(Capsule().strokeBorder(selectedFlightID == id ? WIFTheme.fresh.opacity(0.28) : .clear, lineWidth: 1))
        }
        .foregroundStyle(selectedFlightID == id ? WIFTheme.fresh : WIFTheme.secondaryText)
        .buttonStyle(.plain)
        .accessibilityLabel(id.flatMap { key in flights.first { $0.id == key }?.traveler } ?? "Everyone")
        .accessibilityValue(selectedFlightID == id ? "Selected" : "Not selected")
        .accessibilityAddTraits(selectedFlightID == id ? .isSelected : [])
        .accessibilityIdentifier("mapTraveler-\(id ?? "all")")
    }
}

private struct TripGeographicMap: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let flights: [TripFlight]
    @Binding var selectedFlightID: String?
    let isInteractive: Bool
    let destinationCode: String
    @State private var position: MapCameraPosition = .automatic
    @State private var reveal: Double = 0
    @State private var didReveal = false

    private var routes: [TripMapRoute] { flights.compactMap(TripMapRoute.init) }
    private var focusedRoutes: [TripMapRoute] {
        guard let selectedFlightID else { return routes }
        return routes.filter { $0.id == selectedFlightID }
    }
    private var selectionHasNoRoute: Bool {
        selectedFlightID != nil && focusedRoutes.isEmpty
    }
    private var routeKey: String { routes.map(\.id).joined(separator: ",") }

    private struct Hub: Identifiable {
        let id: String
        let airport: AirportLocation
        let codes: String
        let flightIDs: [String]
        let isDestination: Bool
    }

    private var hubs: [Hub] {
        let shown = focusedRoutes
        var airportsByCity: [String: [AirportLocation]] = [:]
        var idsByCity: [String: [String]] = [:]
        for route in shown {
            for airport in [route.origin, route.destination] {
                if !(airportsByCity[airport.city] ?? []).contains(where: { $0.code == airport.code }) {
                    airportsByCity[airport.city, default: []].append(airport)
                }
                if !(idsByCity[airport.city] ?? []).contains(route.id) {
                    idsByCity[airport.city, default: []].append(route.id)
                }
            }
        }
        return airportsByCity.keys.sorted().compactMap { city in
            guard let airports = airportsByCity[city], let airport = airports.first else { return nil }
            return Hub(id: city, airport: airport, codes: airports.map(\.code).sorted().joined(separator: " / "),
                       flightIDs: idsByCity[city] ?? [], isDestination: airport.code == destinationCode)
        }
    }

    var body: some View {
        Map(position: $position, interactionModes: isInteractive ? [.pan, .zoom, .rotate] : []) {
            ForEach(routes) { route in
                MapPolyline(coordinates: route.coordinates)
                    .stroke(WIFTheme.fresh.opacity(selectedFlightID == nil ? 0.13 : 0.09), lineWidth: 2)
                if selectedFlightID == nil || selectedFlightID == route.id {
                    MapPolyline(coordinates: route.revealedCoordinates(reduceMotion ? 1 : reveal))
                        .stroke(selectedFlightID == nil ? WIFTheme.fresh.opacity(0.68) : route.flight.accent,
                                style: StrokeStyle(lineWidth: selectedFlightID == nil ? 2 : 3, lineCap: .round))
                }
            }
            ForEach(hubs) { hub in
                Annotation(hub.airport.city, coordinate: hub.airport.coordinate, anchor: .center) {
                    Button {
                        if hub.flightIDs.count == 1 { selectedFlightID = hub.flightIDs.first }
                    } label: {
                        Circle().fill(hub.isDestination ? WIFTheme.fresh : WIFTheme.surface)
                            .frame(width: hub.isDestination ? 10 : 7, height: hub.isDestination ? 10 : 7)
                            .overlay(Circle().strokeBorder(WIFTheme.fresh, lineWidth: 2))
                            .frame(width: 44, height: 44)
                            .overlay {
                            Text(hub.codes)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 7).padding(.vertical, 4)
                                .foregroundStyle(hub.isDestination ? WIFTheme.canvas : WIFTheme.primaryText)
                                .background(hub.isDestination ? WIFTheme.fresh : WIFTheme.surface, in: Capsule())
                                .fixedSize()
                                .offset(x: hub.isDestination ? 12 : 0, y: hub.isDestination ? 23 : -23)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(hub.airport.city), \(hub.codes), \(hub.flightIDs.count) flights")
                    .accessibilityHint(hub.flightIDs.count > 1 ? "Choose a traveler using the buttons below the map" : "Show this route")
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .mapControls {}
        .overlay(alignment: .topTrailing) {
            if isInteractive {
                Button {
                    selectedFlightID = nil
                    focus(animated: true)
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(WIFTheme.surface, in: Circle())
                }
                .buttonStyle(.plain).foregroundStyle(WIFTheme.fresh)
                .padding(12).accessibilityLabel("Show all routes")
                .accessibilityIdentifier("resetTripMapButton")
            }
        }
        .overlay {
            if selectionHasNoRoute || routes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "map").font(.title2)
                    Text("Route awaiting verification").font(.subheadline.weight(.semibold))
                    Text("No airport locations have been assumed.").font(.caption)
                }
                .foregroundStyle(WIFTheme.secondaryText)
                .padding(20).background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .task(id: routeKey) {
            focus(animated: false)
            guard !didReveal, !reduceMotion else { reveal = 1; return }
            didReveal = true
            // One route reveal on entry, not simulated live movement. Cancellation stops updates offscreen.
            for step in 1...30 {
                guard !Task.isCancelled else { return }
                reveal = Double(step) / 30
                do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
            }
        }
        .onChange(of: selectedFlightID) { _, _ in focus(animated: true) }
        .onChange(of: reduceMotion) { _, reduced in if reduced { reveal = 1 } }
        .accessibilityLabel("Airport route map")
    }

    private func focus(animated: Bool) {
        let target = TripMapRoute.fittingRect(for: focusedRoutes.isEmpty ? routes : focusedRoutes)
        withAnimation(animated && !reduceMotion ? .easeInOut(duration: 0.85) : nil) {
            if routes.isEmpty, let airport = AirportLocation.location(for: destinationCode) {
                position = .region(MKCoordinateRegion(center: airport.coordinate, span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)))
            } else {
                position = .rect(target)
            }
        }
    }
}

// Geographic data stays independent of screen dimensions and works across the date line.
struct TripMapRoute: Identifiable {
    let flight: TripFlight
    let origin: AirportLocation
    let destination: AirportLocation
    let coordinates: [CLLocationCoordinate2D]
    var id: String { flight.id }

    init?(_ flight: TripFlight) {
        guard flight.status != .unverified,
              let origin = AirportLocation.location(for: flight.origin),
              let destination = AirportLocation.location(for: flight.destination) else { return nil }
        self.flight = flight
        self.origin = origin
        self.destination = destination
        let line = MKGeodesicPolyline(coordinates: [origin.coordinate, destination.coordinate], count: 2)
        coordinates = (0..<line.pointCount).map { line.points()[$0].coordinate }
    }

    func revealedCoordinates(_ progress: Double) -> [CLLocationCoordinate2D] {
        Array(coordinates.prefix(max(2, Int(Double(coordinates.count) * min(1, max(0, progress))))))
    }

    static func fittingRect(for routes: [TripMapRoute]) -> MKMapRect {
        let points = routes.flatMap(\.coordinates).map(MKMapPoint.init)
        guard !points.isEmpty else {
            let point = MKMapPoint(CLLocationCoordinate2D(latitude: 37, longitude: -98))
            return MKMapRect(x: point.x - 30_000_000, y: point.y - 15_000_000, width: 60_000_000, height: 30_000_000)
        }
        let world = MKMapRect.world.width
        let xs = points.map { ($0.x.truncatingRemainder(dividingBy: world) + world).truncatingRemainder(dividingBy: world) }.sorted()
        var largestGap = -Double.infinity
        var startX = xs[0]
        for index in xs.indices {
            let next = index + 1 < xs.count ? xs[index + 1] : xs[0] + world
            if next - xs[index] > largestGap {
                largestGap = next - xs[index]
                startX = next.truncatingRemainder(dividingBy: world)
            }
        }
        let unwrapped = xs.map { $0 < startX - 0.01 ? $0 + world : $0 }
        let minY = points.map(\.y).min()!
        let maxY = points.map(\.y).max()!
        let width = max((unwrapped.max() ?? startX) - startX, world * 0.003)
        let height = max(maxY - minY, world * 0.003)
        return MKMapRect(x: startX, y: minY, width: width, height: height)
            .insetBy(dx: -max(width * 0.17, world * 0.004), dy: -max(height * 0.3, world * 0.004))
    }
}


private struct TripTravelerAvatar: View {
    let name: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Text(String(name.split(separator: " ").prefix(2).compactMap(\.first)))
            .font(.system(size: size * 0.29, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

private struct AddTripFlightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    let trip: TripPlan
    let direction: TripDirection
    let person: TripParticipant
    let existing: TripFlight?
    let onAdd: (String, Date, FlightCandidate?) async -> Bool
    let saveError: () -> String?
    @State private var isSaving = false
    @State private var searchGeneration = UUID()
    @State private var flightNumber = ""
    @State private var date: Date
    @FocusState private var numberFocused: Bool
    @State private var showsSaveError = false
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var candidates: [FlightCandidate] = []
    @State private var showsCustomCalendar = false
    @State private var selectedCandidate: FlightCandidate?
    @State private var selectedDetent: PresentationDetent = .height(580)

    init(trip: TripPlan, person: TripParticipant, direction: TripDirection, existing: TripFlight? = nil,
         saveError: @escaping () -> String? = { nil },
         onAdd: @escaping (String, Date, FlightCandidate?) async -> Bool) {
        self.saveError = saveError
        self.trip = trip
        self.direction = direction
        self.onAdd = onAdd
        self.person = person
        self.existing = existing
        _flightNumber = State(initialValue: existing?.flightNumber ?? "")
        _date = State(initialValue: trip.initialFlightDate(existing: existing))
    }

    private var travelerName: String { person.name }

    private var cleanedNumber: String { flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    private var isValid: Bool {
        person.userID != nil && cleanedNumber.range(of: "^[A-Z0-9]{2,3} ?[0-9]{1,4}[A-Z]?$", options: .regularExpression) != nil
    }

    private var dateString: String {
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 2026, parts.month ?? 1, parts.day ?? 1)
    }

    private var formattedDisplayDate: String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "MMM d"
            return "Today, \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "EEE, MMM d"
            return formatter.string(from: date)
        }
    }

    private func setDate(_ newDate: Date) {
        date = newDate
        selectedCandidate = nil
        candidates = []
        searchError = nil
    }

    private func searchFlight() {
        guard isValid else { return }
        numberFocused = false
        isSearching = true
        searchError = nil
        candidates = []
        selectedCandidate = nil

        let queryNumber = cleanedNumber
        let generation = UUID()
        searchGeneration = generation
        let queryDate = dateString
        let tripID = trip.id
        let dest = trip.destinationAirport.uppercased()
        let isOutbound = direction == .outbound

        Task {
            do {
                let results = try await store.lookupFlight(tripID: tripID, flightNumber: queryNumber, date: queryDate)
                await MainActor.run {
                    guard searchGeneration == generation, cleanedNumber == queryNumber, dateString == queryDate else { return }
                    self.isSearching = false
                    self.candidates = results
                    if results.isEmpty {
                        self.searchError = "No flight routes found for \(queryNumber) on \(queryDate)."
                    } else {
                        self.selectedDetent = .large
                        if let matched = results.first(where: { cand in
                            if isOutbound {
                                return cand.arrival.code?.uppercased() == dest
                            } else {
                                return cand.departure.code?.uppercased() == dest
                            }
                        }) {
                            self.selectedCandidate = matched
                        } else {
                            self.selectedCandidate = results.first
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    guard searchGeneration == generation, cleanedNumber == queryNumber, dateString == queryDate else { return }
                    self.isSearching = false
                    self.searchError = error.localizedDescription
                }
            }
        }
    }

    private func invalidateSearch() {
        searchGeneration = UUID()
        isSearching = false
        selectedCandidate = nil
        candidates = []
        searchError = nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Compact trip context; the traveler is fixed to the signed-in account.
                    HStack(spacing: 8) {
                        Text(direction == .outbound ? "Outbound" : "Inbound")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(WIFTheme.fresh.opacity(0.12), in: Capsule())
                            .foregroundStyle(WIFTheme.fresh)

                        Text(trip.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(WIFTheme.primaryText)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 6) {
                            TripTravelerAvatar(name: travelerName, color: TripFlight.color(for: travelerName), size: 22)
                            Text(travelerName)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(WIFTheme.secondaryText)
                        }
                        .accessibilityIdentifier("tripSignedInTraveler")
                    }
                    .padding(.horizontal, 2)
                    Text(store.repositoryMode == .remote ? "Your flight · signed-in account" : "Your flight · demo account")
                        .font(.caption2).foregroundStyle(WIFTheme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("tripFlightOwnershipCaption")

                    // Flight number card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("FLIGHT NUMBER")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.secondaryText)
                            .tracking(0.5)

                        HStack(spacing: 12) {
                            Image(systemName: "airplane")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(WIFTheme.fresh)

                            TextField("e.g. CZ 328, UA 353", text: $flightNumber)
                                .font(.title3.weight(.semibold))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .keyboardType(.asciiCapable)
                                .submitLabel(.search)
                                .focused($numberFocused)
                                .onSubmit {
                                    numberFocused = false
                                    searchFlight()
                                }
                                .onChange(of: flightNumber) { _, _ in
                                    selectedCandidate = nil
                                    candidates = []
                                    searchError = nil
                                }
                                .accessibilityIdentifier("tripFlightNumberField")

                            if !flightNumber.isEmpty {
                                Button {
                                    flightNumber = ""
                                    selectedCandidate = nil
                                    candidates = []
                                    searchError = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(WIFTheme.secondaryText.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                searchFlight()
                            } label: {
                                HStack(spacing: 5) {
                                    if isSearching {
                                        ProgressView().tint(WIFTheme.canvas)
                                    } else {
                                        Image(systemName: "magnifyingglass")
                                        Text("Search")
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isValid ? WIFTheme.canvas : WIFTheme.secondaryText)
                                .padding(.horizontal, 16)
                                .frame(height: 38)
                                .background(isValid ? WIFTheme.fresh : WIFTheme.border.opacity(0.3), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(!isValid || isSearching)
                            .accessibilityIdentifier("lookupFlightButton")
                        }
                    }
                    .padding(16)
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 18))

                    // Departure date selection: unified single row
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("DEPARTURE DATE")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(WIFTheme.secondaryText)
                                .tracking(0.5)

                            Spacer()

                            Text("Departure airport local date")
                                .font(.caption2)
                                .foregroundStyle(WIFTheme.secondaryText.opacity(0.8))
                        }

                        Button {
                            showsCustomCalendar = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .font(.headline)
                                    .foregroundStyle(WIFTheme.fresh)

                                Text(formattedDisplayDate)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(WIFTheme.primaryText)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(WIFTheme.secondaryText)
                            }
                            .padding(14)
                            .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tripFlightDatePicker")
                    }

                    if isSearching {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text(store.repositoryMode == .remote ? "Looking up flight details…" : "Loading example flight…")
                                .font(.subheadline)
                                .foregroundStyle(WIFTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                    }

                    if let searchError {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(WIFTheme.destructive)
                            Text(searchError)
                                .font(.caption)
                                .foregroundStyle(WIFTheme.secondaryText)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if !candidates.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(store.repositoryMode == .remote ? "Verified Routes (\(candidates.count))" : "Example Routes (\(candidates.count))")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(WIFTheme.secondaryText)
                                Spacer()
                                if selectedCandidate != nil {
                                    Text("Selected")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(WIFTheme.fresh)
                                }
                            }

                            ForEach(candidates) { candidate in
                                let isSelected = selectedCandidate?.id == candidate.id
                                Button {
                                    selectedCandidate = candidate
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 8) {
                                                Text(candidate.airline ?? candidate.flightNumber)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(WIFTheme.primaryText)
                                                Text(candidate.flightNumber)
                                                    .font(.caption.weight(.medium))
                                                    .foregroundStyle(WIFTheme.secondaryText)
                                                Spacer()
                                                Text(candidate.tripStatus.title)
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(candidate.tripStatus.accent.opacity(0.15), in: Capsule())
                                                    .foregroundStyle(candidate.tripStatus.accent)
                                            }

                                            HStack(spacing: 16) {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(candidate.departure.code ?? "—")
                                                        .font(.title3.weight(.bold))
                                                        .foregroundStyle(WIFTheme.primaryText)
                                                    Text(candidate.departureTimeFormatted)
                                                        .font(.caption)
                                                        .foregroundStyle(WIFTheme.secondaryText)
                                                }

                                                Image(systemName: "arrow.right")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(WIFTheme.secondaryText)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(candidate.arrival.code ?? "—")
                                                        .font(.title3.weight(.bold))
                                                        .foregroundStyle(WIFTheme.primaryText)
                                                    Text(candidate.arrivalTimeFormatted)
                                                        .font(.caption)
                                                        .foregroundStyle(WIFTheme.secondaryText)
                                                }

                                                Spacer()

                                                if candidate.terminalFormatted != "Not available" {
                                                    Text(candidate.terminalFormatted)
                                                        .font(.caption2)
                                                        .foregroundStyle(WIFTheme.secondaryText)
                                                }
                                            }
                                        }

                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(isSelected ? WIFTheme.fresh : WIFTheme.border)
                                    }
                                    .padding(14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(isSelected ? WIFTheme.fresh.opacity(0.08) : WIFTheme.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 14)
                                                    .stroke(isSelected ? WIFTheme.fresh : Color.clear, lineWidth: 1.5)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("flightCandidateCard-\(candidate.id)")
                            }
                        }
                    } else if searchError == nil && !isSearching {
                        Label {
                            Text(store.repositoryMode == .remote ? "Flight lookup queries schedules via AeroDataBox. You can also save without lookup as unverified." : "Demo flights are examples, not live schedules. Sign in to your cloud account for real flight lookup.")
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "info.circle")
                        }
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
                .foregroundStyle(WIFTheme.primaryText)
            }
            .scrollDismissesKeyboard(.interactively)
            .disabled(isSaving)
            .background(WIFTheme.canvas)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        isSaving = true
                        Task {
                            if await onAdd(cleanedNumber, date, selectedCandidate) { dismiss() }
                            else { showsSaveError = true }
                            isSaving = false
                        }
                    } label: {
                        Text(existing == nil ? "Add my flight" : "Save my flight").font(.headline)
                            .frame(maxWidth: .infinity)
                            .wifPrimaryActionLabel(enabled: isValid)
                    }
                    .wifPrimaryActionStyle().disabled(!isValid || isSearching || isSaving)
                    .accessibilityIdentifier("confirmAddTripFlightButton")
                }
                .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 16)
                .background(WIFTheme.canvas)
            }
            .alert("Couldn't save flight", isPresented: $showsSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveError() ?? "Your input has been kept. Please try again.")
            }
            .navigationTitle(existing == nil ? "Add flight" : "Edit my flight").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
            }
        }
        .presentationDetents([.height(580), .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(isSaving)
        .onChange(of: flightNumber) { _, _ in invalidateSearch() }
        .onChange(of: date) { _, _ in invalidateSearch() }
        .onDisappear { searchGeneration = UUID() }
        .sheet(isPresented: $showsCustomCalendar) {
            NavigationStack {
                VStack(spacing: 16) {
                    DatePicker(
                        "Departure date",
                        selection: $date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(WIFTheme.fresh)
                    .padding(.horizontal)
                    .onChange(of: date) { _, _ in
                        selectedCandidate = nil
                        candidates = []
                        searchError = nil
                    }

                    Spacer()
                }
                .background(WIFTheme.canvas)
                .navigationTitle("Select Departure Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showsCustomCalendar = false
                        }
                        .font(.headline)
                        .foregroundStyle(WIFTheme.fresh)
                    }
                }
            }
            .presentationDetents([.height(480)])
        }
    }
}

enum TripDirection: String, CaseIterable, Identifiable, Codable {
    case outbound
    case inbound

    var id: String { rawValue }
    var title: String { self == .outbound ? "Outbound" : "Return" }
}

enum TripFlightStatus: String, Codable {
    case airborne, cancelled, diverted, unknown
    case landed
    case boarding
    case onTime
    case scheduled
    case delayed
    case unverified

    var title: String {
        switch self {
        case .airborne: "In flight"
        case .cancelled: "Cancelled"
        case .diverted: "Diverted"
        case .unknown: "Status unknown"
        case .landed: "Landed"
        case .boarding: "Boarding"
        case .onTime: "On time"
        case .scheduled: "Scheduled"
        case .delayed: "Delayed"
        case .unverified: "Unverified"
        }
    }

    var accent: Color {
        switch self {
        case .landed, .onTime, .airborne: WIFTheme.fresh
        case .boarding: WIFTripTheme.sky
        case .scheduled, .unverified, .unknown: WIFTheme.secondaryText
        case .delayed, .cancelled, .diverted: WIFTheme.destructive
        }
    }
}

struct TripFlight: Identifiable, Codable {
    let id: String
    var traveler: String
    let flightNumber: String
    let airline: String
    let origin: String
    let destination: String
    let departureTime: String
    let arrivalTime: String
    var date: Date
    let terminal: String
    let status: TripFlightStatus
    let direction: TripDirection
    var arrivalDayOffset: Int = 0
    var travelerID: String? = nil
    var revision: Int? = nil
    var candidateID: String? = nil
    var verifiedAt: Date? = nil
    var trackingState: String? = nil
    var scheduledDeparture: Date? = nil
    var expectedArrival: Date? = nil
    var accent: Color { Self.color(for: traveler) }

    func isStatusStale(at now: Date = Date()) -> Bool {
        guard status != .unverified else { return false }
        if ["unavailable", "not_found", "quota_limited"].contains(trackingState ?? "") { return true }
        guard let verifiedAt else { return false }
        if status == .landed || status == .cancelled { return false }
        if let departure = scheduledDeparture, departure > now.addingTimeInterval(24 * 3600) {
            return false
        }
        return now.timeIntervalSince(verifiedAt) > 45 * 60
    }

    func freshnessLabel(at now: Date = Date()) -> String {
        guard let verifiedAt else { return "Unverified" }
        let stamp = verifiedAt.formatted(date: .abbreviated, time: .shortened)
        if trackingState == "quota_limited" { return "Update limit reached · last checked \(stamp)" }
        if trackingState == "unavailable" { return "Updates temporarily unavailable · last checked \(stamp)" }
        if trackingState == "not_found" { return "Route not found in latest check · last verified \(stamp)" }
        if isStatusStale(at: now) { return "Last known status · checked \(stamp)" }
        return "Updated \(stamp)"
    }

    private var displayArrivalDate: Date? {
        guard status != .unverified, AirportLocation.location(for: destination) != nil else { return nil }
        if let expectedArrival { return expectedArrival }
        let arrival = arrivalSortDate
        return arrival == .distantFuture ? nil : arrival
    }

    var arrivalDayLabel: String? {
        guard let arrival = displayArrivalDate, let airport = AirportLocation.location(for: destination) else { return nil }
        let formatter = DateFormatter()
        formatter.timeZone = airport.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: arrival)
    }

    var arrivalTimeZoneLabel: String? {
        guard let arrival = displayArrivalDate else { return nil }
        return AirportLocation.location(for: destination)?.timeZone.abbreviation(for: arrival)
    }

    var arrivalSortDate: Date {
        guard let airport = AirportLocation.location(for: destination),
              status != .unverified else { return .distantFuture }
        let parts = arrivalTime.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return .distantFuture }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = airport.timeZone
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = parts[0]
        components.minute = parts[1]
        guard let day = calendar.date(from: components),
              let arrival = calendar.date(byAdding: .day, value: arrivalDayOffset, to: day) else { return .distantFuture }
        return arrival
    }

    static func color(for traveler: String) -> Color {
        switch traveler {
        case "Mia Chen": return WIFTripTheme.warm
        case "David Kim": return Color(red: 0.74, green: 0.49, blue: 0.16)
        case "Lin Zhao": return WIFTripTheme.violet
        case "Alex Rivera": return Color(red: 0.16, green: 0.57, blue: 0.50)
        default: return WIFTripTheme.sky
        }
    }

    static let previewFlights: [TripFlight] = {
        let date = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 15)) ?? Date()
        let returnDate = Calendar.current.date(from: DateComponents(year: 2026, month: 4, day: 20)) ?? Date()
        return [
            TripFlight(
                id: "wang-out", traveler: "Wang Yang", flightNumber: "UA 353", airline: "United Airlines",
                origin: "EWR", destination: "LAX", departureTime: "18:30", arrivalTime: "21:33",
                date: date, terminal: "Terminal 7", status: .onTime, direction: .outbound
            ),
            TripFlight(
                id: "mia-out", traveler: "Mia Chen", flightNumber: "AS 1187", airline: "Alaska Airlines",
                origin: "SFO", destination: "LAX", departureTime: "17:10", arrivalTime: "18:42",
                date: date, terminal: "Terminal 6", status: .landed, direction: .outbound
            ),
            TripFlight(
                id: "david-out", traveler: "David Kim", flightNumber: "DL 2314", airline: "Delta Air Lines",
                origin: "SEA", destination: "LAX", departureTime: "18:45", arrivalTime: "21:27",
                date: date, terminal: "Terminal 3", status: .onTime, direction: .outbound
            ),
            TripFlight(
                id: "alex-out", traveler: "Alex Rivera", flightNumber: "BA 281", airline: "British Airways",
                origin: "LHR", destination: "LAX", departureTime: "15:20", arrivalTime: "18:35",
                date: date, terminal: "Tom Bradley", status: .boarding, direction: .outbound
            ),
            TripFlight(
                id: "wang-in", traveler: "Wang Yang", flightNumber: "UA 2146", airline: "United Airlines",
                origin: "LAX", destination: "EWR", departureTime: "13:15", arrivalTime: "21:41",
                date: returnDate, terminal: "Terminal 7", status: .scheduled, direction: .inbound
            ),
            TripFlight(
                id: "mia-in", traveler: "Mia Chen", flightNumber: "AS 347", airline: "Alaska Airlines",
                origin: "LAX", destination: "SFO", departureTime: "14:05", arrivalTime: "15:32",
                date: returnDate, terminal: "Terminal 6", status: .scheduled, direction: .inbound
            ),
            TripFlight(
                id: "david-in", traveler: "David Kim", flightNumber: "DL 2781", airline: "Delta Air Lines",
                origin: "LAX", destination: "SEA", departureTime: "16:20", arrivalTime: "19:04",
                date: returnDate, terminal: "Terminal 3", status: .scheduled, direction: .inbound
            ),
            TripFlight(
                id: "alex-in", traveler: "Alex Rivera", flightNumber: "BA 282", airline: "British Airways",
                origin: "LAX", destination: "LHR", departureTime: "17:30", arrivalTime: "12:00",
                date: returnDate, terminal: "Tom Bradley", status: .scheduled, direction: .inbound, arrivalDayOffset: 1
            )
        ]
    }()
}

#Preview {
    NavigationStack {
        TripsView()
            .environmentObject(AppStore())
    }
}
