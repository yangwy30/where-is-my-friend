import SwiftUI

struct NotificationHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var referenceDate = Date()

    private var currentCity: String? {
        store.currentCity
    }

    private struct ActiveStayInfo: Identifiable {
        let friend: FriendPresence
        let city: String
        let countryCode: String?
        let startDate: Date
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
                && CityIdentity.matches(
                    city: friend.city,
                    countryCode: friend.countryCode,
                    otherCity: myCity,
                    otherCountryCode: store.snapshot.currentPresence.countryCode
                )
        }

        return matchingFriends.map { friend in
            let session = store.snapshot.colocationSessions.first {
                $0.friendID == friend.id && $0.isActive
            }

            let matchingEvents = store.snapshot.colocationEvents.filter { event in
                event.friendIDs.contains(friend.id)
                    && CityIdentity.matches(
                        city: event.city,
                        countryCode: nil,
                        otherCity: myCity,
                        otherCountryCode: store.snapshot.currentPresence.countryCode
                    )
            }

            let candidateDates = [session?.enteredAt].compactMap { $0 } + matchingEvents.map(\.createdAt)
            let startDate = candidateDates.min() ?? friend.updatedAt ?? referenceDate

            let interval = max(0, referenceDate.timeIntervalSince(startDate))
            let days = Int(interval / (24 * 60 * 60))
            let hours = Int(interval / (60 * 60))

            let durationText: String
            if days >= 1 {
                durationText = String(format: String(localized: "Together for %lld days"), Int64(days))
            } else if hours >= 1 {
                durationText = String(format: String(localized: "Together for %lld hours"), Int64(hours))
            } else {
                let minutes = max(1, Int(interval / 60))
                durationText = String(format: String(localized: "Together for %lldm"), Int64(minutes))
            }

            let sinceText = String(
                format: String(localized: "Since %@"),
                startDate.formatted(date: .abbreviated, time: .omitted)
            )

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
        let activeFriendIDs = Set(activeStays.map(\.friend.id))
        let sorted = store.snapshot.colocationEvents.sorted(by: { $0.createdAt > $1.createdAt })

        let filtered = sorted.filter { event in
            if let myCity = currentCity,
               CityIdentity.matches(
                   city: event.city,
                   countryCode: nil,
                   otherCity: myCity,
                   otherCountryCode: store.snapshot.currentPresence.countryCode
               ),
               event.friendIDs.contains(where: { activeFriendIDs.contains($0) }) {
                // Belong to current active stay; exclude from past moments
                return false
            }
            return true
        }

        var uniqueMoments: [ColocationEvent] = []
        for event in filtered {
            let isDuplicate = uniqueMoments.contains { existing in
                existing.city.lowercased() == event.city.lowercased()
                    && Set(existing.friendIDs) == Set(event.friendIDs)
                    && abs(existing.createdAt.timeIntervalSince(event.createdAt)) < 24 * 60 * 60
            }
            if !isDuplicate {
                uniqueMoments.append(event)
            }
        }
        return uniqueMoments
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

            VStack(alignment: .leading, spacing: 4) {
                Text("Together in \(stay.city)")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)

                Text("You and \(stay.friend.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(stay.durationText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WIFTheme.fresh)

                    Text("·")
                        .foregroundStyle(WIFTheme.secondaryText)

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
            CityEmblemView(
                city: event.city,
                countryCode: nil,
                size: 44
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)

                Text("You and \(event.friendNames.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)

                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText.opacity(0.8))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .wifSettingsGlassCard(tint: WIFTheme.surface.opacity(0.08))
    }
}

#Preview {
    NavigationStack {
        NotificationHistoryView()
    }
    .environmentObject(AppStore())
}
