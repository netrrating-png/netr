// ─────────────────────────────────────────────────────────────────────────────
// PlayerCardView.swift  —  NETR App
//
// The shareable / tappable player card shown on profiles and in game lobbies.
// Rating is the hero — everything else supports it.
//
// States:
//   • Self-assessed (< 5 peer ratings) — rating shown with lock ring + progress
//   • Peer-rated   (≥ 5 peer ratings)  — lock drops, full glow, peer average shown
//
// ─────────────────────────────────────────────────────────────────────────────

import SwiftUI

// MARK: ─── Color Extension ────────────────────────────────────────────────────

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: ─── Tokens ─────────────────────────────────────────────────────────────

enum C {
    static let bg      = Color(hex: "#080808")
    static let surface = Color(hex: "#111111")
    static let card    = Color(hex: "#161616")
    static let border  = Color(hex: "#242424")
    static let text    = Color(hex: "#F2F2F2")
    static let sub     = Color(hex: "#777777")
    static let muted   = Color(hex: "#3A3A3A")
    static let accent  = Color(hex: "#00FF41")
    static let gold    = Color(hex: "#F5C542")
    static let pending = Color(hex: "#666666")
}

// MARK: ─── Player Model ───────────────────────────────────────────────────────

struct PlayerProfile {
    let id: String
    let name: String
    let username: String
    let initials: String
    let position: String          // "PG", "SG", "SF", "PF", "C", "Wing", etc.
    let city: String
    let isPro: Bool

    // Rating
    let selfAssessedRating: Double   // from onboarding quiz
    let peerRating: Double?          // nil until peerRatingCount >= 5
    let peerRatingCount: Int         // how many unique raters
    let peerRatingThreshold: Int     // 5 — when peer rating unlocks

    // Skill breakdown (1–10 scale, peer-averaged)
    let skillShooting:    Double?
    let skillHandles:     Double?
    let skillPlaymaking:  Double?
    let skillDefense:     Double?
    let skillHustle:      Double?
    let skillSportsmanship: Double?

    // Rep
    let gamesPlayed: Int
    let homeCourts: [HomeCourt]

    // Vibe
    let vibeAura: VibeAuraColor?     // nil = pending

    // Computed
    var displayRating: Double {
        guard let peer = peerRating, peerRatingCount >= peerRatingThreshold else {
            return selfAssessedRating
        }
        return peer
    }
    var isPeerRated: Bool { peerRatingCount >= peerRatingThreshold }
    var peerProgress: Double { min(1.0, Double(peerRatingCount) / Double(peerRatingThreshold)) }

    var ratingColor: Color { netrColor(displayRating) }
    var tierLabel: String  { netrTier(displayRating)  }
}

func netrColor(_ r: Double) -> Color {
    switch r {
    case 8...:  return Color(hex: "#30D158")
    case 6..<8: return Color(hex: "#00FF41")
    case 4..<6: return Color(hex: "#F5C542")
    default:    return Color(hex: "#FF453A")
    }
}

func netrTier(_ r: Double) -> String {
    switch r {
    case 9...:   return "NBA Level"
    case 8..<9:  return "Elite"
    case 7..<8:  return "D3 Level"
    case 6..<7:  return "Park Legend"
    case 5..<6:  return "Park Dominant"
    case 4..<5:  return "Above Average"
    case 3..<4:  return "Recreational"
    default:     return "Beginner"
    }
}

struct HomeCourt: Identifiable {
    let id: String
    let name: String
    let neighborhood: String
}

enum VibeAuraColor {
    case lockedIn, solid, mixed, avoid

    var color: Color {
        switch self {
        case .lockedIn: return Color(hex: "#39FF14")
        case .solid:    return Color(hex: "#F5C542")
        case .mixed:    return Color(hex: "#FF9A3C")
        case .avoid:    return Color(hex: "#FF453A")
        }
    }
    var label: String {
        switch self {
        case .lockedIn: return "Locked In"
        case .solid:    return "Solid"
        case .mixed:    return "Mixed"
        case .avoid:    return "Avoid"
        }
    }
}

// MARK: ─── Skill row data ─────────────────────────────────────────────────────

private struct SkillRow: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: Double?
}

// MARK: ─── Mock Data ──────────────────────────────────────────────────────────

extension PlayerProfile {
    /// User with only self-assessment (2 of 5 peer ratings in)
    static let mockSelfAssessed = PlayerProfile(
        id: "you",
        name: "YOU",
        username: "you",
        initials: "YO",
        position: "PG",
        city: "New York",
        isPro: false,
        selfAssessedRating: 6.4,
        peerRating: nil,
        peerRatingCount: 2,
        peerRatingThreshold: 5,
        skillShooting: nil, skillHandles: nil, skillPlaymaking: nil,
        skillDefense: nil, skillHustle: nil, skillSportsmanship: nil,
        gamesPlayed: 5,
        homeCourts: [
            HomeCourt(id:"1", name:"Rucker Park",      neighborhood:"Harlem"),
            HomeCourt(id:"2", name:"West 4th Street",  neighborhood:"West Village"),
            HomeCourt(id:"3", name:"Tompkins Square",  neighborhood:"East Village"),
        ],
        vibeAura: nil
    )

    /// User with peer rating unlocked
    static let mockPeerRated = PlayerProfile(
        id: "kj",
        name: "K. Johnson",
        username: "kj_hoops",
        initials: "KJ",
        position: "SG",
        city: "New York",
        isPro: true,
        selfAssessedRating: 7.1,
        peerRating: 8.0,
        peerRatingCount: 58,
        peerRatingThreshold: 5,
        skillShooting: 7.8, skillHandles: 6.9, skillPlaymaking: 7.5,
        skillDefense: 8.3, skillHustle: 8.6, skillSportsmanship: 9.1,
        gamesPlayed: 34,
        homeCourts: [
            HomeCourt(id:"1", name:"Rucker Park",     neighborhood:"Harlem"),
            HomeCourt(id:"2", name:"West 4th Street", neighborhood:"West Village"),
            HomeCourt(id:"3", name:"Dyckman Park",    neighborhood:"Inwood"),
        ],
        vibeAura: .lockedIn
    )
}

// MARK: ─── Player Card ────────────────────────────────────────────────────────

struct PlayerCardView: View {
    let player: PlayerProfile
    var onDismiss: (() -> Void)? = nil

    @State private var ratingScale: CGFloat = 0.75
    @State private var ratingOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var barsVisible = false

    private var skills: [SkillRow] {[
        SkillRow(icon:"🎯", label:"Shooting",      value: player.skillShooting),
        SkillRow(icon:"⚡", label:"Ball Handling",  value: player.skillHandles),
        SkillRow(icon:"🔑", label:"Playmaking",     value: player.skillPlaymaking),
        SkillRow(icon:"🛡️", label:"Defense",        value: player.skillDefense),
        SkillRow(icon:"💪", label:"Hustle",          value: player.skillHustle),
        SkillRow(icon:"🤝", label:"Sportsmanship",  value: player.skillSportsmanship),
    ]}

    var body: some View {
        ZStack(alignment: .top) {
            // Card background
            RoundedRectangle(cornerRadius: 28)
                .fill(C.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    player.ratingColor.opacity(0.6),
                                    player.ratingColor.opacity(0.1),
                                    C.border,
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )

            VStack(spacing: 0) {
                // ── Top bar ──
                TopBar(player: player, onDismiss: onDismiss)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 24)

                // ── RATING HERO ──
                RatingHero(player: player, scale: ratingScale, opacity: ratingOpacity, glowOpacity: glowOpacity)
                    .padding(.bottom, 20)

                // ── Name + Vibe ──
                VStack(spacing: 6) {
                    Text(player.name)
                        .font(.custom("BarlowCondensed-Black", size: 28))
                        .foregroundColor(C.text)
                        .tracking(0.5)
                    HStack(spacing: 10) {
                        Text("@\(player.username)")
                            .font(.system(size: 13))
                            .foregroundColor(C.sub)
                        if let vibe = player.vibeAura {
                            VibeOrb(color: vibe.color, label: vibe.label)
                        }
                    }
                }
                .padding(.bottom, 22)

                // ── Stats strip ──
                StatsStrip(player: player)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                // Divider
                Divider().background(C.border).padding(.horizontal, 20).padding(.bottom, 20)

                // ── Skill Breakdown ──
                if player.isPeerRated {
                    SkillBreakdown(skills: skills, barsVisible: barsVisible, accentColor: player.ratingColor)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    Divider().background(C.border).padding(.horizontal, 20).padding(.bottom, 20)
                }

                // ── Home Courts ──
                if !player.homeCourts.isEmpty {
                    HomeCourtsSection(courts: player.homeCourts, accentColor: player.ratingColor)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.72).delay(0.1)) {
                ratingScale   = 1.0
                ratingOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.4).delay(0.4)) {
                glowOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { barsVisible = true }
            }
        }
    }
}

// MARK: ─── Top Bar ─────────────────────────────────────────────────────────────

private struct TopBar: View {
    let player: PlayerProfile
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack {
            // Dismiss
            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    ZStack {
                        Circle().fill(C.muted.opacity(0.5)).frame(width: 30, height: 30)
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(C.sub)
                    }
                }
            }

            Spacer()

            // NETR wordmark
            Text("NETR")
                .font(.custom("BarlowCondensed-Black", size: 14))
                .foregroundColor(C.accent)
                .tracking(2.5)

            Spacer()

            // Position badge
            Text(player.position)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(player.isPro ? C.gold : C.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((player.isPro ? C.gold : C.accent).opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke((player.isPro ? C.gold : C.accent).opacity(0.4), lineWidth: 1))
                .cornerRadius(6)
        }
    }
}

// MARK: ─── Rating Hero ────────────────────────────────────────────────────────

private struct RatingHero: View {
    let player: PlayerProfile
    let scale: CGFloat
    let opacity: Double
    let glowOpacity: Double

    @State private var pulse = false

    private let heroSize: CGFloat = 170
    private let ringSize: CGFloat = 196

    var body: some View {
        ZStack {
            // Outer ambient glow
            Circle()
                .fill(player.ratingColor.opacity(player.isPeerRated ? 0.08 : 0.04))
                .frame(width: 240, height: 240)
                .blur(radius: 28)
                .opacity(glowOpacity)
                .scaleEffect(pulse ? 1.06 : 1.0)
                .animation(player.isPeerRated ? .easeInOut(duration: 2.4).repeatForever(autoreverses: true) : .default, value: pulse)

            // Progress ring (self-assessed state) OR solid ring (peer-rated)
            ZStack {
                if !player.isPeerRated {
                    // Background track
                    Circle()
                        .stroke(C.muted, lineWidth: 3)
                        .frame(width: ringSize, height: ringSize)
                    // Progress arc
                    Circle()
                        .trim(from: 0, to: player.peerProgress)
                        .stroke(
                            player.ratingColor.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.8).delay(0.3), value: player.peerProgress)
                } else {
                    // Solid ring for peer-rated
                    Circle()
                        .stroke(player.ratingColor.opacity(0.35), lineWidth: 2)
                        .frame(width: ringSize, height: ringSize)
                    Circle()
                        .stroke(player.ratingColor.opacity(0.12), lineWidth: 14)
                        .frame(width: ringSize, height: ringSize)
                        .blur(radius: 6)
                }
            }
            .opacity(opacity)

            // Main badge circle
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                player.ratingColor.opacity(0.18),
                                player.ratingColor.opacity(0.04),
                                C.card,
                            ]),
                            center: .center,
                            startRadius: 0,
                            endRadius: heroSize / 2
                        )
                    )
                    .frame(width: heroSize, height: heroSize)
                    .shadow(color: player.ratingColor.opacity(player.isPeerRated ? 0.45 : 0.15), radius: player.isPeerRated ? 30 : 12, x: 0, y: 0)

                VStack(spacing: 4) {
                    // The number
                    Text(String(format: "%.1f", player.displayRating))
                        .font(.custom("BarlowCondensed-Black", size: 64))
                        .foregroundColor(player.ratingColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    // Tier label
                    Text(player.tierLabel.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(player.ratingColor.opacity(0.7))
                        .tracking(1.5)
                }
            }
            .frame(width: heroSize, height: heroSize)
            .scaleEffect(scale)
            .opacity(opacity)

            // Lock badge (self-assessed state only)
            if !player.isPeerRated {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        LockBadge(player: player)
                            .offset(x: 8, y: 8)
                    }
                }
                .frame(width: heroSize, height: heroSize)
                .opacity(opacity)
            }

            // Avatar initials (small, inside the hero on self-assessed; top-left on peer)
            if player.isPeerRated {
                VStack {
                    HStack {
                        AvatarChip(initials: player.initials, rating: player.displayRating)
                            .offset(x: -heroSize / 2 + 10, y: heroSize / 2 - 10)
                        Spacer()
                    }
                    Spacer()
                }
                .frame(width: heroSize + 60, height: heroSize + 60)
                .opacity(opacity)
            }
        }
        .frame(height: 220)
        .onAppear { pulse = true }
    }
}

// MARK: ─── Lock Badge ─────────────────────────────────────────────────────────

private struct LockBadge: View {
    let player: PlayerProfile

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(C.sub)
            Text("\(player.peerRatingCount)/\(player.peerRatingThreshold)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(C.sub)
                .tracking(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(C.muted, lineWidth: 1))
        .cornerRadius(10)
    }
}

// MARK: ─── Avatar Chip ────────────────────────────────────────────────────────

private struct AvatarChip: View {
    let initials: String
    let rating: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(netrColor(rating).opacity(0.15))
                .frame(width: 38, height: 38)
            Circle()
                .stroke(netrColor(rating).opacity(0.5), lineWidth: 1.5)
                .frame(width: 38, height: 38)
            Text(initials)
                .font(.custom("BarlowCondensed-Black", size: 13))
                .foregroundColor(netrColor(rating))
        }
    }
}

// MARK: ─── Vibe Orb ───────────────────────────────────────────────────────────

private struct VibeOrb: View {
    let color: Color
    let label: String
    @State private var glow = false

    var body: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().fill(color.opacity(0.2)).frame(width: 14, height: 14)
                    .scaleEffect(glow ? 1.4 : 1.0)
                    .opacity(glow ? 0 : 0.7)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false), value: glow)
                Circle().fill(color).frame(width: 8, height: 8)
                    .shadow(color: color.opacity(0.8), radius: 4, x: 0, y: 0)
            }
            .frame(width: 14, height: 14)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
        }
        .onAppear { glow = true }
    }
}

// MARK: ─── Stats Strip ────────────────────────────────────────────────────────

private struct StatsStrip: View {
    let player: PlayerProfile

    var body: some View {
        HStack(spacing: 0) {
            // NETR state
            StatCell(
                value: player.isPeerRated ? "PEER" : "SELF",
                label: "RATED",
                color: player.isPeerRated ? player.ratingColor : C.pending,
                sublabel: player.isPeerRated ? "\(player.peerRatingCount) raters" : "Updates at 5"
            )

            StatDivider()

            StatCell(
                value: "\(player.gamesPlayed)",
                label: "GAMES",
                color: C.text,
                sublabel: player.city
            )

            StatDivider()

            StatCell(
                value: "\(player.peerRatingCount)",
                label: "RATINGS",
                color: player.isPeerRated ? player.ratingColor : C.pending,
                sublabel: player.isPeerRated ? "Peer avg" : "\(player.peerRatingThreshold - player.peerRatingCount) to unlock"
            )
        }
        .padding(.vertical, 14)
        .background(C.muted.opacity(0.25))
        .cornerRadius(14)
    }
}

private struct StatCell: View {
    let value: String
    let label: String
    let color: Color
    let sublabel: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("BarlowCondensed-Black", size: 22))
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(C.sub)
                .tracking(1.2)
            Text(sublabel)
                .font(.system(size: 10))
                .foregroundColor(C.muted.opacity(1.8))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(C.muted)
            .frame(width: 1, height: 40)
    }
}

// MARK: ─── Skill Breakdown ────────────────────────────────────────────────────

private struct SkillBreakdown: View {
    let skills: [SkillRow]
    let barsVisible: Bool
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SKILL BREAKDOWN")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(C.sub)
                .tracking(1.5)

            ForEach(skills) { skill in
                if let val = skill.value {
                    SkillBarRow(icon: skill.icon, label: skill.label,
                                value: val, visible: barsVisible, color: accentColor)
                }
            }
        }
    }
}

private struct SkillBarRow: View {
    let icon: String
    let label: String
    let value: Double
    let visible: Bool
    let color: Color
    @State private var appeared = false

    private var pct: Double { value / 10.0 }
    private var valColor: Color { netrColor(value) }

    var body: some View {
        HStack(spacing: 10) {
            Text(icon)
                .font(.system(size: 13))
                .frame(width: 20)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(C.sub)
                .frame(width: 90, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(C.muted).frame(height: 3)
                    Capsule()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [valColor.opacity(0.55), valColor]),
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: appeared ? geo.size.width * pct : 0, height: 3)
                        .animation(.easeOut(duration: 0.65), value: appeared)
                }
            }
            .frame(height: 3)
            Text(String(format: "%.1f", value))
                .font(.custom("BarlowCondensed-Bold", size: 14))
                .foregroundColor(valColor)
                .frame(width: 32, alignment: .trailing)
        }
        .onAppear {
            if visible { DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { appeared = true } }
        }
        .onChange(of: visible) { v in if v { appeared = true } }
    }
}

// MARK: ─── Home Courts ────────────────────────────────────────────────────────

private struct HomeCourtsSection: View {
    let courts: [HomeCourt]
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOME COURTS")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(C.sub)
                .tracking(1.5)

            ForEach(courts) { court in
                HStack(spacing: 12) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: accentColor.opacity(0.6), radius: 4, x: 0, y: 0)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(court.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(C.text)
                        Text(court.neighborhood)
                            .font(.system(size: 11))
                            .foregroundColor(C.sub)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(C.muted)
                }
            }
        }
    }
}

// MARK: ─── Full-Screen Wrapper (Modal presentation) ──────────────────────────

/// Use this when presenting the card as a sheet or full-screen cover
struct PlayerCardScreen: View {
    let player: PlayerProfile
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            C.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Pull handle
                    RoundedRectangle(cornerRadius: 3)
                        .fill(C.muted)
                        .frame(width: 36, height: 4)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    PlayerCardView(player: player, onDismiss: { dismiss() })
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: ─── Self-Assessed Explainer (shown below card when locked) ─────────────

struct SelfAssessedBanner: View {
    let peerCount: Int
    let threshold: Int
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14))
                .foregroundColor(C.sub)
            VStack(alignment: .leading, spacing: 3) {
                Text("Self-Assessed Rating")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(C.text)
                Text("Your score is from your onboarding assessment. Once \(threshold) players rate you after games, it switches to your peer average.")
                    .font(.system(size: 12))
                    .foregroundColor(C.sub)
                    .lineSpacing(3)
            }
            Spacer()
            // Mini progress
            VStack(spacing: 4) {
                Text("\(peerCount)/\(threshold)")
                    .font(.custom("BarlowCondensed-Black", size: 18))
                    .foregroundColor(accentColor)
                Text("raters")
                    .font(.system(size: 9))
                    .foregroundColor(C.sub)
            }
        }
        .padding(16)
        .background(C.surface)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(C.muted, lineWidth: 1))
        .cornerRadius(14)
    }
}

// MARK: ─── Profile Integration Example ───────────────────────────────────────

/// How to embed the card in ProfileView
struct ProfileViewExample: View {
    let player: PlayerProfile
    @State private var showCard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Tap to expand card
                PlayerCardView(player: player)
                    .padding(.horizontal, 16)
                    .onTapGesture { showCard = true }

                if !player.isPeerRated {
                    SelfAssessedBanner(
                        peerCount: player.peerRatingCount,
                        threshold: player.peerRatingThreshold,
                        accentColor: player.ratingColor
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 20)
        }
        .background(C.bg.ignoresSafeArea())
        .sheet(isPresented: $showCard) {
            PlayerCardScreen(player: player)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
    }
}

// MARK: ─── Previews ───────────────────────────────────────────────────────────

#Preview("Self-Assessed (locked)") {
    ScrollView {
        VStack(spacing: 16) {
            PlayerCardView(player: .mockSelfAssessed)
                .padding(.horizontal, 16)
            SelfAssessedBanner(
                peerCount: 2, threshold: 5,
                accentColor: netrColor(PlayerProfile.mockSelfAssessed.displayRating)
            )
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 20)
    }
    .background(Color(hex: "#080808"))
}

#Preview("Peer Rated (unlocked)") {
    ScrollView {
        PlayerCardView(player: .mockPeerRated)
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
    }
    .background(Color(hex: "#080808"))
}

#Preview("Full Screen") {
    PlayerCardScreen(player: .mockPeerRated)
}
