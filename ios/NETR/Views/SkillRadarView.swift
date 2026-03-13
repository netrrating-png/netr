import SwiftUI

nonisolated struct RadarSkill: Sendable {
    let label: String
    let icon: String
    let isEmoji: Bool
    let raw: Double
    let value: Double

    init(label: String, icon: String, raw: Double, value: Double) {
        let emojiCheck = icon.unicodeScalars.contains { $0.properties.isEmoji && !$0.isASCII }
        self.label = label
        self.icon = icon
        self.isEmoji = emojiCheck
        self.raw = raw
        self.value = value
    }
}

struct SkillRadarView: View {
    let skills: [RadarSkill]
    let animated: Bool
    let size: CGFloat

    init(skills: [RadarSkill], size: CGFloat = 260, animated: Bool = true) {
        self.skills = skills
        self.size = size
        self.animated = animated
    }

    @State private var progress: Double = 0
    @State private var labelOpacity: Double = 0

    private let levels = 5
    private var n: Int { skills.count }
    private var cx: CGFloat { size / 2 }
    private var cy: CGFloat { size / 2 }
    private var maxR: CGFloat { size / 2 * 0.62 }
    private var labelR: CGFloat { size / 2 * 0.90 }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Canvas { context, _ in
                    let center = CGPoint(x: cx, y: cy)

                    for li in 0..<levels {
                        let frac = CGFloat(li + 1) / CGFloat(levels)
                        let isOuter = li == levels - 1
                        let ringPoints = polygonPoints(radius: maxR * frac)
                        var ringPath = Path()
                        ringPath.addLines(ringPoints)
                        ringPath.closeSubpath()

                        if isOuter {
                            context.fill(ringPath, with: .color(NETRTheme.neonGreen.opacity(0.07)))
                            context.stroke(ringPath, with: .color(NETRTheme.neonGreen.opacity(0.19)), lineWidth: 1)
                        } else {
                            context.stroke(ringPath, with: .color(NETRTheme.muted.opacity(0.5)), lineWidth: 0.5)
                        }
                    }

                    let outerPoints = polygonPoints(radius: maxR)
                    for pt in outerPoints {
                        var spoke = Path()
                        spoke.move(to: center)
                        spoke.addLine(to: pt)
                        context.stroke(spoke, with: .color(NETRTheme.muted.opacity(0.5)), lineWidth: 0.5)
                    }

                    let visualFloor: CGFloat = 0.28
                    let skillPoints = skills.enumerated().map { i, s in
                        let raw = CGFloat(s.value) * CGFloat(progress)
                        let mapped = visualFloor + (1.0 - visualFloor) * raw
                        return polygonPoint(index: i, radius: maxR * mapped)
                    }

                    var glowPath = Path()
                    glowPath.addLines(skillPoints)
                    glowPath.closeSubpath()

                    context.fill(glowPath, with: .color(NETRTheme.neonGreen.opacity(0.15)))
                    context.stroke(glowPath, with: .color(NETRTheme.neonGreen.opacity(0.4)), style: StrokeStyle(lineWidth: 6, lineJoin: .round))

                    var crispPath = Path()
                    crispPath.addLines(skillPoints)
                    crispPath.closeSubpath()
                    context.fill(crispPath, with: .color(NETRTheme.neonGreen.opacity(0.12)))
                    context.stroke(crispPath, with: .color(NETRTheme.neonGreen), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                    for (i, _) in skills.enumerated() {
                        let raw = CGFloat(skills[i].value) * CGFloat(progress)
                        let mapped = visualFloor + (1.0 - visualFloor) * raw
                        let pt = polygonPoint(index: i, radius: maxR * mapped)
                        let dotPath = Path(ellipseIn: CGRect(x: pt.x - 5, y: pt.y - 5, width: 10, height: 10))
                        context.fill(dotPath, with: .color(NETRTheme.neonGreen.opacity(progress)))
                        let innerDot = Path(ellipseIn: CGRect(x: pt.x - 2.5, y: pt.y - 2.5, width: 5, height: 5))
                        context.fill(innerDot, with: .color(.white.opacity(progress * 0.9)))
                    }
                }
                .frame(width: size, height: size)

                ForEach(Array(skills.enumerated()), id: \.offset) { i, skill in
                    let pt = polygonPoint(index: i, radius: labelR)
                    let color = skillColor(skill.value)
                    VStack(spacing: 2) {
                        if skill.isEmoji {
                            Text(skill.icon)
                                .font(.system(size: 13))
                        } else {
                            LucideIcon(skill.icon, size: 12)
                                .foregroundStyle(color)
                        }
                        Text(skill.label.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .default).width(.compressed))
                            .tracking(0.8)
                            .foregroundStyle(color)
                        Text(String(format: "%.1f", skill.raw))
                            .font(.system(size: 11, weight: .bold, design: .default).width(.compressed))
                            .foregroundStyle(color)
                    }
                    .opacity(labelOpacity)
                    .position(x: pt.x, y: pt.y)
                }
            }
            .frame(width: size, height: size)

            legendRow

            insightsSection

            skillPills
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

    private var legendRow: some View {
        HStack(spacing: 12) {
            LegendDot(color: NETRTheme.neonGreen, label: "Strong")
            LegendDot(color: NETRTheme.blue, label: "Solid")
            LegendDot(color: NETRTheme.gold, label: "Developing")
            LegendDot(color: NETRTheme.red, label: "Focus area")
        }
    }

    private var insightsSection: some View {
        let strengths = skills.filter { $0.value >= 0.70 }.sorted { $0.value > $1.value }
        let weaknesses = skills.filter { $0.value < 0.45 }.sorted { $0.value < $1.value }

        return Group {
            if !strengths.isEmpty || !weaknesses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !strengths.isEmpty {
                        InsightRow(
                            icon: "zap",
                            color: NETRTheme.neonGreen,
                            label: "Strengths",
                            items: Array(strengths.prefix(2).map(\.label))
                        )
                    }
                    if !weaknesses.isEmpty {
                        InsightRow(
                            icon: "target",
                            color: NETRTheme.gold,
                            label: "Work on",
                            items: Array(weaknesses.prefix(2).map(\.label))
                        )
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NETRTheme.surface, in: .rect(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
            }
        }
    }

    private var skillPills: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(skills.count, 4))
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(skills.enumerated()), id: \.offset) { _, skill in
                let color = skillColor(skill.value)
                VStack(spacing: 2) {
                    if skill.isEmoji {
                        Text(skill.icon)
                            .font(.system(size: 14))
                    } else {
                        LucideIcon(skill.icon, size: 14)
                            .foregroundStyle(color)
                    }
                    Text(String(format: "%.1f", skill.raw))
                        .font(.system(size: 16, weight: .black, design: .default).width(.compressed))
                        .foregroundStyle(color)
                    Text(skill.label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.07), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.2), lineWidth: 1))
            }
        }
    }

    private func polygonPoint(index: Int, radius: CGFloat) -> CGPoint {
        let angle = (2 * .pi * CGFloat(index) / CGFloat(n)) - (.pi / 2)
        return CGPoint(x: cx + radius * cos(angle), y: cy + radius * sin(angle))
    }

    private func polygonPoints(radius: CGFloat) -> [CGPoint] {
        (0..<n).map { polygonPoint(index: $0, radius: radius) }
    }

    private func skillColor(_ value: Double) -> Color {
        if value >= 0.75 { return NETRTheme.neonGreen }
        if value >= 0.50 { return NETRTheme.blue }
        if value >= 0.30 { return NETRTheme.gold }
        return NETRTheme.red
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
        ("🎯", "7 Core Skill Areas", "Your answers across Scoring, Finishing, Handles, Passing, Defense, Rebounding, and Basketball IQ are each weighted based on how much they reflect overall player value.", false),
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

func buildRadarSkills(from skillRatings: SkillRatings) -> [RadarSkill] {
    let items: [(String, String, Double?)] = [
        ("Scoring", "crosshair", skillRatings.shooting),
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
        return RadarSkill(label: label, icon: icon, raw: raw, value: value)
    }
}

func buildRadarSkills(from categoryScores: [String: Double]) -> [RadarSkill] {
    let order: [(key: String, label: String, icon: String)] = [
        ("scoring", "Scoring", "crosshair"),
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
        return RadarSkill(label: item.label, icon: item.icon, raw: raw, value: value)
    }
}
