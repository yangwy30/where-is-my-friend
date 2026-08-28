import CoreLocation
import Foundation
import UIKit
import UserNotifications

struct ResolvedCity: Equatable, Sendable {
    let city: String
    let countryCode: String?
    let source: PresenceSource
}

@MainActor
final class CityLocationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var latestCity: ResolvedCity?
    @Published private(set) var isResolving = false
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var requestedSource: PresenceSource = .foregroundLocation
    private var backgroundUpdatesEnabled = false
    private var resolvesOnNextAuthorization = false
    private var requestedAlwaysUpgrade = false

    override init() {
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
            isResolving = true
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access is off. You can still select a city manually."
        @unknown default:
            errorMessage = "Location access is unavailable."
        }
    }

    func requestBackgroundUpdates() {
        errorMessage = nil
        backgroundUpdatesEnabled = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            requestedAlwaysUpgrade = true
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startBackgroundMonitoring()
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
    }

    func setBackgroundUpdatesEnabled(_ isEnabled: Bool) {
        backgroundUpdatesEnabled = isEnabled
        if isEnabled, manager.authorizationStatus == .authorizedAlways {
            startBackgroundMonitoring()
        } else if !isEnabled {
            requestedAlwaysUpgrade = false
            manager.stopMonitoringVisits()
            manager.stopMonitoringSignificantLocationChanges()
        }
    }

    private func startBackgroundMonitoring() {
        requestedSource = .significantChange
        manager.startMonitoringVisits()
        manager.startMonitoringSignificantLocationChanges()
    }

    private func resolve(_ location: CLLocation, source: PresenceSource) {
        isResolving = true
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self else { return }
                self.isResolving = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let placemark = placemarks?.first else {
                    self.errorMessage = "A city could not be resolved for this location."
                    return
                }
                let cityCandidate = placemark.locality
                    ?? placemark.subAdministrativeArea
                    ?? placemark.administrativeArea
                    ?? placemark.name
                guard let city = cityCandidate?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty else {
                    self.errorMessage = "A city could not be resolved for this location."
                    return
                }
                self.latestCity = ResolvedCity(
                    city: city,
                    countryCode: placemark.isoCountryCode,
                    source: source
                )
            }
        }
    }
}

extension CityLocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedAlways, backgroundUpdatesEnabled {
                startBackgroundMonitoring()
            } else if manager.authorizationStatus == .authorizedWhenInUse {
                if backgroundUpdatesEnabled, !requestedAlwaysUpgrade {
                    requestedAlwaysUpgrade = true
                    manager.requestAlwaysAuthorization()
                } else if resolvesOnNextAuthorization {
                    resolvesOnNextAuthorization = false
                    isResolving = true
                    manager.requestLocation()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in resolve(location, source: requestedSource) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        let location = CLLocation(
            coordinate: visit.coordinate,
            altitude: 0,
            horizontalAccuracy: visit.horizontalAccuracy,
            verticalAccuracy: -1,
            timestamp: visit.arrivalDate
        )
        Task { @MainActor in resolve(location, source: .visit) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isResolving = false
            if (error as? CLError)?.code != .locationUnknown {
                errorMessage = error.localizedDescription
            }
        }
    }
}

@MainActor
final class LocalNotificationService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
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

    func schedule(_ event: ColocationEvent) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = event.message
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
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let deepLink = response.notification.request.content.userInfo["deepLink"] as? String
        Task { @MainActor in
            if let deepLink, let url = URL(string: deepLink) {
                UIApplication.shared.open(url)
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
