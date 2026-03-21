import SwiftUI
import Supabase
import Auth

@Observable
class GameViewModel {

    var game: SupabaseGame?
    var players: [LobbyPlayer] = []
    var isLoading: Bool = false
    var isStarting: Bool = false
    var error: String?

    var joinCode: String = ""
    var isJoining: Bool = false
    var joinError: String?

    var showRateScreen: Bool = false
    var completedGameId: String?
    var isCheckingOut: Bool = false
    var checkOutError: String?
    var noShowReports: [NoShowReport] = []

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    func createGame(
        courtId: String?,
        format: String,
        skillLevel: String,
        scheduledAt: Date? = nil
    ) async throws -> SupabaseGame {
        guard let hostId = SupabaseManager.shared.session?.user.id.uuidString else {
            throw NSError(domain: "NETR", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        let code = generateJoinCode()
        let maxPlayers: Int = GameFormat(rawValue: format)?.maxPlayers ?? 10

        var scheduledAtStr: String? = nil
        if let scheduledAt {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            scheduledAtStr = fmt.string(from: scheduledAt)
        }

        let payload = CreateGamePayload(
            courtId: courtId,
            hostId: hostId,
            joinCode: code,
            format: format,
            skillLevel: skillLevel,
            status: scheduledAt != nil ? "scheduled" : "waiting",
            maxPlayers: maxPlayers,
            scheduledAt: scheduledAtStr
        )

        let created: SupabaseGame = try await client
            .from("games")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        try await addPlayerToGame(gameId: created.id)

        game = created
        await subscribeToLobby(gameId: created.id)
        await loadPlayers(gameId: created.id)
        return created
    }

    func joinGameByCode(_ code: String) async {
        isJoining = true
        joinError = nil

        do {
            let found: SupabaseGame = try await client
                .from("games")
                .select()
                .eq("join_code", value: code.uppercased())
                .eq("status", value: "waiting")
                .single()
                .execute()
                .value

            try await addPlayerToGame(gameId: found.id)

            game = found
            isJoining = false
            await subscribeToLobby(gameId: found.id)
            await loadPlayers(gameId: found.id)
        } catch {
            joinError = "Game not found. Check the code and try again."
            isJoining = false
        }
    }

    private func addPlayerToGame(gameId: String) async throws {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try await client
            .from("game_players")
            .insert(GamePlayerPayload(gameId: gameId, userId: userId, checkedInAt: fmt.string(from: Date())))
            .execute()
    }

    func loadPlayers(gameId: String) async {
        do {
            let result: [LobbyPlayer] = try await client
                .from("game_players")
                .select("id, user_id, game_id, checked_in_at, checked_out_at, removed, profiles(id, full_name, username, position, avatar_url, netr_score, vibe_score, total_ratings)")
                .eq("game_id", value: gameId)
                .order("created_at", ascending: true)
                .execute()
                .value

            players = result.filter { !$0.isRemoved }
        } catch {
            print("Load players error: \(error)")
        }
    }

    func startGame() async {
        guard let gameId = game?.id else { return }
        isStarting = true

        do {
            try await client
                .from("games")
                .update(GameStatusUpdate(status: "active"))
                .eq("id", value: gameId)
                .execute()

            let updated: SupabaseGame = try await client
                .from("games")
                .select()
                .eq("id", value: gameId)
                .single()
                .execute()
                .value

            game = updated
            isStarting = false
        } catch {
            isStarting = false
            print("Start game error: \(error)")
        }
    }

    func endGame() async {
        guard let gameId = game?.id else { return }

        do {
            try await client
                .from("games")
                .update(GameStatusUpdate(status: "completed"))
                .eq("id", value: gameId)
                .execute()

            await unsubscribe()
            completedGameId = gameId
            showRateScreen = true
        } catch {
            print("End game error: \(error)")
        }
    }

    func checkOut() async {
        guard let gameId = game?.id,
              let userId = SupabaseManager.shared.session?.user.id.uuidString
        else { return }

        if !canCheckOut {
            checkOutError = "You must be checked in for at least 15 minutes before checking out."
            return
        }

        isCheckingOut = true
        checkOutError = nil

        nonisolated struct CheckOutUpdate: Encodable, Sendable {
            let checkedOutAt: String
            nonisolated enum CodingKeys: String, CodingKey {
                case checkedOutAt = "checked_out_at"
            }
        }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = fmt.string(from: Date())

        do {
            try await client
                .from("game_players")
                .update(CheckOutUpdate(checkedOutAt: now))
                .eq("game_id", value: gameId)
                .eq("user_id", value: userId)
                .execute()

            await loadPlayers(gameId: gameId)
            isCheckingOut = false

            completedGameId = gameId
            showRateScreen = true
        } catch {
            isCheckingOut = false
            print("Check out error: \(error)")
        }
    }

    var currentUserCheckedOut: Bool {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return false }
        return players.first(where: { $0.userId == userId })?.isCheckedOut ?? false
    }

    var checkedInPlayerIds: Set<String> {
        Set(players.filter { !$0.isCheckedOut && !$0.isRemoved }.map { $0.userId })
    }

    var uncheckedOutCount: Int {
        players.filter { !$0.isCheckedOut && !$0.isRemoved }.count
    }

    // MARK: - 15-Minute Checkout Guard

    var canCheckOut: Bool {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString,
              let player = players.first(where: { $0.userId == userId }),
              let checkedInStr = player.checkedInAt
        else { return false }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: checkedInStr) {
            return Date().timeIntervalSince(d) >= 900
        }
        fmt.formatOptions = [.withInternetDateTime]
        if let d = fmt.date(from: checkedInStr) {
            return Date().timeIntervalSince(d) >= 900
        }
        return true
    }

    var minutesUntilCheckOut: Int {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString,
              let player = players.first(where: { $0.userId == userId }),
              let checkedInStr = player.checkedInAt
        else { return 0 }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var checkedInDate: Date?
        checkedInDate = fmt.date(from: checkedInStr)
        if checkedInDate == nil {
            fmt.formatOptions = [.withInternetDateTime]
            checkedInDate = fmt.date(from: checkedInStr)
        }
        guard let d = checkedInDate else { return 0 }
        let remaining = max(0, 900 - Date().timeIntervalSince(d))
        return Int(ceil(remaining / 60))
    }

    // MARK: - Join Game Directly (by ID)

    func joinGameDirectly(_ gameId: String) async -> SupabaseGame? {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return nil }
        isJoining = true
        joinError = nil

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        do {
            try await client
                .from("game_players")
                .insert(GamePlayerPayload(gameId: gameId, userId: userId, checkedInAt: fmt.string(from: Date())))
                .execute()

            let found: SupabaseGame = try await client
                .from("games")
                .select()
                .eq("id", value: gameId)
                .single()
                .execute()
                .value

            isJoining = false
            return found
        } catch {
            joinError = error.localizedDescription
            isJoining = false
            return nil
        }
    }

    // MARK: - Kick Player (Host only)

    func kickPlayer(playerId: String) async {
        guard let gameId = game?.id else { return }

        nonisolated struct RemoveUpdate: Encodable, Sendable {
            let removed: Bool
        }

        do {
            try await client
                .from("game_players")
                .update(RemoveUpdate(removed: true))
                .eq("game_id", value: gameId)
                .eq("user_id", value: playerId)
                .execute()

            await loadPlayers(gameId: gameId)
        } catch {
            print("Kick player error: \(error)")
        }
    }

    // MARK: - No-Show Reporting

    func reportNoShow(playerId: String) async {
        guard let gameId = game?.id,
              let userId = SupabaseManager.shared.session?.user.id.uuidString
        else { return }

        do {
            try await client
                .from("no_show_reports")
                .insert(NoShowReportPayload(gameId: gameId, reportedByUserId: userId, reportedUserId: playerId))
                .execute()

            let reports: [NoShowReport] = try await client
                .from("no_show_reports")
                .select("id, game_id, reported_by_user_id, reported_user_id")
                .eq("game_id", value: gameId)
                .eq("reported_user_id", value: playerId)
                .execute()
                .value

            if reports.count >= 2 {
                await kickPlayer(playerId: playerId)
            }

            await loadNoShowReports(gameId: gameId)
        } catch {
            print("Report no-show error: \(error)")
        }
    }

    func loadNoShowReports(gameId: String) async {
        do {
            noShowReports = try await client
                .from("no_show_reports")
                .select("id, game_id, reported_by_user_id, reported_user_id")
                .eq("game_id", value: gameId)
                .execute()
                .value
        } catch {
            print("Load no-show reports error: \(error)")
        }
    }

    func hasReportedNoShow(playerId: String) -> Bool {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString,
              let gameId = game?.id
        else { return false }
        return noShowReports.contains { $0.gameId == gameId && $0.reportedByUserId == userId && $0.reportedUserId == playerId }
    }

    func noShowReportCount(playerId: String) -> Int {
        guard let gameId = game?.id else { return 0 }
        return noShowReports.filter { $0.gameId == gameId && $0.reportedUserId == playerId }.count
    }

    // MARK: - Realtime

    func subscribeToLobby(gameId: String) async {
        realtimeChannel = client.realtimeV2.channel("lobby-\(gameId)")

        guard let channel = realtimeChannel else { return }

        let changes = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "game_players"
        )

        await channel.subscribe()

        realtimeTask = Task {
            for await _ in changes {
                await loadPlayers(gameId: gameId)
            }
        }
    }

    func unsubscribe() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let channel = realtimeChannel {
            await client.realtimeV2.removeChannel(channel)
        }
        realtimeChannel = nil
    }

    var isHost: Bool {
        guard let hostId = game?.hostId,
              let userId = SupabaseManager.shared.session?.user.id.uuidString
        else { return false }
        return hostId == userId
    }

    var isFull: Bool {
        guard let max = game?.maxPlayers else { return false }
        return players.count >= max
    }

    var canStart: Bool {
        isHost && players.count >= 2 && game?.status == "waiting"
    }

    // MARK: - Scheduling Helpers

    var scheduledDate: Date? {
        guard let str = game?.scheduledAt else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }

    var isScheduled: Bool {
        scheduledDate != nil
    }

    var timeUntilStart: TimeInterval? {
        guard let scheduled = scheduledDate else { return nil }
        let diff = scheduled.timeIntervalSinceNow
        return diff > 0 ? diff : nil
    }
}
