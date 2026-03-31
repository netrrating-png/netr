import SwiftUI
import CoreLocation
import Supabase
import Auth
import PostgREST

struct CreateGameView: View {
    @Bindable var viewModel: CourtsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var step: Int = 0
    @State private var selectedCourt: Court?
    @State private var selectedFormat: GameFormat = .fiveVFive
    @State private var selectedSkill: SkillFilter = .any
    @State private var gameViewModel = GameViewModel()
    @State private var showLobby: Bool = false
    @State private var isCreating: Bool = false
    @State private var createError: String?
    @State private var courtSearchQuery: String = ""
    @State private var courtSearchResults: [Court] = []
    @FocusState private var searchFocused: Bool

    // Scheduling
    @State private var scheduleForLater: Bool = false
    @State private var scheduledDate: Date

    init(viewModel: CourtsViewModel, preselectedCourt: Court? = nil) {
        _viewModel = Bindable(wrappedValue: viewModel)
        let cal = Calendar.current
        let now = Date()
        let rounded = cal.date(bySetting: .minute, value: (cal.component(.minute, from: now) / 15 + 1) * 15, of: now) ?? now.addingTimeInterval(900)
        _scheduledDate = State(initialValue: rounded)
        _step = State(initialValue: preselectedCourt != nil ? 1 : 0)
        _selectedCourt = State(initialValue: preselectedCourt)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                if showLobby {
                    GameLobbyView(viewModel: gameViewModel, onDismiss: { dismiss() })
                } else {
                    VStack(spacing: 0) {
                        stepIndicator
                        stepContent
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(NETRTheme.muted.opacity(0.6))
                                .frame(width: 30, height: 30)
                            LucideIcon("x", size: 11)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }
                }
            }
        }
    }

    private var stepIndicator: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { idx in
                    Capsule()
                        .fill(idx == step ? NETRTheme.neonGreen : NETRTheme.muted)
                        .frame(width: idx == step ? 24 : 6, height: 4)
                        .animation(.spring(response: 0.3), value: step)
                }
            }
            Text(stepLabel)
                .font(NETRTheme.headingFont(size: .title3))
                .foregroundStyle(NETRTheme.text)
                .tracking(1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private var stepLabel: String {
        switch step {
        case 0: return "SELECT COURT"
        case 1: return "SELECT FORMAT"
        case 2: return "NOW OR LATER?"
        case 3: return "SKILL LEVEL"
        default: return ""
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: courtSelection
        case 1: formatSelection
        case 2: timingSelection
        case 3: skillSelection
        default: EmptyView()
        }
    }

    private var courtSelection: some View {
        VStack(spacing: 0) {
            courtSearchBar
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            if !courtSearchQuery.isEmpty {
                courtSearchResultsView
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        courtSectionView(
                            title: "NEAREST TO YOU",
                            icon: "map-pin",
                            iconColor: NETRTheme.neonGreen,
                            courts: viewModel.nearestCourts,
                            emptyMessage: nearestEmptyMessage
                        )

                        courtSectionView(
                            title: "YOUR FAVORITES",
                            icon: "star",
                            iconColor: NETRTheme.gold,
                            courts: viewModel.favoriteCourtsOnly,
                            emptyMessage: "Star a court to pin it here for quick access."
                        )

                        HStack(spacing: 8) {
                            LucideIcon("search", size: 12)
                                .foregroundStyle(NETRTheme.muted)
                            Text("Search above to find any other court")
                                .font(.system(size: 13))
                                .foregroundStyle(NETRTheme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
        }
    }

    private var nearestEmptyMessage: String {
        if viewModel.userLocation == nil {
            return "Allow location access to see courts nearest to you."
        }
        return "Finding courts near you\u{2026}"
    }

    private var courtSearchBar: some View {
        HStack(spacing: 10) {
            LucideIcon("search", size: 14)
                .foregroundStyle(courtSearchQuery.isEmpty ? NETRTheme.muted : NETRTheme.neonGreen)

            TextField("Search all courts\u{2026}", text: $courtSearchQuery)
                .font(.system(size: 14))
                .foregroundStyle(NETRTheme.text)
                .tint(NETRTheme.neonGreen)
                .focused($searchFocused)
                .submitLabel(.done)
                .onSubmit { searchFocused = false }
                .onChange(of: courtSearchQuery) { _, newValue in
                    courtSearchResults = viewModel.searchCourts(query: newValue)
                }

            if !courtSearchQuery.isEmpty {
                Button {
                    courtSearchQuery = ""
                    courtSearchResults = []
                } label: {
                    LucideIcon("x-circle", size: 14)
                        .foregroundStyle(NETRTheme.muted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(NETRTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    courtSearchQuery.isEmpty ? NETRTheme.border : NETRTheme.neonGreen.opacity(0.4),
                    lineWidth: 1
                )
        )
        .clipShape(.rect(cornerRadius: 12))
    }

    @ViewBuilder
    private func courtSectionView(
        title: String, icon: String, iconColor: Color,
        courts: [Court], emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                LucideIcon(icon, size: 11)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1.3)
            }

            if courts.isEmpty {
                HStack(spacing: 10) {
                    LucideIcon(icon == "map-pin" ? "map-pin-off" : "star", size: 14)
                        .foregroundStyle(NETRTheme.muted)
                    Text(emptyMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(NETRTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 12))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(courts.enumerated()), id: \.element.id) { idx, court in
                        courtRow(court: court)
                        if idx < courts.count - 1 {
                            Divider()
                                .background(NETRTheme.border)
                                .padding(.leading, 66)
                        }
                    }
                }
                .background(NETRTheme.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
    }

    private func courtRow(court: Court) -> some View {
        Button {
            withAnimation(.snappy) {
                selectedCourt = court
                step = 1
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(court.verified ? 0.15 : 0.06))
                        .frame(width: 36, height: 36)
                    LucideIcon("circle-dot", size: 16)
                        .foregroundStyle(court.verified ? NETRTheme.neonGreen : NETRTheme.muted)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(court.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                            .lineLimit(1)
                        if court.verified {
                            LucideIcon("badge-check", size: 11)
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                    }
                    HStack(spacing: 4) {
                        Text(court.neighborhood.isEmpty ? court.city : court.neighborhood)
                            .font(.system(size: 12))
                            .foregroundStyle(NETRTheme.subtext)
                        if viewModel.userLocation != nil {
                            Text("\u{00B7}")
                                .foregroundStyle(NETRTheme.muted)
                            Text(viewModel.distanceString(for: court))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }
                }

                Spacer()

                Button {
                    Task { await viewModel.toggleFavorite(courtId: court.id) }
                } label: {
                    LucideIcon(viewModel.isFavorite(court.id) ? "star" : "star", size: 14)
                        .foregroundStyle(viewModel.isFavorite(court.id) ? NETRTheme.gold : NETRTheme.muted)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .highPriorityGesture(TapGesture().onEnded {
                    Task { await viewModel.toggleFavorite(courtId: court.id) }
                })

                LucideIcon("chevron-right", size: 12)
                    .foregroundStyle(NETRTheme.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressButtonStyle())
    }

    private var courtSearchResultsView: some View {
        Group {
            if courtSearchResults.isEmpty {
                VStack(spacing: 12) {
                    LucideIcon("search", size: 36)
                        .foregroundStyle(NETRTheme.muted)
                    Text("No courts found")
                        .font(NETRTheme.headingFont(size: .title3))
                        .foregroundStyle(NETRTheme.text)
                    Text("Try a different name or neighborhood.")
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.subtext)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(courtSearchResults.count) courts found")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NETRTheme.subtext)
                            .tracking(1.2)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(Array(courtSearchResults.enumerated()), id: \.element.id) { idx, court in
                                courtRow(court: court)
                                if idx < courtSearchResults.count - 1 {
                                    Divider()
                                        .background(NETRTheme.border)
                                        .padding(.leading, 66)
                                }
                            }
                        }
                        .background(NETRTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
                        .clipShape(.rect(cornerRadius: 14))
                        .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var formatSelection: some View {
        VStack(spacing: 24) {
            if let court = selectedCourt {
                Text(court.name)
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
            }

            VStack(spacing: 12) {
                ForEach(GameFormat.allCases) { format in
                    Button {
                        withAnimation(.snappy) {
                            selectedFormat = format
                            step = 2
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(format.displayName)
                                    .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                                    .foregroundStyle(NETRTheme.text)
                                Text("Max \(format.maxPlayers) players")
                                    .font(.caption)
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                            Spacer()
                            LucideIcon("chevron-right")
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .padding(16)
                        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private var timingSelection: some View {
        VStack(spacing: 20) {
            if let court = selectedCourt {
                HStack(spacing: 6) {
                    LucideIcon("map-pin", size: 11)
                        .foregroundStyle(NETRTheme.neonGreen)
                    Text(court.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NETRTheme.subtext)
                    Text("·")
                        .foregroundStyle(NETRTheme.muted)
                    Text(selectedFormat.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            VStack(spacing: 12) {
                // Now button
                Button {
                    withAnimation(.snappy) {
                        scheduleForLater = false
                        step = 3
                    }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(NETRTheme.background.opacity(0.2))
                                .frame(width: 44, height: 44)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(NETRTheme.background)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("I'M AT THE COURT NOW")
                                .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                .tracking(0.5)
                                .foregroundStyle(NETRTheme.background)
                            Text("Start a live game right now")
                                .font(.caption)
                                .foregroundStyle(NETRTheme.background.opacity(0.7))
                        }
                        Spacer()
                        LucideIcon("arrow-right", size: 16)
                            .foregroundStyle(NETRTheme.background.opacity(0.8))
                    }
                    .padding(18)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 16))
                    .shadow(color: NETRTheme.neonGreen.opacity(0.3), radius: 10, y: 4)
                }
                .buttonStyle(PressButtonStyle())

                // Schedule button
                VStack(spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.35)) {
                            scheduleForLater = true
                        }
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(scheduleForLater ? NETRTheme.gold.opacity(0.15) : NETRTheme.muted.opacity(0.1))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(scheduleForLater ? NETRTheme.gold : NETRTheme.subtext)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("SCHEDULE FOR LATER")
                                    .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                    .tracking(0.5)
                                    .foregroundStyle(scheduleForLater ? NETRTheme.gold : NETRTheme.text)
                                Text("Pick a future date and time")
                                    .font(.caption)
                                    .foregroundStyle(NETRTheme.subtext)
                            }
                            Spacer()
                            LucideIcon(scheduleForLater ? "chevron-down" : "chevron-right", size: 14)
                                .foregroundStyle(scheduleForLater ? NETRTheme.gold : NETRTheme.muted)
                        }
                        .padding(18)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressButtonStyle())

                    if scheduleForLater {
                        VStack(spacing: 14) {
                            Divider()
                                .background(NETRTheme.gold.opacity(0.2))
                                .padding(.horizontal, 18)

                            DatePicker(
                                "Start time",
                                selection: $scheduledDate,
                                in: Date()...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .tint(NETRTheme.gold)
                            .colorScheme(.dark)
                            .padding(.horizontal, 18)

                            Button {
                                withAnimation(.snappy) { step = 3 }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "clock.fill")
                                        .font(.system(size: 13))
                                    Text("CONFIRM TIME & CONTINUE")
                                        .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                                        .tracking(0.5)
                                }
                                .foregroundStyle(NETRTheme.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(NETRTheme.gold, in: .rect(cornerRadius: 12))
                            }
                            .buttonStyle(PressButtonStyle())
                            .padding(.horizontal, 18)
                            .padding(.bottom, 18)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .background(
                    scheduleForLater ? NETRTheme.gold.opacity(0.06) : NETRTheme.card,
                    in: .rect(cornerRadius: 16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(scheduleForLater ? NETRTheme.gold.opacity(0.4) : NETRTheme.border, lineWidth: 1)
                )
                .animation(.spring(response: 0.35), value: scheduleForLater)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private var skillSelection: some View {
        VStack(spacing: 24) {
            Text("Filter who can join")
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)

            VStack(spacing: 8) {
                ForEach(SkillFilter.allCases) { skill in
                    Button {
                        withAnimation(.snappy) { selectedSkill = skill }
                    } label: {
                        HStack {
                            Text(skill.rawValue)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedSkill == skill ? NETRTheme.neonGreen : NETRTheme.text)
                            Spacer()
                            if selectedSkill == skill {
                                LucideIcon("check-circle")
                                    .foregroundStyle(NETRTheme.neonGreen)
                            }
                        }
                        .padding(14)
                        .background(
                            selectedSkill == skill ? NETRTheme.neonGreen.opacity(0.08) : NETRTheme.card,
                            in: .rect(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedSkill == skill ? NETRTheme.neonGreen : NETRTheme.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
            .padding(.horizontal, 16)

            if scheduleForLater {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.gold)
                    Text(scheduledDate, style: .date)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NETRTheme.gold)
                    Text("at")
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.subtext)
                    Text(scheduledDate, style: .time)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NETRTheme.gold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(NETRTheme.gold.opacity(0.08), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.gold.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 16)
            }

            Spacer()

            if let err = createError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(NETRTheme.red)
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
            }

            Button {
                createError = nil
                isCreating = true
                Task {
                    do {
                        _ = try await gameViewModel.createGame(
                            courtId: selectedCourt?.id,
                            format: selectedFormat.rawValue,
                            skillLevel: selectedSkill.rawValue,
                            scheduledAt: scheduleForLater ? scheduledDate : nil
                        )
                        isCreating = false
                        withAnimation(.snappy) { showLobby = true }
                    } catch {
                        isCreating = false
                        createError = error.localizedDescription
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isCreating {
                        ProgressView().tint(NETRTheme.background)
                    } else {
                        Text(scheduleForLater ? "SCHEDULE GAME" : "CREATE GAME")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1)
                    }
                }
                .foregroundStyle(NETRTheme.background)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressButtonStyle())
            .disabled(isCreating)
            .sensoryFeedback(.success, trigger: showLobby)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Game Lobby

struct GameLobbyView: View {
    @Bindable var viewModel: GameViewModel
    let onDismiss: () -> Void
    @State private var showRateSheet: Bool = false
    @State private var countdownTimer: Timer?
    @State private var timeRemaining: TimeInterval = 0
    @State private var showFormatPicker: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("GAME LOBBY")
                        .font(NETRTheme.headingFont(size: .title2))
                        .foregroundStyle(NETRTheme.text)
                    Text(viewModel.game?.format ?? "")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                }
                .padding(.top, 16)

                // Countdown for scheduled games
                if viewModel.isScheduled, let remaining = viewModel.timeUntilStart, remaining > 0 {
                    scheduledCountdownView(remaining: timeRemaining > 0 ? timeRemaining : remaining)
                }

                VStack(spacing: 8) {
                    Text("JOIN CODE")
                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                        .tracking(2)
                        .foregroundStyle(NETRTheme.subtext)

                    Text(viewModel.game?.joinCode ?? "------")
                        .font(.system(size: 48, weight: .black, design: .monospaced))
                        .foregroundStyle(NETRTheme.neonGreen)
                        .neonGlow(radius: 12)
                        .tracking(8)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(NETRTheme.card, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 16)

                if let code = viewModel.game?.joinCode, !code.isEmpty {
                    QRCodeView(content: code, size: 120)
                }

                HStack(spacing: 16) {
                    // Format — tappable for host while waiting
                    let canChangeFormat = viewModel.isHost && viewModel.game?.status == "waiting"
                    Button {
                        if canChangeFormat { showFormatPicker = true }
                    } label: {
                        VStack(spacing: 2) {
                            HStack(spacing: 4) {
                                Text(viewModel.game?.format ?? "")
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(NETRTheme.text)
                                if canChangeFormat {
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(NETRTheme.neonGreen)
                                }
                            }
                            Text(canChangeFormat ? "Format (tap)" : "Format")
                                .font(.caption2)
                                .foregroundStyle(canChangeFormat ? NETRTheme.neonGreen : NETRTheme.subtext)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canChangeFormat)

                    Divider().frame(height: 30).background(NETRTheme.border)
                    VStack(spacing: 2) {
                        Text("\(viewModel.players.count)/\(viewModel.game?.maxPlayers ?? 0)")
                            .font(.headline.weight(.black))
                            .foregroundStyle(
                                viewModel.players.count >= (viewModel.game?.maxPlayers ?? 99)
                                ? NETRTheme.neonGreen : NETRTheme.text
                            )
                        Text("Players")
                            .font(.caption2)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                    Divider().frame(height: 30).background(NETRTheme.border)
                    VStack(spacing: 2) {
                        Text(viewModel.game?.skillLevel ?? "")
                            .font(.headline.weight(.black))
                            .foregroundStyle(NETRTheme.text)
                        Text("Level")
                            .font(.caption2)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                .padding(12)
                .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                .padding(.horizontal, 16)
                .confirmationDialog("Change Game Format", isPresented: $showFormatPicker, titleVisibility: .visible) {
                    ForEach(GameFormat.allCases) { fmt in
                        Button(fmt.displayName) {
                            Task { await viewModel.updateFormat(fmt) }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("You have \(viewModel.players.count) players. Pick a format that fits.")
                }

                if viewModel.game?.status == "active" {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(NETRTheme.neonGreen)
                            .frame(width: 8, height: 8)
                        Text("GAME IN PROGRESS")
                            .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                            .tracking(1.5)
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(NETRTheme.neonGreen.opacity(0.1), in: .capsule)
                }

                // Checkout reminder banner
                if viewModel.game?.status == "active" && viewModel.uncheckedOutCount > 0 && !viewModel.currentUserCheckedOut {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 16))
                            .foregroundStyle(NETRTheme.gold)
                        Text("Don't forget to check out when you're done to rate your teammates.")
                            .font(.system(size: 12))
                            .foregroundStyle(NETRTheme.subtext)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(NETRTheme.gold.opacity(0.08), in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.gold.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 16)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("PLAYERS")
                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                        .tracking(1)
                        .foregroundStyle(NETRTheme.subtext)

                    if viewModel.players.isEmpty {
                        HStack {
                            ProgressView().tint(NETRTheme.neonGreen)
                            Text("Waiting for players...")
                                .font(.subheadline)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(viewModel.players) { player in
                            LobbyPlayerRow(player: player, isHost: player.userId == viewModel.game?.hostId)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // ── Teams Result ───────────────────────────────────────────
                if let teams = viewModel.teams {
                    TeamsResultView(teams: teams) {
                        viewModel.makeTeams()
                    }
                }

                Spacer(minLength: 40)

                VStack(spacing: 12) {
                    if viewModel.game?.status == "waiting" {
                        VStack(spacing: 6) {
                            // ── Make Teams button (host, full game, team format) ──
                            if viewModel.canMakeTeams || viewModel.teams != nil {
                                Button {
                                    viewModel.makeTeams()
                                } label: {
                                    HStack(spacing: 8) {
                                        LucideIcon("shuffle", size: 15)
                                        Text(viewModel.teams == nil ? "MAKE TEAMS" : "RESHUFFLE TEAMS")
                                            .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                                            .tracking(1)
                                    }
                                    .foregroundStyle(NETRTheme.neonGreen)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(NETRTheme.neonGreen.opacity(0.08), in: .rect(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PressButtonStyle())
                            }

                            Button {
                                Task { await viewModel.startGame() }
                            } label: {
                                HStack(spacing: 8) {
                                    if viewModel.isStarting {
                                        ProgressView().tint(NETRTheme.background)
                                    } else {
                                        Text("START GAME")
                                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                            .tracking(1)
                                    }
                                }
                                .foregroundStyle(NETRTheme.background)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    viewModel.canStart ? NETRTheme.neonGreen : NETRTheme.neonGreen.opacity(0.3),
                                    in: .rect(cornerRadius: 14)
                                )
                            }
                            .buttonStyle(PressButtonStyle())
                            .disabled(!viewModel.canStart || viewModel.isStarting)

                            if viewModel.isHost && viewModel.players.count >= 2 {
                                HStack(spacing: 5) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 11))
                                    Text("Not full? No problem — start when you're ready. Tap the format above to adjust.")
                                        .font(.system(size: 11))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .foregroundStyle(NETRTheme.subtext)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else if viewModel.isHost && viewModel.players.count < 2 {
                                Text("Waiting for at least 1 more player to join.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(NETRTheme.subtext)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    // Check Out button (active game, not yet checked out)
                    if viewModel.game?.status == "active" && !viewModel.currentUserCheckedOut {
                        Button {
                            Task { await viewModel.checkOut() }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isCheckingOut {
                                    ProgressView().tint(NETRTheme.background)
                                } else {
                                    Image(systemName: "arrow.right.square")
                                        .font(.system(size: 16, weight: .bold))
                                    Text("CHECK OUT")
                                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                        .tracking(1)
                                }
                            }
                            .foregroundStyle(NETRTheme.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                        }
                        .buttonStyle(PressButtonStyle())
                        .disabled(viewModel.isCheckingOut)
                        .sensoryFeedback(.success, trigger: viewModel.currentUserCheckedOut)
                    }

                    // Already checked out indicator
                    if viewModel.currentUserCheckedOut {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(NETRTheme.neonGreen)
                            Text("You've checked out")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(NETRTheme.neonGreen.opacity(0.08), in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1))
                    }

                    // End Game (host only)
                    if viewModel.isHost {
                        Button {
                            Task { await viewModel.endGame() }
                        } label: {
                            Text("END GAME")
                                .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                                .tracking(1)
                                .foregroundStyle(NETRTheme.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(NETRTheme.red.opacity(0.1), in: .rect(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.red.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .background(NETRTheme.background)
        .onAppear {
            if let gameId = viewModel.game?.id {
                Task {
                    // Subscribe first so any join during load isn't missed
                    if !viewModel.isSubscribed {
                        await viewModel.subscribeToLobby(gameId: gameId)
                    }
                    await viewModel.loadPlayers(gameId: gameId)
                }
            }
            startCountdownIfNeeded()
        }
        .onDisappear {
            countdownTimer?.invalidate()
            Task { await viewModel.unsubscribe() }
        }
        .onChange(of: viewModel.showRateScreen) { _, show in
            if show { showRateSheet = true }
        }
        .sheet(isPresented: $showRateSheet, onDismiss: { onDismiss() }) {
            if let _ = viewModel.completedGameId {
                RateView()
            }
        }
    }

    private func scheduledCountdownView(remaining: TimeInterval) -> some View {
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.gold)
                Text("SCHEDULED START")
                    .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                    .tracking(1.5)
                    .foregroundStyle(NETRTheme.gold)
            }

            if let date = viewModel.scheduledDate {
                Text(date, style: .date)
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
                + Text(" at ")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
                + Text(date, style: .time)
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
            }

            HStack(spacing: 12) {
                countdownUnit(value: hours, label: "HR")
                Text(":")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(NETRTheme.gold.opacity(0.5))
                countdownUnit(value: minutes, label: "MIN")
                Text(":")
                    .font(.system(size: 24, weight: .black, design: .monospaced))
                    .foregroundStyle(NETRTheme.gold.opacity(0.5))
                countdownUnit(value: seconds, label: "SEC")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(NETRTheme.gold.opacity(0.06), in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.gold.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    private func countdownUnit(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .foregroundStyle(NETRTheme.gold)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .tracking(1)
        }
    }

    private func startCountdownIfNeeded() {
        guard let remaining = viewModel.timeUntilStart, remaining > 0 else { return }
        timeRemaining = remaining
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let remaining = viewModel.timeUntilStart, remaining > 0 {
                timeRemaining = remaining
            } else {
                countdownTimer?.invalidate()
                timeRemaining = 0
            }
        }
    }
}

// MARK: - Lobby Player Row

// MARK: - Rating Progress Circle (shown when peer score is locked)

private struct RatingProgressCircle: View {
    let totalRatings: Int   // how many peer ratings received so far
    let needed: Int = 5

    private var progress: Double { min(Double(totalRatings) / Double(needed), 1.0) }

    var body: some View {
        ZStack {
            // Dark fill
            Circle()
                .fill(Color(hex: "#111111"))
                .frame(width: 44, height: 44)

            // Background track
            Circle()
                .stroke(NETRTheme.neonGreen.opacity(0.15), lineWidth: 2.5)
                .frame(width: 44, height: 44)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    NETRTheme.neonGreen,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(-90))
                .shadow(color: NETRTheme.neonGreen.opacity(0.6), radius: 4)

            // Lock icon
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NETRTheme.subtext)
        }
    }
}

// MARK: - Teams Result View

struct TeamsResultView: View {
    let teams: TeamBalancer.BalancedTeams
    let onReshuffle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    LucideIcon("users", size: 12)
                        .foregroundStyle(NETRTheme.neonGreen)
                    Text("TEAMS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(NETRTheme.subtext)
                        .tracking(0.8)
                }
                Spacer()
                Button(action: onReshuffle) {
                    HStack(spacing: 4) {
                        LucideIcon("shuffle", size: 12)
                        Text("Reshuffle")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(NETRTheme.neonGreen)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 10) {
                teamColumn(label: "TEAM A", players: teams.teamA, accent: NETRTheme.neonGreen)
                teamColumn(label: "TEAM B", players: teams.teamB, accent: Color(hex: "#2DA8FF"))
            }

            // Balance indicator
            HStack(spacing: 5) {
                let diff = teams.netrDiff
                Image(systemName: diff < 30 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(diff < 30 ? NETRTheme.neonGreen : NETRTheme.gold)
                Text(diff < 1
                     ? "Perfectly balanced teams"
                     : "\(String(format: "%.0f", diff)) avg NETR difference — \(diff < 30 ? "well balanced" : "consider reshuffling")")
                    .font(.system(size: 11))
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(14)
        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func teamColumn(label: String, players: [LobbyPlayer], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(accent)
                    .tracking(0.5)
            }
            .padding(.bottom, 2)

            ForEach(players) { player in
                HStack(spacing: 7) {
                    // Avatar / initials
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 26, height: 26)
                        .overlay(
                            Text(playerInitials(player))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(accent)
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(playerDisplayName(player))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                            .lineLimit(1)
                        if let pos = player.profile.position, !pos.isEmpty {
                            Text(pos.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                    }

                    Spacer(minLength: 4)

                    if let netr = player.profile.netrScore {
                        Text(String(format: "%.0f", netr))
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(accent.opacity(0.9))
                    }
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(accent.opacity(0.07), in: .rect(cornerRadius: 8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playerInitials(_ player: LobbyPlayer) -> String {
        let name = player.profile.fullName ?? player.profile.username ?? "?"
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return (String(parts[0].prefix(1)) + String(parts[1].prefix(1))).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func playerDisplayName(_ player: LobbyPlayer) -> String {
        if let name = player.profile.fullName, !name.isEmpty { return name }
        if let username = player.profile.username { return "@\(username)" }
        return "Player"
    }
}

// MARK: - Lobby Player Row

struct LobbyPlayerRow: View {
    let player: LobbyPlayer
    var isHost: Bool = false

    private var displayName: String {
        player.profile.fullName ?? player.profile.username ?? "Player"
    }

    private var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with vibe dot overlay
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let avatarUrl = player.profile.avatarUrl, let url = URL(string: avatarUrl) {
                        NETRTheme.card
                            .frame(width: 44, height: 44)
                            .overlay {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                                    }
                                }
                            }
                            .clipShape(Circle())
                    } else {
                        Text(initials)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(player.isCheckedOut ? NETRTheme.muted : NETRTheme.neonGreen)
                            .frame(width: 44, height: 44)
                            .background(NETRTheme.card, in: Circle())
                    }
                }
                .overlay(Circle().stroke(
                    player.isCheckedOut ? NETRTheme.muted.opacity(0.3) : NETRTheme.neonGreen.opacity(0.3),
                    lineWidth: 1.5
                ))
                .opacity(player.isCheckedOut ? 0.5 : 1)

                // Vibe dot — bottom-right of avatar
                if player.profile.vibeScore != nil {
                    VibeDecalView(vibe: player.profile.vibeScore, size: .small)
                        .frame(width: 12, height: 12)
                        .background(NETRTheme.surface, in: Circle())
                        .padding(1)
                        .background(NETRTheme.surface, in: Circle())
                        .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(player.isCheckedOut ? NETRTheme.muted : NETRTheme.text)
                    if isHost {
                        Text("HOST")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(NETRTheme.neonGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(NETRTheme.neonGreen.opacity(0.12), in: .capsule)
                    }
                    if player.isCheckedOut {
                        Text("LEFT")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(NETRTheme.muted)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(NETRTheme.muted.opacity(0.12), in: .capsule)
                    }
                }
                if let pos = player.profile.position, !pos.isEmpty {
                    Text(pos)
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()

            // NETR rating circle — or progress circle if not yet unlocked
            if (player.profile.totalRatings ?? 0) >= 5 {
                NETRBadge(score: player.profile.netrScore, size: .small)
            } else {
                RatingProgressCircle(totalRatings: player.profile.totalRatings ?? 0)
            }
        }
        .padding(10)
        .background(NETRTheme.surface, in: .rect(cornerRadius: 10))
    }
}

// MARK: - Game Players Preview Sheet

struct GamePlayersPreviewSheet: View {
    let gameId: String
    @Environment(\.dismiss) private var dismiss
    @State private var players: [LobbyPlayer] = []
    @State private var game: SupabaseGame?
    @State private var isLoading = true
    @State private var selectedProfileId: String?

    private let client = SupabaseManager.shared.client
    private var currentUserId: String? { SupabaseManager.shared.session?.user.id.uuidString }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(NETRTheme.neonGreen)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            // Header stats
                            if let g = game {
                                HStack(spacing: 24) {
                                    VStack(spacing: 2) {
                                        Text(GameFormat(rawValue: g.format)?.displayName ?? g.format)
                                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                            .foregroundStyle(NETRTheme.text)
                                        Text("Format").font(.caption2).foregroundStyle(NETRTheme.subtext)
                                    }
                                    Divider().frame(height: 28).background(NETRTheme.border)
                                    VStack(spacing: 2) {
                                        Text("\(activePlayers.count)/\(g.maxPlayers)")
                                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                            .foregroundStyle(activePlayers.count >= g.maxPlayers ? NETRTheme.gold : NETRTheme.neonGreen)
                                        Text("Players").font(.caption2).foregroundStyle(NETRTheme.subtext)
                                    }
                                    Divider().frame(height: 28).background(NETRTheme.border)
                                    VStack(spacing: 2) {
                                        Text("\(g.maxPlayers - activePlayers.count)")
                                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                            .foregroundStyle(NETRTheme.text)
                                        Text("Open spots").font(.caption2).foregroundStyle(NETRTheme.subtext)
                                    }
                                }
                                .padding(14)
                                .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                            }

                            if activePlayers.isEmpty {
                                Text("No players have joined yet.")
                                    .font(.subheadline)
                                    .foregroundStyle(NETRTheme.subtext)
                                    .padding(.top, 20)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("WHO'S IN")
                                        .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                                        .tracking(1)
                                        .foregroundStyle(NETRTheme.subtext)
                                    ForEach(activePlayers) { player in
                                        Button { selectedProfileId = player.userId } label: {
                                            LobbyPlayerRow(player: player)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(NETRTheme.background.ignoresSafeArea())
            .navigationTitle("Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NETRTheme.neonGreen)
                }
            }
        }
        .task { await load() }
        .fullScreenCover(item: $selectedProfileId) { uid in
            if uid == currentUserId {
                ProfileView()
            } else {
                PublicPlayerProfileView(userId: uid)
            }
        }
    }

    // Show all non-removed players (including checked-out so count matches the card)
    private var activePlayers: [LobbyPlayer] {
        players.filter { !$0.isRemoved }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        // ── Step 1: Fetch the game record on its own ──────────────────────
        // Keeping this separate from the game_players join so an RLS failure
        // on that table can never silently kill the whole load.
        nonisolated struct SlimGame: Decodable, Sendable {
            let id: String
            let format: String
            let skillLevel: String
            let status: String
            let maxPlayers: Int
            let joinCode: String
            let hostId: String
            let createdAt: String?
            let scheduledAt: String?
            let courtId: String?
            nonisolated enum CodingKeys: String, CodingKey {
                case id; case format; case skillLevel = "skill_level"; case status
                case maxPlayers = "max_players"; case joinCode = "join_code"
                case hostId = "host_id"; case createdAt = "created_at"
                case scheduledAt = "scheduled_at"; case courtId = "court_id"
            }
        }

        guard let g: SlimGame = try? await client
            .from("games")
            .select("id, format, skill_level, status, max_players, join_code, host_id, created_at, scheduled_at, court_id")
            .eq("id", value: gameId)
            .single()
            .execute()
            .value else { return }

        game = SupabaseGame(
            id: g.id, courtId: g.courtId, hostId: g.hostId,
            joinCode: g.joinCode, format: g.format, skillLevel: g.skillLevel,
            status: g.status, maxPlayers: g.maxPlayers,
            createdAt: g.createdAt, scheduledAt: g.scheduledAt, completedAt: nil
        )

        // ── Step 2: Fetch game_players separately (may be RLS-restricted) ─
        nonisolated struct EmbeddedPlayer: Decodable, Sendable {
            let userId: String
            nonisolated enum CodingKeys: String, CodingKey { case userId = "user_id" }
        }
        let joinedPlayers: [EmbeddedPlayer] = (try? await client
            .from("game_players")
            .select("user_id")
            .eq("game_id", value: gameId)
            .execute()
            .value) ?? []

        // Always include the host — the game card counts them as player #1
        // even before a game_players row is written. De-duplicate if already present.
        var userIds = joinedPlayers.map { $0.userId }
        if !userIds.contains(g.hostId) {
            userIds.insert(g.hostId, at: 0)
        }
        guard !userIds.isEmpty else { return }

        // Profile fetch — same minimal column list used by other working queries in the app.
        // total_ratings is intentionally omitted here; it may not exist in the remote DB yet
        // (pending migration). We count from the ratings table instead.
        nonisolated struct SlimProfile: Decodable, Sendable {
            let id: String
            let fullName: String?
            let username: String?
            let position: String?
            let avatarUrl: String?
            let netrScore: Double?
            let vibeScore: Double?
            nonisolated enum CodingKeys: String, CodingKey {
                case id; case fullName = "full_name"; case username; case position
                case avatarUrl = "avatar_url"; case netrScore = "netr_score"
                case vibeScore = "vibe_score"
            }
        }

        let profiles: [SlimProfile] = (try? await client
            .from("profiles")
            .select("id, full_name, username, position, avatar_url, netr_score, vibe_score")
            .in("id", values: userIds)
            .execute()
            .value) ?? []

        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

        // Count peer ratings per user from the ratings table (client-side group).
        nonisolated struct RatingRow: Decodable, Sendable {
            let ratedUserId: String
            nonisolated enum CodingKeys: String, CodingKey { case ratedUserId = "rated_user_id" }
        }
        let ratingRows: [RatingRow] = (try? await client
            .from("ratings")
            .select("rated_user_id")
            .in("rated_user_id", values: userIds)
            .eq("is_self_rating", value: false)
            .execute()
            .value) ?? []
        let ratingsCountMap = Dictionary(grouping: ratingRows, by: { $0.ratedUserId })
            .mapValues { $0.count }

        players = userIds.enumerated().map { idx, uid in
            let p = profileMap[uid]
            return LobbyPlayer(
                id: "\(gameId)-\(idx)", userId: uid, gameId: gameId,
                checkedInAt: nil, checkedOutAt: nil, removed: false,
                profile: LobbyPlayerProfile(
                    id: uid,
                    fullName: p?.fullName, username: p?.username, position: p?.position,
                    avatarUrl: p?.avatarUrl, netrScore: p?.netrScore, vibeScore: p?.vibeScore,
                    totalRatings: ratingsCountMap[uid]
                )
            )
        }
    }
}
