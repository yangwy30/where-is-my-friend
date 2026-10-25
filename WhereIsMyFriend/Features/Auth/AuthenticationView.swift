import AuthenticationServices
import SwiftUI

enum AppleSignInFailurePolicy {
    static func isUserCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == ASAuthorizationError.errorDomain && error.code == ASAuthorizationError.canceled.rawValue
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var store: AppStore
    @State private var isProcessingAppleSignIn = false
    @State private var isProcessingGoogleSignIn = false
    @State private var currentNonce: String?
    @State private var showsEmailSignIn = false
    @State private var googleSignIn = GoogleSignInController()
    private let googleConfiguration = GoogleSignInConfiguration.fromBundle()

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

                if let googleConfiguration {
                    Button {
                        Task { await signInWithGoogle(googleConfiguration) }
                    } label: {
                        HStack(spacing: 10) {
                            Image("GoogleLogo")
                                .resizable()
                                .frame(width: 18, height: 18)
                                .accessibilityHidden(true)
                            Text("Continue with Google")
                        }
                        .authenticationOptionLabel()
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessingGoogleSignIn)
                    .accessibilityIdentifier("googleSignInButton")
                    .padding(.top, 12)
                }

                Button {
                    showsEmailSignIn = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .font(.system(size: 17, weight: .medium))
                            .accessibilityHidden(true)
                        Text("Continue with email")
                    }
                    .authenticationOptionLabel()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("emailSignInButton")
                .padding(.top, 12)

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
        .sheet(isPresented: $showsEmailSignIn) {
            EmailCodeSignInView()
                .environmentObject(store)
        }
        .overlay {
            if isProcessingAppleSignIn || isProcessingGoogleSignIn || (store.isWorking && !showsEmailSignIn) {
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

    private func signInWithGoogle(_ configuration: GoogleSignInConfiguration) async {
        isProcessingGoogleSignIn = true
        defer { isProcessingGoogleSignIn = false }
        do {
            guard let payload = try await googleSignIn.signIn(configuration: configuration) else { return }
            await store.signIn(.google(payload))
        } catch {
            store.notice = AppNotice(
                title: String(localized: "Google sign-in failed"),
                message: error.localizedDescription
            )
        }
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
                await store.signIn(.apple(
                    AppleSignInPayload(
                        appleUserID: credential.user,
                        identityToken: identityToken,
                        nonce: nonce,
                        displayName: name.isEmpty ? nil : name
                    )
                ))
            }
        case .failure(let error):
            guard !AppleSignInFailurePolicy.isUserCancellation(error) else { return }
            store.notice = AppNotice(
                title: String(localized: "Apple sign-in failed"),
                message: error.localizedDescription
            )
        }
    }
}

private extension View {
    /// Secondary sign-in options sit under the Apple button at the same size,
    /// as quiet outlined rows so Sign in with Apple stays the lead option.
    func authenticationOptionLabel() -> some View {
        font(.system(size: 19, weight: .medium))
            .foregroundStyle(WIFTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(WIFTheme.border, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AppStore())
}
