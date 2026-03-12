import SwiftUI
import Supabase

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

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    func createGame(
        courtId: String?,
        format: String,
        skillLevel: String
    ) async throws -> SupabaseGame {
        guard let hostId = SupabaseManager.shared.session?.user.id.uuidString else {
            throw NSError(domain: "NETR", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        let code = generateJoinCode()
        let maxPlayers: Int = {
            switch format {
            case "3v3": return 6
            case "4v4": return 8
            case "5v5": return 10
            case "Run": return 20
            default: return 10
            }
        }()

        let payload = CreateGamePayload(
            courtId: courtId,
            hostId: hostId,
            joinCode: code,
            format: format,
            skillLevel: skillLevel,
            status: "waiting",
            maxPlayers: maxPlayers
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
        try await client
            .from("game_players")
            .insert(GamePlayerPayload(gameId: gameId, userId: userId))
            .execute()
    }

    func loadPlayers(gameId: String) async {
        do {
            let result: [LobbyPlayer] = try await client
                .from("game_players")
                .select("id, user_id, game_id, profiles(id, full_name, username, position, avatar_url, netr_score, vibe_score)")
                .eq("game_id", value: gameId)
                .order("joined_at", ascending: true)
                .execute()
                .value

            players = result
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
}
