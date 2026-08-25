import XCTest

final class PrototypeUITests: XCTestCase {
    func testOfflineEndToEndFlow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))

        let addButton = app.buttons["addFriendButton"]
        XCTAssertTrue(addButton.exists)
        addButton.tap()

        XCTAssertTrue(app.scrollViews["addFriendScreen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["currentUsernameCard"].exists)
        XCTAssertTrue(app.buttons["acceptRequestButton"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["acceptRequestButton"].firstMatch.tap()
        app.buttons["doneAddFriendButton"].tap()
        XCTAssertTrue(app.staticTexts["Jamie Park"].waitForExistence(timeout: 3))

        let cityCard = app.buttons["myCitySharingCard"]
        XCTAssertTrue(cityCard.waitForExistence(timeout: 3))
        cityCard.tap()
        XCTAssertTrue(app.descendants(matching: .any)["citySharingSheet"].waitForExistence(timeout: 3))
        app.buttons["citySourceButton"].tap()
        app.buttons["Choose city manually"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["cityPickerScreen"].waitForExistence(timeout: 3))
    }

    func testProfileEditingAndWidgetPrivacyControls() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["editProfileButton"].waitForExistence(timeout: 3))
        app.buttons["editProfileButton"].tap()

        let nameField = app.textFields["displayNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "New Name")
        app.buttons["saveProfileButton"].tap()
        XCTAssertTrue(app.staticTexts["New Name"].waitForExistence(timeout: 3))

        let privacySettings = app.buttons["widgetPrivacySettingsLink"]
        if !privacySettings.isHittable {
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(privacySettings.waitForExistence(timeout: 3))
        privacySettings.tap()
        XCTAssertTrue(app.descendants(matching: .any)["widgetPrivacyScreen"].waitForExistence(timeout: 3))
        let hideEverything = app.buttons["widgetPrivacyHideAll"]
        XCTAssertTrue(hideEverything.waitForExistence(timeout: 3))
        hideEverything.tap()
        XCTAssertEqual(hideEverything.value as? String, "selected")
    }

    func testNotificationSettingsSeparatesPermissionAndDeviceRegistration() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 1).tap()

        let settingsLink = app.buttons["notificationSettingsLink"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 3))
        settingsLink.tap()

        XCTAssertTrue(app.scrollViews["notificationSettingsScreen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["notificationPermissionCard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["devicePushRegistrationCard"].exists)
    }
}

private extension XCUIElement {
    func replaceText(with text: String) {
        tap()
        if let currentValue = value as? String, !currentValue.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        typeText(text)
    }
}
