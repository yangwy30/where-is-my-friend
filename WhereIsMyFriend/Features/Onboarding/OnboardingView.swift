import SwiftUI
import CoreLocation

/// Real, contextual permission setup after authentication, separate from previews.
struct LocationSetupView: View {
  @EnvironmentObject private var locationService: CityLocationService
  let onComplete: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        Image(systemName: "location.circle.fill")
          .font(.system(size: 76, weight: .light)).foregroundStyle(WIFTheme.fresh)
          .padding(.top, 48).accessibilityHidden(true)
        Text("Start with your city.")
          .font(.largeTitle.bold()).foregroundStyle(WIFTheme.primaryText)
        Text("Turn on location to find your city and discover when you and your friends are nearby.")
          .font(.title3).foregroundStyle(WIFTheme.secondaryText)
        Label("Friends see only your city, never your precise location.", systemImage: "lock.shield")
          .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
        Text("Choose Allow While Using App. Background location is optional and can be set up later.")
          .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
        if locationService.authorizationStatus == .restricted {
          Text("Location is restricted on this device. You can still continue without it.")
            .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
        } else {
          Button {
            if locationService.authorizationStatus == .denied {
              if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } else {
              locationService.requestForegroundCity()
            }
          } label: {
            Text(locationService.authorizationStatus == .denied ? "Open Settings" : "Enable location")
              .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
          }
          .foregroundStyle(.white)
          .background(WIFTheme.fresh, in: RoundedRectangle(cornerRadius: 20))
          .accessibilityIdentifier("enableInitialLocation")
        }
        Button("Not now", action: onComplete)
          .font(.subheadline).foregroundStyle(WIFTheme.secondaryText)
          .frame(maxWidth: .infinity, minHeight: 44)
          .accessibilityIdentifier("skipInitialLocation")
      }
      .padding(28)
    }
    .wifAmbientBackground()
    .accessibilityIdentifier("initialLocationSetup")
  }
}

/// A single illustrated world, reframed across four chapters. All interaction here
/// is a preview: it deliberately has no access to location or sharing settings.
struct OnboardingView: View {
  let onComplete: () -> Void
  @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.scenePhase) private var scenePhase
  @State private var step: Int
  private static let pageCount = 4
  @State private var detailRevealed = false
  @State private var routesRevealed = false
  @State private var drag = CGSize.zero
  @State private var entrance = 0
  @State private var friendsMet = false
  @State private var reunionPulse = false
  @State private var flightOne: CGFloat = 0
  @State private var flightTwo: CGFloat = 0
  @State private var firstArrived = false
  @State private var secondArrived = false

  private var reduceMotion: Bool {
    #if DEBUG
      // Deterministic preview QA without modifying the device's accessibility settings.
      if ProcessInfo.processInfo.arguments.contains("-previewOnboarding"),
        ProcessInfo.processInfo.arguments.contains("-previewOnboardingReducedMotion")
      {
        return true
      }
    #endif
    return systemReduceMotion
  }

  init(initialStep: Int = 0, onComplete: @escaping () -> Void) {
    self.onComplete = onComplete
    _step = State(initialValue: min(max(initialStep, 0), Self.pageCount - 1))
  }

  private var title: LocalizedStringKey {
    switch step {
    case 0: "Different cities.\nStill close."
    case 1: "A little nudge.\nA real-life reunion."
    case 2: "Your next trip,\ntogether."
    default: "Your city.\nYour choice."
    }
  }

  private var subtitle: LocalizedStringKey {
    switch step {
    case 0: "A little window into your friends’ worlds, wherever life takes you."
    case 1: "Get a notification when you and a friend are in the same city. Make time to catch up."
    case 2: "Make a shared trip, invite your friends, and see everyone’s flights in one place."
    default: "Choose who sees your city. Pause sharing anytime."
    }
  }

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 680
      VStack(spacing: 0) {
        navigation
        ScrollView {
          VStack(spacing: compact ? 16 : 26) {
            VStack(spacing: 4) {
              world
                .frame(height: sceneHeight(compact: compact, available: geometry.size.height))
              chapterDetail
                .frame(minHeight: 70, alignment: .bottom)
            }
            VStack(alignment: .leading, spacing: 16) {
              Text(
                [
                  "A WORLD OF FRIENDS", "SAME-CITY NOTIFICATIONS", "A SHARED ADVENTURE",
                  "ON YOUR TERMS",
                ][step]
              )
              .font(.caption2.weight(.bold))
              .tracking(2)
              .foregroundStyle(WIFTheme.fresh)
              Text(title)
                .font(.system(compact ? .title : .largeTitle, design: .rounded, weight: .bold))
                .tracking(-1)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(WIFTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboardingTitle")
              Text(subtitle)
                .font(.body)
                .foregroundStyle(WIFTheme.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 30)
          }
          .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("onboardingContent")
        footer
      }
      .frame(maxWidth: 520)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(WIFTheme.canvas.ignoresSafeArea())
    .task(id: "\(step)-\(reduceMotion)-\(scenePhase == .active)") {
      await playChapter()
    }
  }

  /// All sequencing belongs to the view task: navigation, dismissal and motion
  /// preference changes cancel pending beats instead of leaving delayed callbacks.
  @MainActor private func playChapter() async {
    var reset = Transaction()
    reset.disablesAnimations = true
    withTransaction(reset) {
      entrance = 0
      detailRevealed = false
      routesRevealed = false
      friendsMet = false
      reunionPulse = false
      flightOne = 0
      flightTwo = 0
      firstArrived = false
      secondArrived = false
    }
    guard !reduceMotion, scenePhase == .active else {
      withTransaction(reset) {
        entrance = 3
        detailRevealed = true
        routesRevealed = true
        friendsMet = true
        flightOne = 1
        flightTwo = 1
        firstArrived = true
        secondArrived = true
      }
      return
    }
    do {
      switch step {
      case 0:
        try await beat(180)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.72)) { entrance = 1 }
        try await beat(230)
        withAnimation(.spring(response: 0.65, dampingFraction: 0.65)) { entrance = 2 }
        try await beat(300)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { entrance = 3 }
        withAnimation(.easeOut(duration: 0.6)) { routesRevealed = true }
      case 1:
        try await beat(220)
        withAnimation(.spring(response: 0.85, dampingFraction: 0.76)) { friendsMet = true }
        try await beat(600)
        withAnimation(.easeOut(duration: 0.7)) { reunionPulse = true }
        try await beat(200)
        withAnimation(.spring(response: 0.48, dampingFraction: 0.64)) { detailRevealed = true }
      case 2:
        // Each flight completes before its matching row appears in the trip card.
        try await beat(160)
        withAnimation(.linear(duration: 1.2)) { flightOne = 1 }
        try await beat(320)
        withAnimation(.linear(duration: 1.3)) { flightTwo = 1 }
        try await beat(900)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
          detailRevealed = true
          firstArrived = true
        }
        try await beat(420)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { secondArrived = true }
      default:
        break  // Privacy is deliberately still.
      }
    } catch { /* A new chapter owns the scene now. */  }
  }

  private func beat(_ milliseconds: Int) async throws {
    try await Task.sleep(for: .milliseconds(milliseconds))
    try Task.checkCancellation()
  }

  private func sceneHeight(compact: Bool, available: CGFloat) -> CGFloat {
    switch step {
    case 1: compact ? 145 : min(available * 0.31, 255)
    case 2: compact ? 110 : min(available * 0.25, 210)
    default: compact ? 180 : min(available * 0.37, 310)
    }
  }

  private var spreadCities: Bool { step == 0 || step == 2 }

  private var navigation: some View {
    HStack {
      Button {
        go(to: step - 1)
      } label: {
        Image(systemName: "arrow.left")
          .font(.body.weight(.medium))
          .frame(width: 44, height: 44)
          .contentShape(Rectangle())
      }
      .accessibilityLabel("Back")
      .accessibilityIdentifier("onboardingBackButton")
      .opacity(step == 0 ? 0 : 1)
      .disabled(step == 0)
      .accessibilityHidden(step == 0)
      Spacer()
      Text("ACROSS US")
        .font(.system(size: 11, weight: .bold))
        .tracking(3)
        .accessibilityLabel("Across Us")
      Spacer()
      Button("Skip", action: onComplete)
        .font(.subheadline)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityIdentifier("onboardingSkipButton")
    }
    .foregroundStyle(WIFTheme.secondaryText)
    .padding(.horizontal, 24)
    .padding(.top, 6)
  }

  private var footer: some View {
    VStack(spacing: 18) {
      HStack(spacing: 7) {
        ForEach(0..<Self.pageCount, id: \.self) { index in
          Capsule()
            .fill(index == step ? WIFTheme.fresh : WIFTheme.primaryText.opacity(0.13))
            .frame(width: index == step ? 24 : 6, height: 6)
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel("Page \(step + 1) of \(Self.pageCount)")
      Button {
        if step == Self.pageCount - 1 { onComplete() } else { go(to: step + 1) }
      } label: {
        HStack(spacing: 10) {
          Text(step == Self.pageCount - 1 ? "Get started" : "Continue")
          Image(systemName: "arrow.right").font(.body.weight(.medium))
        }
        .font(.headline)
        .frame(maxWidth: .infinity, minHeight: 54)
        .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
        .background(WIFTheme.fresh, in: Capsule())
        .foregroundStyle(WIFTheme.canvas)
        .contentShape(Capsule())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("onboardingContinueButton")
    }
    .padding(.horizontal, 30)
    .padding(.top, 10)
    .padding(.bottom, 20)
  }

  private func go(to page: Int) {
    guard (0..<Self.pageCount).contains(page) else { return }
    withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.82)) {
      step = page
      detailRevealed = false
      routesRevealed = false
      drag = .zero
    }
  }

  private var world: some View {
    GeometryReader { geometry in
      let scale = min(geometry.size.width / 360, geometry.size.height / 320)
      ZStack {
        // Keep these same view identities through every chapter, so the
        // camera-like reframe is a continuous transition, not a slideshow.
        ZStack {
          Ellipse()
            .fill(WIFTheme.fresh.opacity(0.065))
            .frame(width: 285, height: 130)
            .blur(radius: 25)
            .offset(y: 38)
          connection
            .trim(from: 0, to: routesRevealed || reduceMotion ? 1 : 0)
            .stroke(WIFTheme.fresh.opacity(0.24), style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
            .frame(width: 330, height: 250)
            .opacity(step == 0 ? 1 : 0)
            .offset(x: parallax(0.025), y: parallax(0.015, vertical: true))
          if step == 2 {
            OnboardingFlightRoutes(first: flightOne, second: flightTwo)
              .frame(width: 330, height: 250)
              .offset(x: parallax(0.025), y: parallax(0.015, vertical: true))
          }
          Circle()
            .stroke(WIFTheme.fresh.opacity(reunionPulse ? 0 : 0.5), lineWidth: 1.5)
            .frame(width: 75, height: 75)
            .scaleEffect(reunionPulse ? 1.9 : 0.65)
            .offset(y: -112)
            .opacity(step == 1 && friendsMet ? 1 : 0)
          city("New York", size: 106)
            .offset(x: spreadCities ? -102 : -148, y: spreadCities ? -51 : -50)
            .scaleEffect(spreadCities ? 1 : 0.65)
            .opacity(spreadCities ? 1 : (step == 3 ? 0 : 0.16))
            .scaleEffect(step == 0 && entrance < 1 && !reduceMotion ? 0.65 : 1)
            .offset(
              x: parallax(0.04),
              y: (step == 0 && entrance < 1 && !reduceMotion ? 28 : 0)
                + parallax(0.025, vertical: true)
            )
            .opacity(step == 0 && entrance < 1 && !reduceMotion ? 0 : 1)
          city("Tokyo", size: 104)
            .offset(x: spreadCities ? 108 : 154, y: spreadCities ? -34 : -70)
            .scaleEffect(spreadCities ? 1 : 0.65)
            .opacity(spreadCities ? 1 : (step == 3 ? 0 : 0.16))
            .scaleEffect(step == 0 && entrance < 2 && !reduceMotion ? 0.65 : 1)
            .offset(
              x: parallax(0.05),
              y: (step == 0 && entrance < 2 && !reduceMotion ? 28 : 0)
                + parallax(0.03, vertical: true)
            )
            .opacity(step == 0 && entrance < 2 && !reduceMotion ? 0 : 1)
          city("Paris", size: 136)
            .scaleEffect(spreadCities ? 0.86 : 1.2)
            .offset(y: spreadCities ? 43 : -18)
            .scaleEffect(step == 0 && entrance == 0 && !reduceMotion ? 1.45 : 1)
            .offset(x: parallax(0.12), y: parallax(0.07, vertical: true))

          person("You", initial: "Y", color: WIFTheme.fresh, textColor: WIFTheme.canvas)
            .offset(x: spreadCities ? -123 : -31, y: spreadCities ? -126 : -112)
            .opacity(step == 3 ? 0 : 1)
            .offset(
              x: step == 1 && !friendsMet && !reduceMotion ? -98 : 0,
              y: step == 1 && !friendsMet && !reduceMotion ? 32 : 0
            )
            .modifier(OnboardingPersonEntrance(visible: step != 0 || entrance >= 3 || reduceMotion))
            .offset(x: parallax(0.18), y: parallax(0.10, vertical: true))
          person("Mia", initial: "M", color: Color(red: 0.63, green: 0.39, blue: 0.25))
            .offset(x: spreadCities ? 35 : 32, y: spreadCities ? -5 : -112)
            .opacity(step == 3 ? 0 : 1)
            .modifier(OnboardingPersonEntrance(visible: step != 0 || entrance >= 3 || reduceMotion))
            .offset(x: parallax(0.18), y: parallax(0.10, vertical: true))
          person("Kai", initial: "K", color: Color(red: 0.31, green: 0.48, blue: 0.60))
            .offset(x: spreadCities ? 125 : 150, y: spreadCities ? -112 : -105)
            .opacity(spreadCities ? 1 : 0)
            .modifier(OnboardingPersonEntrance(visible: step != 0 || entrance >= 3 || reduceMotion))
            .offset(x: parallax(0.18), y: parallax(0.10, vertical: true))

          Text("New York")
            .offset(x: -103, y: 13)
            .opacity(spreadCities ? 1 : 0)
            .opacity(step == 0 && entrance < 1 && !reduceMotion ? 0 : 1)
          Text("Tokyo")
            .offset(x: 108, y: 31)
            .opacity(spreadCities ? 1 : 0)
            .opacity(step == 0 && entrance < 2 && !reduceMotion ? 0 : 1)
          Text(step == 3 ? "Paris, France" : "Paris")
            .offset(y: spreadCities ? 120 : 77)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(WIFTheme.secondaryText)
        .offset(x: reduceMotion ? 0 : drag.width * 0.025, y: reduceMotion ? 0 : drag.height * 0.025)
        .rotation3DEffect(
          .degrees(reduceMotion ? 0 : Double(drag.width * 0.018)), axis: (x: 0, y: 1, z: 0)
        )
        .scaleEffect(scale)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .accessibilityHidden(true)

      }
      .contentShape(Rectangle())
      .simultaneousGesture(
        DragGesture(minimumDistance: 12)
          .onChanged { value in
            guard !reduceMotion else { return }
            drag = CGSize(
              width: min(max(value.translation.width, -90), 90),
              height: min(max(value.translation.height, -60), 60))
          }
          .onEnded { _ in
            withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.8)) {
              drag = .zero
            }
          })
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      step == 0
        ? "Preview: friends in New York, Paris and Tokyo"
        : (step == 1
          ? "Example: you and Mia meet in Paris"
          : (step == 2
            ? "Example: friends travel to Paris from different cities"
            : "City-level sharing: Paris, France")))
  }

  private func parallax(_ depth: CGFloat, vertical: Bool = false) -> CGFloat {
    reduceMotion ? 0 : (vertical ? drag.height : drag.width) * depth
  }

  @ViewBuilder
  private var chapterDetail: some View {
    if step == 1 || step == 2 {
      VStack(spacing: 10) {
        if step == 1 { notificationCard } else { tripCard }
        Text(step == 1 ? "Example notification" : "Example trip")
          .font(.caption2)
          .foregroundStyle(WIFTheme.secondaryText)
      }
      .padding(.horizontal, 24)
      .opacity(detailRevealed || reduceMotion ? 1 : 0)
      .offset(y: detailRevealed || reduceMotion ? 0 : (step == 1 ? -52 : 20))
      .scaleEffect(detailRevealed || reduceMotion ? 1 : 0.94)
      .accessibilityHidden(!detailRevealed && !reduceMotion)
    } else {
      // No fake playback controls or developer-facing preview labels.
      Color.clear.frame(height: 12).accessibilityHidden(true)
    }
  }

  private var notificationCard: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 9) {
        Image("OnboardingAppIcon")
          .resizable()
          .frame(width: 26, height: 26)
          .clipShape(RoundedRectangle(cornerRadius: 7))
          .accessibilityHidden(true)
        Text("Across Us").font(.caption.weight(.semibold))
        Spacer(minLength: 8)
        Text("now").font(.caption2)
      }
      .foregroundStyle(WIFTheme.secondaryText)
      VStack(alignment: .leading, spacing: 4) {
        Text("Mia is in Paris too").font(.subheadline.weight(.semibold))
        Text("You’re in the same city. Time to catch up?")
          .font(.subheadline)
          .foregroundStyle(WIFTheme.secondaryText)
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(WIFTheme.border.opacity(0.28)))
    .shadow(color: WIFTheme.primaryText.opacity(0.07), radius: 18, y: 8)
    .foregroundStyle(WIFTheme.primaryText)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("onboardingExampleNotification")
  }

  private var tripCard: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Paris weekend").font(.headline)
          Text("Sep 17–20 · 3 friends")
            .font(.caption)
            .foregroundStyle(WIFTheme.secondaryText)
        }
        Spacer(minLength: 8)
        Image(systemName: "suitcase.rolling")
          .font(.title3)
          .foregroundStyle(WIFTheme.fresh)
          .accessibilityHidden(true)
      }
      Rectangle().fill(WIFTheme.border.opacity(0.35)).frame(height: 0.5)
      flightRow(person: "You", route: "New York → Paris", arrival: "08:40")
        .opacity(firstArrived || reduceMotion ? 1 : 0)
        .offset(y: firstArrived || reduceMotion ? 0 : 10)
        .accessibilityHidden(!firstArrived && !reduceMotion)
      flightRow(person: "Kai", route: "Tokyo → Paris", arrival: "10:15")
        .opacity(secondArrived || reduceMotion ? 1 : 0)
        .offset(y: secondArrived || reduceMotion ? 0 : 10)
        .accessibilityHidden(!secondArrived && !reduceMotion)
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(WIFTheme.surface, in: RoundedRectangle(cornerRadius: 24))
    .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(WIFTheme.border.opacity(0.28)))
    .foregroundStyle(WIFTheme.primaryText)
    .accessibilityElement(children: .combine)
    .accessibilityIdentifier("onboardingExampleTrip")
  }

  private func flightRow(person: String, route: String, arrival: String) -> some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        flightDescription(person: person, route: route)
        Spacer(minLength: 8)
        Text("Arrives \(arrival)").font(.caption).foregroundStyle(WIFTheme.secondaryText)
          .fixedSize()
      }
      VStack(alignment: .leading, spacing: 4) {
        flightDescription(person: person, route: route)
        Text("Arrives \(arrival)").font(.caption).foregroundStyle(WIFTheme.secondaryText)
      }
    }
  }

  private func flightDescription(person: String, route: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(person).font(.caption.weight(.semibold))
      Text(route).font(.caption).foregroundStyle(WIFTheme.secondaryText)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private func city(_ name: String, size: CGFloat) -> some View {
    let asset =
      switch name {
      case "New York": "OnboardingNewYorkFreestanding"
      case "Tokyo": "OnboardingTokyoFreestanding"
      default: "OnboardingParisFreestanding"
      }
    return ZStack {
      Ellipse()
        .fill(WIFTheme.primaryText.opacity(0.08))
        .frame(width: size * 0.42, height: size * 0.07)
        .blur(radius: 4)
        .offset(y: size * 0.43)
      Image(asset)
        .resizable()
        .scaledToFit()
        .frame(width: size, height: size)
    }
    .frame(width: size, height: size)
  }

  private func person(_ name: String, initial: String, color: Color, textColor: Color = .white)
    -> some View
  {
    VStack(spacing: 4) {
      Text(initial)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(textColor)
        .frame(width: 30, height: 30)
        .background(color, in: Circle())
        .overlay(Circle().strokeBorder(WIFTheme.canvas, lineWidth: 2))
      Text(name).font(.system(size: 10, weight: .medium))
    }
  }

  private var connection: Path {
    Path { path in
      path.move(to: CGPoint(x: 65, y: 90))
      path.addQuadCurve(to: CGPoint(x: 165, y: 180), control: CGPoint(x: 70, y: 180))
      path.move(to: CGPoint(x: 273, y: 105))
      path.addQuadCurve(to: CGPoint(x: 165, y: 180), control: CGPoint(x: 260, y: 195))
    }
  }
}

private struct OnboardingPersonEntrance: ViewModifier {
  let visible: Bool
  func body(content: Content) -> some View {
    content.opacity(visible ? 1 : 0)
      .scaleEffect(visible ? 1 : 0.6)
      .offset(y: visible ? 0 : 12)
  }
}

/// Shared curve math keeps the aircraft, heading, trail and drawn route aligned.
enum OnboardingFlightTrajectory {
  static func point(at progress: CGFloat, fromEast: Bool) -> CGPoint {
    let t = min(max(progress, 0), 1)
    let start = fromEast ? CGPoint(x: 273, y: 105) : CGPoint(x: 65, y: 90)
    let control = fromEast ? CGPoint(x: 260, y: 195) : CGPoint(x: 70, y: 180)
    let end = CGPoint(x: 165, y: 180)
    return CGPoint(
      x: (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * control.x + t * t * end.x,
      y: (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * control.y + t * t * end.y)
  }

  static func heading(at progress: CGFloat, fromEast: Bool) -> Double {
    let before = point(at: progress - 0.001, fromEast: fromEast)
    let after = point(at: progress + 0.001, fromEast: fromEast)
    return atan2(Double(after.y - before.y), Double(after.x - before.x)) * 180 / .pi
  }

  static func path(fromEast: Bool, from lower: CGFloat = 0, to upper: CGFloat = 1) -> Path {
    let a = min(max(lower, 0), 1)
    let b = min(max(upper, a), 1)
    let start = point(at: 0, fromEast: fromEast)
    let end = point(at: 1, fromEast: fromEast)
    let control = fromEast ? CGPoint(x: 260, y: 195) : CGPoint(x: 70, y: 180)
    let segmentStart = point(at: a, fromEast: fromEast)
    // Use the same Bézier parameter as the airplane, not Path.trim's arc length.
    let segmentControl = CGPoint(
      x: segmentStart.x + (b - a) * ((1 - a) * (control.x - start.x) + a * (end.x - control.x)),
      y: segmentStart.y + (b - a) * ((1 - a) * (control.y - start.y) + a * (end.y - control.y)))
    return Path { path in
      path.move(to: segmentStart)
      path.addQuadCurve(
        to: point(at: b, fromEast: fromEast), control: segmentControl)
    }
  }
}

/// Interpolates only while a flight is moving; no permanent TimelineView or timer.
private struct OnboardingFlightRoutes: View, Animatable {
  var first: CGFloat
  var second: CGFloat
  var animatableData: AnimatablePair<CGFloat, CGFloat> {
    get { AnimatablePair(first, second) }
    set {
      first = newValue.first
      second = newValue.second
    }
  }

  var body: some View {
    ZStack(alignment: .topLeading) {
      aircraft(progress: first, fromEast: false, color: WIFTheme.fresh)
      aircraft(progress: second, fromEast: true, color: Color(red: 0.31, green: 0.48, blue: 0.60))
    }
    .frame(width: 330, height: 250)
    .accessibilityHidden(true)
  }

  private func aircraft(progress: CGFloat, fromEast: Bool, color: Color) -> some View {
    let p = min(max(progress, 0), 1)
    let point = OnboardingFlightTrajectory.point(at: p, fromEast: fromEast)
    return ZStack(alignment: .topLeading) {
      OnboardingFlightTrajectory.path(fromEast: fromEast, to: p)
        .stroke(color.opacity(0.25), style: StrokeStyle(lineWidth: 1.2, dash: [3, 5]))
      OnboardingFlightTrajectory.path(fromEast: fromEast, from: max(0, p - 0.16), to: p)
        .stroke(color.opacity(0.65), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .opacity(p > 0.9 ? Double((1 - p) * 10) : 1)
      Image(systemName: "airplane")
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(color)
        .rotationEffect(.degrees(OnboardingFlightTrajectory.heading(at: p, fromEast: fromEast)))
        .position(point)
        .opacity(p < 0.03 ? Double(p / 0.03) : (p > 0.93 ? Double((1 - p) / 0.07) : 1))
    }
  }
}
