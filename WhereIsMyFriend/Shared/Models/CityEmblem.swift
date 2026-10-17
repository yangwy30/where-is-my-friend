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

        let country = countryCode?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let areaKey = CityIdentity.presencePart(administrativeArea ?? "")
        let normArea = (CityRegionCatalog.bundled.administrativeAliases?[country ?? "US"]?[areaKey] ?? areaKey).uppercased()
        func accepts(_ match: CityEmblem) -> Bool {
            guard country == nil || country == "" || country == match.countryCode else { return false }
            if match.countryCode == "US", !normArea.isEmpty,
               let allowedStates = registeredUSStates[match.cityID],
               !allowedStates.contains(normArea) {
                return false
            }
            return true
        }
        if let match = registeredCities[normalized], accepts(match) {
            return match
        }

        // Check aliases
        for (alias, match) in cityAliases where normalized == CityIdentity.normalize(alias) && accepts(match) {
            return match
        }

        // Check state-scoped metro satellite cities (reuses parent metro 3D emblem while preserving satellite city displayName & cityID)
        if (country == nil || country == "" || country == "US"), !normArea.isEmpty,
           let stateMap = metroSatelliteParents[normalized],
           let parentKey = stateMap[normArea],
           let parentEmblem = registeredCities[parentKey] {
            return CityEmblem(
                cityID: normalized.replacingOccurrences(of: " ", with: "_"),
                displayName: city,
                countryCode: countryCode ?? "US",
                assetName: parentEmblem.assetName,
                archetype: parentEmblem.archetype
            )
        }

        // Check country-scoped international metro satellite cities (reuses parent metro 3D emblem while preserving satellite city displayName & cityID)
        if let country, !country.isEmpty, country != "US",
           let countryMap = internationalMetroSatellites[normalized],
           let parentKey = countryMap[country],
           let parentEmblem = registeredCities[parentKey] {
            return CityEmblem(
                cityID: normalized.replacingOccurrences(of: " ", with: "_"),
                displayName: city,
                countryCode: country,
                assetName: parentEmblem.assetName,
                archetype: parentEmblem.archetype
            )
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
        "fort worth": CityEmblem(cityID: "fort_worth", displayName: "Fort Worth", countryCode: "US", assetName: "City_fort_worth", archetype: .metropolis),
        "jacksonville": CityEmblem(cityID: "jacksonville", displayName: "Jacksonville", countryCode: "US", assetName: "City_jacksonville", archetype: .coastal),
        "fresno": CityEmblem(cityID: "fresno", displayName: "Fresno", countryCode: "US", assetName: "City_fresno", archetype: .centralValley),
        "colorado springs": CityEmblem(cityID: "colorado_springs", displayName: "Colorado Springs", countryCode: "US", assetName: "City_colorado_springs", archetype: .alpine),
        "omaha": CityEmblem(cityID: "omaha", displayName: "Omaha", countryCode: "US", assetName: "City_omaha", archetype: .metropolis),
        "virginia beach": CityEmblem(cityID: "virginia_beach", displayName: "Virginia Beach", countryCode: "US", assetName: "City_virginia_beach", archetype: .coastal),
        "long beach": CityEmblem(cityID: "long_beach", displayName: "Long Beach", countryCode: "US", assetName: "City_long_beach", archetype: .coastal),
        "oakland": CityEmblem(cityID: "oakland", displayName: "Oakland", countryCode: "US", assetName: "City_oakland", archetype: .coastal),
        "bakersfield": CityEmblem(cityID: "bakersfield", displayName: "Bakersfield", countryCode: "US", assetName: "City_bakersfield", archetype: .centralValley),
        "tulsa": CityEmblem(cityID: "tulsa", displayName: "Tulsa", countryCode: "US", assetName: "City_tulsa", archetype: .metropolis),
        "wichita": CityEmblem(cityID: "wichita", displayName: "Wichita", countryCode: "US", assetName: "City_wichita", archetype: .metropolis),
        "lexington": CityEmblem(cityID: "lexington", displayName: "Lexington", countryCode: "US", assetName: "City_lexington", archetype: .metropolis),
        "stockton": CityEmblem(cityID: "stockton", displayName: "Stockton", countryCode: "US", assetName: "City_stockton", archetype: .centralValley),
        "newark": CityEmblem(cityID: "newark", displayName: "Newark", countryCode: "US", assetName: "City_newark", archetype: .metropolis),
        "corpus christi": CityEmblem(cityID: "corpus_christi", displayName: "Corpus Christi", countryCode: "US", assetName: "City_corpus_christi", archetype: .coastal),
        "greensboro": CityEmblem(cityID: "greensboro", displayName: "Greensboro", countryCode: "US", assetName: "City_greensboro", archetype: .metropolis),
        "jersey city": CityEmblem(cityID: "jersey_city", displayName: "Jersey City", countryCode: "US", assetName: "City_jersey_city", archetype: .metropolis),
        "lincoln": CityEmblem(cityID: "lincoln", displayName: "Lincoln", countryCode: "US", assetName: "City_lincoln", archetype: .metropolis),
        "reno": CityEmblem(cityID: "reno", displayName: "Reno", countryCode: "US", assetName: "City_reno", archetype: .alpine),
        "buffalo": CityEmblem(cityID: "buffalo", displayName: "Buffalo", countryCode: "US", assetName: "City_buffalo", archetype: .metropolis),
        "fort wayne": CityEmblem(cityID: "fort_wayne", displayName: "Fort Wayne", countryCode: "US", assetName: "City_fort_wayne", archetype: .metropolis),
        "lubbock": CityEmblem(cityID: "lubbock", displayName: "Lubbock", countryCode: "US", assetName: "City_lubbock", archetype: .desert),
        "laredo": CityEmblem(cityID: "laredo", displayName: "Laredo", countryCode: "US", assetName: "City_laredo", archetype: .desert),
        "toledo": CityEmblem(cityID: "toledo", displayName: "Toledo", countryCode: "US", assetName: "City_toledo", archetype: .coastal),
        "richmond": CityEmblem(cityID: "richmond", displayName: "Richmond", countryCode: "US", assetName: "City_richmond", archetype: .historicBrick),
        "huntsville": CityEmblem(cityID: "huntsville", displayName: "Huntsville", countryCode: "US", assetName: "City_huntsville", archetype: .metropolis),
        "spokane": CityEmblem(cityID: "spokane", displayName: "Spokane", countryCode: "US", assetName: "City_spokane", archetype: .alpine),
        "baton rouge": CityEmblem(cityID: "baton_rouge", displayName: "Baton Rouge", countryCode: "US", assetName: "City_baton_rouge", archetype: .metropolis),
        "sioux falls": CityEmblem(cityID: "sioux_falls", displayName: "Sioux Falls", countryCode: "US", assetName: "City_sioux_falls", archetype: .centralValley),
        "des moines": CityEmblem(cityID: "des_moines", displayName: "Des Moines", countryCode: "US", assetName: "City_des_moines", archetype: .metropolis),
        "fayetteville": CityEmblem(cityID: "fayetteville", displayName: "Fayetteville", countryCode: "US", assetName: "City_fayetteville", archetype: .historicBrick),
        "little rock": CityEmblem(cityID: "little_rock", displayName: "Little Rock", countryCode: "US", assetName: "City_little_rock", archetype: .metropolis),
        "rochester": CityEmblem(cityID: "rochester", displayName: "Rochester", countryCode: "US", assetName: "City_rochester", archetype: .metropolis),
        "amarillo": CityEmblem(cityID: "amarillo", displayName: "Amarillo", countryCode: "US", assetName: "City_amarillo", archetype: .desert),
        "tallahassee": CityEmblem(cityID: "tallahassee", displayName: "Tallahassee", countryCode: "US", assetName: "City_tallahassee", archetype: .coastal),
        "knoxville": CityEmblem(cityID: "knoxville", displayName: "Knoxville", countryCode: "US", assetName: "City_knoxville", archetype: .alpine),
        "augusta": CityEmblem(cityID: "augusta", displayName: "Augusta", countryCode: "US", assetName: "City_augusta", archetype: .historicBrick),
        "grand rapids": CityEmblem(cityID: "grand_rapids", displayName: "Grand Rapids", countryCode: "US", assetName: "City_grand_rapids", archetype: .metropolis),
        "mobile": CityEmblem(cityID: "mobile", displayName: "Mobile", countryCode: "US", assetName: "City_mobile", archetype: .coastal),
        "birmingham al": CityEmblem(cityID: "birmingham", displayName: "Birmingham", countryCode: "US", assetName: "City_birmingham_al", archetype: .metropolis),
        "montgomery": CityEmblem(cityID: "montgomery", displayName: "Montgomery", countryCode: "US", assetName: "City_montgomery", archetype: .historicBrick),
        "chattanooga": CityEmblem(cityID: "chattanooga", displayName: "Chattanooga", countryCode: "US", assetName: "City_chattanooga", archetype: .alpine),
        "akron": CityEmblem(cityID: "akron", displayName: "Akron", countryCode: "US", assetName: "City_akron", archetype: .metropolis),
        "shreveport": CityEmblem(cityID: "shreveport", displayName: "Shreveport", countryCode: "US", assetName: "City_shreveport", archetype: .coastal),
        "eugene": CityEmblem(cityID: "eugene", displayName: "Eugene", countryCode: "US", assetName: "City_eugene", archetype: .alpine),
        "salem": CityEmblem(cityID: "salem", displayName: "Salem", countryCode: "US", assetName: "City_salem", archetype: .metropolis),
        "springfield": CityEmblem(cityID: "springfield", displayName: "Springfield", countryCode: "US", assetName: "City_springfield_mo", archetype: .metropolis),
        "springfield il": CityEmblem(cityID: "springfield", displayName: "Springfield", countryCode: "US", assetName: "City_springfield_il", archetype: .historicBrick),
        "fort collins": CityEmblem(cityID: "fort_collins", displayName: "Fort Collins", countryCode: "US", assetName: "City_fort_collins", archetype: .alpine),
        "jackson": CityEmblem(cityID: "jackson", displayName: "Jackson", countryCode: "US", assetName: "City_jackson_ms", archetype: .historicBrick),
        "syracuse": CityEmblem(cityID: "syracuse", displayName: "Syracuse", countryCode: "US", assetName: "City_syracuse", archetype: .historicBrick),
        "dayton": CityEmblem(cityID: "dayton", displayName: "Dayton", countryCode: "US", assetName: "City_dayton", archetype: .metropolis),
        "waco": CityEmblem(cityID: "waco", displayName: "Waco", countryCode: "US", assetName: "City_waco", archetype: .metropolis),
        "columbia": CityEmblem(cityID: "columbia", displayName: "Columbia", countryCode: "US", assetName: "City_columbia_sc", archetype: .historicBrick),
        "cedar rapids": CityEmblem(cityID: "cedar_rapids", displayName: "Cedar Rapids", countryCode: "US", assetName: "City_cedar_rapids", archetype: .centralValley),
        "fargo": CityEmblem(cityID: "fargo", displayName: "Fargo", countryCode: "US", assetName: "City_fargo", archetype: .centralValley),
        "midland": CityEmblem(cityID: "midland", displayName: "Midland", countryCode: "US", assetName: "City_midland", archetype: .desert),
        "abilene": CityEmblem(cityID: "abilene", displayName: "Abilene", countryCode: "US", assetName: "City_abilene", archetype: .desert),
        "topeka": CityEmblem(cityID: "topeka", displayName: "Topeka", countryCode: "US", assetName: "City_topeka", archetype: .centralValley),
        "wilmington": CityEmblem(cityID: "wilmington", displayName: "Wilmington", countryCode: "US", assetName: "City_wilmington", archetype: .coastal),
        "lafayette": CityEmblem(cityID: "lafayette", displayName: "Lafayette", countryCode: "US", assetName: "City_lafayette", archetype: .coastal),
        "billings": CityEmblem(cityID: "billings", displayName: "Billings", countryCode: "US", assetName: "City_billings", archetype: .alpine),
        "hartford": CityEmblem(cityID: "hartford", displayName: "Hartford", countryCode: "US", assetName: "City_hartford", archetype: .historicBrick),
        "lansing": CityEmblem(cityID: "lansing", displayName: "Lansing", countryCode: "US", assetName: "City_lansing", archetype: .metropolis),
        "evansville": CityEmblem(cityID: "evansville", displayName: "Evansville", countryCode: "US", assetName: "City_evansville", archetype: .historicBrick),
        "south bend": CityEmblem(cityID: "south_bend", displayName: "South Bend", countryCode: "US", assetName: "City_south_bend", archetype: .historicBrick),
        "columbus ga": CityEmblem(cityID: "columbus", displayName: "Columbus", countryCode: "US", assetName: "City_columbus_ga", archetype: .historicBrick),
        "brownsville": CityEmblem(cityID: "brownsville", displayName: "Brownsville", countryCode: "US", assetName: "City_brownsville", archetype: .coastal),
        "macon": CityEmblem(cityID: "macon", displayName: "Macon", countryCode: "US", assetName: "City_macon", archetype: .historicBrick),
        "mcallen": CityEmblem(cityID: "mcallen", displayName: "McAllen", countryCode: "US", assetName: "City_mcallen", archetype: .desert),
        "killeen": CityEmblem(cityID: "killeen", displayName: "Killeen", countryCode: "US", assetName: "City_killeen", archetype: .centralValley),
        "college station": CityEmblem(cityID: "college_station", displayName: "College Station", countryCode: "US", assetName: "City_college_station", archetype: .historicBrick),
        "tyler": CityEmblem(cityID: "tyler", displayName: "Tyler", countryCode: "US", assetName: "City_tyler", archetype: .historicBrick),
        "beaumont": CityEmblem(cityID: "beaumont", displayName: "Beaumont", countryCode: "US", assetName: "City_beaumont", archetype: .coastal),
        "green bay": CityEmblem(cityID: "green_bay", displayName: "Green Bay", countryCode: "US", assetName: "City_green_bay", archetype: .coastal),
        "peoria": CityEmblem(cityID: "peoria", displayName: "Peoria", countryCode: "US", assetName: "City_peoria_il", archetype: .historicBrick),
        "champaign": CityEmblem(cityID: "champaign", displayName: "Champaign", countryCode: "US", assetName: "City_champaign", archetype: .historicBrick),
        "rochester mn": CityEmblem(cityID: "rochester", displayName: "Rochester", countryCode: "US", assetName: "City_rochester_mn", archetype: .metropolis),
        "las cruces": CityEmblem(cityID: "las_cruces", displayName: "Las Cruces", countryCode: "US", assetName: "City_las_cruces", archetype: .desert),
        "bend": CityEmblem(cityID: "bend", displayName: "Bend", countryCode: "US", assetName: "City_bend", archetype: .alpine),
        "st george": CityEmblem(cityID: "st_george", displayName: "St. George", countryCode: "US", assetName: "City_st_george", archetype: .desert),
        "tuscaloosa": CityEmblem(cityID: "tuscaloosa", displayName: "Tuscaloosa", countryCode: "US", assetName: "City_tuscaloosa", archetype: .historicBrick),
        "yuma": CityEmblem(cityID: "yuma", displayName: "Yuma", countryCode: "US", assetName: "City_yuma", archetype: .desert),
        "visalia": CityEmblem(cityID: "visalia", displayName: "Visalia", countryCode: "US", assetName: "City_visalia", archetype: .centralValley),
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
        "saint george": registeredCities["st george"]!,
        "st. george": registeredCities["st george"]!,
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
        "mcr": registeredCities["manchester"]!,
        "birmingham ": registeredCities["birmingham al"]!
    ]

    private static let registeredUSStates: [String: Set<String>] = [
        "new_york": ["NY"],
        "san_francisco": ["CA"],
        "los_angeles": ["CA"],
        "chicago": ["IL"],
        "seattle": ["WA"],
        "boston": ["MA"],
        "miami": ["FL"],
        "austin": ["TX"],
        "las_vegas": ["NV"],
        "washington": ["DC", "MD", "VA"],
        "honolulu": ["HI"],
        "houston": ["TX"],
        "philadelphia": ["PA"],
        "phoenix": ["AZ"],
        "san_antonio": ["TX"],
        "san_diego": ["CA"],
        "dallas": ["TX"],
        "denver": ["CO"],
        "atlanta": ["GA"],
        "nashville": ["TN"],
        "new_orleans": ["LA"],
        "portland": ["OR"],
        "st_louis": ["MO", "IL"],
        "minneapolis": ["MN"],
        "detroit": ["MI"],
        "pittsburgh": ["PA"],
        "tampa": ["FL"],
        "orlando": ["FL"],
        "charlotte": ["NC"],
        "salt_lake_city": ["UT"],
        "baltimore": ["MD"],
        "kansas_city": ["MO", "KS"],
        "cleveland": ["OH"],
        "indianapolis": ["IN"],
        "columbus": ["OH"],
        "milwaukee": ["WI"],
        "cincinnati": ["OH"],
        "san_jose": ["CA"],
        "raleigh": ["NC"],
        "louisville": ["KY"],
        "memphis": ["TN"],
        "oklahoma_city": ["OK"],
        "albuquerque": ["NM"],
        "tucson": ["AZ"],
        "el_paso": ["TX"],
        "anchorage": ["AK"],
        "sacramento": ["CA"],
        "providence": ["RI"],
        "fort_worth": ["TX"],
        "jacksonville": ["FL"],
        "fresno": ["CA"],
        "colorado_springs": ["CO"],
        "omaha": ["NE"],
        "virginia_beach": ["VA"],
        "long_beach": ["CA"],
        "oakland": ["CA"],
        "bakersfield": ["CA"],
        "tulsa": ["OK"],
        "wichita": ["KS"],
        "lexington": ["KY"],
        "stockton": ["CA"],
        "newark": ["NJ"],
        "corpus_christi": ["TX"],
        "greensboro": ["NC"],
        "jersey_city": ["NJ"],
        "lincoln": ["NE"],
        "reno": ["NV"],
        "buffalo": ["NY"],
        "fort_wayne": ["IN"],
        "lubbock": ["TX"],
        "laredo": ["TX"],
        "toledo": ["OH"],
        "richmond": ["VA"],
        "huntsville": ["AL"],
        "spokane": ["WA"],
        "baton_rouge": ["LA"],
        "sioux_falls": ["SD"],
        "des_moines": ["IA"],
        "fayetteville": ["NC"],
        "little_rock": ["AR"],
        "rochester": ["NY"],
        "amarillo": ["TX"],
        "tallahassee": ["FL"],
        "knoxville": ["TN"],
        "augusta": ["GA"],
        "grand_rapids": ["MI"],
        "mobile": ["AL"],
        "birmingham": ["AL"],
        "montgomery": ["AL"],
        "chattanooga": ["TN"],
        "akron": ["OH"],
        "shreveport": ["LA"],
        "eugene": ["OR"],
        "salem": ["OR"],
        "springfield": ["MO"],
        "fort_collins": ["CO"],
        "jackson": ["MS"],
        "syracuse": ["NY"],
        "dayton": ["OH"],
        "waco": ["TX"],
        "columbia": ["SC"],
        "cedar_rapids": ["IA"],
        "fargo": ["ND"],
        "midland": ["TX"],
        "abilene": ["TX"],
        "topeka": ["KS"],
        "wilmington": ["NC"],
        "lafayette": ["LA"],
        "billings": ["MT"],
        "hartford": ["CT"],
        "lansing": ["MI"],
        "evansville": ["IN"],
        "south_bend": ["IN"],
        "brownsville": ["TX"],
        "macon": ["GA"],
        "mcallen": ["TX"],
        "killeen": ["TX"],
        "college_station": ["TX"],
        "tyler": ["TX"],
        "beaumont": ["TX"],
        "green_bay": ["WI"],
        "peoria": ["IL"],
        "champaign": ["IL"],
        "las_cruces": ["NM"],
        "bend": ["OR"],
        "st_george": ["UT"],
        "tuscaloosa": ["AL"],
        "yuma": ["AZ"],
        "visalia": ["CA"],
        "berkeley": ["CA"],
        "palo_alto": ["CA"],
        "mountain_view": ["CA"],
        "cupertino": ["CA"],
        "sunnyvale": ["CA"],
        "santa_barbara": ["CA"],
        "irvine": ["CA"],
        "boulder": ["CO"],
        "ann_arbor": ["MI"],
        "madison": ["WI"],
        "durham": ["NC"],
        "chapel_hill": ["NC"],
        "charlottesville": ["VA"],
        "ithaca": ["NY"],
        "new_haven": ["CT"],
        "princeton": ["NJ"],
        "savannah": ["GA"],
        "charleston": ["SC"],
        "asheville": ["NC"],
        "boise": ["ID"]
    ]

    /// State-scoped US metropolitan satellite municipalities that reuse their parent metro's 3D emblem
    /// while preserving their own cityID and displayName.
    private static let metroSatelliteParents: [String: [String: String]] = [
        // Greater Los Angeles, Orange County, Inland Empire & Ventura (CA)
        "anaheim": ["CA": "los angeles"],
        "santa ana": ["CA": "los angeles"],
        "riverside": ["CA": "los angeles"],
        "santa clarita": ["CA": "los angeles"],
        "san bernardino": ["CA": "los angeles"],
        "fontana": ["CA": "los angeles"],
        "moreno valley": ["CA": "los angeles"],
        "oxnard": ["CA": "los angeles"],
        "huntington beach": ["CA": "los angeles"],
        "glendale": ["CA": "los angeles", "AZ": "phoenix"],
        "ontario": ["CA": "los angeles"],
        "rancho cucamonga": ["CA": "los angeles"],
        "garden grove": ["CA": "los angeles"],
        "lancaster": ["CA": "los angeles"],
        "palmdale": ["CA": "los angeles"],
        "corona": ["CA": "los angeles"],
        "pomona": ["CA": "los angeles"],
        "victorville": ["CA": "los angeles"],
        "fullerton": ["CA": "los angeles"],
        "torrance": ["CA": "los angeles"],
        "orange": ["CA": "los angeles"],
        "pasadena": ["CA": "los angeles", "TX": "houston"],
        "simi valley": ["CA": "los angeles"],
        "thousand oaks": ["CA": "los angeles"],
        "menifee": ["CA": "los angeles"],
        "temecula": ["CA": "los angeles"],
        "murrieta": ["CA": "los angeles"],
        "ventura": ["CA": "los angeles"],
        "costa mesa": ["CA": "los angeles"],
        "downey": ["CA": "los angeles"],
        "jurupa valley": ["CA": "los angeles"],
        "rialto": ["CA": "los angeles"],
        "west covina": ["CA": "los angeles"],
        "el monte": ["CA": "los angeles"],
        "burbank": ["CA": "los angeles"],
        "hesperia": ["CA": "los angeles"],
        "inglewood": ["CA": "los angeles"],
        "santa monica": ["CA": "los angeles"],
        "beverly hills": ["CA": "los angeles"],
        "west hollywood": ["CA": "los angeles"],
        "culver city": ["CA": "los angeles"],
        "malibu": ["CA": "los angeles"],
        "manhattan beach": ["CA": "los angeles"],
        "hermosa beach": ["CA": "los angeles"],
        "redondo beach": ["CA": "los angeles"],
        "el segundo": ["CA": "los angeles"],
        "hawthorne": ["CA": "los angeles"],
        "gardena": ["CA": "los angeles"],
        "carson": ["CA": "los angeles"],
        "compton": ["CA": "los angeles"],
        "cerritos": ["CA": "los angeles"],
        "whittier": ["CA": "los angeles"],
        "alhambra": ["CA": "los angeles"],
        "monterey park": ["CA": "los angeles"],
        "san gabriel": ["CA": "los angeles"],
        "arcadia": ["CA": "los angeles"],
        "temple city": ["CA": "los angeles"],
        "rosemead": ["CA": "los angeles"],
        "san marino": ["CA": "los angeles"],
        "south pasadena": ["CA": "los angeles"],
        "monrovia": ["CA": "los angeles"],
        "azusa": ["CA": "los angeles"],
        "glendora": ["CA": "los angeles"],
        "covina": ["CA": "los angeles"],
        "walnut": ["CA": "los angeles"],
        "diamond bar": ["CA": "los angeles"],
        "rowland heights": ["CA": "los angeles"],
        "hacienda heights": ["CA": "los angeles"],
        "chino": ["CA": "los angeles"],
        "chino hills": ["CA": "los angeles"],
        "upland": ["CA": "los angeles"],
        "claremont": ["CA": "los angeles"],
        "redlands": ["CA": "los angeles"],
        "palm springs": ["CA": "los angeles"],
        "palm desert": ["CA": "los angeles"],
        "indio": ["CA": "los angeles"],
        "calabasas": ["CA": "los angeles"],
        "camarillo": ["CA": "los angeles"],
        "fountain valley": ["CA": "los angeles"],
        "buena park": ["CA": "los angeles"],
        "brea": ["CA": "los angeles"],
        "yorba linda": ["CA": "los angeles"],
        "placentia": ["CA": "los angeles"],
        "newport beach": ["CA": "irvine"],
        "laguna beach": ["CA": "irvine"],
        "tustin": ["CA": "irvine"],
        "lake forest": ["CA": "irvine"],
        "mission viejo": ["CA": "irvine"],
        "aliso viejo": ["CA": "irvine"],
        "laguna niguel": ["CA": "irvine"],
        "dana point": ["CA": "irvine"],
        "san clemente": ["CA": "irvine"],
        "san juan capistrano": ["CA": "irvine"],
        "santa maria": ["CA": "santa barbara"],
        "san luis obispo": ["CA": "santa barbara"],
        "goleta": ["CA": "santa barbara"],

        // San Francisco Bay Area (CA)
        "fremont": ["CA": "san jose"],
        "santa clara": ["CA": "san jose"],
        "milpitas": ["CA": "san jose"],
        "salinas": ["CA": "san jose"],
        "campbell": ["CA": "san jose"],
        "los gatos": ["CA": "san jose"],
        "saratoga": ["CA": "san jose"],
        "morgan hill": ["CA": "san jose"],
        "gilroy": ["CA": "san jose"],
        "santa cruz": ["CA": "san jose"],
        "monterey": ["CA": "san jose"],
        "carmel-by-the-sea": ["CA": "san jose"],
        "newark": ["CA": "san jose"],
        "union city": ["CA": "san jose", "NJ": "new york"],
        "menlo park": ["CA": "palo alto"],
        "east palo alto": ["CA": "palo alto"],
        "stanford": ["CA": "palo alto"],
        "los altos": ["CA": "mountain view"],
        "los altos hills": ["CA": "mountain view"],
        "hayward": ["CA": "oakland"],
        "vallejo": ["CA": "oakland"],
        "concord": ["CA": "oakland", "NC": "charlotte"],
        "fairfield": ["CA": "oakland"],
        "antioch": ["CA": "oakland"],
        "richmond": ["CA": "oakland"],
        "alameda": ["CA": "oakland"],
        "san leandro": ["CA": "oakland"],
        "emeryville": ["CA": "oakland"],
        "walnut creek": ["CA": "oakland"],
        "pleasanton": ["CA": "oakland"],
        "dublin": ["CA": "oakland", "OH": "columbus"],
        "san ramon": ["CA": "oakland"],
        "livermore": ["CA": "oakland"],
        "danville": ["CA": "oakland"],
        "castro valley": ["CA": "oakland"],
        "el cerrito": ["CA": "berkeley"],
        "vacaville": ["CA": "sacramento"],
        "san mateo": ["CA": "san francisco"],
        "daly city": ["CA": "san francisco"],
        "santa rosa": ["CA": "san francisco"],
        "south san francisco": ["CA": "san francisco"],
        "burlingame": ["CA": "san francisco"],
        "foster city": ["CA": "san francisco"],
        "san bruno": ["CA": "san francisco"],
        "millbrae": ["CA": "san francisco"],
        "san carlos": ["CA": "san francisco"],
        "belmont": ["CA": "san francisco", "MA": "boston"],
        "pacifica": ["CA": "san francisco"],
        "half moon bay": ["CA": "san francisco"],
        "san rafael": ["CA": "san francisco"],
        "sausalito": ["CA": "san francisco"],
        "mill valley": ["CA": "san francisco"],
        "novato": ["CA": "san francisco"],
        "napa": ["CA": "san francisco"],

        // Greater San Diego, Sacramento & Central Valley (CA)
        "chula vista": ["CA": "san diego"],
        "oceanside": ["CA": "san diego"],
        "escondido": ["CA": "san diego"],
        "carlsbad": ["CA": "san diego"],
        "el cajon": ["CA": "san diego"],
        "la jolla": ["CA": "san diego"],
        "del mar": ["CA": "san diego"],
        "encinitas": ["CA": "san diego"],
        "solana beach": ["CA": "san diego"],
        "coronado": ["CA": "san diego"],
        "national city": ["CA": "san diego"],
        "san marcos": ["CA": "san diego", "TX": "austin"],
        "vista": ["CA": "san diego"],
        "poway": ["CA": "san diego"],
        "santee": ["CA": "san diego"],
        "elk grove": ["CA": "sacramento"],
        "roseville": ["CA": "sacramento"],
        "davis": ["CA": "sacramento"],
        "folsom": ["CA": "sacramento"],
        "citrus heights": ["CA": "sacramento"],
        "rancho cordova": ["CA": "sacramento"],
        "rocklin": ["CA": "sacramento"],
        "chico": ["CA": "sacramento"],
        "redding": ["CA": "sacramento"],
        "clovis": ["CA": "fresno"],
        "modesto": ["CA": "stockton"],
        "tracy": ["CA": "stockton"],

        // Dallas–Fort Worth, Greater Houston, Austin & San Antonio (TX)
        "arlington": ["TX": "fort worth", "VA": "washington", "MA": "boston"],
        "plano": ["TX": "dallas"],
        "irving": ["TX": "dallas"],
        "garland": ["TX": "dallas"],
        "frisco": ["TX": "dallas"],
        "mckinney": ["TX": "dallas"],
        "grand prairie": ["TX": "dallas"],
        "denton": ["TX": "dallas"],
        "mesquite": ["TX": "dallas"],
        "lewisville": ["TX": "dallas"],
        "carrollton": ["TX": "dallas"],
        "richardson": ["TX": "dallas"],
        "allen": ["TX": "dallas"],
        "addison": ["TX": "dallas"],
        "coppell": ["TX": "dallas"],
        "flower mound": ["TX": "dallas"],
        "southlake": ["TX": "fort worth"],
        "grapevine": ["TX": "fort worth"],
        "euless": ["TX": "fort worth"],
        "bedford": ["TX": "fort worth"],
        "pearland": ["TX": "houston"],
        "league city": ["TX": "houston"],
        "conroe": ["TX": "houston"],
        "sugar land": ["TX": "houston"],
        "the woodlands": ["TX": "houston"],
        "katy": ["TX": "houston"],
        "cypress": ["TX": "houston"],
        "spring": ["TX": "houston"],
        "missouri city": ["TX": "houston"],
        "baytown": ["TX": "houston"],
        "galveston": ["TX": "houston"],
        "round rock": ["TX": "austin"],
        "georgetown": ["TX": "austin"],
        "pflugerville": ["TX": "austin"],
        "cedar park": ["TX": "austin"],
        "leander": ["TX": "austin"],
        "kyle": ["TX": "austin"],
        "new braunfels": ["TX": "san antonio"],
        "odessa": ["TX": "midland"],
        "edinburg": ["TX": "mcallen"],
        "mission": ["TX": "mcallen"],
        "pharr": ["TX": "mcallen"],
        "harlingen": ["TX": "brownsville"],
        "south padre island": ["TX": "brownsville"],
        "bryan": ["TX": "college station"],
        "temple": ["TX": "killeen"],
        "wichita falls": ["TX": "fort worth"],
        "san angelo": ["TX": "abilene"],

        // Phoenix Valley of the Sun & Northern AZ (AZ)
        "mesa": ["AZ": "phoenix"],
        "gilbert": ["AZ": "phoenix"],
        "chandler": ["AZ": "phoenix"],
        "scottsdale": ["AZ": "phoenix"],
        "peoria": ["AZ": "phoenix"],
        "tempe": ["AZ": "phoenix"],
        "surprise": ["AZ": "phoenix"],
        "buckeye": ["AZ": "phoenix"],
        "goodyear": ["AZ": "phoenix"],
        "avondale": ["AZ": "phoenix"],
        "sedona": ["AZ": "phoenix"],
        "flagstaff": ["AZ": "phoenix"],

        // South Florida, Central Florida & Tampa Bay (FL)
        "hialeah": ["FL": "miami"],
        "fort lauderdale": ["FL": "miami"],
        "pembroke pines": ["FL": "miami"],
        "hollywood": ["FL": "miami"],
        "miramar": ["FL": "miami"],
        "coral springs": ["FL": "miami"],
        "west palm beach": ["FL": "miami"],
        "pompano beach": ["FL": "miami"],
        "miami gardens": ["FL": "miami"],
        "davie": ["FL": "miami"],
        "boca raton": ["FL": "miami"],
        "sunrise": ["FL": "miami"],
        "port st. lucie": ["FL": "miami"],
        "port st lucie": ["FL": "miami"],
        "miami beach": ["FL": "miami"],
        "coral gables": ["FL": "miami"],
        "doral": ["FL": "miami"],
        "aventura": ["FL": "miami"],
        "sunny isles beach": ["FL": "miami"],
        "key biscayne": ["FL": "miami"],
        "key west": ["FL": "miami"],
        "delray beach": ["FL": "miami"],
        "boynton beach": ["FL": "miami"],
        "jupiter": ["FL": "miami"],
        "st. petersburg": ["FL": "tampa"],
        "st petersburg": ["FL": "tampa"],
        "clearwater": ["FL": "tampa"],
        "cape coral": ["FL": "tampa"],
        "fort myers": ["FL": "tampa"],
        "sarasota": ["FL": "tampa"],
        "bradenton": ["FL": "tampa"],
        "naples": ["FL": "tampa"],
        "lakeland": ["FL": "orlando"],
        "palm bay": ["FL": "orlando"],
        "deltona": ["FL": "orlando"],
        "kissimmee": ["FL": "orlando"],
        "winter park": ["FL": "orlando"],
        "daytona beach": ["FL": "orlando"],
        "palm coast": ["FL": "jacksonville"],
        "gainesville": ["FL": "jacksonville"],
        "st. augustine": ["FL": "jacksonville"],
        "st augustine": ["FL": "jacksonville"],
        "pensacola": ["FL": "tallahassee"],
        "destin": ["FL": "tallahassee"],

        // New York Tri-State Metro & Upstate (NY, NJ, CT)
        "yonkers": ["NY": "new york"],
        "albany": ["NY": "new york", "CA": "berkeley"],
        "flushing": ["NY": "new york"],
        "queens": ["NY": "new york"],
        "bronx": ["NY": "new york"],
        "staten island": ["NY": "new york"],
        "long island city": ["NY": "new york"],
        "astoria": ["NY": "new york"],
        "white plains": ["NY": "new york"],
        "new rochelle": ["NY": "new york"],
        "mount vernon": ["NY": "new york"],
        "scarsdale": ["NY": "new york"],
        "great neck": ["NY": "new york"],
        "syosset": ["NY": "new york"],
        "hempstead": ["NY": "new york"],
        "garden city": ["NY": "new york"],
        "stony brook": ["NY": "new york"],
        "hoboken": ["NJ": "new york"],
        "fort lee": ["NJ": "new york"],
        "edgewater": ["NJ": "new york"],
        "weehawken": ["NJ": "new york"],
        "west new york": ["NJ": "new york"],
        "secaucus": ["NJ": "new york"],
        "hackensack": ["NJ": "new york"],
        "paramus": ["NJ": "new york"],
        "bayonne": ["NJ": "jersey city"],
        "paterson": ["NJ": "newark"],
        "elizabeth": ["NJ": "newark"],
        "edison": ["NJ": "newark"],
        "woodbridge": ["NJ": "newark", "VA": "washington"],
        "lakewood": ["NJ": "newark", "CO": "denver", "CA": "los angeles"],
        "toms river": ["NJ": "newark"],
        "clifton": ["NJ": "newark"],
        "passaic": ["NJ": "newark"],
        "new brunswick": ["NJ": "newark"],
        "cherry hill": ["NJ": "philadelphia"],
        "camden": ["NJ": "philadelphia"],
        "trenton": ["NJ": "princeton"],
        "stamford": ["CT": "new york"],
        "greenwich": ["CT": "new york"],
        "norwalk": ["CT": "new york"],
        "bridgeport": ["CT": "new haven"],
        "waterbury": ["CT": "new haven"],
        "danbury": ["CT": "new haven"],
        "west hartford": ["CT": "hartford"],

        // Greater Chicago & Downstate (IL)
        "aurora": ["IL": "chicago", "CO": "denver"],
        "naperville": ["IL": "chicago"],
        "joliet": ["IL": "chicago"],
        "elgin": ["IL": "chicago"],
        "rockford": ["IL": "chicago"],
        "evanston": ["IL": "chicago"],
        "oak park": ["IL": "chicago"],
        "skokie": ["IL": "chicago"],
        "schaumburg": ["IL": "chicago"],
        "cicero": ["IL": "chicago"],
        "arlington heights": ["IL": "chicago"],
        "bolingbrook": ["IL": "chicago"],
        "palatine": ["IL": "chicago"],
        "des plaines": ["IL": "chicago"],
        "orland park": ["IL": "chicago"],
        "oak brook": ["IL": "chicago"],
        "downers grove": ["IL": "chicago"],
        "glenview": ["IL": "chicago"],
        "waukegan": ["IL": "chicago"],
        "urbana": ["IL": "champaign"],
        "normal": ["IL": "peoria"],
        "bloomington": ["IL": "peoria", "MN": "minneapolis", "IN": "indianapolis"],

        // Front Range (CO)
        "thornton": ["CO": "denver"],
        "arvada": ["CO": "denver"],
        "westminster": ["CO": "denver", "CA": "los angeles"],
        "centennial": ["CO": "denver"],
        "greeley": ["CO": "denver"],
        "littleton": ["CO": "denver"],
        "broomfield": ["CO": "denver"],
        "golden": ["CO": "denver"],
        "longmont": ["CO": "boulder"],
        "pueblo": ["CO": "colorado springs"],

        // Puget Sound, Spokane & Greater Portland (WA, OR)
        "tacoma": ["WA": "seattle"],
        "bellevue": ["WA": "seattle"],
        "kent": ["WA": "seattle"],
        "everett": ["WA": "seattle"],
        "renton": ["WA": "seattle"],
        "federal way": ["WA": "seattle"],
        "redmond": ["WA": "seattle"],
        "kirkland": ["WA": "seattle"],
        "bothell": ["WA": "seattle"],
        "issaquah": ["WA": "seattle"],
        "sammamish": ["WA": "seattle"],
        "mercer island": ["WA": "seattle"],
        "lynnwood": ["WA": "seattle"],
        "shoreline": ["WA": "seattle"],
        "edmonds": ["WA": "seattle"],
        "burien": ["WA": "seattle"],
        "tukwila": ["WA": "seattle"],
        "seatac": ["WA": "seattle"],
        "woodinville": ["WA": "seattle"],
        "bainbridge island": ["WA": "seattle"],
        "olympia": ["WA": "seattle"],
        "bellingham": ["WA": "seattle"],
        "spokane valley": ["WA": "spokane"],
        "vancouver": ["WA": "portland"],
        "gresham": ["OR": "portland"],
        "hillsboro": ["OR": "portland"],
        "beaverton": ["OR": "portland"],
        "lake oswego": ["OR": "portland"],
        "tigard": ["OR": "portland"],
        "corvallis": ["OR": "eugene"],

        // Greater Washington DC, Maryland & Hampton Roads (VA, MD)
        "alexandria": ["VA": "washington"],
        "mclean": ["VA": "washington"],
        "tysons": ["VA": "washington"],
        "reston": ["VA": "washington"],
        "herndon": ["VA": "washington"],
        "fairfax": ["VA": "washington"],
        "vienna": ["VA": "washington"],
        "falls church": ["VA": "washington"],
        "annandale": ["VA": "washington"],
        "chantilly": ["VA": "washington"],
        "ashburn": ["VA": "washington"],
        "leesburg": ["VA": "washington"],
        "manassas": ["VA": "washington"],
        "bethesda": ["MD": "washington"],
        "silver spring": ["MD": "washington"],
        "rockville": ["MD": "washington"],
        "gaithersburg": ["MD": "washington"],
        "germantown": ["MD": "washington"],
        "college park": ["MD": "washington"],
        "frederick": ["MD": "washington"],
        "annapolis": ["MD": "baltimore"],
        "towson": ["MD": "baltimore"],
        "ellicott city": ["MD": "baltimore"],
        "chesapeake": ["VA": "virginia beach"],
        "norfolk": ["VA": "virginia beach"],
        "newport news": ["VA": "virginia beach"],
        "hampton": ["VA": "virginia beach"],
        "suffolk": ["VA": "virginia beach"],
        "williamsburg": ["VA": "virginia beach"],

        // Greater Boston & New England (MA, NH)
        "cambridge": ["MA": "boston"],
        "worcester": ["MA": "boston"],
        "lowell": ["MA": "boston"],
        "brockton": ["MA": "boston"],
        "lynn": ["MA": "boston"],
        "quincy": ["MA": "boston"],
        "new bedford": ["MA": "boston"],
        "somerville": ["MA": "boston"],
        "brookline": ["MA": "boston"],
        "newton": ["MA": "boston"],
        "malden": ["MA": "boston"],
        "medford": ["MA": "boston"],
        "waltham": ["MA": "boston"],
        "watertown": ["MA": "boston"],
        "lexington": ["MA": "boston"],
        "wellesley": ["MA": "boston"],
        "natick": ["MA": "boston"],
        "framingham": ["MA": "boston"],
        "revere": ["MA": "boston"],
        "chelsea": ["MA": "boston"],
        "salem": ["MA": "boston"],
        "plymouth": ["MA": "boston"],
        "springfield": ["MA": "boston", "IL": "springfield il"],
        "manchester": ["NH": "boston"],
        "nashua": ["NH": "boston"],

        // Las Vegas, Reno, Salt Lake, Atlanta, Detroit, Carolinas & Midwest Metro Satellites
        "henderson": ["NV": "las vegas"],
        "north las vegas": ["NV": "las vegas"],
        "summerlin": ["NV": "las vegas"],
        "sparks": ["NV": "reno"],
        "carson city": ["NV": "reno"],
        "west valley city": ["UT": "salt lake city"],
        "west jordan": ["UT": "salt lake city"],
        "provo": ["UT": "salt lake city"],
        "orem": ["UT": "salt lake city"],
        "sandy": ["UT": "salt lake city"],
        "ogden": ["UT": "salt lake city"],
        "park city": ["UT": "salt lake city"],
        "sandy springs": ["GA": "atlanta"],
        "south fulton": ["GA": "atlanta"],
        "athens": ["GA": "atlanta"],
        "alpharetta": ["GA": "atlanta"],
        "johns creek": ["GA": "atlanta"],
        "roswell": ["GA": "atlanta"],
        "marietta": ["GA": "atlanta"],
        "smyrna": ["GA": "atlanta"],
        "decatur": ["GA": "atlanta"],
        "duluth": ["GA": "atlanta", "MN": "minneapolis"],
        "suwanee": ["GA": "atlanta"],
        "lawrenceville": ["GA": "atlanta"],
        "peachtree city": ["GA": "atlanta"],
        "columbus": ["GA": "columbus ga"],
        "birmingham": ["AL": "birmingham al"],
        "rochester": ["MN": "rochester mn"],
        "edina": ["MN": "minneapolis"],
        "eagan": ["MN": "minneapolis"],
        "minnetonka": ["MN": "minneapolis"],
        "eden prairie": ["MN": "minneapolis"],
        "maple grove": ["MN": "minneapolis"],
        "woodbury": ["MN": "minneapolis"],
        "fayetteville": ["AR": "little rock"],
        "bentonville": ["AR": "little rock"],
        "davenport": ["IA": "cedar rapids"],
        "iowa city": ["IA": "cedar rapids"],
        "ames": ["IA": "des moines"],
        "west des moines": ["IA": "des moines"],
        "columbia": ["MD": "baltimore", "MO": "st louis"],
        "clayton": ["MO": "st louis"],
        "st. charles": ["MO": "st louis"],
        "warren": ["MI": "detroit"],
        "sterling heights": ["MI": "detroit"],
        "dearborn": ["MI": "detroit"],
        "clinton": ["MI": "detroit"],
        "troy": ["MI": "detroit"],
        "royal oak": ["MI": "detroit"],
        "birmingham mi": ["MI": "detroit"],
        "novi": ["MI": "detroit"],
        "east lansing": ["MI": "lansing"],
        "cary": ["NC": "raleigh"],
        "apex": ["NC": "raleigh"],
        "morrisville": ["NC": "raleigh"],
        "wake forest": ["NC": "raleigh"],
        "winston-salem": ["NC": "greensboro"],
        "winston salem": ["NC": "greensboro"],
        "high point": ["NC": "greensboro"],
        "north charleston": ["SC": "charleston"],
        "mount pleasant": ["SC": "charleston"],
        "hilton head island": ["SC": "savannah"],
        "greenville": ["SC": "charlotte"],
        "overland park": ["KS": "kansas city"],
        "olathe": ["KS": "kansas city"],
        "lenexa": ["KS": "kansas city"],
        "shawnee": ["KS": "kansas city"],
        "lawrence": ["KS": "kansas city"],
        "independence": ["MO": "kansas city"],
        "lee's summit": ["MO": "kansas city"],
        "lees summit": ["MO": "kansas city"],
        "norman": ["OK": "oklahoma city"],
        "edmond": ["OK": "oklahoma city"],
        "broken arrow": ["OK": "tulsa"],
        "carmel": ["IN": "indianapolis"],
        "fishers": ["IN": "indianapolis"],
        "noblesville": ["IN": "indianapolis"],
        "west lafayette": ["IN": "indianapolis"],
        "murfreesboro": ["TN": "nashville"],
        "clarksville": ["TN": "nashville"],
        "franklin": ["TN": "nashville"],
        "brentwood": ["TN": "nashville"],
        "gatlinburg": ["TN": "knoxville"],
        "pigeon forge": ["TN": "knoxville"],
        "rio rancho": ["NM": "albuquerque"],
        "santa fe": ["NM": "albuquerque"],
        "taos": ["NM": "albuquerque"],
        "meridian": ["ID": "boise"],
        "nampa": ["ID": "boise"],
        "allentown": ["PA": "philadelphia"],
        "king of prussia": ["PA": "philadelphia"],
        "bryn mawr": ["PA": "philadelphia"],
        "villanova": ["PA": "philadelphia"],
        "bethlehem": ["PA": "philadelphia"],
        "lakewood oh": ["OH": "cleveland"],
        "shaker heights": ["OH": "cleveland"],
        "beachwood": ["OH": "cleveland"],
        "westerville": ["OH": "columbus"],
        "upper arlington": ["OH": "columbus"],
        "mason": ["OH": "cincinnati"],
        "covington": ["KY": "cincinnati"],
        "newport": ["KY": "cincinnati", "RI": "providence"],
        "wauwatosa": ["WI": "milwaukee"],
        "brookfield": ["WI": "milwaukee"],
        "niagara falls": ["NY": "buffalo"]
    ]

    /// Country-scoped international metropolitan satellite cities and districts that reuse their parent metro's 3D emblem
    /// while preserving their own cityID and displayName.
    private static let internationalMetroSatellites: [String: [String: String]] = [
        // Canada — Greater Toronto (GTA), Greater Vancouver, Greater Montreal, Ottawa & Calgary
        "mississauga": ["CA": "toronto"],
        "markham": ["CA": "toronto"],
        "richmond hill": ["CA": "toronto"],
        "brampton": ["CA": "toronto"],
        "vaughan": ["CA": "toronto"],
        "oakville": ["CA": "toronto"],
        "burlington": ["CA": "toronto"],
        "pickering": ["CA": "toronto"],
        "ajax": ["CA": "toronto"],
        "whitby": ["CA": "toronto"],
        "oshawa": ["CA": "toronto"],
        "newmarket": ["CA": "toronto"],
        "aurora": ["CA": "toronto"],
        "scarborough": ["CA": "toronto"],
        "north york": ["CA": "toronto"],
        "etobicoke": ["CA": "toronto"],
        "hamilton": ["CA": "toronto"],
        "niagara falls": ["CA": "toronto"],
        "kitchener": ["CA": "waterloo"],
        "cambridge": ["CA": "waterloo"],
        "guelph": ["CA": "waterloo"],
        "burnaby": ["CA": "vancouver"],
        "richmond": ["CA": "vancouver", "GB": "london"],
        "surrey": ["CA": "vancouver"],
        "coquitlam": ["CA": "vancouver"],
        "north vancouver": ["CA": "vancouver"],
        "west vancouver": ["CA": "vancouver"],
        "new westminster": ["CA": "vancouver"],
        "langley": ["CA": "vancouver"],
        "delta": ["CA": "vancouver"],
        "white rock": ["CA": "vancouver"],
        "whistler": ["CA": "vancouver"],
        "laval": ["CA": "montreal"],
        "longueuil": ["CA": "montreal"],
        "brossard": ["CA": "montreal"],
        "gatineau": ["CA": "ottawa"],
        "banff": ["CA": "calgary"],
        "canmore": ["CA": "calgary"],

        // Japan — Greater Tokyo, Kansai (Osaka/Kyoto/Kobe), Hokkaido, Kyushu & Okinawa
        "kawasaki": ["JP": "tokyo"],
        "saitama": ["JP": "tokyo"],
        "chiba": ["JP": "tokyo"],
        "funabashi": ["JP": "tokyo"],
        "ichikawa": ["JP": "tokyo"],
        "urayasu": ["JP": "tokyo"],
        "machida": ["JP": "tokyo"],
        "hachioji": ["JP": "tokyo"],
        "mitaka": ["JP": "tokyo"],
        "musashino": ["JP": "tokyo"],
        "kichijoji": ["JP": "tokyo"],
        "kamakura": ["JP": "tokyo"],
        "fujisawa": ["JP": "tokyo"],
        "enoshima": ["JP": "tokyo"],
        "narita": ["JP": "tokyo"],
        "hakone": ["JP": "tokyo"],
        "nikko": ["JP": "tokyo"],
        "kawagoe": ["JP": "tokyo"],
        "tsukuba": ["JP": "tokyo"],
        "shinagawa": ["JP": "tokyo"],
        "roppongi": ["JP": "tokyo"],
        "akihabara": ["JP": "tokyo"],
        "asakusa": ["JP": "tokyo"],
        "ueno": ["JP": "tokyo"],
        "ikebukuro": ["JP": "tokyo"],
        "odaiba": ["JP": "tokyo"],
        "harajuku": ["JP": "tokyo"],
        "ebisu": ["JP": "tokyo"],
        "daikanyama": ["JP": "tokyo"],
        "meguro": ["JP": "tokyo"],
        "setagaya": ["JP": "tokyo"],
        "minato": ["JP": "tokyo"],
        "chiyoda": ["JP": "tokyo"],
        "chuo": ["JP": "tokyo"],
        "sakai": ["JP": "osaka"],
        "suita": ["JP": "osaka"],
        "toyonaka": ["JP": "osaka"],
        "higashiosaka": ["JP": "osaka"],
        "umeda": ["JP": "osaka"],
        "namba": ["JP": "osaka"],
        "shinsaibashi": ["JP": "osaka"],
        "nara": ["JP": "kyoto"],
        "uji": ["JP": "kyoto"],
        "arashiyama": ["JP": "kyoto"],
        "gion": ["JP": "kyoto"],
        "otsu": ["JP": "kyoto"],
        "amagasaki": ["JP": "kobe"],
        "nishinomiya": ["JP": "kobe"],
        "ashiya": ["JP": "kobe"],
        "himeji": ["JP": "kobe"],
        "otaru": ["JP": "sapporo"],
        "chitose": ["JP": "sapporo"],
        "furano": ["JP": "sapporo"],
        "niseko": ["JP": "sapporo"],
        "hakodate": ["JP": "sapporo"],
        "kitakyushu": ["JP": "fukuoka"],
        "dazaifu": ["JP": "fukuoka"],
        "beppu": ["JP": "fukuoka"],
        "yufuin": ["JP": "fukuoka"],
        "hakata": ["JP": "fukuoka"],
        "tenjin": ["JP": "fukuoka"],
        "naha": ["JP": "okinawa"],
        "ishigaki": ["JP": "okinawa"],
        "miyakojima": ["JP": "okinawa"],

        // South Korea — Greater Seoul (Sudogwon), Busan & Jeju
        "seongnam": ["KR": "seoul"],
        "bundang": ["KR": "seoul"],
        "pangyo": ["KR": "seoul"],
        "suwon": ["KR": "seoul"],
        "goyang": ["KR": "seoul"],
        "ilsan": ["KR": "seoul"],
        "yongin": ["KR": "seoul"],
        "anyang": ["KR": "seoul"],
        "bucheon": ["KR": "seoul"],
        "ansan": ["KR": "seoul"],
        "hanam": ["KR": "seoul"],
        "gwacheon": ["KR": "seoul"],
        "gimpo": ["KR": "seoul"],
        "paju": ["KR": "seoul"],
        "gangnam": ["KR": "seoul"],
        "hongdae": ["KR": "seoul"],
        "myeongdong": ["KR": "seoul"],
        "itaewon": ["KR": "seoul"],
        "mapo": ["KR": "seoul"],
        "songdo": ["KR": "incheon"],
        "haeundae": ["KR": "busan"],
        "gyeongju": ["KR": "busan"],
        "ulsan": ["KR": "busan"],
        "changwon": ["KR": "busan"],
        "seogwipo": ["KR": "jeju"],

        // Taiwan — Greater Taipei, Hsinchu, Taichung & Kaohsiung
        "new taipei": ["TW": "taipei"],
        "new taipei city": ["TW": "taipei"],
        "banqiao": ["TW": "taipei"],
        "tamsui": ["TW": "taipei"],
        "danshui": ["TW": "taipei"],
        "xindian": ["TW": "taipei"],
        "zhonghe": ["TW": "taipei"],
        "yonghe": ["TW": "taipei"],
        "sanchong": ["TW": "taipei"],
        "linkou": ["TW": "taipei"],
        "keelung": ["TW": "taipei"],
        "jiufen": ["TW": "taipei"],
        "taoyuan": ["TW": "taipei"],
        "zhongli": ["TW": "taipei"],
        "yilan": ["TW": "taipei"],
        "xinyi": ["TW": "taipei"],
        "daan": ["TW": "taipei"],
        "zhubei": ["TW": "hsinchu"],
        "changhua": ["TW": "taichung"],
        "nantou": ["TW": "taichung"],
        "sun moon lake": ["TW": "taichung"],
        "kenting": ["TW": "kaohsiung"],
        "pingtung": ["TW": "kaohsiung"],

        // Hong Kong, Macau & Mainland China Metro Clusters
        "kowloon": ["HK": "hong kong"],
        "tsim sha tsui": ["HK": "hong kong"],
        "mong kok": ["HK": "hong kong"],
        "wan chai": ["HK": "hong kong"],
        "causeway bay": ["HK": "hong kong"],
        "central": ["HK": "hong kong"],
        "lantau": ["HK": "hong kong"],
        "sha tin": ["HK": "hong kong"],
        "tuen mun": ["HK": "hong kong"],
        "yuen long": ["HK": "hong kong"],
        "taipa": ["MO": "macau"],
        "cotai": ["MO": "macau"],
        "coloane": ["MO": "macau"],
        "foshan": ["CN": "guangzhou"],
        "shunde": ["CN": "guangzhou"],
        "zhuhai": ["CN": "guangzhou"],
        "zhongshan": ["CN": "guangzhou"],
        "jiangmen": ["CN": "guangzhou"],
        "dongguan": ["CN": "shenzhen"],
        "huizhou": ["CN": "shenzhen"],
        "qianhai": ["CN": "shenzhen"],
        "nanshan": ["CN": "shenzhen"],
        "futian": ["CN": "shenzhen"],
        "pudong": ["CN": "shanghai"],
        "minhang": ["CN": "shanghai"],
        "songjiang": ["CN": "shanghai"],
        "jiading": ["CN": "shanghai"],
        "qingpu": ["CN": "shanghai"],
        "kunshan": ["CN": "suzhou"],
        "taicang": ["CN": "suzhou"],
        "changshu": ["CN": "suzhou"],
        "zhangjiagang": ["CN": "suzhou"],
        "wuxi": ["CN": "suzhou"],
        "changzhou": ["CN": "suzhou"],
        "nantong": ["CN": "shanghai"],
        "jiaxing": ["CN": "hangzhou"],
        "wuzhen": ["CN": "hangzhou"],
        "shaoxing": ["CN": "hangzhou"],
        "ningbo": ["CN": "hangzhou"],
        "yiwu": ["CN": "hangzhou"],
        "huzhou": ["CN": "hangzhou"],
        "moganshan": ["CN": "hangzhou"],
        "yangzhou": ["CN": "nanjing"],
        "zhenjiang": ["CN": "nanjing"],
        "dujiangyan": ["CN": "chengdu"],
        "leshan": ["CN": "chengdu"],
        "emeishan": ["CN": "chengdu"],
        "mianyang": ["CN": "chengdu"],
        "quanzhou": ["CN": "xiamen"],
        "zhangzhou": ["CN": "xiamen"],
        "gulangyu": ["CN": "xiamen"],
        "tianjin": ["CN": "beijing"],
        "langfang": ["CN": "beijing"],
        "baoding": ["CN": "beijing"],
        "haidian": ["CN": "beijing"],
        "chaoyang": ["CN": "beijing"],
        "xianyang": ["CN": "xi'an"],

        // Southeast Asia — Singapore, Malaysia, Thailand, Indonesia & Philippines
        "sentosa": ["SG": "singapore"],
        "jurong": ["SG": "singapore"],
        "changi": ["SG": "singapore"],
        "marina bay": ["SG": "singapore"],
        "petaling jaya": ["MY": "kuala lumpur"],
        "subang jaya": ["MY": "kuala lumpur"],
        "shah alam": ["MY": "kuala lumpur"],
        "putrajaya": ["MY": "kuala lumpur"],
        "cyberjaya": ["MY": "kuala lumpur"],
        "klang": ["MY": "kuala lumpur"],
        "genting highlands": ["MY": "kuala lumpur"],
        "johor bahru": ["MY": "kuala lumpur"],
        "george town": ["MY": "penang"],
        "georgetown": ["MY": "penang"],
        "butterworth": ["MY": "penang"],
        "nonthaburi": ["TH": "bangkok"],
        "pak kret": ["TH": "bangkok"],
        "samut prakan": ["TH": "bangkok"],
        "pattaya": ["TH": "bangkok"],
        "ayutthaya": ["TH": "bangkok"],
        "hua hin": ["TH": "bangkok"],
        "krabi": ["TH": "phuket"],
        "koh samui": ["TH": "phuket"],
        "phi phi": ["TH": "phuket"],
        "patong": ["TH": "phuket"],
        "chiang rai": ["TH": "chiang mai"],
        "pai": ["TH": "chiang mai"],
        "canggu": ["ID": "bali"],
        "seminyak": ["ID": "bali"],
        "kuta": ["ID": "bali"],
        "legian": ["ID": "bali"],
        "uluwatu": ["ID": "bali"],
        "jimbaran": ["ID": "bali"],
        "sanur": ["ID": "bali"],
        "nusa dua": ["ID": "bali"],
        "nusa penida": ["ID": "bali"],
        "tangerang": ["ID": "jakarta"],
        "bekasi": ["ID": "jakarta"],
        "depok": ["ID": "jakarta"],
        "bogor": ["ID": "jakarta"],
        "bandung": ["ID": "jakarta"],
        "makati": ["PH": "manila"],
        "bonifacio global city": ["PH": "manila"],
        "bgc": ["PH": "manila"],
        "taguig": ["PH": "manila"],
        "quezon city": ["PH": "manila"],
        "pasay": ["PH": "manila"],
        "paranaque": ["PH": "manila"],
        "mandaluyong": ["PH": "manila"],
        "pasig": ["PH": "manila"],

        // Australia & New Zealand
        "parramatta": ["AU": "sydney"],
        "chatswood": ["AU": "sydney"],
        "manly": ["AU": "sydney"],
        "bondi": ["AU": "sydney"],
        "bondi beach": ["AU": "sydney"],
        "newcastle": ["AU": "sydney"],
        "wollongong": ["AU": "sydney"],
        "blue mountains": ["AU": "sydney"],
        "geelong": ["AU": "melbourne"],
        "st kilda": ["AU": "melbourne"],
        "southbank": ["AU": "melbourne"],
        "fitzroy": ["AU": "melbourne"],
        "sunshine coast": ["AU": "brisbane"],
        "noosa": ["AU": "brisbane"],
        "ipswich": ["AU": "brisbane"],
        "surfers paradise": ["AU": "gold coast"],
        "broadbeach": ["AU": "gold coast"],
        "burleigh heads": ["AU": "gold coast"],
        "byron bay": ["AU": "gold coast"],
        "fremantle": ["AU": "perth"],
        "wanaka": ["NZ": "queenstown"],
        "arrowtown": ["NZ": "queenstown"],
        "milford sound": ["NZ": "queenstown"],
        "north shore": ["NZ": "auckland"],
        "takapuna": ["NZ": "auckland"],
        "manukau": ["NZ": "auckland"],
        "waiheke": ["NZ": "auckland"],

        // UK & Europe
        "croydon": ["GB": "london"],
        "greenwich": ["GB": "london"],
        "wimbledon": ["GB": "london"],
        "kingston": ["GB": "london"],
        "camden": ["GB": "london"],
        "islington": ["GB": "london"],
        "hackney": ["GB": "london"],
        "canary wharf": ["GB": "london"],
        "kensington": ["GB": "london"],
        "chelsea": ["GB": "london"],
        "notting hill": ["GB": "london"],
        "shoreditch": ["GB": "london"],
        "brixton": ["GB": "london"],
        "watford": ["GB": "london"],
        "slough": ["GB": "london"],
        "windsor": ["GB": "london"],
        "reading": ["GB": "london"],
        "brighton": ["GB": "london"],
        "bath": ["GB": "bristol"],
        "salford": ["GB": "manchester"],
        "trafford": ["GB": "manchester"],
        "stockport": ["GB": "manchester"],
        "st andrews": ["GB": "edinburgh"],
        "st. andrews": ["GB": "edinburgh"],
        "versailles": ["FR": "paris"],
        "saint-denis": ["FR": "paris"],
        "saint denis": ["FR": "paris"],
        "boulogne-billancourt": ["FR": "paris"],
        "neuilly-sur-seine": ["FR": "paris"],
        "levallois-perret": ["FR": "paris"],
        "courbevoie": ["FR": "paris"],
        "la defense": ["FR": "paris"],
        "la défense": ["FR": "paris"],
        "nanterre": ["FR": "paris"],
        "creteil": ["FR": "paris"],
        "ivry-sur-seine": ["FR": "paris"],
        "montreuil": ["FR": "paris"],
        "marne-la-vallee": ["FR": "paris"],
        "fontainebleau": ["FR": "paris"],
        "giverny": ["FR": "paris"],
        "montmartre": ["FR": "paris"],
        "monaco": ["FR": "nice", "MC": "nice"],
        "monte carlo": ["FR": "nice", "MC": "nice"],
        "monte-carlo": ["FR": "nice", "MC": "nice"],
        "antibes": ["FR": "nice"],
        "menton": ["FR": "nice"],
        "eze": ["FR": "nice"],
        "saint-tropez": ["FR": "nice"],
        "aix-en-provence": ["FR": "marseille"],
        "avignon": ["FR": "marseille"],
        "cassis": ["FR": "marseille"],
        "chamonix": ["FR": "lyon"],
        "annecy": ["FR": "lyon"],
        "saint-emilion": ["FR": "bordeaux"],
        "potsdam": ["DE": "berlin"],
        "garmisch-partenkirchen": ["DE": "munich"],
        "augsburg": ["DE": "munich"],
        "mainz": ["DE": "frankfurt"],
        "wiesbaden": ["DE": "frankfurt"],
        "darmstadt": ["DE": "frankfurt"],
        "offenbach": ["DE": "frankfurt"],
        "dusseldorf": ["DE": "cologne"],
        "düsseldorf": ["DE": "cologne"],
        "bonn": ["DE": "cologne"],
        "leverkusen": ["DE": "cologne"],
        "aachen": ["DE": "cologne"],
        "mannheim": ["DE": "heidelberg"],
        "lubeck": ["DE": "hamburg"],
        "lübeck": ["DE": "hamburg"],
        "haarlem": ["NL": "amsterdam"],
        "amstelveen": ["NL": "amsterdam"],
        "zaandam": ["NL": "amsterdam"],
        "almere": ["NL": "amsterdam"],
        "hilversum": ["NL": "amsterdam"],
        "leiden": ["NL": "amsterdam"],
        "the hague": ["NL": "rotterdam"],
        "den haag": ["NL": "rotterdam"],
        "delft": ["NL": "rotterdam"],
        "ghent": ["BE": "bruges"],
        "gent": ["BE": "bruges"],
        "leuven": ["BE": "brussels"],
        "mechelen": ["BE": "brussels"],
        "winterthur": ["CH": "zurich"],
        "zug": ["CH": "zurich"],
        "baden": ["CH": "zurich"],
        "interlaken": ["CH": "lucerne"],
        "grindelwald": ["CH": "lucerne"],
        "lauterbrunnen": ["CH": "lucerne"],
        "zermatt": ["CH": "lucerne"],
        "lausanne": ["CH": "geneva"],
        "montreux": ["CH": "geneva"],
        "vevey": ["CH": "geneva"],
        "salzburg": ["AT": "vienna"],
        "innsbruck": ["AT": "vienna"],
        "hallstatt": ["AT": "vienna"],
        "vatican": ["IT": "rome", "VA": "rome"],
        "vatican city": ["IT": "rome", "VA": "rome"],
        "fiumicino": ["IT": "rome"],
        "tivoli": ["IT": "rome"],
        "como": ["IT": "milan"],
        "lake como": ["IT": "milan"],
        "bergamo": ["IT": "milan"],
        "monza": ["IT": "milan"],
        "pisa": ["IT": "florence"],
        "siena": ["IT": "florence"],
        "lucca": ["IT": "florence"],
        "cinque terre": ["IT": "florence"],
        "murano": ["IT": "venice"],
        "burano": ["IT": "venice"],
        "mestre": ["IT": "venice"],
        "lido": ["IT": "venice"],
        "badalona": ["ES": "barcelona"],
        "l'hospitalet": ["ES": "barcelona"],
        "sitges": ["ES": "barcelona"],
        "girona": ["ES": "barcelona"],
        "montserrat": ["ES": "barcelona"],
        "toledo": ["ES": "madrid"],
        "segovia": ["ES": "madrid"],
        "getafe": ["ES": "madrid"],
        "granada": ["ES": "seville"],
        "cordoba": ["ES": "seville"],
        "córdoba": ["ES": "seville"],
        "malaga": ["ES": "seville"],
        "málaga": ["ES": "seville"],
        "marbella": ["ES": "seville"],
        "sintra": ["PT": "lisbon"],
        "cascais": ["PT": "lisbon"],
        "oeiras": ["PT": "lisbon"],
        "almada": ["PT": "lisbon"],
        "estoril": ["PT": "lisbon"],
        "vila nova de gaia": ["PT": "porto"],
        "gaia": ["PT": "porto"],
        "braga": ["PT": "porto"],
        "piraeus": ["GR": "athens"],
        "glyfada": ["GR": "athens"],
        "oia": ["GR": "santorini"],
        "fira": ["GR": "santorini"],
        "mykonos": ["GR": "santorini"],

        // Middle East, Africa & Latin America
        "sharjah": ["AE": "dubai"],
        "ajman": ["AE": "dubai"],
        "palm jumeirah": ["AE": "dubai"],
        "al ain": ["AE": "abu dhabi"],
        "yas island": ["AE": "abu dhabi"],
        "jeddah": ["SA": "riyadh"],
        "dammam": ["SA": "riyadh"],
        "khobar": ["SA": "riyadh"],
        "lusail": ["QA": "doha"],
        "al wakrah": ["QA": "doha"],
        "al rayyan": ["QA": "doha"],
        "jaffa": ["IL": "tel aviv"],
        "ramat gan": ["IL": "tel aviv"],
        "herzliya": ["IL": "tel aviv"],
        "givatayim": ["IL": "tel aviv"],
        "bat yam": ["IL": "tel aviv"],
        "holon": ["IL": "tel aviv"],
        "rishon lezion": ["IL": "tel aviv"],
        "petah tikva": ["IL": "tel aviv"],
        "netanya": ["IL": "tel aviv"],
        "giza": ["EG": "cairo"],
        "new cairo": ["EG": "cairo"],
        "6th of october": ["EG": "cairo"],
        "sheikh zayed": ["EG": "cairo"],
        "stellenbosch": ["ZA": "cape town"],
        "franschhoek": ["ZA": "cape town"],
        "camps bay": ["ZA": "cape town"],
        "guarulhos": ["BR": "sao paulo"],
        "campinas": ["BR": "sao paulo"],
        "santo andre": ["BR": "sao paulo"],
        "sao bernardo do campo": ["BR": "sao paulo"],
        "osasco": ["BR": "sao paulo"],
        "santos": ["BR": "sao paulo"],
        "niteroi": ["BR": "rio de janeiro"],
        "petropolis": ["BR": "rio de janeiro"],
        "buzios": ["BR": "rio de janeiro"],
        "copacabana": ["BR": "rio de janeiro"],
        "ipanema": ["BR": "rio de janeiro"],
        "tigre": ["AR": "buenos aires"],
        "san isidro": ["AR": "buenos aires", "PE": "lima"],
        "vicente lopez": ["AR": "buenos aires"],
        "avellaneda": ["AR": "buenos aires"],
        "la plata": ["AR": "buenos aires"],
        "palermo": ["AR": "buenos aires"],
        "recoleta": ["AR": "buenos aires"],
        "providencia": ["CL": "santiago"],
        "las condes": ["CL": "santiago"],
        "vitacura": ["CL": "santiago"],
        "valparaiso": ["CL": "santiago"],
        "vina del mar": ["CL": "santiago"],
        "miraflores": ["PE": "lima"],
        "barranco": ["PE": "lima"],
        "callao": ["PE": "lima"],
        "machu picchu": ["PE": "cusco"],
        "aguas calientes": ["PE": "cusco"],
        "ollantaytambo": ["PE": "cusco"],
        "urubamba": ["PE": "cusco"],
        "envigado": ["CO": "medellin"],
        "sabaneta": ["CO": "medellin"],
        "itagui": ["CO": "medellin"],
        "bello": ["CO": "medellin"],
        "rionegro": ["CO": "medellin"],
        "guatape": ["CO": "medellin"],
        "chia": ["CO": "bogota"],
        "zipaquira": ["CO": "bogota"],
        "naucalpan": ["MX": "mexico city"],
        "tlalnepantla": ["MX": "mexico city"],
        "ecatepec": ["MX": "mexico city"],
        "coyoacan": ["MX": "mexico city"],
        "polanco": ["MX": "mexico city"],
        "condesa": ["MX": "mexico city"],
        "teotihuacan": ["MX": "mexico city"],
        "playa del carmen": ["MX": "cancun"],
        "tulum": ["MX": "cancun"],
        "cozumel": ["MX": "cancun"],
        "isla mujeres": ["MX": "cancun"],
        "riviera maya": ["MX": "cancun"],
        "zapopan": ["MX": "guadalajara"],
        "tlaquepaque": ["MX": "guadalajara"],
        "tonala": ["MX": "guadalajara"],
        "tequila": ["MX": "guadalajara"],
        "san pedro garza garcia": ["MX": "monterrey"],
        "guadalupe": ["MX": "monterrey"],
        "apodaca": ["MX": "monterrey"],
        "san nicolas": ["MX": "monterrey"]
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
        case .alpineChalet, .alpine: return "City_generic_block" // Chalet artwork withheld: transparent holes in the roof.
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
        let areaKey = CityIdentity.presencePart(administrativeArea ?? "")
        let normArea = (CityRegionCatalog.bundled.administrativeAliases?[normCountry]?[areaKey] ?? areaKey).uppercased()
        // Missing metadata is not permission to assume a country/state from a city name.
        guard !normCountry.isEmpty, normCountry != "US" || !normArea.isEmpty else { return .metropolis }

        // Tier 1: Explicit Curated Sub-Regional Dictionary
        if normCountry == "US" {
            let isCA = normArea == "CA" || normArea == "CALIFORNIA"

            // Central Valley (CA)
            let centralValleyCities: Set<String> = [
                "bakersfield", "fresno", "modesto", "stockton", "visalia", "merced", "clovis",
                "turlock", "chico", "redding", "tulare", "hanford", "delano", "porterville",
                "madera", "lodi", "tracy", "manteca"
            ]
            if isCA && centralValleyCities.contains(normCity) {
                return .centralValley
            }

            // Silicon Valley & Bay Area Suburbs (CA) & Seattle tech hubs (WA)
            let siliconValleyCities: Set<String> = [
                "fremont", "palo alto", "sunnyvale", "cupertino", "mountain view", "santa clara",
                "san mateo", "redwood city", "menlo park", "los altos", "milpitas", "foster city",
                "san carlos", "burlingame", "belmont", "pleasanton", "dublin", "san ramon",
                "walnut creek"
            ]
            if (isCA && siliconValleyCities.contains(normCity)) ||
                (normArea == "WA" && ["bellevue", "redmond", "kirkland"].contains(normCity)) {
                return .siliconValley
            }

            // Pacific Surf Coast
            let surfCities: Set<String> = [
                "santa cruz", "malibu", "laguna beach", "encinitas", "huntington beach",
                "newport beach", "carlsbad", "oceanside", "san clemente", "half moon bay",
                "monterey", "carmel", "pacific grove", "santa barbara", "ventura", "carpinteria",
                "morro bay", "pismo beach", "capitola"
            ]
            if isCA && surfCities.contains(normCity) {
                return .pacificSurf
            }

            // Alpine Mountain Towns
            let alpineCities: [String: Set<String>] = [
                "CA": ["lake tahoe", "south lake tahoe", "truckee", "mammoth lakes", "big bear lake"],
                "CO": ["aspen", "vail", "breckenridge", "boulder", "steamboat springs", "telluride"],
                "UT": ["park city"], "WY": ["jackson"]
            ]
            if alpineCities[normArea]?.contains(normCity) == true { return .alpineChalet }

            let desertCities: [String: Set<String>] = [
                "CA": ["palm springs", "joshua tree", "indio", "cathedral city", "desert hot springs", "palm desert", "la quinta"],
                "AZ": ["sedona", "scottsdale", "tucson", "mesa", "tempe", "chandler", "yuma"],
                "NM": ["santa fe", "taos", "albuquerque"], "UT": ["moab"]
            ]
            if desertCities[normArea]?.contains(normCity) == true { return .desertAdobe }
        }

        // Exact country-scoped names; an international namesake must not inherit another country's artwork.
        let internationalSurf: [String: Set<String>] = [
            "AU": ["byron bay", "gold coast", "noosa", "torquay"], "FR": ["biarritz"]
        ]
        if internationalSurf[normCountry]?.contains(normCity) == true { return .pacificSurf }
        let internationalAlpine: [String: Set<String>] = [
            "CH": ["zermatt", "st. moritz", "grindelwald", "interlaken"], "FR": ["chamonix"],
            "AT": ["innsbruck"], "CA": ["whistler", "banff"], "IT": ["cortina d'ampezzo"],
            "JP": ["nagano", "hakuba", "niseko"]
        ]
        if internationalAlpine[normCountry]?.contains(normCity) == true { return .alpineChalet }
        let internationalHistoric: [String: Set<String>] = [
            "GB": ["oxford", "cambridge", "bath", "york", "cotswolds", "edinburgh", "durham", "canterbury", "stratford-upon-avon", "chester"],
            "DE": ["heidelberg", "rothenburg", "bamberg", "weimar"], "BE": ["bruges", "ghent"],
            "AT": ["salzburg"], "ES": ["toledo"], "IT": ["siena"]
        ]
        if internationalHistoric[normCountry]?.contains(normCity) == true { return .historicBrick }

        // Tier 2: State / Regional Heuristics
        if normCountry == "US" {
            if ["AZ", "NM", "NV"].contains(normArea) { return .desertAdobe }
            if ["CO", "UT", "WY", "MT", "ID", "VT"].contains(normArea) { return .alpineChalet }
            if ["WA", "OR"].contains(normArea) { return .siliconValley }
            if ["HI", "FL"].contains(normArea) { return .pacificSurf }
            if ["IA", "KS", "NE", "OK", "ND", "SD"].contains(normArea) { return .centralValley }
            if ["ME", "NH", "MA", "RI", "CT"].contains(normArea) { return .historicBrick }
        }

        // Treat complete words as decorative motifs; never match fragments such as "ski" in a name.
        let words = Set(normCity.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        if !words.isDisjoint(with: ["beach", "coast", "surf", "shore", "island", "cove", "bay", "key"]) { return .pacificSurf }
        if !words.isDisjoint(with: ["mountain", "mount", "peak", "alpine", "summit", "ridge", "ski"]) { return .alpineChalet }
        if !words.isDisjoint(with: ["desert", "adobe", "dune", "canyon", "mesa"]) { return .desertAdobe }
        if !words.isDisjoint(with: ["valley", "prairie", "plains", "ranch", "farm", "field"]) { return .centralValley }
        if !words.isDisjoint(with: ["village", "castle", "abbey"]) { return .historicBrick }

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
        if emblem.cityID != "unknown" { return UIImage(named: "City_generic_block") ?? UIImage(named: "CityEmblems/City_generic_block") }
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
