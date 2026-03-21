import Foundation
import CoreLocation
import Supabase

@Observable
class NETRLocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = NETRLocationManager()

    var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let locationManager = CLLocationManager()
    private let client = SupabaseManager.shared.client
    private var updateTimer: Timer?
    private var lastUploadDate: Date?

    private let updateInterval: TimeInterval = 15 * 60 // 15 minutes

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Request Permission

    func requestWhenInUsePermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Start Tracking (foreground only)

    func startPeriodicUpdates() {
        locationManager.startUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.uploadLocationIfNeeded()
        }
    }

    func stopUpdates() {
        locationManager.stopUpdatingLocation()
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location.coordinate
            self.uploadLocationIfNeeded()
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                self.startPeriodicUpdates()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NETR] Location error: \(error)")
    }

    // MARK: - Upload to Supabase

    private func uploadLocationIfNeeded() {
        // Throttle to every 15 minutes
        if let last = lastUploadDate, Date().timeIntervalSince(last) < updateInterval {
            return
        }

        guard let coord = currentLocation else { return }
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        lastUploadDate = Date()

        Task {
            do {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let now = formatter.string(from: Date())

                try await client
                    .from("profiles")
                    .update([
                        "last_lat": AnyJSON.double(coord.latitude),
                        "last_lng": AnyJSON.double(coord.longitude),
                        "last_location_updated": AnyJSON.string(now)
                    ])
                    .eq("id", value: userId)
                    .execute()
            } catch {
                print("[NETR] Upload location error: \(error)")
            }
        }
    }
}
