import SwiftUI
import MapKit

struct CourtsView: View {
    @Bindable var viewModel: CourtsViewModel
    @State private var selectedCourt: Court?
    @State private var showAddCourt: Bool = false
    @State private var showCreateGame: Bool = false
    @State private var showJoinGame: Bool = false
    @State private var isMapExpanded: Bool = false
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 40.758, longitude: -73.955),
            span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
        )
    )
    @Namespace private var mapNamespace

    private let filters = ["All", "Live Now", "Full Court", "Lights", "Indoor", "Verified"]

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            if isMapExpanded {
                expandedMapView
            } else {
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
        Map(position: $cameraPosition) {
            ForEach(viewModel.filteredCourts) { court in
                Annotation(court.name, coordinate: court.coordinate) {
                    Button {
                        selectedCourt = court
                    } label: {
                        CourtMapPin(court: court)
                    }
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 220)
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(NETRTheme.border, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isMapExpanded = true
                }
            } label: {
                LucideIcon("maximize-2", size: 14)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
            }
            .padding(8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var expandedMapView: some View {
        ZStack(alignment: .topTrailing) {
            Map(position: $cameraPosition) {
                ForEach(viewModel.filteredCourts) { court in
                    Annotation(court.name, coordinate: court.coordinate) {
                        Button {
                            selectedCourt = court
                        } label: {
                            CourtMapPin(court: court)
                        }
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .ignoresSafeArea()

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isMapExpanded = false
                }
            } label: {
                LucideIcon("x", size: 16)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
    }

    private var searchSection: some View {
        HStack(spacing: 10) {
            LucideIcon("search")
                .foregroundStyle(NETRTheme.subtext)
            TextField("Search courts, neighborhoods, cities...", text: $viewModel.searchText)
                .foregroundStyle(NETRTheme.text)
                .autocorrectionDisabled()
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
                    Text(viewModel.searchText.isEmpty ? "No courts found" : "No courts found for \"\(viewModel.searchText)\"")
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
                        onFavoriteToggle: {
                            Task { await viewModel.toggleFavorite(courtId: court.id) }
                        }
                    )
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture().onEnded {
                        selectedCourt = court
                    })
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

    var pinColor: Color {
        if !court.verified { return NETRTheme.gold }
        return NETRTheme.blue
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(pinColor)
                .frame(width: 28, height: 28)

            LucideIcon("circle-dot", size: 12)
                .foregroundStyle(.white)
        }
    }
}
