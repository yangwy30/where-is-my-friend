// Audit-only XCTest extension, appended temporarily to PrototypeUITests.swift
// for a dedicated build. Evidence observations are not assertions that UX is good.
extension PrototypeUITests {
    private func reviewApp(chinese: Bool = false, extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-seedTripExamples",
            "-tripTestNamespace=review-\(UUID().uuidString)", "-AppleLanguages", chinese ? "(zh-Hans)" : "(en)",
            "-AppleLocale", chinese ? "zh_CN" : "en_US"] + extra
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 10))
        return app
    }

    private func reviewEvidence(_ name: String, app: XCUIApplication, facts: String = "") {
        capture("REVIEW-\(name)")
        let attachment = XCTAttachment(string: facts + "\n\n" + app.debugDescription)
        attachment.name = "REVIEW-\(name)-tree"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reviewScrollTo(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<7 where !element.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func reviewTab(_ index: Int, app: XCUIApplication) {
        let bar = app.tabBars.firstMatch
        if bar.buttons.count < 3 { bar.buttons.firstMatch.tap() }
        XCTAssertTrue(bar.buttons.element(boundBy: index).waitForExistence(timeout: 4))
        bar.buttons.element(boundBy: index).tap()
    }

    private func reviewTheme(_ dark: Bool, app: XCUIApplication) {
        reviewTab(2, app: app)
        let appearance = app.buttons["appearanceSettingsButton"]
        reviewScrollTo(appearance, in: app)
        appearance.tap()
        XCTAssertTrue(app.buttons["nightJadeAppearance"].waitForExistence(timeout: 4))
        app.buttons[dark ? "nightJadeAppearance" : "solarJadeAppearance"].tap()
        app.buttons["appearanceDoneButton"].tap()
        reviewTab(0, app: app)
    }

    func testReviewSharingAndFriendStates() {
        let app = reviewApp()
        reviewTheme(false, app: app)
        reviewEvidence("01-home", app: app)
        app.buttons["myCitySharingCard"].tap()
        XCTAssertTrue(app.switches["citySharingToggle"].waitForExistence(timeout: 4))
        reviewEvidence("02-city-sharing-destination", app: app)
        let toggle = app.switches["citySharingToggle"]
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        reviewEvidence("03-global-sharing-paused", app: app)
        app.buttons["Done"].tap()
        let mia = app.buttons["friendCard-10000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(mia.waitForExistence(timeout: 4)); reviewScrollTo(mia, in: app); mia.tap()
        let sharing = app.switches.matching(NSPredicate(format: "label CONTAINS %@", "Share my city")).firstMatch
        XCTAssertTrue(sharing.waitForExistence(timeout: 4)); reviewScrollTo(sharing, in: app)
        reviewEvidence("04-friend-global-paused", app: app, facts: "Friend sharing switch: \(sharing.value ?? "nil")")
        sharing.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        reviewEvidence("05-friend-sharing-off", app: app, facts: "Friend sharing switch: \(sharing.value ?? "nil")")
        app.buttons["removeFriendButton"].tap()
        reviewEvidence("06-remove-confirmation", app: app)
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18)).tap() }
        reviewScrollTo(app.buttons["blockFriendButton"], in: app)
        app.buttons["blockFriendButton"].tap()
        reviewEvidence("07-block-confirmation", app: app)
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18)).tap() }
        XCTAssertTrue(app.buttons["blockFriendButton"].exists)
    }

    func testReviewProfileAndPrivacyPages() {
        let app = reviewApp()
        reviewTab(2, app: app)
        reviewEvidence("08-profile", app: app)
        for (identifier, name) in [("notificationSettingsLink", "09-notifications"),
                                    ("widgetPrivacySettingsLink", "10-widget-privacy"),
                                    ("sameCityMomentsLink", "11-same-city-history")] {
            let link = app.buttons[identifier]
            // Return to the top before looking for a different profile section.
            for _ in 0..<4 { app.scrollViews.firstMatch.swipeDown() }
            reviewScrollTo(link, in: app); link.tap()
            reviewEvidence(name, app: app)
            app.navigationBars.buttons.firstMatch.tap()
        }
        for (label, name) in [("Privacy & data", "12-privacy-data"), ("Blocked people", "13-blocked-empty")] {
            for _ in 0..<4 { app.scrollViews.firstMatch.swipeDown() }
            let link = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            reviewScrollTo(link, in: app); link.tap()
            reviewEvidence(name, app: app)
            app.navigationBars.buttons.firstMatch.tap()
        }
        reviewTheme(true, app: app)
        reviewEvidence("14-home-dark", app: app)
        app.buttons["myCitySharingCard"].tap()
        reviewEvidence("15-sharing-dark", app: app)
        app.buttons["Done"].tap()
        reviewTheme(false, app: app)
    }

    func testReviewPlanDraftAndSharingModes() {
        let app = reviewApp()
        app.buttons["friendPlansLink"].tap()
        XCTAssertTrue(app.buttons["addMyFriendPlan"].waitForExistence(timeout: 5))
        reviewEvidence("16-plan-feed", app: app)
        // Use the visible friend's plan as a draft; city search has its own tests.
        let copy = app.buttons["copyFriendPlan-A7150000-0000-0000-0000-000000000001"]
        reviewScrollTo(copy, in: app); copy.tap()
        XCTAssertTrue(app.buttons["travelPlanCity"].waitForExistence(timeout: 4))
        app.buttons["travelPlanAudience"].tap()
        let audience = app.switches["travelAudience-lin"]
        XCTAssertTrue(audience.waitForExistence(timeout: 4)); audience.switches.firstMatch.tap()
        app.buttons["travelAudienceDone"].tap()
        let browse = app.switches["travelPlanBrowsing"]
        reviewScrollTo(browse, in: app); browse.switches.firstMatch.tap()
        reviewEvidence("17-plan-match-only", app: app)
        app.buttons["Cancel"].firstMatch.tap()
        let discardedWithoutConfirmation = app.buttons["addMyFriendPlan"].waitForExistence(timeout: 3)
        if !discardedWithoutConfirmation { reviewEvidence("18-plan-discard-dialog", app: app); return }
        app.buttons["addMyFriendPlan"].tap()
        XCTAssertTrue(app.buttons["travelPlanCity"].waitForExistence(timeout: 3))
        reviewEvidence("18-plan-after-cancel", app: app,
                       facts: "Dismissed without confirmation: \(discardedWithoutConfirmation). Reopened city: \(app.buttons["travelPlanCity"].label)")
    }

    func testReviewTripDraftLoss() {
        let app = reviewApp()
        reviewTab(1, app: app)
        XCTAssertTrue(app.buttons["newTripButton"].waitForExistence(timeout: 5)); app.buttons["newTripButton"].tap()
        app.buttons["tripDestinationPicker"].tap()
        app.buttons["Tokyo (NRT)"].tap()
        let field = app.textFields["tripNameField"]
        field.replaceText(with: "Audit unsaved trip")
        reviewEvidence("19-trip-draft-filled", app: app)
        app.buttons["Cancel"].tap()
        let immediateDismiss = app.buttons["newTripButton"].waitForExistence(timeout: 3)
        if !immediateDismiss { reviewEvidence("20-trip-discard-dialog", app: app); return }
        app.buttons["newTripButton"].tap()
        reviewEvidence("20-trip-after-cancel", app: app,
                       facts: "Dismissed without confirmation: \(immediateDismiss). Reopened name: \(field.value ?? "nil")")
    }

    func testReviewChineseFlightFailureAndTouchFrames() {
        let app = reviewApp(chinese: true)
        reviewTab(1, app: app)
        let trip = app.buttons["tripCard-example-new-york"]
        XCTAssertTrue(trip.waitForExistence(timeout: 6)); trip.tap()
        XCTAssertTrue(app.buttons["tripNeedsHelpCard"].waitForExistence(timeout: 5)); app.buttons["tripNeedsHelpCard"].tap()
        let number = app.textFields["tripFlightNumberField"]
        XCTAssertTrue(number.waitForExistence(timeout: 4)); number.tap(); number.typeText("CZ 328")
        let search = app.buttons["lookupFlightButton"]
        reviewEvidence("21-flight-keyboard-small", app: app, facts: "Search frame: \(search.frame). Input frame: \(number.frame)")
        search.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "No flight routes found")).firstMatch.waitForExistence(timeout: 8))
        reviewEvidence("22-flight-no-result-chinese", app: app, facts: "Search frame: \(search.frame)")
        app.buttons["tripFlightDatePicker"].tap()
        reviewEvidence("23-flight-calendar", app: app)
    }

    func testReviewDarkLocationSetup() {
        let app = reviewApp()
        reviewTheme(true, app: app)
        app.terminate()
        app.resetAuthorizationStatus(for: .location)
        app.launchArguments += ["-testLocationSetup"]
        app.launch()
        XCTAssertTrue(app.buttons["enableInitialLocation"].waitForExistence(timeout: 8))
        reviewEvidence("24-location-setup-dark", app: app)
        app.buttons["skipInitialLocation"].tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        reviewTheme(false, app: app)
    }

    func testReviewProfileDraftAndSignedOut() {
        let app = reviewApp()
        reviewTab(2, app: app)
        app.buttons["editProfileButton"].tap()
        let name = app.textFields["displayNameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 4)); name.replaceText(with: "Unsaved review name")
        reviewEvidence("25-profile-draft", app: app)
        app.navigationBars.buttons["Close"].tap()
        let immediateDismiss = app.buttons["editProfileButton"].waitForExistence(timeout: 3)
        if !immediateDismiss { reviewEvidence("26-profile-discard-dialog", app: app); return }
        app.buttons["editProfileButton"].tap()
        reviewEvidence("26-profile-after-close", app: app, facts: "Reopened name: \(name.value ?? "nil")")
        app.navigationBars.buttons["Close"].tap()
        let signOut = app.buttons["Sign out"]
        reviewScrollTo(signOut, in: app); signOut.tap()
        reviewEvidence("27-signout-confirmation", app: app)
        app.buttons["Sign out"].firstMatch.tap()
        XCTAssertTrue(app.buttons["demoSignInButton"].waitForExistence(timeout: 6))
        reviewEvidence("28-authentication", app: app)
        app.buttons["demoSignInButton"].tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
    }

    func testReviewEmptyFriendsAndOfflineState() {
        let app = reviewApp(extra: ["-reviewEmptyFriends"])
        XCTAssertTrue(app.staticTexts["No friends yet"].waitForExistence(timeout: 6))
        reviewEvidence("30-empty-friends", app: app)
        app.buttons["addFriendButton"].tap()
        reviewEvidence("31-first-friend-invitation", app: app)
        app.terminate()
        let offline = reviewApp(extra: ["-reviewOfflineState"])
        offline.scrollViews["friendsScreen"].swipeDown()
        reviewEvidence("32-offline-state", app: offline, facts: "Fixture: syncState=offline, lastSyncedAt=one hour ago. This is UI state injection, not a live network outage.")
    }

    func testReviewFriendRequestActualDeepLink() {
        let app = reviewApp(extra: ["-reviewFriendRequest"])
        // Wait for the injected repository state to replace the initial placeholder snapshot.
        app.scrollViews["friendsScreen"].swipeDown()
        app.open(URL(string: "whereismyfriend://friend-requests/00000000-1111-4222-8333-444444444444")!)
        let accept = app.buttons["acceptNotificationFriendRequest"]
        XCTAssertTrue(accept.waitForExistence(timeout: 10))
        reviewEvidence("37-request-deep-link", app: app)
        app.terminate()
        app.launchArguments.removeAll { $0 == "-resetDemoData" }
        app.launch()
        XCTAssertTrue(accept.waitForExistence(timeout: 10))
        reviewEvidence("38-request-cold-restore", app: app)
        accept.tap()
        XCTAssertTrue(accept.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
    }

    func testReviewWidgetStatesAfterPrivacyReset() {
        let app = reviewApp()
        reviewTab(2, app: app)
        let settings = app.buttons["widgetPrivacySettingsLink"]
        reviewScrollTo(settings, in: app); settings.tap()
        XCTAssertTrue(app.buttons["widgetPrivacyFull"].waitForExistence(timeout: 5))
        app.buttons["widgetPrivacyFull"].tap()
        XCTAssertEqual(app.buttons["widgetPrivacyFull"].value as? String, "1")
        app.terminate()
        // Existing test expects full visibility, but a preceding profile test sets hideAll.
        testWidgetPrivacyAndEdgeStates()
    }

    func testReviewRepeatedStayDuration() {
        let app = reviewApp(extra: ["-reviewRepeatStay"])
        reviewTab(2, app: app)
        let moments = app.buttons["sameCityMomentsLink"]
        reviewScrollTo(moments, in: app); moments.tap()
        XCTAssertTrue(app.scrollViews["notificationHistoryScreen"].waitForExistence(timeout: 5))
        reviewEvidence("33-repeat-stay-duration", app: app,
            facts: "Fixture: current active stay began 1 hour ago. Separate historical event occurred 7 days ago. Expected current duration: about 1 hour.")
    }

    func testReviewLongNamesAtLargestText() {
        let app = reviewApp(extra: ["-reviewLongNames", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let friend = app.buttons["friendCard-10000000-0000-0000-0000-000000000001"]
        reviewScrollTo(friend, in: app)
        reviewEvidence("34-long-name-largest-text", app: app)
        friend.tap()
        reviewEvidence("35-friend-detail-largest-text", app: app)
    }

    func testReviewOnboardingLargestChineseText() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-previewOnboarding", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        for page in 0..<4 {
            let next = app.buttons["onboardingContinueButton"]
            XCTAssertTrue(next.waitForExistence(timeout: 5)); XCTAssertTrue(next.isHittable)
            app.scrollViews["onboardingContent"].swipeUp()
            reviewEvidence("36-onboarding-AX-\(page)", app: app)
            if page < 3 { next.tap() }
        }
    }

    func testReviewAccessibilityDiagnostics() throws {
        let app = reviewApp()
        for (screen, action) in [("home", 0), ("friend-plans", 1), ("trips", 2)] {
            if action == 1 { app.buttons["friendPlansLink"].tap() }
            if action == 2 { reviewTab(1, app: app) }
            var issues: [String] = []
            try app.performAccessibilityAudit(for: .all) { issue in
                issues.append("Type \(issue.auditType.rawValue): \(issue.compactDescription)\n\(issue.detailedDescription)\nElement: \(issue.element?.debugDescription ?? "none")")
                // Collect diagnostics for human review; this is not an a11y pass assertion.
                return true
            }
            let attachment = XCTAttachment(string: issues.isEmpty ? "No issues returned on this visible screen." : issues.joined(separator: "\n\n"))
            attachment.name = "REVIEW-a11y-\(screen)"; attachment.lifetime = .keepAlways; add(attachment)
            reviewEvidence("29-a11y-\(screen)", app: app)
        }
    }
}
