import SwiftUI

struct ProfileView: View {
    let onReplayOnboarding: () -> Void
    @State private var showsDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader

                sectionLabel("Sharing")
                    .padding(.top, 24)
                settingsGroup {
                    settingLink("City sharing", note: "Visible to 7 friends", symbol: "location.circle.fill")
                    divider
                    settingLink("Location access", note: "Prototype — not requested", symbol: "gearshape.fill")
                    divider
                    settingLink("Notifications", note: "Same-city alerts on", symbol: "bell.fill")
                }

                sectionLabel("Privacy")
                    .padding(.top, 24)
                settingsGroup {
                    settingLink("Blocked people", note: nil, symbol: "person.crop.circle.badge.xmark")
                    divider
                    settingLink("Privacy & data", note: "City-level presence only", symbol: "hand.raised.fill")
                    divider
                    Button {
                        onReplayOnboarding()
                    } label: {
                        settingRow("Preview onboarding", note: nil, symbol: "sparkles", color: WIFTheme.fresh)
                    }
                    .buttonStyle(.plain)
                    divider
                    Button(role: .destructive) {
                        showsDeleteConfirmation = true
                    } label: {
                        settingRow(
                            "Delete account",
                            note: nil,
                            symbol: "trash.fill",
                            color: WIFTheme.destructive,
                            isDestructive: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                Text("Prototype build · No account or location data is collected")
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
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This prototype has no real account. Production deletion will remove the account and associated data.")
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            Text("WY")
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
                Text("Wang Yang")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("New York · updated just now")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer()
        }
        .padding(.top, 8)
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
                RoundedRectangle(cornerRadius: WIFTheme.mediumRadius)
                    .stroke(WIFTheme.border, lineWidth: 1)
            }
    }

    private var divider: some View {
        Divider().overlay(WIFTheme.border).padding(.leading, 52)
    }

    private func settingLink(_ title: LocalizedStringKey, note: LocalizedStringKey?, symbol: String) -> some View {
        NavigationLink {
            PrototypeSettingDetail(title: title, symbol: symbol)
        } label: {
            settingRow(title, note: note, symbol: symbol, color: WIFTheme.fresh)
        }
        .buttonStyle(.plain)
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
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(WIFTheme.secondaryText)
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

private struct PrototypeSettingDetail: View {
    let title: LocalizedStringKey
    let symbol: String

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text("This destination is included in the design system and will connect to production services in a later milestone.")
        }
        .background(WIFTheme.canvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ProfileView(onReplayOnboarding: {})
    }
}
