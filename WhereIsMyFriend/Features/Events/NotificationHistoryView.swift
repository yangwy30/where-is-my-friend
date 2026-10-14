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
