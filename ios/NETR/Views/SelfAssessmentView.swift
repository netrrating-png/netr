import SwiftUI

struct SelfAssessmentView: View {
    let position: PlayerPosition
    var onComplete: (Double, Gender, AgeBracket, [String: Double]) -> Void
    var onBack: (() -> Void)? = nil

    @State private var phase: SAPhase = .gender
    @State private var selectedGender: Gender? = nil
    @State private var selectedAgeBracket: AgeBracket? = nil
    @State private var currentQIndex: Int = 0
    @State private var answers: [Int: Int] = [:]
    @State private var selectedOption: Int? = nil
    @State private var finalScore: Double = 0
    @State private var categoryScores: [String: Double] = [:]
    @State private var showScoreInfo: Bool = false

    private enum SAPhase: Equatable {
        case gender, age, questions, result
    }

    private let questions = SAQuestionBank.all
    private var currentQ: SAQuestion { questions[currentQIndex] }
    private var isLastQ: Bool { currentQIndex == questions.count - 1 }

    private var progress: Double {
        Double(currentQIndex) / Double(questions.count)
    }

    private let categoryDisplayNames: [String: String] = [
        "scoring": "Scoring", "iq": "IQ", "defense": "Defense",
        "handles": "Handles", "playmaking": "Playmaking",
        "finishing": "Finishing", "rebounding": "Rebounding",
    ]

    private let categoryIcons: [String: String] = [
        "scoring": "scope", "iq": "brain", "defense": "shield.fill",
        "handles": "hand.raised.fill", "playmaking": "bolt.fill",
        "finishing": "flame.fill", "rebounding": "arrow.up.circle",
    ]

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            switch phase {
            case .gender:
                genderPhase
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .age:
                agePhase
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .questions:
                questionsPhase
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .result:
                resultPhase
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.3), value: phase)
    }

    // MARK: - Gender Phase

    private var genderPhase: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: { onBack?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(NETRTheme.subtext)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("ONE QUICK THING")
                            .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                            .tracking(2)
                            .foregroundStyle(NETRTheme.subtext)

                        Text("What's your gender?")
                            .font(.system(.title, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NETRTheme.text)

                        Text("Used only for context. Won't affect your score.")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    VStack(spacing: 12) {
                        ForEach(Gender.allCases, id: \.self) { g in
                            SASelectionRow(
                                label: g.rawValue,
                                isSelected: selectedGender == g
                            ) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedGender = g
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation { phase = .age }
                    } label: {
                        Text("NEXT")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(selectedGender != nil ? NETRTheme.background : NETRTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedGender != nil ? NETRTheme.neonGreen : NETRTheme.muted,
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selectedGender == nil)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedGender)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Age Phase

    private var agePhase: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation { phase = .gender }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(NETRTheme.subtext)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("How old are you?")
                            .font(.system(.title, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NETRTheme.text)

                        Text("Helps calibrate your score fairly across age groups.")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(AgeBracket.allCases) { bracket in
                            AgeBracketCard(
                                label: bracket.rawValue,
                                sublabel: bracket.sublabel,
                                isSelected: selectedAgeBracket == bracket
                            ) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedAgeBracket = bracket
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation { phase = .questions }
                    } label: {
                        Text("START ASSESSMENT")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(selectedAgeBracket != nil ? NETRTheme.background : NETRTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedAgeBracket != nil ? NETRTheme.neonGreen : NETRTheme.muted,
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selectedAgeBracket == nil)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedAgeBracket)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Questions Phase

    private var questionsPhase: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: handleBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        if currentQIndex == 0 {
                            Text("Back")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(NETRTheme.subtext)
                }

                Spacer()

                Text("\(currentQIndex + 1) / \(questions.count)")
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.subtext)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(NETRTheme.muted)
                        .frame(height: 3)
                    Rectangle()
                        .fill(NETRTheme.neonGreen)
                        .frame(width: geo.size.width * progress, height: 3)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 3)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer().frame(height: 8)

                    HStack(spacing: 8) {
                        if let icon = categoryIcons[currentQ.category] {
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                        if let label = categoryDisplayNames[currentQ.category] {
                            Text(label.uppercased())
                                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                                .tracking(1.5)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }

                    Text(currentQ.prompt)
                        .font(.system(.title2, design: .default, weight: .black).width(.compressed))
                        .foregroundStyle(NETRTheme.text)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        ForEach(currentQ.options.indices, id: \.self) { i in
                            AssessmentOptionRow(
                                emoji: currentQ.options[i].emoji,
                                label: currentQ.options[i].label,
                                detail: currentQ.options[i].detail,
                                isSelected: selectedOption == i
                            ) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedOption = i
                                }
                            }
                        }
                    }

                    Button(action: handleNext) {
                        Text(isLastQ ? "SEE MY SCORE" : "NEXT")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(selectedOption != nil ? NETRTheme.background : NETRTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedOption != nil ? NETRTheme.neonGreen : NETRTheme.muted,
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selectedOption == nil)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: currentQIndex)
                    .padding(.top, 8)

                    Button(action: handleSkip) {
                        Text("Skip this question")
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.subtext)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Result Phase

    private var resultPhase: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 16)

                    Text("YOUR STARTING ESTIMATE")
                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                        .tracking(3)
                        .foregroundStyle(NETRTheme.subtext)

                    Text(String(format: "%.1f", finalScore))
                        .font(.system(size: 72, weight: .black, design: .default).width(.compressed))
                        .foregroundStyle(SAScorer.tierColor(finalScore))
                        .shadow(color: SAScorer.tierColor(finalScore).opacity(0.5), radius: 30)

                    Text(SAScorer.tierLabel(finalScore).uppercased())
                        .font(.system(.title3, design: .default, weight: .heavy).width(.compressed))
                        .foregroundStyle(SAScorer.tierColor(finalScore))

                    HStack(spacing: 10) {
                        if let g = selectedGender {
                            infoPill(text: g.rawValue)
                        }
                        if let a = selectedAgeBracket {
                            infoPill(text: a.rawValue)
                        }
                        infoPill(text: position.shortLabel)
                    }

                    VStack(spacing: 16) {
                        HStack {
                            Text("SKILL BREAKDOWN")
                                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                                .tracking(1.8)
                                .foregroundStyle(NETRTheme.subtext)
                            Spacer()
                            Button { showScoreInfo = true } label: {
                                ScoreInfoButton()
                            }
                        }

                        SkillRadarView(skills: buildRadarSkills(), size: 260, animated: true)
                    }
                    .padding(20)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(NETRTheme.border, lineWidth: 1))
                    .padding(.horizontal, 20)
                    .sheet(isPresented: $showScoreInfo) {
                        ScoreInfoSheet()
                    }

                    VStack(spacing: 8) {
                        Text("This is your provisional starting point.")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                            .multilineTextAlignment(.center)
                        Text("Peer ratings will move this up or down.")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)

                    Spacer(minLength: 100)
                }
            }
            .scrollIndicators(.hidden)

            Button {
                onComplete(
                    finalScore,
                    selectedGender ?? .preferNotToAnswer,
                    selectedAgeBracket ?? .adult,
                    categoryScores
                )
            } label: {
                Text("ENTER THE COURT")
                    .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                    .tracking(2)
                    .foregroundStyle(NETRTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                    .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 16)
            }
            .buttonStyle(PressButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Actions

    private func handleBack() {
        if currentQIndex > 0 {
            withAnimation(.snappy(duration: 0.25)) {
                currentQIndex -= 1
                selectedOption = answers[questions[currentQIndex].id]
            }
        } else {
            withAnimation { phase = .age }
        }
    }

    private func handleNext() {
        guard let opt = selectedOption else { return }
        answers[currentQ.id] = opt
        advanceOrFinish()
    }

    private func handleSkip() {
        advanceOrFinish()
    }

    private func advanceOrFinish() {
        if isLastQ {
            let ageBracket = selectedAgeBracket ?? .adult
            let score = SAScorer.calculate(
                answers: answers,
                gender: selectedGender ?? .preferNotToAnswer,
                ageBracket: ageBracket,
                position: position
            )
            let cats = SAScorer.calculateCategoryScores(
                answers: answers,
                ageBracket: ageBracket,
                position: position
            )
            finalScore = score
            categoryScores = cats
            withAnimation(.snappy) { phase = .result }
        } else {
            withAnimation(.snappy(duration: 0.25)) {
                currentQIndex += 1
                selectedOption = answers[questions[currentQIndex].id]
            }
        }
    }

    // MARK: - Helpers

    private func infoPill(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(NETRTheme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(NETRTheme.card, in: .capsule)
            .overlay(Capsule().strokeBorder(NETRTheme.border, lineWidth: 1))
    }

    private func buildRadarSkills() -> [RadarSkill] {
        let order = ["scoring", "finishing", "handles", "playmaking", "defense", "rebounding", "iq"]
        return order.map { cat in
            let raw = categoryScores[cat] ?? 1.0
            let label = categoryDisplayNames[cat] ?? cat
            let icon = categoryIcons[cat] ?? "questionmark"
            let value = (raw - 1.0) / 9.0
            return RadarSkill(label: label, icon: icon, raw: raw, value: value)
        }
    }
}

// MARK: - Sub-components

struct SASelectionRow: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? NETRTheme.neonGreen : NETRTheme.border,
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(NETRTheme.neonGreen)
                            .frame(width: 11, height: 11)
                    }
                }

                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? NETRTheme.text : NETRTheme.text.opacity(0.85))

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                isSelected ? NETRTheme.neonGreen.opacity(0.08) : NETRTheme.card,
                in: .rect(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? NETRTheme.neonGreen : NETRTheme.border,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(PressButtonStyle())
    }
}

struct AgeBracketCard: View {
    let label: String
    let sublabel: String
    let isSelected: Bool
    let onTap: () -> Void

    init(label: String, sublabel: String = "", isSelected: Bool, onTap: @escaping () -> Void) {
        self.label = label
        self.sublabel = sublabel
        self.isSelected = isSelected
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(isSelected ? NETRTheme.neonGreen : NETRTheme.text)
                if !sublabel.isEmpty {
                    Text(sublabel)
                        .font(.system(size: 10))
                        .foregroundStyle(NETRTheme.subtext)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                isSelected ? NETRTheme.neonGreen.opacity(0.08) : NETRTheme.card,
                in: .rect(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? NETRTheme.neonGreen : NETRTheme.border,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PressButtonStyle())
    }
}

struct AssessmentOptionRow: View {
    let emoji: String
    let label: String
    let detail: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(emoji)
                    .font(.system(size: 20))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? NETRTheme.text : NETRTheme.text.opacity(0.85))
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                ZStack {
                    Circle()
                        .strokeBorder(
                            isSelected ? NETRTheme.neonGreen : NETRTheme.border,
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(NETRTheme.neonGreen)
                            .frame(width: 11, height: 11)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                isSelected ? NETRTheme.neonGreen.opacity(0.08) : NETRTheme.card,
                in: .rect(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? NETRTheme.neonGreen : NETRTheme.border,
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(PressButtonStyle())
    }
}
