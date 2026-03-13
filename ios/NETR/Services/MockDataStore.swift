import Foundation

@Observable
@MainActor
class MockDataStore {
    var players: [Player] = []
    var feedPosts: [MockFeedPost] = []
    var currentUser: Player
    var activeGame: GameSession?
    var courtUserRatings: [String: Int] = [:]

    init() {
        currentUser = Player(
            id: 99, name: "Player", username: "@player", avatar: "??",
            rating: nil, reviews: 3, age: 24, tier: .basic, city: "New York, NY",
            position: .pg, trend: .none, games: 5, isProspect: false,
            skills: SkillRatings(), profileImageData: nil
        )
        loadMockData()
    }

    func syncFromProfile(_ profile: UserProfile) {
        let player = profile.toPlayer()
        currentUser.name = player.name
        currentUser.username = player.username
        currentUser.avatar = player.avatar
        currentUser.avatarUrl = player.avatarUrl
        currentUser.rating = player.rating
        currentUser.position = player.position
        if player.skills.overall != nil {
            currentUser.skills = player.skills
        }
    }

    private func loadMockData() {
        players = Self.mockPlayers
        feedPosts = Self.mockPosts
    }

    func toggleLike(postId: Int) {
        guard let idx = feedPosts.firstIndex(where: { $0.id == postId }) else { return }
        feedPosts[idx].liked.toggle()
        feedPosts[idx].likes += feedPosts[idx].liked ? 1 : -1
    }

    func toggleBookmark(postId: Int) {
        guard let idx = feedPosts.firstIndex(where: { $0.id == postId }) else { return }
        feedPosts[idx].bookmarked.toggle()
    }

    func rateCourt(courtId: String, stars: Int) {
        courtUserRatings[courtId] = stars
    }

    static let mockPlayers: [Player] = [
        Player(id: 1, name: "Marcus T.", username: "@marc_t", avatar: "MT", rating: 7.2, reviews: 34, age: 26, tier: .verified, city: "New York, NY", position: .sg, trend: .up, games: 48, isProspect: false, skills: SkillRatings(shooting: 7.5, finishing: 6.9, ballHandling: 6.8, playmaking: 6.5, defense: 7.0, rebounding: 6.2, basketballIQ: 7.6), profileImageData: nil),
        Player(id: 2, name: "Dre Williams", username: "@dre_w", avatar: "DW", rating: 6.1, reviews: 21, age: 28, tier: .basic, city: "New York, NY", position: .pg, trend: .stable, games: 30, isProspect: false, skills: SkillRatings(shooting: 5.5, finishing: 5.0, ballHandling: 7.2, playmaking: 7.0, defense: 5.8, rebounding: 4.8, basketballIQ: 5.1), profileImageData: nil),
        Player(id: 3, name: "K. Johnson", username: "@kj_hoops", avatar: "KJ", rating: 8.0, reviews: 58, age: 30, tier: .verified, city: "New York, NY", position: .pf, trend: .up, games: 82, isProspect: false, skills: SkillRatings(shooting: 7.2, finishing: 8.5, ballHandling: 6.5, playmaking: 7.0, defense: 9.0, rebounding: 9.2, basketballIQ: 9.1), profileImageData: nil),
        Player(id: 4, name: "Sam Rivera", username: "@sam_r", avatar: "SR", rating: 5.4, reviews: 12, age: 22, tier: .basic, city: "New York, NY", position: .sf, trend: .down, games: 18, isProspect: false, skills: SkillRatings(shooting: 5.0, finishing: 4.5, ballHandling: 5.5, playmaking: 4.8, defense: 5.2, rebounding: 5.8, basketballIQ: 5.4), profileImageData: nil),
        Player(id: 5, name: "Tony Cross", username: "@t_cross", avatar: "TC", rating: 7.8, reviews: 44, age: 27, tier: .verified, city: "New York, NY", position: .pg, trend: .stable, games: 60, isProspect: false, skills: SkillRatings(shooting: 7.0, finishing: 7.2, ballHandling: 8.5, playmaking: 8.8, defense: 7.2, rebounding: 5.5, basketballIQ: 7.8), profileImageData: nil),
        Player(id: 6, name: "Leila Okafor", username: "@lei_ok", avatar: "LO", rating: 6.7, reviews: 29, age: 25, tier: .basic, city: "New York, NY", position: .sf, trend: .up, games: 35, isProspect: false, skills: SkillRatings(shooting: 6.5, finishing: 6.0, ballHandling: 6.0, playmaking: 7.2, defense: 7.0, rebounding: 6.5, basketballIQ: 6.7), profileImageData: nil),
        Player(id: 7, name: "Jaylen M.", username: "@jay_m14", avatar: "JM", rating: nil, reviews: 2, age: 14, tier: .prospect, city: "New York, NY", position: .pg, trend: .none, games: 4, isProspect: true, skills: SkillRatings(), profileImageData: nil),
        Player(id: 8, name: "Nate Diallo", username: "@nate_d", avatar: "ND", rating: 8.6, reviews: 72, age: 29, tier: .verified, city: "New York, NY", position: .sg, trend: .up, games: 95, isProspect: false, skills: SkillRatings(shooting: 9.2, finishing: 8.8, ballHandling: 8.0, playmaking: 7.5, defense: 8.8, rebounding: 7.5, basketballIQ: 9.1), profileImageData: nil),
    ]

    static let mockPosts: [MockFeedPost] = [
        MockFeedPost(id: 1, author: MockPostAuthor(name: "Nate Diallo", username: "@nate_d", avatar: "ND", rating: 8.6, verified: true), time: "14m", content: "Rucker Park is live right now. Who's pulling up? Got next.", tags: ["#RuckerPark", "#NYC", "#Pickup"], court: "Rucker Park", isGame: true, joinCode: "BASK7X", likes: 24, comments: 8, reposts: 3, liked: false, bookmarked: false),
        MockFeedPost(id: 2, author: MockPostAuthor(name: "Tony Cross", username: "@t_cross", avatar: "TC", rating: 7.8, verified: true), time: "1h", content: "West 4th courts are underrated. Best runs in the Village. Surface is clean, lights are good.", tags: ["#West4th", "#CourtReview"], court: "West 4th Street", isGame: false, joinCode: nil, likes: 18, comments: 5, reposts: 2, liked: true, bookmarked: false),
        MockFeedPost(id: 3, author: MockPostAuthor(name: "K. Johnson", username: "@kj_hoops", avatar: "KJ", rating: 8.0, verified: true), time: "2h", content: "Shoutout to @dre_w for that dish in the 4th. Vision was crazy today.", tags: ["#PlayerShoutout", "#Playmaking"], court: nil, isGame: false, joinCode: nil, likes: 31, comments: 12, reposts: 5, liked: false, bookmarked: true),
        MockFeedPost(id: 4, author: MockPostAuthor(name: "Leila Okafor", username: "@lei_ok", avatar: "LO", rating: 6.7, verified: false), time: "3h", content: "Looking for a run in Brooklyn this Saturday. Fort Greene or Betsy Head.", tags: ["#LFG", "#Brooklyn", "#Saturday"], court: nil, isGame: false, joinCode: nil, likes: 9, comments: 6, reposts: 1, liked: false, bookmarked: false),
        MockFeedPost(id: 5, author: MockPostAuthor(name: "Marcus T.", username: "@marc_t", avatar: "MT", rating: 7.2, verified: true), time: "5h", content: "Dyckman tonight. 5v5. Competitive only. Be ready or stay home.", tags: ["#Dyckman", "#5v5", "#Competitive"], court: "Dyckman Park", isGame: true, joinCode: "DYK5V5", likes: 42, comments: 15, reposts: 8, liked: false, bookmarked: false),
    ]
}
