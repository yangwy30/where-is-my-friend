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
        XCTAssertTrue(app.switches["citySharingToggle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.switches["backgroundUpdatesToggle"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["refreshLocationButton"].waitForExistence(timeout: 3))
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
            app.scrollViews["profileSettingsScreen"].swipeUp()
        }
        XCTAssertTrue(privacySettings.waitForExistence(timeout: 3))
        privacySettings.tap()
        XCTAssertTrue(app.descendants(matching: .any)["widgetPrivacyScreen"].waitForExistence(timeout: 3))
        let hideEverything = app.buttons["widgetPrivacyHideAll"]
        XCTAssertTrue(hideEverything.waitForExistence(timeout: 3))
        hideEverything.tap()
        XCTAssertEqual(hideEverything.value as? String, "1")
    }

    func testNotificationSettingsKeepsPushRegistrationAutomatic() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 1).tap()

        let settingsLink = app.buttons["notificationSettingsLink"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 3))
        settingsLink.tap()

        XCTAssertTrue(app.descendants(matching: .any)["notificationSettingsScreen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["notificationPermissionCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["devicePushRegistrationCard"].exists)
        XCTAssertFalse(app.buttons["retryPushRegistrationButton"].exists)
    }

    func testAppearanceCanSwitchBetweenSolarAndNightJade() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 1).tap()

        let appearanceButton = app.buttons["appearanceSettingsButton"]
        if !appearanceButton.isHittable {
            app.scrollViews["profileSettingsScreen"].swipeUp()
        }
        XCTAssertTrue(appearanceButton.waitForExistence(timeout: 3))
        appearanceButton.tap()

        let solar = app.buttons["solarJadeAppearance"]
        let night = app.buttons["nightJadeAppearance"]
        XCTAssertTrue(solar.waitForExistence(timeout: 3))
        XCTAssertTrue(night.exists)

        solar.tap()
        XCTAssertEqual(solar.value as? String, "1")
        night.tap()
        XCTAssertEqual(night.value as? String, "1")

        app.buttons["appearanceDoneButton"].tap()
        let profileScreen = app.scrollViews["profileSettingsScreen"]
        XCTAssertTrue(profileScreen.waitForExistence(timeout: 3))
        XCTAssertEqual(profileScreen.value as? String, "nightJade")
    }

    func testCaptureAppStoreScreenshots() {
        continueAfterFailure = false
        let dir = URL(fileURLWithPath: "/Users/wangyang/.gemini/antigravity-insiders/brain/a9fe7251-03e8-4092-990c-527a6ef21b48/raw_screenshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        sleep(2)
        let shot1 = XCUIScreen.main.screenshot()
        try? shot1.pngRepresentation.write(to: dir.appendingPathComponent("01_friends_main.png"))

        // Tap Lin Zhao or Mia Chen for detail
        let miaCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Mia Chen'")).firstMatch
        if miaCard.waitForExistence(timeout: 3) {
            miaCard.tap()
            sleep(2)
            let shot2 = XCUIScreen.main.screenshot()
            try? shot2.pngRepresentation.write(to: dir.appendingPathComponent("02_friend_detail.png"))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sleep(1)
        }

        // Tap City Sharing card
        let cityCard = app.buttons["myCitySharingCard"]
        if cityCard.waitForExistence(timeout: 3) {
            cityCard.tap()
            sleep(2)
            let shot3 = XCUIScreen.main.screenshot()
            try? shot3.pngRepresentation.write(to: dir.appendingPathComponent("03_city_sharing_privacy.png"))
            app.swipeDown()
            sleep(1)
        }

        // Profile -> City Emblem Gallery
        app.tabBars.buttons.element(boundBy: 1).tap()
        sleep(1)
        let galleryButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'City Emblem Gallery'")).firstMatch
        if !galleryButton.isHittable {
            app.scrollViews["profileSettingsScreen"].swipeUp()
            sleep(1)
        }
        if galleryButton.waitForExistence(timeout: 3) {
            galleryButton.tap()
            sleep(2)
            let shot4 = XCUIScreen.main.screenshot()
            try? shot4.pngRepresentation.write(to: dir.appendingPathComponent("04_city_emblems.png"))
        }

        // Fresh Onboarding
        let onboardingApp = XCUIApplication()
        onboardingApp.launchArguments = ["-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        onboardingApp.launch()
        sleep(2)
        let shot5 = XCUIScreen.main.screenshot()
        try? shot5.pngRepresentation.write(to: dir.appendingPathComponent("05_onboarding.png"))
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
