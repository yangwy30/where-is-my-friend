import SwiftUI

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var username = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    yourUsernameCard
                    shareLink
                    inviteForm

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
            .wifAmbientBackground()
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

    private var yourUsernameCard: some View {
        HStack(spacing: 13) {
            Text(store.snapshot.currentUser.initials)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(WIFTheme.fresh.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Your username")
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                Text("@\(store.snapshot.currentUser.username)")
                    .font(.headline)
                    .foregroundStyle(WIFTheme.primaryText)
                    .textSelection(.enabled)
            }

            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.title3)
                .foregroundStyle(WIFTheme.fresh)
        }
        .padding(15)
        .wifGlassSurface(
            tint: WIFTheme.fresh.opacity(0.14),
            in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("currentUsernameCard")
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
                    .wifGlassSurface(
                        tint: WIFTheme.surface.opacity(0.08),
                        interactive: true,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .accessibilityIdentifier("friendUsernameField")
                    .disabled(store.isSendingFriendRequest)

                Button(action: sendInvite) {
                    if store.isSendingFriendRequest {
                        ProgressView()
                            .frame(minWidth: 50)
                    } else {
                        Text("Invite")
                    }
                }
                    .wifGlassButton(tint: WIFTheme.fresh.opacity(0.28), prominent: true)
                    .disabled(username.trimmingCharacters(in: .whitespaces).isEmpty || store.isSendingFriendRequest)
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
                    .wifGlassSurface(
                        tint: WIFTheme.fresh.opacity(0.16),
                        interactive: true,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
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
        let isResponding = store.isResponding(to: request.id)
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
                .disabled(isResponding)
                .accessibilityIdentifier("declineRequestButton")

                Button {
                    Task { await store.respond(to: request.id, response: .accept) }
                } label: {
                    if isResponding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Accept")
                    }
                }
                .wifGlassButton(tint: WIFTheme.fresh.opacity(0.28), prominent: true)
                .disabled(isResponding)
                .accessibilityIdentifier("acceptRequestButton")
            } else {
                Text("Pending")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WIFTheme.secondaryText)
            }
        }
        .padding(14)
        .wifGlassSurface(
            tint: WIFTheme.surface.opacity(0.08),
            in: RoundedRectangle(cornerRadius: WIFTheme.mediumRadius, style: .continuous)
        )
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
