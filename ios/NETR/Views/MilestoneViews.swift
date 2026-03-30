import SwiftUI
import Supabase
import Auth
import PostgREST

// MARK: - Edit Milestones Sheet

private enum MilestoneFormTarget: Identifiable {
    case add
    case edit(PlayerMilestone)
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let m): return m.id
        }
    }
    var existing: PlayerMilestone? {
        if case .edit(let m) = self { return m }
        return nil
    }
}

struct EditMilestonesView: View {
    @Environment(\.dismiss) private var dismiss
    let userId: String
    @Binding var milestones: [PlayerMilestone]

    @State private var formTarget: MilestoneFormTarget? = nil
    @State private var deletingId: String? = nil

    private let client = SupabaseManager.shared.client

    private var sorted: [PlayerMilestone] {
        milestones.sorted { $0.milestoneType.prestige > $1.milestoneType.prestige }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                if milestones.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, milestone in
                                milestoneRow(milestone, isLast: index == sorted.count - 1)
                            }
                        }
                        .background(NETRTheme.card)
                        .clipShape(.rect(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NETRTheme.border, lineWidth: 1))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .scrollIndicators(.hidden)
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
                        formTarget = .add
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Add")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(NETRTheme.neonGreen)
                    }
                }
            }
            .sheet(item: $formTarget) { target in
                MilestoneFormView(userId: userId, existing: target.existing) { result in
                    if let existing = target.existing,
                       let idx = milestones.firstIndex(where: { $0.id == existing.id }) {
                        milestones[idx] = result
                    } else {
                        milestones.append(result)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(NETRTheme.muted)
            Text("No milestones yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(NETRTheme.text)
            Text("Add your basketball career —\nschool, AAU, college, pro, and more.")
                .font(.system(size: 13))
                .foregroundStyle(NETRTheme.subtext)
                .multilineTextAlignment(.center)
            Button {
                formTarget = .add
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Milestone")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(NETRTheme.background)
                .padding(.horizontal, 24)
                .padding(.vertical, 11)
                .background(NETRTheme.neonGreen, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 60)
        .padding(.horizontal, 32)
    }

    private func milestoneRow(_ m: PlayerMilestone, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(m.milestoneType.badgeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: m.milestoneType.sfSymbol)
                        .font(.system(size: 17, weight: .semibold))
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

                // Edit
                Button {
                    formTarget = .edit(m)
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NETRTheme.subtext)
                        .frame(width: 34, height: 34)
                        .background(NETRTheme.border.opacity(0.5), in: Circle())
                }
                .buttonStyle(.plain)

                // Delete
                Button {
                    Task { await delete(m) }
                } label: {
                    if deletingId == m.id {
                        ProgressView()
                            .tint(.red)
                            .scaleEffect(0.75)
                            .frame(width: 34, height: 34)
                    } else {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.8))
                            .frame(width: 34, height: 34)
                            .background(Color.red.opacity(0.1), in: Circle())
                    }
                }
                .buttonStyle(.plain)
                .disabled(deletingId != nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .background(NETRTheme.border)
                    .padding(.leading, 74)
            }
        }
    }

    private func delete(_ m: PlayerMilestone) async {
        deletingId = m.id
        do {
            try await client
                .from("player_milestones")
                .delete()
                .eq("id", value: m.id)
                .execute()
            milestones.removeAll { $0.id == m.id }
        } catch {
            print("Milestone delete error: \(error)")
        }
        deletingId = nil
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
