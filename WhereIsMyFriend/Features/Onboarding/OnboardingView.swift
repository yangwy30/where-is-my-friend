import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    // Animation Physics States
    @State private var isScattered = false
    @State private var isMerged = false
    @State private var floatingPhase = false
    @State private var particleProgress: CGFloat = 0.0

    private let totalSteps = 3

    var body: some View {
        ZStack {
            WIFAmbientBackground()

            VStack(spacing: 0) {
                // Top Progress Indicator
                progressHeader
                    .padding(.top, 18)

                Spacer(minLength: 12)

                // 🌟 Hero Glass Stage Showcase (Rich, Framed, Deep 3D Stage)
                heroGlassStage
                    .padding(.horizontal, 20)

                Spacer(minLength: 16)

                // Narrative Copy
                narrativeText
                    .padding(.horizontal, 24)
                    .frame(height: 78)

                Spacer(minLength: 16)

                // Bottom Action Controls
                bottomControls
                    .padding(.horizontal, WIFTheme.screenInset)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            startInitialAnimation()
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == step ? WIFTheme.fresh : Color.white.opacity(0.18))
                    .frame(width: index == step ? 28 : 8, height: 4.5)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    // MARK: - Hero Glass Stage (Continuous Living Physics Container)

    private var heroGlassStage: some View {
        ZStack {
            // Frosted Glass Stage Pedestal Container
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 24, y: 12)

            // Inner Stage Content based on current step
            Group {
                switch step {
                case 0:
                    actOneScatterStage
                case 1:
                    actTwoHorizonStage
                default:
                    actThreeReunionStage
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .frame(height: 290)
    }

    // MARK: - Act 1: 散落 (Live Dynamic Burst from Center)

    private var actOneScatterStage: some View {
        ZStack {
            // Ambient Soft Halo
            RadialGradient(
                colors: [
                    WIFTheme.fresh.opacity(0.18),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 130
            )

            // 4 Scattering Cities with independent floating physics
            ZStack {
                // 1. Top Left: New York
                stageDiorama(city: "New York", countryCode: "US", label: "New York")
                    .offset(
                        x: isScattered ? -74 : 0,
                        y: (isScattered ? -56 : 0) + (floatingPhase ? -4 : 4)
                    )
                    .scaleEffect(isScattered ? 1.0 : 0.3)
                    .opacity(isScattered ? 1.0 : 0.0)

                // 2. Top Right: London
                stageDiorama(city: "London", countryCode: "GB", label: "London")
                    .offset(
                        x: isScattered ? 74 : 0,
                        y: (isScattered ? -56 : 0) + (floatingPhase ? 4 : -4)
                    )
                    .scaleEffect(isScattered ? 1.0 : 0.3)
                    .opacity(isScattered ? 1.0 : 0.0)

                // 3. Bottom Left: San Francisco
                stageDiorama(city: "San Francisco", countryCode: "US", label: "SF")
                    .offset(
                        x: isScattered ? -74 : 0,
                        y: (isScattered ? 56 : 0) + (floatingPhase ? 3 : -3)
                    )
                    .scaleEffect(isScattered ? 1.0 : 0.3)
                    .opacity(isScattered ? 1.0 : 0.0)

                // 4. Bottom Right: Tokyo
                stageDiorama(city: "Tokyo", countryCode: "JP", label: "Tokyo")
                    .offset(
                        x: isScattered ? 74 : 0,
                        y: (isScattered ? 56 : 0) + (floatingPhase ? -3 : 3)
                    )
                    .scaleEffect(isScattered ? 1.0 : 0.3)
                    .opacity(isScattered ? 1.0 : 0.0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            replayScatterAnimation()
        }
    }

    private func stageDiorama(city: String, countryCode: String, label: String) -> some View {
        VStack(spacing: 4) {
            CityEmblemView(city: city, countryCode: countryCode, size: 66)

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WIFTheme.primaryText)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        )
    }

    // MARK: - Act 2: 挂念 (Dual Horizon with Flowing Light Beam)

    private var actTwoHorizonStage: some View {
        ZStack {
            // Connecting Laser Horizon
            HStack(spacing: 0) {
                Spacer(minLength: 60)

                ZStack {
                    // Static Track Line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    WIFTheme.fresh.opacity(0.3),
                                    Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)

                    // Traveling Particle
                    Circle()
                        .fill(WIFTheme.fresh)
                        .frame(width: 6, height: 6)
                        .shadow(color: WIFTheme.fresh.opacity(0.9), radius: 6)
                        .offset(x: (particleProgress - 0.5) * 110)
                }

                Spacer(minLength: 60)
            }

            HStack {
                // Left: User City
                VStack(spacing: 4) {
                    CityEmblemView(city: "New York", countryCode: "US", size: 84)
                    Text("New York")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .offset(y: floatingPhase ? -3 : 3)

                Spacer(minLength: 24)

                // Right: Friend City
                VStack(spacing: 4) {
                    CityEmblemView(city: "Tokyo", countryCode: "JP", size: 84)
                    VStack(spacing: 1) {
                        Text("Tokyo")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.primaryText)
                        Text("Lin")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.fresh)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .offset(y: floatingPhase ? 3 : -3)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Act 3: 重聚 (Magnetic Merged Hero Stage)

    private var actThreeReunionStage: some View {
        ZStack {
            // Emerald Radiance Halo
            RadialGradient(
                colors: [
                    WIFTheme.fresh.opacity(0.28),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 130
            )

            // Centered Hero Stage
            VStack(spacing: 8) {
                CityEmblemView(city: "New York", countryCode: "US", size: 100)
                    .scaleEffect(isMerged ? 1.0 : 0.85)

                VStack(spacing: 4) {
                    Text("New York")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)

                    HStack(spacing: 4) {
                        Circle()
                            .fill(WIFTheme.fresh)
                            .frame(width: 5, height: 5)
                        Text("Mia · 2 together")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WIFTheme.fresh)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(WIFTheme.fresh.opacity(0.18)))
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(WIFTheme.fresh.opacity(0.45), lineWidth: 1)
                    )
                    .shadow(color: WIFTheme.fresh.opacity(0.2), radius: 18)
            )
            .offset(y: floatingPhase ? -3 : 3)
        }
    }

    // MARK: - Narrative Text

    private var narrativeText: some View {
        VStack(spacing: 8) {
            switch step {
            case 0:
                Text("散落世界的朋友")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("山海相隔，依然相连。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            case 1:
                Text("只知城市，不添打扰")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("不查轨迹，知道你平安便好。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            default:
                Text("同一座城，偶然重逢")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("当轨迹重叠，点亮这一刻。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
        }
        .multilineTextAlignment(.center)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    // MARK: - Bottom Action Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Button(action: advance) {
                HStack(spacing: 8) {
                    if step == totalSteps - 1 {
                        Image(systemName: "apple.logo")
                    }
                    Text(step == totalSteps - 1 ? "开启" : "继续")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .foregroundStyle(WIFTheme.primaryText)
            .wifGlassButton(tint: WIFTheme.fresh.opacity(0.35), prominent: true)
            .accessibilityIdentifier("onboardingContinueButton")

            Text(step == totalSteps - 1
                 ? "只分享城市 · 随时可暂停"
                 : "左右轻扫浏览")
                .font(.caption2)
                .foregroundStyle(WIFTheme.secondaryText)
        }
    }

    // MARK: - Animation Drivers

    private func advance() {
        if step == totalSteps - 1 {
            onComplete()
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            step += 1
            handleStepTransition(step)
        }
    }

    private func startInitialAnimation() {
        // Continuous floating loop
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            floatingPhase = true
        }

        // Continuous beam particle loop
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            particleProgress = 1.0
        }

        // Visible delayed burst animation (waits for sheet transition to finish)
        replayScatterAnimation()
    }

    private func replayScatterAnimation() {
        isScattered = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.65)) {
                isScattered = true
            }
            triggerHaptic(style: .soft)
        }
    }

    private func handleStepTransition(_ newStep: Int) {
        if newStep == 0 {
            replayScatterAnimation()
        } else if newStep == 2 {
            isMerged = false
            withAnimation(.spring(response: 0.65, dampingFraction: 0.68).delay(0.1)) {
                isMerged = true
            }
            triggerHaptic(style: .medium)
        } else {
            triggerHaptic(style: .soft)
        }
    }

    private func triggerHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
