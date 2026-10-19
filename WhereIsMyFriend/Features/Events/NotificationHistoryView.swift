import SwiftUI

struct NotificationHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var referenceDate = Date()

    private var currentCity: String? {
        store.currentCity
    }

    private struct ActiveStayInfo: Identifiable {
        let friend: FriendPresence
        let city: String
        let countryCode: String?
        let startDate: Date?
        let durationText: String
        let sinceText: String

        var id: UUID { friend.id }
    }

    private var activeStays: [ActiveStayInfo] {
        guard let myCity = currentCity, !myCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              store.snapshot.sharingPreferences.citySharingEnabled else {
            return []
        }

        let matchingFriends = store.friends.filter { friend in
            friend.sharingState == .active
                && store.preference(for: friend.id).sharesMyCity
                && PresenceMatchPolicy.matches(store.snapshot.currentPresence, friend, at: referenceDate)
        }

        let currentKey = CityIdentity.presenceKey(city: myCity, countryCode: store.snapshot.currentPresence.countryCode,
            administrativeArea: store.snapshot.currentPresence.administrativeArea)
        return matchingFriends.map { friend in
            let startDate = ColocationHistoryPolicy.currentStart(friendID: friend.id, cityKey: currentKey,
                sessions: store.snapshot.colocationSessions, at: referenceDate)
            let durationText = startDate.map { currentStayDuration(since: $0) }
                ?? String(localized: "Recent city match")
            let sinceText: String
            if let startDate {
                sinceText = String(format: String(localized: "Since %@"),
                    startDate.formatted(date: .abbreviated, time: .omitted))
            } else {
                // Updates establish a recent match, not when a stay began.
                let observation = ([store.snapshot.currentPresence.updatedAt, friend.updatedAt]
                    .compactMap { $0 } + [referenceDate]).min() ?? referenceDate
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .full
                sinceText = String(localized: "Updated \(formatter.localizedString(for: observation, relativeTo: referenceDate))")
            }

            return ActiveStayInfo(
                friend: friend,
                city: myCity,
                countryCode: store.snapshot.currentPresence.countryCode,
                startDate: startDate,
                durationText: durationText,
                sinceText: sinceText
            )
        }
    }

    /// Past completed events, excluding events belonging to the current active stay
    private var pastEvents: [ColocationEvent] {
        let starts = Dictionary(uniqueKeysWithValues: activeStays.compactMap { stay in
            stay.startDate.map { (stay.friend.id, $0) }
        })
        return ColocationHistoryPolicy.pastEvents(store.snapshot.colocationEvents,
            currentCityKey: CityIdentity.presenceKey(city: currentCity,
                countryCode: store.snapshot.currentPresence.countryCode,
                administrativeArea: store.snapshot.currentPresence.administrativeArea),
            currentStarts: starts, at: referenceDate)
    }

    private func currentStayDuration(since start: Date) -> String {
        let interval = max(0, referenceDate.timeIntervalSince(start))
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        var calendar = Calendar.current
        calendar.locale = .current
        formatter.calendar = calendar
        let components: DateComponents
        if interval >= 86400 {
            formatter.allowedUnits = [.day]
            components = DateComponents(day: Int(interval / 86400))
        } else if interval >= 3600 {
            formatter.allowedUnits = [.hour]
            components = DateComponents(hour: Int(interval / 3600))
        } else {
            formatter.allowedUnits = [.minute]
            components = DateComponents(minute: max(1, Int(interval / 60)))
        }
        guard let duration = formatter.string(from: components) else { return String(localized: "Recent city match") }
        return String(localized: "Same city for \(duration)")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if activeStays.isEmpty && pastEvents.isEmpty {
                    emptyState
                } else {
                    if !activeStays.isEmpty {
                        activeSection
                    }

                    if !pastEvents.isEmpty {
                        historySection
                    }
                }
            }
            .padding(WIFTheme.screenInset)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Same-city moments")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("notificationHistoryScreen")
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { referenceDate = Date() }
        }
        .task {
            referenceDate = Date()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                if scenePhase == .active { referenceDate = Date() }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No same-city moments yet", systemImage: "sparkles")
        } description: {
            Text("When you and a friend are in the same city, your moments together will appear here.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .wifGlassSurface(
            tint: WIFTheme.surface.opacity(0.10),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(WIFTheme.fresh)
                    .frame(width: 8, height: 8)
                Text("Active now")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(WIFTheme.fresh)
            }
            .padding(.leading, 4)

            ForEach(activeStays) { stay in
                activeMomentCard(stay: stay)
            }
        }
    }

    private func activeMomentCard(stay: ActiveStayInfo) -> some View {
        HStack(spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
            ZStack(alignment: .bottomTrailing) {
                CityEmblemView(
                    city: stay.city,
                    countryCode: stay.countryCode,
                    size: 58
                )

                FriendAvatarView(friend: stay.friend, size: 28)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 4, y: 4)
            }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Together in \(stay.city)")
                    .accessibilityIdentifier("activeStayCity-\(stay.id)")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("You and \(stay.friend.displayName)")
                    .accessibilityIdentifier("activeStayFriend-\(stay.id)")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stay.durationText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WIFTheme.fresh)
                        .accessibilityIdentifier("sameCityDuration-\(stay.id)")

                    Text(stay.sinceText)
                        .font(.caption)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .wifSettingsGlassCard(tint: WIFTheme.fresh.opacity(0.14))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Past moments")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(WIFTheme.secondaryText)
                .padding(.leading, 4)
                .padding(.top, activeStays.isEmpty ? 0 : 8)

            VStack(spacing: 10) {
                ForEach(pastEvents) { event in
                    historyMomentCard(event: event)
                }
            }
        }
    }

    private func historyMomentCard(event: ColocationEvent) -> some View {
        HStack(spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
            CityEmblemView(
                city: event.city,
                countryCode: nil,
                size: 44
            )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text("You and \(event.friendNames.formatted(.list(type: .and)))")
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText.opacity(0.8))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .wifSettingsGlassCard(tint: WIFTheme.surface.opacity(0.08))
        .accessibilityIdentifier("pastMoment-\(event.id)")
    }
}

#Preview {
    NavigationStack {
        NotificationHistoryView()
    }
    .environmentObject(AppStore())
}

// MARK: - Option B mock (by friend). Static data; launched with -previewMomentsByFriend.

struct MomentsMockTrip: Identifiable, Hashable {
    let id = UUID()
    let cities: [(name: String, country: String, region: String)]
    let dates: String
    let days: Int
    var isNow = false

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct MomentsMockFriend: Identifiable, Hashable {
    let id: String
    let name: String
    let initials: String
    let trips: [MomentsMockTrip]
    var lastTogether = ""

    var days: Int { trips.map(\.days).reduce(0, +) }
    var isNow: Bool { trips.first?.isNow == true }
    var cityCounts: [(name: String, country: String, region: String, count: Int)] {
        var order: [String] = []
        var found: [String: (String, String, String, Int)] = [:]
        for city in trips.flatMap(\.cities) {
            if let hit = found[city.name] { found[city.name] = (hit.0, hit.1, hit.2, hit.3 + 1) }
            else { order.append(city.name); found[city.name] = (city.name, city.country, city.region, 1) }
        }
        return order.compactMap { found[$0] }.map { (name: $0.0, country: $0.1, region: $0.2, count: $0.3) }
    }

    static let all: [MomentsMockFriend] = [
        MomentsMockFriend(id: "mia", name: "Mia Chen", initials: "MC", trips: [
            MomentsMockTrip(cities: [("Boston", "US", "MA")], dates: "Since Oct 16", days: 3, isNow: true),
            MomentsMockTrip(cities: [("New York", "US", "NY")], dates: "Sep 2 – 3", days: 2),
            MomentsMockTrip(cities: [("Boston", "US", "MA")], dates: "Jun 8", days: 1)
        ]),
        MomentsMockFriend(id: "owen", name: "Owen Park", initials: "OP", trips: [
            MomentsMockTrip(cities: [("Tokyo", "JP", "Tokyo")], dates: "Sep 12 – 16", days: 5),
            MomentsMockTrip(cities: [("Los Angeles", "US", "CA"), ("Santa Barbara", "US", "CA"),
                                     ("San Francisco", "US", "CA")], dates: "Aug 14 – 17", days: 4)
        ], lastTogether: "Sep 16"),
        MomentsMockFriend(id: "zoe", name: "Zoe Liang", initials: "ZL", trips: [
            MomentsMockTrip(cities: [("Shanghai", "CN", "Shanghai")], dates: "Jul 20", days: 1)
        ], lastTogether: "Jul 20")
    ]
}

private struct MomentsMockAvatar: View {
    let friend: MomentsMockFriend
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(WIFPersonPalette.fill(for: friend.name).gradient)
            .frame(width: size, height: size)
            .overlay {
                Text(friend.initials)
                    .font(.system(size: size * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
    }
}

struct MomentsByFriendMockView: View {
    private let friends = MomentsMockFriend.all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("16 days together")
                        .font(.system(size: 34, weight: .semibold))
                        .tracking(-0.8)
                        .foregroundStyle(WIFTheme.primaryText)
                    Text("With 3 friends in 7 cities this year")
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 10)

                ForEach(friends) { friend in
                    NavigationLink(value: friend) { card(friend) }
                        .buttonStyle(.plain)
                }
            }
            .padding(WIFTheme.screenInset)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Same-city moments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func card(_ friend: MomentsMockFriend) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                MomentsMockAvatar(friend: friend, size: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(friend.name)
                        .font(.headline)
                        .foregroundStyle(WIFTheme.primaryText)
                    if friend.isNow, let city = friend.trips.first?.cities.first?.name {
                        HStack(spacing: 6) {
                            Circle().fill(WIFTheme.fresh).frame(width: 7, height: 7)
                            Text("In \(city) with you now")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(WIFTheme.fresh)
                    } else {
                        Text("Last together \(friend.lastTogether)")
                            .font(.subheadline)
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(friend.days)")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)
                    Text(friend.days == 1 ? "day" : "days")
                        .font(.caption)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: -10) {
                    ForEach(Array(friend.cityCounts.prefix(4).enumerated()), id: \.offset) { _, city in
                        CityEmblemView(city: city.name, countryCode: city.country, administrativeArea: city.region, size: 38)
                    }
                }
                Text(friend.cityCounts.count > 2 ? "\(friend.cityCounts.count) cities"
                     : friend.cityCounts.map { $0.count > 1 ? "\($0.name) ×\($0.count)" : $0.name }
                    .formatted(.list(type: .and)))
                    .font(.footnote)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }
            .padding(.leading, 2)
        }
        .wifSettingsGlassCard(tint: friend.isNow ? WIFTheme.fresh.opacity(0.10) : WIFTheme.surface.opacity(0.08))
    }
}

struct MomentsFriendMockDetailView: View {
    let friend: MomentsMockFriend

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    MomentsMockAvatar(friend: friend, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.name)
                            .font(.system(size: 28, weight: .semibold))
                            .tracking(-0.6)
                            .foregroundStyle(WIFTheme.primaryText)
                        Text("\(friend.days) days together in \(friend.cityCounts.count) cities")
                            .font(.subheadline)
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 10)

                VStack(spacing: 0) {
                    ForEach(Array(friend.trips.enumerated()), id: \.element.id) { index, trip in
                        if index > 0 { Divider().overlay(WIFTheme.border).padding(.leading, 74) }
                        row(trip)
                    }
                }
                .wifSettingsGlassCard()
            }
            .padding(WIFTheme.screenInset)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Same-city moments")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ trip: MomentsMockTrip) -> some View {
        HStack(spacing: 14) {
            ZStack {
                ForEach(Array(trip.cities.prefix(3).enumerated().reversed()), id: \.offset) { index, city in
                    CityEmblemView(city: city.name, countryCode: city.country, administrativeArea: city.region,
                                   size: trip.cities.count > 1 ? 40 : 58)
                        .offset(x: trip.cities.count > 1 ? CGFloat(index) * 9 - 9 : 0,
                                y: trip.cities.count > 1 ? CGFloat(index) * -6 + 6 : 0)
                }
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 3) {
                Text(trip.cities.count > 1
                     ? "\(trip.cities.first!.name) to \(trip.cities.last!.name)"
                     : trip.cities[0].name)
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if trip.cities.count > 1 {
                    Text("Road trip · via \(trip.cities.dropFirst().dropLast().map(\.name).formatted(.list(type: .and)))")
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                Text(trip.dates)
                    .font(.subheadline)
                    .foregroundStyle(trip.isNow ? WIFTheme.fresh : WIFTheme.secondaryText)
            }
            Spacer(minLength: 8)
            Text(trip.days == 1 ? "1 day" : "\(trip.days) days")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WIFTheme.fresh)
        }
        .padding(.vertical, 10)
    }
}

struct MomentsMockRoot: View {
    @State private var path: [MomentsMockFriend] = {
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-previewMomentsFriend=") }),
              let friend = MomentsMockFriend.all.first(where: { $0.id == argument.split(separator: "=").last.map(String.init) })
        else { return [] }
        return [friend]
    }()

    var body: some View {
        NavigationStack(path: $path) {
            MomentsByFriendMockView()
                .navigationDestination(for: MomentsMockFriend.self) { MomentsFriendMockDetailView(friend: $0) }
        }
    }
}
