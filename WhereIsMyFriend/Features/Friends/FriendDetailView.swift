import SwiftUI

struct FriendDetailView: View {
    let friend: FriendPresence
    @State private var sharesMyCity = true
    @State private var sameCityAlert = true
    @State private var showsRemoveConfirmation = false
    private let referenceDate = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FriendAvatarView(friend: friend, size: 84)
                    .padding(.top, 8)

                Text(friend.displayName)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .padding(.top, 12)

                Text("@\(friend.username)")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 3)

                citySurface
                    .padding(.top, 24)

                sectionLabel("Between you two")
                    .padding(.top, 24)

                VStack(spacing: 0) {
                    Toggle(isOn: $sharesMyCity) {
                        settingLabel("Share my city", note: "\(friend.displayName) can see your latest city")
                    }
                    .tint(WIFTheme.fresh)
                    .padding(15)

                    Divider().overlay(WIFTheme.border).padding(.leading, 15)

                    Toggle(isOn: $sameCityAlert) {
                        settingLabel("Same-city alert", note: "Notify me when your cities overlap")
                    }
                    .tint(WIFTheme.fresh)
                    .padding(15)

                    Divider().overlay(WIFTheme.border).padding(.leading, 15)

                    Button(role: .destructive) {
                        showsRemoveConfirmation = true
                    } label: {
                        HStack {
                            settingLabel("Remove friend", note: "Stops sharing both ways")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WIFTheme.destructive)
                    .padding(15)
                }
                .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: WIFTheme.mediumRadius)
                        .stroke(WIFTheme.border, lineWidth: 1)
                }

                Label("No precise location or route history is shared.", systemImage: "hand.raised.fill")
                    .font(.footnote)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 18)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 28)
        }
        .background(WIFTheme.canvas)
        .navigationTitle(friend.displayName.components(separatedBy: " ").first ?? friend.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove \(friend.displayName)?",
            isPresented: $showsRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove friend", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is a prototype. No relationship will be changed.")
        }
    }

    private var citySurface: some View {
        VStack(spacing: 7) {
            Text(friend.cityDisplay)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(WIFTheme.primaryText)
                .multilineTextAlignment(.center)

            Text(friend.relativeUpdateLongText(at: referenceDate))
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .background(WIFTheme.cityGradient, in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius))
        .overlay {
            RoundedRectangle(cornerRadius: WIFTheme.largeRadius)
                .stroke(WIFTheme.border, lineWidth: 1)
        }
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

    private func settingLabel(_ title: LocalizedStringKey, note: LocalizedStringKey) -> some View {
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

#Preview {
    NavigationStack {
        FriendDetailView(friend: MockFriendData.friends[0])
    }
}
