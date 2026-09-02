import SwiftUI

struct NotificationHistoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var referenceDate = Date()

    private var currentCity: String? {
        store.currentCity
    }

    private var activeSameCityFriends: [(friend: FriendPresence, session: ColocationSession?)] {
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
            return (friend, session)
        }
    }

    /// Intelligently coalesces consecutive duplicate events for the same friend & city
    private var pastEvents: [ColocationEvent] {
        let sorted = store.snapshot.colocationEvents.sorted(by: { $0.createdAt > $1.createdAt })
        var uniqueMoments: [ColocationEvent] = []

        for event in sorted {
            // Check if we already have an event for this exact city and friend group within 24 hours
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
                if activeSameCityFriends.isEmpty && pastEvents.isEmpty {
                    emptyState
                } else {
                    if !activeSameCityFriends.isEmpty {
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

            ForEach(activeSameCityFriends, id: \.friend.id) { item in
                activeMomentCard(friend: item.friend, session: item.session)
            }
        }
    }

    private func activeMomentCard(friend: FriendPresence, session: ColocationSession?) -> some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                CityEmblemView(
                    city: currentCity,
                    countryCode: store.snapshot.currentPresence.countryCode,
                    size: 58
                )

                FriendAvatarView(friend: friend, size: 28)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Together in \(currentCity ?? "")")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)

                Text("You and \(friend.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)

                if let enteredAt = session?.enteredAt {
                    Text("Since \(enteredAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WIFTheme.fresh)
                } else {
                    Text("In the same city")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WIFTheme.fresh)
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
                .padding(.top, activeSameCityFriends.isEmpty ? 0 : 8)

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
