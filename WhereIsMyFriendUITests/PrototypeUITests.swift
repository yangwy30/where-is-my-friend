import XCTest

final class PrototypeUITests: XCTestCase {
    func testFriendsScreenAndAddFriendSheetAreReachable() {
        let app = XCUIApplication()
        app.launchArguments.append("-skipOnboarding")
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))

        let addButton = app.buttons["addFriendButton"]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        XCTAssertTrue(app.scrollViews["addFriendScreen"].waitForExistence(timeout: 3))
    }
}
