import SwiftUI

public struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    public var body: some View {
        NavigationStack {
            List {
                Section("Privacy") {
                    Toggle(isOn: $viewModel.isGhostMode) {
                        VStack(alignment: .leading) {
                            Text("🌙 Ghost Mode")
                                .fontWeight(.medium)
                            Text("Hide your location city from all friends.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Notifications") {
                    Toggle("Same-City Alerts", isOn: $viewModel.notificationsEnabled)
                }

                Section("Account") {
                    Button(role: .destructive) {
                        viewModel.signOut()
                    } label: {
                        Text("Sign Out")
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
