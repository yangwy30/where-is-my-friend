import XCTest
@testable import WhereIsMyFriend

final class SameCityHeaderRegressionTests: XCTestCase {
    func testMutingAlertsDoesNotHideVisibleSameCityFriends() throws {
        var snapshot = DemoData.initialSnapshot()
        let friend = try XCTUnwrap(SameCityPresencePolicy.currentFriends(in: snapshot).first)
        let index = try XCTUnwrap(snapshot.friendPreferences.firstIndex { $0.friendID == friend.id })
        snapshot.friendPreferences[index].sameCityAlertEnabled = false
        XCTAssertTrue(SameCityPresencePolicy.currentFriends(in: snapshot).contains { $0.id == friend.id })
        XCTAssertFalse(SameCityAlertPolicy.currentFriends(in: snapshot).contains { $0.id == friend.id })
    }

    func testPausedSharingAndRevokedFriendAccessStillHideSummary() throws {
        var snapshot = DemoData.initialSnapshot()
        let friend = try XCTUnwrap(SameCityPresencePolicy.currentFriends(in: snapshot).first)
        let index = try XCTUnwrap(snapshot.friendPreferences.firstIndex { $0.friendID == friend.id })
        snapshot.friendPreferences[index].sharesMyCity = false
        XCTAssertFalse(SameCityPresencePolicy.currentFriends(in: snapshot).contains { $0.id == friend.id })
        snapshot.friendPreferences[index].sharesMyCity = true
        snapshot.blockedPeople = [BlockedPerson(id: friend.id, displayName: friend.displayName, username: friend.username, avatarPalette: friend.avatarPalette, blockedAt: Date())]
        XCTAssertFalse(SameCityPresencePolicy.currentFriends(in: snapshot).contains { $0.id == friend.id })
        snapshot.blockedPeople = []
        snapshot.sharingPreferences.citySharingEnabled = false
        XCTAssertTrue(SameCityPresencePolicy.currentFriends(in: snapshot).isEmpty)
    }

    func testExpiredObservationDoesNotProduceCurrentSameCitySummary() {
        var snapshot = DemoData.initialSnapshot()
        snapshot.currentPresence.updatedAt = Date().addingTimeInterval(-24 * 3600)
        XCTAssertTrue(SameCityPresencePolicy.currentFriends(in: snapshot).isEmpty)
    }

    func testHiddenSummaryStaysCollapsedWhenSharingOrMatchesReturn() {
        var snapshot = DemoData.initialSnapshot()
        var expansion = SameCityExpansionState()
        let shown = SameCityExpansionContext(isVisible: true, presence: snapshot.currentPresence)
        expansion.reconcile(shown)
        expansion.toggle()
        XCTAssertTrue(expansion.isExpanded)

        snapshot.sharingPreferences.citySharingEnabled = false
        expansion.reconcile(SameCityExpansionContext(
            isVisible: !SameCityPresencePolicy.currentFriends(in: snapshot).isEmpty, presence: snapshot.currentPresence))
        XCTAssertFalse(expansion.isExpanded)
        snapshot.sharingPreferences.citySharingEnabled = true
        expansion.reconcile(shown)
        XCTAssertFalse(expansion.isExpanded, "Restoring visibility must never expand automatically")

        expansion.toggle()
        snapshot.friends.removeAll()
        expansion.reconcile(SameCityExpansionContext(
            isVisible: !SameCityPresencePolicy.currentFriends(in: snapshot).isEmpty, presence: snapshot.currentPresence))
        expansion.reconcile(shown)
        XCTAssertFalse(expansion.isExpanded, "A returning match must require another explicit tap")
    }

    func testChangingCurrentCityCollapsesAnExpandedSummary() {
        var presence = DemoData.initialSnapshot().currentPresence
        var expansion = SameCityExpansionState()
        expansion.reconcile(SameCityExpansionContext(isVisible: true, presence: presence))
        expansion.toggle()
        presence.city = "London"
        presence.countryCode = "GB"
        presence.administrativeArea = "England"
        expansion.reconcile(SameCityExpansionContext(isVisible: true, presence: presence))
        XCTAssertFalse(expansion.isExpanded)
        expansion.reconcile(SameCityExpansionContext(isVisible: true, presence: presence))
        XCTAssertFalse(expansion.isExpanded)
    }

    func testRefreshingSameCityPreservesOnlyTheUsersExpansionChoice() {
        var presence = DemoData.initialSnapshot().currentPresence
        var expansion = SameCityExpansionState()
        expansion.reconcile(SameCityExpansionContext(isVisible: true, presence: presence))
        XCTAssertFalse(expansion.isExpanded)
        presence.updatedAt = Date().addingTimeInterval(60)
        expansion.reconcile(SameCityExpansionContext(isVisible: true, presence: presence))
        XCTAssertFalse(expansion.isExpanded)
        expansion.toggle()
        presence.updatedAt = Date().addingTimeInterval(120)
        expansion.reconcile(SameCityExpansionContext(isVisible: true, presence: presence))
        XCTAssertTrue(expansion.isExpanded)
        expansion.collapse()
        expansion.reconcile(SameCityExpansionContext(isVisible: true, presence: presence))
        XCTAssertFalse(expansion.isExpanded)
    }
}
