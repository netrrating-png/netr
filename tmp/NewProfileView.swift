// ─────────────────────────────────────────────────────────────────────────────
// ProfileView.swift  —  NETR App
//
// Full user profile with:
//   • Follow / Followers / Following social graph
//   • Bio (set in Settings)
//   • 7-sided radar chart: Scoring · IQ · Defense · Handles ·
//                          Playmaking · Finishing · Rebounding
//   • Lucide icon mapping (SF Symbol equivalents noted per category)
//   • NETR rating hero (self-assessed lock or peer-rated glow)
//   • Vibe aura dot
//   • Court Rep XP card
//   • Home courts
//
// ─────────────────────────────────────────────────────────────────────────────

import SwiftUI

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

// MARK: ─── Tokens ─────────────────────────────────────────────────────────────

private enum P {
    static let bg      = Color(hex: "#080808")
    static let surface = Color(hex: "#0F0F0F")
    static let card    = Color(hex: "#161616")
    static let border  = Color(hex: "#242424")
    static let text    = Color(hex: "#F2F2F2")
    static let sub     = Color(hex: "#777777")
    static let muted   = Color(hex: "#333333")
    static let accent  = Color(hex: "#00FF41")
    static let gold    = Color(hex: "#F5C542")
    static let red     = Color(hex: "#FF453A")
}

// MARK: ─── Lucide Icon Map ────────────────────────────────────────────────────
// Lucide → SF Symbol equivalents used throughout this file.
// When Rork supports a Lucide package, swap systemName for the lucide variant.
//
//  Lucide "target"          → "scope"               (Scoring)
//  Lucide "brain"           → "brain"               (IQ)
//  Lucide "shield"          → "shield.fill"         (Defense)
//  Lucide "grip"            → "hand.raised.fill"    (Handles)
//  Lucide "zap"             → "bolt.fill"           (Playmaking)
//  Lucide "flame"           → "flame.fill"          (Finishing)
//  Lucide "arrow-up"        → "arrow.up.circle"     (Rebounding)
//  Lucide "users"           → "person.2.fill"       (Followers)
//  Lucide "user-plus"       → "person.badge.plus"   (Follow)
//  Lucide "map-pin"         → "mappin.circle.fill"  (Courts)
//  Lucide "award"           → "rosette"             (Badges)
//  Lucide "lock"            → "lock.fill"           (Locked rating)

// MARK: ─── Skill Category ─────────────────────────────────────────────────────

struct SkillCategory: Identifiable {
    let id: String
    let label: String
    let sfSymbol: String   // SF Symbol (Lucide equivalent — see map above)
    let lucideIcon: String // For reference when swapping to Lucide package
    var value: Double      // 1.0 – 10.0; nil shown as 0 until rated
}

extension SkillCategory {
    /// The canonical 7 NETR skill axes
    static func defaultCategories(from profile: ProfileData) -> [SkillCategory] {[
        SkillCategory(id:"scoring",    label:"Scoring",    sfSymbol:"scope",              lucideIcon:"target",    value: profile.skillScoring    ?? 0),
        SkillCategory(id:"iq",         label:"IQ",         sfSymbol:"brain",              lucideIcon:"brain",     value: profile.skillIQ         ?? 0),
        SkillCategory(id:"defense",    label:"Defense",    sfSymbol:"shield.fill",        lucideIcon:"shield",    value: profile.skillDefense    ?? 0),
        SkillCategory(id:"handles",    label:"Handles",    sfSymbol:"hand.raised.fill",   lucideIcon:"grip",      value: profile.skillHandles    ?? 0),
        SkillCategory(id:"playmaking", label:"Playmaking", sfSymbol:"bolt.fill",          lucideIcon:"zap",       value: profile.skillPlaymaking ?? 0),
        SkillCategory(id:"finishing",  label:"Finishing",  sfSymbol:"flame.fill",         lucideIcon:"flame",     value: profile.skillFinishing  ?? 0),
        SkillCategory(id:"rebounding", label:"Boards",     sfSymbol:"arrow.up.circle",    lucideIcon:"arrow-up",  value: profile.skillRebounding ?? 0),
    ]}
}

// MARK: ─── Profile Data Model ─────────────────────────────────────────────────

struct ProfileData {
    let id: String
    let name: String
    let username: String
    let initials: String
    let position: String
    let city: String
    let bio: String?
    let isPro: Bool
    let isVerified: Bool

    // Rating
    let selfAssessedRating: Double
    let peerRating: Double?
    let peerRatingCount: Int
    let peerRatingThreshold: Int   // 5

    // Skills (nil = not yet peer-rated)
    let skillScoring:    Double?
    let skillIQ:         Double?
    let skillDefense:    Double?
    let skillHandles:    Double?
    let skillPlaymaking: Double?
    let skillFinishing:  Double?
    let skillRebounding: Double?

    // Social
    let followerCount:  Int
    let followingCount: Int
    let isFollowing: Bool          // current viewer follows this profile

    // Rep
    let repLevel: Int
    let repLevelName: String
    let repXP: Int
    let repXPToNext: Int
    let repLevelColor: Color

    // Courts + Vibe
    let homeCourts: [ProfileCourt]
    let vibeAura: ProfileVibeAura?

    // Games played
    let gamesPlayed: Int

    // Computed
    var displayRating: Double {
        guard let peer = peerRating, isPeerRated else { return selfAssessedRating }
        return peer
    }
    var isPeerRated: Bool { peerRatingCount >= peerRatingThreshold }
    var peerProgress: Double { min(1.0, Double(peerRatingCount) / Double(peerRatingThreshold)) }
    var ratingColor: Color { netrRatingColor(displayRating) }
    var tierLabel: String  { netrTierLabel(displayRating)   }
}

func netrRatingColor(_ r: Double) -> Color {
    switch r {
    case 8...:  return Color(hex: "#30D158")
    case 6..<8: return Color(hex: "#00FF41")
    case 4..<6: return Color(hex: "#F5C542")
    default:    return Color(hex: "#FF453A")
    }
}

func netrTierLabel(_ r: Double) -> String {
    switch r {
    case 9...:   return "NBA Level"
    case 8..<9:  return "Elite"
    case 7..<8:  return "D3 Level"
    case 6..<7:  return "Park Legend"
    case 5..<6:  return "Park Dominant"
    case 4..<5:  return "Above Average"
    case 3..<4:  return "Recreational"
    default:     return "Beginner"
    }
}

struct ProfileCourt: Identifiable {
    let id: String
    let name: String
    let neighborhood: String
}

struct ProfileVibeAura {
    let label: String
    let color: Color
}

// MARK: ─── Mock Data ──────────────────────────────────────────────────────────

extension ProfileData {
    static let mockSelf = ProfileData(
        id: "you", name: "Max Gendler", username: "maxygee",
        initials: "MG", position: "PG", city: "New York, NY",
        bio: nil,  // not yet set
        isPro: false, isVerified: false,
        selfAssessedRating: 6.4,
        peerRating: nil, peerRatingCount: 0, peerRatingThreshold: 5,
        skillScoring: nil, skillIQ: nil, skillDefense: nil,
        skillHandles: nil, skillPlaymaking: nil, skillFinishing: nil, skillRebounding: nil,
        followerCount: 3, followingCount: 7, isFollowing: false,
        repLevel: 1, repLevelName: "Newcomer", repXP: 15, repXPToNext: 50,
        repLevelColor: Color(hex:"#888888"),
        homeCourts: [
            ProfileCourt(id:"1", name:"Rucker Park",     neighborhood:"Harlem"),
            ProfileCourt(id:"2", name:"West 4th Street", neighborhood:"West Village"),
            ProfileCourt(id:"3", name:"Tompkins Square", neighborhood:"East Village"),
        ],
        vibeAura: nil,
        gamesPlayed: 0
    )

    static let mockRated = ProfileData(
        id: "kj", name: "K. Johnson", username: "kj_hoops",
        initials: "KJ", position: "SG", city: "New York, NY",
        bio: "Hooper since '09. Run Rucker every summer. Come find me.",
        isPro: true, isVerified: true,
        selfAssessedRating: 7.1,
        peerRating: 8.0, peerRatingCount: 58, peerRatingThreshold: 5,
        skillScoring: 7.8, skillIQ: 8.2, skillDefense: 8.3,
        skillHandles: 6.9, skillPlaymaking: 7.5, skillFinishing: 8.1, skillRebounding: 7.2,
        followerCount: 214, followingCount: 88, isFollowing: false,
        repLevel: 3, repLevelName: "Hooper", repXP: 185, repXPToNext: 115,
        repLevelColor: Color(hex:"#39FF14"),
        homeCourts: [
            ProfileCourt(id:"1", name:"Rucker Park",     neighborhood:"Harlem"),
            ProfileCourt(id:"2", name:"West 4th Street", neighborhood:"West Village"),
            ProfileCourt(id:"3", name:"Dyckman Park",    neighborhood:"Inwood"),
        ],
        vibeAura: ProfileVibeAura(label:"Locked In", color: Color(hex:"#39FF14")),
        gamesPlayed: 34
    )
}

// MARK: ─── Main Profile View ──────────────────────────────────────────────────

struct ProfileView: View {
    let profile: ProfileData
    var isOwnProfile: Bool = true

    @State private var isFollowing: Bool = false
    @State private var showFollowers   = false
    @State private var showFollowing   = false
    @State private var showBioEdit     = false
    @State private var radarVisible    = false
    @State private var ratingAnimated  = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // ── Header gradient ──
                ProfileHeaderGradient(profile: profile)

                VStack(alignment: .leading, spacing: 0) {
                    // ── Avatar + Follow row ──
                    AvatarFollowRow(
                        profile: profile,
                        isOwnProfile: isOwnProfile,
                        isFollowing: $isFollowing,
                        onFollowToggle: { isFollowing.toggle() }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                    // ── Name + badges ──
                    NameBadgeRow(profile: profile)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)

                    // ── Bio ──
                    BioSection(profile: profile, isOwnProfile: isOwnProfile, onEdit: { showBioEdit = true })
                        .padding(.horizontal, 20)
                        .padding(.bottom, 18)

                    // ── Followers / Following strip ──
                    SocialCountsRow(
                        profile: profile,
                        onFollowersTap: { showFollowers = true },
                        onFollowingTap: { showFollowing = true }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                    Divider().background(P.border).padding(.horizontal, 20).padding(.bottom, 24)

                    // ── NETR Rating Hero ──
                    RatingHeroSection(profile: profile, animated: ratingAnimated)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                    // ── 7-Sided Radar Chart ──
                    SkillRadarSection(profile: profile, visible: radarVisible)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)

                    Divider().background(P.border).padding(.horizontal, 20).padding(.bottom, 24)

                    // ── Stats strip ──
                    ProfileStatsStrip(profile: profile)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    Divider().background(P.border).padding(.horizontal, 20).padding(.bottom, 24)

                    // ── Vibe ──
                    if let vibe = profile.vibeAura {
                        VibeRow(vibe: vibe)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        Divider().background(P.border).padding(.horizontal, 20).padding(.bottom, 24)
                    }

                    // ── Court Rep ──
                    CourtRepRow(profile: profile)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                    Divider().background(P.border).padding(.horizontal, 20).padding(.bottom, 24)

                    // ── Home Courts ──
                    if !profile.homeCourts.isEmpty {
                        HomeCourtsRow(courts: profile.homeCourts, accentColor: profile.ratingColor)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
                .background(P.bg)
            }
        }
        .background(P.bg.ignoresSafeArea())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) { ratingAnimated = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation { radarVisible = true }
            }
            isFollowing = profile.isFollowing
        }
        .sheet(isPresented: $showFollowers) { FollowListSheet(title: "Followers", count: profile.followerCount) }
        .sheet(isPresented: $showFollowing) { FollowListSheet(title: "Following", count: profile.followingCount) }
        .sheet(isPresented: $showBioEdit)   { BioEditSheet() }
    }
}

// MARK: ─── Header Gradient ────────────────────────────────────────────────────

private struct ProfileHeaderGradient: View {
    let profile: ProfileData
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                profile.ratingColor.opacity(0.18),
                P.bg,
            ]),
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 120)
    }
}

// MARK: ─── Avatar + Follow Row ────────────────────────────────────────────────

private struct AvatarFollowRow: View {
    let profile: ProfileData
    let isOwnProfile: Bool
    @Binding var isFollowing: Bool
    let onFollowToggle: () -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            // Avatar
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        gradient: Gradient(colors: [profile.ratingColor.opacity(0.2), profile.ratingColor.opacity(0.05)]),
                        center: .center, startRadius: 0, endRadius: 40
                    ))
                    .frame(width: 84, height: 84)
                Circle()
                    .stroke(profile.ratingColor.opacity(profile.isPeerRated ? 0.6 : 0.25), lineWidth: 2)
                    .frame(width: 84, height: 84)
                Text(profile.initials)
                    .font(.custom("BarlowCondensed-Black", size: 30))
                    .foregroundColor(profile.ratingColor)

                // Vibe dot on avatar
                if let vibe = profile.vibeAura {
                    Circle()
                        .fill(vibe.color)
                        .frame(width: 14, height: 14)
                        .shadow(color: vibe.color.opacity(0.8), radius: 4, x: 0, y: 0)
                        .offset(x: 28, y: 28)
                }
            }
            .shadow(color: profile.ratingColor.opacity(profile.isPeerRated ? 0.3 : 0.1), radius: 20, x: 0, y: 0)
            .offset(y: -28)

            Spacer()

            // Action buttons
            HStack(spacing: 10) {
                if isOwnProfile {
                    NavigationLink(destination: SettingsPlaceholderView()) {
                        ProfileActionButton(label: "Edit Profile", icon: "pencil", filled: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: onFollowToggle) {
                        ProfileActionButton(
                            label: isFollowing ? "Following" : "Follow",
                            icon: isFollowing ? "checkmark" : "person.badge.plus",
                            filled: !isFollowing
                        )
                    }
                    .buttonStyle(.plain)
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(P.sub)
                            .frame(width: 36, height: 36)
                            .background(P.card)
                            .overlay(Circle().stroke(P.border, lineWidth: 1))
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
}

private struct ProfileActionButton: View {
    let label: String
    let icon: String
    let filled: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
            Text(label)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(filled ? .black : P.text)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(filled ? P.accent : P.card)
        .overlay(RoundedRectangle(cornerRadius: 99).stroke(filled ? Color.clear : P.border, lineWidth: 1))
        .cornerRadius(99)
    }
}

// MARK: ─── Name + Badges ──────────────────────────────────────────────────────

private struct NameBadgeRow: View {
    let profile: ProfileData

    var body: some View {
        HStack(spacing: 8) {
            Text(profile.name)
                .font(.custom("BarlowCondensed-Black", size: 26))
                .foregroundColor(P.text)

            if profile.isVerified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(P.accent)
            }
            if profile.isPro {
                Text("PRO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(P.gold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(P.gold.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(P.gold.opacity(0.4), lineWidth: 1))
                    .cornerRadius(5)
            }
        }

        HStack(spacing: 8) {
            Text("@\(profile.username)")
                .font(.system(size: 13))
                .foregroundColor(P.sub)
            Text("·")
                .foregroundColor(P.muted)
            Text(profile.position)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(profile.ratingColor)
            Text("·")
                .foregroundColor(P.muted)
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 11))
                .foregroundColor(P.muted)
            Text(profile.city)
                .font(.system(size: 12))
                .foregroundColor(P.sub)
        }
        .padding(.top, 3)
    }
}

// MARK: ─── Bio Section ────────────────────────────────────────────────────────

private struct BioSection: View {
    let profile: ProfileData
    let isOwnProfile: Bool
    let onEdit: () -> Void

    var body: some View {
        if let bio = profile.bio, !bio.isEmpty {
            Text(bio)
                .font(.system(size: 14))
                .foregroundColor(P.sub)
                .lineSpacing(4)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)
        } else if isOwnProfile {
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 13))
                        .foregroundColor(P.accent)
                    Text("Add a bio")
                        .font(.system(size: 13))
                        .foregroundColor(P.accent)
                }
                .padding(.top, 10)
            }
        }
    }
}

// MARK: ─── Social Counts Row ──────────────────────────────────────────────────
// Lucide "users" → SF "person.2.fill"

private struct SocialCountsRow: View {
    let profile: ProfileData
    let onFollowersTap: () -> Void
    let onFollowingTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            SocialCountCell(
                count: profile.followerCount,
                label: profile.followerCount == 1 ? "Follower" : "Followers",
                onTap: onFollowersTap
            )

            Rectangle()
                .fill(P.muted)
                .frame(width: 1, height: 28)
                .padding(.horizontal, 24)

            SocialCountCell(
                count: profile.followingCount,
                label: "Following",
                onTap: onFollowingTap
            )

            Spacer()

            // Games count (non-tappable)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(profile.gamesPlayed)")
                    .font(.custom("BarlowCondensed-Black", size: 20))
                    .foregroundColor(P.text)
                Text("Games")
                    .font(.system(size: 11))
                    .foregroundColor(P.sub)
            }
        }
        .padding(.top, 14)
    }
}

private struct SocialCountCell: View {
    let count: Int
    let label: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(count >= 1000 ? String(format: "%.1fK", Double(count) / 1000) : "\(count)")
                    .font(.custom("BarlowCondensed-Black", size: 22))
                    .foregroundColor(P.text)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(P.sub)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: ─── Rating Hero Section ────────────────────────────────────────────────

private struct RatingHeroSection: View {
    let profile: ProfileData
    let animated: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                // Label
                VStack(alignment: .leading, spacing: 4) {
                    Text("NETR RATING")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(P.sub)
                        .tracking(1.5)
                    Text(profile.tierLabel.uppercased())
                        .font(.custom("BarlowCondensed-Black", size: 22))
                        .foregroundColor(profile.ratingColor)
                    if !profile.isPeerRated {
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(P.sub)
                            Text("Self-assessed · updates at \(profile.peerRatingThreshold) ratings")
                                .font(.system(size: 11))
                                .foregroundColor(P.sub)
                        }
                    } else {
                        Text("\(profile.peerRatingCount) peer ratings")
                            .font(.system(size: 11))
                            .foregroundColor(profile.ratingColor.opacity(0.7))
                    }
                }
                Spacer()

                // Badge
                ZStack {
                    // Progress ring (self-assessed) or glow ring (peer-rated)
                    if !profile.isPeerRated {
                        Circle()
                            .stroke(P.muted, lineWidth: 3)
                            .frame(width: 96, height: 96)
                        Circle()
                            .trim(from: 0, to: animated ? profile.peerProgress : 0)
                            .stroke(profile.ratingColor.opacity(0.75), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 96, height: 96)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.9), value: animated)
                    } else {
                        Circle()
                            .fill(profile.ratingColor.opacity(0.08))
                            .frame(width: 96, height: 96)
                        Circle()
                            .stroke(profile.ratingColor.opacity(0.4), lineWidth: 2)
                            .frame(width: 96, height: 96)
                    }

                    // Core
                    Circle()
                        .fill(RadialGradient(
                            gradient: Gradient(colors: [profile.ratingColor.opacity(0.15), Color.clear]),
                            center: .center, startRadius: 0, endRadius: 42
                        ))
                        .frame(width: 84, height: 84)

                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", profile.displayRating))
                            .font(.custom("BarlowCondensed-Black", size: 36))
                            .foregroundColor(profile.ratingColor)
                        if !profile.isPeerRated {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                                .foregroundColor(P.sub)
                        }
                    }
                }
                .frame(width: 96, height: 96)
                .shadow(color: profile.ratingColor.opacity(profile.isPeerRated ? 0.35 : 0.1), radius: 18, x: 0, y: 0)
                .scaleEffect(animated ? 1.0 : 0.8)
                .opacity(animated ? 1.0 : 0)
                .animation(.spring(response: 0.55, dampingFraction: 0.7), value: animated)
            }

            // Progress bar (self-assessed state)
            if !profile.isPeerRated {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(profile.peerRatingCount) of \(profile.peerRatingThreshold) ratings needed to unlock peer score")
                            .font(.system(size: 11))
                            .foregroundColor(P.sub)
                        Spacer()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(P.muted).frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [profile.ratingColor.opacity(0.6), profile.ratingColor]),
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: animated ? geo.size.width * profile.peerProgress : 0, height: 4)
                                .animation(.easeOut(duration: 0.8).delay(0.2), value: animated)
                        }
                    }
                    .frame(height: 4)
                }
                .padding(14)
                .background(P.surface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(P.border, lineWidth: 1))
                .cornerRadius(12)
            }
        }
    }
}

// MARK: ─── 7-Sided Radar Chart ────────────────────────────────────────────────

private struct SkillRadarSection: View {
    let profile: ProfileData
    let visible: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("SKILL BREAKDOWN")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(P.sub)
                    .tracking(1.5)
                Spacer()
                if !profile.isPeerRated {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9))
                            .foregroundColor(P.sub)
                        Text("Self-assessed")
                            .font(.system(size: 11))
                            .foregroundColor(P.sub)
                    }
                }
            }

            // Radar chart + labels
            HeptagonRadarChart(
                categories: SkillCategory.defaultCategories(from: profile),
                accentColor: profile.ratingColor,
                visible: visible,
                isPeerRated: profile.isPeerRated
            )
            .frame(height: 320)
        }
    }
}

// MARK: Heptagon Radar Chart

struct HeptagonRadarChart: View {
    let categories: [SkillCategory]
    let accentColor: Color
    let visible: Bool
    let isPeerRated: Bool

    @State private var fillProgress: Double = 0

    private let sides = 7
    private let rings = 4     // concentric background rings
    private let chartRadius: CGFloat = 100
    private let labelRadius: CGFloat = 140   // how far out labels sit

    /// Angle for axis i (starting from top, going clockwise)
    private func angle(for i: Int) -> Double {
        (Double(i) / Double(sides)) * 2 * .pi - (.pi / 2)
    }

    /// Point on a circle of given radius at angle for axis i
    private func point(radius: CGFloat, index: Int, center: CGPoint) -> CGPoint {
        let a = angle(for: index)
        return CGPoint(
            x: center.x + radius * CGFloat(cos(a)),
            y: center.y + radius * CGFloat(sin(a))
        )
    }

    /// Path for a ring at fraction 0–1
    private func ringPath(fraction: CGFloat, center: CGPoint) -> Path {
        var path = Path()
        for i in 0..<sides {
            let pt = point(radius: chartRadius * fraction, index: i, center: center)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    /// Data polygon path (values 0–10, mapped to 0–1 of chartRadius)
    private func dataPath(center: CGPoint, progress: Double) -> Path {
        var path = Path()
        for (i, cat) in categories.enumerated() {
            let fraction = CGFloat((cat.value / 10.0) * progress)
            let minFrac: CGFloat = isPeerRated ? 0 : 0.25  // floor for self-assessed
            let pt = point(radius: chartRadius * max(fraction, fraction > 0 ? minFrac : 0), index: i, center: center)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                // Background rings
                ForEach(1...rings, id: \.self) { ring in
                    ringPath(fraction: CGFloat(ring) / CGFloat(rings), center: center)
                        .stroke(P.muted.opacity(ring == rings ? 0.4 : 0.2), lineWidth: ring == rings ? 1 : 0.5)
                }

                // Axis lines
                ForEach(0..<sides, id: \.self) { i in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point(radius: chartRadius, index: i, center: center))
                    }
                    .stroke(P.muted.opacity(0.25), lineWidth: 0.5)
                }

                // Data fill
                dataPath(center: center, progress: fillProgress)
                    .fill(accentColor.opacity(isPeerRated ? 0.18 : 0.10))

                // Data stroke
                dataPath(center: center, progress: fillProgress)
                    .stroke(accentColor.opacity(isPeerRated ? 0.85 : 0.45), lineWidth: 2)

                // Data point dots
                ForEach(Array(categories.enumerated()), id: \.offset) { i, cat in
                    let fraction = CGFloat((cat.value / 10.0) * fillProgress)
                    let minFrac: CGFloat = isPeerRated ? 0 : 0.25
                    let pt = point(radius: chartRadius * max(fraction, fraction > 0 ? minFrac : 0), index: i, center: center)
                    Circle()
                        .fill(accentColor)
                        .frame(width: 6, height: 6)
                        .shadow(color: accentColor.opacity(0.6), radius: 4, x: 0, y: 0)
                        .position(pt)
                        .opacity(fillProgress > 0 ? 1 : 0)
                }

                // Category labels (icon + label + value)
                ForEach(Array(categories.enumerated()), id: \.offset) { i, cat in
                    let pt = point(radius: labelRadius, index: i, center: center)
                    RadarLabel(category: cat, accentColor: accentColor, isPeerRated: isPeerRated)
                        .position(pt)
                }
            }
        }
        .onChange(of: visible) { v in
            if v {
                withAnimation(.easeOut(duration: 0.9)) { fillProgress = 1.0 }
            }
        }
        .onAppear {
            if visible {
                withAnimation(.easeOut(duration: 0.9)) { fillProgress = 1.0 }
            }
        }
    }
}

private struct RadarLabel: View {
    let category: SkillCategory
    let accentColor: Color
    let isPeerRated: Bool

    var body: some View {
        VStack(spacing: 3) {
            // Lucide icon via SF Symbol
            Image(systemName: category.sfSymbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(accentColor.opacity(0.85))

            Text(category.label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(P.sub)
                .tracking(0.3)
                .multilineTextAlignment(.center)
                .lineLimit(1)

            // Value (or — if not peer rated and value is 0)
            Text(category.value > 0 ? String(format: "%.1f", category.value) : "—")
                .font(.custom("BarlowCondensed-Bold", size: 13))
                .foregroundColor(category.value > 0 ? accentColor : P.muted)
        }
        .frame(width: 52)
    }
}

// MARK: ─── Stats Strip ────────────────────────────────────────────────────────

private struct ProfileStatsStrip: View {
    let profile: ProfileData

    var body: some View {
        HStack(spacing: 0) {
            StatBox(value: "\(profile.gamesPlayed)", label: "GAMES")
            Divider().frame(height: 36).background(P.muted)
            StatBox(value: "\(profile.peerRatingCount)", label: "REVIEWS")
            Divider().frame(height: 36).background(P.muted)
            StatBox(value: profile.isVerified ? "✓" : "—", label: "VERIFIED", valueColor: profile.isVerified ? P.accent : P.muted)
        }
    }
}

private struct StatBox: View {
    let value: String
    let label: String
    var valueColor: Color = Color(hex: "#F2F2F2")

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("BarlowCondensed-Black", size: 22))
                .foregroundColor(valueColor)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(P.sub)
                .tracking(1.3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: ─── Vibe Row ───────────────────────────────────────────────────────────

private struct VibeRow: View {
    let vibe: ProfileVibeAura
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(vibe.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .scaleEffect(pulse ? 1.5 : 1.0)
                    .opacity(pulse ? 0 : 0.5)
                    .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false), value: pulse)
                Circle()
                    .fill(vibe.color)
                    .frame(width: 12, height: 12)
                    .shadow(color: vibe.color.opacity(0.8), radius: 5, x: 0, y: 0)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("VIBE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(P.sub)
                    .tracking(1.4)
                Text(vibe.label)
                    .font(.custom("BarlowCondensed-Black", size: 18))
                    .foregroundColor(vibe.color)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(P.muted)
        }
        .onAppear { pulse = true }
    }
}

// MARK: ─── Court Rep Row ──────────────────────────────────────────────────────

private struct CourtRepRow: View {
    let profile: ProfileData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COURT REP")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(P.sub)
                .tracking(1.5)

            HStack(spacing: 14) {
                // Level orb
                ZStack {
                    Circle()
                        .fill(profile.repLevelColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Circle()
                        .stroke(profile.repLevelColor, lineWidth: 1.5)
                        .frame(width: 46, height: 46)
                    Text("L\(profile.repLevel)")
                        .font(.custom("BarlowCondensed-Black", size: 16))
                        .foregroundColor(profile.repLevelColor)
                }
                .shadow(color: profile.repLevelColor.opacity(0.25), radius: 8, x: 0, y: 0)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.repLevelName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(profile.repLevelColor)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(P.muted).frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(
                                    gradient: Gradient(colors: [profile.repLevelColor.opacity(0.6), profile.repLevelColor]),
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: geo.size.width * min(1, Double(profile.repXP) / Double(max(1, profile.repXP + profile.repXPToNext))), height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text("\(profile.repXP) XP · \(profile.repXPToNext) to next level")
                        .font(.system(size: 11))
                        .foregroundColor(P.sub)
                }
            }
        }
    }
}

// MARK: ─── Home Courts ────────────────────────────────────────────────────────

private struct HomeCourtsRow: View {
    let courts: [ProfileCourt]
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("HOME COURTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(P.sub)
                    .tracking(1.5)
                Spacer()
                // Lucide "map-pin" → SF "mappin.circle.fill"
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(P.muted)
            }

            ForEach(courts) { court in
                HStack(spacing: 12) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: accentColor.opacity(0.6), radius: 4, x: 0, y: 0)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(court.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(P.text)
                        Text(court.neighborhood)
                            .font(.system(size: 11))
                            .foregroundColor(P.sub)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(P.muted)
                }
            }
        }
    }
}

// MARK: ─── Follow List Sheet ──────────────────────────────────────────────────
// Lucide "users" → SF "person.2.fill"

struct FollowListSheet: View {
    let title: String
    let count: Int
    @Environment(\.dismiss) var dismiss

    // In production, replace with real user list from Supabase
    private let mockUsers = ["Marcus T.", "Dre Williams", "Sam Rivera", "K. Johnson"]

    var body: some View {
        NavigationView {
            List {
                ForEach(mockUsers, id: \.self) { user in
                    HStack(spacing: 14) {
                        // Avatar placeholder
                        Circle()
                            .fill(P.muted)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(user.prefix(2)).uppercased())
                                    .font(.custom("BarlowCondensed-Bold", size: 15))
                                    .foregroundColor(P.sub)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(user)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(P.text)
                            Text("@\(user.lowercased().replacingOccurrences(of: " ", with: "_"))")
                                .font(.system(size: 12))
                                .foregroundColor(P.sub)
                        }
                        Spacer()
                        // Follow button
                        Text("Follow")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(P.accent)
                            .cornerRadius(99)
                    }
                    .listRowBackground(P.bg)
                    .listRowSeparatorTint(P.border)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(P.bg.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(P.accent)
                }
            }
        }
    }
}

// MARK: ─── Bio Edit Sheet ─────────────────────────────────────────────────────

struct BioEditSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var bio = ""
    private let maxChars = 160

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tell the courts who you are.")
                    .font(.system(size: 14))
                    .foregroundColor(P.sub)

                ZStack(alignment: .topLeading) {
                    if bio.isEmpty {
                        Text("e.g. Hooper since '09. Come find me at Rucker.")
                            .font(.system(size: 14))
                            .foregroundColor(P.muted)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $bio)
                        .font(.system(size: 14))
                        .foregroundColor(P.text)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .frame(minHeight: 100)
                        .onChange(of: bio) { val in
                            if val.count > maxChars { bio = String(val.prefix(maxChars)) }
                        }
                }
                .padding(12)
                .background(P.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(P.border, lineWidth: 1))
                .cornerRadius(12)

                HStack {
                    Spacer()
                    Text("\(bio.count)/\(maxChars)")
                        .font(.system(size: 12))
                        .foregroundColor(bio.count > maxChars - 20 ? P.gold : P.sub)
                }

                Spacer()
            }
            .padding(20)
            .background(P.bg.ignoresSafeArea())
            .navigationTitle("Edit Bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(P.sub)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(P.accent)
                }
            }
        }
    }
}

// MARK: ─── Placeholder ────────────────────────────────────────────────────────

struct SettingsPlaceholderView: View {
    var body: some View {
        Text("Settings")
            .foregroundColor(P.text)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(P.bg.ignoresSafeArea())
    }
}

// MARK: ─── Previews ───────────────────────────────────────────────────────────

#Preview("Own Profile — Unrated") {
    NavigationView {
        ProfileView(profile: .mockSelf, isOwnProfile: true)
    }
}

#Preview("Peer Profile — Rated") {
    NavigationView {
        ProfileView(profile: .mockRated, isOwnProfile: false)
    }
}

#Preview("Radar Chart only") {
    ZStack {
        Color(hex: "#080808").ignoresSafeArea()
        HeptagonRadarChart(
            categories: SkillCategory.defaultCategories(from: .mockRated),
            accentColor: Color(hex: "#00FF41"),
            visible: true,
            isPeerRated: true
        )
        .frame(height: 320)
        .padding(20)
    }
}

#Preview("Follow List") {
    FollowListSheet(title: "Followers", count: 214)
}

#Preview("Bio Edit") {
    BioEditSheet()
}
