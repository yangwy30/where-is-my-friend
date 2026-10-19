import XCTest

final class PrototypeUITests: XCTestCase {
    func testAuditFriendInvitationFailureIsVisibleAndRetryWorks() {
        continueAfterFailure = false
        let app = waveTwoApp()
        app.buttons["addFriendButton"].tap()
        let field = app.textFields["friendUsernameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        for _ in 0..<6 where !field.isHittable { app.scrollViews["addFriendScreen"].swipeUp() }
        field.tap(); field.typeText("missing_user_123\n")
        capture("AUDIT-friend-invitation-error")
        XCTAssertTrue(app.staticTexts["friendRequestError"].waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "missing_user_123")
        field.replaceText(with: "leo"); field.typeText("\n")
        let pending = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "withdrawFriendRequest-")).firstMatch
        for _ in 0..<7 where !pending.isHittable { app.scrollViews["addFriendScreen"].swipeUp() }
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
    }

    func testAuditIncomingInviteFailureRemainsVisibleAndCanBeDismissed() {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.open(URL(string: "whereismyfriend://invite/missing_user_123")!)
        let send = app.buttons["acceptIncomingInvite"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        for _ in 0..<5 where !send.isHittable { app.swipeUp() }
        XCTAssertTrue(send.isHittable)
        capture("AUDIT-invite-link-action-largest-text")
        send.tap()
        let error = app.staticTexts["incomingInviteError"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        for _ in 0..<5 where !error.isHittable || error.frame.maxY > app.frame.maxY - 12 { app.swipeUp() }
        XCTAssertTrue(error.isHittable)
        XCTAssertGreaterThanOrEqual(error.frame.minY, 80)
        XCTAssertLessThanOrEqual(error.frame.maxY, app.frame.maxY - 12)
        capture("AUDIT-invite-link-error-largest-text")
        for _ in 0..<5 where !send.isHittable { app.swipeDown() }
        XCTAssertTrue(send.isEnabled); send.tap()
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        let cancel = app.buttons["Not now"]
        for _ in 0..<5 where !cancel.isHittable { app.swipeUp() }
        cancel.tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(error.exists)
    }

    func testAuditIncomingFriendRequestAtLargestText() {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-testReadableRequest", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.open(URL(string: "whereismyfriend://friend-requests/05000000-0000-4000-8000-000000000001")!)
        let accept = app.buttons["acceptNotificationFriendRequest"]
        XCTAssertTrue(accept.waitForExistence(timeout: 8))
        let scroll = app.scrollViews["friendRequestNotificationScroll"]
        for _ in 0..<5 where !accept.isHittable || accept.frame.maxY > app.frame.maxY { scroll.swipeUp() }
        XCTAssertTrue(accept.isHittable); assertTouchTarget(accept)
        XCTAssertLessThanOrEqual(accept.frame.maxY, app.frame.maxY)
        capture("AUDIT-received-request-largest-text")
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5))
    }

    func testAuditIntegratedHeaderShowsPeopleAndOpensFriend() {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-testSameCityHeader"])
        let chip = app.buttons["sameCitySummaryTitle"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertTrue(chip.label.contains("3 friends are here too"))
        XCTAssertLessThan(chip.frame.maxY, app.frame.height * 0.45)
        assertTouchTarget(chip)
        capture("AUDIT-header-three-chip-en")
        chip.tap()
        let friend = app.buttons["sameCityFriend-mia"]
        XCTAssertTrue(friend.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["sameCityFriend-lin"].exists)
        XCTAssertTrue(app.buttons["sameCityFriend-chloe"].exists)
        XCTAssertFalse(app.staticTexts["Same city. Good company."].exists)
        capture("AUDIT-header-three-sheet-en")
        // A scroll view waits briefly to tell a tap from a drag, so an instant synthesized
        // tap is dropped; press about as long as a finger does.
        Thread.sleep(forTimeInterval: 1)
        friend.press(forDuration: 0.15)
        XCTAssertTrue(app.navigationBars["Mia"].waitForExistence(timeout: 5))
    }

    func testAuditIntegratedHeaderInDarkMode() throws {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-testSameCityHeader"])
        selectAppearance("nightJadeAppearance", in: app)
        let chip = app.buttons["sameCitySummaryTitle"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        assertTouchTarget(chip)
        capture("AUDIT-header-dark-chip")
        try auditRelevantControls(app, prefixes: ["sameCitySummaryTitle"], name: "integrated-header-dark")
        chip.tap()
        XCTAssertTrue(app.buttons["sameCityFriend-mia"].waitForExistence(timeout: 5))
        capture("AUDIT-header-dark-sheet")
        try auditRelevantControls(app, prefixes: ["sameCityFriend-"], name: "integrated-header-dark-sheet")
        app.buttons["Done"].tap()
        selectAppearance("solarJadeAppearance", in: app)
    }

    func testAuditIntegratedHeaderAtLargestChineseText() throws {
        continueAfterFailure = false
        let app = waveTwoApp(language: "zh-Hans", locale: "zh_CN", extra: ["-testSameCityHeader", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let chip = app.buttons["sameCitySummaryTitle"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5)); assertTouchTarget(chip)
        XCTAssertTrue(chip.label.contains("3 位朋友也在这里"))
        capture("AUDIT-header-large-chip-zh")
        chip.tap()
        let friend = app.buttons["sameCityFriend-mia"]
        XCTAssertTrue(friend.waitForExistence(timeout: 4))
        for _ in 0..<5 where !friend.isHittable { app.swipeUp() }
        assertTouchTarget(friend)
        capture("AUDIT-header-large-sheet-zh")
        try auditRelevantControls(app, prefixes: ["sameCityFriend-"], name: "integrated-header")
    }

    func testAuditMutingSameCityAlertDoesNotHideHeader() {
        continueAfterFailure = false
        let app = waveTwoApp()
        selectAppTab(2, in: app)
        let entry = app.buttons["notificationSettingsLink"]
        for _ in 0..<6 where !entry.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        entry.tap(); app.buttons["notificationSameCitySettings"].tap()
        let toggle = app.switches["notificationFriend-mia"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if toggle.value as? String == "1" { toggle.switches.firstMatch.tap() }
        XCTAssertEqual(toggle.value as? String, "0")
        selectAppTab(0, in: app)
        XCTAssertTrue(app.buttons["sameCitySummaryTitle"].waitForExistence(timeout: 5))
        capture("AUDIT-muted-alert-keeps-same-city-summary")
    }

    func testAuditRevokedFriendCannotKeepCachedDetailsVisible() {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-testFriendRevokedAfterOpen"])
        app.buttons["friendCard-10000000-0000-0000-0000-000000000001"].tap()
        XCTAssertTrue(app.navigationBars["Friend unavailable"].waitForExistence(timeout: 12))
        XCTAssertFalse(app.switches["friendCitySharingToggle"].exists)
        XCTAssertFalse(app.buttons["removeFriendButton"].exists)
        capture("AUDIT-revoked-friend-unavailable")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["friendCard-10000000-0000-0000-0000-000000000001"].exists)
    }

    func testAuditOfflineHomeExplainsCachedCitiesAndRetry() {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-testOfflineHome"])
        XCTAssertTrue(app.staticTexts["Couldn’t refresh cities"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["retryHomeSync"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Last synced ")).firstMatch.exists)
        capture("AUDIT-offline-home")
        app.buttons["retryHomeSync"].tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].exists)
    }

    func testAuditPersonalPlanAndProfileProtectUnsavedChanges() {
        continueAfterFailure = false
        let app = waveTwoApp()
        selectAppTab(2, in: app)
        app.buttons["editProfileButton"].tap()
        let name = app.textFields["displayNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let original = name.value as? String
        name.replaceText(with: "Unsaved audit name")
        XCTAssertEqual(name.value as? String, "Unsaved audit name")
        capture("AUDIT-profile-draft-before-close")
        app.buttons["closeProfileButton"].tap()
        capture("AUDIT-profile-discard-dialog")
        XCTAssertTrue(app.buttons["Keep editing"].firstMatch.waitForExistence(timeout: 3)); app.buttons["Keep editing"].firstMatch.tap()
        XCTAssertEqual(name.value as? String, "Unsaved audit name")
        app.buttons["closeProfileButton"].tap()
        let profileDiscard = app.alerts.buttons["Discard changes"].firstMatch
        XCTAssertTrue(profileDiscard.waitForExistence(timeout: 3))
        profileDiscard.tap()
        capture("AUDIT-profile-after-discard")
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        app.buttons["editProfileButton"].tap()
        XCTAssertEqual(name.value as? String, original)
        app.buttons["closeProfileButton"].tap()
        let plans = app.buttons["travelPlansLink"]
        for _ in 0..<6 where !plans.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        plans.tap(); app.buttons["addTravelPlan"].tap()
        XCTAssertTrue(app.buttons["personalPlanCancel"].waitForExistence(timeout: 5))
        app.buttons["personalPlanCancel"].tap()
        XCTAssertFalse(app.buttons["Discard changes"].exists)
        app.buttons["addTravelPlan"].tap()
        let audience = app.buttons["travelPlanAudience"]
        let initialAudience = audience.label
        audience.tap(); app.buttons["clearTravelAudience"].tap()
        app.buttons["travelAudienceDone"].tap()
        let changedAudience = audience.label
        XCTAssertNotEqual(changedAudience, initialAudience)
        app.buttons["personalPlanCancel"].tap()
        XCTAssertTrue(app.buttons["Keep editing"].firstMatch.waitForExistence(timeout: 3))
        app.buttons["Keep editing"].firstMatch.tap()
        XCTAssertEqual(audience.label, changedAudience)
        app.buttons["personalPlanCancel"].tap()
        capture("AUDIT-discard-plan-confirmation")
        app.buttons["Discard changes"].firstMatch.tap()
        XCTAssertTrue(app.buttons["addTravelPlan"].waitForExistence(timeout: 5))
        app.buttons["addTravelPlan"].tap()
        XCTAssertEqual(audience.label, initialAudience)
    }

    func testAuditAuthenticationAtLargestText() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testSignedOut", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let signIn = app.buttons["appleSignInButton"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 8))
        capture("AUDIT-auth-largest-text")
        XCTAssertTrue(signIn.isHittable)
        XCTAssertLessThanOrEqual(signIn.frame.maxY, app.frame.maxY)
        XCTAssertGreaterThanOrEqual(signIn.frame.minY, 0)
    }

    func testEmailCodeSignInFlow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testSignedOut", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let emailOption = app.buttons["emailSignInButton"]
        XCTAssertTrue(emailOption.waitForExistence(timeout: 8))
        emailOption.tap()

        let address = app.textFields["emailSignInAddressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["emailSignInSendButton"].isEnabled)
        address.typeText("Mia@Example.com")
        capture("AUTH-email-address-zh")
        app.buttons["emailSignInSendButton"].tap()

        let code = app.textFields["emailSignInCodeField"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["验证码已发送至 mia@example.com。"].exists)
        capture("AUTH-email-code-zh")
        code.typeText("123456")

        XCTAssertTrue(app.buttons["appleSignInButton"].waitForNonExistence(timeout: 8))
    }

    func testAuditSharingControlsComeFirstAtLargestText() {
        continueAfterFailure = false
        let app = waveTwoApp(language: "zh-Hans", locale: "zh_CN", extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openCitySharingFromProfile(in: app)
        let toggle = app.switches["citySharingToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(toggle.isHittable)
        XCTAssertLessThan(toggle.frame.minY, app.frame.height * 0.5)
        capture("AUDIT-sharing-controls-first-large-zh")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "0")
    }

    func testAuditNotificationSaveFailureIsVisibleFromProfileAndRetryWorks() {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-seedTripExamples", "-testNotificationsDenied", "-testTripNotificationFailure"])
        selectAppTab(2, in: app)
        let entry = app.buttons["notificationSettingsLink"]
        for _ in 0..<6 where !entry.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        entry.tap()
        let trips = app.buttons["notificationSharedTripSettings"]
        for _ in 0..<5 where !trips.isHittable { app.scrollViews["notificationSettingsScreen"].swipeUp() }
        trips.tap()
        let trip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "notificationTrip-")).firstMatch
        XCTAssertTrue(trip.waitForExistence(timeout: 8)); trip.tap()
        let toggle = app.switches["tripFlightAlertsToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let original = toggle.value as? String
        for _ in 0..<4 where !toggle.isHittable { app.swipeUp() }
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.alerts["Could not update notifications"].waitForExistence(timeout: 5))
        capture("AUDIT-notification-save-failure")
        app.alerts.buttons["OK"].tap()
        XCTAssertEqual(toggle.value as? String, original)
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, original == "1" ? "0" : "1")
        app.buttons["tripNotificationsDone"].tap(); trip.tap()
        XCTAssertEqual(toggle.value as? String, original == "1" ? "0" : "1")
        app.buttons["tripNotificationsDone"].tap()
        selectAppTab(1, in: app)
        XCTAssertTrue(app.scrollViews["tripsScreen"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.alerts.count, 0)
    }

    func testAuditTripAndFlightProtectUnsavedChangesAndDateCancel() {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-previewTrips", "-seedTripExamples"])
        app.buttons["newTripButton"].tap()
        app.buttons["tripDestinationPicker"].tap(); app.buttons["Tokyo (NRT)"].tap()
        app.buttons["tripEditorCancel"].tap()
        XCTAssertTrue(app.buttons["Keep editing"].firstMatch.waitForExistence(timeout: 3)); app.buttons["Keep editing"].firstMatch.tap()
        XCTAssertTrue(app.buttons["tripDestinationPicker"].label.contains("Tokyo"))
        app.buttons["tripEditorCancel"].tap(); app.buttons["Discard changes"].firstMatch.tap()
        app.buttons["tripCard-example-new-york"].tap()
        app.buttons["tripNeedsHelpCard"].tap()
        let number = app.textFields["tripFlightNumberField"]
        XCTAssertTrue(number.waitForExistence(timeout: 5)); number.tap(); number.typeText("ZZ9999")
        app.buttons["flightKeyboardDone"].tap()
        let date = app.buttons["tripFlightDatePicker"]
        for _ in 0..<5 where !date.isHittable { app.scrollViews.firstMatch.swipeDown() }
        let before = date.label
        date.tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5))
        let day = app.datePickers.buttons.matching(NSPredicate(format: "label MATCHES %@", ".*\\b15\\b.*")).firstMatch
        XCTAssertTrue(day.waitForExistence(timeout: 3)); day.tap()
        app.buttons["flightDateCancel"].tap()
        XCTAssertEqual(date.label, before)
        app.buttons["flightEditorCancel"].tap()
        XCTAssertTrue(app.buttons["Keep editing"].firstMatch.waitForExistence(timeout: 3)); app.buttons["Keep editing"].firstMatch.tap()
        XCTAssertEqual(number.value as? String, "ZZ9999")
        app.buttons["flightEditorCancel"].tap()
        capture("AUDIT-discard-flight-confirmation")
        app.buttons["Discard changes"].firstMatch.tap()
        XCTAssertTrue(app.buttons["tripNeedsHelpCard"].waitForExistence(timeout: 5))
    }

    func testW3NotificationSettingsAtLargestText() throws {
        continueAfterFailure = false
        let app = waveTwoApp(language: "zh-Hans", locale: "zh_CN", extra: ["-testNotificationsDenied", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        selectAppTab(2, in: app)
        let entry = app.buttons["notificationSettingsLink"]
        for _ in 0..<12 where !entry.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        entry.tap()
        let sameCity = app.buttons["notificationSameCitySettings"]
        for _ in 0..<10 where !sameCity.isHittable { app.scrollViews["notificationSettingsScreen"].swipeUp() }
        assertTouchTarget(sameCity)
        capture("W3-F16-large-overview-zh")
        sameCity.tap()
        let recovery = app.buttons["notificationPermissionRecovery"]
        for _ in 0..<8 where !recovery.isHittable { app.swipeUp() }
        assertTouchTarget(recovery)
        capture("W3-F16-large-permission-zh")
        let toggle = app.switches["notificationFriend-mia"]
        for _ in 0..<8 where !toggle.isHittable { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        assertTouchTarget(toggle)
        capture("W3-F16-large-friends-zh")
        try auditRelevantControls(app, prefixes: ["notificationFriend-"], name: "W3-F16-large-friends")
    }

    func testW3IncomingRequestsAppearFirstAndDisappearAfterResponse() {
        continueAfterFailure = false
        let app = waveTwoApp()
        app.buttons["addFriendButton"].tap()
        let accept = app.buttons["acceptRequestButton"].firstMatch
        XCTAssertTrue(accept.waitForExistence(timeout: 5))
        XCTAssertTrue(accept.isHittable)
        XCTAssertLessThan(accept.frame.minY, app.descendants(matching: .any)["currentUsernameCard"].firstMatch.frame.minY)
        capture("W3-F10-request-first")
        accept.tap()
        let remaining = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 1"), object: app.buttons.matching(identifier: "acceptRequestButton"))
        XCTAssertEqual(XCTWaiter.wait(for: [remaining], timeout: 5), .completed)
        app.buttons["declineRequestButton"].firstMatch.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["currentUsernameCard"].firstMatch.isHittable)
        capture("W3-F10-invite-after-response")
    }

    func testW3LiveTokyoSearchCanBeSelected() {
        continueAfterFailure = false
        let app = waveTwoApp()
        selectAppTab(2, in: app)
        let plans = app.buttons["travelPlansLink"]
        for _ in 0..<6 where !plans.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        plans.tap()
        app.buttons["addTravelPlan"].tap()
        app.buttons["travelPlanCity"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Tokyo, Japan")
        let city = app.buttons["travelCity-Tokyo"]
        XCTAssertTrue(city.waitForExistence(timeout: 30))
        capture("W3-city-live-Tokyo-result")
        city.tap()
        XCTAssertTrue(app.buttons["travelPlanCity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["travelPlanCity"].label.contains("Tokyo"))
    }

    func testW3WidgetFriendLinksOpenWarmColdAndUnavailableDestinations() {
        continueAfterFailure = false
        let app = waveTwoApp()
        XCUIDevice.shared.press(.home)
        app.open(URL(string: "whereismyfriend://friend/10000000-0000-0000-0000-000000000002")!)
        XCTAssertTrue(app.navigationBars["Lin"].waitForExistence(timeout: 10))
        capture("W3-F24-warm-Lin")
        app.terminate()
        app.open(URL(string: "whereismyfriend://friend/10000000-0000-0000-0000-000000000001")!)
        XCTAssertTrue(app.navigationBars["Mia"].waitForExistence(timeout: 10))
        capture("W3-F24-cold-Mia")
        app.open(URL(string: "whereismyfriend://friend/10000000-0000-0000-0000-000000000099")!)
        XCTAssertTrue(app.alerts["Friend unavailable"].waitForExistence(timeout: 10))
        capture("W3-F24-unavailable")
    }

    func testW3NotificationOverviewRoutesAndSavedPreferences() {
        continueAfterFailure = false
        for (language, locale) in [("en", "en_US"), ("zh-Hans", "zh_CN")] {
            let app = waveTwoApp(language: language, locale: locale, extra: ["-testNotificationsDenied", "-seedTripExamples"])
            selectAppTab(2, in: app)
            let entry = app.buttons["notificationSettingsLink"]
            for _ in 0..<6 where !entry.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
            entry.tap()
            let sameCity = app.buttons["notificationSameCitySettings"]
            XCTAssertTrue(sameCity.waitForExistence(timeout: 5))
            capture("W3-F16-overview-\(language)")
            app.buttons["notificationFriendInvitations"].tap()
            XCTAssertTrue(app.buttons["acceptRequestButton"].firstMatch.waitForExistence(timeout: 5))
            app.buttons["doneAddFriendButton"].tap()
            sameCity.tap()
            XCTAssertTrue(app.buttons["notificationPermissionRecovery"].waitForExistence(timeout: 5))
            let toggle = app.switches["notificationFriend-mia"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5))
            let before = toggle.value as? String
            toggle.switches.firstMatch.tap()
            let changed = before == "1" ? "0" : "1"
            XCTAssertEqual(toggle.value as? String, changed)
            capture("W3-F16-same-city-\(language)")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            sameCity.tap()
            XCTAssertEqual(toggle.value as? String, changed)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            let trips = app.buttons["notificationSharedTripSettings"]
            for _ in 0..<5 where !trips.isHittable { app.scrollViews["notificationSettingsScreen"].swipeUp() }
            trips.tap()
            let trip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "notificationTrip-")).firstMatch
            XCTAssertTrue(trip.waitForExistence(timeout: 8)); trip.tap()
            let alerts = app.switches["tripFlightAlertsToggle"]
            XCTAssertTrue(alerts.waitForExistence(timeout: 5))
            if language == "zh-Hans" {
                XCTAssertTrue(app.navigationBars["旅行通知"].exists)
                XCTAssertTrue(alerts.label.contains("好友航班通知"))
            }
            let oldAlerts = alerts.value as? String
            for _ in 0..<4 where !alerts.isHittable { app.swipeUp() }
            alerts.switches.firstMatch.tap()
            XCTAssertEqual(alerts.value as? String, oldAlerts == "1" ? "0" : "1")
            capture("W3-F16-trip-settings-\(language)")
            app.buttons["tripNotificationsDone"].tap()
            trip.tap()
            XCTAssertEqual(alerts.value as? String, oldAlerts == "1" ? "0" : "1")
            app.buttons["tripNotificationsDone"].tap()
            app.navigationBars.buttons.element(boundBy: 0).tap()
            let planSettings = app.buttons["notificationPlanSettings"]
            for _ in 0..<5 where !planSettings.isHittable { app.scrollViews["notificationSettingsScreen"].swipeDown() }
            planSettings.tap()
            XCTAssertTrue(app.buttons["addTravelPlan"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            let invitations = app.buttons["notificationTripInvitations"]
            for _ in 0..<5 where !invitations.isHittable { app.scrollViews["notificationSettingsScreen"].swipeDown() }
            invitations.tap()
            XCTAssertTrue(app.scrollViews["tripsScreen"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    func testChineseOnboardingActionLabels() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-previewOnboarding", "-previewOnboardingStep=3", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["onboardingContinueButton"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["onboardingContinueButton"].label.contains("开始使用"))
        XCTAssertTrue(app.buttons["onboardingSkipButton"].label.contains("跳过"))
        XCTAssertTrue(app.staticTexts["由你决定"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "城市级共享：巴黎，法国")).firstMatch.exists)
        capture("W2-F22-onboarding-zh")
    }

    func testDateRangeTouchTargetsAtLargestText() throws {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-previewTrips", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.buttons["newTripButton"].tap()
        let dates = app.buttons["tripDatesPicker"]
        for _ in 0..<7 where !dates.isHittable { app.scrollViews.firstMatch.swipeUp() }
        dates.tap()
        let next = app.buttons["rangeNextMonth"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<5 where !next.isHittable { app.scrollViews.firstMatch.swipeUp() }
        assertTouchTarget(next)
        let days = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "rangeDay-"))
        for _ in 0..<6 where days.count == 0 { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertGreaterThan(days.count, 0)
        for day in days.allElementsBoundByIndex where day.isHittable { assertTouchTarget(day) }
        capture("W2-F20-date-range-large-text")
        try auditRelevantControls(app, prefixes: ["rangeDay-", "rangeNextMonth", "rangePreviousMonth"], name: "F20-date-range")
    }

    func testNewPlansSelectAllFriendsAndPreserveOptOutInBothLanguages() {
        continueAfterFailure = false
        for (language, locale, allLabel) in [("en", "en_US", "All friends"), ("zh-Hans", "zh_CN", "全部好友")] {
            let app = waveTwoApp(language: language, locale: locale)
            app.buttons["friendPlansLink"].tap()
            let card = app.buttons["friendPlan-A7150000-0000-0000-0000-000000000001"]
            XCTAssertTrue(card.waitForExistence(timeout: 5))
            XCTAssertLessThan(card.frame.minY, app.frame.height / 2)
            XCTAssertFalse(app.staticTexts["Where are friends going?"].exists)
            capture("W2-F19-compact-feed-\(language)")
            app.buttons["copyFriendPlan-A7150000-0000-0000-0000-000000000001"].tap()
            let audience = app.buttons["travelPlanAudience"]
            XCTAssertTrue(audience.waitForExistence(timeout: 4))
            for _ in 0..<5 where !audience.isHittable { app.scrollViews.firstMatch.swipeUp() }
            XCTAssertTrue(audience.label.contains(allLabel))
            capture("W2-default-all-friends-\(language)")
            audience.tap()
            let lin = app.switches["travelAudience-lin"], mia = app.switches["travelAudience-mia"]
            XCTAssertEqual(lin.value as? String, "1")
            XCTAssertEqual(mia.value as? String, "1")
            lin.switches.firstMatch.tap()
            XCTAssertEqual(lin.value as? String, "0")
            app.buttons["travelAudienceDone"].tap()
            let save = app.buttons["saveTravelPlan"]
            for _ in 0..<6 where !save.isHittable { app.scrollViews.firstMatch.swipeUp() }
            XCTAssertEqual(app.switches["travelPlanAlerts"].value as? String, "0")
            save.tap()
            XCTAssertTrue(app.buttons["manageOwnTravelPlans"].waitForExistence(timeout: 5))
            app.buttons["manageOwnTravelPlans"].tap()
            let plan = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "travelPlan-")).firstMatch
            XCTAssertTrue(plan.waitForExistence(timeout: 5)); plan.tap()
            for _ in 0..<5 where !audience.isHittable { app.scrollViews.firstMatch.swipeUp() }
            audience.tap()
            XCTAssertEqual(lin.value as? String, "0", "Editing must preserve the saved opt-out")
            XCTAssertEqual(mia.value as? String, "1")
            capture("W2-saved-audience-\(language)")
            app.terminate()
        }
    }

    func testFriendPlanCopyButtonIsAccessible() throws {
        continueAfterFailure = false
        let app = waveTwoApp()
        app.buttons["friendPlansLink"].tap()
        let copy = app.buttons["copyFriendPlan-A7150000-0000-0000-0000-000000000001"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        for _ in 0..<4 where !copy.isHittable { app.scrollViews["friendPlansScreen"].swipeUp() }
        assertTouchTarget(copy)
        XCTAssertTrue(copy.label.contains("Add to my travel plans"))
        try auditRelevantControls(app, prefixes: ["copyFriendPlan-"], name: "F09-F20-plan-actions")
        XCTAssertFalse(app.buttons["shareFriendPlanInvite-A7150000-0000-0000-0000-000000000001"].exists)
    }

    func testOutgoingInvitationCanBeKeptWithdrawnAndSentAgain() {
        continueAfterFailure = false
        let app = waveTwoApp()
        app.buttons["addFriendButton"].tap()
        let field = app.textFields["friendUsernameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap(); field.typeText("leo\n")
        let withdrawal = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "withdrawFriendRequest-")).firstMatch
        // Asking a missing element for hittability is an error on iOS 26, so wait for it first.
        XCTAssertTrue(withdrawal.waitForExistence(timeout: 5))
        for _ in 0..<7 where !withdrawal.isHittable { app.scrollViews["addFriendScreen"].swipeUp() }
        // A tap while the list is still decelerating only stops the scroll.
        Thread.sleep(forTimeInterval: 1)
        let oldID = withdrawal.identifier
        withdrawal.tap()
        XCTAssertTrue(app.alerts["Withdraw invitation?"].waitForExistence(timeout: 3))
        capture("W2-F11-withdraw-confirmation")
        app.alerts.buttons["Keep invitation"].tap()
        // iOS 26 ignores taps while an alert or sheet is still animating in or out.
        XCTAssertTrue(app.alerts.firstMatch.waitForNonExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(app.buttons[oldID].exists)
        app.buttons[oldID].tap()
        let confirm = app.alerts.buttons["Withdraw invitation"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        Thread.sleep(forTimeInterval: 1)
        confirm.tap()
        XCTAssertTrue(app.buttons[oldID].waitForNonExistence(timeout: 5))
        for _ in 0..<7 where !field.isHittable { app.scrollViews["addFriendScreen"].swipeDown() }
        Thread.sleep(forTimeInterval: 1)
        field.tap(); field.typeText("leo\n")
        XCTAssertTrue(withdrawal.waitForExistence(timeout: 5))
        for _ in 0..<7 where !withdrawal.isHittable { app.scrollViews["addFriendScreen"].swipeUp() }
        XCTAssertNotEqual(withdrawal.identifier, oldID)
        capture("W2-F11-invite-again")
    }

    func testTripSaveStaysAboveKeyboardAndDoneIsAvailable() {
        continueAfterFailure = false
        let app = tripsApp(seedExamples: false)
        XCTAssertTrue(app.buttons["newTripButton"].waitForExistence(timeout: 8)); app.buttons["newTripButton"].tap()
        app.buttons["tripDestinationPicker"].tap(); app.buttons["Tokyo (NRT)"].tap()
        let field = app.textFields["tripNameField"]
        for _ in 0..<4 where !field.isHittable { app.scrollViews.firstMatch.swipeUp() }
        field.replaceText(with: "Keyboard ready")
        let save = app.buttons["saveTripButton"]
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tripKeyboardDone"].exists)
        XCTAssertTrue(save.isHittable)
        XCTAssertLessThanOrEqual(save.frame.maxY, app.keyboards.firstMatch.frame.minY)
        capture("W2-F28-keyboard-save")
        save.tap()
        XCTAssertTrue(app.scrollViews["tripsScreen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Keyboard ready"].exists)
        app.staticTexts["Keyboard ready"].tap()
        app.buttons["tripOptionsButton"].tap(); app.buttons["Edit trip"].tap()
        for _ in 0..<4 where !field.isHittable { app.scrollViews.firstMatch.swipeUp() }
        field.replaceText(with: "Keyboard edited")
        app.buttons["tripKeyboardDone"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        save.tap()
        XCTAssertTrue(app.staticTexts["Keyboard edited"].waitForExistence(timeout: 5))
    }

    func testFlightControlsAtLargestTextHaveReachableTargets() throws {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-previewTrips", "-seedTripExamples", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let card = app.buttons["tripCard-example-west"]
        for _ in 0..<8 where !card.isHittable { app.scrollViews["tripsScreen"].swipeUp() }
        card.tap(); app.buttons["addBoardFlightButton"].tap()
        let number = app.textFields["tripFlightNumberField"]
        let footer = app.buttons["confirmAddTripFlightButton"]
        capture("W2-F20-flight-context")
        func reveal(_ control: XCUIElement) {
            for _ in 0..<8 {
                let top = app.navigationBars.firstMatch.frame.maxY + 10
                let bottom = footer.frame.minY - 10
                if control.isHittable, control.frame.minY >= top, control.frame.maxY <= bottom { break }
                let upper = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (top + 20) / app.frame.height))
                let lower = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (bottom - 20) / app.frame.height))
                if control.frame.minY < top { upper.press(forDuration: 0.05, thenDragTo: lower) }
                else { lower.press(forDuration: 0.05, thenDragTo: upper) }
            }
        }
        reveal(number)
        capture("W2-F20-number-target")
        number.tap(); XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3)); number.typeText("ZZ9999")
        app.buttons["flightKeyboardDone"].tap()
        for id in ["clearTripFlightNumber", "lookupFlightButton"] {
            let control = app.buttons[id]
            reveal(control)
            assertTouchTarget(control)
        }
        XCTAssertGreaterThanOrEqual(number.frame.width, 290)
        XCTAssertEqual(number.value as? String, "ZZ9999")
        capture("W2-F20-flight-large-text")
        try auditRelevantControls(app, prefixes: ["clearTripFlightNumber", "lookupFlightButton", "confirmAddTripFlightButton"], name: "F20-flight-controls")
        app.buttons["clearTripFlightNumber"].tap()
        XCTAssertFalse(app.buttons["lookupFlightButton"].isEnabled)
        let date = app.buttons["tripFlightDatePicker"]
        reveal(date)
        assertTouchTarget(date); date.tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 4))
        capture("W2-F20-native-calendar")
    }

    func testChineseFlightStatesAndGeneratedTripNameAreLocalized() {
        continueAfterFailure = false
        let app = waveTwoApp(language: "zh-Hans", locale: "zh_CN", extra: ["-previewTrips", "-seedTripExamples", "-testFlightToday"])
        app.buttons["newTripButton"].tap()
        app.buttons["tripDestinationPicker"].tap(); app.buttons["Tokyo (NRT)"].tap()
        XCTAssertTrue((app.textFields["tripNameField"].value as? String)?.contains("之旅") == true)
        XCTAssertTrue(app.buttons["saveTripButton"].label.contains("创建旅行"))
        XCTAssertTrue(app.staticTexts["目的地"].exists)
        capture("W2-F22-generated-name-zh")
        app.navigationBars.buttons["取消"].tap()
        // Picking a destination makes the form dirty, so Cancel now asks first (F02).
        let discard = app.alerts.buttons["放弃修改"]
        if discard.waitForExistence(timeout: 3) { discard.tap() }
        let card = app.buttons["tripCard-example-west"]
        for _ in 0..<5 where !card.isHittable { app.scrollViews["tripsScreen"].swipeUp() }
        card.tap(); app.buttons["addBoardFlightButton"].tap()
        XCTAssertTrue(app.navigationBars["添加航班"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tripFlightDatePicker"].label.contains("今天"))
        XCTAssertTrue(app.buttons["lookupFlightButton"].label.contains("查询"))
        app.textFields["tripFlightNumberField"].tap(); app.textFields["tripFlightNumberField"].typeText("ZZ9999\n")
        let error = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "未找到ZZ9999")).firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 8))
        capture("W2-F22-flight-no-result-zh")
    }

    func testSystemAppearanceSelectionPersistsAcrossLaunch() {
        continueAfterFailure = false
        let app = waveTwoApp()
        selectAppearance("systemAppearance", in: app)
        app.terminate(); app.launch()
        selectAppTab(2, in: app)
        let appearance = app.buttons["appearanceSettingsButton"]
        for _ in 0..<5 where !appearance.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        XCTAssertTrue(appearance.label.contains("Follow system")); appearance.tap()
        XCTAssertEqual(app.buttons["systemAppearance"].value as? String, "1")
        capture("W2-F21-system-appearance")
        app.buttons["appearanceDoneButton"].tap(); selectAppTab(0, in: app)
        capture("W2-F21-system-home")
    }

    func testSameCityHistoryWrapsLongNamesAtLargestText() throws {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-testHistoryRevisit", "-testLongHistory", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        selectAppTab(2, in: app)
        let history = app.buttons["sameCityMomentsLink"]
        for _ in 0..<6 where !history.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        history.tap()
        let friend = app.staticTexts["activeStayFriend-10000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(friend.waitForExistence(timeout: 5))
        for _ in 0..<5 where !friend.isHittable { app.scrollViews["notificationHistoryScreen"].swipeUp() }
        XCTAssertTrue(friend.label.contains("Alexandra Catherine Montgomery-Williams"))
        XCTAssertGreaterThan(friend.frame.height, 60)
        XCTAssertLessThanOrEqual(friend.frame.maxX, app.frame.maxX)
        capture("W2-F26-long-history")
        try auditRelevantControls(app, prefixes: ["activeStayFriend-", "activeStayCity-", "sameCityDuration-"], name: "F26-history-text")
    }

    func testSameCityHistoryUpdatesWhileScreenRemainsOpen() {
        continueAfterFailure = false
        let app = historyApp(extra: "-testHistoryRevisit", language: "en", locale: "en_US", additional: ["-testHistoryClock"])
        let duration = app.staticTexts["sameCityDuration-10000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        XCTAssertTrue(duration.label.contains("1 minute"), duration.label)
        let update = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "2 minutes"), object: duration)
        XCTAssertEqual(XCTWaiter.wait(for: [update], timeout: 75), .completed)
        capture("W2-F26-live-time-update")
    }

    func testEmptyHomeHighlightsFirstInvitationAndUsernameAlternative() {
        continueAfterFailure = false
        let app = waveTwoApp(extra: ["-testEmptyFriends"])
        // Replace the initial cached demo snapshot with the empty repository fixture.
        app.scrollViews["friendsScreen"].swipeDown()
        let invite = app.buttons["inviteFirstFriend"]
        XCTAssertTrue(invite.waitForExistence(timeout: 5)); assertTouchTarget(invite)
        XCTAssertTrue(invite.isHittable)
        XCTAssertFalse(app.buttons["friendPlansLink"].exists)
        capture("W2-F30-first-friend")
        invite.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Copy").firstMatch.waitForExistence(timeout: 5))
        dismissSystemShare(in: app)
        app.buttons["addFirstFriendByUsername"].tap()
        XCTAssertTrue(app.textFields["friendUsernameField"].waitForExistence(timeout: 5))
    }

    private func discardChangesIfOffered(in app: XCUIApplication) {
        if app.buttons["Discard changes"].exists { app.buttons["Discard changes"].firstMatch.tap() }
        else if app.buttons["放弃修改"].exists { app.buttons["放弃修改"].firstMatch.tap() }
    }

    private func waveTwoApp(language: String = "en", locale: String = "en_US", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-tripTestNamespace=\(UUID().uuidString)", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + extra
        app.launch()
        let screen = extra.contains("-previewTrips") ? "tripsScreen" : "friendsScreen"
        XCTAssertTrue(app.scrollViews[screen].waitForExistence(timeout: 12))
        return app
    }

    /// Expands Together soon and opens an overlap. With one overlap the card opens it directly.
    private func openOverlapDetail(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let toggle = app.buttons["upcomingTogetherToggle"]
        if !toggle.isHittable { app.scrollViews["friendsScreen"].swipeUp() }
        toggle.tap()
        let detail = app.descendants(matching: .any)["upcomingOverlapDetail"]
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "upcomingOverlap-")).firstMatch
        if !detail.waitForExistence(timeout: 3), row.waitForExistence(timeout: 3) { row.tap() }
        XCTAssertTrue(detail.waitForExistence(timeout: 5), file: file, line: line)
    }

    private func assertTouchTarget(_ control: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(control.frame.width, 43.5, file: file, line: line)
        XCTAssertGreaterThanOrEqual(control.frame.height, 43.5, file: file, line: line)
        XCTAssertLessThanOrEqual(control.frame.maxX, XCUIApplication().frame.maxX, file: file, line: line)
    }

    private func auditRelevantControls(_ app: XCUIApplication, prefixes: [String], name: String) throws {
        var all: [String] = [], relevant: [String] = []
        try app.performAccessibilityAudit(for: [.hitRegion, .textClipped]) { issue in
            let description = "\(issue.compactDescription)\n\(issue.detailedDescription)\n\(issue.element?.debugDescription ?? "No element")"
            all.append(description)
            if let id = issue.element?.identifier, prefixes.contains(where: { id.hasPrefix($0) }) { relevant.append(description) }
            return true
        }
        let report = XCTAttachment(string: all.isEmpty ? "No native hit-region or text-clipping issues on this screen." : all.joined(separator: "\n\n"))
        report.name = "W2-audit-\(name)"; report.lifetime = .keepAlways; add(report)
        XCTAssertTrue(relevant.isEmpty, relevant.joined(separator: "\n"))
    }

    private func dismissSystemShare(in app: XCUIApplication) {
        let copy = app.descendants(matching: .any).matching(identifier: "Copy").firstMatch
        if app.buttons["Close"].firstMatch.exists { app.buttons["Close"].firstMatch.tap() }
        else if app.buttons["Cancel"].firstMatch.exists { app.buttons["Cancel"].firstMatch.tap() }
        else {
            let sheet = app.otherElements["ActivityListView"]
            if sheet.exists, sheet.frame.minY > 50 {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: (sheet.frame.minY - 30) / app.frame.height)).tap()
            } else if sheet.exists, !sheet.frame.isEmpty {
                sheet.swipeDown()
            } else {
                // A share sheet with a titled preview doesn't expose its list frame; tap above it.
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).tap()
            }
        }
        XCTAssertTrue(copy.waitForNonExistence(timeout: 5))
    }

    private func clearTravelAudience(in app: XCUIApplication) {
        let audience = app.buttons["travelPlanAudience"]
        for _ in 0..<5 where !audience.isHittable { app.scrollViews.firstMatch.swipeUp() }
        audience.tap(); app.buttons["clearTravelAudience"].tap(); app.buttons["travelAudienceDone"].tap()
        for _ in 0..<5 where !app.buttons["travelPlanCity"].isHittable { app.scrollViews.firstMatch.swipeDown() }
    }

    func testTravelPurposeLinksAtAccessibilitySize() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewTrips",
                               "-tripTestNamespace=\(UUID().uuidString)", "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let plans = app.buttons["myTravelPlansFromTrips"]
        XCTAssertTrue(plans.waitForExistence(timeout: 8))
        XCTAssertLessThanOrEqual(plans.frame.maxX, app.frame.maxX)
        capture("F08-accessibility-shared-trips")
        for _ in 0..<4 where !plans.isHittable { app.scrollViews["tripsScreen"].swipeUp() }
        plans.tap()
        let trips = app.buttons["openSharedTrips"]
        for _ in 0..<8 where !trips.isHittable { app.scrollViews["travelPlansScreen"].swipeUp() }
        XCTAssertTrue(trips.isHittable)
        XCTAssertLessThanOrEqual(trips.frame.maxX, app.frame.maxX)
        capture("F08-accessibility-personal-plans")
        trips.tap()
        XCTAssertTrue(app.buttons["newTripButton"].waitForExistence(timeout: 5))
    }

    func testTravelPurposesAndNavigationInBothLanguages() {
        continueAfterFailure = false
        for (language, locale, sharedTitle, ownTitle, friendTitle) in [
            ("en", "en_US", "Shared trips", "My travel plans", "Friends’ travel plans"),
            ("zh-Hans", "zh_CN", "共同旅行", "我的出行计划", "好友出行计划")
        ] {
            let app = XCUIApplication()
            app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewTrips", "-seedTripExamples",
                                   "-tripTestNamespace=\(UUID().uuidString)", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
            XCTAssertTrue(app.buttons["myTravelPlansFromTrips"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.staticTexts[sharedTitle].exists)
            capture("F08-shared-trips-\(language)")
            app.buttons["myTravelPlansFromTrips"].tap()
            XCTAssertTrue(app.navigationBars[ownTitle].waitForExistence(timeout: 5))
            capture("F08-my-travel-plans-\(language)")
            let backToTrips = app.buttons["openSharedTrips"]
            for _ in 0..<5 where !backToTrips.isHittable { app.scrollViews["travelPlansScreen"].swipeUp() }
            backToTrips.tap()
            XCTAssertTrue(app.buttons["newTripButton"].waitForExistence(timeout: 5))
            selectAppTab(2, in: app)
            let profileLink = app.buttons["travelPlansLink"]
            for _ in 0..<4 where !profileLink.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
            XCTAssertTrue(profileLink.label.contains(ownTitle))
            profileLink.tap()
            XCTAssertTrue(app.navigationBars[ownTitle].waitForExistence(timeout: 5))
            selectAppTab(0, in: app)
            let friendLink = app.buttons["friendPlansLink"]
            XCTAssertTrue(friendLink.waitForExistence(timeout: 5))
            XCTAssertTrue(friendLink.label.contains(friendTitle))
            friendLink.tap()
            let copy = app.buttons["copyFriendPlan-A7150000-0000-0000-0000-000000000001"]
            for _ in 0..<5 where !copy.isHittable { app.scrollViews["friendPlansScreen"].swipeUp() }
            XCTAssertTrue(copy.label.contains(language == "en" ? "Add to my travel plans" : "添加到我的出行计划"))
            capture("F08-friend-travel-plans-\(language)")
            copy.tap()
            XCTAssertTrue(app.descendants(matching: .any)["travelPlanCopySource"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["travelPlanAudience"].label.contains(language == "en" ? "All friends" : "全部好友"))
            capture("F08-copy-friend-draft-\(language)")
            let boundary = app.staticTexts["travelPlanBoundary"]
            for _ in 0..<5 where !boundary.isHittable { app.scrollViews.firstMatch.swipeUp() }
            XCTAssertTrue(boundary.label.contains(language == "en" ? "doesn’t join" : "不会加入"))
            XCTAssertEqual(app.switches["travelPlanAlerts"].value as? String, "0")
            capture("F08-copy-boundary-\(language)")
            app.navigationBars.buttons[language == "en" ? "Cancel" : "取消"].tap()
            discardChangesIfOffered(in: app)
            XCTAssertTrue(app.scrollViews["friendPlansScreen"].waitForExistence(timeout: 5))
            app.buttons["manageOwnTravelPlans"].tap()
            XCTAssertTrue(app.navigationBars[ownTitle].waitForExistence(timeout: 5))
            XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "travelPlan-")).count, 0)
            app.terminate()
        }
    }

    func testSharedTripDatesCreateIndependentPrivatePlan() {
        continueAfterFailure = false
        let app = tripsApp(seedExamples: false)
        XCTAssertTrue(app.buttons["newTripButton"].waitForExistence(timeout: 8))
        createTrip(in: app, name: "Tokyo together F08", destination: "Tokyo (NRT)")
        app.staticTexts["Tokyo together F08"].tap()
        XCTAssertTrue(app.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 5))
        let useDates = app.buttons["tripDatesToPersonalPlan"]
        for _ in 0..<7 where !useDates.isHittable { app.scrollViews["fullTripArrivalBoard"].swipeUp() }
        XCTAssertTrue(useDates.isHittable)
        capture("F08-trip-copy-entry")
        useDates.tap()
        XCTAssertTrue(app.navigationBars["Choose a city"].waitForExistence(timeout: 5))
        // Use the existing Demo / recent city choices to keep this copy-flow regression
        // independent of live MapKit locality results for metropolitan-area searches.
        app.searchFields.firstMatch.buttons["Clear text"].tap()
        let city = app.buttons["travelCity-Tokyo"].firstMatch
        XCTAssertTrue(city.waitForExistence(timeout: 5))
        capture("F08-trip-confirm-city")
        city.tap()
        XCTAssertTrue(app.navigationBars["New travel plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["travelPlanCopySource"].label.contains("Tokyo together F08"))
        XCTAssertTrue(app.buttons["travelPlanCity"].label.contains("Tokyo"))
        clearTravelAudience(in: app)
        XCTAssertTrue(app.buttons["travelPlanAudience"].label.contains("Only me"))
        let copiedDates = app.buttons["travelPlanDates"].label
        capture("F08-trip-private-draft")
        let save = app.buttons["saveTravelPlan"]
        for _ in 0..<5 where !save.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(app.staticTexts["travelPlanBoundary"].label.contains("saved separately"))
        XCTAssertEqual(app.switches["travelPlanAlerts"].value as? String, "0")
        capture("F08-trip-independent-dates")
        save.tap()
        XCTAssertTrue(app.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tripPeopleButton"].label.contains("1 person"))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let ownEntry = app.buttons["myTravelPlansFromTrips"]
        for _ in 0..<5 where !ownEntry.isHittable { app.scrollViews["tripsScreen"].swipeDown() }
        ownEntry.tap()
        let ownPlans = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "travelPlan-"))
        XCTAssertTrue(ownPlans.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(ownPlans.count, 1)
        XCTAssertTrue(ownPlans.firstMatch.label.contains("Only you"))
        ownPlans.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Edit travel plan"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["travelPlanDates"].label, copiedDates)
        app.navigationBars.buttons["Cancel"].tap()
        discardChangesIfOffered(in: app)
        let importDates = app.buttons["importSharedTripDates"]
        for _ in 0..<5 where !importDates.isHittable { app.scrollViews["travelPlansScreen"].swipeUp() }
        importDates.tap()
        let savedTrip = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "importTrip-")).firstMatch
        XCTAssertTrue(savedTrip.waitForExistence(timeout: 5))
        XCTAssertTrue(savedTrip.label.contains("Tokyo together F08"))
        capture("F08-import-saved-trip")
        savedTrip.tap()
        XCTAssertTrue(app.navigationBars["Choose a city"].waitForExistence(timeout: 5))
        app.searchFields.firstMatch.buttons["Clear text"].tap()
        XCTAssertTrue(city.waitForExistence(timeout: 5)); city.tap()
        XCTAssertTrue(app.navigationBars["New travel plan"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["travelPlanDates"].label, copiedDates)
        app.navigationBars.buttons["Cancel"].tap()
        discardChangesIfOffered(in: app)
        XCTAssertTrue(app.scrollViews["travelPlansScreen"].waitForExistence(timeout: 5))
        XCTAssertEqual(ownPlans.count, 1)
    }

    func testPrivacySummaryExplainsTravelHistoryAndRetentionInBothLanguages() {
        continueAfterFailure = false
        for (language, locale, travel, moments, device, deleted, retained) in [
            ("en", "en_US", "flights you add", "stay periods", "not sent to our servers", "personal plans", "may remain in shared trips"),
            ("zh-Hans", "zh_CN", "你添加的航班", "停留时段", "不会发送至我们的服务器", "个人出行计划", "可能保留")
        ] {
            let app = XCUIApplication()
            app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
            XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
            selectAppTab(2, in: app)
            let privacySettings = app.buttons["privacySettingsLink"]
            for _ in 0..<5 where !privacySettings.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
            privacySettings.tap()
            let privacy = app.buttons["privacyDataLink"]
            XCTAssertTrue(privacy.waitForExistence(timeout: 3))
            privacy.tap()
            XCTAssertTrue(app.scrollViews["privacyDataScreen"].waitForExistence(timeout: 5))
            for (id, text) in [("privacyTravelSummary", travel), ("privacyMomentsSummary", moments),
                               ("privacyDeviceLocationSummary", device), ("privacyDeletionSummary", deleted),
                               ("privacySharedTripRetention", retained)] {
                let row = app.staticTexts[id]
                for _ in 0..<5 where !row.isHittable { app.scrollViews["privacyDataScreen"].swipeUp() }
                XCTAssertTrue(row.exists)
                XCTAssertTrue(row.label.contains(text), row.label)
                if id == "privacyMomentsSummary" || id == "privacyDeviceLocationSummary" || id == "privacySharedTripRetention" {
                    capture("F04-\(id)-\(language)")
                }
            }
            let policy = app.descendants(matching: .any)["privacyPolicyLink"]
            for _ in 0..<4 where !policy.isHittable { app.scrollViews["privacyDataScreen"].swipeUp() }
            XCTAssertTrue(policy.isHittable)
            app.terminate()
        }
    }

    func testLocationSetupAndSolidAccentButtonsInBothThemes() {
        continueAfterFailure = false
        let app = XCUIApplication()
        let base = ["-skipOnboarding", "-resetDemoData", "-testReadableRequest", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        for appearance in ["solarJadeAppearance", "nightJadeAppearance"] {
            app.launchArguments = base
            app.launch()
            XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
            selectAppearance(appearance, in: app)
            capture("F05-home-badge-\(appearance)")
            app.open(URL(string: "whereismyfriend://friend-requests/05000000-0000-4000-8000-000000000001")!)
            XCTAssertTrue(app.buttons["acceptNotificationFriendRequest"].waitForExistence(timeout: 8))
            capture("F05-request-button-\(appearance)")
            app.buttons["Not now"].tap()
            selectAppTab(2, in: app)
            let notifications = app.buttons["notificationSettingsLink"]
            for _ in 0..<4 where !notifications.isHittable { app.scrollViews["profileSettingsScreen"].swipeDown() }
            notifications.tap()
            capture("F05-notifications-\(appearance)")
            app.terminate()
            app.resetAuthorizationStatus(for: .location)
            app.launchArguments = base + ["-testLocationSetup"]
            app.launch()
            let enable = app.buttons["enableInitialLocation"]
            XCTAssertTrue(enable.waitForExistence(timeout: 8))
            XCTAssertTrue(enable.isHittable)
            capture("F05-location-\(appearance)")
            app.buttons["skipInitialLocation"].tap()
            XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
            if appearance == "nightJadeAppearance" { selectAppearance("solarJadeAppearance", in: app) }
            app.terminate()
        }
    }

    func testSameCityHistoryKeepsPreviousVisitSeparateFromCurrentStay() {
        continueAfterFailure = false
        for (language, locale, unit) in [("en", "en_US", "1 hour"), ("zh-Hans", "zh_CN", "1小时")] {
            let app = historyApp(extra: "-testHistoryRevisit", language: language, locale: locale)
            let duration = app.staticTexts["sameCityDuration-10000000-0000-0000-0000-000000000001"]
            XCTAssertTrue(duration.waitForExistence(timeout: 5))
            XCTAssertTrue(duration.label.replacingOccurrences(of: " ", with: "").contains(unit.replacingOccurrences(of: " ", with: "")), duration.label)
            XCTAssertTrue(app.descendants(matching: .any)["pastMoment-07000000-0000-4000-8000-000000000001"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["pastMoment-07000000-0000-4000-8000-000000000002"].exists)
            capture("F07-repeated-visit-\(language)")
            app.terminate()
        }
    }

    func testSameCityHistoryWithoutSessionShowsRecentMatchInsteadOfDuration() {
        continueAfterFailure = false
        let app = historyApp(extra: "-testHistoryMissingSession", language: "en", locale: "en_US")
        let duration = app.staticTexts["sameCityDuration-10000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        XCTAssertEqual(duration.label, "Recent city match")
        XCTAssertTrue(app.descendants(matching: .any)["pastMoment-07000000-0000-4000-8000-000000000001"].exists)
        capture("F07-no-current-session")
    }

    func testHomeCityStatusDoesNotOpenSettingsAndSameCityChipOpensCard() {
        continueAfterFailure = false
        for (language, locale, prefix, summary) in [
            ("en", "en_US", "You’re in ", "Mia is here too"),
            ("zh-Hans", "zh_CN", "你在", "Mia 也在这里")
        ] {
            let app = XCUIApplication()
            app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
            let city = app.staticTexts["homeCityStatus"]
            XCTAssertTrue(city.waitForExistence(timeout: 8))
            XCTAssertEqual(city.label, "\(prefix)New York, NY")
            XCTAssertFalse(app.buttons["myCitySharingCard"].exists)
            XCTAssertFalse(app.buttons["homeCityStatus"].exists)
            XCTAssertFalse(app.buttons["homeCityRecoveryButton"].exists)
            city.tap()
            XCTAssertFalse(app.descendants(matching: .any)["citySharingSheet"].exists)
            let sameCity = app.buttons["sameCitySummaryTitle"]
            XCTAssertEqual(sameCity.label, summary)
            capture("F01-home-\(language)")
            sameCity.tap()
            // Even one friend opens the same-city card first.
            let row = app.buttons["sameCityFriend-mia"]
            XCTAssertTrue(row.waitForExistence(timeout: 4))
            XCTAssertFalse(app.descendants(matching: .any)["citySharingSheet"].exists)
            capture("F01-same-city-card-\(language)")
            // Picking a friend closes the card and opens them on the Friends stack.
            Thread.sleep(forTimeInterval: 1)
            row.press(forDuration: 0.15)
            XCTAssertTrue(app.navigationBars["Mia"].waitForExistence(timeout: 5))
            XCTAssertFalse(row.exists)
            capture("F01-same-city-friend-\(language)")
            app.navigationBars["Mia"].buttons.element(boundBy: 0).tap()
            XCTAssertTrue(sameCity.waitForExistence(timeout: 4))
            openCitySharingFromProfile(in: app)
            XCTAssertTrue(app.switches["citySharingToggle"].waitForExistence(timeout: 4))
            app.terminate()
        }
    }

    func testFriendSharingDescriptionsFollowGlobalAndIndividualPreferences() {
        checkFriendSharingDescriptions(language: "en", locale: "en_US",
            active: "Mia Chen can see your latest city",
            off: "Mia Chen can’t see your city",
            paused: "City sharing is paused. Resume it to share with Mia Chen.")
    }

    func testFriendSharingDescriptionsAreLocalizedInChinese() {
        checkFriendSharingDescriptions(language: "zh-Hans", locale: "zh_CN",
            active: "Mia Chen 可以看到你最近的城市",
            off: "Mia Chen 无法看到你的城市",
            paused: "城市共享已全局暂停。恢复后将与Mia Chen共享。")
    }

    func testMissingCityHasContextualRecoveryAndNoFalseSharingClaim() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewCityFallbackStates", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["homeCityStatus"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["homeCityStatus"].label, "Your city isn’t set yet")
        XCTAssertFalse(app.buttons["sameCitySummaryTitle"].exists)
        XCTAssertTrue(app.buttons["homeCityRecoveryButton"].exists)
        capture("F01-city-not-set")
        let mia = app.buttons["friendCard-10000000-0000-0000-0000-000000000001"]
        for _ in 0..<4 where !mia.isHittable { app.scrollViews["friendsScreen"].swipeUp() }
        mia.tap()
        expectFriendSharingDescription("Set your city to start sharing with Mia Chen.", in: app)
        app.navigationBars.buttons.firstMatch.tap()
        for _ in 0..<4 where !app.buttons["homeCityRecoveryButton"].isHittable { app.scrollViews["friendsScreen"].swipeDown() }
        app.buttons["homeCityRecoveryButton"].tap()
        XCTAssertTrue(app.buttons["manualCityButton"].waitForExistence(timeout: 4))
    }

    func testWhileUsingReminderExplainsAlwaysAndSnoozesAfterOpeningSettings() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = locationReminderArguments()
        app.launch()
        XCTAssertTrue(app.buttons["enableLocationReminder"].waitForExistence(timeout: 8))
        app.buttons["enableLocationReminder"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow While Using App"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        allow.tap()
        app.terminate()
        app.launchArguments = locationReminderArguments()
        app.launch()
        let action = app.buttons["enableLocationReminder"]
        XCTAssertTrue(action.waitForExistence(timeout: 8))
        XCTAssertEqual(action.label, "Choose Always")
        XCTAssertTrue(app.staticTexts["Choose Always to spot same-city friends while the app is closed."].exists)
        XCTAssertEqual(springboard.alerts.count, 0)
        capture("Always location weekly reminder")
        action.tap()
        XCTAssertTrue(XCUIApplication(bundleIdentifier: "com.apple.Preferences").wait(for: .runningForeground, timeout: 8))
        app.activate()
        XCTAssertTrue(app.staticTexts["homeCityStatus"].waitForExistence(timeout: 5))
        XCTAssertFalse(action.exists)
        app.resetAuthorizationStatus(for: .location)
    }

    func testLocationReminderDoesNotRepeatAfterOpeningFriendPlans() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = locationReminderArguments()
        app.launch()
        let enable = app.buttons["enableLocationReminder"]
        XCTAssertTrue(enable.waitForExistence(timeout: 8))
        app.buttons["friendPlansLink"].tap()
        XCTAssertTrue(app.scrollViews["friendPlansScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(enable.exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["homeCityStatus"].waitForExistence(timeout: 5))
        XCTAssertFalse(enable.exists)
        app.resetAuthorizationStatus(for: .location)
    }

    func testLocationReminderChineseCopyAndDismissal() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = locationReminderArguments().map {
            $0 == "(en)" ? "(zh-Hans)" : ($0 == "en_US" ? "zh_CN" : $0)
        }
        app.launch()
        let enable = app.buttons["enableLocationReminder"]
        XCTAssertTrue(enable.waitForExistence(timeout: 8))
        XCTAssertEqual(enable.label, "开启位置")
        XCTAssertTrue(app.staticTexts["让城市信息保持最新"].exists)
        capture("Weekly location reminder Chinese")
        app.buttons["dismissLocationReminder"].tap()
        XCTAssertTrue(enable.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["homeCityStatus"].exists)
        app.resetAuthorizationStatus(for: .location)
    }

    func testLocationReminderSnoozesAcrossNavigationAndRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = locationReminderArguments()
        app.launch()
        let enable = app.buttons["enableLocationReminder"]
        XCTAssertTrue(enable.waitForExistence(timeout: 8))
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count, 0)
        capture("Weekly location reminder")
        app.buttons["dismissLocationReminder"].tap()
        XCTAssertTrue(enable.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["homeCityStatus"].exists)
        selectAppTab(1, in: app)
        selectAppTab(0, in: app)
        XCTAssertFalse(enable.exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
        XCTAssertFalse(enable.exists)
        app.resetAuthorizationStatus(for: .location)
    }

    func testLocationReminderRequestsPermissionOnlyAfterTap() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = locationReminderArguments()
        app.launch()
        XCTAssertTrue(app.buttons["enableLocationReminder"].waitForExistence(timeout: 8))
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertEqual(springboard.alerts.count, 0)
        app.buttons["enableLocationReminder"].tap()
        let allow = springboard.alerts.buttons["Allow While Using App"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        allow.tap()
        XCTAssertTrue(app.staticTexts["homeCityStatus"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["enableLocationReminder"].exists)
        app.resetAuthorizationStatus(for: .location)
    }

    func testDeniedLocationReminderOpensSettingsWithoutAnotherSystemPrompt() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = locationReminderArguments()
        app.launch()
        XCTAssertTrue(app.buttons["enableLocationReminder"].waitForExistence(timeout: 8))
        app.buttons["enableLocationReminder"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.alerts.buttons["Don’t Allow"]
        XCTAssertTrue(deny.waitForExistence(timeout: 5))
        deny.tap()
        app.terminate()
        // A separate test history makes the denied-permission branch immediately due.
        app.launchArguments = locationReminderArguments()
        app.launch()
        let settingsAction = app.buttons["enableLocationReminder"]
        XCTAssertTrue(settingsAction.waitForExistence(timeout: 8))
        XCTAssertEqual(settingsAction.label, "Open Settings")
        capture("Location reminder after denied permission")
        settingsAction.tap()
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 5))
        app.activate()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(settingsAction.exists)
        XCTAssertEqual(springboard.alerts.count, 0)
        app.resetAuthorizationStatus(for: .location)
    }

    func testSetupChecklistClosesForTheRestOfTheDayInChinese() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testSetupChecklist",
                               "-setupChecklistNamespace=\(UUID().uuidString)",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 2).tap()
        let checklist = app.otherElements["setupChecklist"]
        XCTAssertTrue(checklist.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["完成设置"].exists)
        XCTAssertTrue(app.staticTexts["位置：始终"].exists)
        XCTAssertTrue(app.buttons["setupChecklist-location"].exists)
        capture("Setup checklist Chinese")
        app.buttons["setupChecklistClose"].tap()
        XCTAssertTrue(checklist.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["profileCitySharingButton"].exists)

        // Relaunching the same day keeps it closed.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.buttons["profileCitySharingButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(checklist.exists)
        app.resetAuthorizationStatus(for: .location)
    }

    private func locationReminderArguments() -> [String] {
        ["-skipOnboarding", "-resetDemoData", "-testLocationReminder",
         "-locationReminderNamespace=\(UUID().uuidString)",
         "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    }

    func testCompactTripFormAtAccessibilityTextSize() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewTrips",
                               "-tripTestNamespace=\(UUID().uuidString)",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["newTripButton"].waitForExistence(timeout: 8))
        app.buttons["newTripButton"].tap()
        XCTAssertTrue(app.buttons["tripDestinationPicker"].waitForExistence(timeout: 3))
        capture("Compact trip accessibility destination")
        for id in ["tripDatesPicker", "saveTripButton"] {
            let control = app.buttons[id]
            for _ in 0..<6 where !control.isHittable { app.scrollViews.firstMatch.swipeUp() }
            XCTAssertTrue(control.isHittable)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
        }
        capture("Compact trip accessibility fields")
        XCTAssertFalse(app.buttons["saveTripButton"].isEnabled)
    }

    func testCompactTripFormThemesAndSingleCalendar() {
        continueAfterFailure = false
        let app = tripsApp(seedExamples: false)
        for theme in ["solarJadeAppearance", "nightJadeAppearance"] {
            selectAppTab(2, in: app)
            let appearance = app.buttons["appearanceSettingsButton"]
            if !appearance.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
            XCTAssertTrue(appearance.waitForExistence(timeout: 3))
            appearance.tap()
            app.buttons[theme].tap()
            app.buttons["appearanceDoneButton"].tap()
            selectAppTab(1, in: app)
            app.buttons["newTripButton"].tap()
            let save = app.buttons["saveTripButton"]
            XCTAssertTrue(save.waitForExistence(timeout: 3))
            XCTAssertTrue(save.isHittable)
            XCTAssertFalse(save.isEnabled)
            capture("Compact trip empty - \(theme)")
            app.buttons["tripDestinationPicker"].tap()
            app.buttons["Tokyo (NRT)"].tap()
            XCTAssertTrue(save.waitForExistence(timeout: 3))
            XCTAssertTrue(save.isEnabled)
            let dates = app.buttons["tripDatesPicker"]
            let originalDates = dates.value as? String
            dates.tap()
            XCTAssertTrue(app.buttons["rangeNextMonth"].waitForExistence(timeout: 3))
            XCTAssertEqual(app.datePickers.count, 0)
            app.buttons["rangeNextMonth"].tap()
            app.buttons["Cancel"].firstMatch.tap()
            discardChangesIfOffered(in: app)
            XCTAssertEqual(dates.value as? String, originalDates)
            capture("Compact trip destination - \(theme)")
            app.buttons["Cancel"].tap()
            discardChangesIfOffered(in: app)
        }
    }

    func testTripPrimaryActionRemainsReachableAfterScrolling() {
        continueAfterFailure = false
        let app = tripsApp()
        let trip = app.buttons["tripCard-example-west"]
        XCTAssertTrue(trip.waitForExistence(timeout: 8))
        trip.tap()
        let board = app.scrollViews["fullTripArrivalBoard"]
        XCTAssertTrue(board.waitForExistence(timeout: 4))
        board.swipeUp()
        capture("Trip navigation after scrolling")

        let addFlight = app.buttons["addBoardFlightButton"]
        XCTAssertTrue(addFlight.isHittable)
        addFlight.tap()
        XCTAssertTrue(app.buttons["confirmAddTripFlightButton"].waitForExistence(timeout: 4))
        capture("Native flight form action")
        app.buttons["Cancel"].tap()
        discardChangesIfOffered(in: app)
        board.swipeDown()
        let options = app.buttons["tripOptionsButton"]
        XCTAssertTrue(options.isHittable)
        options.tap()
        XCTAssertTrue(app.buttons["Edit trip"].waitForExistence(timeout: 3))
    }

    func testFriendsAccessibilityLayoutKeepsCityAndFriendReachable() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-skipOnboarding", "-resetDemoData", "-previewCityFallbackCompare",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        app.launch()
        let screen = app.scrollViews["friendsScreen"]
        XCTAssertTrue(screen.waitForExistence(timeout: 8))
        let city = app.staticTexts["homeCityStatus"]
        XCTAssertTrue(city.isHittable)
        XCTAssertTrue(city.label.contains("Bakersfield, CA"))
        capture("Friends accessibility city layout")

        let friend = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Fremont, CA")).firstMatch
        for _ in 0..<6 where !friend.isHittable { screen.swipeUp() }
        XCTAssertTrue(friend.isHittable)
        XCTAssertLessThanOrEqual(friend.frame.maxX, app.frame.maxX)
        capture("Friends accessibility card layout")
        friend.tap()
        XCTAssertTrue(app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 3))
    }

    func testMembersCanNudgeAndMuteFlightPlanningRemindersWithoutSyncClutter() {
        continueAfterFailure = false
        let app = tripsApp(asMember: true)
        XCTAssertTrue(app.buttons["tripCard-example-west"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Updating trips…"].exists)
        XCTAssertFalse(app.staticTexts["Synced to your account"].exists)
        let trip = app.buttons["tripCard-example-tokyo"]
        for _ in 0..<4 where !trip.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(trip.exists); trip.tap()
        let remind = app.buttons["remindTripMember-example-lin"]
        XCTAssertTrue(remind.waitForExistence(timeout: 5))
        XCTAssertTrue(remind.isEnabled); remind.tap()
        XCTAssertTrue(remind.waitForExistence(timeout: 3))
        XCTAssertFalse(remind.isEnabled)
        capture("trip-flight-reminder-sent")
        app.buttons["tripOptionsButton"].tap()
        XCTAssertFalse(app.buttons["cancelTripButton"].exists)
        XCTAssertFalse(app.buttons["deleteTripButton"].exists)
        app.buttons["Notifications"].tap()
        let toggle = app.switches["tripPlanningRemindersToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 4))
        capture("trip-flight-planning-reminders-before-toggle")
        // SwiftUI exposes the whole labeled row; tap the actual switch at its trailing edge.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let switchedOff = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: toggle)
        let toggleResult = XCTWaiter.wait(for: [switchedOff], timeout: 3)
        capture("trip-flight-planning-reminders-settings")
        XCTAssertEqual(toggleResult, .completed)
        app.buttons["Done"].tap()
        app.buttons["tripPeopleButton"].tap()
        XCTAssertTrue(app.buttons["remindTripMember-example-alex"].waitForExistence(timeout: 4))
        capture("trip-people-reminders")
    }

    func testTripOwnerRemovesMemberAndDeletesWithConfirmation() {
        continueAfterFailure = false
        let app = tripsApp()
        let trip = app.buttons["tripCard-example-west"]
        XCTAssertTrue(trip.waitForExistence(timeout: 8)); trip.tap()
        app.buttons["tripPeopleButton"].tap()
        let remove = app.buttons["removeTripMember-example-mia"]
        XCTAssertTrue(remove.waitForExistence(timeout: 4)); remove.tap()
        XCTAssertTrue(app.buttons["Keep member"].waitForExistence(timeout: 3))
        app.buttons["Keep member"].tap()
        XCTAssertTrue(remove.exists); remove.tap()
        capture("trip-remove-member-confirmation")
        app.buttons["Remove member"].tap()
        XCTAssertTrue(remove.waitForNonExistence(timeout: 4))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["tripPeopleButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tripPeopleButton"].label.contains("4 people"))
        app.buttons["tripOptionsButton"].tap()
        XCTAssertFalse(app.buttons["cancelTripButton"].exists)
        XCTAssertFalse(app.buttons["Cancel trip"].exists)
        app.buttons["deleteTripButton"].tap()
        capture("trip-delete-confirmation")
        app.buttons["Keep trip"].tap()
        XCTAssertTrue(app.buttons["tripPeopleButton"].exists)
        app.buttons["tripOptionsButton"].tap()
        app.buttons["deleteTripButton"].tap()
        app.buttons["Delete trip"].tap()
        XCTAssertTrue(app.buttons["tripCard-example-new-york"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tripCard-example-west"].exists)
    }

    func testTripMemberCanLeaveButCannotManageOthers() {
        continueAfterFailure = false
        let app = tripsApp(asMember: true)
        let trip = app.buttons["tripCard-example-west"]
        XCTAssertTrue(trip.waitForExistence(timeout: 8)); trip.tap()
        app.buttons["tripPeopleButton"].tap()
        XCTAssertTrue(app.staticTexts["In this trip"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["removeTripMember-example-mia"].exists)
        app.buttons["Done"].tap()
        app.buttons["tripOptionsButton"].tap()
        XCTAssertFalse(app.buttons["deleteTripButton"].exists)
        XCTAssertFalse(app.buttons["cancelTripButton"].exists)
        app.buttons["leaveTripButton"].tap()
        capture("trip-leave-confirmation")
        app.buttons["Keep trip"].tap()
        XCTAssertTrue(app.buttons["tripPeopleButton"].exists)
        app.buttons["tripOptionsButton"].tap()
        app.buttons["leaveTripButton"].tap()
        app.buttons["Leave trip"].tap()
        XCTAssertTrue(app.buttons["tripCard-example-new-york"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tripCard-example-west"].exists)
    }

    func testSingleCalendarSelectsRangeAcrossMonthsAndCancelKeepsDates() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
        app.buttons["friendPlansLink"].tap()
        let copy = app.buttons["copyFriendPlan-A7150000-0000-0000-0000-000000000001"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5)); copy.tap()
        let summary = app.buttons["travelPlanDates"]
        XCTAssertTrue(summary.waitForExistence(timeout: 3))
        let original = summary.label
        summary.tap()
        XCTAssertTrue(app.buttons["rangeNextMonth"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.datePickers.count, 0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let base = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let next = calendar.date(byAdding: .month, value: 1, to: base)!
        let after = calendar.date(byAdding: .month, value: 2, to: base)!
        let start = calendar.date(byAdding: .day, value: calendar.range(of: .day, in: .month, for: next)!.count - 2, to: next)!
        let end = calendar.date(byAdding: .day, value: 2, to: after)!
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.dateFormat = "yyyy-MM-dd"
        let startID = "rangeDay-\(formatter.string(from: start))", endID = "rangeDay-\(formatter.string(from: end))"
        app.buttons["rangeNextMonth"].tap()
        XCTAssertTrue(app.buttons[startID].waitForExistence(timeout: 3)); app.buttons[startID].tap()
        XCTAssertFalse(app.buttons["confirmDateRange"].isEnabled)
        app.buttons["rangeNextMonth"].tap(); app.buttons[endID].tap()
        XCTAssertTrue(app.buttons["confirmDateRange"].isEnabled)
        capture("single-calendar-cross-month-range")
        app.buttons["confirmDateRange"].tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 3)); XCTAssertNotEqual(summary.label, original)
        let committed = summary.label
        summary.tap(); app.buttons["rangeNextMonth"].tap()
        app.buttons["Cancel"].firstMatch.tap()
        discardChangesIfOffered(in: app)
        XCTAssertEqual(summary.label, committed)
    }

    func testManualCitySelectionDoesNotRequireLocationPermission() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        openCitySharingFromProfile(in: app)
        let manual = app.buttons["manualCityButton"]
        for _ in 0..<3 where !manual.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(manual.waitForExistence(timeout: 3)); manual.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        XCTAssertLessThan(search.frame.midY, app.frame.midY)
        let city = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "travelCity-")).firstMatch
        XCTAssertTrue(city.waitForExistence(timeout: 3)); city.tap()
        XCTAssertTrue(app.buttons["refreshLocationButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["refreshLocationButton"].label.contains("Use device location"))
    }

    func testPlanCityPickerShowsSearchAtTopAndOwnTripDestinations() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
        app.buttons["friendPlansLink"].tap()
        XCTAssertTrue(app.buttons["addMyFriendPlan"].waitForExistence(timeout: 5))
        app.buttons["addMyFriendPlan"].tap()
        app.buttons["travelPlanCity"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        XCTAssertLessThan(search.frame.midY, app.frame.midY)
        XCTAssertTrue(app.staticTexts["FROM YOUR SHARED TRIPS"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Choose a city"].buttons["Cancel"].exists)
        capture("plan-city-picker-top-search")
        let tripShortcut = app.buttons["tripCity-example-new-york"]
        XCTAssertTrue(tripShortcut.waitForExistence(timeout: 3))
        tripShortcut.tap()
        XCTAssertTrue((search.value as? String)?.contains("New York") == true)
    }

    func testFriendPlanSecondPageOpensDetails() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testPagedFriendPlans", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
        app.buttons["friendPlansLink"].tap()
        let later = app.buttons["friendPlan-A7150000-0000-0000-0000-000000000003"]
        XCTAssertFalse(later.exists)
        let more = app.buttons["loadMoreFriendPlans"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        for _ in 0..<5 where !more.isHittable { app.scrollViews["friendPlansScreen"].swipeUp() }
        more.tap()
        for _ in 0..<5 where !later.isHittable { app.scrollViews["friendPlansScreen"].swipeUp() }
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        capture("friend-plans-second-page")
        later.tap()
        XCTAssertTrue(app.buttons["copyFriendPlanDetail"].waitForExistence(timeout: 5))
    }

    func testFriendPlanBadgeOpensThatFriendsSharedCities() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let lin = app.buttons["friendCard-10000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(lin.waitForExistence(timeout: 8))
        XCTAssertTrue(lin.label.contains("Has shared travel plans"))
        let mia = app.buttons["friendCard-10000000-0000-0000-0000-000000000001"]
        XCTAssertFalse(mia.label.contains("Has shared travel plans"))
        for _ in 0..<3 where !lin.isHittable { app.scrollViews["friendsScreen"].swipeUp() }
        capture("friend-plan-badge")
        lin.tap()
        let plan = app.buttons["friendDetailPlan-A7150000-0000-0000-0000-000000000001"]
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        XCTAssertTrue(plan.label.contains("Tokyo"))
        XCTAssertFalse(app.buttons["friendDetailPlan-A7150000-0000-0000-0000-000000000002"].exists)
        for _ in 0..<3 where !plan.isHittable { app.swipeUp() }
        capture("friend-shared-plans")
        plan.tap()
        XCTAssertTrue(app.scrollViews["friendPlanDetail"].waitForExistence(timeout: 3))
    }

    func testPlanCityPickerUsesChineseLabels() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
        app.buttons["friendPlansLink"].tap()
        XCTAssertTrue(app.buttons["addMyFriendPlan"].waitForExistence(timeout: 5))
        app.buttons["addMyFriendPlan"].tap()
        app.buttons["travelPlanCity"].tap()
        XCTAssertTrue(app.navigationBars["选择城市"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.searchFields.firstMatch.label, "城市或城镇")
        XCTAssertTrue(app.staticTexts["从你的共同旅行中"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["查找"].firstMatch.exists)
    }

    func testFriendPlansKeepsHomeCompactAndCopiesAPrivateDraft() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let link = app.buttons["friendPlansLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 8))
        let friendCard = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Mia Chen,")).firstMatch
        XCTAssertTrue(friendCard.waitForExistence(timeout: 5))
        XCTAssertTrue(friendCard.isHittable)
        XCTAssertFalse(app.buttons["friendPlan-A7150000-0000-0000-0000-000000000001"].exists)
        capture("friend-plans-home-compact")
        link.tap()
        let plan = app.buttons["friendPlan-A7150000-0000-0000-0000-000000000001"]
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
        capture("friend-plans-list")
        plan.tap()
        XCTAssertTrue(app.buttons["copyFriendPlanDetail"].waitForExistence(timeout: 5))
        capture("friend-plan-details")
        app.buttons["copyFriendPlanDetail"].tap()
        XCTAssertTrue(app.navigationBars["New travel plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["travelPlanCity"].label.contains("Tokyo"))
        clearTravelAudience(in: app)
        XCTAssertTrue(app.staticTexts["Only me · choose friends"].exists)
        let browse = app.switches["travelPlanBrowsing"]
        XCTAssertEqual(browse.value as? String, "1")
        let save = app.buttons["saveTravelPlan"]
        for _ in 0..<5 where !save.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertEqual(app.switches["travelPlanAlerts"].value as? String, "0")
        save.tap()
        XCTAssertTrue(app.scrollViews["friendPlanDetail"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["manageOwnTravelPlans"].tap()
        let own = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "travelPlan-")).firstMatch
        XCTAssertTrue(own.waitForExistence(timeout: 5)); own.tap()
        XCTAssertTrue(app.staticTexts["Only me · choose friends"].exists)
        XCTAssertEqual(app.switches["travelPlanBrowsing"].value as? String, "1")
    }

    func testFriendPlansChineseOptOutPersists() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["friendPlansLink"].label.contains("好友出行计划"))
        app.buttons["friendPlansLink"].tap()
        XCTAssertTrue(app.navigationBars["好友出行计划"].waitForExistence(timeout: 5))
        capture("friend-plans-chinese")
        let copy = app.buttons["copyFriendPlan-A7150000-0000-0000-0000-000000000001"]
        XCTAssertTrue(copy.waitForExistence(timeout: 3)); copy.tap()
        app.buttons["travelPlanAudience"].tap()
        app.buttons["clearTravelAudience"].tap()
        let audience = app.switches["travelAudience-lin"]
        XCTAssertTrue(audience.waitForExistence(timeout: 3)); audience.switches.firstMatch.tap()
        app.buttons["travelAudienceDone"].tap()
        let browse = app.switches["travelPlanBrowsing"]
        for _ in 0..<4 where !browse.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertEqual(browse.value as? String, "1")
        browse.switches.firstMatch.tap()
        XCTAssertEqual(browse.value as? String, "0")
        let save = app.buttons["saveTravelPlan"]
        for _ in 0..<4 where !save.isHittable { app.scrollViews.firstMatch.swipeUp() }
        capture("friend-plan-opt-out-chinese")
        save.tap()
        XCTAssertTrue(app.scrollViews["friendPlansScreen"].waitForExistence(timeout: 5))
        app.buttons["manageOwnTravelPlans"].tap()
        let own = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "travelPlan-")).firstMatch
        XCTAssertTrue(own.waitForExistence(timeout: 5)); own.tap()
        XCTAssertEqual(app.switches["travelPlanBrowsing"].value as? String, "0")
    }

    func testFriendRequestNotificationRestoresAndCanBeAccepted() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testReadableRequest", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
        app.open(URL(string: "whereismyfriend://friend-requests/05000000-0000-4000-8000-000000000001")!)
        XCTAssertTrue(app.buttons["acceptNotificationFriendRequest"].waitForExistence(timeout: 8))
        capture("friend-request-notification")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-testReadableRequest" || $0 == "-resetDemoData" }
        app.launch()
        XCTAssertTrue(app.buttons["acceptNotificationFriendRequest"].waitForExistence(timeout: 8))
        app.buttons["acceptNotificationFriendRequest"].tap()
        XCTAssertTrue(app.buttons["acceptNotificationFriendRequest"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
    }
    func testAccountDeletionFailureShowsVisibleErrorWithoutSigningOut() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testAccountDeletionFailure", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        selectAppTab(2, in: app)
        let privacy = app.buttons["privacySettingsLink"]
        for _ in 0..<6 where !privacy.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        privacy.tap()
        let button = app.buttons["Delete account"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        XCTAssertTrue(button.isHittable)
        button.tap()
        let confirm = app.sheets.buttons["Delete account"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        XCTAssertTrue(app.alerts["Couldn’t confirm account deletion"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.tabBars.firstMatch.exists)
    }

    func testCityRegionArtworkKeepsRealCityAndDoesNotCreateSameCityMatch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewCityRegions", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
        // The initial view can precede the repository's city-region fixture, and one pull
        // doesn't always trigger a refresh under the taller 1.0.8 header.
        var loaded = false
        for _ in 0..<3 where !loaded {
            app.scrollViews["friendsScreen"].swipeDown()
            let loadedCity = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label CONTAINS %@", "Milpitas"),
                object: app.staticTexts["homeCityStatus"])
            loaded = XCTWaiter.wait(for: [loadedCity], timeout: 5) == .completed
        }
        XCTAssertTrue(loaded)
        openCitySharingFromProfile(in: app)
        let region = app.staticTexts["currentCityRegion"]
        XCTAssertTrue(region.waitForExistence(timeout: 5))
        XCTAssertEqual(region.label, "Part of Silicon Valley")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Milpitas")).firstMatch.exists)
        capture("city-region-milpitas-details")
        app.buttons["Done"].tap()
        selectAppTab(0, in: app)
        XCTAssertTrue(app.buttons["sameCitySummaryTitle"].waitForNonExistence(timeout: 5))
        capture("city-region-friends-real-cities")
    }

    func testFirstUseLocationAllowMovesToFriends() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testLocationSetup", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["enableInitialLocation"].waitForExistence(timeout: 5))
        capture("first-use-location-setup")
        app.buttons["enableInitialLocation"].tap()
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow While Using App"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5)); allow.tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["enableInitialLocation"].exists)
        app.resetAuthorizationStatus(for: .location)
    }

    func testFirstUseLocationSetupRequestsSystemPermissionAndAllowsDecline() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testLocationSetup", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchArguments += ["-testLocationReminder", "-locationReminderNamespace=\(UUID().uuidString)"]
        app.launch()
        XCTAssertTrue(app.buttons["enableInitialLocation"].waitForExistence(timeout: 5))
        app.buttons["enableInitialLocation"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.alerts.buttons["Don’t Allow"]
        XCTAssertTrue(deny.waitForExistence(timeout: 5))
        deny.tap()
        XCTAssertTrue(app.buttons["enableInitialLocation"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["enableInitialLocation"].label, "Open Settings")
        app.buttons["skipInitialLocation"].tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["enableLocationReminder"].exists)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-testLocationSetup" }
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["enableLocationReminder"].exists)
        app.resetAuthorizationStatus(for: .location)
    }

    func testNoMatchCardsDisappearWhenCitySharingStops() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        XCTAssertTrue(app.buttons["sameCitySummaryTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["upcomingTogetherToggle"].exists)
        openCitySharingFromProfile(in: app)
        let sharing = app.switches["citySharingToggle"]
        XCTAssertTrue(sharing.waitForExistence(timeout: 3))
        sharing.switches.firstMatch.tap()
        app.buttons["Done"].tap()
        selectAppTab(0, in: app)
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["sameCitySummaryTitle"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["upcomingTogetherToggle"].exists)
        capture("friends-without-matches")
        openCitySharingFromProfile(in: app)
        XCTAssertTrue(sharing.waitForExistence(timeout: 3))
        sharing.switches.firstMatch.tap()
        app.buttons["Done"].tap()
        selectAppTab(0, in: app)
        let summary = app.buttons["sameCitySummaryTitle"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sameCityFriend-mia"].exists)
        capture("AUDIT-sharing-resume-restores-header")
    }

    func testTravelCitySearchFindsPalmSpringsFromProfile() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        selectAppTab(2, in: app)
        let plans = app.buttons["travelPlansLink"]
        for _ in 0..<4 where !plans.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        XCTAssertTrue(plans.isHittable); plans.tap()
        XCTAssertTrue(app.buttons["addTravelPlan"].waitForExistence(timeout: 3)); app.buttons["addTravelPlan"].tap()
        XCTAssertTrue(app.navigationBars["New travel plan"].waitForExistence(timeout: 3))
        app.buttons["travelPlanCity"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap(); search.typeText("Palm Springs California")
        let city = app.buttons["travelCity-Palm Springs"]
        XCTAssertTrue(city.waitForExistence(timeout: 25)); city.tap()
        XCTAssertTrue(app.buttons["travelPlanCity"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["travelPlanCity"].label.contains("Palm Springs"))
        capture("travel-plan-palm-springs")
    }

    func testPersonalPlanCreatesOverlapAndRevokingShareRemovesIt() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testOverlapCity", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        let entry = app.buttons["upcomingTogetherToggle"]
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(entry.exists)
        selectAppTab(2, in: app)
        let plans = app.buttons["travelPlansLink"]
        for _ in 0..<4 where !plans.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        XCTAssertTrue(plans.isHittable); plans.tap()
        XCTAssertTrue(app.buttons["addTravelPlan"].waitForExistence(timeout: 3)); app.buttons["addTravelPlan"].tap()
        XCTAssertTrue(app.navigationBars["New travel plan"].waitForExistence(timeout: 3))
        app.buttons["travelPlanCity"].tap()
        XCTAssertTrue(app.buttons["travelCity-Tokyo"].waitForExistence(timeout: 3)); app.buttons["travelCity-Tokyo"].tap()
        capture("travel-plan-private-editor")
        app.buttons["travelPlanAudience"].tap()
        app.buttons["clearTravelAudience"].tap()
        let audience = app.switches["travelAudience-lin"]
        XCTAssertTrue(audience.waitForExistence(timeout: 3)); audience.switches.firstMatch.tap()
        XCTAssertEqual(audience.value as? String, "1")
        app.buttons["travelAudienceDone"].tap()
        let save = app.buttons["saveTravelPlan"]
        if !save.isHittable { app.scrollViews.firstMatch.swipeUp() }
        save.tap()
        XCTAssertTrue(app.navigationBars["My travel plans"].waitForExistence(timeout: 5))
        selectAppTab(0, in: app)
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        openOverlapDetail(in: app)
        capture("upcoming-together-expanded")
        let manage = app.buttons["My travel plans"]
        if !manage.isHittable { app.scrollViews["friendsScreen"].swipeUp() }; manage.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "travelPlan-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3)); row.tap()
        app.buttons["travelPlanAudience"].tap()
        audience.switches.firstMatch.tap()
        XCTAssertEqual(audience.value as? String, "0")
        app.buttons["travelAudienceDone"].tap()
        if !save.isHittable { app.scrollViews.firstMatch.swipeUp() }; save.tap()
        XCTAssertTrue(app.navigationBars["My travel plans"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["upcomingOverlapDetail"].exists)
        XCTAssertTrue(app.staticTexts["This overlap is no longer available. Plans or sharing may have changed."].exists)
        let close = app.buttons["closeUpcomingTogether"]
        if !close.isHittable { app.scrollViews["friendsScreen"].swipeUp() }
        close.tap()
        XCTAssertFalse(entry.exists)
    }

    func testHomeSummaryExpandsEveryOverlapAndColdLinkOpensBeyondPreview() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-testOverlapSummary", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        let toggle = app.buttons["upcomingTogetherToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "upcomingOverlap-"))
        XCTAssertEqual(rows.count, 0)
        toggle.tap()
        XCTAssertTrue(rows.element(boundBy: 4).waitForExistence(timeout: 5)); XCTAssertEqual(rows.count, 5)
        capture("home-summary-all-five-overlaps")
        let id = String(rows.element(boundBy: 4).identifier.dropFirst("upcomingOverlap-".count))
        app.terminate(); app.open(URL(string: "whereismyfriend://upcoming/" + id)!)
        XCTAssertTrue(app.descendants(matching: .any)["upcomingOverlapDetail"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["This overlap is no longer available. Plans or sharing may have changed."].exists)
        capture("home-summary-fifth-overlap-cold-link")
    }

    func testUnavailableUpcomingLinkIsSafeAfterColdLaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData"]
        app.launch()
        let url = URL(string: "whereismyfriend://upcoming/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")!
        app.open(url)
        XCTAssertTrue(app.staticTexts["This overlap is no longer available. Plans or sharing may have changed."].waitForExistence(timeout: 5))
        app.terminate(); app.open(url)
        XCTAssertTrue(app.staticTexts["This overlap is no longer available. Plans or sharing may have changed."].waitForExistence(timeout: 8))
        XCTAssertFalse(app.descendants(matching: .any)["upcomingOverlapDetail"].exists)
        app.buttons["closeUpcomingTogether"].tap()
        XCTAssertFalse(app.buttons["upcomingTogetherToggle"].exists)
    }

    func testSameCityChipOpensOneFriendOrTheFriendList() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        let chip = app.buttons["sameCitySummaryTitle"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.label, "Mia is here too")
        chip.tap()
        XCTAssertTrue(app.navigationBars["Mia"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["sameCityFriend-mia"].exists)
        app.terminate()

        app.launchArguments += ["-previewSameCityCount", "3"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.label, "3 friends are here too")
        chip.tap()
        XCTAssertTrue(app.buttons["sameCityFriend-mia"].waitForExistence(timeout: 4))
        capture("same-city-sheet")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["sameCityFriend-mia"].waitForNonExistence(timeout: 4))
    }

    func testSameCityChipStaysClosedAfterRefreshTabSwitchAndForeground() {
        continueAfterFailure = false
        let app = waveTwoApp()
        let chip = app.buttons["sameCitySummaryTitle"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))

        app.scrollViews["friendsScreen"].swipeDown()
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        selectAppTab(2, in: app)
        selectAppTab(0, in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sameCityFriend-mia"].exists)
        XCTAssertFalse(app.buttons["closeSameCityReunion"].exists)
        capture("manual-same-city-chip-after-refresh-and-foreground")
    }

    func testUnavailableSameCityLinkOpensSafelyFromAnotherTabAndAfterRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        selectAppTab(2, in: app)
        let url = URL(string: "whereismyfriend://events/11111111-2222-4333-8444-555555555555")!
        app.open(url)
        XCTAssertTrue(app.staticTexts["This update is no longer available"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["closeSameCityReunion"].exists)
        XCTAssertFalse(app.buttons["sameCitySayHello"].exists)
        // Replaying the event rebuilds the Friends view with the same selected ID.
        app.open(url)
        XCTAssertTrue(app.staticTexts["This update is no longer available"].waitForExistence(timeout: 5))
        capture("manual-same-city-event-replay")
        app.terminate()
        app.open(url)
        XCTAssertTrue(app.staticTexts["This update is no longer available"].waitForExistence(timeout: 8))
        capture("manual-same-city-cold-link")
        XCTAssertTrue(app.buttons["closeSameCityReunion"].waitForExistence(timeout: 3))
        app.buttons["closeSameCityReunion"].tap()
        XCTAssertFalse(app.staticTexts["This update is no longer available"].exists)
    }

    func testFriendInviteDeepLinkSurvivesRelaunchAndDismissal() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        // A previous interrupted run may have left the exact persisted invitation.
        if app.buttons["Not now"].waitForExistence(timeout: 2) { app.buttons["Not now"].tap() }
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))

        let url = URL(string: "whereismyfriend://invite/friend_63891351bea44")!
        app.open(url)
        XCTAssertTrue(app.staticTexts["Connect with @friend_63891351bea44?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Send friend request"].isHittable)

        // Retain local storage: this models upgrading a phone stuck in the crash loop.
        app.terminate()
        app.launchArguments.removeAll { $0 == "-resetDemoData" }
        app.launch()
        XCTAssertTrue(app.staticTexts["Connect with @friend_63891351bea44?"].waitForExistence(timeout: 5))
        app.buttons["Not now"].tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Not now"].exists)

        app.open(url)
        XCTAssertTrue(app.buttons["Not now"].waitForExistence(timeout: 5))
        app.buttons["Not now"].tap()
    }

    func testFriendDetailShowsSharedPlanRightAfterLaunchAndOnReturn() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 2) { app.buttons["Not now"].tap() }
        let lin = app.buttons["friendCard-10000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(lin.waitForExistence(timeout: 8))
        let tokyo = app.staticTexts.matching(NSPredicate(format: "label == %@", "Tokyo, Japan"))
        for _ in 0..<2 {
            lin.tap()
            XCTAssertTrue(app.navigationBars["Lin"].waitForExistence(timeout: 5))
            // Lin's current city card says "Tokyo, Japan" once; the shared plan adds a second one.
            let shown = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count >= 2"), object: tokyo)
            XCTAssertEqual(XCTWaiter.wait(for: [shown], timeout: 3), .completed)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(lin.waitForExistence(timeout: 5))
        }
    }

    func testOwnInviteLinkDoesNotOfferAFriendRequest() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 2) { app.buttons["Not now"].tap() }
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))

        // The demo account is @wangyang; a differently cased username still counts as yours.
        app.open(URL(string: "whereismyfriend://invite/WangYang")!)
        XCTAssertTrue(app.staticTexts["This is your invite link"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Send friend request"].exists)
        app.buttons["dismissOwnInvite"].tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["This is your invite link"].exists)
    }

    func testTripInviteDeepLinkSurvivesRelaunchAndDismissal() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 2) { app.buttons["Not now"].tap() }
        app.open(URL(string: "whereismyfriend://trips/join/11111111-2222-4333-8444-555555555555")!)
        XCTAssertTrue(app.navigationBars["Trip invitation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Close"].isHittable)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-resetDemoData" }
        app.launch()
        XCTAssertTrue(app.navigationBars["Trip invitation"].waitForExistence(timeout: 5))
        app.buttons["Close"].tap()
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Trip invitation"].exists)
    }

    func testOnboardingMotionCanBeInterrupted() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-previewOnboarding", "-previewOnboardingStep=1"]
        app.launch()
        let next = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        next.tap()
        capture("privacy-after-interrupted-motion")
        XCTAssertTrue(app.staticTexts["onboardingTitle"].label.contains("Your choice"))
        XCTAssertFalse(app.descendants(matching: .any)["onboardingExampleNotification"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["onboardingExampleTrip"].exists)
        XCTAssertTrue(next.isHittable)
        app.buttons["onboardingBackButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["onboardingExampleTrip"].firstMatch.waitForExistence(timeout: 4))
    }

    func testOnboardingReducedMotionShowsCompleteExamples() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-previewOnboarding", "-previewOnboardingStep=1", "-previewOnboardingReducedMotion"]
        app.launch()
        XCTAssertTrue(app.buttons["onboardingContinueButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["onboardingExampleNotification"].exists)
        app.buttons["onboardingContinueButton"].tap()
        let trip = app.descendants(matching: .any)["onboardingExampleTrip"].firstMatch
        XCTAssertTrue(trip.exists)
        XCTAssertTrue(trip.label.contains("08:40"))
        XCTAssertTrue(trip.label.contains("10:15"))
        capture("onboarding-reduced-motion-trip")
    }

    func testOnboardingCanSkipAndFinishFromProfile() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        selectAppTab(2, in: app)
        let tools = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Developer Lab & Tools")).firstMatch
        for _ in 0..<6 where !tools.isHittable {
            app.scrollViews["profileSettingsScreen"].swipeUp()
        }
        XCTAssertTrue(tools.isHittable)
        tools.tap()
        let preview = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Preview onboarding")).firstMatch
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        if !preview.isHittable { app.scrollViews.firstMatch.swipeUp() }
        preview.tap()
        let skip = app.buttons["onboardingSkipButton"]
        XCTAssertTrue(skip.waitForExistence(timeout: 3))
        skip.tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        preview.tap()
        let next = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(next.waitForExistence(timeout: 3))
        next.tap()
        next.tap()
        next.tap()
        next.tap()
        XCTAssertTrue(preview.waitForExistence(timeout: 3))
        XCTAssertFalse(next.exists)
    }

    func testOnboardingFourChaptersAndExamples() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-previewOnboarding", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let title = app.staticTexts["onboardingTitle"]
        let next = app.buttons["onboardingContinueButton"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertTrue(title.label.contains("Different cities"))
        XCTAssertTrue(app.buttons["onboardingSkipButton"].isHittable)
        XCTAssertFalse(app.buttons["onboardingBackButton"].isEnabled)
        capture("onboarding-world")

        next.tap()
        let notification = app.descendants(matching: .any)["onboardingExampleNotification"].firstMatch
        XCTAssertTrue(notification.waitForExistence(timeout: 3))
        XCTAssertTrue(title.label.contains("reunion"))
        XCTAssertFalse(app.buttons["onboardingPausePreviewButton"].exists)
        XCTAssertTrue(app.staticTexts["Example notification"].exists)
        capture("onboarding-notification")

        next.tap()
        let trip = app.descendants(matching: .any)["onboardingExampleTrip"].firstMatch
        XCTAssertTrue(trip.waitForExistence(timeout: 3))
        XCTAssertTrue(title.label.contains("Your next trip"))
        XCTAssertTrue(next.label.contains("Continue"))
        capture("onboarding-trip")
        next.tap()
        XCTAssertTrue(title.label.contains("Your choice"))
        XCTAssertTrue(next.label.contains("Get started"))
        XCTAssertFalse(trip.exists)
        XCTAssertFalse(notification.exists)
        XCTAssertFalse(app.staticTexts["ILLUSTRATIVE PREVIEW"].exists)
        capture("onboarding-privacy")
        app.buttons["onboardingBackButton"].tap()
        XCTAssertTrue(trip.waitForExistence(timeout: 3))
        app.buttons["onboardingBackButton"].tap()
        XCTAssertTrue(notification.waitForExistence(timeout: 3))
        app.buttons["onboardingBackButton"].tap()
        XCTAssertTrue(title.label.contains("Different cities"))
    }

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

        openCitySharingFromProfile(in: app)
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
        selectAppTab(2, in: app)
        XCTAssertTrue(app.buttons["editProfileButton"].waitForExistence(timeout: 3))
        assertTouchTarget(app.buttons["editProfileButton"])
        app.buttons["editProfileButton"].tap()

        let nameField = app.textFields["displayNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "New Name")
        let username = app.textFields["profileUsernameField"]
        username.replaceText(with: "x")
        app.buttons["saveProfileButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["profileValidationMessage"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(nameField.value as? String, "New Name")
        username.replaceText(with: "new_username")
        app.buttons["saveProfileButton"].tap()
        XCTAssertTrue(app.staticTexts["New Name"].waitForExistence(timeout: 3))
        // The redesigned header shows the handle and city on one line ("@name · City").
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "@new_username")).firstMatch.exists)

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
        selectAppTab(2, in: app)

        let settingsLink = app.buttons["notificationSettingsLink"]
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 3))
        settingsLink.tap()

        XCTAssertTrue(app.descendants(matching: .any)["notificationSettingsScreen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.descendants(matching: .any)["notificationPermissionCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["devicePushRegistrationCard"].exists)
        XCTAssertFalse(app.buttons["retryPushRegistrationButton"].exists)
        let previews = app.switches["notificationPreviewsToggle"]
        XCTAssertTrue(previews.exists)
        previews.switches.firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["notificationPermissionCard"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["devicePushRegistrationCard"].exists)
        capture("notification-setup-with-private-previews")
    }

    func testAppearanceCanSwitchBetweenSolarAndNightJade() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        selectAppTab(2, in: app)

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

    /// Current marketing captures use XCTest attachments so they can be exported
    /// from the result bundle on any machine, without a developer-specific path.
    func testCaptureSeptemberMarketingScreenshots() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
        capture("marketing-01-friends")
        app.buttons["sameCitySummaryTitle"].tap()
        XCTAssertTrue(app.navigationBars["Mia"].waitForExistence(timeout: 3))
        capture("marketing-02-same-city")
        app.terminate()

        let trips = tripsApp()
        XCTAssertTrue(trips.buttons["tripCard-example-west"].waitForExistence(timeout: 8))
        capture("marketing-04-trips")
        trips.buttons["tripCard-example-west"].tap()
        XCTAssertTrue(trips.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 5))
        capture("marketing-05-arrivals")
        trips.terminate()

        app.launch()
        openCitySharingFromProfile(in: app)
        XCTAssertTrue(app.switches["citySharingToggle"].waitForExistence(timeout: 3))
        capture("marketing-07-sharing")
        app.terminate()

        app.launchArguments = ["-previewWidgets", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        capture("marketing-06-widgets")
        app.terminate()
    }

    func testCaptureUpdatedMarketingEnglish() { captureUpdatedMarketing(language: "en", locale: "en_US") }
    func testCaptureUpdatedMarketingChinese() { captureUpdatedMarketing(language: "zh-Hans", locale: "zh_CN") }

    private func captureUpdatedMarketing(language: String, locale: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        let base = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(\(language))", "-AppleLocale", locale,
                    "-AppleInterfaceStyle", "Light"]
        app.launchArguments = base
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
        let lin = app.buttons["friendCard-10000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(lin.waitForExistence(timeout: 5))
        capture("\(language)-01-friends")
        app.buttons["friendPlansLink"].tap()
        XCTAssertTrue(app.buttons["friendPlan-A7150000-0000-0000-0000-000000000001"].waitForExistence(timeout: 5))
        capture("\(language)-02-friend-plans")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["sameCitySummaryTitle"].tap()
        XCTAssertTrue(app.navigationBars["Mia"].waitForExistence(timeout: 5))
        capture("\(language)-04-here-together")
        app.terminate()

        app.launchArguments = base + ["-marketingOverlap"]
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
        app.buttons["friendPlansLink"].tap()
        XCTAssertTrue(app.buttons["friendPlan-A7150000-0000-0000-0000-000000000001"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["upcomingTogetherToggle"].waitForExistence(timeout: 8))
        openOverlapDetail(in: app)
        capture("\(language)-03-together-soon")
        app.terminate()

        app.launchArguments = base + ["-previewTrips", "-seedTripExamples", "-tripTestNamespace=\(UUID().uuidString)"]
        app.launch()
        XCTAssertTrue(app.buttons["tripCard-example-west"].waitForExistence(timeout: 8))
        capture("\(language)-05-shared-trips")
        app.buttons["tripCard-example-west"].tap()
        XCTAssertTrue(app.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 5))
        captureMarketingFlightDetails(app, language: language)
        app.buttons["flightCard-alex-out"].tap()
        captureMarketingFlightMap(app, language: language)
        app.terminate()
    }

    func testCaptureMarketingFlightMaps() {
        continueAfterFailure = false
        for (language, locale) in [("en", "en_US"), ("zh-Hans", "zh_CN")] {
            let app = XCUIApplication()
            app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewTrips", "-seedTripExamples",
                "-tripTestNamespace=\(UUID().uuidString)", "-AppleLanguages", "(\(language))",
                "-AppleLocale", locale, "-AppleInterfaceStyle", "Light"]
            app.launch()
            XCTAssertTrue(app.buttons["tripCard-example-west"].waitForExistence(timeout: 8))
            app.buttons["tripCard-example-west"].tap()
            XCTAssertTrue(app.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 5))
            captureMarketingFlightMap(app, language: language)
            app.terminate()
        }
    }

    func testCaptureMarketingFlightDetails() {
        continueAfterFailure = false
        for (language, locale) in [("en", "en_US"), ("zh-Hans", "zh_CN")] {
            let app = XCUIApplication()
            app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewTrips", "-seedTripExamples",
                "-tripTestNamespace=\(UUID().uuidString)", "-AppleLanguages", "(\(language))",
                "-AppleLocale", locale, "-AppleInterfaceStyle", "Light"]
            app.launch()
            let trip = app.buttons["tripCard-example-west"]
            XCTAssertTrue(trip.waitForExistence(timeout: 8))
            trip.tap()
            XCTAssertTrue(app.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 5))
            captureMarketingFlightDetails(app, language: language)
            app.terminate()
        }
    }

    private func captureMarketingFlightDetails(_ app: XCUIApplication, language: String) {
        let flight = app.buttons["flightCard-alex-out"]
        XCTAssertTrue(flight.waitForExistence(timeout: 5))
        flight.tap()
        XCTAssertEqual(flight.value as? String, "Details expanded")
        XCTAssertTrue(app.staticTexts["British Airways"].waitForExistence(timeout: 3))
        capture("\(language)-07-flight-details")
    }

    private func captureMarketingFlightMap(_ app: XCUIApplication, language: String) {
        let expand = app.buttons["expandTripMapButton"]
        XCTAssertTrue(expand.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if expand.isHittable { break }
            app.scrollViews["fullTripArrivalBoard"].swipeUp()
        }
        expand.tap()
        XCTAssertTrue(app.buttons["closeTripMapButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["mapTraveler-all"].exists)
        // Let MapKit finish loading tiles and the entry route reveal before capture.
        sleep(4)
        capture("\(language)-06-arrivals")
    }

    func testCaptureMarketingOverlapDetails() {
        continueAfterFailure = false
        for (language, locale) in [("en", "en_US"), ("zh-Hans", "zh_CN")] {
            let app = XCUIApplication()
            app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-marketingOverlap", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
            XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
            app.buttons["friendPlansLink"].tap()
            XCTAssertTrue(app.buttons["friendPlan-A7150000-0000-0000-0000-000000000001"].waitForExistence(timeout: 8))
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.buttons["upcomingTogetherToggle"].waitForExistence(timeout: 8))
            openOverlapDetail(in: app)
            capture("\(language)-03-together-soon")
            app.terminate()
        }
    }

    func testCaptureActualMarketingWidgets() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Continue"].exists { springboard.buttons["Continue"].tap() }
        XCUIDevice.shared.press(.home)
        for page in 1...3 {
            capture("actual-widget-page-\(page)")
            if page < 3 { springboard.swipeLeft() }
        }
    }

    func testCaptureRefinedWidgetLayouts() {
        continueAfterFailure = false
        for appearance in ["Light", "Dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewWidgets",
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", appearance]
            if appearance == "Dark" { app.launchArguments.append("-widgetPreviewDark") }
            app.launch()
            XCTAssertTrue(app.segmentedControls["widgetSizePicker"].waitForExistence(timeout: 8))
            for style in ["Friends", "Here together"] {
                app.segmentedControls["widgetStylePicker"].buttons[style].tap()
                for size in ["Small", "Medium", "Large"] {
                    app.segmentedControls["widgetSizePicker"].buttons[size].tap()
                    capture("widget-\(style)-\(size)-\(appearance)")
                }
            }
            app.terminate()
        }
    }

    func testWidgetPrivacyAndEdgeStates() {
        continueAfterFailure = false
        // Privacy is intentionally persistent and may have been changed by another flow.
        // Establish the visible baseline through the same controls users have.
        let setup = waveTwoApp()
        selectAppTab(2, in: setup)
        let settings = setup.buttons["widgetPrivacySettingsLink"]
        for _ in 0..<6 where !settings.isHittable { setup.scrollViews["profileSettingsScreen"].swipeUp() }
        settings.tap()
        XCTAssertTrue(setup.buttons["widgetPrivacyFull"].waitForExistence(timeout: 5))
        setup.buttons["widgetPrivacyFull"].tap()
        setup.terminate()
        let baseline = XCUIApplication()
        baseline.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewWidgets", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        baseline.launch()
        let visibleName = baseline.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Mia Chen")).firstMatch
        XCTAssertTrue(visibleName.waitForExistence(timeout: 8))
        baseline.terminate()
        for state in ["HideNames", "HideAll", "Empty", "LongCity"] {
            let app = XCUIApplication()
            app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewWidgets", "-widget\(state)",
                "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-AppleInterfaceStyle", "Light"]
            app.launch()
            XCTAssertTrue(app.segmentedControls["widgetStylePicker"].waitForExistence(timeout: 8))
            for style in ["Friends", "Here together"] {
                app.segmentedControls["widgetStylePicker"].buttons[style].tap()
                if state == "HideNames" || state == "HideAll" {
                    XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Mia")).firstMatch.exists)
                    XCTAssertFalse(app.staticTexts["MC"].exists)
                }
                if state == "HideAll" { XCTAssertFalse(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "New York")).firstMatch.exists) }
                app.segmentedControls["widgetSizePicker"].buttons["Small"].tap()
                capture("widget-\(style)-\(state)")
            }
            app.terminate()
        }
    }

    func testCaptureRefinedWidgetsChinese() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewWidgets", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.segmentedControls["widgetStylePicker"].waitForExistence(timeout: 8))
        for style in 0..<2 {
            app.segmentedControls["widgetStylePicker"].buttons.element(boundBy: style).tap()
            for size in 0..<3 {
                app.segmentedControls["widgetSizePicker"].buttons.element(boundBy: size).tap()
                capture("widget-zh-\(style)-\(size)")
            }
        }
        app.terminate()
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
        openCitySharingFromProfile(in: app)
        if app.switches["citySharingToggle"].waitForExistence(timeout: 3) {
            sleep(2)
            let shot2 = XCUIScreen.main.screenshot()
            try? shot2.pngRepresentation.write(to: dir.appendingPathComponent("02_city_sharing_privacy.png"))
            let doneButton = app.buttons["Done"]
            if doneButton.waitForExistence(timeout: 2) {
                doneButton.tap()
            }
            selectAppTab(0, in: app)
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
        let profileTab = app.tabBars.buttons.element(boundBy: 2)
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

        // 6. Onboarding Step 1 (Same-city notification)
        let ob1 = XCUIApplication()
        ob1.launchArguments = ["-previewOnboarding", "-previewOnboardingStep=1", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        ob1.launch()
        sleep(2)
        let shot5_1 = XCUIScreen.main.screenshot()
        try? shot5_1.pngRepresentation.write(to: dir.appendingPathComponent("05_onboarding_step1.png"))

        // 7. Onboarding Step 2 (Shared trips)
        let ob2 = XCUIApplication()
        ob2.launchArguments = ["-previewOnboarding", "-previewOnboardingStep=2", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        ob2.launch()
        sleep(2)
        let shot5_2 = XCUIScreen.main.screenshot()
        try? shot5_2.pngRepresentation.write(to: dir.appendingPathComponent("05_onboarding_step2.png"))

        let ob3 = XCUIApplication()
        ob3.launchArguments = ["-previewOnboarding", "-previewOnboardingStep=3", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        ob3.launch()
        sleep(2)
        let shot5_3 = XCUIScreen.main.screenshot()
        try? shot5_3.pngRepresentation.write(to: dir.appendingPathComponent("05_onboarding_step3.png"))

        // 8. 3D Diorama Widget Studio
        let widgetApp = XCUIApplication()
        widgetApp.launchArguments = ["-previewWidgets", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        widgetApp.launch()
        sleep(2)
        let shotWidget = XCUIScreen.main.screenshot()
        try? shotWidget.pngRepresentation.write(to: dir.appendingPathComponent("07_widget_studio.png"))
    }

    func testTripsTabDisplaysCalmTripOverview() {
        continueAfterFailure = false
        let app = tripsApp()
        XCTAssertTrue(app.scrollViews["tripsScreen"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["tripCard-example-west"].exists)
        XCTAssertTrue(app.buttons["tripCard-example-new-york"].exists)
        XCTAssertFalse(app.buttons["tripCard-example-coachella"].exists)
        capture("Multi-trip library")

        app.buttons["tripCard-example-west"].tap()
        XCTAssertTrue(app.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 5))

        app.buttons["addBoardFlightButton"].tap()
        XCTAssertTrue(app.textFields["tripFlightNumberField"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["confirmAddTripFlightButton"].isEnabled)
        capture("Add flight")
        app.buttons["Cancel"].tap()
        discardChangesIfOffered(in: app)

        XCTAssertTrue(app.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["expandTripMapButton"].waitForExistence(timeout: 5))
        capture("Trip board")

        let miaFlight = app.buttons["flightCard-mia-out"]
        XCTAssertTrue(miaFlight.isHittable, "Traveler flights should be visible before the map")
        miaFlight.tap()
        XCTAssertTrue(miaFlight.waitForExistence(timeout: 3))
        XCTAssertEqual(miaFlight.value as? String, "Details expanded")
        let scroll = app.scrollViews["fullTripArrivalBoard"]
        if !miaFlight.isHittable { scroll.swipeUp() }
        capture("Selected flight details")
        miaFlight.tap()
        XCTAssertEqual(miaFlight.value as? String, "Details collapsed")

        for _ in 0..<4 {
            if app.buttons["expandTripMapButton"].isHittable { break }
            scroll.swipeUp()
        }
        app.buttons["expandTripMapButton"].tap()
        XCTAssertTrue(app.buttons["closeTripMapButton"].waitForExistence(timeout: 4))
        let immersive = app.otherElements["immersiveTripMap"]
        immersive.buttons["mapTraveler-mia-out"].tap()
        XCTAssertEqual(immersive.buttons["mapTraveler-mia-out"].value as? String, "Selected")
        capture("Immersive selected route")
        app.buttons["resetTripMapButton"].tap()
        XCTAssertEqual(immersive.buttons["mapTraveler-all"].value as? String, "Selected")
        capture("Immersive all routes")
        app.buttons["closeTripMapButton"].tap()

        for _ in 0..<4 {
            if app.segmentedControls["tripDirectionPicker"].isHittable { break }
            scroll.swipeDown()
        }
        app.segmentedControls["tripDirectionPicker"].buttons["Return"].tap()
        // Return legs leave together from the trip airport, so the board reads in its departure time.
        XCTAssertTrue(app.staticTexts["Departing Los Angeles time"].exists)
        XCTAssertFalse(app.buttons["mapTraveler-mia-out"].exists)
        XCTAssertTrue(app.buttons["flightCard-mia-in"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "4 of 5 flights added")).firstMatch.exists)
        capture("Return routes")
    }

    func testTripUnverifiedFlightEntryAndMissingTravelerUpdate() {
        continueAfterFailure = false
        let app = tripsApp()
        XCTAssertTrue(app.buttons["tripCard-example-west"].waitForExistence(timeout: 8))
        app.buttons["tripCard-example-west"].tap()
        XCTAssertTrue(app.buttons["flightCard-mia-out"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["tripNeedsHelpCard"].exists)
        app.buttons["flightCard-mia-out"].tap()
        XCTAssertFalse(app.buttons["editMyTripFlightButton"].exists)
        XCTAssertFalse(app.buttons["deleteMyTripFlightButton"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tripCard-example-new-york"].tap()
        XCTAssertTrue(app.buttons["tripNeedsHelpCard"].waitForExistence(timeout: 4))
        capture("Missing flight action card")
        app.buttons["tripNeedsHelpCard"].tap()
        let number = app.textFields["tripFlightNumberField"]
        XCTAssertTrue(number.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["tripTravelerPicker"].exists)
        XCTAssertTrue(app.staticTexts["tripFlightOwnershipCaption"].exists)
        // The New York example starts yesterday, so this detects a regression to Date().
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "EEE, MMM d"
        let tripStart = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(app.buttons["tripFlightDatePicker"].label.contains(dateFormatter.string(from: tripStart)))
        capture("Self-service flight form")
        number.tap()
        number.typeText("UA 353")
        app.buttons["confirmAddTripFlightButton"].tap()
        XCTAssertTrue(app.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["tripNeedsHelpCard"].exists)
        capture("Awaiting friend flight compact status")
        app.scrollViews["fullTripArrivalBoard"].swipeUp()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Unverified")).firstMatch.exists)
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "flightCard-")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3))
        card.tap()
        let edit = app.buttons["editMyTripFlightButton"]
        if !edit.isHittable { app.scrollViews["fullTripArrivalBoard"].swipeUp() }
        capture("Own flight actions")
        edit.tap()
        XCTAssertTrue(number.waitForExistence(timeout: 3))
        number.replaceText(with: "DL 12")
        app.buttons["confirmAddTripFlightButton"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "flightCard-", "DL 12")).firstMatch.waitForExistence(timeout: 4))
        let delete = app.buttons["deleteMyTripFlightButton"]
        if !delete.isHittable { app.scrollViews["fullTripArrivalBoard"].swipeUp() }
        delete.tap()
        app.buttons["Delete flight"].tap()
        XCTAssertTrue(app.buttons["tripNeedsHelpCard"].waitForExistence(timeout: 4))
        XCTAssertFalse(card.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["tripCard-example-west"].tap()
        XCTAssertTrue(app.buttons["flightCard-mia-out"].waitForExistence(timeout: 4))
        capture("Other travelers unchanged")
    }

    func testTripVerifiedFlightLookupAndCandidateSelection() {
        continueAfterFailure = false
        let app = tripsApp()
        XCTAssertTrue(app.buttons["tripCard-example-new-york"].waitForExistence(timeout: 8))
        app.buttons["tripCard-example-new-york"].tap()
        XCTAssertTrue(app.buttons["tripNeedsHelpCard"].waitForExistence(timeout: 4))
        app.buttons["tripNeedsHelpCard"].tap()
        let number = app.textFields["tripFlightNumberField"]
        XCTAssertTrue(number.waitForExistence(timeout: 3))
        number.tap()
        number.typeText("UA 353")

        let searchButton = app.buttons["lookupFlightButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3))
        searchButton.tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Example Routes")).firstMatch.waitForExistence(timeout: 4))
        capture("Flight candidate lookup results")

        app.buttons["confirmAddTripFlightButton"].tap()
        XCTAssertTrue(app.scrollViews["fullTripArrivalBoard"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["tripNeedsHelpCard"].exists)
        XCTAssertTrue(app.staticTexts["Local arrival times"].exists)
        capture("Trip board with verified flight")
    }

    func testTripDemoUnknownFlightDoesNotInventProviderResults() {
        continueAfterFailure = false
        let app = tripsApp()
        XCTAssertTrue(app.buttons["tripCard-example-new-york"].waitForExistence(timeout: 8))
        app.buttons["tripCard-example-new-york"].tap()
        XCTAssertTrue(app.buttons["tripNeedsHelpCard"].waitForExistence(timeout: 4))
        app.buttons["tripNeedsHelpCard"].tap()
        let number = app.textFields["tripFlightNumberField"]
        XCTAssertTrue(number.waitForExistence(timeout: 3))
        number.tap()
        number.typeText("CZ 328")

        let searchButton = app.buttons["lookupFlightButton"]
        XCTAssertTrue(searchButton.waitForExistence(timeout: 3))
        searchButton.tap()

        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "No flight routes found")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "China Southern")).firstMatch.exists)
        capture("Demo lookup unavailable without invented routes")
    }

    func testTripsNightAppearance() {
        continueAfterFailure = false
        let app = tripsApp()
        XCTAssertTrue(app.scrollViews["tripsScreen"].waitForExistence(timeout: 8))
        selectAppTab(2, in: app)
        let appearance = app.buttons["appearanceSettingsButton"]
        if !appearance.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        appearance.tap()
        app.buttons["nightJadeAppearance"].tap()
        app.buttons["appearanceDoneButton"].tap()
        selectAppTab(1, in: app)
        app.buttons["tripCard-example-west"].tap()
        XCTAssertTrue(app.buttons["expandTripMapButton"].waitForExistence(timeout: 5))
        capture("Night Jade routes")
        app.buttons["expandTripMapButton"].tap()
        XCTAssertTrue(app.buttons["closeTripMapButton"].waitForExistence(timeout: 4))
        capture("Night Jade immersive map")
        app.buttons["closeTripMapButton"].tap()
        selectAppTab(2, in: app)
        if !appearance.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        appearance.tap()
        app.buttons["solarJadeAppearance"].tap()
        app.buttons["appearanceDoneButton"].tap()
    }

    func testTripCreationPersistencePeopleAndCompletion() {
        continueAfterFailure = false
        let app = tripsApp(seedExamples: false)
        XCTAssertTrue(app.buttons["createFirstTripButton"].waitForExistence(timeout: 8))
        capture("First trip empty state")
        createTrip(in: app, name: "Kyoto with friends", destination: "Tokyo (NRT)")
        createTrip(in: app, name: "New York weekend", destination: "New York (JFK)")
        XCTAssertTrue(app.staticTexts["Upcoming"].exists)
        capture("Two upcoming trips")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["Kyoto with friends"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["New York weekend"].exists)
        app.staticTexts["Kyoto with friends"].tap()
        XCTAssertTrue(app.staticTexts["Tokyo · NRT"].waitForExistence(timeout: 4))
        app.buttons["tripPeopleButton"].tap()
        XCTAssertTrue(app.staticTexts["In this trip"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["tripGuestNameField"].exists)
        XCTAssertFalse(app.buttons["addTripGuestButton"].exists)
        capture("Account-only members")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["tripPeopleButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tripPeopleButton"].label.contains("1 person"))
        capture("New trip with signed-in creator")
        app.buttons["tripOptionsButton"].tap()
        app.buttons["Mark complete"].tap()
        app.buttons["Mark complete"].tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Trip complete")).firstMatch.waitForExistence(timeout: 3))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["pastTripsToggle"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Kyoto with friends"].exists)
        app.buttons["pastTripsToggle"].tap()
        XCTAssertTrue(app.staticTexts["Kyoto with friends"].exists)
        capture("Completed trip in Past")
        app.staticTexts["Kyoto with friends"].tap()
        app.buttons["tripOptionsButton"].tap()
        app.buttons["Undo completion"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertFalse(app.buttons["pastTripsToggle"].exists)
        XCTAssertTrue(app.staticTexts["Kyoto with friends"].exists)
    }

    func testTripEditPreservesOtherTrips() {
        continueAfterFailure = false
        let app = tripsApp()
        XCTAssertTrue(app.buttons["tripCard-example-new-york"].waitForExistence(timeout: 8))
        app.buttons["tripCard-example-new-york"].tap()
        app.buttons["tripOptionsButton"].tap()
        app.buttons["Edit trip"].tap()
        let name = app.textFields["tripNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, "New York catch-up")
        name.replaceText(with: "New York reunion")
        app.buttons["saveTripButton"].tap()
        XCTAssertTrue(app.staticTexts["New York reunion"].waitForExistence(timeout: 4))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["New York reunion"].exists)
        XCTAssertTrue(app.staticTexts["West Coast weekend"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["New York reunion"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["New York catch-up"].exists)
        XCTAssertTrue(app.buttons["tripCard-example-west"].exists)
    }

    private func createTrip(in app: XCUIApplication, name: String, destination: String) {
        app.buttons["newTripButton"].tap()
        let field = app.textFields["tripNameField"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["saveTripButton"].isEnabled)
        capture("Compact new trip form")
        field.tap()
        field.typeText(name + "\n")
        for _ in 0..<4 where !app.buttons["tripDestinationPicker"].isHittable { app.scrollViews.firstMatch.swipeDown() }
        app.buttons["tripDestinationPicker"].tap()
        capture("Destination search sheet")
        app.buttons[destination].tap()
        capture("New trip form")
        for _ in 0..<4 where !app.buttons["saveTripButton"].isHittable { app.scrollViews.firstMatch.swipeUp() }
        app.buttons["saveTripButton"].tap()
        XCTAssertTrue(app.scrollViews["tripsScreen"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts[name].exists)
    }

    func testTripFlightCardDetailsExpansion() {
        continueAfterFailure = false
        let app = tripsApp()
        XCTAssertTrue(app.buttons["tripCard-example-west"].waitForExistence(timeout: 8))
        app.buttons["tripCard-example-west"].tap()
        XCTAssertTrue(app.staticTexts["Arrivals"].waitForExistence(timeout: 4))
        let flightCard = app.buttons["flightCard-wang-out"]
        XCTAssertTrue(flightCard.waitForExistence(timeout: 4))
        flightCard.tap()
        let edit = app.buttons["editMyTripFlightButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 4))
        capture("Trip flight details expanded")
        flightCard.tap()
        XCTAssertFalse(edit.exists)
    }

    func testCityEmblemFallbackSideBySideVisual() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += [
            "-skipOnboarding",
            "-resetDemoData",
            "-previewCityFallbackCompare",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()

        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["homeCityStatus"].label.contains("Bakersfield, CA"))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Fremont, CA")).firstMatch.waitForExistence(timeout: 3))
        // A previous test may have left Night Jade selected. Make both captures deterministic.
        selectAppTab(2, in: app)
        let initialAppearance = app.buttons["appearanceSettingsButton"]
        if !initialAppearance.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        XCTAssertTrue(initialAppearance.waitForExistence(timeout: 3)); initialAppearance.tap()
        app.buttons["solarJadeAppearance"].tap()
        app.buttons["appearanceDoneButton"].tap()
        selectAppTab(0, in: app)
        capture("City fallback visual side-by-side comparison")
        selectAppTab(2, in: app)
        let appearance = app.buttons["appearanceSettingsButton"]
        if !appearance.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        XCTAssertTrue(appearance.waitForExistence(timeout: 3)); appearance.tap()
        app.buttons["nightJadeAppearance"].tap()
        app.buttons["appearanceDoneButton"].tap()
        selectAppTab(0, in: app)
        capture("City fallback comparison Night Jade")
    }

    func testCityArtworkHandlesPausedAndUnavailableLocations() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewCityFallbackStates", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["homeCityStatus"].label.contains("Your city isn’t set yet"))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Sharing paused")).firstMatch.waitForExistence(timeout: 3))
        capture("City artwork paused and unavailable")
    }

    private func historyApp(extra: String, language: String, locale: String, additional: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", extra, "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + additional
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
        app.scrollViews["friendsScreen"].swipeDown()
        selectAppTab(2, in: app)
        let moments = app.buttons["sameCityMomentsLink"]
        XCTAssertTrue(moments.waitForExistence(timeout: 5)); moments.tap()
        XCTAssertTrue(app.scrollViews["notificationHistoryScreen"].waitForExistence(timeout: 5))
        return app
    }

    private func selectAppearance(_ identifier: String, in app: XCUIApplication) {
        selectAppTab(2, in: app)
        let appearance = app.buttons["appearanceSettingsButton"]
        for _ in 0..<5 where !appearance.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        appearance.tap()
        XCTAssertTrue(app.buttons[identifier].waitForExistence(timeout: 4))
        app.buttons[identifier].tap()
        app.buttons["appearanceDoneButton"].tap()
        selectAppTab(0, in: app)
    }

    private func selectAppTab(_ index: Int, in app: XCUIApplication) {
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        if bar.buttons.count < 3 { bar.buttons.firstMatch.tap() }
        let tab = bar.buttons.element(boundBy: index)
        XCTAssertTrue(tab.waitForExistence(timeout: 4))
        tab.tap()
    }

    private func openCitySharingFromProfile(in app: XCUIApplication) {
        selectAppTab(2, in: app)
        let sharing = app.buttons["profileCitySharingButton"]
        // Wait for the You tab before scrolling it; querying a missing view fails on iOS 26.
        XCTAssertTrue(sharing.waitForExistence(timeout: 4))
        for _ in 0..<5 where !sharing.isHittable { app.scrollViews["profileSettingsScreen"].swipeDown() }
        sharing.tap()
        XCTAssertTrue(app.switches["citySharingToggle"].waitForExistence(timeout: 4))
    }

    private func expectFriendSharingDescription(_ expected: String, in app: XCUIApplication) {
        let toggle = app.switches["friendCitySharingToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        for _ in 0..<5 where !toggle.isHittable { app.scrollViews.firstMatch.swipeUp() }
        let updated = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", expected), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 5), .completed)
    }

    private func checkFriendSharingDescriptions(language: String, locale: String, active: String, off: String, paused: String) {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
        let mia = app.buttons["friendCard-10000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(mia.waitForExistence(timeout: 8)); mia.tap()
        let individual = app.switches["friendCitySharingToggle"]
        expectFriendSharingDescription(active, in: app)
        capture("F03-sharing-active-\(language)")
        individual.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        expectFriendSharingDescription(off, in: app)
        XCTAssertEqual(individual.value as? String, "0")
        capture("F03-friend-sharing-off-\(language)")
        individual.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        expectFriendSharingDescription(active, in: app)
        app.navigationBars.buttons.firstMatch.tap()

        openCitySharingFromProfile(in: app)
        let global = app.switches["citySharingToggle"]
        global.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let globalOff = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: global)
        XCTAssertEqual(XCTWaiter.wait(for: [globalOff], timeout: 5), .completed)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        selectAppTab(0, in: app)
        XCTAssertTrue(app.staticTexts["homeSharingPaused"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["sameCitySummaryTitle"].exists)
        XCTAssertFalse(app.buttons["homeCityRecoveryButton"].exists)
        capture("F01-home-sharing-paused-\(language)")
        mia.tap()
        expectFriendSharingDescription(paused, in: app)
        XCTAssertEqual(individual.value as? String, "1")
        capture("F03-global-sharing-paused-\(language)")
        individual.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        expectFriendSharingDescription(off, in: app)
        capture("F03-both-sharing-off-\(language)")
        app.navigationBars.buttons.firstMatch.tap()

        openCitySharingFromProfile(in: app)
        global.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let globalOn = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: global)
        XCTAssertEqual(XCTWaiter.wait(for: [globalOn], timeout: 5), .completed)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        selectAppTab(0, in: app)
        XCTAssertFalse(app.staticTexts["homeSharingPaused"].exists)
        mia.tap()
        expectFriendSharingDescription(off, in: app)
        XCTAssertEqual(individual.value as? String, "0")
        individual.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        expectFriendSharingDescription(active, in: app)
    }

    private func tripsApp(seedExamples: Bool = true, asMember: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-skipOnboarding", "-resetDemoData", "-previewTrips",
                                "-tripTestNamespace=\(UUID().uuidString)",
                                "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if seedExamples { app.launchArguments.append("-seedTripExamples") }
        if asMember { app.launchArguments.append("-previewTripMember") }
        app.launch()
        return app
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 1.2)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    func replaceText(with text: String) {
        tap()
        // A wider field can place the caret mid-text when its center is tapped.
        // Position it at the trailing edge before deleting the existing value.
        coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        if let currentValue = value as? String, !currentValue.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        typeText(text)
    }
}
