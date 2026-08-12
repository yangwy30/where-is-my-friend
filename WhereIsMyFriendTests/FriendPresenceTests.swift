import XCTest
@testable import WhereIsMyFriend

final class FriendPresenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFreshnessTransitions() {
        let fresh = makeFriend(updatedAt: now.addingTimeInterval(-30 * 60))
        let aging = makeFriend(updatedAt: now.addingTimeInterval(-3 * 60 * 60))
        let stale = makeFriend(updatedAt: now.addingTimeInterval(-25 * 60 * 60))

        XCTAssertEqual(fresh.freshness(at: now), .fresh)
        XCTAssertEqual(aging.freshness(at: now), .aging)
        XCTAssertEqual(stale.freshness(at: now), .stale)
    }

    func testPausedPresenceIsUnavailableAndNotSameCityEligible() {
        let paused = FriendPresence(
            displayName: "Mia Chen",
            username: "mia",
            city: "New York",
            countryCode: "US",
            updatedAt: now.addingTimeInterval(-60),
            sharingState: .paused
        )

        XCTAssertEqual(paused.freshness(at: now), .unavailable)
        XCTAssertFalse(paused.isSameCityEligible(at: now))
        XCTAssertFalse(paused.cityDisplay.isEmpty)
    }

    func testSameCityMatchingExcludesAgingAndOtherCities() {
        let freshNewYork = makeFriend(name: "Mia", city: "New York", updatedAt: now.addingTimeInterval(-60))
        let agingNewYork = makeFriend(name: "Alex", city: "New York", updatedAt: now.addingTimeInterval(-3 * 60 * 60))
        let freshTokyo = makeFriend(name: "Lin", city: "Tokyo", updatedAt: now.addingTimeInterval(-60))

        let matches = MockFriendData.sameCityFriends(
            from: [freshNewYork, agingNewYork, freshTokyo],
            currentCity: "new york",
            now: now
        )

        XCTAssertEqual(matches.map(\.displayName), ["Mia"])
    }

    func testCountryCodeBuildsFlag() {
        XCTAssertEqual(makeFriend(countryCode: "US", updatedAt: now).countryFlag, "🇺🇸")
        XCTAssertEqual(makeFriend(countryCode: nil, updatedAt: now).countryFlag, "")
    }

    private func makeFriend(
        name: String = "Test Friend",
        city: String = "New York",
        countryCode: String? = "US",
        updatedAt: Date
    ) -> FriendPresence {
        FriendPresence(
            displayName: name,
            username: name.lowercased().replacingOccurrences(of: " ", with: ""),
            city: city,
            countryCode: countryCode,
            updatedAt: updatedAt
        )
    }
}
