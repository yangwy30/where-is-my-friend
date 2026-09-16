import XCTest
@testable import WhereIsMyFriend

final class TripFlightLookupTests: XCTestCase {
    private func trip(start: String = "2026-10-12", end: String = "2026-10-16") -> TripPlan {
        TripPlan(id: "date-anchor-test", name: "October trip", destinationAirport: "NRT",
                 startDay: TripDay(value: start), endDay: TripDay(value: end), participants: [], flights: [])
    }

    func testNewFlightDateUsesTripStartInsteadOfToday() {
        let trip = trip()
        XCTAssertEqual(TripDay(trip.initialFlightDate()).value, "2026-10-12")
        XCTAssertEqual(trip.initialFlightDate(), trip.startDay.pickerDate)
    }

    func testEachTripUsesItsOwnStartIncludingPastTrips() {
        XCTAssertEqual(TripDay(trip(start: "2026-11-26", end: "2026-11-29").initialFlightDate()).value, "2026-11-26")
        XCTAssertEqual(TripDay(trip(start: "2020-10-12", end: "2020-10-16").initialFlightDate()).value, "2020-10-12")
    }

    func testEditingFlightKeepsItsDateEvenIfTripDatesChange() {
        var flight = TripFlight.previewFlights[0]
        flight.date = TripDay(value: "2026-10-13").pickerDate
        let changedTrip = trip(start: "2026-10-14", end: "2026-10-18")
        XCTAssertEqual(changedTrip.initialFlightDate(existing: flight), flight.date)
        XCTAssertEqual(TripDay(changedTrip.initialFlightDate(existing: flight)).value, "2026-10-13")
    }

    func testProviderTimestampsAndPredictedArrivalRespectUTCAndNextDay() {
        XCTAssertEqual(CloudTrip.timestamp("2026-09-09 22:30Z"), CloudTrip.timestamp("2026-09-09T22:30:00Z"))
        XCTAssertEqual(CloudTrip.timestamp("2026-09-09T22:30:00"), CloudTrip.timestamp("2026-09-09T22:30:00Z"))
        XCTAssertNotNil(CloudTrip.timestamp("2026-09-09 22:30Z"))
        XCTAssertNil(CloudTrip.timestamp("not-a-time"))
        let candidate = FlightCandidate(id: "a", flightNumber: "UA353", date: "2026-09-09",
            departure: .init(scheduledTime: .init(local: "2026-09-09 18:00-04:00")),
            arrival: .init(scheduledTime: .init(local: "2026-09-09 23:45-07:00"),
                revisedTime: .init(), predictedTime: .init(local: "2026-09-10 00:15-07:00", utc: "2026-09-10 07:15Z"), runwayTime: .init()),
            status: "scheduled")
        XCTAssertEqual(candidate.arrivalTimeFormatted, "00:15")
        XCTAssertEqual(candidate.arrivalDayOffset, 1)
        XCTAssertEqual(candidate.arrival.bestTime?.utc, "2026-09-10 07:15Z")
    }

    func testStaleStatusAndTripNotificationLinks() {
        let now = Date()
        var flight = TripFlight.previewFlights.first { $0.status != .landed }!
        flight.verifiedAt = now.addingTimeInterval(-3600)
        flight.trackingState = "updated"
        XCTAssertTrue(flight.isStatusStale(at: now))
        XCTAssertTrue(flight.freshnessLabel(at: now).contains("Last known"))
        flight.verifiedAt = now
        XCTAssertFalse(flight.isStatusStale(at: now))
        flight.trackingState = "quota_limited"
        XCTAssertTrue(flight.isStatusStale(at: now))
        XCTAssertTrue(flight.freshnessLabel(at: now).contains("limit reached"))
        XCTAssertEqual(TripInvitationLink.parseTripView(URL(string: "acrossus://trips/view/trip-1")!, scheme: "acrossus"), "trip-1")
        XCTAssertNil(TripInvitationLink.parseTripView(URL(string: "acrossus://trips/view/trip-1?userID=other")!, scheme: "acrossus"))
        XCTAssertNil(TripInvitationLink.parseTripView(URL(string: "https://example.com/trips/view/trip-1")!, scheme: "acrossus"))
    }
    func testTripInvitationLinksRequireTrustedHostAndExactUUIDRoute() {
        let id = UUID()
        XCTAssertEqual(TripInvitationLink.parse(URL(string: "acrossus://trips/join/\(id)")!, scheme: "acrossus"), id)
        XCTAssertEqual(TripInvitationLink.parse(URL(string: "https://invite.example/trips/join/\(id)")!, hosts: ["invite.example"]), id)
        XCTAssertNil(TripInvitationLink.parse(URL(string: "https://attacker.example/trips/join/\(id)")!, hosts: ["invite.example"]))
        XCTAssertNil(TripInvitationLink.parse(URL(string: "acrossus://trips/join/not-a-uuid")!, scheme: "acrossus"))
        XCTAssertNil(TripInvitationLink.parse(URL(string: "acrossus://trips/join/\(id)?userID=someone")!, scheme: "acrossus"))
        XCTAssertNil(TripInvitationLink.parse(URL(string: "acrossus://trips/join/\(id)/extra")!, scheme: "acrossus"))
    }

    private func summaryFlight(id: String = "flight", travelerID: String = "yang", direction: TripDirection = .outbound,
                               status: TripFlightStatus = .scheduled, day: String = "2026-11-26") -> TripFlight {
        TripFlight(id: id, traveler: "Yang Wang", flightNumber: "WN 1289", airline: "Southwest",
                   origin: "OAK", destination: "LIH", departureTime: "10:00", arrivalTime: "15:46",
                   date: TripDay(value: day).pickerDate, terminal: "—", status: status,
                   direction: direction, travelerID: travelerID)
    }

    private func summaryTrip(flights: [TripFlight]) -> TripPlan {
        TripPlan(id: "summary", name: "Kauai Thanksgiving", destinationAirport: "LIH",
                 startDay: TripDay(value: "2026-11-26"), endDay: TripDay(value: "2026-12-01"),
                 participants: ["yang", "a", "b", "c"].map { TripParticipant(id: $0, name: $0) }, flights: flights)
    }

    func testUpcomingOverviewCountsPeopleOnceAndSeparatesDirections() {
        let plan = summaryTrip(flights: [summaryFlight(), summaryFlight(id: "connection"),
                                        summaryFlight(id: "return", travelerID: "a", direction: .inbound, day: "2026-12-01"),
                                        summaryFlight(id: "removed", travelerID: "former-member")])
        let now = CloudTrip.timestamp("2026-09-15T22:00:00Z")!
        let outbound = plan.arrivalOverview(direction: .outbound, at: now)
        XCTAssertEqual(outbound.title, "1 of 4 flights added")
        XCTAssertEqual(outbound.detail, "Waiting on 3 travelers")
        XCTAssertEqual(outbound.progressCount, 1)
        XCTAssertEqual(plan.arrivalOverview(direction: .inbound, at: now).progressCount, 1)
    }

    func testReturnOverviewStaysInPlanningDuringOutboundTravel() {
        let plan = summaryTrip(flights: [summaryFlight(), summaryFlight(id: "return", direction: .inbound, day: "2026-12-01")])
        let now = CloudTrip.timestamp("2026-11-27T22:00:00Z")!
        XCTAssertEqual(plan.arrivalOverview(direction: .inbound, at: now).title, "1 of 4 flights added")
        XCTAssertEqual(plan.arrivalOverview(direction: .outbound, at: now).title, "0 of 4 travelers arrived")
    }

    func testArrivalOverviewExcludesStaleFlightsFromNextArrival() {
        let now = CloudTrip.timestamp("2026-11-26T22:00:00Z")!
        var stale = summaryFlight()
        stale.expectedArrival = now.addingTimeInterval(60)
        stale.verifiedAt = now.addingTimeInterval(-3600)
        var next = summaryFlight(id: "next", travelerID: "b")
        next.expectedArrival = CloudTrip.timestamp("2026-11-27T01:46:00Z")!
        next.verifiedAt = now
        let landed = summaryFlight(id: "landed", travelerID: "a", status: .landed)
        let plan = summaryTrip(flights: [stale, landed, next])
        let overview = plan.arrivalOverview(direction: .outbound, at: now)
        XCTAssertEqual(overview.title, "1 of 4 travelers arrived")
        XCTAssertTrue(overview.detail.contains(next.arrivalDayLabel!))
        XCTAssertTrue(overview.detail.contains("15:46"))
        XCTAssertFalse(summaryTrip(flights: [stale]).arrivalOverview(direction: .outbound, at: now).detail.contains("Next:"))
        XCTAssertTrue(summaryTrip(flights: [stale]).arrivalOverview(direction: .outbound, at: now).detail.contains("updates delayed"))
    }

    func testCompletedOverviewPreservesAddedProgressWithoutInventingArrivals() {
        let plan = summaryTrip(flights: [summaryFlight()])
        let overview = plan.arrivalOverview(direction: .outbound, at: CloudTrip.timestamp("2026-12-03T22:00:00Z")!)
        XCTAssertEqual(overview.title, "Trip complete")
        XCTAssertEqual(overview.progressCount, 1)
    }

    func testArrivalDateUsesDestinationDayAndHandlesMissingSchedules() {
        var flight = summaryFlight()
        // UTC is Nov 27, while the arrival in Hawaii is still Nov 26.
        flight.expectedArrival = CloudTrip.timestamp("2026-11-27T01:46:00Z")!
        XCTAssertEqual(flight.arrivalDayLabel, TripDay(value: "2026-11-26").label)
        flight.expectedArrival = nil
        flight.arrivalDayOffset = 1
        XCTAssertEqual(flight.arrivalDayLabel, TripDay(value: "2026-11-27").label)
        XCTAssertNotNil(flight.arrivalTimeZoneLabel)
        XCTAssertNil(summaryFlight(status: .unverified).arrivalDayLabel)
    }

    let sampleJSON = """
    {
        "source": "aerodatabox",
        "flightNumber": "UA353",
        "date": "2026-09-06",
        "fetchedAt": "2026-09-06T16:00:00.000Z",
        "flights": [
            {
                "id": "EWR|LAX|2026-09-06 18:30-04:00",
                "flightNumber": "UA 353",
                "date": "2026-09-06",
                "airline": "United Airlines",
                "departure": {
                    "code": "EWR",
                    "icao": "KEWR",
                    "city": "New York",
                    "name": "Newark Liberty Intl",
                    "timeZone": "America/New_York",
                    "scheduledTime": {
                        "local": "2026-09-06 18:30-04:00",
                        "utc": "2026-09-06 22:30Z"
                    },
                    "revisedTime": {
                        "local": "2026-09-06 19:00-04:00"
                    },
                    "terminal": "C"
                },
                "arrival": {
                    "code": "LAX",
                    "icao": "KLAX",
                    "city": "Los Angeles",
                    "name": "Los Angeles Intl",
                    "timeZone": "America/Los_Angeles",
                    "scheduledTime": {
                        "local": "2026-09-06 21:33-07:00"
                    },
                    "runwayTime": {
                        "local": "2026-09-06 21:40-07:00"
                    },
                    "terminal": "7"
                },
                "status": "landed",
                "providerStatus": "Arrived",
                "aircraft": "Boeing 777-200"
            }
        ]
    }
    """

    func testDecodeFlightLookupResponse() throws {
        let data = sampleJSON.data(using: .utf8)!
        let response = try JSONDecoder().decode(FlightLookupResponse.self, from: data)

        XCTAssertEqual(response.source, "aerodatabox")
        XCTAssertEqual(response.flightNumber, "UA353")
        XCTAssertEqual(response.date, "2026-09-06")
        XCTAssertEqual(response.flights.count, 1)

        let flight = try XCTUnwrap(response.flights.first)
        XCTAssertEqual(flight.flightNumber, "UA 353")
        XCTAssertEqual(flight.airline, "United Airlines")
        XCTAssertEqual(flight.departure.code, "EWR")
        XCTAssertEqual(flight.arrival.code, "LAX")
        XCTAssertEqual(flight.departureTimeFormatted, "19:00") // Revised time preferred
        XCTAssertEqual(flight.arrivalTimeFormatted, "21:40") // Runway time preferred
        XCTAssertEqual(flight.terminalFormatted, "Terminal 7")
        XCTAssertEqual(flight.tripStatus, .landed)
        XCTAssertEqual(flight.arrivalDayOffset, 0)
    }

    func testStatusMapping() {
        func candidate(with status: String) -> FlightCandidate {
            FlightCandidate(
                id: "test",
                flightNumber: "UA 1",
                date: "2026-09-06",
                departure: FlightEndpoint(code: "SFO"),
                arrival: FlightEndpoint(code: "HNL"),
                status: status
            )
        }

        XCTAssertEqual(candidate(with: "landed").tripStatus, .landed)
        XCTAssertEqual(candidate(with: "arrived").tripStatus, .landed)
        XCTAssertEqual(candidate(with: "boarding").tripStatus, .boarding)
        XCTAssertEqual(candidate(with: "delayed").tripStatus, .delayed)
        XCTAssertEqual(candidate(with: "airborne").tripStatus, .airborne)
        XCTAssertEqual(candidate(with: "enroute").tripStatus, .airborne)
        XCTAssertEqual(candidate(with: "scheduled").tripStatus, .scheduled)
        XCTAssertEqual(candidate(with: "expected").tripStatus, .scheduled)
        XCTAssertEqual(candidate(with: "unknown").tripStatus, .unknown)
        XCTAssertEqual(candidate(with: "cancelled").tripStatus, .cancelled)
        XCTAssertEqual(candidate(with: "diverted").tripStatus, .diverted)
    }

    func testLocalDemoRepositoryFlightLookup() async throws {
        let repo = LocalDemoRepository()
        let results = try await repo.lookupFlight(tripID: "example-west", flightNumber: "UA 353", date: "2026-09-06")

        XCTAssertFalse(results.isEmpty)
        let first = results[0]
        XCTAssertEqual(first.flightNumber, "UA 353")
        XCTAssertEqual(first.departure.code, "EWR")
        XCTAssertEqual(first.arrival.code, "LAX")
        XCTAssertEqual(first.departureTimeFormatted, "18:30")
        XCTAssertEqual(first.arrivalTimeFormatted, "21:33")
        XCTAssertEqual(first.terminalFormatted, "Terminal 7")
    }

    func testOvernightFlightDayOffset() {
        let overnight = FlightCandidate(
            id: "test-red-eye",
            flightNumber: "UA 100",
            date: "2026-09-06",
            departure: FlightEndpoint(code: "LAX", scheduledTime: FlightTimePair(local: "2026-09-06 23:00-07:00")),
            arrival: FlightEndpoint(code: "EWR", scheduledTime: FlightTimePair(local: "2026-09-07 07:15-04:00")),
            status: "scheduled"
        )
        XCTAssertEqual(overnight.arrivalDayOffset, 1)

        let sameDay = FlightCandidate(
            id: "test-day",
            flightNumber: "UA 200",
            date: "2026-09-06",
            departure: FlightEndpoint(code: "LAX", scheduledTime: FlightTimePair(local: "2026-09-06 08:00-07:00")),
            arrival: FlightEndpoint(code: "SFO", scheduledTime: FlightTimePair(local: "2026-09-06 09:30-07:00")),
            status: "scheduled"
        )
        XCTAssertEqual(sameDay.arrivalDayOffset, 0)
    }

    func testChinaSouthernCZ328FlightLookup() async throws {
        let repo = LocalDemoRepository()
        let results = try await repo.lookupFlight(tripID: "example-west", flightNumber: "CZ 328", date: "2026-09-06")

        XCTAssertTrue(results.isEmpty, "Demo mode must not call a live provider")
        let wrongAirline = try await repo.lookupFlight(tripID: "example-west", flightNumber: "CZ353", date: "2026-09-06")
        XCTAssertTrue(wrongAirline.isEmpty)
    }

    func testAirportLocationLookupAndSearch() {
        // Verify Palm Springs (PSP) dataset entry
        let psp = AirportLocation.location(for: "PSP")
        XCTAssertNotNil(psp)
        XCTAssertEqual(psp?.code, "PSP")
        XCTAssertEqual(psp?.city, "Palm Springs")
        XCTAssertEqual(psp?.timeZoneIdentifier, "America/Los_Angeles")
        XCTAssertEqual(psp?.timeZone, TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertEqual(psp?.coordinate.latitude ?? 0, 33.8297, accuracy: 0.01)
        XCTAssertEqual(psp?.coordinate.longitude ?? 0, -116.5067, accuracy: 0.01)

        // Verify search by city name and by code
        let searchByCity = AirportLocation.search("Palm Springs")
        XCTAssertTrue(searchByCity.contains(where: { $0.code == "PSP" }))

        let searchByCode = AirportLocation.search("psp")
        XCTAssertTrue(searchByCode.contains(where: { $0.code == "PSP" }))

        // Multi-airport city (Tokyo: NRT and HND)
        let tokyoSearch = AirportLocation.search("Tokyo")
        XCTAssertTrue(tokyoSearch.contains(where: { $0.code == "NRT" }))
        XCTAssertTrue(tokyoSearch.contains(where: { $0.code == "HND" }))
    }

    func testAirportLocationRejectsFakeCodes() {
        // Unknown codes return nil instead of fabricating fake airports
        XCTAssertNil(AirportLocation.location(for: "ZZZ"))
        XCTAssertNil(AirportLocation.location(for: "NONEXISTENT"))
        let searchInvalid = AirportLocation.search("ZZZ")
        XCTAssertTrue(searchInvalid.isEmpty)
    }
}
