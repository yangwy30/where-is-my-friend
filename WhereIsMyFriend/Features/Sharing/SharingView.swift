import CoreLocation
import SwiftUI

struct CitySharingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var locationService: CityLocationService
    @State private var showsCityPicker = false
    @State private var showsSourceOptions = false
    @State private var pendingSharingEnabled: Bool?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    locationHero
                    sharingControl
                    locationActions

                    if let errorMessage = locationService.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(WIFTheme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Label(
                        "Only your city and update time are shared. Precise location and routes are never stored.",
                        systemImage: "hand.raised.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                }
                .padding(.horizontal, WIFTheme.screenInset)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .wifAmbientBackground()
            .navigationTitle("City sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showsCityPicker) {
            CityPickerView { city, countryCode in
                Task {
                    await store.updateCurrentCity(city: city, countryCode: countryCode, source: .manual)
                }
            }
        }
        .confirmationDialog(
            "Choose city source",
            isPresented: $showsSourceOptions,
            titleVisibility: .visible
        ) {
            Button("Use current location") {
                locationService.requestForegroundCity()
            }
            Button("Choose city manually") {
                showsCityPicker = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your precise coordinates stay on this iPhone. The app stores only the resolved city.")
        }
        .accessibilityIdentifier("citySharingSheet")
    }

    private var locationHero: some View {
        VStack(spacing: 8) {
            Image(systemName: sharingIsEnabled ? "location.circle.fill" : "pause.circle.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(sharingIsEnabled ? WIFTheme.fresh : WIFTheme.secondaryText)
                .contentTransition(.symbolEffect(.replace))

            Text(store.snapshot.currentPresence.cityDisplay)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(WIFTheme.primaryText)
                .multilineTextAlignment(.center)

            Text(sharingStatusText)
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .wifGlassSurface(
            tint: (sharingIsEnabled ? WIFTheme.fresh : WIFTheme.elevatedSurface).opacity(0.18),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: sharingIsEnabled)
    }

    private var sharingControl: some View {
        Toggle(isOn: citySharingBinding) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Share my city with friends")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("Your per-friend choices still apply")
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
        }
        .tint(WIFTheme.fresh)
        .padding(16)
        .disabled(store.isWorking)
        .wifGlassSurface(
            tint: WIFTheme.surface.opacity(0.08),
            in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius, style: .continuous)
        )
        .accessibilityIdentifier("citySharingToggle")
    }

    private var locationActions: some View {
        WIFGlassEffectGroup(spacing: 10) {
            VStack(spacing: 10) {
                Button {
                    locationService.requestForegroundCity()
                } label: {
                    HStack {
                        if locationService.isResolving {
                            ProgressView().controlSize(.small)
                        }
                        Label("Update from current location", systemImage: "location.fill")
                    }
                    .frame(maxWidth: .infinity)
                }
                .wifGlassButton(tint: WIFTheme.fresh.opacity(0.28), prominent: true)
                .disabled(locationService.isResolving)
                .accessibilityIdentifier("useCurrentCityButton")

                Button {
                    showsSourceOptions = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(WIFTheme.fresh)
                        Text("City source")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(WIFTheme.primaryText)
                        Spacer()
                        Text(citySourceTitle)
                            .foregroundStyle(WIFTheme.secondaryText)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .wifGlassSurface(
                    tint: WIFTheme.surface.opacity(0.08),
                    interactive: true,
                    in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius, style: .continuous)
                )
                .accessibilityIdentifier("citySourceButton")
            }
        }
    }

    private var sharingIsEnabled: Bool {
        pendingSharingEnabled ?? store.snapshot.sharingPreferences.citySharingEnabled
    }

    private var sharingStatusText: String {
        guard sharingIsEnabled else { return String(localized: "Sharing is paused") }
        guard store.currentCity != nil else { return String(localized: "Choose a city to start sharing") }

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

    private var citySourceTitle: String {
        if store.snapshot.sharingPreferences.backgroundUpdatesEnabled {
            return String(localized: "Automatic")
        }

        return switch store.snapshot.currentPresence.source {
        case .manual: String(localized: "Manual")
        case .demo: String(localized: "Demo")
        case .foregroundLocation: String(localized: "Current location")
        case .significantChange, .visit: String(localized: "Automatic")
        }
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
            .navigationTitle("Choose city manually")
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
    CitySharingSheet()
        .environmentObject(AppStore())
        .environmentObject(CityLocationService())
}
