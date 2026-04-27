import SwiftUI
import MapKit
import CoreLocation
import Supabase
import Auth
import PostgREST

@Observable
@MainActor
class CourtsViewModel: NSObject, CLLocationManagerDelegate {

    var courts: [Court] = []
    var favoriteCourtIds: Set<String> = []
    var homeCourtId: String?
    var isLoading: Bool = false
    var error: String?

    var searchText: String = ""
    var selectedFilter: String = "All"
    var selectedNeighborhood: String?
    var liveCourtIds: Set<String> = []
    var scheduledCourtIds: Set<String> = []
    /// Set to true when the user explicitly wants to browse all courts
    var isExploring: Bool = false

    // ── Advanced filter state (set via CourtFilterSheet) ──────────────────
    /// Maximum distance in miles. nil = no limit.
    var filterMaxDistance: Double? = nil
    /// Surface types to include. Empty = any surface.
    var filterSurfaces: Set<SurfaceType> = []
    /// nil = any, true = full court only, false = half court only
    var filterCourtType: Bool? = nil
    /// nil = any, true = indoor only, false = outdoor only
    var filterIndoor: Bool? = nil

    /// True when at least one advanced filter is active.
    var hasActiveFilters: Bool {
        filterMaxDistance != nil || !filterSurfaces.isEmpty || filterCourtType != nil || filterIndoor != nil
    }

    var userLocation: CLLocationCoordinate2D?

    private let locationManager = CLLocationManager()
    private let client = SupabaseManager.shared.client

    private let filters = ["All", "Favorites", "Live Now", "Scheduled", "Verified"]

    var neighborhoods: [String] {
        let hoods = Set(courts.map { $0.neighborhood }).sorted()
        return hoods.filter { !$0.isEmpty }
    }

    /// True when showing the personalised default (home + favourites only).
    var isDefaultView: Bool { !isExploring && searchText.isEmpty && selectedFilter == "All" }

    var filteredCourts: [Court] {
        // ── Default: home court + favourites only ──────────────────────────
        if isDefaultView {
            let myCourts = courts.filter {
                favoriteCourtIds.contains($0.id) || $0.id == homeCourtId
            }
            return myCourts.sorted { a, b in
                let aHome = a.id == homeCourtId
                let bHome = b.id == homeCourtId
                if aHome != bHome { return aHome }
                if let loc = userLocation {
                    let distA = CLLocation(latitude: a.lat, longitude: a.lng)
                        .distance(from: CLLocation(latitude: loc.latitude, longitude: loc.longitude))
                    let distB = CLLocation(latitude: b.lat, longitude: b.lng)
                        .distance(from: CLLocation(latitude: loc.latitude, longitude: loc.longitude))
                    return distA < distB
                }
                return a.name < b.name
            }
        }

        // ── Search / filter mode: full results ─────────────────────────────
        var results = courts

        if !searchText.isEmpty {
            let trimmed = searchText.trimmingCharacters(in: .whitespaces)
            let isZip = trimmed.count == 5 && trimmed.allSatisfy(\.isNumber)
            if isZip {
                results = results.filter { $0.zipCode == trimmed }
            } else {
                results = results.filter {
                    $0.name.localizedStandardContains(searchText) ||
                    $0.neighborhood.localizedStandardContains(searchText) ||
                    $0.city.localizedStandardContains(searchText) ||
                    ($0.zipCode?.hasPrefix(trimmed) ?? false)
                }
            }
        }

        if let hood = selectedNeighborhood {
            results = results.filter { $0.neighborhood == hood }
        }

        switch selectedFilter {
        case "Live Now":   results = results.filter { liveCourtIds.contains($0.id.lowercased()) }
        case "Favorites":  results = results.filter { favoriteCourtIds.contains($0.id) }
        case "Scheduled":  results = results.filter { scheduledCourtIds.contains($0.id.lowercased()) }
        case "Verified":   results = results.filter { $0.verified }
        default: break
        }

        // ── Advanced filters ──────────────────────────────────────────────
        if !filterSurfaces.isEmpty {
            results = results.filter { filterSurfaces.contains($0.surfaceType) }
        }
        if let courtType = filterCourtType {
            results = results.filter { $0.fullCourt == courtType }
        }
        if let indoor = filterIndoor {
            results = results.filter { $0.indoor == indoor }
        }
        if let maxMiles = filterMaxDistance, let loc = userLocation {
            let origin = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
            let maxMeters = maxMiles * 1609.34
            results = results.filter {
                CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: origin) <= maxMeters
            }
        }

        results.sort { a, b in
            let aFav = favoriteCourtIds.contains(a.id)
            let bFav = favoriteCourtIds.contains(b.id)
            if aFav != bFav { return aFav }
            let aHome = a.id == homeCourtId
            let bHome = b.id == homeCourtId
            if aHome != bHome { return aHome }
            if let loc = userLocation {
                let distA = CLLocation(latitude: a.lat, longitude: a.lng)
                    .distance(from: CLLocation(latitude: loc.latitude, longitude: loc.longitude))
                let distB = CLLocation(latitude: b.lat, longitude: b.lng)
                    .distance(from: CLLocation(latitude: loc.latitude, longitude: loc.longitude))
                return distA < distB
            }
            return a.name < b.name
        }

        return results
    }

    /// Call when the user explicitly resets to the my-courts default view.
    func resetToDefaultView() {
        searchText = ""
        selectedFilter = "All"
        isExploring = false
        filterMaxDistance = nil
        filterSurfaces = []
        filterCourtType = nil
        filterIndoor = nil
    }

    var totalCourtCount: Int { courts.count }
    var activeCourtCount: Int { courts.filter { $0.verified }.count }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            if let loc = locations.first?.coordinate {
                userLocation = loc
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[NETR] Location error: \(error.localizedDescription)")
    }

    func distanceString(for court: Court) -> String {
        guard userLocation != nil else { return "—" }
        let miles = distanceMiles(for: court)
        if miles < 0.1 { return "< 0.1 mi" }
        if miles < 10 { return String(format: "%.1f mi", miles) }
        return String(format: "%.0f mi", miles)
    }

    func distanceMiles(for court: Court) -> Double {
        guard let loc = userLocation else { return .greatestFiniteMagnitude }
        let courtLoc = CLLocation(latitude: court.lat, longitude: court.lng)
        let userLoc = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        return courtLoc.distance(from: userLoc) / 1609.34
    }

    var nearestCourts: [Court] {
        guard userLocation != nil else { return [] }
        return Array(
            courts
                .sorted { distanceMiles(for: $0) < distanceMiles(for: $1) }
                .prefix(3)
        )
    }

    var favoriteCourtsOnly: [Court] {
        courts
            .filter { favoriteCourtIds.contains($0.id) }
            .sorted { distanceMiles(for: $0) < distanceMiles(for: $1) }
    }

    /// Courts within 5 miles that are not already saved/home — shown in default view for new users.
    var nearbyCourtsInDefaultView: [Court] {
        guard let loc = userLocation else { return [] }
        let origin = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        let maxMeters = 5.0 * 1609.34
        return courts
            .filter {
                $0.id != homeCourtId &&
                !favoriteCourtIds.contains($0.id) &&
                CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: origin) <= maxMeters
            }
            .sorted { distanceMiles(for: $0) < distanceMiles(for: $1) }
    }

    /// All courts within 3 miles of the user — always shown on the map regardless of list filters.
    var mapCourts: [Court] {
        guard let loc = userLocation else { return courts }
        let origin = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        let maxMeters = 3.0 * 1609.34
        return courts
            .filter { CLLocation(latitude: $0.lat, longitude: $0.lng).distance(from: origin) <= maxMeters }
            .sorted { distanceMiles(for: $0) < distanceMiles(for: $1) }
    }

    func searchCourts(query: String) -> [Court] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let isZip = q.count == 5 && q.allSatisfy(\.isNumber)
        if isZip {
            return courts
                .filter { $0.zipCode == q }
                .sorted { distanceMiles(for: $0) < distanceMiles(for: $1) }
        }
        let lower = q.lowercased()
        return courts
            .filter {
                $0.name.localizedStandardContains(lower) ||
                $0.neighborhood.localizedStandardContains(lower) ||
                $0.city.localizedStandardContains(lower) ||
                ($0.zipCode?.hasPrefix(q) ?? false)
            }
            .sorted { distanceMiles(for: $0) < distanceMiles(for: $1) }
    }

    func isFavorite(_ courtId: String) -> Bool {
        favoriteCourtIds.contains(courtId)
    }

    func isHomeCourt(_ courtId: String) -> Bool {
        courtId == homeCourtId
    }

    var homeCourtName: String? {
        guard let hid = homeCourtId else { return nil }
        return courts.first(where: { $0.id == hid })?.name
    }

    func loadCourts() async {
        isLoading = true
        error = nil
        do {
            let batchSize = 1000
            var all: [Court] = []
            var offset = 0
            while true {
                let batch: [Court] = try await client
                    .from("courts")
                    .select("id, name, address, neighborhood, city, lat, lng, surface, lights, indoor, full_court, verified, tags, court_rating, submitted_by, photo_count")
                    .range(from: offset, to: offset + batchSize - 1)
                    .execute()
                    .value
                all.append(contentsOf: batch)
                if batch.count < batchSize { break }
                offset += batchSize
            }
            courts = all
            isLoading = false
        } catch let decodingError as DecodingError {
            self.error = "Failed to load courts"
            isLoading = false
            switch decodingError {
            case .typeMismatch(let type, let context):
                print("Courts decode typeMismatch: \(type) at \(context.codingPath.map { $0.stringValue }): \(context.debugDescription)")
            case .keyNotFound(let key, let context):
                print("Courts decode keyNotFound: \(key.stringValue) at \(context.codingPath.map { $0.stringValue }): \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("Courts decode valueNotFound: \(type) at \(context.codingPath.map { $0.stringValue }): \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("Courts decode dataCorrupted: \(context.debugDescription)")
            @unknown default:
                print("[NETR] Courts decode error: \(decodingError)")
            }
        } catch {
            self.error = "Failed to load courts"
            isLoading = false
            print("[NETR] Courts load error: \(error)")
        }
    }

    func loadLiveCourts() async {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let cutoff = fmt.string(from: Date().addingTimeInterval(-4 * 3600))
        do {
            let response = try await client
                .from("games")
                .select("court_id, status, created_at")
                .in("status", values: ["active", "waiting"])
                .gte("created_at", value: cutoff)
                .execute()
            struct GameCourtId: Decodable { let courtId: String?; enum CodingKeys: String, CodingKey { case courtId = "court_id" } }
            let games = try JSONDecoder().decode([GameCourtId].self, from: response.data)
            liveCourtIds = Set(games.compactMap { $0.courtId?.lowercased() })
            print("[NETR Games] Live filter returned \(games.count) games, court IDs: \(liveCourtIds), cutoff: \(cutoff)")
        } catch {
            print("[NETR Games] Live courts load error: \(error)")
        }
    }

    func loadScheduledCourts() async {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let now = fmt.string(from: Date())
        let future = fmt.string(from: Date().addingTimeInterval(48 * 3600))
        do {
            let response = try await client
                .from("games")
                .select("court_id, status, scheduled_at")
                .eq("status", value: "scheduled")
                .gte("scheduled_at", value: now)
                .lte("scheduled_at", value: future)
                .execute()
            struct GameCourtId: Decodable { let courtId: String?; enum CodingKeys: String, CodingKey { case courtId = "court_id" } }
            let games = try JSONDecoder().decode([GameCourtId].self, from: response.data)
            scheduledCourtIds = Set(games.compactMap { $0.courtId?.lowercased() })
            print("[NETR Games] Scheduled filter returned \(games.count) games, court IDs: \(scheduledCourtIds)")
        } catch {
            print("[NETR Games] Scheduled courts load error: \(error)")
        }
    }

    func loadFavorites() async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }
        do {
            let favs: [CourtFavorite] = try await client
                .from("court_favorites")
                .select("court_id, is_home_court")
                .eq("user_id", value: userId)
                .execute()
                .value
            favoriteCourtIds = Set(favs.map { $0.courtId })
            homeCourtId = favs.first(where: { $0.isHomeCourt })?.courtId
        } catch {
            print("[NETR] Favorites load error: \(error)")
        }
    }

    func toggleFavorite(courtId: String) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }

        if favoriteCourtIds.contains(courtId) {
            favoriteCourtIds.remove(courtId)
            if homeCourtId == courtId { homeCourtId = nil }
            do {
                try await client
                    .from("court_favorites")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("court_id", value: courtId)
                    .execute()
            } catch {
                favoriteCourtIds.insert(courtId)
                print("[NETR] Remove favorite error: \(error)")
            }
        } else {
            favoriteCourtIds.insert(courtId)

            nonisolated struct FavPayload: Encodable, Sendable {
                let userId: String
                let courtId: String
                let isHomeCourt: Bool
                nonisolated enum CodingKeys: String, CodingKey {
                    case userId = "user_id"
                    case courtId = "court_id"
                    case isHomeCourt = "is_home_court"
                }
            }

            do {
                try await client
                    .from("court_favorites")
                    .upsert(FavPayload(userId: userId, courtId: courtId, isHomeCourt: false))
                    .execute()
            } catch {
                favoriteCourtIds.remove(courtId)
                print("[NETR] Add favorite error: \(error)")
            }
        }
    }

    func setHomeCourt(courtId: String) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return }

        let previousHome = homeCourtId
        let wasAlreadyFavorite = favoriteCourtIds.contains(courtId)
        homeCourtId = courtId
        favoriteCourtIds.insert(courtId)

        nonisolated struct HomeUpdate: Encodable, Sendable {
            let isHomeCourt: Bool
            nonisolated enum CodingKeys: String, CodingKey {
                case isHomeCourt = "is_home_court"
            }
        }

        nonisolated struct FavPayload: Encodable, Sendable {
            let userId: String
            let courtId: String
            let isHomeCourt: Bool
            nonisolated enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case courtId = "court_id"
                case isHomeCourt = "is_home_court"
            }
        }

        do {
            // Clear home court flag on all existing favorites
            try await client
                .from("court_favorites")
                .update(HomeUpdate(isHomeCourt: false))
                .eq("user_id", value: userId)
                .execute()

            if wasAlreadyFavorite {
                // Row already exists — just flip is_home_court
                try await client
                    .from("court_favorites")
                    .update(HomeUpdate(isHomeCourt: true))
                    .eq("user_id", value: userId)
                    .eq("court_id", value: courtId)
                    .execute()
            } else {
                // No row yet — insert fresh
                try await client
                    .from("court_favorites")
                    .insert(FavPayload(userId: userId, courtId: courtId, isHomeCourt: true))
                    .execute()
            }
        } catch {
            homeCourtId = previousHome
            if !wasAlreadyFavorite { favoriteCourtIds.remove(courtId) }
            print("[NETR] Set home court error: \(error)")
        }
    }

    func addCourt(
        name: String, address: String, neighborhood: String, city: String,
        surface: SurfaceType, lights: Bool, indoor: Bool, fullCourt: Bool
    ) async -> Bool {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString.lowercased() else { return false }

        var lat = 40.7128
        var lng = -74.0060

        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.geocodeAddressString("\(address), \(city)"),
           let loc = placemarks.first?.location {
            lat = loc.coordinate.latitude
            lng = loc.coordinate.longitude
        }

        nonisolated struct NewCourt: Encodable, Sendable {
            let name: String
            let address: String
            let neighborhood: String
            let city: String
            let lat: Double
            let lng: Double
            let surfaceType: String
            let lights: Bool
            let indoor: Bool
            let fullCourt: Bool
            let verified: Bool
            let submittedBy: String
            nonisolated enum CodingKeys: String, CodingKey {
                case name, address, neighborhood, city, lat, lng
                case surfaceType = "surface"
                case lights, indoor
                case fullCourt = "full_court"
                case verified
                case submittedBy = "submitted_by"
            }
        }

        do {
            try await client
                .from("courts")
                .insert(NewCourt(
                    name: name, address: address, neighborhood: neighborhood,
                    city: city, lat: lat, lng: lng, surfaceType: surface.rawValue,
                    lights: lights, indoor: indoor, fullCourt: fullCourt,
                    verified: false, submittedBy: userId
                ))
                .execute()
            await loadCourts()
            return true
        } catch {
            print("[NETR] Add court error: \(error)")
            return false
        }
    }

}
