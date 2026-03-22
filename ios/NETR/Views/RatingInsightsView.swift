import SwiftUI

// MARK: - Model

struct RatingInsight: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let headline: String
    let detail: String
    let priority: Int
}

// MARK: - Engine

struct RatingInsightsEngine {

    static func generate(profile: UserProfile, vibeScore: Double?) -> [RatingInsight] {
        var out: [RatingInsight] = []
        let score   = profile.netrScore   ?? 4.0
        let ratings = profile.totalRatings ?? 0
        let games   = profile.totalGames   ?? 0

        out.append(sampleSize(ratings: ratings, score: score))

        if let s = skillBalance(profile: profile)              { out.append(s) }
        if let v = vibe(score: vibeScore, netr: score)         { out.append(v) }
        if games > 3 {
            if let r = ratingRatio(games: games, ratings: ratings) { out.append(r) }
        }
        if ratings >= 8 {
            if let g = growthCeiling(score: score, ratings: ratings) { out.append(g) }
        }
        return out.sorted { $0.priority > $1.priority }
    }

    private static func sampleSize(ratings: Int, score: Double) -> RatingInsight {
        if ratings == 0 {
            return RatingInsight(icon: "circle-dashed", iconColor: NETRTheme.subtext,
                headline: "No peer ratings yet",
                detail: "Your score updates as soon as teammates rate you after games. Play with active NETR players to get your first ratings.",
                priority: 10)
        }
        if ratings < 5 {
            let needed = 5 - ratings
            let word   = ratings == 1 ? "rating" : "ratings"
            return RatingInsight(icon: "loader", iconColor: NETRTheme.gold,
                headline: "Score is still early",
                detail: "\(ratings) peer \(word) in. \(needed) more unlock your Verified badge and make the score more reliable.",
                priority: 10)
        }
        if ratings < 15 {
            return RatingInsight(icon: "trending-up", iconColor: NETRTheme.neonGreen,
                headline: "Score is building",
                detail: "\(ratings) players have rated your game. You're past the early stage — keep running and it will keep tightening.",
                priority: 8)
        }
        let label = String(format: "%.1f", score)
        return RatingInsight(icon: "shield-check", iconColor: NETRTheme.neonGreen,
            headline: "Well-established score",
            detail: "\(ratings) peer ratings in. Your \(label) is a reliable reflection of how the community sees your game.",
            priority: 6)
    }

    private static func skillBalance(profile: UserProfile) -> RatingInsight? {
        let raw: [(String, Double)] = [
            ("Shooting",      profile.catShooting    ?? 0),
            ("Finishing",     profile.catFinishing    ?? 0),
            ("Ball Handling", profile.catDribbling    ?? 0),
            ("Passing",       profile.catPassing      ?? 0),
            ("Defense",       profile.catDefense      ?? 0),
            ("Rebounding",    profile.catRebounding   ?? 0),
            ("Basketball IQ", profile.catBasketballIq ?? 0)
        ]
        let skills = raw.filter { $0.1 > 0 }
        guard skills.count >= 3 else { return nil }
        let sorted = skills.sorted { $0.1 > $1.1 }
        let top    = sorted.first!
        let bottom = sorted.last!
        let gap    = top.1 - bottom.1
        if gap < 0.4 {
            return RatingInsight(icon: "sliders-horizontal", iconColor: NETRTheme.blue,
                headline: "Well-rounded game",
                detail: "Your skills are closely balanced. \(top.0) edges ahead as your strongest area.",
                priority: 5)
        }
        return RatingInsight(icon: "bar-chart-2", iconColor: NETRTheme.blue,
            headline: "\(top.0) is your strength",
            detail: "\(bottom.0) has the most room to grow. Balanced players earn higher scores over time.",
            priority: 5)
    }

    private static func vibe(score: Double?, netr: Double) -> RatingInsight? {
        guard let score else {
            return RatingInsight(icon: "users", iconColor: Color.purple,
                headline: "No vibe score yet",
                detail: "Your vibe reflects how much teammates enjoy running with you — energy, communication, attitude.",
                priority: 4)
        }
        if score >= 3.5 {
            return RatingInsight(icon: "heart", iconColor: .pink,
                headline: "Teammates love running with you",
                detail: "Your vibe score is strong. Attitude, communication, and energy are all noticed on the court.",
                priority: 7)
        }
        if score <= 2.0 {
            return RatingInsight(icon: "message-circle", iconColor: NETRTheme.gold,
                headline: "Your vibe has room to grow",
                detail: "Skill gets you on the court. Vibe keeps you on it. Energy and communication matter as much as buckets.",
                priority: 7)
        }
        return nil
    }

    private static func ratingRatio(games: Int, ratings: Int) -> RatingInsight? {
        guard games > 0 else { return nil }
        let rate = Double(ratings) / Double(games)
        if rate < 0.25 && games > 5 {
            return RatingInsight(icon: "user-x", iconColor: NETRTheme.gold,
                headline: "Most games went unrated",
                detail: "You've played \(games) games but only \(ratings) were rated. More NETR players means more data and a more accurate score.",
                priority: 6)
        }
        if rate > 0.75 {
            return RatingInsight(icon: "check-circle", iconColor: NETRTheme.neonGreen,
                headline: "High rating activity",
                detail: "Most of your games have been peer-rated. That's the best way to build an accurate, credible score.",
                priority: 4)
        }
        return nil
    }

    private static func growthCeiling(score: Double, ratings: Int) -> RatingInsight? {
        if score >= 4.5 && score <= 5.8 && ratings >= 10 {
            return RatingInsight(icon: "rocket", iconColor: NETRTheme.neonGreen,
                headline: "Room to grow",
                detail: "Your score can climb further when you play with higher-level competition. The caliber of who rates you matters.",
                priority: 9)
        }
        if score > 6.5 {
            return RatingInsight(icon: "award", iconColor: NETRTheme.gold,
                headline: "Elite tier",
                detail: "You're in the top tier of NETR players. Your score carries real weight — peers at your level have confirmed it.",
                priority: 7)
        }
        return nil
    }
}

// MARK: - Top-level view

struct RatingInsightsView: View {
    let profile: UserProfile
    let vibeScore: Double?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    RatingInsightsHeader(profile: profile, vibeScore: vibeScore, onDismiss: { dismiss() })
                    Divider()
                        .background(NETRTheme.border)
                        .padding(.horizontal, 20)
                    RatingInsightsList(profile: profile, vibeScore: vibeScore)
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Header

struct RatingInsightsHeader: View {
    let profile: UserProfile
    let vibeScore: Double?
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NETRTheme.subtext)
                        .frame(width: 30, height: 30)
                        .background(NETRTheme.card, in: Circle())
                        .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(NETRTheme.neonGreen)
                    Text("RATING BREAKDOWN")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(NETRTheme.subtext)
                }

                RatingScoreDisplay(score: profile.netrScore)

                HStack(spacing: 10) {
                    RatingStatPill(value: "\(profile.totalRatings ?? 0)", label: "RATINGS")
                    RatingStatPill(value: "\(profile.totalGames ?? 0)", label: "GAMES")
                    if let v = vibeScore {
                        RatingStatPill(value: String(format: "%.1f", v), label: "VIBE")
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
}

// MARK: - Score display

struct RatingScoreDisplay: View {
    let score: Double?

    var body: some View {
        Group {
            if let score {
                let color = NETRRating.color(for: score)
                Text(String(format: "%.2f", score))
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                    .neonGlow(color, radius: 10)
            } else {
                Text("--")
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
    }
}

// MARK: - Stat pill

struct RatingStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(NETRTheme.text)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(minWidth: 64)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(NETRTheme.card, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
    }
}

// MARK: - Insights list

struct RatingInsightsList: View {
    let profile: UserProfile
    let vibeScore: Double?

    private var insights: [RatingInsight] {
        RatingInsightsEngine.generate(profile: profile, vibeScore: vibeScore)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("WHAT YOUR DATA SAYS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(NETRTheme.subtext)
                Spacer()
            }
            .padding(.top, 20)

            ForEach(insights.indices, id: \.self) { index in
                InsightCard(insight: insights[index], delay: Double(index) * 0.07)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 48)
    }
}

// MARK: - Insight card

struct InsightCard: View {
    let insight: RatingInsight
    let delay: Double
    @State private var appeared = false

    var body: some View {
        InsightCardContent(insight: insight)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct InsightCardContent: View {
    let insight: RatingInsight

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(insight.iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                LucideIcon(insight.icon, size: 16)
                    .foregroundStyle(insight.iconColor)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NETRTheme.text)
                Text(insight.detail)
                    .font(.caption)
                    .foregroundStyle(NETRTheme.subtext)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NETRTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
    }
}
