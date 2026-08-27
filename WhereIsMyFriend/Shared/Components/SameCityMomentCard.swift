import SwiftUI

struct SameCityMomentCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let friends: [FriendPresence]
    let city: String
    let referenceDate: Date

    private var names: String {
        friends.prefix(3).map(\.displayName).joined(separator: ", ")
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 14) {
                    cityMarker
                    description
                }
            } else {
                HStack(spacing: 14) {
                    cityMarker
                    description
                    Spacer(minLength: 0)
                    CityEmblemView(city: city, size: 48)
                }
            }
        }
        .padding(16)
        .wifGlassSurface(
            tint: WIFTheme.fresh.opacity(0.18),
            in: RoundedRectangle(cornerRadius: WIFTheme.largeRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var cityMarker: some View {
        Image(systemName: "location.fill")
            .font(.headline)
            .foregroundStyle(WIFTheme.fresh)
            .frame(width: 42, height: 42)
            .background(WIFTheme.fresh.opacity(0.13), in: Circle())
            .accessibilityHidden(true)
    }

    private var description: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Together in \(city)")
                .font(.headline)
                .foregroundStyle(WIFTheme.primaryText)

            Text("You and \(names)")
                .font(.subheadline)
                .foregroundStyle(WIFTheme.secondaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
        }
    }
}
