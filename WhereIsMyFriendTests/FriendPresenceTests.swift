import MapKit
import CoreLocation
import UIKit
import XCTest
@testable import WhereIsMyFriend

final class CityLocationLabelTests: XCTestCase {
    func testUSStateNamesAndCodesShareCompactAndFullLabels() {
        for area in ["CA", "ca", " California "] {
            XCTAssertEqual(CityLocationLabel.compact(city: "Bakersfield", countryCode: "US", administrativeArea: area), "Bakersfield, CA")
            XCTAssertEqual(CityLocationLabel.full(city: "Bakersfield", countryCode: "US", administrativeArea: area, locale: Locale(identifier: "en_US")), "Bakersfield, California, United States")
        }
        XCTAssertEqual(CityLocationLabel.compact(city: "New York", countryCode: "US", administrativeArea: "New York"), "New York, NY")
    }

    func testMissingAndForeignRegionsAreNotGuessedOrConvertedToUSStates() {
        XCTAssertEqual(CityLocationLabel.compact(city: "Bakersfield", countryCode: "US", administrativeArea: nil), "Bakersfield")
        XCTAssertEqual(CityLocationLabel.full(city: "Bakersfield", countryCode: "US", administrativeArea: " ", locale: Locale(identifier: "en_US")), "Bakersfield, United States")
        XCTAssertEqual(CityLocationLabel.compact(city: "Cambridge", countryCode: "GB", administrativeArea: "England"), "Cambridge, England")
        XCTAssertEqual(CityLocationLabel.compact(city: "Example", countryCode: "CA", administrativeArea: "California"), "Example, California")
        XCTAssertNil(CityLocationLabel.compact(city: " ", countryCode: "US", administrativeArea: "CA"))
    }

    func testHiddenFriendLocationDoesNotLeakThroughFullDetailLabel() {
        var friend = FriendPresence(displayName: "Example", username: "example", city: "Bakersfield", countryCode: "US", updatedAt: Date(), administrativeArea: "CA")
        XCTAssertEqual(friend.cityDisplay, "Bakersfield, CA")
        for state in [PresenceSharingState.paused, .unavailable] {
            friend.sharingState = state
            XCTAssertEqual(friend.fullCityDisplay, friend.cityDisplay)
            XCTAssertFalse(friend.fullCityDisplay.contains("Bakersfield"))
            XCTAssertFalse(friend.fullCityDisplay.contains("California"))
        }
    }
}

private final class StubCityManager: CLLocationManager {
    var permission: CLAuthorizationStatus = .authorizedWhenInUse
    var requests = 0
    var significantStarts = 0
    var alwaysRequests = 0
    override var authorizationStatus: CLAuthorizationStatus { permission }
    override func requestLocation() { requests += 1 }
    override func startUpdatingLocation() {}
    override func stopUpdatingLocation() {}
    override func startMonitoringVisits() {}
    override func stopMonitoringVisits() {}
    override func startMonitoringSignificantLocationChanges() { significantStarts += 1 }
    override func stopMonitoringSignificantLocationChanges() {}
    override func requestAlwaysAuthorization() { alwaysRequests += 1 }
}

private final class StubCityGeocoder: CLGeocoder {
    var callbacks: [CLGeocodeCompletionHandler] = []
    override func reverseGeocodeLocation(_ location: CLLocation, completionHandler: @escaping CLGeocodeCompletionHandler) {
        callbacks.append(completionHandler)
    }
    override func cancelGeocode() {} // Deliberately deliver cancelled results to exercise the guard.
}

final class CityRegionCatalogTests: XCTestCase {
    func testBundledCatalogIsSharedAndEveryReviewedMemberResolves() throws {
        let catalog = CityRegionCatalog.bundled
        XCTAssertEqual(catalog.version, "2026-09-15.1")
        XCTAssertFalse(catalog.regionMatchingEnabled)
        XCTAssertEqual(catalog.regions.count, 4)
        for region in catalog.regions {
            for member in region.members {
                for city in member.cities {
                    for area in [member.administrativeArea] + member.administrativeAliases {
                        XCTAssertEqual(catalog.resolve(city: city, countryCode: region.countryCode, administrativeArea: area)?.id, region.id)
                        let emblem = CityEmblem.resolve(city: city, countryCode: region.countryCode, administrativeArea: area)
                        XCTAssertEqual(emblem.assetName, CityEmblem.resolve(city: region.artworkCity, countryCode: region.countryCode).assetName)
                        XCTAssertEqual(emblem.displayName, city)
                        XCTAssertNotNil(emblem.assetName)
                    }
                }
            }
        }
    }

    func testUnknownAndAmbiguousLocationsNeverInheritRegionIdentity() {
        let catalog = CityRegionCatalog.bundled
        XCTAssertNil(CityEmblem.resolve(city: "Sunnyvale", countryCode: "US", administrativeArea: "TX").assetName)
        XCTAssertNil(catalog.resolve(city: "Pasadena", countryCode: "US", administrativeArea: "TX"))
        XCTAssertNil(catalog.resolve(city: "Santa Clara", countryCode: "US", administrativeArea: "UT"))
        XCTAssertNil(catalog.resolve(city: "Milpitas", countryCode: "US", administrativeArea: nil))
        XCTAssertNil(catalog.resolve(city: "Milpitas", countryCode: nil, administrativeArea: "CA"))
        XCTAssertNil(catalog.resolve(city: "Milpitas", countryCode: "CA", administrativeArea: "CA"))
        XCTAssertNil(catalog.resolve(city: "Palm Springs", countryCode: "US", administrativeArea: "CA"))
        XCTAssertEqual(catalog.resolve(city: "  Sán   Jose ", countryCode: "us", administrativeArea: "california")?.id, "us-ca-silicon-valley")
        XCTAssertNotEqual(catalog.resolve(city: "San Francisco", countryCode: "US", administrativeArea: "CA")?.id,
                          catalog.resolve(city: "Milpitas", countryCode: "US", administrativeArea: "CA")?.id)
        XCTAssertEqual(catalog.resolve(city: "Hoboken", countryCode: "US", administrativeArea: "NJ")?.id,
                       catalog.resolve(city: "New York", countryCode: "US", administrativeArea: "NY")?.id)
        XCTAssertFalse(CityIdentity.matches(city: "Milpitas", countryCode: "US", otherCity: "Sunnyvale", otherCountryCode: "US"))
        XCTAssertFalse(CityIdentity.matches(city: "Hoboken", countryCode: "US", otherCity: "New York", otherCountryCode: "US"))
    }

    func testLegacySnapshotAndPendingUploadDecodeWithoutState() throws {
        let data = Data(#"{"city":"Milpitas","countryCode":"US","source":"manual"}"#.utf8)
        let presence = try JSONDecoder().decode(CurrentUserPresence.self, from: data)
        XCTAssertNil(presence.administrativeArea)
        XCTAssertNil(presence.artworkRegion)
        let upload = try JSONDecoder().decode(PendingPresenceUpload.self, from: Data(#"{"city":"Milpitas","countryCode":"US","source":"manual","clientUpdatedAt":0}"#.utf8))
        XCTAssertNil(upload.administrativeArea)
    }

    @MainActor
    func testStateMetadataSurvivesAppStoreAndWidgetPersistence() async throws {
        SharedAppStateStore.reset()
        defer { SharedAppStateStore.reset() }
        let store = AppStore(repository: SlowTestRepository())
        await store.updateCurrentCity(city: "Milpitas", countryCode: "US", source: .foregroundLocation, administrativeArea: "CA")
        XCTAssertEqual(store.snapshot.currentPresence.administrativeArea, "CA")
        XCTAssertEqual(store.snapshot.currentPresence.artworkRegion?.displayName, "Silicon Valley")
        XCTAssertEqual(SharedPresenceStore.loadCurrentAdministrativeArea(), "CA")
        await store.updateCurrentCity(city: "Paris", countryCode: "FR", source: .manual)
        XCTAssertNil(store.snapshot.currentPresence.administrativeArea)
        XCTAssertNil(SharedPresenceStore.loadCurrentAdministrativeArea())
    }
}

final class CityRefreshRegressionTests: XCTestCase {
    @MainActor
    func testStateWithoutLocalityIsNotPublishedAsACity() async throws {
        let manager = StubCityManager(), geocoder = StubCityGeocoder()
        let service = CityLocationService(manager: manager, geocoder: geocoder)
        service.configure(CityLocationContext(ownerID: UUID(), isActive: true, automaticAllowed: true))
        let point = CLLocation(latitude: 37.4, longitude: -121.9)
        service.locationManager(manager, didUpdateLocations: [point])
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(geocoder.callbacks.count, 1)
        geocoder.callbacks[0]([MKPlacemark(coordinate: point.coordinate, addressDictionary: ["State":"CA", "CountryCode":"US"])], nil)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertNil(service.latestCity)
        XCTAssertFalse(service.isResolving)
        service.configure(CityLocationContext())
    }

    @MainActor
    func testFailedGeocodeCanRetrySameValidSampleWithoutInventingFreshness() async throws {
        let manager = StubCityManager(), geocoder = StubCityGeocoder()
        let service = CityLocationService(manager: manager, geocoder: geocoder)
        service.configure(CityLocationContext(ownerID: UUID(), isActive: true, automaticAllowed: true))
        let time = Date()
        let location = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.4, longitude: -121.9), altitude: 0,
                                  horizontalAccuracy: 3000, verticalAccuracy: -1, timestamp: time)
        service.locationManager(manager, didUpdateLocations: [location])
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(geocoder.callbacks.count, 1)
        geocoder.callbacks[0](nil, NSError(domain: "Test", code: 1))
        try await Task.sleep(for: .milliseconds(20))
        service.requestForegroundCity()
        service.locationManager(manager, didUpdateLocations: [location])
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(geocoder.callbacks.count, 2)
        guard geocoder.callbacks.count == 2 else { return }
        geocoder.callbacks[1]([MKPlacemark(coordinate: location.coordinate, addressDictionary: ["City":"Milpitas", "CountryCode":"US"])], nil)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(service.latestCity?.observedAt, time)
        service.requestForegroundCity()
        service.locationManager(manager, didUpdateLocations: [location])
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertFalse(service.isResolving)
        XCTAssertEqual(geocoder.callbacks.count, 2)
        XCTAssertEqual(service.latestCity?.observedAt, time)
        service.configure(CityLocationContext())
    }

    func testStrictPresenceIdentityAndUnifiedFreshness() {
        let now = Date()
        let me = CurrentUserPresence(administrativeArea: "CA", city: "Pasadena", countryCode: "US", updatedAt: now, source: .foregroundLocation)
        var friend = FriendPresence(displayName: "Friend", username: "friend", city: "Pasadena", countryCode: "US",
                                    updatedAt: now, administrativeArea: "TX")
        XCTAssertFalse(PresenceMatchPolicy.matches(me, friend, at: now))
        friend.administrativeArea = nil
        XCTAssertFalse(PresenceMatchPolicy.matches(me, friend, at: now))
        friend.administrativeArea = "California"
        friend.updatedAt = now.addingTimeInterval(-3 * 3600)
        XCTAssertTrue(PresenceMatchPolicy.matches(me, friend, at: now))
        friend.updatedAt = now.addingTimeInterval(-24 * 3600)
        XCTAssertFalse(PresenceMatchPolicy.matches(me, friend, at: now))
        XCTAssertFalse(friend.isSameCityEligible(at: now))
    }

    func testStaleLocationDoesNotManufactureDepartureAndReturn() {
        let now = Date()
        var snapshot = DemoData.initialSnapshot(now: now)
        snapshot.friends = [snapshot.friends[0]]
        snapshot.colocationEvents = []; snapshot.colocationSessions = []
        ColocationEvaluator.evaluate(snapshot: &snapshot, now: now)
        XCTAssertEqual(snapshot.colocationEvents.count, 1)
        ColocationEvaluator.evaluate(snapshot: &snapshot, now: now.addingTimeInterval(25 * 3600))
        XCTAssertEqual(snapshot.colocationSessions.filter(\.isActive).count, 1)
        XCTAssertTrue(SameCityAlertPolicy.currentFriends(in: snapshot, at: now.addingTimeInterval(25 * 3600)).isEmpty)
        snapshot.currentPresence.updatedAt = now.addingTimeInterval(26 * 3600)
        snapshot.friends[0].updatedAt = snapshot.currentPresence.updatedAt
        ColocationEvaluator.evaluate(snapshot: &snapshot, now: now.addingTimeInterval(26 * 3600))
        XCTAssertEqual(snapshot.colocationEvents.count, 1)
    }
    @MainActor
    func testOneShotTimeoutClearsProgress() async throws {
        let service = CityLocationService(manager: StubCityManager(), geocoder: StubCityGeocoder(),
                                          resolutionTimeout: .milliseconds(20))
        service.configure(CityLocationContext(ownerID: UUID(), isActive: true, automaticAllowed: false))
        service.requestForegroundCity()
        XCTAssertTrue(service.isResolving)
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertFalse(service.isResolving)
        XCTAssertNotNil(service.errorMessage)
        service.configure(CityLocationContext())
    }

    @MainActor
    func testForegroundRefreshAndBackgroundConsent() {
        let manager = StubCityManager()
        let service = CityLocationService(manager: manager, geocoder: StubCityGeocoder())
        var context = CityLocationContext(ownerID: UUID(), isActive: true, automaticAllowed: true)
        service.configure(context)
        XCTAssertEqual(manager.requests, 1)
        service.refreshIfNeeded()
        XCTAssertEqual(manager.requests, 1)
        XCTAssertEqual(manager.significantStarts, 0)
        context.isActive = false
        service.configure(context)
        XCTAssertFalse(service.isResolving)
        context.isActive = true
        service.configure(context)
        XCTAssertEqual(manager.requests, 2)
        context.backgroundEnabled = true
        service.configure(context)
        XCTAssertEqual(manager.significantStarts, 0)
        XCTAssertEqual(manager.alwaysRequests, 0) // Stored preference alone must not prompt.
        manager.permission = .authorizedAlways
        service.configure(context)
        service.configure(context)
        XCTAssertEqual(manager.significantStarts, 1)
        service.configure(CityLocationContext())
    }

    @MainActor
    func testLateGeocodeCannotReplaceNewerCityOrPublishAfterAccountSwitch() async throws {
        let manager = StubCityManager(), geocoder = StubCityGeocoder()
        let service = CityLocationService(manager: manager, geocoder: geocoder)
        let owner = UUID(), now = Date()
        service.configure(CityLocationContext(ownerID: owner, isActive: true, automaticAllowed: true))
        func location(_ time: Date) -> CLLocation {
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.43, longitude: -121.90), altitude: 0,
                       horizontalAccuracy: 3000, verticalAccuracy: -1, timestamp: time)
        }
        func city(_ name: String) -> CLPlacemark {
            MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: 37.43, longitude: -121.90),
                        addressDictionary: ["City": name, "CountryCode": "US"])
        }
        service.locationManager(manager, didUpdateLocations: [location(now.addingTimeInterval(-20))])
        try await Task.sleep(for: .milliseconds(20))
        service.locationManager(manager, didUpdateLocations: [location(now.addingTimeInterval(-10))])
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(geocoder.callbacks.count, 2)
        guard geocoder.callbacks.count == 2 else { return }
        geocoder.callbacks[1]([city("Milpitas")], nil)
        try await Task.sleep(for: .milliseconds(20))
        geocoder.callbacks[0]([city("Old city")], nil)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(service.latestCity?.city, "Milpitas")
        XCTAssertEqual(service.latestCity?.observedAt, now.addingTimeInterval(-10))
        service.locationManager(manager, didUpdateLocations: [location(now)])
        try await Task.sleep(for: .milliseconds(20))
        service.configure(CityLocationContext(ownerID: UUID(), isActive: true, automaticAllowed: true))
        geocoder.callbacks.last?([city("Wrong account")], nil)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertNil(service.latestCity)
        service.configure(CityLocationContext())
    }

    func testRejectsCachedFutureInvalidAndOutOfOrderLocations() {
        let now = Date()
        func sample(age: TimeInterval, accuracy: Double = 3000) -> CLLocation {
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.43, longitude: -121.90), altitude: 0,
                       horizontalAccuracy: accuracy, verticalAccuracy: -1, timestamp: now.addingTimeInterval(-age))
        }
        XCTAssertTrue(CityLocationPolicy.accepts(sample(age: 10), now: now))
        XCTAssertTrue(CityLocationPolicy.accepts(sample(age: 10, accuracy: 9000), now: now))
        XCTAssertFalse(CityLocationPolicy.accepts(sample(age: 121), now: now))
        XCTAssertFalse(CityLocationPolicy.accepts(sample(age: -31), now: now))
        XCTAssertFalse(CityLocationPolicy.accepts(sample(age: 0, accuracy: -1), now: now))
        XCTAssertFalse(CityLocationPolicy.accepts(sample(age: 0, accuracy: 20000), now: now))
        XCTAssertFalse(CityLocationPolicy.accepts(sample(age: 20), now: now, newerThan: now.addingTimeInterval(-10)))
        XCTAssertFalse(CityLocationPolicy.accepts(sample(age: 10), now: now, newerThan: now.addingTimeInterval(-10)))
    }

    func testManualCityAndPausedSharingDisableAutomaticUpdates() {
        let manual = CurrentUserPresence(city: "Paris", countryCode: "FR", updatedAt: Date(), source: .manual)
        let gps = CurrentUserPresence(city: "Paris", countryCode: "FR", updatedAt: Date(), source: .foregroundLocation)
        let empty = CurrentUserPresence(city: nil, countryCode: nil, updatedAt: nil, source: .manual)
        XCTAssertFalse(CityLocationPolicy.automaticAllowed(sharingEnabled: true, presence: manual))
        XCTAssertFalse(CityLocationPolicy.automaticAllowed(sharingEnabled: false, presence: gps))
        XCTAssertTrue(CityLocationPolicy.automaticAllowed(sharingEnabled: true, presence: gps))
        XCTAssertTrue(CityLocationPolicy.automaticAllowed(sharingEnabled: true, presence: empty))
    }

    func testArtworkAliasesDoNotBecomeGeographicIdentity() {
        XCTAssertEqual(CityEmblem.resolve(city: "Santa Clara", countryCode: "US").displayName, "Santa Clara")
        XCTAssertNil(CityEmblem.resolve(city: "Santa Clara", countryCode: "US").assetName)
        XCTAssertNil(CityEmblem.resolve(city: "Milpitas", countryCode: "US").assetName)
        XCTAssertNil(CityEmblem.resolve(city: "Paris", countryCode: "US").assetName)
        XCTAssertEqual(CityEmblem.resolve(city: " LA ", countryCode: "us").cityID, "los_angeles")
        XCTAssertEqual(CityEmblem.resolve(city: "Shinjuku", countryCode: "JP").cityID, "tokyo")
        for pair in [("Santa Clara", "Los Angeles"), ("Shinjuku", "Tokyo"), ("Milpitas", "San Jose"), ("Clearwater", "Tampa")] {
            XCTAssertFalse(CityIdentity.matches(city: pair.0, countryCode: nil, otherCity: pair.1, otherCountryCode: nil))
        }
    }

    func testRepeatedCityObservationsHaveDistinctFreshness() {
        let owner = UUID(), now = Date()
        let first = ResolvedCity(city: "Milpitas", countryCode: "US", source: .foregroundLocation,
                                 observedAt: now, ownerID: owner, isAutomatic: true)
        let second = ResolvedCity(city: "Milpitas", countryCode: "US", source: .foregroundLocation,
                                  observedAt: now.addingTimeInterval(300), ownerID: owner, isAutomatic: true)
        XCTAssertNotEqual(first, second)
    }
}

final class FriendNotificationLinkTests: XCTestCase {
    func testOnlyExactAppRequestLinksAreAccepted() {
        let id = UUID()
        XCTAssertEqual(FriendRequestNotificationLink.parse(URL(string: "testapp://friend-requests/\(id)")!, scheme: "testapp"), id)
        for url in ["testapp://friend-requests", "testapp://friend-requests/not-a-uuid", "testapp://friend-requests/\(id)/extra",
                    "testapp://friend-requests/\(id)?account=other", "testapp://friend-requests/\(id)#fragment",
                    "testapp://user@friend-requests/\(id)", "testapp://friend-requests:123/\(id)", "https://friend-requests/\(id)"] {
            XCTAssertNil(FriendRequestNotificationLink.parse(URL(string: url)!, scheme: "testapp"))
        }
    }
}

@MainActor
final class LocationPermissionReminderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let week = LocationPermissionReminderState.interval

    private func withStore(_ run: (LocationPermissionReminderStore, UserDefaults) -> Void) {
        let suite = "location-reminder-tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        run(LocationPermissionReminderStore(defaults: defaults, keyPrefix: "test"), defaults)
    }

    func testWeeklyCooldownPersistsAcrossRelaunchAndStopsAfterThreePresentations() {
        withStore { store, defaults in
            let owner = UUID()
            for attempt in 0..<3 {
                let time = now.addingTimeInterval(Double(attempt) * week)
                store.prepare(ownerID: owner, eligible: true, at: time)
                XCTAssertEqual(store.presentedOwnerID, owner)
                // Reevaluation while visible must not count as another presentation.
                store.prepare(ownerID: owner, eligible: true, at: time)
                XCTAssertEqual(store.history(for: owner).presentations, attempt + 1)
                store.dismiss(for: owner, at: time)
                let relaunched = LocationPermissionReminderStore(defaults: defaults, keyPrefix: "test")
                relaunched.prepare(ownerID: owner, eligible: true, at: time.addingTimeInterval(week - 1))
                XCTAssertNil(relaunched.presentedOwnerID)
            }
            let relaunched = LocationPermissionReminderStore(defaults: defaults, keyPrefix: "test")
            relaunched.prepare(ownerID: owner, eligible: true, at: now.addingTimeInterval(week * 50))
            XCTAssertNil(relaunched.presentedOwnerID)
            XCTAssertEqual(relaunched.history(for: owner).presentations, 3)
        }
    }

    func testInitialSetupSkipDefersWithoutSpendingAReminder() {
        withStore { store, _ in
            let owner = UUID()
            store.deferAfterInitialSetup(for: owner, at: now)
            store.prepare(ownerID: owner, eligible: true, at: now)
            XCTAssertNil(store.presentedOwnerID)
            XCTAssertEqual(store.history(for: owner).presentations, 0)
            store.prepare(ownerID: owner, eligible: true, at: now.addingTimeInterval(week))
            XCTAssertEqual(store.presentedOwnerID, owner)
        }
    }

    func testAccountsAndInactivePagesDoNotShareOrConsumeReminders() {
        withStore { store, _ in
            let first = UUID(), second = UUID()
            store.prepare(ownerID: first, eligible: false, at: now)
            XCTAssertEqual(store.history(for: first).presentations, 0)
            store.prepare(ownerID: first, eligible: true, at: now)
            store.prepare(ownerID: nil, eligible: false, at: now)
            XCTAssertNil(store.presentedOwnerID)
            store.prepare(ownerID: second, eligible: true, at: now)
            XCTAssertEqual(store.presentedOwnerID, second)
            store.dismiss(for: first, at: now) // A stale account callback cannot dismiss the new account.
            XCTAssertEqual(store.presentedOwnerID, second)
            store.prepare(ownerID: first, eligible: true, at: now)
            XCTAssertNil(store.presentedOwnerID)
            XCTAssertEqual(store.history(for: first).presentations, 1)
            XCTAssertEqual(store.history(for: second).presentations, 1)
        }
    }

    func testLateDismissalAndClockRollbackCannotImmediatelyRepeat() {
        withStore { store, _ in
            let owner = UUID()
            store.prepare(ownerID: owner, eligible: true, at: now)
            let dismissedAt = now.addingTimeInterval(week * 2)
            store.dismiss(for: owner, at: dismissedAt)
            for time in [now.addingTimeInterval(-week), dismissedAt, dismissedAt.addingTimeInterval(week - 1)] {
                store.prepare(ownerID: owner, eligible: true, at: time)
                XCTAssertNil(store.presentedOwnerID)
            }
            store.prepare(ownerID: owner, eligible: true, at: dismissedAt.addingTimeInterval(week))
            XCTAssertEqual(store.presentedOwnerID, owner)
        }
    }

    func testEligibilityRespectsManualCitiesSharingAndPermissionState() {
        let empty = CurrentUserPresence(city: nil, countryCode: nil, updatedAt: nil, source: .foregroundLocation)
        func eligible(_ status: CLAuthorizationStatus = .notDetermined, authenticated: Bool = true,
                      live: Bool = true, visible: Bool = true, sharing: Bool = true,
                      presence: CurrentUserPresence? = nil) -> Bool {
            LocationPermissionReminderPolicy.isEligible(isAuthenticated: authenticated, isLiveAccount: live,
                isHomeVisible: visible, sharingEnabled: sharing, presence: presence ?? empty, status: status)
        }
        XCTAssertTrue(eligible())
        XCTAssertTrue(eligible(.denied))
        for status: CLAuthorizationStatus in [.authorizedAlways, .authorizedWhenInUse, .restricted] {
            XCTAssertFalse(eligible(status))
            XCTAssertEqual(LocationPermissionReminderPolicy.action(for: status), .none)
        }
        XCTAssertFalse(eligible(authenticated: false))
        XCTAssertFalse(eligible(live: false))
        XCTAssertFalse(eligible(visible: false))
        XCTAssertFalse(eligible(sharing: false))
        XCTAssertFalse(eligible(presence: .init(city: "Paris", countryCode: "FR", updatedAt: now, source: .manual)))
        XCTAssertTrue(eligible(presence: .init(city: "Paris", countryCode: "FR", updatedAt: now, source: .foregroundLocation)))
        XCTAssertEqual(LocationPermissionReminderPolicy.action(for: .notDetermined), .requestPermission)
        XCTAssertEqual(LocationPermissionReminderPolicy.action(for: .denied), .openSettings)
    }

    func testPermissionOrSharingChangeHidesAnAlreadyVisibleReminder() {
        withStore { store, _ in
            let owner = UUID()
            store.prepare(ownerID: owner, eligible: true, at: now)
            store.prepare(ownerID: owner, eligible: false, at: now)
            XCTAssertNil(store.presentedOwnerID)
            XCTAssertEqual(store.history(for: owner).presentations, 1)
        }
    }

    func testCorruptSavedHistoryDoesNotResetTheReminderLimit() {
        withStore { store, defaults in
            let owner = UUID()
            defaults.set(Data("invalid".utf8), forKey: "test.\(owner.uuidString)")
            store.prepare(ownerID: owner, eligible: true, at: now)
            XCTAssertNil(store.presentedOwnerID)
        }
    }
}

final class LocationSetupPolicyTests: XCTestCase {
    func testFirstSignedInUsePromptsButPermissionAndExplicitSkipAreRespected() {
        for status: CLAuthorizationStatus in [.notDetermined, .denied, .restricted] {
            XCTAssertTrue(LocationSetupPolicy.shouldPresent(isAuthenticated: true, hasSeenSetup: false, isLiveAccount: true, status: status))
            XCTAssertFalse(LocationSetupPolicy.shouldPresent(isAuthenticated: true, hasSeenSetup: true, isLiveAccount: true, status: status))
        }
        for status: CLAuthorizationStatus in [.authorizedAlways, .authorizedWhenInUse] {
            XCTAssertFalse(LocationSetupPolicy.shouldPresent(isAuthenticated: true, hasSeenSetup: false, isLiveAccount: true, status: status))
        }
        XCTAssertFalse(LocationSetupPolicy.shouldPresent(isAuthenticated: false, hasSeenSetup: false, isLiveAccount: true, status: .notDetermined))
        XCTAssertFalse(LocationSetupPolicy.shouldPresent(isAuthenticated: true, hasSeenSetup: false, isLiveAccount: false, status: .notDetermined))
    }
}

final class PersonalTravelPlanTests: XCTestCase {
    @MainActor
    func testOldRefreshCannotOverwriteSaveOrNewAccount() async throws {
        let repository = SlowTestRepository()
        let library = TravelPlanLibrary()
        let owner = UUID()
        library.connect(repository: repository, userID: owner)
        let refresh = Task { await library.refresh() }
        try await Task.sleep(for: .milliseconds(30))
        let plan = PersonalTravelPlan(city: "Tokyo", countryCode: "JP", region: "Tokyo", timeZone: "Asia/Tokyo", startDay: "2026-09-12", endDay: "2026-09-15")
        let saved = await library.save(plan); XCTAssertTrue(saved)
        await refresh.value
        XCTAssertEqual(library.plans.first?.id, plan.id)
        let oldAccountRefresh = Task { await library.refresh() }
        try await Task.sleep(for: .milliseconds(30))
        library.connect(repository: repository, userID: UUID())
        await oldAccountRefresh.value
        XCTAssertTrue(library.plans.isEmpty)
        XCTAssertFalse(library.hasSynced)
        UserDefaults.standard.removeObject(forKey: "travel-plans.v1.\(repository.storageScope).\(owner)")
    }
    func testPrivateDefaultAndStrictCalendarDates() throws {
        let plan = PersonalTravelPlan(city: "Tokyo", countryCode: "JP", region: "Tokyo", timeZone: "Asia/Tokyo", startDay: "2026-09-12", endDay: "2026-09-15")
        XCTAssertTrue(plan.audience.isEmpty)
        XCTAssertFalse(plan.alertsEnabled)
        XCTAssertNoThrow(try plan.validated())
        var invalid = plan; invalid.endDay = "2026-02-30"
        XCTAssertThrowsError(try invalid.validated())
        invalid = plan; invalid.endDay = "2026-09-11"
        XCTAssertThrowsError(try invalid.validated())
        invalid = plan; invalid.timeZone = "Invented/City"
        XCTAssertThrowsError(try invalid.validated())
        let payload = try JSONSerialization.jsonObject(with: JSONEncoder().encode(TravelPlanPayload(plan))) as! [String: Any]
        XCTAssertNil(payload["ownerID"]); XCTAssertNil(payload["id"])
    }

    func testLocalDayBoundaryAndDSTCounting() {
        let plan = PersonalTravelPlan(city: "Tokyo", countryCode: "JP", region: "Tokyo", timeZone: "Asia/Tokyo", startDay: "2026-09-12", endDay: "2026-09-12")
        let now = ISO8601DateFormatter().date(from: "2026-09-12T15:01:00Z")!
        XCTAssertTrue(plan.isPast(at: now))
        let overlap = TravelOverlap(id: String(repeating: "a", count: 32), friendID: UUID(), friendName: "Friend", city: "New York", countryCode: "US", region: "NY", timeZone: "America/New_York", startDay: "2026-10-31", endDay: "2026-11-02")
        XCTAssertEqual(overlap.daysTogether, 3)
        var other = TravelCity.examples[1]; other.region = "NJ"
        XCTAssertNotEqual(other.id, TravelCity.examples[1].id)
    }

    func testUpcomingLinksRejectForeignSchemesAndMalformedIDs() {
        let id = String(repeating: "a", count: 32)
        XCTAssertEqual(UpcomingTravelLink.parse(URL(string: "whereismyfriend://upcoming/\(id)")!, scheme: "whereismyfriend"), id)
        for url in ["other://upcoming/\(id)", "whereismyfriend://upcoming/nope", "whereismyfriend://upcoming/\(id)?owner=someone", "whereismyfriend://upcoming/\(id)/extra"] {
            XCTAssertNil(UpcomingTravelLink.parse(URL(string: url)!, scheme: "whereismyfriend"))
        }
    }

    @MainActor
    func testDemoCRUDRevocationAndAccountScope() async throws {
        let snapshot = DemoData.initialSnapshot()
        let repository = LocalDemoRepository(snapshot: snapshot, persistsChanges: false)
        let library = TravelPlanLibrary()
        library.connect(repository: repository, userID: snapshot.currentUser.id)
        await library.refresh()
        let lin = try XCTUnwrap(snapshot.friends.first { $0.username == "lin" })
        let start = TripDay(Date(), timeZone: TimeZone(identifier: "Asia/Tokyo")!).value
        let end = TripDay(Date().addingTimeInterval(3 * 86400), timeZone: TimeZone(identifier: "Asia/Tokyo")!).value
        var plan = PersonalTravelPlan(city: "Tokyo", countryCode: "JP", region: "Tokyo", timeZone: "Asia/Tokyo", startDay: start, endDay: end)
        let privateSaved = await library.save(plan); XCTAssertTrue(privateSaved)
        XCTAssertTrue(library.overlaps.isEmpty)
        plan = try XCTUnwrap(library.plans.first); plan.audience = [lin.id]
        let shared = await library.save(plan); XCTAssertTrue(shared)
        XCTAssertEqual(library.overlaps.count, 1)
        let stale = await library.save(plan); XCTAssertFalse(stale)
        plan = try XCTUnwrap(library.plans.first); plan.audience = []
        let revoked = await library.save(plan); XCTAssertTrue(revoked)
        XCTAssertTrue(library.overlaps.isEmpty)
        plan = try XCTUnwrap(library.plans.first)
        let deleted = await library.delete(plan); XCTAssertTrue(deleted)
        XCTAssertTrue(library.plans.isEmpty)
        library.connect(repository: repository, userID: nil)
        XCTAssertTrue(library.plans.isEmpty); XCTAssertTrue(library.overlaps.isEmpty)
        XCTAssertFalse(library.hasSynced)
    }
}

final class SameCityAlertPolicyTests: XCTestCase {
    private let now = Date()

    private func fixture() -> AppSnapshot {
        var snapshot = DemoData.initialSnapshot(now: now)
        snapshot.friends = [FriendPresence(displayName: "Mia Chen", username: "mia", city: "New York",
                                          countryCode: "US", updatedAt: now, administrativeArea: "NY")]
        snapshot.friendPreferences = [FriendAccessPreference(friendID: snapshot.friends[0].id,
                                                              sharesMyCity: true, sameCityAlertEnabled: true)]
        snapshot.colocationEvents = [ColocationEvent(cityKey: "v2|US|ny|newyork", id: UUID(), deduplicationKey: "test", city: "New York",
            friendIDs: [snapshot.friends[0].id], friendNames: ["Mia Chen"], createdAt: now, wasNotified: false)]
        return snapshot
    }

    func testFreshMutuallySharedCityCanBeShownAsCurrent() {
        let snapshot = fixture()
        XCTAssertEqual(SameCityAlertPolicy.currentFriends(in: snapshot, at: now).count, 1)
        XCTAssertTrue(SameCityAlertPolicy.isCurrent(snapshot.colocationEvents[0], in: snapshot, at: now))
    }

    func testOldOrDifferentStateEventCannotBecomeCurrentAgain() {
        var snapshot = fixture()
        snapshot.colocationEvents[0].cityKey = nil
        XCTAssertNotNil(SameCityAlertPolicy.event(snapshot.colocationEvents[0].id, in: snapshot))
        XCTAssertFalse(SameCityAlertPolicy.isCurrent(snapshot.colocationEvents[0], in: snapshot, at: now))
        snapshot.colocationEvents[0].cityKey = "v2|US|tx|newyork"
        XCTAssertFalse(SameCityAlertPolicy.isCurrent(snapshot.colocationEvents[0], in: snapshot, at: now))
    }

    func testOldEventIsHistoricalEvenIfBothSavedCitiesStillMatch() {
        var snapshot = fixture()
        let event = snapshot.colocationEvents[0]
        snapshot.colocationEvents = [ColocationEvent(id: event.id, deduplicationKey: event.deduplicationKey,
            city: event.city, friendIDs: event.friendIDs, friendNames: event.friendNames,
            createdAt: now.addingTimeInterval(-86401), wasNotified: true)]
        XCTAssertNotNil(SameCityAlertPolicy.event(event.id, in: snapshot))
        XCTAssertFalse(SameCityAlertPolicy.isCurrent(snapshot.colocationEvents[0], in: snapshot, at: now))
    }

    func testStaleMissingAndFutureDatedCityUpdatesDoNotAssertCurrentColocation() {
        let dates: [Date?] = [nil, now.addingTimeInterval(-86400), now.addingTimeInterval(300)]
        for date in dates {
            var snapshot = fixture()
            snapshot.friends[0].updatedAt = date
            XCTAssertTrue(SameCityAlertPolicy.currentFriends(in: snapshot, at: now).isEmpty)
            snapshot = fixture()
            snapshot.currentPresence.updatedAt = date
            XCTAssertTrue(SameCityAlertPolicy.currentFriends(in: snapshot, at: now).isEmpty)
        }
    }

    func testRevocationMuteSignOutAndBlockingHideEventDetails() {
        let mutations: [(inout AppSnapshot) -> Void] = [
            { $0.isAuthenticated = false },
            { $0.sharingPreferences.citySharingEnabled = false },
            { $0.friendPreferences[0].sharesMyCity = false },
            { $0.friendPreferences[0].sameCityAlertEnabled = false },
            { $0.friends[0].sharingState = .paused },
            { $0.blockedPeople = [BlockedPerson(id: $0.friends[0].id, displayName: "Mia", username: "mia",
                                               avatarPalette: 1, blockedAt: Date())] },
            { $0.friends = [] }
        ]
        for mutation in mutations {
            var snapshot = fixture()
            let eventID = snapshot.colocationEvents[0].id
            mutation(&snapshot)
            XCTAssertTrue(SameCityAlertPolicy.currentFriends(in: snapshot, at: now).isEmpty)
            XCTAssertNil(SameCityAlertPolicy.event(eventID, in: snapshot))
        }
    }

    func testSameNameDifferentCountryDoesNotMatch() {
        var snapshot = fixture()
        snapshot.friends[0].countryCode = "GB"
        XCTAssertTrue(SameCityAlertPolicy.currentFriends(in: snapshot, at: now).isEmpty)
    }

    func testNotificationPreviewPrivacyDoesNotRemoveInAppMoments() {
        var snapshot = fixture()
        snapshot.sharingPreferences.notificationPreviewEnabled = false
        XCTAssertEqual(SameCityAlertPolicy.currentFriends(in: snapshot, at: now).count, 1)
    }

    func testMultipleFriendsAreDistinctAndUnknownEventsAreUnavailable() {
        var snapshot = fixture()
        snapshot.friends.append(FriendPresence(displayName: "Alex", username: "alex", city: "New York",
                                               countryCode: "US", updatedAt: now, administrativeArea: "NY"))
        XCTAssertEqual(SameCityAlertPolicy.currentFriends(in: snapshot, at: now).map(\.displayName), ["Alex", "Mia Chen"])
        XCTAssertNil(SameCityAlertPolicy.event(UUID(), in: snapshot))
    }

    func testStrictNotificationDeepLinksKeepLegacyEventsRouteCompatible() {
        let id = UUID()
        XCTAssertEqual(SameCityAlertLink.eventID(from: SharedAppLink.make(host: "events", path: id.uuidString)), id)
        XCTAssertEqual(SameCityAlertLink.eventID(from: URL(string: "testscheme://events/\(id)")!, scheme: "testscheme"), id)
        for link in ["https://events/\(id)", "whereismyfriend://events", "whereismyfriend://events/not-a-uuid",
                     "whereismyfriend://events/\(id)/extra", "whereismyfriend://events/\(id)?city=Tokyo",
                     "whereismyfriend://user@events/\(id)", "whereismyfriend://events/\(id)#fragment"] {
            XCTAssertNil(SameCityAlertLink.eventID(from: URL(string: link)!))
        }
    }
}

@MainActor
final class SameCityAlertDeliveryTests: XCTestCase {
    private func remoteFixture() async -> (SlowTestRepository, AppStore, AppSnapshot) {
        var snapshot = DemoData.initialSnapshot()
        snapshot.currentUser = AppUser(id: UUID(), displayName: "Owner", username: "owner")
        snapshot.currentPresence = CurrentUserPresence(administrativeArea: "NY", city: "New York",
            countryCode: "US", updatedAt: Date(), source: .foregroundLocation)
        snapshot.friends = [FriendPresence(displayName: "Friend", username: "friend", city: "New York",
            countryCode: "US", updatedAt: Date(), administrativeArea: "NY")]
        snapshot.colocationEvents = []
        let repo = SlowTestRepository(loadDelay: .zero, mode: .remote)
        await repo.configureSnapshot(snapshot)
        let store = AppStore(repository: repo)
        store.setAppActive(true)
        return (repo, store, snapshot)
    }

    private func event(in snapshot: AppSnapshot, at date: Date = Date()) -> ColocationEvent {
        let friend = snapshot.friends[0]
        return ColocationEvent(cityKey: "v2|US|ny|newyork", id: UUID(), deduplicationKey: UUID().uuidString,
            city: "New York", friendIDs: [friend.id], friendNames: [friend.displayName], createdAt: date, wasNotified: false)
    }

    func testNewRemoteEventShowsWithoutPushAndLatePushDoesNotRepeat() async throws {
        let (repo, store, initial) = await remoteFixture()
        var snapshot = initial
        snapshot.colocationEvents = [event(in: snapshot)]
        await repo.configureSnapshot(snapshot)
        await store.refresh()
        XCTAssertNil(store.sameCityBannerEventID, "Bootstrap must not replay even recent history")
        let arrived = event(in: snapshot)
        snapshot.colocationEvents.append(arrived)
        await repo.configureSnapshot(snapshot)
        await store.refresh()
        XCTAssertEqual(store.sameCityBannerEventID, arrived.id)
        store.dismissSameCityBanner()
        store.notificationService.onSameCityForeground?(arrived.id)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(store.sameCityBannerEventID)
        await store.signOut()
    }

    func testRemoteSnapshotRejectsOlderEventsDisabledAlertsAndNewAccountHistory() async {
        let (repo, store, initial) = await remoteFixture()
        var snapshot = initial
        await store.refresh()
        snapshot.colocationEvents = [event(in: snapshot, at: Date().addingTimeInterval(-600))]
        await repo.configureSnapshot(snapshot)
        await store.refresh()
        XCTAssertNil(store.sameCityBannerEventID)
        snapshot.friendPreferences = [FriendAccessPreference(friendID: snapshot.friends[0].id,
            sharesMyCity: true, sameCityAlertEnabled: false)]
        snapshot.colocationEvents.append(event(in: snapshot))
        await repo.configureSnapshot(snapshot)
        await store.refresh()
        XCTAssertNil(store.sameCityBannerEventID)
        snapshot.friendPreferences = []
        snapshot.currentUser = AppUser(id: UUID(), displayName: "New owner", username: "newowner")
        snapshot.colocationEvents.append(event(in: snapshot))
        await repo.configureSnapshot(snapshot)
        await store.refresh()
        XCTAssertNil(store.sameCityBannerEventID)
        await store.signOut()
    }

    func testBackgroundSnapshotDoesNotQueueAnUnseenBannerForResume() async {
        let (repo, store, initial) = await remoteFixture()
        var snapshot = initial
        await store.refresh()
        store.setAppActive(false)
        snapshot.colocationEvents = [event(in: snapshot)]
        await repo.configureSnapshot(snapshot)
        await store.refresh()
        XCTAssertNil(store.sameCityBannerEventID)
        store.setAppActive(true)
        await store.refresh()
        XCTAssertNil(store.sameCityBannerEventID)
        let arrived = event(in: snapshot)
        snapshot.colocationEvents.append(arrived)
        await repo.configureSnapshot(snapshot)
        await store.refresh()
        XCTAssertEqual(store.sameCityBannerEventID, arrived.id)
        store.setAppActive(false)
        XCTAssertNil(store.sameCityBannerEventID)
        await store.signOut()
    }

    private func makeStore() async -> (AppStore, ColocationEvent) {
        var snapshot = DemoData.initialSnapshot()
        snapshot.currentUser = AppUser(id: UUID(), displayName: "Test owner", username: "testowner")
        let friend = FriendPresence(displayName: "Mia", username: "mia", city: "New York",
                                    countryCode: "US", updatedAt: Date(), administrativeArea: "NY")
        snapshot.friends = [friend]
        let event = ColocationEvent(cityKey: "v2|US|ny|newyork", id: UUID(), deduplicationKey: UUID().uuidString, city: "New York",
            friendIDs: [friend.id], friendNames: [friend.displayName], createdAt: Date(), wasNotified: true)
        snapshot.colocationEvents = [event]
        let store = AppStore(repository: LocalDemoRepository(snapshot: snapshot, persistsChanges: false))
        store.setAppActive(true)
        await store.refresh()
        return (store, event)
    }

    func testBootstrapDoesNotReplayHistoryAndDuplicatePushDoesNotReappear() async throws {
        let (store, event) = await makeStore()
        XCTAssertNil(store.sameCityBannerEventID)
        store.notificationService.onSameCityForeground?(event.id)
        for _ in 0..<50 where store.sameCityBannerEventID == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(store.sameCityBannerEventID, event.id)
        store.dismissSameCityBanner()
        store.notificationService.onSameCityForeground?(event.id)
        try await Task.sleep(for: .milliseconds(150))
        XCTAssertNil(store.sameCityBannerEventID)
        await store.signOut()
    }

    func testTapRoutesByIDAndSignOutClearsPendingPresentation() async {
        let (store, event) = await makeStore()
        XCTAssertTrue(store.handleIncomingURL(SharedAppLink.make(host: "events", path: event.id.uuidString)))
        XCTAssertEqual(store.pendingSameCityEventID, event.id)
        await store.signOut()
        XCTAssertNil(store.pendingSameCityEventID)
        XCTAssertNil(store.sameCityBannerEventID)
        store.notificationService.onSameCityForeground?(event.id)
        XCTAssertNil(store.sameCityBannerEventID)
    }
}

final class OnboardingAssetTests: XCTestCase {
    func testFlightCurvesConvergeAndTrailsFollowTheAircraft() {
        for east in [false, true] {
            XCTAssertEqual(OnboardingFlightTrajectory.point(at: 1, fromEast: east), CGPoint(x: 165, y: 180))
            XCTAssertEqual(OnboardingFlightTrajectory.point(at: -1, fromEast: east), OnboardingFlightTrajectory.point(at: 0, fromEast: east))
            for progress in [CGFloat(0.1), 0.5, 0.9] {
                let plane = OnboardingFlightTrajectory.point(at: progress, fromEast: east)
                let trail = OnboardingFlightTrajectory.path(fromEast: east, from: max(0, progress-0.16), to: progress)
                XCTAssertEqual(trail.currentPoint?.x ?? -1, plane.x, accuracy: 0.001)
                XCTAssertEqual(trail.currentPoint?.y ?? -1, plane.y, accuracy: 0.001)
                XCTAssertTrue(OnboardingFlightTrajectory.heading(at: progress, fromEast: east).isFinite)
            }
        }
    }

    func testFreestandingCityAssetsHaveTransparentBackgrounds() throws {
        for name in ["OnboardingNewYorkFreestanding", "OnboardingParisFreestanding", "OnboardingTokyoFreestanding"] {
            let image = try XCTUnwrap(UIImage(named: name)?.cgImage, "Missing bundled asset: \(name)")
            var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 16, height: 16,
                    bitsPerComponent: 8, bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 16))
            }
            for corner in [0, 15, 240, 255] {
                XCTAssertLessThan(pixels[corner * 4 + 3], 5, "Opaque background in \(name)")
            }
            XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 200 },
                          "Asset must contain a visible landmark: \(name)")
        }
    }
}

final class TripMapTests: XCTestCase {
    func testUnknownAirportNeverFallsBackToLosAngeles() {
        XCTAssertNil(AirportLocation.location(for: "???"))
        XCTAssertEqual(AirportLocation.location(for: " lhr ")?.city, "London")
    }

    func testInternationalRouteUsesActualCoordinates() throws {
        let flight = try XCTUnwrap(TripFlight.previewFlights.first { $0.id == "alex-out" })
        let route = try XCTUnwrap(TripMapRoute(flight))
        XCTAssertEqual(route.coordinates.first!.longitude, -0.4543, accuracy: 0.01)
        XCTAssertEqual(route.coordinates.last!.longitude, -118.4085, accuracy: 0.01)
        XCTAssertGreaterThan(route.coordinates.count, 2)
        XCTAssertEqual(route.revealedCoordinates(1).count, route.coordinates.count)
    }

    func testPacificRouteFitsAcrossDateLineInsteadOfAcrossWholeWorld() throws {
        let flight = TripFlight(id: "pacific", traveler: "Lin Zhao", flightNumber: "NH 6",
                                airline: "Example", origin: "NRT", destination: "LAX",
                                departureTime: "17:00", arrivalTime: "11:00", date: Date(),
                                terminal: "B", status: .scheduled, direction: .outbound)
        let route = try XCTUnwrap(TripMapRoute(flight))
        let rect = TripMapRoute.fittingRect(for: [route])
        XCTAssertLessThan(rect.width, MKMapRect.world.width * 0.5)
        XCTAssertGreaterThan(rect.width, 0)
        XCTAssertTrue(rect.origin.x.isFinite)
    }

    func testUnverifiedEntryDoesNotInventRouteOrSortBeforeKnownArrivals() {
        let flight = TripFlight(id: "unknown", traveler: "Lin Zhao", flightNumber: "UA 353",
                                airline: "Not verified", origin: "—", destination: "LAX",
                                departureTime: "—", arrivalTime: "—", date: Date(),
                                terminal: "Not available", status: .unverified, direction: .outbound)
        XCTAssertNil(TripMapRoute(flight))
        XCTAssertEqual(flight.arrivalSortDate, .distantFuture)
    }

    func testReturnArrivalsSortByDateAndDestinationTimezone() throws {
        let flights = TripFlight.previewFlights.filter { $0.direction == .inbound }
            .sorted { $0.arrivalSortDate < $1.arrivalSortDate }
        XCTAssertEqual(flights.map(\.id), ["mia-in", "wang-in", "david-in", "alex-in"])
        let london = try XCTUnwrap(flights.last)
        XCTAssertEqual(london.arrivalDayOffset, 1)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        XCTAssertEqual(calendar.component(.day, from: london.arrivalSortDate), 21)
    }
}

@MainActor
final class TripLibraryTests: XCTestCase {
    private let owner = TripParticipant(id: "owner", name: "Wang Yang", userID: "owner")

    private func cloudTrip(_ id: String, ownerID: String) -> CloudTrip {
        CloudTrip(id: id, name: id, destination_airport: "LAX", start_date: "2035-01-01", end_date: "2035-01-05",
                  completed_at: nil, my_role: "owner", revision: 1,
                  participants: [.init(id: "person-\(id)", name: id, user_id: ownerID)], flights: [])
    }

    func testAccountSwitchStartsNewTripRefreshWhileOldRequestIsStillInFlight() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TripSwitch-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SlowTestRepository(mode: .remote)
        let firstOwner = UUID().uuidString, secondOwner = UUID().uuidString
        await repository.configureTripReads([[cloudTrip("old", ownerID: firstOwner)],
                                             [cloudTrip("new", ownerID: secondOwner)]],
                                            delays: [.milliseconds(90), .milliseconds(220)])
        let library = TripLibrary(directory: directory)
        library.connect(repository)
        library.load(scope: "remote-first-\(firstOwner)", userID: firstOwner)
        let oldRefresh = Task { await library.refresh() }
        let firstReadStarted = await repository.waitForTripReads(1)
        XCTAssertTrue(firstReadStarted)

        library.load(scope: "remote-second-\(secondOwner)", userID: secondOwner)
        XCTAssertFalse(library.isRefreshing)
        let newRefresh = Task { await library.refresh() }
        let secondReadStarted = await repository.waitForTripReads(2)
        XCTAssertTrue(secondReadStarted)
        let oldResult = await oldRefresh.value
        XCTAssertNil(oldResult)
        XCTAssertTrue(library.isRefreshing)
        let newResult = await newRefresh.value
        XCTAssertEqual(newResult, true)
        XCTAssertEqual(library.trips.map(\.id), ["new"])
        XCTAssertFalse(library.isRefreshing)
    }

    func testAccountSwitchKeepsNewTripSaveLockedUntilItsOwnResponse() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TripSaveSwitch-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SlowTestRepository(mode: .remote)
        let firstOwner = UUID().uuidString, secondOwner = UUID().uuidString
        await repository.configureTripWrites([cloudTrip("old", ownerID: firstOwner),
                                              cloudTrip("new", ownerID: secondOwner)],
                                             delays: [.milliseconds(90), .milliseconds(220)])
        let library = TripLibrary(directory: directory)
        library.connect(repository)
        func draft(_ id: String, ownerID: String) -> TripPlan {
            TripPlan(id: id, name: id, destinationAirport: "LAX", startDay: TripDay(value: "2035-01-01"),
                     endDay: TripDay(value: "2035-01-05"),
                     participants: [.init(id: "person-\(id)", name: id, userID: ownerID)], flights: [],
                     creatorUserID: ownerID)
        }
        library.load(scope: "remote-first-\(firstOwner)", userID: firstOwner)
        let oldSave = Task { await library.create(draft("old", ownerID: firstOwner)) }
        let firstWriteStarted = await repository.waitForTripWrites(1)
        XCTAssertTrue(firstWriteStarted)

        library.load(scope: "remote-second-\(secondOwner)", userID: secondOwner)
        XCTAssertFalse(library.isSaving)
        let newSave = Task { await library.create(draft("new", ownerID: secondOwner)) }
        let secondWriteStarted = await repository.waitForTripWrites(2)
        XCTAssertTrue(secondWriteStarted)
        let oldSaved = await oldSave.value
        XCTAssertFalse(oldSaved)
        XCTAssertTrue(library.isSaving)
        let newSaved = await newSave.value
        XCTAssertTrue(newSaved)
        XCTAssertEqual(library.trips.map(\.id), ["new"])
        XCTAssertFalse(library.isSaving)
    }

    func testOldInvitationFailureDoesNotAlertNewAccount() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TripInviteSwitch-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = SlowTestRepository(mode: .remote)
        await repository.configureDismissal(delay: .milliseconds(120), error: .networkUnavailable)
        let library = TripLibrary(directory: directory)
        library.connect(repository)
        library.load(scope: "remote-first", userID: UUID().uuidString)
        let invitation = TripInvitation(id: UUID(), trip_name: "Old invite", trip_id: "old-trip",
                                        destination_airport: "LAX", start_date: "2035-01-01", end_date: "2035-01-05",
                                        inviter_name: "Alex", recipient_name: "Wang", recipient_id: UUID(),
                                        expires_at: "2035-01-01T00:00:00Z")
        let oldDecline = Task { await library.decline(invitation) }
        let dismissalStarted = await repository.waitForDismissalStart()
        XCTAssertTrue(dismissalStarted)
        library.load(scope: "remote-second", userID: UUID().uuidString)
        await oldDecline.value
        XCTAssertNil(library.errorMessage)
    }

    func testFlightReminderEligibilityAndLocalCooldown() async throws {
        let (library, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        library.addExamples(owner: owner)
        var plan = try XCTUnwrap(library.trips.first { $0.id == "example-tokyo" })
        let person = plan.participants[1]
        XCTAssertTrue(library.canRemind(person, in: plan))
        XCTAssertFalse(library.canRemind(owner, in: plan))
        let first = await library.remind(person, tripID: plan.id)
        let repeated = await library.remind(person, tripID: plan.id)
        XCTAssertEqual(first?.status, "queued")
        XCTAssertEqual(repeated?.status, "cooldown")
        var flight = try XCTUnwrap(TripFlight.previewFlights.first { $0.direction == .outbound })
        flight.travelerID = person.id
        plan.flights.append(flight)
        XCTAssertFalse(library.canRemind(person, in: plan))
        plan.flights = []; plan.completedAt = Date()
        XCTAssertFalse(library.canRemind(person, in: plan))
        let disabled = await library.setPlanningReminders(false, tripID: "example-tokyo")
        XCTAssertTrue(disabled)
        let restored = TripLibrary(directory: directory)
        restored.load(scope: "demo-owner", userID: owner.userID)
        XCTAssertEqual(restored.trips.first { $0.id == "example-tokyo" }?.planningRemindersEnabled, false)
    }

    func testLifecycleRemovesOnlyTargetFlightsAndCancelledTripStaysReadOnlyAfterReload() async throws {
        let (library, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        library.addExamples(owner: owner)
        let original = try XCTUnwrap(library.trips.first { $0.id == "example-west" })
        let cannotLeave = await library.changeLifecycle(.leave, tripID: original.id, revision: nil)
        XCTAssertFalse(cannotLeave)
        let cannotRemoveOwner = await library.changeLifecycle(.removeMember, tripID: original.id, participantID: owner.id, revision: nil)
        XCTAssertFalse(cannotRemoveOwner)
        let removed = await library.changeLifecycle(.removeMember, tripID: original.id, participantID: "example-mia", revision: nil)
        XCTAssertTrue(removed)
        var plan = try XCTUnwrap(library.trips.first { $0.id == original.id })
        XCTAssertFalse(plan.participants.contains { $0.id == "example-mia" })
        XCTAssertFalse(plan.flights.contains { $0.travelerID == "example-mia" })
        XCTAssertEqual(plan.flights.count, original.flights.filter { $0.travelerID != "example-mia" }.count)
        let cancelled = await library.changeLifecycle(.cancel, tripID: plan.id, revision: nil)
        XCTAssertTrue(cancelled)
        let restored = TripLibrary(directory: directory)
        restored.load(scope: "demo-owner", userID: owner.userID)
        plan = try XCTUnwrap(restored.trips.first { $0.id == original.id })
        XCTAssertNotNil(plan.cancelledAt)
        XCTAssertEqual(plan.phase(), .past)
        XCTAssertFalse(restored.complete(plan.id, at: nil))
        XCTAssertFalse(restored.deleteFlight(try XCTUnwrap(plan.flights.first { $0.travelerID == owner.id }).id, in: plan.id))
        let deleted = await restored.changeLifecycle(.delete, tripID: plan.id, revision: nil)
        XCTAssertTrue(deleted)
        XCTAssertEqual(restored.trips.count, 3)
        XCTAssertFalse(restored.trips.contains { $0.id == plan.id })
    }

    func testMemberCanLeaveButCannotCancelDeleteOrRemoveAnyone() async throws {
        let (library, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        var plan = trip()
        plan.creatorUserID = "another-owner"
        plan.participants.append(.init(id: "another-owner", name: "Creator", userID: "another-owner"))
        struct Archive: Encodable { let version = 1; let trips: [TripPlan] }
        try JSONEncoder().encode(Archive(trips: [plan])).write(to: directory.appendingPathComponent("demo-owner.json"))
        library.load(scope: "signed-out", userID: nil)
        library.load(scope: "demo-owner", userID: owner.userID)
        for action in [TripLifecycleAction.cancel, .delete, .removeMember] {
            let saved = await library.changeLifecycle(action, tripID: plan.id, participantID: action == .removeMember ? "another-owner" : nil, revision: nil)
            XCTAssertFalse(saved)
        }
        XCTAssertEqual(library.trips.count, 1)
        let left = await library.changeLifecycle(.leave, tripID: plan.id, revision: nil)
        XCTAssertTrue(left)
        let restored = TripLibrary(directory: directory)
        restored.load(scope: "demo-owner", userID: owner.userID)
        XCTAssertTrue(restored.trips.isEmpty)
    }

    private func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func day(_ value: String) -> TripDay {
        TripDay(instant(value + "T12:00:00Z"), timeZone: TimeZone(secondsFromGMT: 0)!)
    }
    private func trip(_ id: String = "first", airport: String = "LAX") -> TripPlan {
        TripPlan(id: id, name: id, destinationAirport: airport,
                 startDay: day("2026-09-05"), endDay: day("2026-09-08"),
                 participants: [owner], flights: [], creatorUserID: owner.userID)
    }
    private func temporaryLibrary() throws -> (TripLibrary, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TripLibraryTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let library = TripLibrary(directory: directory)
        library.load(scope: "demo-owner", userID: owner.userID)
        return (library, directory)
    }

    func testNewAccountStartsEmptyAndOverlappingTripsRemainIndependent() throws {
        let (library, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertTrue(library.trips.isEmpty)
        XCTAssertTrue(library.add(trip()))
        XCTAssertTrue(library.add(trip("second", airport: "JFK")))
        XCTAssertEqual(library.trips(in: .ongoing, at: instant("2026-09-06T12:00:00Z")).count, 2)
        var flight = TripFlight.previewFlights[0]
        flight.travelerID = owner.id
        XCTAssertTrue(library.addFlight(flight, to: "first"))
        XCTAssertFalse(library.addFlight(flight, to: "first"))
        XCTAssertEqual(library.trips[0].flights.count, 1)
        XCTAssertTrue(library.trips[1].flights.isEmpty)
        flight.travelerID = "not-a-member"
        XCTAssertFalse(library.addFlight(flight, to: "second"))
        XCTAssertFalse(library.addFlight(flight, to: "missing"))
    }

    func testPhaseUsesDestinationLocalDateAndIncludesWholeEndDay() {
        let plan = trip()
        XCTAssertEqual(plan.phase(at: instant("2026-09-05T06:59:59Z")), .upcoming)
        XCTAssertEqual(plan.phase(at: instant("2026-09-05T07:00:00Z")), .ongoing)
        XCTAssertEqual(plan.phase(at: instant("2026-09-09T06:59:59Z")), .ongoing)
        XCTAssertEqual(plan.phase(at: instant("2026-09-09T07:00:00Z")), .past)
        let tokyo = trip(airport: "NRT")
        XCTAssertEqual(tokyo.phase(at: instant("2026-09-04T15:00:00Z")), .ongoing)
    }

    func testManualCompletionCanBeUndoneWithoutLosingPeopleOrFlights() throws {
        let (library, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertTrue(library.add(trip()))
        let now = instant("2026-09-06T12:00:00Z")
        XCTAssertTrue(library.complete("first", at: now))
        XCTAssertEqual(library.trips(in: .past, at: now).count, 1)
        XCTAssertTrue(library.complete("first", at: nil))
        XCTAssertEqual(library.trips(in: .ongoing, at: now).count, 1)
        XCTAssertEqual(library.trips[0].participants, [owner])
    }

    func testPersistenceAndAccountIsolation() throws {
        let (library, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertTrue(library.add(trip()))
        let restored = TripLibrary(directory: directory)
        restored.load(scope: "demo-owner", userID: owner.userID)
        XCTAssertEqual(restored.trips.map(\.id), ["first"])
        restored.load(scope: "demo-another-account", userID: "other")
        XCTAssertTrue(restored.trips.isEmpty)
        var other = trip("other")
        other.creatorUserID = "other"
        other.participants = [TripParticipant(id: "other", name: "Other", userID: "other")]
        XCTAssertTrue(restored.add(other))
        restored.load(scope: "demo-owner", userID: owner.userID)
        XCTAssertEqual(restored.trips.map(\.id), ["first"])
    }

    func testCorruptArchiveIsPreservedAndCannotBeOverwritten() throws {
        let (library, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertTrue(library.add(trip()))
        let file = directory.appendingPathComponent("demo-owner.json")
        let original = Data("corrupt fixture".utf8)
        try original.write(to: file)
        let restored = TripLibrary(directory: directory)
        restored.load(scope: "demo-owner", userID: owner.userID)
        XCTAssertNotNil(restored.errorMessage)
        XCTAssertFalse(restored.add(trip("new")))
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testInvalidDatesAndUnknownDestinationsAreRejected() throws {
        let (library, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        var invalid = trip()
        invalid.endDay = day("2026-09-01")
        XCTAssertFalse(library.add(invalid))
        XCTAssertFalse(library.add(trip(airport: "???")))
        XCTAssertTrue(library.add(trip()))
        XCTAssertFalse(library.editTrip("first", name: "first", airport: "LAX", start: day("2026-09-05"), end: day("2026-09-01")))
        XCTAssertEqual(library.trips[0].endDay, day("2026-09-08"))
    }

    func testOwnerCannotAddEditDeleteOrTakeOverAnotherTravelersFlight() throws {
        let (library, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        library.addExamples(owner: owner)
        let plan = try XCTUnwrap(library.trips.first { $0.id == "example-west" })
        var other = try XCTUnwrap(plan.flights.first { $0.travelerID == "example-mia" })
        XCTAssertFalse(library.owns(other, in: plan))
        XCTAssertFalse(library.addFlight(other, to: "example-new-york"))
        XCTAssertFalse(library.editFlight(other, in: plan.id))
        XCTAssertFalse(library.deleteFlight(other.id, in: plan.id))
        other.travelerID = owner.id
        XCTAssertFalse(library.editFlight(other, in: plan.id))
        let mine = try XCTUnwrap(plan.flights.first { $0.travelerID == owner.id })
        XCTAssertTrue(library.editFlight(mine, in: plan.id))
        XCTAssertTrue(library.deleteFlight(mine.id, in: plan.id))
        XCTAssertEqual(library.trips.first { $0.id == plan.id }?.flights.count, plan.flights.count - 1)
    }

    func testLegacyNamesakesAreNotClaimedAndSignedOutCannotWrite() throws {
        let (_, directory) = try temporaryLibrary()
        defer { try? FileManager.default.removeItem(at: directory) }
        var legacy = trip()
        legacy.creatorUserID = nil
        legacy.participants[0].userID = nil
        var flight = TripFlight.previewFlights[0]
        flight.travelerID = owner.id
        legacy.flights = [flight]
        struct Archive: Encodable { let version = 1; let trips: [TripPlan] }
        try JSONEncoder().encode(Archive(trips: [legacy])).write(to: directory.appendingPathComponent("demo-owner.json"))
        let restored = TripLibrary(directory: directory)
        restored.load(scope: "demo-owner", userID: owner.userID)
        let saved = try XCTUnwrap(restored.trips.first)
        XCTAssertNil(restored.selfParticipant(in: saved))
        XCTAssertFalse(restored.canManage(saved))
        XCTAssertFalse(restored.addFlight(flight, to: saved.id))
        XCTAssertFalse(restored.deleteFlight(flight.id, in: saved.id))
        XCTAssertFalse(restored.complete(saved.id, at: Date()))
        restored.load(scope: "demo-owner", userID: nil)
        XCTAssertTrue(restored.trips.isEmpty)
        XCTAssertFalse(restored.add(trip("new")))
        XCTAssertFalse(restored.deleteFlight(flight.id, in: saved.id))
    }
}

final class FriendPresenceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFreshnessTransitions() {
        let fresh = makeFriend(updatedAt: now.addingTimeInterval(-30 * 60))
        let aging = makeFriend(updatedAt: now.addingTimeInterval(-3 * 24 * 60 * 60))
        let stale = makeFriend(updatedAt: now.addingTimeInterval(-15 * 24 * 60 * 60))

        XCTAssertEqual(fresh.freshness(at: now), .fresh)
        XCTAssertEqual(aging.freshness(at: now), .aging)
        XCTAssertEqual(stale.freshness(at: now), .stale)
    }

    func testPausedPresenceIsUnavailableAndNotSameCityEligible() {
        let paused = FriendPresence(
            displayName: "Mia Chen",
            username: "mia",
            city: "New York",
            countryCode: "US",
            updatedAt: now.addingTimeInterval(-60),
            sharingState: .paused
        )

        XCTAssertEqual(paused.freshness(at: now), .unavailable)
        XCTAssertFalse(paused.isSameCityEligible(at: now))
        XCTAssertFalse(paused.cityDisplay.isEmpty)
    }

    func testSameCityMatchingIncludesActiveFriendsAndExcludesPausedOrDifferentCity() {
        let activeNewYork = makeFriend(name: "Mia", city: "New York", updatedAt: now.addingTimeInterval(-60))
        let longStayNewYork = makeFriend(name: "Alex", city: "New York", updatedAt: now.addingTimeInterval(-30 * 24 * 60 * 60))
        let pausedNewYork = makeFriend(name: "Sam", city: "New York", updatedAt: now.addingTimeInterval(-60), sharingState: .paused)
        let freshTokyo = makeFriend(name: "Lin", city: "Tokyo", updatedAt: now.addingTimeInterval(-60))

        let matches = MockFriendData.sameCityFriends(
            from: [activeNewYork, longStayNewYork, pausedNewYork, freshTokyo],
            currentCity: "new york", currentCountryCode: "US",
            now: now, currentAdministrativeArea: "NY", currentUpdatedAt: now
        )

        XCTAssertEqual(matches.map(\.displayName), ["Mia"])
        XCTAssertTrue(activeNewYork.isSameCityEligible(at: now))
        XCTAssertFalse(longStayNewYork.isSameCityEligible(at: now))
        XCTAssertFalse(pausedNewYork.isSameCityEligible(at: now))
    }

    func testCityIdentityIgnoresCaseWhitespaceAndDiacriticsButHonorsKnownCountry() {
        XCTAssertTrue(
            CityIdentity.matches(
                city: "  São   Paulo ",
                countryCode: "BR",
                otherCity: "sao paulo",
                otherCountryCode: nil
            )
        )
        XCTAssertFalse(
            CityIdentity.matches(
                city: "London",
                countryCode: "GB",
                otherCity: "London",
                otherCountryCode: "CA"
            )
        )
    }

    func testProfileValidationNormalizesSafeValues() throws {
        let update = try ProfileUpdate(
            displayName: "  Wang Yang  ",
            username: "@Wang_Yang",
            avatarPalette: 99
        ).validated()

        XCTAssertEqual(update.displayName, "Wang Yang")
        XCTAssertEqual(update.username, "wang_yang")
        XCTAssertEqual(update.avatarPalette, 6)
        XCTAssertThrowsError(
            try ProfileUpdate(displayName: "Name", username: "bad-name", avatarPalette: 1).validated()
        )
    }

    func testInviteLinkParserSupportsAppAndUniversalLinks() {
        let appLink = URL(string: "whereismyfriend://invite/Jamie")!
        let universalLink = URL(string: "https://example.com/invite/priya")!

        XCTAssertEqual(InviteLinkParser.parse(appLink, appScheme: "whereismyfriend")?.username, "jamie")
        XCTAssertEqual(
            InviteLinkParser.parse(universalLink, trustedInviteHosts: ["example.com"])?.username,
            "priya"
        )
        XCTAssertNil(InviteLinkParser.parse(universalLink, trustedInviteHosts: ["friends.example.com"]))
        XCTAssertNil(
            InviteLinkParser.parse(
                URL(string: "https://example.com/profile/jamie")!,
                trustedInviteHosts: ["example.com"]
            )
        )
        XCTAssertNil(InviteLinkParser.parse(URL(string: "whereismyfriend://invite/bad-name")!))
    }

    func testPrivacyPolicyConfigurationRequiresARealHTTPSURL() {
        XCTAssertNil(PrivacyPolicyConfiguration.validated(rawValue: nil))
        XCTAssertNil(PrivacyPolicyConfiguration.validated(rawValue: "http://example.com/privacy"))
        XCTAssertNil(PrivacyPolicyConfiguration.validated(rawValue: "https://example.invalid/privacy"))
        XCTAssertEqual(
            PrivacyPolicyConfiguration.validated(rawValue: "https://example.com/privacy")?.absoluteString,
            "https://example.com/privacy"
        )
    }

    func testSameCityListHonorsCountryCode() {
        let londonCanada = makeFriend(
            name: "Canadian Friend",
            city: "London",
            countryCode: "CA",
            updatedAt: now
        )
        XCTAssertTrue(
            MockFriendData.sameCityFriends(
                from: [londonCanada],
                currentCity: "London",
                currentCountryCode: "GB",
                now: now
            ).isEmpty
        )
    }

    func testAPIConfigurationRejectsPlaceholderAndInsecureOrigins() {
        XCTAssertNil(APIConfiguration.validated(rawValue: "https://api.example.invalid"))
        XCTAssertNil(APIConfiguration.validated(rawValue: "https://staging-api.example.invalid"))
        XCTAssertNil(APIConfiguration.validated(rawValue: "http://api.example.com"))
        XCTAssertEqual(
            APIConfiguration.validated(rawValue: "https://api.example.com")?.baseURL,
            URL(string: "https://api.example.com")
        )
        #if DEBUG
        XCTAssertEqual(
            APIConfiguration.validated(rawValue: "http://127.0.0.1:54321/functions/v1/api")?.baseURL,
            URL(string: "http://127.0.0.1:54321/functions/v1/api")
        )
        #endif
    }

    func testAPIConfigurationPreservesEdgeFunctionPrefixWhenBuildingEndpoint() throws {
        let configuration = try XCTUnwrap(
            APIConfiguration.validated(rawValue: "https://project.supabase.co/functions/v1/api")
        )
        XCTAssertEqual(
            configuration.endpoint(path: "/v1/friends/requests")?.absoluteString,
            "https://project.supabase.co/functions/v1/api/v1/friends/requests"
        )
    }

    func testSupabaseConfigurationRejectsSecretKeys() {
        XCTAssertNil(
            SupabaseConfiguration.validated(
                projectURL: "https://project.supabase.co",
                publishableKey: "sb_" + "secret_do-not-ship"
            )
        )
        XCTAssertNotNil(
            SupabaseConfiguration.validated(
                projectURL: "https://project.supabase.co",
                publishableKey: "sb_publishable_test"
            )
        )
    }

    func testAppleSignInNonceIsRandomAndHashable() throws {
        let first = try AppleSignInNonce.make()
        let second = try AppleSignInNonce.make()
        XCTAssertEqual(first.count, 32)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(
            AppleSignInNonce.sha256("test"),
            "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        )
    }

    func testCountryCodeBuildsFlag() {
        XCTAssertEqual(makeFriend(countryCode: "US", updatedAt: now).countryFlag, "🇺🇸")
        XCTAssertEqual(makeFriend(countryCode: nil, updatedAt: now).countryFlag, "")
    }

    func testCityEmblemResolutionAndAliases() {
        let ny = CityEmblem.resolve(city: "New York", countryCode: "US")
        XCTAssertEqual(ny.cityID, "new_york")
        XCTAssertEqual(ny.assetName, "City_new_york")

        let nyc = CityEmblem.resolve(city: "NYC", countryCode: "US")
        XCTAssertEqual(nyc.cityID, "new_york")

        let tokyo = CityEmblem.resolve(city: "  shinjuku ", countryCode: "JP")
        XCTAssertEqual(tokyo.cityID, "tokyo")
        XCTAssertEqual(tokyo.assetName, "City_tokyo")

        let sf = CityEmblem.resolve(city: "San Francisco")
        XCTAssertEqual(sf.cityID, "san_francisco")
        XCTAssertEqual(sf.assetName, "City_san_francisco")

        let beijing = CityEmblem.resolve(city: "Peking")
        XCTAssertEqual(beijing.cityID, "beijing")

        let fallbackFrench = CityEmblem.resolve(city: "Strasbourg", countryCode: "FR")
        XCTAssertEqual(fallbackFrench.archetype, .european)
        XCTAssertNil(fallbackFrench.assetName)

        let fallbackKorean = CityEmblem.resolve(city: "Daegu", countryCode: "KR")
        XCTAssertEqual(fallbackKorean.archetype, .asian)
        XCTAssertNil(fallbackKorean.assetName)
    }

    func testUniversalCityFallbackAndUnknownLocationAssets() throws {
        let bakersfield = CityEmblem.resolve(city: "Bakersfield", countryCode: "US", administrativeArea: "CA")
        XCTAssertEqual(bakersfield.cityID, "bakersfield")
        XCTAssertNil(bakersfield.assetName)
        XCTAssertEqual(bakersfield.displayName, "Bakersfield")
        XCTAssertEqual(bakersfield.archetype, .centralValley)
        XCTAssertEqual(bakersfield.fallbackAssetName, "City_archetype_central_valley")

        let fremont = CityEmblem.resolve(city: "Fremont", countryCode: "US", administrativeArea: "CA")
        XCTAssertEqual(fremont.cityID, "fremont")
        XCTAssertNil(fremont.assetName)
        XCTAssertEqual(fremont.displayName, "Fremont")
        XCTAssertEqual(fremont.archetype, .siliconValley)
        XCTAssertEqual(fremont.fallbackAssetName, "City_archetype_silicon_valley")

        let unknown = CityEmblem.resolve(city: nil)
        XCTAssertEqual(unknown.cityID, "unknown")
        XCTAssertEqual(unknown.displayName, "Somewhere")
        XCTAssertEqual(unknown.fallbackAssetName, "City_unknown_location")

        let testedAssets = [
            "City_generic_block",
            "City_unknown_location",
            "City_archetype_central_valley",
            "City_archetype_silicon_valley",
            "City_archetype_pacific_surf",
            "City_archetype_desert_adobe",
            "City_archetype_historic_brick"
        ]

        for assetName in testedAssets {
            let image = try XCTUnwrap(UIImage(named: assetName)?.cgImage, "Missing bundled asset: \(assetName)")
            var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
            try pixels.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(
                    data: bytes.baseAddress, width: 16, height: 16,
                    bitsPerComponent: 8, bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ))
                context.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 16))
            }
            for corner in [0, 15, 240, 255] {
                XCTAssertLessThan(pixels[corner * 4 + 3], 15, "Opaque background corner in \(assetName)")
            }
            XCTAssertTrue(stride(from: 3, to: pixels.count, by: 4).contains { pixels[$0] > 200 },
                          "Asset must contain visible opaque content: \(assetName)")
        }
    }

    func testSmartArchetypeCascadeMappingEngine() {
        // Tier 1: Explicit Sub-Regional Dictionary
        XCTAssertEqual(CityArchetype.infer(from: "Bakersfield", countryCode: "US", administrativeArea: "CA"), .centralValley)
        XCTAssertEqual(CityArchetype.infer(from: "Fresno", countryCode: "US", administrativeArea: "CA"), .centralValley)
        XCTAssertEqual(CityArchetype.infer(from: "Fremont", countryCode: "US", administrativeArea: "CA"), .siliconValley)
        XCTAssertEqual(CityArchetype.infer(from: "Palo Alto", countryCode: "US", administrativeArea: "CA"), .siliconValley)
        XCTAssertEqual(CityArchetype.infer(from: "Santa Cruz", countryCode: "US", administrativeArea: "CA"), .pacificSurf)
        XCTAssertEqual(CityArchetype.infer(from: "Laguna Beach", countryCode: "US", administrativeArea: "CA"), .pacificSurf)
        XCTAssertEqual(CityArchetype.infer(from: "Lake Tahoe", countryCode: "US", administrativeArea: "CA"), .alpineChalet)
        XCTAssertEqual(CityArchetype.infer(from: "Aspen", countryCode: "US", administrativeArea: "CO"), .alpineChalet)
        XCTAssertEqual(CityArchetype.infer(from: "Palm Springs", countryCode: "US", administrativeArea: "CA"), .desertAdobe)
        XCTAssertEqual(CityArchetype.infer(from: "Sedona", countryCode: "US", administrativeArea: "AZ"), .desertAdobe)
        XCTAssertEqual(CityArchetype.infer(from: "Oxford", countryCode: "GB"), .historicBrick)
        XCTAssertEqual(CityArchetype.infer(from: "Heidelberg", countryCode: "DE"), .historicBrick)

        // Tier 2: State / National Regional Heuristics
        XCTAssertEqual(CityArchetype.infer(from: "SomeSmallTown", countryCode: "US", administrativeArea: "AZ"), .desertAdobe)
        XCTAssertEqual(CityArchetype.infer(from: "PineTown", countryCode: "US", administrativeArea: "WA"), .siliconValley)
        XCTAssertEqual(CityArchetype.infer(from: "SnowVillage", countryCode: "US", administrativeArea: "CO"), .alpineChalet)
        XCTAssertEqual(CityArchetype.infer(from: "FarmTown", countryCode: "US", administrativeArea: "IA"), .centralValley)
        XCTAssertEqual(CityArchetype.infer(from: "SunnyTown", countryCode: "US", administrativeArea: "FL"), .pacificSurf)
        XCTAssertEqual(CityArchetype.infer(from: "AlpenDorf", countryCode: "CH"), .alpineChalet)

        // Tier 3: Semantic Keyword Sniffing
        XCTAssertEqual(CityArchetype.infer(from: "Sunny Beach", countryCode: "FR"), .pacificSurf)
        XCTAssertEqual(CityArchetype.infer(from: "Eagle Mountain", countryCode: "FR"), .alpineChalet)
        XCTAssertEqual(CityArchetype.infer(from: "Cactus Desert", countryCode: "MX"), .desertAdobe)
        XCTAssertEqual(CityArchetype.infer(from: "Green Valley", countryCode: "FR"), .centralValley)
        XCTAssertEqual(CityArchetype.infer(from: "Old Abbey", countryCode: "CA"), .historicBrick)
    }

    func testHiddenPresenceNeverRevealsCachedGeographyThroughArtwork() {
        var friend = FriendPresence(displayName: "Example", username: "example", city: "New York",
                                    countryCode: "US", updatedAt: Date(), administrativeArea: "NY")
        XCTAssertEqual(CityEmblem.resolve(friend: friend).assetName, "City_new_york")
        for state in [PresenceSharingState.paused, .unavailable] {
            friend.sharingState = state
            let artwork = CityEmblemView(friend: friend, size: 36).emblem
            XCTAssertNil(artwork.assetName)
            XCTAssertNil(artwork.countryCode)
            XCTAssertEqual(artwork.fallbackAssetName, "City_unknown_location")
            XCTAssertEqual(artwork.displayName, friend.cityDisplay)
            XCTAssertFalse(artwork.displayName.contains("New York"))
        }
        let empty = CityEmblem.resolve(city: "  ", countryCode: "US")
        XCTAssertEqual(empty.fallbackAssetName, "City_unknown_location")
    }

    func testArchetypeRulesRespectMetadataAndWholeWords() {
        for (short, full) in [("CA", "California"), ("AZ", "Arizona"), ("WA", "Washington"), ("CO", "Colorado"), ("ME", "Maine")] {
            XCTAssertEqual(CityArchetype.infer(from: "Example Town", countryCode: "US", administrativeArea: short),
                           CityArchetype.infer(from: "Example Town", countryCode: "us", administrativeArea: full))
        }
        XCTAssertEqual(CityArchetype.infer(from: "Bakersfield", countryCode: nil, administrativeArea: "CA"), .metropolis)
        XCTAssertEqual(CityArchetype.infer(from: "Fremont", countryCode: "US"), .metropolis)
        XCTAssertEqual(CityArchetype.infer(from: "Cambridge", countryCode: "US", administrativeArea: "CA"), .metropolis)
        XCTAssertNotEqual(CityArchetype.infer(from: "Jackson", countryCode: "US", administrativeArea: "FL"), .alpineChalet)
        XCTAssertEqual(CityArchetype.infer(from: "Testskiville", countryCode: "MX"), .metropolis)
        XCTAssertEqual(CityArchetype.infer(from: "Turkey", countryCode: "MX"), .metropolis)
        XCTAssertEqual(CityArchetype.infer(from: "Greenfield", countryCode: "MX"), .metropolis)
        XCTAssertEqual(CityArchetype.infer(from: "Sunny Beach", countryCode: "MX"), .pacificSurf)
        XCTAssertEqual(CityArchetype.alpineChalet.assetName, "City_generic_block")
    }

    func testSharedArchetypeDoesNotMeanSameCity() {
        let now = Date()
        let a = CityEmblem.resolve(city: "Bakersfield", countryCode: "US", administrativeArea: "CA")
        let b = CityEmblem.resolve(city: "Fresno", countryCode: "US", administrativeArea: "California")
        XCTAssertEqual(a.fallbackAssetName, b.fallbackAssetName)
        let me = CurrentUserPresence(administrativeArea: "CA", city: "Bakersfield", countryCode: "US", updatedAt: now, source: .manual)
        let friend = FriendPresence(displayName: "Example", username: "example", city: "Fresno", countryCode: "US", updatedAt: now, administrativeArea: "California")
        XCTAssertFalse(PresenceMatchPolicy.matches(me, friend, at: now))
    }

    private func makeFriend(
        name: String = "Test Friend",
        city: String = "New York",
        countryCode: String? = "US",
        updatedAt: Date,
        sharingState: PresenceSharingState = .active
    ) -> FriendPresence {
        FriendPresence(
            displayName: name,
            username: name.lowercased().replacingOccurrences(of: " ", with: ""),
            city: city,
            countryCode: countryCode,
            updatedAt: updatedAt,
            sharingState: sharingState,
            administrativeArea: city == "New York" ? "NY" : "Tokyo"
        )
    }
}

final class LocalDemoRepositoryTests: XCTestCase {
    func testAcceptingIncomingRequestCreatesFriendAndPreferences() async throws {
        let initial = DemoData.initialSnapshot()
        let request = try XCTUnwrap(initial.incomingRequests.first)
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)

        let updated = try await repository.respond(to: request.id, response: .accept)

        XCTAssertTrue(updated.friends.contains(where: { $0.id == request.userID }))
        XCTAssertFalse(updated.friendRequests.contains(where: { $0.id == request.id }))
        XCTAssertTrue(updated.preference(for: request.userID).sharesMyCity)
    }

    func testSendingKnownUsernameCreatesOutgoingRequest() async throws {
        var initial = DemoData.initialSnapshot()
        initial.friendRequests.removeAll { $0.username == "leo" }
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)

        let updated = try await repository.sendFriendRequest(username: "@leo")

        XCTAssertTrue(updated.outgoingRequests.contains(where: { $0.username == "leo" }))
    }

    func testDuplicateAndUnknownInvitesAreRejected() async throws {
        let repository = LocalDemoRepository(snapshot: DemoData.initialSnapshot(), persistsChanges: false)

        do {
            _ = try await repository.sendFriendRequest(username: "mia")
            XCTFail("Expected an already-friends error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .alreadyFriends)
        }

        do {
            _ = try await repository.sendFriendRequest(username: "nobody")
            XCTFail("Expected a user-not-found error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .userNotFound)
        }
    }

    func testSameCityEventIsIdempotentForRepeatedPresenceUpload() async throws {
        var initial = DemoData.initialSnapshot()
        initial.colocationEvents = []
        initial.colocationSessions = []
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)

        let first = try await repository.updateCurrentCity(city: "New York", countryCode: "US", source: .manual, observedAt: Date(), administrativeArea: "NY")
        let second = try await repository.updateCurrentCity(city: "New York", countryCode: "US", source: .manual, observedAt: Date(), administrativeArea: "NY")

        XCTAssertEqual(first.colocationEvents.count, 1)
        XCTAssertEqual(second.colocationEvents.count, 1)
        XCTAssertEqual(first.colocationEvents.first?.deduplicationKey, second.colocationEvents.first?.deduplicationKey)
    }

    func testColocationRequiresExitAndCooldownBeforeAnotherEvent() throws {
        let enteredAt = Date(timeIntervalSince1970: 1_900_000_000)
        var snapshot = DemoData.initialSnapshot(now: enteredAt)
        let friendID = try XCTUnwrap(snapshot.friends.first?.id)
        snapshot.friends = [try XCTUnwrap(snapshot.friends.first)]
        snapshot.friends[0].city = "New York"
        snapshot.friends[0].countryCode = "US"
        snapshot.friends[0].updatedAt = enteredAt.addingTimeInterval(-60)
        snapshot.friendPreferences = [
            FriendAccessPreference(friendID: friendID, sharesMyCity: true, sameCityAlertEnabled: true)
        ]
        snapshot.currentPresence = CurrentUserPresence(
            administrativeArea: "NY",
            city: "New York",
            countryCode: "US",
            updatedAt: enteredAt,
            source: .manual
        )
        snapshot.colocationEvents = []
        snapshot.colocationSessions = []

        ColocationEvaluator.evaluate(snapshot: &snapshot, now: enteredAt)
        XCTAssertEqual(snapshot.colocationEvents.count, 1)
        XCTAssertEqual(snapshot.colocationSessions.filter(\.isActive).count, 1)

        snapshot.friends[0].city = "Tokyo"
        ColocationEvaluator.evaluate(snapshot: &snapshot, now: enteredAt.addingTimeInterval(60 * 60))
        XCTAssertEqual(snapshot.colocationSessions.filter(\.isActive).count, 0)

        snapshot.friends[0].city = "New York"
        snapshot.friends[0].updatedAt = enteredAt.addingTimeInterval(2 * 60 * 60)
        ColocationEvaluator.evaluate(snapshot: &snapshot, now: enteredAt.addingTimeInterval(2 * 60 * 60))
        XCTAssertEqual(snapshot.colocationEvents.count, 1)

        snapshot.friends[0].updatedAt = enteredAt.addingTimeInterval(7 * 60 * 60)
        snapshot.currentPresence.updatedAt = enteredAt.addingTimeInterval(7 * 60 * 60)
        ColocationEvaluator.evaluate(snapshot: &snapshot, now: enteredAt.addingTimeInterval(7 * 60 * 60))
        XCTAssertEqual(snapshot.colocationEvents.count, 2)
    }

    func testProfileBlockAndUnblockLifecycle() async throws {
        let initial = DemoData.initialSnapshot()
        let friend = try XCTUnwrap(initial.friends.first)
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)

        let profile = try await repository.updateProfile(
            ProfileUpdate(displayName: "New Name", username: "new_name", avatarPalette: 4)
        )
        XCTAssertEqual(profile.currentUser.username, "new_name")

        let blocked = try await repository.blockUser(id: friend.id)
        XCTAssertFalse(blocked.friends.contains(where: { $0.id == friend.id }))
        XCTAssertTrue(blocked.blockedPeople.contains(where: { $0.id == friend.id }))
        XCTAssertFalse(blocked.colocationEvents.contains(where: { $0.friendIDs.contains(friend.id) }))

        let unblocked = try await repository.unblockUser(id: friend.id)
        XCTAssertFalse(unblocked.blockedUserIDs.contains(friend.id))
    }

    func testSignOutClearsSensitiveWidgetSnapshotData() async throws {
        let repository = LocalDemoRepository(snapshot: DemoData.initialSnapshot(), persistsChanges: false)

        let signedOut = try await repository.signOut()

        XCTAssertFalse(signedOut.isAuthenticated)
        XCTAssertTrue(signedOut.friends.isEmpty)
        XCTAssertNil(signedOut.currentPresence.city)
        XCTAssertTrue(signedOut.colocationEvents.isEmpty)
    }

    func testFriendPreferencesAreIndependent() async throws {
        let initial = DemoData.initialSnapshot()
        let firstFriend = try XCTUnwrap(initial.friends.first)
        let repository = LocalDemoRepository(snapshot: initial, persistsChanges: false)
        let changed = FriendAccessPreference(
            friendID: firstFriend.id,
            sharesMyCity: false,
            sameCityAlertEnabled: false
        )

        let updated = try await repository.setFriendPreference(changed)

        XCTAssertEqual(updated.preference(for: firstFriend.id), changed)
        XCTAssertTrue(updated.friendPreferences.filter { $0.friendID != firstFriend.id }.allSatisfy(\.sharesMyCity))
    }
}

final class OfflineMutationQueueTests: XCTestCase {
    func testQueueCoalescesAndBacksOffFailedMutations() async throws {
        let suiteName = "OfflineMutationQueueTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let queue = OfflineMutationQueue(defaults: defaults, storageKey: "queue")
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let ownerID = UUID()

        await queue.enqueue(
            .presence(PendingPresenceUpload(city: "London", countryCode: "GB", source: .manual, clientUpdatedAt: now)),
            ownerID: ownerID,
            now: now
        )
        await queue.enqueue(
            .presence(PendingPresenceUpload(city: "Tokyo", countryCode: "JP", source: .visit, clientUpdatedAt: now)),
            ownerID: ownerID,
            now: now
        )
        await queue.enqueue(.pushToken("token"), ownerID: ownerID, now: now)

        let queuedCount = await queue.count(ownerID: ownerID)
        XCTAssertEqual(queuedCount, 2)
        let due = await queue.due(ownerID: ownerID, at: now)
        XCTAssertEqual(due.count, 2)
        guard let presence = due.first(where: { $0.payload.coalescingKey == "presence" }) else {
            return XCTFail("Expected a coalesced presence mutation")
        }
        if case .presence(let upload) = presence.payload {
            XCTAssertEqual(upload.city, "Tokyo")
        } else {
            XCTFail("Expected a presence mutation")
        }

        await queue.markFailed(id: presence.id, now: now)
        let tooEarly = await queue.due(ownerID: ownerID, at: now.addingTimeInterval(14))
        let retryReady = await queue.due(ownerID: ownerID, at: now.addingTimeInterval(15))
        XCTAssertFalse(tooEarly.contains(where: { $0.id == presence.id }))
        XCTAssertTrue(retryReady.contains(where: { $0.id == presence.id }))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testQueueNeverReturnsAnotherAccountsMutations() async throws {
        let suiteName = "OfflineMutationQueueIsolationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let queue = OfflineMutationQueue(defaults: defaults, storageKey: "queue")
        let firstOwner = UUID()
        let secondOwner = UUID()

        await queue.enqueue(.pushToken("first"), ownerID: firstOwner)
        await queue.enqueue(.pushToken("second"), ownerID: secondOwner)

        let firstMutations = await queue.all(ownerID: firstOwner)
        let secondMutations = await queue.all(ownerID: secondOwner)
        XCTAssertEqual(firstMutations.count, 1)
        XCTAssertEqual(secondMutations.count, 1)
        XCTAssertEqual(firstMutations.first?.ownerID, firstOwner)
        XCTAssertEqual(secondMutations.first?.ownerID, secondOwner)
        defaults.removePersistentDomain(forName: suiteName)
    }
}

final class RemoteAppRepositoryTests: XCTestCase {
    func testUsernameConflictAfterTokenRefreshDoesNotSignOutTheUser() async throws {
        let setup = try makeRepository()
        setup.tokenStore.configureRefresh(.success("refreshed"))
        StubURLProtocol.setHandler { request in
            request.value(forHTTPHeaderField: "Authorization") == "Bearer token"
                ? .response(statusCode: 401, data: Data())
                : .response(statusCode: 409, data: Data(#"{"message":"That username is already taken."}"#.utf8))
        }
        do {
            _ = try await setup.repository.updateProfile(ProfileUpdate(displayName: "Name", username: "taken", avatarPalette: 1))
            XCTFail("Expected a conflict")
        } catch { XCTAssertEqual(error as? RepositoryError, .message("That username is already taken.")) }
        XCTAssertNotNil(setup.tokenStore.load())
    }

    func testNetworkFailureDuringTokenRefreshPreservesSession() async throws {
        let setup = try makeRepository()
        setup.tokenStore.configureRefresh(.failure(.networkUnavailable))
        StubURLProtocol.setHandler { _ in .response(statusCode: 401, data: Data()) }
        do {
            _ = try await setup.repository.updateProfile(ProfileUpdate(displayName: "Name", username: "valid_name", avatarPalette: 1))
            XCTFail("Expected a connection error")
        } catch { XCTAssertEqual(error as? RepositoryError, .networkUnavailable) }
        XCTAssertNotNil(setup.tokenStore.load())
    }
    func testProfileRequestIsAuthenticatedBoundedAndReturnsConfirmedFields() async throws {
        let setup = try makeRepository()
        var confirmed = DemoData.initialSnapshot()
        confirmed.currentUser.displayName = "New Name"
        confirmed.currentUser.username = "new_username"
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(confirmed)
        StubURLProtocol.setHandler { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/v1/profile")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            XCTAssertEqual(request.timeoutInterval, 15)
            let body = (try? JSONSerialization.jsonObject(with: requestBodyData(request) ?? Data())) as? [String: Any]
            XCTAssertEqual(body?["displayName"] as? String, "New Name")
            XCTAssertEqual(body?["username"] as? String, "new_username")
            return .response(statusCode: 200, data: data)
        }
        let result = try await setup.repository.updateProfile(ProfileUpdate(displayName: " New Name ", username: "@NEW_USERNAME", avatarPalette: 1))
        XCTAssertEqual(result.currentUser.username, "new_username")
        XCTAssertEqual(result.currentUser.displayName, "New Name")
    }

    private var cloudTripJSON: String {
        #"{"id":"cloud-one","name":"Together","destination_airport":"LAX","start_date":"2026-09-07","end_date":"2026-09-10","completed_at":null,"my_role":"owner","revision":4,"participants":[{"id":"participant-one","name":"Alice","user_id":"10000000-0000-0000-0000-000000000001"}],"flights":[]}"#
    }

    func testTripRequestsUseUserTokenAndOnlyPerResourceFields() async throws {
        let setup = try makeRepository()
        let response = Data(cloudTripJSON.utf8)
        var body: [String: Any] = [:]
        var capturedPath: String?
        StubURLProtocol.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            capturedPath = request.url?.path
            body = (try? JSONSerialization.jsonObject(with: requestBodyData(request) ?? Data()) as? [String: Any]) ?? [:]
            return .response(statusCode: 200, data: response)
        }
        let result = try await setup.repository.mutateTrip(id: "cloud-one", mutation: TripMutation(kind: "editFlight",
            payload: TripPayload(id: "my-flight", flightNumber: "UA353", date: "2026-09-07", direction: "outbound", candidateID: "EWR-LAX"), revision: 7))
        XCTAssertEqual(result.name, "Together")
        XCTAssertEqual(capturedPath, "/v1/trips/cloud-one/mutations")
        XCTAssertEqual(body["revision"] as? Int, 7)
        let payload = try XCTUnwrap(body["payload"] as? [String: Any])
        XCTAssertNil(payload["participants"])
        XCTAssertNil(payload["travelerID"])
        XCTAssertNil(payload["status"])
        XCTAssertEqual(payload["candidateID"] as? String, "EWR-LAX")
    }

    func testTripPermissionDenialDoesNotSignUserOut() async throws {
        let setup = try makeRepository()
        StubURLProtocol.setHandler { _ in .response(statusCode: 403, data: Data(#"{"message":"Trip access denied."}"#.utf8)) }
        do {
            _ = try await setup.repository.fetchTrips()
            XCTFail("Expected access denied")
        } catch { XCTAssertEqual(error as? RepositoryError, .message("Trip access denied.")) }
        XCTAssertEqual(setup.tokenStore.load(), "token")
    }

    func testTripRemindersUseOnlyAuthenticatedContextAndTarget() async throws {
        let setup = try makeRepository()
        var paths: [String] = []
        StubURLProtocol.setHandler { request in
            paths.append(request.url?.path ?? "")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            let body = (try? JSONSerialization.jsonObject(with: requestBodyData(request) ?? Data())) as? [String: Any]
            XCTAssertNil(body?["userID"]); XCTAssertNil(body?["senderID"])
            if request.url?.path == "/v1/trip-reminders/context" {
                XCTAssertEqual(body?["timeZone"] as? String, "America/Los_Angeles")
                return .response(statusCode: 200, data: Data(#"{"success":true}"#.utf8))
            }
            XCTAssertEqual(body?["participantID"] as? String, "target-person")
            return .response(statusCode: 200, data: Data(#"{"status":"cooldown","nextAllowedAt":"2035-01-01T09:00:00Z"}"#.utf8))
        }
        try await setup.repository.updateTripReminderContext(.init(timeZone: "America/Los_Angeles", locale: "en"))
        let reminder = try await setup.repository.remindTripMember(tripID: "cloud-one", participantID: "target-person")
        XCTAssertEqual(reminder.status, "cooldown")
        XCTAssertEqual(paths, ["/v1/trip-reminders/context", "/v1/trips/cloud-one/reminders"])
    }

    @MainActor
    func testTripLifecycleWaitsForConfirmationAndReusesRequestIDAfterLostResponse() async throws {
        let setup = try makeRepository()
        let response = Data("{\"trips\":[\(cloudTripJSON)]}".utf8)
        StubURLProtocol.setHandler { request in
            .response(statusCode: 200, data: request.url?.path == "/v1/trip-invitations" ? Data(#"{"invitations":[]}"#.utf8) : response)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TripLifecycleTest-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TripLibrary(directory: directory)
        let userID = "10000000-0000-0000-0000-000000000001"
        library.connect(setup.repository)
        library.load(scope: "remote-one-\(userID)", userID: userID)
        await library.refresh()
        var requestIDs: [String] = []
        var attempt = 0
        StubURLProtocol.setHandler { request in
            XCTAssertEqual(request.url?.path, "/v1/trips/cloud-one/lifecycle")
            let body = (try? JSONSerialization.jsonObject(with: requestBodyData(request) ?? Data())) as? [String: Any]
            requestIDs.append(body?["requestID"] as? String ?? "")
            XCTAssertNil(body?["userID"])
            XCTAssertNil(body?["participantID"])
            XCTAssertEqual(body?["revision"] as? Int, 4)
            attempt += 1
            return attempt == 1 ? .failure(URLError(.networkConnectionLost)) : .response(statusCode: 200, data: Data(#"{"success":true,"trip":null}"#.utf8))
        }
        let first = await library.changeLifecycle(.delete, tripID: "cloud-one", revision: 4)
        XCTAssertFalse(first)
        XCTAssertEqual(library.trips.count, 1)
        let second = await library.changeLifecycle(.delete, tripID: "cloud-one", revision: 4)
        XCTAssertTrue(second)
        XCTAssertTrue(library.trips.isEmpty)
        XCTAssertEqual(requestIDs.count, 2)
        XCTAssertEqual(requestIDs.first, requestIDs.last)
        XCTAssertFalse(requestIDs.first?.isEmpty ?? true)
        let restored = TripLibrary(directory: directory)
        restored.load(scope: "remote-one-\(userID)", userID: userID)
        XCTAssertTrue(restored.trips.isEmpty)
    }

    @MainActor
    func testCloudLibraryCachesReadsButDoesNotPretendOfflineWritesSucceeded() async throws {
        let setup = try makeRepository()
        let response = Data("{\"trips\":[\(cloudTripJSON)]}".utf8)
        StubURLProtocol.setHandler { request in
            .response(statusCode: 200, data: request.url?.path == "/v1/trip-invitations" ? Data(#"{"invitations":[]}"#.utf8) : response)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TripCloudTest-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = TripLibrary(directory: directory)
        let userID = "10000000-0000-0000-0000-000000000001"
        library.connect(setup.repository)
        library.load(scope: "remote-one-\(userID)", userID: userID)
        let initialRefresh = await library.refresh()
        XCTAssertEqual(initialRefresh, true)
        XCTAssertEqual(library.trips.first?.name, "Together")
        XCTAssertNotNil(library.lastSyncedAt)
        XCTAssertTrue(library.canManage(try XCTUnwrap(library.trips.first)))
        let cached = TripLibrary(directory: directory)
        cached.connect(setup.repository)
        cached.load(scope: "remote-one-\(userID)", userID: userID)
        XCTAssertEqual(cached.trips.count, 1)
        StubURLProtocol.setHandler { _ in .failure(URLError(.notConnectedToInternet)) }
        let failedRefresh = await library.refresh()
        XCTAssertEqual(failedRefresh, false)
        XCTAssertTrue(library.syncFailed)
        XCTAssertEqual(library.trips.count, 1)
        let saved = await library.saveDetails("cloud-one", name: "Offline edit", airport: "LAX",
            start: TripDay(value: "2026-09-07"), end: TripDay(value: "2026-09-10"), revision: 4)
        XCTAssertFalse(saved)
        XCTAssertEqual(library.trips.first?.name, "Together")
        XCTAssertTrue(library.errorMessage?.contains("Reconnect") == true)
        cached.load(scope: "remote-other-\(userID)", userID: userID)
        XCTAssertTrue(cached.trips.isEmpty)
        library.load(scope: "signed-out", userID: nil)
        XCTAssertTrue(library.trips.isEmpty)
        XCTAssertTrue(library.invitations.isEmpty)
    }

    private let installationID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!

    override func tearDown() {
        StubURLProtocol.setHandler(nil)
        SharedAppStateStore.reset()
        super.tearDown()
    }

    func testExpiredSessionClearsToken() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        StubURLProtocol.setHandler { _ in .response(statusCode: 401, data: Data()) }

        do {
            _ = try await setup.repository.loadSnapshot()
            XCTFail("Expected the expired session to fail")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .sessionExpired)
        }
        XCTAssertNil(setup.tokenStore.load())
    }

    func testExpiredSessionDuringPushRegistrationClearsToken() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        StubURLProtocol.setHandler { _ in .response(statusCode: 403, data: Data()) }

        do {
            try await setup.repository.registerPushToken("push-token")
            XCTFail("Expected the expired session to fail")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .sessionExpired)
        }
        XCTAssertNil(setup.tokenStore.load())
    }

    func testAccountDeletionUsesDeleteEndpointAndClearsLocalSession() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let response = try encoder.encode(DemoData.signedOutSnapshot())
        var capturedMethod: String?
        var capturedPath: String?
        StubURLProtocol.setHandler { request in
            capturedMethod = request.httpMethod
            capturedPath = request.url?.path
            return .response(statusCode: 200, data: response)
        }

        setup.tokenStore.configureSignOutFailure(.networkUnavailable)
        let snapshot = try await setup.repository.deleteAccount()

        XCTAssertEqual(capturedMethod, "DELETE")
        XCTAssertEqual(capturedPath, "/v1/account")
        XCTAssertFalse(snapshot.isAuthenticated)
        XCTAssertNil(setup.tokenStore.load())
    }

    func testStagingTestFlightSendsItsOwnBundleIDWithProductionAPNs() async throws {
        let setup = try makeRepository(push: APNsRegistrationConfiguration(environment: .production,
            installationID: installationID, bundleID: "com.yangwy30.whereismyfriend.staging"))
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        var captured: [String: Any] = [:]
        StubURLProtocol.setHandler { request in
            if let data = requestBodyData(request) { captured = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:] }
            return .response(statusCode: 204, data: Data())
        }
        try await setup.repository.registerPushToken("test-token")
        XCTAssertEqual(captured["bundleID"] as? String, "com.yangwy30.whereismyfriend.staging")
        XCTAssertEqual(captured["environment"] as? String, "production")
    }

    func testPushRegistrationSendsStableInstallationAndSandboxEnvironment() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        var requestBody: [String: Any] = [:]
        StubURLProtocol.setHandler { request in
            if let data = requestBodyData(request),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                requestBody = object
            }
            return .response(statusCode: 204, data: Data())
        }

        try await setup.repository.registerPushToken(String(repeating: "ab", count: 32))

        XCTAssertEqual(requestBody["token"] as? String, String(repeating: "ab", count: 32))
        XCTAssertEqual(requestBody["platform"] as? String, "ios")
        XCTAssertEqual(requestBody["environment"] as? String, "sandbox")
        XCTAssertEqual(
            (requestBody["installationID"] as? String)?.lowercased(),
            installationID.uuidString.lowercased()
        )
        let isPending = await setup.repository.isPushRegistrationPending()
        XCTAssertFalse(isPending)
    }

    func testOfflinePushRegistrationReportsThatItIsWaitingForNetwork() async throws {
        let setup = try makeRepository()
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: setup.repository.storageScope)
        StubURLProtocol.setHandler { _ in .failure(URLError(.notConnectedToInternet)) }

        try await setup.repository.registerPushToken(String(repeating: "cd", count: 32))

        let isPending = await setup.repository.isPushRegistrationPending()
        XCTAssertTrue(isPending)
    }

    func testTerminalQueuedMutationIsRemovedInsteadOfBlockingFutureSync() async throws {
        let setup = try makeRepository()
        let snapshot = DemoData.initialSnapshot()
        SharedAppStateStore.save(snapshot, origin: setup.repository.storageScope)
        await setup.queue.enqueue(
            .sharingPreferences(snapshot.sharingPreferences),
            ownerID: snapshot.currentUser.id
        )
        StubURLProtocol.setHandler { _ in
            .response(statusCode: 400, data: Data(#"{"message":"invalid preference"}"#.utf8))
        }

        do {
            _ = try await setup.repository.retryPendingOperations()
            XCTFail("Expected a terminal server error")
        } catch {
            XCTAssertEqual(error as? RepositoryError, .message("invalid preference"))
        }
        let pendingCount = await setup.queue.count(ownerID: snapshot.currentUser.id)
        XCTAssertEqual(pendingCount, 0)
    }

    func testOfflinePauseSharingAppliesLocallyAndQueuesRetry() async throws {
        let setup = try makeRepository()
        var snapshot = DemoData.initialSnapshot()
        snapshot.sharingPreferences.citySharingEnabled = true
        SharedAppStateStore.save(snapshot, origin: setup.repository.storageScope)
        StubURLProtocol.setHandler { _ in .failure(URLError(.notConnectedToInternet)) }

        var pausedPreferences = snapshot.sharingPreferences
        pausedPreferences.citySharingEnabled = false
        let paused = try await setup.repository.setSharingPreferences(pausedPreferences)

        XCTAssertFalse(paused.sharingPreferences.citySharingEnabled)
        XCTAssertEqual(paused.syncState, .offline)
        let pendingCount = await setup.queue.count(ownerID: snapshot.currentUser.id)
        XCTAssertEqual(pendingCount, 1)
    }

    private func makeRepository(push: APNsRegistrationConfiguration? = nil) throws -> (
        repository: RemoteAppRepository,
        queue: OfflineMutationQueue,
        tokenStore: InMemoryTokenStore
    ) {
        let configuration = try XCTUnwrap(APIConfiguration.validated(rawValue: "https://api.test"))
        let supabaseConfiguration = try XCTUnwrap(
            SupabaseConfiguration.validated(
                projectURL: "https://project.supabase.co",
                publishableKey: "sb_publishable_test"
            )
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [StubURLProtocol.self]
        let tokenStore = InMemoryTokenStore(token: "token")
        let suiteName = "RemoteAppRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let queue = OfflineMutationQueue(defaults: defaults, storageKey: "queue")
        let repository = RemoteAppRepository(
            configuration: configuration,
            supabaseConfiguration: supabaseConfiguration,
            mutationQueue: queue,
            session: URLSession(configuration: sessionConfiguration),
            authentication: tokenStore,
            pushConfiguration: push ?? APNsRegistrationConfiguration(
                environment: .sandbox,
                installationID: installationID
            )
        )
        return (repository, queue, tokenStore)
    }
}

@MainActor
final class AppStoreReliabilityTests: XCTestCase {
    func testPushRegistrationTimeoutIsRetryableAndLateResultIsIgnored() async throws {
        let repository = SlowTestRepository()
        await repository.configurePush(delay: .milliseconds(140))
        let store = AppStore(repository: repository, pushRegistrationTimeout: .milliseconds(30))
        let registration = Task { await store.registerPushToken("test-token") }
        try await Task.sleep(for: .milliseconds(65))
        XCTAssertEqual(store.pushRegistrationState, .failed)
        XCTAssertNotNil(store.pushRegistrationError)
        await registration.value
        XCTAssertEqual(store.pushRegistrationState, .failed)
        await repository.configurePush(delay: .zero)
        await store.registerPushToken("test-token")
        if case .registered = store.pushRegistrationState {} else { XCTFail("Retry must complete registration") }
        XCTAssertNil(store.pushRegistrationError)
    }

    func testPushRegistrationCompletionCannotRestoreStateAfterSignOut() async throws {
        let repository = SlowTestRepository()
        await repository.configurePush(delay: .milliseconds(100))
        let store = AppStore(repository: repository)
        let registration = Task { await store.registerPushToken("test-token") }
        try await Task.sleep(for: .milliseconds(20))
        await store.signOut()
        await registration.value
        XCTAssertFalse(store.snapshot.isAuthenticated)
        XCTAssertEqual(store.pushRegistrationState, .notStarted)
    }

    func testFriendNotificationLinkIsRetainedUntilSignInAndClearsOnSignOut() async {
        let repository = LocalDemoRepository(persistsChanges: false)
        let store = AppStore(repository: repository)
        await store.signOut()
        XCTAssertFalse(store.snapshot.isAuthenticated)
        let id = UUID()
        defer { store.discardFriendRequestLink() }
        XCTAssertTrue(store.handleIncomingURL(SharedAppLink.make(host: "friend-requests", path: id.uuidString)))
        XCTAssertEqual(store.pendingFriendRequestID, id)
        let restored = AppStore(repository: repository)
        XCTAssertEqual(restored.pendingFriendRequestID, id)
        await store.signInDemo()
        XCTAssertEqual(store.pendingFriendRequestID, id)
        await store.signOut()
        XCTAssertNil(store.pendingFriendRequestID)
        XCTAssertNil(UserDefaults.standard.string(forKey: "pending-friend-request.v1"))
    }

    func testInvitationForegroundRefreshDoesNotOpenAnUnrequestedSheet() async throws {
        let store = AppStore(repository: SlowTestRepository(loadDelay: .zero))
        let before = store.invitationRefreshRevision
        store.notificationService.onInvitationForeground?()
        XCTAssertEqual(store.invitationRefreshRevision, before + 1)
        XCTAssertNil(store.pendingFriendRequestID)
        XCTAssertNil(store.pendingTripInvitationID)
        try await Task.sleep(for: .milliseconds(30))
    }
    func testRefreshAndProfileSaveCannotSupersedeAccountDeletion() async throws {
        let repository = SlowTestRepository()
        await repository.configureDeletion(error: nil, delay: .milliseconds(80))
        let store = AppStore(repository: repository)
        let deletion = Task { await store.deleteAccount() }
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertTrue(store.isDeletingAccount)
        await store.refresh()
        let saved = await store.updateProfile(ProfileUpdate(displayName: "Too late", username: "too_late", avatarPalette: 0))
        XCTAssertFalse(saved)
        let loads = await repository.snapshotLoadCount()
        XCTAssertEqual(loads, 0)
        await deletion.value
        XCTAssertFalse(store.snapshot.isAuthenticated)
        XCTAssertFalse(store.isDeletingAccount)
    }

    func testAccountDeletionFailureIsVisibleAndAllowsRetry() async {
        let repository = SlowTestRepository()
        let store = AppStore(repository: repository)
        await repository.configureDeletion(error: .networkUnavailable)
        await store.deleteAccount()
        XCTAssertTrue(store.snapshot.isAuthenticated)
        XCTAssertFalse(store.isDeletingAccount)
        XCTAssertEqual(store.notice?.title, "Couldn’t confirm account deletion")
        XCTAssertFalse(store.notice?.message.isEmpty ?? true)
        await repository.configureDeletion(error: nil)
        await store.deleteAccount()
        XCTAssertFalse(store.snapshot.isAuthenticated)
        XCTAssertFalse(store.isDeletingAccount)
    }
    func testProfileSaveIsNotDiscardedByARefreshStartedWhileSaving() async throws {
        let repository = SlowTestRepository(profileDelay: .milliseconds(180), loadDelay: .milliseconds(20))
        let store = AppStore(repository: repository)
        let saving = Task { await store.updateProfile(ProfileUpdate(displayName: "Actually saved", username: "actually_saved", avatarPalette: 1)) }
        try await Task.sleep(for: .milliseconds(30))
        await store.refresh()
        let succeeded = await saving.value
        XCTAssertTrue(succeeded)
        XCTAssertEqual(store.snapshot.currentUser.displayName, "Actually saved")
        XCTAssertEqual(store.snapshot.currentUser.username, "actually_saved")
    }
    func testProfileTimeoutClearsSpinnerAndIgnoresLateResultThenAllowsRetry() async throws {
        let repository = SlowTestRepository(profileDelay: .milliseconds(150))
        let store = AppStore(repository: repository, profileSaveTimeout: .milliseconds(30))
        let original = store.snapshot.currentUser.displayName
        let update = ProfileUpdate(displayName: "Late name", username: "late_name", avatarPalette: 1)
        let request = Task { await store.updateProfile(update) }
        try await Task.sleep(for: .milliseconds(10))
        XCTAssertTrue(store.isSavingProfile)
        XCTAssertFalse(store.isWorking)
        let saved = await request.value
        XCTAssertFalse(saved)
        XCTAssertFalse(store.isSavingProfile)
        XCTAssertTrue(store.profileSaveError?.contains("took too long") == true)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(store.snapshot.currentUser.displayName, original)
        await repository.configureProfile(delay: .zero, error: nil)
        let retried = await store.updateProfile(ProfileUpdate(displayName: "Confirmed", username: "confirmed", avatarPalette: 1))
        XCTAssertTrue(retried)
        XCTAssertNil(store.profileSaveError)
        XCTAssertFalse(store.isSavingProfile)
        XCTAssertEqual(store.snapshot.currentUser.displayName, "Confirmed")
    }

    func testProfileConflictAndOfflineErrorsStayInEditorAndReleaseSavingState() async {
        let repository = SlowTestRepository()
        let store = AppStore(repository: repository)
        let update = ProfileUpdate(displayName: "Name", username: "taken_name", avatarPalette: 1)
        for error in [RepositoryError.message("That username is already taken."), .networkUnavailable] {
            await repository.configureProfile(delay: .zero, error: error)
            let saved = await store.updateProfile(update)
            XCTAssertFalse(saved)
            XCTAssertFalse(store.isSavingProfile)
            XCTAssertNotNil(store.profileSaveError)
            XCTAssertFalse(store.profileSaveError?.contains("saved and will retry") == true)
            XCTAssertNil(store.notice)
        }
    }

    override func tearDown() {
        SharedAppStateStore.reset()
        super.tearDown()
    }

    func testLocationUpdateWaitsForInFlightRefreshInsteadOfBeingDropped() async {
        let repository = SlowTestRepository()
        let store = AppStore(repository: repository)

        let refresh = Task { await store.refresh() }
        try? await Task.sleep(for: .milliseconds(40))
        await store.updateCurrentCity(city: "London", countryCode: "GB", source: .significantChange)
        await refresh.value

        let uploadedCities = await repository.uploadedCities()
        XCTAssertEqual(uploadedCities, ["London"])
        XCTAssertEqual(store.snapshot.currentPresence.city, "London")
    }

    func testAutomaticCityPreservesObservationDateAndCannotOverwriteManualOrOtherAccount() async {
        let repository = SlowTestRepository()
        let store = AppStore(repository: repository)
        let owner = store.snapshot.currentUser.id
        let observed = Date().addingTimeInterval(-30)
        await store.updateCurrentCity(city: "Milpitas", countryCode: "US", source: .foregroundLocation, observedAt: observed)
        XCTAssertEqual(store.snapshot.currentPresence.updatedAt, observed)
        let next = observed.addingTimeInterval(10)
        await store.updateCurrentCity(city: "Milpitas", countryCode: "US", source: .foregroundLocation,
                                      observedAt: next, automaticOwnerID: owner)
        XCTAssertEqual(store.snapshot.currentPresence.updatedAt, next)
        await store.updateCurrentCity(city: "Old city", countryCode: "US", source: .foregroundLocation,
                                      observedAt: observed, automaticOwnerID: owner)
        await store.updateCurrentCity(city: "Wrong account", countryCode: "US", source: .foregroundLocation,
                                      expectedOwnerID: UUID())
        XCTAssertEqual(store.snapshot.currentPresence.city, "Milpitas")
        await store.updateCurrentCity(city: "Paris", countryCode: "FR", source: .manual)
        await store.updateCurrentCity(city: "San Jose", countryCode: "US", source: .foregroundLocation,
                                      automaticOwnerID: owner)
        XCTAssertEqual(store.snapshot.currentPresence.city, "Paris")
        XCTAssertEqual(store.snapshot.currentPresence.source, .manual)
    }

    func testPendingManualCityWinsOverAutomaticResultDuringRefresh() async {
        let repository = SlowTestRepository()
        let store = AppStore(repository: repository)
        await store.updateCurrentCity(city: "Milpitas", countryCode: "US", source: .foregroundLocation)
        let refresh = Task { await store.refresh() }
        try? await Task.sleep(for: .milliseconds(40))
        await store.updateCurrentCity(city: "Paris", countryCode: "FR", source: .manual)
        await store.updateCurrentCity(city: "San Jose", countryCode: "US", source: .foregroundLocation,
                                      automaticOwnerID: store.snapshot.currentUser.id)
        await refresh.value
        XCTAssertEqual(store.snapshot.currentPresence.city, "Paris")
        let cities = await repository.uploadedCities()
        XCTAssertEqual(cities, ["Milpitas", "Paris"])
    }

    func testFriendRequestResponseIsNotDroppedDuringRefresh() async throws {
        let repository = SlowTestRepository()
        let store = AppStore(repository: repository)
        let rawRequestID = await repository.incomingRequestID()
        let rawRequestUserID = await repository.incomingRequestUserID()
        let requestID = try XCTUnwrap(rawRequestID)
        let requestUserID = try XCTUnwrap(rawRequestUserID)

        let refresh = Task { await store.refresh() }
        try? await Task.sleep(for: .milliseconds(40))
        let accepted = await store.respond(to: requestID, response: .accept)
        await refresh.value

        XCTAssertTrue(accepted)
        let respondedRequestIDs = await repository.respondedRequestIDs()
        XCTAssertEqual(respondedRequestIDs, [requestID])
        XCTAssertFalse(store.snapshot.friendRequests.contains(where: { $0.id == requestID }))
        XCTAssertTrue(store.snapshot.friends.contains(where: { $0.id == requestUserID }))
    }

    func testBackgroundRefreshFailureDoesNotPresentAnAlert() async {
        let repository = SlowTestRepository(loadError: RepositoryError.notAuthenticated)
        let store = AppStore(repository: repository)

        await store.refresh()

        XCTAssertNil(store.notice)
    }

    func testConcurrentRefreshesAreCoalesced() async {
        let repository = SlowTestRepository()
        let store = AppStore(repository: repository)

        let firstRefresh = Task { await store.refresh() }
        try? await Task.sleep(for: .milliseconds(40))
        let secondRefresh = Task { await store.refresh() }
        await firstRefresh.value
        await secondRefresh.value

        let loadCount = await repository.snapshotLoadCount()
        XCTAssertEqual(loadCount, 1)
    }
}

private actor SlowTestRepository: AppRepository {
    nonisolated let mode: RepositoryMode
    nonisolated let storageScope = "test:slow-repository"
    private var snapshot = DemoData.initialSnapshot()
    private var cities: [String] = []
    private var responses: [UUID] = []
    private var loadCount = 0
    private let loadError: Error?
    private var travel = TravelPlanSnapshot()
    private var travelError: Error?
    private var tripReads: [[CloudTrip]] = []
    private var tripReadDelays: [Duration] = []
    private var tripReadCount = 0
    private var tripWrites: [CloudTrip] = []
    private var tripWriteDelays: [Duration] = []
    private var tripWriteCount = 0
    private var dismissalDelay: Duration = .zero
    private var dismissalError: RepositoryError?
    private var dismissalStarted = false
    private var profileDelay: Duration
    private var profileError: Error?
    private let loadDelay: Duration

    func fetchTravelPlans() async throws -> TravelPlanSnapshot {
        let old = travel
        let error = travelError
        try await Task.sleep(for: .milliseconds(180))
        if let error { throw error }
        return old
    }
    func configureTravel(snapshot: TravelPlanSnapshot, error: Error? = nil) {
        travel = snapshot; travelError = error
    }
    func saveTravelPlan(_ plan: PersonalTravelPlan) async throws -> TravelPlanSnapshot {
        travel = TravelPlanSnapshot(plans: [plan]); return travel
    }

    func configureTripReads(_ values: [[CloudTrip]], delays: [Duration]) {
        tripReads = values; tripReadDelays = delays; tripReadCount = 0
    }
    func waitForTripReads(_ count: Int) async -> Bool {
        for _ in 0..<200 {
            if tripReadCount >= count { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
    func fetchTrips() async throws -> [CloudTrip] {
        tripReadCount += 1
        let index = tripReadCount - 1
        let result = tripReads.indices.contains(index) ? tripReads[index] : []
        let delay = tripReadDelays.indices.contains(index) ? tripReadDelays[index] : .zero
        try? await Task.sleep(for: delay)
        return result
    }
    func tripInvitations(tripID: String?) async throws -> [TripInvitation] { [] }
    func configureTripWrites(_ values: [CloudTrip], delays: [Duration]) {
        tripWrites = values; tripWriteDelays = delays; tripWriteCount = 0
    }
    func waitForTripWrites(_ count: Int) async -> Bool {
        for _ in 0..<200 {
            if tripWriteCount >= count { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
    func createTrip(_ payload: TripPayload) async throws -> CloudTrip {
        tripWriteCount += 1
        let index = tripWriteCount - 1
        guard tripWrites.indices.contains(index) else { throw RepositoryError.unsupportedInCurrentMode }
        let result = tripWrites[index]
        let delay = tripWriteDelays.indices.contains(index) ? tripWriteDelays[index] : .zero
        try? await Task.sleep(for: delay)
        return result
    }
    func configureDismissal(delay: Duration, error: RepositoryError?) {
        dismissalDelay = delay; dismissalError = error; dismissalStarted = false
    }
    func waitForDismissalStart() async -> Bool {
        for _ in 0..<200 {
            if dismissalStarted { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }
    func dismissTripInvitation(id: UUID, revoke: Bool) async throws {
        dismissalStarted = true
        let error = dismissalError
        try? await Task.sleep(for: dismissalDelay)
        if let error { throw error }
    }

    init(loadError: Error? = nil, profileDelay: Duration = .zero, loadDelay: Duration = .milliseconds(180),
         mode: RepositoryMode = .localDemo) {
        self.mode = mode
        self.loadError = loadError
        self.profileDelay = profileDelay
        self.loadDelay = loadDelay
    }

    func loadSnapshot() async throws -> AppSnapshot {
        loadCount += 1
        try await Task.sleep(for: loadDelay)
        if let loadError { throw loadError }
        return snapshot
    }

    func configureSnapshot(_ value: AppSnapshot) { snapshot = value }

    func uploadedCities() -> [String] { cities }
    func incomingRequestID() -> UUID? { snapshot.incomingRequests.first?.id }
    func incomingRequestUserID() -> UUID? { snapshot.incomingRequests.first?.userID }
    func respondedRequestIDs() -> [UUID] { responses }
    func snapshotLoadCount() -> Int { loadCount }
    func signInDemo() async throws -> AppSnapshot { snapshot }
    func signInWithApple(_ payload: AppleSignInPayload) async throws -> AppSnapshot { snapshot }
    func signOut() async throws -> AppSnapshot { DemoData.signedOutSnapshot() }
    private var deletionError: RepositoryError?
    private var deletionDelay: Duration = .zero
    func configureDeletion(error: RepositoryError?, delay: Duration = .zero) { deletionError = error; deletionDelay = delay }
    func deleteAccount() async throws -> AppSnapshot {
        try await Task.sleep(for: deletionDelay)
        if let deletionError { throw deletionError }
        return DemoData.signedOutSnapshot()
    }
    func configureProfile(delay: Duration, error: Error?) { profileDelay = delay; profileError = error }
    func updateProfile(_ update: ProfileUpdate) async throws -> AppSnapshot {
        let delay = profileDelay
        // Model a transport that does not promptly cooperate with cancellation.
        await Task.detached { try? await Task.sleep(for: delay) }.value
        if let profileError { throw profileError }
        snapshot.currentUser.displayName = update.displayName
        snapshot.currentUser.username = update.username
        return snapshot
    }
    func sendFriendRequest(username: String) async throws -> AppSnapshot { snapshot }
    func respond(to requestID: UUID, response: FriendRequestResponse) async throws -> AppSnapshot {
        responses.append(requestID)
        guard let request = snapshot.friendRequests.first(where: { $0.id == requestID }) else {
            throw RepositoryError.requestNotFound
        }
        snapshot.friendRequests.removeAll { $0.id == requestID }
        if response == .accept {
            snapshot.friends.append(
                FriendPresence(
                    id: request.userID,
                    displayName: request.displayName,
                    username: request.username,
                    city: nil,
                    countryCode: nil,
                    updatedAt: nil,
                    sharingState: .unavailable,
                    avatarPalette: request.avatarPalette
                )
            )
        }
        return snapshot
    }
    func removeFriend(id: UUID) async throws -> AppSnapshot { snapshot }
    func blockUser(id: UUID) async throws -> AppSnapshot { snapshot }
    func unblockUser(id: UUID) async throws -> AppSnapshot { snapshot }
    func setFavorite(friendID: UUID, isFavorite: Bool) async throws -> AppSnapshot { snapshot }
    func setFriendPreference(_ preference: FriendAccessPreference) async throws -> AppSnapshot {
        try await Task.sleep(for: sharingDelay)
        snapshot.friendPreferences.removeAll { $0.friendID == preference.friendID }
        snapshot.friendPreferences.append(preference)
        return snapshot
    }
    private var sharingDelay: Duration = .zero
    func configureSharingDelay(_ delay: Duration) { sharingDelay = delay }
    func setSharingPreferences(_ preferences: SharingPreferences) async throws -> AppSnapshot {
        try await Task.sleep(for: sharingDelay)
        snapshot.sharingPreferences = preferences
        return snapshot
    }

    func updateCurrentCity(city: String, countryCode: String?, source: PresenceSource, observedAt: Date, administrativeArea: String? = nil) async throws -> AppSnapshot {
        cities.append(city)
        snapshot.currentPresence = CurrentUserPresence(
            administrativeArea: administrativeArea,
            city: city,
            countryCode: countryCode,
            updatedAt: observedAt,
            source: source
        )
        return snapshot
    }

    private var pushDelay: Duration = .zero
    func configurePush(delay: Duration) { pushDelay = delay }
    func registerPushToken(_ token: String) async throws {
        let delay = pushDelay
        await Task.detached { try? await Task.sleep(for: delay) }.value
    }
    func retryPendingOperations() async throws -> AppSnapshot { snapshot }
    func pendingOperationCount() async -> Int { 0 }
    func runDemoScenario(_ scenario: DemoScenario) async throws -> AppSnapshot { snapshot }
}

private func requestBodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 { return nil }
        if count == 0 { break }
        result.append(buffer, count: count)
    }
    return result
}

private final class InMemoryTokenStore: RemoteAuthenticationProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?
    private var refreshResult: Result<String, RepositoryError> = .failure(.sessionExpired)
    private var signOutError: RepositoryError?
    func configureSignOutFailure(_ error: RepositoryError) { lock.withLock { signOutError = error } }
    func configureRefresh(_ result: Result<String, RepositoryError>) { lock.withLock { refreshResult = result } }

    init(token: String?) { self.token = token }

    func save(_ token: String) {
        lock.lock()
        self.token = token
        lock.unlock()
    }

    func load() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    func clear() {
        lock.lock()
        token = nil
        lock.unlock()
    }

    func accessToken() async throws -> String {
        guard let token = load() else { throw RepositoryError.notAuthenticated }
        return token
    }

    func signInWithApple(_ payload: AppleSignInPayload) async throws -> String {
        guard let token = load() else { throw RepositoryError.notAuthenticated }
        return token
    }

    func refreshAccessToken() async throws -> String {
        try lock.withLock { try refreshResult.get() }
    }

    func signOut() async throws {
        clear()
        if let error = lock.withLock({ signOutError }) { throw error }
    }
}

private final class StubURLProtocol: URLProtocol {
    enum Outcome {
        case response(statusCode: Int, data: Data)
        case failure(Error)
    }

    private static let lock = NSLock()
    private static var handler: ((URLRequest) -> Outcome)?

    static func setHandler(_ handler: ((URLRequest) -> Outcome)?) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handler
        Self.lock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        switch handler(request) {
        case .response(let statusCode, let data):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class FriendTravelPlanTests: XCTestCase {
    private func shared(start: String = "2090-01-01", end: String = "2090-01-05") -> FriendTravelPlan {
        FriendTravelPlan(id: UUID(), friendID: UUID(), friendName: "A friend", city: "Tokyo", countryCode: "JP",
                         region: "Tokyo", timeZone: "Asia/Tokyo", startDay: start, endDay: end)
    }

    func testLegacyPlansAndSnapshotsUseTheCurrentBrowsingDefault() throws {
        let plan = shared().privateDraft()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as? [String: Any])
        json.removeValue(forKey: "allowFriendBrowsing")
        let decoded = try JSONDecoder().decode(PersonalTravelPlan.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(decoded.allowFriendBrowsing)
        json["allowFriendBrowsing"] = false
        let optedOut = try JSONDecoder().decode(PersonalTravelPlan.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(optedOut.allowFriendBrowsing)
        json.removeValue(forKey: "allowFriendBrowsing")
        let snapshot = try JSONDecoder().decode(TravelPlanSnapshot.self,
            from: JSONSerialization.data(withJSONObject: ["plans": [json], "overlaps": []]))
        XCTAssertTrue(snapshot.friendPlans.isEmpty)
        XCTAssertEqual(snapshot.plans.first?.id, plan.id)
    }

    func testCopyCreatesNewPrivatePlanAndDoesNotInheritAuthorOrNotifications() throws {
        let source = shared()
        let copy = source.privateDraft()
        XCTAssertNotEqual(copy.id, source.id)
        XCTAssertNotEqual(copy.id, source.privateDraft().id)
        XCTAssertEqual(copy.startDay, source.startDay)
        XCTAssertEqual(copy.endDay, source.endDay)
        XCTAssertEqual(copy.destination.region, source.region)
        XCTAssertTrue(copy.audience.isEmpty)
        XCTAssertFalse(copy.alertsEnabled)
        XCTAssertTrue(copy.allowFriendBrowsing)
        XCTAssertEqual(copy.revision, 0)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(TravelPlanPayload(copy))) as? [String: Any])
        XCTAssertEqual(payload["allowFriendBrowsing"] as? Bool, true)
        XCTAssertNil(payload["friendID"])
    }

    @MainActor
    func testSharedDatesAreNotCachedAndDisappearOnFailureAndAccountChange() async throws {
        let repo = SlowTestRepository()
        let library = TravelPlanLibrary()
        let owner = UUID(), row = shared()
        let key = "travel-plans.v1.\(repo.storageScope).\(owner)"
        defer { UserDefaults.standard.removeObject(forKey: key) }
        await repo.configureTravel(snapshot: TravelPlanSnapshot(friendPlans: [row]))
        library.connect(repository: repo, userID: owner)
        await library.refresh()
        XCTAssertEqual(library.friendPlans, [row])
        let cached = try XCTUnwrap(UserDefaults.standard.data(forKey: key))
        XCTAssertEqual(try JSONDecoder().decode([PersonalTravelPlan].self, from: cached).count, 0)
        let cold = TravelPlanLibrary()
        cold.connect(repository: repo, userID: owner)
        XCTAssertTrue(cold.friendPlans.isEmpty)
        await repo.configureTravel(snapshot: TravelPlanSnapshot(friendPlans: [row]), error: RepositoryError.networkUnavailable)
        await library.refresh()
        XCTAssertTrue(library.friendPlans.isEmpty)
        XCTAssertFalse(library.hasSynced)
        await repo.configureTravel(snapshot: TravelPlanSnapshot(friendPlans: [row]))
        let oldRefresh = Task { await library.refresh() }
        try await Task.sleep(for: .milliseconds(20))
        library.connect(repository: repo, userID: UUID())
        await oldRefresh.value
        XCTAssertTrue(library.friendPlans.isEmpty)
    }

    @MainActor
    func testFeedSortsAndFiltersRemovedFriendsAndDestinationDayExpiry() async {
        let repo = SlowTestRepository(), library = TravelPlanLibrary(), owner = UUID()
        defer { UserDefaults.standard.removeObject(forKey: "travel-plans.v1.\(repo.storageScope).\(owner)") }
        let first = shared(start: "2026-09-15", end: "2026-09-15")
        let next = shared(start: "2026-09-16", end: "2026-09-18")
        await repo.configureTravel(snapshot: TravelPlanSnapshot(friendPlans: [next, first]))
        library.connect(repository: repo, userID: owner)
        await library.refresh()
        let beforeMidnight = ISO8601DateFormatter().date(from: "2026-09-15T14:59:00Z")!
        let afterMidnight = ISO8601DateFormatter().date(from: "2026-09-15T15:01:00Z")!
        XCTAssertEqual(library.visibleFriendPlans(friendIDs: [first.friendID, next.friendID], at: beforeMidnight), [first, next])
        XCTAssertEqual(library.visibleFriendPlans(friendIDs: [first.friendID, next.friendID], at: afterMidnight), [next])
        XCTAssertEqual(library.visibleFriendPlans(friendIDs: [next.friendID], at: beforeMidnight), [next])
    }
}

extension RemoteAppRepositoryTests {
    func testSuccessfulSharingWriteRetiresOldOfflineIntent() async throws {
        let setup = try makeRepository()
        var server = DemoData.initialSnapshot()
        server.sharingPreferences.citySharingEnabled = false
        SharedAppStateStore.save(server, origin: setup.repository.storageScope)
        StubURLProtocol.setHandler { _ in .failure(URLError(.notConnectedToInternet)) }
        var old = server.sharingPreferences; old.citySharingEnabled = true
        let offline = try await setup.repository.setSharingPreferences(old)
        SharedAppStateStore.save(offline, origin: setup.repository.storageScope)
        var writes: [Bool] = []
        StubURLProtocol.setHandler { request in
            if request.url?.path == "/v1/sharing" {
                let value = try! JSONDecoder().decode(SharingPreferences.self, from: requestBodyData(request)!)
                writes.append(value.citySharingEnabled); server.sharingPreferences = value
            }
            let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
            return .response(statusCode: 200, data: try! encoder.encode(server))
        }
        var paused = old; paused.citySharingEnabled = false
        let confirmed = try await setup.repository.setSharingPreferences(paused)
        SharedAppStateStore.save(confirmed, origin: setup.repository.storageScope)
        let pending = await setup.queue.count(ownerID: server.currentUser.id)
        XCTAssertEqual(pending, 0)
        let refreshed = try await setup.repository.retryPendingOperations()
        XCTAssertEqual(writes, [false])
        XCTAssertFalse(refreshed.sharingPreferences.citySharingEnabled)
    }

    func testLateFailuresNeverQueueOrReplayIntoAnotherAccount() async throws {
        for action in ["presence", "sharing", "push"] {
            let setup = try makeRepository()
            let original = DemoData.initialSnapshot()
            var other = DemoData.initialSnapshot()
            other.currentUser = AppUser(id: UUID(), displayName: "Other", username: "other")
            SharedAppStateStore.save(original, origin: setup.repository.storageScope)
            StubURLProtocol.setHandler { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
                setup.tokenStore.save("other-token")
                SharedAppStateStore.save(other, origin: setup.repository.storageScope)
                return .failure(URLError(.timedOut))
            }
            do {
                switch action {
                case "presence": _ = try await setup.repository.updateCurrentCity(city: "Tokyo", countryCode: "JP", source: .manual, observedAt: Date(), administrativeArea: "Tokyo")
                case "sharing": _ = try await setup.repository.setSharingPreferences(original.sharingPreferences)
                default: try await setup.repository.registerPushToken("test-push-token")
                }
                XCTFail("Expected changed account to cancel \(action)")
            } catch { XCTAssertTrue(error is CancellationError, "\(error)") }
            let oldQueue = await setup.queue.count(ownerID: original.currentUser.id)
            let newQueue = await setup.queue.count(ownerID: other.currentUser.id)
            XCTAssertEqual(oldQueue, 0); XCTAssertEqual(newQueue, 0)
            XCTAssertEqual(setup.tokenStore.load(), "other-token")
        }
    }

    func testOldUnauthorizedResponseCannotRefreshOrSignOutNewAccount() async throws {
        let setup = try makeRepository()
        let original = DemoData.initialSnapshot()
        var other = original; other.currentUser = AppUser(id: UUID(), displayName: "Other", username: "other")
        SharedAppStateStore.save(original, origin: setup.repository.storageScope)
        var requests = 0
        StubURLProtocol.setHandler { _ in
            requests += 1
            setup.tokenStore.save("other-token")
            SharedAppStateStore.save(other, origin: setup.repository.storageScope)
            return .response(statusCode: 401, data: Data())
        }
        do { _ = try await setup.repository.updateProfile(ProfileUpdate(displayName: "Old", username: "old", avatarPalette: 1)); XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(requests, 1)
        XCTAssertEqual(setup.tokenStore.load(), "other-token")
    }
}

extension AppStoreReliabilityTests {
    func testConcurrentSharingControlsCannotRestorePausedCity() async throws {
        let repo = SlowTestRepository(loadDelay: .zero)
        await repo.configureSharingDelay(.milliseconds(120))
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: repo.storageScope)
        let store = AppStore(repository: repo)
        var paused = store.snapshot.sharingPreferences; paused.citySharingEnabled = false
        let first = Task { await store.setSharingPreferences(paused) }
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertTrue(store.isSavingSharingPreferences)
        var stale = store.snapshot.sharingPreferences; stale.backgroundUpdatesEnabled.toggle()
        let rejected = await store.setSharingPreferences(stale)
        XCTAssertFalse(rejected)
        let saved = await first.value
        XCTAssertTrue(saved)
        XCTAssertFalse(store.snapshot.sharingPreferences.citySharingEnabled)
        XCTAssertFalse(store.isSavingSharingPreferences)
    }
}

final class DateRangeRegressionTests: XCTestCase {
    func testRecentCitiesStayWithinTheAccountAndRemainBounded() throws {
        let suite = "travel-city-history-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let firstOwner = UUID(), secondOwner = UUID(), origin = "test:city-history"
        let cities = (0..<5).map {
            TravelCity(name: "City \($0)", countryCode: "US", region: "CA", timeZone: "America/Los_Angeles")
        }
        for city in cities { TravelCityHistory.remember(city, origin: origin, ownerID: firstOwner, defaults: defaults) }
        XCTAssertEqual(TravelCityHistory.recent(origin: origin, ownerID: firstOwner, defaults: defaults).map(\.name),
                       ["City 4", "City 3", "City 2", "City 1"])
        XCTAssertTrue(TravelCityHistory.recent(origin: origin, ownerID: secondOwner, defaults: defaults).isEmpty)
        TravelCityHistory.remember(cities[2], origin: origin, ownerID: firstOwner, defaults: defaults)
        XCTAssertEqual(TravelCityHistory.recent(origin: origin, ownerID: firstOwner, defaults: defaults).map(\.name),
                       ["City 2", "City 4", "City 3", "City 1"])
    }

    func testSameDayCrossMonthAndReverseSelection() {
        var selection = TravelDateRangeSelection(start: "2026-12-29", end: "2027-01-03")
        selection.select("2026-12-31")
        XCTAssertNil(selection.end)
        selection.select("2027-01-02")
        XCTAssertEqual(selection.dayCount, 3)
        selection.select("2027-02-05"); selection.select("2027-02-02")
        XCTAssertEqual(selection.start, "2027-02-02"); XCTAssertEqual(selection.end, "2027-02-05")
        selection.select("2028-02-29"); selection.select("2028-02-29")
        XCTAssertEqual(selection.dayCount, 1)
    }
    func testCrossYearLabelsAndAdministrativeAliases() {
        let label = TravelDateRangeSelection.label(start: "2026-12-29", end: "2027-01-03")
        XCTAssertTrue(label.contains("2026")); XCTAssertTrue(label.contains("2027"))
        let a = TravelCity(name: "New York", countryCode: "US", region: "NY", timeZone: "America/New_York")
        let b = TravelCity(name: "New York", countryCode: "US", region: "New York", timeZone: "America/New_York")
        XCTAssertEqual(a.matchingKey, b.matchingKey)
        XCTAssertNil(TravelCity(name: "Pasadena", countryCode: "US", region: "", timeZone: "America/Los_Angeles").matchingKey)
    }
    @MainActor
    func testClearingAccountCacheDoesNotRemoveAnotherUserOrAllowOldWrites() throws {
        let origin = "test-cache-" + UUID().uuidString, owner = UUID(), other = UUID()
        let ownKey = "travel-plans.v1.\(origin).\(owner)", otherKey = "travel-plans.v1.\(origin).\(other)"
        UserDefaults.standard.set(Data("own".utf8), forKey: ownKey)
        UserDefaults.standard.set(Data("other".utf8), forKey: otherKey)
        let remembered = TravelCity(name: "Tokyo", countryCode: "JP", region: "Tokyo", timeZone: "Asia/Tokyo")
        TravelCityHistory.remember(remembered, origin: origin, ownerID: owner)
        TravelCityHistory.remember(remembered, origin: origin, ownerID: other)
        let library = TripLibrary(); let scope = "\(origin)-\(owner)"
        library.load(scope: scope, userID: owner.uuidString)
        let person = TripParticipant(id: owner.uuidString, name: "Owner", userID: owner.uuidString)
        let plan = TripPlan(id: UUID().uuidString, name: "Test", destinationAirport: "LAX", startDay: TripDay(value: "2026-10-01"), endDay: TripDay(value: "2026-10-03"), participants: [person], flights: [], creatorUserID: owner.uuidString)
        XCTAssertTrue(library.add(plan))
        AccountLocalData.clear(origin: origin, ownerID: owner)
        XCTAssertNil(UserDefaults.standard.data(forKey: ownKey))
        XCTAssertNotNil(UserDefaults.standard.data(forKey: otherKey))
        XCTAssertTrue(TravelCityHistory.recent(origin: origin, ownerID: owner).isEmpty)
        XCTAssertEqual(TravelCityHistory.recent(origin: origin, ownerID: other), [remembered])
        var delayed = plan; delayed.name = "Late response"
        XCTAssertFalse(library.editTrip(plan.id, name: delayed.name, airport: "LAX", start: plan.startDay, end: plan.endDay))
        let fresh = TripLibrary(); fresh.load(scope: scope, userID: owner.uuidString)
        XCTAssertTrue(fresh.trips.isEmpty)
        AccountLocalData.clear(origin: origin, ownerID: other)
    }
}


extension AppStoreReliabilityTests {
    func testPerFriendSharingCannotBeRestoredByConcurrentAlertToggle() async throws {
        let repo = SlowTestRepository(loadDelay: .zero)
        await repo.configureSharingDelay(.milliseconds(120))
        SharedAppStateStore.save(DemoData.initialSnapshot(), origin: repo.storageScope)
        let store = AppStore(repository: repo)
        let id = try XCTUnwrap(store.friends.first?.id)
        var paused = store.preference(for: id); paused.sharesMyCity = false
        let first = Task { await store.setFriendPreference(paused) }
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertTrue(store.isSavingFriendPreference(for: id))
        var stale = store.preference(for: id); stale.sameCityAlertEnabled.toggle()
        await store.setFriendPreference(stale)
        await first.value
        XCTAssertFalse(store.preference(for: id).sharesMyCity)
        XCTAssertFalse(store.isSavingFriendPreference(for: id))
    }
}
