import CoreLocation
import Foundation

struct AirportLocation: Identifiable, Sendable, Hashable {
    var id: String { code }
    let code: String
    let name: String
    let city: String
    let country: String
    let countryCode: String
    let coordinate: CLLocationCoordinate2D
    let timeZoneIdentifier: String

    init(code: String, city: String, country: String = "United States", countryCode: String = "US", coordinate: CLLocationCoordinate2D) {
        self.code = code
        self.name = "\(city) Airport"
        self.city = city
        self.country = country
        self.countryCode = countryCode
        self.coordinate = coordinate
        self.timeZoneIdentifier = "America/Los_Angeles"
    }

    init(code: String, name: String, city: String, country: String, countryCode: String, coordinate: CLLocationCoordinate2D, timeZoneIdentifier: String) {
        self.code = code
        self.name = name
        self.city = city
        self.country = country
        self.countryCode = countryCode
        self.coordinate = coordinate
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }

    static func == (lhs: AirportLocation, rhs: AirportLocation) -> Bool {
        lhs.code == rhs.code
    }

    var flag: String {
        guard countryCode.count == 2 else { return "" }
        let base: UInt32 = 127_397
        return countryCode.uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(base + scalar.value).map(String.init)
        }.joined()
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0) ?? .gmt
    }

    func matches(_ query: String) -> Bool {
        let q = query.lowercased()
        return code.lowercased().contains(q) ||
               city.lowercased().contains(q) ||
               name.lowercased().contains(q) ||
               country.lowercased().contains(q)
    }

    static let popularCodes: [String] = [
        "PSP", "JFK", "SFO", "LAX", "NRT", "HND", "LHR", "CDG", "HNL", "SEA", "ORD", "AMS", "SIN", "SYD"
    ]

    static var popularList: [AirportLocation] {
        popularCodes.compactMap { directory[$0] }
    }

    static var allList: [AirportLocation] {
        directory.values.sorted { $0.city == $1.city ? $0.code < $1.code : $0.city < $1.city }
    }

    static func location(for code: String) -> AirportLocation? {
        directory[code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()]
    }

    static func search(_ query: String) -> [AirportLocation] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return popularList }

        var results: [AirportLocation] = []
        var seen = Set<String>()

        // 1. Exact IATA code match
        if let exact = location(for: q) {
            results.append(exact)
            seen.insert(exact.code)
        }

        // 2. City prefix matches
        let cityPrefixMatches = allList.filter {
            !seen.contains($0.code) && $0.city.lowercased().hasPrefix(q)
        }.sorted { $0.city < $1.city }
        for item in cityPrefixMatches {
            results.append(item)
            seen.insert(item.code)
        }

        // 3. Airport code prefix matches
        let codePrefixMatches = allList.filter {
            !seen.contains($0.code) && $0.code.lowercased().hasPrefix(q)
        }.sorted { $0.code < $1.code }
        for item in codePrefixMatches {
            results.append(item)
            seen.insert(item.code)
        }

        // 4. Other matches (city, airport name, country contains)
        let otherMatches = allList.filter {
            !seen.contains($0.code) && $0.matches(q)
        }.sorted { $0.city == $1.city ? $0.code < $1.code : $0.city < $1.city }
        results.append(contentsOf: otherMatches)

        return results
    }

    static let directory: [String: AirportLocation] = [
        "PSP": AirportLocation(code: "PSP", name: "Palm Springs International Airport", city: "Palm Springs", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 33.8297, longitude: -116.5067), timeZoneIdentifier: "America/Los_Angeles"),
        "LAX": AirportLocation(code: "LAX", name: "Los Angeles International Airport", city: "Los Angeles", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 33.9416, longitude: -118.4085), timeZoneIdentifier: "America/Los_Angeles"),
        "SFO": AirportLocation(code: "SFO", name: "San Francisco International Airport", city: "San Francisco", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 37.6213, longitude: -122.379), timeZoneIdentifier: "America/Los_Angeles"),
        "OAK": AirportLocation(code: "OAK", name: "Oakland International Airport", city: "Oakland", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 37.7213, longitude: -122.2207), timeZoneIdentifier: "America/Los_Angeles"),
        "SJC": AirportLocation(code: "SJC", name: "Norman Y. Mineta San Jose International Airport", city: "San Jose", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 37.3619, longitude: -121.929), timeZoneIdentifier: "America/Los_Angeles"),
        "SAN": AirportLocation(code: "SAN", name: "San Diego International Airport", city: "San Diego", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 32.7338, longitude: -117.1933), timeZoneIdentifier: "America/Los_Angeles"),
        "SNA": AirportLocation(code: "SNA", name: "John Wayne Airport", city: "Orange County", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 33.6757, longitude: -117.8675), timeZoneIdentifier: "America/Los_Angeles"),
        "BUR": AirportLocation(code: "BUR", name: "Hollywood Burbank Airport", city: "Burbank", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 34.2007, longitude: -118.3587), timeZoneIdentifier: "America/Los_Angeles"),
        "ONT": AirportLocation(code: "ONT", name: "Ontario International Airport", city: "Ontario", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 34.056, longitude: -117.6012), timeZoneIdentifier: "America/Los_Angeles"),
        "SMF": AirportLocation(code: "SMF", name: "Sacramento International Airport", city: "Sacramento", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 38.6954, longitude: -121.5908), timeZoneIdentifier: "America/Los_Angeles"),
        "SBA": AirportLocation(code: "SBA", name: "Santa Barbara Municipal Airport", city: "Santa Barbara", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 34.4262, longitude: -119.8404), timeZoneIdentifier: "America/Los_Angeles"),
        "FAT": AirportLocation(code: "FAT", name: "Fresno Yosemite International Airport", city: "Fresno", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 36.7762, longitude: -119.7181), timeZoneIdentifier: "America/Los_Angeles"),
        "LAS": AirportLocation(code: "LAS", name: "Harry Reid International Airport", city: "Las Vegas", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 36.084, longitude: -115.1537), timeZoneIdentifier: "America/Los_Angeles"),
        "RNO": AirportLocation(code: "RNO", name: "Reno-Tahoe International Airport", city: "Reno", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.4991, longitude: -119.7681), timeZoneIdentifier: "America/Los_Angeles"),
        "PHX": AirportLocation(code: "PHX", name: "Phoenix Sky Harbor International Airport", city: "Phoenix", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 33.4373, longitude: -112.0078), timeZoneIdentifier: "America/Phoenix"),
        "TUS": AirportLocation(code: "TUS", name: "Tucson International Airport", city: "Tucson", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 32.1161, longitude: -110.941), timeZoneIdentifier: "America/Phoenix"),
        "SLC": AirportLocation(code: "SLC", name: "Salt Lake City International Airport", city: "Salt Lake City", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 40.7899, longitude: -111.9791), timeZoneIdentifier: "America/Denver"),
        "DEN": AirportLocation(code: "DEN", name: "Denver International Airport", city: "Denver", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.8561, longitude: -104.6737), timeZoneIdentifier: "America/Denver"),
        "ASE": AirportLocation(code: "ASE", name: "Aspen/Pitkin County Airport", city: "Aspen", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.2232, longitude: -106.8688), timeZoneIdentifier: "America/Denver"),
        "EGE": AirportLocation(code: "EGE", name: "Eagle County Regional Airport", city: "Vail", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.6426, longitude: -106.9177), timeZoneIdentifier: "America/Denver"),
        "JAC": AirportLocation(code: "JAC", name: "Jackson Hole Airport", city: "Jackson Hole", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 43.6073, longitude: -110.7377), timeZoneIdentifier: "America/Denver"),
        "BZN": AirportLocation(code: "BZN", name: "Bozeman Yellowstone International Airport", city: "Bozeman", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 45.7772, longitude: -111.153), timeZoneIdentifier: "America/Denver"),
        "BOI": AirportLocation(code: "BOI", name: "Boise Airport", city: "Boise", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 43.5644, longitude: -116.2228), timeZoneIdentifier: "America/Boise"),
        "ABQ": AirportLocation(code: "ABQ", name: "Albuquerque International Sunport", city: "Albuquerque", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 35.0402, longitude: -106.6092), timeZoneIdentifier: "America/Denver"),
        "SEA": AirportLocation(code: "SEA", name: "Seattle-Tacoma International Airport", city: "Seattle", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 47.4502, longitude: -122.3088), timeZoneIdentifier: "America/Los_Angeles"),
        "PDX": AirportLocation(code: "PDX", name: "Portland International Airport", city: "Portland", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 45.5898, longitude: -122.5951), timeZoneIdentifier: "America/Los_Angeles"),
        "HNL": AirportLocation(code: "HNL", name: "Daniel K. Inouye International Airport", city: "Honolulu", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 21.3187, longitude: -157.9224), timeZoneIdentifier: "Pacific/Honolulu"),
        "OGG": AirportLocation(code: "OGG", name: "Kahului Airport", city: "Maui", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 20.8986, longitude: -156.4305), timeZoneIdentifier: "Pacific/Honolulu"),
        "KOA": AirportLocation(code: "KOA", name: "Ellison Onizuka Kona International Airport", city: "Kona", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 19.7388, longitude: -156.0456), timeZoneIdentifier: "Pacific/Honolulu"),
        "LIH": AirportLocation(code: "LIH", name: "Lihue Airport", city: "Kauai", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 21.976, longitude: -159.339), timeZoneIdentifier: "Pacific/Honolulu"),
        "ANC": AirportLocation(code: "ANC", name: "Ted Stevens Anchorage International Airport", city: "Anchorage", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 61.1743, longitude: -149.9962), timeZoneIdentifier: "America/Anchorage"),
        "ORD": AirportLocation(code: "ORD", name: "O'Hare International Airport", city: "Chicago", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 41.9742, longitude: -87.9073), timeZoneIdentifier: "America/Chicago"),
        "MDW": AirportLocation(code: "MDW", name: "Chicago Midway International Airport", city: "Chicago", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 41.7868, longitude: -87.7522), timeZoneIdentifier: "America/Chicago"),
        "MSP": AirportLocation(code: "MSP", name: "Minneapolis-Saint Paul International Airport", city: "Minneapolis", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 44.8848, longitude: -93.2223), timeZoneIdentifier: "America/Chicago"),
        "DTW": AirportLocation(code: "DTW", name: "Detroit Metropolitan Wayne County Airport", city: "Detroit", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 42.2162, longitude: -83.3554), timeZoneIdentifier: "America/Detroit"),
        "IND": AirportLocation(code: "IND", name: "Indianapolis International Airport", city: "Indianapolis", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.7173, longitude: -86.2944), timeZoneIdentifier: "America/Indiana/Indianapolis"),
        "CLE": AirportLocation(code: "CLE", name: "Cleveland Hopkins International Airport", city: "Cleveland", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 41.4108, longitude: -81.8494), timeZoneIdentifier: "America/New_York"),
        "CMH": AirportLocation(code: "CMH", name: "John Glenn Columbus International Airport", city: "Columbus", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.998, longitude: -82.8919), timeZoneIdentifier: "America/New_York"),
        "CVG": AirportLocation(code: "CVG", name: "Cincinnati/Northern Kentucky International Airport", city: "Cincinnati", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.0461, longitude: -84.6622), timeZoneIdentifier: "America/New_York"),
        "STL": AirportLocation(code: "STL", name: "St. Louis Lambert International Airport", city: "St. Louis", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 38.7487, longitude: -90.37), timeZoneIdentifier: "America/Chicago"),
        "MCI": AirportLocation(code: "MCI", name: "Kansas City International Airport", city: "Kansas City", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.2976, longitude: -94.7139), timeZoneIdentifier: "America/Chicago"),
        "MKE": AirportLocation(code: "MKE", name: "Milwaukee Mitchell International Airport", city: "Milwaukee", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 42.9475, longitude: -87.8966), timeZoneIdentifier: "America/Chicago"),
        "DFW": AirportLocation(code: "DFW", name: "Dallas/Fort Worth International Airport", city: "Dallas", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 32.8998, longitude: -97.0403), timeZoneIdentifier: "America/Chicago"),
        "DAL": AirportLocation(code: "DAL", name: "Dallas Love Field", city: "Dallas", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 32.8471, longitude: -96.8518), timeZoneIdentifier: "America/Chicago"),
        "IAH": AirportLocation(code: "IAH", name: "George Bush Intercontinental Airport", city: "Houston", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 29.9902, longitude: -95.3368), timeZoneIdentifier: "America/Chicago"),
        "HOU": AirportLocation(code: "HOU", name: "William P. Hobby Airport", city: "Houston", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 29.6454, longitude: -95.2789), timeZoneIdentifier: "America/Chicago"),
        "AUS": AirportLocation(code: "AUS", name: "Austin-Bergstrom International Airport", city: "Austin", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 30.1975, longitude: -97.6664), timeZoneIdentifier: "America/Chicago"),
        "SAT": AirportLocation(code: "SAT", name: "San Antonio International Airport", city: "San Antonio", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 29.5337, longitude: -98.4698), timeZoneIdentifier: "America/Chicago"),
        "MSY": AirportLocation(code: "MSY", name: "Louis Armstrong New Orleans International Airport", city: "New Orleans", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 29.9934, longitude: -90.258), timeZoneIdentifier: "America/Chicago"),
        "BNA": AirportLocation(code: "BNA", name: "Nashville International Airport", city: "Nashville", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 36.1245, longitude: -86.6782), timeZoneIdentifier: "America/Chicago"),
        "MEM": AirportLocation(code: "MEM", name: "Memphis International Airport", city: "Memphis", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 35.0424, longitude: -89.9767), timeZoneIdentifier: "America/Chicago"),
        "JFK": AirportLocation(code: "JFK", name: "John F. Kennedy International Airport", city: "New York", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 40.6413, longitude: -73.7781), timeZoneIdentifier: "America/New_York"),
        "EWR": AirportLocation(code: "EWR", name: "Newark Liberty International Airport", city: "New York", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 40.6895, longitude: -74.1745), timeZoneIdentifier: "America/New_York"),
        "LGA": AirportLocation(code: "LGA", name: "LaGuardia Airport", city: "New York", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 40.7769, longitude: -73.874), timeZoneIdentifier: "America/New_York"),
        "BOS": AirportLocation(code: "BOS", name: "Logan International Airport", city: "Boston", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 42.3656, longitude: -71.0096), timeZoneIdentifier: "America/New_York"),
        "PHL": AirportLocation(code: "PHL", name: "Philadelphia International Airport", city: "Philadelphia", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.8729, longitude: -75.2409), timeZoneIdentifier: "America/New_York"),
        "BWI": AirportLocation(code: "BWI", name: "Baltimore/Washington International Thurgood Marshall Airport", city: "Baltimore", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 39.1754, longitude: -76.6683), timeZoneIdentifier: "America/New_York"),
        "IAD": AirportLocation(code: "IAD", name: "Washington Dulles International Airport", city: "Washington, D.C.", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 38.9531, longitude: -77.4565), timeZoneIdentifier: "America/New_York"),
        "DCA": AirportLocation(code: "DCA", name: "Ronald Reagan Washington National Airport", city: "Washington, D.C.", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 38.8512, longitude: -77.0402), timeZoneIdentifier: "America/New_York"),
        "ATL": AirportLocation(code: "ATL", name: "Hartsfield-Jackson Atlanta International Airport", city: "Atlanta", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 33.6407, longitude: -84.4277), timeZoneIdentifier: "America/New_York"),
        "CLT": AirportLocation(code: "CLT", name: "Charlotte Douglas International Airport", city: "Charlotte", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 35.214, longitude: -80.9431), timeZoneIdentifier: "America/New_York"),
        "RDU": AirportLocation(code: "RDU", name: "Raleigh-Durham International Airport", city: "Raleigh", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 35.8801, longitude: -78.788), timeZoneIdentifier: "America/New_York"),
        "MIA": AirportLocation(code: "MIA", name: "Miami International Airport", city: "Miami", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 25.7959, longitude: -80.287), timeZoneIdentifier: "America/New_York"),
        "FLL": AirportLocation(code: "FLL", name: "Fort Lauderdale-Hollywood International Airport", city: "Fort Lauderdale", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 26.0742, longitude: -80.1506), timeZoneIdentifier: "America/New_York"),
        "PBI": AirportLocation(code: "PBI", name: "Palm Beach International Airport", city: "West Palm Beach", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 26.6832, longitude: -80.0956), timeZoneIdentifier: "America/New_York"),
        "MCO": AirportLocation(code: "MCO", name: "Orlando International Airport", city: "Orlando", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 28.4312, longitude: -81.3081), timeZoneIdentifier: "America/New_York"),
        "TPA": AirportLocation(code: "TPA", name: "Tampa International Airport", city: "Tampa", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 27.9755, longitude: -82.5332), timeZoneIdentifier: "America/New_York"),
        "RSW": AirportLocation(code: "RSW", name: "Southwest Florida International Airport", city: "Fort Myers", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 26.5362, longitude: -81.7552), timeZoneIdentifier: "America/New_York"),
        "JAX": AirportLocation(code: "JAX", name: "Jacksonville International Airport", city: "Jacksonville", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 30.4941, longitude: -81.6879), timeZoneIdentifier: "America/New_York"),
        "SAV": AirportLocation(code: "SAV", name: "Savannah/Hilton Head International Airport", city: "Savannah", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 32.1276, longitude: -81.2021), timeZoneIdentifier: "America/New_York"),
        "CHS": AirportLocation(code: "CHS", name: "Charleston International Airport", city: "Charleston", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 32.8986, longitude: -80.0405), timeZoneIdentifier: "America/New_York"),
        "RIC": AirportLocation(code: "RIC", name: "Richmond International Airport", city: "Richmond", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 37.5052, longitude: -77.3197), timeZoneIdentifier: "America/New_York"),
        "BDL": AirportLocation(code: "BDL", name: "Bradley International Airport", city: "Hartford", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 41.9389, longitude: -72.6832), timeZoneIdentifier: "America/New_York"),
        "PWM": AirportLocation(code: "PWM", name: "Portland International Jetport", city: "Portland, ME", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 43.6462, longitude: -70.3093), timeZoneIdentifier: "America/New_York"),
        "BTV": AirportLocation(code: "BTV", name: "Patrick Leahy Burlington International Airport", city: "Burlington", country: "United States", countryCode: "US", coordinate: CLLocationCoordinate2D(latitude: 44.473, longitude: -73.1503), timeZoneIdentifier: "America/New_York"),
        "YVR": AirportLocation(code: "YVR", name: "Vancouver International Airport", city: "Vancouver", country: "Canada", countryCode: "CA", coordinate: CLLocationCoordinate2D(latitude: 49.1967, longitude: -123.1815), timeZoneIdentifier: "America/Vancouver"),
        "YYZ": AirportLocation(code: "YYZ", name: "Toronto Pearson International Airport", city: "Toronto", country: "Canada", countryCode: "CA", coordinate: CLLocationCoordinate2D(latitude: 43.6777, longitude: -79.6248), timeZoneIdentifier: "America/Toronto"),
        "YUL": AirportLocation(code: "YUL", name: "Montréal-Trudeau International Airport", city: "Montreal", country: "Canada", countryCode: "CA", coordinate: CLLocationCoordinate2D(latitude: 45.4657, longitude: -73.7455), timeZoneIdentifier: "America/Toronto"),
        "YYC": AirportLocation(code: "YYC", name: "Calgary International Airport", city: "Calgary", country: "Canada", countryCode: "CA", coordinate: CLLocationCoordinate2D(latitude: 51.1215, longitude: -114.0076), timeZoneIdentifier: "America/Edmonton"),
        "YEG": AirportLocation(code: "YEG", name: "Edmonton International Airport", city: "Edmonton", country: "Canada", countryCode: "CA", coordinate: CLLocationCoordinate2D(latitude: 53.3097, longitude: -113.5798), timeZoneIdentifier: "America/Edmonton"),
        "YOW": AirportLocation(code: "YOW", name: "Ottawa Macdonald-Cartier International Airport", city: "Ottawa", country: "Canada", countryCode: "CA", coordinate: CLLocationCoordinate2D(latitude: 45.3225, longitude: -75.6672), timeZoneIdentifier: "America/Toronto"),
        "YHZ": AirportLocation(code: "YHZ", name: "Halifax Stanfield International Airport", city: "Halifax", country: "Canada", countryCode: "CA", coordinate: CLLocationCoordinate2D(latitude: 44.8808, longitude: -63.5086), timeZoneIdentifier: "America/Halifax"),
        "YQB": AirportLocation(code: "YQB", name: "Québec City Jean Lesage International Airport", city: "Quebec City", country: "Canada", countryCode: "CA", coordinate: CLLocationCoordinate2D(latitude: 46.7911, longitude: -71.3933), timeZoneIdentifier: "America/Toronto"),
        "YYJ": AirportLocation(code: "YYJ", name: "Victoria International Airport", city: "Victoria", country: "Canada", countryCode: "CA", coordinate: CLLocationCoordinate2D(latitude: 48.6469, longitude: -123.4258), timeZoneIdentifier: "America/Vancouver"),
        "CUN": AirportLocation(code: "CUN", name: "Cancún International Airport", city: "Cancún", country: "Mexico", countryCode: "MX", coordinate: CLLocationCoordinate2D(latitude: 21.0365, longitude: -86.8771), timeZoneIdentifier: "America/Cancun"),
        "MEX": AirportLocation(code: "MEX", name: "Mexico City International Airport", city: "Mexico City", country: "Mexico", countryCode: "MX", coordinate: CLLocationCoordinate2D(latitude: 19.4361, longitude: -99.0719), timeZoneIdentifier: "America/Mexico_City"),
        "SJD": AirportLocation(code: "SJD", name: "Los Cabos International Airport", city: "San José del Cabo", country: "Mexico", countryCode: "MX", coordinate: CLLocationCoordinate2D(latitude: 23.1518, longitude: -109.7214), timeZoneIdentifier: "America/Mazatlan"),
        "PVR": AirportLocation(code: "PVR", name: "Licenciado Gustavo Díaz Ordaz International Airport", city: "Puerto Vallarta", country: "Mexico", countryCode: "MX", coordinate: CLLocationCoordinate2D(latitude: 20.6801, longitude: -105.2542), timeZoneIdentifier: "America/Mexico_City"),
        "GDL": AirportLocation(code: "GDL", name: "Guadalajara International Airport", city: "Guadalajara", country: "Mexico", countryCode: "MX", coordinate: CLLocationCoordinate2D(latitude: 20.5218, longitude: -103.3112), timeZoneIdentifier: "America/Mexico_City"),
        "MTY": AirportLocation(code: "MTY", name: "Monterrey International Airport", city: "Monterrey", country: "Mexico", countryCode: "MX", coordinate: CLLocationCoordinate2D(latitude: 25.7785, longitude: -100.1069), timeZoneIdentifier: "America/Monterrey"),
        "SJU": AirportLocation(code: "SJU", name: "Luis Muñoz Marín International Airport", city: "San Juan", country: "Puerto Rico", countryCode: "PR", coordinate: CLLocationCoordinate2D(latitude: 18.4394, longitude: -66.0018), timeZoneIdentifier: "America/Puerto_Rico"),
        "NAS": AirportLocation(code: "NAS", name: "Lynden Pindling International Airport", city: "Nassau", country: "Bahamas", countryCode: "BS", coordinate: CLLocationCoordinate2D(latitude: 25.039, longitude: -77.4662), timeZoneIdentifier: "America/Nassau"),
        "MBJ": AirportLocation(code: "MBJ", name: "Sangster International Airport", city: "Montego Bay", country: "Jamaica", countryCode: "JM", coordinate: CLLocationCoordinate2D(latitude: 18.5037, longitude: -77.9134), timeZoneIdentifier: "America/Jamaica"),
        "PUJ": AirportLocation(code: "PUJ", name: "Punta Cana International Airport", city: "Punta Cana", country: "Dominican Republic", countryCode: "DO", coordinate: CLLocationCoordinate2D(latitude: 18.5674, longitude: -68.3634), timeZoneIdentifier: "America/Santo_Domingo"),
        "SXM": AirportLocation(code: "SXM", name: "Princess Juliana International Airport", city: "Sint Maarten", country: "Sint Maarten", countryCode: "SX", coordinate: CLLocationCoordinate2D(latitude: 18.041, longitude: -63.1089), timeZoneIdentifier: "America/Anguilla"),
        "AUA": AirportLocation(code: "AUA", name: "Queen Beatrix International Airport", city: "Aruba", country: "Aruba", countryCode: "AW", coordinate: CLLocationCoordinate2D(latitude: 12.5014, longitude: -70.0152), timeZoneIdentifier: "America/Aruba"),
        "PTY": AirportLocation(code: "PTY", name: "Tocumen International Airport", city: "Panama City", country: "Panama", countryCode: "PA", coordinate: CLLocationCoordinate2D(latitude: 9.0714, longitude: -79.3835), timeZoneIdentifier: "America/Panama"),
        "SJO": AirportLocation(code: "SJO", name: "Juan Santamaría International Airport", city: "San José", country: "Costa Rica", countryCode: "CR", coordinate: CLLocationCoordinate2D(latitude: 9.9939, longitude: -84.2089), timeZoneIdentifier: "America/Costa_Rica"),
        "BOG": AirportLocation(code: "BOG", name: "El Dorado International Airport", city: "Bogotá", country: "Colombia", countryCode: "CO", coordinate: CLLocationCoordinate2D(latitude: 4.7016, longitude: -74.1469), timeZoneIdentifier: "America/Bogota"),
        "MDE": AirportLocation(code: "MDE", name: "José María Córdova International Airport", city: "Medellín", country: "Colombia", countryCode: "CO", coordinate: CLLocationCoordinate2D(latitude: 6.1645, longitude: -75.4231), timeZoneIdentifier: "America/Bogota"),
        "LIM": AirportLocation(code: "LIM", name: "Jorge Chávez International Airport", city: "Lima", country: "Peru", countryCode: "PE", coordinate: CLLocationCoordinate2D(latitude: -12.0219, longitude: -77.1143), timeZoneIdentifier: "America/Lima"),
        "CUZ": AirportLocation(code: "CUZ", name: "Alejandro Velasco Astete International Airport", city: "Cusco", country: "Peru", countryCode: "PE", coordinate: CLLocationCoordinate2D(latitude: -13.5357, longitude: -71.9388), timeZoneIdentifier: "America/Lima"),
        "SCL": AirportLocation(code: "SCL", name: "Arturo Merino Benítez International Airport", city: "Santiago", country: "Chile", countryCode: "CL", coordinate: CLLocationCoordinate2D(latitude: -33.393, longitude: -70.7858), timeZoneIdentifier: "America/Santiago"),
        "EZE": AirportLocation(code: "EZE", name: "Ministro Pistarini International Airport", city: "Buenos Aires", country: "Argentina", countryCode: "AR", coordinate: CLLocationCoordinate2D(latitude: -34.8222, longitude: -58.5358), timeZoneIdentifier: "America/Argentina/Buenos_Aires"),
        "GRU": AirportLocation(code: "GRU", name: "São Paulo/Guarulhos International Airport", city: "São Paulo", country: "Brazil", countryCode: "BR", coordinate: CLLocationCoordinate2D(latitude: -23.4356, longitude: -46.4731), timeZoneIdentifier: "America/Sao_Paulo"),
        "GIG": AirportLocation(code: "GIG", name: "Rio de Janeiro/Galeão International Airport", city: "Rio de Janeiro", country: "Brazil", countryCode: "BR", coordinate: CLLocationCoordinate2D(latitude: -22.8099, longitude: -43.2506), timeZoneIdentifier: "America/Sao_Paulo"),
        "LHR": AirportLocation(code: "LHR", name: "Heathrow Airport", city: "London", country: "United Kingdom", countryCode: "GB", coordinate: CLLocationCoordinate2D(latitude: 51.47, longitude: -0.4543), timeZoneIdentifier: "Europe/London"),
        "LGW": AirportLocation(code: "LGW", name: "Gatwick Airport", city: "London", country: "United Kingdom", countryCode: "GB", coordinate: CLLocationCoordinate2D(latitude: 51.1537, longitude: -0.1821), timeZoneIdentifier: "Europe/London"),
        "STN": AirportLocation(code: "STN", name: "London Stansted Airport", city: "London", country: "United Kingdom", countryCode: "GB", coordinate: CLLocationCoordinate2D(latitude: 51.886, longitude: 0.2389), timeZoneIdentifier: "Europe/London"),
        "MAN": AirportLocation(code: "MAN", name: "Manchester Airport", city: "Manchester", country: "United Kingdom", countryCode: "GB", coordinate: CLLocationCoordinate2D(latitude: 53.3537, longitude: -2.275), timeZoneIdentifier: "Europe/London"),
        "EDI": AirportLocation(code: "EDI", name: "Edinburgh Airport", city: "Edinburgh", country: "United Kingdom", countryCode: "GB", coordinate: CLLocationCoordinate2D(latitude: 55.95, longitude: -3.3725), timeZoneIdentifier: "Europe/London"),
        "DUB": AirportLocation(code: "DUB", name: "Dublin Airport", city: "Dublin", country: "Ireland", countryCode: "IE", coordinate: CLLocationCoordinate2D(latitude: 53.4264, longitude: -6.2499), timeZoneIdentifier: "Europe/Dublin"),
        "CDG": AirportLocation(code: "CDG", name: "Charles de Gaulle Airport", city: "Paris", country: "France", countryCode: "FR", coordinate: CLLocationCoordinate2D(latitude: 49.0097, longitude: 2.5479), timeZoneIdentifier: "Europe/Paris"),
        "ORY": AirportLocation(code: "ORY", name: "Paris Orly Airport", city: "Paris", country: "France", countryCode: "FR", coordinate: CLLocationCoordinate2D(latitude: 48.7262, longitude: 2.3652), timeZoneIdentifier: "Europe/Paris"),
        "NCE": AirportLocation(code: "NCE", name: "Nice Côte d'Azur Airport", city: "Nice", country: "France", countryCode: "FR", coordinate: CLLocationCoordinate2D(latitude: 43.6584, longitude: 7.2159), timeZoneIdentifier: "Europe/Paris"),
        "AMS": AirportLocation(code: "AMS", name: "Amsterdam Airport Schiphol", city: "Amsterdam", country: "Netherlands", countryCode: "NL", coordinate: CLLocationCoordinate2D(latitude: 52.3105, longitude: 4.7683), timeZoneIdentifier: "Europe/Amsterdam"),
        "BRU": AirportLocation(code: "BRU", name: "Brussels Airport", city: "Brussels", country: "Belgium", countryCode: "BE", coordinate: CLLocationCoordinate2D(latitude: 50.901, longitude: 4.4856), timeZoneIdentifier: "Europe/Brussels"),
        "FRA": AirportLocation(code: "FRA", name: "Frankfurt Airport", city: "Frankfurt", country: "Germany", countryCode: "DE", coordinate: CLLocationCoordinate2D(latitude: 50.0379, longitude: 8.5622), timeZoneIdentifier: "Europe/Berlin"),
        "MUC": AirportLocation(code: "MUC", name: "Munich Airport", city: "Munich", country: "Germany", countryCode: "DE", coordinate: CLLocationCoordinate2D(latitude: 48.3537, longitude: 11.775), timeZoneIdentifier: "Europe/Berlin"),
        "BER": AirportLocation(code: "BER", name: "Berlin Brandenburg Airport", city: "Berlin", country: "Germany", countryCode: "DE", coordinate: CLLocationCoordinate2D(latitude: 52.3667, longitude: 13.5033), timeZoneIdentifier: "Europe/Berlin"),
        "HAM": AirportLocation(code: "HAM", name: "Hamburg Airport", city: "Hamburg", country: "Germany", countryCode: "DE", coordinate: CLLocationCoordinate2D(latitude: 53.6304, longitude: 9.9882), timeZoneIdentifier: "Europe/Berlin"),
        "DUS": AirportLocation(code: "DUS", name: "Düsseldorf Airport", city: "Düsseldorf", country: "Germany", countryCode: "DE", coordinate: CLLocationCoordinate2D(latitude: 51.2895, longitude: 6.7668), timeZoneIdentifier: "Europe/Berlin"),
        "ZRH": AirportLocation(code: "ZRH", name: "Zurich Airport", city: "Zurich", country: "Switzerland", countryCode: "CH", coordinate: CLLocationCoordinate2D(latitude: 47.4582, longitude: 8.5555), timeZoneIdentifier: "Europe/Zurich"),
        "GVA": AirportLocation(code: "GVA", name: "Geneva Airport", city: "Geneva", country: "Switzerland", countryCode: "CH", coordinate: CLLocationCoordinate2D(latitude: 46.237, longitude: 6.1092), timeZoneIdentifier: "Europe/Zurich"),
        "VIE": AirportLocation(code: "VIE", name: "Vienna International Airport", city: "Vienna", country: "Austria", countryCode: "AT", coordinate: CLLocationCoordinate2D(latitude: 48.1103, longitude: 16.5697), timeZoneIdentifier: "Europe/Vienna"),
        "PRG": AirportLocation(code: "PRG", name: "Václav Havel Airport Prague", city: "Prague", country: "Czech Republic", countryCode: "CZ", coordinate: CLLocationCoordinate2D(latitude: 50.1008, longitude: 14.26), timeZoneIdentifier: "Europe/Prague"),
        "BUD": AirportLocation(code: "BUD", name: "Budapest Ferenc Liszt International Airport", city: "Budapest", country: "Hungary", countryCode: "HU", coordinate: CLLocationCoordinate2D(latitude: 47.4369, longitude: 19.2556), timeZoneIdentifier: "Europe/Budapest"),
        "WAW": AirportLocation(code: "WAW", name: "Warsaw Chopin Airport", city: "Warsaw", country: "Poland", countryCode: "PL", coordinate: CLLocationCoordinate2D(latitude: 52.1672, longitude: 20.9679), timeZoneIdentifier: "Europe/Warsaw"),
        "MAD": AirportLocation(code: "MAD", name: "Adolfo Suárez Madrid-Barajas Airport", city: "Madrid", country: "Spain", countryCode: "ES", coordinate: CLLocationCoordinate2D(latitude: 40.4839, longitude: -3.568), timeZoneIdentifier: "Europe/Madrid"),
        "BCN": AirportLocation(code: "BCN", name: "Josep Tarradellas Barcelona-El Prat Airport", city: "Barcelona", country: "Spain", countryCode: "ES", coordinate: CLLocationCoordinate2D(latitude: 41.2974, longitude: 2.0833), timeZoneIdentifier: "Europe/Madrid"),
        "AGP": AirportLocation(code: "AGP", name: "Málaga-Costa del Sol Airport", city: "Málaga", country: "Spain", countryCode: "ES", coordinate: CLLocationCoordinate2D(latitude: 36.6749, longitude: -4.4991), timeZoneIdentifier: "Europe/Madrid"),
        "PMI": AirportLocation(code: "PMI", name: "Palma de Mallorca Airport", city: "Mallorca", country: "Spain", countryCode: "ES", coordinate: CLLocationCoordinate2D(latitude: 39.5517, longitude: 2.7388), timeZoneIdentifier: "Europe/Madrid"),
        "IBZ": AirportLocation(code: "IBZ", name: "Ibiza Airport", city: "Ibiza", country: "Spain", countryCode: "ES", coordinate: CLLocationCoordinate2D(latitude: 38.8729, longitude: 1.3731), timeZoneIdentifier: "Europe/Madrid"),
        "LIS": AirportLocation(code: "LIS", name: "Humberto Delgado Airport", city: "Lisbon", country: "Portugal", countryCode: "PT", coordinate: CLLocationCoordinate2D(latitude: 38.7742, longitude: -9.1342), timeZoneIdentifier: "Europe/Lisbon"),
        "OPO": AirportLocation(code: "OPO", name: "Francisco Sá Carneiro Airport", city: "Porto", country: "Portugal", countryCode: "PT", coordinate: CLLocationCoordinate2D(latitude: 41.2421, longitude: -8.6786), timeZoneIdentifier: "Europe/Lisbon"),
        "FAO": AirportLocation(code: "FAO", name: "Faro Airport", city: "Faro", country: "Portugal", countryCode: "PT", coordinate: CLLocationCoordinate2D(latitude: 37.0144, longitude: -7.9659), timeZoneIdentifier: "Europe/Lisbon"),
        "FCO": AirportLocation(code: "FCO", name: "Leonardo da Vinci-Fiumicino Airport", city: "Rome", country: "Italy", countryCode: "IT", coordinate: CLLocationCoordinate2D(latitude: 41.8003, longitude: 12.2389), timeZoneIdentifier: "Europe/Rome"),
        "MXP": AirportLocation(code: "MXP", name: "Milan Malpensa Airport", city: "Milan", country: "Italy", countryCode: "IT", coordinate: CLLocationCoordinate2D(latitude: 45.6301, longitude: 8.7255), timeZoneIdentifier: "Europe/Rome"),
        "LIN": AirportLocation(code: "LIN", name: "Milan Linate Airport", city: "Milan", country: "Italy", countryCode: "IT", coordinate: CLLocationCoordinate2D(latitude: 45.4451, longitude: 9.2767), timeZoneIdentifier: "Europe/Rome"),
        "VCE": AirportLocation(code: "VCE", name: "Venice Marco Polo Airport", city: "Venice", country: "Italy", countryCode: "IT", coordinate: CLLocationCoordinate2D(latitude: 45.5053, longitude: 12.3519), timeZoneIdentifier: "Europe/Rome"),
        "FLR": AirportLocation(code: "FLR", name: "Florence Airport", city: "Florence", country: "Italy", countryCode: "IT", coordinate: CLLocationCoordinate2D(latitude: 43.81, longitude: 11.2051), timeZoneIdentifier: "Europe/Rome"),
        "NAP": AirportLocation(code: "NAP", name: "Naples International Airport", city: "Naples", country: "Italy", countryCode: "IT", coordinate: CLLocationCoordinate2D(latitude: 40.886, longitude: 14.2908), timeZoneIdentifier: "Europe/Rome"),
        "ATH": AirportLocation(code: "ATH", name: "Athens International Airport", city: "Athens", country: "Greece", countryCode: "GR", coordinate: CLLocationCoordinate2D(latitude: 37.9364, longitude: 23.9445), timeZoneIdentifier: "Europe/Athens"),
        "JTR": AirportLocation(code: "JTR", name: "Santorini National Airport", city: "Santorini", country: "Greece", countryCode: "GR", coordinate: CLLocationCoordinate2D(latitude: 36.3992, longitude: 25.4793), timeZoneIdentifier: "Europe/Athens"),
        "JMK": AirportLocation(code: "JMK", name: "Mykonos Airport", city: "Mykonos", country: "Greece", countryCode: "GR", coordinate: CLLocationCoordinate2D(latitude: 37.4351, longitude: 25.3481), timeZoneIdentifier: "Europe/Athens"),
        "HER": AirportLocation(code: "HER", name: "Heraklion International Airport", city: "Crete", country: "Greece", countryCode: "GR", coordinate: CLLocationCoordinate2D(latitude: 35.3397, longitude: 25.1803), timeZoneIdentifier: "Europe/Athens"),
        "IST": AirportLocation(code: "IST", name: "Istanbul Airport", city: "Istanbul", country: "Turkey", countryCode: "TR", coordinate: CLLocationCoordinate2D(latitude: 41.2753, longitude: 28.7519), timeZoneIdentifier: "Europe/Istanbul"),
        "CPH": AirportLocation(code: "CPH", name: "Copenhagen Airport", city: "Copenhagen", country: "Denmark", countryCode: "DK", coordinate: CLLocationCoordinate2D(latitude: 55.618, longitude: 12.656), timeZoneIdentifier: "Europe/Copenhagen"),
        "ARN": AirportLocation(code: "ARN", name: "Stockholm Arlanda Airport", city: "Stockholm", country: "Sweden", countryCode: "SE", coordinate: CLLocationCoordinate2D(latitude: 59.6498, longitude: 17.9238), timeZoneIdentifier: "Europe/Stockholm"),
        "OSL": AirportLocation(code: "OSL", name: "Oslo Airport", city: "Oslo", country: "Norway", countryCode: "NO", coordinate: CLLocationCoordinate2D(latitude: 60.1976, longitude: 11.1004), timeZoneIdentifier: "Europe/Oslo"),
        "HEL": AirportLocation(code: "HEL", name: "Helsinki Airport", city: "Helsinki", country: "Finland", countryCode: "FI", coordinate: CLLocationCoordinate2D(latitude: 60.3172, longitude: 24.9633), timeZoneIdentifier: "Europe/Helsinki"),
        "KEF": AirportLocation(code: "KEF", name: "Keflavík International Airport", city: "Reykjavik", country: "Iceland", countryCode: "IS", coordinate: CLLocationCoordinate2D(latitude: 63.985, longitude: -22.6056), timeZoneIdentifier: "Atlantic/Reykjavik"),
        "NRT": AirportLocation(code: "NRT", name: "Narita International Airport", city: "Tokyo", country: "Japan", countryCode: "JP", coordinate: CLLocationCoordinate2D(latitude: 35.772, longitude: 140.3929), timeZoneIdentifier: "Asia/Tokyo"),
        "HND": AirportLocation(code: "HND", name: "Haneda Airport", city: "Tokyo", country: "Japan", countryCode: "JP", coordinate: CLLocationCoordinate2D(latitude: 35.5494, longitude: 139.7798), timeZoneIdentifier: "Asia/Tokyo"),
        "KIX": AirportLocation(code: "KIX", name: "Kansai International Airport", city: "Osaka", country: "Japan", countryCode: "JP", coordinate: CLLocationCoordinate2D(latitude: 34.432, longitude: 135.2304), timeZoneIdentifier: "Asia/Tokyo"),
        "ITM": AirportLocation(code: "ITM", name: "Itami Airport", city: "Osaka", country: "Japan", countryCode: "JP", coordinate: CLLocationCoordinate2D(latitude: 34.7855, longitude: 135.4382), timeZoneIdentifier: "Asia/Tokyo"),
        "CTS": AirportLocation(code: "CTS", name: "New Chitose Airport", city: "Sapporo", country: "Japan", countryCode: "JP", coordinate: CLLocationCoordinate2D(latitude: 42.7752, longitude: 141.6923), timeZoneIdentifier: "Asia/Tokyo"),
        "FUK": AirportLocation(code: "FUK", name: "Fukuoka Airport", city: "Fukuoka", country: "Japan", countryCode: "JP", coordinate: CLLocationCoordinate2D(latitude: 33.5859, longitude: 130.4507), timeZoneIdentifier: "Asia/Tokyo"),
        "OKA": AirportLocation(code: "OKA", name: "Naha Airport", city: "Okinawa", country: "Japan", countryCode: "JP", coordinate: CLLocationCoordinate2D(latitude: 26.1958, longitude: 127.6459), timeZoneIdentifier: "Asia/Tokyo"),
        "NGO": AirportLocation(code: "NGO", name: "Chubu Centrair International Airport", city: "Nagoya", country: "Japan", countryCode: "JP", coordinate: CLLocationCoordinate2D(latitude: 34.8584, longitude: 136.8053), timeZoneIdentifier: "Asia/Tokyo"),
        "ICN": AirportLocation(code: "ICN", name: "Incheon International Airport", city: "Seoul", country: "South Korea", countryCode: "KR", coordinate: CLLocationCoordinate2D(latitude: 37.4602, longitude: 126.4407), timeZoneIdentifier: "Asia/Seoul"),
        "GMP": AirportLocation(code: "GMP", name: "Gimpo International Airport", city: "Seoul", country: "South Korea", countryCode: "KR", coordinate: CLLocationCoordinate2D(latitude: 37.5583, longitude: 126.7906), timeZoneIdentifier: "Asia/Seoul"),
        "PUS": AirportLocation(code: "PUS", name: "Gimhae International Airport", city: "Busan", country: "South Korea", countryCode: "KR", coordinate: CLLocationCoordinate2D(latitude: 35.1795, longitude: 128.9382), timeZoneIdentifier: "Asia/Seoul"),
        "CJU": AirportLocation(code: "CJU", name: "Jeju International Airport", city: "Jeju", country: "South Korea", countryCode: "KR", coordinate: CLLocationCoordinate2D(latitude: 33.5113, longitude: 126.493), timeZoneIdentifier: "Asia/Seoul"),
        "PEK": AirportLocation(code: "PEK", name: "Beijing Capital International Airport", city: "Beijing", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 40.0799, longitude: 116.6031), timeZoneIdentifier: "Asia/Shanghai"),
        "PKX": AirportLocation(code: "PKX", name: "Beijing Daxing International Airport", city: "Beijing", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 39.5098, longitude: 116.4105), timeZoneIdentifier: "Asia/Shanghai"),
        "PVG": AirportLocation(code: "PVG", name: "Shanghai Pudong International Airport", city: "Shanghai", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 31.1443, longitude: 121.8083), timeZoneIdentifier: "Asia/Shanghai"),
        "SHA": AirportLocation(code: "SHA", name: "Shanghai Hongqiao International Airport", city: "Shanghai", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 31.1979, longitude: 121.3363), timeZoneIdentifier: "Asia/Shanghai"),
        "CAN": AirportLocation(code: "CAN", name: "Guangzhou Baiyun International Airport", city: "Guangzhou", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 23.3924, longitude: 113.299), timeZoneIdentifier: "Asia/Shanghai"),
        "SZX": AirportLocation(code: "SZX", name: "Shenzhen Bao'an International Airport", city: "Shenzhen", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 22.6393, longitude: 113.8107), timeZoneIdentifier: "Asia/Shanghai"),
        "CTU": AirportLocation(code: "CTU", name: "Chengdu Shuangliu International Airport", city: "Chengdu", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 30.5785, longitude: 103.9471), timeZoneIdentifier: "Asia/Shanghai"),
        "TFU": AirportLocation(code: "TFU", name: "Chengdu Tianfu International Airport", city: "Chengdu", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 30.3167, longitude: 104.4444), timeZoneIdentifier: "Asia/Shanghai"),
        "CKG": AirportLocation(code: "CKG", name: "Chongqing Jiangbei International Airport", city: "Chongqing", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 29.7192, longitude: 106.6417), timeZoneIdentifier: "Asia/Shanghai"),
        "XIY": AirportLocation(code: "XIY", name: "Xi'an Xianyang International Airport", city: "Xi'an", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 34.4471, longitude: 108.7516), timeZoneIdentifier: "Asia/Shanghai"),
        "HGH": AirportLocation(code: "HGH", name: "Hangzhou Xiaoshan International Airport", city: "Hangzhou", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 30.2295, longitude: 120.4344), timeZoneIdentifier: "Asia/Shanghai"),
        "NKG": AirportLocation(code: "NKG", name: "Nanjing Lukou International Airport", city: "Nanjing", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 31.742, longitude: 118.862), timeZoneIdentifier: "Asia/Shanghai"),
        "WUH": AirportLocation(code: "WUH", name: "Wuhan Tianhe International Airport", city: "Wuhan", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 30.7838, longitude: 114.2081), timeZoneIdentifier: "Asia/Shanghai"),
        "TAO": AirportLocation(code: "TAO", name: "Qingdao Jiaodong International Airport", city: "Qingdao", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 36.3653, longitude: 120.0886), timeZoneIdentifier: "Asia/Shanghai"),
        "XMN": AirportLocation(code: "XMN", name: "Xiamen Gaoqi International Airport", city: "Xiamen", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 24.544, longitude: 118.1278), timeZoneIdentifier: "Asia/Shanghai"),
        "SYX": AirportLocation(code: "SYX", name: "Sanya Phoenix International Airport", city: "Sanya", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 18.3029, longitude: 109.4123), timeZoneIdentifier: "Asia/Shanghai"),
        "HAK": AirportLocation(code: "HAK", name: "Haikou Meilan International Airport", city: "Haikou", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 19.9349, longitude: 110.459), timeZoneIdentifier: "Asia/Shanghai"),
        "KMG": AirportLocation(code: "KMG", name: "Kunming Changshui International Airport", city: "Kunming", country: "China", countryCode: "CN", coordinate: CLLocationCoordinate2D(latitude: 25.1019, longitude: 102.9292), timeZoneIdentifier: "Asia/Shanghai"),
        "HKG": AirportLocation(code: "HKG", name: "Hong Kong International Airport", city: "Hong Kong", country: "Hong Kong", countryCode: "HK", coordinate: CLLocationCoordinate2D(latitude: 22.308, longitude: 113.9185), timeZoneIdentifier: "Asia/Hong_Kong"),
        "MFM": AirportLocation(code: "MFM", name: "Macau International Airport", city: "Macau", country: "Macau", countryCode: "MO", coordinate: CLLocationCoordinate2D(latitude: 22.1496, longitude: 113.5916), timeZoneIdentifier: "Asia/Macau"),
        "TPE": AirportLocation(code: "TPE", name: "Taiwan Taoyuan International Airport", city: "Taipei", country: "Taiwan", countryCode: "TW", coordinate: CLLocationCoordinate2D(latitude: 25.0797, longitude: 121.2342), timeZoneIdentifier: "Asia/Taipei"),
        "TSA": AirportLocation(code: "TSA", name: "Taipei Songshan Airport", city: "Taipei", country: "Taiwan", countryCode: "TW", coordinate: CLLocationCoordinate2D(latitude: 25.0697, longitude: 121.5525), timeZoneIdentifier: "Asia/Taipei"),
        "KHH": AirportLocation(code: "KHH", name: "Kaohsiung International Airport", city: "Kaohsiung", country: "Taiwan", countryCode: "TW", coordinate: CLLocationCoordinate2D(latitude: 22.5711, longitude: 120.35), timeZoneIdentifier: "Asia/Taipei"),
        "SIN": AirportLocation(code: "SIN", name: "Singapore Changi Airport", city: "Singapore", country: "Singapore", countryCode: "SG", coordinate: CLLocationCoordinate2D(latitude: 1.3644, longitude: 103.9915), timeZoneIdentifier: "Asia/Singapore"),
        "BKK": AirportLocation(code: "BKK", name: "Suvarnabhumi Airport", city: "Bangkok", country: "Thailand", countryCode: "TH", coordinate: CLLocationCoordinate2D(latitude: 13.69, longitude: 100.7501), timeZoneIdentifier: "Asia/Bangkok"),
        "DMK": AirportLocation(code: "DMK", name: "Don Mueang International Airport", city: "Bangkok", country: "Thailand", countryCode: "TH", coordinate: CLLocationCoordinate2D(latitude: 13.9126, longitude: 100.6068), timeZoneIdentifier: "Asia/Bangkok"),
        "HKT": AirportLocation(code: "HKT", name: "Phuket International Airport", city: "Phuket", country: "Thailand", countryCode: "TH", coordinate: CLLocationCoordinate2D(latitude: 8.1132, longitude: 98.3169), timeZoneIdentifier: "Asia/Bangkok"),
        "CNX": AirportLocation(code: "CNX", name: "Chiang Mai International Airport", city: "Chiang Mai", country: "Thailand", countryCode: "TH", coordinate: CLLocationCoordinate2D(latitude: 18.7668, longitude: 98.9626), timeZoneIdentifier: "Asia/Bangkok"),
        "USM": AirportLocation(code: "USM", name: "Samui Airport", city: "Koh Samui", country: "Thailand", countryCode: "TH", coordinate: CLLocationCoordinate2D(latitude: 9.5478, longitude: 100.0628), timeZoneIdentifier: "Asia/Bangkok"),
        "KUL": AirportLocation(code: "KUL", name: "Kuala Lumpur International Airport", city: "Kuala Lumpur", country: "Malaysia", countryCode: "MY", coordinate: CLLocationCoordinate2D(latitude: 2.7456, longitude: 101.7099), timeZoneIdentifier: "Asia/Kuala_Lumpur"),
        "PEN": AirportLocation(code: "PEN", name: "Penang International Airport", city: "Penang", country: "Malaysia", countryCode: "MY", coordinate: CLLocationCoordinate2D(latitude: 5.2971, longitude: 100.2769), timeZoneIdentifier: "Asia/Kuala_Lumpur"),
        "DPS": AirportLocation(code: "DPS", name: "Ngurah Rai International Airport", city: "Bali", country: "Indonesia", countryCode: "ID", coordinate: CLLocationCoordinate2D(latitude: -8.7482, longitude: 115.1672), timeZoneIdentifier: "Asia/Makassar"),
        "CGK": AirportLocation(code: "CGK", name: "Soekarno-Hatta International Airport", city: "Jakarta", country: "Indonesia", countryCode: "ID", coordinate: CLLocationCoordinate2D(latitude: -6.1256, longitude: 106.6559), timeZoneIdentifier: "Asia/Jakarta"),
        "SGN": AirportLocation(code: "SGN", name: "Tan Son Nhat International Airport", city: "Ho Chi Minh City", country: "Vietnam", countryCode: "VN", coordinate: CLLocationCoordinate2D(latitude: 10.8188, longitude: 106.6519), timeZoneIdentifier: "Asia/Ho_Chi_Minh"),
        "HAN": AirportLocation(code: "HAN", name: "Noi Bai International Airport", city: "Hanoi", country: "Vietnam", countryCode: "VN", coordinate: CLLocationCoordinate2D(latitude: 21.2212, longitude: 105.8072), timeZoneIdentifier: "Asia/Bangkok"),
        "DAD": AirportLocation(code: "DAD", name: "Da Nang International Airport", city: "Da Nang", country: "Vietnam", countryCode: "VN", coordinate: CLLocationCoordinate2D(latitude: 16.0439, longitude: 108.1994), timeZoneIdentifier: "Asia/Bangkok"),
        "PQC": AirportLocation(code: "PQC", name: "Phu Quoc International Airport", city: "Phu Quoc", country: "Vietnam", countryCode: "VN", coordinate: CLLocationCoordinate2D(latitude: 10.1698, longitude: 103.9931), timeZoneIdentifier: "Asia/Bangkok"),
        "MNL": AirportLocation(code: "MNL", name: "Ninoy Aquino International Airport", city: "Manila", country: "Philippines", countryCode: "PH", coordinate: CLLocationCoordinate2D(latitude: 14.5086, longitude: 121.0194), timeZoneIdentifier: "Asia/Manila"),
        "CEB": AirportLocation(code: "CEB", name: "Mactan-Cebu International Airport", city: "Cebu", country: "Philippines", countryCode: "PH", coordinate: CLLocationCoordinate2D(latitude: 10.3075, longitude: 123.9794), timeZoneIdentifier: "Asia/Manila"),
        "DEL": AirportLocation(code: "DEL", name: "Indira Gandhi International Airport", city: "Delhi", country: "India", countryCode: "IN", coordinate: CLLocationCoordinate2D(latitude: 28.5562, longitude: 77.1), timeZoneIdentifier: "Asia/Kolkata"),
        "BOM": AirportLocation(code: "BOM", name: "Chhatrapati Shivaji Maharaj International Airport", city: "Mumbai", country: "India", countryCode: "IN", coordinate: CLLocationCoordinate2D(latitude: 19.0896, longitude: 72.8656), timeZoneIdentifier: "Asia/Kolkata"),
        "BLR": AirportLocation(code: "BLR", name: "Kempegowda International Airport", city: "Bengaluru", country: "India", countryCode: "IN", coordinate: CLLocationCoordinate2D(latitude: 13.1986, longitude: 77.7066), timeZoneIdentifier: "Asia/Kolkata"),
        "MLE": AirportLocation(code: "MLE", name: "Velana International Airport", city: "Malé", country: "Maldives", countryCode: "MV", coordinate: CLLocationCoordinate2D(latitude: 4.1918, longitude: 73.529), timeZoneIdentifier: "Indian/Maldives"),
        "CMB": AirportLocation(code: "CMB", name: "Bandaranaike International Airport", city: "Colombo", country: "Sri Lanka", countryCode: "LK", coordinate: CLLocationCoordinate2D(latitude: 7.1808, longitude: 79.8841), timeZoneIdentifier: "Asia/Colombo"),
        "DXB": AirportLocation(code: "DXB", name: "Dubai International Airport", city: "Dubai", country: "United Arab Emirates", countryCode: "AE", coordinate: CLLocationCoordinate2D(latitude: 25.2532, longitude: 55.3657), timeZoneIdentifier: "Asia/Dubai"),
        "AUH": AirportLocation(code: "AUH", name: "Zayed International Airport", city: "Abu Dhabi", country: "United Arab Emirates", countryCode: "AE", coordinate: CLLocationCoordinate2D(latitude: 24.433, longitude: 54.6511), timeZoneIdentifier: "Asia/Dubai"),
        "DOH": AirportLocation(code: "DOH", name: "Hamad International Airport", city: "Doha", country: "Qatar", countryCode: "QA", coordinate: CLLocationCoordinate2D(latitude: 25.2731, longitude: 51.6081), timeZoneIdentifier: "Asia/Qatar"),
        "RUH": AirportLocation(code: "RUH", name: "King Khalid International Airport", city: "Riyadh", country: "Saudi Arabia", countryCode: "SA", coordinate: CLLocationCoordinate2D(latitude: 24.9576, longitude: 46.6988), timeZoneIdentifier: "Asia/Riyadh"),
        "JED": AirportLocation(code: "JED", name: "King Abdulaziz International Airport", city: "Jeddah", country: "Saudi Arabia", countryCode: "SA", coordinate: CLLocationCoordinate2D(latitude: 21.6796, longitude: 39.1565), timeZoneIdentifier: "Asia/Riyadh"),
        "TLV": AirportLocation(code: "TLV", name: "Ben Gurion Airport", city: "Tel Aviv", country: "Israel", countryCode: "IL", coordinate: CLLocationCoordinate2D(latitude: 32.0055, longitude: 34.8854), timeZoneIdentifier: "Asia/Jerusalem"),
        "SYD": AirportLocation(code: "SYD", name: "Sydney Kingsford Smith Airport", city: "Sydney", country: "Australia", countryCode: "AU", coordinate: CLLocationCoordinate2D(latitude: -33.9399, longitude: 151.1753), timeZoneIdentifier: "Australia/Sydney"),
        "MEL": AirportLocation(code: "MEL", name: "Melbourne Airport", city: "Melbourne", country: "Australia", countryCode: "AU", coordinate: CLLocationCoordinate2D(latitude: -37.669, longitude: 144.841), timeZoneIdentifier: "Australia/Melbourne"),
        "BNE": AirportLocation(code: "BNE", name: "Brisbane Airport", city: "Brisbane", country: "Australia", countryCode: "AU", coordinate: CLLocationCoordinate2D(latitude: -27.3842, longitude: 153.1175), timeZoneIdentifier: "Australia/Brisbane"),
        "PER": AirportLocation(code: "PER", name: "Perth Airport", city: "Perth", country: "Australia", countryCode: "AU", coordinate: CLLocationCoordinate2D(latitude: -31.9403, longitude: 115.9668), timeZoneIdentifier: "Australia/Perth"),
        "ADL": AirportLocation(code: "ADL", name: "Adelaide Airport", city: "Adelaide", country: "Australia", countryCode: "AU", coordinate: CLLocationCoordinate2D(latitude: -34.945, longitude: 138.5306), timeZoneIdentifier: "Australia/Adelaide"),
        "AKL": AirportLocation(code: "AKL", name: "Auckland Airport", city: "Auckland", country: "New Zealand", countryCode: "NZ", coordinate: CLLocationCoordinate2D(latitude: -37.0082, longitude: 174.785), timeZoneIdentifier: "Pacific/Auckland"),
        "CHC": AirportLocation(code: "CHC", name: "Christchurch Airport", city: "Christchurch", country: "New Zealand", countryCode: "NZ", coordinate: CLLocationCoordinate2D(latitude: -43.4894, longitude: 172.5322), timeZoneIdentifier: "Pacific/Auckland"),
        "ZQN": AirportLocation(code: "ZQN", name: "Queenstown Airport", city: "Queenstown", country: "New Zealand", countryCode: "NZ", coordinate: CLLocationCoordinate2D(latitude: -45.0216, longitude: 168.745), timeZoneIdentifier: "Pacific/Auckland"),
        "NAN": AirportLocation(code: "NAN", name: "Nadi International Airport", city: "Nadi", country: "Fiji", countryCode: "FJ", coordinate: CLLocationCoordinate2D(latitude: -17.7554, longitude: 177.4434), timeZoneIdentifier: "Pacific/Fiji"),
        "PPT": AirportLocation(code: "PPT", name: "Fa'a'ā International Airport", city: "Tahiti", country: "French Polynesia", countryCode: "PF", coordinate: CLLocationCoordinate2D(latitude: -17.5537, longitude: -149.6069), timeZoneIdentifier: "Pacific/Tahiti"),
        "CAI": AirportLocation(code: "CAI", name: "Cairo International Airport", city: "Cairo", country: "Egypt", countryCode: "EG", coordinate: CLLocationCoordinate2D(latitude: 30.1219, longitude: 31.4056), timeZoneIdentifier: "Africa/Cairo"),
        "CMN": AirportLocation(code: "CMN", name: "Mohammed V International Airport", city: "Casablanca", country: "Morocco", countryCode: "MA", coordinate: CLLocationCoordinate2D(latitude: 33.3675, longitude: -7.5899), timeZoneIdentifier: "Africa/Casablanca"),
        "RAK": AirportLocation(code: "RAK", name: "Marrakesh Menara Airport", city: "Marrakesh", country: "Morocco", countryCode: "MA", coordinate: CLLocationCoordinate2D(latitude: 31.6069, longitude: -8.0363), timeZoneIdentifier: "Africa/Casablanca"),
        "JNB": AirportLocation(code: "JNB", name: "O.R. Tambo International Airport", city: "Johannesburg", country: "South Africa", countryCode: "ZA", coordinate: CLLocationCoordinate2D(latitude: -26.1367, longitude: 28.2411), timeZoneIdentifier: "Africa/Johannesburg"),
        "CPT": AirportLocation(code: "CPT", name: "Cape Town International Airport", city: "Cape Town", country: "South Africa", countryCode: "ZA", coordinate: CLLocationCoordinate2D(latitude: -33.9715, longitude: 18.6021), timeZoneIdentifier: "Africa/Johannesburg"),
        "NBO": AirportLocation(code: "NBO", name: "Jomo Kenyatta International Airport", city: "Nairobi", country: "Kenya", countryCode: "KE", coordinate: CLLocationCoordinate2D(latitude: -1.3192, longitude: 36.9275), timeZoneIdentifier: "Africa/Nairobi")
    ]
}
