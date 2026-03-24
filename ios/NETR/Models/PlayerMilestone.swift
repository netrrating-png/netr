import SwiftUI

// MARK: - Milestone Type

enum MilestoneType: String, CaseIterable, Codable, Sendable {
    case highSchoolJV      = "hs_jv"
    case highSchoolVarsity = "hs_varsity"
    case aau               = "aau"
    case juco              = "juco"
    case collegeD3         = "college_d3"
    case collegeD2         = "college_d2"
    case collegeD1         = "college_d1"
    case proSemiPro        = "pro_semi"
    case cityLeague        = "city_league"

    var displayName: String {
        switch self {
        case .highSchoolJV:      return "High School JV"
        case .highSchoolVarsity: return "High School Varsity"
        case .aau:               return "AAU"
        case .juco:              return "JUCO"
        case .collegeD3:         return "College D3"
        case .collegeD2:         return "College D2"
        case .collegeD1:         return "College D1"
        case .proSemiPro:        return "Pro / Semi-Pro"
        case .cityLeague:        return "City / Rec League"
        }
    }

    /// SF Symbol name used for display
    var sfSymbol: String {
        switch self {
        case .highSchoolJV:      return "figure.run"
        case .highSchoolVarsity: return "trophy.fill"
        case .aau:               return "bolt.fill"
        case .juco:              return "graduationcap"
        case .collegeD3:         return "graduationcap.fill"
        case .collegeD2:         return "graduationcap.fill"
        case .collegeD1:         return "building.columns.fill"
        case .proSemiPro:        return "star.fill"
        case .cityLeague:        return "person.3.fill"
        }
    }

    /// Prestige order — higher = more notable (used to pick the profile badge)
    var prestige: Int {
        switch self {
        case .cityLeague:        return 1
        case .aau:               return 2
        case .highSchoolJV:      return 3
        case .highSchoolVarsity: return 4
        case .juco:              return 5
        case .collegeD3:         return 6
        case .collegeD2:         return 7
        case .collegeD1:         return 8
        case .proSemiPro:        return 9
        }
    }

    var badgeColor: Color {
        switch self {
        case .highSchoolJV:      return Color(hex: "#2DA8FF")
        case .highSchoolVarsity: return NETRTheme.neonGreen
        case .aau:               return Color(hex: "#FFC247")
        case .juco:              return Color(hex: "#7B9FFF")
        case .collegeD3:         return Color(hex: "#7B9FFF")
        case .collegeD2:         return Color(hex: "#FF7A00")
        case .collegeD1:         return Color(hex: "#FF3B30")
        case .proSemiPro:        return Color(hex: "#C40010")
        case .cityLeague:        return NETRTheme.subtext
        }
    }
}

// MARK: - Model

nonisolated struct PlayerMilestone: Identifiable, Codable, Sendable {
    let id: String
    let userId: String
    var milestoneType: MilestoneType
    var teamName: String?
    var season: String?
    let createdAt: Date

    nonisolated enum CodingKeys: String, CodingKey {
        case id
        case userId        = "user_id"
        case milestoneType = "milestone_type"
        case teamName      = "team_name"
        case season
        case createdAt     = "created_at"
    }

    /// Short label shown on chips
    var chipLabel: String {
        if let team = teamName, !team.isEmpty { return team }
        return milestoneType.displayName
    }

    /// Subtitle shown in the milestones list
    var subtitle: String? {
        var parts: [String] = []
        if let team = teamName, !team.isEmpty { parts.append(team) }
        if let s = season, !s.isEmpty { parts.append(s) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Insert / Update Payloads

nonisolated struct MilestoneInsert: Encodable, Sendable {
    let userId: String
    let milestoneType: String
    let teamName: String?
    let season: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case userId        = "user_id"
        case milestoneType = "milestone_type"
        case teamName      = "team_name"
        case season
    }
}

nonisolated struct MilestoneUpdate: Encodable, Sendable {
    let milestoneType: String
    let teamName: String?
    let season: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case milestoneType = "milestone_type"
        case teamName      = "team_name"
        case season
    }
}
