import SwiftUI
import Supabase
import Auth

@Observable
class ProfileViewModel {

    var player: Player?
    var userProfile: UserProfile?
    var isLoading: Bool = false
    var isSaving: Bool = false
    var error: String?
    var isCurrentUser: Bool = false

    var avatarImage: UIImage?
    var isUploadingAvatar: Bool = false

    var isFollowing: Bool = false
    var followerCount: Int = 0
    var followingCount: Int = 0
    var vibeScore: Double?

    private let client = SupabaseManager.shared.client
    private var profileUserId: String?

    var bio: String?
    var userPosts: [SupabaseFeedPost] = []
    var homeCourt: Court?
    var milestones: [PlayerMilestone] = []

    func loadProfile(userId: String? = nil) async {
        isLoading = true
        error = nil

        let targetId = userId ?? SupabaseManager.shared.session?.user.id.uuidString

        guard let targetId else {
            isLoading = false
            return
        }

        profileUserId = targetId
        isCurrentUser = (targetId == SupabaseManager.shared.session?.user.id.uuidString)

        do {
            let profile: UserProfile = try await client
                .from("profiles")
                .select()
                .eq("id", value: targetId)
                .single()
                .execute()
                .value

            var bridgedPlayer = profile.toPlayer()

            if isCurrentUser {
                bridgedPlayer = mergeLocalAssessment(into: bridgedPlayer)
            }

            player = bridgedPlayer
            userProfile = profile
            vibeScore = profile.vibeScore
            bio = profile.bio
            isLoading = false

            await loadSocialCounts(targetId: targetId)
            await loadHomeCourt(userId: targetId)
            await loadMilestones(userId: targetId)
        } catch {
            if isCurrentUser {
                let fallback = buildLocalOnlyPlayer()
                if fallback.rating != nil {
                    player = fallback
                    isLoading = false
                    return
                }
            }
            self.error = "Failed to load profile"
            isLoading = false
            print("Profile load error: \(error)")
        }
    }

    func loadMilestones(userId: String) async {
        milestones = (try? await client
            .from("player_milestones")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value) ?? []
    }

    func loadHomeCourt(userId: String) async {
        nonisolated struct FavCourtId: Decodable, Sendable {
            let courtId: String
            nonisolated enum CodingKeys: String, CodingKey { case courtId = "court_id" }
        }
        guard let fav = (try? await client
            .from("court_favorites")
            .select("court_id")
            .eq("user_id", value: userId)
            .eq("is_home_court", value: true)
            .execute()
            .value as [FavCourtId])?.first else {
            homeCourt = nil
            return
        }
        homeCourt = try? await client
            .from("courts")
            .select("id, name, address, neighborhood, city, lat, lng, surface, lights, indoor, full_court, verified, tags, court_rating, submitted_by")
            .eq("id", value: fav.courtId)
            .single()
            .execute()
            .value
    }

    func setHomeCourt(courtId: String) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        nonisolated struct HomeUpdate: Encodable, Sendable {
            let isHomeCourt: Bool
            nonisolated enum CodingKeys: String, CodingKey { case isHomeCourt = "is_home_court" }
        }
        nonisolated struct FavPayload: Encodable, Sendable {
            let userId: String; let courtId: String; let isHomeCourt: Bool
            nonisolated enum CodingKeys: String, CodingKey {
                case userId = "user_id"; case courtId = "court_id"; case isHomeCourt = "is_home_court"
            }
        }

        do {
            // Clear existing home court flag
            try await client.from("court_favorites").update(HomeUpdate(isHomeCourt: false)).eq("user_id", value: userId).execute()
            // Try insert; if a row already exists for this court, fall back to update
            do {
                try await client.from("court_favorites").insert(FavPayload(userId: userId, courtId: courtId, isHomeCourt: true)).execute()
            } catch {
                try await client.from("court_favorites").update(HomeUpdate(isHomeCourt: true)).eq("user_id", value: userId).eq("court_id", value: courtId).execute()
            }
        } catch {
            print("Set home court error: \(error)")
        }
        await loadHomeCourt(userId: userId)
    }

    private func loadSocialCounts(targetId: String) async {
        nonisolated struct IdRow: Decodable, Sendable { let followerId: String
            nonisolated enum CodingKeys: String, CodingKey { case followerId = "follower_id" }
        }
        nonisolated struct IdRow2: Decodable, Sendable { let followingId: String
            nonisolated enum CodingKeys: String, CodingKey { case followingId = "following_id" }
        }

        // Follower count
        if let rows: [IdRow] = try? await client
            .from("follows")
            .select("follower_id")
            .eq("following_id", value: targetId)
            .execute()
            .value {
            followerCount = rows.count
        }

        // Following count
        if let rows: [IdRow2] = try? await client
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: targetId)
            .execute()
            .value {
            followingCount = rows.count
        }

        // Check if current user follows this profile
        if !isCurrentUser,
           let currentId = SupabaseManager.shared.session?.user.id.uuidString {
            let rows: [FollowingIdRow]? = try? await client
                .from("follows")
                .select("following_id")
                .eq("follower_id", value: currentId)
                .eq("following_id", value: targetId)
                .execute()
                .value
            isFollowing = !(rows?.isEmpty ?? true)
        }
    }

    func loadUserPosts() async {
        guard let targetId = profileUserId else { return }

        let selectQuery = """
            id, author_id, content, like_count, comment_count,
            court_tag_id, court_tag_name, created_at,
            profiles(id, full_name, username, avatar_url, netr_score)
        """

        let fetched: [SupabaseFeedPost]? = try? await client
            .from("feed_posts")
            .select(selectQuery)
            .eq("author_id", value: targetId)
            .order("created_at", ascending: false)
            .limit(20)
            .execute()
            .value

        userPosts = fetched ?? []
    }

    func toggleFollow() async {
        guard let currentId = SupabaseManager.shared.session?.user.id.uuidString,
              let targetId = profileUserId,
              currentId != targetId else { return }

        nonisolated struct FollowPayload: Encodable, Sendable {
            let followerId: String
            let followingId: String
            nonisolated enum CodingKeys: String, CodingKey {
                case followerId = "follower_id"
                case followingId = "following_id"
            }
        }

        do {
            if isFollowing {
                try await client
                    .from("follows")
                    .delete()
                    .eq("follower_id", value: currentId)
                    .eq("following_id", value: targetId)
                    .execute()
                isFollowing = false
                followerCount = max(0, followerCount - 1)
            } else {
                let payload = FollowPayload(
                    followerId: currentId,
                    followingId: targetId
                )
                try await client
                    .from("follows")
                    .insert(payload)
                    .execute()
                isFollowing = true
                followerCount += 1
            }
        } catch {
            print("Follow toggle error: \(error)")
        }
    }

    func uploadAvatar(_ image: UIImage) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        isUploadingAvatar = true

        let path = "\(userId)/avatar.jpg"

        do {
            try await client.storage
                .from("avatars")
                .upload(
                    path,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )

            let publicURL = try client.storage
                .from("avatars")
                .getPublicURL(path: path)

            // Append timestamp to bust AsyncImage cache
            let cacheBustedUrl = publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"

            nonisolated struct AvatarUpdate: Encodable, Sendable {
                let avatarUrl: String
                nonisolated enum CodingKeys: String, CodingKey {
                    case avatarUrl = "avatar_url"
                }
            }

            try await client
                .from("profiles")
                .update(AvatarUpdate(avatarUrl: cacheBustedUrl))
                .eq("id", value: userId)
                .execute()

            avatarImage = image
            isUploadingAvatar = false

            await SupabaseManager.shared.loadProfile(userId: userId)
            await loadProfile()
        } catch {
            isUploadingAvatar = false
            print("[NETR] Avatar upload error: \(error)")
        }
    }

    private func mergeLocalAssessment(into player: Player) -> Player {
        var merged = player

        if merged.rating == nil, let localScore = SelfAssessmentStore.savedScore {
            merged.rating = localScore
        }

        if let localSkills = SelfAssessmentStore.savedSkillRatings {
            let current = merged.skills
            let hasRemoteSkills = [current.shooting, current.finishing, current.ballHandling, current.playmaking, current.defense, current.rebounding, current.basketballIQ].compactMap({ $0 }).count > 0
            if !hasRemoteSkills {
                merged.skills = localSkills
            }
        }

        return merged
    }

    private func buildLocalOnlyPlayer() -> Player {
        let name = SupabaseManager.shared.currentProfile?.fullName ?? "Player"
        let uname = SupabaseManager.shared.currentProfile?.username ?? "player"
        let localScore = SelfAssessmentStore.savedScore
        let localSkills = SelfAssessmentStore.savedSkillRatings ?? SkillRatings()

        let posStr = SupabaseManager.shared.currentProfile?.position?.uppercased() ?? "?"
        let posEnum = Position(rawValue: posStr) ?? .unknown

        let initials: String = {
            let parts = name.split(separator: " ")
            if parts.count >= 2 {
                return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
            }
            return String(name.prefix(2)).uppercased()
        }()

        return Player(
            id: 0,
            name: name,
            username: "@\(uname)",
            avatar: initials,
            rating: localScore,
            reviews: 0,
            age: 0,
            tier: .basic,
            city: "New York, NY",
            position: posEnum,
            trend: .none,
            games: 0,
            isProspect: false,
            skills: localSkills,
            avatarUrl: SupabaseManager.shared.currentProfile?.avatarUrl
        )
    }

    func updateProfile(fullName: String, username: String, bio: String?) async throws {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        nonisolated struct ProfileUpdate: Encodable, Sendable {
            let fullName: String
            let username: String
            let bio: String?
            nonisolated enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case username
                case bio
            }
        }

        try await client
            .from("profiles")
            .update(ProfileUpdate(fullName: fullName, username: username, bio: bio))
            .eq("id", value: userId)
            .execute()

        await loadProfile()
    }

    func updateFullProfile(fullName: String, username: String, bio: String?, city: String?, position: String?) async throws {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }

        nonisolated struct FullProfileUpdate: Encodable, Sendable {
            let fullName: String
            let username: String
            let bio: String?
            let city: String?
            let position: String?
            nonisolated enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
                case username
                case bio
                case city
                case position
            }
        }

        isSaving = true
        defer { isSaving = false }

        try await client
            .from("profiles")
            .update(FullProfileUpdate(fullName: fullName, username: username, bio: bio, city: city, position: position))
            .eq("id", value: userId)
            .execute()

        await SupabaseManager.shared.loadProfile(userId: userId)
        await loadProfile()
    }

    func uploadBanner(_ image: UIImage) async -> String? {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return nil }

        let path = "\(userId)/banner.jpg"

        do {
            try await client.storage
                .from("profile-backgrounds")
                .upload(
                    path,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: true
                    )
                )

            let publicURL = try client.storage
                .from("profile-backgrounds")
                .getPublicURL(path: path)

            // Append timestamp to bust AsyncImage cache
            let cacheBustedUrl = publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"

            nonisolated struct BannerUpdate: Encodable, Sendable {
                let backgroundImageUrl: String
                nonisolated enum CodingKeys: String, CodingKey {
                    case backgroundImageUrl = "background_image_url"
                }
            }

            try await client
                .from("profiles")
                .update(BannerUpdate(backgroundImageUrl: cacheBustedUrl))
                .eq("id", value: userId)
                .execute()

            await SupabaseManager.shared.loadProfile(userId: userId)
            await loadProfile()

            return cacheBustedUrl
        } catch {
            print("Banner upload error: \(error)")
            return nil
        }
    }
}
