import Foundation

struct FlightLookupResponse: Codable, Sendable {
    let source: String
    let flightNumber: String
    let date: String
    let fetchedAt: String
    let flights: [FlightCandidate]

    init(source: String, flightNumber: String, date: String, fetchedAt: String, flights: [FlightCandidate]) {
        self.source = source
        self.flightNumber = flightNumber
        self.date = date
        self.fetchedAt = fetchedAt
        self.flights = flights
    }
}

struct FlightTimePair: Codable, Sendable, Hashable {
    let local: String?
    let utc: String?

    init(local: String? = nil, utc: String? = nil) {
        self.local = local
        self.utc = utc
    }
}

struct FlightEndpoint: Codable, Sendable, Hashable {
    let code: String?
    let icao: String?
    let city: String?
    let name: String?
    let timeZone: String?
    let scheduledTime: FlightTimePair?
    let revisedTime: FlightTimePair?
    let predictedTime: FlightTimePair?
    let runwayTime: FlightTimePair?
    let terminal: String?
    let gate: String?
    let quality: [String]?

    init(
        code: String? = nil,
        icao: String? = nil,
        city: String? = nil,
        name: String? = nil,
        timeZone: String? = nil,
        scheduledTime: FlightTimePair? = nil,
        revisedTime: FlightTimePair? = nil,
        predictedTime: FlightTimePair? = nil,
        runwayTime: FlightTimePair? = nil,
        terminal: String? = nil,
        gate: String? = nil,
        quality: [String]? = nil
    ) {
        self.code = code
        self.icao = icao
        self.city = city
        self.name = name
        self.timeZone = timeZone
        self.scheduledTime = scheduledTime
        self.revisedTime = revisedTime
        self.predictedTime = predictedTime
        self.runwayTime = runwayTime
        self.terminal = terminal
        self.gate = gate
        self.quality = quality
    }

    /// Best available local time string (e.g. "18:30") extracted from revisedTime or scheduledTime.
    var bestTime: FlightTimePair? {
        [runwayTime, revisedTime, predictedTime, scheduledTime].compactMap { $0 }
            .first { $0.utc != nil || $0.local != nil }
    }
    var timeFormatted: String {
        let raw = runwayTime?.local ?? revisedTime?.local ?? predictedTime?.local ?? scheduledTime?.local
        guard let raw else { return "—" }
        return Self.extractTime(from: raw)
    }

    static func extractTime(from raw: String) -> String {
        if let range = raw.range(of: #"\b\d{2}:\d{2}\b"#, options: .regularExpression) {
            return String(raw[range])
        }
        return "—"
    }
}

struct FlightCandidate: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let flightNumber: String
    let date: String
    let airline: String?
    let departure: FlightEndpoint
    let arrival: FlightEndpoint
    let status: String
    let providerStatus: String?
    let aircraft: String?
    let providerUpdatedAt: String?

    init(
        id: String,
        flightNumber: String,
        date: String,
        airline: String? = nil,
        departure: FlightEndpoint,
        arrival: FlightEndpoint,
        status: String,
        providerStatus: String? = nil,
        aircraft: String? = nil,
        providerUpdatedAt: String? = nil
    ) {
        self.id = id
        self.flightNumber = flightNumber
        self.date = date
        self.airline = airline
        self.departure = departure
        self.arrival = arrival
        self.status = status
        self.providerStatus = providerStatus
        self.aircraft = aircraft
        self.providerUpdatedAt = providerUpdatedAt
    }

    var departureTimeFormatted: String { departure.timeFormatted }
    var arrivalTimeFormatted: String {
        let raw = arrival.runwayTime?.local ?? arrival.revisedTime?.local ?? arrival.predictedTime?.local ?? arrival.scheduledTime?.local
        guard let raw else { return "—" }
        return FlightEndpoint.extractTime(from: raw)
    }

    var terminalFormatted: String {
        if let term = arrival.terminal, !term.trimmingCharacters(in: .whitespaces).isEmpty {
            let clean = term.trimmingCharacters(in: .whitespaces)
            return clean.localizedCaseInsensitiveContains("terminal") ? clean : "Terminal \(clean)"
        }
        if let term = departure.terminal, !term.trimmingCharacters(in: .whitespaces).isEmpty {
            let clean = term.trimmingCharacters(in: .whitespaces)
            return clean.localizedCaseInsensitiveContains("terminal") ? clean : "Terminal \(clean)"
        }
        return "Not available"
    }

    var tripStatus: TripFlightStatus {
        switch status.lowercased() {
        case "landed", "arrived": return .landed
        case "boarding": return .boarding
        case "delayed": return .delayed
        case "airborne", "departed", "enroute": return .airborne
        case "cancelled", "canceled": return .cancelled
        case "diverted": return .diverted
        case "scheduled", "expected": return .scheduled
        default: return .unknown
        }
    }

    var routeSummary: String {
        "\(departure.code ?? "—") → \(arrival.code ?? "—")"
    }

    var arrivalDayOffset: Int {
        guard let depStr = departure.scheduledTime?.local ?? departure.revisedTime?.local,
              let arrStr = arrival.runwayTime?.local ?? arrival.revisedTime?.local ?? arrival.predictedTime?.local ?? arrival.scheduledTime?.local else {
            return 0
        }
        let depDate = String(depStr.prefix(10))
        let arrDate = String(arrStr.prefix(10))
        return Calendar.current.dateComponents([.day], from: TripDay(value: depDate).pickerDate,
            to: TripDay(value: arrDate).pickerDate).day ?? 0
    }
}

struct FlightLookupRequestBody: Encodable, Sendable {
    let flightNumber: String
    let date: String

    init(flightNumber: String, date: String) {
        self.flightNumber = flightNumber
        self.date = date
    }
}
