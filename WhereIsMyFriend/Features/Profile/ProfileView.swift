import CoreLocation
import SwiftUI
import UIKit
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    let onReplayOnboarding: () -> Void
    @State private var showsDeleteConfirmation = false
    @State private var showsSignOutConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader

                sectionLabel("Sharing").padding(.top, 24)
                settingsGroup {
                    NavigationLink { SharingSummaryView() } label: {
                        settingRow(
                            "City sharing",
                            note: store.snapshot.sharingPreferences.citySharingEnabled
                                ? "Visible to accepted friends" : "Paused",
                            symbol: "location.circle.fill",
                            color: WIFTheme.fresh
                        )
                    }
                    .buttonStyle(.plain)
                    divider
                    NavigationLink { LocationAccessView() } label: {
                        settingRow("Location access", note: "Foreground and background controls", symbol: "gearshape.fill", color: WIFTheme.fresh)
                    }
                    .buttonStyle(.plain)
                    divider
                    NavigationLink { NotificationSettingsView() } label: {
                        settingRow("Notifications", note: "Permissions and moment history", symbol: "bell.fill", color: WIFTheme.fresh)
                    }
                    .buttonStyle(.plain)
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
        .background(WIFTheme.canvas)
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
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
                 : "The server will delete your account, friendships, preferences and current city presence.")
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
                Text(profilePresenceText)
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var profilePresenceText: String {
        guard let city = store.currentCity else { return "No shared city" }
        return "\(city) · \(store.snapshot.syncState.rawValue)"
    }

    private var buildFooter: String {
        let mode = store.repositoryMode == .localDemo ? "Local Demo Repository" : "Remote API"
        return "Development build · \(mode)\nNo precise coordinates or route history are stored"
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
            .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius))
            .overlay {
                RoundedRectangle(cornerRadius: WIFTheme.mediumRadius).stroke(WIFTheme.border, lineWidth: 1)
            }
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

private struct SharingSummaryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            LabeledContent("Shared city", value: store.snapshot.currentPresence.cityDisplay)
            LabeledContent("Accepted friends", value: "\(store.friends.count)")
            LabeledContent("Global sharing", value: store.snapshot.sharingPreferences.citySharingEnabled ? "On" : "Paused")
            LabeledContent("Stored precision", value: "City only")
            LabeledContent("History retention", value: "Current city only")
        }
        .navigationTitle("City sharing")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LocationAccessView: View {
    @EnvironmentObject private var locationService: CityLocationService

    var body: some View {
        List {
            Section {
                LabeledContent("Authorization", value: authorizationText)
                Button("Request current city") { locationService.requestForegroundCity() }
                Button("Enable background city changes") { locationService.requestBackgroundUpdates() }
            }
            Section {
                Button("Open iOS Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            } footer: {
                Text("The app requests coarse, city-level use. iOS controls when background Visits and significant changes arrive.")
            }
        }
        .navigationTitle("Location access")
        .navigationBarTitleDisplayMode(.inline)
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
}

private struct NotificationSettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section {
                LabeledContent("Authorization", value: authorizationText)
                Button("Allow notifications") {
                    Task { await store.notificationService.requestAuthorization() }
                }
            }
            Section {
                NavigationLink("View same-city history") { NotificationHistoryView() }
            } footer: {
                Text("The local demo schedules a real local notification. Production will create the same idempotent event on the server and deliver it through APNs.")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var authorizationText: String {
        switch store.notificationService.authorizationStatus {
        case .notDetermined: "Not requested"
        case .denied: "Denied"
        case .authorized: "Allowed"
        case .provisional: "Provisional"
        case .ephemeral: "Temporary"
        @unknown default: "Unknown"
        }
    }
}

private struct BlockedPeopleView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ContentUnavailableView {
            Label("No blocked people", systemImage: "person.crop.circle.badge.checkmark")
        } description: {
            Text("Blocked users cannot invite you or access your presence.")
        }
        .navigationTitle("Blocked people")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyDataView: View {
    var body: some View {
        List {
            privacyRow("Stored", detail: "Account identity, accepted friendships, sharing choices, current city and update time")
            privacyRow("Never stored", detail: "Precise coordinates, routes, location history or contact book")
            privacyRow("Widget", detail: "Accepted friends’ last-known cities in an App Group cache")
            privacyRow("Deletion", detail: "Local data is removed immediately; production calls the account deletion endpoint")
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

#Preview {
    NavigationStack { ProfileView(onReplayOnboarding: {}) }
        .environmentObject(AppStore())
        .environmentObject(CityLocationService())
}
