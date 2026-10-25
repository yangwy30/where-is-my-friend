import SwiftUI

enum EmailSignInInput {
    /// Supabase sends 6-digit codes by default; projects can raise it to 10.
    static let codeLengths = 6...10
    static let autoSubmitLength = 6
    static let resendDelay: TimeInterval = 60

    static func normalizedEmail(_ value: String) -> String? {
        let email = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard email.count <= 254, parts.count == 2, !parts[0].isEmpty,
              parts[1].contains("."), !parts[1].hasPrefix("."), !parts[1].hasSuffix("."),
              !email.contains(where: \.isWhitespace)
        else { return nil }
        return email
    }

    static func normalizedCode(_ value: String) -> String {
        String(value.filter(\.isASCIIDigit).prefix(codeLengths.upperBound))
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}

struct EmailCodeSignInView: View {
    private enum Field { case email, code }

    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var sentTo: String?
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var isVerifying = false
    @State private var resendAvailableAt = Date.distantPast
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(sentTo == nil ? "Continue with email" : "Enter the code")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)

                Group {
                    if let sentTo {
                        Text("We sent a code to \(sentTo).")
                    } else {
                        Text("We’ll email you a code. No password needed.")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
                .padding(.top, 6)

                if sentTo == nil {
                    emailStep
                } else {
                    codeStep
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(WIFTheme.destructive)
                        .padding(.top, 10)
                        .accessibilityIdentifier("emailSignInError")
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, WIFTheme.screenInset)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WIFTheme.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isVerifying)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isVerifying)
        .onAppear { focusedField = .email }
    }

    private var emailStep: some View {
        VStack(spacing: 14) {
            TextField("Email address", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focusedField, equals: .email)
                .onSubmit { Task { await sendCode() } }
                .inputFieldStyle()
                .accessibilityIdentifier("emailSignInAddressField")

            primaryButton(
                title: "Send code",
                isEnabled: EmailSignInInput.normalizedEmail(email) != nil,
                isBusy: isSending
            ) {
                Task { await sendCode() }
            }
            .accessibilityIdentifier("emailSignInSendButton")
        }
        .padding(.top, 22)
    }

    private var codeStep: some View {
        VStack(spacing: 14) {
            TextField("Code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .focused($focusedField, equals: .code)
                .inputFieldStyle()
                .onChange(of: code) { _, newValue in
                    let normalized = EmailSignInInput.normalizedCode(newValue)
                    if normalized != newValue { code = normalized }
                    if normalized.count == EmailSignInInput.autoSubmitLength, !isVerifying {
                        Task { await verify() }
                    }
                }
                .accessibilityIdentifier("emailSignInCodeField")

            primaryButton(
                title: "Sign in",
                isEnabled: EmailSignInInput.codeLengths.contains(code.count),
                isBusy: isVerifying
            ) {
                Task { await verify() }
            }
            .accessibilityIdentifier("emailSignInVerifyButton")

            HStack {
                Button("Use a different email") {
                    sentTo = nil
                    code = ""
                    errorMessage = nil
                    focusedField = .email
                }
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = Int(resendAvailableAt.timeIntervalSince(context.date).rounded(.up))
                    Button(remaining > 0 ? String(localized: "Resend in \(remaining)s") : String(localized: "Resend code")) {
                        Task { await sendCode() }
                    }
                    .disabled(remaining > 0 || isSending)
                    .foregroundStyle(remaining > 0 ? WIFTheme.secondaryText : WIFTheme.fresh)
                    .monospacedDigit()
                }
            }
            .font(.subheadline)
            .foregroundStyle(WIFTheme.fresh)
            .disabled(isVerifying)
        }
        .padding(.top, 22)
    }

    private func primaryButton(title: LocalizedStringKey, isEnabled: Bool, isBusy: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Text(title).opacity(isBusy ? 0 : 1)
                if isBusy { ProgressView().tint(WIFTheme.canvas) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 44)
            .wifPrimaryActionLabel(enabled: isEnabled || isBusy)
        }
        .wifPrimaryActionStyle()
        .disabled(!isEnabled || isBusy)
    }

    private func sendCode() async {
        guard !isSending, let address = EmailSignInInput.normalizedEmail(sentTo ?? email) else {
            if sentTo == nil { errorMessage = String(localized: "Enter a valid email address.") }
            return
        }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        if let failure = await store.sendEmailSignInCode(to: address) {
            errorMessage = failure
            return
        }
        resendAvailableAt = Date().addingTimeInterval(EmailSignInInput.resendDelay)
        code = ""
        sentTo = address
        focusedField = .code
    }

    private func verify() async {
        guard !isVerifying, let sentTo, EmailSignInInput.codeLengths.contains(code.count) else { return }
        isVerifying = true
        errorMessage = nil
        defer { isVerifying = false }
        var failure: String?
        await store.signIn(.emailCode(email: sentTo, code: code)) { failure = $0 }
        if let failure {
            errorMessage = failure
            code = ""
            focusedField = .code
        }
    }
}

private extension View {
    func inputFieldStyle() -> some View {
        padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(WIFTheme.border, lineWidth: 1)
            }
    }
}

#Preview {
    EmailCodeSignInView()
        .environmentObject(AppStore())
}
