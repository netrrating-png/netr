import SwiftUI

extension Color {
    nonisolated init(hex: String) {
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

private enum NC {
    static let bg      = Color(hex: "#080808")
    static let surface = Color(hex: "#111111")
    static let card    = Color(hex: "#1A1A1A")
    static let border  = Color(hex: "#252525")
    static let text    = Color(hex: "#F2F2F2")
    static let sub     = Color(hex: "#888888")
    static let muted   = Color(hex: "#444444")
    static let accent  = Color(hex: "#00FF41")
    static let gold    = Color(hex: "#F5C542")
    static let red     = Color(hex: "#FF453A")
}

nonisolated enum VibeResponse: String, CaseIterable, Identifiable, Sendable {
    case lockedIn      = "locked_in"
    case solid         = "solid"
    case whatever      = "whatever"
    case wouldntReturn = "wouldnt_run"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lockedIn:      return "Locked In"
        case .solid:         return "Solid"
        case .whatever:      return "It's Whatever"
        case .wouldntReturn: return "Wouldn't Run Again"
        }
    }

    var emoji: String {
        switch self {
        case .lockedIn:      return "🔥"
        case .solid:         return "👍"
        case .whatever:      return "😐"
        case .wouldntReturn: return "🚫"
        }
    }

    var sublabel: String {
        switch self {
        case .lockedIn:      return "Great energy, easy to play with"
        case .solid:         return "No issues, decent teammate"
        case .whatever:      return "Neutral — wouldn't seek them out"
        case .wouldntReturn: return "Made the run harder"
        }
    }

    var color: Color {
        switch self {
        case .lockedIn:      return Color(hex: "#39FF14")
        case .solid:         return Color(hex: "#F5C542")
        case .whatever:      return Color(hex: "#FF9A3C")
        case .wouldntReturn: return Color(hex: "#FF453A")
        }
    }

    var weight: Double {
        switch self {
        case .lockedIn:      return 1.0
        case .solid:         return 0.5
        case .whatever:      return -0.5
        case .wouldntReturn: return -1.0
        }
    }
}

struct VibeAura: Sendable {
    let label: String
    let color: Color
    let glow: Color
    let description: String
    let minScore: Double

    static let lockedIn  = VibeAura(label:"LOCKED IN",  color:Color(hex:"#39FF14"), glow:Color(hex:"#39FF1455"), description:"People actively want to run with this player", minScore: 0.55)
    static let solid     = VibeAura(label:"SOLID",      color:Color(hex:"#F5C542"), glow:Color(hex:"#F5C54244"), description:"Generally good to be around on the court",     minScore: 0.15)
    static let mixed     = VibeAura(label:"MIXED",      color:Color(hex:"#FF9A3C"), glow:Color(hex:"#FF9A3C44"), description:"Some teammates have concerns",                 minScore:-0.20)
    static let avoid     = VibeAura(label:"AVOID",      color:Color(hex:"#FF453A"), glow:Color(hex:"#FF453A44"), description:"Frequently makes runs harder",                 minScore:-1.01)
    static let pending   = VibeAura(label:"PENDING",    color:Color(hex:"#444444"), glow:.clear,                 description:"Need 5+ responses to unlock",                  minScore:-999)

    static let all: [VibeAura] = [.lockedIn, .solid, .mixed, .avoid]

    static func aura(for score: Double?, totalResponses: Int) -> VibeAura {
        guard let s = score, totalResponses >= 5 else { return .pending }
        return all.first { s >= $0.minScore } ?? .avoid
    }
}

struct VibeData {
    let totalResponses: Int
    let counts: [VibeResponse: Int]

    var isPending: Bool { totalResponses < 5 }

    var weightedScore: Double? {
        guard !isPending else { return nil }
        let total = Double(totalResponses)
        guard total > 0 else { return nil }
        let sum = VibeResponse.allCases.reduce(0.0) { acc, r in
            acc + Double(counts[r] ?? 0) * r.weight
        }
        return sum / total
    }

    var aura: VibeAura { VibeAura.aura(for: weightedScore, totalResponses: totalResponses) }

    func pct(_ response: VibeResponse) -> Double {
        guard totalResponses > 0 else { return 0 }
        return Double(counts[response] ?? 0) / Double(totalResponses)
    }

    var dominantResponse: VibeResponse? {
        counts.max { $0.value < $1.value }?.key
    }
}

extension VibeData {
    static let mockGreen = VibeData(totalResponses: 38, counts: [
        .lockedIn: 24, .solid: 10, .whatever: 3, .wouldntReturn: 1
    ])
    static let mockYellow = VibeData(totalResponses: 22, counts: [
        .lockedIn: 8, .solid: 9, .whatever: 4, .wouldntReturn: 1
    ])
    static let mockPending = VibeData(totalResponses: 2, counts: [
        .lockedIn: 1, .solid: 1, .whatever: 0, .wouldntReturn: 0
    ])
}

struct VibeQuestionView: View {
    let playerName: String
    let playerInitials: String
    var onSubmit: (VibeResponse) -> Void = { _ in }

    @State private var selected: VibeResponse? = nil
    @State private var submitted = false

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(NC.muted)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 24)

            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(NC.accent.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text(playerInitials)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(NC.accent)
                    }
                    Text(playerName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(NC.text)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(NC.card)
                .overlay(RoundedRectangle(cornerRadius: 99).stroke(NC.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 99))

                Text("One last thing —")
                    .font(.system(size: 14))
                    .foregroundStyle(NC.sub)
                    .padding(.top, 4)

                Text("How was their vibe?")
                    .font(.system(.title, design: .default, weight: .black).width(.compressed))
                    .foregroundStyle(NC.text)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)

            VStack(spacing: 10) {
                ForEach(VibeResponse.allCases) { response in
                    VibeOptionButton(
                        response: response,
                        isSelected: selected == response,
                        onTap: { selected = response }
                    )
                }
            }
            .padding(.horizontal, 20)

            Button {
                guard let r = selected else { return }
                withAnimation(.spring(response: 0.3)) { submitted = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onSubmit(r) }
            } label: {
                HStack {
                    if submitted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                    } else {
                        Text(selected != nil ? "Submit Vibe →" : "Select one to continue")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    selected != nil
                    ? LinearGradient(gradient: Gradient(colors: [selected!.color.opacity(0.9), selected!.color]), startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(gradient: Gradient(colors: [NC.muted, NC.muted]), startPoint: .leading, endPoint: .trailing)
                )
                .foregroundStyle(selected != nil ? .white : NC.sub)
                .clipShape(.rect(cornerRadius: 14))
                .shadow(color: selected != nil ? selected!.color.opacity(0.35) : .clear, radius: 12, x: 0, y: 4)
                .scaleEffect(submitted ? 0.97 : 1.0)
                .animation(.spring(response: 0.25), value: submitted)
            }
            .disabled(selected == nil)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 36)
        }
        .background(NC.surface)
    }
}

struct VibeOptionButton: View {
    let response: VibeResponse
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? response.color.opacity(0.2) : NC.bg)
                        .frame(width: 44, height: 44)
                    Circle()
                        .stroke(isSelected ? response.color : NC.border, lineWidth: isSelected ? 1.5 : 1)
                        .frame(width: 44, height: 44)
                    Text(response.emoji)
                        .font(.system(size: 20))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(response.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isSelected ? response.color : NC.text)
                    Text(response.sublabel)
                        .font(.system(size: 12))
                        .foregroundStyle(NC.sub)
                        .lineLimit(1)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(isSelected ? response.color : NC.muted, lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(response.color)
                            .frame(width: 11, height: 11)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? response.color.opacity(0.08) : NC.card)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? response.color.opacity(0.4) : NC.border, lineWidth: 1))
            .clipShape(.rect(cornerRadius: 14))
            .shadow(color: isSelected ? response.color.opacity(0.15) : .clear, radius: 8, x: 0, y: 2)
            .animation(.spring(response: 0.25), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct VibeAuraBadge: View {
    let vibe: VibeData
    @State private var pulse = false

    private var aura: VibeAura { vibe.aura }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(aura.color.opacity(vibe.isPending ? 0 : 0.15))
                    .frame(width: 36, height: 36)
                    .scaleEffect(pulse ? 1.25 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(
                        vibe.isPending ? .default :
                        .easeInOut(duration: 1.8).repeatForever(autoreverses: false),
                        value: pulse
                    )
                Circle()
                    .fill(aura.color)
                    .frame(width: 14, height: 14)
                    .shadow(color: aura.color.opacity(vibe.isPending ? 0 : 0.7), radius: 6, x: 0, y: 0)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text(aura.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(aura.color)
                    .tracking(0.5)
                if vibe.isPending {
                    Text("\(5 - vibe.totalResponses) responses to unlock")
                        .font(.system(size: 11))
                        .foregroundStyle(NC.sub)
                } else {
                    Text("Vibe · \(vibe.totalResponses) responses")
                        .font(.system(size: 11))
                        .foregroundStyle(NC.sub)
                }
            }
        }
        .onAppear { pulse = !vibe.isPending }
    }
}

struct VibeDetailSheet: View {
    let vibe: VibeData
    @Environment(\.dismiss) private var dismiss

    private var aura: VibeAura { vibe.aura }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 16) {
                        AuraOrb(aura: aura, size: 100)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)

                        VStack(spacing: 6) {
                            Text(aura.label)
                                .font(.system(.title, design: .default, weight: .black).width(.compressed))
                                .foregroundStyle(aura.color)
                            Text(aura.description)
                                .font(.system(size: 14))
                                .foregroundStyle(NC.sub)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        if !vibe.isPending {
                            Text("\(vibe.totalResponses) players weighed in")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(aura.color.opacity(0.8))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(aura.color.opacity(0.1))
                                .clipShape(.rect(cornerRadius: 99))
                        }
                    }
                    .padding(.bottom, 32)

                    if !vibe.isPending {
                        Text("RESPONSE BREAKDOWN")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NC.sub)
                            .tracking(1.3)
                            .padding(.bottom, 14)

                        VStack(spacing: 10) {
                            ForEach(VibeResponse.allCases) { r in
                                VibeResponseBar(
                                    response: r,
                                    count: vibe.counts[r] ?? 0,
                                    pct: vibe.pct(r),
                                    isDominant: r == vibe.dominantResponse
                                )
                            }
                        }
                        .padding(.bottom, 28)
                    }

                    Text("HOW VIBE WORKS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(NC.sub)
                        .tracking(1.3)
                        .padding(.bottom, 14)

                    VStack(spacing: 10) {
                        VibeInfoRow(icon:"🎯", text:"After rating skills, teammates answer one question: \"How was this player's vibe?\"")
                        VibeInfoRow(icon:"🎨", text:"Responses map to a color aura — no scores, no decimals. Just a vibe.")
                        VibeInfoRow(icon:"🔒", text:"Needs 5+ responses before your aura becomes visible to others.")
                        VibeInfoRow(icon:"⚖️", text:"Outlier responses are down-weighted. One bad actor can't tank you.")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("AURA GUIDE")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NC.sub)
                            .tracking(1.3)
                            .padding(.top, 24)
                            .padding(.bottom, 4)

                        ForEach(VibeAura.all, id: \.label) { a in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(a.color)
                                    .frame(width: 12, height: 12)
                                    .shadow(color: a.color.opacity(0.6), radius: 4, x: 0, y: 0)
                                Text(a.label)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(a.color)
                                    .frame(width: 90, alignment: .leading)
                                Text(a.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(NC.sub)
                                    .lineLimit(1)
                                Spacer()
                                if aura.label == a.label {
                                    Text("YOU")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(a.color)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(a.color.opacity(0.15))
                                        .clipShape(.rect(cornerRadius: 99))
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(aura.label == a.label ? a.color.opacity(0.07) : Color.clear)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(aura.label == a.label ? a.color.opacity(0.25) : NC.border, lineWidth: 1))
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }
                .padding(20)
            }
            .background(NC.bg.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Vibe")
                        .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                        .foregroundStyle(NC.text)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(aura.color)
                }
            }
        }
    }
}

struct AuraOrb: View {
    let aura: VibeAura
    let size: CGFloat
    @State private var glow = false

    var body: some View {
        ZStack {
            Circle()
                .fill(aura.color.opacity(0.06))
                .frame(width: size * 1.6, height: size * 1.6)
                .blur(radius: 16)
            Circle()
                .fill(aura.color.opacity(0.12))
                .frame(width: size * 1.2, height: size * 1.2)
                .blur(radius: 8)
            Circle()
                .fill(RadialGradient(
                    gradient: Gradient(colors: [aura.color.opacity(0.9), aura.color.opacity(0.4)]),
                    center: .center, startRadius: 0, endRadius: size / 2
                ))
                .frame(width: size, height: size)
                .shadow(color: aura.color.opacity(0.6), radius: glow ? 28 : 16, x: 0, y: 0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glow)

            if aura.label != "PENDING" {
                Text(aura.label)
                    .font(.system(size: size * 0.2, weight: .black, design: .default).width(.compressed))
                    .foregroundStyle(.white.opacity(0.9))
                    .tracking(1.5)
            } else {
                Text("?")
                    .font(.system(size: size * 0.4, weight: .black, design: .default).width(.compressed))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .onAppear { glow = (aura.label != "PENDING") }
    }
}

struct VibeResponseBar: View {
    let response: VibeResponse
    let count: Int
    let pct: Double
    let isDominant: Bool
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            Text(response.emoji).font(.system(size: 18)).frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(response.label)
                        .font(.system(size: 13, weight: isDominant ? .bold : .regular))
                        .foregroundStyle(isDominant ? response.color : NC.text)
                    Spacer()
                    Text("\(count) · \(Int(pct * 100))%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isDominant ? response.color : NC.sub)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(NC.border).frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [response.color.opacity(0.6), response.color]),
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(width: appeared ? geo.size.width * pct : 0, height: 5)
                            .animation(.easeOut(duration: 0.7), value: appeared)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(14)
        .background(isDominant ? response.color.opacity(0.06) : NC.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(isDominant ? response.color.opacity(0.25) : NC.border, lineWidth: 1))
        .clipShape(.rect(cornerRadius: 12))
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { appeared = true } }
    }
}

struct VibeInfoRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon).font(.system(size: 16))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(NC.sub)
                .lineSpacing(4)
        }
        .padding(14)
        .background(NC.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NC.border, lineWidth: 1))
        .clipShape(.rect(cornerRadius: 12))
    }
}

nonisolated struct RepAction: Sendable {
    let id: String
    let label: String
    let icon: String
    let xp: Int
    let description: String
}

extension RepAction {
    static let all: [RepAction] = [
        RepAction(id:"rate",        label:"Rate a Player",         icon:"⭐", xp:10,  description:"Submit a peer rating after a game"),
        RepAction(id:"new_court",   label:"New Court",             icon:"🗺️", xp:25,  description:"Play at a court you've never been to"),
        RepAction(id:"host",        label:"Host a Game",           icon:"📋", xp:15,  description:"Create and run a game session"),
        RepAction(id:"full_rating", label:"Rate All Players",      icon:"✅", xp:20,  description:"Rate every player in a game — no skips"),
        RepAction(id:"streak",      label:"5-Game Month Streak",   icon:"🔥", xp:30,  description:"Play 5+ games in a single month"),
        RepAction(id:"cosign",      label:"Cosign Received",       icon:"🤝", xp:8,   description:"A player cosigns you at a specific court"),
        RepAction(id:"post",        label:"Post to Feed",          icon:"🗣️", xp:5,   description:"Share to the community feed"),
    ]
}

struct RepBadge: Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let requirement: String
    let color: Color
    let xpThreshold: Int
    let isUnlocked: Bool
}

extension RepBadge {
    static func allBadges(for profile: CourtRepData) -> [RepBadge] {[
        RepBadge(id:"first_run",     name:"First Run",      icon:"👟", description:"Played your first game",                   requirement:"Play 1 game",           color:Color(hex:"#888888"), xpThreshold:0,   isUnlocked: profile.gamesPlayed >= 1),
        RepBadge(id:"rater",         name:"Rater",          icon:"⭐", description:"You rate others — rare quality",           requirement:"Rate 25 players",        color:Color(hex:"#F5C542"), xpThreshold:0,   isUnlocked: profile.playersRated >= 25),
        RepBadge(id:"court_hopper",  name:"Court Hopper",   icon:"🗺️", description:"You run everywhere",                      requirement:"Play at 5 courts",       color:Color(hex:"#4A9EFF"), xpThreshold:0,   isUnlocked: profile.uniqueCourts >= 5),
        RepBadge(id:"regular",       name:"Regular",        icon:"🏀", description:"A true hooper",                           requirement:"20 games played",        color:Color(hex:"#00FF41"), xpThreshold:0,   isUnlocked: profile.gamesPlayed >= 20),
        RepBadge(id:"on_sight",      name:"On Sight",       icon:"🔥", description:"Always ready to run",                     requirement:"5 games in a month",     color:Color(hex:"#FF6B2B"), xpThreshold:0,   isUnlocked: profile.hasMonthStreak),
        RepBadge(id:"known_face",    name:"Known Face",     icon:"👋", description:"People know you at the courts",           requirement:"10 cosigns",             color:Color(hex:"#9B6DFF"), xpThreshold:0,   isUnlocked: profile.cosigns >= 10),
        RepBadge(id:"full_send",     name:"Full Send",      icon:"✅", description:"Never skips a rating",                    requirement:"Rate all in 10 games",   color:Color(hex:"#39FF14"), xpThreshold:0,   isUnlocked: profile.fullRatingGames >= 10),
        RepBadge(id:"globe_trotter", name:"Globe Trotter",  icon:"🌍", description:"You've seen every borough",               requirement:"Play at 10+ courts",     color:Color(hex:"#FFD700"), xpThreshold:0,   isUnlocked: profile.uniqueCourts >= 10),
        RepBadge(id:"legend",        name:"Legend",         icon:"👑", description:"A fixture. The courts aren't the same without you.", requirement:"500 XP total", color:Color(hex:"#FFD700"), xpThreshold:500, isUnlocked: profile.totalXP >= 500),
    ]}
}

nonisolated struct RepLevel: Sendable {
    let level: Int
    let name: String
    let color: Color
    let minXP: Int
    let maxXP: Int
}

extension RepLevel {
    static let levels: [RepLevel] = [
        RepLevel(level:1, name:"Newcomer",   color:Color(hex:"#888888"), minXP:0,   maxXP:49),
        RepLevel(level:2, name:"Regular",    color:Color(hex:"#4A9EFF"), minXP:50,  maxXP:149),
        RepLevel(level:3, name:"Hooper",     color:Color(hex:"#39FF14"), minXP:150, maxXP:299),
        RepLevel(level:4, name:"Baller",     color:Color(hex:"#FF6B2B"), minXP:300, maxXP:499),
        RepLevel(level:5, name:"Legend",     color:Color(hex:"#FFD700"), minXP:500, maxXP:999),
    ]

    static func level(for xp: Int) -> RepLevel {
        levels.last(where: { xp >= $0.minXP }) ?? levels[0]
    }

    var nextLevel: RepLevel? {
        RepLevel.levels.first { $0.level == self.level + 1 }
    }
}

struct CourtRepData {
    let totalXP: Int
    let gamesPlayed: Int
    let uniqueCourts: Int
    let playersRated: Int
    let cosigns: Int
    let fullRatingGames: Int
    let hasMonthStreak: Bool
    let homeCourts: [String]
    let recentActions: [RecentRepAction]

    var level: RepLevel { RepLevel.level(for: totalXP) }
    var badges: [RepBadge] { RepBadge.allBadges(for: self) }
    var unlockedBadges: [RepBadge] { badges.filter { $0.isUnlocked } }
    var lockedBadges: [RepBadge]   { badges.filter { !$0.isUnlocked } }

    var xpIntoCurrentLevel: Int { totalXP - level.minXP }
    var xpToNextLevel: Int { (level.nextLevel?.minXP ?? level.maxXP + 1) - level.minXP }
    var levelProgress: Double {
        guard xpToNextLevel > 0 else { return 1.0 }
        return Double(xpIntoCurrentLevel) / Double(xpToNextLevel)
    }
}

struct RecentRepAction: Identifiable {
    let id: String
    let icon: String
    let label: String
    let xp: Int
    let timeAgo: String
}

extension CourtRepData {
    static let mock = CourtRepData(
        totalXP: 185,
        gamesPlayed: 22,
        uniqueCourts: 6,
        playersRated: 31,
        cosigns: 7,
        fullRatingGames: 8,
        hasMonthStreak: true,
        homeCourts: ["Rucker Park", "West 4th", "Dyckman"],
        recentActions: [
            RecentRepAction(id:"1", icon:"⭐", label:"Rated all players",   xp:20,  timeAgo:"Today"),
            RecentRepAction(id:"2", icon:"🗺️", label:"New court — Dyckman", xp:25,  timeAgo:"Yesterday"),
            RecentRepAction(id:"3", icon:"🤝", label:"Cosign received",      xp:8,   timeAgo:"2 days ago"),
            RecentRepAction(id:"4", icon:"📋", label:"Hosted a game",        xp:15,  timeAgo:"3 days ago"),
        ]
    )
}

struct CourtRepCard: View {
    let data: CourtRepData
    @State private var showSheet = false
    @State private var barVisible = false

    var body: some View {
        Button(action: { showSheet = true }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(data.level.color.opacity(0.12))
                            .frame(width: 52, height: 52)
                        Circle()
                            .stroke(data.level.color, lineWidth: 1.5)
                            .frame(width: 52, height: 52)
                        Text("L\(data.level.level)")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(data.level.color)
                    }
                    .shadow(color: data.level.color.opacity(0.3), radius: 8, x: 0, y: 0)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("COURT REP")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NC.sub)
                            .tracking(1.3)
                        Text(data.level.name)
                            .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(data.level.color)
                        Text("\(data.totalXP) XP")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(data.level.color.opacity(0.75))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NC.muted)
                }
                .padding(.bottom, 14)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(data.xpIntoCurrentLevel) / \(data.xpToNextLevel) XP to \(data.level.nextLevel?.name ?? "Max")")
                            .font(.system(size: 11))
                            .foregroundStyle(NC.sub)
                        Spacer()
                        if let next = data.level.nextLevel {
                            Text("Level \(next.level)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(next.color)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(NC.border)
                                .frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [data.level.color.opacity(0.7), data.level.color]),
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: barVisible ? geo.size.width * data.levelProgress : 0, height: 6)
                                .animation(.easeOut(duration: 0.85).delay(0.3), value: barVisible)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.bottom, 16)

                if !data.unlockedBadges.isEmpty {
                    HStack(spacing: 8) {
                        Text("BADGES")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(NC.sub)
                            .tracking(1.2)
                        Spacer()
                        Text("\(data.unlockedBadges.count)/\(data.badges.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(NC.sub)
                    }
                    .padding(.bottom, 10)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(data.unlockedBadges) { badge in
                                BadgeChip(badge: badge, compact: true)
                            }
                            ForEach(data.lockedBadges.prefix(2)) { badge in
                                BadgeChip(badge: badge, compact: true, locked: true)
                            }
                        }
                    }
                }
            }
            .padding(18)
            .background(NC.card)
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(data.level.color.opacity(0.25), lineWidth: 1))
            .clipShape(.rect(cornerRadius: 18))
            .shadow(color: data.level.color.opacity(0.1), radius: 16, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { barVisible = true } }
        .sheet(isPresented: $showSheet) {
            CourtRepSheet(data: data)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct BadgeChip: View {
    let badge: RepBadge
    var compact: Bool = false
    var locked: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 10 : 14)
                    .fill(locked ? NC.muted.opacity(0.08) : badge.color.opacity(0.12))
                    .frame(width: compact ? 40 : 56, height: compact ? 40 : 56)
                RoundedRectangle(cornerRadius: compact ? 10 : 14)
                    .stroke(locked ? NC.muted.opacity(0.2) : badge.color.opacity(0.4), lineWidth: 1)
                    .frame(width: compact ? 40 : 56, height: compact ? 40 : 56)
                Text(locked ? "🔒" : badge.icon)
                    .font(.system(size: compact ? 18 : 24))
                    .opacity(locked ? 0.4 : 1.0)
            }
            if !compact {
                Text(badge.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(locked ? NC.muted : badge.color)
                    .lineLimit(1)
            }
        }
    }
}

struct CourtRepSheet: View {
    let data: CourtRepData
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    private let tabLabels = ["Progress", "Badges", "How to Earn"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(tabLabels.enumerated()), id: \.offset) { i, label in
                        Button {
                            withAnimation { selectedTab = i }
                        } label: {
                            Text(label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selectedTab == i ? NC.text : NC.sub)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedTab == i ? NC.card : Color.clear)
                                .clipShape(.rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(NC.surface)
                .clipShape(.rect(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case 0: RepProgressTab(data: data)
                        case 1: RepBadgesTab(data: data)
                        default: RepEarnTab()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(NC.bg.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Court Rep")
                        .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                        .foregroundStyle(NC.text)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(data.level.color)
                }
            }
        }
    }
}

struct RepProgressTab: View {
    let data: CourtRepData
    @State private var barVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Level \(data.level.level)")
                            .font(.system(.largeTitle, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(data.level.color)
                        Text(data.level.name.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(data.level.color.opacity(0.75))
                            .tracking(1.5)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(data.totalXP)")
                            .font(.system(.largeTitle, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NC.text)
                        Text("total XP")
                            .font(.system(size: 12))
                            .foregroundStyle(NC.sub)
                    }
                }

                VStack(spacing: 8) {
                    HStack {
                        Text("\(data.xpIntoCurrentLevel) XP")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(data.level.color)
                        Spacer()
                        if let next = data.level.nextLevel {
                            Text("\(data.xpToNextLevel) XP to \(next.name)")
                                .font(.system(size: 12))
                                .foregroundStyle(NC.sub)
                        } else {
                            Text("Max Level")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(data.level.color)
                        }
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(NC.border).frame(height: 8)
                            Capsule()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [data.level.color.opacity(0.65), data.level.color]),
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: barVisible ? geo.size.width * data.levelProgress : 0, height: 8)
                                .animation(.easeOut(duration: 0.9), value: barVisible)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding(20)
            .background(data.level.color.opacity(0.07))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(data.level.color.opacity(0.25), lineWidth: 1))
            .clipShape(.rect(cornerRadius: 18))

            Text("LEVEL LADDER")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NC.sub)
                .tracking(1.3)

            ForEach(RepLevel.levels, id: \.level) { lvl in
                let isCurrent = data.level.level == lvl.level
                let isPast = data.level.level > lvl.level
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(lvl.color.opacity(isCurrent ? 0.2 : isPast ? 0.1 : 0.05))
                            .frame(width: 38, height: 38)
                        Text("L\(lvl.level)")
                            .font(.system(.subheadline, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(isCurrent || isPast ? lvl.color : NC.muted)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lvl.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(isCurrent ? lvl.color : isPast ? NC.sub : NC.muted)
                        Text("\(lvl.minXP)+ XP")
                            .font(.system(size: 11))
                            .foregroundStyle(NC.muted)
                    }
                    Spacer()
                    if isCurrent {
                        Text("YOU ARE HERE")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(lvl.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(lvl.color.opacity(0.15))
                            .clipShape(.rect(cornerRadius: 99))
                    } else if isPast {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(lvl.color.opacity(0.6))
                    }
                }
                .padding(12)
                .background(isCurrent ? lvl.color.opacity(0.07) : NC.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isCurrent ? lvl.color.opacity(0.3) : NC.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 12))
            }

            if !data.recentActions.isEmpty {
                Text("RECENT XP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NC.sub)
                    .tracking(1.3)

                VStack(spacing: 0) {
                    ForEach(data.recentActions) { action in
                        HStack(spacing: 12) {
                            Text(action.icon).font(.system(size: 18)).frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.label)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(NC.text)
                                Text(action.timeAgo)
                                    .font(.system(size: 11))
                                    .foregroundStyle(NC.sub)
                            }
                            Spacer()
                            Text("+\(action.xp) XP")
                                .font(.system(.subheadline, design: .default, weight: .bold).width(.compressed))
                                .foregroundStyle(data.level.color)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        if action.id != data.recentActions.last?.id {
                            Divider().background(NC.border).padding(.leading, 56)
                        }
                    }
                }
                .background(NC.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(NC.border, lineWidth: 1))
                .clipShape(.rect(cornerRadius: 14))
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { barVisible = true } }
    }
}

struct RepBadgesTab: View {
    let data: CourtRepData
    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !data.unlockedBadges.isEmpty {
                Text("EARNED · \(data.unlockedBadges.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NC.sub)
                    .tracking(1.3)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(data.unlockedBadges) { badge in
                        FullBadgeCell(badge: badge, locked: false)
                    }
                }
            }

            if !data.lockedBadges.isEmpty {
                Text("LOCKED · \(data.lockedBadges.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(NC.sub)
                    .tracking(1.3)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(data.lockedBadges) { badge in
                        FullBadgeCell(badge: badge, locked: true)
                    }
                }
            }
        }
    }
}

struct FullBadgeCell: View {
    let badge: RepBadge
    let locked: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(locked ? NC.muted.opacity(0.06) : badge.color.opacity(0.12))
                RoundedRectangle(cornerRadius: 14)
                    .stroke(locked ? NC.muted.opacity(0.15) : badge.color.opacity(0.4), lineWidth: 1)
                Text(locked ? "🔒" : badge.icon)
                    .font(.system(size: 28))
                    .opacity(locked ? 0.35 : 1.0)
            }
            .frame(height: 64)
            .shadow(color: locked ? .clear : badge.color.opacity(0.2), radius: 8, x: 0, y: 2)

            Text(badge.name)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(locked ? NC.muted : badge.color)
                .multilineTextAlignment(.center)
                .lineLimit(1)
            Text(badge.requirement)
                .font(.system(size: 10))
                .foregroundStyle(NC.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
}

struct RepEarnTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Court Rep is your presence in the game. The more you show up — and give back to the community by rating others — the more XP you earn.")
                .font(.system(size: 14))
                .foregroundStyle(NC.sub)
                .lineSpacing(5)
                .padding(.bottom, 4)

            Text("WAYS TO EARN XP")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(NC.sub)
                .tracking(1.3)

            VStack(spacing: 8) {
                ForEach(RepAction.all, id: \.id) { action in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(NC.surface)
                                .frame(width: 42, height: 42)
                            Text(action.icon).font(.system(size: 20))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(action.label)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(NC.text)
                            Text(action.description)
                                .font(.system(size: 12))
                                .foregroundStyle(NC.sub)
                        }
                        Spacer()
                        Text("+\(action.xp)")
                            .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                            .foregroundStyle(NC.accent)
                        Text("XP")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(NC.sub)
                    }
                    .padding(14)
                    .background(NC.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NC.border, lineWidth: 1))
                    .clipShape(.rect(cornerRadius: 12))
                }
            }
        }
    }
}

struct VibeAndRepBlock: View {
    let vibe: VibeData
    let rep: CourtRepData
    @State private var showVibeSheet = false

    var body: some View {
        VStack(spacing: 12) {
            Button(action: { showVibeSheet = true }) {
                HStack {
                    VibeAuraBadge(vibe: vibe)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(NC.muted)
                }
                .padding(16)
                .background(NC.card)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(vibe.aura.color.opacity(vibe.isPending ? 0.15 : 0.3), lineWidth: 1))
                .clipShape(.rect(cornerRadius: 14))
                .shadow(color: vibe.isPending ? .clear : vibe.aura.color.opacity(0.12), radius: 10, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            CourtRepCard(data: rep)
        }
        .sheet(isPresented: $showVibeSheet) {
            VibeDetailSheet(vibe: vibe)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
