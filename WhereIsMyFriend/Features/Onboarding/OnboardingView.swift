import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

    // Animation States
    @State private var isScattered = false
    @State private var isMerged = false
    @State private var isReunionVisible = false

    private let totalSteps = 3

    var body: some View {
        ZStack {
            WIFAmbientBackground()

            VStack(spacing: 0) {
                // Top Minimal Progress Indicator
                progressHeader
                    .padding(.top, 20)

                Spacer(minLength: 16)

                // Cinematic Stage Carousel
                TabView(selection: $step) {
                    actOneView.tag(0)
                    actTwoView.tag(1)
                    actThreeView.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: step)
                .onChange(of: step) { _, newStep in
                    handleStepChange(newStep)
                }

                Spacer(minLength: 16)

                // Bottom Action
                bottomControls
                    .padding(.horizontal, WIFTheme.screenInset)
                    .padding(.bottom, 28)
            }
        }
        .onAppear {
            triggerScatterAnimation()
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: 7) {
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
                .fill(Color.white.opacity(0.05))
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    // MARK: - Act 1: 散落 (Clean 3D Floating Stage, No Circles, No Crosshairs)

    private var actOneView: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            // Pure 3D Diorama Constellation (Clean floating stage with soft shadows)
            ZStack {
                // Subtle Ambient Light Glow
                RadialGradient(
                    colors: [
                        WIFTheme.fresh.opacity(0.15),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 10,
                    endRadius: 130
                )
                .frame(width: 260, height: 200)

                // 1. Top Left: New York
                cityDioramaCard(city: "New York", countryCode: "US", label: "New York")
                    .offset(x: isScattered ? -74 : 0, y: isScattered ? -54 : 0)
                    .scaleEffect(isScattered ? 1.0 : 0.6)
                    .opacity(isScattered ? 1.0 : 0.2)
                    .animation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.05), value: isScattered)

                // 2. Top Right: London
                cityDioramaCard(city: "London", countryCode: "GB", label: "London")
                    .offset(x: isScattered ? 74 : 0, y: isScattered ? -54 : 0)
                    .scaleEffect(isScattered ? 1.0 : 0.6)
                    .opacity(isScattered ? 1.0 : 0.2)
                    .animation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.12), value: isScattered)

                // 3. Bottom Left: San Francisco
                cityDioramaCard(city: "San Francisco", countryCode: "US", label: "SF")
                    .offset(x: isScattered ? -74 : 0, y: isScattered ? 54 : 0)
                    .scaleEffect(isScattered ? 1.0 : 0.6)
                    .opacity(isScattered ? 1.0 : 0.2)
                    .animation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.18), value: isScattered)

                // 4. Bottom Right: Tokyo
                cityDioramaCard(city: "Tokyo", countryCode: "JP", label: "Tokyo")
                    .offset(x: isScattered ? 74 : 0, y: isScattered ? 54 : 0)
                    .scaleEffect(isScattered ? 1.0 : 0.6)
                    .opacity(isScattered ? 1.0 : 0.2)
                    .animation(.spring(response: 0.7, dampingFraction: 0.72).delay(0.24), value: isScattered)
            }
            .frame(height: 210)
            .contentShape(Rectangle())
            .onTapGesture {
                triggerScatterAnimation()
            }

            Spacer(minLength: 0)

            // Ultra-clean Minimalist Copy
            VStack(spacing: 8) {
                Text("散落世界的朋友")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)

                Text("山海相隔，依然相连。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private func cityDioramaCard(city: String, countryCode: String, label: String) -> some View {
        VStack(spacing: 3) {
            CityEmblemView(city: city, countryCode: countryCode, size: 66)

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(WIFTheme.primaryText)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        )
    }

    // MARK: - Act 2: 挂念 (Dual Horizon)

    private var actTwoView: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            // Dual City Bridge Stage
            ZStack {
                // Connecting Horizon Light Beam
                HStack(spacing: 4) {
                    Circle()
                        .fill(WIFTheme.fresh.opacity(0.8))
                        .frame(width: 4, height: 4)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    WIFTheme.fresh.opacity(0.5),
                                    Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.5)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1.5)
                    Circle()
                        .fill(Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.8))
                        .frame(width: 4, height: 4)
                }
                .padding(.horizontal, 56)

                HStack {
                    // Left: New York
                    VStack(spacing: 4) {
                        CityEmblemView(city: "New York", countryCode: "US", size: 84)
                        Text("New York")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.primaryText)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )

                    Spacer(minLength: 24)

                    // Right: Tokyo
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
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 210)

            Spacer(minLength: 0)

            // Ultra-clean Minimalist Copy
            VStack(spacing: 8) {
                Text("只知城市，不添打扰")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)

                Text("不查轨迹，知道你平安便好。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Act 3: 重聚 (Same-City Serendipity)

    private var actThreeView: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)

            // Single Hero Same-City Stage
            ZStack {
                // Soft Green Halo
                RadialGradient(
                    colors: [
                        WIFTheme.fresh.opacity(0.24),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 15,
                    endRadius: 120
                )
                .frame(width: 240, height: 200)

                VStack(spacing: 8) {
                    CityEmblemView(city: "New York", countryCode: "US", size: 96)

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
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .strokeBorder(WIFTheme.fresh.opacity(0.35), lineWidth: 1)
                        )
                )
            }
            .frame(height: 210)

            Spacer(minLength: 0)

            // Ultra-clean Minimalist Copy
            VStack(spacing: 8) {
                Text("同一座城，偶然重逢")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)

                Text("当轨迹重叠，点亮这一刻。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
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

    private func advance() {
        if step == totalSteps - 1 {
            onComplete()
            return
        }

        if reduceMotion {
            step += 1
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                step += 1
            }
        }
    }

    private func handleStepChange(_ newStep: Int) {
        triggerHaptic(for: newStep)
        if newStep == 0 {
            triggerScatterAnimation()
        }
    }

    private func triggerScatterAnimation() {
        isScattered = false
        withAnimation(.spring(response: 0.72, dampingFraction: 0.70).delay(0.12)) {
            isScattered = true
        }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            generator.impactOccurred()
        }
        #endif
    }

    private func triggerHaptic(for currentStep: Int) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: currentStep == totalSteps - 1 ? .medium : .soft)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
