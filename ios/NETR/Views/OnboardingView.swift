import SwiftUI
import PhotosUI
import AuthenticationServices
import CryptoKit
import Supabase
import Auth
import PostgREST

struct OnboardingView: View {
    @Environment(SupabaseManager.self) private var supabase
    @Environment(BiometricAuthManager.self) private var biometrics
    @State private var currentStep: Int = 0
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var selfAssessmentScore: Double? = nil
    @State private var selfAssessmentCategoryScores: [String: Double] = [:]
    @State private var selfAssessmentIsProClaim: Bool = false
    @State private var selfAssessmentPosition: String = ""
    @State private var isProspect: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImageData: Data?

    @State private var showRatingReveal: Bool = false
    @State private var signUpError: String?
    @State private var isSigningUp: Bool = false
    @State private var isGoogleUser: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    private let totalSteps = 8

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if currentStep > 0 && currentStep < 3 {
                    progressBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                ZStack {
                    onboardingStep(for: currentStep)
                        .id(currentStep)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.snappy(duration: 0.3), value: currentStep)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(NETRTheme.muted)
                    .frame(height: 4)
                Capsule()
                    .fill(NETRTheme.neonGreen)
                    .frame(width: geo.size.width * CGFloat(currentStep) / CGFloat(totalSteps - 1), height: 4)
                    .animation(.snappy, value: currentStep)
            }
        }
        .frame(height: 4)
    }


    private var locationStep: some View {
        VStack(spacing: 24) {
            Spacer()

            LucideIcon("map-pin", size: 56)
                .foregroundStyle(NETRTheme.neonGreen)
                .neonGlow(radius: 12)

            Text("FIND COURTS NEAR YOU")
                .font(NETRTheme.headingFont)
                .foregroundStyle(NETRTheme.text)

            Text("We use your location to show nearby courts and active games. Your exact location is never stored.")
                .font(.body)
                .foregroundStyle(NETRTheme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button {
                    withAnimation { currentStep = 2 }
                } label: {
                    Text("ALLOW LOCATION")
                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(NETRTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(PressButtonStyle())

                Button {
                    withAnimation { currentStep = 2 }
                } label: {
                    Text("Skip for Now")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var accountStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("CREATE YOUR PROFILE")
                        .font(NETRTheme.headingFont)
                        .foregroundStyle(NETRTheme.text)
                    Text("This is how other players will find you")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                }
                .padding(.top, 40)

                photoPickerSection

                VStack(spacing: 16) {
                    NETRTextField(placeholder: "Full Name", text: $fullName, icon: "person.fill")
                    NETRTextField(placeholder: "@username", text: $username, icon: "at")
                        .onChange(of: username) { _, newValue in
                            let sanitized = newValue.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
                            if sanitized != newValue { username = sanitized }
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("DATE OF BIRTH")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(NETRTheme.subtext)
                            .tracking(1)

                        DatePicker("", selection: $dateOfBirth, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(NETRTheme.neonGreen)
                            .padding(12)
                            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                            .onChange(of: dateOfBirth) { _, newValue in
                                let age = Calendar.current.dateComponents([.year], from: newValue, to: Date()).year ?? 0
                                isProspect = age <= 15
                            }
                    }

                    if isProspect {
                        HStack(spacing: 12) {
                            LucideIcon("shield")
                                .foregroundStyle(NETRTheme.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PROSPECT ACCOUNT")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(NETRTheme.purple)
                                Text("Players 15 & under are in a protected tier designed to track youth development.")
                                    .font(.caption)
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                        }
                        .padding(12)
                        .background(NETRTheme.purple.opacity(0.1), in: .rect(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.purple.opacity(0.3), lineWidth: 1))
                    }

                    if let error = signUpError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(NETRTheme.red)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(NETRTheme.red.opacity(0.1), in: .rect(cornerRadius: 8))
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)

                Button {
                    withAnimation { currentStep = 3 }  // → photo prompt
                } label: {
                    Text("CONTINUE")
                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(NETRTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canContinueAccount ? NETRTheme.neonGreen : NETRTheme.muted,
                            in: .rect(cornerRadius: 14)
                        )
                }
                .buttonStyle(PressButtonStyle())
                .disabled(!canContinueAccount)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .dismissKeyboardOnScroll()
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    profileImageData = data
                }
            }
        }
    }

    private var canContinueAccount: Bool {
        !fullName.isEmpty && !username.isEmpty
    }

    private var ratingTiers: [(range: String, label: String, description: String, color: Color)] {
        NETRTier.all.map { tier in
            let lo = String(format: "%.1f", tier.range.lowerBound)
            let hi = String(format: "%.1f", tier.range.upperBound)
            return (range: "\(lo)–\(hi)", label: tier.name.uppercased(), description: tier.stat, color: tier.color)
        }
    }

    private var ratingExplainedStep: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("NETR RATING EXPLAINED")
                    .font(NETRTheme.headingFont)
                    .foregroundStyle(NETRTheme.text)
                Text("Here's what the numbers mean")
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
            }
            .padding(.top, 16)

            VStack(spacing: 0) {
                ForEach(Array(ratingTiers.enumerated()), id: \.offset) { index, tier in
                    HStack(spacing: 10) {
                        Text(tier.range)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(tier.color)
                            .frame(width: 54, alignment: .trailing)

                        Circle()
                            .fill(tier.color)
                            .frame(width: 6, height: 6)

                        VStack(alignment: .leading, spacing: 0) {
                            Text(tier.label)
                                .font(.system(size: 11, weight: .heavy, design: .default).width(.compressed))
                                .tracking(0.5)
                                .foregroundStyle(tier.color)
                            if !tier.description.isEmpty {
                                Text(tier.description)
                                    .font(.system(size: 9))
                                    .foregroundStyle(NETRTheme.subtext)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if tier.range.hasPrefix("3.0") {
                            Text("MOST PLAYERS")
                                .font(.system(size: 7, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(tier.color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(tier.color.opacity(0.15), in: Capsule())
                                .overlay(Capsule().stroke(tier.color.opacity(0.35), lineWidth: 1))
                        } else if tier.range.hasPrefix("4.0") {
                            Text("AVG PICKUP")
                                .font(.system(size: 7, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(tier.color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(tier.color.opacity(0.15), in: Capsule())
                                .overlay(Capsule().stroke(tier.color.opacity(0.35), lineWidth: 1))
                        } else if tier.range.hasPrefix("5.0") {
                            Text("SOLID HOOPER")
                                .font(.system(size: 7, weight: .black))
                                .tracking(0.5)
                                .foregroundStyle(tier.color)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(tier.color.opacity(0.15), in: Capsule())
                                .overlay(Capsule().stroke(tier.color.opacity(0.35), lineWidth: 1))
                        }
                    }
                    .padding(.vertical, 4)

                    if index < ratingTiers.count - 1 {
                        HStack(spacing: 10) {
                            Color.clear.frame(width: 54)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(NETRTheme.border)
                                .frame(width: 1, height: 2)
                                .padding(.leading, 2.5)
                            Spacer()
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.top, 12)

            HStack(spacing: 6) {
                LucideIcon("info", size: 11)
                    .foregroundStyle(NETRTheme.neonGreen)
                Text("Your NETR is shaped by peer reviews. Play games, get rated, watch your number move.")
                    .font(.system(size: 11))
                    .foregroundStyle(NETRTheme.subtext)
            }
            .padding(10)
            .background(NETRTheme.neonGreen.opacity(0.06), in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()

            if let error = signUpError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(NETRTheme.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            VStack(spacing: 12) {
                Button {
                    withAnimation { currentStep = 5 }
                } label: {
                    Text("START SELF ASSESSMENT")
                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(NETRTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(PressButtonStyle())

                Button {
                    performSignUp()
                } label: {
                    HStack(spacing: 8) {
                        if isSigningUp {
                            ProgressView()
                                .tint(NETRTheme.subtext)
                        }
                        Text("Skip for Now")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                .disabled(isSigningUp)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private var disclaimerStep: some View {
        SelfAssessmentDisclaimerView(
            onContinue: {
                withAnimation { currentStep = 6 }
            },
            onBack: {
                withAnimation { currentStep = 4 }
            }
        )
    }

    private var ageFromDOB: Int {
        Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year ?? 20
    }

    private var selfAssessmentStep: some View {
        SelfAssessmentFlowView(initialAge: ageFromDOB) { score, profile, catScores in
            selfAssessmentScore = score
            selfAssessmentCategoryScores = catScores
            selfAssessmentIsProClaim = (profile.highestLevel == .nba)
            // Build position string: "PG", "SG", "PG/SG", etc.
            if let p1 = profile.position {
                if let p2 = profile.position2 {
                    selfAssessmentPosition = "\(p1.short)/\(p2.short)"
                } else if p1 != .notSure {
                    selfAssessmentPosition = p1.short
                }
            }
            SelfAssessmentStore.save(score: score, categoryScores: catScores)
            // Save profile + score and go straight into the app
            if isGoogleUser {
                performGoogleProfileSave()
            } else {
                performSignUp()
            }
        }
    }

    private func ratingTierInfo(for rating: Double) -> (name: String, color: Color) {
        (NETRRating.tierName(for: rating).uppercased(), NETRRating.color(for: rating))
    }

    private var revealScore: Double {
        selfAssessmentScore ?? 3.0
    }

    private var ratingRevealStep: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            RadialGradient(
                colors: [
                    ratingTierInfo(for: revealScore).color.opacity(0.15),
                    ratingTierInfo(for: revealScore).color.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    Text("YOUR STARTING NETR")
                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                        .tracking(3)
                        .foregroundStyle(NETRTheme.subtext)
                        .opacity(showRatingReveal ? 1 : 0)
                        .offset(y: showRatingReveal ? 0 : 10)

                    ZStack {
                        Circle()
                            .stroke(
                                ratingTierInfo(for: revealScore).color.opacity(0.15),
                                lineWidth: 6
                            )
                            .frame(width: 180, height: 180)

                        Circle()
                            .trim(from: 0, to: showRatingReveal ? CGFloat(revealScore / 10.0) : 0)
                            .stroke(
                                ratingTierInfo(for: revealScore).color,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 180, height: 180)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: ratingTierInfo(for: revealScore).color.opacity(0.6), radius: 12)
                            .animation(.spring(duration: 1.2, bounce: 0.2).delay(0.2), value: showRatingReveal)

                        VStack(spacing: 4) {
                            Text(String(format: "%.1f", revealScore))
                                .font(.system(size: 64, weight: .black, design: .default).width(.compressed))
                                .foregroundStyle(ratingTierInfo(for: revealScore).color)
                                .shadow(color: ratingTierInfo(for: revealScore).color.opacity(0.5), radius: 16)
                                .contentTransition(.numericText())

                            Text(ratingTierInfo(for: revealScore).name)
                                .font(.system(.caption2, design: .default, weight: .heavy).width(.compressed))
                                .tracking(1)
                                .foregroundStyle(ratingTierInfo(for: revealScore).color.opacity(0.8))
                        }
                    }
                    .scaleEffect(showRatingReveal ? 1 : 0.5)
                    .opacity(showRatingReveal ? 1 : 0)

                    VStack(spacing: 8) {
                        Text("This is your starting point.")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(NETRTheme.text)

                        Text("Play games, get rated by your peers, and watch your NETR evolve. Self-assessments are private — your real score is earned on the court.")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .opacity(showRatingReveal ? 1 : 0)
                    .offset(y: showRatingReveal ? 0 : 20)
                    .animation(.spring(duration: 0.6).delay(0.8), value: showRatingReveal)
                }

                if let error = signUpError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(NETRTheme.red)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                }

                Spacer()

                Button {
                    if isGoogleUser {
                        performGoogleProfileSave()
                    } else {
                        performSignUp()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isSigningUp {
                            ProgressView()
                                .tint(NETRTheme.background)
                        }
                        Text("ENTER NETR")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(2)
                            .foregroundStyle(NETRTheme.background)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                    .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 16)
                }
                .buttonStyle(PressButtonStyle())
                .disabled(isSigningUp)
                .opacity(showRatingReveal ? 1 : 0)
                .animation(.easeOut.delay(1.2), value: showRatingReveal)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { showRatingReveal = true }
            }
        }
    }

    @ViewBuilder
    private func onboardingStep(for step: Int) -> some View {
        switch step {
        case 0:
            WelcomeView(
                onContinue: { withAnimation { currentStep = 1 } },
                onGoogleSignedInAsNewUser: {
                    isGoogleUser = true
                    withAnimation { currentStep = 2 } // skip location, go to name/username
                },
                onGoogleSignedInAsExistingUser: {
                    hasCompletedOnboarding = true
                }
            )
        case 1:
            locationStep
        case 2:
            accountStep
        case 3:
            // Photo prompt — right after username/profile setup
            ProfilePhotoPromptView {
                withAnimation { currentStep = 4 }
            }
        case 4:
            ratingExplainedStep
        case 5:
            disclaimerStep
        case 6:
            selfAssessmentStep
        default:
            ratingRevealStep
        }
    }

    private func performSignUp() {
        isSigningUp = true
        signUpError = nil

        let name = fullName
        let handle = username
        let dob = dateOfBirth
        let pos = selfAssessmentPosition
        let score = selfAssessmentScore

        Task {
            do {
                // If user already has a session (e.g. Google sign-in), just save
                // their profile — no email sign-up needed.
                if let existingSession = supabase.session {
                    let userId = existingSession.user.id.uuidString.lowercased()
                    try await supabase.saveProfile(
                        userId: userId,
                        fullName: name,
                        username: handle,
                        dateOfBirth: dob,
                        position: pos
                    )
                } else {
                    let email = supabase.pendingEmail
                    let password = supabase.pendingPassword

                    guard !email.isEmpty, !password.isEmpty else {
                        signUpError = "Missing email or password. Please go back and enter your credentials."
                        isSigningUp = false
                        return
                    }

                    do {
                        try await supabase.signUpWithEmail(
                            email: email,
                            password: password,
                            fullName: name,
                            username: handle,
                            dateOfBirth: dob,
                            position: pos
                        )
                    } catch {
                        let msg = error.localizedDescription.lowercased()
                        if msg.contains("already registered") || msg.contains("already been registered") || msg.contains("user already") {
                            try await supabase.signInWithEmail(email: email, password: password)
                            guard let userId = supabase.session?.user.id.uuidString.lowercased(), !userId.isEmpty else {
                                throw NSError(domain: "NETR", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get user session after sign in."])
                            }
                            try await supabase.saveProfile(
                                userId: userId,
                                fullName: name,
                                username: handle,
                                dateOfBirth: dob,
                                position: pos
                            )
                        } else {
                            throw error
                        }
                    }

                    // Sign-up may succeed without returning a session (e.g. email
                    // confirmation enabled). Try signing in to establish one, but
                    // don't fail the whole flow — the auth listener may still
                    // deliver the session asynchronously.
                    if supabase.session == nil {
                        do {
                            try await supabase.signInWithEmail(email: email, password: password)
                        } catch {
                            for _ in 0..<6 {
                                try? await Task.sleep(for: .milliseconds(500))
                                if supabase.session != nil { break }
                            }
                        }
                    }
                }

                if let score, supabase.session != nil {
                    try await supabase.saveSelfAssessmentScore(
                        score: score,
                        categoryScores: selfAssessmentCategoryScores.isEmpty ? nil : selfAssessmentCategoryScores
                    )
                    if selfAssessmentIsProClaim {
                        try? await supabase.flagProVerificationPending()
                    }
                }

                biometrics.isUnlocked = true
                hasCompletedOnboarding = true
            } catch {
                signUpError = error.localizedDescription
            }
            isSigningUp = false
        }
    }

    private func performGoogleProfileSave() {
        guard let userId = supabase.session?.user.id.uuidString.lowercased() else {
            signUpError = "Session not found. Please try signing in again."
            return
        }
        isSigningUp = true
        signUpError = nil
        Task {
            do {
                try await supabase.saveProfile(
                    userId: userId,
                    fullName: fullName,
                    username: username,
                    dateOfBirth: dateOfBirth,
                    position: selfAssessmentPosition
                )
                if let score = selfAssessmentScore {
                    try await supabase.saveSelfAssessmentScore(
                        score: score,
                        categoryScores: selfAssessmentCategoryScores.isEmpty ? nil : selfAssessmentCategoryScores
                    )
                    if selfAssessmentIsProClaim {
                        try? await supabase.flagProVerificationPending()
                    }
                }
                biometrics.isUnlocked = true
                hasCompletedOnboarding = true
            } catch {
                signUpError = error.localizedDescription
            }
            isSigningUp = false
        }
    }

    private var photoPickerSection: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    if let data = profileImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 140, height: 140)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(NETRTheme.neonGreen, lineWidth: 3))
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(NETRTheme.neonGreen)
                                    .background(Color.black, in: Circle())
                                    .offset(x: -4, y: -4)
                            }
                    } else {
                        Circle()
                            .fill(NETRTheme.card)
                            .frame(width: 140, height: 140)
                            .overlay(
                                Circle()
                                    .stroke(
                                        NETRTheme.neonGreen.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                                    )
                            )
                            .overlay(
                                LucideIcon("camera", size: 36)
                                    .foregroundStyle(NETRTheme.muted)
                            )
                    }
                }
            }

            Text("Put a face to your game.")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(NETRTheme.text)

            Text("Players who add a photo get more ratings\nand build trust faster.")
                .font(.caption)
                .foregroundStyle(NETRTheme.subtext)
                .multilineTextAlignment(.center)
        }
    }
}

struct PositionCard: View {
    let position: Position
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                LucideIcon(position.icon, size: 22)
                    .foregroundStyle(isSelected ? NETRTheme.neonGreen : NETRTheme.subtext)

                Text(position.rawValue)
                    .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(isSelected ? NETRTheme.neonGreen : NETRTheme.text)

                Text(position.fullName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? NETRTheme.text : NETRTheme.subtext)

                Text(position.shortDesc)
                    .font(.caption2)
                    .foregroundStyle(NETRTheme.subtext)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(isSelected ? NETRTheme.neonGreen.opacity(0.08) : NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? NETRTheme.neonGreen : NETRTheme.border, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PressButtonStyle())
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}
