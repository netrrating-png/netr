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

    // Re-rate lifecycle state (drives the UI in SkillRatingScreen)
    var rerateState: RerateState = .idle

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

    // MARK: - Re-rate context

    /// Checks whether this rater has previously rated this player.
    /// - If yes and within 24 h:  sets `rerateState = .blocked`
    /// - If yes and cooldown over: sets `rerateState = .rerateAvailable` and pre-fills sliders
    /// - If no prior rating:       sets `rerateState = .firstTime`
    ///
    /// Must be called after `players` is populated so pre-fill has a target.
    func loadRerateContext(ratedPlayerId: String) async {
        guard let raterId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        await MainActor.run { rerateState = .loading }

        do {
            // 1. Fetch most recent rating for this rater → rated pair
            let prevRows: [PreviousRatingRow] = try await client
                .from("ratings")
                .select("cat_shooting,cat_finishing,cat_dribbling,cat_passing,cat_defense,cat_rebounding,cat_basketball_iq,vibe_run_again,created_at")
                .eq("rater_id", value: raterId)
                .eq("rated_id", value: ratedPlayerId)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let prev = prevRows.first else {
                await MainActor.run { rerateState = .firstTime }
                return
            }

            // 2. Check 24-hour cooldown
            let prevDate = Self.parseISO8601(prev.createdAt) ?? .distantPast
            let hoursSince = Date().timeIntervalSince(prevDate) / 3600
            guard hoursSince >= 24 else {
                let cooldownEnd = prevDate.addingTimeInterval(24 * 3600)
                await MainActor.run { rerateState = .blocked(blockedUntil: cooldownEnd) }
                return
            }

            // 3. Co-play count (games where BOTH users checked in)
            let coPlayCount = try await fetchCoPlayCount(raterId: raterId, ratedPlayerId: ratedPlayerId)

            // 4. Build previous values snapshot
            let snapshot = PreviousRatingValues(
                catShooting:     prev.catShooting,
                catFinishing:    prev.catFinishing,
                catDribbling:    prev.catDribbling,
                catPassing:      prev.catPassing,
                catDefense:      prev.catDefense,
                catRebounding:   prev.catRebounding,
                catBasketballIq: prev.catBasketballIq,
                vibeRunAgain:    prev.vibeRunAgain
            )

            // 5. Build contextual message
            let firstName = players.first?.name.components(separatedBy: " ").first ?? "them"
            let message = Self.rerateMessage(coPlayCount: coPlayCount, firstName: firstName)

            let ctx = RerateContext(
                coPlayCount: coPlayCount,
                contextualMessage: message,
                previousValues: snapshot
            )

            // 6. Pre-fill sliders with previous values so rater anchors from their read
            await MainActor.run {
                if !players.isEmpty {
                    players[0].skillRatings.shooting     = prev.catShooting
                    players[0].skillRatings.finishing    = prev.catFinishing
                    players[0].skillRatings.dribbling    = prev.catDribbling
                    players[0].skillRatings.passing      = prev.catPassing
                    players[0].skillRatings.defense      = prev.catDefense
                    players[0].skillRatings.rebounding   = prev.catRebounding
                    players[0].skillRatings.basketballIQ = prev.catBasketballIq
                    if let vibe = prev.vibeRunAgain { players[0].vibeRunAgain = vibe }
                }
                rerateState = .rerateAvailable(ctx)
            }

        } catch {
            // On network failure: treat as first-time to keep flow unblocked
            await MainActor.run { rerateState = .firstTime }
            print("[NETR] Re-rate context load error: \(error)")
        }
    }

    // MARK: - Submit

    func submitRating(for playerIndex: Int) async {
        guard playerIndex >= 0, playerIndex < players.count,
              let raterId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        let player = players[playerIndex]
        isSubmitting = true

        // Compute re-rate fields from current state
        let isRerate: Bool
        let previousValues: PreviousRatingValues?
        let coPlayCount: Int
        let ratingWeight: Double

        if case .rerateAvailable(let ctx) = rerateState {
            isRerate = true
            previousValues = ctx.previousValues
            coPlayCount = ctx.coPlayCount
            // Raters with 10+ co-plays get lower delta weight — they're calibrated,
            // their adjustments should move the score gradually not spike it.
            ratingWeight = ctx.coPlayCount >= 10 ? 0.3 : 0.6
        } else {
            isRerate = false
            previousValues = nil
            coPlayCount = 0
            ratingWeight = 1.0
        }

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
            vibeRunAgain:    player.vibeRunAgain,
            isRerate:        isRerate,
            previousValues:  previousValues,
            coPlayCount:     coPlayCount,
            ratingWeight:    ratingWeight
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

    // MARK: - Private helpers

    /// Counts games where both the rater and the rated player checked in.
    /// Fetches both sets of game IDs and intersects them client-side.
    private func fetchCoPlayCount(raterId: String, ratedPlayerId: String) async throws -> Int {
        async let raterTask: [CoPlayGameRow] = client
            .from("game_players")
            .select("game_id, checked_in_at")
            .eq("user_id", value: raterId)
            .execute()
            .value

        async let ratedTask: [CoPlayGameRow] = client
            .from("game_players")
            .select("game_id, checked_in_at")
            .eq("user_id", value: ratedPlayerId)
            .execute()
            .value

        let (raterRows, ratedRows) = try await (raterTask, ratedTask)

        let raterSet = Set(raterRows.filter { $0.checkedInAt != nil }.map { $0.gameId })
        let ratedSet = Set(ratedRows.filter { $0.checkedInAt != nil }.map { $0.gameId })
        return raterSet.intersection(ratedSet).count
    }

    private static func rerateMessage(coPlayCount: Int, firstName: String) -> String {
        switch coPlayCount {
        case 1...3:   return "Still feel the same about \(firstName)?"
        case 4...9:   return "Any new changes with \(firstName)?"
        case 10...14: return "Has \(firstName) got better or worse in anything particular?"
        default:      return "You know their game. Adjust the tape if needed"
        }
    }

    private static func parseISO8601(_ string: String) -> Date? {
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: string) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: string)
    }

    // MARK: - Private Decodable types

    private nonisolated struct PreviousRatingRow: Decodable, Sendable {
        let catShooting: Int?
        let catFinishing: Int?
        let catDribbling: Int?
        let catPassing: Int?
        let catDefense: Int?
        let catRebounding: Int?
        let catBasketballIq: Int?
        let vibeRunAgain: Int?
        let createdAt: String

        nonisolated enum CodingKeys: String, CodingKey {
            case catShooting     = "cat_shooting"
            case catFinishing    = "cat_finishing"
            case catDribbling    = "cat_dribbling"
            case catPassing      = "cat_passing"
            case catDefense      = "cat_defense"
            case catRebounding   = "cat_rebounding"
            case catBasketballIq = "cat_basketball_iq"
            case vibeRunAgain    = "vibe_run_again"
            case createdAt       = "created_at"
        }
    }

    private nonisolated struct CoPlayGameRow: Decodable, Sendable {
        let gameId: String
        let checkedInAt: String?

        nonisolated enum CodingKeys: String, CodingKey {
            case gameId      = "game_id"
            case checkedInAt = "checked_in_at"
        }
    }
}
