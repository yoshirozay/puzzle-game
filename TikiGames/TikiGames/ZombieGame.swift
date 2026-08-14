import Foundation
import Observation

/// Zombie — the 2048 merge engine. Pure logic, no SwiftUI: 4x4 grid, swipes
/// slide all tiles, equal tiles merge into the next drink tier (one merge per
/// tile per swipe, resolved from the target edge), every effective swipe
/// spawns a tier-1 (90%) or tier-2 (10%) drink — 20% tier-2 while a tier-8+
/// drink sits on the board (Doubles After Midnight). Game over when no move
/// changes the board; reaching tier 11 (THE ZOMBIE) is the win moment.
/// Session state lives here, not in view @State (gotcha #3).
@Observable
final class ZombieGame {
    struct Tile: Identifiable, Equatable, Codable {
        var id: UUID
        var tier: Int   // 1...11
        var col: Int
        var row: Int
    }

    enum Direction {
        case up, down, left, right
    }

    static let size = 4
    static let zombieTier = 11

    private(set) var tiles: [Tile] = []
    private(set) var score = 0
    /// What the board is worth right now: every tile's face value added up —
    /// the number the player can literally read off the screen, which is why
    /// it ranks the leaderboard instead of the cumulative merge score.
    ///
    /// Note the arithmetic this rests on: a merge CONSERVES this total
    /// (512 + 512 becomes 1024), so it rises only when a tile spawns and
    /// falls only when a Depth Charge clears one. It measures how much
    /// material a run accumulated and kept organised — not merge count.
    var boardValue: Int {
        tiles.reduce(0) { $0 + (1 << $1.tier) }
    }
    private(set) var isOver = false
    private(set) var zombieReached = false
    /// True once this run's ZOMBIE banner has had its moment — dismissed
    /// live, or the run resumed/staged past it. Session state lives here,
    /// not in view @State (gotcha #3): @State writes from onAppear are lost.
    var zombieCelebrated = false
    /// Set for one animation beat after a swipe that merged tiles: the
    /// highest tier created (drives juice/SFX escalation).
    private(set) var lastMergedTier: Int?
    /// IDs of tiles created by merge in the last swipe (view pulses these).
    private(set) var justMerged: Set<UUID> = []
    /// ID of the tile spawned by the last swipe (view pops it in).
    private(set) var justSpawned: UUID?
    /// Points gained by the last swipe's merges, and a counter that keys the
    /// floating "+N" popup (one popup per scoring move).
    private(set) var lastGain = 0
    private(set) var gainBeat = 0
    var lastRunSummary: RunSummary?
    private(set) var best = 0
    /// Tiers whose first-mix lore card has been shown (persisted).
    var loreSeen: Set<Int> = []
    /// Doubles After Midnight: tier-2 spawns double (10% → 20%) while a
    /// tier-8+ drink sits on the board. The view announces it once per run.
    var doublesLive: Bool { tiles.contains { $0.tier >= 8 } }
    var doublesAnnounced = false

    // MARK: undo (one per run)

    private struct Snapshot {
        var tiles: [Tile]
        var score: Int
        var zombieReached: Bool
    }
    private var undoSnapshot: Snapshot?
    private(set) var undoUsed = false

    var canUndo: Bool { undoSnapshot != nil && !undoUsed && !isOver }

    /// Rewinds the last effective swipe (board, score, win flag). One per
    /// run; unavailable after game over — reviving a paid-out run would
    /// double-pay the wallet.
    @discardableResult
    func undo() -> Bool {
        guard canUndo, let snap = undoSnapshot else { return false }
        tiles = snap.tiles
        score = snap.score
        zombieReached = snap.zombieReached
        undoSnapshot = nil
        undoUsed = true
        justMerged = []
        justSpawned = nil
        lastMergedTier = nil
        return true
    }

    // MARK: depth charge (2×2 bomb)

    /// One beat per detonation — keys the view's blast FX at the cleared cells.
    private(set) var bombBeat = 0
    private(set) var lastBombedCells: [(col: Int, row: Int)] = []

    /// DANGER: two or fewer empty cells with the run still live — the window
    /// where the Depth Charge earns its keep (and its one-time comp).
    var inDanger: Bool {
        !isOver && !tutorialActive && tiles.count >= Self.size * Self.size - 2
    }

    /// Depth Charge: clears the 2×2 whose top-left cell is (col, row), clamped
    /// onto the board. A rescue, not a move — no score, no spawn, and the undo
    /// snapshot dies with the board it remembered. Clearing tiles can only add
    /// legal moves, so a live run stays live; a 0 return (empty target, dead
    /// run, tutorial) leaves everything untouched so the caller doesn't spend
    /// the charge.
    @discardableResult
    func detonate(col: Int, row: Int) -> Int {
        guard !isOver, !tutorialActive else { return 0 }
        let c = min(max(col, 0), Self.size - 2)
        let r = min(max(row, 0), Self.size - 2)
        let hit = tiles.filter { (c...c + 1).contains($0.col) && (r...r + 1).contains($0.row) }
        guard !hit.isEmpty else { return 0 }
        let ids = Set(hit.map(\.id))
        tiles.removeAll { ids.contains($0.id) }
        undoSnapshot = nil
        justMerged = []
        justSpawned = nil
        lastMergedTier = nil
        lastBombedCells = hit.map { (col: $0.col, row: $0.row) }
        bombBeat += 1
        return hit.count
    }

    func configureBest(_ value: Int) { best = max(best, value) }

    // MARK: setup

    func newGame() {
        tiles = []
        score = 0
        isOver = false
        zombieReached = false
        zombieCelebrated = false
        lastMergedTier = nil
        justMerged = []
        justSpawned = nil
        lastGain = 0
        lastRunSummary = nil
        undoSnapshot = nil
        undoUsed = false
        doublesAnnounced = false
        lastBombedCells = []
        // Abandoning the tutorial must hand the board back — a stuck flag
        // would suppress spawns forever and drain the run unwinnably.
        tutorialActive = false
        spawn()
        spawn()
    }

    /// First-run seed: three sequential rounds that walk the player from
    /// tier 1 up to tier 4 (value 16). Each round places two same-tier drinks
    /// stacked in column 1 so a DOWN swipe merges them into the next tier.
    /// The game's own drink-lore cards fire at tier 3 (LIME DAIQUIRI) and
    /// tier 4 (MAI TAI) as free "first mix" reveals — the tutorial doesn't
    /// name them; the game does.
    struct TutorialRound {
        let tiles: [(col: Int, row: Int, tier: Int)]
        let expectedTier: Int
    }

    /// Column 1 keeps the seeded pair on the middle-left rail so the DOWN
    /// arrow between the tiles doesn't crowd the chrome or the loreCard.
    /// Round 3 is a swipe-teach beat: no scripted merge, board holds the
    /// earned tier-4 (value 16) at the bottom of col 1 plus two fresh 2s
    /// scattered across the board — any swipe direction slides them.
    static let tutorialRounds: [TutorialRound] = [
        TutorialRound(tiles: [(1, 0, 1), (1, 1, 1)], expectedTier: 2),
        TutorialRound(tiles: [(1, 0, 2), (1, 1, 2)], expectedTier: 3),
        TutorialRound(tiles: [(1, 0, 3), (1, 1, 3)], expectedTier: 4),
        TutorialRound(tiles: [(1, 3, 4), (0, 0, 1), (3, 3, 1)], expectedTier: 4),
    ]
    static var tutorialRoundCount: Int { tutorialRounds.count }
    /// Rounds 0–2 want a DOWN swipe (stacked pair merges). Round 3 is the
    /// swipe-teach — any successful move dismisses.
    static let tutorialSwipeTeachRound: Int = 3
    static let tutorialDirection: Direction = .down

    /// Empty on the swipe-teach round (no target cells to pulse).
    static func tutorialTilePositions(round: Int) -> [(col: Int, row: Int)] {
        let r = max(0, min(round, tutorialRounds.count - 1))
        if r == tutorialSwipeTeachRound { return [] }
        return tutorialRounds[r].tiles.map { (col: $0.col, row: $0.row) }
    }

    /// True while the tutorial owns the board — suppresses spawn() so the
    /// board stays deterministic between scripted rounds.
    var tutorialActive: Bool = false

    func seedTutorialBoard(round: Int) {
        let r = max(0, min(round, Self.tutorialRounds.count - 1))
        let spec = Self.tutorialRounds[r]
        tiles = []
        score = 0
        isOver = false
        zombieReached = false
        lastMergedTier = nil
        justMerged = []
        justSpawned = nil
        undoSnapshot = nil
        undoUsed = false
        lastBombedCells = []
        tutorialActive = true
        if r == 0 {
            lastRunSummary = nil
        }
        for t in spec.tiles {
            tiles.append(Tile(id: UUID(), tier: t.tier, col: t.col, row: t.row))
        }
    }

    /// View calls this after the last scripted merge lands so real play
    /// resumes with normal spawn behavior. The final merged tile stays on
    /// the board as a gift, and we spawn TWO fresh drinks so the board reads
    /// as "your turn now" instead of one tile sitting alone.
    func endTutorial() {
        tutorialActive = false
        spawn()
        spawn()
    }

    // MARK: sliding

    /// Applies a swipe. Returns true when the board changed (and a new tile
    /// spawned); false swipes are no-ops per 2048 canon.
    @discardableResult
    func slide(_ direction: Direction) -> Bool {
        guard !isOver else { return false }
        let before = Snapshot(tiles: tiles, score: score, zombieReached: zombieReached)
        var moved = false
        var merged: Set<UUID> = []
        var mergedTier: Int?
        var gain = 0
        var next: [Tile] = []

        for lane in 0..<Self.size {
            let line = laneTiles(lane, direction)
            var results: [Tile] = []
            var i = 0
            while i < line.count {
                var tile = line[i]
                if i + 1 < line.count,
                   line[i + 1].tier == tile.tier,
                   tile.tier < Self.zombieTier {
                    tile.tier += 1
                    score += 1 << tile.tier
                    gain += 1 << tile.tier
                    merged.insert(tile.id)
                    mergedTier = max(mergedTier ?? 0, tile.tier)
                    if tile.tier == Self.zombieTier { zombieReached = true }
                    moved = true
                    i += 2
                } else {
                    i += 1
                }
                results.append(tile)
            }
            for (slot, var tile) in results.enumerated() {
                let (col, row) = cell(lane: lane, slot: slot, direction: direction)
                if tile.col != col || tile.row != row { moved = true }
                tile.col = col
                tile.row = row
                next.append(tile)
            }
        }

        guard moved else { return false }
        undoSnapshot = before
        tiles = next
        justMerged = merged
        lastMergedTier = mergedTier
        if gain > 0 {
            lastGain = gain
            gainBeat += 1
        }
        // Tutorial owns the board — no random spawn while it's scripted, and
        // scripted merges must not pollute the displayed best.
        if !tutorialActive {
            spawn()
            // Read AFTER the spawn: best tracks `boardValue`, so it has to
            // mean the same board the player is looking at.
            best = max(best, boardValue)
        }
        if !hasLegalMove { isOver = true }
        return true
    }

    private func laneTiles(_ lane: Int, _ direction: Direction) -> [Tile] {
        let inLane = tiles.filter { direction.isHorizontal ? $0.row == lane : $0.col == lane }
        let sorted = inLane.sorted {
            direction.isHorizontal ? $0.col < $1.col : $0.row < $1.row
        }
        return direction.fromFarEdge ? sorted.reversed() : sorted
    }

    private func cell(lane: Int, slot: Int, direction: Direction) -> (Int, Int) {
        let pos = direction.fromFarEdge ? Self.size - 1 - slot : slot
        return direction.isHorizontal ? (pos, lane) : (lane, pos)
    }

    private func spawn() {
        let occupied = Set(tiles.map { $0.row * Self.size + $0.col })
        let free = (0..<Self.size * Self.size).filter { !occupied.contains($0) }
        guard let cell = free.randomElement() else { return }
        // Doubles After Midnight: a tier-8+ drink on the board doubles the
        // tier-2 pour. A late-game kindness, not a spike.
        let tier = Int.random(in: 0..<10) < (doublesLive ? 2 : 1) ? 2 : 1
        let tile = Tile(id: UUID(), tier: tier, col: cell % Self.size, row: cell / Self.size)
        tiles.append(tile)
        justSpawned = tile.id
        #if DEBUG
        if Self.spawnLog { print("[zombie] spawn tier=\(tier) doubles=\(doublesLive)") }
        #endif
    }

    private var hasLegalMove: Bool {
        if tiles.count < Self.size * Self.size { return true }
        var grid = [[Int]](repeating: [Int](repeating: 0, count: Self.size), count: Self.size)
        for t in tiles { grid[t.row][t.col] = t.tier }
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                // Mirror slide()'s merge rule: two ZOMBIEs never merge, so an
                // adjacent tier-11 pair is not a legal move.
                guard grid[r][c] < Self.zombieTier else { continue }
                if c + 1 < Self.size, grid[r][c] == grid[r][c + 1] { return true }
                if r + 1 < Self.size, grid[r][c] == grid[r + 1][c] { return true }
            }
        }
        return false
    }

    // MARK: persistence (SwiftData payload via PlayerStore.saveState)

    struct SavePayload: Codable {
        var seenHowTo: Bool
        var score: Int
        var board: [Tile]?
        /// Optional so payloads written before these fields decode.
        var undoUsed: Bool?
        var loreSeen: [Int]?
    }

    func payload(seenHowTo: Bool) -> String {
        let state = SavePayload(
            seenHowTo: seenHowTo,
            score: score,
            board: isOver ? nil : tiles,
            undoUsed: isOver ? nil : undoUsed,
            loreSeen: Array(loreSeen)
        )
        guard let data = try? JSONEncoder().encode(state) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Restores a live board from a payload. Returns the decoded payload so
    /// the view can read seenHowTo; falls back to a fresh game.
    @discardableResult
    func restore(from json: String?) -> SavePayload? {
        guard let json, let data = json.data(using: .utf8),
              let state = try? JSONDecoder().decode(SavePayload.self, from: data) else {
            newGame()
            return nil
        }
        loreSeen = Set(state.loreSeen ?? [])
        if let board = state.board, boardIsValid(board) {
            tiles = board
            // Corrupt saves: a score near Int.max would trap on the next
            // merge's `score += 1 << tile.tier`; clamp instead of trusting it.
            score = min(max(state.score, 0), Int.max / 2)
            isOver = !hasLegalMove
            zombieReached = board.contains { $0.tier >= Self.zombieTier }
            // A resumed past-ZOMBIE run already had its banner; a resumed
            // past-midnight run already heard the announcement.
            zombieCelebrated = zombieReached
            doublesAnnounced = doublesLive
            undoUsed = state.undoUsed ?? false
            undoSnapshot = nil
            // The restored board replaces whatever was mid-animation or
            // mid-tutorial on this instance.
            lastMergedTier = nil
            justMerged = []
            justSpawned = nil
            lastBombedCells = []
            tutorialActive = false
        } else {
            newGame()
        }
        return state
    }

    #if DEBUG
    /// Staging (SIMCTL_CHILD_TIKI_ZOMBIE_SPAWNLOG=1): prints every spawn's
    /// tier and doubles state so the 90/10 → 80/20 shift can be measured live.
    private static let spawnLog =
        ProcessInfo.processInfo.environment["TIKI_ZOMBIE_SPAWNLOG"] == "1"

    /// Staging hook (TIKI_ZOMBIE_BOARD): seeds a live board whose highest
    /// tile is `maxTier`, plus the lore ladder up to it — a board holding
    /// tier N means every drink below N was mixed on the way. Marked
    /// celebrated so a staged ZOMBIE stays environmental, banner-free.
    func debugSeedBoard(maxTier: Int) {
        let cap = min(max(maxTier, 1), Self.zombieTier)
        var cells: [(col: Int, row: Int, tier: Int)] = [(3, 3, cap), (0, 0, 1)]
        if cap > 1 { cells.append((2, 3, cap - 1)) }
        if cap > 2 { cells.append((1, 3, cap - 2)) }
        tiles = cells.map { Tile(id: UUID(), tier: $0.tier, col: $0.col, row: $0.row) }
        score = (cap - 1) * (1 << cap)
        isOver = false
        zombieReached = cap >= Self.zombieTier
        zombieCelebrated = true
        if cap >= 3 { loreSeen.formUnion(3...cap) }
        lastMergedTier = nil
        justMerged = []
        justSpawned = nil
        undoSnapshot = nil
        undoUsed = false
    }

    /// Staging hook (TIKI_ZOMBIE_DANGER): a 14-tile board with no adjacent
    /// equal pair — alive only because two cells sit empty, i.e. the exact
    /// DANGER state that comps the Depth Charge.
    func debugSeedDangerBoard() {
        let specs: [(col: Int, row: Int, tier: Int)] = [
            (0, 0, 1), (1, 0, 2), (2, 0, 3), (3, 0, 4),
            (0, 1, 5), (1, 1, 6), (2, 1, 7), (3, 1, 8),
            (0, 2, 2), (1, 2, 3), (2, 2, 4), (3, 2, 5),
            (0, 3, 6), (1, 3, 7),
        ]
        tiles = specs.map { Tile(id: UUID(), tier: $0.tier, col: $0.col, row: $0.row) }
        score = 260
        isOver = false
        zombieReached = false
        zombieCelebrated = true
        // A fresh install seeds the tutorial before this hook runs; a staged
        // danger board is real play, and inDanger/detonate refuse tutorials.
        tutorialActive = false
        loreSeen.formUnion(3...8)
        lastMergedTier = nil
        justMerged = []
        justSpawned = nil
        undoSnapshot = nil
        undoUsed = false
        lastBombedCells = []
    }
    #endif

    /// Guards restore against corrupt payloads: in-range tiers and positions,
    /// no stacked tiles, board fits the grid.
    private func boardIsValid(_ board: [Tile]) -> Bool {
        guard !board.isEmpty, board.count <= Self.size * Self.size else { return false }
        var seen: Set<Int> = []
        for t in board {
            guard (1...Self.zombieTier).contains(t.tier),
                  (0..<Self.size).contains(t.col),
                  (0..<Self.size).contains(t.row),
                  seen.insert(t.row * Self.size + t.col).inserted else { return false }
        }
        return true
    }
}

private extension ZombieGame.Direction {
    var isHorizontal: Bool { self == .left || self == .right }
    /// True when tiles collapse toward the high-index edge (right/down).
    var fromFarEdge: Bool { self == .right || self == .down }
}
