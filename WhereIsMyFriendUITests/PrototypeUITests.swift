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
        XCTAssertTrue(app.buttons["acceptRequestButton"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["acceptRequestButton"].firstMatch.tap()
        if app.alerts.firstMatch.waitForExistence(timeout: 2) {
            app.alerts.firstMatch.buttons.firstMatch.tap()
        }
        app.buttons["doneAddFriendButton"].tap()
        XCTAssertTrue(app.staticTexts["Jamie Park"].waitForExistence(timeout: 3))

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.scrollViews["sharingScreen"].waitForExistence(timeout: 3))
        app.buttons["chooseCityButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["cityPickerScreen"].waitForExistence(timeout: 3))
    }

    func testProfileEditingAndWidgetPrivacyControls() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.buttons["editProfileButton"].waitForExistence(timeout: 3))
        app.buttons["editProfileButton"].tap()

        let nameField = app.textFields["displayNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "New Name")
        app.buttons["saveProfileButton"].tap()
        if app.alerts.firstMatch.waitForExistence(timeout: 2) {
            app.alerts.firstMatch.buttons.firstMatch.tap()
        }
        XCTAssertTrue(app.staticTexts["New Name"].waitForExistence(timeout: 3))

        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(app.scrollViews["sharingScreen"].waitForExistence(timeout: 3))
        app.scrollViews["sharingScreen"].swipeUp()
        let privacyPicker = app.buttons["widgetPrivacyPicker"]
        XCTAssertTrue(privacyPicker.waitForExistence(timeout: 3))
        privacyPicker.tap()
        let hideEverything = app.buttons["widgetPrivacyHideAll"]
        XCTAssertTrue(hideEverything.waitForExistence(timeout: 3))
        hideEverything.tap()
        XCTAssertEqual(privacyPicker.value as? String, "hideAll")
    }

    func testNotificationSettingsSeparatesPermissionAndDeviceRegistration() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 2).tap()

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
