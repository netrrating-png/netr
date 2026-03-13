import SwiftUI
import Supabase

@Observable
class RateViewModel {

    var players: [PlayerToRate] = []
    var currentIndex: Int = 0
    var isSubmitting: Bool = false
    var isComplete: Bool = false
    var error: String?
    var activeTab: RatingTab = .skill
    var hasLoadedOnce: Bool = false

    enum RatingTab: String, CaseIterable {
        case skill = "SKILL"
        case vibe = "VIBE"
    }

    private let client = SupabaseManager.shared.client
    private var gameId: String?

    func setGameId(_ id: String) {
        gameId = id
    }

    var currentPlayer: PlayerToRate? {
        guard currentIndex < players.count else { return nil }
        return players[currentIndex]
    }

    var progress: Double {
        guard !players.isEmpty else { return 0 }
        return Double(currentIndex) / Double(players.count)
    }

    func loadGamePlayers(gameId: String) async {
        self.gameId = gameId
        guard let currentUserId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        nonisolated struct GamePlayerRow: Decodable, Sendable {
            let userId: String
            let profile: ProfileSnippet

            nonisolated struct ProfileSnippet: Decodable, Sendable {
                let id: String
                let fullName: String?
                let username: String?
                let position: String?
                let avatarUrl: String?
                let netrScore: Double?
                let vibeScore: Double?

                nonisolated enum CodingKeys: String, CodingKey {
                    case id
                    case fullName = "full_name"
                    case username
                    case position
                    case avatarUrl = "avatar_url"
                    case netrScore = "netr_score"
                    case vibeScore = "vibe_score"
                }
            }

            nonisolated enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case profile = "profiles"
            }
        }

        do {
            let rows: [GamePlayerRow] = try await client
                .from("game_players")
                .select("user_id, profiles(id, full_name, username, position, avatar_url, netr_score, vibe_score)")
                .eq("game_id", value: gameId)
                .neq("user_id", value: currentUserId)
                .execute()
                .value

            players = rows.map { row in
                PlayerToRate(
                    id: row.profile.id,
                    name: row.profile.fullName ?? row.profile.username ?? "Player",
                    username: row.profile.username ?? "",
                    position: row.profile.position ?? "PG",
                    avatarUrl: row.profile.avatarUrl,
                    currentNetr: row.profile.netrScore,
                    currentVibe: row.profile.vibeScore
                )
            }
            hasLoadedOnce = true
        } catch {
            self.error = "Couldn't load players"
            hasLoadedOnce = true
            print("Load game players error: \(error)")
        }
    }

    func loadNearbyPlayers() async {
        guard let currentUserId = SupabaseManager.shared.session?.user.id.uuidString else {
            hasLoadedOnce = true
            return
        }

        nonisolated struct ProfileRow: Decodable, Sendable {
            let id: String
            let fullName: String?
            let username: String?
            let position: String?
            let avatarUrl: String?
            let netrScore: Double?
            let vibeScore: Double?

            nonisolated enum CodingKeys: String, CodingKey {
                case id
                case fullName = "full_name"
                case username
                case position
                case avatarUrl = "avatar_url"
                case netrScore = "netr_score"
                case vibeScore = "vibe_score"
            }
        }

        do {
            let rows: [ProfileRow] = try await client
                .from("profiles")
                .select("id, full_name, username, position, avatar_url, netr_score, vibe_score")
                .neq("id", value: currentUserId)
                .limit(20)
                .execute()
                .value

            players = rows.map { row in
                PlayerToRate(
                    id: row.id,
                    name: row.fullName ?? row.username ?? "Player",
                    username: row.username ?? "",
                    position: row.position ?? "PG",
                    avatarUrl: row.avatarUrl,
                    currentNetr: row.netrScore,
                    currentVibe: row.vibeScore
                )
            }
            hasLoadedOnce = true
        } catch {
            self.error = "Couldn't load players"
            hasLoadedOnce = true
            print("Load players error: \(error)")
        }
    }

    func setSkillRating(playerIndex: Int, key: String, value: Int) {
        guard playerIndex < players.count else { return }
        switch key {
        case "shooting":      players[playerIndex].skillRatings.shooting = value
        case "finishing":     players[playerIndex].skillRatings.finishing = value
        case "dribbling":     players[playerIndex].skillRatings.dribbling = value
        case "passing":       players[playerIndex].skillRatings.passing = value
        case "defense":       players[playerIndex].skillRatings.defense = value
        case "rebounding":    players[playerIndex].skillRatings.rebounding = value
        case "basketballIQ":  players[playerIndex].skillRatings.basketballIQ = value
        default: break
        }
    }

    func setVibeRating(playerIndex: Int, key: String, value: Int) {
        guard playerIndex < players.count else { return }
        switch key {
        case "communication": players[playerIndex].vibeRatings.communication = value
        case "unselfishness": players[playerIndex].vibeRatings.unselfishness = value
        case "effort":        players[playerIndex].vibeRatings.effort = value
        case "attitude":      players[playerIndex].vibeRatings.attitude = value
        case "inclusion":     players[playerIndex].vibeRatings.inclusion = value
        default: break
        }
    }

    func loadExistingRating(for playerIndex: Int) async {
        guard playerIndex >= 0, playerIndex < players.count,
              let raterId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        let player = players[playerIndex]

        nonisolated struct ExistingRating: Decodable, Sendable {
            let catShooting: Int?
            let catFinishing: Int?
            let catDribbling: Int?
            let catPassing: Int?
            let catDefense: Int?
            let catRebounding: Int?
            let catBasketballIq: Int?
            let vibeCommunication: Int?
            let vibeUnselfishness: Int?
            let vibeEffort: Int?
            let vibeAttitude: Int?
            let vibeInclusion: Int?

            nonisolated enum CodingKeys: String, CodingKey {
                case catShooting = "cat_shooting"
                case catFinishing = "cat_finishing"
                case catDribbling = "cat_dribbling"
                case catPassing = "cat_passing"
                case catDefense = "cat_defense"
                case catRebounding = "cat_rebounding"
                case catBasketballIq = "cat_basketball_iq"
                case vibeCommunication = "vibe_communication"
                case vibeUnselfishness = "vibe_unselfishness"
                case vibeEffort = "vibe_effort"
                case vibeAttitude = "vibe_attitude"
                case vibeInclusion = "vibe_inclusion"
            }
        }

        do {
            let rows: [ExistingRating] = try await client
                .from("ratings")
                .select("cat_shooting, cat_finishing, cat_dribbling, cat_passing, cat_defense, cat_rebounding, cat_basketball_iq, vibe_communication, vibe_unselfishness, vibe_effort, vibe_attitude, vibe_inclusion")
                .eq("rater_id", value: raterId)
                .eq("rated_id", value: player.id)
                .limit(1)
                .execute()
                .value

            if let existing = rows.first {
                players[playerIndex].skillRatings.shooting = existing.catShooting
                players[playerIndex].skillRatings.finishing = existing.catFinishing
                players[playerIndex].skillRatings.dribbling = existing.catDribbling
                players[playerIndex].skillRatings.passing = existing.catPassing
                players[playerIndex].skillRatings.defense = existing.catDefense
                players[playerIndex].skillRatings.rebounding = existing.catRebounding
                players[playerIndex].skillRatings.basketballIQ = existing.catBasketballIq
                players[playerIndex].vibeRatings.communication = existing.vibeCommunication
                players[playerIndex].vibeRatings.unselfishness = existing.vibeUnselfishness
                players[playerIndex].vibeRatings.effort = existing.vibeEffort
                players[playerIndex].vibeRatings.attitude = existing.vibeAttitude
                players[playerIndex].vibeRatings.inclusion = existing.vibeInclusion
            }
        } catch {
            print("Load existing rating error: \(error)")
        }
    }

    func submitRating(for playerIndex: Int) async {
        guard playerIndex >= 0, playerIndex < players.count,
              let raterId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        let player = players[playerIndex]
        isSubmitting = true

        let submission = RatingSubmission(
            gameId: gameId ?? "",
            raterId: raterId,
            ratedId: player.id,
            isSelfRating: false,
            catShooting: player.skillRatings.shooting,
            catFinishing: player.skillRatings.finishing,
            catDribbling: player.skillRatings.dribbling,
            catPassing: player.skillRatings.passing,
            catDefense: player.skillRatings.defense,
            catRebounding: player.skillRatings.rebounding,
            catBasketballIq: player.skillRatings.basketballIQ,
            vibeCommunication: player.vibeRatings.communication,
            vibeUnselfishness: player.vibeRatings.unselfishness,
            vibeEffort: player.vibeRatings.effort,
            vibeAttitude: player.vibeRatings.attitude,
            vibeInclusion: player.vibeRatings.inclusion
        )

        do {
            try await client
                .from("ratings")
                .upsert(submission, onConflict: "rater_id,rated_id")
                .execute()

            players[playerIndex].isSubmitted = true
            isSubmitting = false
        } catch {
            self.error = "Failed to submit rating"
            isSubmitting = false
            print("Rating submit error: \(error)")
        }
    }

    func submitCurrentAndAdvance() async {
        guard currentIndex < players.count else { return }
        await submitRating(for: currentIndex)
        if currentIndex + 1 < players.count {
            currentIndex += 1
            activeTab = .skill
        } else {
            isComplete = true
        }
    }

    func skipCurrent() {
        if currentIndex + 1 < players.count {
            currentIndex += 1
            activeTab = .skill
        } else {
            isComplete = true
        }
    }

    func skillValue(for key: String, playerIndex: Int) -> Int? {
        guard playerIndex >= 0, playerIndex < players.count else { return nil }
        let p = players[playerIndex]
        switch key {
        case "shooting":      return p.skillRatings.shooting
        case "finishing":     return p.skillRatings.finishing
        case "dribbling":     return p.skillRatings.dribbling
        case "passing":       return p.skillRatings.passing
        case "defense":       return p.skillRatings.defense
        case "rebounding":    return p.skillRatings.rebounding
        case "basketballIQ":  return p.skillRatings.basketballIQ
        default: return nil
        }
    }

    func vibeValue(for key: String, playerIndex: Int) -> Int? {
        guard playerIndex >= 0, playerIndex < players.count else { return nil }
        let p = players[playerIndex]
        switch key {
        case "communication": return p.vibeRatings.communication
        case "unselfishness": return p.vibeRatings.unselfishness
        case "effort":        return p.vibeRatings.effort
        case "attitude":      return p.vibeRatings.attitude
        case "inclusion":     return p.vibeRatings.inclusion
        default: return nil
        }
    }

    func vibeAccentColor(playerIndex: Int) -> Color {
        guard playerIndex >= 0, playerIndex < players.count else { return NETRTheme.neonGreen }
        let p = players[playerIndex]
        let vals = [p.vibeRatings.communication, p.vibeRatings.unselfishness,
                    p.vibeRatings.effort, p.vibeRatings.attitude, p.vibeRatings.inclusion]
            .compactMap { $0 }
        guard !vals.isEmpty else { return NETRTheme.neonGreen }
        let avg = Double(vals.reduce(0, +)) / Double(vals.count)
        let tier = VibeTier.from(score: avg) ?? .none
        return Color(red: tier.color.red, green: tier.color.green, blue: tier.color.blue)
    }
}
