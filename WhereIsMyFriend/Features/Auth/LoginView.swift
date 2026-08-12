import SwiftUI

public struct LoginView: View {
    @State private var viewModel = AuthViewModel()
    @State private var showingSignUp = false

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("📍")
                        .font(.system(size: 64))
                    Text("Where's My Friend")
                        .font(.largeTitle.bold())
                    Text("Know which city your friends are in")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 16) {
                    TextField("Email", text: $viewModel.email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $viewModel.password)
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button {
                        Task { await viewModel.login() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                    }

                    Button("Don't have an account? Sign Up") {
                        showingSignUp = true
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
        }
    }
}
