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

        // 2. City Sharing Sheet
        let cityCard = app.buttons["myCitySharingCard"]
        if cityCard.waitForExistence(timeout: 3) {
            cityCard.tap()
            sleep(2)
            let shot2 = XCUIScreen.main.screenshot()
            try? shot2.pngRepresentation.write(to: dir.appendingPathComponent("02_city_sharing_privacy.png"))
            let doneButton = app.buttons["Done"]
            if doneButton.waitForExistence(timeout: 2) {
                doneButton.tap()
            }
            sleep(1)
        }

        // 3. Tap Friend Detail (Lin Zhao)
        let linZhaoText = app.staticTexts["Lin Zhao"]
        if linZhaoText.waitForExistence(timeout: 3) {
            linZhaoText.tap()
            sleep(2)
            let shot3 = XCUIScreen.main.screenshot()
            try? shot3.pngRepresentation.write(to: dir.appendingPathComponent("03_friend_detail.png"))
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
            sleep(1)
        }

        // 4. Same-city moments / Co-presence days screen
        let profileTab = app.tabBars.buttons.element(boundBy: 1)
        if profileTab.waitForExistence(timeout: 3) {
            profileTab.tap()
            sleep(1)
            let momentsLink = app.buttons["sameCityMomentsLink"]
            if momentsLink.waitForExistence(timeout: 3) {
                momentsLink.tap()
                sleep(2)
                let shotMoments = XCUIScreen.main.screenshot()
                try? shotMoments.pngRepresentation.write(to: dir.appendingPathComponent("06_same_city_moments_days.png"))
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                }
                sleep(1)
            }

            // 4b. Widget Studio
            let profileScreen = app.scrollViews["profileSettingsScreen"]
            if profileScreen.waitForExistence(timeout: 3) {
                profileScreen.swipeUp()
                profileScreen.swipeUp()
                sleep(1)
            }
            let widgetStudioBtn = app.buttons["widgetStudioLink"]
            if widgetStudioBtn.waitForExistence(timeout: 3) {
                widgetStudioBtn.tap()
                sleep(2)
                let shotWidget = XCUIScreen.main.screenshot()
                try? shotWidget.pngRepresentation.write(to: dir.appendingPathComponent("07_widget_studio.png"))
                if app.navigationBars.buttons.firstMatch.exists {
                    app.navigationBars.buttons.firstMatch.tap()
                }
                sleep(1)
            }
        }

        // 5. Onboarding Step 0
        let ob0 = XCUIApplication()
        ob0.launchArguments = ["-previewOnboarding", "-previewOnboardingStep=0", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        ob0.launch()
        sleep(2)
        let shot5_0 = XCUIScreen.main.screenshot()
        try? shot5_0.pngRepresentation.write(to: dir.appendingPathComponent("05_onboarding_step0.png"))

        // 6. Onboarding Step 1 (Privacy)
        let ob1 = XCUIApplication()
        ob1.launchArguments = ["-previewOnboarding", "-previewOnboardingStep=1", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        ob1.launch()
        sleep(2)
        let shot5_1 = XCUIScreen.main.screenshot()
        try? shot5_1.pngRepresentation.write(to: dir.appendingPathComponent("05_onboarding_step1.png"))

        // 7. Onboarding Step 2 (Same-city Reunion)
        let ob2 = XCUIApplication()
        ob2.launchArguments = ["-previewOnboarding", "-previewOnboardingStep=2", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        ob2.launch()
        sleep(2)
        let shot5_2 = XCUIScreen.main.screenshot()
        try? shot5_2.pngRepresentation.write(to: dir.appendingPathComponent("05_onboarding_step2.png"))

        // 8. 3D Diorama Widget Studio
        let widgetApp = XCUIApplication()
        widgetApp.launchArguments = ["-previewWidgets", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        widgetApp.launch()
        sleep(2)
        let shotWidget = XCUIScreen.main.screenshot()
        try? shotWidget.pngRepresentation.write(to: dir.appendingPathComponent("07_widget_studio.png"))
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
