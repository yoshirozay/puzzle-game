import SwiftUI
import GameKit

/// Game Center plumbing: authentication, score submission with an offline
/// pending queue, and leaderboard standings for the custom per-game boards.
/// Views never touch GameKit directly — they read this wrapper, so the
/// themed leaderboard screens stay pure SwiftUI.
/// GKLeaderboardEntry.h declares `@property (strong, readonly, nonatomic)
/// NSDate *date` with no `nullable`, so Swift imports it as a NON-OPTIONAL
/// `Date`. The server does not honour that promise: an entry can arrive with no
/// date, and the bridge then TRAPS in `Date._unconditionallyBridgeFromObjectiveC`
/// instead of yielding nil. Reading `entry.date` is an unconditional crash on
/// such an entry, and Swift cannot catch it.
///
/// Two device crashes, both 2026-07-25, both opening the Cabana Cipher board:
///   1. EXC_BREAKPOINT/SIGTRAP in `Date._unconditionallyBridgeFromObjectiveC`
///      ← convert thunk ← `Optional.map` ← loadStandings. The LOCAL player's
///      entry had no date.
///   2. SIGABRT, `NSUnknownKeyException` ← `valueForUndefinedKey:` ← this
///      getter, after a first attempt read the property via KVC. **KVC does not
///      work here** — whatever object GameKit hands back does not expose `date`
///      as a KVC key, despite the header. Do not reinstate `value(forKey:)`.
///
/// So this uses `perform`, guarded by `responds(to:)`, which is fail-safe in
/// every direction: an absent selector returns nil, and a nil return value
/// arrives as nil rather than through the non-optional bridge. Worst case the
/// date is simply unknown — `BoardStanding.date` is already `Date?` and
/// PlayerCardView hides the line when it is nil.
///
/// BEST EFFORT BY DESIGN: never make anything depend on this being non-nil.
private extension GKLeaderboard.Entry {
    var safeDate: Date? {
        let getter = NSSelectorFromString("date")
        guard responds(to: getter), let boxed = perform(getter) else { return nil }
        return boxed.takeUnretainedValue() as? Date
    }
}

@MainActor
@Observable
final class GameCenter {
    static let shared = GameCenter()
    private init() {}

    private(set) var isAuthenticated = false

    /// Games with a leaderboard configured in App Store Connect. A nil here
    /// quietly opts the game out of submission and all leaderboard chrome.
    static func leaderboardID(for game: TikiGame) -> String? {
        // Placeholders. Replace with your App Store Connect leaderboard IDs.
        switch game {
        case .tikiStacks: return "YOUR_LEADERBOARD_TOTEM"
        case .zombie: return "YOUR_LEADERBOARD_TOPSHELF"
        case .luau: return "YOUR_LEADERBOARD_LUAU"
        // Cipher's rank changed from best SCORE to phrases-in-a-row, but it
        // keeps this board: Carson was its only entrant, so there is no
        // field of score-era entries to strand. The board is already the
        // right shape for a streak (integer, higher is better).
        // ⚠ The one hazard, if this ever comes up again: Game Center keeps
        // the max ever submitted and ASC cannot wipe a live board, so any
        // surviving score-era entry (up to 126) outranks every real streak
        // until it is cleared. Re-pointing at a fresh ID is the only clean
        // switch once a board has real players on the old scale.
        case .cabanaCipher: return "YOUR_LEADERBOARD_CIPHER"
        case .blueprints: return "YOUR_LEADERBOARD_BLUEPRINTS"
        case .navigator: return "YOUR_LEADERBOARD_NAVIGATOR"
        }
    }

    /// The recordRun mirror. Navigator is the one exception: recordRun fires
    /// per PASSAGE with the wallet score, but its board ranks total passages
    /// per run — NavigatorView submits that explicitly at run over.
    func submitRunScore(_ score: Int, for game: TikiGame) {
        guard game != .navigator else { return }
        submit(score: score, for: game)
    }

    /// One-time: park each game's pre-integration best so veterans' scores
    /// populate the boards without a replay. Navigator sits out — its board
    /// ranks passages, which only its own run-over path can produce.
    func backfillBests(from store: PlayerStore) {
        // Keyed by epoch so a server-side wipe re-arms it exactly once.
        let key = "tikiLeaderboardBackfilled.e\(Self.boardEpoch)"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        for game in TikiGame.allCases {
            submitRunScore(store.leaderboardScore(for: game), for: game)
        }
    }

    // MARK: - Authentication

    /// True inside the unit-test host. GameKit's sign-in sheet must never
    /// pop mid-suite, and synthetic runs from tests must not park scores
    /// that a later real launch would submit to the live board.
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    @ObservationIgnored private var handlerInstalled = false

    /// Installs the authenticate handler once. GameKit may hand back a
    /// sign-in view controller (player not signed into Game Center at the
    /// OS level); it is presented as-is — Apple requires their sheet here.
    /// Callers gate WHEN this first runs: returning players at launch,
    /// new players at their first run end or leaderboard visit, so the
    /// sign-in sheet can never land on top of the FTUE.
    func authenticate() {
        guard !Self.isRunningTests else { return }
        #if DEBUG
        if Self.mockMode != nil {
            isAuthenticated = Self.mockMode != "unauth"
            return
        }
        #endif
        guard !handlerInstalled else { return }
        handlerInstalled = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            // GameKit delivers on the main thread.
            guard let self else { return }
            if let viewController {
                Self.rootViewController?.present(viewController, animated: true)
                return
            }
            self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            // The error used to be discarded, which left declined /
            // no-Apple-ID / offline indistinguishable (ANALYTICS_PLAN §5.6.2).
            if !self.isAuthenticated, error != nil {
                // Design event only. A player who isn't signed into Game
                // Center is not a fault, and routing it to `error` would
                // bury real faults under the most common state there is.
                Analytics.design("gc:auth:fail")
            }
            if self.isAuthenticated { self.resubmitPending() }
        }
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }

    // MARK: - Submission

    /// Fire-and-forget, called synchronously from `PlayerStore.recordRun`.
    /// Every run parks its score first (only the per-game max is kept), so
    /// offline and signed-out runs land on the next successful submit —
    /// Game Center itself also only ever keeps a player's best.
    func submit(score: Int, for game: TikiGame) {
        guard !Self.isRunningTests, score > 0, let id = Self.leaderboardID(for: game) else { return }
        stashPending(score: score, for: game)
        // A brand-new player's first run end doubles as the sign-in moment.
        if !handlerInstalled { authenticate() }
        guard isAuthenticated else { return }
        Task { await pushPending(for: game, id: id) }
    }

    // MARK: - Live (mid-run) submission

    @ObservationIgnored private var lastLivePush: [TikiGame: Date] = [:]

    /// Mid-run mirror — a legendary run appears on the board while it's
    /// happening, not only at the kill screen. Every call parks the score
    /// (the pending queue keeps the max); network pushes go out at most
    /// once per 30 s per game, and pushPending drops anything this player
    /// has already submitted, so ordinary runs cost zero round trips.
    func submitLive(score: Int, for game: TikiGame) {
        guard !Self.isRunningTests, score > 0, let id = Self.leaderboardID(for: game) else { return }
        stashPending(score: score, for: game)
        guard isAuthenticated else { return }
        if let last = lastLivePush[game], Date.now.timeIntervalSince(last) < 30 { return }
        lastLivePush[game] = .now
        Task { await pushPending(for: game, id: id) }
    }

    private func pendingKey(_ game: TikiGame) -> String {
        "tikiPendingLeaderboard.\(game.rawValue)"
    }

    /// Bumped whenever a board changes WHICH stat it ranks. The high-water
    /// below is a number on a particular scale, so re-ranking a board makes
    /// every stored value meaningless — and silently unbeatable if the new
    /// scale is smaller.
    ///
    /// Top Shelf is at v2: it used to rank the cumulative merge score, which
    /// grows all run, and now ranks the board's face value, which a merge
    /// conserves and which 16 tiles bound. Every player who scored under the
    /// old rule held a high-water no board value could ever beat, so their
    /// submissions were dropped locally and the board went quiet for them.
    /// Bumped when the BOARDS THEMSELVES are wiped or reset server-side —
    /// distinct from `metricVersion`, which tracks what a board ranks.
    ///
    /// The local high-water assumes Game Center still holds everything we
    /// ever sent it. Delete a board's scores in App Store Connect and that
    /// is false for every player at once: their submissions get dropped
    /// against a cache describing scores the server no longer has, and no
    /// board recovers until each player happens to beat their old best.
    /// Bumping this re-keys every high-water and re-arms the backfill, so
    /// every player re-submits their bests on their next launch.
    ///
    /// e2 — all six boards cleared 2026-08-01.
    private static let boardEpoch = 2

    private static func metricVersion(_ game: TikiGame) -> Int {
        switch game {
        case .zombie: 2
        default: 1
        }
    }

    /// Per-player high-water of successfully submitted scores — pushes that
    /// can't beat it are dropped locally (Game Center keeps best-ever and
    /// would ignore them anyway; this just saves the round trips).
    ///
    /// Keyed by metric version AND player id, so both re-ranking a board and
    /// switching Game Center account start from a clean slate rather than
    /// comparing against a number from a different scale.
    private func highWaterKey(_ game: TikiGame) -> String {
        Self.highWaterKey(game, version: Self.metricVersion(game),
                          playerID: GKLocalPlayer.local.gamePlayerID)
    }

    /// Pure key builder, so the partitioning can be tested without GameKit.
    static func highWaterKey(_ game: TikiGame, version: Int, playerID: String,
                             epoch: Int = GameCenter.boardEpoch) -> String {
        "tikiLeaderboardHighWater.\(game.rawValue).e\(epoch).v\(version).\(playerID)"
    }

    /// Test seam for `boardEpoch`.
    static var currentBoardEpoch: Int { boardEpoch }

    /// Test seam for `metricVersion`, which is private by intent.
    static func rankedMetricVersion(_ game: TikiGame) -> Int { metricVersion(game) }

    private func stashPending(score: Int, for game: TikiGame) {
        let key = pendingKey(game)
        if score > UserDefaults.standard.integer(forKey: key) {
            UserDefaults.standard.set(score, forKey: key)
        }
    }

    private func pushPending(for game: TikiGame, id: String) async {
        let key = pendingKey(game)
        let score = UserDefaults.standard.integer(forKey: key)
        guard score > 0 else { return }
        let hwKey = highWaterKey(game)
        if score <= UserDefaults.standard.integer(forKey: hwKey) {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        #if DEBUG
        if Self.mockMode != nil {
            UserDefaults.standard.set(score, forKey: hwKey)
            UserDefaults.standard.removeObject(forKey: key)
            return
        }
        #endif
        do {
            try await GKLeaderboard.submitScore(
                score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id]
            )
            UserDefaults.standard.set(score, forKey: hwKey)
            UserDefaults.standard.removeObject(forKey: key)
        } catch {
            // Stays parked; the next run end or authentication retries.
        }
    }

    private func resubmitPending() {
        for game in TikiGame.allCases {
            guard let id = Self.leaderboardID(for: game) else { continue }
            Task { await pushPending(for: game, id: id) }
        }
    }

    // MARK: - Standings

    struct Entry: Identifiable {
        let rank: Int
        let name: String
        let score: Int
        let isLocal: Bool
        /// Backing GKPlayer for card lookups; nil in staging mocks.
        var player: GKPlayer? = nil
        /// When the score was earned (server-reported); nil in some mocks.
        var date: Date? = nil
        var id: Int { rank }
    }

    /// One tapped player's standing across the whole lounge.
    struct BoardStanding {
        let game: TikiGame
        let rank: Int
        let score: Int
        let date: Date?
    }

    struct PlayerCard {
        let name: String
        let photo: UIImage?
        /// One slot per game in TikiGame.allCases order; nil = never charted.
        let standings: [TikiGame: BoardStanding]
    }

    struct Standings {
        var local: Entry?
        var entries: [Entry]
        var totalPlayers: Int
    }

    enum Failure: Error { case noLeaderboard }

    @ObservationIgnored private var cache: [String: (at: Date, standings: Standings)] = [:]

    /// Top 50 plus the local player's own entry and the total player count.
    /// Cached for 60 s so the payoff-panel teaser and an immediately-opened
    /// board share one network round trip.
    func loadStandings(for game: TikiGame, forceRefresh: Bool = false) async throws -> Standings {
        guard let id = Self.leaderboardID(for: game) else { throw Failure.noLeaderboard }
        #if DEBUG
        if let mock = try Self.mockStandings() { return mock }
        #endif
        if !forceRefresh, let hit = cache[id], Date.now.timeIntervalSince(hit.at) < 60 {
            return hit.standings
        }
        let boards = try await GKLeaderboard.loadLeaderboards(IDs: [id])
        guard let board = boards.first else { throw Failure.noLeaderboard }
        let (localEntry, top, total) = try await board.loadEntries(
            for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 50)
        )
        let localID = GKLocalPlayer.local.gamePlayerID
        func convert(_ e: GKLeaderboard.Entry) -> Entry {
            Entry(
                rank: e.rank,
                name: e.player.displayName,
                score: e.score,
                isLocal: e.player.gamePlayerID == localID,
                player: e.player
                // No `date:` — deliberately. This is the path that crashed, and
                // nothing reads the result: the leaderboard screen never shows
                // an entry date (only PlayerCardView does, from BoardStanding).
                // The safest way to survive a lying nonnull property is not to
                // touch it, so the board no longer reads `date` at all and
                // `Entry.date` stays at its nil default.
            )
        }
        let standings = Standings(
            local: localEntry.map(convert),
            entries: top.map(convert),
            totalPlayers: total
        )
        cache[id] = (.now, standings)
        reconcileHighWater(for: game, against: standings)
        return standings
    }

    /// Trusts the server over the local cache.
    ///
    /// The high-water is an optimisation that assumes Game Center still holds
    /// everything we ever sent it. Delete a board's data — or reset it for a
    /// season — and that assumption breaks silently: every later submission is
    /// dropped locally against a high-water for scores the server no longer
    /// has, and the board stays empty with no error anywhere.
    ///
    /// Costs nothing extra: it reads the standings call that just happened.
    /// Clearing the high-water is enough to recover, because the next run end
    /// submits `PlayerStore.leaderboardScore` — the player's best-ever, not
    /// just that run's — so their standing is restored by playing once.
    private func reconcileHighWater(for game: TikiGame, against standings: Standings) {
        let key = highWaterKey(game)
        let stored = UserDefaults.standard.integer(forKey: key)
        guard stored > 0 else { return }
        // No entry at all means the server has nothing for this player.
        let serverScore = standings.local?.score ?? 0
        guard serverScore < stored else { return }
        UserDefaults.standard.set(serverScore, forKey: key)
    }

    // MARK: - Player cards

    @ObservationIgnored private var boardObjects: [String: GKLeaderboard] = [:]
    @ObservationIgnored private var cardCache: [String: (at: Date, card: PlayerCard)] = [:]

    /// Everything Game Center knows about one tapped player: avatar, name,
    /// and their entry on each of the six boards (rank, score, when set).
    func loadPlayerCard(for entry: Entry) async throws -> PlayerCard {
        #if DEBUG
        if let mock = Self.mockPlayerCard(for: entry) { return mock }
        #endif
        guard let player = entry.player else { throw Failure.noLeaderboard }
        let cacheKey = player.gamePlayerID
        if let hit = cardCache[cacheKey], Date.now.timeIntervalSince(hit.at) < 60 {
            return hit.card
        }
        if boardObjects.isEmpty {
            let ids = TikiGame.allCases.compactMap(Self.leaderboardID(for:))
            for board in try await GKLeaderboard.loadLeaderboards(IDs: ids) {
                boardObjects[board.baseLeaderboardID] = board
            }
        }
        var standings: [TikiGame: BoardStanding] = [:]
        for game in TikiGame.allCases {
            guard let id = Self.leaderboardID(for: game), let board = boardObjects[id] else { continue }
            let (_, entries) = try await board.loadEntries(for: [player], timeScope: .allTime)
            if let e = entries.first {
                // safeDate, not e.date — the same nonnull-lie that crashed
                // loadStandings reaches the player card through this path too.
                standings[game] = BoardStanding(game: game, rank: e.rank, score: e.score, date: e.safeDate)
            }
        }
        let photo = try? await player.loadPhoto(for: .normal)
        let card = PlayerCard(name: player.displayName, photo: photo, standings: standings)
        cardCache[cacheKey] = (.now, card)
        return card
    }

    // MARK: - Staging mocks

    #if DEBUG
    /// SIMCTL_CHILD_TIKI_LB_MOCK=1 serves a full fake board (sim has no
    /// sandbox Game Center); =empty / =offline / =unauth stage those states.
    private static var mockMode: String? {
        ProcessInfo.processInfo.environment["TIKI_LB_MOCK"]
    }

    /// Mock card for staging: the tapped board's rank/score verbatim,
    /// plausible spreads on three other boards, two never charted — so the
    /// card shows both filled rows and the "—" state.
    private static func mockPlayerCard(for entry: Entry) -> PlayerCard? {
        guard mockMode != nil else { return nil }
        let day: TimeInterval = 86_400
        var standings: [TikiGame: BoardStanding] = [
            .tikiStacks: BoardStanding(game: .tikiStacks, rank: entry.rank, score: entry.score, date: .now.addingTimeInterval(-2 * day)),
            .zombie: BoardStanding(game: .zombie, rank: entry.rank * 3 + 4, score: max(64, entry.score / 2), date: .now.addingTimeInterval(-11 * day)),
            .luau: BoardStanding(game: .luau, rank: max(1, entry.rank - 2), score: entry.score + 210, date: .now.addingTimeInterval(-day / 2)),
            .cabanaCipher: BoardStanding(game: .cabanaCipher, rank: entry.rank * 9 + 17, score: max(40, entry.score / 6), date: .now.addingTimeInterval(-34 * day)),
        ]
        if entry.isLocal {
            standings[.navigator] = BoardStanding(game: .navigator, rank: 12, score: 47, date: .now.addingTimeInterval(-5 * day))
        }
        return PlayerCard(name: entry.name, photo: nil, standings: standings)
    }

    private static func mockStandings() throws -> Standings? {
        guard let mode = mockMode else { return nil }
        switch mode {
        case "offline": throw URLError(.notConnectedToInternet)
        case "empty": return Standings(local: nil, entries: [], totalPlayers: 0)
        case let m where m.hasPrefix("big"):
            // A 1,000-player board: the fetch window is ranks 1–50. "big"
            // parks the local player at Nº 412 (pinned bar); "big:<n>"
            // seats them at that rank; "bigyou" = big:47 (scroll-to-you).
            let pool = [
                "TheBigKahuna", "MaiTaiMarv", "SaltySue88", "TorchTina", "KonaKing",
                "LagoonLarry", "DriftwoodDan", "MoonriseMona", "CocoLoco", "UkuleleUna",
                "BarracudaBex", "HulaHank", "TidalTeddy", "PineappleShirl", "GroggyGreg",
                "SeafoamSal", "VolcanoVi", "CabanaCal", "LimboLinda", "SunsetSid",
                "ReefRaff", "MangoMags", "PuffinChaser", "ZombieZeb", "PalmPilot",
            ]
            let youRank: Int
            if mode == "bigyou" {
                youRank = 47
            } else if let colon = mode.firstIndex(of: ":"), let n = Int(mode[mode.index(after: colon)...]) {
                youRank = max(1, n)
            } else {
                youRank = 412
            }
            var entries: [Entry] = []
            for i in 0..<50 {
                let rank = i + 1
                let isYou = rank == youRank
                let name: String = isYou ? "CarsonOSully"
                    : (i < pool.count ? pool[i] : pool[i - pool.count] + String(i))
                let decay: Int = i * 36
                let jitter: Int = (i % 3) * 9
                entries.append(Entry(rank: rank, name: name, score: 2680 - decay - jitter, isLocal: isYou))
            }
            let local: Entry
            if youRank <= 50 {
                local = entries[youRank - 1]
            } else {
                let tail: Int = max(20, 907 - (youRank - 50) * 2)
                local = Entry(rank: youRank, name: "CarsonOSully", score: tail, isLocal: true)
            }
            return Standings(local: local, entries: entries, totalPlayers: max(1000, youRank))
        default:
            let names = [
                "TheBigKahuna", "MaiTaiMarv", "SaltySue88", "TorchTina", "KonaKing",
                "LagoonLarry", "DriftwoodDan", "MoonriseMona", "CocoLoco", "UkuleleUna",
                "BarracudaBex", "HulaHank", "TidalTeddy", "PineappleShirl", "GroggyGreg",
                "SeafoamSal", "VolcanoVi", "CabanaCal", "LimboLinda", "SunsetSid",
                "ReefRaff", "MangoMags", "PuffinChaser", "ZombieZeb", "PalmPilot",
            ]
            let scores = [
                2340, 2105, 1980, 1720, 1610, 1495, 1380, 1240, 1150, 1040,
                960, 885, 810, 760, 700, 645, 590, 540, 495, 450,
                400, 380, 310, 240, 180,
            ]
            let entries = zip(names, scores).enumerated().map { i, pair in
                Entry(rank: i + 1, name: pair.0, score: pair.1, isLocal: false)
            }
            return Standings(
                local: Entry(rank: 212, name: "You", score: 112, isLocal: true),
                entries: entries,
                totalPlayers: 15431
            )
        }
    }
    #endif
}
