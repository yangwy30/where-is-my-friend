import XCTest

final class PrototypeUITests: XCTestCase {
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
        XCTAssertEqual(summary.label, committed)
    }

    func testManualCitySelectionDoesNotRequireLocationPermission() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["myCitySharingCard"].waitForExistence(timeout: 8)); app.buttons["myCitySharingCard"].tap()
        let manual = app.buttons["manualCityButton"]
        for _ in 0..<3 where !manual.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(manual.waitForExistence(timeout: 3)); manual.tap()
        XCTAssertTrue(app.buttons["travelCity-Tokyo"].waitForExistence(timeout: 3)); app.buttons["travelCity-Tokyo"].tap()
        XCTAssertTrue(app.buttons["refreshLocationButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["refreshLocationButton"].label.contains("Use device location"))
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
        XCTAssertTrue(app.navigationBars["New plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["travelPlanCity"].label.contains("Tokyo"))
        XCTAssertTrue(app.staticTexts["Only me · choose friends"].exists)
        let browse = app.switches["travelPlanBrowsing"]
        XCTAssertEqual(browse.value as? String, "0")
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
        XCTAssertEqual(app.switches["travelPlanBrowsing"].value as? String, "0")
    }

    func testFriendPlansChineseSharingConsentPersists() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["friendPlansLink"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["friendPlansLink"].label.contains("好友计划"))
        app.buttons["friendPlansLink"].tap()
        XCTAssertTrue(app.staticTexts["朋友接下来去哪"].waitForExistence(timeout: 5))
        capture("friend-plans-chinese")
        let copy = app.buttons["copyFriendPlan-A7150000-0000-0000-0000-000000000001"]
        XCTAssertTrue(copy.waitForExistence(timeout: 3)); copy.tap()
        app.buttons["travelPlanAudience"].tap()
        let audience = app.switches["travelAudience-lin"]
        XCTAssertTrue(audience.waitForExistence(timeout: 3)); audience.switches.firstMatch.tap()
        app.buttons["travelAudienceDone"].tap()
        let browse = app.switches["travelPlanBrowsing"]
        for _ in 0..<4 where !browse.isHittable { app.scrollViews.firstMatch.swipeUp() }
        browse.switches.firstMatch.tap()
        XCTAssertEqual(browse.value as? String, "1")
        let save = app.buttons["saveTravelPlan"]
        for _ in 0..<4 where !save.isHittable { app.scrollViews.firstMatch.swipeUp() }
        capture("friend-plan-explicit-sharing-chinese")
        save.tap()
        XCTAssertTrue(app.scrollViews["friendPlansScreen"].waitForExistence(timeout: 5))
        app.buttons["manageOwnTravelPlans"].tap()
        let own = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "travelPlan-")).firstMatch
        XCTAssertTrue(own.waitForExistence(timeout: 5)); own.tap()
        XCTAssertEqual(app.switches["travelPlanBrowsing"].value as? String, "1")
    }

    func testFriendRequestNotificationRestoresAndCanBeAccepted() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewFriendRequestNotification", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["acceptNotificationFriendRequest"].waitForExistence(timeout: 8))
        capture("friend-request-notification")
        app.terminate()
        app.launchArguments.removeAll { $0 == "-previewFriendRequestNotification" || $0 == "-resetDemoData" }
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
        app.tabBars.buttons.element(boundBy: 2).tap()
        let button = app.buttons["Delete account"]
        for _ in 0..<12 where !button.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
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
        app.buttons["myCitySharingCard"].tap()
        let region = app.staticTexts["currentCityRegion"]
        XCTAssertTrue(region.waitForExistence(timeout: 5))
        XCTAssertEqual(region.label, "Part of Silicon Valley")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Milpitas")).firstMatch.exists)
        capture("city-region-milpitas-details")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["sameCityReunionToggle"].waitForNonExistence(timeout: 5))
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
        app.terminate()
        app.launchArguments.removeAll { $0 == "-testLocationSetup" }
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        app.resetAuthorizationStatus(for: .location)
    }

    func testNoMatchCardsDisappearWhenCitySharingStops() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        XCTAssertTrue(app.buttons["sameCityReunionToggle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["upcomingTogetherToggle"].exists)
        app.buttons["myCitySharingCard"].tap()
        let sharing = app.switches["citySharingToggle"]
        XCTAssertTrue(sharing.waitForExistence(timeout: 3))
        sharing.switches.firstMatch.tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["sameCityReunionToggle"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["upcomingTogetherToggle"].exists)
        capture("friends-without-matches")
    }

    func testTravelCitySearchFindsPalmSpringsFromProfile() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 2).tap()
        let plans = app.buttons["travelPlansLink"]
        for _ in 0..<4 where !plans.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        XCTAssertTrue(plans.isHittable); plans.tap()
        XCTAssertTrue(app.buttons["addTravelPlan"].waitForExistence(timeout: 3)); app.buttons["addTravelPlan"].tap()
        XCTAssertTrue(app.navigationBars["New plan"].waitForExistence(timeout: 3))
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
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        let entry = app.buttons["upcomingTogetherToggle"]
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 5))
        XCTAssertFalse(entry.exists)
        app.tabBars.buttons.element(boundBy: 2).tap()
        let plans = app.buttons["travelPlansLink"]
        for _ in 0..<4 where !plans.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        XCTAssertTrue(plans.isHittable); plans.tap()
        XCTAssertTrue(app.buttons["addTravelPlan"].waitForExistence(timeout: 3)); app.buttons["addTravelPlan"].tap()
        XCTAssertTrue(app.navigationBars["New plan"].waitForExistence(timeout: 3))
        app.buttons["travelPlanCity"].tap()
        XCTAssertTrue(app.buttons["travelCity-Tokyo"].waitForExistence(timeout: 3)); app.buttons["travelCity-Tokyo"].tap()
        capture("travel-plan-private-editor")
        app.buttons["travelPlanAudience"].tap()
        let audience = app.switches["travelAudience-lin"]
        XCTAssertTrue(audience.waitForExistence(timeout: 3)); audience.switches.firstMatch.tap()
        XCTAssertEqual(audience.value as? String, "1")
        app.buttons["travelAudienceDone"].tap()
        let save = app.buttons["saveTravelPlan"]
        if !save.isHittable { app.scrollViews.firstMatch.swipeUp() }
        save.tap()
        XCTAssertTrue(app.navigationBars["Travel plans"].waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5)); entry.tap()
        let overlap = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "upcomingOverlap-")).firstMatch
        XCTAssertTrue(overlap.waitForExistence(timeout: 5)); overlap.tap()
        XCTAssertTrue(app.buttons["upcomingSayHello"].waitForExistence(timeout: 3))
        capture("upcoming-together-expanded")
        let manage = app.buttons["Manage my plans"]
        if !manage.isHittable { app.scrollViews["friendsScreen"].swipeUp() }; manage.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "travelPlan-")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3)); row.tap()
        app.buttons["travelPlanAudience"].tap()
        audience.switches.firstMatch.tap()
        XCTAssertEqual(audience.value as? String, "0")
        app.buttons["travelAudienceDone"].tap()
        if !save.isHittable { app.scrollViews.firstMatch.swipeUp() }; save.tap()
        XCTAssertTrue(app.navigationBars["Travel plans"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertFalse(app.buttons["upcomingSayHello"].exists)
        XCTAssertTrue(app.staticTexts["This overlap is no longer available. Plans or sharing may have changed."].exists)
        let close = app.buttons["closeUpcomingTogether"]
        if !close.isHittable { app.scrollViews["friendsScreen"].swipeUp() }
        close.tap()
        XCTAssertFalse(entry.exists)
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
        XCTAssertFalse(app.buttons["upcomingSayHello"].exists)
        app.buttons["closeUpcomingTogether"].tap()
        XCTAssertFalse(app.buttons["upcomingTogetherToggle"].exists)
    }

    func testSameCityCardExpandsAndSharesWithoutSendingAutomatically() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        let toggle = app.buttons["sameCityReunionToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(app.staticTexts["Same city. Good company."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["sameCitySayHello"].exists)
        capture("same-city-expanded")
        let close = app.buttons["closeSameCityReunion"]
        if !close.isHittable { app.scrollViews["friendsScreen"].swipeUp() }
        close.tap()
        XCTAssertFalse(app.buttons["sameCitySayHello"].exists)
    }

    func testUnavailableSameCityLinkOpensSafelyFromAnotherTabAndAfterRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        if app.buttons["Not now"].waitForExistence(timeout: 1) { app.buttons["Not now"].tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        app.tabBars.buttons.element(boundBy: 2).tap()
        let url = URL(string: "whereismyfriend://events/11111111-2222-4333-8444-555555555555")!
        app.open(url)
        XCTAssertTrue(app.staticTexts["This update is no longer available"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sameCitySayHello"].exists)
        app.buttons["closeSameCityReunion"].tap()
        app.terminate()
        app.open(url)
        XCTAssertTrue(app.staticTexts["This update is no longer available"].waitForExistence(timeout: 8))
        capture("same-city-unavailable-link")
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
        XCTAssertTrue(app.staticTexts["onboardingTitle"].label.contains("Your privacy"))
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
        app.tabBars.buttons.element(boundBy: 2).tap()
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
        XCTAssertTrue(title.label.contains("Your privacy"))
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
        app.tabBars.buttons.element(boundBy: 2).tap()
        XCTAssertTrue(app.buttons["editProfileButton"].waitForExistence(timeout: 3))
        app.buttons["editProfileButton"].tap()

        let nameField = app.textFields["displayNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.replaceText(with: "New Name")
        app.textFields["profileUsernameField"].replaceText(with: "new_username")
        app.buttons["saveProfileButton"].tap()
        XCTAssertTrue(app.staticTexts["New Name"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["@new_username"].exists)

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
        app.tabBars.buttons.element(boundBy: 2).tap()

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
        app.tabBars.buttons.element(boundBy: 2).tap()

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
        app.buttons["sameCityReunionToggle"].tap()
        XCTAssertTrue(app.buttons["sameCitySayHello"].waitForExistence(timeout: 3))
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
        XCTAssertTrue(app.buttons["myCitySharingCard"].waitForExistence(timeout: 5))
        app.buttons["myCitySharingCard"].tap()
        XCTAssertTrue(app.switches["citySharingToggle"].waitForExistence(timeout: 3))
        capture("marketing-07-sharing")
        app.terminate()

        app.launchArguments = ["-previewWidgets", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        capture("marketing-06-widgets")
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
        XCTAssertTrue(app.staticTexts["Local arrival times"].exists)
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
        app.tabBars.buttons.element(boundBy: 2).tap()
        let appearance = app.buttons["appearanceSettingsButton"]
        if !appearance.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        appearance.tap()
        app.buttons["nightJadeAppearance"].tap()
        app.buttons["appearanceDoneButton"].tap()
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.buttons["tripCard-example-west"].tap()
        XCTAssertTrue(app.buttons["expandTripMapButton"].waitForExistence(timeout: 5))
        capture("Night Jade routes")
        app.buttons["expandTripMapButton"].tap()
        XCTAssertTrue(app.buttons["closeTripMapButton"].waitForExistence(timeout: 4))
        capture("Night Jade immersive map")
        app.buttons["closeTripMapButton"].tap()
        app.tabBars.buttons.element(boundBy: 2).tap()
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
        field.tap()
        field.typeText(name)
        app.buttons["tripDestinationPicker"].tap()
        capture("Destination search sheet")
        app.buttons[destination].tap()
        capture("New trip form")
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
        XCTAssertTrue(app.buttons["myCitySharingCard"].label.contains("Bakersfield, CA"))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Fremont, CA")).firstMatch.waitForExistence(timeout: 3))
        capture("City fallback visual side-by-side comparison")
        app.tabBars.buttons.element(boundBy: 2).tap()
        let appearance = app.buttons["appearanceSettingsButton"]
        if !appearance.isHittable { app.scrollViews["profileSettingsScreen"].swipeUp() }
        XCTAssertTrue(appearance.waitForExistence(timeout: 3)); appearance.tap()
        app.buttons["nightJadeAppearance"].tap()
        app.buttons["appearanceDoneButton"].tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        capture("City fallback comparison Night Jade")
    }

    func testCityArtworkHandlesPausedAndUnavailableLocations() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-resetDemoData", "-previewCityFallbackStates", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.scrollViews["friendsScreen"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["myCitySharingCard"].label.contains("Location unavailable"))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Sharing paused")).firstMatch.waitForExistence(timeout: 3))
        capture("City artwork paused and unavailable")
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
        if let currentValue = value as? String, !currentValue.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count))
        }
        typeText(text)
    }
}
