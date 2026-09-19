import AuthenticationServices
import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isProcessingAppleSignIn = false
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            WIFAmbientBackground()

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

                Text("Sign in to connect with your friends.")
                    .font(.body)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 10)
                    .padding(.horizontal, 30)

                Spacer()

                SignInWithAppleButton(.continue) { request in
                    do {
                        let nonce = try AppleSignInNonce.make()
                        currentNonce = nonce
                        request.nonce = AppleSignInNonce.sha256(nonce)
                        request.requestedScopes = [.fullName]
                        isProcessingAppleSignIn = true
                    } catch {
                        store.notice = AppNotice(
                            title: String(localized: "Apple sign-in failed"),
                            message: error.localizedDescription
                        )
                    }
                } onCompletion: { result in
                    handleAppleResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("appleSignInButton")

                if showsDebugSignIn {
                    Button {
                        Task { await store.signInDemo() }
                    } label: {
                        Label(debugSignInLabel, systemImage: "iphone.gen3")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                    .foregroundStyle(WIFTheme.fresh)
                    .wifGlassButton(tint: WIFTheme.fresh.opacity(0.20))
                    .accessibilityIdentifier("demoSignInButton")
                    .padding(.top, 12)
                }

                if showsDebugSignIn {
                    Text("Demo mode · sample data")
                        .font(.caption)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.bottom, 24)
        }
        .overlay {
            if isProcessingAppleSignIn || store.isWorking {
                ProgressView()
                    .padding(18)
                    .wifGlassSurface(
                        tint: WIFTheme.surface.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                    )
            }
        }
    }

    private var showsDebugSignIn: Bool {
        store.repositoryMode == .localDemo
    }

    private var debugSignInLabel: String {
        "Continue with local demo"
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        isProcessingAppleSignIn = false
        let nonce = currentNonce
        currentNonce = nil
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8),
                let nonce
            else {
                store.notice = AppNotice(
                    title: String(localized: "Apple sign-in failed"),
                    message: String(localized: "Apple did not return an identity token.")
                )
                return
            }
            let name = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
            Task {
                await store.signInWithApple(
                    AppleSignInPayload(
                        appleUserID: credential.user,
                        identityToken: identityToken,
                        nonce: nonce,
                        displayName: name.isEmpty ? nil : name
                    )
                )
            }
        case .failure(let error):
            store.notice = AppNotice(
                title: String(localized: "Apple sign-in failed"),
                message: error.localizedDescription
            )
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AppStore())
}
