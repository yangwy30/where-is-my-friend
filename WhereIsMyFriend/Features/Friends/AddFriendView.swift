import SwiftUI
import UIKit
import UserNotifications

struct InvitationNotificationStatusView: View {
    @EnvironmentObject private var store: AppStore
    @ObservedObject var service: LocalNotificationService
    var isSameCityContext = false

    private var needsSetup: Bool {
        if !service.allowsNotifications { return true }
        return store.pushRegistrationState == .failed || store.pushRegistrationState == .waitingForNetwork
    }

    private var promptTitle: LocalizedStringKey {
        if service.allowsNotifications { return "Finish notification setup" }
        return isSameCityContext ? "Enable same-city notifications" : "Get invitation notifications"
    }

    private var promptDetail: LocalizedStringKey {
        if service.allowsNotifications { return "Notifications couldn’t be enabled. Try again." }
        return isSameCityContext ? "Get an alert when you and this friend share a city."
            : "Invitations stay in the app even when notifications are off."
    }

    var body: some View {
        if store.repositoryMode == .remote && needsSetup {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge").foregroundStyle(WIFTheme.fresh)
                VStack(alignment: .leading, spacing: 3) {
                    Text(promptTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(promptDetail)
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText)
                }
                Spacer(minLength: 4)
                if store.pushRegistrationState.isInProgress {
                    ProgressView()
                } else {
                    Button(service.authorizationStatus == .notDetermined ? "Enable" : service.allowsNotifications ? "Retry" : "Settings") {
                        if service.authorizationStatus == .notDetermined {
                            Task { await store.requestNotificationAuthorization() }
                        } else if service.allowsNotifications {
                            Task { await store.retryPushRegistration() }
                        } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                    .accessibilityIdentifier("invitationNotificationSetupButton")
                }
            }
            .padding(16).background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .accessibilityIdentifier("invitationNotificationSetup")
            .task { await store.preparePushRegistrationIfAuthorized() }
        }
    }
}

struct FriendRequestNotificationSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let requestID: UUID
    @State private var loading = true
    private var request: FriendRequest? { store.snapshot.incomingRequests.first { $0.id == requestID } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if loading {
                    ProgressView("Loading friend request…")
                } else if let request {
                    Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 48)).foregroundStyle(WIFTheme.fresh)
                    Text(request.displayName).font(.title2.bold())
                    Text("@\(request.username) wants to connect with you.")
                        .foregroundStyle(WIFTheme.secondaryText).multilineTextAlignment(.center)
                    Text("Your city-sharing preferences still apply after you accept.")
                        .font(.caption).foregroundStyle(WIFTheme.secondaryText).multilineTextAlignment(.center)
                    Button("Accept") { respond(.accept) }
                        .controlSize(.large)
                        .wifGlassButton(tint: WIFTheme.fresh, prominent: true)
                        .disabled(store.isResponding(to: requestID))
                        .accessibilityIdentifier("acceptNotificationFriendRequest")
                    Button("Decline", role: .destructive) { respond(.decline) }
                        .frame(minHeight: 44)
                        .disabled(store.isResponding(to: requestID))
                        .accessibilityIdentifier("declineNotificationFriendRequest")
                } else {
                    Text(store.snapshot.syncState == .offline
                         ? "Couldn’t refresh this request. Check your connection and retry."
                         : "This request is no longer pending, or belongs to another account.")
                        .multilineTextAlignment(.center).foregroundStyle(WIFTheme.secondaryText)
                    Button("Retry") { Task { await refresh() } }
                }
                InvitationNotificationStatusView(service: store.notificationService)
            }
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).wifAmbientBackground()
            .navigationTitle("Friend request").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Not now") { store.discardFriendRequestLink(); dismiss() }
            } }
        }
        .accessibilityIdentifier("friendRequestNotificationSheet")
        .task(id: requestID) { await refresh() }
    }

    private func refresh() async {
        loading = true
        await store.refresh()
        loading = false
    }
    private func respond(_ response: FriendRequestResponse) {
        Task {
            if await store.respond(to: requestID, response: response) {
                store.discardFriendRequestLink(); dismiss()
            }
        }
    }
}

struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @State private var username = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    yourUsernameCard
                    InvitationNotificationStatusView(service: store.notificationService)
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
            Image(systemName: "at")
                .font(.headline.weight(.bold))
                .foregroundStyle(WIFTheme.fresh)
                .frame(width: 48, height: 48)
                .background(WIFTheme.fresh.opacity(0.12), in: Circle())

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

            Image(systemName: "checkmark.seal.fill")
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
        return HStack(spacing: 12) {
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
