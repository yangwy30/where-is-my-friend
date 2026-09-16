import CoreLocation
import Foundation
import UIKit
import UserNotifications

struct ResolvedCity: Equatable, Sendable {
    let city: String
    let countryCode: String?
    let source: PresenceSource
    let observedAt: Date
    let ownerID: UUID?
    let isAutomatic: Bool
    var administrativeArea: String? = nil
}

struct CityLocationContext: Hashable {
    var ownerID: UUID?
    var isActive = false
    var automaticAllowed = false
    var backgroundEnabled = false
}

enum CityLocationPolicy {
    static func automaticAllowed(sharingEnabled: Bool, presence: CurrentUserPresence) -> Bool {
        sharingEnabled && (presence.city == nil || presence.source != .manual)
    }

    static func accepts(_ location: CLLocation, now: Date = Date(), newerThan: Date? = nil) -> Bool {
        let age = now.timeIntervalSince(location.timestamp)
        return CLLocationCoordinate2DIsValid(location.coordinate)
            && location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 10_000
            && age >= -30 && age <= 120
            && (newerThan == nil || location.timestamp > newerThan!)
    }
}

enum LocationSetupPolicy {
    static func shouldPresent(isAuthenticated: Bool, hasSeenSetup: Bool, isLiveAccount: Bool,
                              status: CLAuthorizationStatus) -> Bool {
        isAuthenticated && isLiveAccount && !hasSeenSetup
            && status != .authorizedWhenInUse && status != .authorizedAlways
    }
}

@MainActor
final class CityLocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var latestCity: ResolvedCity?
    @Published private(set) var isResolving = false
    @Published private(set) var errorMessage: String?

    private let manager: CLLocationManager
    private let geocoder: CLGeocoder
    private let resolutionTimeout: Duration
    private var requestedSource: PresenceSource = .foregroundLocation
    private var backgroundUpdatesEnabled = false
    private var resolvesOnNextAuthorization = false
    private var requestedAlwaysUpgrade = false
    private var context = CityLocationContext()
    private var monitoring = false
    private var foregroundMonitoring = false
    private var explicitRequest = false
    private var lastRequestAt: Date?
    private var newestObservation: Date?
    private var generation = UUID()
    private var timeoutTask: Task<Void, Never>?

    func configure(_ newContext: CityLocationContext) {
        let revoked = context.ownerID != newContext.ownerID
            || (context.automaticAllowed && !newContext.automaticAllowed)
            || (context.isActive && !newContext.isActive && !newContext.backgroundEnabled
                && !explicitRequest && !resolvesOnNextAuthorization)
        if revoked {
            cancelResolution()
            latestCity = nil
            newestObservation = nil
            lastRequestAt = nil
        }
        context = newContext
        setBackgroundUpdatesEnabled(newContext.ownerID != nil && newContext.automaticAllowed && newContext.backgroundEnabled)
        updateForegroundMonitoring()
        refreshIfNeeded(minimumInterval: 60)
    }

    func refreshIfNeeded(minimumInterval: TimeInterval = 300) {
        guard context.ownerID != nil, context.isActive, context.automaticAllowed,
              !isResolving, authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse,
              lastRequestAt.map({ Date().timeIntervalSince($0) >= minimumInterval }) ?? true else { return }
        requestCurrentLocation(source: .foregroundLocation, explicit: false)
    }

    private func updateForegroundMonitoring() {
        let shouldRun = context.ownerID != nil && context.isActive && context.automaticAllowed
            && (authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse)
        guard shouldRun != foregroundMonitoring else { return }
        foregroundMonitoring = shouldRun
        if shouldRun { manager.startUpdatingLocation() }
        else { manager.stopUpdatingLocation() }
    }

    private func cancelResolution() {
        generation = UUID()
        geocoder.cancelGeocode()
        timeoutTask?.cancel()
        timeoutTask = nil
        manager.stopUpdatingLocation()
        foregroundMonitoring = false
        explicitRequest = false
        resolvesOnNextAuthorization = false
        isResolving = false
    }

    private func requestCurrentLocation(source: PresenceSource, explicit: Bool) {
        generation = UUID()
        geocoder.cancelGeocode()
        // An attempted/cancelled lookup is not a successfully resolved observation.
        newestObservation = latestCity?.observedAt
        requestedSource = source
        explicitRequest = explicit
        lastRequestAt = Date()
        isResolving = true
        errorMessage = nil
        armTimeout()
        // requestLocation is ignored while continuous foreground updates run.
        if foregroundMonitoring { manager.stopUpdatingLocation(); foregroundMonitoring = false }
        manager.requestLocation()
    }

    private func armTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            guard let delay = self?.resolutionTimeout else { return }
            do { try await Task.sleep(for: delay) } catch { return }
            guard let self else { return }
            let wasExplicit = self.explicitRequest
            self.cancelResolution()
            if wasExplicit { self.errorMessage = "Location is taking too long. Please try again." }
            self.updateForegroundMonitoring()
        }
    }

    override convenience init() {
        self.init(manager: CLLocationManager(), geocoder: CLGeocoder())
    }

    init(manager: CLLocationManager, geocoder: CLGeocoder, resolutionTimeout: Duration = .seconds(20)) {
        self.manager = manager
        self.geocoder = geocoder
        self.resolutionTimeout = resolutionTimeout
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        manager.distanceFilter = 5_000
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = true
    }

    func requestForegroundCity() {
        errorMessage = nil
        requestedSource = .foregroundLocation
        switch manager.authorizationStatus {
        case .notDetermined:
            resolvesOnNextAuthorization = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestCurrentLocation(source: .foregroundLocation, explicit: true)
        case .denied, .restricted:
            errorMessage = "Location access is off. You can still select a city manually."
        @unknown default:
            errorMessage = "Location access is unavailable."
        }
    }

    func requestBackgroundUpdates() {
        errorMessage = nil
        backgroundUpdatesEnabled = true
        requestedAlwaysUpgrade = false
        switch manager.authorizationStatus {
        case .notDetermined:
            resolvesOnNextAuthorization = true
            requestedAlwaysUpgrade = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            requestForegroundCity()
        case .authorizedAlways:
            startBackgroundMonitoring()
            requestForegroundCity()
        case .denied, .restricted:
            errorMessage = "Always Location access is required for automatic city changes."
        @unknown default:
            break
        }
    }

    func stopBackgroundUpdates() {
        backgroundUpdatesEnabled = false
        requestedAlwaysUpgrade = false
        manager.stopMonitoringVisits()
        manager.stopMonitoringSignificantLocationChanges()
        monitoring = false
    }

    func setBackgroundUpdatesEnabled(_ isEnabled: Bool) {
        backgroundUpdatesEnabled = isEnabled
        if isEnabled, manager.authorizationStatus == .authorizedAlways {
            startBackgroundMonitoring()
        } else {
            manager.stopMonitoringVisits()
            manager.stopMonitoringSignificantLocationChanges()
            monitoring = false
        }
    }

    private func startBackgroundMonitoring() {
        guard !monitoring else { return }
        monitoring = true
        manager.startMonitoringVisits()
        manager.startMonitoringSignificantLocationChanges()
    }

    private func resolve(_ location: CLLocation, source: PresenceSource) {
        guard context.ownerID != nil,
              explicitRequest || (context.automaticAllowed && (context.isActive || monitoring)),
              CityLocationPolicy.accepts(location) else { return }
        if explicitRequest, latestCity?.observedAt == location.timestamp {
            // Already resolved; finish without inventing a newer confirmation time.
            isResolving = false
            explicitRequest = false
            timeoutTask?.cancel()
            updateForegroundMonitoring()
            return
        }
        guard CityLocationPolicy.accepts(location, newerThan: newestObservation) else { return }
        newestObservation = location.timestamp
        generation = UUID()
        let ticket = generation
        let ownerID = context.ownerID
        let wasExplicit = explicitRequest
        geocoder.cancelGeocode()
        isResolving = true
        armTimeout()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self, self.generation == ticket, self.context.ownerID == ownerID else { return }
                defer { self.newestObservation = self.latestCity?.observedAt }
                self.isResolving = false
                self.explicitRequest = false
                self.timeoutTask?.cancel()
                self.updateForegroundMonitoring()
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let placemark = placemarks?.first else {
                    self.errorMessage = "A city could not be resolved for this location."
                    return
                }
                // A county/state fallback is not evidence that two people share a city.
                let cityCandidate = placemark.locality
                guard let city = cityCandidate?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty else {
                    self.errorMessage = "A city could not be resolved for this location."
                    return
                }
                self.latestCity = ResolvedCity(
                    city: city,
                    countryCode: placemark.isoCountryCode,
                    source: source,
                    observedAt: location.timestamp,
                    ownerID: ownerID,
                    isAutomatic: !wasExplicit,
                    administrativeArea: placemark.administrativeArea
                )
            }
        }
    }
}

extension CityLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            let previousStatus = authorizationStatus
            authorizationStatus = manager.authorizationStatus
            let isAuthorized = authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
            let becameAuthorized = isAuthorized && previousStatus != .authorizedWhenInUse && previousStatus != .authorizedAlways
            if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                cancelResolution()
                errorMessage = "Location access is off. You can enable it in Settings whenever you’re ready."
            }
            setBackgroundUpdatesEnabled(backgroundUpdatesEnabled)
            updateForegroundMonitoring()
            if authorizationStatus == .authorizedWhenInUse, requestedAlwaysUpgrade {
                requestedAlwaysUpgrade = false
                manager.requestAlwaysAuthorization()
            }
            // Also resolve after enabling access in Settings, not just the first alert.
            if isAuthorized && resolvesOnNextAuthorization {
                resolvesOnNextAuthorization = false
                requestCurrentLocation(source: .foregroundLocation, explicit: true)
            } else if becameAuthorized {
                refreshIfNeeded(minimumInterval: 0)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let location = locations.filter({ CityLocationPolicy.accepts($0) }).max(by: { $0.timestamp < $1.timestamp }) else { return }
            resolve(location, source: explicitRequest ? requestedSource : (context.isActive ? .foregroundLocation : .significantChange))
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // Visits may arrive long after arrival/departure. Use them only as a wake-up.
        Task { @MainActor in
            guard monitoring, context.automaticAllowed, !isResolving else { return }
            requestCurrentLocation(source: .visit, explicit: false)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            guard isResolving else { return }
            cancelResolution()
            updateForegroundMonitoring()
            if (error as? CLError)?.code != .locationUnknown {
                errorMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
final class LocalNotificationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var onSameCityForeground: ((UUID) -> Void)?
    var onUpcomingForeground: ((String) -> Void)?
    var onNotificationOpen: ((URL) -> Bool)?
    var onInvitationForeground: (() -> Void)?
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
        Task { await refreshAuthorizationStatus() }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            await refreshAuthorizationStatus()
        } catch {
            await refreshAuthorizationStatus()
        }
        return allowsNotifications
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    func unregisterRemoteNotifications() {
        UIApplication.shared.unregisterForRemoteNotifications()
    }

    func schedule(_ event: ColocationEvent, previewsEnabled: Bool = true) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = previewsEnabled ? event.title : String(localized: "A same-city update")
        content.body = previewsEnabled ? event.message : String(localized: "Open Across Us to see the update.")
        content.sound = .default
        content.threadIdentifier = "colocation"
        content.userInfo = ["deepLink": SharedAppLink.make(host: "events", path: event.id.uuidString).absoluteString]
        let request = UNNotificationRequest(
            identifier: event.deduplicationKey,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        try? await center.add(request)
    }

    var allowsNotifications: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            true
        default:
            false
        }
    }
}

extension LocalNotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let link = (notification.request.content.userInfo["deepLink"] as? String).flatMap(URL.init(string:))
        Task { @MainActor in
            if let link, FriendRequestNotificationLink.parse(link) != nil || TripInvitationLink.parse(link) != nil {
                onInvitationForeground?()
                completionHandler([.banner, .sound, .list])
            } else if let link, let id = UpcomingTravelLink.parse(link), let onUpcomingForeground {
                onUpcomingForeground(id)
                completionHandler([])
            } else if let link, let id = SameCityAlertLink.eventID(from: link), let onSameCityForeground {
                // One in-app banner instead of an APNs banner plus a second card.
                onSameCityForeground(id)
                completionHandler([])
            } else {
                completionHandler([.banner, .sound, .list])
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let deepLink = response.notification.request.content.userInfo["deepLink"] as? String
        Task { @MainActor in
            if let deepLink, let url = URL(string: deepLink) {
                if onNotificationOpen?(url) != true {
                    UIApplication.shared.open(url)
                }
            }
            completionHandler()
        }
    }
}

extension Notification.Name {
    static let pushTokenUpdated = Notification.Name("WhereIsMyFriend.pushTokenUpdated")
    static let pushRegistrationFailed = Notification.Name("WhereIsMyFriend.pushRegistrationFailed")
}

final class PushRegistrationDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .pushTokenUpdated, object: token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        NotificationCenter.default.post(name: .pushRegistrationFailed, object: error)
    }
}
