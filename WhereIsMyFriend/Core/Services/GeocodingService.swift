import Foundation
import CoreLocation

public class GeocodingService {
    public static let shared = GeocodingService()
    private let geocoder = CLGeocoder()
    private var lastGeocodedCity: String?

    private init() {}

    public func reverseGeocodeAndUpload(location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return }

            let city = placemark.locality ?? placemark.administrativeArea ?? "Unknown City"
            let country = placemark.country ?? "Unknown Country"
            let countryCode = placemark.isoCountryCode ?? "UN"

            print("[GeocodingService] Reverse geocoded city: \(city), \(country) (\(countryCode))")

            // Throttling: If the city hasn't changed, log and skip Firestore write
            if city == lastGeocodedCity {
                print("[GeocodingService] City unchanged (\(city)), skipping upload.")
                return
            }

            lastGeocodedCity = city

            // Upload to Firestore
            await FirestoreService.shared.updateUserLocation(
                city: city,
                country: country,
                countryCode: countryCode,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        } catch {
            print("[GeocodingService] Reverse geocoding failed: \(error.localizedDescription)")
        }
    }
}
