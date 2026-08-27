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
            List {
                Section {
                    locationSummaryRow
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    Toggle("Share my city with friends", isOn: citySharingBinding)
                        .tint(WIFTheme.fresh)
                        .disabled(store.isWorking)
                        .accessibilityIdentifier("citySharingToggle")
                } footer: {
                    Text("Your per-friend choices still apply")
                }

                Section("Location") {
                    Button {
                        locationService.requestForegroundCity()
                    } label: {
                        Label {
                            HStack {
                                Text("Update from current location")
                                Spacer()
                                if locationService.isResolving {
                                    ProgressView()
                                }
                            }
                        } icon: {
                            Image(systemName: "location.fill")
                        }
                    }
                    .disabled(locationService.isResolving)
                    .accessibilityIdentifier("useCurrentCityButton")

                    Button {
                        showsSourceOptions = true
                    } label: {
                        HStack {
                            Label("City source", systemImage: "arrow.triangle.branch")
                            Spacer()
                            Text(citySourceTitle)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("citySourceButton")
                }

                if let errorMessage = locationService.errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(WIFTheme.destructive)
                    }
                }

                Section {
                    Label(
                        "Only your city and update time are shared. Precise location and routes are never stored.",
                        systemImage: "hand.raised.fill"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
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

    private var locationSummaryRow: some View {
        VStack(spacing: 8) {
            Image(systemName: sharingIsEnabled ? "location.circle.fill" : "pause.circle.fill")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(sharingIsEnabled ? WIFTheme.fresh : .secondary)
                .contentTransition(.symbolEffect(.replace))

            Text(store.snapshot.currentPresence.cityDisplay)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text(sharingStatusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
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
