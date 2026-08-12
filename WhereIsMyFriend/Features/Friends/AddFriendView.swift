import SwiftUI

public struct AddFriendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var inviteCode: String = ""
    @State private var statusMessage: String?
    @State private var isSubmitting: Bool = false

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Enter 6-character code", text: $inviteCode)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .font(.title3.monospaced())
                        .multilineTextAlignment(.center)
                } header: {
                    Text("Friend Invite Code")
                } footer: {
                    Text("Ask your friend for their 6-character invite code from their Profile tab.")
                }

                if let statusMessage {
                    Section {
                        Text(statusMessage)
                            .foregroundColor(.blue)
                    }
                }

                Section {
                    Button {
                        sendFriendRequest()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Send Friend Request")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(inviteCode.trimmingCharacters(in: .whitespaces).count != 6 || isSubmitting)
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func sendFriendRequest() {
        isSubmitting = true
        Task {
            do {
                let msg = try await FirestoreService.shared.addFriend(byInviteCode: inviteCode.uppercased())
                statusMessage = msg
                isSubmitting = false
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                dismiss()
            } catch {
                statusMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}
