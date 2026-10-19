import Foundation
import CoreLocation
import MapKit

// 📍 Near me: the phone's location, only when the person uses the Concierge.
// Asks "While using the app" once. Then Northstar's notice asks which they prefer:
//   • Exact location: the spot, rounded to about a block (3 decimals), so "nearest" really is nearest.
//   • City only: just the city's center point.
// Either way it's sent only with a search, and Northstar doesn't save it.

@MainActor
final class NearMe: NSObject, CLLocationManagerDelegate {
    static let shared = NearMe()

    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<CLLocation?, Never>] = []
    private(set) var lastLocation: CLLocation?
    private(set) var city: String?
    /// The street they're on ("Washington St"), from the same lookup as the city.
    private(set) var street: String?

    /// nil = not asked yet (show the notice), true = exact (about a block), false = city only.
    static var preciseChoice: Bool? {
        get { UserDefaults.standard.object(forKey: "ns.preciseLocation") as? Bool }
        set { UserDefaults.standard.set(newValue, forKey: "ns.preciseLocation") }
    }
    static var precise: Bool { preciseChoice ?? false }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// "Petaluma, CA" (or nil if they said no, or it isn't known).
    func cityName() async -> String? {
        if let city { return city }
        guard let location = await currentLocation() else { return nil }
        let marks = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let mark = marks?.first else { return nil }
        let parts = [mark.locality, mark.administrativeArea].compactMap { $0 }
        city = parts.isEmpty ? nil : parts.joined(separator: ", ")
        street = mark.thoroughfare
        return city
    }

    /// Where to search from: their spot rounded to about a block (exact), or the city's center (city only).
    func searchPoint() async -> (lat: Double, lng: Double, precise: Bool)? {
        if Self.precise, let here = await currentLocation() {
            return (Self.round3(here.coordinate.latitude), Self.round3(here.coordinate.longitude), true)
        }
        guard let city = await cityName(),
              let request = MKGeocodingRequest(addressString: city),
              let center = try? await request.mapItems.first?.location.coordinate else { return nil }
        return ((center.latitude * 100).rounded() / 100, (center.longitude * 100).rounded() / 100, false)
    }

    /// For the brain's search words: "near Washington St, Petaluma, CA" (exact) or "in Petaluma, CA".
    func nearText() async -> String? {
        guard let city = await cityName() else { return nil }
        if Self.precise, let street, !street.isEmpty { return "near \(street), \(city)" }
        return "in \(city)"
    }

    private static func round3(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }

    func currentLocation() async -> CLLocation? {
        if let lastLocation, abs(lastLocation.timestamp.timeIntervalSinceNow) < 600 { return lastLocation }
        switch manager.authorizationStatus {
        case .denied, .restricted:
            return nil
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
            // Never wait forever.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(8))
                self.finish(nil)
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        if let location { lastLocation = location }
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume(returning: location ?? lastLocation) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if !self.waiters.isEmpty { manager.requestLocation() }
            case .denied, .restricted:
                self.finish(nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in self.finish(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}
