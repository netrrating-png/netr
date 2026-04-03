import SwiftUI
import Supabase
import Auth
import PostgREST

@Observable
class RateViewModel {

    var players: [PlayerToRate] = []
    var currentIndex: Int = 0
    var isSubmitting: Bool = false
    var isComplete: Bool = false
    var error: String?
    var hasLoadedOnce: Bool = false

    private let client = SupabaseManager.shared.client
    private var gameId: String?

    func setGameId(_ id: String) { gameId = id }

    var currentPlayer: PlayerToRate? {
        guard currentIndex < players.count else { return nil }
        return players[currentIndex]
    }

    // MARK: - Skill ratings

    func setSkillRating(playerIndex: Int, key: String, value: Int) {
        guard playerIndex < players.count else { return }
        switch key {
        case "shooting":     players[playerIndex].skillRatings.shooting     = value
        case "finishing":    players[playerIndex].skillRatings.finishing    = value
        case "dribbling":    players[playerIndex].skillRatings.dribbling    = value
        case "passing":      players[playerIndex].skillRatings.passing      = value
        case "defense":      players[playerIndex].skillRatings.defense      = value
        case "rebounding":   players[playerIndex].skillRatings.rebounding   = value
        case "basketballIQ": players[playerIndex].skillRatings.basketballIQ = value
        default: break
        }
    }

    func skillValue(for key: String, playerIndex: Int) -> Int? {
        guard playerIndex >= 0, playerIndex < players.count else { return nil }
        let p = players[playerIndex]
        switch key {
        case "shooting":     return p.skillRatings.shooting
        case "finishing":    return p.skillRatings.finishing
        case "dribbling":    return p.skillRatings.dribbling
        case "passing":      return p.skillRatings.passing
        case "defense":      return p.skillRatings.defense
        case "rebounding":   return p.skillRatings.rebounding
        case "basketballIQ": return p.skillRatings.basketballIQ
        default: return nil
        }
    }

    // MARK: - Vibe (single run-again question)

    func setVibeRunAgain(playerIndex: Int, value: Int) {
        guard playerIndex < players.count else { return }
        players[playerIndex].vibeRunAgain = value
    }

    func vibeRunAgainValue(playerIndex: Int) -> Int? {
        guard playerIndex >= 0, playerIndex < players.count else { return nil }
        return players[playerIndex].vibeRunAgain
    }

    func vibeAccentColor(playerIndex: Int) -> Color {
        guard playerIndex >= 0, playerIndex < players.count,
              let value = players[playerIndex].vibeRunAgain else { return NETRTheme.neonGreen }
        return Color(hex: vibeRunAgainOptions.first { $0.id == value }?.colorHex ?? "#39FF14")
    }

    // MARK: - Submit

    func submitRating(for playerIndex: Int) async {
        guard playerIndex >= 0, playerIndex < players.count,
              let raterId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        let player = players[playerIndex]
        isSubmitting = true

        let submission = RatingSubmission(
            gameId:          gameId ?? "",
            raterId:         raterId,
            ratedId:         player.id,
            isSelfRating:    false,
            catShooting:     player.skillRatings.shooting,
            catFinishing:    player.skillRatings.finishing,
            catDribbling:    player.skillRatings.dribbling,
            catPassing:      player.skillRatings.passing,
            catDefense:      player.skillRatings.defense,
            catRebounding:   player.skillRatings.rebounding,
            catBasketballIq: player.skillRatings.basketballIQ,
            vibeRunAgain:    player.vibeRunAgain
        )

        do {
            try await client
                .from("ratings")
                .insert(submission)
                .execute()

            players[playerIndex].isSubmitted = true
            isSubmitting = false
        } catch {
            self.error = "Failed to submit rating"
            isSubmitting = false
            print("[NETR] Rating submit error: \(error)")
        }
    }
}
