import SwiftUI
import MapKit

struct CourtsView: View {
    @Bindable var viewModel: CourtsViewModel
    @State private var selectedCourt: Court?
    @State private var showAddCourt: Bool = false
    @State private var showCreateGame: Bool = false
    @State private var showJoinGame: Bool = false
    @State private var showFullScreenMap: Bool = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.758, longitude: -73.955),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )

    private let filters = ["All", "Live Now", "Full Court", "Lights", "Indoor", "Verified"]

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    mapSection
                    searchSection
                    filterChips
                    neighborhoodChips
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
            if let loc = viewModel.userLocation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                ))
            }
        }
        .onChange(of: viewModel.selectedNeighborhood) { _, hood in
            if let hood {
                let hoodsFiltered = viewModel.courts.filter { $0.neighborhood == hood }
                if let first = hoodsFiltered.first {
                    withAnimation {
                        cameraPosition = .region(MKCoordinateRegion(
                            center: first.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                        ))
                    }
                }
            } else if let loc = viewModel.userLocation {
                withAnimation {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: loc,
                        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                    ))
                }
            }
        }
        .sheet(item: $selectedCourt) { court in
            CourtDetailView(court: court, viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
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

            Text("COURTS NEAR YOU")
                .font(NETRTheme.headingFont(size: .title2))
                .foregroundStyle(NETRTheme.text)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var mapSection: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition) {
                ForEach(viewModel.filteredCourts) { court in
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
                ForEach(viewModel.filteredCourts) { court in
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
        HStack(spacing: 10) {
            LucideIcon("search")
                .foregroundStyle(NETRTheme.subtext)
            TextField("Search courts, neighborhoods, zip codes...", text: $viewModel.searchText)
                .foregroundStyle(NETRTheme.text)
                .autocorrectionDisabled()
                .submitLabel(.done)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    LucideIcon("x-circle")
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
        .padding(12)
        .background(NETRTheme.card, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        withAnimation(.snappy) { viewModel.selectedFilter = filter }
                    } label: {
                        Text(filter)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(viewModel.selectedFilter == filter ? NETRTheme.background : NETRTheme.subtext)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                viewModel.selectedFilter == filter ? NETRTheme.neonGreen : NETRTheme.card,
                                in: Capsule()
                            )
                            .overlay(Capsule().stroke(viewModel.selectedFilter == filter ? Color.clear : NETRTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())
                }
            }
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .padding(.top, 12)
    }

    private var neighborhoodChips: some View {
        Group {
            if !viewModel.neighborhoods.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.neighborhoods, id: \.self) { hood in
                            Button {
                                withAnimation(.snappy) {
                                    if viewModel.selectedNeighborhood == hood {
                                        viewModel.selectedNeighborhood = nil
                                    } else {
                                        viewModel.selectedNeighborhood = hood
                                    }
                                }
                            } label: {
                                Text(hood)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(viewModel.selectedNeighborhood == hood ? NETRTheme.background : NETRTheme.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        viewModel.selectedNeighborhood == hood ? NETRTheme.blue : NETRTheme.surface,
                                        in: Capsule()
                                    )
                                    .overlay(Capsule().stroke(viewModel.selectedNeighborhood == hood ? Color.clear : NETRTheme.border, lineWidth: 1))
                            }
                            .buttonStyle(PressButtonStyle())
                        }
                    }
                }
                .contentMargins(.horizontal, 16)
                .scrollIndicators(.hidden)
                .padding(.top, 8)
            }
        }
    }

    private var resultsHeader: some View {
        HStack {
            let filtered = viewModel.filteredCourts
            let activeCount = filtered.filter { $0.verified }.count
            Text("\(viewModel.totalCourtCount) courts · \(activeCount) active")
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
                    Button {
                        selectedCourt = court
                    } label: {
                        CourtCardView(
                            court: court,
                            distance: viewModel.distanceString(for: court),
                            isFavorite: viewModel.isFavorite(court.id),
                            isHomeCourt: viewModel.isHomeCourt(court.id),
                            onFavoriteToggle: {
                                Task { await viewModel.toggleFavorite(courtId: court.id) }
                            }
                        )
                    }
                    .buttonStyle(PressButtonStyle())
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
                LucideIcon("home", size: 12)
                    .foregroundStyle(.white)
            } else {
                LucideIcon("circle-dot", size: 12)
                    .foregroundStyle(.white)
            }
        }
    }
}
