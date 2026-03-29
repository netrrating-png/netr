import SwiftUI
import MapKit

struct CourtsView: View {
    @Bindable var viewModel: CourtsViewModel
    @State private var selectedCourt: Court?
    @State private var showAddCourt: Bool = false
    @State private var showCreateGame: Bool = false
    @State private var showJoinGame: Bool = false
    @State private var showFullScreenMap: Bool = false
    @State private var showFilterSheet: Bool = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasSetInitialLocation: Bool = false

    private let filters: [(label: String, icon: String)] = [
        ("Favorites", "heart"),
        ("Live Now", "circle-dot"),
        ("Lights", "sun"),
        ("Indoor", "warehouse"),
        ("Verified", "shield-check")
    ]

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    mapSection
                    searchSection
                    filterChips
                    resultsHeader
                    courtsList
                }
            }
            .scrollIndicators(.hidden)
            .dismissKeyboardOnScroll()

            if showFullScreenMap {
                fullScreenMapOverlay
                    .transition(.opacity)
            }
        }
        .task {
            viewModel.requestLocation()
            await viewModel.loadCourts()
            await viewModel.loadFavorites()
            await viewModel.loadLiveCourts()
        }
        .onChange(of: viewModel.userLocation?.latitude) { _, _ in
            guard !hasSetInitialLocation, let loc = viewModel.userLocation else { return }
            hasSetInitialLocation = true
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                ))
            }
        }
        .sheet(item: $selectedCourt) { court in
            CourtDetailView(court: court, viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
        }
        .sheet(isPresented: $showFilterSheet) {
            CourtFilterSheet(viewModel: viewModel, isPresented: $showFilterSheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(NETRTheme.surface)
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showAddCourt) {
            AddCourtView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
        }
        .sheet(isPresented: $showCreateGame) {
            CreateGameView(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
        }
        .sheet(isPresented: $showJoinGame) {
            JoinGameView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    LucideIcon("map-pin")
                        .foregroundStyle(NETRTheme.neonGreen)
                    Text(viewModel.userLocation != nil ? "Near You" : "New York, NY")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.subtext)
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(NETRTheme.neonGreen)
                        .frame(width: 6, height: 6)
                    Text("GPS On")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(NETRTheme.neonGreen)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(NETRTheme.neonGreen.opacity(0.1), in: Capsule())
            }

            Text(viewModel.isDefaultView
                 ? (viewModel.favoriteCourtIds.isEmpty && viewModel.homeCourtId == nil ? "NEARBY" : "MY COURTS")
                 : "COURTS")
                .font(NETRTheme.headingFont(size: .title2))
                .foregroundStyle(NETRTheme.text)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var mapSection: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(viewModel.filteredCourts + viewModel.nearbyCourtsInDefaultView) { court in
                    Annotation(court.name, coordinate: court.coordinate) {
                        Button {
                            selectedCourt = court
                        } label: {
                            CourtMapPin(court: court, isHomeCourt: viewModel.isHomeCourt(court.id))
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls { MapUserLocationButton() }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showFullScreenMap = true
                }
            } label: {
                LucideIcon("maximize-2", size: 14)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 32, height: 32)
                    .background(NETRTheme.card.opacity(0.9), in: .rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(NETRTheme.border, lineWidth: 1))
            }
            .padding(8)
        }
        .frame(height: 220)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NETRTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var fullScreenMapOverlay: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition) {
                UserAnnotation()
                ForEach(viewModel.filteredCourts + viewModel.nearbyCourtsInDefaultView) { court in
                    Annotation(court.name, coordinate: court.coordinate) {
                        Button {
                            selectedCourt = court
                        } label: {
                            CourtMapPin(court: court, isHomeCourt: viewModel.isHomeCourt(court.id))
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .mapControls { MapUserLocationButton() }
            .ignoresSafeArea()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showFullScreenMap = false
                }
            } label: {
                LucideIcon("x", size: 16)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 40, height: 40)
                    .background(NETRTheme.card.opacity(0.9), in: Circle())
                    .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 8)
            }
            .padding(.top, 56)
            .padding(.trailing, 16)
        }
    }

    private var searchSection: some View {
        HStack(spacing: 8) {
            // Search field
            HStack(spacing: 10) {
                LucideIcon("search")
                    .foregroundStyle(NETRTheme.subtext)
                TextField("Search courts, neighborhoods, zip codes...", text: $viewModel.searchText)
                    .foregroundStyle(NETRTheme.text)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onChange(of: viewModel.searchText) { _, newValue in
                        if !newValue.isEmpty { viewModel.isExploring = true }
                    }
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        if viewModel.selectedFilter == "All" {
                            viewModel.isExploring = false
                        }
                    } label: {
                        LucideIcon("x-circle")
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
            .padding(12)
            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))

            // Filter button
            Button {
                showFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    LucideIcon("sliders-horizontal", size: 18)
                        .foregroundStyle(viewModel.hasActiveFilters ? NETRTheme.neonGreen : NETRTheme.subtext)
                        .frame(width: 44, height: 44)
                        .background(
                            viewModel.hasActiveFilters
                                ? NETRTheme.neonGreen.opacity(0.12)
                                : NETRTheme.card,
                            in: .rect(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    viewModel.hasActiveFilters
                                        ? NETRTheme.neonGreen.opacity(0.4)
                                        : NETRTheme.border,
                                    lineWidth: 1
                                )
                        )
                    // Active badge dot
                    if viewModel.hasActiveFilters {
                        Circle()
                            .fill(NETRTheme.neonGreen)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(PressButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(filters, id: \.label) { filter in
                    let isSelected = viewModel.selectedFilter == filter.label && !viewModel.isDefaultView
                    Button {
                        withAnimation(.snappy) {
                            if isSelected {
                                // Tap active chip → reset to My Courts
                                viewModel.resetToDefaultView()
                            } else {
                                viewModel.isExploring = true
                                viewModel.selectedFilter = filter.label
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            LucideIcon(filter.icon, size: 11)
                            Text(filter.label)
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
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .padding(.top, 10)
    }

    private var resultsHeader: some View {
        HStack {
            let filtered = viewModel.filteredCourts
            let resultsLabel: String = {
                if viewModel.isDefaultView {
                    let favCount = viewModel.favoriteCourtIds.count
                    let hasHome = viewModel.homeCourtId != nil
                    let nearbyCount = viewModel.nearbyCourtsInDefaultView.count
                    if favCount == 0 && !hasHome {
                        return nearbyCount > 0
                            ? "\(nearbyCount) courts within 5 mi"
                            : (viewModel.userLocation != nil ? "No courts within 5 mi" : "No courts saved yet")
                    }
                    var parts: [String] = []
                    if hasHome { parts.append("1 home court") }
                    let favOnly = viewModel.favoriteCourtIds.filter { $0 != viewModel.homeCourtId }.count
                    if favOnly > 0 { parts.append("\(favOnly) favorite\(favOnly == 1 ? "" : "s")") }
                    if nearbyCount > 0 { parts.append("\(nearbyCount) nearby") }
                    return parts.joined(separator: " · ")
                } else {
                    let activeCount = filtered.filter { $0.verified }.count
                    return "\(filtered.count) courts · \(activeCount) verified"
                }
            }()
            Text(resultsLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(NETRTheme.subtext)

            Spacer()

            Button {
                showAddCourt = true
            } label: {
                HStack(spacing: 4) {
                    LucideIcon("plus", size: 12)
                    Text("Court")
                }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NETRTheme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(NETRTheme.card, in: Capsule())
                    .overlay(Capsule().stroke(NETRTheme.border, lineWidth: 1))
            }

            Button {
                showJoinGame = true
            } label: {
                HStack(spacing: 4) {
                    LucideIcon("user-plus", size: 12)
                    Text("Join")
                }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(NETRTheme.neonGreen.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1))
            }

            Button {
                showCreateGame = true
            } label: {
                HStack(spacing: 4) {
                    LucideIcon("plus", size: 12)
                    Text("Game")
                }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(NETRTheme.background)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(NETRTheme.neonGreen, in: Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func courtSectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            LucideIcon(icon, size: 10)
                .foregroundStyle(NETRTheme.subtext)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(NETRTheme.subtext)
                .kerning(0.8)
            Rectangle()
                .fill(NETRTheme.border)
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    private var courtsList: some View {
        LazyVStack(spacing: 12) {
            if viewModel.isLoading && viewModel.courts.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(NETRTheme.neonGreen)
                    Text("Loading courts...")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                }
                .padding(.vertical, 40)
            } else if viewModel.isDefaultView {
                let saved = viewModel.filteredCourts
                let nearby = viewModel.nearbyCourtsInDefaultView
                if saved.isEmpty && nearby.isEmpty {
                    VStack(spacing: 16) {
                        LucideIcon(viewModel.userLocation != nil ? "map-pin-off" : "map-pin", size: 36)
                            .foregroundStyle(NETRTheme.muted)
                        Text(viewModel.userLocation != nil ? "No courts within 5 miles" : "Finding courts near you...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NETRTheme.text)
                        Text(viewModel.userLocation != nil
                             ? "Try browsing all courts or add one nearby."
                             : "Enable location or browse all courts.")
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        Button {
                            withAnimation(.snappy) { viewModel.isExploring = true }
                        } label: {
                            HStack(spacing: 6) {
                                LucideIcon("search", size: 13)
                                Text("Browse All Courts")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NETRTheme.background)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(NETRTheme.neonGreen, in: Capsule())
                        }
                        .buttonStyle(PressButtonStyle())
                    }
                    .padding(.vertical, 40)
                } else {
                    if !saved.isEmpty {
                        courtSectionHeader("MY COURTS", icon: "heart")
                        ForEach(saved) { court in
                            CourtCardView(
                                court: court,
                                distance: viewModel.distanceString(for: court),
                                isFavorite: viewModel.isFavorite(court.id),
                                isHomeCourt: viewModel.isHomeCourt(court.id),
                                onFavoriteToggle: {
                                    Task { await viewModel.toggleFavorite(courtId: court.id) }
                                },
                                onTap: { selectedCourt = court }
                            )
                        }
                    }
                    if !nearby.isEmpty {
                        courtSectionHeader("NEARBY · 5 MI", icon: "map-pin")
                        ForEach(nearby) { court in
                            CourtCardView(
                                court: court,
                                distance: viewModel.distanceString(for: court),
                                isFavorite: viewModel.isFavorite(court.id),
                                isHomeCourt: viewModel.isHomeCourt(court.id),
                                onFavoriteToggle: {
                                    Task { await viewModel.toggleFavorite(courtId: court.id) }
                                },
                                onTap: { selectedCourt = court }
                            )
                        }
                    }
                }
            } else if viewModel.filteredCourts.isEmpty && viewModel.selectedFilter == "Favorites" {
                VStack(spacing: 12) {
                    LucideIcon("heart", size: 28)
                        .foregroundStyle(NETRTheme.subtext)
                    Text("No favorites yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                    Text("Tap \u{2665} on any court to save it here")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                }
                .padding(.vertical, 40)
            } else if viewModel.filteredCourts.isEmpty {
                VStack(spacing: 12) {
                    LucideIcon("map-pin-off", size: 28)
                        .foregroundStyle(NETRTheme.subtext)
                    Text(viewModel.searchText.isEmpty ? "No courts found" : "No courts match \"\(viewModel.searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                    Button {
                        showAddCourt = true
                    } label: {
                        Text("+ Add a Court")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                }
                .padding(.vertical, 40)
            } else {
                ForEach(viewModel.filteredCourts) { court in
                    CourtCardView(
                        court: court,
                        distance: viewModel.distanceString(for: court),
                        isFavorite: viewModel.isFavorite(court.id),
                        isHomeCourt: viewModel.isHomeCourt(court.id),
                        onFavoriteToggle: {
                            Task { await viewModel.toggleFavorite(courtId: court.id) }
                        },
                        onTap: { selectedCourt = court }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 100)
    }
}

struct CourtMapPin: View {
    let court: Court
    var isHomeCourt: Bool = false

    var pinColor: Color {
        if !court.verified { return NETRTheme.gold }
        return NETRTheme.blue
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: 28, height: 28)

            if isHomeCourt {
                LucideIcon("house", size: 12)
                    .foregroundStyle(.white)
            } else {
                LucideIcon("circle-dot", size: 12)
                    .foregroundStyle(.white)
            }
        }
    }
}
