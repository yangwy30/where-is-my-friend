import CoreLocation
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var appearanceController: WIFAppearanceController
    let onReplayOnboarding: () -> Void
    let onOpenCitySharing: () -> Void
    @State private var showsDeleteConfirmation = false
    @State private var showsSignOutConfirmation = false
    @State private var showsEditProfile = false
    @State private var showsAppearanceSettings = false

    init(
        onReplayOnboarding: @escaping () -> Void,
        onOpenCitySharing: @escaping () -> Void = {}
    ) {
        self.onReplayOnboarding = onReplayOnboarding
        self.onOpenCitySharing = onOpenCitySharing
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                profileHeader
                    .padding(.bottom, 42)

                profileSection("Your world") {
                    Button(action: onOpenCitySharing) {
                        profileMenuRow(
                            "City sharing",
                            subtitle: "Choose who can see your current city",
                            symbol: "location.fill",
                            color: WIFTheme.fresh
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profileCitySharingButton")

                    menuDivider

                    NavigationLink {
                        NotificationSettingsView(notificationService: store.notificationService)
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        profileMenuRow(
                            "Notifications",
                            subtitle: "Same-city alerts and moment history",
                            symbol: "bell.fill",
                            color: .orange
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("notificationSettingsLink")

                    menuDivider

                    NavigationLink {
                        WidgetPrivacyView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        profileMenuRow(
                            "Widget & Lock Screen",
                            subtitle: "Choose what appears at a glance",
                            symbol: "rectangle.3.group.fill",
                            color: .indigo
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("widgetPrivacySettingsLink")

                    menuDivider

                    Button {
                        showsAppearanceSettings = true
                    } label: {
                        profileMenuRow(
                            "Appearance",
                            subtitle: appearance == .solarJade ? "Solar Jade" : "Night Jade",
                            symbol: "circle.lefthalf.filled",
                            color: WIFTheme.fresh
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("appearanceSettingsButton")
                }

                sectionDivider

                profileSection("Account & privacy") {
                    NavigationLink {
                        LocationAccessView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        profileMenuRow(
                            "Location & automatic updates",
                            subtitle: "Control automatic city updates",
                            symbol: "location.viewfinder",
                            color: .cyan
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("locationAccessLink")

                    menuDivider

                    NavigationLink {
                        BlockedPeopleView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        profileMenuRow(
                            "Blocked people",
                            subtitle: blockedPeopleSubtitle,
                            symbol: "person.slash.fill",
                            color: .secondary
                        )
                    }
                    .buttonStyle(.plain)

                    menuDivider

                    NavigationLink {
                        PrivacyDataView()
                            .toolbar(.visible, for: .navigationBar)
                    } label: {
                        profileMenuRow(
                            "Privacy & data",
                            subtitle: "See how your location data is protected",
                            symbol: "hand.raised.fill",
                            color: .blue
                        )
                    }
                    .buttonStyle(.plain)
                }

                if store.repositoryMode == .localDemo {
                    sectionDivider

                    profileSection("Development") {
                        NavigationLink {
                            DemoLabView()
                                .toolbar(.visible, for: .navigationBar)
                        } label: {
                            profileMenuRow(
                                "Demo Lab",
                                subtitle: "Simulate invites, stale data and alerts",
                                symbol: "testtube.2",
                                color: .purple
                            )
                        }
                        .buttonStyle(.plain)

                        menuDivider

                        NavigationLink {
                            CityEmblemGalleryView()
                                .toolbar(.visible, for: .navigationBar)
                        } label: {
                            profileMenuRow(
                                "City Emblem Gallery",
                                subtitle: "Browse 150+ 3D city landmarks",
                                symbol: "building.2.crop.circle.fill",
                                color: WIFTheme.fresh
                            )
                        }
                        .buttonStyle(.plain)

                        menuDivider

                        NavigationLink {
                            WidgetShowcaseView()
                                .toolbar(.visible, for: .navigationBar)
                        } label: {
                            profileMenuRow(
                                "Widget Studio",
                                subtitle: "Interactive 3D diorama widget preview",
                                symbol: "square.grid.2x2.fill",
                                color: .cyan
                            )
                        }
                        .buttonStyle(.plain)

                        menuDivider

                        Button(action: onReplayOnboarding) {
                            profileMenuRow(
                                "Preview onboarding",
                                subtitle: "A quick introduction before you start",
                                symbol: "sparkles",
                                color: .yellow,
                                showsDisclosure: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionDivider

                profileSection("Account") {
                    Button {
                        showsSignOutConfirmation = true
                    } label: {
                        profileMenuRow(
                            "Sign out",
                            subtitle: nil,
                            symbol: "rectangle.portrait.and.arrow.right",
                            color: .secondary,
                            showsDisclosure: false
                        )
                    }
                    .buttonStyle(.plain)

                    menuDivider

                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        profileMenuRow(
                            "Delete account",
                            subtitle: nil,
                            symbol: "trash.fill",
                            color: WIFTheme.destructive,
                            showsDisclosure: false,
                            isDestructive: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text(buildFooter)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 34)
                    .padding(.bottom, 42)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.top, 20)
        }
        .scrollIndicators(.hidden)
        .wifAmbientBackground()
        .accessibilityIdentifier("profileSettingsScreen")
        .accessibilityValue(appearance.rawValue)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showsEditProfile) {
            EditProfileView()
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
        .confirmationDialog("Delete your account?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) { Task { await store.deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(store.repositoryMode == .localDemo
                 ? "This removes the local demo account and cached Widget data."
                 : "The server will delete your account, friendships, preferences, current city and notification devices. You can separately remove Where Is My Friend under Sign in with Apple in your Apple Account settings.")
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.snapshot.currentUser.displayName)
                        .font(.largeTitle.bold())
                        .fontWidth(.expanded)
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text("@\(store.snapshot.currentUser.username)")
                        .font(.headline)
                        .foregroundStyle(WIFTheme.fresh)
                        .lineLimit(1)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 8)

                Button {
                    showsEditProfile = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(WIFTheme.fresh)
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.plain)
                .wifGlassSurface(tint: WIFTheme.fresh.opacity(0.14), interactive: true, in: Circle())
                .accessibilityLabel("Edit profile")
                .accessibilityIdentifier("editProfileButton")
            }

            Text(profilePresenceText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WIFTheme.secondaryText)
        }
    }

    private var appearance: WIFAppearance {
        appearanceController.appearance
    }

    private var profilePresenceText: String {
        guard store.currentCity != nil else { return "No shared city" }
        return store.snapshot.currentPresence.cityDisplay
    }

    private var buildFooter: String {
        if store.repositoryMode == .localDemo {
            return "Local demo · No precise coordinates or route history are stored"
        }
        return "No precise coordinates or route history are stored"
    }

    private var blockedPeopleSubtitle: LocalizedStringKey {
        store.snapshot.blockedUserIDs.isEmpty ? "No blocked people" : "\(store.snapshot.blockedUserIDs.count) blocked"
    }

    @ViewBuilder
    private func profileSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            VStack(spacing: 0, content: content)
        }
    }

    private func profileMenuRow(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey?,
        symbol: String,
        color _: Color,
        showsDisclosure: Bool = true,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(isDestructive ? WIFTheme.destructive : WIFTheme.fresh)
                .frame(width: 48, height: 48)
                .background(WIFTheme.fresh.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isDestructive ? WIFTheme.destructive : .primary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 76)
        .contentShape(Rectangle())
    }

    private var menuDivider: some View {
        Divider()
            .overlay(WIFTheme.border)
            .padding(.leading, 64)
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(WIFTheme.border)
            .padding(.vertical, 36)
    }
}

private struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearanceController: WIFAppearanceController

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose one look for the App, Home Screen widgets, and Lock Screen widgets.")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)

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
        .accessibilityIdentifier(appearance == .solarJade ? "solarJadeAppearance" : "nightJadeAppearance")
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
            .wifGlassSurface(
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
                    detail: "City detection happens on this iPhone. Precise coordinates and routes are never uploaded."
                )

                Toggle(isOn: backgroundUpdatesBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Automatic city updates")
                            .font(.headline)
                            .foregroundStyle(WIFTheme.primaryText)
                        Text("Refresh after meaningful location changes")
                            .font(.subheadline)
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                }
                .tint(WIFTheme.fresh)
                .disabled(store.isWorking)
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
        case .authorizedAlways: "Automatic city changes are available."
        case .authorizedWhenInUse: "Choose automatic updates to request Always access."
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
                    detail: "Widgets start with a useful default. Choose a quieter privacy level only when you need it."
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
                        note: "Show only a private placeholder.",
                        symbol: "lock.fill"
                    )
                }

                Text("This controls Where Is My Friend widgets on the Home Screen and Lock Screen. iOS may apply additional privacy redaction while your iPhone is locked.")
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

private struct NotificationSettingsView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var notificationService: LocalNotificationService
    @State private var pendingAlertPreference: Bool?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                VStack(spacing: 14) {
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(WIFTheme.fresh)
                        .frame(width: 86, height: 86)
                        .background(WIFTheme.fresh.opacity(0.12), in: Circle())
                        .overlay {
                            Circle().stroke(WIFTheme.fresh.opacity(0.22), lineWidth: 1)
                        }
                        .shadow(color: WIFTheme.fresh.opacity(0.26), radius: 28, y: 12)

                    Text("Stay close, without checking")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    Text("We’ll let you know when you and a friend are in the same city.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 16)

                Toggle(isOn: sameCityAlertsBinding) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Same-city notifications")
                            .font(.headline)
                        Text(alertsEnabled ? "On" : "Paused")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(WIFTheme.fresh)
                .disabled(store.isWorking)
                .padding(18)
                .wifGlassSurface(
                    tint: WIFTheme.fresh.opacity(0.08),
                    in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
                )
                .accessibilityIdentifier("sameCityNotificationsToggle")

                if alertsEnabled {
                    permissionStatusRow

                    if notificationService.authorizationStatus == .notDetermined {
                        Button("Allow notifications") {
                            Task { await store.requestNotificationAuthorization() }
                        }
                        .font(.headline)
                        .controlSize(.large)
                        .buttonBorderShape(.capsule)
                        .wifGlassButton(tint: WIFTheme.fresh.opacity(0.30), prominent: true)
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

                NavigationLink {
                    NotificationHistoryView()
                } label: {
                    HStack(spacing: 15) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundStyle(WIFTheme.fresh)
                            .frame(width: 46, height: 46)
                            .background(WIFTheme.fresh.opacity(0.10), in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text("View same-city history")
                                .font(.headline)
                            Text("Every same-city moment stays available here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Text("Notification delivery is handled automatically in the background.")
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

    private var sameCityAlertsBinding: Binding<Bool> {
        Binding {
            alertsEnabled
        } set: { newValue in
            pendingAlertPreference = newValue
            var preferences = store.snapshot.sharingPreferences
            preferences.notificationPreviewEnabled = newValue
            Task {
                let saved = await store.setSharingPreferences(preferences)
                pendingAlertPreference = nil
                if saved, newValue {
                    await store.requestNotificationAuthorization()
                }
            }
        }
    }

    private var alertsEnabled: Bool {
        pendingAlertPreference ?? store.snapshot.sharingPreferences.notificationPreviewEnabled
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
        case .notDetermined: "Allow notifications to receive same-city updates."
        case .denied: "Notifications are turned off in iOS Settings."
        case .authorized: "City alerts can appear as banners and play sounds."
        case .provisional: "City alerts arrive quietly in Notification Center."
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
                            .disabled(store.isWorking)
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
                    detail: "Your friends get useful context without precise tracking or route history."
                )

                VStack(spacing: 0) {
                    privacyRow(
                        "Stored",
                        detail: "Identity, friendships, sharing choices, current city and update time",
                        symbol: "externaldrive.fill"
                    )
                    Divider().overlay(WIFTheme.border).padding(.leading, 52)
                    privacyRow(
                        "Never stored",
                        detail: "Precise coordinates, routes, location history or your contact book",
                        symbol: "location.slash.fill"
                    )
                    Divider().overlay(WIFTheme.border).padding(.leading, 52)
                    privacyRow(
                        "On your Widget",
                        detail: "Accepted friends’ last-known cities in a private App Group cache",
                        symbol: "rectangle.3.group.fill"
                    )
                    Divider().overlay(WIFTheme.border).padding(.leading, 52)
                    privacyRow(
                        "When you delete",
                        detail: "Server data, the local session and Widget cache are removed",
                        symbol: "trash.fill"
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func privacyRow(
        _ title: LocalizedStringKey,
        detail: LocalizedStringKey,
        symbol: String
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
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }
}

private struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var displayName = ""
    @State private var username = ""
    @State private var validationMessage: String?

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
                            text: $displayName,
                            contentType: .name,
                            identifier: "displayNameField"
                        )

                        Divider().overlay(WIFTheme.border)

                        profileField(
                            title: "Username",
                            text: $username,
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

                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(WIFTheme.destructive)
                            .wifSettingsGlassCard(tint: WIFTheme.destructive.opacity(0.08))
                    }

                    Button(action: save) {
                        HStack {
                            if store.isWorking { ProgressView() }
                            Text("Save changes")
                                .frame(maxWidth: .infinity)
                        }
                        .font(.headline)
                        .padding(.vertical, 15)
                    }
                    .foregroundStyle(WIFTheme.primaryText)
                    .wifGlassButton(tint: WIFTheme.fresh.opacity(0.34), prominent: true)
                    .disabled(store.isWorking)
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
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .onAppear {
                displayName = store.snapshot.currentUser.displayName
                username = store.snapshot.currentUser.username
            }
        }
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
                .accessibilityIdentifier(identifier)
        }
        .padding(.vertical, 7)
    }

    private func save() {
        let update = ProfileUpdate(
            displayName: displayName,
            username: username,
            avatarPalette: store.snapshot.currentUser.avatarPalette
        )
        do {
            let validated = try update.validated()
            validationMessage = nil
            Task {
                if await store.updateProfile(validated) { dismiss() }
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}

// MARK: - Widget Studio Showcase

struct WidgetShowcaseView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selectedAmbience: AmbienceTone = .day
    @State private var selectedTab: WidgetTab = .dualOrbit

    enum WidgetTab: String, CaseIterable, Identifiable {
        case dualOrbit = "Dual Orbit"
        case heroSmall = "Hero Stage"
        case large = "Constellation"
        case together = "Together"

        var id: String { rawValue }
    }

    enum AmbienceTone: String, CaseIterable, Identifiable {
        case dawn = "Dawn"
        case day = "Day"
        case goldenHour = "Sunset"
        case night = "Night"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dawn: return "sun.horizon.fill"
            case .day: return "sun.max.fill"
            case .goldenHour: return "sun.dust.fill"
            case .night: return "moon.stars.fill"
            }
        }

        var edgeTint: Color {
            switch self {
            case .dawn: return Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.18)
            case .day: return Color(red: 0.38, green: 0.68, blue: 0.96).opacity(0.14)
            case .goldenHour: return Color(red: 0.98, green: 0.58, blue: 0.24).opacity(0.20)
            case .night: return Color(red: 0.35, green: 0.45, blue: 0.88).opacity(0.18)
            }
        }
    }

    private var myCity: String {
        store.currentCity ?? "New York"
    }

    private var featuredFriend: FriendPresence {
        store.friends.first ?? FriendPresence(
            id: UUID(),
            displayName: "Lin Zhao",
            username: "lin",
            city: "Tokyo",
            countryCode: "JP",
            updatedAt: Date().addingTimeInterval(-18 * 60),
            avatarPalette: 1,
            isFavorite: true
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                // Header description
                VStack(spacing: 6) {
                    Text("3D Diorama Widget Studio")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                    Text("Live simulator for iOS 18 Home Screen & StandBy widgets.")
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 12)
                .padding(.horizontal)

                // Solar Ambience Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Solar Ambience (Day/Night Mood)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WIFTheme.secondaryText)
                        .textCase(.uppercase)

                    HStack(spacing: 8) {
                        ForEach(AmbienceTone.allCases) { tone in
                            solarButton(tone)
                        }
                    }
                }
                .padding(.horizontal)

                // Format Picker
                Picker("Format", selection: $selectedTab) {
                    ForEach(WidgetTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Live Widget Display
                VStack(spacing: 10) {
                    Text("iOS 18 Home Screen Preview")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WIFTheme.secondaryText)

                    widgetContainer {
                        switch selectedTab {
                        case .dualOrbit:
                            dualOrbitWidgetView
                                .frame(width: 338, height: 158)
                        case .heroSmall:
                            heroSmallWidgetView
                                .frame(width: 158, height: 158)
                        case .large:
                            constellationLargeWidgetView
                                .frame(width: 338, height: 338)
                        case .together:
                            togetherWidgetView
                                .frame(width: 338, height: 158)
                        }
                    }
                }
                .padding(.top, 6)

                // Design Highlights
                VStack(alignment: .leading, spacing: 14) {
                    Text("Apple HIG Design Highlights")
                        .font(.headline)
                        .foregroundStyle(WIFTheme.primaryText)

                    highlightRow(
                        icon: "sparkles",
                        title: "101 Native 3D City Dioramas",
                        desc: "Rendered at crisp Retina scale on chamfered aluminum & frosted glass pedestals."
                    )
                    highlightRow(
                        icon: "arrow.left.and.right",
                        title: "Dual Orbit 1v1 Connection",
                        desc: "Uncluttered focus on your closest bond, bridging two cities with minimal elegance."
                    )
                    highlightRow(
                        icon: "sun.max.trianglebadge.exclamationmark",
                        title: "10-15% Subtle Solar Edge Halo",
                        desc: "Ambient mood lights up according to destination local sun position."
                    )
                }
                .padding(18)
                .wifGlassSurface(tint: WIFTheme.surface.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .wifAmbientBackground()
        .navigationTitle("Widget Studio")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dualOrbitWidgetView: some View {
        HStack(spacing: 0) {
            // Left: User City Stage
            VStack(spacing: 3) {
                CityEmblemView(city: myCity, countryCode: store.snapshot.currentPresence.countryCode, size: 68)

                Text("Me")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WIFTheme.secondaryText)

                Text(myCity)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selectedAmbience.edgeTint.opacity(0.35))
            )

            // Center Connector
            VStack(spacing: 4) {
                HStack(spacing: 3) {
                    Circle()
                        .fill(WIFTheme.secondaryText.opacity(0.40))
                        .frame(width: 4, height: 4)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    WIFTheme.secondaryText.opacity(0.25),
                                    WIFTheme.fresh.opacity(0.50),
                                    WIFTheme.secondaryText.opacity(0.25)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 32, height: 1.5)
                    Circle()
                        .fill(WIFTheme.fresh.opacity(0.80))
                        .frame(width: 4, height: 4)
                }

                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(WIFTheme.secondaryText.opacity(0.60))
            }
            .padding(.horizontal, 6)

            // Right: Featured Friend
            VStack(spacing: 3) {
                CityEmblemView(city: featuredFriend.city, countryCode: featuredFriend.countryCode, size: 68)

                Text(featuredFriend.displayName.components(separatedBy: " ").first ?? featuredFriend.displayName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WIFTheme.fresh)
                    .lineLimit(1)

                Text(featuredFriend.city ?? "Tokyo")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .padding(10)
    }

    private var heroSmallWidgetView: some View {
        VStack(spacing: 4) {
            HStack {
                Label(myCity, systemImage: "location.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: selectedAmbience.icon)
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer(minLength: 0)

            CityEmblemView(city: myCity, countryCode: store.snapshot.currentPresence.countryCode, size: 68)

            Spacer(minLength: 0)

            HStack(spacing: 3) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 8.5, weight: .bold))
                Text("2 friends around")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
            }
            .foregroundStyle(WIFTheme.fresh)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(WIFTheme.fresh.opacity(0.18))
                    .overlay(Capsule().strokeBorder(WIFTheme.fresh.opacity(0.35), lineWidth: 1))
            )
        }
        .padding(10)
    }

    private var constellationLargeWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Friend Orbit")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                Spacer()
                Text("\(Set(store.friends.compactMap(\.city)).count) cities")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(store.friends.prefix(4)) { friend in
                    VStack(spacing: 2) {
                        CityEmblemView(city: friend.city, countryCode: friend.countryCode, size: 66)
                        Text(friend.displayName.components(separatedBy: " ").first ?? friend.displayName)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WIFTheme.primaryText)
                            .lineLimit(1)
                        Text(friend.city ?? "—")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(WIFTheme.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
    }

    private var togetherWidgetView: some View {
        HStack(spacing: 12) {
            CityEmblemView(city: myCity, countryCode: store.snapshot.currentPresence.countryCode, size: 84)

            VStack(alignment: .leading, spacing: 4) {
                Label("Together in \(myCity)", systemImage: "sparkles")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.fresh)
                    .lineLimit(1)

                Text("You and Mia")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(2)

                Text("2 friends in city now")
                    .font(.caption2)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private func widgetContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.12),
                            Color(white: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)

            content()
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(.horizontal, 16)
    }

    private func solarButton(_ tone: AmbienceTone) -> some View {
        let isSelected = selectedAmbience == tone
        return Button {
            selectedAmbience = tone
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tone.icon)
                    .font(.caption2.weight(.bold))
                Text(tone.rawValue)
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? tone.edgeTint.opacity(0.8) : Color.white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? WIFTheme.fresh : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? WIFTheme.primaryText : WIFTheme.secondaryText)
        }
        .buttonStyle(.plain)
    }

    private func highlightRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(WIFTheme.fresh)
                .frame(width: 32, height: 32)
                .background(WIFTheme.fresh.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(WIFTheme.primaryText)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
        }
    }
}

#Preview {
    NavigationStack { ProfileView(onReplayOnboarding: {}) }
        .environmentObject(AppStore())
        .environmentObject(CityLocationService())
        .environmentObject(WIFAppearanceController())
}
