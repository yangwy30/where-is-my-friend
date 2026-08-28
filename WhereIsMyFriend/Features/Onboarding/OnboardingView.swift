import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0

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
                    triggerHaptic(for: newStep)
                }

                Spacer(minLength: 12)

                // Bottom Action & Caption
                bottomControls
                    .padding(.horizontal, WIFTheme.screenInset)
                    .padding(.bottom, 24)
            }
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

    // MARK: - Act 1: 散落 (The Great Scatter / 毕业奔赴山海)

    private var actOneView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            // Visual: 4 Cities Scattering Outward
            ZStack {
                // Background subtle orbital rings
                Circle()
                    .strokeBorder(WIFTheme.fresh.opacity(0.12), lineWidth: 1)
                    .frame(width: 210, height: 210)

                Circle()
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: 140, height: 140)

                // Center Origin Tag
                Text("🎓 Origin")
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(Color.white.opacity(0.08)))

                // Top Left: New York
                VStack(spacing: 2) {
                    CityEmblemView(city: "New York", countryCode: "US", size: 62)
                    Text("New York")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)
                }
                .offset(x: -76, y: -62)

                // Top Right: London
                VStack(spacing: 2) {
                    CityEmblemView(city: "London", countryCode: "GB", size: 62)
                    Text("London")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)
                }
                .offset(x: 76, y: -62)

                // Bottom Left: San Francisco
                VStack(spacing: 2) {
                    CityEmblemView(city: "San Francisco", countryCode: "US", size: 62)
                    Text("SF")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)
                }
                .offset(x: -76, y: 64)

                // Bottom Right: Tokyo
                VStack(spacing: 2) {
                    CityEmblemView(city: "Tokyo", countryCode: "JP", size: 62)
                    Text("Tokyo")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)
                }
                .offset(x: 76, y: 64)
            }
            .frame(height: 210)

            Spacer(minLength: 0)

            // Narrative Copy
            VStack(spacing: 10) {
                Text("毕业那年，\n我们奔赴各自的山海。")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("各自收拾行囊，各奔东西。\n曾经形影不离的人，散落到了世界各个角落。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .lineSpacing(4)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Act 2: 挂念 (Silent Presence / 各自忙碌 遥遥相望)

    private var actTwoView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 0)

            // Visual: Dual Horizon Bridge
            ZStack {
                // Connecting Horizon Arc
                HStack(spacing: 4) {
                    Circle()
                        .fill(WIFTheme.fresh.opacity(0.8))
                        .frame(width: 5, height: 5)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    WIFTheme.fresh.opacity(0.6),
                                    Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1.5)
                    Circle()
                        .fill(Color(red: 0.98, green: 0.65, blue: 0.52).opacity(0.8))
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
            .frame(height: 210)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)

            // Narrative Copy
            VStack(spacing: 10) {
                Text("我们很少再联系，\n但依然想知道你去了哪。")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("各自忙于生活，不必刻意寒暄。\n只要看一眼你所在的城市，就知道你一切安好。")
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

            // Visual: Merged Same-City Hero Stage
            ZStack {
                // Ambient Green Aura
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                WIFTheme.fresh.opacity(0.24),
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
                                .strokeBorder(WIFTheme.fresh.opacity(0.40), lineWidth: 1)
                        )
                )
            }
            .frame(height: 210)

            Spacer(minLength: 0)

            // Narrative Copy
            VStack(spacing: 10) {
                Text("如果有一天，\n我们在同一座城市降落。")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
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
