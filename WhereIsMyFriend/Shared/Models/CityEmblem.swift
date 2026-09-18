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

    /// A generic illustration is presentation only, never a geographic identity.
    var fallbackAssetName: String {
        if cityID == "unknown" { return "City_unknown_location" }
        return archetype.assetName ?? "City_generic_block"
    }

    static func resolve(friend: FriendPresence) -> CityEmblem {
        guard friend.sharingState == .active else {
            return CityEmblem(cityID: "unknown", displayName: friend.cityDisplay, countryCode: nil)
        }
        return resolve(city: friend.city, countryCode: friend.countryCode, administrativeArea: friend.administrativeArea)
    }

    /// Resolves a city name and optional country code into a standardized `CityEmblem`.
    public static func resolve(city: String?, countryCode: String? = nil, administrativeArea: String? = nil) -> CityEmblem {
        guard let city = city?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty else {
            return CityEmblem(cityID: "unknown", displayName: "Somewhere", countryCode: countryCode, archetype: .metropolis)
        }

        let normalized = CityIdentity.normalize(city)
        if let region = CityRegionCatalog.bundled.resolve(city: city, countryCode: countryCode, administrativeArea: administrativeArea) {
            let artwork = resolve(city: region.artworkCity, countryCode: region.countryCode)
            // Reuse only the artwork. Preserve the actual city and its accessibility name.
            return CityEmblem(cityID: normalized.replacingOccurrences(of: " ", with: "_"), displayName: city,
                              countryCode: countryCode, assetName: artwork.assetName, archetype: artwork.archetype)
        }

        if let administrativeArea, !CityRegionCatalog.normalize(administrativeArea).isEmpty,
           let countryCode,
           CityRegionCatalog.bundled.regions.contains(where: { region in
               CityRegionCatalog.normalize(region.countryCode) == CityRegionCatalog.normalize(countryCode)
                   && region.members.contains { $0.cities.contains { CityRegionCatalog.normalize($0) == CityRegionCatalog.normalize(city) } }
           }) {
            // A known namesake in another state must not inherit this region's legacy city asset.
            return CityEmblem(cityID: normalized.replacingOccurrences(of: " ", with: "_"), displayName: city,
                              countryCode: countryCode, archetype: CityArchetype.infer(from: city, countryCode: countryCode, administrativeArea: administrativeArea))
        }

        let country = countryCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        func accepts(_ match: CityEmblem) -> Bool {
            country == nil || country == "" || country == match.countryCode
        }
        if let match = registeredCities[normalized], accepts(match) {
            return match
        }

        // Check aliases
        for (alias, match) in cityAliases where normalized == CityIdentity.normalize(alias) && accepts(match) {
            return match
        }

        // Fallback: Infer archetype from city name, country code, and state/administrativeArea
        let inferredArchetype = CityArchetype.infer(from: city, countryCode: countryCode, administrativeArea: administrativeArea)
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
        "philadelphia": CityEmblem(cityID: "philadelphia", displayName: "Philadelphia", countryCode: "US", assetName: "City_philadelphia", archetype: .european),
        "kyoto": CityEmblem(cityID: "kyoto", displayName: "Kyoto", countryCode: "JP", assetName: "City_kyoto", archetype: .asian),
        "taipei": CityEmblem(cityID: "taipei", displayName: "Taipei", countryCode: "TW", assetName: "City_taipei", archetype: .asian),
        "bangkok": CityEmblem(cityID: "bangkok", displayName: "Bangkok", countryCode: "TH", assetName: "City_bangkok", archetype: .asian),
        "venice": CityEmblem(cityID: "venice", displayName: "Venice", countryCode: "IT", assetName: "City_venice", archetype: .coastal),
        "florence": CityEmblem(cityID: "florence", displayName: "Florence", countryCode: "IT", assetName: "City_florence", archetype: .european),
        "milan": CityEmblem(cityID: "milan", displayName: "Milan", countryCode: "IT", assetName: "City_milan", archetype: .european),
        "madrid": CityEmblem(cityID: "madrid", displayName: "Madrid", countryCode: "ES", assetName: "City_madrid", archetype: .european),
        "munich": CityEmblem(cityID: "munich", displayName: "Munich", countryCode: "DE", assetName: "City_munich", archetype: .european),
        "vienna": CityEmblem(cityID: "vienna", displayName: "Vienna", countryCode: "AT", assetName: "City_vienna", archetype: .european),
        "prague": CityEmblem(cityID: "prague", displayName: "Prague", countryCode: "CZ", assetName: "City_prague", archetype: .european),
        "phoenix": CityEmblem(cityID: "phoenix", displayName: "Phoenix", countryCode: "US", assetName: "City_phoenix", archetype: .desert),
        "san antonio": CityEmblem(cityID: "san_antonio", displayName: "San Antonio", countryCode: "US", assetName: "City_san_antonio", archetype: .desert),
        "san diego": CityEmblem(cityID: "san_diego", displayName: "San Diego", countryCode: "US", assetName: "City_san_diego", archetype: .coastal),
        "dallas": CityEmblem(cityID: "dallas", displayName: "Dallas", countryCode: "US", assetName: "City_dallas", archetype: .metropolis),
        "denver": CityEmblem(cityID: "denver", displayName: "Denver", countryCode: "US", assetName: "City_denver", archetype: .alpine),
        "atlanta": CityEmblem(cityID: "atlanta", displayName: "Atlanta", countryCode: "US", assetName: "City_atlanta", archetype: .metropolis),
        "nashville": CityEmblem(cityID: "nashville", displayName: "Nashville", countryCode: "US", assetName: "City_nashville", archetype: .metropolis),
        "new orleans": CityEmblem(cityID: "new_orleans", displayName: "New Orleans", countryCode: "US", assetName: "City_new_orleans", archetype: .coastal),
        "portland": CityEmblem(cityID: "portland", displayName: "Portland", countryCode: "US", assetName: "City_portland", archetype: .coastal),
        "st louis": CityEmblem(cityID: "st_louis", displayName: "St. Louis", countryCode: "US", assetName: "City_st_louis", archetype: .metropolis),
        "melbourne": CityEmblem(cityID: "melbourne", displayName: "Melbourne", countryCode: "AU", assetName: "City_melbourne", archetype: .coastal),
        "auckland": CityEmblem(cityID: "auckland", displayName: "Auckland", countryCode: "NZ", assetName: "City_auckland", archetype: .coastal),
        "athens": CityEmblem(cityID: "athens", displayName: "Athens", countryCode: "GR", assetName: "City_athens", archetype: .european),
        "istanbul": CityEmblem(cityID: "istanbul", displayName: "Istanbul", countryCode: "TR", assetName: "City_istanbul", archetype: .european),
        "osaka": CityEmblem(cityID: "osaka", displayName: "Osaka", countryCode: "JP", assetName: "City_osaka", archetype: .asian),
        "edinburgh": CityEmblem(cityID: "edinburgh", displayName: "Edinburgh", countryCode: "GB", assetName: "City_edinburgh", archetype: .european),
        "nice": CityEmblem(cityID: "nice", displayName: "Nice", countryCode: "FR", assetName: "City_nice", archetype: .coastal),
        "zurich": CityEmblem(cityID: "zurich", displayName: "Zurich", countryCode: "CH", assetName: "City_zurich", archetype: .alpine),
        "geneva": CityEmblem(cityID: "geneva", displayName: "Geneva", countryCode: "CH", assetName: "City_geneva", archetype: .coastal),
        "budapest": CityEmblem(cityID: "budapest", displayName: "Budapest", countryCode: "HU", assetName: "City_budapest", archetype: .european),
        "lisbon": CityEmblem(cityID: "lisbon", displayName: "Lisbon", countryCode: "PT", assetName: "City_lisbon", archetype: .coastal),
        "dublin": CityEmblem(cityID: "dublin", displayName: "Dublin", countryCode: "IE", assetName: "City_dublin", archetype: .european),
        "copenhagen": CityEmblem(cityID: "copenhagen", displayName: "Copenhagen", countryCode: "DK", assetName: "City_copenhagen", archetype: .coastal),
        "stockholm": CityEmblem(cityID: "stockholm", displayName: "Stockholm", countryCode: "SE", assetName: "City_stockholm", archetype: .coastal),
        "helsinki": CityEmblem(cityID: "helsinki", displayName: "Helsinki", countryCode: "FI", assetName: "City_helsinki", archetype: .coastal),
        "oslo": CityEmblem(cityID: "oslo", displayName: "Oslo", countryCode: "NO", assetName: "City_oslo", archetype: .coastal),
        "vancouver": CityEmblem(cityID: "vancouver", displayName: "Vancouver", countryCode: "CA", assetName: "City_vancouver", archetype: .coastal),
        "montreal": CityEmblem(cityID: "montreal", displayName: "Montreal", countryCode: "CA", assetName: "City_montreal", archetype: .european),
        "mexico city": CityEmblem(cityID: "mexico_city", displayName: "Mexico City", countryCode: "MX", assetName: "City_mexico_city", archetype: .metropolis),
        "cape town": CityEmblem(cityID: "cape_town", displayName: "Cape Town", countryCode: "ZA", assetName: "City_cape_town", archetype: .coastal),
        "minneapolis": CityEmblem(cityID: "minneapolis", displayName: "Minneapolis", countryCode: "US", assetName: "City_minneapolis", archetype: .metropolis),
        "detroit": CityEmblem(cityID: "detroit", displayName: "Detroit", countryCode: "US", assetName: "City_detroit", archetype: .metropolis),
        "pittsburgh": CityEmblem(cityID: "pittsburgh", displayName: "Pittsburgh", countryCode: "US", assetName: "City_pittsburgh", archetype: .metropolis),
        "tampa": CityEmblem(cityID: "tampa", displayName: "Tampa", countryCode: "US", assetName: "City_tampa", archetype: .coastal),
        "orlando": CityEmblem(cityID: "orlando", displayName: "Orlando", countryCode: "US", assetName: "City_orlando", archetype: .metropolis),
        "charlotte": CityEmblem(cityID: "charlotte", displayName: "Charlotte", countryCode: "US", assetName: "City_charlotte", archetype: .metropolis),
        "salt lake city": CityEmblem(cityID: "salt_lake_city", displayName: "Salt Lake City", countryCode: "US", assetName: "City_salt_lake_city", archetype: .alpine),
        "baltimore": CityEmblem(cityID: "baltimore", displayName: "Baltimore", countryCode: "US", assetName: "City_baltimore", archetype: .coastal),
        "kansas city": CityEmblem(cityID: "kansas_city", displayName: "Kansas City", countryCode: "US", assetName: "City_kansas_city", archetype: .metropolis),
        "cleveland": CityEmblem(cityID: "cleveland", displayName: "Cleveland", countryCode: "US", assetName: "City_cleveland", archetype: .coastal),
        "indianapolis": CityEmblem(cityID: "indianapolis", displayName: "Indianapolis", countryCode: "US", assetName: "City_indianapolis", archetype: .metropolis),
        "columbus": CityEmblem(cityID: "columbus", displayName: "Columbus", countryCode: "US", assetName: "City_columbus", archetype: .metropolis),
        "milwaukee": CityEmblem(cityID: "milwaukee", displayName: "Milwaukee", countryCode: "US", assetName: "City_milwaukee", archetype: .coastal),
        "cincinnati": CityEmblem(cityID: "cincinnati", displayName: "Cincinnati", countryCode: "US", assetName: "City_cincinnati", archetype: .metropolis),
        "san jose": CityEmblem(cityID: "san_jose", displayName: "San Jose", countryCode: "US", assetName: "City_san_jose", archetype: .metropolis),
        "raleigh": CityEmblem(cityID: "raleigh", displayName: "Raleigh", countryCode: "US", assetName: "City_raleigh", archetype: .metropolis),
        "louisville": CityEmblem(cityID: "louisville", displayName: "Louisville", countryCode: "US", assetName: "City_louisville", archetype: .metropolis),
        "memphis": CityEmblem(cityID: "memphis", displayName: "Memphis", countryCode: "US", assetName: "City_memphis", archetype: .metropolis),
        "oklahoma city": CityEmblem(cityID: "oklahoma_city", displayName: "Oklahoma City", countryCode: "US", assetName: "City_oklahoma_city", archetype: .metropolis),
        "albuquerque": CityEmblem(cityID: "albuquerque", displayName: "Albuquerque", countryCode: "US", assetName: "City_albuquerque", archetype: .desert),
        "tucson": CityEmblem(cityID: "tucson", displayName: "Tucson", countryCode: "US", assetName: "City_tucson", archetype: .desert),
        "el paso": CityEmblem(cityID: "el_paso", displayName: "El Paso", countryCode: "US", assetName: "City_el_paso", archetype: .desert),
        "san juan": CityEmblem(cityID: "san_juan", displayName: "San Juan", countryCode: "PR", assetName: "City_san_juan", archetype: .coastal),
        "anchorage": CityEmblem(cityID: "anchorage", displayName: "Anchorage", countryCode: "US", assetName: "City_anchorage", archetype: .alpine),
        "sacramento": CityEmblem(cityID: "sacramento", displayName: "Sacramento", countryCode: "US", assetName: "City_sacramento", archetype: .metropolis),
        "providence": CityEmblem(cityID: "providence", displayName: "Providence", countryCode: "US", assetName: "City_providence", archetype: .european),
        "doha": CityEmblem(cityID: "doha", displayName: "Doha", countryCode: "QA", assetName: "City_doha", archetype: .desert),
        "sao paulo": CityEmblem(cityID: "sao_paulo", displayName: "São Paulo", countryCode: "BR", assetName: "City_sao_paulo", archetype: .metropolis),
        "buenos aires": CityEmblem(cityID: "buenos_aires", displayName: "Buenos Aires", countryCode: "AR", assetName: "City_buenos_aires", archetype: .metropolis),
        "santiago": CityEmblem(cityID: "santiago", displayName: "Santiago", countryCode: "CL", assetName: "City_santiago", archetype: .metropolis),
        "lima": CityEmblem(cityID: "lima", displayName: "Lima", countryCode: "PE", assetName: "City_lima", archetype: .metropolis),

        // UK & Europe Hubs
        "oxford": CityEmblem(cityID: "oxford", displayName: "Oxford", countryCode: "GB", assetName: "City_oxford", archetype: .european),
        "cambridge": CityEmblem(cityID: "cambridge", displayName: "Cambridge", countryCode: "GB", assetName: "City_cambridge", archetype: .european),
        "manchester": CityEmblem(cityID: "manchester", displayName: "Manchester", countryCode: "GB", assetName: "City_manchester", archetype: .european),
        "birmingham": CityEmblem(cityID: "birmingham", displayName: "Birmingham", countryCode: "GB", assetName: "City_birmingham", archetype: .european),
        "bristol": CityEmblem(cityID: "bristol", displayName: "Bristol", countryCode: "GB", assetName: "City_bristol", archetype: .coastal),
        "glasgow": CityEmblem(cityID: "glasgow", displayName: "Glasgow", countryCode: "GB", assetName: "City_glasgow", archetype: .european),
        "liverpool": CityEmblem(cityID: "liverpool", displayName: "Liverpool", countryCode: "GB", assetName: "City_liverpool", archetype: .coastal),
        "frankfurt": CityEmblem(cityID: "frankfurt", displayName: "Frankfurt", countryCode: "DE", assetName: "City_frankfurt", archetype: .metropolis),
        "hamburg": CityEmblem(cityID: "hamburg", displayName: "Hamburg", countryCode: "DE", assetName: "City_hamburg", archetype: .coastal),
        "cologne": CityEmblem(cityID: "cologne", displayName: "Cologne", countryCode: "DE", assetName: "City_cologne", archetype: .european),
        "heidelberg": CityEmblem(cityID: "heidelberg", displayName: "Heidelberg", countryCode: "DE", assetName: "City_heidelberg", archetype: .european),
        "marseille": CityEmblem(cityID: "marseille", displayName: "Marseille", countryCode: "FR", assetName: "City_marseille", archetype: .coastal),
        "lyon": CityEmblem(cityID: "lyon", displayName: "Lyon", countryCode: "FR", assetName: "City_lyon", archetype: .european),
        "bordeaux": CityEmblem(cityID: "bordeaux", displayName: "Bordeaux", countryCode: "FR", assetName: "City_bordeaux", archetype: .european),
        "valencia": CityEmblem(cityID: "valencia", displayName: "Valencia", countryCode: "ES", assetName: "City_valencia", archetype: .coastal),
        "seville": CityEmblem(cityID: "seville", displayName: "Seville", countryCode: "ES", assetName: "City_seville", archetype: .european),
        "porto": CityEmblem(cityID: "porto", displayName: "Porto", countryCode: "PT", assetName: "City_porto", archetype: .coastal),
        "brussels": CityEmblem(cityID: "brussels", displayName: "Brussels", countryCode: "BE", assetName: "City_brussels", archetype: .european),
        "antwerp": CityEmblem(cityID: "antwerp", displayName: "Antwerp", countryCode: "BE", assetName: "City_antwerp", archetype: .coastal),
        "bruges": CityEmblem(cityID: "bruges", displayName: "Bruges", countryCode: "BE", assetName: "City_bruges", archetype: .european),
        "rotterdam": CityEmblem(cityID: "rotterdam", displayName: "Rotterdam", countryCode: "NL", assetName: "City_rotterdam", archetype: .coastal),
        "utrecht": CityEmblem(cityID: "utrecht", displayName: "Utrecht", countryCode: "NL", assetName: "City_utrecht", archetype: .european),
        "basel": CityEmblem(cityID: "basel", displayName: "Basel", countryCode: "CH", assetName: "City_basel", archetype: .alpine),
        "lucerne": CityEmblem(cityID: "lucerne", displayName: "Lucerne", countryCode: "CH", assetName: "City_lucerne", archetype: .alpine),
        "warsaw": CityEmblem(cityID: "warsaw", displayName: "Warsaw", countryCode: "PL", assetName: "City_warsaw", archetype: .european),
        "krakow": CityEmblem(cityID: "krakow", displayName: "Krakow", countryCode: "PL", assetName: "City_krakow", archetype: .european),
        "dubrovnik": CityEmblem(cityID: "dubrovnik", displayName: "Dubrovnik", countryCode: "HR", assetName: "City_dubrovnik", archetype: .coastal),
        "split": CityEmblem(cityID: "split", displayName: "Split", countryCode: "HR", assetName: "City_split", archetype: .coastal),
        "santorini": CityEmblem(cityID: "santorini", displayName: "Santorini", countryCode: "GR", assetName: "City_santorini", archetype: .coastal),
        "reykjavik": CityEmblem(cityID: "reykjavik", displayName: "Reykjavik", countryCode: "IS", assetName: "City_reykjavik", archetype: .alpine),

        // North America University & Tech Hubs
        "berkeley": CityEmblem(cityID: "berkeley", displayName: "Berkeley", countryCode: "US", assetName: "City_berkeley", archetype: .coastal),
        "palo alto": CityEmblem(cityID: "palo_alto", displayName: "Palo Alto", countryCode: "US", assetName: "City_palo_alto", archetype: .metropolis),
        "mountain view": CityEmblem(cityID: "mountain_view", displayName: "Mountain View", countryCode: "US", assetName: "City_mountain_view", archetype: .metropolis),
        "cupertino": CityEmblem(cityID: "cupertino", displayName: "Cupertino", countryCode: "US", assetName: "City_cupertino", archetype: .metropolis),
        "sunnyvale": CityEmblem(cityID: "sunnyvale", displayName: "Sunnyvale", countryCode: "US", assetName: "City_sunnyvale", archetype: .metropolis),
        "santa barbara": CityEmblem(cityID: "santa_barbara", displayName: "Santa Barbara", countryCode: "US", assetName: "City_santa_barbara", archetype: .coastal),
        "irvine": CityEmblem(cityID: "irvine", displayName: "Irvine", countryCode: "US", assetName: "City_irvine", archetype: .coastal),
        "boulder": CityEmblem(cityID: "boulder", displayName: "Boulder", countryCode: "US", assetName: "City_boulder", archetype: .alpine),
        "ann arbor": CityEmblem(cityID: "ann_arbor", displayName: "Ann Arbor", countryCode: "US", assetName: "City_ann_arbor", archetype: .metropolis),
        "madison": CityEmblem(cityID: "madison", displayName: "Madison", countryCode: "US", assetName: "City_madison", archetype: .coastal),
        "durham": CityEmblem(cityID: "durham", displayName: "Durham", countryCode: "US", assetName: "City_durham", archetype: .metropolis),
        "chapel hill": CityEmblem(cityID: "chapel_hill", displayName: "Chapel Hill", countryCode: "US", assetName: "City_chapel_hill", archetype: .metropolis),
        "charlottesville": CityEmblem(cityID: "charlottesville", displayName: "Charlottesville", countryCode: "US", assetName: "City_charlottesville", archetype: .european),
        "ithaca": CityEmblem(cityID: "ithaca", displayName: "Ithaca", countryCode: "US", assetName: "City_ithaca", archetype: .alpine),
        "new haven": CityEmblem(cityID: "new_haven", displayName: "New Haven", countryCode: "US", assetName: "City_new_haven", archetype: .european),
        "princeton": CityEmblem(cityID: "princeton", displayName: "Princeton", countryCode: "US", assetName: "City_princeton", archetype: .european),
        "savannah": CityEmblem(cityID: "savannah", displayName: "Savannah", countryCode: "US", assetName: "City_savannah", archetype: .coastal),
        "charleston": CityEmblem(cityID: "charleston", displayName: "Charleston", countryCode: "US", assetName: "City_charleston", archetype: .coastal),
        "asheville": CityEmblem(cityID: "asheville", displayName: "Asheville", countryCode: "US", assetName: "City_asheville", archetype: .alpine),
        "boise": CityEmblem(cityID: "boise", displayName: "Boise", countryCode: "US", assetName: "City_boise", archetype: .alpine),
        "calgary": CityEmblem(cityID: "calgary", displayName: "Calgary", countryCode: "CA", assetName: "City_calgary", archetype: .alpine),
        "ottawa": CityEmblem(cityID: "ottawa", displayName: "Ottawa", countryCode: "CA", assetName: "City_ottawa", archetype: .european),
        "edmonton": CityEmblem(cityID: "edmonton", displayName: "Edmonton", countryCode: "CA", assetName: "City_edmonton", archetype: .alpine),
        "quebec city": CityEmblem(cityID: "quebec_city", displayName: "Quebec City", countryCode: "CA", assetName: "City_quebec_city", archetype: .european),
        "victoria": CityEmblem(cityID: "victoria", displayName: "Victoria", countryCode: "CA", assetName: "City_victoria", archetype: .coastal),
        "halifax": CityEmblem(cityID: "halifax", displayName: "Halifax", countryCode: "CA", assetName: "City_halifax", archetype: .coastal),
        "waterloo": CityEmblem(cityID: "waterloo", displayName: "Waterloo", countryCode: "CA", assetName: "City_waterloo", archetype: .metropolis),
        "cancun": CityEmblem(cityID: "cancun", displayName: "Cancún", countryCode: "MX", assetName: "City_cancun", archetype: .coastal),
        "guadalajara": CityEmblem(cityID: "guadalajara", displayName: "Guadalajara", countryCode: "MX", assetName: "City_guadalajara", archetype: .metropolis),
        "monterrey": CityEmblem(cityID: "monterrey", displayName: "Monterrey", countryCode: "MX", assetName: "City_monterrey", archetype: .desert),

        // Asia-Pacific & Middle East Hubs
        "fukuoka": CityEmblem(cityID: "fukuoka", displayName: "Fukuoka", countryCode: "JP", assetName: "City_fukuoka", archetype: .coastal),
        "sapporo": CityEmblem(cityID: "sapporo", displayName: "Sapporo", countryCode: "JP", assetName: "City_sapporo", archetype: .alpine),
        "kobe": CityEmblem(cityID: "kobe", displayName: "Kobe", countryCode: "JP", assetName: "City_kobe", archetype: .coastal),
        "yokohama": CityEmblem(cityID: "yokohama", displayName: "Yokohama", countryCode: "JP", assetName: "City_yokohama", archetype: .coastal),
        "okinawa": CityEmblem(cityID: "okinawa", displayName: "Okinawa", countryCode: "JP", assetName: "City_okinawa", archetype: .coastal),
        "busan": CityEmblem(cityID: "busan", displayName: "Busan", countryCode: "KR", assetName: "City_busan", archetype: .coastal),
        "incheon": CityEmblem(cityID: "incheon", displayName: "Incheon", countryCode: "KR", assetName: "City_incheon", archetype: .coastal),
        "jeju": CityEmblem(cityID: "jeju", displayName: "Jeju", countryCode: "KR", assetName: "City_jeju", archetype: .coastal),
        "kaohsiung": CityEmblem(cityID: "kaohsiung", displayName: "Kaohsiung", countryCode: "TW", assetName: "City_kaohsiung", archetype: .coastal),
        "tainan": CityEmblem(cityID: "tainan", displayName: "Tainan", countryCode: "TW", assetName: "City_tainan", archetype: .asian),
        "taichung": CityEmblem(cityID: "taichung", displayName: "Taichung", countryCode: "TW", assetName: "City_taichung", archetype: .metropolis),
        "hsinchu": CityEmblem(cityID: "hsinchu", displayName: "Hsinchu", countryCode: "TW", assetName: "City_hsinchu", archetype: .metropolis),
        "shenzhen": CityEmblem(cityID: "shenzhen", displayName: "Shenzhen", countryCode: "CN", assetName: "City_shenzhen", archetype: .metropolis),
        "guangzhou": CityEmblem(cityID: "guangzhou", displayName: "Guangzhou", countryCode: "CN", assetName: "City_guangzhou", archetype: .metropolis),
        "hangzhou": CityEmblem(cityID: "hangzhou", displayName: "Hangzhou", countryCode: "CN", assetName: "City_hangzhou", archetype: .asian),
        "chengdu": CityEmblem(cityID: "chengdu", displayName: "Chengdu", countryCode: "CN", assetName: "City_chengdu", archetype: .asian),
        "wuhan": CityEmblem(cityID: "wuhan", displayName: "Wuhan", countryCode: "CN", assetName: "City_wuhan", archetype: .metropolis),
        "nanjing": CityEmblem(cityID: "nanjing", displayName: "Nanjing", countryCode: "CN", assetName: "City_nanjing", archetype: .asian),
        "xi'an": CityEmblem(cityID: "xi_an", displayName: "Xi'an", countryCode: "CN", assetName: "City_xi_an", archetype: .asian),
        "suzhou": CityEmblem(cityID: "suzhou", displayName: "Suzhou", countryCode: "CN", assetName: "City_suzhou", archetype: .asian),
        "chongqing": CityEmblem(cityID: "chongqing", displayName: "Chongqing", countryCode: "CN", assetName: "City_chongqing", archetype: .metropolis),
        "xiamen": CityEmblem(cityID: "xiamen", displayName: "Xiamen", countryCode: "CN", assetName: "City_xiamen", archetype: .coastal),
        "macau": CityEmblem(cityID: "macau", displayName: "Macau", countryCode: "MO", assetName: "City_macau", archetype: .metropolis),
        "kuala lumpur": CityEmblem(cityID: "kuala_lumpur", displayName: "Kuala Lumpur", countryCode: "MY", assetName: "City_kuala_lumpur", archetype: .metropolis),
        "penang": CityEmblem(cityID: "penang", displayName: "Penang", countryCode: "MY", assetName: "City_penang", archetype: .coastal),
        "bali": CityEmblem(cityID: "bali", displayName: "Bali", countryCode: "ID", assetName: "City_bali", archetype: .coastal),
        "jakarta": CityEmblem(cityID: "jakarta", displayName: "Jakarta", countryCode: "ID", assetName: "City_jakarta", archetype: .metropolis),
        "phuket": CityEmblem(cityID: "phuket", displayName: "Phuket", countryCode: "TH", assetName: "City_phuket", archetype: .coastal),
        "chiang mai": CityEmblem(cityID: "chiang_mai", displayName: "Chiang Mai", countryCode: "TH", assetName: "City_chiang_mai", archetype: .asian),
        "manila": CityEmblem(cityID: "manila", displayName: "Manila", countryCode: "PH", assetName: "City_manila", archetype: .coastal),

        // Australia, NZ, Latin America & Middle East
        "brisbane": CityEmblem(cityID: "brisbane", displayName: "Brisbane", countryCode: "AU", assetName: "City_brisbane", archetype: .coastal),
        "perth": CityEmblem(cityID: "perth", displayName: "Perth", countryCode: "AU", assetName: "City_perth", archetype: .coastal),
        "adelaide": CityEmblem(cityID: "adelaide", displayName: "Adelaide", countryCode: "AU", assetName: "City_adelaide", archetype: .coastal),
        "gold coast": CityEmblem(cityID: "gold_coast", displayName: "Gold Coast", countryCode: "AU", assetName: "City_gold_coast", archetype: .coastal),
        "wellington": CityEmblem(cityID: "wellington", displayName: "Wellington", countryCode: "NZ", assetName: "City_wellington", archetype: .coastal),
        "christchurch": CityEmblem(cityID: "christchurch", displayName: "Christchurch", countryCode: "NZ", assetName: "City_christchurch", archetype: .coastal),
        "queenstown": CityEmblem(cityID: "queenstown", displayName: "Queenstown", countryCode: "NZ", assetName: "City_queenstown", archetype: .alpine),
        "abu dhabi": CityEmblem(cityID: "abu_dhabi", displayName: "Abu Dhabi", countryCode: "AE", assetName: "City_abu_dhabi", archetype: .desert),
        "riyadh": CityEmblem(cityID: "riyadh", displayName: "Riyadh", countryCode: "SA", assetName: "City_riyadh", archetype: .desert),
        "tel aviv": CityEmblem(cityID: "tel_aviv", displayName: "Tel Aviv", countryCode: "IL", assetName: "City_tel_aviv", archetype: .coastal),
        "bogota": CityEmblem(cityID: "bogota", displayName: "Bogotá", countryCode: "CO", assetName: "City_bogota", archetype: .metropolis),
        "medellin": CityEmblem(cityID: "medellin", displayName: "Medellín", countryCode: "CO", assetName: "City_medellin", archetype: .metropolis),
        "cusco": CityEmblem(cityID: "cusco", displayName: "Cusco", countryCode: "PE", assetName: "City_cusco", archetype: .alpine),
        "san jose cr": CityEmblem(cityID: "san_jose_cr", displayName: "San José", countryCode: "CR", archetype: .coastal),
        "panama city": CityEmblem(cityID: "panama_city", displayName: "Panama City", countryCode: "PA", archetype: .coastal)
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
        "silicon valley": registeredCities["san jose"]!,
        "são paulo": registeredCities["sao paulo"]!,
        "sp": registeredCities["sao paulo"]!,
        "ba": registeredCities["buenos aires"]!,
        "shibuya": registeredCities["tokyo"]!,
        "shinjuku": registeredCities["tokyo"]!,
        "ginza": registeredCities["tokyo"]!,
        "dotonbori": registeredCities["osaka"]!,
        "cannes": registeredCities["nice"]!,
        "french riviera": registeredCities["nice"]!,
        "lisboa": registeredCities["lisbon"]!,
        "kobenhavn": registeredCities["copenhagen"]!,
        "cdmx": registeredCities["mexico city"]!,
        "mexico": registeredCities["mexico city"]!,
        "montréal": registeredCities["montreal"]!,
        "twin cities": registeredCities["minneapolis"]!,
        "st paul": registeredCities["minneapolis"]!,
        "st. paul": registeredCities["minneapolis"]!,
        "motor city": registeredCities["detroit"]!,
        "tampa bay": registeredCities["tampa"]!,
        "st petersburg": registeredCities["tampa"]!,
        "clearwater": registeredCities["tampa"]!,
        "slc": registeredCities["salt lake city"]!,
        "kc": registeredCities["kansas city"]!,
        "indy": registeredCities["indianapolis"]!,
        "okc": registeredCities["oklahoma city"]!,
        "abq": registeredCities["albuquerque"]!,
        "puerto rico": registeredCities["san juan"]!,
        "westminster": registeredCities["london"]!,
        "soho": registeredCities["london"]!,
        "peking": registeredCities["beijing"]!,
        "nola": registeredCities["new orleans"]!,
        "philly": registeredCities["philadelphia"]!,
        "saint louis": registeredCities["st louis"]!,
        "st. louis": registeredCities["st louis"]!,
        "washington dc": registeredCities["washington"]!,
        "dc": registeredCities["washington"]!,
        "kl": registeredCities["kuala lumpur"]!,
        "xian": registeredCities["xi'an"]!,
        "denpasar": registeredCities["bali"]!,
        "ubud": registeredCities["bali"]!,
        "macao": registeredCities["macau"]!,
        "quebec": registeredCities["quebec city"]!,
        "bogotá": registeredCities["bogota"]!,
        "medellín": registeredCities["medellin"]!,
        "cancún": registeredCities["cancun"]!,
        "ox": registeredCities["oxford"]!,
        "cam": registeredCities["cambridge"]!,
        "mcr": registeredCities["manchester"]!
    ]
}

/// Regional architectural, ecological, and landscape archetypes for personalized fallback dioramas.
public enum CityArchetype: String, CaseIterable, Sendable {
    // 6 Tailored Micro-Archetypes
    case centralValley = "central_valley"
    case siliconValley = "silicon_valley"
    case pacificSurf = "pacific_surf"
    case alpineChalet = "alpine_chalet"
    case desertAdobe = "desert_adobe"
    case historicBrick = "historic_brick"

    // Preserved archetypes for catalog and generic fallbacks
    case european
    case metropolis
    case coastal
    case alpine
    case asian
    case desert

    public var title: String {
        switch self {
        case .centralValley: return "Central Valley & Golden Plains"
        case .siliconValley: return "Silicon Valley & Modern Suburb"
        case .pacificSurf, .coastal: return "Pacific Surf Coast"
        case .alpineChalet, .alpine: return "Alpine Chalet & Mountain Pass"
        case .desertAdobe, .desert: return "Southwest Adobe & Desert"
        case .historicBrick, .european: return "Historic Brick & Stone Town"
        case .metropolis: return "Modern Metropolis"
        case .asian: return "East Asian Town"
        }
    }

    public var assetName: String? {
        switch self {
        case .centralValley: return "City_archetype_central_valley"
        case .siliconValley: return "City_archetype_silicon_valley"
        case .pacificSurf, .coastal: return "City_archetype_pacific_surf"
        case .alpineChalet, .alpine: return "City_archetype_alpine_chalet"
        case .desertAdobe, .desert: return "City_archetype_desert_adobe"
        case .historicBrick, .european: return "City_archetype_historic_brick"
        case .metropolis, .asian: return "City_generic_block"
        }
    }

    public var iconSymbol: String {
        switch self {
        case .centralValley: return "sun.haze.fill"
        case .siliconValley: return "house.lodge.fill"
        case .pacificSurf, .coastal: return "water.waves"
        case .alpineChalet, .alpine: return "mountain.2.fill"
        case .desertAdobe, .desert: return "sun.max.fill"
        case .historicBrick, .european: return "building.columns.fill"
        case .metropolis: return "building.2.fill"
        case .asian: return "house.lodge.fill"
        }
    }

    public var themeColor: Color {
        switch self {
        case .centralValley: return Color(red: 0.88, green: 0.65, blue: 0.22)
        case .siliconValley: return Color(red: 0.28, green: 0.62, blue: 0.45)
        case .pacificSurf, .coastal: return Color(red: 0.18, green: 0.72, blue: 0.80)
        case .alpineChalet, .alpine: return Color(red: 0.42, green: 0.68, blue: 0.82)
        case .desertAdobe, .desert: return Color(red: 0.86, green: 0.45, blue: 0.28)
        case .historicBrick, .european: return Color(red: 0.75, green: 0.52, blue: 0.38)
        case .metropolis: return Color(red: 0.35, green: 0.52, blue: 0.72)
        case .asian: return Color(red: 0.82, green: 0.35, blue: 0.30)
        }
    }

    /// 4-Tier Cascade Mapping: Curated Sub-Regions -> State/Country Heuristics -> Semantic Keywords -> Defaults
    public static func infer(
        from city: String,
        countryCode: String?,
        administrativeArea: String? = nil
    ) -> CityArchetype {
        let normCity = CityIdentity.normalize(city)
        let normCountry = countryCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let normArea = administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""

        // Tier 1: Explicit Curated Sub-Regional Dictionary
        if normCountry == "US" || normCountry.isEmpty {
            let isCA = normArea == "CA" || normArea == "CALIFORNIA"

            // Central Valley (CA)
            let centralValleyCities: Set<String> = [
                "bakersfield", "fresno", "modesto", "stockton", "visalia", "merced", "clovis",
                "turlock", "chico", "redding", "tulare", "hanford", "delano", "porterville",
                "madera", "lodi", "tracy", "manteca"
            ]
            if (isCA || normArea.isEmpty) && centralValleyCities.contains(normCity) {
                return .centralValley
            }

            // Silicon Valley & Bay Area Suburbs (CA) & Seattle tech hubs (WA)
            let siliconValleyCities: Set<String> = [
                "fremont", "palo alto", "sunnyvale", "cupertino", "mountain view", "santa clara",
                "san mateo", "redwood city", "menlo park", "los altos", "milpitas", "foster city",
                "san carlos", "burlingame", "belmont", "pleasanton", "dublin", "san ramon",
                "walnut creek", "bellevue", "redmond", "kirkland"
            ]
            if (isCA || normArea == "WA" || normArea.isEmpty) && siliconValleyCities.contains(normCity) {
                return .siliconValley
            }

            // Pacific Surf Coast
            let surfCities: Set<String> = [
                "santa cruz", "malibu", "laguna beach", "encinitas", "huntington beach",
                "newport beach", "carlsbad", "oceanside", "san clemente", "half moon bay",
                "monterey", "carmel", "pacific grove", "santa barbara", "ventura", "carpinteria",
                "morro bay", "pismo beach", "capitola"
            ]
            if (isCA || normArea == "HI" || normArea.isEmpty) && surfCities.contains(normCity) {
                return .pacificSurf
            }

            // Alpine Mountain Towns
            let alpineCities: Set<String> = [
                "lake tahoe", "south lake tahoe", "truckee", "mammoth lakes", "aspen", "vail",
                "breckenridge", "boulder", "park city", "jackson", "steamboat springs",
                "telluride", "big bear lake"
            ]
            if alpineCities.contains(normCity) {
                return .alpineChalet
            }

            // Desert & Adobe
            let desertCities: Set<String> = [
                "palm springs", "sedona", "scottsdale", "santa fe", "moab", "taos", "tucson",
                "mesa", "tempe", "chandler", "joshua tree", "indio", "cathedral city",
                "desert hot springs", "palm desert", "la quinta", "albuquerque", "yuma"
            ]
            if desertCities.contains(normCity) {
                return .desertAdobe
            }
        }

        // International Tier 1 Matches
        let internationalSurf: Set<String> = ["byron bay", "gold coast", "biarritz", "noosa", "torquay"]
        if internationalSurf.contains(normCity) { return .pacificSurf }

        let internationalAlpine: Set<String> = [
            "zermatt", "chamonix", "innsbruck", "st. moritz", "grindelwald", "interlaken",
            "whistler", "banff", "cortina d'ampezzo", "nagano", "hakuba", "niseko"
        ]
        if internationalAlpine.contains(normCity) { return .alpineChalet }

        let internationalHistoric: Set<String> = [
            "oxford", "cambridge", "bath", "york", "cotswolds", "heidelberg", "bruges",
            "ghent", "salzburg", "toledo", "siena", "edinburgh", "durham", "canterbury",
            "stratford-upon-avon", "chester", "rothenburg", "bamberg", "weimar"
        ]
        if internationalHistoric.contains(normCity) { return .historicBrick }

        // Tier 2: State / Regional Heuristics
        if normCountry == "US" {
            if ["AZ", "NM", "NV"].contains(normArea) { return .desertAdobe }
            if ["CO", "UT", "WY", "MT", "ID", "VT"].contains(normArea) { return .alpineChalet }
            if ["WA", "OR"].contains(normArea) { return .siliconValley }
            if ["HI", "FL"].contains(normArea) { return .pacificSurf }
            if ["IA", "KS", "NE", "OK", "ND", "SD"].contains(normArea) { return .centralValley }
            if ["ME", "NH", "MA", "RI", "CT"].contains(normArea) { return .historicBrick }
        }

        // Tier 3: Semantic Keyword Sniffing
        if normCity.contains("beach") || normCity.contains("coast") || normCity.contains("surf") ||
           normCity.contains("shore") || normCity.contains("island") || normCity.contains("cove") ||
           normCity.contains("bay") || normCity.contains("key") {
            return .pacificSurf
        }
        if normCity.contains("mountain") || normCity.contains("mount ") || normCity.contains("peak") ||
           normCity.contains("alpine") || normCity.contains("summit") || normCity.contains("ridge") ||
           normCity.contains("ski") {
            return .alpineChalet
        }
        if normCity.contains("desert") || normCity.contains("adobe") || normCity.contains("dune") ||
           normCity.contains("canyon") || normCity.contains("mesa") {
            return .desertAdobe
        }
        if normCity.contains("valley") || normCity.contains("prairie") || normCity.contains("plains") ||
           normCity.contains("ranch") || normCity.contains("farm") || normCity.contains("field") {
            return .centralValley
        }
        if normCity.contains("village") || normCity.contains("burg") || normCity.contains("bad ") ||
           normCity.contains("castle") || normCity.contains("abbey") || normCity.contains("chester") {
            return .historicBrick
        }

        // Tier 4: International Country Heuristics
        if ["CH", "AT"].contains(normCountry) { return .alpineChalet }
        if ["NO", "SE", "FI", "IS"].contains(normCountry) { return .alpineChalet }
        if ["GB", "IE"].contains(normCountry) { return .historicBrick }
        if ["AE", "EG", "SA", "QA", "MA"].contains(normCountry) { return .desertAdobe }
        if ["JP", "CN", "KR", "TW", "HK", "TH", "VN", "SG"].contains(normCountry) { return .asian }
        if ["FR", "IT", "DE", "ES", "NL", "PT", "GR", "CZ", "BE"].contains(normCountry) { return .european }

        // Tier 5: Global Default
        return .metropolis
    }
}

/// A SwiftUI view that displays a high-fidelity 3D miniature city emblem or procedural fallback.
public struct CityEmblemView: View {
    public let emblem: CityEmblem
    public var size: CGFloat

    public init(city: String?, countryCode: String? = nil, administrativeArea: String? = nil, size: CGFloat = 84) {
        self.emblem = CityEmblem.resolve(city: city, countryCode: countryCode, administrativeArea: administrativeArea)
        self.size = size
    }

    public init(emblem: CityEmblem, size: CGFloat = 84) {
        self.emblem = emblem
        self.size = size
    }

    init(friend: FriendPresence, size: CGFloat = 84) {
        self.emblem = CityEmblem.resolve(friend: friend)
        self.size = size
    }

    private var loadedImage: UIImage? {
        if let assetName = emblem.assetName {
            if let direct = UIImage(named: assetName) { return direct }
            if let namespaced = UIImage(named: "CityEmblems/\(assetName)") { return namespaced }
        }

        if let direct = UIImage(named: emblem.fallbackAssetName) { return direct }
        if let namespaced = UIImage(named: "CityEmblems/\(emblem.fallbackAssetName)") { return namespaced }

        return nil
    }

    public var body: some View {
        ZStack {
            if let uiImage = loadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
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
            Circle()
                .fill(Color(uiColor: .tertiarySystemFill))
            Image(systemName: emblem.cityID == "unknown" ? "globe.americas.fill" : "building.2.fill")
                .font(.system(size: size * 0.40, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
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
