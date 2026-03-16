import Foundation

nonisolated struct UserProfile: Codable, Sendable {
    let id: String
    var fullName: String?
    var username: String?
    var position: String?
    var dateOfBirth: String?
    var bio: String?
    var avatarUrl: String?
    var bannerUrl: String?
    var city: String?
    var isProspect: Bool?
    var totalRatings: Int?
    var totalGames: Int?
    var netrScore: Double?
    var catShooting: Double?
    var catFinishing: Double?
    var catDribbling: Double?
    var catPassing: Double?
    var catDefense: Double?
    var catRebounding: Double?
    var catBasketballIq: Double?
    var vibeScore: Double?
    var vibeCommunication: Double?
    var vibeUnselfishness: Double?
    var vibeEffort: Double?
    var vibeAttitude: Double?
    var vibeInclusion: Double?
    var isVerifiedPro: Bool?
    var createdAt: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case username
        case position
        case dateOfBirth = "date_of_birth"
        case bio
        case avatarUrl = "avatar_url"
        case bannerUrl = "banner_url"
        case city
        case isProspect = "is_prospect"
        case totalRatings = "total_ratings"
        case totalGames = "total_games"
        case netrScore = "netr_score"
        case catShooting = "cat_shooting"
        case catFinishing = "cat_finishing"
        case catDribbling = "cat_dribbling"
        case catPassing = "cat_passing"
        case catDefense = "cat_defense"
        case catRebounding = "cat_rebounding"
        case catBasketballIq = "cat_basketball_iq"
        case vibeScore = "vibe_score"
        case vibeCommunication = "vibe_communication"
        case vibeUnselfishness = "vibe_unselfishness"
        case vibeEffort = "vibe_effort"
        case vibeAttitude = "vibe_attitude"
        case vibeInclusion = "vibe_inclusion"
        case isVerifiedPro = "is_verified_pro"
        case createdAt = "created_at"
    }
}

extension UserProfile {

    func toPlayer() -> Player {
        let skills = [
            catShooting, catFinishing, catDribbling, catPassing,
            catDefense, catRebounding, catBasketballIq
        ].compactMap { $0 }

        let overallScore: Double? = netrScore ?? (skills.isEmpty
            ? nil
            : skills.reduce(0, +) / Double(skills.count))

        let posEnum: Position = {
            guard let p = position?.uppercased() else { return .unknown }
            return Position(rawValue: p) ?? .unknown
        }()

        let tier: PlayerTier = {
            if isProspect == true { return .prospect }
            if (totalRatings ?? 0) >= 5 { return .verified }
            return .basic
        }()

        let trend: TrendDirection = .none

        let initials: String = {
            guard let name = fullName else { return "?" }
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }()

        return Player(
            id: abs(id.hashValue),
            name: fullName ?? username ?? "Player",
            username: username.map { "@\($0)" } ?? "@player",
            avatar: initials,
            rating: overallScore,
            reviews: totalRatings ?? 0,
            age: ageFromDOB(),
            tier: tier,
            city: city ?? "New York, NY",
            position: posEnum,
            trend: trend,
            games: totalGames ?? 0,
            isProspect: isProspect ?? false,
            skills: SkillRatings(
                shooting: catShooting,
                finishing: catFinishing,
                ballHandling: catDribbling,
                playmaking: catPassing,
                defense: catDefense,
                rebounding: catRebounding,
                basketballIQ: catBasketballIq
            ),
            profileImageData: nil,
            avatarUrl: avatarUrl,
            bannerUrl: bannerUrl
        )
    }

    private func ageFromDOB() -> Int {
        guard let dob = dateOfBirth else { return 0 }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dob) else { return 0 }
        let years = Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
        return years
    }
}
