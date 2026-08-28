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
                    triggerHaptic(for: newStep)
                }

                Spacer(minLength: 16)

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

    // MARK: - Act 1: 羁绊 (Cross-Horizon Bond)

    private var actOneView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            // Stage Visual: Dual Horizon
            ZStack {
                // Connecting Horizon Beam
                HStack(spacing: 4) {
                    Circle()
                        .fill(WIFTheme.fresh.opacity(0.7))
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
                    // New York
                    VStack(spacing: 6) {
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

                    Spacer(minLength: 20)

                    // Tokyo
                    VStack(spacing: 6) {
                        CityEmblemView(city: "Tokyo", countryCode: "JP", size: 84)
                        Text("Tokyo")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.primaryText)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.white.opacity(0.04))
                    )
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 200)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)

            // Text
            VStack(spacing: 10) {
                Text("相隔万里，\n也能知道你在哪座城。")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("朋友散落世界各地，但距离不必让彼此失去联系。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Act 2: 安心 (City-Level Gentle Privacy)

    private var actTwoView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            // Stage Visual: Protected Paris Diorama
            ZStack {
                // Soft Privacy Halo Circle
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                WIFTheme.fresh.opacity(0.45),
                                WIFTheme.fresh.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 170, height: 170)
                    .background(
                        Circle()
                            .fill(WIFTheme.fresh.opacity(0.06))
                    )

                VStack(spacing: 6) {
                    CityEmblemView(city: "Paris", countryCode: "FR", size: 96)

                    Text("Paris")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(WIFTheme.primaryText)
                }

                // Floating Privacy Tag
                HStack(spacing: 4) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("仅共享城市 · 零轨迹追踪")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundStyle(WIFTheme.fresh)
                .padding(.horizontal, 10)
                .padding(.vertical, 4.5)
                .background(
                    Capsule()
                        .fill(Color(white: 0.12).opacity(0.92))
                        .overlay(Capsule().strokeBorder(WIFTheme.fresh.opacity(0.35), lineWidth: 1))
                )
                .offset(y: 72)
            }
            .frame(height: 200)

            Spacer(minLength: 0)

            // Text
            VStack(spacing: 10) {
                Text("只分享城市，\n不分享轨迹。")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("知道你平安在哪座城，也尊重你独处的距离。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - Act 3: 惊喜 (Same-City Serendipity)

    private var actThreeView: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)

            // Stage Visual: Merged Same-City Stage
            ZStack {
                // Outer Radiance
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                WIFTheme.fresh.opacity(0.22),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 110
                        )
                    )
                    .frame(width: 220, height: 180)

                VStack(spacing: 8) {
                    CityEmblemView(city: "New York", countryCode: "US", size: 94)

                    VStack(spacing: 3) {
                        Text("New York")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(WIFTheme.primaryText)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(WIFTheme.fresh)
                                .frame(width: 5, height: 5)
                            Text("Mia · 2 together")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(WIFTheme.fresh)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(WIFTheme.fresh.opacity(0.18)))
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(WIFTheme.fresh.opacity(0.35), lineWidth: 1)
                        )
                )
            }
            .frame(height: 200)

            Spacer(minLength: 0)

            // Text
            VStack(spacing: 10) {
                Text("有一天，\n我们刚好同城。")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("当城市重叠，App 会提醒你这一刻。")
                    .font(.subheadline)
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .lineSpacing(3)
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
                    Text(step == totalSteps - 1 ? "开启，看看朋友在哪座城" : "继续")
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
