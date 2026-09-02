import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingView: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: Int

    // Continuous floating engine
    @State private var floatingPhase = false
    @State private var actOneStoryStart: Date?

    // Act 2 Crystal Halo State
    @State private var shieldScale: CGFloat = 0.75
    @State private var shieldOpacity: Double = 0.0

    // Act 3 Cinematic Convergence State
    @State private var collisionPhase: CGFloat = 0.0
    @State private var showMergedStage = false
    @State private var showNotificationBanner = false
    @State private var auraScale: CGFloat = 0.2
    @State private var auraOpacity: Double = 0.0

    private let totalSteps = 3

    init(initialStep: Int = 0, onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _step = State(initialValue: min(max(initialStep, 0), 2))
    }

    var body: some View {
        ZStack {
            WIFAmbientBackground()

            VStack(spacing: 0) {
                // Top Progress Indicators
                headerProgressIndicator
                    .padding(.top, 16)

                // 🌟 Boundless Cinematic Stage (Unified Visual Universe)
                stageShowcaseArea
                    .frame(height: 380)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                // Flexible Narrative Section (No fixed height cutoff, SF Pro Rounded)
                narrativeSection
                    .padding(.horizontal, 30)
                    .padding(.top, 2)

                Spacer(minLength: 20)

                // Bottom Controls (Clean CTA, No misleading Apple Logo)
                bottomControls
                    .padding(.horizontal, WIFTheme.screenInset)
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            startAmbientEngines()
        }
    }

    // MARK: - Top Header Progress Bar

    private var headerProgressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == step ? WIFTheme.fresh : WIFTheme.primaryText.opacity(0.14))
                    .frame(width: index == step ? 32 : 8, height: 4.5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.40))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.60), lineWidth: 0.8)
                )
        )
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: step)
    }

    // MARK: - Boundless Stage Showcase

    @ViewBuilder
    private var stageShowcaseArea: some View {
        ZStack {
            switch step {
            case 0:
                actOneConstellationStage
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 1.06))
                    ))
            case 1:
                actTwoPrivacyCloakStage
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 1.06))
                    ))
            default:
                actThreeConvergenceStage
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 1.06))
                    ))
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.80), value: step)
    }

    // MARK: - Act 1: From One Place to Three Cities

    private var actOneConstellationStage: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let storyProgress = actOneStoryProgress(at: context.date)
            let departureProgress = storyWindow(storyProgress, from: 0.16, to: 0.52)
            let cityReveal = storyWindow(storyProgress, from: 0.34, to: 0.58)
            let connectionProgress = storyWindow(storyProgress, from: 0.48, to: 0.76)
            let signalOpacity = storyWindow(storyProgress, from: 0.70, to: 0.88)
            let memoryFade = 1 - storyWindow(storyProgress, from: 0.24, to: 0.48)
            let hubReveal = storyWindow(storyProgress, from: 0.54, to: 0.76)
            let travelerOpacity = storyWindow(storyProgress, from: 0.12, to: 0.22)
                * (1 - storyWindow(storyProgress, from: 0.52, to: 0.68))

            ZStack {
                actOneWorldField(revealProgress: cityReveal)

                actOneStoryCaption(storyProgress: storyProgress)
                    .offset(y: -164)

                actOneConnectionNetwork(
                    at: context.date,
                    drawProgress: connectionProgress,
                    signalOpacity: signalOpacity
                )

                actOneSharedMemory
                    .opacity(Double(memoryFade))
                    .scaleEffect(1 - departureProgress * 0.12)
                    .blur(radius: departureProgress * 1.8)

                actOneConnectionHub
                    .opacity(Double(hubReveal))
                    .scaleEffect(0.62 + hubReveal * 0.38)

                actOneDestinationCity(
                    assetCity: "London",
                    cityLabel: "London",
                    countryCode: "GB",
                    localTime: "06:00",
                    size: 82,
                    x: -112,
                    y: reduceMotion ? -72 : (floatingPhase ? -76 : -68),
                    revealProgress: cityReveal,
                    rotation: -7
                )

                actOneDestinationCity(
                    assetCity: "New York",
                    cityLabel: "New York",
                    countryCode: "US",
                    localTime: "01:00",
                    size: 82,
                    x: 112,
                    y: reduceMotion ? -64 : (floatingPhase ? -60 : -68),
                    revealProgress: cityReveal,
                    rotation: 7
                )

                actOneDestinationCity(
                    assetCity: "Tokyo",
                    cityLabel: "Tokyo",
                    countryCode: "JP",
                    localTime: "15:00",
                    size: 96,
                    x: 7,
                    y: reduceMotion ? 94 : (floatingPhase ? 89 : 99),
                    revealProgress: cityReveal,
                    rotation: 0
                )

                ForEach(OnboardingConnectionRoute.allCases, id: \.self) { route in
                    actOneTravelingFriend(
                        route: route,
                        progress: departureProgress,
                        opacity: travelerOpacity
                    )
                }
            }
        }
    }

    private func actOneStoryProgress(at date: Date) -> CGFloat {
        guard !reduceMotion else { return 1 }
        guard let actOneStoryStart else { return 0 }
        return min(max(CGFloat(date.timeIntervalSince(actOneStoryStart) / 3.6), 0), 1)
    }

    private func storyWindow(_ progress: CGFloat, from start: CGFloat, to end: CGFloat) -> CGFloat {
        let normalized = min(max((progress - start) / (end - start), 0), 1)
        return normalized * normalized * (3 - 2 * normalized)
    }

    private func actOneWorldField(revealProgress: CGFloat) -> some View {
        let starOffsets = [
            CGSize(width: -148, height: -118),
            CGSize(width: -132, height: 102),
            CGSize(width: -70, height: 136),
            CGSize(width: 124, height: 116),
            CGSize(width: 151, height: -104),
            CGSize(width: 54, height: -132)
        ]

        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            WIFTheme.fresh.opacity(0.14),
                            WIFTheme.sunGlow.opacity(0.055),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 176
                    )
                )
                .frame(width: 346, height: 272)
                .blur(radius: 22)

            Ellipse()
                .stroke(WIFTheme.fresh.opacity(0.17), lineWidth: 1)
                .frame(width: 326, height: 238)
                .rotationEffect(.degrees(-8))

            Ellipse()
                .stroke(
                    WIFTheme.fresh.opacity(0.12),
                    style: StrokeStyle(lineWidth: 1, dash: [3, 7], dashPhase: floatingPhase ? 10 : 0)
                )
                .frame(width: 326, height: 92)
                .rotationEffect(.degrees(-8))

            Ellipse()
                .stroke(WIFTheme.primaryText.opacity(0.075), lineWidth: 0.8)
                .frame(width: 118, height: 238)
                .rotationEffect(.degrees(-8))

            ForEach(starOffsets.indices, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? WIFTheme.sunGlow : WIFTheme.fresh)
                    .frame(width: index.isMultiple(of: 3) ? 4 : 2.5)
                    .shadow(color: WIFTheme.fresh.opacity(0.38), radius: 4)
                    .offset(starOffsets[index])
            }
        }
        .opacity(0.44 + Double(revealProgress) * 0.56)
        .scaleEffect(0.90 + revealProgress * 0.10)
        .accessibilityHidden(true)
    }

    private func actOneStoryCaption(storyProgress: CGFloat) -> some View {
        let openingOpacity = 1 - storyWindow(storyProgress, from: 0.18, to: 0.32)
        let departureOpacity = storyWindow(storyProgress, from: 0.22, to: 0.36)
            * (1 - storyWindow(storyProgress, from: 0.54, to: 0.68))
        let connectedOpacity = storyWindow(storyProgress, from: 0.62, to: 0.82)

        return ZStack {
            actOneCaptionLabel("Once, we were all in one place.")
                .opacity(Double(openingOpacity))
            actOneCaptionLabel("Then life took us elsewhere.")
                .opacity(Double(departureOpacity))
            actOneCaptionLabel("Different cities. Still close.")
                .opacity(Double(connectedOpacity))
        }
    }

    private func actOneCaptionLabel(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(WIFTheme.fresh)
                .frame(width: 5, height: 5)
                .shadow(color: WIFTheme.fresh.opacity(0.50), radius: 4)

            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(0.2)
        }
        .foregroundStyle(WIFTheme.secondaryText)
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(WIFTheme.surface.opacity(0.70))
                .overlay(Capsule().strokeBorder(WIFTheme.primaryText.opacity(0.08), lineWidth: 0.8))
        )
    }

    private var actOneSharedMemory: some View {
        ZStack {
            Circle()
                .fill(WIFTheme.surface.opacity(0.90))
                .overlay(
                    Circle()
                        .strokeBorder(WIFTheme.fresh.opacity(0.48), lineWidth: 1.1)
                )
                .shadow(color: WIFTheme.fresh.opacity(0.25), radius: 18)

            Image(systemName: "house.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(WIFTheme.fresh.opacity(0.64))

            sharedFriendBubble(
                tint: WIFTheme.fresh,
                x: -27,
                y: 20
            )
            sharedFriendBubble(
                tint: WIFTheme.sunGlow,
                x: 0,
                y: -27
            )
            sharedFriendBubble(
                tint: WIFTheme.primaryText,
                x: 27,
                y: 20
            )
        }
        .frame(width: 94, height: 94)
        .accessibilityHidden(true)
    }

    private func sharedFriendBubble(tint: Color, x: CGFloat, y: CGFloat) -> some View {
        Image(systemName: "person.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(WIFTheme.surface)
            .frame(width: 29, height: 29)
            .background(Circle().fill(tint))
            .overlay(Circle().strokeBorder(WIFTheme.surface.opacity(0.90), lineWidth: 1.5))
            .shadow(color: tint.opacity(0.32), radius: 6, y: 2)
            .offset(x: x, y: y)
    }

    private var actOneConnectionHub: some View {
        ZStack {
            Circle()
                .stroke(WIFTheme.fresh.opacity(0.24), lineWidth: 1)
                .frame(width: 58, height: 58)
                .scaleEffect(floatingPhase ? 1.08 : 0.88)

            Circle()
                .fill(WIFTheme.surface.opacity(0.94))
                .frame(width: 38, height: 38)
                .overlay(Circle().strokeBorder(WIFTheme.fresh.opacity(0.55), lineWidth: 1.2))
                .shadow(color: WIFTheme.fresh.opacity(0.34), radius: 12)

            Image(systemName: "heart.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(WIFTheme.fresh)
        }
        .accessibilityHidden(true)
    }

    private func actOneDestinationCity(
        assetCity: String,
        cityLabel: LocalizedStringKey,
        countryCode: String,
        localTime: String,
        size: CGFloat,
        x: CGFloat,
        y: CGFloat,
        revealProgress: CGFloat,
        rotation: Double
    ) -> some View {
        VStack(spacing: -7) {
            OnboardingCityEmblem(
                city: assetCity,
                countryCode: countryCode,
                size: size,
                localizedCity: cityLabel
            )
                .shadow(color: Color.black.opacity(0.13), radius: 11, y: 6)

            HStack(spacing: 5) {
                Circle()
                    .fill(WIFTheme.fresh)
                    .frame(width: 5, height: 5)
                    .shadow(color: WIFTheme.fresh.opacity(0.46), radius: 3)

                Text(cityLabel)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)

                Text(localTime)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(WIFTheme.secondaryText)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .background(
                Capsule()
                    .fill(WIFTheme.surface.opacity(0.92))
                    .overlay(Capsule().strokeBorder(WIFTheme.primaryText.opacity(0.10), lineWidth: 0.8))
                    .shadow(color: Color.black.opacity(0.065), radius: 7, y: 3)
            )
        }
        .scaleEffect(0.74 + revealProgress * 0.26)
        .rotationEffect(.degrees(rotation * Double(1 - revealProgress)))
        .opacity(Double(revealProgress))
        .offset(x: x, y: y + (1 - revealProgress) * 10)
    }

    private func actOneTravelingFriend(
        route: OnboardingConnectionRoute,
        progress: CGFloat,
        opacity: CGFloat
    ) -> some View {
        let offset = departureOffset(for: route, progress: progress)
        let tint: Color
        switch route {
        case .london: tint = WIFTheme.fresh
        case .newYork: tint = WIFTheme.sunGlow
        case .tokyo: tint = WIFTheme.primaryText
        }

        return Image(systemName: "person.fill")
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(WIFTheme.surface)
            .frame(width: 24, height: 24)
            .background(Circle().fill(tint))
            .overlay(Circle().strokeBorder(WIFTheme.surface.opacity(0.92), lineWidth: 1.3))
            .shadow(color: tint.opacity(0.45), radius: 7)
            .offset(offset)
            .opacity(Double(opacity))
            .accessibilityHidden(true)
    }

    private func departureOffset(
        for route: OnboardingConnectionRoute,
        progress: CGFloat
    ) -> CGSize {
        let end: CGSize
        let control: CGSize
        switch route {
        case .london:
            end = CGSize(width: -112, height: -72)
            control = CGSize(width: -68, height: -18)
        case .newYork:
            end = CGSize(width: 112, height: -64)
            control = CGSize(width: 70, height: -16)
        case .tokyo:
            end = CGSize(width: 7, height: 94)
            control = CGSize(width: -2, height: 62)
        }

        let inverse = 1 - progress
        return CGSize(
            width: 2 * inverse * progress * control.width + progress * progress * end.width,
            height: 2 * inverse * progress * control.height + progress * progress * end.height
        )
    }

    private func actOneConnectionNetwork(
        at date: Date,
        drawProgress: CGFloat,
        signalOpacity: CGFloat
    ) -> some View {
        return ZStack {
            ForEach(OnboardingConnectionRoute.allCases, id: \.self) { route in
                connectionTrack(
                    route: route,
                    drawProgress: drawProgress,
                    signalProgress: reduceMotion
                        ? route.reducedMotionSignalProgress
                        : connectionSignalProgress(at: date, phaseOffset: route.signalPhaseOffset),
                    signalOpacity: signalOpacity
                )
            }
        }
        .frame(width: 350, height: 320)
        .accessibilityHidden(true)
    }

    private func connectionSignalProgress(at date: Date, phaseOffset: TimeInterval) -> CGFloat {
        let cycleDuration: TimeInterval = 3.2
        let shiftedTime = date.timeIntervalSinceReferenceDate - phaseOffset
        let rawProgress = shiftedTime - floor(shiftedTime / cycleDuration) * cycleDuration
        let normalizedProgress = rawProgress / cycleDuration
        let easedProgress = normalizedProgress * normalizedProgress * (3 - 2 * normalizedProgress)
        return 0.06 + CGFloat(easedProgress) * 0.88
    }

    private func connectionTrack(
        route: OnboardingConnectionRoute,
        drawProgress: CGFloat,
        signalProgress: CGFloat,
        signalOpacity: CGFloat
    ) -> some View {
        let arc = OnboardingConnectionArc(route: route)
        let railStart = max(0, 1 - drawProgress)
        let trailStart = max(0, signalProgress - 0.17)
        let sparkStart = max(0, signalProgress - 0.018)

        return ZStack {
            // Soft contact shadow keeps the rail legible in both appearances.
            arc
                .trim(from: railStart, to: 1)
                .stroke(
                    WIFTheme.primaryText.opacity(0.13),
                    style: StrokeStyle(lineWidth: 3.4, lineCap: .round)
                )
                .blur(radius: 1.2)

            // Both connections deliberately share one visual weight.
            arc
                .trim(from: railStart, to: 1)
                .stroke(
                    WIFTheme.fresh.opacity(0.46),
                    style: StrokeStyle(lineWidth: 1.45, lineCap: .round)
                )

            // A short jade wake makes the relationship feel alive without
            // turning the whole composition into a neon network diagram.
            arc
                .trim(from: trailStart, to: signalProgress)
                .stroke(
                    WIFTheme.fresh.opacity(0.92),
                    style: StrokeStyle(lineWidth: 2.7, lineCap: .round)
                )
                .shadow(color: WIFTheme.fresh.opacity(0.55), radius: 4)
                .opacity(Double(signalOpacity))

            // Warmth belongs to the moving signal, not to an entire rail.
            arc
                .trim(from: sparkStart, to: signalProgress)
                .stroke(
                    WIFTheme.sunGlow,
                    style: StrokeStyle(lineWidth: 4.2, lineCap: .round)
                )
                .shadow(color: WIFTheme.fresh.opacity(0.80), radius: 3)
                .opacity(Double(signalOpacity))
        }
    }

    // MARK: - Act 2: Ethereal Privacy Cloak (Focused Spotlight & Liquid Dome)

    private var actTwoPrivacyCloakStage: some View {
        ZStack {
            // Focused Emerald Aura Spotlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            WIFTheme.fresh.opacity(0.28),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 20)

            // Paris Hero Diorama (142pt)
            VStack(spacing: 10) {
                ZStack {
                    Ellipse()
                        .fill(Color.black.opacity(0.14))
                        .frame(width: 96, height: 20)
                        .blur(radius: 8)
                        .offset(y: 74)
                        .scaleEffect(floatingPhase ? 0.90 : 1.08)

                    CityEmblemView(city: "Paris", countryCode: "FR", size: 142)
                        .shadow(color: Color.black.opacity(0.18), radius: 20, y: 10)
                        .offset(y: reduceMotion ? 0 : (floatingPhase ? -5 : 5))
                        .accessibilityLabel(Text("Paris"))
                }

                VStack(spacing: 3) {
                    Text("Paris")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)
                    Text("Chloe")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.fresh)
                }
            }

            // Descending Frosted Liquid Dome (High-contrast glass shield)
            RoundedRectangle(cornerRadius: 115, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.40),
                            WIFTheme.fresh.opacity(0.08)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 115, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    WIFTheme.fresh.opacity(0.45)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .frame(width: 230, height: 230)
                .scaleEffect(reduceMotion ? 1.0 : shieldScale)
                .opacity(reduceMotion ? 1.0 : shieldOpacity)
                .shadow(color: WIFTheme.fresh.opacity(0.35), radius: 24)

            // Reassuring Privacy Badge
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("City-Level Only · Zero Tracking")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(WIFTheme.fresh)
            .padding(.horizontal, 16)
            .padding(.vertical, 8.5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.94))
                    .overlay(
                        Capsule()
                            .strokeBorder(WIFTheme.fresh.opacity(0.50), lineWidth: 1.2)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
            )
            .offset(y: 128)
            .opacity(reduceMotion ? 1.0 : shieldOpacity)
        }
    }

    // MARK: - Act 3: Magnetic Convergence & Live Notification Banner

    private var actThreeConvergenceStage: some View {
        ZStack {
            // Emerald Radiance Core
            RadialGradient(
                colors: [
                    WIFTheme.fresh.opacity(0.30),
                    WIFTheme.sunGlow.opacity(0.10),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 160
            )
            .frame(width: 320, height: 320)
            .blur(radius: 20)

            // Expanding Celestial Light Aura on Merge
            Circle()
                .strokeBorder(WIFTheme.fresh.opacity(auraOpacity), lineWidth: 2.5)
                .frame(width: 260, height: 260)
                .scaleEffect(reduceMotion ? 1.0 : auraScale)

            // Phase 1: Two cities sliding inward with magnetic attraction
            if !showMergedStage && !reduceMotion {
                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        CityEmblemView(city: "New York", countryCode: "US", size: 94)
                            .shadow(color: Color.black.opacity(0.14), radius: 12, y: 6)
                            .accessibilityLabel(Text("New York"))
                        Text("You")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.primaryText)
                    }
                    .offset(x: collisionPhase * 64)

                    Spacer()

                    VStack(spacing: 6) {
                        CityEmblemView(city: "Tokyo", countryCode: "JP", size: 94)
                            .shadow(color: Color.black.opacity(0.14), radius: 12, y: 6)
                            .accessibilityLabel(Text("Tokyo"))
                        Text("Mia")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.primaryText)
                    }
                    .offset(x: -collisionPhase * 64)
                }
                .padding(.horizontal, 36)
                .opacity(1.0 - Double(collisionPhase * 0.75))
            }

            // Phase 2: Merged Hero Monument
            if showMergedStage || reduceMotion {
                VStack(spacing: 8) {
                    CityEmblemView(city: "New York", countryCode: "US", size: 124)
                        .shadow(color: Color.black.opacity(0.20), radius: 22, y: 12)
                        .accessibilityLabel(Text("New York"))

                    VStack(spacing: 4) {
                        Text("New York")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.primaryText)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(WIFTheme.fresh)
                                .frame(width: 6, height: 6)
                            Text("Mia · 2 together")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(WIFTheme.fresh)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(WIFTheme.fresh.opacity(0.18)))
                    }
                }
                .transition(.scale(scale: 0.82).combined(with: .opacity))
                .offset(y: (showNotificationBanner || reduceMotion) ? 36 : 0)
                .animation(.spring(response: 0.45, dampingFraction: 0.78), value: showNotificationBanner)
            }

            // Phase 3: 🔔 High-Impact Realistic iOS Lock Screen Notification Banner
            if showNotificationBanner || reduceMotion {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Color(red: 0.96, green: 0.68, blue: 0.18))

                        Text("ACROSS US")
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(WIFTheme.fresh)

                        Text("·")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(WIFTheme.secondaryText.opacity(0.6))

                        Text("SAME CITY")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.secondaryText)

                        Spacer()

                        Text("NOW")
                            .font(.system(size: 8.5, weight: .bold, design: .rounded))
                            .foregroundStyle(WIFTheme.secondaryText.opacity(0.8))
                    }

                    Text("You and Mia are in New York together 📍")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(WIFTheme.primaryText)

                    Text("Grab coffee? You're both in the city right now.")
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundStyle(WIFTheme.secondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            WIFTheme.fresh.opacity(0.80),
                                            Color(red: 0.96, green: 0.68, blue: 0.18).opacity(0.50)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 18, y: 8)
                )
                .padding(.horizontal, 16)
                .offset(y: -112)
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.90)))
            }
        }
    }

    // MARK: - Narrative Section (Flexible Dynamic Type & Localized Strings)

    private var narrativeSection: some View {
        VStack(spacing: 8) {
            switch step {
            case 0:
                Text("Life moved us apart.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text("Across time zones, the people who matter still feel close.")
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            case 1:
                Text("Only Your City, Never Your Steps")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text("Zero precise tracking. Zero social pressure. Your exact steps stay entirely yours.")
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            default:
                Text("Spark Moments in the Same City")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(WIFTheme.primaryText)
                    .multilineTextAlignment(.center)
                Text("When your paths cross, Across Us gently captures the reunion.")
                    .font(.system(size: 14.5, weight: .medium, design: .rounded))
                    .foregroundStyle(WIFTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: step)
    }

    // MARK: - Bottom Controls (No Apple Logo on generic Get Started)

    private var bottomControls: some View {
        VStack(spacing: 12) {
            Button(action: advance) {
                ZStack {
                    if step == totalSteps - 1 {
                        Text("Get Started")
                    } else {
                        Text("Continue")
                    }

                    HStack {
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.white.opacity(0.17)))
                    }
                    .padding(.horizontal, 16)
                }
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(OnboardingPrimaryButtonStyle())
            .accessibilityIdentifier("onboardingContinueButton")

            Text("City-level sharing. Pause anytime.")
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(WIFTheme.secondaryText)
        }
    }

    // MARK: - Transitions & Engines

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

    private func startAmbientEngines() {
        if actOneStoryStart == nil {
            actOneStoryStart = Date()
        }

        guard !reduceMotion else { return }

        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            floatingPhase = true
        }

        triggerActAnimation(for: step)
    }

    private func triggerActAnimation(for currentStep: Int) {
        guard !reduceMotion else {
            shieldScale = 1.0
            shieldOpacity = 1.0
            collisionPhase = 1.0
            showMergedStage = true
            showNotificationBanner = true
            return
        }

        if currentStep == 1 {
            shieldScale = 0.75
            shieldOpacity = 0.0
            withAnimation(.spring(response: 0.65, dampingFraction: 0.70).delay(0.12)) {
                shieldScale = 1.0
                shieldOpacity = 1.0
            }
            triggerHaptic(style: .soft)
        } else if currentStep == 2 {
            collisionPhase = 0.0
            showMergedStage = false
            showNotificationBanner = false
            auraScale = 0.2
            auraOpacity = 0.0

            // Stage 1: Magnetic Glide (0.0s -> 0.75s)
            withAnimation(.easeInOut(duration: 0.75).delay(0.12)) {
                collisionPhase = 1.0
            }

            // Stage 2: Magnetic Merge & Radiant Shockwave (0.85s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                withAnimation(.spring(response: 0.50, dampingFraction: 0.65)) {
                    showMergedStage = true
                }
                withAnimation(.easeOut(duration: 0.70)) {
                    auraScale = 1.6
                    auraOpacity = 0.75
                }
                withAnimation(.easeOut(duration: 0.70).delay(0.30)) {
                    auraOpacity = 0.0
                }
                triggerHaptic(style: .rigid)
            }

            // Stage 3: High-Impact Notification Banner Drops (1.30s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) {
                withAnimation(.spring(response: 0.48, dampingFraction: 0.76)) {
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

private enum OnboardingConnectionRoute: CaseIterable, Hashable {
    case london
    case newYork
    case tokyo

    var signalPhaseOffset: TimeInterval {
        switch self {
        case .london: 0
        case .newYork: 0.44
        case .tokyo: 0.88
        }
    }

    var reducedMotionSignalProgress: CGFloat {
        switch self {
        case .london: 0.68
        case .newYork: 0.46
        case .tokyo: 0.82
        }
    }
}

private struct OnboardingConnectionArc: Shape {
    let route: OnboardingConnectionRoute

    func path(in rect: CGRect) -> Path {
        let start: CGPoint
        let control: CGPoint
        switch route {
        case .london:
            start = CGPoint(x: rect.width * 0.18, y: rect.height * 0.275)
            control = CGPoint(x: rect.width * 0.31, y: rect.height * 0.41)
        case .newYork:
            start = CGPoint(x: rect.width * 0.82, y: rect.height * 0.30)
            control = CGPoint(x: rect.width * 0.70, y: rect.height * 0.41)
        case .tokyo:
            start = CGPoint(x: rect.width * 0.52, y: rect.height * 0.795)
            control = CGPoint(x: rect.width * 0.49, y: rect.height * 0.66)
        }
        let destination = CGPoint(x: rect.width * 0.50, y: rect.height * 0.50)

        return Path { path in
            path.move(to: start)
            path.addQuadCurve(to: destination, control: control)
        }
    }
}

private struct OnboardingCityEmblem: View {
    @Environment(\.colorScheme) private var colorScheme

    let city: String
    let countryCode: String
    let size: CGFloat
    let localizedCity: LocalizedStringKey

    var body: some View {
        ZStack {
            CityEmblemView(city: city, countryCode: countryCode, size: size)

            if colorScheme == .dark {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.48),
                        .init(color: WIFTheme.canvas.opacity(0.18), location: 0.62),
                        .init(color: WIFTheme.canvas.opacity(0.78), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.multiply)
                .mask {
                    CityEmblemView(city: city, countryCode: countryCode, size: size)
                }
            }
        }
        .scaleEffect(1.10)
        .offset(y: size * 0.025)
        .frame(width: size, height: size)
        .clipped()
        .blendMode(colorScheme == .light ? .multiply : .normal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(localizedCity))
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                WIFTheme.fresh,
                                WIFTheme.fresh.opacity(0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .shadow(color: WIFTheme.fresh.opacity(0.25), radius: 18, y: 8)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
