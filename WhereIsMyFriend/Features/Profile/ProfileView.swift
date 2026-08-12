import SwiftUI

public struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @State private var copiedToast = false

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        AvatarView(
                            name: viewModel.user?.displayName ?? "User",
                            photoURL: viewModel.user?.photoURL,
                            emoji: viewModel.user?.avatarEmoji,
                            avatarColor: viewModel.user?.avatarColor ?? "#007AFF",
                            size: 64
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.user?.displayName ?? "My Profile")
                                .font(.title3.bold())
                            Text(viewModel.user?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Your Invite Code") {
                    HStack {
                        Text(viewModel.inviteCode)
                            .font(.title2.monospaced().bold())
                            .foregroundColor(.blue)

                        Spacer()

                        Button {
                            viewModel.copyInviteCode()
                            copiedToast = true
                        } label: {
                            Label(copiedToast ? "Copied!" : "Copy", systemImage: copiedToast ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(copiedToast ? .green : .blue)
                    }
                }

                Section("Location Privacy") {
                    HStack {
                        Text("Current City")
                        Spacer()
                        Text(viewModel.user?.currentCity ?? "Not detected yet")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
