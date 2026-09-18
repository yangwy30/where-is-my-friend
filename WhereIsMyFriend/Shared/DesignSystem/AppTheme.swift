import SwiftUI
import UIKit

enum WIFAppearance: String, CaseIterable, Identifiable {
    case solarJade
    case nightJade

    var id: String { rawValue }

    var colorScheme: ColorScheme {
        switch self {
        case .solarJade: .light
        case .nightJade: .dark
        }
    }
}

enum SharedAppearancePreference {
    static let key = "wif.appearance"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: SharedPresenceStore.appGroupIdentifier) ?? .standard
    }

    static var appearance: WIFAppearance {
        get {
            guard let rawValue = defaults.string(forKey: key),
                  let appearance = WIFAppearance(rawValue: rawValue) else {
                return .solarJade
            }
            return appearance
        }
        set {
            defaults.set(newValue.rawValue, forKey: key)
        }
    }
}

@MainActor
final class WIFAppearanceController: ObservableObject {
    @Published private(set) var appearance: WIFAppearance

    init(appearance: WIFAppearance = SharedAppearancePreference.appearance) {
        self.appearance = appearance
    }

    func select(_ appearance: WIFAppearance) {
        guard self.appearance != appearance else { return }
        self.appearance = appearance
        SharedAppearancePreference.appearance = appearance
    }
}

enum WIFTheme {
    static let canvas = Color.adaptive(
        light: UIColor(red: 0.992, green: 0.984, blue: 0.949, alpha: 1),
        dark: UIColor(red: 0.027, green: 0.067, blue: 0.043, alpha: 1)
    )

    static let surface = Color.adaptive(
        light: UIColor(red: 1.000, green: 0.996, blue: 0.976, alpha: 1),
        dark: UIColor(red: 0.067, green: 0.133, blue: 0.090, alpha: 1)
    )

    static let elevatedSurface = Color.adaptive(
        light: UIColor(red: 0.933, green: 0.976, blue: 0.855, alpha: 1),
        dark: UIColor(red: 0.090, green: 0.208, blue: 0.141, alpha: 1)
    )

    static let primaryText = Color.adaptive(
        light: UIColor(red: 0.075, green: 0.188, blue: 0.129, alpha: 1),
        dark: UIColor(red: 0.929, green: 0.976, blue: 0.945, alpha: 1)
    )

    static let secondaryText = Color.adaptive(
        light: UIColor(red: 0.365, green: 0.447, blue: 0.373, alpha: 1),
        dark: UIColor(red: 0.620, green: 0.710, blue: 0.639, alpha: 1)
    )

    static let fresh = Color.adaptive(
        light: UIColor(red: 0.016, green: 0.459, blue: 0.322, alpha: 1),
        dark: UIColor(red: 0.651, green: 0.902, blue: 0.467, alpha: 1)
    )

    static let freshSurface = Color.adaptive(
        light: UIColor(red: 0.855, green: 0.957, blue: 0.694, alpha: 1),
        dark: UIColor(red: 0.098, green: 0.235, blue: 0.157, alpha: 1)
    )

    static let eventBlue = Color.adaptive(
        light: UIColor(red: 0.867, green: 0.961, blue: 0.925, alpha: 1),
        dark: UIColor(red: 0.075, green: 0.153, blue: 0.224, alpha: 1)
    )

    static let sunGlow = Color.adaptive(
        light: UIColor(red: 1.000, green: 0.824, blue: 0.302, alpha: 1),
        dark: UIColor(red: 0.804, green: 0.969, blue: 0.302, alpha: 1)
    )

    static let border = Color.adaptive(
        light: UIColor(red: 0.710, green: 0.824, blue: 0.741, alpha: 0.66),
        dark: UIColor(red: 0.176, green: 0.302, blue: 0.224, alpha: 0.76)
    )

    static let destructive = Color.adaptive(
        light: UIColor(red: 0.710, green: 0.286, blue: 0.286, alpha: 1),
        dark: UIColor(red: 0.941, green: 0.537, blue: 0.537, alpha: 1)
    )

    static var eventGradient: LinearGradient {
        LinearGradient(
            colors: [freshSurface, eventBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cityGradient: LinearGradient {
        LinearGradient(
            colors: [elevatedSurface, eventBlue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let smallRadius: CGFloat = 12
    static let mediumRadius: CGFloat = 18
    static let largeRadius: CGFloat = 24
    static let screenInset: CGFloat = 20

    static var ambientGradient: LinearGradient {
        LinearGradient(
            colors: [
                canvas,
                freshSurface.opacity(0.38),
                eventBlue.opacity(0.34),
                canvas
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Small travel accents that carry a little of TripFlights' energy without
/// replacing Across Us' adaptive jade surfaces and typography.
enum WIFTripTheme {
    static let sky = Color.adaptive(
        light: UIColor(red: 0.176, green: 0.502, blue: 0.710, alpha: 1),
        dark: UIColor(red: 0.357, green: 0.741, blue: 0.922, alpha: 1)
    )

    static let warm = Color.adaptive(
        light: UIColor(red: 0.773, green: 0.357, blue: 0.204, alpha: 1),
        dark: UIColor(red: 0.973, green: 0.604, blue: 0.420, alpha: 1)
    )

    static let violet = Color.adaptive(
        light: UIColor(red: 0.424, green: 0.357, blue: 0.690, alpha: 1),
        dark: UIColor(red: 0.706, green: 0.620, blue: 0.933, alpha: 1)
    )
}

/// A content backdrop with enough depth and color for Liquid Glass to refract.
/// Controls float above this layer; the backdrop itself never behaves like a control.
struct WIFAmbientBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            WIFTheme.canvas

            if !reduceTransparency {
                WIFTheme.ambientGradient

                Circle()
                    .fill(WIFTheme.fresh.opacity(0.10))
                    .frame(width: 310, height: 310)
                    .blur(radius: 72)
                    .offset(x: 150, y: -280)

                Circle()
                    .fill(WIFTheme.sunGlow.opacity(0.065))
                    .frame(width: 280, height: 280)
                    .blur(radius: 82)
                    .offset(x: -170, y: 330)

                Circle()
                    .fill(WIFTheme.eventBlue.opacity(0.10))
                    .frame(width: 300, height: 300)
                    .blur(radius: 88)
                    .offset(x: 180, y: 360)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Uses Apple's native Liquid Glass on iOS 26+ and a legible material fallback
/// for the app's iOS 18–25 support range.
private struct WIFGlassSurfaceModifier<S: Shape>: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let tint: Color?
    let interactive: Bool
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(WIFTheme.surface, in: shape)
                .overlay { shape.stroke(WIFTheme.border, lineWidth: 1) }
        } else if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay {
                    shape.stroke(WIFTheme.border.opacity(0.82), lineWidth: 1)
                }
        }
    }
}

/// Content stays on a stable surface; glass belongs to floating controls/navigation.
private struct WIFContentSurfaceModifier<S: Shape>: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast
    let tint: Color?
    let interactive: Bool
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content.background {
                shape.fill(WIFTheme.surface)
                if let tint { shape.fill(tint) }
            }
            .overlay {
                shape.stroke(
                    WIFTheme.border.opacity(contrast == .increased ? 1 : 0.4),
                    lineWidth: contrast == .increased ? 1.5 : 0.7
                )
            }
        } else {
            content.wifGlassSurface(tint: tint, interactive: interactive, in: shape)
        }
    }
}

enum WIFToolbarPlacement {
    static var primary: ToolbarItemPlacement {
        if #available(iOS 27.0, *) { return .topBarPinnedTrailing }
        return .primaryAction
    }
}

extension View {
    func wifContentSurface<S: Shape>(tint: Color? = nil, interactive: Bool = false, in shape: S) -> some View {
        modifier(WIFContentSurfaceModifier(tint: tint, interactive: interactive, shape: shape))
    }

    /// Trip actions must stay reachable while reading a long arrivals board.
    @ViewBuilder
    func wifPersistentTripNavigation() -> some View {
        if #available(iOS 27.0, *) {
            toolbarMinimizationBehavior(.never, for: .navigationBar)
        } else {
            self
        }
    }

    @ViewBuilder
    func wifNavigationSurface() -> some View {
        if #available(iOS 27.0, *) {
            toolbarBackground(.automatic, for: .navigationBar)
        } else {
            toolbarBackground(WIFTheme.canvas, for: .navigationBar)
        }
    }

    @ViewBuilder
    func wifPrimaryActionLabel(enabled: Bool) -> some View {
        if #available(iOS 27.0, *) {
            frame(minHeight: 26)
                .foregroundStyle(enabled ? WIFTheme.canvas : WIFTheme.secondaryText)
        } else {
            frame(minHeight: 52).foregroundStyle(enabled ? WIFTheme.canvas : WIFTheme.secondaryText)
                .background(enabled ? WIFTheme.fresh : WIFTheme.border.opacity(0.25), in: Capsule())
        }
    }

    @ViewBuilder
    func wifPrimaryActionStyle() -> some View {
        if #available(iOS 27.0, *) {
            buttonStyle(.glassProminent).tint(WIFTheme.fresh).controlSize(.large)
        } else {
            buttonStyle(.plain)
        }
    }

    func wifGlassSurface<S: Shape>(
        tint: Color? = nil,
        interactive: Bool = false,
        in shape: S
    ) -> some View {
        modifier(WIFGlassSurfaceModifier(tint: tint, interactive: interactive, shape: shape))
    }

    @ViewBuilder
    func wifGlassButton(tint: Color? = nil, prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *), prominent {
            buttonStyle(.glassProminent)
                .tint(tint)
        } else if #available(iOS 26.0, *) {
            buttonStyle(.glass)
                .tint(tint)
        } else if prominent {
            buttonStyle(.borderedProminent)
                .tint(tint)
        } else {
            buttonStyle(.bordered)
                .tint(tint)
        }
    }

    func wifAmbientBackground() -> some View {
        background { WIFAmbientBackground() }
    }

    @ViewBuilder
    func wifTabBarMinimizeOnScroll() -> some View {
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}

/// Nearby glass controls share a sampling region and can morph naturally on
/// current systems. The fallback preserves the exact same layout.
struct WIFGlassEffectGroup<Content: View>: View {
    let spacing: CGFloat?
    private let content: Content

    init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    @ViewBuilder
    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

private extension Color {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
