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
                VStack(alignment: .leading, spacing: 20) {
                    cityHero

                    Toggle(isOn: citySharingBinding) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share my city")
                                .font(.headline)
                                .foregroundStyle(WIFTheme.primaryText)
                            Text("Your per-friend choices still apply")
                                .font(.subheadline)
                                .foregroundStyle(WIFTheme.secondaryText)
                        }
                    }
                    .tint(WIFTheme.fresh)
                    .disabled(store.isWorking)
                    .wifSettingsGlassCard(tint: WIFTheme.fresh.opacity(0.10))
                    .accessibilityIdentifier("citySharingToggle")

                    VStack(alignment: .leading, spacing: 0) {
                        Text("City source")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WIFTheme.secondaryText)
                            .padding(.bottom, 10)

                        Button {
                            showsSourceOptions = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: sourceSymbol)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(WIFTheme.fresh)
                                    .frame(width: 42, height: 42)
                                    .background(WIFTheme.fresh.opacity(0.11), in: Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(citySourceTitle)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(WIFTheme.primaryText)
                                    Text(citySourceDetail)
                                        .font(.caption)
                                        .foregroundStyle(WIFTheme.secondaryText)
                                }

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(WIFTheme.secondaryText)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("citySourceButton")

                        Divider()
                            .overlay(WIFTheme.border)
                            .padding(.vertical, 14)

                        Button {
                            locationService.requestForegroundCity()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: locationService.isResolving ? "arrow.trianglehead.2.clockwise.rotate.90" : "arrow.clockwise")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(WIFTheme.fresh)
                                    .frame(width: 42, height: 42)
                                    .background(WIFTheme.eventBlue.opacity(0.42), in: Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Refresh now")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(WIFTheme.primaryText)
                                    Text("Use your current location for this city")
                                        .font(.caption)
                                        .foregroundStyle(WIFTheme.secondaryText)
                                }

                                Spacer(minLength: 8)

                                if locationService.isResolving {
                                    ProgressView()
                                        .tint(WIFTheme.fresh)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(locationService.isResolving)
                        .accessibilityIdentifier("useCurrentCityButton")
                    }
                    .wifSettingsGlassCard()

                    if let errorMessage = locationService.errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(WIFTheme.destructive)
                            .wifSettingsGlassCard(tint: WIFTheme.destructive.opacity(0.08))
                    }

                    Text("Only your city and update time are shared. Precise location and routes are never stored.")
                        .font(.footnote)
                        .foregroundStyle(WIFTheme.secondaryText)
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
            .accessibilityIdentifier("useCurrentLocationSourceButton")
            Button("Choose city manually") {
                showsCityPicker = true
            }
            .accessibilityIdentifier("chooseCityManuallyButton")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your precise coordinates stay on this iPhone. The app stores only the resolved city.")
        }
        .accessibilityIdentifier("citySharingSheet")
    }

    private var cityHero: some View {
        HStack(spacing: 16) {
            CityEmblemView(
                city: store.currentCity,
                countryCode: store.snapshot.currentPresence.countryCode,
                size: 82
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(store.snapshot.currentPresence.cityDisplay)
                    .font(.title2.bold())
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(sharingStatusText)
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .wifSettingsGlassCard(tint: sharingIsEnabled ? WIFTheme.fresh.opacity(0.13) : WIFTheme.surface.opacity(0.07))
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: sharingIsEnabled)
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

    private var sourceSymbol: String {
        store.snapshot.sharingPreferences.backgroundUpdatesEnabled ? "arrow.triangle.branch" : "hand.tap.fill"
    }

    private var citySourceDetail: String {
        store.snapshot.sharingPreferences.backgroundUpdatesEnabled
            ? "Updates when your city meaningfully changes"
            : "Choose automatic or manual updates"
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
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WIFSettingsPageHero(
                        symbol: "building.2.crop.circle.fill",
                        title: "Choose your city",
                        detail: "Your friends see the city you choose, never a precise location."
                    )

                    VStack(spacing: 10) {
                        ForEach(cities, id: \.0) { city, code, flag in
                            Button {
                                onSelect(city, code)
                                dismiss()
                            } label: {
                                HStack(spacing: 14) {
                                    CityEmblemView(city: city, countryCode: code, size: 48)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(city)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(WIFTheme.primaryText)
                                        Text("\(flag)  \(code)")
                                            .font(.caption)
                                            .foregroundStyle(WIFTheme.secondaryText)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(WIFTheme.secondaryText)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .wifSettingsGlassCard(tint: WIFTheme.surface.opacity(0.07))
                        }
                    }
                }
                .padding(WIFTheme.screenInset)
            }
            .scrollIndicators(.hidden)
            .wifAmbientBackground()
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
