import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    // Continuous Fluid Physics & Visual FX States
    @State private var floatingPhase = false
    @State private var particleOffset: CGFloat = -1.0
    @State private var shieldScale: CGFloat = 0.8
    @State private var shieldOpacity: Double = 0.0
    @State private var collisionProgress: CGFloat = 0.0
    @State private var rippleActive = false

    private let totalSteps = 3

    var body: some View {
        ZStack {
            WIFAmbientBackground()

            VStack(spacing: 0) {
                // Top Indicator
                headerBar
                    .padding(.top, 18)

                Spacer(minLength: 16)

                // 🌟 Centerpiece: Cinematic Liquid Glass 3D Stage
                mainShowcaseStage
                    .padding(.horizontal, 20)

                Spacer(minLength: 20)

                // Narrative Copy
                narrativeSection
                    .padding(.horizontal, 28)
                    .frame(height: 72)

                Spacer(minLength: 16)

                // Bottom CTA Controls
                bottomControls
                    .padding(.horizontal, WIFTheme.screenInset)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            startContinuousEngines()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == step ? WIFTheme.fresh : Color.white.opacity(0.18))
                    .frame(width: index == step ? 30 : 8, height: 4.5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    // MARK: - Showcase Stage

    private var mainShowcaseStage: some View {
        ZStack {
            // Luxury Frosted Glass Stage Container
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 24, y: 12)

            // Stage Content Switcher
            Group {
                switch step {
                case 0:
                    actOneDualOrbitStage
                case 1:
                    actTwoPrivacyShieldStage
                default:
                    actThreeReunionCollisionStage
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .frame(height: 310)
    }

    // MARK: - Act 1: 跨国对望 (Dual Orbit Horizon with Aurora Particle Beam)

    private var actOneDualOrbitStage: some View {
        ZStack {
            // Ambient Horizon Halo
            RadialGradient(
                colors: [
                    WIFTheme.fresh.opacity(0.16),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 140
            )

            // Connecting Aurora Horizon Beam
            HStack(spacing: 0) {
                Spacer(minLength: 70)

                ZStack {
                    // Soft Glowing Track
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    WIFTheme.fresh.opacity(0.35),
                                    Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.35)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)

                    // Flying Aurora Particle
                    Circle()
                        .fill(WIFTheme.fresh)
                        .frame(width: 7, height: 7)
                        .shadow(color: WIFTheme.fresh.opacity(0.95), radius: 8)
                        .offset(x: particleOffset * 54)
                }

                Spacer(minLength: 70)
            }

            // Left & Right Hero 3D Dioramas
            HStack {
                // Left: New York
                VStack(spacing: 5) {
                    CityEmblemView(city: "New York", countryCode: "US", size: 88)
                    Text("New York")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .offset(y: floatingPhase ? -4 : 4)

                Spacer(minLength: 28)

                // Right: Tokyo
                VStack(spacing: 5) {
                    CityEmblemView(city: "Tokyo", countryCode: "JP", size: 88)
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
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
                .offset(y: floatingPhase ? 4 : -4)
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Act 2: 纯净留白 (Crystal Glass Shield Descending over Paris)

    private var actTwoPrivacyShieldStage: some View {
        ZStack {
            // Soft Emerald Ambient Sphere
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            WIFTheme.fresh.opacity(0.20),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)

            // Center: Paris Hero Diorama
            VStack(spacing: 6) {
                CityEmblemView(city: "Paris", countryCode: "FR", size: 104)

                Text("Paris")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(WIFTheme.primaryText)
            }
            .offset(y: floatingPhase ? -3 : 3)

            // Descending Protective Glass Cloak Ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            WIFTheme.fresh.opacity(0.8),
                            WIFTheme.fresh.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.8
                )
                .frame(width: 190, height: 190)
                .background(
                    Circle()
                        .fill(WIFTheme.fresh.opacity(0.05))
                )
                .scaleEffect(shieldScale)
                .opacity(shieldOpacity)
                .shadow(color: WIFTheme.fresh.opacity(0.35), radius: 14)

            // Privacy Capsule Badge
            HStack(spacing: 5) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("城市级共享 · 零轨迹追踪")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
            }
            .foregroundStyle(WIFTheme.fresh)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(white: 0.10).opacity(0.92))
                    .overlay(Capsule().strokeBorder(WIFTheme.fresh.opacity(0.35), lineWidth: 1))
            )
            .offset(y: 92)
            .opacity(shieldOpacity)
        }
    }

    // MARK: - Act 3: 磁吸重聚 (Magnetic Collision & Merged Same-City Hero Stage)

    private var actThreeReunionCollisionStage: some View {
        ZStack {
            // Expanding Shockwave Ripple when merged
            if rippleActive {
                Circle()
                    .strokeBorder(WIFTheme.fresh.opacity(0.4), lineWidth: 1.5)
                    .frame(width: 260, height: 260)
                    .scaleEffect(1.3)
                    .opacity(0.0)
                    .animation(.easeOut(duration: 0.8), value: rippleActive)
            }

            // Emerald Radiance
            RadialGradient(
                colors: [
                    WIFTheme.fresh.opacity(0.30),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 140
            )

            // Sliding In State vs Final Unified Stage
            if collisionProgress < 0.95 {
                HStack {
                    stagePedestalMini(city: "New York", countryCode: "US", label: "You")
                        .offset(x: collisionProgress * 48)

                    Spacer()

                    stagePedestalMini(city: "Tokyo", countryCode: "JP", label: "Mia")
                        .offset(x: -collisionProgress * 48)
                }
                .padding(.horizontal, 36)
                .opacity(1.0 - Double(collisionProgress))
            }

            // Merged Final Stage
            VStack(spacing: 8) {
                CityEmblemView(city: "New York", countryCode: "US", size: 104)

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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(WIFTheme.fresh.opacity(0.20)))
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(WIFTheme.fresh.opacity(0.45), lineWidth: 1.2)
                    )
                    .shadow(color: WIFTheme.fresh.opacity(0.28), radius: 20)
            )
            .scaleEffect(collisionProgress > 0.9 ? 1.0 : 0.75)
            .opacity(collisionProgress > 0.9 ? 1.0 : 0.0)
            .offset(y: floatingPhase ? -3 : 3)
        }
    }

    private func stagePedestalMini(city: String, countryCode: String, label: String) -> some View {
        VStack(spacing: 4) {
            CityEmblemView(city: city, countryCode: countryCode, size: 76)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WIFTheme.primaryText)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Narrative Section

    private var narrativeSection: some View {
        VStack(spacing: 8) {
            switch step {
            case 0:
                Text("跨越时区，相连彼此")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("散落世界各地的朋友，一眼看清彼此的城市。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            case 1:
                Text("只知城市，不添打扰")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("不记录轨迹，不查经纬度。知道你平安，便已足够。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            default:
                Text("若有幸同城，街角偶遇")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("当生活轨迹再次重叠，App 会替你点亮这一刻。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }
        }
        .multilineTextAlignment(.center)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Button(action: advance) {
                HStack(spacing: 8) {
                    if step == totalSteps - 1 {
                        Image(systemName: "apple.logo")
                    }
                    Text(step == totalSteps - 1 ? "开始探索" : "继续")
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

    // MARK: - Transitions & Physics Drivers

    private func advance() {
        if step == totalSteps - 1 {
            onComplete()
            return
        }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            step += 1
            triggerActAnimation(for: step)
        }
    }

    private func startContinuousEngines() {
        // Floating loop
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            floatingPhase = true
        }

        // Particle beam loop
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            particleOffset = 1.0
        }

        // Start Act 1 FX
        triggerActAnimation(for: 0)
    }

    private func triggerActAnimation(for currentStep: Int) {
        if currentStep == 1 {
            // Shield descends over Paris
            shieldScale = 0.7
            shieldOpacity = 0.0
            withAnimation(.spring(response: 0.65, dampingFraction: 0.70).delay(0.15)) {
                shieldScale = 1.0
                shieldOpacity = 1.0
            }
            triggerHaptic(style: .soft)
        } else if currentStep == 2 {
            // Magnetic collision
            collisionProgress = 0.0
            rippleActive = false
            withAnimation(.easeInOut(duration: 0.65).delay(0.1)) {
                collisionProgress = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                rippleActive = true
                triggerHaptic(style: .medium)
            }
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
