import Foundation
import CoreLocation

nonisolated enum SurfaceType: String, Sendable, Codable, CaseIterable {
    case asphalt = "Asphalt"
    case concrete = "Concrete"
    case rubber = "Rubber"
    case hardwood = "Hardwood"
}

nonisolated struct Court: Identifiable, Equatable, Codable, Sendable {
    let id: String
    var name: String
    var address: String
    var neighborhood: String
    var city: String
    var lat: Double
    var lng: Double
    var surfaceType: SurfaceType
    var lights: Bool
    var indoor: Bool
    var fullCourt: Bool
    var verified: Bool
    var tags: [String]?
    var zipCode: String?
    var courtRating: Double?
    var submittedBy: String?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    nonisolated static func == (lhs: Court, rhs: Court) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, address, neighborhood, city, lat, lng
        case surfaceType = "surface"
        case lights, indoor, verified, tags
        case fullCourt = "full_court"
        case zipCode = "zip_code"
        case courtRating = "court_rating"
        case submittedBy = "submitted_by"
    }

    init(
        id: String, name: String, address: String, neighborhood: String, city: String,
        lat: Double, lng: Double, surfaceType: SurfaceType, lights: Bool,
        indoor: Bool, fullCourt: Bool, verified: Bool, tags: [String]?,
        zipCode: String? = nil, courtRating: Double? = nil,
        submittedBy: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.neighborhood = neighborhood
        self.city = city
        self.lat = lat
        self.lng = lng
        self.surfaceType = surfaceType
        self.lights = lights
        self.indoor = indoor
        self.fullCourt = fullCourt
        self.verified = verified
        self.tags = tags
        self.zipCode = zipCode
        self.courtRating = courtRating
        self.submittedBy = submittedBy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = try container.decode(String.self, forKey: .id)
        }
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        neighborhood = try container.decodeIfPresent(String.self, forKey: .neighborhood) ?? ""
        city = try container.decodeIfPresent(String.self, forKey: .city) ?? ""
        lat = try container.decode(Double.self, forKey: .lat)
        lng = try container.decode(Double.self, forKey: .lng)
        let surfaceStr = try container.decodeIfPresent(String.self, forKey: .surfaceType) ?? "Asphalt"
        surfaceType = SurfaceType(rawValue: surfaceStr) ?? .asphalt
        lights = try container.decodeIfPresent(Bool.self, forKey: .lights) ?? false
        indoor = try container.decodeIfPresent(Bool.self, forKey: .indoor) ?? false
        fullCourt = try container.decodeIfPresent(Bool.self, forKey: .fullCourt) ?? true
        verified = try container.decodeIfPresent(Bool.self, forKey: .verified) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        zipCode = try container.decodeIfPresent(String.self, forKey: .zipCode)
        courtRating = try container.decodeIfPresent(Double.self, forKey: .courtRating)
        submittedBy = try container.decodeIfPresent(String.self, forKey: .submittedBy)
    }
}

nonisolated struct CourtFavorite: Codable, Sendable {
    let courtId: String
    let isHomeCourt: Bool

    nonisolated enum CodingKeys: String, CodingKey {
        case courtId = "court_id"
        case isHomeCourt = "is_home_court"
    }
}
