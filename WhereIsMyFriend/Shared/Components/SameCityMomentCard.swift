import SwiftUI

struct SameCityAlertBanner: View {
    @EnvironmentObject private var store: AppStore
    let event: ColocationEvent

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Button { store.openSameCityEvent(event.id) } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.badge")
                        Text("Same-city alert").textCase(.uppercase).tracking(0.8)
                        Spacer()
                        Text(event.createdAt, style: .relative)
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WIFTheme.secondaryText)
                    Text(store.snapshot.sharingPreferences.notificationPreviewEnabled
                         ? "A familiar face in \(event.city)." : "A same-city update")
                        .font(.headline)
                        .foregroundStyle(WIFTheme.primaryText)
                    Text(store.snapshot.sharingPreferences.notificationPreviewEnabled
                         ? "\(event.friendNames.joined(separator: ", ")) is in town too."
                         : "Open Across Us to see the update.")
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sameCityAlertBanner")
            Button { store.dismissSameCityBanner() } label: {
                Image(systemName: "xmark").font(.caption.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .foregroundStyle(WIFTheme.secondaryText)
            .accessibilityLabel("Dismiss same-city alert")
        }
        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 25))
        .shadow(color: WIFTheme.primaryText.opacity(0.12), radius: 18, y: 7)
        .padding(.horizontal, WIFTheme.screenInset)
        .padding(.top, 8)
    }
}

/// Re-resolves its content from the current snapshot: a revoked share or old
/// notification must not keep an obsolete "here together" claim on screen.
struct SameCityReunionCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let referenceDate: Date
    @Binding var eventID: UUID?
    @State private var expanded = false
    @State private var selectedFriendID: UUID?

    private var currentFriends: [FriendPresence] {
        SameCityAlertPolicy.currentFriends(in: store.snapshot, at: referenceDate)
    }
    private var event: ColocationEvent? {
        eventID.flatMap { SameCityAlertPolicy.event($0, in: store.snapshot) }
    }
    private var people: [FriendPresence] {
        if let event {
            return store.friends.filter { event.friendIDs.contains($0.id) }
        }
        return eventID == nil ? currentFriends : []
    }
    private var isCurrent: Bool {
        if let event { return SameCityAlertPolicy.isCurrent(event, in: store.snapshot, at: referenceDate) }
        return eventID == nil && !currentFriends.isEmpty
    }
    private var city: String { event?.city ?? store.currentCity ?? "" }
    private var selectedFriend: FriendPresence? {
        people.first { $0.id == selectedFriendID } ?? (people.count == 1 ? people.first : nil)
    }
    private var motion: Animation? { reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.82) }

    var body: some View {
        if !currentFriends.isEmpty || eventID != nil {
            VStack(spacing: 0) {
                Button {
                    withAnimation(motion) { expanded.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isCurrent ? "person.2" : "clock")
                            .font(.body.weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .foregroundStyle(WIFTheme.fresh)
                            .frame(width: 40, height: 40)
                            .background(WIFTheme.fresh.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(isCurrent ? "Here together" : "Same-city moment")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(WIFTheme.primaryText)
                            Text(people.isEmpty ? "This update is no longer available"
                                 : people.map(\.displayName).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(WIFTheme.secondaryText)
                                .lineLimit(expanded ? nil : 2)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sameCityReunionToggle")
                .accessibilityValue(expanded ? "Expanded" : "Collapsed")

                if expanded {
                    VStack(spacing: 16) {
                        if people.isEmpty {
                            Text("The moment may have expired or sharing may have changed.")
                                .font(.subheadline)
                                .foregroundStyle(WIFTheme.secondaryText)
                                .multilineTextAlignment(.center)
                        } else if let friend = selectedFriend {
                            reunionDetail(friend)
                        } else {
                            ForEach(people) { friend in
                                Button {
                                    withAnimation(motion) { selectedFriendID = friend.id }
                                } label: {
                                    HStack(spacing: 12) {
                                        FriendAvatarView(friend: friend, size: 38)
                                        Text(friend.displayName).font(.subheadline.weight(.medium))
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.caption)
                                    }
                                    .foregroundStyle(WIFTheme.primaryText)
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Button("Back to Friends") {
                            withAnimation(motion) {
                                expanded = false
                                eventID = nil
                                selectedFriendID = nil
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("closeSameCityReunion")
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                }
            }
            .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
            .clipped()
            .onChange(of: eventID, initial: true) { _, id in
                if id != nil { expanded = true; selectedFriendID = nil }
            }
            .animation(motion, value: expanded)
            .padding(.top, 14)
        }
    }

    private func reunionDetail(_ friend: FriendPresence) -> some View {
        VStack(spacing: 14) {
            if people.count > 1 {
                Button {
                    withAnimation(motion) { selectedFriendID = nil }
                } label: { Label("Everyone here", systemImage: "chevron.left") }
                    .font(.caption)
                    .foregroundStyle(WIFTheme.fresh)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            HStack(alignment: .center, spacing: typeSize.isAccessibilitySize ? 8 : 20) {
                VStack(spacing: 6) {
                    Text(store.snapshot.currentUser.initials)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WIFTheme.surface)
                        .frame(width: 38, height: 38)
                        .background(WIFTheme.fresh, in: Circle())
                    Text("You").font(.caption).foregroundStyle(WIFTheme.secondaryText)
                }
                CityEmblemView(city: city, countryCode: isCurrent ? store.snapshot.currentPresence.countryCode : nil,
                               administrativeArea: isCurrent ? store.snapshot.currentPresence.administrativeArea : nil,
                               size: typeSize.isAccessibilitySize ? 82 : 122)
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    FriendAvatarView(friend: friend, size: 38)
                    Text(friend.displayName.components(separatedBy: " ").first ?? friend.displayName)
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            Text(isCurrent ? "Same city. Good company." : "A moment you shared.")
                .font(.title2.weight(.semibold))
                .tracking(-0.5)
                .foregroundStyle(WIFTheme.primaryText)
                .multilineTextAlignment(.center)
            Text("You + \(friend.displayName) · \(city)")
                .font(.subheadline)
                .foregroundStyle(WIFTheme.fresh)
                .multilineTextAlignment(.center)
            if isCurrent {
                Text(friend.relativeUpdateLongText(at: referenceDate))
                    .font(.caption2).foregroundStyle(WIFTheme.secondaryText)
                ShareLink(item: "We’re both in \(city)! Want to catch up?") {
                    Label("Say hello", systemImage: "bubble.left")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(WIFTheme.canvas)
                        .background(WIFTheme.fresh, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Choose who to message.")
                .accessibilityIdentifier("sameCitySayHello")
            } else if let event {
                Text(event.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                Text("Past city update")
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct SameCityMomentCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let friends: [FriendPresence]
    let city: String
    let referenceDate: Date

    private var names: String {
        friends.prefix(3).map(\.displayName).joined(separator: ", ")
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    cityMarker
                    description
                }
            } else {
                HStack(spacing: 14) {
                    cityMarker
                    description
                    Spacer(minLength: 0)
                    CityEmblemView(city: city, size: 48)
                }
            }
        }
        .padding(16)
        .wifContentSurface(
            tint: WIFTheme.fresh.opacity(0.18),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var cityMarker: some View {
        Image(systemName: "location.fill")
            .font(.headline)
            .foregroundStyle(WIFTheme.fresh)
            .frame(width: 42, height: 42)
            .background(WIFTheme.fresh.opacity(0.13), in: Circle())
            .accessibilityHidden(true)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Together in \(city)")
                .font(.headline)
                .foregroundStyle(WIFTheme.primaryText)

            Text("You and \(names)")
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
        }
    }
}
