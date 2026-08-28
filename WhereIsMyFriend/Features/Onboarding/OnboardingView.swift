import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    // Act 1 Hero Carousel State
    @State private var act1CityIndex = 0
    @State private var floatingPhase = false

    // Act 2 Crystal Halo State
    @State private var shieldScale: CGFloat = 0.8
    @State private var shieldOpacity: Double = 0.0

    // Act 3 Cinematic Serendipity Bloom
    @State private var collisionPhase: CGFloat = 0.0
    @State private var showMergedStage = false
    @State private var showMomentCard = false
    @State private var auraRadius: CGFloat = 20.0
    @State private var auraOpacity: Double = 0.0

    private let totalSteps = 3

    var body: some View {
        ZStack {
            WIFAmbientBackground()

            VStack(spacing: 0) {
                // Top Indicator
                headerBar
                    .padding(.top, 18)

                Spacer(minLength: 12)

                // 🌟 Centerpiece: Hero Liquid Glass Stage
                mainShowcaseStage
                    .padding(.horizontal, 20)

                Spacer(minLength: 20)

                // Narrative Copy
                narrativeSection
                    .padding(.horizontal, 28)
                    .frame(height: 70)

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
                    .fill(index == step ? WIFTheme.fresh : Color.black.opacity(0.12))
                    .frame(width: index == step ? 30 : 8, height: 4.5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.40))
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    // MARK: - Showcase Stage

    private var mainShowcaseStage: some View {
        ZStack {
            // Ethereal White Frosted Glass Showcase Container
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.70), lineWidth: 1.2)
                )
                .shadow(color: Color(red: 0.1, green: 0.3, blue: 0.2).opacity(0.08), radius: 24, y: 12)

            // Dynamic Step Content
            Group {
                switch step {
                case 0:
                    actOneHeroDioramaCarouselStage
                case 1:
                    actTwoPrivacyShieldStage
                default:
                    actThreeCinematicReunionStage
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .frame(height: 320)
    }

    // MARK: - Act 1: 巨幅手办轮播 · 把朋友装进桌面 (Large Hero 3D Diorama Carousel)

    private let carouselCities = [
        (city: "Tokyo", country: "JP", name: "Lin Zhao", label: "Tokyo", time: "15:00", mood: "☀️ 下午茶时间"),
        (city: "New York", country: "US", name: "You", label: "New York", time: "02:00", mood: "🌙 深夜星空"),
        (city: "London", country: "GB", name: "Mia Chen", label: "London", time: "07:00", mood: "☕️ 晨光初醒")
    ]

    private var actOneHeroDioramaCarouselStage: some View {
        TabView(selection: $act1CityIndex) {
            ForEach(0..<carouselCities.count, id: \.self) { index in
                let item = carouselCities[index]
                VStack(spacing: 8) {
                    Spacer(minLength: 0)

                    // Hero 112pt Large 3D Diorama
                    CityEmblemView(city: item.city, countryCode: item.country, size: 116)
                        .shadow(color: Color.black.opacity(0.12), radius: 14, y: 8)
                        .offset(y: floatingPhase ? -4 : 4)

                    // Crisp Ethereal Pill
                    VStack(spacing: 3) {
                        Text(item.label)
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.primaryText)

                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(WIFTheme.fresh)

                            Circle()
                                .fill(WIFTheme.secondaryText.opacity(0.4))
                                .frame(width: 3.5, height: 3.5)

                            Text(item.mood)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(WIFTheme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.60))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.80), lineWidth: 1))
                            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                    )

                    Spacer(minLength: 0)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
    }

    // MARK: - Act 2: 纯净留白 · 城市级安心 (Crystal Glass Cloak over Paris)

    private var actTwoPrivacyShieldStage: some View {
        ZStack {
            // Radiant Light Sphere
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            WIFTheme.fresh.opacity(0.22),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                )
                .frame(width: 230, height: 230)

            // Center: Paris Hero Diorama (116pt)
            VStack(spacing: 6) {
                CityEmblemView(city: "Paris", countryCode: "FR", size: 116)
                    .shadow(color: Color.black.opacity(0.14), radius: 16, y: 8)

                VStack(spacing: 2) {
                    Text("Paris")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                    Text("Chloe")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(WIFTheme.fresh)
                }
            }
            .offset(y: floatingPhase ? -3 : 3)

            // Descending Ethereal Crystal Halo Ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            WIFTheme.fresh.opacity(0.85),
                            WIFTheme.fresh.opacity(0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .frame(width: 200, height: 200)
                .background(
                    Circle()
                        .fill(WIFTheme.fresh.opacity(0.04))
                )
                .scaleEffect(shieldScale)
                .opacity(shieldOpacity)
                .shadow(color: WIFTheme.fresh.opacity(0.25), radius: 14)

            // Privacy Ethereal Badge
            HStack(spacing: 5) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("城市级共享 · 零轨迹追踪")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(WIFTheme.fresh)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.85))
                    .overlay(Capsule().strokeBorder(WIFTheme.fresh.opacity(0.40), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.06), radius: 8, y: 3)
            )
            .offset(y: 104)
            .opacity(shieldOpacity)
        }
    }

    // MARK: - Act 3: 浪漫同城 · 璀璨相遇提醒 (Serendipity Bloom & Luminous Alert Card)

    private var actThreeCinematicReunionStage: some View {
        ZStack {
            // Emerald Luminous Radiance
            RadialGradient(
                colors: [
                    WIFTheme.fresh.opacity(0.28),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 150
            )

            // Expanding Celestial Light Aura on Merge
            Circle()
                .strokeBorder(WIFTheme.fresh.opacity(auraOpacity), lineWidth: 2)
                .frame(width: auraRadius, height: auraRadius)

            // Phase 1: Two cities sliding into center
            if !showMergedStage {
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        CityEmblemView(city: "New York", countryCode: "US", size: 84)
                        Text("You")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(WIFTheme.primaryText)
                    }
                    .offset(x: collisionPhase * 54)

                    Spacer()

                    VStack(spacing: 4) {
                        CityEmblemView(city: "Tokyo", countryCode: "JP", size: 84)
                        Text("Mia")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(WIFTheme.primaryText)
                    }
                    .offset(x: -collisionPhase * 54)
                }
                .padding(.horizontal, 32)
                .opacity(1.0 - Double(collisionPhase * 0.7))
            }

            // Phase 2: Merged Hero New York Monument
            if showMergedStage {
                VStack(spacing: 8) {
                    CityEmblemView(city: "New York", countryCode: "US", size: 108)
                        .shadow(color: Color.black.opacity(0.16), radius: 16, y: 8)

                    VStack(spacing: 4) {
                        Text("New York")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.primaryText)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(WIFTheme.fresh)
                                .frame(width: 5, height: 5)
                            Text("Mia · 2 together")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(WIFTheme.fresh)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(WIFTheme.fresh.opacity(0.18)))
                    }
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .offset(y: showMomentCard ? 28 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.78), value: showMomentCard)
            }

            // Phase 3: 🔔 Luminous High-Impact "Same City Moment" Card (Visible, Cinematic & Clean)
            if showMomentCard {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.20))

                        Text("SAME CITY MOMENT")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.fresh)

                        Spacer()

                        Text("NOW")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(WIFTheme.secondaryText)
                    }

                    Text("你和 Mia 今晚都在 New York 📍")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            WIFTheme.fresh.opacity(0.70),
                                            Color(red: 0.95, green: 0.65, blue: 0.20).opacity(0.50)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.10), radius: 14, y: 6)
                )
                .padding(.horizontal, 18)
                .offset(y: -98)
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92)))
            }
        }
    }

    // MARK: - Narrative Section

    private var narrativeSection: some View {
        VStack(spacing: 6) {
            switch step {
            case 0:
                Text("把朋友装进桌面")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                Text("左右轻扫，随时感知远方世界。")
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
                Text("同在这一座城，为你第一时间捕捉相遇。")
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

        // Start Act 1
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
            // Act 3 Cinematic Serendipity Flow
            collisionPhase = 0.0
            showMergedStage = false
            showMomentCard = false
            auraRadius = 20.0
            auraOpacity = 0.0

            // Stage 1: Glide into center (0.0s -> 0.8s)
            withAnimation(.easeInOut(duration: 0.8).delay(0.15)) {
                collisionPhase = 1.0
            }

            // Stage 2: Merge with radiant shockwave (0.95s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) {
                    showMergedStage = true
                }
                withAnimation(.easeOut(duration: 0.75)) {
                    auraRadius = 260.0
                    auraOpacity = 0.75
                }
                withAnimation(.easeOut(duration: 0.75).delay(0.35)) {
                    auraOpacity = 0.0
                }
                triggerHaptic(style: .medium)
            }

            // Stage 3: Luminous Alert Card Blossoms (1.45s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    showMomentCard = true
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
