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
struct SameCityExpansionContext: Equatable {
    let isVisible: Bool
    let cityIdentity: String

    init(isVisible: Bool, presence: CurrentUserPresence) {
        self.isVisible = isVisible
        cityIdentity = CityIdentity.presenceKey(city: presence.city, countryCode: presence.countryCode,
            administrativeArea: presence.administrativeArea)
            ?? [presence.city.map(CityIdentity.normalize) ?? "",
                presence.countryCode?.uppercased() ?? "",
                presence.administrativeArea.map(CityIdentity.presencePart) ?? ""].joined(separator: "|")
    }
}

struct SameCityExpansionState {
    private(set) var isExpanded = false
    private var context: SameCityExpansionContext?

    mutating func toggle() { isExpanded.toggle() }
    mutating func collapse() { isExpanded = false }
    mutating func reconcile(_ updated: SameCityExpansionContext) {
        if !updated.isVisible || context?.cityIdentity != updated.cityIdentity { collapse() }
        context = updated
    }
}

struct SameCityReunionCard: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let referenceDate: Date
    @Binding var eventID: UUID?
    @State private var expansion = SameCityExpansionState()

    private var expanded: Bool { expansion.isExpanded }
    private var expansionContext: SameCityExpansionContext {
        SameCityExpansionContext(isVisible: !currentFriends.isEmpty || eventID != nil, presence: store.snapshot.currentPresence)
    }

    private var currentFriends: [FriendPresence] {
        SameCityPresencePolicy.currentFriends(in: store.snapshot, at: referenceDate)
    }
    private var event: ColocationEvent? {
        eventID.flatMap { SameCityAlertPolicy.event($0, in: store.snapshot) }
    }
    private var people: [FriendPresence] {
        if let event { return store.friends.filter { event.friendIDs.contains($0.id) } }
        return eventID == nil ? currentFriends : []
    }
    private var isCurrent: Bool {
        if let event { return SameCityAlertPolicy.isCurrent(event, in: store.snapshot, at: referenceDate) }
        return eventID == nil && !currentFriends.isEmpty
    }
    private var motion: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.22) }
    private var summaryTitle: String {
        guard isCurrent, let friend = people.first else { return String(localized: "Same-city moment") }
        let name = friend.displayName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? friend.displayName
        if people.count == 1 { return String(localized: "\(name) is here too") }
        if people.count == 2 { return String(localized: "\(name) + 1 friend are here too") }
        return String(localized: "\(name) + \(people.count - 1) friends are here too")
    }
    private var summaryDetail: String {
        guard !people.isEmpty else { return String(localized: "This update is no longer available") }
        if isCurrent, let oldest = ([store.snapshot.currentPresence.updatedAt] + people.map(\.updatedAt)).compactMap({ $0 }).min() {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return String(localized: "City updates · \(formatter.localizedString(for: oldest, relativeTo: referenceDate))")
        }
        return event.map { "\($0.city) · \($0.createdAt.formatted(date: .abbreviated, time: .omitted))" }
            ?? String(localized: "This update is no longer available")
    }

    private var city: (name: String, countryCode: String?, region: String?) {
        if let event, !isCurrent { return (event.city, nil, nil) }
        let presence = store.snapshot.currentPresence
        return (presence.city ?? event?.city ?? "", presence.countryCode, presence.administrativeArea)
    }
    private var headline: String {
        guard isCurrent, let friend = people.first else { return String(localized: "Same-city moment") }
        let name = friend.displayName.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? friend.displayName
        if people.count == 1 { return String(localized: "\(name) is in \(city.name) too") }
        return String(localized: "\(name) + \(people.count - 1) more are in \(city.name) too")
    }
    private var freshness: String {
        if isCurrent, people.count == 1, let friend = people.first { return friend.relativeUpdateLongText(at: referenceDate) }
        return summaryDetail
    }

    var body: some View {
        Group {
        // A current same-city moment lives in the Friends header; this card only
        // explains a notification whose moment has since ended.
        if expansionContext.isVisible && !isCurrent {
            HStack(spacing: 14) {
                summary
                Button { eventID = nil } label: {
                    Image(systemName: "xmark").font(.caption.weight(.semibold)).frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).foregroundStyle(WIFTheme.secondaryText)
                .accessibilityLabel("Dismiss")
                .accessibilityIdentifier("closeSameCityReunion")
            }
            .padding(.leading, 14).padding(.trailing, 12).padding(.vertical, 12)
            .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous))
            .padding(.top, 14)
        }
        }
        .onChange(of: expansionContext, initial: true) { _, context in
            expansion.reconcile(context)
        }
    }

    /// The emblem says where; the avatar badge on its corner says who.
    private var summary: some View {
        HStack(spacing: 14) {
            if !typeSize.isAccessibilitySize {
                CityEmblemView(city: city.name, countryCode: city.countryCode, administrativeArea: city.region, size: 60)
                    .frame(width: 60, height: 60)
                    .overlay(alignment: .bottomTrailing) {
                        HStack(spacing: -8) {
                            ForEach(Array(people.prefix(2))) { friend in
                                avatar(friend, size: 26).overlay(Circle().stroke(WIFTheme.surface, lineWidth: 2))
                            }
                        }
                        .offset(x: 6, y: 4)
                    }
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                    .accessibilityIdentifier("sameCitySummaryTitle")
                Text(freshness)
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .accessibilityIdentifier("sameCitySummaryFreshness")
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func avatar(_ friend: FriendPresence, size: CGFloat) -> some View {
        let tint = WIFPersonPalette.tint(for: friend.displayName)
        return Text(friend.initials)
            .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
            .foregroundStyle(WIFTheme.primaryText)
            .frame(width: size, height: size)
            .background(tint, in: Circle())
            .accessibilityHidden(true)
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
