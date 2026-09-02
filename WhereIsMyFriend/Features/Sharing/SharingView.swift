import CoreLocation
import SwiftUI
import UIKit

struct CitySharingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationService: CityLocationService
    @State private var pendingSharingEnabled: Bool?
    @State private var pendingBackgroundUpdates: Bool?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    cityHero

                    VStack(spacing: 0) {
                        Toggle(isOn: citySharingBinding) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Share my city")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(WIFTheme.primaryText)
                                Text("Your per-friend visibility choices still apply")
                                    .font(.caption)
                                    .foregroundStyle(WIFTheme.secondaryText)
                            }
                        }
                        .tint(WIFTheme.fresh)
                        .disabled(store.isWorking)
                        .accessibilityIdentifier("citySharingToggle")

                        Divider()
                            .overlay(WIFTheme.border)
                            .padding(.vertical, 14)

                        Toggle(isOn: backgroundUpdatesBinding) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Background updates")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(WIFTheme.primaryText)
                                Text("Automatically keep your city updated as you travel")
                                    .font(.caption)
                                    .foregroundStyle(WIFTheme.secondaryText)
                            }
                        }
                        .tint(WIFTheme.fresh)
                        .disabled(store.isWorking)
                        .accessibilityIdentifier("backgroundUpdatesToggle")
                    }
                    .wifSettingsGlassCard()

                    if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Location access disabled", systemImage: "location.slash.fill")
                                .font(.headline)
                                .foregroundStyle(WIFTheme.destructive)

                            Text("Across Us needs location access to automatically detect your city. Precise coordinates are never stored.")
                                .font(.caption)
                                .foregroundStyle(WIFTheme.secondaryText)

                            Button {
                                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                UIApplication.shared.open(url)
                            } label: {
                                HStack {
                                    Image(systemName: "gear")
                                    Text("Open iOS Settings")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(WIFTheme.fresh)
                            }
                            .padding(.top, 4)
                        }
                        .wifSettingsGlassCard(tint: WIFTheme.destructive.opacity(0.08))
                    }

                    if let errorMessage = locationService.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(WIFTheme.destructive)
                            .wifSettingsGlassCard(tint: WIFTheme.destructive.opacity(0.08))
                    }

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "shield.checkmark.fill")
                            .font(.subheadline)
                            .foregroundStyle(WIFTheme.fresh)

                        Text("Zero precise tracking. Only your coarse city name and update timestamp are shared. Exact GPS coordinates and route history are never uploaded or stored.")
                            .font(.footnote)
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 20)
                }
                .padding(WIFTheme.screenInset)
            }
            .scrollIndicators(.hidden)
            .wifAmbientBackground()
            .navigationTitle("City sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.68), .large])
        .presentationDragIndicator(.visible)
        .accessibilityIdentifier("citySharingSheet")
    }

    private var cityHero: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                CityEmblemView(
                    city: store.currentCity,
                    countryCode: store.snapshot.currentPresence.countryCode,
                    size: 80
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.snapshot.currentPresence.cityDisplay)
                        .font(.title2.bold())
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(sharingStatusText)
                        .font(.subheadline)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            Divider()
                .overlay(WIFTheme.border.opacity(0.6))

            Button {
                locationService.requestForegroundCity()
            } label: {
                HStack(spacing: 8) {
                    if locationService.isResolving {
                        ProgressView()
                            .tint(WIFTheme.fresh)
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                    }

                    Text(locationService.isResolving ? "Detecting current city…" : "Refresh location")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(WIFTheme.fresh)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(WIFTheme.fresh.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(locationService.isResolving)
            .accessibilityIdentifier("refreshLocationButton")
        }
        .wifSettingsGlassCard(tint: sharingIsEnabled ? WIFTheme.fresh.opacity(0.12) : WIFTheme.surface.opacity(0.07))
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: sharingIsEnabled)
    }

    private var sharingIsEnabled: Bool {
        pendingSharingEnabled ?? store.snapshot.sharingPreferences.citySharingEnabled
    }

    private var sharingStatusText: String {
        guard sharingIsEnabled else { return String(localized: "Sharing is paused") }
        guard store.currentCity != nil else { return String(localized: "Detecting your city…") }

        let recipientCount = store.friends.filter {
            store.preference(for: $0.id).sharesMyCity
        }.count
        let updateTime = store.snapshot.currentPresence.updatedAt?
            .formatted(date: .omitted, time: .shortened) ?? "—"

        if recipientCount == 1 {
            return String(format: String(localized: "Shared with 1 friend · updated %@"), updateTime)
        }
        return String(
            format: String(localized: "Shared with %lld friends · updated %@"),
            Int64(recipientCount),
            updateTime
        )
    }

    private var citySharingBinding: Binding<Bool> {
        Binding {
            sharingIsEnabled
        } set: { newValue in
            pendingSharingEnabled = newValue
            var preferences = store.snapshot.sharingPreferences
            preferences.citySharingEnabled = newValue
            Task {
                await store.setSharingPreferences(preferences)
                pendingSharingEnabled = nil
            }
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

#Preview {
    CitySharingSheet()
        .environmentObject(AppStore())
        .environmentObject(CityLocationService())
}
