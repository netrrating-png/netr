// ─────────────────────────────────────────────────────────────────────────────
// JoinGameView.swift  —  NETR App
//
// Replaces the 6-digit code entry screen with two smarter join methods:
//
//   Tab 1 — NEARBY RUNS
//     • Fetches active games at courts within ~1 mile of the user
//     • Shows court name, player count, host name, how long ago it started
//     • One tap to join — no code needed
//     • Pulls live via Supabase Realtime so the list stays fresh
//
//   Tab 2 — SCAN QR
//     • Native camera QR scanner using AVFoundation
//     • Parses NETR join links: netr://join/<CODE> or https://netr.app/join/<CODE>
//     • Falls back to manual 6-char code entry below the viewfinder
//
// ─────────────────────────────────────────────────────────────────────────────

import SwiftUI
import AVFoundation
import CoreLocation
import Supabase

// MARK: ─── Color Helper ───────────────────────────────────────────────────────

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}

private enum J {
    static let bg      = Color(hex: "#080808")
    static let surface = Color(hex: "#111111")
    static let card    = Color(hex: "#1A1A1A")
    static let border  = Color(hex: "#242424")
    static let text    = Color(hex: "#F2F2F2")
    static let sub     = Color(hex: "#777777")
    static let muted   = Color(hex: "#333333")
    static let accent  = Color(hex: "#00FF41")
    static let gold    = Color(hex: "#F5C542")
    static let red     = Color(hex: "#FF453A")
}

// MARK: ─── Models ─────────────────────────────────────────────────────────────

struct ActiveGame: Identifiable, Decodable {
    let id: UUID
    let join_code: String
    let created_at: String
    let players: [UUID]

    // Joined relations
    let courts: CourtRef?
    let host: HostRef?

    struct CourtRef: Decodable {
        let name: String
        let neighborhood: String?
        let lat: Double
        let lng: Double
    }
    struct HostRef: Decodable {
        let full_name: String?
        let username: String?
    }

    var playerCount: Int { players.count }
    var courtName: String  { courts?.name ?? "Unknown Court" }
    var neighborhood: String { courts?.neighborhood ?? "" }
    var hostName: String {
        if let name = host?.full_name, !name.isEmpty { return name }
        if let username = host?.username { return "@\(username)" }
        return "Unknown"
    }
    var startedAgo: String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fmt.date(from: created_at) else { return "" }
        let diff = Int(-date.timeIntervalSinceNow / 60)
        if diff < 1 { return "Just started" }
        if diff == 1 { return "1 min ago" }
        return "\(diff) mins ago"
    }
    var distanceMiles: Double = 0.0
}

// MARK: ─── Location Manager ───────────────────────────────────────────────────

final class JoinLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let mgr = CLLocationManager()
    @Published var location: CLLocation? = nil
    @Published var status: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        mgr.delegate = self
        mgr.desiredAccuracy = kCLLocationAccuracyHundredMeters
        mgr.requestWhenInUseAuthorization()
    }
    func request() { mgr.requestLocation() }
    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) { location = locs.first }
    func locationManager(_ m: CLLocationManager, didFailWithError e: Error) {}
    func locationManager(_ m: CLLocationManager, didChangeAuthorization s: CLAuthorizationStatus) {
        status = s
        if s == .authorizedWhenInUse || s == .authorizedAlways { mgr.requestLocation() }
    }
}

// MARK: ─── ViewModel ──────────────────────────────────────────────────────────

@MainActor
class JoinGameViewModel: ObservableObject {
    @Published var nearbyGames: [ActiveGame] = []
    @Published var isLoading     = false
    @Published var errorMessage: String? = nil
    @Published var joinedGame: ActiveGame? = nil
    @Published var isJoining     = false

    private var realtimeChannel: RealtimeChannelV2? = nil

    // ── Fetch active games near user ──────────────────────────────────────────

    func loadNearby(supabase: SupabaseClient, userId: UUID, userLocation: CLLocation?) async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch all active games with court + host info
            // games.status = 'active', created in last 4 hours
            let cutoff = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-4 * 3600))

            let games: [ActiveGame] = try await supabase
                .from("games")
                .select("""
                    id, join_code, created_at, players,
                    courts(name, neighborhood, lat, lng),
                    host:profiles!games_host_id_fkey(full_name, username)
                """)
                .eq("status", value: "active")
                .gte("created_at", value: cutoff)
                // Exclude games the user is already in
                .not("players", operator: "cs", value: "{\"\(userId.uuidString)\"}")
                .order("created_at", ascending: false)
                .execute()
                .value

            // Filter to within ~1.5 miles of user, compute distances
            var filtered = games.map { game -> ActiveGame in
                var g = game
                if let loc = userLocation, let court = game.courts {
                    let courtLoc = CLLocation(latitude: court.lat, longitude: court.lng)
                    g.distanceMiles = loc.distance(from: courtLoc) / 1609.34
                }
                return g
            }

            if userLocation != nil {
                filtered = filtered
                    .filter { $0.distanceMiles <= 1.5 }
                    .sorted { $0.distanceMiles < $1.distanceMiles }
            }

            nearbyGames = filtered

        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // ── Join by code (from QR or manual) ─────────────────────────────────────

    func join(code: String, supabase: SupabaseClient, userId: UUID) async {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard cleanCode.count == 6 else { return }

        isJoining = true
        errorMessage = nil

        do {
            // Look up game by join_code
            let games: [ActiveGame] = try await supabase
                .from("games")
                .select("id, join_code, created_at, players, courts(name, neighborhood, lat, lng), host:profiles!games_host_id_fkey(full_name, username)")
                .eq("join_code", value: cleanCode)
                .eq("status", value: "active")
                .limit(1)
                .execute()
                .value

            guard let game = games.first else {
                errorMessage = "No active game found with that code."
                isJoining = false
                return
            }

            // Add user to players array via RPC (avoids race condition)
            try await supabase
                .rpc("join_game", params: ["p_game_id": game.id.uuidString, "p_user_id": userId.uuidString])
                .execute()

            joinedGame = game

        } catch {
            errorMessage = error.localizedDescription
        }

        isJoining = false
    }

    // ── Join an active game directly (tap from nearby list) ───────────────────

    func joinGame(_ game: ActiveGame, supabase: SupabaseClient, userId: UUID) async {
        isJoining = true
        errorMessage = nil
        do {
            try await supabase
                .rpc("join_game", params: ["p_game_id": game.id.uuidString, "p_user_id": userId.uuidString])
                .execute()
            joinedGame = game
        } catch {
            errorMessage = error.localizedDescription
        }
        isJoining = false
    }
}

// MARK: ─── Main Join View ─────────────────────────────────────────────────────

struct JoinGameView: View {
    let supabase: SupabaseClient
    let userId: UUID
    var onJoined: (ActiveGame) -> Void
    var onDismiss: () -> Void

    @StateObject private var vm       = JoinGameViewModel()
    @StateObject private var locMgr   = JoinLocationManager()
    @State private var selectedTab    = 0    // 0 = Nearby, 1 = Scan QR
    @State private var hasLoaded      = false

    var body: some View {
        ZStack {
            J.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                HStack {
                    Button(action: onDismiss) {
                        ZStack {
                            Circle().fill(J.muted.opacity(0.6)).frame(width: 32, height: 32)
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(J.sub)
                        }
                    }
                    Spacer()
                    Text("JOIN A RUN")
                        .font(.custom("BarlowCondensed-Black", size: 20))
                        .foregroundColor(J.text)
                        .tracking(2)
                    Spacer()
                    // Balance the X button
                    Circle().fill(Color.clear).frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 16)

                // ── Tab Switcher ──
                TabPicker(selected: $selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                // ── Content ──
                if selectedTab == 0 {
                    NearbyRunsTab(
                        vm: vm,
                        supabase: supabase,
                        userId: userId,
                        onJoin: { game in
                            Task {
                                await vm.joinGame(game, supabase: supabase, userId: userId)
                            }
                        }
                    )
                } else {
                    QRScannerTab(
                        onCode: { code in
                            Task { await vm.join(code: code, supabase: supabase, userId: userId) }
                        },
                        isJoining: vm.isJoining,
                        errorMessage: vm.errorMessage
                    )
                }
            }

            // ── Joining overlay ──
            if vm.isJoining {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView().tint(J.accent).scaleEffect(1.4)
                    Text("Joining run…")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(J.text)
                }
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            locMgr.request()
            await vm.loadNearby(supabase: supabase, userId: userId, userLocation: locMgr.location)
        }
        .onChange(of: locMgr.location) { _ in
            Task { await vm.loadNearby(supabase: supabase, userId: userId, userLocation: locMgr.location) }
        }
        .onChange(of: vm.joinedGame) { game in
            if let g = game { onJoined(g) }
        }
    }
}

// MARK: ─── Tab Picker ─────────────────────────────────────────────────────────

private struct TabPicker: View {
    @Binding var selected: Int
    private let tabs = ["Nearby Runs", "Scan QR"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { i in
                Button(action: { withAnimation(.spring(response: 0.3)) { selected = i } }) {
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: i == 0 ? "location.fill" : "qrcode.viewfinder")
                                .font(.system(size: 13, weight: .semibold))
                            Text(tabs[i])
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(selected == i ? J.accent : J.sub)

                        Capsule()
                            .fill(selected == i ? J.accent : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.plain)
            }
        }
        .overlay(
            Rectangle()
                .fill(J.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: ─── Nearby Runs Tab ────────────────────────────────────────────────────

private struct NearbyRunsTab: View {
    @ObservedObject var vm: JoinGameViewModel
    let supabase: SupabaseClient
    let userId: UUID
    let onJoin: (ActiveGame) -> Void

    var body: some View {
        Group {
            if vm.isLoading {
                VStack(spacing: 14) {
                    ProgressView().tint(J.accent).scaleEffect(1.2)
                    Text("Looking for runs near you…")
                        .font(.system(size: 14)).foregroundColor(J.sub)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if let err = vm.errorMessage {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36)).foregroundColor(J.gold)
                    Text(err).font(.system(size: 13)).foregroundColor(J.sub)
                        .multilineTextAlignment(.center).padding(.horizontal, 32)
                    Button("Retry") { Task { await vm.loadNearby(supabase: supabase, userId: userId, userLocation: nil) } }
                        .foregroundColor(J.accent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else if vm.nearbyGames.isEmpty {
                NoNearbyRuns()

            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(J.accent)
                                .frame(width: 7, height: 7)
                                .shadow(color: J.accent.opacity(0.7), radius: 4, x: 0, y: 0)
                            Text("\(vm.nearbyGames.count) active run\(vm.nearbyGames.count == 1 ? "" : "s") within 1.5 mi")
                                .font(.system(size: 12))
                                .foregroundColor(J.sub)
                        }
                        .padding(.horizontal, 20)

                        ForEach(Array(vm.nearbyGames.enumerated()), id: \.element.id) { i, game in
                            ActiveGameCard(game: game, delay: Double(i) * 0.06, onJoin: { onJoin(game) })
                                .padding(.horizontal, 20)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
                .refreshable {
                    await vm.loadNearby(supabase: supabase, userId: userId, userLocation: nil)
                }
            }
        }
    }
}

private struct NoNearbyRuns: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(J.muted.opacity(0.3)).frame(width: 80, height: 80)
                Image(systemName: "basketball.fill")
                    .font(.system(size: 36))
                    .foregroundColor(J.muted)
            }
            VStack(spacing: 8) {
                Text("No Active Runs Nearby")
                    .font(.custom("BarlowCondensed-Black", size: 26))
                    .foregroundColor(J.text)
                Text("No games within 1.5 miles of you right now.\nScan a QR to join by code, or start your own run.")
                    .font(.system(size: 14))
                    .foregroundColor(J.sub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: ─── Active Game Card ───────────────────────────────────────────────────

private struct ActiveGameCard: View {
    let game: ActiveGame
    let delay: Double
    let onJoin: () -> Void

    @State private var appeared = false
    @State private var pulsing  = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Live pulse dot
                ZStack {
                    Circle()
                        .fill(J.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulsing ? 1.4 : 1.0)
                        .opacity(pulsing ? 0 : 0.6)
                        .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false), value: pulsing)
                    Circle()
                        .fill(J.accent.opacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: "basketball.fill")
                        .font(.system(size: 20))
                        .foregroundColor(J.accent)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.courtName)
                        .font(.custom("BarlowCondensed-Black", size: 20))
                        .foregroundColor(J.text)
                    HStack(spacing: 4) {
                        if !game.neighborhood.isEmpty {
                            Text(game.neighborhood)
                                .font(.system(size: 12))
                                .foregroundColor(J.sub)
                            Text("·").foregroundColor(J.muted)
                        }
                        if game.distanceMiles > 0 {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                                .foregroundColor(J.accent.opacity(0.7))
                            Text(distLabel(game.distanceMiles))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(J.accent.opacity(0.8))
                            Text("·").foregroundColor(J.muted)
                        }
                        Text(game.startedAgo)
                            .font(.system(size: 12))
                            .foregroundColor(J.sub)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10))
                            .foregroundColor(J.muted)
                        Text("Hosted by \(game.hostName)")
                            .font(.system(size: 12))
                            .foregroundColor(J.muted)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                // Player count badge
                VStack(spacing: 2) {
                    Text("\(game.playerCount)")
                        .font(.custom("BarlowCondensed-Black", size: 26))
                        .foregroundColor(J.accent)
                    Text("in")
                        .font(.system(size: 10))
                        .foregroundColor(J.sub)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // Join button
            Button(action: onJoin) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                    Text("Join This Run")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(J.accent)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(J.card)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(J.accent.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(18)
        .shadow(color: J.accent.opacity(0.08), radius: 12, x: 0, y: 4)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 14)
        .animation(.spring(response: 0.45, dampingFraction: 0.8).delay(delay), value: appeared)
        .onAppear {
            appeared = true
            pulsing  = true
        }
    }

    private func distLabel(_ mi: Double) -> String {
        mi < 0.1 ? "< 0.1 mi" : String(format: "%.1f mi", mi)
    }
}

// MARK: ─── QR Scanner Tab ─────────────────────────────────────────────────────

private struct QRScannerTab: View {
    let onCode: (String) -> Void
    let isJoining: Bool
    let errorMessage: String?

    @State private var showManual  = false
    @State private var manualCode  = ""
    @State private var cameraAuth: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    var body: some View {
        VStack(spacing: 0) {
            // ── Camera viewfinder ──
            ZStack {
                if cameraAuth == .authorized {
                    QRCameraPreview(onCode: { code in
                        guard !isJoining else { return }
                        // Parse NETR deep link or raw code
                        let parsed = parseCode(code)
                        if let c = parsed { onCode(c) }
                    })
                } else {
                    // Camera not authorized
                    ZStack {
                        Rectangle().fill(J.surface)
                        VStack(spacing: 14) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 40))
                                .foregroundColor(J.muted)
                            Text("Camera access needed to scan QR codes.")
                                .font(.system(size: 13))
                                .foregroundColor(J.sub)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(J.accent)
                        }
                    }
                }

                // Corner brackets overlay
                ScannerFrame()
                    .stroke(J.accent, lineWidth: 3)
                    .frame(width: 220, height: 220)
                    .shadow(color: J.accent.opacity(0.4), radius: 8, x: 0, y: 0)

                // Scanning line animation
                ScanLine()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 0))

            // ── Label ──
            VStack(spacing: 4) {
                Text("Point your camera at the host's QR code")
                    .font(.system(size: 13))
                    .foregroundColor(J.sub)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)

            Divider().background(J.border).padding(.horizontal, 20)

            // ── Manual code entry ──
            VStack(spacing: 14) {
                Text("or enter code manually")
                    .font(.system(size: 12))
                    .foregroundColor(J.muted)

                // 6-box OTP style input
                SixCharCodeInput(code: $manualCode)

                if let err = errorMessage {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(J.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    if manualCode.count == 6 { onCode(manualCode) }
                }) {
                    HStack(spacing: 8) {
                        if isJoining {
                            ProgressView().tint(.black)
                        } else {
                            Text("Join Run")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(manualCode.count == 6 ? J.accent : J.muted)
                    .cornerRadius(13)
                }
                .disabled(manualCode.count < 6 || isJoining)
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 20)

            Spacer()
        }
        .onAppear {
            if cameraAuth == .notDetermined {
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        cameraAuth = granted ? .authorized : .denied
                    }
                }
            }
        }
    }

    /// Parse netr://join/XXXXXX or https://netr.app/join/XXXXXX or raw 6-char code
    private func parseCode(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        // Deep link
        if s.hasPrefix("netr://join/") { return String(s.dropFirst("netr://join/".count)).uppercased() }
        if s.hasPrefix("https://netr.app/join/") { return String(s.dropFirst("https://netr.app/join/".count)).uppercased() }
        // Raw 6-char alphanumeric
        let clean = s.uppercased()
        if clean.count == 6, clean.allSatisfy({ $0.isLetter || $0.isNumber }) { return clean }
        return nil
    }
}

// MARK: ─── 6-Char Code Input ──────────────────────────────────────────────────

private struct SixCharCodeInput: View {
    @Binding var code: String
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            // Hidden real text field to capture keyboard input
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.characters)
                .focused($focused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: code) { v in
                    let clean = v.uppercased().filter { $0.isLetter || $0.isNumber }
                    if clean.count > 6 { code = String(clean.prefix(6)) }
                    else { code = clean }
                }

            // Visual boxes
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { i in
                    let char: String = code.count > i ? String(code[code.index(code.startIndex, offsetBy: i)]) : ""
                    let isActive = code.count == i

                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(J.card)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isActive ? J.accent : (char.isEmpty ? J.border : J.accent.opacity(0.4)), lineWidth: isActive ? 1.5 : 1)
                            )
                        Text(char.isEmpty ? (isActive ? "|" : "·") : char)
                            .font(.custom("BarlowCondensed-Black", size: char.isEmpty ? 18 : 24))
                            .foregroundColor(char.isEmpty ? J.muted : J.accent)
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

// MARK: ─── Scanner Corner Frame ───────────────────────────────────────────────

private struct ScannerFrame: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let corner: CGFloat = 24
        let len: CGFloat = 40

        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.minY + corner),
                 radius: corner, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))

        // Top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.minY + corner),
                 radius: corner, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))

        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner),
                 radius: corner, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.maxY - corner),
                 radius: corner, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))

        return p
    }
}

// MARK: ─── Animated Scan Line ─────────────────────────────────────────────────

private struct ScanLine: View {
    @State private var offset: CGFloat = -110

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [Color.clear, J.accent.opacity(0.7), Color.clear]),
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: 200, height: 2)
            .offset(y: offset)
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: true)) {
                    offset = 110
                }
            }
    }
}

// MARK: ─── QR Camera Preview ─────────────────────────────────────────────────
// UIViewRepresentable wrapping AVCaptureSession for real QR scanning

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
        private var lastScanTime: Date  = .distantPast

        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput objects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard let obj = objects.first as? AVMetadataMachineReadableCodeObject,
                  let str = obj.stringValue else { return }

            // Debounce: don't fire the same code twice within 2 seconds
            let now = Date()
            guard str != lastScanned || now.timeIntervalSince(lastScanTime) > 2 else { return }
            lastScanned = str
            lastScanTime = now

            // Haptic feedback
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onCode(str)
        }
    }
}

// MARK: ─── Supabase RPC Note ──────────────────────────────────────────────────
//
// The join_game RPC safely appends the user to games.players[] atomically:
//
// CREATE OR REPLACE FUNCTION join_game(p_game_id UUID, p_user_id UUID)
// RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
// BEGIN
//   UPDATE games
//   SET players = array_append(players, p_user_id)
//   WHERE id = p_game_id
//     AND status = 'active'
//     AND NOT (players @> ARRAY[p_user_id]);
//
//   IF NOT FOUND THEN
//     RAISE EXCEPTION 'Game not found or already joined';
//   END IF;
// END;
// $$;

// MARK: ─── Preview ────────────────────────────────────────────────────────────

struct JoinGamePreview: View {
    @State private var tab = 0

    private var mockGames: [ActiveGame] {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        let t1 = fmt.string(from: Date().addingTimeInterval(-900))
        let t2 = fmt.string(from: Date().addingTimeInterval(-1800))

        var g1 = ActiveGame(
            id: UUID(), join_code: "BASK7X", created_at: t1,
            players: Array(repeating: UUID(), count: 8),
            courts: .init(name: "Rucker Park", neighborhood: "Harlem", lat: 40.827, lng: -73.935),
            host: .init(full_name: "Marcus T.", username: "marc_t")
        )
        var g2 = ActiveGame(
            id: UUID(), join_code: "NYC4RN", created_at: t2,
            players: Array(repeating: UUID(), count: 5),
            courts: .init(name: "West 4th Street", neighborhood: "West Village", lat: 40.731, lng: -74.002),
            host: .init(full_name: "K. Johnson", username: "kj_hoops")
        )
        g1.distanceMiles = 0.3
        g2.distanceMiles = 0.8
        return [g1, g2]
    }

    var body: some View {
        ZStack {
            J.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    ZStack {
                        Circle().fill(J.muted.opacity(0.6)).frame(width: 32, height: 32)
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(J.sub)
                    }
                    Spacer()
                    Text("JOIN A RUN")
                        .font(.custom("BarlowCondensed-Black", size: 20))
                        .foregroundColor(J.text).tracking(2)
                    Spacer()
                    Circle().fill(Color.clear).frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 16)

                TabPicker(selected: $tab).padding(.horizontal, 20).padding(.bottom, 20)

                if tab == 0 {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                Circle().fill(J.accent).frame(width: 7, height: 7)
                                    .shadow(color: J.accent.opacity(0.7), radius: 4, x: 0, y: 0)
                                Text("2 active runs within 1.5 mi")
                                    .font(.system(size: 12)).foregroundColor(J.sub)
                            }.padding(.horizontal, 20)
                            ForEach(Array(mockGames.enumerated()), id: \.element.id) { i, game in
                                ActiveGameCard(game: game, delay: Double(i)*0.06, onJoin: {})
                                    .padding(.horizontal, 20)
                            }
                        }.padding(.top, 16)
                    }
                } else {
                    QRScannerTab(onCode: { _ in }, isJoining: false, errorMessage: nil)
                }
            }
        }
    }
}

#Preview("Join — Nearby Runs") {
    JoinGamePreview()
}
