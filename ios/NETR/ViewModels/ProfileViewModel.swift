import SwiftUI
import Supabase
import Auth

@MainActor @Observable
class ProfileViewModel {

    var player: Player?
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
            vibeScore = profile.vibeScore
            isLoading = false
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

    func toggleFollow() async {
        guard let currentId = SupabaseManager.shared.session?.user.id.uuidString,
              let targetId = profileUserId else { return }

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

            nonisolated struct AvatarUpdate: Encodable, Sendable {
                let avatarUrl: String
                nonisolated enum CodingKeys: String, CodingKey {
                    case avatarUrl = "avatar_url"
                }
            }

            try await client
                .from("profiles")
                .update(AvatarUpdate(avatarUrl: publicURL.absoluteString))
                .eq("id", value: userId)
                .execute()

            avatarImage = image
            isUploadingAvatar = false

            await SupabaseManager.shared.loadProfile(userId: userId)
        } catch {
            isUploadingAvatar = false
            print("Avatar upload error: \(error)")
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
}
