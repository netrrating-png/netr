import SwiftUI
import Auth

struct CrewDetailView: View {
    @Bindable var viewModel: CrewViewModel
    let crew: MyCrew
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 0
    @State private var selectedFilter: CrewLeaderboardFilter = .overall
    @State private var showSettings: Bool = false
    @State private var showLeaveConfirm: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showTransferAdmin: Bool = false
    @State private var transferTarget: CrewMemberProfile? = nil
    @State private var isLoading: Bool = false
    @State private var errorMsg: String? = nil

    private var currentUserId: String {
        SupabaseManager.shared.session?.user.id.uuidString ?? ""
    }

    private var isAdmin: Bool {
        crew.adminId == currentUserId
    }

    private var members: [CrewMemberProfile] {
        viewModel.members
    }

    private var leaderboard: [CrewMemberProfile] {
        viewModel.sortedMembers
    }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Header
                headerView

                // Crew Info Card
                crewInfoCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Tab Bar
                tabBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                // Debug error (temp)
                if let err = errorMsg {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                        .multilineTextAlignment(.center)
                }

                // Content
                if selectedTab == 0 {
                    leaderboardTab
                } else {
                    membersTab
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            crewSettingsSheet
        }
        .alert("Leave Crew", isPresented: $showLeaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Leave", role: .destructive) {
                Task { await leaveCrew() }
            }
        } message: {
            Text("Are you sure you want to leave \(crew.name)?")
        }
        .alert("Delete Crew", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteCrew() }
            }
        } message: {
            Text("This will permanently delete \(crew.name) and remove all members. This cannot be undone.")
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(NETRTheme.card)
                        .frame(width: 36, height: 36)
                    LucideIcon("arrow-left", size: 16)
                        .foregroundStyle(NETRTheme.text)
                }
            }
            .buttonStyle(PressButtonStyle())

            Spacer()

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(0.12))
                        .frame(width: 32, height: 32)
                    LucideIcon(crew.icon, size: 16)
                        .foregroundStyle(NETRTheme.neonGreen)
                }
                Text(crew.name)
                    .font(NETRTheme.headingFont(size: .title2))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)
            }

            Spacer()

            if isAdmin {
                Button { showSettings = true } label: {
                    ZStack {
                        Circle()
                            .fill(NETRTheme.card)
                            .frame(width: 36, height: 36)
                        LucideIcon("settings", size: 16)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
                .buttonStyle(PressButtonStyle())
            } else {
                // Placeholder to balance layout
                Circle()
                    .fill(Color.clear)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Crew Info Card

    private var crewInfoCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(NETRTheme.neonGreen.opacity(0.12))
                    .frame(width: 56, height: 56)
                LucideIcon(crew.icon, size: 26)
                    .foregroundStyle(NETRTheme.neonGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(crew.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(NETRTheme.text)

                HStack(spacing: 4) {
                    LucideIcon("users", size: 12)
                        .foregroundStyle(NETRTheme.subtext)
                    Text("\(viewModel.members.count) member\(viewModel.members.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()

            if crew.isPrimary {
                Text("PRIMARY")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(NETRTheme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(NETRTheme.gold.opacity(0.12), in: .rect(cornerRadius: 6))
            }
        }
        .padding(16)
        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(["LEADERBOARD", "MEMBERS"], id: \.self) { tab in
                let idx = tab == "LEADERBOARD" ? 0 : 1
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = idx }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab)
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(selectedTab == idx ? NETRTheme.text : NETRTheme.subtext)
                            .frame(maxWidth: .infinity)
                        Rectangle()
                            .fill(selectedTab == idx ? NETRTheme.neonGreen : Color.clear)
                            .frame(height: 2)
                            .cornerRadius(1)
                    }
                }
                .buttonStyle(PressButtonStyle())
            }
        }
        .background(
            VStack {
                Spacer()
                NETRTheme.border.frame(height: 1)
            }
        )
    }

    // MARK: - Leaderboard Tab

    private var leaderboardTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(CrewLeaderboardFilter.allCases, id: \.self) { filter in
                            let isSelected = selectedFilter == filter
                            Button {
                                selectedFilter = filter
                                viewModel.leaderboardFilter = filter
                            } label: {
                                HStack(spacing: 5) {
                                    LucideIcon(filter.icon, size: 11)
                                    Text(filter.rawValue)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundStyle(isSelected ? NETRTheme.background : NETRTheme.subtext)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isSelected ? NETRTheme.neonGreen : NETRTheme.card, in: Capsule())
                                .overlay(Capsule().stroke(isSelected ? Color.clear : NETRTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(PressButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 12)
                .padding(.bottom, 8)

                if leaderboard.isEmpty {
                    emptyLeaderboardState
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, member in
                            leaderboardRow(member: member, rank: index + 1)
                            if index < leaderboard.count - 1 {
                                NETRTheme.border.frame(height: 1)
                                    .padding(.leading, 20)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, 40)
        }
    }

    private var emptyLeaderboardState: some View {
        VStack(spacing: 12) {
            LucideIcon("bar-chart-2", size: 36)
                .foregroundStyle(NETRTheme.muted)
            Text("No data yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private func leaderboardRow(member: CrewMemberProfile, rank: Int) -> some View {
        HStack(spacing: 12) {
            // Rank
            Group {
                switch rank {
                case 1: Text("🥇")
                case 2: Text("🥈")
                case 3: Text("🥉")
                default:
                    Text("\(rank)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NETRTheme.muted)
                        .frame(width: 24)
                }
            }
            .frame(width: 28)

            // Avatar
            avatarCircle(profile: member, size: 38)

            // Name & username
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(member.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NETRTheme.text)
                    if member.id == crew.adminId {
                        LucideIcon("crown", size: 11)
                            .foregroundStyle(NETRTheme.gold)
                    }
                }
                if let username = member.username {
                    Text("@\(username)")
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()

            // Score Badge — shows the selected category score
            let displayScore = member.score(for: selectedFilter) ?? member.netrScore
            if let score = displayScore {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.1f", score))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(NETRRating.color(for: score))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(NETRRating.color(for: score).opacity(0.12), in: .rect(cornerRadius: 8))
                    if selectedFilter != .overall {
                        Text(selectedFilter.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(NETRTheme.muted)
                    }
                }
            } else {
                Text("—")
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.muted)
            }
        }
        .padding(.vertical, 12)
        .background(rank == 1 ? NETRTheme.gold.opacity(0.05) : Color.clear)
    }

    // MARK: - Members Tab

    private var membersTab: some View {
        ScrollView {
            VStack(spacing: 0) {
                LazyVStack(spacing: 0) {
                    ForEach(members) { member in
                        memberRow(member: member)
                        if member.id != members.last?.id {
                            NETRTheme.border.frame(height: 1)
                                .padding(.leading, 20)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                if members.contains(where: { $0.id == currentUserId }) && !isAdmin {
                    leaveCrewButton
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                }
            }
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private func memberRow(member: CrewMemberProfile) -> some View {
        HStack(spacing: 12) {
            avatarCircle(profile: member, size: 42)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(member.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(NETRTheme.text)
                    if member.id == crew.adminId {
                        LucideIcon("crown", size: 11)
                            .foregroundStyle(NETRTheme.gold)
                    }
                    if member.id == currentUserId {
                        Text("YOU")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(NETRTheme.neonGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(NETRTheme.neonGreen.opacity(0.12), in: .rect(cornerRadius: 4))
                    }
                }
                if let username = member.username {
                    Text("@\(username)")
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
            }

            Spacer()

            if let score = member.netrScore {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(NETRRating.color(for: score))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(NETRRating.color(for: score).opacity(0.12), in: .rect(cornerRadius: 8))
            }

            if isAdmin && member.id != currentUserId {
                Menu {
                    Button {
                        Task { await removeMember(member) }
                    } label: {
                        Label("Remove", systemImage: "person.fill.xmark")
                    }

                    Button {
                        Task { await makeAdmin(member) }
                    } label: {
                        Label("Make Admin", systemImage: "crown.fill")
                    }
                } label: {
                    LucideIcon("ellipsis", size: 16)
                        .foregroundStyle(NETRTheme.subtext)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var leaveCrewButton: some View {
        Button {
            showLeaveConfirm = true
        } label: {
            HStack(spacing: 8) {
                LucideIcon("log-out", size: 16)
                Text("Leave Crew")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(NETRTheme.red)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(NETRTheme.red.opacity(0.08), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.red.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
    }

    // MARK: - Settings Sheet

    private var crewSettingsSheet: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Invite Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("INVITE PLAYERS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NETRTheme.subtext)
                                .tracking(1.3)

                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(NETRTheme.neonGreen.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    LucideIcon("share-2", size: 18)
                                        .foregroundStyle(NETRTheme.neonGreen)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Share outside the app")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(NETRTheme.text)
                                    Text("Send your crew name & code to players so they can join")
                                        .font(.system(size: 12))
                                        .foregroundStyle(NETRTheme.subtext)
                                }
                            }
                            .padding(14)
                            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                        }

                        Divider().background(NETRTheme.border)

                        // Transfer Admin
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TRANSFER ADMIN")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NETRTheme.subtext)
                                .tracking(1.3)

                            let otherMembers = members.filter { $0.id != currentUserId }
                            if otherMembers.isEmpty {
                                Text("No other members to transfer admin to")
                                    .font(.system(size: 13))
                                    .foregroundStyle(NETRTheme.muted)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(otherMembers) { member in
                                        Button {
                                            Task { await makeAdmin(member) }
                                        } label: {
                                            HStack(spacing: 12) {
                                                avatarCircle(profile: member, size: 36)
                                                Text(member.displayName)
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(NETRTheme.text)
                                                Spacer()
                                                LucideIcon("chevron-right", size: 14)
                                                    .foregroundStyle(NETRTheme.muted)
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 14)
                                        }
                                        .buttonStyle(PressButtonStyle())

                                        if member.id != otherMembers.last?.id {
                                            NETRTheme.border.frame(height: 1)
                                                .padding(.leading, 14)
                                        }
                                    }
                                }
                                .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                            }
                        }

                        Divider().background(NETRTheme.border)

                        // Delete Crew
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DANGER ZONE")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NETRTheme.red.opacity(0.7))
                                .tracking(1.3)

                            Button {
                                showDeleteConfirm = true
                            } label: {
                                HStack(spacing: 10) {
                                    LucideIcon("trash-2", size: 16)
                                    Text("Delete Crew")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(NETRTheme.red)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(NETRTheme.red.opacity(0.08), in: .rect(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.red.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(PressButtonStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Crew Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { showSettings = false } label: {
                        LucideIcon("x", size: 16).foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
        }
        .alert("Delete Crew", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteCrew() }
            }
        } message: {
            Text("This will permanently delete \(crew.name) and remove all members. This cannot be undone.")
        }
    }

    // MARK: - Avatar Helper

    @ViewBuilder
    private func avatarCircle(profile: CrewMemberProfile, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(NETRTheme.surface)
                .frame(width: size, height: size)

            if let urlString = profile.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialsView(name: profile.displayName, size: size)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initialsView(name: profile.displayName, size: size)
            }
        }
    }

    @ViewBuilder
    private func initialsView(name: String, size: CGFloat) -> some View {
        Text(initials(from: name))
            .font(.system(size: size * 0.35, weight: .bold))
            .foregroundStyle(NETRTheme.subtext)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Actions

    private func loadData() async {
        isLoading = true
        viewModel.errorMessage = nil
        await viewModel.loadCrewDetail(crewId: crew.id)
        if let err = viewModel.errorMessage {
            errorMsg = "Load error: \(err)"
        }
        isLoading = false
    }

    private func removeMember(_ member: CrewMemberProfile) async {
        do {
            try await viewModel.removeMember(crewId: crew.id, userId: member.id)
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func makeAdmin(_ member: CrewMemberProfile) async {
        do {
            try await viewModel.transferAdmin(crewId: crew.id, toUserId: member.id)
            showSettings = false
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func leaveCrew() async {
        do {
            try await viewModel.leaveCrew(crewId: crew.id)
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
    }

    private func deleteCrew() async {
        do {
            try await viewModel.deleteCrew(crewId: crew.id)
            showSettings = false
            dismiss()
        } catch {
            errorMsg = error.localizedDescription
        }
    }
}
