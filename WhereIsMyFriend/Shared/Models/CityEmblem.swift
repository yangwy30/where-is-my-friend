import SwiftUI

/// Represents a 3D skeuomorphic city emblem or procedural fallback.
public struct CityEmblem: Hashable, Sendable {
    public let cityID: String
    public let displayName: String
    public let countryCode: String?
    public let assetName: String?
    public let archetype: CityArchetype

    public init(
        cityID: String,
        displayName: String,
        countryCode: String?,
        assetName: String? = nil,
        archetype: CityArchetype = .metropolis
    ) {
        self.cityID = cityID
        self.displayName = displayName
        self.countryCode = countryCode
        self.assetName = assetName
        self.archetype = archetype
    }

    /// Resolves a city name and optional country code into a standardized `CityEmblem`.
    public static func resolve(city: String?, countryCode: String? = nil) -> CityEmblem {
        guard let city = city?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty else {
            return CityEmblem(cityID: "unknown", displayName: "Somewhere", countryCode: countryCode, archetype: .metropolis)
        }

        let normalized = CityIdentity.normalize(city)

        if let match = registeredCities[normalized] {
            return match
        }

        // Check aliases
        for (alias, match) in cityAliases where normalized.contains(alias) || alias.contains(normalized) {
            return match
        }

        // Fallback: Infer archetype from country code or city name
        let inferredArchetype = CityArchetype.infer(from: city, countryCode: countryCode)
        return CityEmblem(
            cityID: normalized.replacingOccurrences(of: " ", with: "_"),
            displayName: city,
            countryCode: countryCode,
            assetName: nil,
            archetype: inferredArchetype
        )
    }

    // MARK: - Registry of Curated 3D Assets & Metadata

    private static let registeredCities: [String: CityEmblem] = [
        "new york": CityEmblem(cityID: "new_york", displayName: "New York", countryCode: "US", assetName: "City_new_york", archetype: .metropolis),
        "tokyo": CityEmblem(cityID: "tokyo", displayName: "Tokyo", countryCode: "JP", assetName: "City_tokyo", archetype: .asian),
        "london": CityEmblem(cityID: "london", displayName: "London", countryCode: "GB", assetName: "City_london", archetype: .european),
        "paris": CityEmblem(cityID: "paris", displayName: "Paris", countryCode: "FR", assetName: "City_paris", archetype: .european),
        "san francisco": CityEmblem(cityID: "san_francisco", displayName: "San Francisco", countryCode: "US", assetName: "City_san_francisco", archetype: .coastal),
        "beijing": CityEmblem(cityID: "beijing", displayName: "Beijing", countryCode: "CN", assetName: "City_beijing", archetype: .asian),
        "los angeles": CityEmblem(cityID: "los_angeles", displayName: "Los Angeles", countryCode: "US", assetName: "City_los_angeles", archetype: .coastal),
        "chicago": CityEmblem(cityID: "chicago", displayName: "Chicago", countryCode: "US", assetName: "City_chicago", archetype: .metropolis),
        "seattle": CityEmblem(cityID: "seattle", displayName: "Seattle", countryCode: "US", assetName: "City_seattle", archetype: .coastal),
        "rome": CityEmblem(cityID: "rome", displayName: "Rome", countryCode: "IT", assetName: "City_rome", archetype: .european),
        "sydney": CityEmblem(cityID: "sydney", displayName: "Sydney", countryCode: "AU", assetName: "City_sydney", archetype: .coastal),
        "berlin": CityEmblem(cityID: "berlin", displayName: "Berlin", countryCode: "DE", assetName: "City_berlin", archetype: .european),
        "shanghai": CityEmblem(cityID: "shanghai", displayName: "Shanghai", countryCode: "CN", assetName: "City_shanghai", archetype: .metropolis),
        "hong kong": CityEmblem(cityID: "hong_kong", displayName: "Hong Kong", countryCode: "HK", assetName: "City_hong_kong", archetype: .metropolis),
        "singapore": CityEmblem(cityID: "singapore", displayName: "Singapore", countryCode: "SG", assetName: "City_singapore", archetype: .coastal),
        "seoul": CityEmblem(cityID: "seoul", displayName: "Seoul", countryCode: "KR", assetName: "City_seoul", archetype: .asian),
        "dubai": CityEmblem(cityID: "dubai", displayName: "Dubai", countryCode: "AE", assetName: "City_dubai", archetype: .desert),
        "amsterdam": CityEmblem(cityID: "amsterdam", displayName: "Amsterdam", countryCode: "NL", assetName: "City_amsterdam", archetype: .european),
        "barcelona": CityEmblem(cityID: "barcelona", displayName: "Barcelona", countryCode: "ES", assetName: "City_barcelona", archetype: .european),
        "toronto": CityEmblem(cityID: "toronto", displayName: "Toronto", countryCode: "CA", assetName: "City_toronto", archetype: .metropolis),
        "cairo": CityEmblem(cityID: "cairo", displayName: "Cairo", countryCode: "EG", assetName: "City_cairo", archetype: .desert),
        "rio de janeiro": CityEmblem(cityID: "rio_de_janeiro", displayName: "Rio de Janeiro", countryCode: "BR", assetName: "City_rio_de_janeiro", archetype: .coastal),
        "boston": CityEmblem(cityID: "boston", displayName: "Boston", countryCode: "US", assetName: "City_boston", archetype: .european),
        "miami": CityEmblem(cityID: "miami", displayName: "Miami", countryCode: "US", assetName: "City_miami", archetype: .coastal),
        "austin": CityEmblem(cityID: "austin", displayName: "Austin", countryCode: "US", assetName: "City_austin", archetype: .metropolis),
        "las vegas": CityEmblem(cityID: "las_vegas", displayName: "Las Vegas", countryCode: "US", assetName: "City_las_vegas", archetype: .desert),
        "washington": CityEmblem(cityID: "washington", displayName: "Washington", countryCode: "US", assetName: "City_washington", archetype: .european),
        "honolulu": CityEmblem(cityID: "honolulu", displayName: "Honolulu", countryCode: "US", assetName: "City_honolulu", archetype: .coastal),
        "houston": CityEmblem(cityID: "houston", displayName: "Houston", countryCode: "US", assetName: "City_houston", archetype: .metropolis),
        "philadelphia": CityEmblem(cityID: "philadelphia", displayName: "Philadelphia", countryCode: "US", assetName: "City_philadelphia", archetype: .european)
    ]

    private static let cityAliases: [String: CityEmblem] = [
        "nyc": registeredCities["new york"]!,
        "new york city": registeredCities["new york"]!,
        "manhattan": registeredCities["new york"]!,
        "brooklyn": registeredCities["new york"]!,
        "sf": registeredCities["san francisco"]!,
        "bay area": registeredCities["san francisco"]!,
        "la": registeredCities["los angeles"]!,
        "hollywood": registeredCities["los angeles"]!,
        "shibuya": registeredCities["tokyo"]!,
        "shinjuku": registeredCities["tokyo"]!,
        "ginza": registeredCities["tokyo"]!,
        "westminster": registeredCities["london"]!,
        "soho": registeredCities["london"]!,
        "peking": registeredCities["beijing"]!
    ]
}

/// Regional architectural and landscape archetypes for Tier 2 fallback.
public enum CityArchetype: String, CaseIterable, Sendable {
    case european
    case metropolis
    case coastal
    case alpine
    case asian
    case desert

    public var iconSymbol: String {
        switch self {
        case .european: return "building.columns.fill"
        case .metropolis: return "building.2.fill"
        case .coastal: return "water.waves"
        case .alpine: return "mountain.2.fill"
        case .asian: return "house.lodge.fill"
        case .desert: return "sun.max.fill"
        }
    }

    public var themeColor: Color {
        switch self {
        case .european: return Color(red: 0.72, green: 0.58, blue: 0.44)
        case .metropolis: return Color(red: 0.35, green: 0.52, blue: 0.72)
        case .coastal: return Color(red: 0.22, green: 0.65, blue: 0.75)
        case .alpine: return Color(red: 0.45, green: 0.68, blue: 0.55)
        case .asian: return Color(red: 0.82, green: 0.35, blue: 0.30)
        case .desert: return Color(red: 0.85, green: 0.62, blue: 0.28)
        }
    }

    public static func infer(from city: String, countryCode: String?) -> CityArchetype {
        let code = countryCode?.uppercased() ?? ""
        if ["JP", "CN", "KR", "TW", "HK", "TH", "VN", "SG"].contains(code) {
            return .asian
        }
        if ["GB", "FR", "IT", "DE", "ES", "NL", "AT", "CZ", "PT", "GR", "CH"].contains(code) {
            return .european
        }
        if ["AE", "EG", "SA", "QA", "MA"].contains(code) {
            return .desert
        }
        if ["NO", "SE", "FI", "IS", "NZ", "CH", "AT"].contains(code) {
            return .alpine
        }
        return .metropolis
    }
}

/// A SwiftUI view that displays a high-fidelity 3D miniature city emblem or procedural fallback.
public struct CityEmblemView: View {
    public let emblem: CityEmblem
    public var size: CGFloat

    public init(city: String?, countryCode: String? = nil, size: CGFloat = 84) {
        self.emblem = CityEmblem.resolve(city: city, countryCode: countryCode)
        self.size = size
    }

    public init(emblem: CityEmblem, size: CGFloat = 84) {
        self.emblem = emblem
        self.size = size
    }

    private var loadedImage: UIImage? {
        guard let assetName = emblem.assetName else { return nil }
        if let direct = UIImage(named: assetName) { return direct }
        if let namespaced = UIImage(named: "CityEmblems/\(assetName)") { return namespaced }
        return nil
    }

    public var body: some View {
        ZStack {
            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .shadow(color: Color.black.opacity(0.14), radius: size * 0.08, x: 0, y: size * 0.05)
            } else {
                proceduralFallback
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(emblem.displayName)
    }

    private var proceduralFallback: some View {
        ZStack {
            // Tactile aluminum base pedestal
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.94),
                            Color(white: 0.82),
                            Color(white: 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.14), radius: size * 0.07, x: 0, y: size * 0.04)

            // Frosted glass inner platform
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(emblem.archetype.themeColor.opacity(0.15))
                .padding(size * 0.10)

            // Archetype symbol and city initial
            VStack(spacing: size * 0.02) {
                Image(systemName: emblem.archetype.iconSymbol)
                    .font(.system(size: size * 0.30, weight: .semibold, design: .rounded))
                    .foregroundStyle(emblem.archetype.themeColor)

                Text(String(emblem.displayName.prefix(3)).uppercased())
                    .font(.system(size: size * 0.14, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("City Emblems Grid") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 20) {
            ForEach(["New York", "Tokyo", "London", "Paris", "San Francisco", "Beijing", "Sydney", "Rome", "Zurich", "Honolulu"], id: \.self) { city in
                VStack(spacing: 8) {
                    CityEmblemView(city: city, size: 84)
                    Text(city)
                        .font(.caption.weight(.semibold))
                }
            }
        }
        .padding()
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
