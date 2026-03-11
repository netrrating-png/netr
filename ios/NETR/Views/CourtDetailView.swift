import SwiftUI

struct CourtDetailView: View {
    let court: Court
    @Bindable var viewModel: CourtsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int = 0

    private var distance: String { viewModel.distanceString(for: court) }
    private var isFav: Bool { viewModel.isFavorite(court.id) }
    private var isHome: Bool { viewModel.isHomeCourt(court.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    courtHeader
                    actionButtons
                    chipDetails
                    tabSelector
                    tabContent
                }
            }
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomCTA
            }
        }
    }

    private var courtHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(court.name)
                            .font(.system(.title2, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NETRTheme.text)

                        if court.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(NETRTheme.blue)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption2)
                                Text("PENDING")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(NETRTheme.gold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(NETRTheme.gold.opacity(0.12), in: Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                            .foregroundStyle(NETRTheme.subtext)
                        Text(court.address)
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    HStack(spacing: 6) {
                        Text(court.neighborhood)
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                        Text("·")
                            .foregroundStyle(NETRTheme.muted)
                        Text(distance)
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }

                Spacer()

                if isHome {
                    VStack(spacing: 2) {
                        Image(systemName: "house.fill")
                            .foregroundStyle(NETRTheme.neonGreen)
                        Text("HOME")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                }
            }

            HStack(spacing: 16) {
                StatPill(label: "Cosigns", value: "\(court.cosignCount)", icon: "hand.thumbsup.fill")
                StatPill(label: "Surface", value: court.surfaceType.rawValue, icon: "square.grid.2x2.fill")
                StatPill(label: "Distance", value: distance, icon: "location.fill")
            }
        }
        .padding(16)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleFavorite(courtId: court.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .foregroundStyle(isFav ? NETRTheme.red : NETRTheme.text)
                    Text(isFav ? "Favorited" : "Favorite")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(NETRTheme.card, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isFav ? NETRTheme.red.opacity(0.3) : NETRTheme.border, lineWidth: 1))
            }
            .sensoryFeedback(.selection, trigger: isFav)

            Button {
                Task { await viewModel.setHomeCourt(courtId: court.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isHome ? "house.fill" : "house")
                        .foregroundStyle(isHome ? NETRTheme.neonGreen : NETRTheme.text)
                    Text(isHome ? "Home Court" : "Set Home")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isHome ? NETRTheme.neonGreen.opacity(0.08) : NETRTheme.card, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isHome ? NETRTheme.neonGreen.opacity(0.3) : NETRTheme.border, lineWidth: 1))
            }
            .sensoryFeedback(.success, trigger: isHome)

            Button {
                Task { await viewModel.cosignCourt(courtId: court.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "hand.thumbsup.fill")
                        .foregroundStyle(NETRTheme.neonGreen)
                    Text("Cosign")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(NETRTheme.card, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.border, lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
    }

    private var chipDetails: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                DetailChip(icon: "square.grid.2x2", text: court.surfaceType.rawValue)
                DetailChip(icon: court.lights ? "lightbulb.fill" : "lightbulb.slash", text: court.lights ? "Lights" : "No Lights")
                DetailChip(icon: court.indoor ? "building.2" : "sun.max", text: court.indoor ? "Indoor" : "Outdoor")
                DetailChip(icon: "basketball", text: court.fullCourt ? "Full Court" : "Half Court")
            }
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .padding(.top, 14)
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(["INFO", "TAGS"].enumerated()), id: \.offset) { idx, title in
                Button {
                    withAnimation(.snappy) { selectedTab = idx }
                } label: {
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                            .tracking(1)
                            .foregroundStyle(selectedTab == idx ? NETRTheme.neonGreen : NETRTheme.subtext)

                        Rectangle()
                            .fill(selectedTab == idx ? NETRTheme.neonGreen : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case 0: infoTab
        case 1: tagsTab
        default: EmptyView()
        }
    }

    private var infoTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("DETAILS")
                    .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(NETRTheme.subtext)

                InfoRow(label: "Surface", value: court.surfaceType.rawValue)
                InfoRow(label: "Lights", value: court.lights ? "Yes" : "No")
                InfoRow(label: "Indoor", value: court.indoor ? "Yes" : "No")
                InfoRow(label: "Full Court", value: court.fullCourt ? "Yes" : "No")
                InfoRow(label: "City", value: court.city)
                InfoRow(label: "Address", value: court.address)
                InfoRow(label: "Cosigns", value: "\(court.cosignCount)")
                InfoRow(label: "Verified", value: court.verified ? "Yes" : "Pending")
            }
        }
        .padding(16)
    }

    private var tagsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TAGS")
                .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                .tracking(1)
                .foregroundStyle(NETRTheme.subtext)

            if let tags = court.tags, !tags.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NETRTheme.text)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(NETRTheme.card, in: Capsule())
                            .overlay(Capsule().stroke(NETRTheme.border, lineWidth: 1))
                    }
                }
            } else {
                Text("No tags yet")
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
                    .padding(.vertical, 20)
            }
        }
        .padding(16)
    }

    private var bottomCTA: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Text("START GAME HERE")
                    .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(NETRTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
            }
            .buttonStyle(PressButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }
}

struct DetailChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(NETRTheme.neonGreen)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NETRTheme.text)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(NETRTheme.card, in: Capsule())
        .overlay(Capsule().stroke(NETRTheme.border, lineWidth: 1))
    }
}

struct StatPill: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(NETRTheme.neonGreen)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NETRTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(NETRTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(NETRTheme.card, in: .rect(cornerRadius: 10))
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(NETRTheme.subtext)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(NETRTheme.text)
        }
        .padding(.vertical, 4)
    }
}
