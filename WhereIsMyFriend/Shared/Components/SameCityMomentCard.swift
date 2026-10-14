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

    var body: some View {
        Group {
        if expansionContext.isVisible {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(motion) { expansion.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        if !typeSize.isAccessibilitySize {
                            if people.isEmpty {
                                Image(systemName: "clock").frame(width: 26, height: 26)
                                    .accessibilityHidden(true)
                            } else {
                                HStack(spacing: -7) {
                                    ForEach(Array(people.prefix(3))) { friend in
                                        avatar(friend, size: 26)
                                            .overlay(Circle().stroke(WIFTheme.canvas, lineWidth: 2))
                                    }
                                }.accessibilityHidden(true)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(summaryTitle)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(WIFTheme.fresh)
                                .accessibilityIdentifier("sameCitySummaryTitle")
                            Text(summaryDetail)
                                .font(.caption)
                                .foregroundStyle(WIFTheme.secondaryText)
                                .accessibilityIdentifier("sameCitySummaryFreshness")
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(WIFTheme.fresh)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: expanded)
                .accessibilityIdentifier("sameCityReunionToggle")
                .accessibilityValue(expanded ? Text("Expanded") : Text("Collapsed"))

                if expanded {
                    VStack(alignment: .leading, spacing: 0) {
                        if people.isEmpty {
                            Text("The moment may have expired or sharing may have changed.")
                                .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true).padding(.vertical, 12)
                        } else {
                            ForEach(people) { friend in
                                NavigationLink(value: friend) {
                                    HStack(spacing: 12) {
                                        if !typeSize.isAccessibilitySize { avatar(friend, size: 34) }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(friend.displayName).font(.subheadline.weight(.medium))
                                                .foregroundStyle(WIFTheme.primaryText)
                                            Text(isCurrent ? friend.relativeUpdateLongText(at: referenceDate) : String(localized: "Past city update"))
                                                .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                                        }.fixedSize(horizontal: false, vertical: true)
                                        Spacer(minLength: 4)
                                        Image(systemName: "chevron.right").font(.caption)
                                            .foregroundStyle(WIFTheme.secondaryText).accessibilityHidden(true)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                    .padding(.vertical, 4).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("sameCityFriend-\(friend.username)")
                            }
                        }
                        Button {
                            withAnimation(motion) { expansion.collapse(); eventID = nil }
                        } label: {
                            Text("Collapse").font(.caption)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).foregroundStyle(WIFTheme.secondaryText)
                        .accessibilityIdentifier("closeSameCityReunion")
                    }
                    .padding(.top, 4)
                    .transition(.opacity)
                }
                Divider().overlay(WIFTheme.border.opacity(0.35)).padding(.top, 12)
            }
            // Event selection is only content: it must never reopen this summary.
            .animation(motion, value: expanded)
            .padding(.top, 10)
        }
        }
        // Keep this observer outside the conditional content so hiding the
        // summary also retires its expansion before it becomes visible again.
        .onChange(of: expansionContext, initial: true) { _, context in
            expansion.reconcile(context)
        }
    }

    private func avatar(_ friend: FriendPresence, size: CGFloat) -> some View {
        let tint = WIFPersonPalette.tint(for: friend.displayName)
        return Text(friend.initials)
            .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
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
