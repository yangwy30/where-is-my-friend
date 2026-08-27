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
        List {
            Section {
                profileHeader
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            if connectionNeedsAttention {
                Section("Connection") {
                    Button {
                        Task { await store.retryPendingOperations() }
                    } label: {
                        settingsLabel(
                            "Finish syncing",
                            symbol: "arrow.triangle.2.circlepath",
                            color: WIFTheme.fresh,
                            value: connectionStatusText
                        )
                    }
                    .disabled(store.isWorking)
                }
            }

            Section("Location & Sharing") {
                Button(action: onOpenCitySharing) {
                    settingsLabel(
                        "City sharing",
                        symbol: "location.fill",
                        color: WIFTheme.fresh,
                        value: store.snapshot.sharingPreferences.citySharingEnabled
                            ? LocalizedStringKey(store.snapshot.currentPresence.cityDisplay)
                            : "Paused",
                        showsDisclosure: true
                    )
                }
                .accessibilityIdentifier("profileCitySharingButton")

                NavigationLink { LocationAccessView() } label: {
                    settingsLabel(
                        "Location & automatic updates",
                        symbol: "location.viewfinder",
                        color: WIFTheme.fresh,
                        value: store.snapshot.sharingPreferences.backgroundUpdatesEnabled
                            ? "Automatic updates on"
                            : "Automatic updates off"
                    )
                }
                .accessibilityIdentifier("locationAccessLink")
            }

            Section("Alerts & Display") {
                NavigationLink {
                    NotificationSettingsView(notificationService: store.notificationService)
                } label: {
                    settingsLabel(
                        "Notifications",
                        symbol: "bell.fill",
                        color: .red,
                        value: notificationSummary
                    )
                }
                .accessibilityIdentifier("notificationSettingsLink")

                NavigationLink { WidgetPrivacyView() } label: {
                    settingsLabel(
                        "Widget & Lock Screen",
                        symbol: "rectangle.3.group.fill",
                        color: .indigo,
                        value: widgetPrivacySummary
                    )
                }
                .accessibilityIdentifier("widgetPrivacySettingsLink")
            }

            Section("Privacy") {
                NavigationLink { BlockedPeopleView() } label: {
                    settingsLabel(
                        "Blocked people",
                        symbol: "person.crop.circle.badge.xmark",
                        color: .gray,
                        value: "\(store.snapshot.blockedUserIDs.count)"
                    )
                }

                NavigationLink { PrivacyDataView() } label: {
                    settingsLabel(
                        "Privacy & data",
                        symbol: "hand.raised.fill",
                        color: .blue
                    )
                }
            }

            if store.repositoryMode == .localDemo {
                Section("Development") {
                    NavigationLink { CityEmblemGalleryView() } label: {
                        settingsLabel(
                            "City Emblem Gallery",
                            symbol: "building.2.crop.circle.fill",
                            color: WIFTheme.fresh
                        )
                    }

                    NavigationLink { DemoLabView() } label: {
                        settingsLabel(
                            "Demo Lab",
                            symbol: "testtube.2",
                            color: .purple
                        )
                    }

                    Button(action: onReplayOnboarding) {
                        settingsLabel(
                            "Preview onboarding",
                            symbol: "sparkles",
                            color: .orange
                        )
                    }
                }
            }

            Section {
                Button("Sign out", role: .destructive) {
                    showsSignOutConfirmation = true
                }
                Button("Delete account", role: .destructive) {
                    showsDeleteConfirmation = true
                }
            } header: {
                Text("Account")
            } footer: {
                Text(buildFooter)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .accessibilityIdentifier("profileSettingsScreen")
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
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

    private var notificationSummary: LocalizedStringKey {
        guard store.snapshot.sharingPreferences.notificationPreviewEnabled else {
            return "Paused"
        }
        return store.notificationService.allowsNotifications ? "Allowed" : "Needs attention"
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

    private func settingsLabel(
        _ title: LocalizedStringKey,
        symbol: String,
        color: Color,
        value: LocalizedStringKey? = nil,
        showsDisclosure: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(title)

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
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
        .listStyle(.insetGrouped)
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
        .listStyle(.insetGrouped)
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
        List {
            Section {
                Toggle(isOn: sameCityAlertsBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Same-city notifications")
                        Text("Get an alert when you and an allowed friend overlap")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(WIFTheme.fresh)
                .disabled(store.isWorking)
                .accessibilityIdentifier("sameCityNotificationsToggle")
            } header: {
                Text("Same-city notifications")
            } footer: {
                Text(alertsEnabled
                     ? "Same-city moments still remain available in your history."
                     : "Turn on same-city notifications whenever you want alerts again.")
            }

            if alertsEnabled {
                Section {
                    permissionStatusRow

                    if notificationService.authorizationStatus == .notDetermined {
                        Button("Allow notifications") {
                            Task { await store.requestNotificationAuthorization() }
                        }
                        .disabled(store.pushRegistrationState.isInProgress)
                        .accessibilityIdentifier("allowNotificationsButton")
                    } else if notificationService.authorizationStatus == .denied {
                        Button("Open iOS Settings", action: openNotificationSettings)
                            .accessibilityIdentifier("openNotificationSettingsButton")
                    }

                    deviceStatusRow

                    if case .registered(let date) = store.pushRegistrationState {
                        LabeledContent("Last registered") {
                            Text(date, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    } else if canRetryDeviceRegistration {
                        Button(deviceActionTitle) {
                            Task { await store.retryPushRegistration() }
                        }
                        .disabled(store.pushRegistrationState.isInProgress)
                        .accessibilityIdentifier("retryPushRegistrationButton")
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text(footerText)
                }
            }

            Section {
                NavigationLink {
                    NotificationHistoryView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("View same-city history")
                            Text("Every same-city moment stays available here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(WIFTheme.fresh)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("notificationSettingsScreen")
    }

    private var permissionStatusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: permissionSymbol)
                .foregroundStyle(permissionColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text("Notification permission")
                Text(permissionDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(permissionStatusText)
                .font(.subheadline)
                .foregroundStyle(permissionColor)
        }
        .accessibilityIdentifier("notificationPermissionCard")
    }

    private var deviceStatusRow: some View {
        HStack(spacing: 12) {
            if store.pushRegistrationState.isInProgress {
                ProgressView()
                    .frame(width: 22)
            } else {
                Image(systemName: deviceSymbol)
                    .foregroundStyle(deviceColor)
                    .frame(width: 22)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("This iPhone")
                Text(deviceDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(deviceStatusText)
                .font(.subheadline)
                .foregroundStyle(deviceColor)
        }
        .accessibilityIdentifier("devicePushRegistrationCard")
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
