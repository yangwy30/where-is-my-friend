import SwiftUI

/// Same-city history, one card per friend. Trips live one level down so the list
/// reads as who you've shared cities with, not a log of every match.
struct NotificationHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var referenceDate = Date()

    private var summary: SameCityMomentsPolicy.Summary {
        SameCityMomentsPolicy.summary(in: store.snapshot, at: referenceDate)
    }

    var body: some View {
        let summary = summary
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if summary.friends.isEmpty {
                    emptyState
                } else {
                    header(summary)
                    ForEach(summary.friends) { history in
                        NavigationLink {
                            SameCityFriendHistoryView(friendID: history.id)
                        } label: {
                            SameCityFriendCard(history: history, referenceDate: referenceDate)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("momentsFriend-\(history.id)")
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
        .sameCityClock($referenceDate, scenePhase: scenePhase)
    }

    private func header(_ summary: SameCityMomentsPolicy.Summary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(SameCityMomentsText.daysTogether(summary.days))
                .font(.system(size: 34, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(WIFTheme.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("momentsTotalDays")
            Text(SameCityMomentsText.friendsAndCities(friends: summary.friends.count, cities: summary.cityCount))
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
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
}

private struct SameCityFriendCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let history: SameCityMomentsPolicy.FriendHistory
    let referenceDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                if !dynamicTypeSize.isAccessibilitySize { FriendAvatarView(friend: history.friend, size: 48) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(history.friend.displayName)
                        .font(.headline)
                        .foregroundStyle(WIFTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("momentsFriendName-\(history.id)")
                    SameCityFriendStatus(history: history, referenceDate: referenceDate)
                }
                Spacer(minLength: 8)
                if !history.days.isEmpty {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(history.days.count, format: .number)
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(WIFTheme.primaryText)
                        Text(SameCityMomentsText.dayUnit(history.days.count))
                            .font(.caption)
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("momentsDays-\(history.id)")
                }
            }

            let cities = history.cities
            if !cities.isEmpty {
                HStack(spacing: 10) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        HStack(spacing: -10) {
                            ForEach(cities.prefix(4), id: \.stop.cityKey) { city in
                                CityEmblemView(city: city.stop.name, countryCode: city.stop.countryCode,
                                               administrativeArea: city.stop.region, size: 38)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                    Text(SameCityMomentsText.cityList(cities))
                        .font(.footnote)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 2)
            }
        }
        .wifSettingsGlassCard(tint: history.isHereNow ? WIFTheme.fresh.opacity(0.10) : WIFTheme.surface.opacity(0.08))
        .contentShape(RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous))
    }
}

private struct SameCityFriendStatus: View {
    let history: SameCityMomentsPolicy.FriendHistory
    let referenceDate: Date

    var body: some View {
        Group {
            if history.isHereNow {
                HStack(spacing: 6) {
                    Circle().fill(WIFTheme.fresh).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(history.currentCity.map { String(localized: "In \($0) with you now") }
                         ?? String(localized: "Here with you"))
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(WIFTheme.fresh)
            } else if let last = history.lastTogether {
                Text(String(localized: "Last together \(SameCityMomentsText.day(last, relativeTo: referenceDate))"))
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("momentsStatus-\(history.id)")
    }
}

/// Every trip with one friend, newest first. Re-reads the store so a removed or
/// blocked friend drops out instead of leaving stale history on screen.
struct SameCityFriendHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let friendID: UUID
    @State private var referenceDate = Date()

    private var history: SameCityMomentsPolicy.FriendHistory? {
        SameCityMomentsPolicy.summary(in: store.snapshot, at: referenceDate).friends.first { $0.id == friendID }
    }

    var body: some View {
        ScrollView {
            if let history {
                VStack(alignment: .leading, spacing: 14) {
                    header(history)
                    if !history.trips.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(history.trips.enumerated()), id: \.element.id) { index, trip in
                                if index > 0 { Divider().overlay(WIFTheme.border).padding(.leading, 74) }
                                row(trip)
                            }
                        }
                        .wifSettingsGlassCard()
                    }
                }
                .padding(WIFTheme.screenInset)
            }
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Same-city moments")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("friendMomentsScreen")
        .sameCityClock($referenceDate, scenePhase: scenePhase)
    }

    private func header(_ history: SameCityMomentsPolicy.FriendHistory) -> some View {
        HStack(spacing: 16) {
            if !dynamicTypeSize.isAccessibilitySize { FriendAvatarView(friend: history.friend, size: 64) }
            VStack(alignment: .leading, spacing: 4) {
                Text(history.friend.displayName)
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(WIFTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if history.isHereNow || !history.days.isEmpty {
                    Text(SameCityMomentsText.friendDetail(history))
                        .font(.subheadline)
                        .foregroundStyle(history.isHereNow && history.trips.isEmpty ? WIFTheme.fresh : WIFTheme.secondaryText)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }

    private func row(_ trip: SameCityMomentsPolicy.Trip) -> some View {
        HStack(spacing: 14) {
            if !dynamicTypeSize.isAccessibilitySize {
                ZStack {
                    let stops = Array(trip.stops.prefix(3))
                    ForEach(Array(stops.enumerated().reversed()), id: \.element.cityKey) { index, stop in
                        CityEmblemView(city: stop.name, countryCode: stop.countryCode, administrativeArea: stop.region,
                                       size: stops.count > 1 ? 40 : 58)
                            .offset(x: stops.count > 1 ? CGFloat(index) * 9 - 9 : 0,
                                    y: stops.count > 1 ? CGFloat(index) * -6 + 6 : 0)
                    }
                }
                .frame(width: 60, height: 60)
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(SameCityMomentsText.route(trip))
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if trip.stops.count > 2 {
                    Text(String(localized: "Via \(trip.stops.dropFirst().dropLast().map(\.name).formatted(.list(type: .and)))"))
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(SameCityMomentsText.dates(trip, relativeTo: referenceDate))
                    .font(.subheadline)
                    .foregroundStyle(trip.isActive ? WIFTheme.fresh : WIFTheme.secondaryText)
            }
            Spacer(minLength: 8)
            Text(SameCityMomentsText.dayCount(trip.days.count))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WIFTheme.fresh)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("momentsTrip-\(trip.id)")
    }
}

enum SameCityMomentsText {
    static func daysTogether(_ days: Int) -> String {
        days == 1 ? String(localized: "1 day together") : String(localized: "\(days) days together")
    }

    static func dayUnit(_ days: Int) -> String {
        days == 1 ? String(localized: "day") : String(localized: "days")
    }

    static func dayCount(_ days: Int) -> String {
        days == 1 ? String(localized: "1 day") : String(localized: "\(days) days")
    }

    static func cityCount(_ cities: Int) -> String {
        cities == 1 ? String(localized: "1 city") : String(localized: "\(cities) cities")
    }

    static func friendsAndCities(friends: Int, cities: Int) -> String {
        let people = friends == 1 ? String(localized: "1 friend") : String(localized: "\(friends) friends")
        return String(localized: "With \(people) in \(cityCount(cities))")
    }

    static func friendDetail(_ history: SameCityMomentsPolicy.FriendHistory) -> String {
        guard !history.days.isEmpty else { return String(localized: "Here with you") }
        return "\(daysTogether(history.days.count)) · \(cityCount(history.cities.count))"
    }

    static func cityList(_ cities: [(stop: SameCityMomentsPolicy.Stop, trips: Int)]) -> String {
        guard cities.count <= 2 else { return cityCount(cities.count) }
        return cities.map { $0.trips > 1 ? "\($0.stop.name) ×\($0.trips)" : $0.stop.name }.formatted(.list(type: .and))
    }

    static func route(_ trip: SameCityMomentsPolicy.Trip) -> String {
        guard let first = trip.stops.first, let last = trip.stops.last, trip.stops.count > 1 else {
            return trip.stops.first?.name ?? ""
        }
        return String(localized: "\(first.name) to \(last.name)")
    }

    static func day(_ date: Date, relativeTo now: Date) -> String {
        let sameYear = Calendar.current.isDate(date, equalTo: now, toGranularity: .year)
        return date.formatted(sameYear ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).day().year())
    }

    static func dates(_ trip: SameCityMomentsPolicy.Trip, relativeTo now: Date) -> String {
        if trip.isActive { return String(format: String(localized: "Since %@"), day(trip.start, relativeTo: now)) }
        if Calendar.current.isDate(trip.start, inSameDayAs: trip.end) { return day(trip.start, relativeTo: now) }
        let sameYear = Calendar.current.isDate(trip.start, equalTo: now, toGranularity: .year)
        let style: Date.IntervalFormatStyle = sameYear ? .interval.month(.abbreviated).day() : .interval.month(.abbreviated).day().year()
        return (trip.start..<trip.end).formatted(style)
    }
}

private extension View {
    /// Keeps "now" honest while the screen stays open: an ongoing stay grows, an ended one moves to history.
    func sameCityClock(_ referenceDate: Binding<Date>, scenePhase: ScenePhase) -> some View {
        onChange(of: scenePhase) { _, phase in
            if phase == .active { referenceDate.wrappedValue = Date() }
        }
        .task {
            referenceDate.wrappedValue = Date()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                if scenePhase == .active { referenceDate.wrappedValue = Date() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationHistoryView()
    }
    .environmentObject(AppStore())
}
