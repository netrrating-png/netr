import SwiftUI

nonisolated struct RadarSkill: Sendable {
    let label: String
    let icon: String
    let isEmoji: Bool
    let raw: Double
    let value: Double
    let categoryColor: Color

    init(label: String, icon: String, raw: Double, value: Double, categoryColor: Color = Color(hex: "#39FF14")) {
        let emojiCheck = icon.unicodeScalars.contains { $0.properties.isEmoji && !$0.isASCII }
        self.label = label
        self.icon = icon
        self.isEmoji = emojiCheck
        self.raw = raw
        self.value = value
        self.categoryColor = categoryColor
    }
}

struct SkillRadarView: View {
    let skills: [RadarSkill]
    let animated: Bool
    let size: CGFloat
    let tierColor: Color

    init(skills: [RadarSkill], size: CGFloat = 260, animated: Bool = true, tierColor: Color = Color(hex: "#39FF14")) {
        self.skills = skills
        self.size = size
        self.animated = animated
        self.tierColor = tierColor
    }

    // Per-spoke progress — each animates independently with stagger
    @State private var spokeProgress: [Double] = Array(repeating: 0, count: 7)
    @State private var labelOpacity: [Double] = Array(repeating: 0, count: 7)
    // Breathing center: 0 = exhale, 1 = inhale
    @State private var breathePhase: CGFloat = 0

    private let levels = 5
    private let maxVal = 10.0
    private let ringDim = Color(hex: "#1C1C2A")
    private let ringOuter = Color(hex: "#2A2A3A")
    private let darkBg = Color(hex: "#050507")
    private var n: Int { skills.count }
    private var cx: CGFloat { size / 2 }
    private var cy: CGFloat { size / 2 }
    private var maxR: CGFloat { size / 2 - 52 }
    private var labelR: CGFloat { size / 2 - 22 }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Breathing center glow — driven by breathePhase (0=exhale, 1=inhale)
                Canvas { ctx, _ in
                    let r = 18 + breathePhase * 22        // 18...40
                    let opac = 0.05 + breathePhase * 0.22 // 0.05...0.27
                    let glow = Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
                    ctx.fill(glow, with: .color(tierColor.opacity(Double(opac))))
                    let ri = r * 0.45
                    let inner = Path(ellipseIn: CGRect(x: cx - ri, y: cy - ri, width: ri * 2, height: ri * 2))
                    ctx.fill(inner, with: .color(tierColor.opacity(Double(opac) * 0.65)))
                }
                .frame(width: size, height: size)
                .blur(radius: 9)

                // Main radar canvas
                Canvas { context, _ in
                    let center = CGPoint(x: cx, y: cy)

                    // Grid rings
                    for li in 1...levels {
                        let frac = CGFloat(li) / CGFloat(levels)
                        let isOuter = li == levels
                        let ringPoints = polygonPoints(radius: maxR * frac)
                        var ringPath = Path()
                        ringPath.addLines(ringPoints)
                        ringPath.closeSubpath()
                        context.stroke(ringPath, with: .color(isOuter ? ringOuter : ringDim), lineWidth: isOuter ? 1.2 : 0.7)
                    }

                    // Spokes
                    let outerPoints = polygonPoints(radius: maxR)
                    for pt in outerPoints {
                        var spoke = Path()
                        spoke.move(to: center)
                        spoke.addLine(to: pt)
                        context.stroke(spoke, with: .color(ringDim), lineWidth: 0.7)
                    }

                    // Ring value labels on top spoke
                    for li in 1...levels {
                        let frac = CGFloat(li) / CGFloat(levels)
                        let pt = polygonPoint(index: 0, radius: maxR * frac)
                        let text = Text("\(Int(Double(li) / Double(levels) * maxVal))")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(hex: "#2E2E42"))
                        context.draw(context.resolve(text), at: CGPoint(x: pt.x, y: pt.y - 7))
                    }

                    // Per-spoke data points — each has its own progress
                    let skillPoints = skills.enumerated().map { i, s in
                        let p = i < spokeProgress.count ? CGFloat(spokeProgress[i]) : 0
                        return polygonPoint(index: i, radius: maxR * CGFloat(s.value) * p)
                    }

                    // Overall fill progress = average of all spokes
                    let avgProgress = spokeProgress.prefix(n).reduce(0, +) / Double(max(n, 1))

                    // Data fill
                    var fillPath = Path()
                    fillPath.addLines(skillPoints)
                    fillPath.closeSubpath()
                    context.fill(fillPath, with: .color(tierColor.opacity(0.07 * avgProgress)))

                    // Data stroke
                    var strokePath = Path()
                    strokePath.addLines(skillPoints)
                    strokePath.closeSubpath()
                    context.stroke(strokePath, with: .color(tierColor.opacity(0.8 * avgProgress)), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))

                    // Spoke lines center → data
                    for (i, pt) in skillPoints.enumerated() {
                        let p = i < spokeProgress.count ? spokeProgress[i] : 0
                        var spokeLine = Path()
                        spokeLine.move(to: center)
                        spokeLine.addLine(to: pt)
                        context.stroke(spokeLine, with: .color(tierColor.opacity(0.18 * p)), lineWidth: 1)
                    }

                    // Dots — halo + outer + inner per spoke
                    for (i, pt) in skillPoints.enumerated() {
                        let p = i < spokeProgress.count ? spokeProgress[i] : 0
                        let halo = Path(ellipseIn: CGRect(x: pt.x - 7, y: pt.y - 7, width: 14, height: 14))
                        context.fill(halo, with: .color(tierColor.opacity(0.14 * p)))
                        let outer = Path(ellipseIn: CGRect(x: pt.x - 4.5, y: pt.y - 4.5, width: 9, height: 9))
                        context.fill(outer, with: .color(tierColor.opacity(p)))
                        let inner = Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4))
                        context.fill(inner, with: .color(darkBg.opacity(p)))
                    }
                }
                .frame(width: size, height: size)

                // Axis labels — staggered fade-in per spoke
                ForEach(Array(skills.enumerated()), id: \.offset) { i, skill in
                    let pt = polygonPoint(index: i, radius: labelR)
                    VStack(spacing: 2) {
                        Text(skill.label)
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(skill.categoryColor)
                        Text(String(format: "%.1f", skill.raw))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(skill.categoryColor)
                    }
                    .opacity(i < labelOpacity.count ? labelOpacity[i] : 0)
                    .scaleEffect(i < labelOpacity.count ? (0.7 + 0.3 * labelOpacity[i]) : 0.7)
                    .position(x: pt.x, y: pt.y)
                }
            }
            .frame(width: size, height: size)

            legendGrid
                .opacity(spokeProgress.reduce(0, +) / Double(max(n, 1)) > 0.5 ? 1 : 0)
                .animation(.easeIn(duration: 0.4), value: spokeProgress.reduce(0, +))

            insightsSection
                .opacity(spokeProgress.reduce(0, +) / Double(max(n, 1)) > 0.85 ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: spokeProgress.reduce(0, +))
        }
        .onAppear {
            guard animated else {
                spokeProgress = Array(repeating: 1, count: 7)
                labelOpacity = Array(repeating: 1, count: 7)
                breathePhase = 0.5
                return
            }

            // Stagger each spoke's spring reveal — one by one
            for i in 0..<min(skills.count, 7) {
                let delay = 0.05 + Double(i) * 0.11
                withAnimation(.spring(response: 0.52, dampingFraction: 0.60).delay(delay)) {
                    spokeProgress[i] = 1.0
                }
                // Label pops in just after its dot arrives
                withAnimation(.spring(response: 0.35, dampingFraction: 0.65).delay(delay + 0.36)) {
                    labelOpacity[i] = 1.0
                }
            }

            // Start breathing center after last spoke settles
            // Pattern: quick inhale → hold → slow exhale × 2, then settle to faint resting glow
            let b = 0.05 + Double(min(skills.count, 7) - 1) * 0.11 + 0.65

            // Breath 1 — full
            withAnimation(.easeIn(duration: 0.72).delay(b)) {
                breathePhase = 1.0
            }
            withAnimation(.easeOut(duration: 1.1).delay(b + 1.05)) {
                breathePhase = 0.0
            }

            // Breath 2 — slightly shallower
            withAnimation(.easeIn(duration: 0.68).delay(b + 2.55)) {
                breathePhase = 0.78
            }
            withAnimation(.easeOut(duration: 1.0).delay(b + 3.55)) {
                breathePhase = 0.0
            }

            // Settle to a faint resting glow — just enough to feel alive without looping
            withAnimation(.easeOut(duration: 1.6).delay(b + 5.1)) {
                breathePhase = 0.14
            }
        }
    }

    // Per-category colored legend matching SA style
    private var legendGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(Array(skills.enumerated()), id: \.offset) { _, skill in
                HStack(spacing: 7) {
                    Circle().fill(skill.categoryColor).frame(width: 8, height: 8)
                    Text(skill.label)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#BBBBBB"))
                    Spacer()
                    Text(String(format: "%.1f", skill.raw))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(skill.categoryColor)
                }
            }
        }
    }

    private var insightsSection: some View {
        let sorted = skills.sorted { $0.value > $1.value }
        let strengths = Array(sorted.prefix(2))
        let weaknesses = Array(sorted.suffix(2).reversed())

        return Group {
            VStack(alignment: .leading, spacing: 8) {
                InsightRow(
                    icon: "zap",
                    color: NETRTheme.neonGreen,
                    label: "Strengths",
                    items: strengths.map(\.label)
                )
                InsightRow(
                    icon: "target",
                    color: NETRTheme.gold,
                    label: "Weaknesses",
                    items: weaknesses.map(\.label)
                )
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NETRTheme.surface, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
        }
    }

    private func polygonPoint(index: Int, radius: CGFloat) -> CGPoint {
        let angle = (2 * .pi * CGFloat(index) / CGFloat(n)) - (.pi / 2)
        return CGPoint(x: cx + radius * cos(angle), y: cy + radius * sin(angle))
    }

    private func polygonPoints(radius: CGFloat) -> [CGPoint] {
        (0..<n).map { polygonPoint(index: $0, radius: radius) }
    }
}

private struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(NETRTheme.subtext)
        }
    }
}

private struct InsightRow: View {
    let icon: String
    let color: Color
    let label: String
    let items: [String]

    var body: some View {
        HStack(spacing: 10) {
            LucideIcon(icon, size: 12)
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
                .frame(minWidth: 68, alignment: .leading)
            Text(items.joined(separator: ", "))
                .font(.system(size: 13))
                .foregroundStyle(NETRTheme.text)
        }
    }
}

struct ScoreInfoButton: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(NETRTheme.subtext.opacity(0.12))
                .frame(width: 26, height: 26)
            Circle()
                .strokeBorder(NETRTheme.muted, lineWidth: 1)
                .frame(width: 26, height: 26)
            VStack(spacing: 2) {
                Circle()
                    .fill(NETRTheme.subtext)
                    .frame(width: 3, height: 3)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(NETRTheme.subtext)
                    .frame(width: 2.5, height: 7)
            }
        }
    }
}

struct ScoreInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let sections: [(icon: String, title: String, description: String, highlight: Bool)] = [
        ("🎯", "7 Core Skill Areas", "Your answers across Shooting, Finishing, Handles, Passing, Defense, Rebounding, and Basketball IQ are each weighted based on how much they reflect overall player value.", false),
        ("⚖️", "Weighted & Calibrated", "Not all categories count equally. Answers are run through a multi-factor model that accounts for level played, age, and consistency across your responses.", false),
        ("📉", "Self-Assessment Discount", "Research shows players consistently rate themselves higher than peers do. A built-in discount keeps your estimate realistic — it's not a penalty, it's calibration.", false),
        ("🏀", "This Is Just the Starting Line", "Your true NETR comes from the court. Every game you play, teammates and opponents rate you — those peer ratings are what move your score up or down over time.", true),
    ]

    var body: some View {
        ZStack {
            NETRTheme.surface.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(NETRTheme.neonGreen.opacity(0.12))
                                .frame(width: 38, height: 38)
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1)
                                .frame(width: 38, height: 38)
                            Text("ℹ️")
                                .font(.system(size: 18))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("How Your Score Is Calculated")
                                .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                                .foregroundStyle(NETRTheme.text)
                            Text("Self-Assessment Estimate")
                                .font(.system(size: 12))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                    VStack(spacing: 12) {
                        ForEach(0..<sections.count, id: \.self) { i in
                            let s = sections[i]
                            HStack(alignment: .top, spacing: 12) {
                                Text(s.icon)
                                    .font(.system(size: 20))
                                    .frame(width: 28)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(s.title)
                                        .font(.system(.callout, design: .default, weight: .black).width(.compressed))
                                        .foregroundStyle(s.highlight ? NETRTheme.neonGreen : NETRTheme.text)
                                    Text(s.description)
                                        .font(.system(size: 13))
                                        .foregroundStyle(NETRTheme.subtext)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                s.highlight
                                    ? NETRTheme.neonGreen.opacity(0.07)
                                    : Color.white.opacity(0.03),
                                in: .rect(cornerRadius: 14)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        s.highlight
                                            ? NETRTheme.neonGreen.opacity(0.22)
                                            : NETRTheme.border,
                                        lineWidth: 1
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    Button(action: { dismiss() }) {
                        Text("Got it")
                            .font(.system(.headline, design: .default, weight: .bold))
                            .foregroundStyle(NETRTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [NETRTheme.neonGreen, NETRTheme.darkGreen],
                                    startPoint: .leading, endPoint: .trailing
                                ),
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .presentationDetents([.fraction(0.82)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }
}

// Per-category colors matching SASkillCategory.color exactly
private let radarCategoryColors: [String: Color] = [
    "Shooting":     Color(hex: "#39FF14"),
    "Finishing":   Color(hex: "#FF7A00"),
    "Handles":     Color(hex: "#FFC247"),
    "Playmaking":  Color(hex: "#2ECC71"),
    "Defense":     Color(hex: "#FF3B30"),
    "Rebounding":  Color(hex: "#2DA8FF"),
    "IQ":          Color(hex: "#9B8BFF"),
]

func buildRadarSkills(from skillRatings: SkillRatings) -> [RadarSkill] {
    let items: [(String, String, Double?)] = [
        ("Shooting", "crosshair", skillRatings.shooting),
        ("Finishing", "flame", skillRatings.finishing),
        ("Handles", "hand", skillRatings.ballHandling),
        ("Playmaking", "zap", skillRatings.playmaking),
        ("Defense", "shield", skillRatings.defense),
        ("Rebounding", "arrow-up-circle", skillRatings.rebounding),
        ("IQ", "brain", skillRatings.basketballIQ),
    ]
    return items.map { label, icon, val in
        let raw = val ?? 2.5
        let value = (raw - 1.0) / 9.0
        return RadarSkill(label: label, icon: icon, raw: raw, value: value, categoryColor: radarCategoryColors[label] ?? NETRTheme.neonGreen)
    }
}

func buildRadarSkills(from categoryScores: [String: Double]) -> [RadarSkill] {
    let order: [(key: String, label: String, icon: String)] = [
        ("scoring", "Shooting", "crosshair"),
        ("finishing", "Finishing", "flame"),
        ("handles", "Handles", "hand"),
        ("playmaking", "Playmaking", "zap"),
        ("defense", "Defense", "shield"),
        ("rebounding", "Rebounding", "arrow-up-circle"),
        ("iq", "IQ", "brain"),
    ]
    return order.map { item in
        let raw = categoryScores[item.key] ?? 2.5
        let value = (raw - 1.0) / 9.0
        return RadarSkill(label: item.label, icon: item.icon, raw: raw, value: value, categoryColor: radarCategoryColors[item.label] ?? NETRTheme.neonGreen)
    }
}

// MARK: - Archetypes (powered by ArchetypeEngine)

/// Archetype badge that uses the new ArchetypeEngine.
/// Prefers the persisted archetype_name from the profile; falls back to computing from skill scores.
struct ArchetypeBadge: View {
    var archetypeName: String? = nil
    var archetypeKey: String? = nil
    var skills: [RadarSkill] = []

    var body: some View {
        if let name = displayName {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(NETRTheme.neonGreen.opacity(0.12))
                        .frame(width: 38, height: 38)
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1)
                        .frame(width: 38, height: 38)
                    LucideIcon("zap", size: 18)
                        .foregroundStyle(NETRTheme.neonGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("ARCHETYPE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                        .tracking(1.5)
                    Text(name)
                        .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                        .foregroundStyle(NETRTheme.neonGreen)
                }
                Spacer()
                if let key = displayKey {
                    Text(key.replacingOccurrences(of: "_", with: " · ").uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(NETRTheme.neonGreen.opacity(0.85))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(NETRTheme.neonGreen.opacity(0.12), in: .capsule)
                        .overlay(Capsule().stroke(NETRTheme.neonGreen.opacity(0.28), lineWidth: 1))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NETRTheme.surface, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1))
        }
    }

    private var displayName: String? {
        if let name = archetypeName, !name.isEmpty { return name }
        return computedResult?.name
    }

    private var displayKey: String? {
        if let key = archetypeKey, !key.isEmpty { return key }
        return computedResult?.key
    }

    private var computedResult: ArchetypeEngine.Result? {
        guard !skills.isEmpty else { return nil }
        var scores: [String: Double] = [:]
        for skill in skills where skill.raw > 0 {
            let key: String
            switch skill.label {
            case "SHT": key = "shooting"
            case "FIN": key = "finishing"
            case "HND": key = "handles"
            case "PLY": key = "playmaking"
            case "DEF": key = "defense"
            case "REB": key = "rebounding"
            case "IQ":  key = "iq"
            default: continue
            }
            scores[key] = skill.raw
        }
        return ArchetypeEngine.computeArchetype(categoryScores: scores)
    }
}
