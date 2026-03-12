import SwiftUI

struct SelfAssessmentView: View {
    @Binding var estimatedScore: Double?
    @Binding var categoryScores: [String: Double]
    var onComplete: () -> Void
    var onBack: (() -> Void)? = nil

    @State private var phase: AssessmentPhase = .age
    @State private var selectedAgeGroup: AgeGroup? = nil
    @State private var selectedPlayingLevel: PlayingLevel? = nil
    @State private var selectedFrequency: PlayFrequency? = nil
    @State private var selectedPosition: PlayerPosition? = nil
    @State private var currentIndex: Int = 0
    @State private var answers: [String: Int] = [:]
    @State private var selectedAnswer: Int? = nil
    @State private var assessmentResult: AssessmentResult? = nil
    @State private var showScoreInfo: Bool = false

    private enum AssessmentPhase: Equatable {
        case age, level, frequency, position, questions, result
    }

    private let questions = AssessmentQuestionBank.all

    private var currentQuestion: AssessmentQuestion {
        questions[currentIndex]
    }

    private var progress: Double {
        Double(currentIndex) / Double(questions.count)
    }

    private var isLast: Bool {
        currentIndex == questions.count - 1
    }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            switch phase {
            case .age:
                ageView
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .level:
                levelView
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .frequency:
                frequencyView
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .position:
                positionView
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .questions:
                questionView
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            case .result:
                assessmentResultView
                    .transition(.opacity)
            }
        }
        .animation(.snappy(duration: 0.3), value: phase)
    }

    // MARK: - Age Phase

    private var ageView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: { onBack?() }) {
                    HStack(spacing: 4) {
                        LucideIcon("chevron-left", size: 14)
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
                        Text("FIRST THINGS FIRST")
                            .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                            .tracking(2)
                            .foregroundStyle(NETRTheme.subtext)

                        Text("How old are you?")
                            .font(.system(.title, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NETRTheme.text)

                        Text("Helps calibrate your score fairly across age groups.")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(AgeGroup.allCases) { bracket in
                            AgeBracketCard(
                                label: bracket.label,
                                sublabel: bracket.sublabel,
                                isSelected: selectedAgeGroup == bracket
                            ) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedAgeGroup = bracket
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation { phase = .level }
                    } label: {
                        Text("NEXT")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(selectedAgeGroup != nil ? NETRTheme.background : NETRTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedAgeGroup != nil ? NETRTheme.neonGreen : NETRTheme.muted,
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selectedAgeGroup == nil)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedAgeGroup)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Playing Level Phase

    private var levelView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation { phase = .age }
                } label: {
                    HStack(spacing: 4) {
                        LucideIcon("chevron-left", size: 14)
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
                        Text("YOUR BACKGROUND")
                            .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                            .tracking(2)
                            .foregroundStyle(NETRTheme.subtext)

                        Text("What level do you play at?")
                            .font(.system(.title, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NETRTheme.text)

                        Text("This anchors your score to a realistic range.")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    VStack(spacing: 10) {
                        ForEach(PlayingLevel.allCases) { level in
                            PlayingLevelRow(
                                level: level,
                                isSelected: selectedPlayingLevel == level
                            ) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedPlayingLevel = level
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation { phase = .frequency }
                    } label: {
                        Text("NEXT")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(selectedPlayingLevel != nil ? NETRTheme.background : NETRTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedPlayingLevel != nil ? NETRTheme.neonGreen : NETRTheme.muted,
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selectedPlayingLevel == nil)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedPlayingLevel)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Frequency Phase

    private var frequencyView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation { phase = .level }
                } label: {
                    HStack(spacing: 4) {
                        LucideIcon("chevron-left", size: 14)
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
                        Text("STAY SHARP")
                            .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                            .tracking(2)
                            .foregroundStyle(NETRTheme.subtext)

                        Text("How often do you hoop?")
                            .font(.system(.title, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NETRTheme.text)

                        Text("Skill fades without reps. This keeps your score honest.")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    VStack(spacing: 10) {
                        ForEach(PlayFrequency.allCases) { freq in
                            FrequencyRow(
                                frequency: freq,
                                isSelected: selectedFrequency == freq
                            ) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedFrequency = freq
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation { phase = .position }
                    } label: {
                        Text("NEXT")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(selectedFrequency != nil ? NETRTheme.background : NETRTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedFrequency != nil ? NETRTheme.neonGreen : NETRTheme.muted,
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selectedFrequency == nil)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedFrequency)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Position Phase

    private var positionView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation { phase = .frequency }
                } label: {
                    HStack(spacing: 4) {
                        LucideIcon("chevron-left", size: 14)
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
                        Text("YOUR POSITION")
                            .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                            .tracking(2)
                            .foregroundStyle(NETRTheme.subtext)

                        Text("What position do you play?")
                            .font(.system(.title, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NETRTheme.text)

                        Text("Your score is weighted based on what matters most for your position.")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    VStack(spacing: 10) {
                        ForEach(PlayerPosition.allCases) { pos in
                            PositionRow(
                                position: pos,
                                isSelected: selectedPosition == pos
                            ) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedPosition = pos
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
                            .foregroundStyle(selectedPosition != nil ? NETRTheme.background : NETRTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedPosition != nil ? NETRTheme.neonGreen : NETRTheme.muted,
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selectedPosition == nil)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: selectedPosition)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Questions Phase

    private var questionView: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: handleBack) {
                    HStack(spacing: 4) {
                        LucideIcon("chevron-left", size: 14)
                        if currentIndex == 0 {
                            Text("Back")
                                .font(.system(size: 15, weight: .semibold))
                        }
                    }
                    .foregroundStyle(NETRTheme.subtext)
                }

                Spacer()

                Text("\(currentIndex + 1) / \(questions.count)")
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
                    Spacer()
                        .frame(height: 8)

                    HStack(spacing: 8) {
                        if let icon = AssessmentResult.categoryIcons[currentQuestion.category] {
                            LucideIcon(icon, size: 14)
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                        if let label = AssessmentResult.categoryDisplayNames[currentQuestion.category] {
                            Text(label.uppercased())
                                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                                .tracking(1.5)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }

                    Text(currentQuestion.prompt)
                        .font(.system(.title2, design: .default, weight: .black).width(.compressed))
                        .foregroundStyle(NETRTheme.text)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        ForEach(currentQuestion.options) { option in
                            AssessmentOptionRow(
                                emoji: option.emoji,
                                label: option.label,
                                detail: option.detail,
                                isSelected: selectedAnswer == option.id
                            ) {
                                withAnimation(.snappy(duration: 0.2)) {
                                    selectedAnswer = option.id
                                }
                            }
                        }
                    }

                    Button(action: handleNext) {
                        Text(isLast ? "SEE MY SCORE" : "NEXT")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(selectedAnswer != nil ? NETRTheme.background : NETRTheme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                selectedAnswer != nil ? NETRTheme.neonGreen : NETRTheme.muted,
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .buttonStyle(PressButtonStyle())
                    .disabled(selectedAnswer == nil)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: currentIndex)
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

    private var assessmentResultView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 16)

                    Text("YOUR STARTING ESTIMATE")
                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                        .tracking(3)
                        .foregroundStyle(NETRTheme.subtext)
                        .textCase(.uppercase)

                    if let result = assessmentResult {
                        Text(result.formattedScore)
                            .font(.system(size: 72, weight: .black, design: .default).width(.compressed))
                            .foregroundStyle(NETRTheme.neonGreen)
                            .shadow(color: NETRTheme.neonGreen.opacity(0.5), radius: 30)

                        Text(result.tierLabel.uppercased())
                            .font(.system(.title3, design: .default, weight: .heavy).width(.compressed))
                            .foregroundStyle(tierColor(for: result.overallScore))

                        HStack(spacing: 10) {
                            if let age = selectedAgeGroup {
                                infoPill(text: age.label)
                            }
                            if let level = selectedPlayingLevel {
                                infoPill(text: level.label)
                            }
                        }

                        HStack(spacing: 10) {
                            if let freq = selectedFrequency {
                                infoPill(text: "\(freq.emoji) \(freq.label)")
                            }
                            if let pos = selectedPosition {
                                infoPill(text: pos.shortLabel)
                            }
                        }

                        if selectedAgeGroup?.athleticModifier ?? 1.0 < 1.0 {
                            HStack(spacing: 6) {
                                LucideIcon("info", size: 12)
                                    .foregroundStyle(NETRTheme.gold)
                                Text("Age-adjusted for fair calibration")
                                    .font(.system(size: 12))
                                    .foregroundStyle(NETRTheme.gold)
                            }
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

                            SkillRadarView(skills: buildRadarSkillsFromResult(result), size: 260, animated: true)
                        }
                        .padding(20)
                        .background(NETRTheme.card, in: .rect(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NETRTheme.border, lineWidth: 1))
                        .padding(.horizontal, 20)
                        .sheet(isPresented: $showScoreInfo) {
                            ScoreInfoSheet()
                        }
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

            Button(action: onComplete) {
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
        if currentIndex > 0 {
            withAnimation(.snappy(duration: 0.25)) {
                currentIndex -= 1
                selectedAnswer = answers[questions[currentIndex].id]
            }
        } else {
            withAnimation { phase = .position }
        }
    }

    private func handleNext() {
        guard let answer = selectedAnswer else { return }
        answers[currentQuestion.id] = answer

        if isLast {
            finalizeAssessment()
        } else {
            withAnimation(.snappy(duration: 0.25)) {
                currentIndex += 1
                selectedAnswer = answers[questions[currentIndex].id]
            }
        }
    }

    private func handleSkip() {
        if isLast {
            finalizeAssessment()
        } else {
            withAnimation(.snappy(duration: 0.25)) {
                currentIndex += 1
                selectedAnswer = answers[questions[currentIndex].id]
            }
        }
    }

    private func finalizeAssessment() {
        guard let age = selectedAgeGroup,
              let level = selectedPlayingLevel,
              let freq = selectedFrequency,
              let pos = selectedPosition else { return }
        let context = AssessmentContext(ageGroup: age, playingLevel: level, playFrequency: freq, position: pos)
        let result = AssessmentScoringEngine.calculate(answers: answers, context: context)
        assessmentResult = result
        estimatedScore = result.overallScore
        categoryScores = result.categoryScores
        withAnimation(.snappy) { phase = .result }
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

    private func tierColor(for score: Double) -> Color {
        switch score {
        case 7.0...: return NETRTheme.neonGreen
        case 5.0..<7.0: return Color(red: 0.478, green: 0.91, blue: 0.0)
        case 3.0..<5.0: return NETRTheme.blue
        default: return NETRTheme.subtext
        }
    }

    private func buildRadarSkillsFromResult(_ result: AssessmentResult) -> [RadarSkill] {
        let order = ["scoring", "finishing", "handles", "playmaking", "defense", "rebounding", "iq"]
        return order.map { cat in
            let raw = result.categoryScores[cat] ?? 1.0
            let label = AssessmentResult.categoryDisplayNames[cat] ?? cat
            let icon = AssessmentResult.categoryIcons[cat] ?? "help-circle"
            let value = (raw - 1.0) / 9.0
            return RadarSkill(label: label, icon: icon, raw: raw, value: value)
        }
    }
}

// MARK: - Sub-components

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

struct PlayingLevelRow: View {
    let level: PlayingLevel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? NETRTheme.neonGreen.opacity(0.15) : NETRTheme.card)
                        .frame(width: 40, height: 40)
                    LucideIcon(level.icon, size: 16)
                        .foregroundStyle(isSelected ? NETRTheme.neonGreen : NETRTheme.subtext)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? NETRTheme.text : NETRTheme.text.opacity(0.85))
                    Text(level.sublabel)
                        .font(.system(size: 11))
                        .foregroundStyle(NETRTheme.subtext)
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

struct FrequencyRow: View {
    let frequency: PlayFrequency
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(frequency.emoji)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)

                Text(frequency.label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? NETRTheme.text : NETRTheme.text.opacity(0.85))

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

struct PositionRow: View {
    let position: PlayerPosition
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? NETRTheme.neonGreen.opacity(0.15) : NETRTheme.card)
                        .frame(width: 40, height: 40)
                    LucideIcon(position.icon, size: 16)
                        .foregroundStyle(isSelected ? NETRTheme.neonGreen : NETRTheme.subtext)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(position.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? NETRTheme.text : NETRTheme.text.opacity(0.85))
                    Text(position.sublabel)
                        .font(.system(size: 11))
                        .foregroundStyle(NETRTheme.subtext)
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
