import SwiftUI
import Supabase
import Auth
import PostgREST

@Observable
class SupabaseManager {

    static let shared = SupabaseManager()

    let client: SupabaseClient

    var session: Session?
    var currentProfile: UserProfile?
    var isLoading: Bool = false
    var authError: String?

    var pendingEmail: String = ""
    var pendingPassword: String = ""

    var isSignedIn: Bool { session != nil }

    /// Single source of truth for the current user's avatar URL.
    /// All views displaying the current user's avatar should observe this property.
    var currentUserAvatarUrl: String? {
        get { currentProfile?.avatarUrl }
        set {
            currentProfile?.avatarUrl = newValue
        }
    }

    init() {
        let urlString = Config.SUPABASE_URL.isEmpty ? "https://placeholder.supabase.co" : Config.SUPABASE_URL
        guard let url = URL(string: urlString) else {
            fatalError("[NETR] Invalid Supabase URL: \(urlString)")
        }
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Config.SUPABASE_ANON_KEY.isEmpty ? "placeholder" : Config.SUPABASE_ANON_KEY
        )
        Task { await listenForAuthChanges() }
    }

    func listenForAuthChanges() async {
        for await (event, session) in client.auth.authStateChanges {
            self.session = session
            if [.initialSession, .signedIn].contains(event), let session {
                await loadProfile(userId: session.user.id.uuidString)
            } else if event == .signedOut {
                self.currentProfile = nil
            }
        }
    }

    func signUpWithEmail(
        email: String,
        password: String,
        fullName: String,
        username: String,
        dateOfBirth: Date?,
        position: String
    ) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: [
                "full_name": .string(fullName),
                "username": .string(username)
            ]
        )

        let userId: String
        if let s = response.session {
            self.session = s
            userId = s.user.id.uuidString
        } else {
            userId = response.user.id.uuidString
        }

        try await saveProfile(
            userId: userId,
            fullName: fullName,
            username: username,
            dateOfBirth: dateOfBirth,
            position: position
        )
    }

    func signInWithEmail(email: String, password: String) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        let session = try await client.auth.signIn(email: email, password: password)
        self.session = session
        await loadProfile(userId: session.user.id.uuidString)
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        self.session = session
        await loadProfile(userId: session.user.id.uuidString)
    }

    func signInWithGoogle() async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        let url = try await client.auth.getOAuthSignInURL(
            provider: .google,
            redirectTo: URL(string: "netr://auth/callback")
        )
        await UIApplication.shared.open(url)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
        currentProfile = nil
    }

    func saveProfile(
        userId: String,
        fullName: String,
        username: String,
        dateOfBirth: Date?,
        position: String
    ) async throws {
        var params: [String: AnyJSON] = [
            "id": .string(userId),
            "full_name": .string(fullName),
            "username": .string(username),
            "position": .string(position)
        ]
        if let dob = dateOfBirth {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            params["date_of_birth"] = .string(formatter.string(from: dob))
        }
        try await client
            .from("profiles")
            .upsert(params)
            .execute()
    }

    func loadProfile(userId: String) async {
        do {
            let profile: UserProfile = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            self.currentProfile = profile
        } catch {
            print("Error loading profile: \(error)")
        }
    }

    func saveSelfRating(
        shooting: Double,
        finishing: Double,
        dribbling: Double,
        passing: Double,
        defense: Double,
        rebounding: Double,
        basketballIQ: Double
    ) async throws {
        guard let userId = session?.user.id.uuidString else { return }
        try await client
            .from("profiles")
            .update([
                "cat_shooting": AnyJSON.double(shooting),
                "cat_finishing": AnyJSON.double(finishing),
                "cat_dribbling": AnyJSON.double(dribbling),
                "cat_passing": AnyJSON.double(passing),
                "cat_defense": AnyJSON.double(defense),
                "cat_rebounding": AnyJSON.double(rebounding),
                "cat_basketball_iq": AnyJSON.double(basketballIQ)
            ])
            .eq("id", value: userId)
            .execute()
    }

    func saveSelfAssessmentScore(score: Double, categoryScores: [String: Double]? = nil) async throws {
        guard let userId = session?.user.id.uuidString else {
            print("[NETR] saveSelfAssessmentScore: no session, saving locally only")
            SelfAssessmentStore.save(score: score, categoryScores: categoryScores)
            return
        }

        SelfAssessmentStore.save(score: score, categoryScores: categoryScores)

        var params: [String: AnyJSON] = [
            "netr_score": .double(score)
        ]

        if let cats = categoryScores {
            if let v = cats["scoring"] { params["cat_shooting"] = .double(v) }
            if let v = cats["finishing"] { params["cat_finishing"] = .double(v) }
            if let v = cats["handles"] { params["cat_dribbling"] = .double(v) }
            if let v = cats["playmaking"] { params["cat_passing"] = .double(v) }
            if let v = cats["defense"] { params["cat_defense"] = .double(v) }
            if let v = cats["rebounding"] { params["cat_rebounding"] = .double(v) }
            if let v = cats["iq"] { params["cat_basketball_iq"] = .double(v) }
        }

        do {
            try await client
                .from("profiles")
                .update(params)
                .eq("id", value: userId)
                .execute()
        } catch {
            print("[NETR] saveSelfAssessmentScore remote save failed: \(error)")
        }

        await loadProfile(userId: userId)
    }

    /// Upload avatar to Supabase Storage bucket and update profile + shared state.
    func uploadAvatar(_ image: UIImage) async throws {
        guard let userId = session?.user.id.uuidString,
              let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        let path = "\(userId)/avatar.jpg"

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

        // Update the single source of truth immediately
        currentUserAvatarUrl = cacheBustedUrl
    }

    func flagProVerificationPending() async throws {
        guard let userId = session?.user.id.uuidString else { return }
        do {
            try await client
                .from("profiles")
                .update(["pro_verification_pending": AnyJSON.bool(true)])
                .eq("id", value: userId)
                .execute()
            await loadProfile(userId: userId)
        } catch {
            print("[NETR] flagProVerificationPending failed: \(error)")
        }
    }
}
