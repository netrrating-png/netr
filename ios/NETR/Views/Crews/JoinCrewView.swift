import SwiftUI

struct JoinCrewView: View {
    @Bindable var viewModel: CrewViewModel
    var onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var query: String = ""
    @State private var searchResults: [CrewSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var selectedCrew: CrewSearchResult? = nil
    @State private var password: String = ""
    @State private var isJoining: Bool = false
    @State private var errorMsg: String? = nil
    @State private var searchTask: Task<Void, Never>? = nil

    private var canJoin: Bool {
        selectedCrew != nil && !password.isEmpty && !isJoining
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    if let selected = selectedCrew {
                        // Selected crew + code entry
                        selectedCrewSection(selected)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                    } else {
                        // Search results
                        resultsSection
                    }

                    Spacer()

                    if let err = errorMsg {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                    }

                    // Join Button
                    Button {
                        Task { await joinCrew() }
                    } label: {
                        HStack {
                            if isJoining {
                                ProgressView().tint(NETRTheme.background).scaleEffect(0.8)
                            }
                            Text("JOIN CREW")
                                .font(.system(.body, design: .default, weight: .black).width(.compressed))
                                .tracking(1)
                        }
                        .foregroundStyle(NETRTheme.background)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canJoin ? NETRTheme.neonGreen : NETRTheme.muted, in: .rect(cornerRadius: 14))
                    }
                    .disabled(!canJoin)
                    .buttonStyle(PressButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Join a Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        LucideIcon("x", size: 16).foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            LucideIcon("search", size: 14)
                .foregroundStyle(NETRTheme.subtext)

            TextField("Search crews...", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(NETRTheme.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: query) { _, newValue in
                    selectedCrew = nil
                    errorMsg = nil
                    password = ""
                    triggerSearch(query: newValue)
                }

            if !query.isEmpty {
                Button {
                    query = ""
                    selectedCrew = nil
                    searchResults = []
                    password = ""
                    errorMsg = nil
                } label: {
                    LucideIcon("x", size: 12)
                        .foregroundStyle(NETRTheme.subtext)
                        .frame(width: 20, height: 20)
                        .background(NETRTheme.surface, in: Circle())
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(NETRTheme.card, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        if isSearching {
            VStack(spacing: 8) {
                ProgressView().tint(NETRTheme.neonGreen)
                Text("Searching...")
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.subtext)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if !query.isEmpty && query.count >= 2 && searchResults.isEmpty {
            VStack(spacing: 8) {
                LucideIcon("search-x", size: 32)
                    .foregroundStyle(NETRTheme.muted)
                Text("No crews found")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NETRTheme.subtext)
                Text("Try a different name")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if !searchResults.isEmpty {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchResults) { crew in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedCrew = crew
                                query = crew.name
                            }
                        } label: {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(NETRTheme.neonGreen.opacity(0.12))
                                        .frame(width: 44, height: 44)
                                    LucideIcon(crew.icon, size: 20)
                                        .foregroundStyle(NETRTheme.neonGreen)
                                }
                                Text(crew.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(NETRTheme.text)
                                Spacer()
                                LucideIcon("chevron-right", size: 14)
                                    .foregroundStyle(NETRTheme.muted)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 20)
                        }
                        .buttonStyle(PressButtonStyle())

                        if crew.id != searchResults.last?.id {
                            NETRTheme.border.frame(height: 1)
                                .padding(.leading, 20)
                        }
                    }
                }
            }
        } else {
            // Idle hint
            VStack(spacing: 8) {
                LucideIcon("users", size: 32)
                    .foregroundStyle(NETRTheme.muted)
                Text("Search for a crew by name")
                    .font(.system(size: 14))
                    .foregroundStyle(NETRTheme.subtext)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        }
    }

    // MARK: - Selected Crew + Code

    @ViewBuilder
    private func selectedCrewSection(_ crew: CrewSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Crew card
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(0.12))
                        .frame(width: 48, height: 48)
                    LucideIcon(crew.icon, size: 22)
                        .foregroundStyle(NETRTheme.neonGreen)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(crew.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(NETRTheme.text)
                    Text("Tap to change")
                        .font(.system(size: 11))
                        .foregroundStyle(NETRTheme.muted)
                }
                Spacer()
                Button {
                    withAnimation {
                        selectedCrew = nil
                        query = ""
                        password = ""
                        errorMsg = nil
                    }
                } label: {
                    LucideIcon("x", size: 14)
                        .foregroundStyle(NETRTheme.subtext)
                        .frame(width: 28, height: 28)
                        .background(NETRTheme.surface, in: Circle())
                }
            }
            .padding(14)
            .background(NETRTheme.card, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1))

            // Code field
            VStack(alignment: .leading, spacing: 8) {
                Text("CREW CODE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .tracking(1.3)

                SecureField("Enter the code", text: $password)
                    .font(.system(size: 15))
                    .foregroundStyle(NETRTheme.text)
                    .padding(14)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
            }
        }
    }

    // MARK: - Helpers

    private func triggerSearch(query: String) {
        searchTask?.cancel()
        guard query.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            guard !Task.isCancelled else { return }
            let results = await viewModel.searchCrews(query: query)
            if !Task.isCancelled {
                searchResults = results
                isSearching = false
            }
        }
    }

    private func joinCrew() async {
        guard let crew = selectedCrew else { return }
        errorMsg = nil
        isJoining = true
        do {
            try await viewModel.joinCrew(name: crew.name, password: password)
            onSuccess()
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
        isJoining = false
    }
}
