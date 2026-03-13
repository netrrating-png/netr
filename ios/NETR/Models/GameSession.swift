import Foundation

nonisolated enum GameFormat: String, CaseIterable, Sendable, Identifiable {
    case threeVThree = "3v3"
    case fourVFour = "4v4"
    case fiveVFive = "5v5"
    case run = "Run"

    var id: String { rawValue }

    var maxPlayers: Int {
        switch self {
        case .threeVThree: return 6
        case .fourVFour: return 8
        case .fiveVFive: return 10
        case .run: return 20
        }
    }
}

nonisolated enum SkillFilter: String, CaseIterable, Sendable, Identifiable {
    case any = "Any Level"
    case beginner = "Beginner"
    case recreational = "Recreational"
    case competitive = "Competitive"
    case advanced = "Advanced"
    case elite = "Elite"

    var id: String { rawValue }
}

struct GameSession: Identifiable, Equatable {
    let id: UUID
    let court: Court
    let format: GameFormat
    let skillFilter: SkillFilter
    let joinCode: String
    var players: [Player]
    var isActive: Bool

    static func == (lhs: GameSession, rhs: GameSession) -> Bool {
        lhs.id == rhs.id
    }
}
