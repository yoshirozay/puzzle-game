import Foundation
import SwiftData
import Observation

// MARK: - Models

/// The player's wallet and identity. Exactly one row exists.
@Model
final class PlayerProfile {
    var points: Int
    var createdAt: Date
    /// Lounge v2 expression prefs (LOUNGE_V2_PLAN §4–§5): which live view each
    /// window shows and the rug's colorway. Additive defaulted fields —
    /// lightweight migration, same class as GameRecord.milestoneMask.
    var windowViewEast: String = "sunset"
    var windowViewWest: String = "sunset"
    var rugColorway: Int = 0
    /// Top Shelf's Depth Charge shelf: charges owned, and whether the one-time
    /// house comp (poured at the first near-full board) has ever happened.
    /// Additive defaulted fields — lightweight migration, same class as
    /// GameRecord.milestoneMask.
    var zombieBombs: Int = 0
    var zombieBombGranted: Bool = false
    /// Luau's Lounge Cat basket: same comp shape as the Depth Charge, granted
    /// the first time a campaign night hits the low-moves danger zone.
    var luauCats: Int = 0
    var luauCatGranted: Bool = false
    /// Vic's daily round: when he last poured a comp refill in the lounge.
    /// Nil until the first pour ever. Additive optional — lightweight
    /// migration, same class as GameRecord.lastPlayed.
    var lastDailyCompAt: Date?
    /// Shared lives pool (Candy Crush shape): one count for the whole
    /// bundle, cap `PlayerStore.livesCap`. Fresh installs start full.
    /// Additive defaulted field — lightweight migration, same class as
    /// zombieBombs.
    var lives: Int = 3
    /// Wall-clock start of the current refill period. Nil while the pool
    /// is full (no timer runs). Additive optional — lightweight migration.
    var livesRefillAnchor: Date?
    /// How many Luau campaign nights this player has ever cleared. The
    /// campaign's own progress list lives in Luau's save state, which the
    /// store cannot read — but the lives activation gate needs a persisted
    /// depth signal it can check from anywhere, so the view mirrors the
    /// count here at each run end. Monotonic. Additive defaulted field —
    /// lightweight migration, same class as zombieBombs.
    var luauLevelsCleared: Int = 0
    /// Lifetime count of Vic's Nightly Nine pours claimed. Existing installs
    /// start at 0 and earn their three — the App Store rating ask gates on
    /// this. Additive defaulted field — lightweight migration.
    var nightlyPoursClaimed: Int = 0
    /// When we last asked for an App Store rating (nil = never). Our
    /// 120-day re-space lives here; iOS caps display independently.
    /// Additive optional — lightweight migration.
    var lastRatingAskAt: Date?
    /// The first game this player ever entered, as a `TikiGame.rawValue`.
    /// Write-once, ever — it backs the only analytics dimension that
    /// supports a true install cohort (ANALYTICS_PLAN §4.2), and it cannot
    /// be reconstructed after the fact. Nil for installs that predate it.
    /// Additive optional — lightweight migration, same class as lastRatingAskAt.
    var firstGameID: String?

    init(points: Int = 0, createdAt: Date = .now) {
        self.points = points
        self.createdAt = createdAt
    }
}

/// Per-game lifetime stats. One row per game, keyed by TikiGame.rawValue.
@Model
final class GameRecord {
    @Attribute(.unique) var gameID: String
    var bestScore: Int
    var gamesPlayed: Int
    var totalScore: Int
    var lastPlayed: Date?
    /// Depth-state milestones ever reached (bit layout documented at
    /// `recordMilestone`). Additive defaulted field — lightweight migration.
    var milestoneMask: Int = 0
    /// Wins in a row (`recordRun` raises it, `breakStreak` zeroes it on a
    /// defeat) and the best such run. Cipher's board ranks `bestStreak`;
    /// other games keep them as stats. Additive defaulted fields.
    var streak: Int = 0
    var bestStreak: Int = 0
    /// Best end-of-run board value (Top Shelf ranks this — see
    /// `leaderboardScore(for:)`). Additive defaulted field.
    var bestBoardValue: Int = 0

    init(gameID: String) {
        self.gameID = gameID
        self.bestScore = 0
        self.gamesPlayed = 0
        self.totalScore = 0
        self.lastPlayed = nil
        self.milestoneMask = 0
        self.streak = 0
        self.bestStreak = 0
        self.bestBoardValue = 0
    }
}

/// A purchasable lounge item. The catalog is upserted at every launch;
/// purchasedAt/isPlaced carry the player's progress.
@Model
final class LoungeItem {
    @Attribute(.unique) var itemID: String
    var name: String
    var price: Int
    var purchasedAt: Date?
    var isPlaced: Bool
    /// Lounge v2 drag placement (LOUNGE_V2_PLAN §6): the item's world-x
    /// fraction, or -1 for its designed default anchor. The y band derives
    /// from the item type. Additive defaulted field — lightweight migration.
    var posX: Double = -1
    /// Floor depth, 0…1: 0 = the wall rail (designed default), 1 = the
    /// deepest downstage point (closest to the camera — Carson's device
    /// note: pieces grow as they come down the floor). Only
    /// LoungeRoomView.depthEligible pieces ever get > 0. Additive
    /// defaulted field — lightweight migration (replaced the short-lived
    /// two-band posBand the same evening it shipped, pre-release).
    var posDepth: Double = 0

    init(itemID: String, name: String, price: Int) {
        self.itemID = itemID
        self.name = name
        self.price = price
        self.purchasedAt = nil
        self.isPlaced = false
    }
}

/// Generic per-game save state: one row per game, JSON payload owned by the
/// game (live merge board, solved puzzle IDs, current cipher assignments...).
/// Keeps a killed app from losing an in-progress run.
@Model
final class GameSaveState {
    @Attribute(.unique) var gameID: String
    var payload: String
    var updatedAt: Date

    init(gameID: String, payload: String) {
        self.gameID = gameID
        self.payload = payload
        self.updatedAt = .now
    }
}

// MARK: - Store
// (RunSummary moved to RunSummary.swift so headless tools can source
// LuauGame without pulling in PlayerStore's SwiftData/SwiftUI deps.)

/// The app's single persistence gateway. Games and views call typed methods;
/// SwiftData details stay in here.
@MainActor
@Observable
final class PlayerStore {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// Mirrored for cheap observation by UI (kept in sync with the profile row).
    private(set) var points: Int = 0

    /// Mirrored placement state (same pattern as `points`): LoungeItem rows are
    /// not observable through the computed `loungeItems` fetch, so the lounge
    /// room renders from this set and updates the moment a purchase lands.
    private(set) var placedItemIDs: Set<String> = []

    /// Per-game onboarding skip. SKIP silences only the game it was tapped
    /// in; every other game still teaches itself on first entry.
    ///
    /// This was bundle-global until 2026-08-03 (one key, `tikiOnboardingSkipped`),
    /// which meant one SKIP tap anywhere suppressed the coach everywhere. Luau
    /// leads the rail, so the players most likely to skip it — the impatient
    /// ones — were exactly the players never taught Totem or Top Shelf. Carson
    /// caught it watching a new device open Top Shelf to no tutorial.
    ///
    /// The legacy global key is deliberately NOT migrated (Carson's call: "let
    /// it lapse"). An install carrying it gets its un-seen lessons back rather
    /// than inheriting silence — the friendlier direction, and the flag only
    /// ever meant "not right now" anyway. Per-game `seenHowTo` still lives in
    /// each game's save state, so anyone who actually COMPLETED a tutorial is
    /// unaffected.
    static func onboardingSkipKey(_ game: TikiGame) -> String {
        "tikiOnboardingSkipped.\(game.rawValue)"
    }

    func onboardingSkipped(for game: TikiGame) -> Bool {
        UserDefaults.standard.bool(forKey: Self.onboardingSkipKey(game))
    }

    func setOnboardingSkipped(_ skipped: Bool, for game: TikiGame) {
        UserDefaults.standard.set(skipped, forKey: Self.onboardingSkipKey(game))
    }

    /// First real life spend — the education toast fires once, ever.
    /// Same UserDefaults shape as `onboardingSkipped`.
    private static let livesExplainedKey = "tikiLivesExplained"
    var livesExplained: Bool {
        get { UserDefaults.standard.bool(forKey: Self.livesExplainedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.livesExplainedKey) }
    }

    /// The lounge's first-run coach fires once. Silent dismissal on success,
    /// SKIP dismissal, or an already-owned welcome gift all flip this true.
    private static let loungeSeenKey = "tikiLoungeOnboardingSeen"
    var loungeOnboardingSeen: Bool {
        get { UserDefaults.standard.bool(forKey: Self.loungeSeenKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.loungeSeenKey) }
    }

    /// Vic's welcome mug — the free gift the onboarding hands over. Fixed item
    /// so the seeded first-success (rubric §2) is always the same object.
    static let welcomeGiftItemID = "flamingMug"

    /// The one gated purchase: the Neon Tiki Sign unlocks after the first
    /// milestone in each of the five games. It gates on play, never payment;
    /// every other item stays wallet-only.
    static let signItemID = "neonTikiSign"

    /// Persisted so the free-purchase bypass in `purchase(_:)` fires exactly
    /// once, even across launches — a resumed onboarding still gets the gift.
    private static let welcomeGiftKey = "tikiLoungeWelcomeGiftClaimed"
    var welcomeGiftClaimed: Bool {
        get { UserDefaults.standard.bool(forKey: Self.welcomeGiftKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.welcomeGiftKey) }
    }

    /// The lounge's one-time discovery drift (the camera nudges west and
    /// settles back once the west wing has content) fires once per install.
    private static let panHintKey = "tikiLoungePanHintShown"
    var loungePanHintShown: Bool {
        get { UserDefaults.standard.bool(forKey: Self.panHintKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.panHintKey) }
    }

    /// `url` points the store at a custom file — tests use a temp file for
    /// multi-launch scenarios so they never open the app's real default.store
    /// (doing so corrupted it: CoreData disk I/O errors mid-suite).
    init(inMemory: Bool = false, url: URL? = nil) {
        let config: ModelConfiguration
        if let url {
            config = ModelConfiguration(url: url)
        } else {
            config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        }
        do {
            container = try ModelContainer(
                for: PlayerProfile.self, GameRecord.self, LoungeItem.self,
                GameSaveState.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
        migrateLegacyBestIfNeeded()
        syncLoungeCatalog()
        retroCreditMilestonesIfNeeded()
        #if DEBUG
        applyDebugMilestoneMask()
        applyDebugLives()
        applyDebugRating()
        if ProcessInfo.processInfo.environment["TIKI_CATALOG"] == "1" {
            let items = loungeItems
            let total = items.reduce(0) { $0 + $1.price }
            let gift = items.first { $0.itemID == Self.welcomeGiftItemID }?.price ?? 0
            print("[catalog] rows=\(items.count) priceTotal=\(total) realSpend=\(total - gift)")
        }
        #endif
        points = profile().points
        placedItemIDs = Set(loungeItems.filter(\.isPlaced).map(\.itemID))
        let prof = profile()
        windowViewEast = prof.windowViewEast
        windowViewWest = prof.windowViewWest
        rugColorway = prof.rugColorway
        zombieBombs = prof.zombieBombs
        zombieBombGranted = prof.zombieBombGranted
        luauCats = prof.luauCats
        luauCatGranted = prof.luauCatGranted
        luauLevelsCleared = prof.luauLevelsCleared
        // Roll any pending refill onto the mirrors before the first paint.
        _ = materializeLives(now: .now)
        refreshNightlyMirrors()
        nightlyTrackingEnabled = true
        itemPositions = Dictionary(uniqueKeysWithValues:
            loungeItems.filter { $0.posX >= 0 }.map { ($0.itemID, $0.posX) })
        itemDepths = Dictionary(uniqueKeysWithValues:
            loungeItems.filter { $0.posDepth > 0 }.map { ($0.itemID, $0.posDepth) })
    }

    // MARK: lounge v2 drag placement (mirrored like `placedItemIDs`)

    /// Player-chosen world-x fractions; items absent here sit at their
    /// designed default anchors.
    private(set) var itemPositions: [String: Double] = [:]

    func setItemPosition(_ id: String, cx: Double) {
        // Reject NaN and clamp to the world-x fraction domain: init's
        // rehydration filter (posX >= 0) would otherwise drop what the live
        // mirror shows — the room must look the same before and after relaunch.
        guard !cx.isNaN, let item = loungeItems.first(where: { $0.itemID == id }) else { return }
        let x = min(max(cx, 0), 1)
        item.posX = x
        itemPositions[id] = x
        save()
    }

    /// Player-chosen floor depths (0…1); items absent here stand on the
    /// wall rail (depth 0).
    private(set) var itemDepths: [String: Double] = [:]

    func setItemDepth(_ id: String, depth: Double) {
        // NaN survives min/max clamping (comparison-order) — reject it
        // before it poisons posDepth and the layout math downstream.
        guard !depth.isNaN, let item = loungeItems.first(where: { $0.itemID == id }) else { return }
        let d = min(max(depth, 0), 1)
        item.posDepth = d
        if d == 0 { itemDepths.removeValue(forKey: id) } else { itemDepths[id] = d }
        save()
    }

    /// VIC TIDIES UP: every piece back to its designed anchor.
    func resetPlacements() {
        for item in loungeItems where item.posX >= 0 { item.posX = -1 }
        for item in loungeItems where item.posDepth > 0 { item.posDepth = 0 }
        itemPositions = [:]
        itemDepths = [:]
        save()
    }

    // MARK: lounge v2 expression prefs (mirrored like `points`)

    private(set) var windowViewEast: String = "sunset"
    private(set) var windowViewWest: String = "sunset"
    private(set) var rugColorway: Int = 0

    func setWindowView(_ view: String, east: Bool) {
        let prof = profile()
        if east { prof.windowViewEast = view; windowViewEast = view }
        else { prof.windowViewWest = view; windowViewWest = view }
        save()
    }

    func setRugColorway(_ index: Int) {
        let prof = profile()
        prof.rugColorway = index
        rugColorway = index
        save()
    }

    /// houseStanding's tier index (0–3) for occupancy logic in the room.
    var houseStandingTier: Int {
        switch combinedMilestoneMask.nonzeroBitCount {
        case ..<5: return 0
        case ..<10: return 1
        case ..<15: return 2
        default: return 3
        }
    }

    // MARK: fetch-or-create

    private func profile() -> PlayerProfile {
        if let existing = (try? context.fetch(FetchDescriptor<PlayerProfile>()))?.first {
            return existing
        }
        let fresh = PlayerProfile()
        context.insert(fresh)
        save()
        return fresh
    }

    func record(for game: TikiGame) -> GameRecord {
        let id = game.rawValue
        let descriptor = FetchDescriptor<GameRecord>(predicate: #Predicate { $0.gameID == id })
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let fresh = GameRecord(gameID: id)
        context.insert(fresh)
        save()
        return fresh
    }

    func bestScore(for game: TikiGame) -> Int {
        record(for: game).bestScore
    }

    /// One-shot, called at launch. Top Shelf's run score moved from the
    /// cumulative merge total to the board's face value, and the two are a
    /// factor of roughly (top tier − 1) apart — so every `bestScore` banked
    /// before the switch sits ~10x above anything the new metric can reach
    /// and would stand as an unbeatable BEST forever. Realign it to the
    /// face-value best, which `recordRun` has banked separately since
    /// 0.1.3 (15); a player who last played before that starts the metric
    /// from zero, which is the honest answer for a stat never measured.
    func migrateTopShelfBestToBoardValue() {
        let key = "tikiTopShelfBestIsBoardValue"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let rec = record(for: .zombie)
        guard rec.bestScore != rec.bestBoardValue else { return }
        rec.bestScore = rec.bestBoardValue
        save()
    }

    /// The number `game`'s leaderboard ranks — NOT always its best run.
    ///
    /// - **Luau** ranks career total. A Luau "run" is a single LEVEL
    ///   (`score` resets at every level start) and levels grant 13–50 moves,
    ///   so best-run ranked *which level you happened to play*.
    /// - **Cipher** ranks the longest run of phrases solved in a row. Its
    ///   per-phrase score is dominated by phrase LENGTH (36–126 by letter
    ///   count), which is drawn from catalog position, not earned — and it
    ///   capped out, so the board tied. A streak is unbounded and reads
    ///   plainly on the board.
    /// - **Top Shelf** ranks the board's face value at run end — the number
    ///   the player can read straight off the grid. Its cumulative merge
    ///   score is exponential (one 2048 merge outweighs hundreds of early
    ///   ones), so it read as a restatement of "biggest tile" and told the
    ///   player nothing they could see.
    /// - Everything else ranks its best run, where a run is a full session.
    func leaderboardScore(for game: TikiGame) -> Int {
        let rec = record(for: game)
        switch game {
        case .luau: return rec.totalScore
        case .cabanaCipher: return rec.bestStreak
        case .zombie: return rec.bestBoardValue
        default: return rec.bestScore
        }
    }

    /// A defeat ends the current run of wins. Cipher calls this from its
    /// defeat path (defeats never reach `recordRun`, by lives canon).
    func breakStreak(for game: TikiGame) {
        let rec = record(for: game)
        guard rec.streak != 0 else { return }
        rec.streak = 0
        save()
    }

    // MARK: gameplay

    /// Call when a run ends. Updates the game's record, pays points into the
    /// wallet, and returns a summary for the game-over UI.
    /// `earnScore` lets games whose native scoring runs hotter than the
    /// shared economy (Zombie's classic-2048 scores) pass a scaled value for
    /// point earning while `score` stays the displayed/best-tracked number.
    /// `boardValue` is the end-of-run face value of the board, for games
    /// whose leaderboard ranks that rather than the run score (Top Shelf).
    @discardableResult
    func recordRun(game: TikiGame, score: Int, earnScore: Int? = nil,
                   wonLevel: Bool = false, boardValue: Int? = nil,
                   now: Date = .now) -> RunSummary {
        let rec = record(for: game)
        let isNewBest = score > rec.bestScore
        if isNewBest { rec.bestScore = score }
        rec.gamesPlayed += 1
        rec.totalScore += score
        rec.streak += 1
        rec.bestStreak = max(rec.bestStreak, rec.streak)
        if let boardValue { rec.bestBoardValue = max(rec.bestBoardValue, boardValue) }
        rec.lastPlayed = .now

        let earned = max(1, (earnScore ?? score) / 10)
        let prof = profile()
        prof.points += earned
        points = prof.points
        Analytics.resource(.source, currency: "points", amount: earned,
                           itemType: "run", itemId: game.rawValue)

        save()
        recordNightlyRun(game: game, score: score, earned: earned, won: wonLevel, now: now)
        // Mirror the run onto its Game Center board — offline runs park and
        // land on the next sign-in. (Navigator submits passages separately.)
        // `rec` is already updated above, so this reads the post-run value
        // for whichever stat this game's board ranks (best run / career
        // total / streak) — see leaderboardScore(for:).
        GameCenter.shared.submitRunScore(leaderboardScore(for: game), for: game)
        // Run outcomes are NOT recorded here. This method's defeat coverage
        // differs per game — Blueprints, Cipher and Navigator never reach it
        // on a loss — so anything counted from here is incomparable across
        // the bundle. Each game view calls `Analytics.runEnded` itself with
        // an explicit outcome (ANALYTICS_PLAN §3.2).
        return RunSummary(
            best: rec.bestScore,
            isNewBest: isNewBest,
            pointsEarned: earned,
            totalPoints: prof.points
        )
    }

    /// Navigator's wallet divisor. It is the bundle's only PER-PASSAGE
    /// earner — every other game pays once per multi-minute run — so raw
    /// passage scores ran ~10x the shared economy (SHOP_PLAN.md §2). Same
    /// shape as Top Shelf's hot-score divisor, but named and tested here
    /// because the whole price ladder is calibrated to it.
    static func navigatorEarnScore(_ levelScore: Int) -> Int {
        levelScore / 5
    }

    // MARK: milestones

    /// Canonical milestoneMask bit layout. One global index space; each
    /// game's record only ever sets its own range, so ORing all five masks
    /// yields the cross-game total.
    ///   bits 0–3    Stacks      score 150 / 400 / 800 / 1500
    ///   bits 4–7    Zombie      board tier 5 / 7 / 9 / 11
    ///   bits 8–10   Luau        score 150 / 400 / 700
    ///   bits 11–13  Blueprints  puzzles solved 5 / 15 / 30
    ///   bits 14–17  Cipher      matchbooks completed 1 / 4 / 8 / 16
    ///   bit  22     Blueprints  whole drawer drafted (60). Sits above the
    ///               Honu reservation at 18–21 rather than extending 11–13,
    ///               so the original three thresholds stay where players
    ///               already earned them.
    static let milestoneMint = 75

    /// Sets a milestone bit and pays the mint exactly once ("Vic buys a
    /// round"). Returns whether the bit was new — drives the game-over toast.
    @discardableResult
    func recordMilestone(game: TikiGame, bit: Int) -> Bool {
        // Swift's smart shift makes 1 << 64 and 1 << -1 both 0, so the
        // already-set guard below can't catch out-of-width bits — they'd
        // mint 75 points on EVERY call. Reject them outright.
        guard (0..<Int.bitWidth).contains(bit) else { return false }
        let rec = record(for: game)
        let flag = 1 << bit
        guard rec.milestoneMask & flag == 0 else { return false }
        rec.milestoneMask |= flag
        grant(points: Self.milestoneMint, source: "milestone",
              sourceID: "\(game.rawValue):\(bit)")
        return true
    }

    /// The clean bonus faucet (milestone mints, matchbook bonuses): pays the
    /// wallet without touching gamesPlayed/totalScore/bestScore — bonuses
    /// never route through recordRun.
    /// `source`/`sourceID` name the wallet inflow for the economy dashboard —
    /// they must stay inside `Analytics`' declared item-type vocabulary.
    /// `sourceID` must never be empty — GA rejects a resource event with a
    /// blank itemId outright, which silently dropped every milestone mint
    /// until this was caught in the SDK log. The default is a valid
    /// placeholder rather than "", so an un-attributed grant still lands.
    func grant(points n: Int, source: String = "milestone",
               sourceID: String = "unattributed") {
        let prof = profile()
        prof.points += n
        points = prof.points
        save()
        recordNightlyPoints(n)
        Analytics.resource(.source, currency: "points", amount: n,
                           itemType: source, itemId: sourceID)
    }

    // MARK: consumables (Top Shelf Depth Charge)

    /// Mirrored for cheap observation by UI (kept in sync like `points`).
    private(set) var zombieBombs: Int = 0
    private(set) var zombieBombGranted = false

    /// The one-time house comp: a single Depth Charge, poured the first time
    /// a run reaches the danger zone. Returns false if ever poured before.
    /// Free forever after that — refills (earned-points or otherwise) are a
    /// separate, undecided design.
    @discardableResult
    func grantZombieBombIfNeeded() -> Bool {
        let prof = profile()
        guard !prof.zombieBombGranted else { return false }
        prof.zombieBombGranted = true
        prof.zombieBombs += 1
        zombieBombGranted = true
        zombieBombs = prof.zombieBombs
        save()
        return true
    }

    /// Spends one Depth Charge. Returns false when the shelf is dry — the
    /// caller must not have detonated anything.
    @discardableResult
    func spendZombieBomb() -> Bool {
        let prof = profile()
        guard prof.zombieBombs > 0 else { return false }
        prof.zombieBombs -= 1
        zombieBombs = prof.zombieBombs
        save()
        return true
    }

    /// Mirrored for cheap observation by UI (kept in sync like `points`).
    private(set) var luauCats: Int = 0
    private(set) var luauCatGranted = false

    /// Mirrored for cheap observation (kept in sync like `points`). Backs
    /// Luau's half of the lives activation gate.
    private(set) var luauLevelsCleared: Int = 0

    /// Mirrors Luau's campaign depth into the store. The count lives in
    /// Luau's save state, which the store cannot decode, so the view reports
    /// it at each run end. Monotonic — a replayed or abandoned night can
    /// never walk the gate back off.
    @discardableResult
    func noteLuauLevelsCleared(_ count: Int) -> Bool {
        let prof = profile()
        guard count > prof.luauLevelsCleared else { return false }
        prof.luauLevelsCleared = count
        luauLevelsCleared = count
        save()
        return true
    }

    /// The Lounge Cat's one-time comp — same contract as the Depth Charge's.
    @discardableResult
    func grantLuauCatIfNeeded() -> Bool {
        let prof = profile()
        guard !prof.luauCatGranted else { return false }
        prof.luauCatGranted = true
        prof.luauCats += 1
        luauCatGranted = true
        luauCats = prof.luauCats
        save()
        return true
    }

    /// Spends one Lounge Cat. Returns false when the basket is empty — the
    /// caller must not have placed anything.
    @discardableResult
    func spendLuauCat() -> Bool {
        let prof = profile()
        guard prof.luauCats > 0 else { return false }
        prof.luauCats -= 1
        luauCats = prof.luauCats
        save()
        return true
    }

    // MARK: shared lives pool (Candy Crush shape)

    /// Bundle-global pool cap. Fresh installs start full; refill never
    /// overshoots this.
    ///
    /// v2: 3, down from 5, on an hour instead of half an hour. Deliberately
    /// harsher — across the three shipping games a run takes materially
    /// longer to lose than it did in the six-game bundle, so five lives on a
    /// 30-minute drip was never a real ceiling. The `livesActive` gate is
    /// what keeps this off new players.
    static let livesCap = 3
    /// Wall-clock seconds per granted life while below cap.
    static let livesRefillPeriod: TimeInterval = 60 * 60

    /// Mirrored for cheap observation by UI (kept in sync like `points`).
    /// Always the post-refill count — `materializeLives` rolls pending
    /// grants onto the profile before writing this.
    private(set) var lives: Int = PlayerStore.livesCap
    /// Seconds until the next life, or nil while the pool is full (no
    /// timer runs). Mirrored for the chip / out-of-lives sheet.
    private(set) var livesSecondsToNext: Int? = nil
    /// Monotonic count of successful spends — an EVENT mirror, not state.
    /// Escaping engine hooks (Totem's onGameOver) arm their defeat beat via
    /// onChange of this: the lives VALUE can revisit the same number inside
    /// one spend (a pending refill materializes first), and a same-value
    /// change never fires onChange.
    private(set) var livesSpendCount = 0

    /// Snapshot of the shared pool after applying any pending refill.
    struct LivesSnapshot: Equatable {
        var count: Int
        /// Nil when the pool is full — no timer is running.
        var secondsToNext: Int?
    }

    /// Every launch game spends a life on a real defeat — Totem stack-death,
    /// Top Shelf board-full, a LOST Luau night, Navigator voyage end,
    /// Blueprints' third wrong fill, Cipher's fifth wrong letter.
    static func gameSpendsLives(_ game: TikiGame) -> Bool {
        switch game {
        case .tikiStacks, .zombie, .luau, .navigator, .blueprints, .cabanaCipher:
            return true
        }
    }

    /// Depth at which each game starts charging for defeats. Lives are a
    /// conversion lever, and a player who has not been caught by a game yet
    /// will not convert — they will just leave. So a game plays FREE until
    /// the player has demonstrably taken to it, and only then does it draw
    /// on the shared pool.
    ///
    /// Per-game by design: the pool is shared, but being hooked on Luau says
    /// nothing about Totem. A Luau regular who opens Totem for the first
    /// time still gets Totem free until they are good at it — and can always
    /// play SOMETHING even at zero lives.
    static func livesActivationDepth(for game: TikiGame) -> Int {
        switch game {
        case .luau: return 10          // campaign nights cleared
        case .zombie: return 64        // best board value (a 64 tile)
        case .tikiStacks: return 300   // best score
        // Cut games keep the old always-on behavior; they are unreachable.
        case .cabanaCipher, .blueprints, .navigator: return 0
        }
    }

    /// The player's current depth in `game`, on the same scale as
    /// `livesActivationDepth`.
    func livesActivationProgress(for game: TikiGame) -> Int {
        switch game {
        case .luau: return luauLevelsCleared
        case .zombie: return record(for: .zombie).bestBoardValue
        case .tikiStacks: return record(for: .tikiStacks).bestScore
        case .cabanaCipher, .blueprints, .navigator: return 0
        }
    }

    /// True once `game` has started charging this player for defeats.
    /// Never regresses: every backing signal is a best-ever or a monotonic
    /// count, so a bad run cannot switch lives back off.
    func livesActive(for game: TikiGame) -> Bool {
        livesActivationProgress(for: game) >= Self.livesActivationDepth(for: game)
    }

    /// True once ANY game has started charging. Drives whether the lives
    /// chip appears at all — a new player should not see a pool they are
    /// not yet spending from.
    var livesActiveAnywhere: Bool {
        TikiGame.allCases.contains { Self.gameSpendsLives($0) && livesActive(for: $0) }
    }

    /// Gate predicate: true when a defeat-capable game must show the
    /// out-of-lives sheet instead of launching / playing again.
    func isOutOfLives(for game: TikiGame, now: Date = .now) -> Bool {
        Self.gameSpendsLives(game) && livesActive(for: game)
            && materializeLives(now: now).count == 0
    }

    /// Current pool after rolling pending refills — a PURE read (resolve
    /// only, never writes), so the chip / sheet TimelineView ticks can call
    /// it from view bodies without mutating observable state or saving
    /// mid-update. Grants persist at the mutation points instead: spend,
    /// the launch gate, init, and the debug stage hook.
    func livesSnapshot(now: Date = .now) -> LivesSnapshot {
        let resolved = resolveLives(readLivesRaw(), now: now)
        return LivesSnapshot(count: resolved.count,
                             secondsToNext: secondsToNext(resolved, now: now))
    }

    /// Wall-clock seconds until the pool sits at cap — a PURE read (same
    /// resolve path as `livesSnapshot`). Nil when already full. Remainder
    /// carries: current period's `secondsToNext` plus one full period per
    /// additional missing life. Used by the restock local-notification
    /// schedule so a backgrounded app can fire exactly when the bar is full.
    func secondsUntilFull(now: Date = .now) -> Int? {
        let resolved = resolveLives(readLivesRaw(), now: now)
        guard resolved.count < Self.livesCap else { return nil }
        // resolve re-anchors a missing timer to `now`, so secondsToNext is
        // always non-nil while below cap after resolve.
        let toNext = secondsToNext(resolved, now: now) ?? Int(Self.livesRefillPeriod)
        let missing = Self.livesCap - resolved.count
        // One life lands at toNext; each further missing life is a full period.
        return toNext + (missing - 1) * Int(Self.livesRefillPeriod)
    }

    /// Spends one life for a real defeat. Tutorials and non-spending games
    /// leave the pool untouched; floors at zero. Spending from a full pool
    /// starts the refill timer.
    @discardableResult
    func spendLifeForDefeat(game: TikiGame, duringTutorial: Bool = false,
                            now: Date = .now) -> Bool {
        guard Self.gameSpendsLives(game), livesActive(for: game),
              !duringTutorial else { return false }
        let spent = spendLife(now: now)
        // The lives pool is a real currency, so it rides GA's economy
        // dashboard rather than a design event. Attributed here, not in
        // `spendLife`, because this is the layer that knows which game
        // took the life — and the only layer that excludes tutorials.
        if spent {
            Analytics.resource(.sink, currency: "lives", amount: 1,
                               itemType: "defeat", itemId: game.rawValue)
        }
        return spent
    }

    /// Spends one life. Returns false when the pool is already empty.
    @discardableResult
    func spendLife(now: Date = .now) -> Bool {
        var state = materializeLives(now: now)
        guard state.count > 0 else { return false }
        state.count -= 1
        // Leaving a full pool starts the timer; an already-running period
        // keeps its remainder (no re-anchor on spend).
        if state.count < Self.livesCap, state.anchor == nil {
            state.anchor = now
        }
        writeLives(state, now: now)
        livesSpendCount += 1
        return true
    }

    private struct LivesRaw: Equatable {
        var count: Int
        /// Start of the current incomplete refill period; nil when full.
        var anchor: Date?
    }

    private func readLivesRaw() -> LivesRaw {
        let prof = profile()
        return LivesRaw(count: prof.lives, anchor: prof.livesRefillAnchor)
    }

    private func writeLives(_ state: LivesRaw, now: Date) {
        let prof = profile()
        prof.lives = state.count
        prof.livesRefillAnchor = state.anchor
        save()
        lives = state.count
        livesSecondsToNext = secondsToNext(state, now: now)
    }

    // TESTFLIGHT ONLY — REMOVE BEFORE APP STORE SUBMISSION.
    /// Fills the shared lives pool so testers never wait out a 30-minute refill.
    func refillLivesToCap(now: Date = .now) {
        writeLives(LivesRaw(count: Self.livesCap, anchor: nil), now: now)
    }

    /// Today's lives after applying pending refill grants. Pure roll-on-read
    /// (same shape as `nightlyState(now:)`): grants land on the profile when
    /// the resolved state differs from storage.
    @discardableResult
    private func materializeLives(now: Date) -> LivesRaw {
        let raw = readLivesRaw()
        let resolved = resolveLives(raw, now: now)
        if resolved != raw {
            writeLives(resolved, now: now)
        } else {
            lives = resolved.count
            livesSecondsToNext = secondsToNext(resolved, now: now)
        }
        return resolved
    }

    /// Applies +1 life per `livesRefillPeriod` of wall-clock time while
    /// below cap. Remainder carries across grants; a backwards clock may
    /// re-anchor but never mints or destroys lives; at full the timer clears.
    private func resolveLives(_ raw: LivesRaw, now: Date) -> LivesRaw {
        var count = min(max(raw.count, 0), Self.livesCap)
        if count >= Self.livesCap {
            return LivesRaw(count: Self.livesCap, anchor: nil)
        }
        guard let anchor = raw.anchor else {
            // Below cap with no anchor (legacy / staged): re-anchor without
            // minting so the next period starts cleanly from `now`.
            return LivesRaw(count: count, anchor: now)
        }
        if now < anchor {
            // Clock went backwards — re-anchor, never mint or destroy.
            return LivesRaw(count: count, anchor: now)
        }
        let elapsed = now.timeIntervalSince(anchor)
        let periods = Int(elapsed / Self.livesRefillPeriod)
        guard periods > 0 else {
            return LivesRaw(count: count, anchor: anchor)
        }
        let remainder = elapsed - TimeInterval(periods) * Self.livesRefillPeriod
        count = min(Self.livesCap, count + periods)
        if count >= Self.livesCap {
            return LivesRaw(count: Self.livesCap, anchor: nil)
        }
        // Remainder carries: the next period is already `remainder` in.
        return LivesRaw(count: count, anchor: now.addingTimeInterval(-remainder))
    }

    private func secondsToNext(_ state: LivesRaw, now: Date) -> Int? {
        guard state.count < Self.livesCap, let anchor = state.anchor else { return nil }
        let remaining = Self.livesRefillPeriod - now.timeIntervalSince(anchor)
        return max(0, Int(ceil(remaining - 0.000_001)))
    }

    #if DEBUG
    /// Staging-only: pin the pool to an exact count + optional refill
    /// anchor so refill math / gate tests don't wait on wall clock.
    func debugStageLives(count: Int, refillAnchor: Date?, now: Date = .now) {
        let clamped = min(max(count, 0), Self.livesCap)
        let anchor: Date? = clamped >= Self.livesCap ? nil : refillAnchor
        writeLives(LivesRaw(count: clamped, anchor: anchor), now: now)
    }
    #endif

    // MARK: Vic's daily round (lounge comp refill)

    /// One of each — the daily pour is a regen, not a stockpile: hoarded
    /// rescues would turn the leaderboards into inventory contests.
    static let dailyCompCap = 1

    /// Games whose comp the danger moment has already introduced AND whose
    /// slot is empty — the pool Vic pours from.
    private func dailyCompPool() -> [TikiGame] {
        let prof = profile()
        var pool: [TikiGame] = []
        if prof.zombieBombGranted, prof.zombieBombs < Self.dailyCompCap { pool.append(.zombie) }
        if prof.luauCatGranted, prof.luauCats < Self.dailyCompCap { pool.append(.luau) }
        return pool
    }

    /// Which of a multi-game pool tonight pours from. Day-seeded rather than
    /// `randomElement()` so the board can SHOW tonight's prize before it is
    /// claimed and be telling the truth — a preview that rolls its own dice
    /// is worse than no preview. Distribution over a week is unchanged.
    private static func pourSeed(now: Date) -> Int {
        let day = Calendar.current.startOfDay(for: now)
        return abs(Int(day.timeIntervalSince1970 / 86_400))
    }

    /// Tonight's pour, resolved without granting it. Read freely — the board
    /// calls this on every render.
    func previewNightlyReward(now: Date = .now) -> NightlyReward {
        #if DEBUG
        // Staging: SIMCTL_CHILD_TIKI_POUR=charge|cat|points forces a face.
        // Which comp is live depends on which danger moments a profile has
        // already seen, so the three payoffs are otherwise hours apart.
        switch ProcessInfo.processInfo.environment["TIKI_POUR"] {
        case "charge": return .item(.zombie)
        case "cat": return .item(.luau)
        case "points": return .points(Self.nightlyPointsPour)
        default: break
        }
        #endif
        let pool = dailyCompPool()
        guard !pool.isEmpty else { return .points(Self.nightlyPointsPour) }
        return .item(pool[Self.pourSeed(now: now) % pool.count])
    }

    // MARK: the Nightly Nine (daily missions)

    /// One fixed board of nine, forever — progress resets each local day.
    /// Kinds are tracked at the store's choke points (recordRun / grant), so
    /// games carry no mission code of their own.
    enum NightlyKind {
        case runScore(TikiGame, Int)   // best single round today reaches N
        case luauWin                   // clear a campaign night
        case gameRuns(TikiGame, Int)   // N finished rounds in one game
        case anyRuns(Int)              // N finished rounds anywhere
        case distinctGames(Int)        // N different games played
        case pointsEarned(Int)         // N wallet points earned today
    }

    struct NightlyChallenge: Identifiable {
        let id: String
        let title: String
        let kind: NightlyKind
        var target: Int {
            switch kind {
            case .runScore(_, let n), .gameRuns(_, let n), .anyRuns(let n),
                 .distinctGames(let n), .pointsEarned(let n):
                return n
            case .luauWin:
                return 1
            }
        }

        var isPointsKind: Bool {
            if case .pointsEarned = kind { return true }
            return false
        }
    }

    /// Board order = display order. IDs are persisted — never rename.
    /// A round = any finished run, solved sketch, or cracked phrase (all six
    /// games funnel through recordRun).
    static let nightlyChallenges: [NightlyChallenge] = [
        // Retuned with Top Shelf's switch to face-value scoring. 500 on the
        // old merge scale was about "get a 64 up", which is ~100 of face
        // value; left at 500 the same goal would have quietly become ~6x
        // harder. New id so a half-finished day on the old scale can't
        // auto-complete the new one.
        .init(id: "topShelf100", title: "CLOSE A 100 TAB ON THE TOP SHELF", kind: .runScore(.zombie, 100)),
        .init(id: "totem150", title: "STACK 150 AT THE TOTEM", kind: .runScore(.tikiStacks, 150)),
        .init(id: "luauNight", title: "CLEAR A NIGHT AT THE LUAU", kind: .luauWin),
        // These three used to read "CHART 3 PASSAGES", "FINISH A SKETCH" and
        // "CRACK A CIPHER" — the only game rows that never named their game,
        // while the three above them all carry a venue ("ON THE TOP SHELF").
        // A board you can't route from is just trivia.
        .init(id: "navigator3", title: "CHART 3 NAVIGATOR PASSAGES", kind: .gameRuns(.navigator, 3)),
        .init(id: "blueprintsSketch", title: "FINISH A BLUEPRINTS SKETCH", kind: .gameRuns(.blueprints, 1)),
        .init(id: "cipherPhrase", title: "CRACK A CABANA CIPHER", kind: .gameRuns(.cabanaCipher, 1)),
        .init(id: "rounds3", title: "MAKE THE ROUNDS — 3 GAMES", kind: .distinctGames(3)),
        .init(id: "busy4", title: "KEEP IT GOING — 4 ROUNDS", kind: .anyRuns(4)),
        .init(id: "wallet60", title: "EARN 60 POINTS", kind: .pointsEarned(60)),
    ]
    static let nightlyGoal = 4
    static let nightlyPointsPour = 50

    /// Stable per-game bit for the distinct-games mask. Order is persisted —
    /// never reorder.
    private static let nightlyGameOrder: [TikiGame] =
        [.tikiStacks, .zombie, .luau, .blueprints, .cabanaCipher, .navigator]

    private struct NightlyState: Codable {
        var dayStamp: Date
        var progress: [String: Int]
        var gamesMask: Int
        var rewardClaimed: Bool

        static func fresh(_ now: Date) -> NightlyState {
            NightlyState(dayStamp: now, progress: [:], gamesMask: 0, rewardClaimed: false)
        }
    }

    private static let nightlyRowID = "nightlyNine"

    /// Mirrored for cheap observation by the lounge board (same pattern as
    /// `points`).
    private(set) var nightlyProgress: [String: Int] = [:]
    private(set) var nightlyCompleted = 0
    private(set) var nightlyRewardClaimed = false

    /// Flipped at the end of init — retro-credit mints and migration work
    /// during startup must not count toward tonight's wallet challenge.
    private var nightlyTrackingEnabled = false

    private func nightlyRow() -> GameSaveState? {
        let id = Self.nightlyRowID
        let d = FetchDescriptor<GameSaveState>(predicate: #Predicate { $0.gameID == id })
        return (try? context.fetch(d))?.first
    }

    /// Today's state — rolls to a fresh board when the local day has changed
    /// since the last write. Pure read; the roll persists on the next mutation.
    private func nightlyState(now: Date) -> NightlyState {
        guard let row = nightlyRow(),
              let data = row.payload.data(using: .utf8),
              let state = try? JSONDecoder().decode(NightlyState.self, from: data),
              Calendar.current.isDate(state.dayStamp, inSameDayAs: now)
        else { return .fresh(now) }
        return state
    }

    private func saveNightly(_ state: NightlyState) {
        guard let data = try? JSONEncoder().encode(state),
              let json = String(data: data, encoding: .utf8) else { return }
        if let row = nightlyRow() {
            row.payload = json
            row.updatedAt = .now
        } else {
            context.insert(GameSaveState(gameID: Self.nightlyRowID, payload: json))
        }
        save()
        refreshNightlyMirrors(state)
    }

    func refreshNightlyMirrors(now: Date = .now) {
        refreshNightlyMirrors(nightlyState(now: now))
    }

    private func refreshNightlyMirrors(_ state: NightlyState) {
        let wasDone = Set(nightlyProgress.keys.filter { key in
            guard let c = Self.nightlyChallenges.first(where: { $0.id == key }) else { return false }
            return (nightlyProgress[key] ?? 0) >= c.target
        })
        let previousCount = nightlyCompleted
        nightlyProgress = state.progress
        nightlyRewardClaimed = state.rewardClaimed
        let done = Self.nightlyChallenges.filter {
            (state.progress[$0.id] ?? 0) >= $0.target
        }
        nightlyCompleted = done.count
        // Fired on the transition only — this method is a mirror refresh and
        // runs far more often than a challenge actually completes.
        for c in done where !wasDone.contains(c.id) {
            Analytics.design("nightly:done:\(c.id)")
        }
        if previousCount < Self.nightlyGoal, nightlyCompleted >= Self.nightlyGoal {
            Analytics.design("nightly:goal")
        }
    }

    /// recordRun's nightly hook — one finished round feeds every matching
    /// challenge.
    private func recordNightlyRun(game: TikiGame, score: Int, earned: Int, won: Bool, now: Date) {
        guard nightlyTrackingEnabled else { return }
        var state = nightlyState(now: now)
        if let bit = Self.nightlyGameOrder.firstIndex(of: game) {
            state.gamesMask |= 1 << bit
        }
        for c in Self.nightlyChallenges {
            switch c.kind {
            case .runScore(let g, _) where g == game:
                state.progress[c.id] = max(state.progress[c.id] ?? 0, score)
            case .luauWin where game == .luau && won:
                state.progress[c.id] = 1
            case .gameRuns(let g, _) where g == game:
                state.progress[c.id] = (state.progress[c.id] ?? 0) + 1
            case .anyRuns:
                state.progress[c.id] = (state.progress[c.id] ?? 0) + 1
            case .distinctGames:
                state.progress[c.id] = state.gamesMask.nonzeroBitCount
            case .pointsEarned:
                state.progress[c.id] = (state.progress[c.id] ?? 0) + earned
            default:
                break
            }
        }
        saveNightly(state)
    }

    /// grant()'s nightly hook — bonus faucets (milestone mints, matchbook
    /// bonuses) count toward the wallet challenge too.
    private func recordNightlyPoints(_ n: Int, now: Date = .now) {
        guard nightlyTrackingEnabled, n > 0 else { return }
        var state = nightlyState(now: now)
        for c in Self.nightlyChallenges where c.isPointsKind {
            state.progress[c.id] = (state.progress[c.id] ?? 0) + n
        }
        saveNightly(state)
    }

    /// Vic pours when the board says so: four of nine done, not yet claimed
    /// tonight. The pour prefers an empty introduced comp slot; full slots
    /// fall back to wallet points so a finished board never feels dead.
    enum NightlyReward: Equatable {
        case item(TikiGame)
        case points(Int)
    }

    @discardableResult
    func claimNightlyReward(now: Date = .now) -> NightlyReward? {
        var state = nightlyState(now: now)
        guard !state.rewardClaimed else { return nil }
        let done = Self.nightlyChallenges.filter { (state.progress[$0.id] ?? 0) >= $0.target }.count
        guard done >= Self.nightlyGoal else { return nil }
        let reward: NightlyReward
        // Same call the board previewed with — claim and plaque cannot drift.
        if case .item(let game) = previewNightlyReward(now: now) {
            let prof = profile()
            switch game {
            case .zombie:
                prof.zombieBombs += 1
                zombieBombs = prof.zombieBombs
            case .luau:
                prof.luauCats += 1
                luauCats = prof.luauCats
            default:
                return nil
            }
            reward = .item(game)
            Analytics.resource(.source, currency: game == .zombie ? "depthCharge" : "loungeCat",
                               amount: 1, itemType: "comp", itemId: game.rawValue)
        } else {
            // grant() writes its own nightly bump — reload so this claim's
            // save doesn't clobber it with a stale copy.
            grant(points: Self.nightlyPointsPour, source: "nightly", sourceID: "pour")
            state = nightlyState(now: now)
            reward = .points(Self.nightlyPointsPour)
        }
        Analytics.design("nightly:pour")
        let prof = profile()
        prof.lastDailyCompAt = now
        // Lifetime pour counter — the rating ask's only fuel. Bumped once
        // per successful claim, never decremented, never on a nil return.
        prof.nightlyPoursClaimed += 1
        state.rewardClaimed = true
        saveNightly(state)
        return reward
    }

    // MARK: App Store rating ask

    /// Pours claimed before the first rating ask is allowed.
    static let ratingAskMinPours = 3
    /// Calendar days between our asks. iOS still caps display at 3/365 days;
    /// this only spaces *our* requestReview calls.
    static let ratingAskCooldownDays = 120

    /// Pure due-read (no writes): true when the player has earned enough
    /// pours and we haven't asked within the cooldown (the cooldown's own
    /// day is due). Display is unobservable — iOS may no-op silently.
    func isRatingAskDue(now: Date = .now) -> Bool {
        let prof = profile()
        guard prof.nightlyPoursClaimed >= Self.ratingAskMinPours else { return false }
        guard let last = prof.lastRatingAskAt else { return true }
        let days = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
        return days >= Self.ratingAskCooldownDays
    }

    /// Stamps the ask. Fires whenever we *call* requestReview — not when
    /// iOS displays the sheet (display is unobservable and system-rationed).
    func markRatingAsk(now: Date = .now) {
        let prof = profile()
        prof.lastRatingAskAt = now
        save()
    }

    /// Lifetime pour count (for tests / staging reads).
    var nightlyPoursClaimed: Int { profile().nightlyPoursClaimed }

    #if DEBUG
    /// Staging-only: pin the lifetime pour counter and/or last-ask age so
    /// the third-pour ask is stageable end to end (pair with TIKI_NIGHTLY=4
    /// + TIKI_NIGHTLY_CLAIM=1). Days-ago of 0 stamps "asked today."
    func debugStageRating(pours: Int? = nil, askedDaysAgo: Int? = nil, now: Date = .now) {
        let prof = profile()
        if let pours { prof.nightlyPoursClaimed = max(0, pours) }
        if let days = askedDaysAgo {
            prof.lastRatingAskAt = Calendar.current.date(byAdding: .day, value: -days, to: now)
        }
        save()
    }

    /// Staging-only comp rewinds, so the TIKI_ZOMBIE_DANGER / TIKI_LUAU_CAT
    /// hooks can replay the ON THE HOUSE beat on any profile — including a
    /// device profile that was already comped.
    func debugResetZombieComp() {
        let prof = profile()
        prof.zombieBombs = 0
        prof.zombieBombGranted = false
        zombieBombs = 0
        zombieBombGranted = false
        save()
    }

    func debugResetLuauCatComp() {
        let prof = profile()
        prof.luauCats = 0
        prof.luauCatGranted = false
        luauCats = 0
        luauCatGranted = false
        save()
    }

    /// Staging-only: stamp a fresh nightly board with `done` challenges
    /// complete, clear tonight's claim, and empty both introduced comp
    /// slots — the TIKI_NIGHTLY hook stages any board/pour state on demand.
    func debugStageNightly(done: Int) {
        let prof = profile()
        prof.zombieBombGranted = true
        prof.zombieBombs = 0
        prof.luauCatGranted = true
        prof.luauCats = 0
        prof.lastDailyCompAt = nil
        zombieBombGranted = true
        zombieBombs = 0
        luauCatGranted = true
        luauCats = 0
        save()
        var state = NightlyState.fresh(.now)
        for c in Self.nightlyChallenges.prefix(max(0, min(done, 9))) {
            state.progress[c.id] = c.target
        }
        saveNightly(state)
    }
    #endif

    /// Canonical bit range per game (layout above `milestoneMint`).
    ///
    /// Bits 18–21 are RESERVED for Honu (game #6, hex-match) — parked in
    /// `TikiGames/_Attic/Honu/` pending an IAP revival. Do not repurpose that
    /// range: keeping it empty means a player who someday buys the IAP gets
    /// a clean save with Honu starting at DRIFTER.
    static func milestoneBits(for game: TikiGame) -> Range<Int> {
        switch game {
        case .tikiStacks: return 0..<4
        case .zombie: return 4..<8
        case .luau: return 8..<11
        case .blueprints: return 11..<14
        case .cabanaCipher: return 14..<18
        case .navigator: return 22..<26   // REEF PASS / OPEN OCEAN / LANDFALL / first perfect chart (Stage 6 wires the mints)
        }
    }

    /// Ladder index (0-based) of the deepest state ever reached in a game,
    /// or nil when none — drives the picker-card tints (quiet trophy row).
    func deepestMilestone(for game: TikiGame) -> Int? {
        let bits = Self.milestoneBits(for: game)
        let mask = record(for: game).milestoneMask
        return (0..<bits.count).last { mask & (1 << (bits.lowerBound + $0)) != 0 }
    }

    /// Each record only ever sets its own bit range, so ORing the five masks
    /// yields the cross-game whole.
    var combinedMilestoneMask: Int {
        TikiGame.allCases.reduce(0) { $0 | record(for: $1).milestoneMask }
    }

    /// House Standing: a named tier from the total milestone count (0–18).
    /// Diegetic bar-standing names, shown once — the plaque over the back bar.
    var houseStanding: String {
        switch combinedMilestoneMask.nonzeroBitCount {
        case ..<5: return "WALK-IN"
        case ..<10: return "REGULAR"
        case ..<15: return "ISLANDER"
        default: return "NAME ON THE DOOR"
        }
    }

    /// True once every launch-five game has its first rung — the Sign's
    /// whole gate. FROZEN at the launch five: post-launch games (Honu,
    /// parked; Navigator) do NOT gate the Sign, because including them would
    /// silently re-lock it for owners who already earned it.
    var signUnlocked: Bool {
        let launchFive: [TikiGame] = [.tikiStacks, .luau, .zombie, .cabanaCipher, .blueprints]
        return launchFive.allSatisfy { record(for: $0).milestoneMask != 0 }
    }

    /// The Aquarium ships with one fish; each game whose TOP depth state has
    /// ever been reached (bits 3/7/10/13/17) stocks another species, to 5
    /// (the v2 art delivery ships five species). Stocking it is play, not
    /// payment.
    var aquariumFish: Int {
        let mask = combinedMilestoneMask
        return min(5, 1 + [3, 7, 10, 13, 17].filter { mask & (1 << $0) != 0 }.count)
    }

    // MARK: lounge

    /// True when some unowned catalog item is within the current balance.
    /// Drives the "something's affordable" badges on Home, the lounge SHOP
    /// button, and the game-over handoff line. The welcome gift counts as
    /// affordable until claimed, so a fresh install sees the SHOP badge.
    var canAffordNewItem: Bool {
        if !welcomeGiftClaimed { return true }
        // Ownership (purchasedAt), not placement: an owned-but-unplaced item
        // is not a NEW purchase, and purchase() could never clear its badge.
        return loungeItems.contains {
            $0.purchasedAt == nil && $0.price <= points
                && ($0.itemID != Self.signItemID || signUnlocked)
        }
    }

    var loungeItems: [LoungeItem] {
        let descriptor = FetchDescriptor<LoungeItem>(
            sortBy: [SortDescriptor(\.price), SortDescriptor(\.itemID)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Spends points on an item. Returns false if unaffordable, unknown, or owned.
    /// The first-time welcome gift (`welcomeGiftItemID`, unclaimed) bypasses
    /// the cost check — Vic serves it on the house so the lounge onboarding's
    /// seeded first-success is guaranteed regardless of wallet balance.
    @discardableResult
    func purchase(_ itemID: String) -> Bool {
        let descriptor = FetchDescriptor<LoungeItem>(predicate: #Predicate { $0.itemID == itemID })
        guard let item = (try? context.fetch(descriptor))?.first,
              item.purchasedAt == nil else { return false }
        // Vic saves the Sign for regulars — locked until every game has a bit.
        guard itemID != Self.signItemID || signUnlocked else { return false }
        let prof = profile()
        let onTheHouse = (itemID == Self.welcomeGiftItemID) && !welcomeGiftClaimed
        if !onTheHouse {
            guard prof.points >= item.price else { return false }
            prof.points -= item.price
        }
        item.purchasedAt = .now
        item.isPlaced = true
        points = prof.points
        placedItemIDs.insert(item.itemID)
        if onTheHouse { welcomeGiftClaimed = true }
        save()
        // The comped welcome mug is an inflow, not a purchase — booking it
        // as a sink would show a spend the player never made.
        if onTheHouse {
            Analytics.resource(.source, currency: "points", amount: item.price,
                               itemType: "welcome", itemId: itemID)
        } else {
            Analytics.resource(.sink, currency: "points", amount: item.price,
                               itemType: "decor", itemId: itemID)
        }
        return true
    }

    /// The cheapest item the player cannot yet afford — the same pick the
    /// shop's NEXT UP row makes (LoungeShopPanel), surfaced here so the
    /// analytics read and the UI can never disagree about what the player
    /// is saving toward.
    var nextUnaffordableItemID: String? {
        let items = (try? context.fetch(FetchDescriptor<LoungeItem>())) ?? []
        return items
            .filter { $0.purchasedAt == nil && $0.price > points }
            .min { $0.price < $1.price }?
            .itemID
    }

    /// Saves, and reports a failure instead of swallowing it. `try?` on a
    /// SwiftData save discards the error, so a persistent write fault would
    /// silently lose player progress with no signal anywhere — the whole of
    /// D-12. `site` names the caller so the GA message is actionable.
    private func save(_ site: String = #function) {
        do {
            try context.save()
        } catch {
            Analytics.error("save:\(site): \(error.localizedDescription)")
        }
    }

    // MARK: analytics dimensions
    //
    // The three sticky splits GA attaches to every event (ANALYTICS_PLAN §4).
    // Values must match the vocabularies registered in `Analytics.start()`
    // or the SDK rejects them.

    /// custom_01 — how much of the bundle this player actually uses.
    /// Floors at 1: a brand-new player has played nothing, but GA needs a
    /// value and "games_1" is the closest honest bucket.
    var analyticsBreadth: String {
        let played = TikiGame.allCases.filter { bestScoreRecordExists(for: $0) }.count
        return "games_\(min(TikiGame.allCases.count, max(1, played)))"
    }

    /// custom_02 — the entry point, write-once. Nil for installs that
    /// predate the field, which GA reads as "leave the dimension alone"
    /// rather than bucketing them wrongly.
    var analyticsEntry: String? {
        profile().firstGameID.map { "first_\($0)" }
    }

    /// custom_03 — where this player sits against the lives wall right now.
    var analyticsLivesTier: String {
        switch lives {
        case 0: "lives_zeroed"
        case 1...2: "lives_pinched"
        default: "lives_healthy"
        }
    }

    /// Stamps the first game the player ever **chose** from the picker.
    /// Write-once and irreversible.
    ///
    /// Deliberately not called from the cold-launch route: a fresh install
    /// is sent straight to Luau by `ContentView.resumeTarget`, so recording
    /// that would measure the app's default rather than the player's choice
    /// and would report `first_luau` for essentially every install.
    func noteFirstGame(_ game: TikiGame) {
        let prof = profile()
        guard prof.firstGameID == nil else { return }
        prof.firstGameID = game.rawValue
        save()
    }

    /// Has this game ever been played? `gamesPlayed` rather than `bestScore`,
    /// so a run that scored zero still counts as breadth.
    private func bestScoreRecordExists(for game: TikiGame) -> Bool {
        record(for: game).gamesPlayed > 0
    }

    // MARK: save state

    /// Upserts a game's save-state payload (JSON string owned by the game).
    func saveState(for game: TikiGame, payload: String) {
        let id = game.rawValue
        let descriptor = FetchDescriptor<GameSaveState>(predicate: #Predicate { $0.gameID == id })
        if let existing = (try? context.fetch(descriptor))?.first {
            existing.payload = payload
            existing.updatedAt = .now
        } else {
            context.insert(GameSaveState(gameID: id, payload: payload))
        }
        save()
    }

    func loadState(for game: TikiGame) -> String? {
        let id = game.rawValue
        let descriptor = FetchDescriptor<GameSaveState>(predicate: #Predicate { $0.gameID == id })
        return (try? context.fetch(descriptor))?.first?.payload
    }

    /// Removes a game's save state (e.g. after a finished run).
    func clearState(for game: TikiGame) {
        let id = game.rawValue
        let descriptor = FetchDescriptor<GameSaveState>(predicate: #Predicate { $0.gameID == id })
        guard let existing = (try? context.fetch(descriptor))?.first else { return }
        context.delete(existing)
        save()
    }

    #if DEBUG
    /// Dev hook (TIKI_POINTS): grants wallet points for simulator testing.
    func debugGrant(points n: Int) {
        let prof = profile()
        prof.points += n
        points = prof.points
        save()
    }

    /// Dev hook (TIKI_BEST): seeds a best score for screenshot protocols.
    func debugSetBest(game: TikiGame, score: Int) {
        let rec = record(for: game)
        if rec.bestScore < score { rec.bestScore = score }
        save()
    }

    /// Dev hook (TIKI_STREAK): stages a live win streak so the panels'
    /// N-IN-A-ROW beats can be shot without solving N real phrases.
    /// `best` (optional) pins a higher standing best — the quiet "BEST N"
    /// variant needs streak < best, which real play can't stage in one launch.
    func debugSetStreak(game: TikiGame, streak: Int, best: Int? = nil) {
        let rec = record(for: game)
        rec.streak = max(streak, 0)
        rec.bestStreak = max(rec.bestStreak, max(rec.streak, best ?? 0))
        save()
    }

    /// Dev hook (TIKI_MASK=<game>:<mask>,...): stages milestone masks (global
    /// bit indices) for screenshot protocols. Sets exact values, mints nothing.
    private func applyDebugMilestoneMask() {
        guard let raw = ProcessInfo.processInfo.environment["TIKI_MASK"] else { return }
        for pair in raw.split(separator: ",") {
            let parts = pair.split(separator: ":")
            guard parts.count == 2, let game = TikiGame(rawValue: String(parts[0])),
                  let mask = Int(parts[1]) else { continue }
            record(for: game).milestoneMask = mask
        }
        save()
    }

    /// Dev hook (TIKI_LIVES=<n>): stages the shared lives pool for
    /// screenshot / gate protocols. Clamps to 0…livesCap; full clears the
    /// timer, below-cap starts one at now when none is set.
    private func applyDebugLives() {
        guard let raw = ProcessInfo.processInfo.environment["TIKI_LIVES"],
              let n = Int(raw) else { return }
        let clamped = min(max(n, 0), Self.livesCap)
        let prof = profile()
        prof.lives = clamped
        if clamped >= Self.livesCap {
            prof.livesRefillAnchor = nil
        } else if prof.livesRefillAnchor == nil {
            prof.livesRefillAnchor = .now
        }
        // TIKI_LIVES_ELAPSED=<sec>: pre-age the refill anchor so a landing
        // can be staged without waiting wall clock (sheet PLAY protocols).
        if clamped < Self.livesCap,
           let rawElapsed = ProcessInfo.processInfo.environment["TIKI_LIVES_ELAPSED"],
           let sec = TimeInterval(rawElapsed) {
            prof.livesRefillAnchor = Date.now.addingTimeInterval(-sec)
        }
        save()
    }

    /// Dev hooks (TIKI_RATING_POURS=<n>, TIKI_RATING_ASKED_DAYS_AGO=<n>):
    /// pin the lifetime pour counter and last-ask age so the third-pour
    /// rating sheet is stageable with TIKI_NIGHTLY + TIKI_NIGHTLY_CLAIM.
    private func applyDebugRating() {
        let pours = ProcessInfo.processInfo.environment["TIKI_RATING_POURS"].flatMap(Int.init)
        let daysAgo = ProcessInfo.processInfo.environment["TIKI_RATING_ASKED_DAYS_AGO"].flatMap(Int.init)
        guard pours != nil || daysAgo != nil else { return }
        debugStageRating(pours: pours, askedDaysAgo: daysAgo)
    }
    #endif

    // MARK: bootstrap

    /// Carries the pre-SwiftData UserDefaults best into the tikiStacks record.
    private func migrateLegacyBestIfNeeded() {
        let legacy = UserDefaults.standard.integer(forKey: "tikiStacksBest")
        guard legacy > 0 else { return }
        let rec = record(for: .tikiStacks)
        if rec.bestScore < legacy {
            rec.bestScore = legacy
            save()
        }
        UserDefaults.standard.removeObject(forKey: "tikiStacksBest")
    }

    /// One-shot retroactive milestone credit (same pattern as
    /// welcomeGiftClaimed): the first launch after the progression update
    /// derives milestone bits from data the app already persists and pays the
    /// mints — veterans never re-earn demonstrated play. Mints route through
    /// recordMilestone, so the pass stays idempotent even if it re-runs.
    private static let retroCreditKey = "tikiProgressionRetroCredit"
    private func retroCreditMilestonesIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Self.retroCreditKey) else { return }
        func payload<T: Decodable>(_ type: T.Type, for game: TikiGame) -> T? {
            guard let json = loadState(for: game), let data = json.data(using: .utf8) else { return nil }
            return try? JSONDecoder().decode(type, from: data)
        }
        let stacksBest = record(for: .tikiStacks).bestScore
        for (i, score) in [150, 400, 800, 1500].enumerated() where stacksBest >= score {
            recordMilestone(game: .tikiStacks, bit: i)
        }
        // Zombie's lifetime best tier proxies through the persisted lore
        // cards (tiers ≥ 3 only — accepted over schema churn).
        let bestTier = payload(ZombieGame.SavePayload.self, for: .zombie)?.loreSeen?.max() ?? 0
        for (i, tier) in [5, 7, 9, 11].enumerated() where bestTier >= tier {
            recordMilestone(game: .zombie, bit: 4 + i)
        }
        let luauBest = record(for: .luau).bestScore
        for (i, score) in [150, 400, 700].enumerated() where luauBest >= score {
            recordMilestone(game: .luau, bit: 8 + i)
        }
        let drafted = payload(BlueprintsGame.SavePayload.self, for: .blueprints)?.solved.count ?? 0
        for (i, count) in [5, 15, 30].enumerated() where drafted >= count {
            recordMilestone(game: .blueprints, bit: 11 + i)
        }
        // Phrases advance linearly, so completed matchbooks = solvedCount / 6.
        let books = (payload(CipherGame.SavePayload.self, for: .cabanaCipher)?.solvedCount ?? 0) / 6
        for (i, count) in [1, 4, 8, 16].enumerated() where books >= count {
            recordMilestone(game: .cabanaCipher, bit: 14 + i)
        }
        // Honu (bits 18–21) intentionally absent: parked pre-store (see
        // _Attic/Honu/README.md). If Honu is revived as IAP, keep this
        // block Honu-free — new buyers should start at DRIFTER, not
        // retro-credit off unrelated history.
        UserDefaults.standard.set(true, forKey: Self.retroCreditKey)
    }

    /// Upserts the catalog: inserts new items and retunes name/price on
    /// existing unpurchased ones, never touching ownership. Runs every launch
    /// so prices stay tunable after installs exist.
    private func syncLoungeCatalog() {
        // 2026-08 retune (SHOP_PLAN.md): one ladder priced against the
        // measured earn model (~400 pts/engaged day incl. the nightly pour).
        // Total 17,800 — 17,750 after the free mug — ≈ 5.3 engaged weeks to a
        // complete room; `catalogTotalStaysInSinkBand` pins it. Prices ascend
        // with visual prominence inside each shop section (the patron twins
        // tie by design); the cross-aisle axis is documented in SHOP_PLAN §4.
        // The panel's section map lives in LoungeShopPanel.
        let catalog: [(String, String, Int)] = [
            ("flamingMug", "Flaming Mug", 50),
            ("umbrellaDrink", "Umbrella Drink", 80),
            ("cornerFronds", "Corner Fronds", 90),
            ("palmPlant", "Palm Plant", 300),
            ("glassFloat", "Glass Float", 100),
            ("tikiStatue", "Tiki Statue", 220),
            ("blowfishLamp", "Blowfish Lamp", 160),
            ("recordCredenza", "Record Credenza", 220),
            ("martiniWoman", "Martini Regular", 400),
            ("highballMan", "Highball Regular", 400),
            ("backBarShelf", "The Back Bar", 360),
            ("sunsetWindow", "Sunset Window", 400),
            ("suspiciousCat", "The Suspicious Cat", 180),
            ("barStools", "Bar Stools", 140),
            ("ceilingFan", "Ceiling Fan", 250),
            ("marlin", "The Marlin", 750),
            ("parrot", "Parrot", 280),
            ("neonTikiSign", "Neon Tiki Sign", 600),
            ("aquarium", "The Aquarium", 1100),
            // Lounge v2 (LOUNGE_V2_PLAN §5): the west wing.
            ("plantBush", "Potted Bush", 120),
            ("plantSnake", "Snake Plant", 160),
            ("plantTiered", "The Topiary", 220),
            ("loungeRug", "The Rug", 320),
            ("highTable", "The Tall Table", 500),
            ("bayWindow", "The Bay Window", 550),
            ("loungeCouch", "The Davenport", 800),
            ("grandPiano", "The Baby Grand", 1250),
            // The lagoon (Carson's water-scene delivery): life above the
            // room. These items are bought, not placed — they drift, bob,
            // and stand watch on their own; none are draggable.
            ("buoy", "The Buoy", 120),
            ("lagoonDuck", "The Lagoon Duck", 160),
            ("messageBottle", "Message in a Bottle", 220),
            ("dolphin", "The Dolphin", 300),
            ("seaTurtle", "Honu the Turtle", 400),
            ("sailboat", "The Sailboat", 550),
            ("shark", "The Shark", 700),
            ("orca", "The Orca", 950),
            ("farIsland", "The Far Island", 1200),
            ("volcano", "The Volcano", 1400),
            ("yacht", "The Yacht", 1800),
        ]
        // A failed fetch must NOT read as an empty store: inserting over
        // existing rows upserts on the unique itemID and wipes ownership.
        // Skipping the sync is harmless.
        guard let existing = try? context.fetch(FetchDescriptor<LoungeItem>()) else { return }
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.itemID, $0) })
        for (id, name, price) in catalog {
            if let item = byID[id] {
                if item.name != name { item.name = name }
                if item.purchasedAt == nil, item.price != price { item.price = price }
            } else {
                context.insert(LoungeItem(itemID: id, name: name, price: price))
            }
        }
        save()
    }
}
