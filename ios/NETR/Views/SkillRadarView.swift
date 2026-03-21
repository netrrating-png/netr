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

    @State private var progress: Double = 0
    @State private var labelOpacity: Double = 0

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
                Canvas { context, _ in
                    let center = CGPoint(x: cx, y: cy)

                    // Grid rings — match SA style
                    for li in 1...levels {
                        let frac = CGFloat(li) / CGFloat(levels)
                        let isOuter = li == levels
                        let ringPoints = polygonPoints(radius: maxR * frac)
                        var ringPath = Path()
                        ringPath.addLines(ringPoints)
                        ringPath.closeSubpath()
                        context.stroke(ringPath, with: .color(isOuter ? ringOuter : ringDim), lineWidth: isOuter ? 1.2 : 0.7)
                    }

                    // Spokes — match SA style
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

                    // Data points
                    let skillPoints = skills.enumerated().map { i, s in
                        let raw = CGFloat(s.value) * CGFloat(progress)
                        return polygonPoint(index: i, radius: maxR * raw)
                    }

                    // Data fill — tier color, very low opacity (matching SA 0.07)
                    var fillPath = Path()
                    fillPath.addLines(skillPoints)
                    fillPath.closeSubpath()
                    context.fill(fillPath, with: .color(tierColor.opacity(0.07)))

                    // Data stroke — tier color at 0.8 opacity, 1.8 lineWidth (matching SA)
                    var strokePath = Path()
                    strokePath.addLines(skillPoints)
                    strokePath.closeSubpath()
                    context.stroke(strokePath, with: .color(tierColor.opacity(0.8)), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))

                    // Spoke lines from center to data point — faint tier color (matching SA 0.15)
                    for pt in skillPoints {
                        var spokeLine = Path()
                        spokeLine.move(to: center)
                        spokeLine.addLine(to: pt)
                        context.stroke(spokeLine, with: .color(tierColor.opacity(0.15)), lineWidth: 1)
                    }

                    // Dots — 3-layer matching SA: glow halo, outer dot, inner dark fill
                    for pt in skillPoints {
                        // Glow halo — tier color
                        let halo = Path(ellipseIn: CGRect(x: pt.x - 7, y: pt.y - 7, width: 14, height: 14))
                        context.fill(halo, with: .color(tierColor.opacity(0.12 * progress)))
                        // Outer dot — tier color solid
                        let outer = Path(ellipseIn: CGRect(x: pt.x - 4.5, y: pt.y - 4.5, width: 9, height: 9))
                        context.fill(outer, with: .color(tierColor.opacity(progress)))
                        // Inner fill — dark background
                        let inner = Path(ellipseIn: CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4))
                        context.fill(inner, with: .color(darkBg.opacity(progress)))
                    }
                }
                .frame(width: size, height: size)

                // Axis labels — per-category color (matching SA)
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
                    .opacity(labelOpacity)
                    .position(x: pt.x, y: pt.y)
                }
            }
            .frame(width: size, height: size)

            legendGrid

            insightsSection
        }
        .onAppear {
            if animated {
                withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
                    progress = 1
                }
                withAnimation(.easeIn(duration: 0.5).delay(0.9)) {
                    labelOpacity = 1
                }
            } else {
                progress = 1
                labelOpacity = 1
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

// MARK: - Archetypes

private let singleArchetypes: [String: [String]] = [
    "Shooting":   ["Durant Jr.", "Kobe's Echo", "The Microwave"],
    "Finishing":  ["Shaq's Heir", "The Lob Son", "Mutombo's Revenge"],
    "Handles":    ["Kyrie's Shadow", "Iverson's Ghost"],
    "Playmaking": ["Magic's Apprentice", "Young CP3"],
    "Defense":    ["Kawhi's Clone", "Draymond's Disciple"],
    "Rebounding": ["Young Worm", "Moses' Mentee"],
    "IQ":         ["LeBron's Blueprint", "Jokic's Cousin"],
]

private let dualArchetypes: [String: [String]] = [
    "Finishing|Shooting":    ["Kobe-Shaq Remix"],
    "Handles|Shooting":      ["Kyrie-Kobe Hybrid", "Iverson's Last Wish"],
    "IQ|Shooting":           ["LeBron's Understudy", "Dirk's Protégé"],
    "Defense|Shooting":      ["Jimmy's Twin"],
    "Finishing|Rebounding":  ["Shaq-Worm Combo"],
    "Defense|Finishing":     ["Giannis' Little Bro"],
    "Handles|Playmaking":    ["CP3's Protégé"],
    "Defense|Handles":       ["Payton's Heir"],
    "Playmaking|Rebounding": ["LeBron's Outlet"],
    "IQ|Playmaking":         ["Magic & Jokic's Kid"],
    "Defense|Rebounding":    ["Draymond-Worm"],
    "Defense|IQ":            ["Kawhi's Apprentice"],
    "IQ|Rebounding":         ["Jokic With a Grudge"],
]

struct ArchetypeResult {
    let name: String
    let color: Color
    let subtitle: String
    let icon: String
}

func computeArchetype(from skills: [RadarSkill]) -> ArchetypeResult? {
    let sorted = skills.filter { $0.raw > 2.5 }.sorted { $0.raw > $1.raw }
    guard let top = sorted.first else { return nil }

    let topRounded = (top.raw * 10).rounded() / 10

    if sorted.count >= 2 {
        let second = sorted[1]
        let secondRounded = (second.raw * 10).rounded() / 10
        if secondRounded == topRounded {
            let pairKey = [top.label, second.label].sorted().joined(separator: "|")
            if let options = dualArchetypes[pairKey], !options.isEmpty {
                let idx = abs(Int((top.raw + second.raw) * 50)) % options.count
                let subtitle = "\(top.label) · \(second.label)"
                return ArchetypeResult(name: options[idx], color: top.categoryColor, subtitle: subtitle, icon: top.icon)
            }
        }
    }

    if let options = singleArchetypes[top.label], !options.isEmpty {
        let idx = abs(Int(top.raw * 100)) % options.count
        return ArchetypeResult(name: options[idx], color: top.categoryColor, subtitle: top.label, icon: top.icon)
    }

    return nil
}

struct ArchetypeBadge: View {
    let skills: [RadarSkill]

    var body: some View {
        if let result = computeArchetype(from: skills) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(result.color.opacity(0.12))
                        .frame(width: 38, height: 38)
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(result.color.opacity(0.3), lineWidth: 1)
                        .frame(width: 38, height: 38)
                    LucideIcon(result.icon, size: 18)
                        .foregroundStyle(result.color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("ARCHETYPE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                        .tracking(1.5)
                    Text(result.name)
                        .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                        .foregroundStyle(result.color)
                }
                Spacer()
                Text(result.subtitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(result.color.opacity(0.85))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(result.color.opacity(0.12), in: .capsule)
                    .overlay(Capsule().stroke(result.color.opacity(0.28), lineWidth: 1))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NETRTheme.surface, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(result.color.opacity(0.3), lineWidth: 1))
        }
    }
}
