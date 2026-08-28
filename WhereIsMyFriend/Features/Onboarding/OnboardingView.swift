import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    // Interactive States for Act 1 (Tactile Toy World)
    @State private var selectedCityIndex: Int? = 0
    @State private var floatingPhase = false
    @State private var cityBounces: [CGFloat] = [1.0, 1.0, 1.0, 1.0]

    // Act 2 (Crystal Glass Shield)
    @State private var shieldScale: CGFloat = 0.8
    @State private var shieldOpacity: Double = 0.0

    // Act 3 (Romantic Aurora Collision & Starlight Serendipity)
    @State private var collisionPhase: CGFloat = 0.0
    @State private var showMergedStage = false
    @State private var showAuroraAlert = false
    @State private var starlightBurst = false

    private let totalSteps = 3

    var body: some View {
        ZStack {
            WIFAmbientBackground()

            VStack(spacing: 0) {
                // Top Progress Indicator
                headerBar
                    .padding(.top, 18)

                Spacer(minLength: 12)

                // 🌟 Centerpiece: Living Liquid Glass Stage
                mainShowcaseStage
                    .padding(.horizontal, 20)

                Spacer(minLength: 16)

                // Ultra-Minimalist Narrative
                narrativeSection
                    .padding(.horizontal, 28)
                    .frame(height: 68)

                Spacer(minLength: 16)

                // Bottom Controls
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

    // MARK: - Main Showcase Stage

    private var mainShowcaseStage: some View {
        ZStack {
            // Liquid Glass Showcase Container
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

            // Dynamic Step Content
            Group {
                switch step {
                case 0:
                    actOneInteractiveToyStage
                case 1:
                    actTwoPrivacyShieldStage
                default:
                    actThreeRomanticSerendipityStage
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .frame(height: 310)
    }

    // MARK: - Act 1: 趣味把玩 · 触碰朋友的世界 (Interactive Living Diorama World)

    private var actOneInteractiveToyStage: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let rx: CGFloat = 88
            let ry: CGFloat = 58

            ZStack {
                // Soft Ambient Halo
                RadialGradient(
                    colors: [
                        WIFTheme.fresh.opacity(0.16),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 140
                )

                // Subtle Glowing Orbit Track
                Ellipse()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                WIFTheme.fresh.opacity(0.35),
                                Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.35),
                                WIFTheme.fresh.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: rx * 2, height: ry * 2)
                    .position(x: cx, y: cy)

                // 4 Interactive Tappable City Nodes

                // 1. Top: New York (You)
                interactiveCityNode(index: 0, city: "New York", countryCode: "US", label: "New York", sub: "You", time: "02:00 🌙")
                    .position(x: cx, y: cy - ry)
                    .offset(y: floatingPhase ? -3 : 3)

                // 2. Right: Tokyo (Lin)
                interactiveCityNode(index: 1, city: "Tokyo", countryCode: "JP", label: "Tokyo", sub: "Lin", time: "15:00 ☀️")
                    .position(x: cx + rx, y: cy)
                    .offset(y: floatingPhase ? 3 : -3)

                // 3. Bottom: London (Mia)
                interactiveCityNode(index: 2, city: "London", countryCode: "GB", label: "London", sub: "Mia", time: "07:00 ☕️")
                    .position(x: cx, y: cy + ry)
                    .offset(y: floatingPhase ? -2 : 2)

                // 4. Left: San Francisco (Alex)
                interactiveCityNode(index: 3, city: "San Francisco", countryCode: "US", label: "SF", sub: "Alex", time: "23:00 🌉")
                    .position(x: cx - rx, y: cy)
                    .offset(y: floatingPhase ? 2 : -2)
            }
        }
    }

    private func interactiveCityNode(index: Int, city: String, countryCode: String, label: String, sub: String, time: String) -> some View {
        let isSelected = selectedCityIndex == index
        return Button {
            tapCity(at: index)
        } label: {
            VStack(spacing: 2) {
                // Playful Popover Bubble on Selected City
                if isSelected {
                    Text(time)
                        .font(.system(size: 8.5, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(white: 0.12).opacity(0.95))
                                .overlay(Capsule().strokeBorder(WIFTheme.fresh.opacity(0.4), lineWidth: 1))
                        )
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }

                CityEmblemView(city: city, countryCode: countryCode, size: 68)
                    .scaleEffect(cityBounces[index])
                    .shadow(color: .black.opacity(0.25), radius: isSelected ? 12 : 6, y: isSelected ? 8 : 4)

                VStack(spacing: 0.5) {
                    Text(label)
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)
                        .lineLimit(1)

                    Text(sub)
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? WIFTheme.fresh : WIFTheme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func tapCity(at index: Int) {
        selectedCityIndex = index
        cityBounces[index] = 1.25
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            cityBounces[index] = 1.0
        }
        triggerHaptic(style: .soft)
    }

    // MARK: - Act 2: 极简留白 (Crystal Glass Cloak)

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

    // MARK: - Act 3: 浪漫同城 · 璀璨相遇 (Romantic Aurora Halo & Starlight Sparkles)

    private var actThreeRomanticSerendipityStage: some View {
        ZStack {
            // Emerald Radiance
            RadialGradient(
                colors: [
                    WIFTheme.fresh.opacity(0.35),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 140
            )

            // Romantic Starlight Particles floating around
            if starlightBurst {
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(WIFTheme.fresh.opacity(0.7))
                        .frame(width: 4, height: 4)
                        .offset(
                            x: CGFloat(cos(Double(i) * .pi / 3)) * 96,
                            y: CGFloat(sin(Double(i) * .pi / 3)) * 80
                        )
                        .scaleEffect(starlightBurst ? 1.2 : 0.2)
                        .opacity(starlightBurst ? 0.8 : 0.0)
                        .animation(.easeOut(duration: 1.2).repeatForever(autoreverses: true).delay(Double(i) * 0.15), value: starlightBurst)
                }
            }

            // Phase 1: Two cities sliding into center
            if !showMergedStage {
                HStack {
                    VStack(spacing: 2) {
                        CityEmblemView(city: "New York", countryCode: "US", size: 76)
                        Text("You")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WIFTheme.primaryText)
                    }
                    .offset(x: collisionPhase * 56)

                    Spacer()

                    VStack(spacing: 2) {
                        CityEmblemView(city: "Tokyo", countryCode: "JP", size: 76)
                        Text("Mia")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(WIFTheme.primaryText)
                    }
                    .offset(x: -collisionPhase * 56)
                }
                .padding(.horizontal, 36)
                .opacity(1.0 - Double(collisionPhase * 0.8))
            }

            // Phase 2: Merged Glowing City Stage
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
                .offset(y: showAuroraAlert ? 18 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: showAuroraAlert)
            }

            // Phase 3: ✨ Romantic Aurora Serendipity Capsule (No rigid system alert box!)
            if showAuroraAlert {
                HStack(spacing: 7) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red: 0.98, green: 0.82, blue: 0.42))

                    Text("今夜同城 · 距离归零")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)

                    Circle()
                        .fill(WIFTheme.fresh)
                        .frame(width: 4, height: 4)

                    Text("Mia Chen")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(WIFTheme.fresh)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.12, green: 0.22, blue: 0.18).opacity(0.95),
                                    Color(white: 0.10).opacity(0.95)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            WIFTheme.fresh.opacity(0.7),
                                            Color(red: 0.98, green: 0.82, blue: 0.42).opacity(0.5)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: WIFTheme.fresh.opacity(0.35), radius: 14, y: 6)
                )
                .offset(y: -96)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
    }

    // MARK: - Ultra-Minimalist Narrative Section

    private var narrativeSection: some View {
        VStack(spacing: 6) {
            switch step {
            case 0:
                Text("把朋友装进桌面")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("随时感知远方，轻触探索世界。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            case 1:
                Text("只知城市")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("零轨迹追踪，零社交压力。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            default:
                Text("偶然同城，惊喜点亮")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("同在这一座城，为你悄然点亮。")
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

        // Start Act 1 FX
        triggerActAnimation(for: 0)
    }

    private func triggerActAnimation(for currentStep: Int) {
        if currentStep == 0 {
            // Auto select a city for demo
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    selectedCityIndex = 1 // Tokyo (Lin)
                }
            }
        } else if currentStep == 1 {
            // Shield descends over Paris
            shieldScale = 0.7
            shieldOpacity = 0.0
            withAnimation(.spring(response: 0.65, dampingFraction: 0.70).delay(0.15)) {
                shieldScale = 1.0
                shieldOpacity = 1.0
            }
            triggerHaptic(style: .soft)
        } else if currentStep == 2 {
            // Act 3 Romantic Flow
            collisionPhase = 0.0
            showMergedStage = false
            showAuroraAlert = false
            starlightBurst = false

            // Stage 1: Glide into center (0.0s -> 0.8s)
            withAnimation(.easeInOut(duration: 0.8).delay(0.15)) {
                collisionPhase = 1.0
            }

            // Stage 2: Merge with starlight (0.95s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
                    showMergedStage = true
                    starlightBurst = true
                }
                triggerHaptic(style: .medium)
            }

            // Stage 3: Romantic Aurora Serendipity Capsule appears (1.4s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    showAuroraAlert = true
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
