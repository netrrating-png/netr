// ── NETR Skill Radar Chart — SwiftUI component for Rork ──────────────────────
// A 7-sided radar/spider chart that visualizes skill breakdown on the result screen.
// Categories: Scoring, Finishing, Handles, Passing, Defense, Rebounding, IQ
//
// HOW TO USE:
// 1. Add SkillRadarView to your result phase in SelfAssessmentView
// 2. Pass in the answers dictionary from the assessment
// 3. The chart auto-extracts per-category scores and animates in
//
// INTEGRATION — in resultView, add above the score pills:
//
//   SkillRadarView(answers: answers)
//       .frame(width: 300, height: 300)
//       .padding(.vertical, 8)

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// ── DATA
// ─────────────────────────────────────────────────────────────────────────────

struct RadarSkill: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
    let value: Double   // 0.0–1.0 (normalized)
    let rawScore: Double // 1–5 from answers
}

// Maps assessment answers → radar values
// Only the 7 core skill categories are shown (not level/frequency/perception)
func buildRadarSkills(from answers: [Int: Int]) -> [RadarSkill] {
    // question id → category label, icon, answer index → score mapping
    let skillQuestions: [(id: Int, label: String, icon: String)] = [
        (1,  "Scoring",    "🎯"),
        (2,  "Finishing",  "🤙"),
        (3,  "Handles",    "⚡"),
        (4,  "Passing",    "🔑"),
        (5,  "Defense",    "🛡"),
        (6,  "Boards",     "💪"),
        (7,  "IQ",         "🧠"),
    ]

    let allScores: [[Double]] = [
        [5.0, 4.0, 3.0, 2.0, 2.5],  // Q1 scoring
        [5.0, 3.5, 2.5, 1.5, 1.0],  // Q2 finishing
        [5.0, 4.0, 2.5, 1.5, 2.0],  // Q3 handles
        [5.0, 3.5, 2.5, 2.0, 2.5],  // Q4 passing
        [5.0, 4.0, 3.0, 2.0, 1.0],  // Q5 defense
        [5.0, 3.5, 2.5, 1.5, 1.0],  // Q6 rebounding
        [5.0, 3.5, 2.5, 1.5, 1.0],  // Q7 iq
    ]

    return skillQuestions.enumerated().map { (idx, skill) in
        let answerIndex = answers[skill.id]
        let raw: Double
        if let ai = answerIndex, ai < allScores[idx].count {
            raw = allScores[idx][ai]
        } else {
            raw = 2.5 // default if skipped
        }
        let normalized = (raw - 1.0) / 4.0   // normalize 1–5 to 0–1
        return RadarSkill(label: skill.label, icon: skill.icon, value: normalized, rawScore: raw)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── RADAR CHART VIEW
// ─────────────────────────────────────────────────────────────────────────────

struct SkillRadarView: View {
    let answers: [Int: Int]

    @State private var animationProgress: Double = 0.0
    @State private var labelOpacity: Double = 0.0

    var skills: [RadarSkill] { buildRadarSkills(from: answers) }
    let levels = 5   // number of concentric rings
    let accentColor = Color(hex: "39FF14")

    var body: some View {
        ZStack {
            // Background grid rings
            ForEach(1...levels, id: \.self) { level in
                RadarRing(
                    sides: skills.count,
                    fraction: Double(level) / Double(levels),
                    color: level == levels
                        ? Color(hex: "39FF14").opacity(0.12)
                        : Color(hex: "2E2E3A").opacity(0.5),
                    lineWidth: level == levels ? 1.0 : 0.5
                )
            }

            // Spoke lines from center to each vertex
            RadarSpokes(sides: skills.count, color: Color(hex: "2E2E3A").opacity(0.8))

            // Filled skill polygon (animated)
            RadarFilledPolygon(
                values: skills.map { $0.value },
                progress: animationProgress,
                fillColor: Color(hex: "39FF14").opacity(0.18),
                strokeColor: Color(hex: "39FF14"),
                glowColor: Color(hex: "39FF14").opacity(0.5)
            )

            // Vertex dots
            RadarDots(
                values: skills.map { $0.value },
                progress: animationProgress,
                color: Color(hex: "39FF14")
            )

            // Labels
            RadarLabels(skills: skills, opacity: labelOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
                animationProgress = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.85)) {
                labelOpacity = 1.0
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── GEOMETRY HELPERS
// ─────────────────────────────────────────────────────────────────────────────

// Returns the point for a vertex on a regular polygon
// angle 0 = top (12 o'clock), going clockwise
func polygonPoint(center: CGPoint, radius: CGFloat, sides: Int, index: Int) -> CGPoint {
    let angle = (2.0 * .pi * Double(index) / Double(sides)) - (.pi / 2.0)
    return CGPoint(
        x: center.x + radius * CGFloat(cos(angle)),
        y: center.y + radius * CGFloat(sin(angle))
    )
}

// ─────────────────────────────────────────────────────────────────────────────
// ── SUB-SHAPES
// ─────────────────────────────────────────────────────────────────────────────

// One concentric ring
struct RadarRing: View {
    let sides: Int
    let fraction: Double
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 * 0.72 * CGFloat(fraction)

            Path { path in
                for i in 0..<sides {
                    let pt = polygonPoint(center: center, radius: radius, sides: sides, index: i)
                    if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                }
                path.closeSubpath()
            }
            .stroke(color, lineWidth: lineWidth)
        }
    }
}

// Spoke lines center → each vertex
struct RadarSpokes: View {
    let sides: Int
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 * 0.72

            Path { path in
                for i in 0..<sides {
                    let pt = polygonPoint(center: center, radius: radius, sides: sides, index: i)
                    path.move(to: center)
                    path.addLine(to: pt)
                }
            }
            .stroke(color, lineWidth: 0.5)
        }
    }
}

// Filled + stroked skill polygon
struct RadarFilledPolygon: View {
    let values: [Double]
    let progress: Double
    let fillColor: Color
    let strokeColor: Color
    let glowColor: Color

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 * 0.72
            let sides = values.count

            // Visual floor: lowest skill always shows at 28% of max radius
            // Shape stays a real polygon even for low scores — numbers show truth
            let visualFloor: CGFloat = 0.28
            let path = Path { p in
                for i in 0..<sides {
                    let raw = CGFloat(values[i]) * CGFloat(progress)
                    let mapped = visualFloor + (1.0 - visualFloor) * raw
                    let radius = maxRadius * mapped
                    let pt = polygonPoint(center: center, radius: radius, sides: sides, index: i)
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
                p.closeSubpath()
            }

            path.fill(fillColor)

            // Glow stroke (wide, dim)
            path.stroke(glowColor, lineWidth: 4)

            // Crisp stroke (narrow, bright)
            path.stroke(strokeColor, lineWidth: 1.5)
        }
    }
}

// Dots at each skill vertex
struct RadarDots: View {
    let values: [Double]
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 * 0.72
            let sides = values.count

            let visualFloor: CGFloat = 0.28
            ForEach(0..<sides, id: \.self) { i in
                let raw = CGFloat(values[i]) * CGFloat(progress)
                let mapped = visualFloor + (1.0 - visualFloor) * raw
                let radius = maxRadius * mapped
                let pt = polygonPoint(center: center, radius: radius, sides: sides, index: i)

                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .shadow(color: color, radius: 5)
                    .position(pt)
                    .opacity(progress)
            }
        }
    }
}

// Labels outside each vertex
struct RadarLabels: View {
    let skills: [RadarSkill]
    let opacity: Double

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            // Labels sit slightly beyond the outermost ring
            let labelRadius = min(geo.size.width, geo.size.height) / 2 * 0.95
            let sides = skills.count

            ForEach(0..<sides, id: \.self) { i in
                let pt = polygonPoint(center: center, radius: labelRadius, sides: sides, index: i)
                let skill = skills[i]

                // Color per value
                let c = skillColor(value: skill.value)

                VStack(spacing: 2) {
                    Text(skill.icon)
                        .font(.system(size: 13))
                    Text(skill.label)
                        .font(.custom("BarlowCondensed-Black", size: 11))
                        .foregroundColor(c)
                        .kerning(0.4)
                        .textCase(.uppercase)
                    // Score out of 5
                    Text(String(format: "%.1f", skill.rawScore))
                        .font(.custom("BarlowCondensed-Black", size: 12))
                        .foregroundColor(c)
                }
                .frame(width: 58)
                .multilineTextAlignment(.center)
                .opacity(opacity)
                .position(pt)
            }
        }
    }

    func skillColor(value: Double) -> Color {
        if value >= 0.75 { return Color(hex: "39FF14") }
        if value >= 0.50 { return Color(hex: "4A9EFF") }
        if value >= 0.30 { return Color(hex: "F5C542") }
        return Color(hex: "FF4545")
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── FULL RESULT CARD (drop this into resultView)
// ─────────────────────────────────────────────────────────────────────────────
// This wraps the radar + a legend + a brief strengths/weakness line.
// Replaces the plain score display in the result phase.

struct SkillRadarCard: View {
    let answers: [Int: Int]
    let finalScore: Double

    var skills: [RadarSkill] { buildRadarSkills(from: answers) }

    var strengths: [RadarSkill] {
        skills.filter { $0.value >= 0.7 }.sorted { $0.value > $1.value }
    }
    var weaknesses: [RadarSkill] {
        skills.filter { $0.value < 0.45 }.sorted { $0.value < $1.value }
    }

    var body: some View {
        VStack(spacing: 20) {

            // Title
            Text("SKILL BREAKDOWN")
                .font(.custom("DMSans-Medium", size: 11))
                .foregroundColor(Color(hex: "6A6A82"))
                .kerning(1.8)

            // Radar chart
            SkillRadarView(answers: answers)
                .frame(width: 300, height: 300)

            // Legend pills
            HStack(spacing: 8) {
                LegendDot(color: Color(hex: "39FF14"), label: "Strong")
                LegendDot(color: Color(hex: "4A9EFF"), label: "Solid")
                LegendDot(color: Color(hex: "F5C542"), label: "Developing")
                LegendDot(color: Color(hex: "FF4545"), label: "Focus area")
            }

            // Strengths & weaknesses callout
            if !strengths.isEmpty || !weaknesses.isEmpty {
                VStack(spacing: 10) {
                    if !strengths.isEmpty {
                        InsightRow(
                            icon: "⚡",
                            color: Color(hex: "39FF14"),
                            label: "Strengths",
                            text: strengths.prefix(2).map { $0.label }.joined(separator: ", ")
                        )
                    }
                    if !weaknesses.isEmpty {
                        InsightRow(
                            icon: "🎯",
                            color: Color(hex: "F5C542"),
                            label: "Work on",
                            text: weaknesses.prefix(2).map { $0.label }.joined(separator: ", ")
                        )
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "0F0F14"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color(hex: "1C1C24"), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 4)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "0A0A0D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color(hex: "1C1C24"), lineWidth: 1)
                )
        )
    }
}

struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.custom("DMSans-Regular", size: 11))
                .foregroundColor(Color(hex: "6A6A82"))
        }
    }
}

struct InsightRow: View {
    let icon: String
    let color: Color
    let label: String
    let text: String
    var body: some View {
        HStack(spacing: 10) {
            Text(icon).font(.system(size: 14))
            Text(label)
                .font(.custom("DMSans-SemiBold", size: 13))
                .foregroundColor(color)
            Text(text)
                .font(.custom("DMSans-Regular", size: 13))
                .foregroundColor(Color(hex: "EEEEF5"))
            Spacer()
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── HOW TO WIRE INTO resultView in SelfAssessmentView
// ─────────────────────────────────────────────────────────────────────────────
//
// In your resultView body, after the big score number, add:
//
//   if let score = estimatedScore {
//       // --- existing score display ---
//       Text(String(format: "%.1f", score)) ...
//       Text(netrTierLabel(for: score)) ...
//
//       // --- ADD THIS ---
//       SkillRadarCard(answers: answers, finalScore: score)
//           .padding(.horizontal, 20)
//
//       // --- existing pills & disclaimer ---
//       Text("This is your provisional starting point.") ...
//   }
//
// That's it. The chart animates in automatically.

// ─────────────────────────────────────────────────────────────────────────────
// ── COLOR EXTENSION (skip if already in project)
// ─────────────────────────────────────────────────────────────────────────────

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int = UInt64()
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:(r, g, b) = (1, 1, 1)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── INFO MODAL — How Your Score Is Calculated
// ─────────────────────────────────────────────────────────────────────────────
// Add a small ⓘ button next to "SKILL BREAKDOWN" label in SkillRadarCard.
// Tapping it presents this sheet from the bottom.
//
// WIRE IT IN — inside SkillRadarCard, replace the title line with:
//
//   HStack {
//       Text("SKILL BREAKDOWN")
//           .font(.custom("DMSans-Medium", size: 11))
//           .foregroundColor(Color(hex: "6A6A82"))
//           .kerning(1.8)
//       Spacer()
//       Button(action: { showInfo = true }) {
//           InfoIconButton()
//       }
//   }
//   .sheet(isPresented: $showInfo) { ScoreInfoSheet() }
//
// Add @State private var showInfo = false to SkillRadarCard.

struct InfoIconButton: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "6A6A82").opacity(0.12))
                .frame(width: 26, height: 26)
            Circle()
                .strokeBorder(Color(hex: "2E2E3A"), lineWidth: 1)
                .frame(width: 26, height: 26)
            // Custom "i" drawn cleanly
            VStack(spacing: 2) {
                Circle()
                    .fill(Color(hex: "6A6A82"))
                    .frame(width: 3, height: 3)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(hex: "6A6A82"))
                    .frame(width: 2.5, height: 7)
            }
        }
    }
}

struct ScoreInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    struct InfoSection {
        let icon: String
        let title: String
        let body: String
        let highlight: Bool
    }

    let sections: [InfoSection] = [
        InfoSection(
            icon: "🎯",
            title: "7 Core Skill Areas",
            body: "Your answers across Scoring, Finishing, Handles, Passing, Defense, Rebounding, and Basketball IQ are each weighted based on how much they reflect overall player value.",
            highlight: false
        ),
        InfoSection(
            icon: "⚖️",
            title: "Weighted & Calibrated",
            body: "Not all categories count equally. Answers are run through a multi-factor model that accounts for level played, age, and consistency across your responses.",
            highlight: false
        ),
        InfoSection(
            icon: "📉",
            title: "Self-Assessment Discount",
            body: "Research shows players consistently rate themselves higher than peers do. A built-in discount keeps your estimate realistic — it's not a penalty, it's calibration.",
            highlight: false
        ),
        InfoSection(
            icon: "🏀",
            title: "This Is Just the Starting Line",
            body: "Your true NETR comes from the court. Every game you play, teammates and opponents rate you — those peer ratings are what move your score up or down over time.",
            highlight: true
        ),
    ]

    var body: some View {
        ZStack {
            Color(hex: "0F0F14").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Handle bar
                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: 99)
                            .fill(Color(hex: "2E2E3A"))
                            .frame(width: 36, height: 4)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                    // Title row
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hex: "39FF14").opacity(0.12))
                                .frame(width: 38, height: 38)
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color(hex: "39FF14").opacity(0.3), lineWidth: 1)
                                .frame(width: 38, height: 38)
                            Text("ℹ️").font(.system(size: 18))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("How Your Score Is Calculated")
                                .font(.custom("BarlowCondensed-Black", size: 22))
                                .foregroundColor(.white)
                            Text("Self-Assessment Estimate")
                                .font(.custom("DMSans-Regular", size: 12))
                                .foregroundColor(Color(hex: "6A6A82"))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    // Sections
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
                                        .font(.custom("BarlowCondensed-Black", size: 17))
                                        .foregroundColor(s.highlight ? Color(hex: "39FF14") : .white)
                                    Text(s.body)
                                        .font(.custom("DMSans-Regular", size: 13))
                                        .foregroundColor(Color(hex: "6A6A82"))
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(s.highlight
                                        ? Color(hex: "39FF14").opacity(0.07)
                                        : Color.white.opacity(0.03)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .strokeBorder(
                                                s.highlight
                                                    ? Color(hex: "39FF14").opacity(0.22)
                                                    : Color(hex: "1C1C24"),
                                                lineWidth: 1
                                            )
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, 20)

                    // Got it button
                    Button(action: { dismiss() }) {
                        Text("Got it")
                            .font(.custom("DMSans-SemiBold", size: 16))
                            .foregroundColor(Color(hex: "040406"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "39FF14"), Color(hex: "00CC2A")],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(14)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .presentationDetents([.fraction(0.82)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}
