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
    @State private var pulseBeam = false

    private let totalSteps = 3

    var body: some View {
        ZStack {
            WIFAmbientBackground()

            VStack(spacing: 0) {
                // Top Progress Indicator
                progressHeader
                    .padding(.top, 18)

                Spacer(minLength: 12)

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

                Spacer(minLength: 12)

                // Bottom Action & Caption
                bottomControls
                    .padding(.horizontal, WIFTheme.screenInset)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            triggerScatterAnimation()
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? WIFTheme.fresh : WIFTheme.border.opacity(0.35))
                    .frame(width: index == step ? 32 : 10, height: 5.5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.06))
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: step)
    }

    // MARK: - Act 1: 散落 (The Interactive Scatter Animation)

    private var actOneView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            // Stage Visual: Animated Burst from Center
            Button {
                triggerScatterAnimation()
            } label: {
                ZStack {
                    // Expanding shockwave ripple rings
                    Circle()
                        .strokeBorder(WIFTheme.fresh.opacity(isScattered ? 0.18 : 0.0), lineWidth: 1.5)
                        .frame(width: isScattered ? 230 : 60, height: isScattered ? 230 : 60)
                        .animation(.easeOut(duration: 0.85), value: isScattered)

                    Circle()
                        .strokeBorder(Color.white.opacity(isScattered ? 0.08 : 0.0), lineWidth: 1)
                        .frame(width: isScattered ? 160 : 40, height: isScattered ? 160 : 40)
                        .animation(.easeOut(duration: 0.70).delay(0.05), value: isScattered)

                    // Connecting Laser Lines from center
                    if isScattered {
                        ForEach([45.0, 135.0, 225.0, 315.0], id: \.self) { angle in
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [WIFTheme.fresh.opacity(0.4), Color.clear],
                                        startPoint: .center,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 80, height: 1)
                                .rotationEffect(.degrees(angle))
                        }
                        .transition(.opacity)
                    }

                    // Center Hub Label (Fades when scattered)
                    VStack(spacing: 2) {
                        Image(systemName: isScattered ? "arrow.up.left.and.arrow.down.right" : "person.3.sequence.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(WIFTheme.fresh)
                        Text(isScattered ? "轻触重放" : "曾在一个地方")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.secondaryText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(white: 0.12).opacity(0.9)))
                    .scaleEffect(isScattered ? 0.88 : 1.05)

                    // 4 Scattering Cities:

                    // 1. Top Left: New York
                    cityNode(city: "New York", countryCode: "US", label: "New York")
                        .offset(x: isScattered ? -82 : 0, y: isScattered ? -68 : 0)
                        .scaleEffect(isScattered ? 1.0 : 0.45)
                        .opacity(isScattered ? 1.0 : 0.15)

                    // 2. Top Right: London
                    cityNode(city: "London", countryCode: "GB", label: "London")
                        .offset(x: isScattered ? 82 : 0, y: isScattered ? -68 : 0)
                        .scaleEffect(isScattered ? 1.0 : 0.45)
                        .opacity(isScattered ? 1.0 : 0.15)

                    // 3. Bottom Left: San Francisco
                    cityNode(city: "San Francisco", countryCode: "US", label: "SF")
                        .offset(x: isScattered ? -82 : 0, y: isScattered ? 68 : 0)
                        .scaleEffect(isScattered ? 1.0 : 0.45)
                        .opacity(isScattered ? 1.0 : 0.15)

                    // 4. Bottom Right: Tokyo
                    cityNode(city: "Tokyo", countryCode: "JP", label: "Tokyo")
                        .offset(x: isScattered ? 82 : 0, y: isScattered ? 68 : 0)
                        .scaleEffect(isScattered ? 1.0 : 0.45)
                        .opacity(isScattered ? 1.0 : 0.15)
                }
                .frame(height: 220)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            // Universal Narrative Copy (No forced graduation assumption)
            VStack(spacing: 10) {
                Text("无论曾经在哪里相聚，\n后来我们四散在世界各地。")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("有人去了远方，有人留守原地。\n散落天涯的朋友，不该因为距离而淡出彼此的生活。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .lineSpacing(4)
            }

            Spacer(minLength: 0)
        }
    }

    private func cityNode(city: String, countryCode: String, label: String) -> some View {
        VStack(spacing: 3) {
            CityEmblemView(city: city, countryCode: countryCode, size: 60)
            Text(label)
                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                .foregroundStyle(WIFTheme.primaryText)
        }
    }

    // MARK: - Act 2: 挂念 (Silent Presence / 遥遥相望)

    private var actTwoView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            // Stage Visual: Dual Horizon Bridge with Shimmering Pulse
            ZStack {
                // Connecting Horizon Arc
                HStack(spacing: 4) {
                    Circle()
                        .fill(WIFTheme.fresh.opacity(0.85))
                        .frame(width: 5, height: 5)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    WIFTheme.fresh.opacity(0.6),
                                    Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1.5)
                    Circle()
                        .fill(Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.85))
                        .frame(width: 5, height: 5)
                }
                .padding(.horizontal, 48)

                HStack {
                    // Left: New York (Me)
                    VStack(spacing: 4) {
                        CityEmblemView(city: "New York", countryCode: "US", size: 84)
                        Text("New York")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.primaryText)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )

                    Spacer(minLength: 20)

                    // Right: Tokyo (Friend)
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
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
                .padding(.horizontal, 24)

                // Privacy Indicator
                HStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 8.5, weight: .bold))
                    Text("只知身在何城 · 不查轨迹，不添打扰")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                }
                .foregroundStyle(WIFTheme.fresh)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(white: 0.12).opacity(0.92))
                        .overlay(Capsule().strokeBorder(WIFTheme.fresh.opacity(0.30), lineWidth: 1))
                )
                .offset(y: 74)
            }
            .frame(height: 220)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)

            // Narrative Copy
            VStack(spacing: 10) {
                Text("即使很少联系，\n依然想知道你去了哪。")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("不必频繁寒暄，不查精确轨迹。\n只要看一眼你所在的城市，就知道你一切安好。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .lineSpacing(4)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Act 3: 重聚 (The Reunion / 偶然降落同一座城)

    private var actThreeView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            // Visual: Merged Same-City Hero Stage with Magnetic Snap Animation
            ZStack {
                // Ambient Green Aura
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                WIFTheme.fresh.opacity(isMerged ? 0.28 : 0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 110
                        )
                    )
                    .frame(width: 230, height: 190)

                VStack(spacing: 8) {
                    CityEmblemView(city: "New York", countryCode: "US", size: 96)
                        .scaleEffect(isMerged ? 1.0 : 0.88)

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
                                .strokeBorder(WIFTheme.fresh.opacity(isMerged ? 0.45 : 0.15), lineWidth: 1)
                        )
                )
            }
            .frame(height: 220)

            Spacer(minLength: 0)

            // Narrative Copy
            VStack(spacing: 10) {
                Text("如果有一天，\n我们在同一座城市降落。")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("时差归零，街角相聚。\n当生活轨迹再次重叠，App 会替你记住这奇迹的一刻。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .lineSpacing(4)
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
                    Text(step == totalSteps - 1 ? "开启，看看老朋友们在哪座城" : "继续")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .foregroundStyle(WIFTheme.primaryText)
            .wifGlassButton(tint: WIFTheme.fresh.opacity(0.35), prominent: true)
            .accessibilityIdentifier("onboardingContinueButton")

            Text(step == totalSteps - 1
                 ? "只分享城市，你可以随时暂停"
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
        } else if newStep == 2 {
            isMerged = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.65).delay(0.1)) {
                isMerged = true
            }
        }
    }

    private func triggerScatterAnimation() {
        isScattered = false
        withAnimation(.spring(response: 0.75, dampingFraction: 0.68).delay(0.15)) {
            isScattered = true
        }
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
