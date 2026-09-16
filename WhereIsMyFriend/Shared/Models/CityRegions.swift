import Foundation

/// Display formatting only; never supplies missing geographic identity for matching.
enum CityLocationLabel {
    static func compact(city: String?, countryCode: String?, administrativeArea: String?) -> String? {
        guard let city = cleaned(city) else { return nil }
        let area = cleaned(administrativeArea)
        let state = usState(countryCode: countryCode, area: area)
        return joined([city, state?.code ?? area])
    }

    static func full(city: String?, countryCode: String?, administrativeArea: String?, locale: Locale = .current) -> String? {
        guard let city = cleaned(city) else { return nil }
        let area = cleaned(administrativeArea)
        let state = usState(countryCode: countryCode, area: area)
        let country = cleaned(countryCode).map { locale.localizedString(forRegionCode: $0.uppercased()) ?? $0.uppercased() }
        return joined([city, state?.name ?? area, country])
    }

    private static func cleaned(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private static func joined(_ parts: [String?]) -> String {
        var seen = Set<String>()
        return parts.compactMap { $0 }.filter { seen.insert($0.lowercased()).inserted }.joined(separator: ", ")
    }

    private static func usState(countryCode: String?, area: String?) -> (code: String, name: String)? {
        guard cleaned(countryCode)?.uppercased() == "US", let area else { return nil }
        let code = area.uppercased()
        if let name = usStates[code] { return (code, name) }
        if let state = usStates.first(where: { $0.value.caseInsensitiveCompare(area) == .orderedSame }) {
            return (state.key, state.value)
        }
        return nil
    }

    private static let usStates = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California",
        "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware", "DC": "District of Columbia",
        "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho", "IL": "Illinois",
        "IN": "Indiana", "IA": "Iowa", "KS": "Kansas", "KY": "Kentucky", "LA": "Louisiana",
        "ME": "Maine", "MD": "Maryland", "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota",
        "MS": "Mississippi", "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
        "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
        "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma", "OR": "Oregon",
        "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota",
        "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VT": "Vermont", "VA": "Virginia",
        "WA": "Washington", "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming",
        "PR": "Puerto Rico", "VI": "U.S. Virgin Islands", "GU": "Guam",
        "AS": "American Samoa", "MP": "Northern Mariana Islands"
    ]
}

/// Presentation membership only. Neither city identity nor notification eligibility uses this catalog.
struct CityRegion: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let displayName: String
    let countryCode: String
    let artworkCity: String
    let members: [Member]

    struct Member: Codable, Hashable, Sendable {
        let administrativeArea: String
        let administrativeAliases: [String]
        let cities: [String]
    }
}

struct CityRegionCatalog: Decodable, Sendable {
    let schemaVersion: Int
    let version: String
    let regionMatchingEnabled: Bool
    let regions: [CityRegion]
    var administrativeAliases: [String: [String: String]]? = nil

    static let bundled: CityRegionCatalog = {
        guard let url = Bundle.main.url(forResource: "city-regions.v1", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Self.self, from: data),
              catalog.schemaVersion == 1, !catalog.regionMatchingEnabled else {
            // Fail closed: a missing/unsupported catalog must not change geographic identity.
            return Self(schemaVersion: 1, version: "unavailable", regionMatchingEnabled: false, regions: [])
        }
        return catalog
    }()

    static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    func resolve(city: String?, countryCode: String?, administrativeArea: String?) -> CityRegion? {
        guard schemaVersion == 1, let city, let countryCode, let administrativeArea,
              !Self.normalize(city).isEmpty, !Self.normalize(administrativeArea).isEmpty else { return nil }
        let matches = regions.filter { region in
            Self.normalize(region.countryCode) == Self.normalize(countryCode) && region.members.contains { member in
                ([member.administrativeArea] + member.administrativeAliases).contains {
                    Self.normalize($0) == Self.normalize(administrativeArea)
                } && member.cities.contains { Self.normalize($0) == Self.normalize(city) }
            }
        }
        // Ambiguous data is not a reason to choose the first record.
        return matches.count == 1 ? matches[0] : nil
    }
}
