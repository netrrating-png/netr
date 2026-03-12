import SwiftUI
import PhotosUI
import AuthenticationServices
import CryptoKit
import Auth

struct OnboardingView: View {
    @Environment(SupabaseManager.self) private var supabase
    @Environment(BiometricAuthManager.self) private var biometrics
    @State private var currentStep: Int = 0
    @State private var fullName: String = ""
    @State private var username: String = ""
    @State private var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    @State private var selectedPosition: Position?
    @State private var selfAssessmentScore: Double? = nil
    @State private var selfAssessmentCategoryScores: [String: Double] = [:]
    @State private var isProspect: Bool = false
    @State private var showDatePicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var profileImageData: Data?

    @State private var showRatingReveal: Bool = false
    @State private var signUpError: String?
    @State private var isSigningUp: Bool = false

    private let totalSteps = 8

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                if currentStep > 0 && currentStep < 4 {
                    progressBar
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                TabView(selection: $currentStep) {
                    WelcomeView {
                        withAnimation { currentStep = 1 }
                    }.tag(0)
                    locationStep.tag(1)
                    accountStep.tag(2)
                    positionStep.tag(3)
                    ratingExplainedStep.tag(4)
                    disclaimerStep.tag(5)
                    selfAssessmentStep.tag(6)
                    ratingRevealStep.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
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
                    withAnimation { currentStep = 3 }
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
        .scrollDismissesKeyboard(.interactively)
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

    private var positionStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("WHAT'S YOUR POSITION?")
                        .font(NETRTheme.headingFont)
                        .foregroundStyle(NETRTheme.text)
                    Text("Pick the spot where you feel most comfortable")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                }
                .padding(.top, 24)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Position.allCases) { pos in
                        PositionCard(position: pos, isSelected: selectedPosition == pos) {
                            withAnimation(.snappy) { selectedPosition = pos }
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)

                Button {
                    withAnimation { currentStep = 4 }
                } label: {
                    Text("CONTINUE")
                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(NETRTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(PressButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private let ratingTiers: [(range: String, label: String, description: String, color: Color)] = [
        ("10.0", "THEORETICAL MAX", "Unreachable. Doesn't exist in the app.", NETRTheme.neonGreen),
        ("9.5–9.9", "NBA LEVEL", "LeBron, Steph, KD. Even they have room.", NETRTheme.neonGreen),
        ("9.0–9.4", "ELITE D1", "Top program starter. The gap between here and NBA is real.", NETRTheme.neonGreen),
        ("8.0–8.9", "D2 / PRO OVERSEAS", "Best player on a D2 team.", Color(red: 0.478, green: 0.91, blue: 0.0)),
        ("7.0–7.9", "D3 LEVEL", "Dominates every pickup run they walk into.", Color(red: 0.478, green: 0.91, blue: 0.0)),
        ("6.0–6.9", "PARK LEGEND", "Elite across the board. Peer-earned only, no self-rating here.", Color(red: 1.0, green: 0.839, blue: 0.039)),
        ("5.0–5.9", "PARK DOMINANT", "Best player at most courts. Where serious ballers land.", Color(red: 1.0, green: 0.839, blue: 0.039)),
        ("4.0–4.9", "ABOVE AVERAGE", "Solid, has real skills, organized ball background.", Color(red: 1.0, green: 0.839, blue: 0.039)),
        ("3.0–3.9", "HS / AAU LEVEL", "Fundamentals are there, comfortable in competitive pickup.", NETRTheme.blue),
        ("2.0–2.9", "PLAYING FOR FUN", "Shows up, contributes, it's recreational.", NETRTheme.blue),
        ("1.0–1.9", "JUST STARTING OUT", "", NETRTheme.subtext),
    ]

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

            Button {
                withAnimation { currentStep = 5 }
            } label: {
                Text("GOT IT — NEXT")
                    .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(NETRTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressButtonStyle())
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

    private var selfAssessmentStep: some View {
        SelfAssessmentView(
            estimatedScore: $selfAssessmentScore,
            categoryScores: $selfAssessmentCategoryScores,
            onComplete: {
                if let score = selfAssessmentScore {
                    SelfAssessmentStore.save(
                        score: score,
                        categoryScores: selfAssessmentCategoryScores.isEmpty ? nil : selfAssessmentCategoryScores
                    )
                }
                withAnimation { currentStep = 7 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(duration: 0.8, bounce: 0.3)) {
                        showRatingReveal = true
                    }
                }
            },
            onBack: {
                withAnimation { currentStep = 5 }
            }
        )
    }

    private func ratingTierInfo(for rating: Double) -> (name: String, color: Color) {
        switch rating {
        case 9.5...: return ("NBA LEVEL", NETRTheme.gold)
        case 9.0..<9.5: return ("ELITE D1", NETRTheme.gold)
        case 8.0..<9.0: return ("D2 / PRO OVERSEAS", NETRTheme.neonGreen)
        case 7.0..<8.0: return ("D3 LEVEL", NETRTheme.neonGreen)
        case 6.0..<7.0: return ("PARK LEGEND", Color(red: 0.478, green: 0.91, blue: 0.0))
        case 5.0..<6.0: return ("PARK DOMINANT", Color(red: 0.478, green: 0.91, blue: 0.0))
        case 4.0..<5.0: return ("ABOVE AVERAGE", NETRTheme.blue)
        case 3.0..<4.0: return ("HS / AAU LEVEL", NETRTheme.blue)
        case 2.0..<3.0: return ("PLAYING FOR FUN", NETRTheme.subtext)
        default: return ("JUST STARTING OUT", NETRTheme.subtext)
        }
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
                    performSignUp()
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
    }

    private func performSignUp() {
        isSigningUp = true
        signUpError = nil

        let email = supabase.pendingEmail
        let password = supabase.pendingPassword
        let name = fullName
        let handle = username
        let dob = dateOfBirth
        let pos = selectedPosition?.rawValue ?? "?"
        let score = selfAssessmentScore

        Task {
            do {
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
                        try await supabase.saveProfile(
                            userId: supabase.session?.user.id.uuidString ?? "",
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
                // confirmation enabled). Explicitly sign in to establish one.
                if supabase.session == nil {
                    try await supabase.signInWithEmail(email: email, password: password)
                }

                if let score {
                    try await supabase.saveSelfAssessmentScore(
                        score: score,
                        categoryScores: selfAssessmentCategoryScores.isEmpty ? nil : selfAssessmentCategoryScores
                    )
                }

                biometrics.isUnlocked = true
            } catch {
                signUpError = error.localizedDescription
            }
            isSigningUp = false
        }
    }

    private var photoPickerSection: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    if let data = profileImageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(NETRTheme.neonGreen, lineWidth: 3))
                    } else {
                        Circle()
                            .fill(NETRTheme.card)
                            .frame(width: 100, height: 100)
                            .overlay(
                                LucideIcon("user", size: 40)
                                    .foregroundStyle(NETRTheme.muted)
                            )
                            .overlay(Circle().stroke(NETRTheme.border, lineWidth: 2))
                    }

                    LucideIcon("camera", size: 12)
                        .foregroundStyle(NETRTheme.background)
                        .frame(width: 30, height: 30)
                        .background(NETRTheme.neonGreen, in: Circle())
                        .overlay(Circle().stroke(NETRTheme.background, lineWidth: 2))
                }
            }

            Text("Add a photo")
                .font(.caption.weight(.semibold))
                .foregroundStyle(NETRTheme.subtext)
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
