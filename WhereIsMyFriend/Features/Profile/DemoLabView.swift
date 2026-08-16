import SwiftUI

struct DemoLabView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        List {
            Section {
                scenarioButton(
                    .friendArrives,
                    title: "Friend arrives in my city",
                    note: "Moves one friend here and evaluates a same-city alert.",
                    symbol: "airplane.arrival"
                )
                scenarioButton(
                    .ageLocations,
                    title: "Make locations stale",
                    note: "Moves active updates past the 24-hour freshness limit.",
                    symbol: "clock.badge.exclamationmark"
                )
                scenarioButton(
                    .incomingRequest,
                    title: "Add incoming request",
                    note: "Adds another request to the Add Friends screen.",
                    symbol: "person.badge.plus"
                )
            } header: {
                Text("Scenarios")
            }

            Section {
                scenarioButton(
                    .restoreDefaults,
                    title: "Restore demo defaults",
                    note: "Resets only local demo data.",
                    symbol: "arrow.counterclockwise"
                )
            } footer: {
                Text("Demo Lab never contacts a server or requests precise location.")
            }
        }
        .scrollContentBackground(.hidden)
        .wifAmbientBackground()
        .navigationTitle("Demo Lab")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("demoLabScreen")
    }

    private func scenarioButton(
        _ scenario: DemoScenario,
        title: LocalizedStringKey,
        note: LocalizedStringKey,
        symbol: String
    ) -> some View {
        Button {
            Task { await store.runDemoScenario(scenario) }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(WIFTheme.fresh)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WIFTheme.primaryText)
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(WIFTheme.secondaryText)
                }
            }
        }
        .disabled(store.isWorking)
    }
}

#Preview {
    NavigationStack { DemoLabView() }
        .environmentObject(AppStore())
}
