import Foundation
import CoreLocation

// 📍 Near me: the phone's rough location, only when the person uses the Concierge.
// Asks "While using the app" once. Only the CITY is ever sent to Northstar, never the exact spot.
// The exact spot stays on the phone (for distances on the cards).

@MainActor
final class NearMe: NSObject, CLLocationManagerDelegate {
    static let shared = NearMe()

    private let manager = CLLocationManager()
    private var waiters: [CheckedContinuation<CLLocation?, Never>] = []
    private(set) var lastLocation: CLLocation?
    private(set) var city: String?

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
        return city
    }

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
