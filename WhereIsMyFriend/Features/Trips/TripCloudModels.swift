import Foundation

struct TripCloudList: Decodable { let trips: [CloudTrip] }
struct TripInvitationList: Decodable { let invitations: [TripInvitation] }
struct TripActionResult: Decodable { let success: Bool }

enum TripLifecycleAction: String, Encodable, Sendable {
    case leave, cancel, delete, removeMember
}

struct TripLifecyclePayload: Encodable, Sendable {
    let action: TripLifecycleAction
    let requestID: UUID
    let revision: Int?
    let participantID: String?
}

struct TripLifecycleResult: Decodable, Sendable {
    let success: Bool
    let trip: CloudTrip?
}

struct TripCollaborationPayload: Encodable, Sendable {
    var enabled: Bool? = nil
    var point: String? = nil
    var revision: Int? = nil
    var state: String? = nil
}

struct TripPayload: Codable, Sendable {
    var id: String? = nil
    var name: String? = nil
    var destinationAirport: String? = nil
    var startDate: String? = nil
    var endDate: String? = nil
    var completed: Bool? = nil
    var flightNumber: String? = nil
    var date: String? = nil
    var direction: String? = nil
    var candidateID: String? = nil
    var username: String? = nil
}

struct TripMutation: Encodable, Sendable {
    let kind: String
    let payload: TripPayload
    let revision: Int?
}

struct CloudTrip: Decodable, Sendable {
    let id: String
    let name: String
    let destination_airport: String
    let start_date: String
    let end_date: String
    let completed_at: String?
    let my_role: String
    let revision: Int
    let participants: [Person]
    let flights: [Flight]
    var flight_alerts_enabled: Bool? = nil
    var meeting_point: String? = nil
    var cancelled_at: String? = nil

    struct Person: Decodable, Sendable {
        let id: String
        let name: String
        let user_id: String?
        var check_in: String? = nil
        var check_in_at: String? = nil
    }

    struct Flight: Decodable, Sendable {
        let id: String
        let participant_id: String
        let flight_number: String
        let date: String
        let direction: String?
        let airline: String?
        let departure: FlightEndpoint
        let arrival: FlightEndpoint
        let status: String?
        let revision: Int
        let candidate_id: String?
        let verified_at: String?
        var tracking_state: String? = nil
    }

    func plan(userID: String) -> TripPlan {
        let people = participants.map { TripParticipant(id: $0.id, name: $0.name, userID: $0.user_id?.uppercased(),
            checkIn: $0.check_in.flatMap(TripCheckIn.init(rawValue:)), checkInAt: Self.timestamp($0.check_in_at)) }
        let mappedFlights = flights.map { flight in
            let candidate = FlightCandidate(id: flight.candidate_id ?? flight.id, flightNumber: flight.flight_number,
                date: flight.date, airline: flight.airline, departure: flight.departure, arrival: flight.arrival,
                status: flight.status ?? "unknown")
            return TripFlight(id: flight.id, traveler: people.first { $0.id == flight.participant_id }?.name ?? "Traveler",
                flightNumber: flight.flight_number, airline: flight.airline?.isEmpty == false ? flight.airline! : "Not verified",
                origin: flight.departure.code ?? (flight.direction == "inbound" ? destination_airport : "—"),
                destination: flight.arrival.code ?? (flight.direction == "outbound" ? destination_airport : "—"),
                departureTime: candidate.departureTimeFormatted, arrivalTime: candidate.arrivalTimeFormatted,
                date: TripDay(value: flight.date).pickerDate, terminal: candidate.terminalFormatted,
                status: flight.status == "unverified" ? .unverified : candidate.tripStatus,
                direction: flight.direction == "inbound" ? .inbound : .outbound,
                arrivalDayOffset: candidate.arrivalDayOffset, travelerID: flight.participant_id,
                revision: flight.revision, candidateID: flight.candidate_id, verifiedAt: Self.timestamp(flight.verified_at),
                trackingState: flight.tracking_state, scheduledDeparture: Self.timestamp(flight.departure.scheduledTime?.utc),
                expectedArrival: Self.timestamp(flight.arrival.bestTime?.utc))
        }
        return TripPlan(id: id, name: name, destinationAirport: destination_airport,
            startDay: TripDay(value: start_date), endDay: TripDay(value: end_date), participants: people,
            flights: mappedFlights, completedAt: Self.timestamp(completed_at), creatorUserID: my_role == "owner" ? userID : nil,
            revision: revision, flightAlertsEnabled: flight_alerts_enabled, meetingPoint: meeting_point,
            cancelledAt: Self.timestamp(cancelled_at))
    }

    static func timestamp(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // AeroDataBox UTC fields may omit a trailing Z; never interpret them in the device time zone.
        let iso = value.replacingOccurrences(of: " ", with: "T")
            .replacingOccurrences(of: #"(T\d{2}:\d{2})(?=Z|[+-]|$)"#, with: "$1:00", options: .regularExpression)
        let normalized = iso.range(of: #"(Z|[+-]\d{2}:\d{2})$"#, options: .regularExpression) == nil ? iso + "Z" : iso
        return formatter.date(from: normalized) ?? ISO8601DateFormatter().date(from: normalized)
    }
}

struct TripInvitation: Identifiable, Decodable, Sendable {
    let id: UUID
    let trip_name: String
    let trip_id: String
    let destination_airport: String
    let start_date: String
    let end_date: String
    let inviter_name: String
    let recipient_name: String
    let recipient_id: UUID
    let expires_at: String
}

struct CreatedTripInvitation: Decodable, Sendable { let id: UUID }

enum TripInvitationLink {
    static func parseTripView(_ url: URL, scheme: String = SharedAppLink.urlScheme) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard url.scheme == scheme, url.host == "trips", url.user == nil, url.password == nil,
              url.query == nil, url.fragment == nil, parts.count == 2, parts[0] == "view",
              parts[1].range(of: #"^[A-Za-z0-9_-]{1,100}$"#, options: .regularExpression) != nil else { return nil }
        return parts[1]
    }

    static func make(id: UUID, bundle: Bundle = .main) -> URL {
        if let raw = bundle.object(forInfoDictionaryKey: "WIFInviteBaseURL") as? String,
           let base = URL(string: raw), base.scheme == "https",
           let host = base.host, InviteLinkConfiguration.trustedHosts(bundle: bundle).contains(host) {
            return base.appending(path: "trips/join/\(id.uuidString.lowercased())")
        }
        return SharedAppLink.make(host: "trips", path: "join/\(id.uuidString.lowercased())")
    }

    static func parse(_ url: URL, scheme: String = SharedAppLink.urlScheme,
                      hosts: Set<String> = InviteLinkConfiguration.trustedHosts()) -> UUID? {
        guard url.user == nil, url.password == nil, url.query == nil, url.fragment == nil else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        if url.scheme == scheme, url.host == "trips", parts.count == 2, parts[0] == "join" {
            return UUID(uuidString: parts[1])
        }
        if url.scheme == "https", let host = url.host?.lowercased(), hosts.contains(host),
           parts.count >= 3, Array(parts.suffix(3).prefix(2)) == ["trips", "join"] {
            return UUID(uuidString: parts.last!)
        }
        return nil
    }
}
