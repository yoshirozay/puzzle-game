import Foundation
import Testing
@testable import Tiki_Lounge

// Adversarial tests for ZombieGame (Top Shelf), the pure-logic 2048 merge engine.
//
// Determinism strategy (no RNG seed seam exists in the engine):
//  - Boards are injected via restore(from:) with hand-built SavePayload JSON.
//  - Setting the public `tutorialActive = true` suppresses spawn(), making
//    slide() fully deterministic (caveat: it also freezes `best`).
//  - Tests that keep live spawns assert only spawn-invariant facts, or leave
//    exactly one free cell so the spawn position is forced.
//
// The "Zombie fixed bugs" suite holds permanent regression tests for real
// bugs this sweep exposed and fixed in ZombieGame (2026-07-17). Slugs:
//  - score-not-validated-on-restore   (restore now clamps score to 0...Int.max/2)
//  - newgame-keeps-tutorial-active    (newGame now clears tutorialActive)
//  - restore-keeps-tutorial-active    (restore now clears tutorialActive)
//  - newgame-stale-lastgain           (newGame now resets lastGain)
//  - restore-stale-animation-state    (restore now clears justMerged/justSpawned/lastMergedTier)

// MARK: - Shared fixtures

typealias Spec = (tier: Int, col: Int, row: Int)

private let allDirections: [ZombieGame.Direction] = [.up, .down, .left, .right]

/// Full 16-tile board whose ONLY adjacent equal pair is the 1-1 at (0,0)/(1,0):
/// alive, but exactly one legal merge.
private let fullAliveBoard: [Spec] = [
    (1, 0, 0), (1, 1, 0), (2, 2, 0), (3, 3, 0),
    (2, 0, 1), (3, 1, 1), (4, 2, 1), (5, 3, 1),
    (3, 0, 2), (4, 1, 2), (5, 2, 2), (6, 3, 2),
    (4, 0, 3), (5, 1, 3), (6, 2, 3), (7, 3, 3),
]

/// Full 16-tile board whose ONLY adjacent equal pair is two tier-11 ZOMBIEs —
/// which never merge, so the board is dead on arrival.
private let deadBoard: [Spec] = [
    (11, 0, 0), (11, 1, 0), (1, 2, 0), (2, 3, 0),
    (1, 0, 1), (2, 1, 1), (3, 2, 1), (4, 3, 1),
    (2, 0, 2), (3, 1, 2), (4, 2, 2), (5, 3, 2),
    (3, 0, 3), (4, 1, 3), (5, 2, 3), (6, 3, 3),
]

/// 15 tiles, one free cell at (3,0) after slide(.left). The forced spawn
/// completes a board with no adjacent equal pair regardless of whether a
/// tier 1 or a tier 2 spawns (its neighbors are tiers 5 and 7) => must die.
private let dyingBoard: [Spec] = [
    (3, 1, 0), (4, 2, 0), (5, 3, 0),
    (4, 0, 1), (5, 1, 1), (6, 2, 1), (7, 3, 1),
    (5, 0, 2), (6, 1, 2), (7, 2, 2), (8, 3, 2),
    (6, 0, 3), (7, 1, 3), (8, 2, 3), (9, 3, 3),
]

/// Same shape, but column 0 holds a vertical 6-6 pair after the slide, so the
/// filled board stays alive regardless of the spawned tier => must survive.
private let survivingBoard: [Spec] = [
    (3, 1, 0), (4, 2, 0), (5, 3, 0),
    (4, 0, 1), (5, 1, 1), (6, 2, 1), (7, 3, 1),
    (6, 0, 2), (7, 1, 2), (8, 2, 2), (9, 3, 2),
    (6, 0, 3), (8, 1, 3), (9, 2, 3), (10, 3, 3),
]

/// Semantically invalid boards: decode fine, boardIsValid must reject each.
private let invalidBoards: [[Spec]] = [
    [],                                     // empty live board
    [(0, 0, 0)],                            // tier below 1
    [(12, 0, 0)],                           // tier above ZOMBIE
    [(2, -1, 0)],                           // col below 0
    [(2, 4, 0)],                            // col above 3
    [(2, 0, -1)],                           // row below 0
    [(2, 0, 4)],                            // row above 3
    [(2, 1, 1), (3, 1, 1)],                 // two tiles stacked on one cell
    (0..<17).map { (tier: 1, col: $0 % 4, row: $0 / 4) }, // 17 tiles
]

/// Fence-post boards boardIsValid must ACCEPT.
private let boundaryBoards: [[Spec]] = [
    [(1, 0, 0)],        // min tier, origin cell, 1 tile
    [(11, 3, 3)],       // max tier, far cell
    fullAliveBoard,     // exactly 16 tiles
]

/// Undecodable payloads: every one must yield nil + newGame fallback.
private let garbageInputs: [String?] = [
    nil,
    "",
    "not json",
    "{}",                                   // seenHowTo/score have no defaults
    "[]",
    "null",
    #"{"seenHowTo":true}"#,                 // missing score
    #"{"seenHowTo":true,"score":"#,         // truncated
    "\u{FEFF}{}",                           // UTF-8 BOM prefix
    "\u{1F9DF}\u{200F}{}",                  // emoji + RTL mark noise
    #"{"seenHowTo":false,"score":1e308,"board":[]}"#,   // score not an Int
    #"{"seenHowTo":false,"score":"12","board":[]}"#,    // score as string
    #"{"seenHowTo":false,"score":0,"board":[{"id":"nope","tier":1,"col":0,"row":0}]}"#, // bad UUID
    #"{"seenHowTo":false,"score":0,"board":[{"tier":1,"col":0,"row":0}]}"#,             // missing id
    #"{"seenHowTo":false,"score":0,"board":[{"id":"00000000-0000-0000-0000-000000000000","tier":"11","col":0,"row":0}]}"#, // tier as string
]

/// Direction geometry: asymmetric board tier2@(0,1), tier2@(0,2), tier5@(2,0)
/// driven through each axis. `expected` is the exact post-slide board.
private let geometryCases: [(label: String, dir: ZombieGame.Direction, expected: Set<String>, gain: Int)] = [
    ("up", .up, ["3@0,0", "5@2,0"], 8),
    ("down", .down, ["3@0,3", "5@2,3"], 8),
    ("left", .left, ["2@0,1", "2@0,2", "5@0,0"], 0),
    ("right", .right, ["2@3,1", "2@3,2", "5@3,0"], 0),
]

// MARK: - Helpers

@MainActor
private func payloadJSON(
    seenHowTo: Bool = false,
    score: Int = 0,
    board: [Spec]?,
    undoUsed: Bool? = false,
    loreSeen: [Int]? = []
) throws -> String {
    let tiles = board.map { specs in
        specs.map { ZombieGame.Tile(id: UUID(), tier: $0.tier, col: $0.col, row: $0.row) }
    }
    let payload = ZombieGame.SavePayload(
        seenHowTo: seenHowTo, score: score, board: tiles, undoUsed: undoUsed, loreSeen: loreSeen
    )
    let data = try JSONEncoder().encode(payload)
    return try #require(String(data: data, encoding: .utf8))
}

@MainActor
private func signature(of game: ZombieGame) -> Set<String> {
    Set(game.tiles.map { "\($0.tier)@\($0.col),\($0.row)" })
}

private func signature(_ board: [Spec]) -> Set<String> {
    Set(board.map { "\($0.tier)@\($0.col),\($0.row)" })
}

/// Restores `board` into a fresh instance and PROVES it was accepted (not the
/// newGame fallback). `deterministic: true` flips tutorialActive so slide()
/// skips spawn — note this also freezes `best`.
@MainActor
private func restoredGame(
    _ board: [Spec],
    score: Int = 0,
    undoUsed: Bool = false,
    loreSeen: [Int] = [],
    deterministic: Bool = true
) throws -> ZombieGame {
    let game = ZombieGame()
    let payload = game.restore(
        from: try payloadJSON(score: score, board: board, undoUsed: undoUsed, loreSeen: loreSeen)
    )
    try #require(payload != nil, "payload must decode")
    try #require(signature(of: game) == signature(board), "board must be accepted, not fall back to newGame")
    if deterministic { game.tutorialActive = true }
    return game
}

@MainActor
private func tileAt(_ game: ZombieGame, _ col: Int, _ row: Int) -> ZombieGame.Tile? {
    game.tiles.first { $0.col == col && $0.row == row }
}

/// Structural invariants that must hold after ANY operation.
@MainActor
private func expectBoardSane(_ game: ZombieGame, _ location: SourceLocation = #_sourceLocation) {
    let cellCount = ZombieGame.size * ZombieGame.size
    #expect(game.tiles.count <= cellCount, "more tiles than cells", sourceLocation: location)
    let cells = game.tiles.map { $0.row * ZombieGame.size + $0.col }
    #expect(Set(cells).count == cells.count, "stacked tiles", sourceLocation: location)
    #expect(
        game.tiles.allSatisfy {
            (1...ZombieGame.zombieTier).contains($0.tier)
                && (0..<ZombieGame.size).contains($0.col)
                && (0..<ZombieGame.size).contains($0.row)
        },
        "tile out of bounds", sourceLocation: location
    )
}

/// Deterministic direction source for the soak test (spawns stay unseeded;
/// only the swipe sequence is reproducible).
private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Merge mechanics

@MainActor
@Suite("Zombie board value")
struct ZombieBoardValueTests {
    // guards: boardValue is the plain sum of tile face values — the number
    // the player reads off the grid, and what the leaderboard ranks
    @Test func boardValueSumsFaceValues() throws {
        // tiers 2,3,4 -> face values 4 + 8 + 16
        let game = try restoredGame([(2, 0, 0), (3, 1, 0), (4, 2, 0)])
        #expect(game.boardValue == 28)
    }

    // guards: THE load-bearing property of this leaderboard — a merge
    // CONSERVES board value (512+512 becomes 1024), so the rank measures
    // material accumulated, never merge count. If this ever changes, the
    // leaderboard silently changes meaning.
    @Test func mergeConservesBoardValue() throws {
        let game = try restoredGame([(2, 0, 0), (2, 1, 0), (2, 2, 0), (2, 3, 0)])
        let before = game.boardValue
        try #require(game.slide(.left))
        // A spawn rides in after the slide, so the merge itself is isolated
        // by subtracting the newcomer.
        let spawnedID = game.justSpawned
        let spawned = game.tiles.first { $0.id == spawnedID }.map { 1 << $0.tier } ?? 0
        #expect(game.boardValue - spawned == before, "merging must not change board value")
        #expect(game.score == 16, "the cumulative score DOES rise — the two differ by design")
    }

    // guards: a Depth Charge lowers board value, since it removes tiles —
    // the one way the number can go down, and a real cost to the rank
    @Test func detonateLowersBoardValue() throws {
        // deterministic:false — the helper's determinism flag arms
        // tutorialActive, and detonate refuses to fire during the tutorial.
        let game = try restoredGame([(5, 0, 0), (5, 1, 0), (3, 2, 2)], deterministic: false)
        let before = game.boardValue
        #expect(game.detonate(col: 0, row: 0) > 0)
        #expect(game.boardValue < before)
    }
}

@MainActor
@Suite("Zombie merge mechanics")
struct ZombieMergeMechanicsTests {
    // guards: one merge per resulting tile — a full quad lane yields two pairs, never a chain
    @Test func quadLaneMergesIntoTwoPairs() throws {
        let game = try restoredGame([(2, 0, 0), (2, 1, 0), (2, 2, 0), (2, 3, 0)])
        try #require(game.slide(.left))
        #expect(signature(of: game) == ["3@0,0", "3@1,0"])
        #expect(game.score == 16)
        #expect(game.lastGain == 16)
        #expect(game.justMerged.count == 2)
        #expect(game.lastMergedTier == 3)
        #expect(game.gainBeat == 1)
        expectBoardSane(game)
    }

    // guards: merges resolve from the target edge — [2,2,2] becomes [3,2] with the 3 on the edge
    @Test func tripleMergesEdgePairOnly() throws {
        let game = try restoredGame([(2, 0, 0), (2, 1, 0), (2, 2, 0)])
        try #require(game.slide(.left))
        #expect(signature(of: game) == ["3@0,0", "2@1,0"])
        #expect(game.lastGain == 8)
        #expect(game.justMerged.count == 1)
        expectBoardSane(game)
    }

    // guards: no chained merges within one swipe — [1,1,2] toward the 2 yields [2,2], never [3]
    @Test func noChainMergeWithinOneSwipe() throws {
        let game = try restoredGame([(2, 0, 0), (1, 1, 0), (1, 2, 0)])
        try #require(game.slide(.left))
        #expect(signature(of: game) == ["2@0,0", "2@1,0"], "chained into a single tile")
        #expect(game.score == 4)
        // The freshly formed pair merges only on the NEXT swipe.
        try #require(game.slide(.left))
        #expect(signature(of: game) == ["3@0,0"])
        #expect(game.score == 4 + 8)
    }

    // guards: fromFarEdge/cell math per axis — same board through all four directions
    @Test(arguments: geometryCases)
    func directionGeometry(_ c: (label: String, dir: ZombieGame.Direction, expected: Set<String>, gain: Int)) throws {
        let game = try restoredGame([(2, 0, 1), (2, 0, 2), (5, 2, 0)])
        try #require(game.slide(c.dir), "swipe \(c.label) must be effective")
        #expect(signature(of: game) == c.expected)
        if c.gain > 0 {
            #expect(game.lastGain == c.gain)
            #expect(game.gainBeat == 1)
            #expect(game.justMerged.count == 1)
            #expect(game.lastMergedTier == 3)
        } else {
            // Effective but merge-free: gainBeat must NOT tick, justMerged empty.
            #expect(game.gainBeat == 0)
            #expect(game.justMerged.isEmpty)
            #expect(game.lastMergedTier == nil)
            #expect(game.score == 0)
        }
        expectBoardSane(game)
    }

    // guards: surviving-UUID contract — merge keeps the edge-side tile's id, absorbs the other
    @Test func survivingTileKeepsEdgeUUID() throws {
        let game = try restoredGame([(4, 1, 2), (4, 2, 2)])
        let edgeID = try #require(tileAt(game, 2, 2)?.id)   // nearest the .right edge
        let absorbedID = try #require(tileAt(game, 1, 2)?.id)
        try #require(game.slide(.right))
        #expect(game.justMerged == [edgeID])
        let survivor = try #require(game.tiles.first { $0.id == edgeID })
        #expect(survivor.tier == 5)
        #expect(survivor.col == 3 && survivor.row == 2)
        #expect(!game.tiles.contains { $0.id == absorbedID })
    }

    // guards: ineffective swipe is a strict no-op — no spawn, no snapshot, no state drift
    @Test func ineffectiveSwipeIsStrictNoOp() throws {
        // Packed into the left/top corner; spawns stay LIVE to prove a failed
        // swipe never spawns.
        let game = try restoredGame([(1, 0, 0), (2, 0, 1)], deterministic: false)
        let preTiles = game.tiles
        for dir in [ZombieGame.Direction.left, .up] {
            #expect(!game.slide(dir))
            #expect(game.tiles == preTiles, "failed swipe mutated the board")
            #expect(game.score == 0)
            #expect(game.lastGain == 0)
            #expect(game.gainBeat == 0)
            #expect(game.justMerged.isEmpty)
            #expect(game.justSpawned == nil)
            #expect(game.lastMergedTier == nil)
            #expect(!game.canUndo, "failed swipe armed the undo snapshot")
        }
    }

    // guards: 10+10 creates THE ZOMBIE — zombieReached, lastMergedTier 11, gain 2048
    @Test func tierTenMergeCreatesZombie() throws {
        let game = try restoredGame([(10, 0, 0), (10, 1, 0)])
        try #require(game.slide(.left))
        #expect(signature(of: game) == ["11@0,0"])
        #expect(game.zombieReached)
        #expect(game.lastMergedTier == 11)
        #expect(game.lastGain == 2048)
        #expect(game.score == 2048)
        #expect(!game.isOver)
    }

    // guards: two ZOMBIEs never merge — packed pair refuses, sliding pair moves intact
    @Test func zombiePairNeverMerges() throws {
        let game = try restoredGame([(11, 0, 0), (11, 1, 0)])
        #expect(!game.slide(.left), "packed 11-11 pair counted as a move")
        try #require(game.slide(.right))
        #expect(signature(of: game) == ["11@3,0", "11@2,0"], "tier-11 pair merged")
        #expect(game.lastGain == 0)
        #expect(game.justMerged.isEmpty)
    }

    // guards: hasLegalMove mirrors the 11-no-merge rule — a board whose only pair is 11-11 is
    // dead; newGame then strips the dead run's zombieReached/zombieCelebrated/doublesAnnounced
    @Test func deadBoardWithOnlyZombiePairIsOver() throws {
        let game = try restoredGame(deadBoard, score: 4242, deterministic: false)
        #expect(game.isOver)
        #expect(game.zombieReached)
        #expect(game.zombieCelebrated, "resumed past-ZOMBIE run must not re-banner")
        #expect(game.doublesAnnounced, "tier 11 on board => doublesLive => announced on resume")
        #expect(!game.canUndo)
        let frozen = game.tiles
        for dir in allDirections { #expect(!game.slide(dir), "slide succeeded on a dead board") }
        #expect(game.tiles == frozen)
        #expect(game.score == 4242)
        // Starting the next run must strip the dead run's decorations.
        game.newGame()
        #expect(!game.zombieReached, "newGame kept zombieReached")
        #expect(!game.zombieCelebrated, "newGame kept zombieCelebrated — next run's banner is dead")
        #expect(!game.doublesAnnounced, "newGame kept doublesAnnounced — next run's announcement is dead")
    }

    // guards: isOver flips (or not) on the exact filling swipe, and the last-cell spawn is forced
    @Test func fillingSwipeResolvesIsOverBothWays() throws {
        // Side 1: the forced 16th spawn leaves no pair (its neighbors are
        // tiers 5 and 7, spawn is 1 or 2) => over on this very slide.
        let dying = try restoredGame(dyingBoard, deterministic: false)
        try #require(!dying.isOver)
        try #require(dying.slide(.left))
        #expect(dying.tiles.count == 16)
        let spawned = try #require(dying.tiles.first { $0.id == dying.justSpawned })
        #expect(spawned.col == 3 && spawned.row == 0, "spawn missed the only free cell")
        #expect((1...2).contains(spawned.tier))
        #expect(dying.isOver)
        #expect(!dying.canUndo, "snapshot was armed by the slide, but isOver must block undo")
        #expect(!dying.slide(.up))
        expectBoardSane(dying)

        // Side 2: a vertical 6-6 pair survives the fill => still alive.
        let surviving = try restoredGame(survivingBoard, deterministic: false)
        try #require(surviving.slide(.left))
        #expect(surviving.tiles.count == 16)
        #expect(!surviving.isOver, "full board with a live pair declared over")
        expectBoardSane(surviving)
    }
}

// MARK: - Undo

@MainActor
@Suite("Zombie undo")
struct ZombieUndoTests {
    // guards: undo requires an armed snapshot — fresh and newGame'd instances refuse
    @Test func undoUnavailableBeforeFirstEffectiveSwipe() {
        let fresh = ZombieGame()
        #expect(!fresh.canUndo)
        #expect(!fresh.undo())

        let game = ZombieGame()
        game.newGame()
        #expect(!game.canUndo)
        #expect(!game.undo())
        #expect(game.tiles.count == 2)
        #expect(game.score == 0)
    }

    // guards: one-per-run exact undo — byte-for-byte restore, then forbidden forever
    @Test func undoRestoresExactlyAndOnlyOnce() throws {
        let game = try restoredGame([(4, 0, 0), (4, 1, 0), (7, 3, 3)])
        let preTiles = game.tiles
        try #require(game.slide(.left))
        #expect(game.score == 32)
        try #require(game.canUndo)
        #expect(game.undo())
        #expect(game.tiles == preTiles, "undo did not restore the exact tile array (ids included)")
        #expect(game.score == 0)
        #expect(game.justMerged.isEmpty)
        #expect(game.justSpawned == nil)
        #expect(game.lastMergedTier == nil)
        #expect(game.undoUsed)
        #expect(!game.canUndo)
        #expect(!game.undo(), "second undo succeeded")
        #expect(game.tiles == preTiles, "failed undo mutated state")
        // A later effective swipe re-arms the snapshot but undoUsed keeps it dead.
        try #require(game.slide(.right))
        #expect(!game.canUndo, "undo re-enabled after being spent")
    }

    // guards: failed swipes never re-arm the snapshot — undo skips them back to the last effective state
    @Test func ineffectiveSwipeDoesNotRearmUndo() throws {
        let game = try restoredGame([(2, 0, 0), (2, 1, 0)])
        let preA = game.tiles
        try #require(game.slide(.left))          // A: effective merge
        #expect(!game.slide(.left))              // B: no-op
        #expect(!game.slide(.up))                // C: no-op
        #expect(game.undo())
        #expect(game.tiles == preA, "undo restored a post-no-op state instead of pre-A")
        #expect(game.score == 0)
    }

    // guards: undo restores exactly the snapshot trio (tiles/score/zombieReached);
    // zombieCelebrated/doublesAnnounced are per-run banner flags and deliberately survive
    // (doc on zombieCelebrated: "once this RUN's banner has had its moment") — pinned as intended
    @Test func undoWinRollsBackReachedNotCelebration() throws {
        let game = try restoredGame([(10, 0, 0), (10, 1, 0)])
        try #require(game.slide(.left))
        try #require(game.zombieReached)
        try #require(game.doublesLive)
        // The view flips these when the banner/announcement shows.
        game.zombieCelebrated = true
        game.doublesAnnounced = true
        #expect(game.undo())
        #expect(!game.zombieReached, "undo must roll back the win flag")
        #expect(signature(of: game) == ["10@0,0", "10@1,0"])
        #expect(game.zombieCelebrated, "per-run banner flag should survive undo (pinned)")
        #expect(game.doublesAnnounced, "per-run announcement flag should survive undo (pinned)")
    }

    // guards: best is a ratchet that records undone peaks
    @Test func bestKeepsUndonePeak() throws {
        // Non-tutorial (spawns live) because tutorialActive freezes best.
        let game = try restoredGame([(4, 0, 0), (4, 1, 0)], deterministic: false)
        try #require(game.slide(.left))
        #expect(game.score == 32)
        // best tracks face value, and the live spawn makes the exact number
        // random — the peak itself is the thing under test.
        let peak = game.boardValue
        #expect(peak > 32, "the swipe's spawn should be in the peak")
        #expect(game.best == peak)
        try #require(game.canUndo)
        #expect(game.undo())
        #expect(game.score == 0)
        #expect(game.boardValue < peak, "undo must roll the board back below the peak")
        #expect(game.best == peak, "best lost the undone peak")
    }
}

// MARK: - Tutorial

@MainActor
@Suite("Zombie tutorial")
struct ZombieTutorialTests {
    // guards: scripted rounds 0-2 merge to exactly expectedTier at (1,3) with no spawn and frozen best
    @Test(arguments: [0, 1, 2])
    func scriptedRoundsMergeAsDesigned(_ round: Int) throws {
        let game = ZombieGame()
        game.seedTutorialBoard(round: round)
        let expected = ZombieGame.tutorialRounds[round].expectedTier
        try #require(game.slide(.down))
        #expect(game.tiles.count == 1, "tutorial slide spawned")
        let tile = try #require(game.tiles.first)
        #expect(tile.tier == expected)
        #expect(tile.col == 1 && tile.row == 3)
        #expect(game.score == 1 << expected)
        #expect(game.best == 0, "tutorial merge polluted best")
        #expect(game.justMerged.count == 1)
    }

    // guards: round index clamps to 0...3 for any Int — never crashes, board matches the clamped script
    @Test(arguments: [Int.min, -1, 0, 3, 4, Int.max])
    func roundIndexClamping(_ round: Int) {
        let clamped = max(0, min(round, ZombieGame.tutorialRounds.count - 1))
        let spec = ZombieGame.tutorialRounds[clamped]

        let positions = ZombieGame.tutorialTilePositions(round: round)
        if clamped == ZombieGame.tutorialSwipeTeachRound {
            #expect(positions.isEmpty, "swipe-teach round must pulse no cells")
        } else {
            #expect(
                Set(positions.map { "\($0.col),\($0.row)" })
                    == Set(spec.tiles.map { "\($0.col),\($0.row)" })
            )
        }

        let game = ZombieGame()
        game.seedTutorialBoard(round: round)
        #expect(
            signature(of: game)
                == Set(spec.tiles.map { "\($0.tier)@\($0.col),\($0.row)" })
        )
        #expect(game.tutorialActive)
        #expect(game.score == 0)
        #expect(!game.isOver)
        #expect(!game.canUndo)
        expectBoardSane(game)
    }

    // guards: endTutorial clears the flag and spawns exactly two sane tiles
    @Test func endTutorialSpawnsExactlyTwo() throws {
        let game = ZombieGame()
        game.seedTutorialBoard(round: 3)
        let seededIDs = Set(game.tiles.map(\.id))
        try #require(seededIDs.count == 3)
        game.endTutorial()
        #expect(!game.tutorialActive)
        #expect(game.tiles.count == 5)
        let fresh = game.tiles.filter { !seededIDs.contains($0.id) }
        #expect(fresh.count == 2)
        #expect(fresh.allSatisfy { (1...2).contains($0.tier) })
        #expect(fresh.contains { $0.id == game.justSpawned })
        expectBoardSane(game)
    }

    // guards: spawn on a full board is a silent no-op — endTutorial on 16 tiles cannot overlap or crash
    @Test func endTutorialOnFullBoardIsSafe() throws {
        let game = try restoredGame(fullAliveBoard, deterministic: false)
        game.tutorialActive = true
        game.endTutorial()
        #expect(!game.tutorialActive)
        #expect(game.tiles.count == 16)
        expectBoardSane(game)
    }

    // guards: engine allows off-script tutorial swipes — tiles slide without merging or spawning
    @Test func offScriptSwipeSlidesWithoutMergeOrSpawn() throws {
        let game = ZombieGame()
        game.seedTutorialBoard(round: 0)   // two tier-1s at (1,0),(1,1)
        try #require(game.slide(.left))
        #expect(signature(of: game) == ["1@0,0", "1@0,1"], "cross-row tiles merged or spawned")
        #expect(game.score == 0)
        #expect(game.justMerged.isEmpty)
        #expect(game.justSpawned == nil)
    }

    // guards: pins that slide() arms undo even mid-tutorial — only the view hides the button
    @Test func tutorialSlideArmsUndo() throws {
        let game = ZombieGame()
        game.seedTutorialBoard(round: 0)
        let pre = game.tiles
        try #require(game.slide(.down))
        #expect(game.canUndo, "pin: engine arms undo during the tutorial (view must hide it)")
        #expect(game.undo())
        #expect(game.tiles == pre)
        #expect(game.tutorialActive, "undo should not exit tutorial mode")
    }

    // guards: pins that seedTutorialBoard preserves per-run banner flags (mid-run re-entry contract)
    @Test func seedTutorialKeepsCelebrationFlags() {
        let game = ZombieGame()
        game.zombieCelebrated = true
        game.doublesAnnounced = true
        game.seedTutorialBoard(round: 1)
        #expect(game.zombieCelebrated, "pin: seed does not reset zombieCelebrated")
        #expect(game.doublesAnnounced, "pin: seed does not reset doublesAnnounced")
        #expect(game.score == 0)
        #expect(!game.canUndo)
    }

    // guards: configureBest ratchets; tutorial scoring never raises best; a real swipe does
    @Test func configureBestRatchetAndTutorialFreeze() throws {
        let g1 = ZombieGame()
        g1.configureBest(50)
        g1.configureBest(10)
        g1.configureBest(-3)
        #expect(g1.best == 50, "configureBest must be a ratchet")

        let g2 = ZombieGame()
        g2.configureBest(5)
        g2.seedTutorialBoard(round: 2)     // tier-3 pair => merge scores 16 > 5
        try #require(g2.slide(.down))
        #expect(g2.score == 16)
        #expect(g2.best == 5, "tutorial merge raised best")

        let g3 = try restoredGame([(4, 0, 0), (4, 1, 0)], score: 100, deterministic: false)
        g3.configureBest(5)
        #expect(g3.best == 5, "pin: restore itself never raises best; only the next swipe does")
        try #require(g3.slide(.left))      // merge: 100 + 32
        #expect(g3.score == 132)
        // Face value, not the merge total: the two tier-4s become one 32,
        // plus whatever the live spawn added.
        #expect(g3.best == g3.boardValue, "a real swipe raises best to the board's face value")
        #expect(g3.best > 32, "and it beat the configured 5")
    }
}

// MARK: - Persistence

@MainActor
@Suite("Zombie persistence")
struct ZombiePersistenceTests {
    // guards: live round-trip is exact (UUIDs included), the undo snapshot never survives it,
    // and a spent undo (undoUsed) stays spent across the round-trip
    @Test func liveRoundTripFidelity() throws {
        let game = ZombieGame()
        game.newGame()
        game.loreSeen = [3, 4]
        var moved = false
        for dir in allDirections where !moved { moved = game.slide(dir) }
        try #require(moved, "no direction was effective from a 2-tile board")
        try #require(game.canUndo)

        let saved = game.payload(seenHowTo: true)
        let fresh = ZombieGame()
        let payload = try #require(fresh.restore(from: saved))
        #expect(payload.seenHowTo == true)
        #expect(fresh.tiles == game.tiles, "round-trip changed tiles (order/ids/fields)")
        #expect(fresh.score == game.score)
        #expect(fresh.undoUsed == game.undoUsed)
        #expect(fresh.loreSeen == [3, 4])
        #expect(!fresh.canUndo, "undo snapshot survived a relaunch")
        #expect(fresh.zombieCelebrated == fresh.zombieReached)
        #expect(fresh.doublesAnnounced == fresh.doublesLive)

        // Spend the one-per-run undo and round-trip again: undoUsed must persist
        // as true and keep undo dead after relaunch.
        try #require(game.undo())
        moved = false
        for dir in allDirections where !moved { moved = game.slide(dir) }
        try #require(moved)
        try #require(game.undoUsed)
        let fresh2 = ZombieGame()
        _ = try #require(fresh2.restore(from: game.payload(seenHowTo: true)))
        #expect(fresh2.undoUsed, "spent-undo flag lost in the round-trip")
        var moved2 = false
        for dir in allDirections where !moved2 { moved2 = fresh2.slide(dir) }
        try #require(moved2)
        #expect(!fresh2.canUndo, "spent undo came back after relaunch")
    }

    // guards: dead runs never resurrect — payload drops board/undoUsed, restore starts fresh, lore survives
    @Test func gameOverPayloadDropsBoard() throws {
        let dead = try restoredGame(deadBoard, score: 4242, loreSeen: [7], deterministic: false)
        try #require(dead.isOver)
        let saved = dead.payload(seenHowTo: true)
        let decoded = try JSONDecoder().decode(
            ZombieGame.SavePayload.self, from: try #require(saved.data(using: .utf8))
        )
        #expect(decoded.board == nil, "dead run serialized its board")
        #expect(decoded.undoUsed == nil)
        #expect(decoded.score == 4242)

        let fresh = ZombieGame()
        let payload = try #require(fresh.restore(from: saved))
        #expect(payload.seenHowTo == true)
        #expect(fresh.tiles.count == 2, "dead run resurrected")
        #expect(fresh.score == 0)
        #expect(!fresh.isOver)
        #expect(fresh.loreSeen == [7])
        expectBoardSane(fresh)
    }

    // guards: pins that a never-started game's payload (board:[]) is unrepresentable and degrades to newGame
    @Test func neverStartedPayloadFallsBackToNewGame() throws {
        let idle = ZombieGame()   // no newGame(): tiles empty, isOver false
        let saved = idle.payload(seenHowTo: false)
        let decoded = try JSONDecoder().decode(
            ZombieGame.SavePayload.self, from: try #require(saved.data(using: .utf8))
        )
        #expect(decoded.board?.isEmpty == true, "expected an encoded empty live board")

        let fresh = ZombieGame()
        let payload = fresh.restore(from: saved)
        #expect(payload != nil)
        #expect(fresh.tiles.count == 2, "pin: empty live board falls back to newGame")
        #expect(fresh.score == 0)
    }

    // guards: every undecodable payload returns nil and leaves a fresh playable game, no partial state
    @Test(arguments: garbageInputs)
    func undecodableRestoreFallsBack(_ raw: String?) {
        let game = ZombieGame()
        game.loreSeen = [42]   // sentinel: decode failure must not touch loreSeen
        let payload = game.restore(from: raw)
        #expect(payload == nil)
        #expect(game.loreSeen == [42], "partial state applied from an undecodable payload")
        #expect(game.tiles.count == 2)
        #expect(game.tiles.allSatisfy { (1...2).contains($0.tier) })
        #expect(game.score == 0)
        #expect(!game.isOver)
        expectBoardSane(game)
    }

    // guards: boardIsValid rejects hostile-but-decodable boards, yet the decoded payload/loreSeen apply
    @Test(arguments: invalidBoards)
    func invalidBoardFallsBackButAppliesLore(_ board: [Spec]) throws {
        let game = ZombieGame()
        let payload = try #require(
            game.restore(from: payloadJSON(seenHowTo: true, score: 77, board: board, loreSeen: [3, 4]))
        )
        #expect(payload.seenHowTo == true, "decoded payload must reach the caller")
        #expect(game.loreSeen == [3, 4], "loreSeen is assigned before board validation")
        #expect(game.tiles.count == 2, "invalid board did not fall back to newGame")
        #expect(game.score == 0, "score from the rejected payload leaked in")
        #expect(!game.isOver)
        expectBoardSane(game)
    }

    // guards: boardIsValid accepts the exact fence-posts (tier 1/11, cells 0/3, counts 1/16)
    @Test(arguments: boundaryBoards)
    func boundaryBoardsRestore(_ board: [Spec]) throws {
        let game = try restoredGame(board, score: 55, deterministic: false)
        #expect(game.score == 55)
        #expect(!game.isOver)
        expectBoardSane(game)
    }

    // guards: hostile lore ids (Int.max/Int.min/negative/dupes) round-trip as a set without crashing
    @Test func hostileLoreSeenRoundTrips() throws {
        let hostile = [Int.max, Int.min, -7, 999, 3, 3, 3]
        let game = ZombieGame()
        let payload = game.restore(
            from: try payloadJSON(board: [(2, 0, 0)], loreSeen: hostile)
        )
        try #require(payload != nil)
        #expect(game.loreSeen == Set(hostile))
        #expect(game.loreSeen.count == 5)

        let reEncoded = game.payload(seenHowTo: false)
        let decoded = try JSONDecoder().decode(
            ZombieGame.SavePayload.self, from: try #require(reEncoded.data(using: .utf8))
        )
        #expect(Set(decoded.loreSeen ?? []) == Set(hostile))
    }

    // guards: doublesLive threshold is exactly tier 8, and restore mirrors it into doublesAnnounced
    @Test(arguments: [(tier: 7, live: false), (tier: 8, live: true)])
    func doublesLiveThreshold(_ c: (tier: Int, live: Bool)) throws {
        let game = try restoredGame([(c.tier, 0, 0)], deterministic: false)
        #expect(game.doublesLive == c.live)
        #expect(game.doublesAnnounced == c.live)
    }
}

// MARK: - Fixed bugs (permanent regression tests for the 2026-07-17 fixes)

@MainActor
@Suite("Zombie fixed bugs")
struct ZombieSuspectedBugTests {
    // guards: restore must clamp hostile scores so no later merge can trap on Int overflow
    // REGRESSION(score-not-validated-on-restore): fixed — restore clamps to 0...Int.max/2.
    // NOTE: deliberately no slide() here — an unclamped score == Int.max would make the
    // next merge's `score += 1 << tier` TRAP and kill the entire test process.
    @Test(arguments: [Int.max, -5000])
    func restoreClampsHostileScore(_ hostile: Int) throws {
        let game = ZombieGame()
        let payload = game.restore(
            from: try payloadJSON(score: hostile, board: [(1, 0, 0), (1, 1, 0)])
        )
        try #require(payload != nil)
        try #require(game.tiles.count == 2, "valid board must restore even when score is hostile")
        #expect(game.score >= 0, "negative score restored verbatim")
        // Max possible single-swipe gain is 8 merges x (1 << 11) = 16384; any
        // restored score above Int.max - 16384 can trap on the next merge.
        #expect(game.score <= Int.max - 16384, "restored score can overflow on the next merge")
    }

    // guards: newGame must hand the board back from the tutorial so spawns/best resume
    // REGRESSION(newgame-keeps-tutorial-active): fixed — newGame clears tutorialActive.
    @Test func newGameExitsTutorialMode() throws {
        let game = ZombieGame()
        game.seedTutorialBoard(round: 0)
        game.newGame()
        #expect(!game.tutorialActive, "newGame left tutorialActive set")
        var moved = false
        for dir in allDirections where !moved { moved = game.slide(dir) }
        try #require(moved)
        // With tutorialActive stuck, spawn() is skipped and the run drains unwinnably.
        #expect(game.justSpawned != nil, "post-newGame swipe did not spawn")
    }

    // guards: restoring a live run must exit tutorial mode so spawns resume
    // REGRESSION(restore-keeps-tutorial-active): fixed — restore clears tutorialActive.
    @Test func restoreExitsTutorialMode() throws {
        let game = ZombieGame()
        game.seedTutorialBoard(round: 0)
        let payload = game.restore(from: try payloadJSON(board: [(3, 0, 0), (5, 1, 0)]))
        try #require(payload != nil)
        try #require(signature(of: game) == ["3@0,0", "5@1,0"])
        #expect(!game.tutorialActive, "restore left tutorialActive set")
    }

    // guards: newGame must reset lastGain — a view reading it pre-first-swipe sees the old run's gain
    // REGRESSION(newgame-stale-lastgain): fixed — newGame resets lastGain.
    // (gainBeat continuity across runs is deliberately NOT asserted — it is an
    // intentional change-key; only lastGain was stale data.)
    @Test func newGameResetsLastGain() throws {
        let game = try restoredGame([(2, 0, 0), (2, 1, 0)])
        try #require(game.slide(.left))
        try #require(game.lastGain == 8)
        game.newGame()
        #expect(game.lastGain == 0, "lastGain from the previous run survived newGame")
    }

    // guards: restore must clear animation state — stale UUIDs of dead tiles must not survive
    // REGRESSION(restore-stale-animation-state): fixed — restore clears the animation trio.
    @Test func restoreClearsAnimationState() throws {
        let game = try restoredGame([(2, 0, 0), (2, 1, 0)], deterministic: false)
        try #require(game.slide(.left))
        try #require(!game.justMerged.isEmpty)
        try #require(game.justSpawned != nil)
        try #require(game.lastMergedTier != nil)

        let payload = game.restore(from: try payloadJSON(board: [(5, 2, 2)]))
        try #require(payload != nil)
        try #require(signature(of: game) == ["5@2,2"])
        #expect(game.justMerged.isEmpty, "justMerged references tiles that no longer exist")
        #expect(game.justSpawned == nil, "justSpawned references a tile that no longer exists")
        #expect(game.lastMergedTier == nil, "lastMergedTier survived restore")
    }
}

// MARK: - Resource / soak

@MainActor
@Suite("Zombie resource bounds")
struct ZombieResourceTests {
    // guards: a 10,000-tile board decodes, is rejected at count > 16, and finishes fast
    @Test func giantBoardPayloadRejectedFast() throws {
        let uuid = UUID().uuidString
        var entries: [String] = []
        entries.reserveCapacity(10_000)
        for i in 0..<10_000 {
            entries.append(#"{"id":"\#(uuid)","tier":1,"col":\#(i % 4),"row":\#((i / 4) % 4)}"#)
        }
        let json = #"{"seenHowTo":false,"score":0,"board":[\#(entries.joined(separator: ","))]}"#

        let start = Date()
        let game = ZombieGame()
        let payload = game.restore(from: json)
        #expect(Date().timeIntervalSince(start) < 2, "giant-board restore exceeded 2s")
        #expect(payload != nil, "well-formed JSON should decode even with a huge board")
        #expect(game.tiles.count == 2, "giant board was not rejected")
        expectBoardSane(game)
    }

    // guards: soak invariants across ~1200 real swipes — bounds, unique cells, score accounting,
    // gainBeat ticks only on scoring swipes, spawn tiers sane, isOver latches until newGame
    // un-latches it (and newGame drops the dead run's undo snapshot)
    @Test func randomSoakHoldsInvariants() {
        var rng = SplitMix64(state: 0xC0FFEE)
        let game = ZombieGame()
        game.newGame()

        for _ in 0..<1200 {
            if game.isOver {
                let frozenTiles = game.tiles
                let frozenScore = game.score
                for dir in allDirections {
                    #expect(!game.slide(dir), "slide succeeded after isOver")
                }
                #expect(game.tiles == frozenTiles, "dead board mutated")
                #expect(game.score == frozenScore)
                #expect(!game.canUndo)
                game.newGame()
                #expect(game.tiles.count == 2)
                #expect(game.score == 0)
                #expect(!game.isOver, "newGame left isOver latched")
                #expect(!game.canUndo, "previous run's undo snapshot survived newGame")
                continue
            }

            let dir = allDirections.randomElement(using: &rng)!
            let scoreBefore = game.score
            let beatBefore = game.gainBeat
            let tilesBefore = game.tiles
            let moved = game.slide(dir)

            expectBoardSane(game)
            if moved {
                let delta = game.score - scoreBefore
                #expect(delta >= 0, "score decreased on a swipe")
                if delta > 0 {
                    #expect(delta == game.lastGain, "lastGain != score delta")
                    #expect(game.gainBeat == beatBefore + 1, "gainBeat did not tick on a scoring swipe")
                } else {
                    #expect(game.gainBeat == beatBefore, "gainBeat ticked without a gain")
                }
                if let spawnedID = game.justSpawned,
                   let spawned = game.tiles.first(where: { $0.id == spawnedID }) {
                    #expect((1...2).contains(spawned.tier), "spawned tier \(spawned.tier)")
                }
            } else {
                #expect(game.tiles == tilesBefore, "failed swipe mutated the board")
                #expect(game.score == scoreBefore)
                #expect(game.gainBeat == beatBefore)
            }
        }
    }

    // guards: payload() is pure — repeated calls yield equal payloads and mutate nothing
    @Test func payloadIsPureAndStable() throws {
        let game = try restoredGame(
            [(3, 0, 0), (5, 1, 0), (8, 2, 2)], score: 640, loreSeen: [3, 4, 9], deterministic: false
        )
        let tilesBefore = game.tiles
        let first = try JSONDecoder().decode(
            ZombieGame.SavePayload.self,
            from: try #require(game.payload(seenHowTo: true).data(using: .utf8))
        )
        for _ in 0..<200 {
            let next = try JSONDecoder().decode(
                ZombieGame.SavePayload.self,
                from: try #require(game.payload(seenHowTo: true).data(using: .utf8))
            )
            #expect(next.seenHowTo == first.seenHowTo)
            #expect(next.score == first.score)
            #expect(next.board == first.board)
            #expect(next.undoUsed == first.undoUsed)
            // Set ordering may differ per encode; compare as sets.
            #expect(Set(next.loreSeen ?? []) == Set(first.loreSeen ?? []))
        }
        #expect(game.tiles == tilesBefore, "payload() mutated tiles")
        #expect(game.score == 640, "payload() mutated score")
    }
}

// MARK: - Depth charge (2×2 bomb)

@MainActor
@Suite("Zombie depth charge")
struct ZombieDepthChargeTests {
    // guards: the blast is surgical — exactly the anchored 2×2 dies; score and spawn untouched; the run stays live
    @Test func detonateClearsOnlyTheTargetSquare() throws {
        let game = try restoredGame(fullAliveBoard, score: 500, deterministic: false)
        let cleared = game.detonate(col: 1, row: 1)
        #expect(cleared == 4)
        #expect(game.tiles.count == 12, "no spawn rides along")
        let gone = [(1, 1), (2, 1), (1, 2), (2, 2)]
        let expected = signature(fullAliveBoard.filter { s in
            !gone.contains { $0.0 == s.col && $0.1 == s.row }
        })
        #expect(signature(of: game) == expected)
        #expect(game.score == 500, "a rescue never scores")
        #expect(!game.isOver, "clearing tiles can only open the board")
        #expect(game.bombBeat == 1)
        #expect(game.lastBombedCells.count == 4)
        expectBoardSane(game)
    }

    // guards: out-of-range anchors clamp onto the board instead of missing it
    @Test func detonateAnchorClampsOntoTheBoard() throws {
        let game = try restoredGame(fullAliveBoard, deterministic: false)
        #expect(game.detonate(col: 9, row: 9) == 4, "clamps to (2,2)")
        #expect(tileAt(game, 3, 3) == nil)
        #expect(tileAt(game, 2, 2) == nil)
        let game2 = try restoredGame(fullAliveBoard, deterministic: false)
        #expect(game2.detonate(col: -3, row: -3) == 4, "clamps to (0,0)")
        #expect(tileAt(game2, 0, 0) == nil)
        #expect(tileAt(game2, 1, 1) == nil)
    }

    // guards: an empty target refuses — nothing cleared, no FX beat, so the caller keeps the charge
    @Test func detonateOnEmptyRegionIsANoOp() throws {
        let game = try restoredGame([(3, 0, 0), (5, 1, 0)], deterministic: false)
        #expect(game.detonate(col: 2, row: 2) == 0)
        #expect(signature(of: game) == signature([(3, 0, 0), (5, 1, 0)]))
        #expect(game.bombBeat == 0)
        #expect(game.lastBombedCells.isEmpty)
    }

    // guards: no reviving the dead — the charge is a danger tool, not a continue (a revived run would double-pay the wallet via recordRun)
    @Test func detonateRefusesADeadRun() throws {
        let game = try restoredGame(deadBoard, deterministic: false)
        try #require(game.isOver)
        #expect(game.detonate(col: 1, row: 1) == 0)
        #expect(game.tiles.count == 16)
    }

    // guards: the scripted tutorial board is off-limits
    @Test func detonateRefusesDuringTutorial() throws {
        let game = try restoredGame(fullAliveBoard, deterministic: true)  // flips tutorialActive
        #expect(game.detonate(col: 1, row: 1) == 0)
        #expect(game.tiles.count == 16)
    }

    // guards: the undo snapshot dies with the board it remembered — no rewinding across a blast, and no stale animation crumbs
    @Test func detonateKillsTheUndoSnapshot() throws {
        let game = try restoredGame([(2, 0, 0), (2, 1, 0)], deterministic: false)
        try #require(game.slide(.left))
        try #require(game.canUndo)
        #expect(game.detonate(col: 0, row: 0) >= 1)
        #expect(!game.canUndo)
        #expect(game.justMerged.isEmpty)
        #expect(game.justSpawned == nil)
        #expect(game.lastMergedTier == nil)
    }

    // guards: DANGER is exactly "two or fewer empties on a live, non-tutorial board"
    @Test func dangerThresholds() throws {
        #expect(try restoredGame(fullAliveBoard, deterministic: false).inDanger, "0 empties, alive")
        #expect(try restoredGame(Array(fullAliveBoard.dropLast(2)), deterministic: false).inDanger, "2 empties")
        #expect(!(try restoredGame(Array(fullAliveBoard.dropLast(3)), deterministic: false).inDanger), "3 empties is still open water")
        #expect(!(try restoredGame(deadBoard, deterministic: false).inDanger), "dead is dead, not danger")
        #expect(!(try restoredGame(fullAliveBoard, deterministic: true).inDanger), "tutorial boards never comp")
    }

    // guards: newGame forgets the last blast — no ghost bursts on a fresh board
    @Test func newGameClearsBlastState() throws {
        let game = try restoredGame(fullAliveBoard, deterministic: false)
        _ = game.detonate(col: 0, row: 0)
        try #require(!game.lastBombedCells.isEmpty)
        game.newGame()
        #expect(game.lastBombedCells.isEmpty)
    }
}
