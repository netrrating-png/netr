import SwiftUI

struct MyCrewsView: View {
    @Bindable var viewModel: CrewViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showCreate: Bool = false
    @State private var showJoin: Bool = false
    @State private var selectedCrew: MyCrew? = nil
    @State private var showDetail: Bool = false

    private var atCapacity: Bool {
        viewModel.myCrews.count >= 5
    }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                NETRTheme.border.frame(height: 1)

                if viewModel.myCrews.isEmpty {
                    emptyState
                } else {
                    crewList
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateCrewView(viewModel: viewModel) {
                Task { await viewModel.loadMyCrews() }
            }
        }
        .sheet(isPresented: $showJoin) {
            JoinCrewView(viewModel: viewModel) {
                Task { await viewModel.loadMyCrews() }
            }
        }
        .sheet(item: $selectedCrew) { crew in
            CrewDetailView(viewModel: viewModel, crew: crew)
        }
        .task {
            await viewModel.loadMyCrews()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
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

            Text("MY CREWS")
                .font(NETRTheme.headingFont(size: .title2))
                .foregroundStyle(NETRTheme.text)

            Spacer()

            // Count badge
            HStack(spacing: 3) {
                Text("\(viewModel.myCrews.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(atCapacity ? NETRTheme.red : NETRTheme.neonGreen)
                Text("/ 5")
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.subtext)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(NETRTheme.card, in: .rect(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(NETRTheme.border, lineWidth: 1))
            .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(NETRTheme.surface)
                        .frame(width: 80, height: 80)
                    LucideIcon("users", size: 36)
                        .foregroundStyle(NETRTheme.muted)
                }

                VStack(spacing: 8) {
                    Text("No Crews Yet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(NETRTheme.text)

                    Text("Create or join a crew to connect with your ballers")
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                HStack(spacing: 12) {
                    Button {
                        showCreate = true
                    } label: {
                        Text("Create Crew")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(NETRTheme.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(PressButtonStyle())

                    Button {
                        showJoin = true
                    } label: {
                        Text("Join Crew")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(NETRTheme.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.top, 4)
            }

            Spacer()
        }
    }

    // MARK: - Crew List

    private var crewList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.myCrews) { crew in
                        crewRow(crew: crew)
                        if crew.id != viewModel.myCrews.last?.id {
                            NETRTheme.border.frame(height: 1)
                                .padding(.leading, 20)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 20)
            }

            Spacer()

            // Bottom Bar
            bottomBar
        }
    }

    @ViewBuilder
    private func crewRow(crew: MyCrew) -> some View {
        Button {
            selectedCrew = crew
        } label: {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(0.12))
                        .frame(width: 48, height: 48)
                    LucideIcon(crew.icon, size: 22)
                        .foregroundStyle(NETRTheme.neonGreen)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(crew.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(NETRTheme.text)

                        if crew.isPrimary {
                            Text("PRIMARY")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(NETRTheme.gold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(NETRTheme.gold.opacity(0.12), in: .rect(cornerRadius: 4))
                        }
                    }

                    HStack(spacing: 4) {
                        LucideIcon("users", size: 11)
                            .foregroundStyle(NETRTheme.subtext)
                        Text("Crew")
                            .font(.system(size: 12))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }

                Spacer()

                LucideIcon("chevron-right", size: 16)
                    .foregroundStyle(NETRTheme.muted)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
        }
        .buttonStyle(PressButtonStyle())
        .contextMenu {
            if !crew.isPrimary {
                Button {
                    Task { try? await viewModel.setPrimary(crewId: crew.id) }
                } label: {
                    Label("Set as Primary", systemImage: "star.fill")
                }
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            NETRTheme.border.frame(height: 1)

            HStack(spacing: 12) {
                Button {
                    showCreate = true
                } label: {
                    HStack(spacing: 6) {
                        LucideIcon("plus", size: 14)
                        Text("Create Crew")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(atCapacity ? NETRTheme.muted : NETRTheme.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(atCapacity ? NETRTheme.border.opacity(0.5) : NETRTheme.border, lineWidth: 1))
                }
                .disabled(atCapacity)
                .buttonStyle(PressButtonStyle())

                Button {
                    showJoin = true
                } label: {
                    HStack(spacing: 6) {
                        LucideIcon("log-in", size: 14)
                        Text("Join Crew")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(atCapacity ? NETRTheme.muted : NETRTheme.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(atCapacity ? NETRTheme.border.opacity(0.5) : NETRTheme.border, lineWidth: 1))
                }
                .disabled(atCapacity)
                .buttonStyle(PressButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if atCapacity {
                Text("You've reached the maximum of 5 crews")
                    .font(.system(size: 11))
                    .foregroundStyle(NETRTheme.muted)
                    .padding(.bottom, 8)
            }
        }
        .background(NETRTheme.background)
    }
}
