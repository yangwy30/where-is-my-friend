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
    @State private var orbitRotation: Double = 0.0
    @State private var shieldScale: CGFloat = 0.8
    @State private var shieldOpacity: Double = 0.0

    // Act 3 Cinematic Multi-Stage Animation
    @State private var collisionPhase: CGFloat = 0.0
    @State private var showMergedStage = false
    @State private var showNotificationBanner = false
    @State private var shockwaveRadius: CGFloat = 10.0
    @State private var shockwaveOpacity: Double = 0.0

    private let totalSteps = 3

    var body: some View {
        ZStack {
            WIFAmbientBackground()

            VStack(spacing: 0) {
                // Top Progress Indicator
                headerBar
                    .padding(.top, 18)

                Spacer(minLength: 12)

                // 🌟 Centerpiece: Cinematic Liquid Glass Stage
                mainShowcaseStage
                    .padding(.horizontal, 20)

                Spacer(minLength: 16)

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
            // Seamless Frosted Glass Stage Container
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
                    actOneFourCityOrbitStage
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

    // MARK: - Act 1: 全球四城 · 星系引力环 (4-City Celestial Orbit Ring)

    private var actOneFourCityOrbitStage: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let rx: CGFloat = 88
            let ry: CGFloat = 58

            ZStack {
                // Soft Ambient Center Radial Halo
                RadialGradient(
                    colors: [
                        WIFTheme.fresh.opacity(0.18),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 140
                )

                // 💫 Celestial Elliptical Orbit Track
                Ellipse()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                WIFTheme.fresh.opacity(0.40),
                                Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.35),
                                WIFTheme.fresh.opacity(0.40)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: rx * 2, height: ry * 2)
                    .position(x: cx, y: cy)

                // Traveling Aurora Particle around orbit
                Circle()
                    .fill(WIFTheme.fresh)
                    .frame(width: 6, height: 6)
                    .shadow(color: WIFTheme.fresh.opacity(0.95), radius: 8)
                    .position(
                        x: cx + rx * cos(orbitRotation * .pi / 180),
                        y: cy + ry * sin(orbitRotation * .pi / 180)
                    )

                // 4 Global Cities (Equally spaced around orbit)

                // 1. Top: New York (You)
                citySeamlessNode(city: "New York", countryCode: "US", label: "New York", sub: "You", size: 68)
                    .position(x: cx, y: cy - ry)
                    .offset(y: floatingPhase ? -3 : 3)

                // 2. Right: Tokyo (Lin)
                citySeamlessNode(city: "Tokyo", countryCode: "JP", label: "Tokyo", sub: "Lin", size: 68)
                    .position(x: cx + rx, y: cy)
                    .offset(y: floatingPhase ? 3 : -3)

                // 3. Bottom: London (Mia)
                citySeamlessNode(city: "London", countryCode: "GB", label: "London", sub: "Mia", size: 68)
                    .position(x: cx, y: cy + ry)
                    .offset(y: floatingPhase ? -2 : 2)

                // 4. Left: San Francisco (Alex)
                citySeamlessNode(city: "San Francisco", countryCode: "US", label: "SF", sub: "Alex", size: 68)
                    .position(x: cx - rx, y: cy)
                    .offset(y: floatingPhase ? 2 : -2)
            }
        }
    }

    // Seamless Floating Node
    private func citySeamlessNode(city: String, countryCode: String, label: String, sub: String, size: CGFloat) -> some View {
        VStack(spacing: 2) {
            CityEmblemView(city: city, countryCode: countryCode, size: size)
                .shadow(color: .black.opacity(0.22), radius: 8, y: 5)

            VStack(spacing: 0.5) {
                Text(label)
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .lineLimit(1)

                Text(sub)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(WIFTheme.fresh)
                    .lineLimit(1)
            }
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

            // Center: Paris Hero Diorama (Seamless)
            VStack(spacing: 3) {
                CityEmblemView(city: "Paris", countryCode: "FR", size: 104)
                    .shadow(color: .black.opacity(0.25), radius: 14, y: 8)

                VStack(spacing: 1) {
                    Text("Paris")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                    Text("Chloe")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WIFTheme.fresh)
                }
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
            .offset(y: 94)
            .opacity(shieldOpacity)
        }
    }

    // MARK: - Act 3: 奇迹重逢 + 同城通知提醒 (Reunion Collision & Push Alert Banner)

    private var actThreeReunionCollisionStage: some View {
        ZStack {
            // Emerald Radiance
            RadialGradient(
                colors: [
                    WIFTheme.fresh.opacity(0.32),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 140
            )

            // Shockwave Ring on Collision
            Circle()
                .strokeBorder(WIFTheme.fresh.opacity(shockwaveOpacity), lineWidth: 2)
                .frame(width: shockwaveRadius, height: shockwaveRadius)

            // Phase 1: Two cities sliding in from sides
            if !showMergedStage {
                HStack {
                    citySeamlessNode(city: "New York", countryCode: "US", label: "New York", sub: "You", size: 76)
                        .offset(x: collisionPhase * 56)

                    Spacer()

                    citySeamlessNode(city: "Tokyo", countryCode: "JP", label: "Tokyo", sub: "Mia", size: 76)
                        .offset(x: -collisionPhase * 56)
                }
                .padding(.horizontal, 36)
                .opacity(1.0 - Double(collisionPhase * 0.8))
            }

            // Phase 2: Merged Hero Stage
            if showMergedStage {
                VStack(spacing: 6) {
                    CityEmblemView(city: "New York", countryCode: "US", size: 94)
                        .shadow(color: .black.opacity(0.28), radius: 14, y: 8)

                    VStack(spacing: 3) {
                        Text("New York")
                            .font(.system(.headline, design: .rounded, weight: .bold))
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
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(WIFTheme.fresh.opacity(0.20)))
                    }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .offset(y: showNotificationBanner ? 22 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: showNotificationBanner)
            }

            // Phase 3: 🔔 iOS Dropdown Notification Banner (宣传核心“同城提醒”功能)
            if showNotificationBanner {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(WIFTheme.fresh)

                        Text("SAME CITY MOMENT")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.fresh)

                        Spacer()

                        Text("NOW")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(WIFTheme.secondaryText)
                    }

                    Text("你和 Mia 今晚都在 New York 📍")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(white: 0.12).opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(WIFTheme.fresh.opacity(0.40), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
                )
                .padding(.horizontal, 20)
                .offset(y: -96)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
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
                Text("如果刚好同城，自动通知提醒")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("当轨迹重叠，App 会第一时间为你捕捉相遇瞬间。")
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

        // Orbit rotation loop (smoother and continuous)
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            orbitRotation = 360.0
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
            // Act 3 Cinematic Multi-Stage Flow:
            collisionPhase = 0.0
            showMergedStage = false
            showNotificationBanner = false
            shockwaveRadius = 10.0
            shockwaveOpacity = 0.0

            // Stage 1: Slow-burn approach (0.0s -> 0.8s)
            withAnimation(.easeInOut(duration: 0.8).delay(0.15)) {
                collisionPhase = 1.0
            }

            // Stage 2: Merge & Shockwave explosion (0.95s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
                    showMergedStage = true
                }
                withAnimation(.easeOut(duration: 0.7)) {
                    shockwaveRadius = 240.0
                    shockwaveOpacity = 0.6
                }
                withAnimation(.easeOut(duration: 0.7).delay(0.3)) {
                    shockwaveOpacity = 0.0
                }
                triggerHaptic(style: .medium)
            }

            // Stage 3: Notification Dropdown Banner (1.5s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    showNotificationBanner = true
                }
                triggerSuccessHaptic()
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

    private func triggerSuccessHaptic() {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
