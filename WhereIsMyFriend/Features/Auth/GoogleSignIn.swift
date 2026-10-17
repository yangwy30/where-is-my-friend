import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Google's iOS OAuth client. iOS clients are public (no secret), so the code
/// exchange is protected with PKCE and the identity token with a hashed nonce.
struct GoogleSignInConfiguration: Equatable, Sendable {
    let clientID: String

    private static let clientSuffix = ".apps.googleusercontent.com"

    static func validated(clientID rawValue: String) -> GoogleSignInConfiguration? {
        let clientID = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = clientID.dropLast(clientSuffix.count)
        guard clientID.hasSuffix(clientSuffix), !prefix.isEmpty,
              prefix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
        else { return nil }
        return GoogleSignInConfiguration(clientID: clientID)
    }

    static func fromBundle(_ bundle: Bundle = .main) -> GoogleSignInConfiguration? {
        guard let value = bundle.object(forInfoDictionaryKey: "WIFGoogleClientID") as? String else { return nil }
        return validated(clientID: value)
    }

    /// Google registers the reversed client ID as the iOS client's redirect scheme.
    var callbackScheme: String {
        "com.googleusercontent.apps." + clientID.dropLast(Self.clientSuffix.count)
    }

    var redirectURI: String { callbackScheme + ":/oauth2redirect" }

    func authorizationURL(state: String, codeChallenge: String, hashedNonce: String) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "nonce", value: hashedNonce),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        return components.url!
    }
}

enum GoogleSignInError: LocalizedError, Equatable {
    case invalidCallback
    case denied(String)
    case tokenExchangeFailed

    var errorDescription: String? {
        switch self {
        case .invalidCallback: String(localized: "Google returned an unexpected response. Please try again.")
        case .denied(let reason): String(localized: "Google sign-in was not completed (\(reason)).")
        case .tokenExchangeFailed: String(localized: "Google did not return an identity token. Please try again.")
        }
    }
}

enum GoogleSignInProtocol {
    static func codeChallenge(for verifier: String) -> String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncodedString()
    }

    /// Returns the authorization code, nil when the person backed out on Google's page.
    static func authorizationCode(from callback: URL, expectedState: String) throws -> String? {
        guard let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems else {
            throw GoogleSignInError.invalidCallback
        }
        let value = { (name: String) in items.first(where: { $0.name == name })?.value }
        guard value("state") == expectedState else { throw GoogleSignInError.invalidCallback }
        if let error = value("error") {
            if error == "access_denied" { return nil }
            throw GoogleSignInError.denied(error)
        }
        guard let code = value("code"), !code.isEmpty else { throw GoogleSignInError.invalidCallback }
        return code
    }

    /// Reads the display name from an identity token Supabase will verify.
    /// The claim is only used as a profile default, never for authorization.
    static func displayName(fromIdentityToken token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count == 3, let data = Data(base64URLEncoded: String(parts[1])),
              let claims = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = (claims["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty
        else { return nil }
        return name
    }
}

@MainActor
final class GoogleSignInController: NSObject, ASWebAuthenticationPresentationContextProviding {
    private struct TokenResponse: Decodable {
        let id_token: String?
        let access_token: String?
    }

    private var session: ASWebAuthenticationSession?

    /// Returns nil when the person cancels.
    func signIn(configuration: GoogleSignInConfiguration, urlSession: URLSession = .shared) async throws -> GoogleSignInPayload? {
        let verifier = try AppleSignInNonce.make(length: 64)
        let state = try AppleSignInNonce.make()
        let nonce = try AppleSignInNonce.make()
        let url = configuration.authorizationURL(
            state: state,
            codeChallenge: GoogleSignInProtocol.codeChallenge(for: verifier),
            hashedNonce: AppleSignInNonce.sha256(nonce)
        )
        guard let callback = try await authenticate(url: url, callbackScheme: configuration.callbackScheme),
              let code = try GoogleSignInProtocol.authorizationCode(from: callback, expectedState: state)
        else { return nil }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
        ]
        request.httpBody = form.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
        let (data, response) = try await urlSession.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let tokens = try? JSONDecoder().decode(TokenResponse.self, from: data),
              let identityToken = tokens.id_token
        else { throw GoogleSignInError.tokenExchangeFailed }
        return GoogleSignInPayload(
            identityToken: identityToken,
            accessToken: tokens.access_token,
            nonce: nonce,
            displayName: GoogleSignInProtocol.displayName(fromIdentityToken: identityToken)
        )
    }

    private func authenticate(url: URL, callbackScheme: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callback: .customScheme(callbackScheme)) { [weak self] callback, error in
                Task { @MainActor in self?.session = nil }
                if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(returning: nil)
                } else if let error {
                    continuation.resume(throwing: error)
                } else if let callback {
                    continuation.resume(returning: callback)
                } else {
                    continuation.resume(throwing: GoogleSignInError.invalidCallback)
                }
            }
            session.presentationContextProvider = self
            self.session = session
            if !session.start() {
                self.session = nil
                continuation.resume(throwing: GoogleSignInError.invalidCallback)
            }
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        self.init(base64Encoded: base64)
    }
}
