import CoreLocation
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var appearanceController: WIFAppearanceController
    @EnvironmentObject private var travelPlans: TravelPlanLibrary
    let onReplayOnboarding: () -> Void
    let onOpenCitySharing: () -> Void
    @State private var showsSignOutConfirmation = false
    @State private var profileDraft: ProfileEditorDraft?
    @State private var showsAppearanceSettings = false
    @State private var isShowingOnboarding = false

    init(
        onReplayOnboarding: @escaping () -> Void,
        onOpenCitySharing: @escaping () -> Void = {}
    ) {
        self.onReplayOnboarding = onReplayOnboarding
        self.onOpenCitySharing = onOpenCitySharing
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                profileHeader

                SetupChecklistCard(notificationService: store.notificationService)

                ProfileSettingsGroup {
                    Button(action: onOpenCitySharing) {
                        ProfileSettingsRow("City sharing", symbol: "location.fill", value: citySharingValue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profileCitySharingButton")

                    ProfileSettingsDivider()

                    NavigationLink { TravelPlansView() } label: {
                        ProfileSettingsRow("My travel plans", symbol: "calendar", value: countValue(upcomingPlanCount))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("travelPlansLink")

                    ProfileSettingsDivider()

                    NavigationLink {
                        NotificationHistoryView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        ProfileSettingsRow("Same-city moments", symbol: "clock.arrow.circlepath",
                                           value: countValue(store.snapshot.colocationEvents.count))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("sameCityMomentsLink")
                }
                .padding(.top, 28)

                ProfileSettingsGroup {
                    NavigationLink {
                        NotificationSettingsView(notificationService: store.notificationService)
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        ProfileSettingsRow("Notifications", symbol: "bell")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("notificationSettingsLink")

                    ProfileSettingsDivider()

                    NavigationLink {
                        WidgetPrivacyView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        ProfileSettingsRow("Widgets", symbol: "rectangle.3.group")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("widgetPrivacySettingsLink")

                    ProfileSettingsDivider()

                    Button {
                        showsAppearanceSettings = true
                    } label: {
                        ProfileSettingsRow("Appearance", symbol: "circle.lefthalf.filled", value: Text(appearance.title))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("appearanceSettingsButton")
                }
                .padding(.top, 20)

                ProfileSettingsGroup {
                    NavigationLink {
                        PrivacySettingsView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        ProfileSettingsRow("Privacy", symbol: "hand.raised")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("privacySettingsLink")
                }
                .padding(.top, 20)

                if store.repositoryMode == .localDemo {
                    ProfileSettingsGroup {
                        NavigationLink {
                            DeveloperToolsView(isShowingOnboarding: $isShowingOnboarding)
                                .toolbar(.visible, for: .navigationBar)
                        } label: {
                            ProfileSettingsRow("Developer Lab & Tools", symbol: "testtube.2")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 20)
                }

                VStack(spacing: 6) {
                    Button("Sign out") { showsSignOutConfirmation = true }
                        .font(.body)
                        .foregroundStyle(WIFTheme.fresh)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("signOutButton")

                    Text(versionText)
                        .font(.caption)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 26)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .accessibilityIdentifier("profileSettingsScreen")
        .accessibilityValue(appearance.rawValue)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $isShowingOnboarding) {
            OnboardingView {
                isShowingOnboarding = false
            }
        }
        .sheet(item: $profileDraft) { draft in
            EditProfileView(draft: draft, onClose: { profileDraft = nil })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsAppearanceSettings) {
            AppearanceSettingsView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Sign out?", isPresented: $showsSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { Task { await store.signOut() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Cached friend data will be removed from the App and Widget.")
        }
    }

    /// Your own city emblem stands in for an avatar: it's the same one friends see on their cards.
    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                let presence = store.snapshot.currentPresence
                CityEmblemView(city: store.currentCity, countryCode: presence.countryCode,
                               administrativeArea: presence.administrativeArea, size: 96)
                    .padding(.leading, -6)
                    .accessibilityHidden(true)

                Spacer(minLength: 8)

                Button("Edit") {
                    store.clearProfileSaveError()
                    profileDraft = ProfileEditorDraft(displayName: store.snapshot.currentUser.displayName,
                        username: store.snapshot.currentUser.username)
                }
                .font(.body)
                .foregroundStyle(WIFTheme.fresh)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Edit profile")
                .accessibilityIdentifier("editProfileButton")
            }

            Text(store.snapshot.currentUser.displayName)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(WIFTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .padding(.top, 8)

            Text(profileSubtitle)
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
                .lineLimit(1)
                .padding(.top, 4)
        }
    }

    private var appearance: WIFAppearance {
        appearanceController.appearance
    }

    private var profileSubtitle: String {
        let handle = "@\(store.snapshot.currentUser.username)"
        guard store.currentCity != nil else { return handle }
        return "\(handle) · \(store.snapshot.currentPresence.cityDisplay)"
    }

    private var citySharingValue: Text? {
        if !store.snapshot.sharingPreferences.citySharingEnabled { return Text("Paused") }
        return store.currentCity.map { Text(verbatim: $0) }
    }

    private var upcomingPlanCount: Int {
        travelPlans.plans.filter { !$0.isPast() }.count
    }

    /// Counts only earn a value when there is something to count; zero stays quiet.
    private func countValue(_ count: Int) -> Text? {
        count > 0 ? Text(count, format: .number) : nil
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return String(localized: "Version \(version) (\(build))")
    }
}

/// One rounded card of settings rows, the grouping used across the You tab.
private struct ProfileSettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 16)
            .wifContentSurface(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// A settings row: a plain accent icon, a title, and the current state on the trailing edge.
/// Rows describe themselves through their state, so there is no subtitle.
private struct ProfileSettingsRow: View {
    let title: LocalizedStringKey
    let symbol: String
    var value: Text?
    var showsDisclosure = true

    init(_ title: LocalizedStringKey, symbol: String, value: Text? = nil, showsDisclosure: Bool = true) {
        self.title = title
        self.symbol = symbol
        self.value = value
        self.showsDisclosure = showsDisclosure
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(WIFTheme.fresh)
                .frame(width: 24)

            Text(title)
                .font(.body)
                .foregroundStyle(WIFTheme.primaryText)

            Spacer(minLength: 8)

            if let value {
                value
                    .font(.body)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(1)
            }

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WIFTheme.secondaryText.opacity(0.55))
            }
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

private struct ProfileSettingsDivider: View {
    var body: some View {
        Divider()
            .overlay(WIFTheme.border)
            .padding(.leading, 38)
    }
}

/// Blocking, the data summary and account deletion: rarely visited, so they sit one level down.
private struct PrivacySettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showsDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ProfileSettingsGroup {
                    NavigationLink {
                        BlockedPeopleView()
                    } label: {
                        ProfileSettingsRow("Blocked people", symbol: "person.slash", value: blockedValue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("blockedPeopleLink")

                    ProfileSettingsDivider()

                    NavigationLink {
                        PrivacyDataView()
                    } label: {
                        ProfileSettingsRow("Privacy & data", symbol: "lock")
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("privacyDataLink")
                }

                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Text(store.isDeletingAccount ? "Deleting account…" : "Delete account")
                        .font(.body)
                        .foregroundStyle(WIFTheme.destructive)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.isDeletingAccount)
                .padding(.top, 32)
            }
            .padding(WIFTheme.screenInset)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("privacySettingsScreen")
        .confirmationDialog("Delete your account?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { Task { await store.deleteAccount() } }
                .disabled(store.isDeletingAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(store.repositoryMode == .localDemo
                 ? "This removes the local demo account and cached Widget data."
                 : "Your account, personal plans, friendships, city-sharing data and notification devices will be deleted. Shared trips may retain your participant name and flights for other members. Remove your flights first if you don’t want them retained. This can’t be undone.")
        }
    }

    private var blockedValue: Text? {
        let count = store.snapshot.blockedUserIDs.count
        return count > 0 ? Text(count, format: .number) : nil
    }
}

/// Everything Across Us needs from iOS, in one place. It returns each day until every
/// item is on, so a dismissed home reminder never leaves someone without a way back.
private struct SetupChecklistCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationService: CityLocationService
    @ObservedObject var notificationService: LocalNotificationService
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    /// Re-read on appear and on return to the app, so a closed card comes back the next day.
    @State private var isHiddenToday = false
    private let dismissal = SetupChecklistDismissal()

    private struct Item: Identifiable {
        let id: String
        let symbol: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        let isDone: Bool
        let action: LocalizedStringKey
        let perform: () -> Void
    }

    var body: some View {
        Group {
        if isLiveAccount, store.snapshot.isAuthenticated, !isHiddenToday, items.contains(where: { !$0.isDone }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Finish setting up").font(.headline).foregroundStyle(WIFTheme.primaryText)
                    Spacer()
                    Text("\(items.filter(\.isDone).count) of \(items.count) on")
                        .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                    Button(action: hideForToday) {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold)).foregroundStyle(WIFTheme.secondaryText)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, -12)
                    .accessibilityLabel("Hide until tomorrow")
                    .accessibilityIdentifier("setupChecklistClose")
                }
                .padding(.top, -10)
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().overlay(WIFTheme.border).padding(.leading, 52) }
                    row(item)
                }
            }
            .padding(.horizontal, 18).padding(.top, 16).padding(.bottom, 8)
            .wifContentSurface(tint: WIFTheme.fresh.opacity(0.05),
                               in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous))
            // Sits between the header and the first settings group, which adds its own 28pt.
            .padding(.top, 28)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("setupChecklist")
            .transition(.opacity)
        }
        }
        .onAppear(perform: refreshVisibility)
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshVisibility() } }
    }

    /// Demo data has no real permissions to finish, like the home reminders.
    private var isLiveAccount: Bool {
        var isLive = store.repositoryMode == .remote
        #if DEBUG
        isLive = isLive || ProcessInfo.processInfo.arguments.contains("-testSetupChecklist")
        #endif
        return isLive
    }

    private func refreshVisibility() {
        isHiddenToday = dismissal.isHidden(for: store.snapshot.currentUser.id)
    }

    private func hideForToday() {
        dismissal.dismiss(for: store.snapshot.currentUser.id)
        withAnimation(.easeOut(duration: 0.2)) { isHiddenToday = true }
    }

    private func row(_ item: Item) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: item.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WIFTheme.fresh)
                .frame(width: 38, height: 38)
                .background(WIFTheme.fresh.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
                Text(item.detail).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if item.isDone {
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold)).foregroundStyle(WIFTheme.fresh)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("On")
            } else {
                Button(action: item.perform) {
                    Text(item.action)
                        .font(.subheadline.weight(.semibold)).foregroundStyle(WIFTheme.onFresh)
                        .padding(.horizontal, 14).frame(minHeight: 34)
                        .background(WIFTheme.fresh, in: Capsule())
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("setupChecklist-\(item.id)")
            }
        }
        .padding(.vertical, 10)
    }

    private var items: [Item] {
        var items: [Item] = []
        if store.snapshot.sharingPreferences.citySharingEnabled {
            let status = locationService.authorizationStatus
            items.append(Item(
                id: "location", symbol: "location.fill", title: "Location: Always",
                detail: "Know the moment a friend lands, even with the app closed.",
                isDone: status == .authorizedAlways,
                action: "Turn on",
                perform: { turnOnLocation(status) }))
        }
        items.append(Item(
            id: "notifications", symbol: "bell.fill", title: "Notifications",
            detail: "Same-city moments and trip reminders.",
            isDone: notificationService.allowsNotifications,
            action: "Turn on",
            perform: turnOnNotifications))
        return items
    }

    private func turnOnLocation(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationService.requestForegroundCity()
        case .authorizedWhenInUse:
            Task {
                // Background updates must be on before iOS offers Always in Settings.
                if !store.snapshot.sharingPreferences.backgroundUpdatesEnabled {
                    var preferences = store.snapshot.sharingPreferences
                    preferences.backgroundUpdatesEnabled = true
                    guard await store.setSharingPreferences(preferences) else { return }
                }
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        default:
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        }
    }

    private func turnOnNotifications() {
        if notificationService.authorizationStatus == .notDetermined {
            Task { await store.requestNotificationAuthorization() }
        } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            openURL(url)
        }
    }
}

private struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearanceController: WIFAppearanceController

    var body: some View {
        NavigationStack {
            ScrollView {
              VStack(alignment: .leading, spacing: 14) {
                Text("Choose one look for the App, Home Screen widgets, and Lock Screen widgets.")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)

                appearanceChoice(.system, title: "Follow system", subtitle: "Switch between light and dark with your device.", symbol: "circle.lefthalf.filled")

                appearanceChoice(
                    .solarJade,
                    title: "Solar Jade",
                    subtitle: "Warm ivory, sunlit green, and clear emerald glass",
                    symbol: "sun.max.fill"
                )

                appearanceChoice(
                    .nightJade,
                    title: "Night Jade",
                    subtitle: "Deep ink green, midnight blue, and luminous jade",
                    symbol: "moon.stars.fill"
                )

                Spacer(minLength: 0)
            }
              }
            .padding(WIFTheme.screenInset)
            .wifAmbientBackground()
            .navigationTitle("Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("appearanceDoneButton")
                }
            }
        }
    }

    private func appearanceChoice(
        _ appearance: WIFAppearance,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        symbol: String
    ) -> some View {
        Button {
            appearanceController.select(appearance)
            WidgetCenter.shared.reloadAllTimelines()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(appearance == .solarJade ? WIFTheme.fresh : WIFTheme.sunGlow)
                    .frame(width: 50, height: 50)
                    .background(WIFTheme.fresh.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(WIFTheme.primaryText)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: currentAppearance == appearance ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(currentAppearance == appearance ? WIFTheme.fresh : WIFTheme.secondaryText)
            }
            .padding(16)
            .contentShape(Rectangle())
            .wifGlassSurface(
                tint: currentAppearance == appearance ? WIFTheme.fresh.opacity(0.14) : nil,
                interactive: true,
                in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(appearance.rawValue)Appearance")
        .accessibilityValue(currentAppearance == appearance ? "1" : "0")
    }

    private var currentAppearance: WIFAppearance {
        appearanceController.appearance
    }
}

struct WIFSettingsPageHero: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(WIFTheme.fresh)
                .frame(width: 62, height: 62)
                .background(WIFTheme.fresh.opacity(0.12), in: Circle())

            Text(title)
                .font(.title2.bold())
                .foregroundStyle(WIFTheme.primaryText)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    func wifSettingsGlassCard(tint: Color = WIFTheme.surface.opacity(0.08)) -> some View {
        padding(18)
            .wifContentSurface(
                tint: tint,
                in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
            )
    }
}

private struct LocationAccessView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationService: CityLocationService
    @State private var pendingBackgroundUpdates: Bool?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WIFSettingsPageHero(
                    symbol: "location.viewfinder",
                    title: "Your city, kept current",
                    detail: "Keep your city up to date as you travel."
                )

                Toggle(isOn: backgroundUpdatesBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic city updates")
                            .font(.headline)
                            .foregroundStyle(WIFTheme.primaryText)
                        Text(locationService.authorizationStatus == .authorizedAlways
                             ? "Refresh after meaningful location changes"
                             : "Choose Always in Settings to update in the background.")
                            .font(.subheadline)
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                }
                .tint(WIFTheme.fresh)
                .disabled(store.isWorking || store.isSavingSharingPreferences)
                .wifSettingsGlassCard(tint: WIFTheme.fresh.opacity(0.08))
                .accessibilityIdentifier("backgroundUpdatesToggle")

                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        Image(systemName: authorizationSymbol)
                            .font(.headline)
                            .foregroundStyle(WIFTheme.fresh)
                            .frame(width: 42, height: 42)
                            .background(WIFTheme.fresh.opacity(0.10), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Location access")
                                .font(.headline)
                            Text(authorizationText)
                                .font(.subheadline)
                                .foregroundStyle(WIFTheme.secondaryText)
                        }

                        Spacer()
                    }

                    Divider().overlay(WIFTheme.border).padding(.vertical, 14)

                    Button {
                        locationService.requestForegroundCity()
                    } label: {
                        settingsActionLabel(
                            "Update current city",
                            symbol: locationService.isResolving ? "arrow.trianglehead.2.clockwise.rotate.90" : "location.fill"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(locationService.isResolving)

                    Divider().overlay(WIFTheme.border).padding(.vertical, 14)

                    Button("Open iOS Settings", systemImage: "gear") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WIFTheme.fresh)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.plain)
                }
                .wifSettingsGlassCard()

                Text(locationPermissionFooter)
                    .font(.footnote)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.horizontal, 4)

                if let errorMessage = locationService.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(WIFTheme.destructive)
                        .wifSettingsGlassCard(tint: WIFTheme.destructive.opacity(0.08))
                }
            }
            .padding(WIFTheme.screenInset)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Location & updates")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("locationAccessScreen")
    }

    private var authorizationSymbol: String {
        switch locationService.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: "checkmark.shield.fill"
        case .denied, .restricted: "location.slash.fill"
        default: "location.fill"
        }
    }

    private func settingsActionLabel(_ title: LocalizedStringKey, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.body.weight(.semibold))
            .foregroundStyle(WIFTheme.fresh)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var authorizationText: String {
        switch locationService.authorizationStatus {
        case .notDetermined: "Not requested"
        case .restricted: "Restricted"
        case .denied: "Denied"
        case .authorizedWhenInUse: "While Using"
        case .authorizedAlways: "Always"
        @unknown default: "Unknown"
        }
    }

    private var locationPermissionFooter: LocalizedStringKey {
        switch locationService.authorizationStatus {
        case .authorizedAlways: store.snapshot.sharingPreferences.backgroundUpdatesEnabled
            ? "Automatic city changes are available." : "Automatic city updates are off."
        case .authorizedWhenInUse: "Your city updates when you open the app. Choose Always for background updates."
        case .denied, .restricted: "Location access is off. You can still choose a city manually from the Friends screen."
        case .notDetermined: "Permission is requested only when you use a location feature."
        @unknown default: "Location access is unavailable."
        }
    }

    private var backgroundUpdatesBinding: Binding<Bool> {
        Binding {
            pendingBackgroundUpdates ?? store.snapshot.sharingPreferences.backgroundUpdatesEnabled
        } set: { newValue in
            pendingBackgroundUpdates = newValue
            var preferences = store.snapshot.sharingPreferences
            preferences.backgroundUpdatesEnabled = newValue
            if !newValue {
                locationService.stopBackgroundUpdates()
            }
            Task {
                let saved = await store.setSharingPreferences(preferences)
                if saved, newValue {
                    locationService.requestBackgroundUpdates()
                } else if !saved {
                    locationService.stopBackgroundUpdates()
                }
                pendingBackgroundUpdates = nil
            }
        }
    }
}

private struct WidgetPrivacyView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WIFSettingsPageHero(
                    symbol: "rectangle.3.group.fill",
                    title: "Beautiful at a glance",
                    detail: "Choose what appears on your widgets."
                )

                VStack(spacing: 12) {
                    privacyChoice(
                        mode: .full,
                        title: "Show names and cities",
                        note: "Recommended · Everything you need at a glance.",
                        symbol: "text.below.photo.fill"
                    )
                    privacyChoice(
                        mode: .hideNames,
                        title: "Hide names",
                        note: "Keep the city stages, without friend names.",
                        symbol: "eye.slash.fill"
                    )
                    privacyChoice(
                        mode: .hideAll,
                        title: "Hide everything",
                        note: "Hide names and cities.",
                        symbol: "lock.fill"
                    )
                }

                Text("Applies to Home Screen and Lock Screen widgets.")
                    .font(.footnote)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.horizontal, 4)
            }
            .padding(WIFTheme.screenInset)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Widget & Lock Screen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("widgetPrivacyScreen")
    }

    private func privacyChoice(
        mode: WidgetPrivacyMode,
        title: LocalizedStringKey,
        note: LocalizedStringKey,
        symbol: String
    ) -> some View {
        Button {
            store.setWidgetPrivacyMode(mode)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(WIFTheme.fresh)
                    .frame(width: 44, height: 44)
                    .background(WIFTheme.fresh.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WIFTheme.primaryText)
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                Spacer()
                if store.widgetPrivacyMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(WIFTheme.fresh)
                }
            }
            .contentShape(Rectangle())
            .wifSettingsGlassCard(
                tint: store.widgetPrivacyMode == mode
                    ? WIFTheme.fresh.opacity(0.13)
                    : WIFTheme.surface.opacity(0.06)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(widgetPrivacyIdentifier(for: mode))
        .accessibilityValue(store.widgetPrivacyMode == mode ? "1" : "0")
    }

    private func widgetPrivacyIdentifier(for mode: WidgetPrivacyMode) -> String {
        switch mode {
        case .full: "widgetPrivacyFull"
        case .hideNames: "widgetPrivacyHideNames"
        case .hideAll: "widgetPrivacyHideAll"
        }
    }
}

struct NotificationPermissionNotice: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var service: LocalNotificationService
    var body: some View {
        if !service.allowsNotifications {
            VStack(alignment: .leading, spacing: 10) {
                Label("iOS notifications are off", systemImage: "bell.slash").font(.headline)
                Text("Your preferences are saved, but alerts cannot appear until notifications are allowed in iOS.")
                    .font(.subheadline).foregroundStyle(WIFTheme.secondaryText).fixedSize(horizontal: false, vertical: true)
                Button {
                    if service.authorizationStatus == .notDetermined { Task { await store.requestNotificationAuthorization() } }
                    else if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                } label: {
                    Text(service.authorizationStatus == .notDetermined ? "Allow notifications" : "Open iOS Settings")
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .disabled(store.pushRegistrationState.isInProgress)
                .accessibilityIdentifier("notificationPermissionRecovery")
            }
        }
    }
}

private struct SameCityNotificationPreferencesView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            Section {
                NotificationPermissionNotice(service: store.notificationService)
                if !store.snapshot.sharingPreferences.citySharingEnabled {
                    Text("City sharing is paused. Same-city alerts are paused too.")
                }
            }
            Section {
                ForEach(store.friends.filter { !store.snapshot.blockedUserIDs.contains($0.id) }) { friend in
                    Toggle(isOn: Binding(get: { store.preference(for: friend.id).sameCityAlertEnabled }, set: { enabled in
                        var preference = store.preference(for: friend.id)
                        preference.sameCityAlertEnabled = enabled
                        Task { _ = await store.setFriendPreference(preference) }
                    })) {
                        Text(friend.displayName).fixedSize(horizontal: false, vertical: true)
                    }
                    .disabled(store.isSavingFriendPreference(for: friend.id))
                    .accessibilityIdentifier("notificationFriend-\(friend.username)")
                }
                if store.friends.isEmpty { Text("Add friends to configure same-city alerts.") }
            } footer: {
                Text("Alerts require both people to share recent cities. Turning off an alert does not stop city sharing.")
            }
        }
        .scrollContentBackground(.hidden).background(WIFTheme.canvas).tint(WIFTheme.fresh)
        .navigationTitle("Same-city alerts").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("sameCityNotificationPreferences")
    }
}

private struct TripNotificationDirectoryView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var library: TripLibrary
    @State private var selected: TripPlan?
    @State private var loaded = false
    private var scope: String { TripLibrary.storageScope(repository: store.tripRepository, ownerID: store.snapshot.currentUser.id.uuidString) }
    private var activeTrips: [TripPlan] { library.trips.filter { $0.phase() != .past && $0.cancelledAt == nil } }
    var body: some View {
        List {
            Section {
                NotificationPermissionNotice(service: store.notificationService)
                Text("Choose a shared trip to manage flight changes and flight planning reminders.")
                    .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
            }
            if !loaded { ProgressView() }
            if library.syncFailed {
                Section {
                    Text("Couldn’t refresh shared trips. Saved trips are shown below.")
                    Button("Try again") { Task { _ = await library.refresh() } }
                }
            }
            ForEach(activeTrips) { trip in
                Button { selected = trip } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(trip.name).font(.headline).foregroundStyle(WIFTheme.primaryText)
                        Text(trip.flightAlertsEnabled == true ? "Flight alerts on" : "Flight alerts off")
                        Text(trip.planningRemindersEnabled ?? true ? "Planning reminders on" : "Planning reminders off")
                    }
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true).frame(minHeight: 60)
                }
                .accessibilityIdentifier("notificationTrip-\(trip.id)")
            }
            if loaded && activeTrips.isEmpty && !library.syncFailed { Text("No ongoing or upcoming trips.") }
        }
        .scrollContentBackground(.hidden).background(WIFTheme.canvas).tint(WIFTheme.fresh)
        .navigationTitle("Shared trip alerts").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("tripNotificationDirectory")
        .sheet(item: $selected) { TripNotificationsSheet(library: library, trip: $0) }
        .task(id: scope) {
            loaded = false
            let owner = store.snapshot.currentUser
            library.connect(store.tripRepository)
            library.load(scope: scope, userID: owner.id.uuidString)
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-seedTripExamples") {
                library.addExamples(owner: TripParticipant(id: owner.id.uuidString, name: owner.displayName, userID: owner.id.uuidString))
            }
            #endif
            _ = await library.refresh()
            loaded = true
        }
        .refreshable { _ = await library.refresh() }
    }
}

private struct NotificationSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var notificationService: LocalNotificationService
    @State private var pendingPreviewPreference: Bool?
    @State private var showsFriendInvitations = false
    @StateObject private var invitationDraft = FriendInvitationDraft()
    @Environment(\.openSharedTrips) private var openSharedTrips
    @EnvironmentObject private var plans: TravelPlanLibrary

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                permissionStatusRow
                Text("Choose the updates you receive")
                    .font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
                Text("The settings below are saved preferences. iOS notification access is required for delivery.")
                    .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                Button { invitationDraft.reset(); showsFriendInvitations = true } label: {
                    TravelPurposeLink(title: "Friend invitations", subtitle: "Review requests. Delivery follows iOS notification access.", symbol: "person.badge.plus")
                }.buttonStyle(.plain).accessibilityIdentifier("notificationFriendInvitations")
                Button(action: openSharedTrips) {
                    TravelPurposeLink(title: "Trip invitations", subtitle: "Review invitations in Shared trips.", symbol: "envelope")
                }.buttonStyle(.plain).accessibilityIdentifier("notificationTripInvitations")
                NavigationLink { SameCityNotificationPreferencesView() } label: {
                    TravelPurposeLink(title: "Same-city alerts", subtitle: store.snapshot.sharingPreferences.citySharingEnabled
                        ? "Choose which friends can trigger an alert." : "Paused while city sharing is off.", symbol: "person.2")
                }.buttonStyle(.plain).accessibilityIdentifier("notificationSameCitySettings")
                NavigationLink { TravelPlansView() } label: {
                    TravelPurposeLink(title: "Travel plan overlaps", subtitle: "Manage reminders on each of your travel plans.", symbol: "calendar")
                }.buttonStyle(.plain).accessibilityIdentifier("notificationPlanSettings")
                Text("Plans with reminders on: \(plans.plans.filter { $0.alertsEnabled && !$0.isPast() }.count)")
                    .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                NavigationLink { TripNotificationDirectoryView() } label: {
                    TravelPurposeLink(title: "Flights and planning reminders", subtitle: "Manage flight updates and reminders for each shared trip.", symbol: "airplane")
                }.buttonStyle(.plain).accessibilityIdentifier("notificationSharedTripSettings")

                Toggle(isOn: notificationPreviewsBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show notification previews")
                            .font(.headline)
                        Text(previewsEnabled ? "Show names and invitation details" : "Hide names and details")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(WIFTheme.fresh)
                .disabled(store.isWorking || store.isSavingSharingPreferences)
                .padding(18)
                .wifGlassSurface(
                    tint: WIFTheme.fresh.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
                )
                .accessibilityIdentifier("notificationPreviewsToggle")

                Group {

                    if notificationService.authorizationStatus == .notDetermined {
                        Button {
                            Task { await store.requestNotificationAuthorization() }
                        } label: {
                            Text("Allow notifications").foregroundStyle(WIFTheme.onFresh)
                        }
                        .font(.headline)
                        .controlSize(.large)
                        .buttonBorderShape(.capsule)
                        .wifGlassButton(tint: WIFTheme.fresh, prominent: true)
                        .disabled(store.pushRegistrationState.isInProgress)
                        .accessibilityIdentifier("allowNotificationsButton")
                    } else if notificationService.authorizationStatus == .denied {
                        Button("Open iOS Settings", action: openNotificationSettings)
                            .font(.headline)
                            .controlSize(.large)
                            .buttonBorderShape(.capsule)
                            .wifGlassButton(tint: .orange.opacity(0.20))
                            .accessibilityIdentifier("openNotificationSettingsButton")
                    }
                }

                if store.repositoryMode == .remote && (store.pushRegistrationState == .failed || store.pushRegistrationState == .waitingForNetwork) {
                    deviceRegistrationCard
                }

                Text("Invitations don’t depend on location sharing. Same-city and flight alerts follow your friend and Trip settings.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .accessibilityIdentifier("notificationSettingsScreen")
        .sheet(isPresented: $showsFriendInvitations) { AddFriendView(draft: invitationDraft) }
        .task { await plans.refreshOwnPlans(); await store.preparePushRegistrationIfAuthorized() }
    }

    private var deviceRegistrationCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.radiowaves.left.and.right").foregroundStyle(WIFTheme.fresh)
            VStack(alignment: .leading, spacing: 4) {
                Text("Notifications need attention").font(.headline)
                Text(registrationDetail).font(.caption).foregroundStyle(WIFTheme.secondaryText)
            }
            Spacer(minLength: 4)
            if store.pushRegistrationState.isInProgress { ProgressView() }
            else if notificationService.allowsNotifications && store.repositoryMode == .remote {
                Button("Retry") { Task { await store.retryPushRegistration() } }
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("retryPushRegistrationButton")
            }
        }
        .padding(18).wifSettingsGlassCard()
        .accessibilityIdentifier("devicePushRegistrationCard")
    }

    private var registrationDetail: String {
        String(localized: "Couldn’t enable notifications. Check your connection and try again.")
    }

    private var permissionStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: permissionSymbol)
                .foregroundStyle(permissionColor)
                .frame(width: 44, height: 44)
                .background(permissionColor.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("iOS notification access")
                    .font(.headline)
                Text(permissionDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(permissionStatusText)
                .font(.subheadline)
                .foregroundStyle(permissionColor)
        }
        .padding(18)
        .wifGlassSurface(
            tint: permissionColor.opacity(0.08),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityIdentifier("notificationPermissionCard")
    }

    private var notificationPreviewsBinding: Binding<Bool> {
        Binding {
            previewsEnabled
        } set: { newValue in
            pendingPreviewPreference = newValue
            var preferences = store.snapshot.sharingPreferences
            preferences.notificationPreviewEnabled = newValue
            Task {
                _ = await store.setSharingPreferences(preferences)
                pendingPreviewPreference = nil
            }
        }
    }

    private var previewsEnabled: Bool {
        pendingPreviewPreference ?? store.snapshot.sharingPreferences.notificationPreviewEnabled
    }

    private var permissionStatusText: LocalizedStringKey {
        switch notificationService.authorizationStatus {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .provisional: "Quietly allowed"
        case .ephemeral: "Temporary"
        @unknown default: "Unknown"
        }
    }

    private var permissionDetail: LocalizedStringKey {
        switch notificationService.authorizationStatus {
        case .notDetermined: "Allow notifications for friend and Trip invitations."
        case .denied: "Notifications are turned off in iOS Settings."
        case .authorized: "Invitations and selected updates can appear as notifications."
        case .provisional: "Notifications arrive quietly in Notification Center."
        case .ephemeral: "Notification access is temporarily available."
        @unknown default: "Notification access is unavailable on this device."
        }
    }

    private var permissionSymbol: String {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional, .ephemeral: "checkmark"
        case .denied: "exclamationmark"
        default: "bell"
        }
    }

    private var permissionColor: Color {
        switch notificationService.authorizationStatus {
        case .authorized, .provisional, .ephemeral: WIFTheme.fresh
        case .denied: .orange
        default: WIFTheme.secondaryText
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct BlockedPeopleView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WIFSettingsPageHero(
                    symbol: "person.slash.fill",
                    title: "You’re in control",
                    detail: "Blocked people cannot invite you or see your shared city."
                )

                if store.snapshot.blockedPeople.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(WIFTheme.fresh)
                        Text("No blocked people")
                            .font(.headline)
                            .foregroundStyle(WIFTheme.primaryText)
                        Text("Anyone you block later will appear here.")
                            .font(.subheadline)
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .wifSettingsGlassCard(tint: WIFTheme.fresh.opacity(0.08))
                } else {
                    ForEach(store.snapshot.blockedPeople) { person in
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.displayName).font(.body.weight(.semibold))
                                Text("@\(person.username)")
                                    .font(.caption)
                                    .foregroundStyle(WIFTheme.secondaryText)
                            }
                            Spacer()
                            Button("Unblock") {
                                Task { await store.unblockUser(id: person.id) }
                            }
                            .wifGlassButton(tint: WIFTheme.fresh.opacity(0.14))
                            .disabled(store.isWorking || store.isSavingSharingPreferences)
                        }
                        .wifSettingsGlassCard()
                    }
                }
            }
            .padding(WIFTheme.screenInset)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Blocked people")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

private struct PrivacyDataView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WIFSettingsPageHero(
                    symbol: "hand.raised.fill",
                    title: "City-level by design",
                    detail: "See what you share and what the app saves."
                )

                VStack(spacing: 0) {
                    privacyRow(
                        "Account and city sharing",
                        detail: "Your profile, friends, sharing choices, latest city, update times and notification preferences.",
                        symbol: "externaldrive.fill", identifier: "privacyAccountSummary"
                    )
                    Divider().overlay(WIFTheme.border).padding(.leading, 52)
                    privacyRow(
                        "Plans and shared trips",
                        detail: "Planned cities and dates, selected friends, trip members and invitations, and flights you add with their routes, times and status.",
                        symbol: "airplane", identifier: "privacyTravelSummary"
                    )
                    Divider().overlay(WIFTheme.border).padding(.leading, 52)
                    privacyRow(
                        "Same-city moments",
                        detail: "Same-city events and stay periods used for your history and alerts.",
                        symbol: "clock.arrow.circlepath", identifier: "privacyMomentsSummary"
                    )
                    Divider().overlay(WIFTheme.border).padding(.leading, 52)
                    privacyRow(
                        "Device location",
                        detail: "Precise device coordinates are not sent to our servers. We don’t keep a GPS movement trail or access your contact book. Flight routes come from the flights you add.",
                        symbol: "location.slash.fill", identifier: "privacyDeviceLocationSummary"
                    )
                    Divider().overlay(WIFTheme.border).padding(.leading, 52)
                    privacyRow(
                        "On your Widget",
                        detail: "Your friends’ latest shared cities",
                        symbol: "rectangle.3.group.fill", identifier: "privacyWidgetSummary"
                    )
                    Divider().overlay(WIFTheme.border).padding(.leading, 52)
                    privacyRow(
                        "When you delete",
                        detail: "Your account, personal plans, friendships, city-sharing data and notification devices are deleted. You’re signed out and local cached data is cleared.",
                        symbol: "trash.fill", identifier: "privacyDeletionSummary"
                    )
                    Divider().overlay(WIFTheme.border).padding(.leading, 52)
                    privacyRow(
                        "Shared trips after deletion",
                        detail: "Your participant name and flights may remain in shared trips for other members. Remove your own flights before deleting your account if you don’t want them retained.",
                        symbol: "person.2.fill", identifier: "privacySharedTripRetention"
                    )
                }
                .wifSettingsGlassCard()

                Link(destination: PrivacyPolicyConfiguration.url()) {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(WIFTheme.fresh)
                            .frame(width: 44, height: 44)
                            .background(WIFTheme.fresh.opacity(0.10), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("View Privacy Policy")
                                .font(.headline)
                                .foregroundStyle(WIFTheme.primaryText)
                            Text("Collection, service providers, retention and your choices")
                                .font(.caption)
                                .foregroundStyle(WIFTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption.bold())
                            .foregroundStyle(WIFTheme.fresh)
                    }
                    .wifSettingsGlassCard(tint: WIFTheme.fresh.opacity(0.08))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("privacyPolicyLink")
            }
            .padding(WIFTheme.screenInset)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Privacy & data")
        .accessibilityIdentifier("privacyDataScreen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func privacyRow(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey,
        symbol: String,
        identifier: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WIFTheme.fresh)
                .frame(width: 38, height: 38)
                .background(WIFTheme.fresh.opacity(0.09), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(identifier)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }
}

/// Keep one draft for each explicit opening. Presentation/keyboard transitions
/// may recreate the sheet's view, but must never reseed fields from the account.
private final class ProfileEditorDraft: ObservableObject, Identifiable {
    let id = UUID()
    let initialDisplayName: String
    let initialUsername: String
    @Published var displayName: String
    @Published var username: String
    @Published var validationMessage: String?
    @Published var saveInProgress = false
    @Published var showsDiscardConfirmation = false

    init(displayName: String, username: String) {
        initialDisplayName = displayName
        initialUsername = username
        self.displayName = displayName
        self.username = username
    }

    var hasUnsavedChanges: Bool {
        displayName != initialDisplayName || username != initialUsername
    }

}

private struct EditProfileView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var draft: ProfileEditorDraft
    let onClose: () -> Void

    private var isSaving: Bool { draft.saveInProgress || store.isSavingProfile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    WIFSettingsPageHero(
                        symbol: "pencil.line",
                        title: "Make it yours",
                        detail: "Your name and username are the only identity details friends need."
                    )

                    VStack(spacing: 0) {
                        profileField(
                            title: "Display name",
                            text: $draft.displayName,
                            contentType: .name,
                            identifier: "displayNameField"
                        )

                        Divider().overlay(WIFTheme.border)

                        profileField(
                            title: "Username",
                            text: $draft.username,
                            contentType: .username,
                            identifier: "profileUsernameField",
                            usernameStyle: true
                        )
                    }
                    .wifSettingsGlassCard(tint: WIFTheme.fresh.opacity(0.08))

                    Text("Usernames use 3–20 lowercase letters, numbers, or underscores.")
                        .font(.footnote)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .padding(.horizontal, 4)

                    if let validationMessage = draft.validationMessage ?? store.profileSaveError {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(WIFTheme.destructive)
                            .wifSettingsGlassCard(tint: WIFTheme.destructive.opacity(0.08))
                            .accessibilityIdentifier("profileValidationMessage")
                    }

                    Button(action: save) {
                        HStack {
                            if isSaving { ProgressView() }
                            Text("Save changes")
                                .frame(maxWidth: .infinity)
                        }
                        .font(.headline)
                        .padding(.vertical, 15)
                    }
                    .foregroundStyle(WIFTheme.primaryText)
                    .wifGlassButton(tint: WIFTheme.fresh.opacity(0.34), prominent: true)
                    .disabled(isSaving)
                    .accessibilityIdentifier("saveProfileButton")
                }
                .padding(WIFTheme.screenInset)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .wifAmbientBackground()
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: close)
                        .disabled(isSaving)
                        .accessibilityIdentifier("closeProfileButton")
                }
            }
        }
        .alert(isPresented: $draft.showsDiscardConfirmation) {
            Alert(
                title: Text("Discard changes?"),
                message: Text("Your unsaved changes will be lost."),
                primaryButton: .destructive(Text("Discard changes")) {
                    onClose()
                },
                secondaryButton: .cancel(Text("Keep editing"))
            )
        }
        .interactiveDismissDisabled(draft.hasUnsavedChanges || isSaving)

    }

    private func profileField(
        title: LocalizedStringKey,
        text: Binding<String>,
        contentType: UITextContentType,
        identifier: String,
        usernameStyle: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(WIFTheme.secondaryText)

            TextField(title, text: text)
                .font(.body.weight(.semibold))
                .foregroundStyle(WIFTheme.primaryText)
                .textContentType(contentType)
                .textInputAutocapitalization(usernameStyle ? .never : .words)
                .autocorrectionDisabled(usernameStyle)
                .disabled(isSaving)
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 7)
    }

    private func save() {
        guard !isSaving else { return }
        let update = ProfileUpdate(
            displayName: draft.displayName,
            username: draft.username,
            avatarPalette: store.snapshot.currentUser.avatarPalette
        )
        do {
            let validated = try update.validated()
            draft.validationMessage = nil
            draft.saveInProgress = true
            Task {
                defer { draft.saveInProgress = false }
                if await store.updateProfile(validated) { onClose() }
            }
        } catch {
            draft.validationMessage = error.localizedDescription
        }
    }

    private func close() {
        guard !isSaving else { return }
        if draft.hasUnsavedChanges { draft.showsDiscardConfirmation = true }
        else { onClose() }
    }

}

// MARK: - Developer Tools

private struct DeveloperToolsView: View {
    @Binding var isShowingOnboarding: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WIFSettingsPageHero(
                    symbol: "testtube.2",
                    title: "Developer Lab & Tools",
                    detail: "Simulate data states, browse 3D landmarks, and preview widgets."
                )

                VStack(spacing: 0) {
                    NavigationLink {
                        DemoLabView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        devToolRow(
                            title: "Demo Lab",
                            subtitle: "Simulate invites, stale data and alerts",
                            symbol: "testtube.2",
                            color: .purple
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().overlay(WIFTheme.border).padding(.leading, 56)

                    NavigationLink {
                        CityEmblemGalleryView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        devToolRow(
                            title: "City Emblem Gallery",
                            subtitle: "Browse 150+ 3D city landmarks",
                            symbol: "building.2.crop.circle.fill",
                            color: WIFTheme.fresh
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cityEmblemGalleryLink")

                    Divider().overlay(WIFTheme.border).padding(.leading, 56)

                    NavigationLink {
                        WidgetShowcaseView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        devToolRow(
                            title: "Widget Studio",
                            subtitle: "Preview your Home Screen widgets",
                            symbol: "square.grid.2x2.fill",
                            color: .cyan
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("widgetStudioLink")

                    Divider().overlay(WIFTheme.border).padding(.leading, 56)

                    Button {
                        isShowingOnboarding = true
                    } label: {
                        devToolRow(
                            title: "Preview onboarding",
                            subtitle: "A quick introduction before you start",
                            symbol: "sparkles",
                            color: .yellow,
                            showsDisclosure: false
                        )
                    }
                    .buttonStyle(.plain)
                }
                .wifSettingsGlassCard()
            }
            .padding(WIFTheme.screenInset)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func devToolRow(
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        symbol: String,
        color: Color,
        showsDisclosure: Bool = true
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer(minLength: 8)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(WIFTheme.secondaryText)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 6)
    }
}

// MARK: - Widget Studio Showcase

struct WidgetShowcaseView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @State private var size: HomeWidgetSize = .large
    @State private var together = false

    private var previewScheme: ColorScheme {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-widgetPreviewDark") { return .dark }
        #endif
        return scheme
    }

    private var content: HomeWidgetContent {
        var value = HomeWidgetContent(date: Date(), friends: store.friends,
            currentPresence: store.snapshot.currentPresence, privacyMode: store.widgetPrivacyMode)
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-widgetHideNames") { value.privacyMode = .hideNames }
        if args.contains("-widgetHideAll") { value.privacyMode = .hideAll }
        if args.contains("-widgetEmpty") { value.friends = [] }
        if args.contains("-widgetLongCity"), !value.friends.isEmpty {
            value.friends[0].city = "San Luis Obispo"; value.friends[0].administrativeArea = "California"
            value.friends[0].displayName = "Alexandra Montgomery-Rivera"
            value.currentPresence.city = "San Luis Obispo"; value.currentPresence.administrativeArea = "CA"
        }
        #endif
        return value
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Picker("Widget style", selection: $together) {
                    Text("Friends").tag(false)
                    Text("Here together").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("widgetStylePicker")
                Picker("Widget size", selection: $size) {
                    ForEach(HomeWidgetSize.allCases) { item in Text(item.title).tag(item) }
                }.pickerStyle(.segmented).accessibilityIdentifier("widgetSizePicker")
                ViewThatFits(in: .horizontal) {
                    preview(width: size.previewSize.width)
                    preview(width: size == .small ? 170 : 300)
                }
                Text("Across Us").font(.caption).foregroundStyle(WIFTheme.secondaryText)
            }.padding(20)
        }
        .background(WIFTheme.canvas)
        .navigationTitle("Widgets").navigationBarTitleDisplayMode(.inline)
    }

    private func preview(width: CGFloat) -> some View {
        Group {
            if together { TogetherHomeWidget(content: content, size: size) }
            else { FriendDirectoryWidget(content: content, size: size) }
        }
        .padding(16)
        .frame(width: width, height: size.previewSize.height)
        .background(together ? HomeWidgetPalette.together : HomeWidgetPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 27))
        .overlay(RoundedRectangle(cornerRadius: 27).strokeBorder(HomeWidgetPalette.rule.opacity(0.6), lineWidth: 0.5))
        .environment(\.colorScheme, previewScheme)
        .accessibilityElement(children: .contain).accessibilityIdentifier("widgetPreviewSurface")
    }
}

// The debug entry uses the same views as the installed extension.
struct HomeScreenWidgetMarketingView: View {
    var body: some View {
        NavigationStack { WidgetShowcaseView() }
    }
}

#Preview {
    let store = AppStore()
    NavigationStack { ProfileView(onReplayOnboarding: {}) }
        .environmentObject(store)
        .environmentObject(store.travelPlans)
        .environmentObject(TripLibrary())
        .environmentObject(CityLocationService())
        .environmentObject(WIFAppearanceController())
}
