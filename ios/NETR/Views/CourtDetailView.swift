import SwiftUI
import PhotosUI
import Supabase

struct CourtDetailView: View {
    let court: Court
    @Bindable var viewModel: CourtsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int = 0
    @State private var weatherService = WeatherService.shared
    @State private var courtPhotos: [CourtPhoto] = []
    @State private var isLoadingPhotos: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingPhoto: Bool = false
    @State private var fullScreenPhotoUrl: String?

    // Games at this court
    @State private var courtLiveGames: [NearbyGame] = []
    @State private var courtScheduledGames: [NearbyGame] = []
    @State private var isLoadingGames: Bool = false
    @State private var courtJoinedGameIds: Set<String> = []
    @State private var courtLobbyVM = GameViewModel()
    @State private var courtJoinVM = JoinGameViewModel()
    @State private var showCourtLobby: Bool = false
    @State private var showCreateGameFromCourt: Bool = false

    private var distance: String { viewModel.distanceString(for: court) }
    private var isFav: Bool { viewModel.isFavorite(court.id) }
    private var isHome: Bool { viewModel.isHomeCourt(court.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    courtHeader
                    weatherBadge
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
                        LucideIcon("x-circle")
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomCTA
            }
        }
        .sheet(isPresented: $showCourtLobby) {
            GameLobbyView(viewModel: courtLobbyVM, onDismiss: { showCourtLobby = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCreateGameFromCourt) {
            CreateGameView(viewModel: viewModel, preselectedCourt: court)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(NETRTheme.surface)
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
                            LucideIcon("badge-check")
                                .foregroundStyle(NETRTheme.blue)
                        } else {
                            HStack(spacing: 4) {
                                LucideIcon("clock", size: 11)
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
                        LucideIcon("map-pin", size: 11)
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
                        LucideIcon("home")
                            .foregroundStyle(NETRTheme.neonGreen)
                        Text("HOME")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                }
            }

            HStack(spacing: 16) {
                StatPill(label: "Surface", value: court.surfaceType.rawValue, icon: "layout-grid")
                StatPill(label: "Distance", value: distance, icon: "map-pin")
            }
        }
        .padding(16)
    }

    private var weatherBadge: some View {
        Group {
            if let w = weatherService.weather[court.id] {
                HStack(spacing: 10) {
                    Text("\(w.emoji) \(Int(w.temperatureF))°F")
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(NETRTheme.text)

                    Text("·")
                        .foregroundStyle(NETRTheme.muted)

                    Text(w.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.subtext)

                    if w.showWind {
                        Text("·")
                            .foregroundStyle(NETRTheme.muted)
                        Text("💨 \(Int(w.windSpeedMph))mph")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(NETRTheme.subtext)
                    }

                    Spacer()

                    Text(w.condition)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(w.condition == "Good conditions" ? NETRTheme.neonGreen : NETRTheme.gold)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.3), value: weatherService.weather[court.id] != nil)
        .onAppear {
            weatherService.fetch(courtId: court.id, lat: court.lat, lng: court.lng)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Favorite — uses the isolated FavoriteButton internally
            Button {
                Task { await viewModel.toggleFavorite(courtId: court.id) }
            } label: {
                HStack(spacing: 6) {
                    LucideIcon(isFav ? "heart" : "heart")
                        .foregroundStyle(isFav ? NETRTheme.red : NETRTheme.text)
                    Text(isFav ? "Favorited" : "Favorite")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(isFav ? NETRTheme.red.opacity(0.06) : NETRTheme.card, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isFav ? NETRTheme.red.opacity(0.3) : NETRTheme.border, lineWidth: 1))
                .contentShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.selection, trigger: isFav)

            // Home court
            Button {
                Task { await viewModel.setHomeCourt(courtId: court.id) }
            } label: {
                HStack(spacing: 6) {
                    LucideIcon(isHome ? "home" : "home")
                        .foregroundStyle(isHome ? NETRTheme.neonGreen : NETRTheme.text)
                    Text(isHome ? "Home Court" : "Set Home")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NETRTheme.text)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .background(isHome ? NETRTheme.neonGreen.opacity(0.08) : NETRTheme.card, in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(isHome ? NETRTheme.neonGreen.opacity(0.3) : NETRTheme.border, lineWidth: 1))
                .contentShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: isHome)
        }
        .padding(.horizontal, 16)
    }

    private var chipDetails: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                DetailChip(icon: "layout-grid", text: court.surfaceType.rawValue)
                DetailChip(icon: court.lights ? "lightbulb" : "lightbulb", text: court.lights ? "Lights" : "No Lights")
                DetailChip(icon: court.indoor ? "building-2" : "sun", text: court.indoor ? "Indoor" : "Outdoor")
                DetailChip(icon: "circle-dot", text: court.fullCourt ? "Full Court" : "Half Court")
            }
        }
        .contentMargins(.horizontal, 16)
        .scrollIndicators(.hidden)
        .padding(.top, 14)
    }

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(Array(["GAMES", "INFO", "TAGS", "PHOTOS"].enumerated()), id: \.offset) { idx, title in
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
        case 0: gamesTab
        case 1: infoTab
        case 2: tagsTab
        case 3: photosTab
        default: EmptyView()
        }
    }

    private var gamesTab: some View {
        VStack(alignment: .leading, spacing: 20) {
            if isLoadingGames {
                HStack {
                    Spacer()
                    ProgressView().tint(NETRTheme.neonGreen)
                    Spacer()
                }
                .padding(.vertical, 40)
            } else if courtLiveGames.isEmpty && courtScheduledGames.isEmpty {
                VStack(spacing: 12) {
                    LucideIcon("circle-dot", size: 32)
                        .foregroundStyle(NETRTheme.muted)
                    Text("No games at this court")
                        .font(.system(.subheadline, design: .default, weight: .bold))
                        .foregroundStyle(NETRTheme.text)
                    Text("Be the first to start or schedule a game here.")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.muted)
                        .multilineTextAlignment(.center)
                    Button {
                        showCreateGameFromCourt = true
                    } label: {
                        Text("Create a Game")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                if !courtLiveGames.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(NETRTheme.neonGreen)
                                .frame(width: 7, height: 7)
                                .shadow(color: NETRTheme.neonGreen.opacity(0.7), radius: 4)
                            Text("LIVE NOW")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NETRTheme.subtext)
                                .tracking(1.3)
                        }
                        ForEach(courtLiveGames) { game in
                            courtGameCard(game)
                        }
                    }
                }

                if !courtScheduledGames.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(NETRTheme.gold)
                            Text("UPCOMING")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NETRTheme.subtext)
                                .tracking(1.3)
                        }
                        ForEach(courtScheduledGames) { game in
                            courtGameCard(game)
                        }
                    }
                }
            }
        }
        .padding(16)
        .task {
            await loadCourtGames()
        }
    }

    private func courtGameCard(_ game: NearbyGame) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(game.isScheduled ? NETRTheme.gold.opacity(0.12) : NETRTheme.neonGreen.opacity(0.12))
                        .frame(width: 42, height: 42)
                    if game.isScheduled {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(NETRTheme.gold)
                    } else {
                        LucideIcon("circle-dot", size: 18)
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        if let fmt = game.format {
                            Text(fmt)
                                .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                                .foregroundStyle(NETRTheme.text)
                        }
                        if game.isScheduled {
                            Text("SCHEDULED")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(NETRTheme.gold)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(NETRTheme.gold.opacity(0.12), in: Capsule())
                        } else {
                            Text("LIVE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(NETRTheme.neonGreen)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(NETRTheme.neonGreen.opacity(0.12), in: Capsule())
                        }
                    }
                    HStack(spacing: 4) {
                        Text(game.startedAgo)
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                        Text("·")
                            .foregroundStyle(NETRTheme.muted)
                        Text("by \(game.hostName)")
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)

            if courtJoinedGameIds.contains(game.id) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                    Text("JOINED")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(NETRTheme.neonGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(NETRTheme.neonGreen.opacity(0.08), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1))
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            } else {
                Button {
                    Task {
                        if let joined = await courtJoinVM.joinGameDirectly(game) {
                            courtLobbyVM.game = joined
                            await courtLobbyVM.loadPlayers(gameId: joined.id)
                            await courtLobbyVM.subscribeToLobby(gameId: joined.id)
                            courtJoinedGameIds.insert(game.id)
                            showCourtLobby = true
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        LucideIcon("arrow-right-circle", size: 15)
                        Text("Join This Run")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 10))
                }
                .buttonStyle(PressButtonStyle())
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(NETRTheme.card)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
        .clipShape(.rect(cornerRadius: 14))
    }

    private func loadCourtGames() async {
        isLoadingGames = true
        let client = SupabaseManager.shared.client

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let cutoff = fmt.string(from: Date().addingTimeInterval(-4 * 3600))

        do {
            let live: [NearbyGame] = try await client
                .from("games")
                .select("""
                    id, join_code, created_at, format, max_players, scheduled_at,
                    courts(name, neighborhood, lat, lng),
                    host:profiles!games_host_id_fkey(full_name, username)
                """)
                .in("status", values: ["active", "waiting"])
                .eq("court_id", value: court.id)
                .gte("created_at", value: cutoff)
                .order("created_at", ascending: false)
                .execute()
                .value

            let nowStr = fmt.string(from: Date())
            let scheduled: [NearbyGame] = try await client
                .from("games")
                .select("""
                    id, join_code, created_at, format, max_players, scheduled_at,
                    courts(name, neighborhood, lat, lng),
                    host:profiles!games_host_id_fkey(full_name, username)
                """)
                .gt("scheduled_at", value: nowStr)
                .in("status", values: ["scheduled", "waiting", "active"])
                .eq("court_id", value: court.id)
                .order("scheduled_at", ascending: true)
                .execute()
                .value

            courtLiveGames = live
            courtScheduledGames = scheduled

            if let userId = SupabaseManager.shared.session?.user.id.uuidString {
                nonisolated struct JoinedId: Decodable, Sendable {
                    let gameId: String
                    nonisolated enum CodingKeys: String, CodingKey { case gameId = "game_id" }
                }
                let rows: [JoinedId] = try await client
                    .from("game_players")
                    .select("game_id")
                    .eq("user_id", value: userId)
                    .execute()
                    .value
                courtJoinedGameIds = Set(rows.map { $0.gameId })
            }
        } catch {
            print("Load court games error: \(error)")
        }
        isLoadingGames = false
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

    private var photosTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PHOTOS")
                    .font(.system(.caption, design: .default, weight: .bold).width(.compressed))
                    .tracking(1)
                    .foregroundStyle(NETRTheme.subtext)

                Spacer()

                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 4) {
                        if isUploadingPhoto {
                            ProgressView()
                                .tint(NETRTheme.neonGreen)
                                .scaleEffect(0.7)
                        } else {
                            LucideIcon("camera", size: 12)
                        }
                        Text("Add Photo")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(NETRTheme.neonGreen)
                }
                .disabled(isUploadingPhoto)
            }

            if isLoadingPhotos {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(NETRTheme.neonGreen)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if courtPhotos.isEmpty {
                VStack(spacing: 8) {
                    LucideIcon("image", size: 28)
                        .foregroundStyle(NETRTheme.muted)
                    Text("No photos yet")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                    Text("Be the first to share a photo of this court")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(courtPhotos) { photo in
                            courtPhotoCard(photo)
                        }
                    }
                }
                .contentMargins(.horizontal, 0)
                .scrollIndicators(.hidden)
            }
        }
        .padding(16)
        .onChange(of: selectedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadCourtPhoto(image: image)
                }
                selectedPhotoItem = nil
            }
        }
        .task {
            await fetchCourtPhotos()
        }
        .fullScreenCover(item: Binding(
            get: { fullScreenPhotoUrl.map { IdentifiableURL(url: $0) } },
            set: { fullScreenPhotoUrl = $0?.url }
        )) { item in
            CourtPhotoFullScreen(url: item.url)
        }
    }

    private func courtPhotoCard(_ photo: CourtPhoto) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: photo.photoUrl)) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 150)
                        .clipShape(.rect(cornerRadius: 10))
                        .onTapGesture {
                            fullScreenPhotoUrl = photo.photoUrl
                        }
                } else if phase.error != nil {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(NETRTheme.card)
                        .frame(width: 200, height: 150)
                        .overlay {
                            LucideIcon("image-off", size: 20)
                                .foregroundStyle(NETRTheme.muted)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(NETRTheme.card)
                        .frame(width: 200, height: 150)
                        .overlay {
                            ProgressView()
                                .tint(NETRTheme.neonGreen)
                        }
                }
            }

            HStack(spacing: 4) {
                Text(photo.uploader?.displayName ?? "Player")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(NETRTheme.text)
                Text("·")
                    .foregroundStyle(NETRTheme.muted)
                Text(photo.createdAt.relativeTimeFromISO)
                    .font(.caption2)
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
    }

    private func fetchCourtPhotos() async {
        isLoadingPhotos = true
        let client = SupabaseManager.shared.client
        do {
            let photos: [CourtPhoto] = try await client
                .from("court_photos")
                .select("id, court_id, user_id, photo_url, created_at, profiles(id, full_name, username, avatar_url, netr_score, vibe_score)")
                .eq("court_id", value: court.id)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            courtPhotos = photos
        } catch {
            print("Fetch court photos error: \(error)")
        }
        isLoadingPhotos = false
    }

    private func uploadCourtPhoto(image: UIImage) async {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        isUploadingPhoto = true

        let client = SupabaseManager.shared.client
        let timestamp = Int(Date().timeIntervalSince1970)
        let path = "\(court.id)/\(userId)/\(timestamp).jpg"

        do {
            try await client.storage
                .from("court-photos")
                .upload(path, data: data, options: FileOptions(
                    cacheControl: "3600", contentType: "image/jpeg", upsert: true
                ))
            let url = try client.storage
                .from("court-photos")
                .getPublicURL(path: path)

            let payload = CreateCourtPhotoPayload(
                courtId: court.id,
                userId: userId,
                photoUrl: url.absoluteString
            )

            let created: CourtPhoto = try await client
                .from("court_photos")
                .insert(payload)
                .select("id, court_id, user_id, photo_url, created_at, profiles(id, full_name, username, avatar_url, netr_score, vibe_score)")
                .single()
                .execute()
                .value

            courtPhotos.insert(created, at: 0)
        } catch {
            print("Court photo upload error: \(error)")
        }
        isUploadingPhoto = false
    }

    private var bottomCTA: some View {
        HStack(spacing: 12) {
            Button {
                showCreateGameFromCourt = true
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
            LucideIcon(icon, size: 10)
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
            LucideIcon(icon, size: 12)
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

private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: String
}

struct CourtPhotoFullScreen: View {
    let url: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .shadow(radius: 4)
            }
            .padding(20)
        }
    }
}
