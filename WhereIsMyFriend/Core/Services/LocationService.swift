import Foundation
import CoreLocation
import Observation

@Observable
public class LocationService: NSObject, CLLocationManagerDelegate {
    public static let shared = LocationService()

    private let locationManager = CLLocationManager()
    public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    public var lastLocation: CLLocation?
    public var isMonitoring: Bool = false

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = locationManager.authorizationStatus
    }

    public func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    public func startMonitoring() {
        guard CLLocationManager.significantLocationChangeMonitoringAvailable() else {
            print("[LocationService] Significant Location Change is not available on this device.")
            return
        }
        locationManager.startMonitoringSignificantLocationChanges()
        isMonitoring = true
        print("[LocationService] Started monitoring significant location changes.")
    }

    public func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        isMonitoring = false
        print("[LocationService] Stopped monitoring location changes.")
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        print("[LocationService] Received new location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

        Task {
            await GeocodingService.shared.reverseGeocodeAndUpload(location: location)
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationService] Location error: \(error.localizedDescription)")
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        print("[LocationService] Authorization status changed: \(authorizationStatus.rawValue)")

        if authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse {
            startMonitoring()
        }
    }
}
