import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var username = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    inviteForm
                    shareLink

                    if !store.snapshot.incomingRequests.isEmpty {
                        requestSection(
                            title: "Friend requests",
                            requests: store.snapshot.incomingRequests,
                            isIncoming: true
                        )
                    }

                    if !store.snapshot.outgoingRequests.isEmpty {
                        requestSection(
                            title: "Pending invitations",
                            requests: store.snapshot.outgoingRequests,
                            isIncoming: false
                        )
                    }

                    if store.repositoryMode == .localDemo {
                        Text("Demo usernames: jamie, priya, leo, emma")
                            .font(.caption)
                            .foregroundStyle(WIFTheme.secondaryText)
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
                        .accessibilityIdentifier("doneAddFriendButton")
                }
            }
        }
    }

    private var inviteForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Invite by username")
                .font(.headline)
                .foregroundStyle(WIFTheme.primaryText)

            HStack(spacing: 10) {
                TextField("Friend’s username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit(sendInvite)
                    .padding(13)
                    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14).stroke(WIFTheme.border, lineWidth: 1)
                    }
                    .accessibilityIdentifier("friendUsernameField")

                Button("Invite", action: sendInvite)
                    .buttonStyle(.borderedProminent)
                    .tint(WIFTheme.fresh)
                    .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || store.isWorking)
                    .accessibilityIdentifier("sendInviteButton")
            }
        }
    }

    private var shareLink: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Or share your invite link")
                .font(.headline)
                .foregroundStyle(WIFTheme.primaryText)

            ShareLink(item: InviteURLFactory.make(username: store.snapshot.currentUser.username)) {
                Label("Share invite link", systemImage: "square.and.arrow.up")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(WIFTheme.freshSurface, in: RoundedRectangle(cornerRadius: 14))
            }
            .foregroundStyle(WIFTheme.fresh)
        }
    }

    private func requestSection(title: LocalizedStringKey, requests: [FriendRequest], isIncoming: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(WIFTheme.primaryText)

            ForEach(requests) { request in
                requestRow(request, isIncoming: isIncoming)
            }
        }
    }

    private func requestRow(_ request: FriendRequest, isIncoming: Bool) -> some View {
        let friend = FriendPresence(
            id: request.userID,
            displayName: request.displayName,
            username: request.username,
            city: nil,
            countryCode: nil,
            updatedAt: nil,
            sharingState: .unavailable,
            avatarPalette: request.avatarPalette
        )

        return HStack(spacing: 12) {
            FriendAvatarView(friend: friend, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName).font(.body.weight(.semibold))
                Text("@\(request.username)").font(.caption).foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer()

            if isIncoming {
                Button("Decline") {
                    Task { await store.respond(to: request.id, response: .decline) }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(WIFTheme.secondaryText)

                Button("Accept") {
                    Task { await store.respond(to: request.id, response: .accept) }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(WIFTheme.fresh)
                .accessibilityIdentifier("acceptRequestButton")
            } else {
                Text("Pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.secondaryText)
            }
        }
        .padding(14)
        .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius))
        .overlay {
            RoundedRectangle(cornerRadius: WIFTheme.mediumRadius).stroke(WIFTheme.border, lineWidth: 1)
        }
    }

    private func sendInvite() {
        let value = username
        Task {
            if await store.sendFriendRequest(username: value) {
                username = ""
            }
        }
    }
}

#Preview {
    AddFriendView()
        .environmentObject(AppStore())
}
