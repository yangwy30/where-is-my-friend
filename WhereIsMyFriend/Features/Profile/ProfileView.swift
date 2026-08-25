import CoreLocation
import SwiftUI
import UIKit
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    let onReplayOnboarding: () -> Void
    let onOpenCitySharing: () -> Void
    @State private var showsDeleteConfirmation = false
    @State private var showsSignOutConfirmation = false
    @State private var showsEditProfile = false

    init(
        onReplayOnboarding: @escaping () -> Void,
        onOpenCitySharing: @escaping () -> Void = {}
    ) {
        self.onReplayOnboarding = onReplayOnboarding
        self.onOpenCitySharing = onOpenCitySharing
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader

                if connectionNeedsAttention {
                    sectionLabel("Connection").padding(.top, 24)
                    settingsGroup {
                        Button {
                            Task { await store.retryPendingOperations() }
                        } label: {
                            settingRow(
                                "Finish syncing",
                                note: connectionStatusText,
                                symbol: "arrow.triangle.2.circlepath",
                                color: WIFTheme.fresh
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isWorking)
                    }
                }

                sectionLabel("Location & Sharing").padding(.top, 24)
                settingsGroup {
                    Button(action: onOpenCitySharing) {
                        settingRow(
                            "City sharing",
                            note: store.snapshot.sharingPreferences.citySharingEnabled
                                ? LocalizedStringKey(store.snapshot.currentPresence.cityDisplay) : "Paused",
                            symbol: "location.circle.fill",
                            color: WIFTheme.fresh
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("profileCitySharingButton")
                    divider
                    NavigationLink { LocationAccessView() } label: {
                        settingRow(
                            "Location & automatic updates",
                            note: store.snapshot.sharingPreferences.backgroundUpdatesEnabled
                                ? "Automatic updates on" : "Automatic updates off",
                            symbol: "location.viewfinder",
                            color: WIFTheme.fresh
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("locationAccessLink")
                }

                sectionLabel("Alerts & Display").padding(.top, 24)
                settingsGroup {
                    NavigationLink {
                        NotificationSettingsView(notificationService: store.notificationService)
                    } label: {
                        settingRow("Notifications", note: "Permissions and moment history", symbol: "bell.fill", color: WIFTheme.fresh)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("notificationSettingsLink")
                    divider
                    NavigationLink { WidgetPrivacyView() } label: {
                        settingRow(
                            "Widget & Lock Screen",
                            note: widgetPrivacySummary,
                            symbol: "rectangle.3.group.bubble.left.fill",
                            color: WIFTheme.fresh
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("widgetPrivacySettingsLink")
                }

                sectionLabel("Privacy").padding(.top, 24)
                settingsGroup {
                    NavigationLink { BlockedPeopleView() } label: {
                        settingRow("Blocked people", note: "\(store.snapshot.blockedUserIDs.count)", symbol: "person.crop.circle.badge.xmark", color: WIFTheme.fresh)
                    }
                    .buttonStyle(.plain)
                    divider
                    NavigationLink { PrivacyDataView() } label: {
                        settingRow("Privacy & data", note: "City-level presence only", symbol: "hand.raised.fill", color: WIFTheme.fresh)
                    }
                    .buttonStyle(.plain)
                }

                if store.repositoryMode == .localDemo {
                    sectionLabel("Development").padding(.top, 24)
                    settingsGroup {
                        NavigationLink { CityEmblemGalleryView() } label: {
                            settingRow("City Emblem Gallery", note: "Browse 150+ 3D city landmarks", symbol: "building.2.crop.circle.fill", color: WIFTheme.fresh)
                        }
                        .buttonStyle(.plain)
                        divider
                        NavigationLink { DemoLabView() } label: {
                            settingRow("Demo Lab", note: "Simulate invites, stale data and alerts", symbol: "testtube.2", color: WIFTheme.fresh)
                        }
                        .buttonStyle(.plain)
                        divider
                        Button(action: onReplayOnboarding) {
                            settingRow("Preview onboarding", note: nil, symbol: "sparkles", color: WIFTheme.fresh)
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionLabel("Account").padding(.top, 24)
                settingsGroup {
                    Button { showsSignOutConfirmation = true } label: {
                        settingRow("Sign out", note: nil, symbol: "rectangle.portrait.and.arrow.right", color: WIFTheme.primaryText)
                    }
                    .buttonStyle(.plain)
                    divider
                    Button(role: .destructive) { showsDeleteConfirmation = true } label: {
                        settingRow("Delete account", note: nil, symbol: "trash.fill", color: WIFTheme.destructive, isDestructive: true)
                    }
                    .buttonStyle(.plain)
                }

                Text(buildFooter)
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 30)
        }
        .wifAmbientBackground()
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showsEditProfile = true }
                    .accessibilityIdentifier("editProfileButton")
            }
        }
        .sheet(isPresented: $showsEditProfile) {
            EditProfileView()
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
        HStack(spacing: 14) {
            Text(store.snapshot.currentUser.initials)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(
                    LinearGradient(
                        colors: [.mint.opacity(0.82), .teal.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(store.snapshot.currentUser.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("@\(store.snapshot.currentUser.username)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WIFTheme.fresh)
                    .textSelection(.enabled)
                Text(profilePresenceText)
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .wifGlassSurface(
            tint: WIFTheme.fresh.opacity(0.12),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .padding(.top, 8)
    }

    private var profilePresenceText: String {
        guard store.currentCity != nil else { return "No shared city" }
        return store.snapshot.currentPresence.cityDisplay
    }

    private var widgetPrivacySummary: LocalizedStringKey {
        switch store.widgetPrivacyMode {
        case .full: "Names and cities visible"
        case .hideNames: "Names hidden"
        case .hideAll: "Everything hidden"
        }
    }

    private var buildFooter: String {
        if store.repositoryMode == .localDemo {
            return "Local demo · No precise coordinates or route history are stored"
        }
        return "No precise coordinates or route history are stored"
    }

    private var connectionNeedsAttention: Bool {
        store.repositoryMode == .remote
            && (store.snapshot.syncState == .offline || store.pendingOperationCount > 0)
    }

    private var connectionStatusText: LocalizedStringKey {
        if store.pendingOperationCount > 0 {
            return "\(store.pendingOperationCount) change(s) waiting for a connection"
        }
        return "Reconnect to refresh your friends"
    }

    private func sectionLabel(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(1.1)
            .foregroundStyle(WIFTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 3)
            .padding(.bottom, 8)
    }

    private func settingsGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .wifGlassSurface(
                tint: WIFTheme.surface.opacity(0.08),
                in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius, style: .continuous)
            )
    }

    private var divider: some View {
        Divider().overlay(WIFTheme.border).padding(.leading, 52)
    }

    private func settingRow(
        _ title: LocalizedStringKey,
        note: LocalizedStringKey?,
        symbol: String,
        color: Color,
        isDestructive: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isDestructive ? WIFTheme.destructive : WIFTheme.primaryText)
                if let note {
                    Text(note).font(.caption).foregroundStyle(WIFTheme.secondaryText)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WIFTheme.secondaryText)
        }
        .padding(15)
        .contentShape(Rectangle())
    }
}

private struct LocationAccessView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationService: CityLocationService
    @State private var pendingBackgroundUpdates: Bool?

    var body: some View {
        List {
            Section {
                Toggle("Update city automatically", isOn: backgroundUpdatesBinding)
                    .disabled(store.isWorking)
                    .accessibilityIdentifier("backgroundUpdatesToggle")
            } header: {
                Text("Automatic updates")
            } footer: {
                Text("When enabled, iOS can update your city after significant location changes. Precise coordinates are resolved on this iPhone and are not uploaded.")
            }

            Section {
                LabeledContent("Authorization", value: authorizationText)
                Button("Update current city") { locationService.requestForegroundCity() }
                    .disabled(locationService.isResolving)
                Button("Open iOS Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            } header: {
                Text("Location access")
            } footer: {
                Text(locationPermissionFooter)
            }

            if let errorMessage = locationService.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(WIFTheme.destructive)
                }
            }
        }
        .navigationTitle("Location & updates")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("locationAccessScreen")
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
        List {
            Section {
                privacyChoice(
                    mode: .full,
                    title: "Show names and cities",
                    note: "Friend names and shared cities are visible."
                )
                privacyChoice(
                    mode: .hideNames,
                    title: "Hide names",
                    note: "Cities stay visible, but names and initials are hidden."
                )
                privacyChoice(
                    mode: .hideAll,
                    title: "Hide everything",
                    note: "Widgets show a private placeholder."
                )
            } header: {
                Text("Visible details")
            } footer: {
                Text("This controls Where Is My Friend widgets on the Home Screen and Lock Screen. iOS may apply additional privacy redaction while your iPhone is locked.")
            }
        }
        .navigationTitle("Widget & Lock Screen")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("widgetPrivacyScreen")
    }

    private func privacyChoice(
        mode: WidgetPrivacyMode,
        title: LocalizedStringKey,
        note: LocalizedStringKey
    ) -> some View {
        Button {
            store.setWidgetPrivacyMode(mode)
        } label: {
            HStack(spacing: 12) {
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
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(widgetPrivacyIdentifier(for: mode))
        .accessibilityValue(store.widgetPrivacyMode == mode ? "selected" : "not selected")
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
            VStack(spacing: 18) {
                notificationHeader
                sameCityAlertCard

                if alertsEnabled {
                    permissionCard
                    deviceRegistrationCard
                }

                NavigationLink {
                    NotificationHistoryView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(WIFTheme.fresh)
                            .frame(width: 42, height: 42)
                            .background(WIFTheme.fresh.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 3) {
                            Text("View same-city history")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(WIFTheme.primaryText)
                            Text("Every same-city moment stays available here.")
                                .font(.caption)
                                .foregroundStyle(WIFTheme.secondaryText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                    .padding(16)
                    .wifGlassSurface(
                        tint: WIFTheme.surface.opacity(0.08),
                        interactive: true,
                        in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                Text(footerText)
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.top, 10)
            .padding(.bottom, 30)
        }
        .wifAmbientBackground()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("notificationSettingsScreen")
    }

    private var sameCityAlertCard: some View {
        Toggle(isOn: sameCityAlertsBinding) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Same-city notifications")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                Text("Get an alert when you and an allowed friend overlap")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(WIFTheme.fresh)
        .padding(16)
        .disabled(store.isWorking)
        .wifGlassSurface(
            tint: WIFTheme.fresh.opacity(0.10),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityIdentifier("sameCityNotificationsToggle")
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

    private var notificationHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: isReady ? "bell.badge.fill" : "bell.and.waves.left.and.right.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(isReady ? WIFTheme.fresh : WIFTheme.secondaryText)
                .frame(width: 74, height: 74)
                .background(
                    (isReady ? WIFTheme.fresh : WIFTheme.elevatedSurface).opacity(0.18),
                    in: Circle()
                )
                .contentTransition(.symbolEffect(.replace))

            VStack(spacing: 5) {
                Text(headerTitle)
                    .font(.title2.bold())
                    .foregroundStyle(WIFTheme.primaryText)
                Text(headerDetail)
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: isReady)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                statusIcon(
                    symbol: permissionSymbol,
                    color: permissionColor,
                    showsProgress: false
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notification permission")
                        .font(.headline)
                        .foregroundStyle(WIFTheme.primaryText)
                    Text(permissionDetail)
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                statusPill(permissionStatusText, color: permissionColor)
            }

            if notificationService.authorizationStatus == .notDetermined {
                Button {
                    Task { await store.requestNotificationAuthorization() }
                } label: {
                    Label("Allow notifications", systemImage: "bell.badge")
                        .frame(maxWidth: .infinity)
                }
                .wifGlassButton(tint: WIFTheme.fresh.opacity(0.28), prominent: true)
                .disabled(store.pushRegistrationState.isInProgress)
                .accessibilityIdentifier("allowNotificationsButton")
            } else if notificationService.authorizationStatus == .denied {
                Button(action: openNotificationSettings) {
                    Label("Open iOS Settings", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity)
                }
                .wifGlassButton(tint: Color.orange.opacity(0.16))
                .accessibilityIdentifier("openNotificationSettingsButton")
            }
        }
        .padding(16)
        .wifGlassSurface(
            tint: permissionColor.opacity(0.10),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityIdentifier("notificationPermissionCard")
    }

    private var deviceRegistrationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                statusIcon(
                    symbol: deviceSymbol,
                    color: deviceColor,
                    showsProgress: store.pushRegistrationState.isInProgress
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text("This iPhone")
                        .font(.headline)
                        .foregroundStyle(WIFTheme.primaryText)
                    Text(deviceDetail)
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                statusPill(deviceStatusText, color: deviceColor)
            }

            if case .registered(let date) = store.pushRegistrationState {
                Divider().overlay(WIFTheme.border)
                LabeledContent("Last registered") {
                    Text(date, style: .relative)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                .font(.caption)
            } else if canRetryDeviceRegistration {
                Button {
                    Task { await store.retryPushRegistration() }
                } label: {
                    Label(deviceActionTitle, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .wifGlassButton(tint: WIFTheme.fresh.opacity(0.18))
                .disabled(store.pushRegistrationState.isInProgress)
                .accessibilityIdentifier("retryPushRegistrationButton")
            }
        }
        .padding(16)
        .wifGlassSurface(
            tint: deviceColor.opacity(0.10),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .animation(.easeInOut(duration: 0.25), value: store.pushRegistrationState)
        .accessibilityIdentifier("devicePushRegistrationCard")
    }

    private func statusIcon(symbol: String, color: Color, showsProgress: Bool) -> some View {
        ZStack {
            Circle().fill(color.opacity(0.13))
            if showsProgress {
                ProgressView().tint(color)
            } else {
                Image(systemName: symbol)
                    .font(.body.weight(.bold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: 42, height: 42)
    }

    private func statusPill(_ text: LocalizedStringKey, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var isReady: Bool {
        guard alertsEnabled else { return false }
        guard notificationService.allowsNotifications else { return false }
        if case .registered = store.pushRegistrationState { return true }
        return false
    }

    private var headerTitle: LocalizedStringKey {
        if !alertsEnabled { return "Same-city alerts are off" }
        return isReady ? "Notifications are ready" : "Complete notification setup"
    }

    private var headerDetail: LocalizedStringKey {
        if !alertsEnabled {
            return "Same-city moments still remain available in your history."
        }
        return isReady
            ? "This iPhone is ready for same-city alerts."
            : "Two quick checks make sure same-city alerts can reach you."
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

    private var deviceStatusText: LocalizedStringKey {
        guard notificationService.allowsNotifications else { return "Waiting" }
        return switch store.pushRegistrationState {
        case .notStarted: "Not registered"
        case .waitingForDeviceToken: "Connecting"
        case .registering: "Registering"
        case .waitingForNetwork: "Waiting for network"
        case .registered: "Ready"
        case .failed: "Needs attention"
        }
    }

    private var deviceDetail: LocalizedStringKey {
        guard notificationService.allowsNotifications else {
            return "Allow notifications before registering this iPhone."
        }
        return switch store.pushRegistrationState {
        case .notStarted: "Register this iPhone to receive remote same-city alerts."
        case .waitingForDeviceToken: "Requesting a secure notification token from Apple."
        case .registering: "Saving this iPhone with your account."
        case .waitingForNetwork: "Registration will finish automatically when your connection returns."
        case .registered: "This iPhone can receive remote same-city alerts."
        case .failed: "Registration needs attention. Your account and other features still work."
        }
    }

    private var deviceSymbol: String {
        guard notificationService.allowsNotifications else { return "iphone" }
        return switch store.pushRegistrationState {
        case .registered: "checkmark"
        case .failed: "exclamationmark"
        case .waitingForNetwork: "wifi.slash"
        default: "iphone"
        }
    }

    private var deviceColor: Color {
        guard notificationService.allowsNotifications else { return WIFTheme.secondaryText }
        return switch store.pushRegistrationState {
        case .registered: WIFTheme.fresh
        case .failed: .orange
        case .waitingForNetwork: .orange
        default: WIFTheme.secondaryText
        }
    }

    private var canRetryDeviceRegistration: Bool {
        guard notificationService.allowsNotifications else { return false }
        return switch store.pushRegistrationState {
        case .notStarted, .waitingForNetwork, .failed: true
        case .waitingForDeviceToken, .registering, .registered: false
        }
    }

    private var deviceActionTitle: LocalizedStringKey {
        store.pushRegistrationState == .notStarted ? "Register this iPhone" : "Try again"
    }

    private var footerText: LocalizedStringKey {
        if !alertsEnabled {
            return "Turn on same-city notifications whenever you want alerts again."
        }
        return store.repositoryMode == .localDemo
            ? "Demo mode schedules same-city alerts directly on this iPhone."
            : "Same-city moments always appear in history. Remote alerts arrive when this iPhone is registered and notification delivery is available."
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct BlockedPeopleView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.snapshot.blockedPeople.isEmpty {
                ContentUnavailableView {
                    Label("No blocked people", systemImage: "person.crop.circle.badge.checkmark")
                } description: {
                    Text("Blocked users cannot invite you or access your presence.")
                }
            } else {
                List(store.snapshot.blockedPeople) { person in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(WIFTheme.fresh.opacity(0.16))
                            .frame(width: 42, height: 42)
                            .overlay {
                                Text(initials(for: person.displayName))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(WIFTheme.fresh)
                            }
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
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Blocked people")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func initials(for name: String) -> String {
        String(name.split(separator: " ").prefix(2).compactMap(\.first))
    }
}

private struct PrivacyDataView: View {
    var body: some View {
        List {
            Section {
                privacyRow("Stored", detail: "Account identity, accepted friendships, sharing choices, current city and update time")
                privacyRow("Never stored", detail: "Precise coordinates, routes, location history or contact book")
                privacyRow("Widget", detail: "Accepted friends’ last-known cities in an App Group cache")
                privacyRow("Deletion", detail: "Deleting your account removes server account data, the local session and Widget cache")
            }

            Section {
                Link(destination: PrivacyPolicyConfiguration.url()) {
                    Label("View Privacy Policy", systemImage: "doc.text.magnifyingglass")
                }
                .accessibilityIdentifier("privacyPolicyLink")
            } footer: {
                Text("The public policy explains data collection, service providers, retention and your choices.")
            }
        }
        .navigationTitle("Privacy & data")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func privacyRow(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline)
            Text(detail).font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
        }
        .padding(.vertical, 5)
    }
}

private struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var displayName = ""
    @State private var username = ""
    @State private var avatarPalette = 1
    @State private var validationMessage: String?

    private let paletteColors: [Color] = [.pink, .mint, .purple, .orange, .gray, .blue, .teal]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Display name", text: $displayName)
                        .textContentType(.name)
                        .accessibilityIdentifier("displayNameField")
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .accessibilityIdentifier("profileUsernameField")
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Usernames use 3–20 lowercase letters, numbers, or underscores.")
                }

                Section("Avatar color") {
                    HStack {
                        ForEach(paletteColors.indices, id: \.self) { index in
                            Button {
                                avatarPalette = index
                            } label: {
                                Circle()
                                    .fill(paletteColors[index].gradient)
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if avatarPalette == index {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Avatar color \(index + 1)")
                        }
                    }
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(WIFTheme.destructive)
                    }
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(store.isWorking)
                        .accessibilityIdentifier("saveProfileButton")
                }
            }
            .onAppear {
                displayName = store.snapshot.currentUser.displayName
                username = store.snapshot.currentUser.username
                avatarPalette = store.snapshot.currentUser.avatarPalette
            }
        }
    }

    private func save() {
        let update = ProfileUpdate(
            displayName: displayName,
            username: username,
            avatarPalette: avatarPalette
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

#Preview {
    NavigationStack { ProfileView(onReplayOnboarding: {}) }
        .environmentObject(AppStore())
        .environmentObject(CityLocationService())
}
