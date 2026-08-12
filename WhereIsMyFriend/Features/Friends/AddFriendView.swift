import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var showsSentAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite by username")
                            .font(.headline)
                            .foregroundStyle(WIFTheme.primaryText)

                        HStack(spacing: 10) {
                            TextField("Friend’s username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(13)
                                .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(WIFTheme.border, lineWidth: 1)
                                }

                            Button("Invite") {
                                showsSentAlert = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(WIFTheme.fresh)
                            .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Or share your invite link")
                            .font(.headline)
                            .foregroundStyle(WIFTheme.primaryText)

                        ShareLink(item: URL(string: "https://wif.example/invite/WY24")!) {
                            Label("Share invite link", systemImage: "square.and.arrow.up")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(WIFTheme.freshSurface, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .foregroundStyle(WIFTheme.fresh)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Friend requests")
                            .font(.headline)
                            .foregroundStyle(WIFTheme.primaryText)

                        requestRow(name: "Jamie Park", username: "jamie", palette: 3)
                        requestRow(name: "Priya Shah", username: "priya", palette: 2)
                    }
                }
                .padding(WIFTheme.screenInset)
            }
            .accessibilityIdentifier("addFriendScreen")
            .background(WIFTheme.canvas)
            .navigationTitle("Add friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Invite ready", isPresented: $showsSentAlert) {
                Button("OK") { username = "" }
            } message: {
                Text("The production app will send this through the backend. Nothing was sent from the prototype.")
            }
        }
    }

    private func requestRow(name: String, username: String, palette: Int) -> some View {
        let friend = FriendPresence(
            displayName: name,
            username: username,
            city: nil,
            countryCode: nil,
            updatedAt: nil,
            sharingState: .unavailable,
            avatarPalette: palette
        )

        return HStack(spacing: 12) {
            FriendAvatarView(friend: friend, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.body.weight(.semibold))
                Text("@\(username)").font(.caption).foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer()

            Button("Accept") {}
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(WIFTheme.fresh)
        }
        .padding(14)
        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius))
        .overlay {
            RoundedRectangle(cornerRadius: WIFTheme.mediumRadius)
                .stroke(WIFTheme.border, lineWidth: 1)
        }
    }
}

#Preview {
    AddFriendView()
}
