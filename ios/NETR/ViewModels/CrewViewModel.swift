import Foundation
import Supabase

@Observable
class CrewViewModel {

    // MARK: - State
    var myCrews: [MyCrew] = []
    var currentCrew: Crew? = nil
    var members: [CrewMemberProfile] = []
    var messages: [CrewMessage] = []
    var senderProfiles: [String: (name: String, avatarUrl: String?)] = [:]
    var leaderboardFilter: CrewLeaderboardFilter = .overall
    var isLoading: Bool = false
    var isSending: Bool = false
    var errorMessage: String? = nil
    var sendText: String = ""

    private let client = SupabaseManager.shared.client
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    var currentUserId: String? {
        SupabaseManager.shared.session?.user.id.uuidString
    }

    var sortedMembers: [CrewMemberProfile] {
        members.sorted {
            ($0.score(for: leaderboardFilter) ?? -1) > ($1.score(for: leaderboardFilter) ?? -1)
        }
    }

    var primaryCrew: MyCrew? {
        myCrews.first { $0.isPrimary } ?? myCrews.first
    }

    // MARK: - Load My Crews
    func loadMyCrews() async {
        guard let userId = currentUserId else { return }
        isLoading = true
        errorMessage = nil

        do {
            let memberRows: [CrewMember] = try await client
                .from("crew_members")
                .select("id, crew_id, user_id, joined_at, is_primary, last_read_at")
                .eq("user_id", value: userId)
                .execute()
                .value

            let crewIds = memberRows.map { $0.crewId }
            guard !crewIds.isEmpty else {
                myCrews = []
                isLoading = false
                return
            }

            let crews: [Crew] = try await client
                .from("crews")
                .select("id, name, icon, creator_id, admin_id, created_at")
                .in("id", values: crewIds)
                .order("created_at", ascending: false)
                .execute()
                .value

            let memberMap = Dictionary(uniqueKeysWithValues: memberRows.map { ($0.crewId, $0) })
            myCrews = crews.compactMap { crew in
                guard let row = memberMap[crew.id] else { return nil }
                return MyCrew(crew: crew, memberRow: row)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Load Members (for leaderboard)
    func loadMembers(crewId: String) async {
        // Inner profile struct for decoding
        nonisolated struct ProfileRow: Decodable, Sendable {
            let id: String
            let fullName: String?
            let username: String?
            let avatarUrl: String?
            let netrScore: Double?
            let catShooting: Double?
            let catFinishing: Double?
            let catDribbling: Double?
            let catPassing: Double?
            let catDefense: Double?
            let catRebounding: Double?
            let catBasketballIq: Double?
            let reviewCount: Int?
            nonisolated enum CodingKeys: String, CodingKey {
                case id
                case fullName        = "full_name"
                case username
                case avatarUrl       = "avatar_url"
                case netrScore       = "netr_score"
                case catShooting     = "cat_shooting"
                case catFinishing    = "cat_finishing"
                case catDribbling    = "cat_dribbling"
                case catPassing      = "cat_passing"
                case catDefense      = "cat_defense"
                case catRebounding   = "cat_rebounding"
                case catBasketballIq = "cat_basketball_iq"
                case reviewCount     = "review_count"
            }
        }

        do {
            let memberRows: [CrewMember] = try await client
                .from("crew_members")
                .select("id, crew_id, user_id, joined_at, is_primary, last_read_at")
                .eq("crew_id", value: crewId)
                .execute()
                .value

            guard !memberRows.isEmpty else { members = []; return }

            // Lowercase IDs for profile lookup — Swift uuidString is uppercase
            let userIds = memberRows.map { $0.userId.lowercased() }

            // Fetch profiles
            let profiles: [ProfileRow] = try await client
                .from("profiles")
                .select("id, full_name, username, avatar_url, netr_score, cat_shooting, cat_finishing, cat_dribbling, cat_passing, cat_defense, cat_rebounding, cat_basketball_iq, review_count")
                .in("id", values: userIds)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id.lowercased(), $0) })

            members = memberRows.map { member in
                let p = profileMap[member.userId.lowercased()]
                return CrewMemberProfile(
                    id: member.userId,
                    memberId: member.id,
                    fullName: p?.fullName,
                    username: p?.username,
                    avatarUrl: p?.avatarUrl,
                    netrScore: p?.netrScore,
                    catShooting: p?.catShooting,
                    catFinishing: p?.catFinishing,
                    catDribbling: p?.catDribbling,
                    catPassing: p?.catPassing,
                    catDefense: p?.catDefense,
                    catRebounding: p?.catRebounding,
                    catBasketballIq: p?.catBasketballIq,
                    reviewCount: p?.reviewCount,
                    isPrimary: member.isPrimary ?? false,
                    joinedAt: member.joinedAt
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Create Crew
    func createCrew(name: String, icon: String, password: String) async throws {
        guard let userId = currentUserId else { throw CrewError.notAuthenticated }
        guard myCrews.count < 5 else { throw CrewError.tooManyCrews }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = fmt.string(from: Date())

        let created: Crew
        do {
            created = try await client
                .from("crews")
                .insert(CreateCrewPayload(name: name, icon: icon, password: password, creatorId: userId, adminId: userId))
                .select("id, name, icon, creator_id, admin_id, created_at")
                .single()
                .execute()
                .value
        } catch {
            if error.localizedDescription.contains("crews_name_key") ||
               error.localizedDescription.contains("unique constraint") {
                throw CrewError.nameTaken
            }
            throw error
        }

        // Add creator as first member
        try await client
            .from("crew_members")
            .insert(CrewMemberPayload(crewId: created.id, userId: userId, joinedAt: now))
            .execute()

        // Set as primary if first crew
        if myCrews.isEmpty {
            try? await client
                .from("crew_members")
                .update(["is_primary": true])
                .eq("crew_id", value: created.id)
                .eq("user_id", value: userId)
                .execute()
        }

        await loadMyCrews()
    }

    // MARK: - Search Crews
    func searchCrews(query: String) async -> [CrewSearchResult] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        let results: [CrewSearchResult] = (try? await client
            .from("crews")
            .select("id, name, icon")
            .ilike("name", pattern: "%\(q)%")
            .limit(10)
            .execute()
            .value) ?? []
        return results
    }

    // MARK: - Join Crew
    func joinCrew(name: String, password: String) async throws {
        guard let userId = currentUserId else { throw CrewError.notAuthenticated }
        guard myCrews.count < 5 else { throw CrewError.tooManyCrews }

        // Find crew by name + password (case-insensitive name match)
        // We filter by password so the server never sends the password back
        nonisolated struct CrewLookup: Decodable, Sendable {
            let id: String
            let name: String
            let icon: String
            let creatorId: String
            let adminId: String
            let createdAt: String?
            nonisolated enum CodingKeys: String, CodingKey {
                case id, name, icon
                case creatorId = "creator_id"
                case adminId   = "admin_id"
                case createdAt = "created_at"
            }
        }

        // First find by name
        let byName: [CrewLookup] = (try? await client
            .from("crews")
            .select("id, name, icon, creator_id, admin_id, created_at")
            .ilike("name", pattern: name)
            .limit(1)
            .execute()
            .value) ?? []

        guard let found = byName.first else { throw CrewError.crewNotFound }

        // Verify password by querying with both id AND password — if no result, wrong password
        let verified: [CrewLookup] = (try? await client
            .from("crews")
            .select("id, name, icon, creator_id, admin_id, created_at")
            .eq("id", value: found.id)
            .eq("password", value: password)
            .limit(1)
            .execute()
            .value) ?? []

        guard !verified.isEmpty else { throw CrewError.wrongPassword }

        // Check member count
        let memberRows: [CrewMember] = (try? await client
            .from("crew_members")
            .select("id, crew_id, user_id, joined_at, is_primary, last_read_at")
            .eq("crew_id", value: found.id)
            .execute()
            .value) ?? []

        guard memberRows.count < 50 else { throw CrewError.crewFull }
        guard !memberRows.contains(where: { $0.userId.lowercased() == userId.lowercased() }) else {
            throw CrewError.alreadyMember
        }

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        try await client
            .from("crew_members")
            .insert(CrewMemberPayload(crewId: found.id, userId: userId, joinedAt: fmt.string(from: Date())))
            .execute()

        await loadMyCrews()
    }

    // MARK: - Leave Crew
    func leaveCrew(crewId: String) async throws {
        guard let userId = currentUserId else { throw CrewError.notAuthenticated }
        try await client
            .from("crew_members")
            .delete()
            .eq("crew_id", value: crewId)
            .eq("user_id", value: userId)
            .execute()
        await loadMyCrews()
    }

    // MARK: - Remove Member (admin)
    func removeMember(crewId: String, userId: String) async throws {
        try await client
            .from("crew_members")
            .delete()
            .eq("crew_id", value: crewId)
            .eq("user_id", value: userId)
            .execute()
        await loadMembers(crewId: crewId)
    }

    // MARK: - Delete Crew (admin only)
    func deleteCrew(crewId: String) async throws {
        try await client
            .from("crews")
            .delete()
            .eq("id", value: crewId)
            .execute()
        await loadMyCrews()
    }

    // Alias used by CrewDetailView
    func loadCrewDetail(crewId: String) async {
        await loadMembers(crewId: crewId)
    }

    // MARK: - Transfer Admin
    func transferAdmin(crewId: String, toUserId: String) async throws {
        try await client
            .from("crews")
            .update(["admin_id": toUserId])
            .eq("id", value: crewId)
            .execute()
        if var crew = currentCrew, crew.id == crewId {
            crew.adminId = toUserId
            currentCrew = crew
        }
        await loadMyCrews()
    }

    // MARK: - Set Primary Crew (for profile display)
    func setPrimary(crewId: String) async throws {
        guard let userId = currentUserId else { throw CrewError.notAuthenticated }
        // Unset all
        try await client
            .from("crew_members")
            .update(["is_primary": false])
            .eq("user_id", value: userId)
            .execute()
        // Set new primary
        try await client
            .from("crew_members")
            .update(["is_primary": true])
            .eq("crew_id", value: crewId)
            .eq("user_id", value: userId)
            .execute()
        await loadMyCrews()
    }

    // MARK: - Messages
    func loadMessages(crewId: String) async {
        do {
            let msgs: [CrewMessage] = try await client
                .from("crew_messages")
                .select("id, crew_id, sender_id, content, created_at")
                .eq("crew_id", value: crewId)
                .order("created_at", ascending: true)
                .execute()
                .value
            messages = msgs
            await loadSenderProfiles(for: msgs)
            await markRead(crewId: crewId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSenderProfiles(for msgs: [CrewMessage]) async {
        let ids = Array(Set(msgs.map { $0.senderId }))
        guard !ids.isEmpty else { return }

        nonisolated struct SenderRow: Decodable, Sendable {
            let id: String
            let fullName: String?
            let username: String?
            let avatarUrl: String?
            nonisolated enum CodingKeys: String, CodingKey {
                case id
                case fullName  = "full_name"
                case username
                case avatarUrl = "avatar_url"
            }
        }

        let rows: [SenderRow] = (try? await client
            .from("profiles")
            .select("id, full_name, username, avatar_url")
            .in("id", values: ids)
            .execute()
            .value) ?? []

        for row in rows {
            let name = row.fullName ?? (row.username.map { "@\($0)" } ?? "Player")
            senderProfiles[row.id.lowercased()] = (name: name, avatarUrl: row.avatarUrl)
        }
    }

    func sendMessage(crewId: String) async {
        guard let userId = currentUserId, !sendText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = sendText.trimmingCharacters(in: .whitespacesAndNewlines)
        sendText = ""
        isSending = true
        do {
            let msg: CrewMessage = try await client
                .from("crew_messages")
                .insert(CrewMessagePayload(crewId: crewId, senderId: userId, content: text))
                .select("id, crew_id, sender_id, content, created_at")
                .single()
                .execute()
                .value
            messages.append(msg)
            await markRead(crewId: crewId)
        } catch {
            sendText = text // restore on failure
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func subscribeToMessages(crewId: String) async {
        await unsubscribe()
        let channel = client.channel("crew_messages_\(crewId)")
        realtimeChannel = channel

        realtimeTask = Task {
            let changes = await channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "crew_messages",
                filter: "crew_id=eq.\(crewId)"
            )
            await channel.subscribe()
            for await change in changes {
                if let msg = try? change.decodeRecord(as: CrewMessage.self, decoder: JSONDecoder()) {
                    guard !self.messages.contains(where: { $0.id == msg.id }) else { continue }
                    await MainActor.run { self.messages.append(msg) }
                    await self.loadSenderProfiles(for: [msg])
                    await self.markRead(crewId: crewId)
                }
            }
        }
    }

    func unsubscribe() async {
        realtimeTask?.cancel()
        realtimeTask = nil
        if let ch = realtimeChannel {
            await ch.unsubscribe()
            realtimeChannel = nil
        }
    }

    private func markRead(crewId: String) async {
        guard let userId = currentUserId else { return }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try? await client
            .from("crew_members")
            .update(["last_read_at": fmt.string(from: Date())])
            .eq("crew_id", value: crewId)
            .eq("user_id", value: userId)
            .execute()
    }

    // MARK: - Unread count for a crew (for DM inbox badge)
    func unreadCount(for crewId: String, lastReadAt: String?) async -> Int {
        let threshold = lastReadAt ?? "1970-01-01T00:00:00Z"
        let msgs: [CrewMessage] = (try? await client
            .from("crew_messages")
            .select("id, crew_id, sender_id, content, created_at")
            .eq("crew_id", value: crewId)
            .gt("created_at", value: threshold)
            .neq("sender_id", value: currentUserId ?? "")
            .execute()
            .value) ?? []
        return msgs.count
    }

    // MARK: - Latest message for DM inbox preview
    func latestMessage(for crewId: String) async -> CrewMessage? {
        let rows: [CrewMessage] = (try? await client
            .from("crew_messages")
            .select("id, crew_id, sender_id, content, created_at")
            .eq("crew_id", value: crewId)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value) ?? []
        return rows.first
    }
}
