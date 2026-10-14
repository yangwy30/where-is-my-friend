import XCTest
@testable import WhereIsMyFriend

final class WidgetAuditRegressionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_590_400)

    private func friend(_ name: String, city: String = "Sunnyvale", age: TimeInterval = 300,
                        sharing: PresenceSharingState = .active) -> FriendPresence {
        FriendPresence(displayName: name, username: name.lowercased(), city: city,
                       countryCode: "US", updatedAt: now.addingTimeInterval(-age),
                       sharingState: sharing, administrativeArea: "CA")
    }

    private func content(_ friends: [FriendPresence]) -> HomeWidgetContent {
        HomeWidgetContent(date: now, friends: friends,
            currentPresence: CurrentUserPresence(administrativeArea: "CA", city: "Sunnyvale",
                countryCode: "US", updatedAt: now.addingTimeInterval(-600), source: .foregroundLocation),
            privacyMode: .full)
    }

    func testNoSameCityMatchDoesNotFallBackToFriendsElsewhere() {
        let value = content([friend("Mia", city: "San Francisco"), friend("Kai", city: "Los Angeles")])
        XCTAssertTrue(value.lockScreenFriends(sameCityOnly: true).isEmpty)
        XCTAssertEqual(value.lockScreenDestination(sameCityOnly: true), SharedAppLink.make(host: "home"))
    }

    func testOneSameCityMatchDoesNotFillSecondColumnWithDistantFriend() {
        let near = friend("Mia")
        let value = content([friend("Kai", city: "Los Angeles"), near])
        XCTAssertEqual(value.lockScreenFriends(sameCityOnly: true).map(\.id), [near.id])
        XCTAssertEqual(FriendDetailLink.parse(value.lockScreenDestination(sameCityOnly: true)), near.id)
    }

    func testTwoSameCityMatchesRemainInSourceOrder() {
        let first = friend("Mia"), second = friend("Kai")
        let value = content([first, friend("Jules", city: "Oakland"), second, friend("Lin")])
        XCTAssertEqual(value.lockScreenFriends(sameCityOnly: true).map(\.id), [first.id, second.id])
        XCTAssertEqual(value.lockScreenDestination(sameCityOnly: true), SharedAppLink.make(host: "home"))
    }

    func testExpiredOrPausedPresenceIsNotShownAsSameCity() {
        var value = content([friend("Old", age: 24 * 3600), friend("Paused", sharing: .paused)])
        XCTAssertTrue(value.lockScreenFriends(sameCityOnly: true).isEmpty)
        value.friends = [friend("Recent")]
        value.currentPresence.updatedAt = now.addingTimeInterval(-24 * 3600)
        XCTAssertTrue(value.lockScreenFriends(sameCityOnly: true).isEmpty)
    }

    func testHiddenModesDoNotExposeFriendIdentityThroughLink() {
        let person = friend("Private Person")
        var value = content([person])
        value.privacyMode = .hideNames
        XCTAssertEqual(value.lockScreenFriends(sameCityOnly: true).map(\.id), [person.id])
        XCTAssertEqual(value.name(for: person), String(localized: "Friend"))
        for sameCityOnly in [false, true] {
            XCTAssertEqual(value.lockScreenDestination(sameCityOnly: sameCityOnly), SharedAppLink.make(host: "home"))
        }
        value.privacyMode = .hideAll
        for sameCityOnly in [false, true] {
            XCTAssertTrue(value.lockScreenFriends(sameCityOnly: sameCityOnly).isEmpty)
            XCTAssertEqual(value.lockScreenDestination(sameCityOnly: sameCityOnly), SharedAppLink.make(host: "home"))
        }
    }

    func testGenericFriendWidgetKeepsDistantFriendsAndExistingOrder() {
        let first = friend("Mia", city: "Oakland"), second = friend("Kai", city: "Los Angeles")
        let value = content([first, second, friend("Nearby")])
        XCTAssertEqual(value.lockScreenFriends(sameCityOnly: false).map(\.id), [first.id, second.id])
        let single = content([first])
        XCTAssertEqual(FriendDetailLink.parse(single.lockScreenDestination(sameCityOnly: false)), first.id)
    }
}
