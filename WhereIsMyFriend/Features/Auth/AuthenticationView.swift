import AuthenticationServices
import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isProcessingAppleSignIn = false

    var body: some View {
        ZStack {
            WIFTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 78, weight: .semibold))
                    .foregroundStyle(WIFTheme.fresh)
                    .symbolRenderingMode(.hierarchical)

                Text("Find your people")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
                    .padding(.top, 22)

                Text("Sign in to restore your accepted friends and city-sharing preferences.")
                    .font(.body)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 10)
                    .padding(.horizontal, 30)

                Spacer()

                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName]
                    isProcessingAppleSignIn = true
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("appleSignInButton")

                if store.repositoryMode == .localDemo {
                    Button {
                        Task { await store.signInDemo() }
                    } label: {
                        Label("Continue with local demo", systemImage: "iphone.gen3")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(WIFTheme.fresh)
                    .background(WIFTheme.freshSurface, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("demoSignInButton")
                    .padding(.top, 12)
                }

                Text(store.repositoryMode == .localDemo
                     ? "Apple authorization is wired, but server verification is replaced by the local repository in this build."
                     : "Your Apple identity token is sent only to the configured API over HTTPS.")
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    .padding(.bottom, 24)
            }
            .padding(.horizontal, WIFTheme.screenInset)
        }
        .overlay {
            if isProcessingAppleSignIn || store.isWorking {
                ProgressView()
                    .padding(18)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        isProcessingAppleSignIn = false
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                store.notice = AppNotice(
                    title: "Apple sign-in failed",
                    message: "Apple did not return an identity token."
                )
                return
            }
            let name = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
            Task {
                await store.signInWithApple(
                    AppleSignInPayload(
                        appleUserID: credential.user,
                        identityToken: identityToken,
                        displayName: name.isEmpty ? nil : name
                    )
                )
            }
        case .failure(let error):
            store.notice = AppNotice(title: "Apple sign-in failed", message: error.localizedDescription)
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AppStore())
}
