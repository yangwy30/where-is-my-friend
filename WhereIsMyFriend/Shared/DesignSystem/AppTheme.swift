import SwiftUI
import UIKit

enum WIFTheme {
    static let canvas = Color.adaptive(
        light: UIColor(red: 0.965, green: 0.969, blue: 0.949, alpha: 1),
        dark: UIColor(red: 0.061, green: 0.092, blue: 0.074, alpha: 1)
    )

    static let surface = Color.adaptive(
        light: .white,
        dark: UIColor(red: 0.090, green: 0.133, blue: 0.106, alpha: 1)
    )

    static let elevatedSurface = Color.adaptive(
        light: UIColor(red: 0.929, green: 0.957, blue: 0.937, alpha: 1),
        dark: UIColor(red: 0.118, green: 0.196, blue: 0.153, alpha: 1)
    )

    static let primaryText = Color.adaptive(
        light: UIColor(red: 0.090, green: 0.141, blue: 0.114, alpha: 1),
        dark: UIColor(red: 0.929, green: 0.961, blue: 0.937, alpha: 1)
    )

    static let secondaryText = Color.adaptive(
        light: UIColor(red: 0.365, green: 0.424, blue: 0.392, alpha: 1),
        dark: UIColor(red: 0.631, green: 0.694, blue: 0.655, alpha: 1)
    )

    static let fresh = Color.adaptive(
        light: UIColor(red: 0.157, green: 0.420, blue: 0.290, alpha: 1),
        dark: UIColor(red: 0.486, green: 0.820, blue: 0.635, alpha: 1)
    )

    static let freshSurface = Color.adaptive(
        light: UIColor(red: 0.867, green: 0.949, blue: 0.902, alpha: 1),
        dark: UIColor(red: 0.125, green: 0.286, blue: 0.208, alpha: 1)
    )

    static let eventBlue = Color.adaptive(
        light: UIColor(red: 0.855, green: 0.898, blue: 0.996, alpha: 1),
        dark: UIColor(red: 0.153, green: 0.216, blue: 0.365, alpha: 1)
    )

    static let border = Color.adaptive(
        light: UIColor(red: 0.870, green: 0.894, blue: 0.878, alpha: 1),
        dark: UIColor(red: 0.169, green: 0.224, blue: 0.188, alpha: 1)
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
}

private extension Color {
    static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
