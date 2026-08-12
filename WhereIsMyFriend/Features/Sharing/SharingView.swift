import CoreLocation
import SwiftUI
import UIKit

struct SharingView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationService: CityLocationService
    @State private var showsCityPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                sharingIllustration

                Text("City changes only")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("Friends see your latest city and update time. Precise coordinates and route history stay out of the product.")
                    .font(.body)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 10)
                    .padding(.horizontal, 8)

                statusCard.padding(.top, 24)
                controls.padding(.top, 16)
                locationActions.padding(.top, 16)
                widgetPrivacy.padding(.top, 16)

                if let errorMessage = locationService.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(WIFTheme.destructive)
                        .padding(.top, 14)
                }

                Label("You can pause sharing at any time.", systemImage: "hand.raised.fill")
                    .font(.footnote)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 18)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 30)
        }
        .background(WIFTheme.canvas)
        .navigationTitle("Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsCityPicker) {
            CityPickerView { city, countryCode in
                Task {
                    await store.updateCurrentCity(city: city, countryCode: countryCode, source: .manual)
                }
            }
        }
        .accessibilityIdentifier("sharingScreen")
    }

    private var controls: some View {
        VStack(spacing: 0) {
            Toggle(isOn: citySharingBinding) {
                settingLabel("City sharing", note: "Visible only to accepted friends you allow")
            }
            .tint(WIFTheme.fresh)
            .padding(15)
            .disabled(store.isWorking)
            .accessibilityIdentifier("citySharingToggle")

            Divider().overlay(WIFTheme.border).padding(.leading, 15)

            Toggle(isOn: backgroundUpdatesBinding) {
                settingLabel("Background updates", note: backgroundPermissionNote)
            }
            .tint(WIFTheme.fresh)
            .padding(15)
            .disabled(store.isWorking)
            .accessibilityIdentifier("backgroundUpdatesToggle")

            Divider().overlay(WIFTheme.border).padding(.leading, 15)

            Toggle(isOn: notificationPreviewBinding) {
                settingLabel("Same-city notifications", note: "Respects each friend’s alert preference")
            }
            .tint(WIFTheme.fresh)
            .padding(15)
            .disabled(store.isWorking)
        }
        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius))
        .overlay {
            RoundedRectangle(cornerRadius: WIFTheme.mediumRadius).stroke(WIFTheme.border, lineWidth: 1)
        }
    }

    private var locationActions: some View {
        VStack(spacing: 10) {
            Button {
                showsCityPicker = true
            } label: {
                Label("Choose a test city", systemImage: "building.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(WIFTheme.fresh)
            .accessibilityIdentifier("chooseCityButton")

            Button {
                locationService.requestForegroundCity()
            } label: {
                HStack {
                    if locationService.isResolving { ProgressView().controlSize(.small) }
                    Label("Use my current city", systemImage: "location.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(WIFTheme.fresh)
            .disabled(locationService.isResolving)
            .accessibilityIdentifier("useCurrentCityButton")
        }
    }

    private var widgetPrivacy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Lock Screen & Widget privacy", systemImage: "rectangle.3.group.bubble.left.fill")
                .font(.headline)
                .foregroundStyle(WIFTheme.primaryText)
            Menu {
                Button("Show names and cities") { store.setWidgetPrivacyMode(.full) }
                    .accessibilityIdentifier("widgetPrivacyFull")
                Button("Hide names") { store.setWidgetPrivacyMode(.hideNames) }
                    .accessibilityIdentifier("widgetPrivacyHideNames")
                Button("Hide everything") { store.setWidgetPrivacyMode(.hideAll) }
                    .accessibilityIdentifier("widgetPrivacyHideAll")
            } label: {
                HStack {
                    Text("Widget details")
                    Spacer()
                    Text(widgetPrivacyModeTitle)
                        .foregroundStyle(WIFTheme.secondaryText)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
            }
            .accessibilityIdentifier("widgetPrivacyPicker")
            .accessibilityValue(store.widgetPrivacyMode.rawValue)
            Text(widgetPrivacyDescription)
                .font(.caption)
                .foregroundStyle(WIFTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius))
        .overlay {
            RoundedRectangle(cornerRadius: WIFTheme.mediumRadius).stroke(WIFTheme.border, lineWidth: 1)
        }
    }

    private var widgetPrivacyModeTitle: LocalizedStringKey {
        switch store.widgetPrivacyMode {
        case .full: "Show names and cities"
        case .hideNames: "Hide names"
        case .hideAll: "Hide everything"
        }
    }

    private var widgetPrivacyDescription: LocalizedStringKey {
        switch store.widgetPrivacyMode {
        case .full: "Friend names and shared cities appear on the Home Screen."
        case .hideNames: "Cities remain visible, but friend names and initials are hidden."
        case .hideAll: "The Widget shows only a private placeholder until you change this setting."
        }
    }

    private var sharingIllustration: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(WIFTheme.eventGradient)
                .frame(height: 230)

            Circle()
                .stroke(WIFTheme.fresh.opacity(0.32), style: StrokeStyle(lineWidth: 3, dash: [7, 8]))
                .frame(width: 210, height: 135)
                .rotationEffect(.degrees(-11))

            Image(systemName: "location.fill.viewfinder")
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(WIFTheme.fresh)
                .symbolRenderingMode(.hierarchical)

            Text((store.currentCity ?? "NO CITY").uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(WIFTheme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(WIFTheme.surface, in: Capsule())
                .offset(x: 78, y: -75)
                .lineLimit(1)
        }
        .accessibilityHidden(true)
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: store.snapshot.sharingPreferences.citySharingEnabled
                  ? "checkmark.circle.fill" : "pause.circle.fill")
                .font(.title2)
                .foregroundStyle(store.snapshot.sharingPreferences.citySharingEnabled
                                 ? WIFTheme.fresh : WIFTheme.secondaryText)

            VStack(alignment: .leading, spacing: 3) {
                Text(store.snapshot.sharingPreferences.citySharingEnabled ? "Sharing is on" : "Sharing is paused")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            Spacer()
        }
        .padding(15)
        .background(WIFTheme.freshSurface, in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius))
    }

    private var statusText: String {
        guard store.snapshot.sharingPreferences.citySharingEnabled else {
            return "Friends cannot see your city"
        }
        guard let city = store.currentCity else { return "Choose a city to start sharing" }
        let update = store.snapshot.currentPresence.updatedAt?.formatted(date: .omitted, time: .shortened) ?? "—"
        return "\(city) · updated \(update)"
    }

    private var backgroundPermissionNote: LocalizedStringKey {
        switch locationService.authorizationStatus {
        case .authorizedAlways: "Visits and significant changes enabled"
        case .authorizedWhenInUse: "Enable to request Always access"
        case .denied, .restricted: "Location permission is off"
        case .notDetermined: "Permission will be requested when enabled"
        @unknown default: "Location permission unavailable"
        }
    }

    private var citySharingBinding: Binding<Bool> {
        Binding {
            store.snapshot.sharingPreferences.citySharingEnabled
        } set: { newValue in
            var preferences = store.snapshot.sharingPreferences
            preferences.citySharingEnabled = newValue
            Task { await store.setSharingPreferences(preferences) }
        }
    }

    private var backgroundUpdatesBinding: Binding<Bool> {
        Binding {
            store.snapshot.sharingPreferences.backgroundUpdatesEnabled
        } set: { newValue in
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
            }
        }
    }

    private var notificationPreviewBinding: Binding<Bool> {
        Binding {
            store.snapshot.sharingPreferences.notificationPreviewEnabled
        } set: { newValue in
            var preferences = store.snapshot.sharingPreferences
            preferences.notificationPreviewEnabled = newValue
            Task {
                await store.setSharingPreferences(preferences)
                if newValue { await store.notificationService.requestAuthorization() }
            }
        }
    }

    private func settingLabel(_ title: LocalizedStringKey, note: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.body.weight(.semibold)).foregroundStyle(WIFTheme.primaryText)
            Text(note).font(.caption).foregroundStyle(WIFTheme.secondaryText)
        }
    }
}

private struct CityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (String, String?) -> Void

    private let cities: [(String, String, String)] = [
        ("New York", "US", "🇺🇸"), ("London", "GB", "🇬🇧"), ("Tokyo", "JP", "🇯🇵"),
        ("Toronto", "CA", "🇨🇦"), ("Lisbon", "PT", "🇵🇹"), ("Berlin", "DE", "🇩🇪"),
        ("Seoul", "KR", "🇰🇷"), ("Singapore", "SG", "🇸🇬"), ("Sydney", "AU", "🇦🇺")
    ]

    var body: some View {
        NavigationStack {
            List(cities, id: \.0) { city, code, flag in
                Button {
                    onSelect(city, code)
                    dismiss()
                } label: {
                    HStack {
                        Text(flag).font(.title2)
                        Text(city).foregroundStyle(WIFTheme.primaryText)
                        Spacer()
                    }
                }
            }
            .accessibilityIdentifier("cityPickerScreen")
            .navigationTitle("Choose a test city")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { SharingView() }
        .environmentObject(AppStore())
        .environmentObject(CityLocationService())
}
