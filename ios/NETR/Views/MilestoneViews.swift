import SwiftUI
import Supabase
import Auth
import PostgREST

// MARK: - Edit Milestones Sheet

struct EditMilestonesView: View {
    @Environment(\.dismiss) private var dismiss
    let userId: String
    @Binding var milestones: [PlayerMilestone]

    @State private var isLoading = false
    @State private var showAddSheet = false
    @State private var editingMilestone: PlayerMilestone? = nil

    private let client = SupabaseManager.shared.client

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                if milestones.isEmpty {
                    VStack(spacing: 14) {
                        Text("🏀")
                            .font(.system(size: 44))
                        Text("No milestones yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                        Text("Add real-world achievements to your profile.\nThey don't affect your NETR score.")
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.subtext)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                } else {
                    List {
                        ForEach(milestones.sorted { $0.milestoneType.prestige > $1.milestoneType.prestige }) { milestone in
                            milestoneRow(milestone)
                                .listRowBackground(NETRTheme.card)
                                .listRowSeparatorTint(NETRTheme.border)
                        }
                        .onDelete(perform: deleteMilestones)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Milestones")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingMilestone = nil
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                MilestoneFormView(userId: userId, existing: nil) { newMilestone in
                    milestones.append(newMilestone)
                }
            }
            .sheet(item: $editingMilestone) { m in
                MilestoneFormView(userId: userId, existing: m) { updated in
                    if let idx = milestones.firstIndex(where: { $0.id == updated.id }) {
                        milestones[idx] = updated
                    }
                }
            }
        }
    }

    private func milestoneRow(_ m: PlayerMilestone) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(m.milestoneType.badgeColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: m.milestoneType.sfSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(m.milestoneType.badgeColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(m.milestoneType.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NETRTheme.text)
                if let sub = m.subtitle {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()

            Button {
                editingMilestone = m
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.subtext)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func deleteMilestones(at offsets: IndexSet) {
        let sorted = milestones.sorted { $0.milestoneType.prestige > $1.milestoneType.prestige }
        let toDelete = offsets.map { sorted[$0] }
        Task {
            for m in toDelete {
                try? await client
                    .from("player_milestones")
                    .delete()
                    .eq("id", value: m.id)
                    .execute()
                milestones.removeAll { $0.id == m.id }
            }
        }
    }
}

// MARK: - Add / Edit Form

struct MilestoneFormView: View {
    @Environment(\.dismiss) private var dismiss
    let userId: String
    let existing: PlayerMilestone?
    let onSave: (PlayerMilestone) -> Void

    @State private var selectedType: MilestoneType
    @State private var teamName: String
    @State private var season: String
    @State private var isSaving = false

    private let client = SupabaseManager.shared.client

    init(userId: String, existing: PlayerMilestone?, onSave: @escaping (PlayerMilestone) -> Void) {
        self.userId = userId
        self.existing = existing
        self.onSave = onSave
        _selectedType = State(initialValue: existing?.milestoneType ?? .highSchoolVarsity)
        _teamName = State(initialValue: existing?.teamName ?? "")
        _season = State(initialValue: existing?.season ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Type picker
                        VStack(alignment: .leading, spacing: 10) {
                            label("LEVEL")
                            VStack(spacing: 0) {
                                ForEach(MilestoneType.allCases.sorted { $0.prestige < $1.prestige }, id: \.rawValue) { type in
                                    Button {
                                        selectedType = type
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: type.sfSymbol)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundStyle(type.badgeColor)
                                                .frame(width: 24)
                                            Text(type.displayName)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(NETRTheme.text)
                                            Spacer()
                                            if selectedType == type {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(NETRTheme.neonGreen)
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 13)
                                        .background(selectedType == type ? selectedType.badgeColor.opacity(0.08) : Color.clear)
                                    }
                                    .buttonStyle(.plain)
                                    if type != MilestoneType.allCases.sorted(by: { $0.prestige < $1.prestige }).last {
                                        Divider().background(NETRTheme.border).padding(.leading, 52)
                                    }
                                }
                            }
                            .background(NETRTheme.card)
                            .clipShape(.rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                        }

                        // Team name
                        VStack(alignment: .leading, spacing: 10) {
                            label("TEAM / SCHOOL NAME")
                            TextField("e.g. Jefferson HS, City College", text: $teamName)
                                .font(.system(size: 14))
                                .foregroundStyle(NETRTheme.text)
                                .padding(14)
                                .background(NETRTheme.card)
                                .clipShape(.rect(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                        }

                        // Season
                        VStack(alignment: .leading, spacing: 10) {
                            label("SEASON / YEAR  (optional)")
                            TextField("e.g. 2025-26, Fall 2025", text: $season)
                                .font(.system(size: 14))
                                .foregroundStyle(NETRTheme.text)
                                .padding(14)
                                .background(NETRTheme.card)
                                .clipShape(.rect(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                        }

                        // Honesty note
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13))
                                .foregroundStyle(NETRTheme.subtext)
                                .padding(.top, 1)
                            Text("Milestones don't change your NETR score. They're a badge of your basketball journey — keep it real.")
                                .font(.system(size: 12))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existing == nil ? "Add Milestone" : "Edit Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(NETRTheme.neonGreen)
                        } else {
                            Text("Save")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(NETRTheme.subtext)
            .tracking(1.5)
    }

    private func save() async {
        isSaving = true
        let trimmedTeam = teamName.trimmingCharacters(in: .whitespaces).nilIfEmpty
        let trimmedSeason = season.trimmingCharacters(in: .whitespaces).nilIfEmpty

        if let existing {
            // UPDATE
            let payload = MilestoneUpdate(
                milestoneType: selectedType.rawValue,
                teamName: trimmedTeam,
                season: trimmedSeason
            )
            do {
                let updated: [PlayerMilestone] = try await client
                    .from("player_milestones")
                    .update(payload)
                    .eq("id", value: existing.id)
                    .select()
                    .execute()
                    .value
                if let first = updated.first {
                    onSave(first)
                }
            } catch {
                print("Milestone update error: \(error)")
            }
        } else {
            // INSERT
            let payload = MilestoneInsert(
                userId: userId,
                milestoneType: selectedType.rawValue,
                teamName: trimmedTeam,
                season: trimmedSeason
            )
            do {
                let inserted: [PlayerMilestone] = try await client
                    .from("player_milestones")
                    .insert(payload)
                    .select()
                    .execute()
                    .value
                if let first = inserted.first {
                    onSave(first)
                }
            } catch {
                print("Milestone insert error: \(error)")
            }
        }
        isSaving = false
        dismiss()
    }
}

// MARK: - Profile Badge (small tappable icon next to name — tapping scrolls to milestones)

struct MilestoneProfileBadge: View {
    let milestones: [PlayerMilestone]
    let onTap: () -> Void

    private var topMilestone: PlayerMilestone? {
        milestones.max(by: { $0.milestoneType.prestige < $1.milestoneType.prestige })
    }

    var body: some View {
        if let top = topMilestone {
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .fill(top.milestoneType.badgeColor.opacity(0.15))
                        .frame(width: 24, height: 24)
                    Circle()
                        .stroke(top.milestoneType.badgeColor.opacity(0.4), lineWidth: 1)
                        .frame(width: 24, height: 24)
                    Image(systemName: top.milestoneType.sfSymbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(top.milestoneType.badgeColor)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Helpers

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
