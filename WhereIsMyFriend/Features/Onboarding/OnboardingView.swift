import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    private let pages = [
        OnboardingPage(
            title: "Your people, around the world",
            body: "See the latest city your closest friends have chosen to share — without starting another group chat.",
            symbol: "person.2.fill",
            buttonTitle: "See how it works"
        ),
        OnboardingPage(
            title: "City-level by design",
            body: "Friends see a city and an update time. Precise coordinates and route history are not part of this experience.",
            symbol: "hand.raised.fill",
            buttonTitle: "Continue"
        ),
        OnboardingPage(
            title: "Keep your city current",
            body: "Background location lets the app notice meaningful city changes. You can pause sharing at any time.",
            symbol: "location.fill.viewfinder",
            buttonTitle: "Continue to sign in"
        )
    ]

    var body: some View {
        ZStack {
            WIFAmbientBackground()

            VStack(spacing: 0) {
                progress
                    .padding(.top, 16)

                Spacer(minLength: 24)

                OnboardingIllustration(pageIndex: step, symbol: pages[step].symbol)
                    .id(step)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))

                Spacer(minLength: 28)

                VStack(spacing: 12) {
                    Text(pages[step].title)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                        .multilineTextAlignment(.center)

                    Text(pages[step].body)
                        .font(.body)
                        .foregroundStyle(WIFTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 28)

                Button(action: advance) {
                    HStack(spacing: 8) {
                        if step == pages.count - 1 {
                            Image(systemName: "apple.logo")
                        }
                        Text(pages[step].buttonTitle)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .foregroundStyle(WIFTheme.primaryText)
                .wifGlassButton(tint: WIFTheme.fresh.opacity(0.34), prominent: true)
                .accessibilityIdentifier("onboardingContinueButton")
                .padding(.horizontal, WIFTheme.screenInset)

                Text(step == pages.count - 1
                     ? "Apple sign-in comes next"
                     : "A quick introduction before you start")
                    .font(.caption)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
            }
        }
    }

    private var progress: some View {
        HStack(spacing: 7) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? WIFTheme.fresh : WIFTheme.border)
                    .frame(width: index == step ? 30 : 10, height: 7)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .wifGlassSurface(tint: WIFTheme.surface.opacity(0.08), in: Capsule())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: step)
        .accessibilityLabel("Step \(step + 1) of \(pages.count)")
    }

    private func advance() {
        if step == pages.count - 1 {
            onComplete()
            return
        }

        if reduceMotion {
            step += 1
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                step += 1
            }
        }
    }
}

private struct OnboardingPage {
    let title: LocalizedStringKey
    let body: LocalizedStringKey
    let symbol: String
    let buttonTitle: LocalizedStringKey
}

private struct OnboardingIllustration: View {
    let pageIndex: Int
    let symbol: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(WIFTheme.fresh.opacity(0.28), style: StrokeStyle(lineWidth: 3, dash: [8, 8]))
                .frame(width: 210, height: 150)
                .rotationEffect(.degrees(-12))

            Image(systemName: symbol)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(WIFTheme.fresh)
                .symbolRenderingMode(.hierarchical)

            if pageIndex == 0 {
                avatar(initials: "M", color: .pink, x: -102, y: 66)
                avatar(initials: "L", color: .mint, x: 104, y: -66)
            } else if pageIndex == 2 {
                cityLabel("NEW YORK", x: -74, y: 88)
                cityLabel("TOKYO", x: 82, y: -86)
            }
        }
        .frame(maxWidth: 310, maxHeight: 280)
        .frame(height: 280)
        .wifGlassSurface(
            tint: WIFTheme.eventBlue.opacity(0.18),
            in: RoundedRectangle(cornerRadius: 36, style: .continuous)
        )
        .padding(.horizontal, WIFTheme.screenInset)
        .accessibilityHidden(true)
    }

    private func avatar(initials: String, color: Color, x: CGFloat, y: CGFloat) -> some View {
        Text(initials)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(color.gradient, in: Circle())
            .overlay { Circle().stroke(WIFTheme.surface, lineWidth: 3) }
            .offset(x: x, y: y)
    }

    private func cityLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(WIFTheme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .wifGlassSurface(tint: WIFTheme.surface.opacity(0.10), in: Capsule())
            .offset(x: x, y: y)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
