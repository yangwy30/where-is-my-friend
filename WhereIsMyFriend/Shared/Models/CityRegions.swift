import Foundation

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
