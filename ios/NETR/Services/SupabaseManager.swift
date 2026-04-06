import SwiftUI
import Supabase
import Auth
import PostgREST
import GoogleSignIn

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
    /// Stored independently so it survives profile reloads and is immediately observable.
    var currentUserAvatarUrl: String?

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
                await loadProfile(userId: session.user.id.uuidString.lowercased())
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
            userId = s.user.id.uuidString.lowercased()
        } else {
            userId = response.user.id.uuidString.lowercased()
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
        await loadProfile(userId: session.user.id.uuidString.lowercased())
    }

    func signInWithApple(idToken: String, nonce: String, fullName: String? = nil) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }
        print("[NETR Auth] Apple Sign-In started")
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        self.session = session
        print("[NETR Auth] Apple session established: \(session.user.id)")
        await loadProfile(userId: session.user.id.uuidString.lowercased())

        // Apple only sends the user's name on the very first sign-in.
        // Save it to the profiles table if we got it and the profile doesn't have one yet.
        if let name = fullName, !name.isEmpty, currentProfile?.fullName == nil {
            print("[NETR Auth] Saving Apple-provided name: \(name)")
            do {
                try await client
                    .from("profiles")
                    .update(["full_name": AnyJSON.string(name)])
                    .eq("id", value: session.user.id.uuidString.lowercased())
                    .execute()
                await loadProfile(userId: session.user.id.uuidString.lowercased())
            } catch {
                print("[NETR Auth] Failed to save Apple name: \(error)")
            }
        }
    }

    func signInWithGoogle() async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        // Resolve the root view controller needed to present Google's account picker.
        guard let windowScene = await UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first,
              let rootVC = await windowScene.keyWindow?.rootViewController else {
            throw NSError(domain: "NETRAuth", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to find root view controller"])
        }

        // Native Google Sign-In — presents the system account picker, no browser required.
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)

        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "NETRAuth", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Google did not return an ID token"])
        }

        // Exchange the Google ID token for a Supabase session.
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
        )
        self.session = session
        await loadProfile(userId: session.user.id.uuidString)
    }

    func signOut() async throws {
        try await client.auth.signOut()
        session = nil
        currentProfile = nil
        currentUserAvatarUrl = nil
        // Reset onboarding so a fresh sign-in starts from scratch
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.set(false, forKey: "hasCompletedPhotoPrompt")
        UserDefaults.standard.set(0, forKey: "photoPromptSkipCount")
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
        ]
        if !position.isEmpty && position != "?" {
            params["position"] = .string(position)
        }
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
        // Try both the given format and lowercase — Supabase returns UUIDs lowercase
        // but Swift's uuidString is uppercase. Handle both TEXT and UUID column types.
        let lower = userId.lowercased()
        let candidates = userId == lower ? [userId] : [userId, lower]
        for candidate in candidates {
            if let profile = try? await client
                .from("profiles")
                .select()
                .eq("id", value: candidate)
                .single()
                .execute()
                .value as UserProfile {
                self.currentProfile = profile
                if let avatarUrl = profile.avatarUrl {
                    self.currentUserAvatarUrl = avatarUrl
                }
                print("[NETR] Profile loaded (id: \(profile.id)), avatar_url: \(profile.avatarUrl ?? "nil")")

                // Recalculate archetype if category scores exist (fixes stale single→dual mismatches)
                var catScores: [String: Double] = [:]
                if let v = profile.catShooting    { catScores["shooting"] = v }
                if let v = profile.catFinishing   { catScores["finishing"] = v }
                if let v = profile.catDribbling   { catScores["handles"] = v }
                if let v = profile.catPassing     { catScores["playmaking"] = v }
                if let v = profile.catDefense     { catScores["defense"] = v }
                if let v = profile.catRebounding  { catScores["rebounding"] = v }
                if let v = profile.catBasketballIq { catScores["iq"] = v }
                print("[NETR] Profile catScores for archetype: \(catScores) (archetypeKey=\(profile.archetypeKey ?? "nil"))")
                if !catScores.isEmpty {
                    await computeAndSaveArchetype(userId: profile.id, categoryScores: catScores)
                }

                return
            }
        }
        // No profile found — create one. Use lowercase so RLS auth.uid()::text check passes.
        print("[NETR] No profile found for user \(userId), creating one...")
        await ensureProfileExists(userId: userId.lowercased())
    }

    private func ensureProfileExists(userId: String) async {
        guard let user = session?.user else { return }
        let fullName: String
        if case .string(let v) = user.userMetadata["full_name"] { fullName = v } else { fullName = "" }
        let username: String
        if case .string(let v) = user.userMetadata["username"] { username = v }
        else { username = user.email?.components(separatedBy: "@").first ?? "player\(userId.prefix(4))" }

        let params: [String: AnyJSON] = [
            "id": .string(userId),
            "full_name": .string(fullName),
            "username": .string(username)
        ]
        do {
            try await client.from("profiles").upsert(params).execute()
            print("[NETR] Auto-created profile for user \(userId)")
            if let profile: UserProfile = try? await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value {
                self.currentProfile = profile
                print("[NETR] currentProfile set after auto-create: \(profile.id)")
            } else {
                print("[NETR] Auto-create upsert succeeded but reload failed for \(userId)")
            }
        } catch {
            print("[NETR] Failed to auto-create profile: \(error)")
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
        guard let userId = session?.user.id.uuidString.lowercased() else { return }
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
        guard let userId = session?.user.id.uuidString.lowercased() else {
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

        print("[NETR] saveSelfAssessmentScore: userId=\(userId), params=\(params)")
        do {
            try await client
                .from("profiles")
                .update(params)
                .eq("id", value: userId)
                .execute()
            print("[NETR] saveSelfAssessmentScore: remote save succeeded")
        } catch {
            print("[NETR] saveSelfAssessmentScore remote save failed: \(error)")
        }

        // Compute and save archetype from category scores
        if let cats = categoryScores {
            await computeAndSaveArchetype(userId: userId, categoryScores: cats)
        }

        await loadProfile(userId: userId)
    }

    /// Compute archetype from category scores and persist to profiles table.
    /// Reassigns whenever the computed key differs from the stored key.
    func computeAndSaveArchetype(userId: String, categoryScores: [String: Double]) async {
        let currentKey = currentProfile?.archetypeKey
        print("[NETR] computeArchetype input: \(categoryScores)")

        // Compute what the archetype WOULD be
        let computed = ArchetypeEngine.computeArchetype(categoryScores: categoryScores)
        guard let computed else { print("[NETR] computeArchetype returned nil"); return }
        print("[NETR] computeArchetype result: name=\(computed.name) key=\(computed.key) isSingle=\(computed.isSingle) currentKey=\(currentKey ?? "nil")")

        // If archetype already exists and the key hasn't changed, don't reassign
        if let existing = currentKey, !existing.isEmpty, existing == computed.key {
            print("[NETR] archetype key unchanged (\(existing)), skipping")
            return
        }

        // Assign (random pick from 3 options) and persist
        guard let assigned = ArchetypeEngine.assignArchetype(categoryScores: categoryScores) else { return }

        do {
            try await client
                .from("profiles")
                .update([
                    "archetype_name": AnyJSON.string(assigned.name),
                    "archetype_key": AnyJSON.string(assigned.key),
                ])
                .eq("id", value: userId)
                .execute()
            // Update in-memory profile immediately so the UI reflects the change
            currentProfile?.archetypeName = assigned.name
            currentProfile?.archetypeKey = assigned.key
            print("[NETR] Archetype assigned: \(assigned.name) (\(assigned.key))")
        } catch {
            print("[NETR] Failed to save archetype: \(error)")
        }
    }

    /// Upload avatar to Supabase Storage bucket and update profile + shared state.
    func uploadAvatar(_ image: UIImage) async throws {
        guard let userId = session?.user.id.uuidString.lowercased() else {
            print("[NETR Avatar] ERROR: No session/userId available")
            return
        }
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("[NETR Avatar] ERROR: Failed to convert image to JPEG data")
            return
        }

        let path = "\(userId)/avatar.jpg"
        print("[NETR Avatar] Starting upload for user: \(userId), path: \(path), size: \(imageData.count) bytes")

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
            print("[NETR Avatar] Upload to storage succeeded")
        } catch {
            print("[NETR Avatar] ERROR: Storage upload failed: \(error)")
            throw error
        }

        let publicURL: URL
        do {
            publicURL = try client.storage
                .from("avatars")
                .getPublicURL(path: path)
            print("[NETR Avatar] Public URL: \(publicURL.absoluteString)")
        } catch {
            print("[NETR Avatar] ERROR: getPublicURL failed: \(error)")
            throw error
        }

        let cacheBustedUrl = publicURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
        print("[NETR Avatar] Cache-busted URL: \(cacheBustedUrl)")

        do {
            try await client
                .from("profiles")
                .update(["avatar_url": AnyJSON.string(cacheBustedUrl)])
                .eq("id", value: userId)
                .execute()
            print("[NETR Avatar] Saved URL to profiles table successfully")
        } catch {
            print("[NETR Avatar] ERROR: Failed to save URL to profiles table: \(error)")
            throw error
        }

        // Update the single source of truth immediately — no need to reload profile
        currentUserAvatarUrl = cacheBustedUrl
        currentProfile?.avatarUrl = cacheBustedUrl
        print("[NETR Avatar] Updated currentUserAvatarUrl in SupabaseManager")
    }

    func flagProVerificationPending() async throws {
        guard let userId = session?.user.id.uuidString.lowercased() else { return }
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

