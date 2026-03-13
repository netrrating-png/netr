import SwiftUI
import AVFoundation
import CoreLocation
import Supabase

nonisolated struct NearbyGame: Identifiable, Decodable, Sendable {
    let id: String
    let join_code: String
    let created_at: String
    let format: String?
    let max_players: Int?
    let scheduled_at: String?

    let courts: CourtRef?
    let host: HostRef?

    nonisolated struct CourtRef: Decodable, Sendable {
        let name: String
        let neighborhood: String?
        let lat: Double?
        let lng: Double?
    }
    nonisolated struct HostRef: Decodable, Sendable {
        let full_name: String?
        let username: String?
    }

    var courtName: String { courts?.name ?? "Unknown Court" }
    var neighborhood: String { courts?.neighborhood ?? "" }
    var hostName: String {
        if let name = host?.full_name, !name.isEmpty { return name }
        if let username = host?.username { return "@\(username)" }
        return "Unknown"
    }
    var isScheduled: Bool { scheduled_at != nil }
    var scheduledDate: Date? {
        guard let str = scheduled_at else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }
    var startedAgo: String {
        if let scheduled = scheduledDate {
            let diff = scheduled.timeIntervalSinceNow
            if diff > 0 {
                let mins = Int(diff / 60)
                if mins < 60 { return "Starts in \(mins)m" }
                let hrs = mins / 60
                return "Starts in \(hrs)h \(mins % 60)m"
            }
        }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: created_at) else { return "" }
        let diff = Int(-date.timeIntervalSinceNow / 60)
        if diff < 1 { return "Just started" }
        if diff == 1 { return "1 min ago" }
        return "\(diff) min ago"
    }
    var distanceMiles: Double = 0.0
}

@Observable
final class JoinLocationManager: NSObject, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    var location: CLLocation? = nil

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    func request() {
        mgr.requestWhenInUseAuthorization()
        mgr.requestLocation()
    }
    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        Task { @MainActor in
            location = locs.first
        }
    }
    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError e: Error) {}
    nonisolated func locationManager(_ m: CLLocationManager, didChangeAuthorization s: CLAuthorizationStatus) {
        Task { @MainActor in
            if s == .authorizedWhenInUse || s == .authorizedAlways { mgr.requestLocation() }
        }
    }
}

@MainActor @Observable
class JoinGameViewModel {
    var nearbyGames: [NearbyGame] = []
    var isLoading = false
    var errorMessage: String? = nil
    var isJoining = false

    private let client = SupabaseManager.shared.client

    func loadNearby(userLocation: CLLocation?) async {
        isLoading = true
        errorMessage = nil

        do {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime]
            let cutoff = fmt.string(from: Date().addingTimeInterval(-4 * 3600))

            let games: [NearbyGame] = try await client
                .from("games")
                .select("""
                    id, join_code, created_at, format, max_players, scheduled_at,
                    courts(name, neighborhood, lat, lng),
                    host:profiles!games_host_id_fkey(full_name, username)
                """)
                .in("status", values: ["active", "waiting"])
                .gte("created_at", value: cutoff)
                .order("created_at", ascending: false)
                .execute()
                .value

            var filtered = games.map { game -> NearbyGame in
                var g = game
                if let loc = userLocation, let court = game.courts, let lat = court.lat, let lng = court.lng {
                    let courtLoc = CLLocation(latitude: lat, longitude: lng)
                    g.distanceMiles = loc.distance(from: courtLoc) / 1609.34
                }
                return g
            }

            if userLocation != nil {
                filtered = filtered
                    .filter { $0.distanceMiles <= 5.0 }
                    .sorted { $0.distanceMiles < $1.distanceMiles }
            }

            nearbyGames = filtered
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func joinGameDirectly(_ game: NearbyGame) async -> SupabaseGame? {
        guard let userId = SupabaseManager.shared.session?.user.id.uuidString else { return nil }
        isJoining = true
        errorMessage = nil

        do {
            try await client
                .from("game_players")
                .insert(GamePlayerPayload(gameId: game.id, userId: userId))
                .execute()

            let found: SupabaseGame = try await client
                .from("games")
                .select()
                .eq("id", value: game.id)
                .single()
                .execute()
                .value

            isJoining = false
            return found
        } catch {
            errorMessage = error.localizedDescription
            isJoining = false
            return nil
        }
    }
}

struct JoinGameView: View {
    @State private var gameViewModel = GameViewModel()
    @State private var joinVM = JoinGameViewModel()
    @State private var locMgr = JoinLocationManager()
    @State private var selectedTab: Int = 0
    @State private var showLobby: Bool = false
    @State private var hasLoaded: Bool = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    joinTabPicker

                    if selectedTab == 0 {
                        nearbyRunsTab
                    } else {
                        qrScannerTab
                    }
                }

                if joinVM.isJoining || gameViewModel.isJoining {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView().tint(NETRTheme.neonGreen).scaleEffect(1.4)
                        Text("Joining run…")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NETRTheme.text)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("JOIN A RUN")
                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                        .tracking(2)
                        .foregroundStyle(NETRTheme.text)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        LucideIcon("x-circle")
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
            .task {
                guard !hasLoaded else { return }
                hasLoaded = true
                locMgr.request()
                try? await Task.sleep(for: .milliseconds(500))
                await joinVM.loadNearby(userLocation: locMgr.location)
            }
            .onChange(of: locMgr.location) { _, newLoc in
                if newLoc != nil {
                    Task { await joinVM.loadNearby(userLocation: newLoc) }
                }
            }
            .onChange(of: gameViewModel.game?.id) { _, newVal in
                if newVal != nil { showLobby = true }
            }
            .sheet(isPresented: $showLobby) {
                GameLobbyView(viewModel: gameViewModel, onDismiss: {
                    showLobby = false
                    dismiss()
                })
            }
        }
    }

    private var joinTabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: "Nearby Runs", icon: "location.fill", index: 0)
            tabButton(title: "Scan / Code", icon: "qrcode.viewfinder", index: 1)
        }
        .overlay(
            Rectangle()
                .fill(NETRTheme.border)
                .frame(height: 1),
            alignment: .bottom
        )
        .padding(.horizontal, 20)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { selectedTab = index }
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    LucideIcon(icon, size: 13)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(selectedTab == index ? NETRTheme.neonGreen : NETRTheme.subtext)

                Capsule()
                    .fill(selectedTab == index ? NETRTheme.neonGreen : .clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    // MARK: - Nearby Runs

    private var nearbyRunsTab: some View {
        Group {
            if joinVM.isLoading {
                VStack(spacing: 14) {
                    ProgressView().tint(NETRTheme.neonGreen).scaleEffect(1.2)
                    Text("Looking for runs near you…")
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.subtext)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let err = joinVM.errorMessage, !joinVM.isJoining {
                VStack(spacing: 14) {
                    LucideIcon("triangle-alert", size: 36)
                        .foregroundStyle(NETRTheme.gold)
                    Text(err)
                        .font(.system(size: 13))
                        .foregroundStyle(NETRTheme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") {
                        Task { await joinVM.loadNearby(userLocation: locMgr.location) }
                    }
                    .foregroundStyle(NETRTheme.neonGreen)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if joinVM.nearbyGames.isEmpty {
                noNearbyRunsView

            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(NETRTheme.neonGreen)
                                .frame(width: 7, height: 7)
                                .shadow(color: NETRTheme.neonGreen.opacity(0.7), radius: 4)
                            Text("\(joinVM.nearbyGames.count) active run\(joinVM.nearbyGames.count == 1 ? "" : "s") nearby")
                                .font(.system(size: 12))
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .padding(.horizontal, 20)

                        ForEach(Array(joinVM.nearbyGames.enumerated()), id: \.element.id) { i, game in
                            NearbyGameCard(game: game, delay: Double(i) * 0.06) {
                                Task {
                                    if let joined = await joinVM.joinGameDirectly(game) {
                                        gameViewModel.game = joined
                                        await gameViewModel.loadPlayers(gameId: joined.id)
                                        showLobby = true
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
                .refreshable {
                    await joinVM.loadNearby(userLocation: locMgr.location)
                }
            }
        }
    }

    private var noNearbyRunsView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(NETRTheme.muted.opacity(0.3)).frame(width: 80, height: 80)
                LucideIcon("circle-dot", size: 36)
                    .foregroundStyle(NETRTheme.muted)
            }
            VStack(spacing: 8) {
                Text("NO ACTIVE RUNS NEARBY")
                    .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(NETRTheme.text)
                Text("No games near you right now.\nScan a QR or enter a code to join, or start your own run.")
                    .font(.system(size: 14))
                    .foregroundStyle(NETRTheme.subtext)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - QR / Code Tab

    private var qrScannerTab: some View {
        JoinQRTab(
            gameViewModel: gameViewModel,
            joinError: joinVM.errorMessage ?? gameViewModel.joinError
        )
    }
}

// MARK: - Nearby Game Card

private struct NearbyGameCard: View {
    let game: NearbyGame
    let delay: Double
    let onJoin: () -> Void

    @State private var appeared: Bool = false
    @State private var pulsing: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulsing ? 1.4 : 1.0)
                        .opacity(pulsing ? 0 : 0.6)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false), value: pulsing)
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(0.08))
                        .frame(width: 44, height: 44)
                    LucideIcon("circle-dot", size: 20)
                        .foregroundStyle(NETRTheme.neonGreen)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(game.courtName)
                        .font(.system(.body, design: .default, weight: .black).width(.compressed))
                        .foregroundStyle(NETRTheme.text)
                    HStack(spacing: 4) {
                        if !game.neighborhood.isEmpty {
                            Text(game.neighborhood)
                                .font(.system(size: 12))
                                .foregroundStyle(NETRTheme.subtext)
                            Text("·").foregroundStyle(NETRTheme.muted)
                        }
                        if game.distanceMiles > 0 {
                            LucideIcon("map-pin", size: 10)
                                .foregroundStyle(NETRTheme.neonGreen.opacity(0.7))
                            Text(game.distanceMiles < 0.1 ? "< 0.1 mi" : String(format: "%.1f mi", game.distanceMiles))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(NETRTheme.neonGreen.opacity(0.8))
                            Text("·").foregroundStyle(NETRTheme.muted)
                        }
                        Text(game.startedAgo)
                            .font(.system(size: 12))
                            .foregroundStyle(NETRTheme.subtext)
                    }
                    HStack(spacing: 4) {
                        LucideIcon("user", size: 10)
                            .foregroundStyle(NETRTheme.muted)
                        Text("Hosted by \(game.hostName)")
                            .font(.system(size: 12))
                            .foregroundStyle(NETRTheme.muted)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                VStack(spacing: 4) {
                    if game.isScheduled {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(NETRTheme.gold)
                    }
                    if let fmt = game.format {
                        Text(fmt)
                            .font(.system(.caption, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NETRTheme.neonGreen)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Button(action: onJoin) {
                HStack(spacing: 8) {
                    LucideIcon("arrow-right-circle", size: 16)
                    Text("Join This Run")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(PressButtonStyle())
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(NETRTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1)
        )
        .clipShape(.rect(cornerRadius: 18))
        .shadow(color: NETRTheme.neonGreen.opacity(0.08), radius: 12, y: 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(delay), value: appeared)
        .onAppear {
            appeared = true
            pulsing = true
        }
    }
}

// MARK: - QR / Manual Code Tab

private struct JoinQRTab: View {
    @Bindable var gameViewModel: GameViewModel
    let joinError: String?

    @State private var manualCode: String = ""
    @State private var cameraAuth: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                #if targetEnvironment(simulator)
                qrPlaceholder
                #else
                if cameraAuth == .authorized {
                    QRCameraPreview { code in
                        guard !gameViewModel.isJoining else { return }
                        if let parsed = parseJoinCode(code) {
                            Task { await gameViewModel.joinGameByCode(parsed) }
                        }
                    }
                } else {
                    qrPlaceholder
                }
                #endif

                JoinScannerFrame()
                    .stroke(NETRTheme.neonGreen, lineWidth: 3)
                    .frame(width: 200, height: 200)
                    .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 8)

                JoinScanLine()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()

            VStack(spacing: 4) {
                Text("Point your camera at the host's QR code")
                    .font(.system(size: 13))
                    .foregroundStyle(NETRTheme.subtext)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 16)

            Divider().overlay(NETRTheme.border).padding(.horizontal, 20)

            VStack(spacing: 14) {
                Text("or enter code manually")
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.muted)

                JoinCodeInput(code: $manualCode)

                if let err = joinError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    if manualCode.count == 6 {
                        Task { await gameViewModel.joinGameByCode(manualCode) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if gameViewModel.isJoining {
                            ProgressView().tint(.black)
                        } else {
                            Text("JOIN RUN")
                                .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                .tracking(2)
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        manualCode.count == 6 ? NETRTheme.neonGreen : NETRTheme.muted,
                        in: .rect(cornerRadius: 13)
                    )
                }
                .buttonStyle(PressButtonStyle())
                .disabled(manualCode.count < 6 || gameViewModel.isJoining)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)

            Spacer()
        }
        .onAppear {
            #if !targetEnvironment(simulator)
            if cameraAuth == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    Task { @MainActor in
                        cameraAuth = granted ? .authorized : .denied
                    }
                }
            }
            #endif
        }
    }

    private var qrPlaceholder: some View {
        ZStack {
            NETRTheme.surface
            VStack(spacing: 14) {
                LucideIcon("camera", size: 40)
                    .foregroundStyle(NETRTheme.muted)
                Text("Camera Preview")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(NETRTheme.text)
                Text("Install this app on your device\nvia the Rork App to use the camera.")
                    .font(.subheadline)
                    .foregroundStyle(NETRTheme.subtext)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func parseJoinCode(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("netr://join/") { return String(s.dropFirst("netr://join/".count)).uppercased() }
        if s.hasPrefix("https://netr.app/join/") { return String(s.dropFirst("https://netr.app/join/".count)).uppercased() }
        let clean = s.uppercased()
        if clean.count == 6, clean.allSatisfy({ $0.isLetter || $0.isNumber }) { return clean }
        return nil
    }
}

// MARK: - 6-Char Code Input

private struct JoinCodeInput: View {
    @Binding var code: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .focused($focused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: code) { _, newValue in
                    let clean = newValue.uppercased().filter { $0.isLetter || $0.isNumber }
                    code = String(clean.prefix(6))
                }

            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    let char: String = code.count > i ? String(code[code.index(code.startIndex, offsetBy: i)]) : ""
                    let isActive = code.count == i

                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(NETRTheme.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        isActive ? NETRTheme.neonGreen : (char.isEmpty ? NETRTheme.border : NETRTheme.neonGreen.opacity(0.4)),
                                        lineWidth: isActive ? 1.5 : 1
                                    )
                            )
                        Text(char.isEmpty ? (isActive ? "|" : "·") : char)
                            .font(.system(size: char.isEmpty ? 18 : 24, weight: .black, design: .monospaced))
                            .foregroundStyle(char.isEmpty ? NETRTheme.muted : NETRTheme.neonGreen)
                            .animation(.easeInOut(duration: 0.15), value: isActive)
                    }
                    .frame(width: 44, height: 52)
                    .animation(.spring(response: 0.2), value: char)
                }
            }
            .onTapGesture { focused = true }
        }
    }
}

// MARK: - Scanner Frame Shape

private struct JoinScannerFrame: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let corner: CGFloat = 24
        let len: CGFloat = 40

        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.minY + corner),
                 radius: corner, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))

        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.minY + corner),
                 radius: corner, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))

        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner),
                 radius: corner, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))

        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.maxY - corner),
                 radius: corner, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))

        return p
    }
}

// MARK: - Animated Scan Line

private struct JoinScanLine: View {
    @State private var offset: CGFloat = -100

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, NETRTheme.neonGreen.opacity(0.7), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: 180, height: 2)
            .offset(y: offset)
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                    offset = 100
                }
            }
    }
}

// MARK: - QR Camera Preview (real device only)

struct QRCameraPreview: UIViewRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black

        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return view }

        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        context.coordinator.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.previewLayer?.frame = uiView.bounds
        }
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCode: (String) -> Void
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        private var lastScanned: String = ""
        private var lastScanTime: Date = .distantPast

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let str = obj.stringValue else { return }

            Task { @MainActor [weak self] in
                guard let self else { return }
                let now = Date()
                guard str != self.lastScanned || now.timeIntervalSince(self.lastScanTime) > 2 else { return }
                self.lastScanned = str
                self.lastScanTime = now
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                self.onCode(str)
            }
        }
    }
}
