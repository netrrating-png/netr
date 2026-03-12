import SwiftUI

// ─────────────────────────────────────────────────────────────
// MARK: — NETR Rating Scale
// Scale: 2.0 – 9.9
// Regular player ceiling: 9.4
// 9.5–9.9 locked to verified pros only
// Bayesian prior: 3.2 (real average pickup player)
// ─────────────────────────────────────────────────────────────

// MARK: — Tier Model

struct NETRTier {
    let name: String
    let range: ClosedRange<Double>
    let color: Color
    let hexColor: String
    let description: String
    let percentile: String
    let stat: String
    let isLocked: Bool

    static let all: [NETRTier] = [
        NETRTier(
            name: "In The League",
            range: 9.5...9.9,
            color: Color(hex: "#C40010"),
            hexColor: "#C40010",
            description: "Reserved exclusively for verified NBA, WNBA, G-League, and professional players. There is no amount of pickup games that gets you here.",
            percentile: "Verified Only",
            stat: "Pros exclusively",
            isLocked: true
        ),
        NETRTier(
            name: "Certified",
            range: 9.0...9.4,
            color: Color(hex: "#FF3B30"),
            hexColor: "#FF3B30",
            description: "The highest reachable tier for pickup players. Everyone at the court knows your name before you touch the ball. Semi-pro talent. Undeniable presence.",
            percentile: "Top 1%",
            stat: "Extremely rare",
            isLocked: false
        ),
        NETRTier(
            name: "Elite",
            range: 8.0...8.9,
            color: Color(hex: "#FF7A00"),
            hexColor: "#FF7A00",
            description: "You dominate most runs you step into. Whether it's organized ball or years of grinding — the result is the same. You can hoop.",
            percentile: "Top 3%",
            stat: "Rare",
            isLocked: false
        ),
        NETRTier(
            name: "Built Different",
            range: 7.0...7.9,
            color: Color(hex: "#FFC247"),
            hexColor: "#FFC247",
            description: "Something in your game stands out. Doesn't matter if it was the weight room, the gym, or thousands of hours at the park — people feel it when they guard you.",
            percentile: "Top 10%",
            stat: "Serious hoopers",
            isLocked: false
        ),
        NETRTier(
            name: "Hooper",
            range: 6.0...6.9,
            color: Color(hex: "#39FF14"),
            hexColor: "#39FF14",
            description: "Nobody questions if you belong. You make plays, understand the game, hold your own in any run. Top quarter of all pickup players.",
            percentile: "Top 20%",
            stat: "Park regular",
            isLocked: false
        ),
        NETRTier(
            name: "Got Game",
            range: 5.0...5.9,
            color: Color(hex: "#2ECC71"),
            hexColor: "#2ECC71",
            description: "You contribute, you compete, you make your team better. Better than most people who lace up. The ceiling is right there.",
            percentile: "Top 35%",
            stat: "Above average",
            isLocked: false
        ),
        NETRTier(
            name: "Prospect",
            range: 4.0...4.9,
            color: Color(hex: "#2DA8FF"),
            hexColor: "#2DA8FF",
            description: "The foundation is there. Whether you built it at organized practice, the rec center, or grinding at the park every weekend — you can play.",
            percentile: "Above Avg",
            stat: "Developing",
            isLocked: false
        ),
        NETRTier(
            name: "On The Come Up",
            range: 3.0...3.9,
            color: Color(hex: "#7B9FFF"),
            hexColor: "#7B9FFF",
            description: "The real average — the majority of people who show up to a pickup game land right here. You showed up, you ran, you're putting in reps.",
            percentile: "Average",
            stat: "Most players",
            isLocked: false
        ),
        NETRTier(
            name: "Fresh Laces",
            range: 2.0...2.9,
            color: Color(hex: "#9B8BFF"),
            hexColor: "#9B8BFF",
            description: "Everybody started here. You laced up, you showed up — that's the whole thing. Your score will move as your game does.",
            percentile: "Just Starting",
            stat: "The beginning",
            isLocked: false
        ),
    ]
}

// MARK: — Core Helpers

struct NETRRating {

    /// Returns the color for a given score
    static func color(for score: Double?) -> Color {
        guard let score else { return Color(hex: "#444444") }
        switch score {
        case 9.5...9.9: return Color(hex: "#C40010")
        case 9.0..<9.5: return Color(hex: "#FF3B30")
        case 8.0..<9.0: return Color(hex: "#FF7A00")
        case 7.0..<8.0: return Color(hex: "#FFC247")
        case 6.0..<7.0: return Color(hex: "#39FF14")
        case 5.0..<6.0: return Color(hex: "#2ECC71")
        case 4.0..<5.0: return Color(hex: "#2DA8FF")
        case 3.0..<4.0: return Color(hex: "#7B9FFF")
        case 2.0..<3.0: return Color(hex: "#9B8BFF")
        default:        return Color(hex: "#444444")
        }
    }

    /// Returns the tier name for a given score
    static func tierName(for score: Double?) -> String {
        guard let score else { return "Unrated" }
        switch score {
        case 9.5...9.9: return "In The League"
        case 9.0..<9.5: return "Certified"
        case 8.0..<9.0: return "Elite"
        case 7.0..<8.0: return "Built Different"
        case 6.0..<7.0: return "Hooper"
        case 5.0..<6.0: return "Got Game"
        case 4.0..<5.0: return "Prospect"
        case 3.0..<4.0: return "On The Come Up"
        case 2.0..<3.0: return "Fresh Laces"
        default:        return "Unrated"
        }
    }

    /// Returns the full NETRTier object for a given score
    static func tier(for score: Double?) -> NETRTier? {
        guard let score else { return nil }
        return NETRTier.all.first { $0.range.contains(score) }
    }

    /// Clamps a score to the valid range for a given player type
    static func clamp(_ raw: Double, isVerifiedPro: Bool = false) -> Double {
        let minimum = 2.0
        let maximum = isVerifiedPro ? 9.9 : 9.4
        return max(minimum, min(raw, maximum))
    }

    /// Formats a score for display (e.g. "7.2" or "—")
    static func formatted(_ score: Double?) -> String {
        guard let score else { return "—" }
        return String(format: "%.1f", score)
    }

    /// Bayesian prior — the assumed mean before peer reviews come in
    /// Set to 3.2 to reflect the real average pickup player population
    static let bayesianPrior: Double = 3.2
    static let bayesianK: Int = 8

    /// Returns true if a score is in the NBA-locked tier
    static func isLockedTier(_ score: Double) -> Bool {
        return score >= 9.5
    }
}

// MARK: — NETR Score Badge

struct NETRBadge: View {
    let score: Double?
    var size: BadgeSize = .medium

    enum BadgeSize {
        case small, medium, large, xl
        var dimension: CGFloat {
            switch self { case .small: return 44; case .medium: return 56; case .large: return 72; case .xl: return 110 }
        }
        var fontSize: CGFloat {
            switch self { case .small: return 14; case .medium: return 18; case .large: return 24; case .xl: return 38 }
        }
        var borderWidth: CGFloat {
            switch self { case .xl: return 3; default: return 2 }
        }
        var showLabel: Bool { self == .xl }
    }

    var color: Color { NETRRating.color(for: score) }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.18), color.opacity(0.04)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size.dimension / 2
                    )
                )
            Circle()
                .stroke(score != nil ? color : Color(hex: "#444444"), lineWidth: size.borderWidth)

            VStack(spacing: 2) {
                Text(NETRRating.formatted(score))
                    .font(.custom("BarlowCondensed-Black", size: size.fontSize))
                    .foregroundColor(score != nil ? color : Color(hex: "#444444"))
                    .lineLimit(1)

                if size.showLabel {
                    Text("NETR")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(color.opacity(0.8))
                        .kerning(1.5)
                }
            }
        }
        .frame(width: size.dimension, height: size.dimension)
        .shadow(color: score != nil ? color.opacity(0.35) : .clear, radius: size == .xl ? 16 : 8)
    }
}

// MARK: — Tier Pill

struct NETRTierPill: View {
    let score: Double?
    var showLock: Bool = true

    private var tier: NETRTier? { NETRRating.tier(for: score) }
    private var color: Color { NETRRating.color(for: score) }

    var body: some View {
        HStack(spacing: 5) {
            if let tier, tier.isLocked, showLock {
                Text("⭐")
                    .font(.system(size: 11))
            }
            Text(NETRRating.tierName(for: score))
                .font(.system(size: 11, weight: .bold))
                .kerning(0.5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .overlay(
            Capsule().stroke(color.opacity(0.35), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

// MARK: — Score Ring (for Profile Hero)

struct NETRScoreRing: View {
    let score: Double?
    var diameter: CGFloat = 120
    var lineWidth: CGFloat = 5

    private var color: Color { NETRRating.color(for: score) }
    private var progress: Double {
        guard let score else { return 0 }
        return (score - 2.0) / 7.9 // normalized 2.0–9.9
    }

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Color(hex: "#2A2A35"), lineWidth: lineWidth)

            // Fill
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [color.opacity(0.5), color],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content
            VStack(spacing: 4) {
                Text(NETRRating.formatted(score))
                    .font(.custom("BarlowCondensed-Black", size: diameter * 0.28))
                    .foregroundColor(color)

                Text(NETRRating.tierName(for: score))
                    .font(.system(size: diameter * 0.07, weight: .semibold))
                    .foregroundColor(color.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: diameter, height: diameter)
        .shadow(color: color.opacity(0.3), radius: 16)
        .onAppear {
            withAnimation(.easeOut(duration: 1.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: score) { _ in
            withAnimation(.easeOut(duration: 1.0)) {
                animatedProgress = progress
            }
        }
    }
}

// MARK: — Full Rating Scale Screen

struct NETRRatingScaleView: View {
    @Environment(\.dismiss) var dismiss
    @State private var appeared = false

    // Colors
    private let bg    = Color(hex: "#050507")
    private let card  = Color(hex: "#111116")
    private let border = Color(hex: "#1E1E26")
    private let sub   = Color(hex: "#6A6A82")

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Header ──
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("THE NETR SCALE")
                                    .font(.system(size: 11, weight: .bold))
                                    .kerning(1.4)
                                    .foregroundColor(Color(hex: "#39FF14"))

                                Text("Know Your\nLevel.")
                                    .font(.custom("BarlowCondensed-Black", size: 44))
                                    .foregroundColor(.white)
                                    .lineSpacing(-2)
                            }
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(sub)
                                    .padding(10)
                                    .background(card)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(border, lineWidth: 1))
                            }
                        }

                        // Avg callout
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("3.0–3.9")
                                    .font(.custom("BarlowCondensed-Black", size: 22))
                                    .foregroundColor(Color(hex: "#7B9FFF"))
                                Text("Where most pickup players land")
                                    .font(.system(size: 12))
                                    .foregroundColor(sub)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("6.0+")
                                    .font(.custom("BarlowCondensed-Black", size: 22))
                                    .foregroundColor(Color(hex: "#39FF14"))
                                Text("Top 20–25%")
                                    .font(.system(size: 12))
                                    .foregroundColor(sub)
                            }
                        }
                        .padding(16)
                        .background(card)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(border, lineWidth: 1))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 24)

                    // ── Tier Cards ──
                    VStack(spacing: 8) {
                        ForEach(Array(NETRTier.all.enumerated()), id: \.offset) { index, tier in
                            TierCard(tier: tier, isAverage: tier.name == "On The Come Up")
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 16)
                                .animation(
                                    .easeOut(duration: 0.45).delay(Double(index) * 0.07),
                                    value: appeared
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { appeared = true }
    }
}

// MARK: — Tier Card Component

private struct TierCard: View {
    let tier: NETRTier
    var isAverage: Bool = false

    private let bg    = Color(hex: "#111116")
    private let border = Color(hex: "#1E1E26")
    private let sub   = Color(hex: "#6A6A82")
    private let muted = Color(hex: "#2A2A35")

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 16) {

                // Score badge
                ZStack {
                    Circle()
                        .fill(tier.color.opacity(0.12))
                    Circle()
                        .stroke(tier.color, lineWidth: 2)
                    VStack(spacing: 2) {
                        Text(rangeLabel)
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(tier.color)
                        Text("NETR")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(tier.color.opacity(0.6))
                            .kerning(1)
                    }
                }
                .frame(width: 64, height: 64)
                .shadow(color: tier.color.opacity(0.25), radius: 8)

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 6) {
                        if tier.isLocked {
                            Text("⭐")
                                .font(.system(size: 14))
                        }
                        Text(tier.name)
                            .font(.custom("BarlowCondensed-Black", size: 24))
                            .foregroundColor(.white)
                    }

                    Text(tier.description)
                        .font(.system(size: 12))
                        .foregroundColor(sub)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 99)
                                .fill(muted)
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 99)
                                .fill(
                                    LinearGradient(
                                        colors: [tier.color.opacity(0.5), tier.color],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * barWidth, height: 3)
                        }
                    }
                    .frame(height: 3)
                }

                // Right side
                VStack(alignment: .trailing, spacing: 6) {
                    if tier.isLocked {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                            Text("PROS ONLY")
                                .font(.system(size: 9, weight: .black))
                                .kerning(0.5)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#C40010").opacity(0.15))
                        .foregroundColor(Color(hex: "#C40010"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(hex: "#C40010").opacity(0.35), lineWidth: 1))
                    } else {
                        Text(tier.percentile)
                            .font(.system(size: 10, weight: .black))
                            .kerning(0.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tier.color.opacity(0.12))
                            .foregroundColor(tier.color)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(tier.color.opacity(0.25), lineWidth: 1))
                    }
                    Text(tier.stat)
                        .font(.system(size: 11))
                        .foregroundColor(sub)
                }
                .frame(minWidth: 80, alignment: .trailing)
            }
            .padding(18)
            .background(
                isAverage
                ? LinearGradient(colors: [Color(hex: "#0D0D18"), bg], startPoint: .topLeading, endPoint: .bottomTrailing)
                : LinearGradient(colors: [bg, bg], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isAverage ? tier.color.opacity(0.3) : border,
                        lineWidth: isAverage ? 1.5 : 1
                    )
            )
            // Left accent stripe
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(tier.color)
                    .frame(width: 4)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 2)
                    )
                    .shadow(color: tier.color.opacity(0.5), radius: 6)
            }

            // "Most players" banner
            if isAverage {
                Text("Most players land here")
                    .font(.system(size: 8, weight: .black))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(tier.color)
                    .foregroundColor(.white)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 8,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 18
                        )
                    )
            }
        }
        // NBA glow
        .shadow(
            color: tier.isLocked ? tier.color.opacity(0.3) : .clear,
            radius: 16
        )
    }

    private var rangeLabel: String {
        let lo = tier.range.lowerBound
        let hi = tier.range.upperBound
        return "\(String(format: "%.1f", lo))–\(String(format: "%.1f", hi))"
    }

    private var barWidth: Double {
        switch tier.name {
        case "In The League":  return 1.00
        case "Certified":      return 0.88
        case "Elite":          return 0.76
        case "Built Different": return 0.62
        case "Hooper":         return 0.50
        case "Got Game":       return 0.39
        case "Prospect":       return 0.28
        case "On The Come Up": return 0.18
        case "Fresh Laces":    return 0.08
        default:               return 0.10
        }
    }
}

// MARK: — Preview

#Preview("Rating Scale Screen") {
    NETRRatingScaleView()
}

#Preview("Badges") {
    ZStack {
        Color(hex: "#050507").ignoresSafeArea()
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                NETRBadge(score: 9.7, size: .xl)
                NETRBadge(score: 7.4, size: .xl)
                NETRBadge(score: 3.2, size: .xl)
            }
            HStack(spacing: 16) {
                NETRBadge(score: 8.2, size: .large)
                NETRBadge(score: 5.9, size: .large)
                NETRBadge(score: nil, size: .large)
            }
            HStack(spacing: 12) {
                NETRTierPill(score: 9.7)
                NETRTierPill(score: 6.1)
                NETRTierPill(score: 3.4)
                NETRTierPill(score: nil)
            }
        }
    }
}

#Preview("Score Ring") {
    ZStack {
        Color(hex: "#050507").ignoresSafeArea()
        VStack(spacing: 32) {
            NETRScoreRing(score: 7.4, diameter: 140)
            NETRScoreRing(score: 3.2, diameter: 140)
        }
    }
}
