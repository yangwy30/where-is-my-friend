import SwiftUI

public struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AuthViewModel()

    public var body: some View {
        NavigationStack {
            Form {
                Section("Personal Details") {
                    TextField("Display Name", text: $viewModel.displayName)
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    SecureField("Password", text: $viewModel.password)
                }

                Section("Select Avatar Emoji") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.availableEmojis, id: \.self) { emoji in
                                Text(emoji)
                                    .font(.title)
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(viewModel.selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                                    .onTapGesture {
                                        viewModel.selectedEmoji = emoji
                                    }
                            }
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await viewModel.signUp()
                            dismiss()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Create Account")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .navigationTitle("Sign Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
