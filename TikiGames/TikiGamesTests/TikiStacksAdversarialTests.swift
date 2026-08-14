import Foundation
import Testing
@testable import Tiki_Lounge

/// Adversarial tests for the TikiStacks ("Totems") engine — TikiStacksGame.swift.
///
/// Every hard-coded expected value in this file was verified 2026-07-17 by
/// compiling TikiStacksGame.swift + RunSummary.swift into a standalone harness
/// (swiftc -swift-version 6 -D DEBUG, arm64 macOS) and running it 10x with 0
/// failures. Notable measured facts:
///   - snappedOrigin engages at euclidean distance EXACTLY 1.25 (5.25 - 4.0 is
///     exact in binary floating point; sqrt(25/16) == 1.25 exactly).
///   - The half-cell tie at ideal (3.5, 3.0) resolves to row 3 (the dr=-1
///     candidate iterated first), NOT the rounded row 4 — strict `<` keeps the
///     first minimum.
///   - Moonlit-vs-clean sweep is evaluated AFTER the clear's points land:
///     score 395 + 1 + 10 = 406 => stage 2 at bonus time => +240, total 646.
///   - restore once accepted score/streak up to Int.max unclamped and the
///     very next place() trapped on `score +=`; FIXED 2026-07-17 (clamps to
///     99_999_999 / 9_999), pinned by restoreClampsOverflowNumbers, which
///     still asserts WITHOUT placing.
///
/// TikiStacksGame is @MainActor @Observable with zero global state: no
/// UserDefaults, no SwiftData, no singletons, no Date()/timers — only two
/// unstructured MainActor Task.sleeps (750ms clearFlash expiry, 1s popup
/// removal), which the VFX-timing suite awaits past with >=100ms margins.
/// A fresh instance per test is complete isolation. Randomness (piece colors,
/// bag order) is NOT seedable, so no test asserts colors or deal order;
/// deterministic tests overwrite `grid`/`tray` directly after init.
///
/// Piece.rows/cols force-unwrap on empty `cells` — hasAnyPlacement /
/// snappedOrigin / checkGameOver TRAP on an empty-cells piece, and
/// debugBotBatch(runs: 0) traps on empty-array indexing. Swift Testing exit
/// tests are unavailable on iOS, so those traps are documented (and their
/// guard conditions tested) rather than triggered.

// MARK: - Helpers (fileprivate; every game mutation runs on MainActor)

@MainActor
private func emptyGrid() -> [[BlockColor?]] {
    Array(repeating: Array(repeating: BlockColor?.none, count: 8), count: 8)
}

@MainActor
private func dot() -> Piece { Piece(id: UUID(), cells: [GridPos(row: 0, col: 0)], color: .coral) }

@MainActor
private func hline(_ n: Int) -> Piece {
    Piece(id: UUID(), cells: (0..<n).map { GridPos(row: 0, col: $0) }, color: .teal)
}

@MainActor
private func vline(_ n: Int) -> Piece {
    Piece(id: UUID(), cells: (0..<n).map { GridPos(row: $0, col: 0) }, color: .teal)
}

@MainActor
private func square3() -> Piece {
    Piece(id: UUID(), cells: (0..<3).flatMap { r in (0..<3).map { GridPos(row: r, col: $0) } }, color: .gold)
}

@MainActor
private func fillRow(_ g: TikiStacksGame, _ row: Int, cols: Range<Int>) {
    for c in cols { g.grid[row][c] = .gold }
}

@MainActor
private func gridIsEmpty(_ g: TikiStacksGame) -> Bool {
    g.grid.allSatisfy { $0.allSatisfy { $0 == nil } }
}

@MainActor
private func encodePayload(_ p: TikiStacksGame.SavePayload) throws -> String {
    try #require(String(data: JSONEncoder().encode(p), encoding: .utf8))
}

/// Fills the board with a checkerboard (no full lines) whose free cells cannot
/// host a 3x3 — the deterministic no-clear game-over stage.
@MainActor
private func checkerboard(_ g: TikiStacksGame) {
    g.grid = emptyGrid()
    for r in 0..<8 { for k in 0..<8 where (r + k) % 2 == 0 { g.grid[r][k] = .coral } }
}

/// PieceLibrary shapes as GridPos arrays, in library order (deals are exact
/// untransformed copies, so `cells` identifies the shape index).
@MainActor
private func libraryShapeCells() -> [[GridPos]] {
    PieceLibrary.shapes.map { $0.map { GridPos(row: $0.0, col: $0.1) } }
}

// MARK: - Argument lists (global lets: immutable, Sendable, isolation-free)

private let boundsCases: [(row: Int, col: Int, legal: Bool)] = [
    (0, 0, true), (0, 7, true), (7, 0, true), (7, 7, true),
    (-1, 0, false), (0, -1, false), (8, 0, false), (0, 8, false),
    (Int.min, 0, false), (0, Int.min, false), (Int.max, Int.max, false),
]

private let stageCases: [(score: Int, stage: Int)] = [
    (0, 0), (149, 0), (150, 1), (399, 1), (400, 2), (799, 2),
    (800, 3), (1499, 3), (1500, 4), (Int.max - 1000, 4), (-5, 0),
]

private let garbagePayloads: [String?] = [nil, "", "not json", "[]", "{}"]

private let abusiveSlots: [Int] = [-1, 3, Int.max, Int.min]

/// (round, expected score after the scripted drop): cells + (round+1)*10*1.
private let tutorialCases: [(round: Int, score: Int)] = [(0, 11), (1, 21), (2, 32), (3, 44)]

#if DEBUG
private let fireflyBagCases: [(seedScore: Int, glowPerBag: Int)] = [(399, 0), (400, 1), (1500, 2)]
#endif

// MARK: - Geometry

@MainActor
@Suite("TikiStacks geometry")
struct TikiStacksGeometryTests {

    // guards: canPlace accepts every in-bounds empty corner and rejects out-of-bounds origins (incl. Int.min/Int.max) without trapping
    @Test(arguments: boundsCases)
    func canPlaceBoundsAndCorners(_ c: (row: Int, col: Int, legal: Bool)) {
        let g = TikiStacksGame()
        #expect(g.canPlace(dot(), at: GridPos(row: c.row, col: c.col)) == c.legal)
    }

    // guards: exact-fit 5-long lines place at the last legal origin and overflow one past it, both axes
    @Test func exactFitFiveLines() {
        let g = TikiStacksGame()
        #expect(g.canPlace(hline(5), at: GridPos(row: 0, col: 3)) == true)
        #expect(g.canPlace(hline(5), at: GridPos(row: 0, col: 4)) == false)
        #expect(g.canPlace(vline(5), at: GridPos(row: 3, col: 0)) == true)
        #expect(g.canPlace(vline(5), at: GridPos(row: 4, col: 0)) == false)
    }

    // guards: hasAnyPlacement handles an exact-board-height piece (0...0 origin range) and rejects a 9-tall piece without a range trap
    @Test func hasAnyPlacementHeightBounds() {
        let g = TikiStacksGame()
        #expect(g.hasAnyPlacement(vline(8)) == true)
        #expect(g.hasAnyPlacement(vline(9)) == false)
    }

    // guards: snap radius is a closed bound — engages at euclidean distance exactly 1.25 (edge clamp), refuses just past it
    @Test func snapEngagesAtExactRadiusAndNotPast() {
        let g = TikiStacksGame()
        let line4 = hline(4)
        // All 3x3 candidates clamp to the max legal col 4; dist == |4 - 5.25| == 1.25 exactly.
        #expect(g.snappedOrigin(for: line4, idealRow: 0.0, idealCol: 5.25) == GridPos(row: 0, col: 4))
        #expect(g.snappedOrigin(for: line4, idealRow: 0.0, idealCol: 5.2500001) == nil)
    }

    // guards: resting diagonals (sqrt2 ~ 1.414) and far drops (tray zone) never teleport a piece
    @Test func snapNeverTeleportsDiagonalOrFar() {
        let g = TikiStacksGame()
        g.grid[3][3] = .coral; g.grid[3][2] = .coral; g.grid[3][4] = .coral
        g.grid[2][3] = .coral; g.grid[4][3] = .coral
        // (2,2) is free but diagonal — must not be reached.
        #expect(g.snappedOrigin(for: dot(), idealRow: 3.0, idealCol: 3.0) == nil)
        let g2 = TikiStacksGame()
        #expect(g2.snappedOrigin(for: dot(), idealRow: 9.5, idealCol: 3.0) == nil)
    }

    // guards: the exact .5 tie resolves deterministically to the first-iterated (dr=-1) candidate, NOT the rounded origin
    @Test func snapHalfCellTieBreakIsDeterministic() {
        let g = TikiStacksGame()
        // rounded() gives row 4 (half-away-from-zero) at dist 0.5, but row 3
        // (dr=-1, iterated first) also has dist 0.5 and strict `<` keeps it.
        #expect(g.snappedOrigin(for: dot(), idealRow: 3.5, idealCol: 3.0) == GridPos(row: 3, col: 3))
    }

    // guards: a piece taller than the board drives the clamp target negative — absorbed by canPlace, nil, no trap
    @Test func snapOversizedPieceReturnsNil() {
        let g = TikiStacksGame()
        #expect(g.snappedOrigin(for: vline(10), idealRow: 3.0, idealCol: 3.0) == nil)
    }

    // SUSPECTED-BUG(negative-coord-piece-geometry): pins the validation gap's downstream geometry — current behavior
    // guards: a cells-above-anchor piece (rows == 0) widens hasAnyPlacement's origin scan past the board edge; only final-cell bounds matter
    @Test func negativeCoordPieceWidensOriginRange() {
        let g = TikiStacksGame()
        let p = Piece(id: UUID(), cells: [GridPos(row: -1, col: 0)], color: .teal)
        #expect(g.hasAnyPlacement(p) == true)
        // Origin row 8 is outside the board, yet legal: the sole cell lands on row 7.
        #expect(g.canPlace(p, at: GridPos(row: 8, col: 0)) == true)
        #expect(g.canPlace(p, at: GridPos(row: 0, col: 0)) == false)
    }

    // SUSPECTED-BUG(empty-piece-trap): safe halves only — hasAnyPlacement/snappedOrigin/checkGameOver TRAP on
    // an empty-cells piece (Piece.rows force-unwraps); restore's `!cells.isEmpty &&` short-circuit is the sole guard
    // guards: canPlace/place treat an empty-cells piece as vacuously legal (score +0, no cells written, slot consumed)
    @Test func emptyPieceVacuousPlacement() {
        let g = TikiStacksGame()
        let empty = Piece(id: UUID(), cells: [], color: .teal)
        #expect(g.canPlace(empty, at: GridPos(row: 0, col: 0)) == true)
        #expect(g.canPlace(empty, at: GridPos(row: 99, col: 99)) == true) // vacuous even out of bounds
        g.grid = emptyGrid()
        g.tray = [empty, nil, nil]
        let before = g.score
        // Tray must not retain the empty piece afterward: checkGameOver would
        // call hasAnyPlacement(empty) and crash. Placing it (slot -> nil) and
        // letting the auto-refill deal real pieces keeps this trap-free.
        #expect(g.place(slot: 0, at: GridPos(row: 4, col: 4)) == true)
        #expect(g.score == before)
        #expect(gridIsEmpty(g))
        #expect(g.tray.compactMap { $0 }.count == 3)
    }
}

// MARK: - Scoring & clears

@MainActor
@Suite("TikiStacks scoring")
struct TikiStacksScoringTests {

    // guards: sweep tier is decided AFTER the clear's points land — 395 + 1 + 10 crosses NIGHTFALL, so the bonus is 240 not 120
    @Test func moonlitSweepEvaluatedAfterClearPoints() {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        fillRow(g, 4, cols: 0..<7)
        g.score = 395
        g.tray = [dot(), nil, nil]
        #expect(g.place(slot: 0, at: GridPos(row: 4, col: 7)) == true)
        #expect(g.score == 646) // 395 + 1 + 10 + 240
        #expect(g.popups.contains { $0.text == "MOONLIT SWEEP! +240" })
        #expect(!g.popups.contains { $0.text.hasPrefix("CLEAN SWEEP") })
    }

    // guards: 16 simultaneous lines clear in one pass (delta 1 + 16*10*1 + 120 = 281), grid fully empties, flash covers all 64 cells
    @Test func sixteenLineNukeCleanSweep() {
        let g = TikiStacksGame()
        for r in 0..<8 { for k in 0..<8 { g.grid[r][k] = BlockColor.allCases[(r + k) % 6] } }
        g.grid[4][7] = nil
        g.tray = [dot(), nil, nil]
        #expect(g.place(slot: 0, at: GridPos(row: 4, col: 7)) == true)
        #expect(g.score == 281)
        #expect(g.lastClearCount == 16)
        #expect(g.streak == 1)
        #expect(Set(g.clearFlash).count == 64)
        #expect(g.popups.contains { $0.text == "CLEAN SWEEP! +120" && $0.tier == 3 })
        #expect(gridIsEmpty(g))
        #expect(g.clearBeat == 1)
    }

    // guards: streak counts consecutive clearing placements (1,2,0,1), points scale by the NEW streak, COMBO popup fires only at streak>=2 with tier min(streak-1,2)
    @Test func streakAndComboSequence() {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        g.grid[7][0] = .teal // sentinel: board never empties, no sweep noise
        fillRow(g, 0, cols: 0..<7)
        g.tray = [dot(), nil, nil]
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 7)) == true)
        #expect(g.streak == 1 && g.score == 11)
        fillRow(g, 1, cols: 0..<7)
        g.tray[0] = dot()
        #expect(g.place(slot: 0, at: GridPos(row: 1, col: 7)) == true)
        #expect(g.streak == 2 && g.score == 32) // +1 + 1*10*2
        #expect(g.popups.filter { $0.text.hasPrefix("COMBO") }.count == 1)
        #expect(g.popups.first { $0.text == "COMBO x2" }?.tier == 1)
        g.tray[0] = dot()
        #expect(g.place(slot: 0, at: GridPos(row: 5, col: 5)) == true) // non-clearing
        #expect(g.streak == 0 && g.lastClearCount == 0 && g.score == 33)
        g.grid[5][5] = nil
        fillRow(g, 2, cols: 0..<7)
        g.tray[0] = dot()
        #expect(g.place(slot: 0, at: GridPos(row: 2, col: 7)) == true)
        #expect(g.streak == 1 && g.score == 44) // streak restarted at 1
        #expect(g.popups.filter { $0.text.hasPrefix("COMBO") }.count == 1) // no new combo at streak 1
    }

    // guards: clearBeat is +1 per clearing placement, cumulative, and deliberately NOT reset by restart()
    @Test func clearBeatCumulativeAcrossRestart() {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        g.grid[7][0] = .teal
        for row in [0, 1] {
            fillRow(g, row, cols: 0..<7)
            g.tray[0] = dot()
            #expect(g.place(slot: 0, at: GridPos(row: row, col: 7)) == true)
        }
        #expect(g.clearBeat == 2)
        g.restart()
        #expect(g.clearBeat == 2)
        g.grid[7][0] = .teal
        fillRow(g, 0, cols: 0..<7)
        g.tray[0] = dot()
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 7)) == true)
        #expect(g.clearBeat == 3)
    }

    // guards: stage is a pure >= count over [150,400,800,1500] with exact off-by-one edges; negative score maps to 0
    @Test(arguments: stageCases)
    func stageLadder(_ c: (score: Int, stage: Int)) {
        let g = TikiStacksGame()
        g.score = c.score
        #expect(g.stage == c.stage)
    }

    // guards: mood fill threshold flips between 38 and 39 filled cells (0.6 boundary) and priority is sleepy > surprised > grumpy > happy
    @Test func moodPriorityAndFillThreshold() {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        var placed = 0
        outer: for r in 0..<8 {
            for k in 0..<8 {
                if placed == 38 { break outer }
                g.grid[r][k] = .coral
                placed += 1
            }
        }
        #expect(g.mood == .happy)   // 38/64 = 0.59375 <= 0.6
        g.grid[5][0] = .coral
        #expect(g.mood == .grumpy)  // 39/64 = 0.609375 > 0.6
        g.lastClearCount = 1
        #expect(g.mood == .grumpy)  // single-line clears never surprise: threshold is >= 2
        g.lastClearCount = 2
        #expect(g.mood == .surprised)
        g.isGameOver = true
        #expect(g.mood == .sleepy)
    }

    // guards: clear centroid rounds the fractional midpoint half-away-from-zero while the points popup keeps the exact fraction
    @Test func clearCentroidHalfCellRounding() throws {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        g.grid[7][0] = .teal
        fillRow(g, 4, cols: 0..<7)
        g.tray = [dot(), nil, nil]
        #expect(g.place(slot: 0, at: GridPos(row: 4, col: 7)) == true)
        #expect(g.clearCentroid == GridPos(row: 4, col: 4)) // midCol 3.5 rounds to 4
        let pop = try #require(g.popups.first { $0.text == "+10" })
        #expect(pop.row == 4.0 && pop.col == 3.5)
    }

    // SUSPECTED-BUG(restore-firefly-validation): pins that restore accepts fireflies on empty and out-of-board cells — current behavior
    // guards: firefly bonus is flat +25 per clear event (not per cell), cleared fireflies leave the set, disjoint clears pay nothing, (99,99) leaks forever
    @Test func fireflyBonusFlatPerClearAndCraftedFireflies() throws {
        let g = TikiStacksGame()
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: 0, streak: 0, board: emptyGrid(),
            tray: [dot(), nil, nil],
            fireflies: [GridPos(row: 4, col: 0), GridPos(row: 4, col: 5), GridPos(row: 99, col: 99)],
            glowingTray: nil
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        #expect(g.fireflyCells.count == 3) // no bounds/filled validation
        g.grid[0][0] = .teal // sentinel against clean sweep
        fillRow(g, 4, cols: 0..<7)
        #expect(g.place(slot: 0, at: GridPos(row: 4, col: 7)) == true)
        #expect(g.score == 36) // 1 + 10 + 25: TWO fireflies in the clear pay ONE flat bonus
        #expect(g.fireflyCells == [GridPos(row: 99, col: 99)])
        #expect(g.popups.filter { $0.text.hasPrefix("FIREFLY") }.count == 1)
        fillRow(g, 2, cols: 0..<7)
        g.tray[0] = dot()
        #expect(g.place(slot: 0, at: GridPos(row: 2, col: 7)) == true) // firefly-free clear
        #expect(g.score == 57) // +1 + 1*10*2, no bonus
        #expect(g.fireflyCells == [GridPos(row: 99, col: 99)]) // dormant leak, untouched
        #expect(g.popups.filter { $0.text.hasPrefix("FIREFLY") }.count == 1)
    }

    // SUSPECTED-BUG(first-best-popup-asymmetry): pins that a first-ever best (startingBest 0) never gets the NEW BEST! popup while isNewBest reports true
    // guards: NEW BEST! fires exactly once per run when startingBest > 0, and never when startingBest == 0
    @Test func firstBestPopupAsymmetry() {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        g.grid[7][0] = .teal
        fillRow(g, 0, cols: 0..<7)
        g.tray = [dot(), nil, nil]
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 7)) == true)
        #expect(g.isNewBest == true) // score 11 > startingBest 0
        #expect(!g.popups.contains { $0.text == "NEW BEST!" }) // suppressed: startingBest == 0

        let g2 = TikiStacksGame()
        g2.configureBest(50)
        g2.grid = emptyGrid()
        g2.grid[7][0] = .teal
        fillRow(g2, 0, cols: 0..<7)
        g2.score = 45
        g2.tray = [dot(), nil, nil]
        #expect(g2.place(slot: 0, at: GridPos(row: 0, col: 7)) == true)
        #expect(g2.score == 56)
        #expect(g2.popups.filter { $0.text == "NEW BEST!" }.count == 1)
        fillRow(g2, 1, cols: 0..<7)
        g2.tray[0] = dot()
        #expect(g2.place(slot: 0, at: GridPos(row: 1, col: 7)) == true)
        #expect(g2.popups.filter { $0.text == "NEW BEST!" }.count == 1) // celebratedBest latched
    }
}

// MARK: - Lifecycle & state corruption

@MainActor
@Suite("TikiStacks lifecycle")
struct TikiStacksLifecycleTests {

    // guards: out-of-range slot indices are rejected with zero mutation and no index trap
    @Test(arguments: abusiveSlots)
    func slotIndexAbuse(_ slot: Int) {
        let g = TikiStacksGame()
        let ids = g.tray.map { $0?.id }
        #expect(g.place(slot: slot, at: GridPos(row: 0, col: 0)) == false)
        #expect(g.tray.map { $0?.id } == ids && g.score == 0)
    }

    // guards: a spent slot cannot be double-spent — second place on the same slot fails with no mutation
    @Test func doubleSpendSlot() {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        g.tray = [dot(), dot(), nil]
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 0)) == true)
        let score = g.score
        #expect(g.place(slot: 0, at: GridPos(row: 5, col: 5)) == false)
        #expect(g.score == score && g.grid[5][5] == nil)
    }

    // guards: place() is atomic on failure — a partially-overlapping piece writes NO cells and mutates nothing
    @Test func placementAtomicOnPartialOverlap() {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        g.grid[3][4] = .coral
        g.streak = 5
        g.tray = [hline(4), dot(), nil]
        #expect(g.place(slot: 0, at: GridPos(row: 3, col: 2)) == false) // cols 2..5, col 4 blocked
        #expect(g.grid[3][2] == nil && g.grid[3][3] == nil && g.grid[3][5] == nil)
        #expect(g.score == 0 && g.streak == 5 && g.tray[0] != nil)
    }

    // guards: game over is detected without any clear, latches against further placement, fires onGameOver exactly once with the post-placement score, and restart() re-arms play
    @Test func gameOverLatchAndExactlyOnceCallback() {
        let g = TikiStacksGame()
        checkerboard(g) // free cells cannot host a 3x3
        g.tray = [dot(), square3(), square3()]
        var calls: [Int] = []
        g.onGameOver = { calls.append($0) }
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 1)) == true)
        #expect(g.isGameOver == true)
        #expect(calls == [1]) // dot's 1 point, best already updated
        #expect(g.place(slot: 1, at: GridPos(row: 0, col: 3)) == false) // latch
        #expect(calls == [1])
        g.onGameOver = nil
        g.restart()
        #expect(g.isGameOver == false)
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 0)) == true)
    }

    // guards: the death moment announces its reason — game over spawns the tier-3 NO ROOM LEFT popup exactly once, and restart() clears it with the rest
    @Test func gameOverSpawnsNoRoomPopup() {
        let g = TikiStacksGame()
        checkerboard(g)
        g.tray = [dot(), square3(), square3()]
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 1)) == true)
        #expect(g.isGameOver == true)
        #expect(g.popups.filter { $0.text == "NO ROOM LEFT" && $0.tier == 3 }.count == 1)
        g.restart()
        #expect(g.popups.isEmpty)
    }

    // guards: an onGameOver hook that calls restart() reentrantly unwinds safely — place returns true into restarted state, callback saw the pre-restart final score
    @Test func reentrantOnGameOverRestart() {
        let g = TikiStacksGame()
        checkerboard(g)
        g.tray = [dot(), square3(), square3()]
        var received: [Int] = []
        g.onGameOver = { [weak g] score in
            received.append(score)
            g?.restart()
        }
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 1)) == true)
        #expect(g.isGameOver == false && g.score == 0 && g.best == 1)
        #expect(received == [1])
        #expect(gridIsEmpty(g))
    }

    // SUSPECTED-BUG(configure-best-midrun): pins the call-once-before-play contract — mid-run configureBest flips isNewBest false with no score change
    // guards: configureBest never lowers best; called mid-run it resets startingBest to the raised best
    @Test func configureBestMidRunContract() {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        g.grid[7][0] = .teal
        fillRow(g, 0, cols: 0..<7)
        g.score = 40
        g.tray = [dot(), nil, nil]
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 7)) == true)
        #expect(g.score == 51 && g.best == 51 && g.isNewBest == true)
        g.configureBest(30)
        #expect(g.best == 51 && g.previousBest == 51 && g.isNewBest == false)
        g.configureBest(-10)
        #expect(g.best == 51)
    }

    // guards: tray refills only when all 3 slots empty (nil-count trace 1,2,0) and refilled pieces are fresh instances
    @Test func trayRefillCadence() {
        let g = TikiStacksGame()
        g.grid = emptyGrid()
        let d0 = dot(), d1 = dot(), d2 = dot()
        g.tray = [d0, d1, d2]
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 0)) == true)
        #expect(g.tray.filter { $0 == nil }.count == 1)
        #expect(g.place(slot: 1, at: GridPos(row: 0, col: 2)) == true)
        #expect(g.tray.filter { $0 == nil }.count == 2)
        #expect(g.place(slot: 2, at: GridPos(row: 0, col: 4)) == true)
        #expect(g.tray.compactMap { $0 }.count == 3)
        let oldIDs: Set<UUID> = [d0.id, d1.id, d2.id]
        #expect(g.tray.compactMap { $0 }.allSatisfy { !oldIDs.contains($0.id) })
    }

    // guards: restart() resets every run-scoped field (grid, score, streak, tray, VFX, fireflies, glow, summary), re-arms the best baseline, and keeps best + clearBeat
    @Test func restartCompleteness() throws {
        let g = TikiStacksGame()
        var board = emptyGrid()
        board[1][1] = .teal
        let d = dot()
        let p = TikiStacksGame.SavePayload(
            seenHowTo: true, score: 30, streak: 1, board: board,
            tray: [d, nil, nil], fireflies: [GridPos(row: 1, col: 1)], glowingTray: [d.id]
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        #expect(!g.fireflyCells.isEmpty && !g.glowingPieceIDs.isEmpty)
        g.isGameOver = true
        g.popups = [ScorePopup(text: "X", row: 0, col: 0, tier: 0)]
        g.clearFlash = [GridPos(row: 0, col: 0)]
        g.lastRunSummary = RunSummary(best: 1, isNewBest: false, pointsEarned: 1, totalPoints: 1)
        g.best = 77
        g.restart()
        #expect(gridIsEmpty(g))
        #expect(g.score == 0 && g.streak == 0 && !g.isGameOver && g.lastClearCount == 0)
        #expect(g.tray.compactMap { $0 }.count == 3)
        #expect(g.clearFlash.isEmpty && g.popups.isEmpty && g.lastRunSummary == nil)
        #expect(g.fireflyCells.isEmpty && g.glowingPieceIDs.isEmpty)
        #expect(g.best == 77 && g.previousBest == 77)
    }

    // guards: each scripted tutorial round clears exactly round+1 lines, empties the grid, pays no sweep bonus, never touches best, never auto-refills
    @Test(arguments: tutorialCases)
    func tutorialRoundGeometry(_ c: (round: Int, score: Int)) {
        let g = TikiStacksGame()
        g.seedTutorialBoard(round: c.round)
        let target = TikiStacksGame.tutorialTarget(round: c.round)
        #expect(g.place(slot: 0, at: GridPos(row: target.row, col: target.col)) == true)
        #expect(g.lastClearCount == c.round + 1)
        #expect(gridIsEmpty(g))
        #expect(g.score == c.score)
        #expect(g.best == 0) // tutorial firewall
        #expect(g.tray.allSatisfy { $0 == nil }) // auto-refill suppressed
        #expect(g.isGameOver == false)
        #expect(!g.popups.contains { $0.text.contains("SWEEP") })
    }

    // guards: tutorial round index clamps at both ends; only a round-0 seed resets isGameOver/popups; targets and refill clamp too
    @Test func tutorialClampingAndFlagScoping() {
        let g = TikiStacksGame()
        g.popups = [ScorePopup(text: "X", row: 0, col: 0, tier: 0)]
        g.isGameOver = true
        g.seedTutorialBoard(round: 99) // clamps to round 3
        #expect(g.popups.count == 1)           // non-zero-round seed keeps popups
        #expect(g.isGameOver == true)          // and the game-over flag
        #expect(g.grid[2][0] != nil && g.grid[5][6] != nil && g.grid[4][7] == nil) // round-3 board
        g.seedTutorialBoard(round: -5) // clamps to round 0
        #expect(g.popups.isEmpty)
        #expect(g.isGameOver == false)
        let tm1 = TikiStacksGame.tutorialTarget(round: -1)
        let t99 = TikiStacksGame.tutorialTarget(round: 99)
        #expect(tm1.row == 4 && tm1.col == 7)
        #expect(t99.row == 2 && t99.col == 7)
        g.refillTutorialTray(for: 99) // clamps to round 3's vertical-4
        #expect(g.tray[0]?.cells.count == 4 && g.tray[1] == nil && g.tray[2] == nil)
    }

    // SUSPECTED-BUG(tutorial-idle-softlock): pins that a non-clearing tutorial placement leaves an empty tray with refill suppressed and game-over unreachable — view discipline is the only guard
    // guards: engine permits placing the scripted piece off-target; the run then idles (no pieces, not over) until the view intervenes
    @Test func tutorialNonClearingPlacementIdles() {
        let g = TikiStacksGame()
        g.seedTutorialBoard(round: 0)
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 0)) == true) // legal, clears nothing
        #expect(g.tray.allSatisfy { $0 == nil })
        #expect(g.isGameOver == false)
        #expect(g.score == 1 && g.streak == 0)
    }

    // SUSPECTED-BUG(end-tutorial-destructive): pins that endTutorialAndRefill unconditionally zeroes score/streak and redeals — destructive if ever called mid-real-run
    // guards: the API's view-discipline-only contract (no tutorialActive precondition)
    @Test func endTutorialAndRefillIsDestructiveOutOfContext() {
        let g = TikiStacksGame()
        g.score = 500
        g.streak = 3
        g.endTutorialAndRefill() // tutorial was never active
        #expect(g.score == 0 && g.streak == 0)
        #expect(g.tray.compactMap { $0 }.count == 3)
    }
}

// MARK: - Persistence

@MainActor
@Suite("TikiStacks persistence")
struct TikiStacksPersistenceTests {

    // guards: nil/empty/non-JSON/wrong-shape payloads return nil and leave fresh state untouched
    @Test(arguments: garbagePayloads)
    func restoreRejectsGarbage(_ json: String?) {
        let g = TikiStacksGame()
        #expect(g.restore(from: json) == nil)
        #expect(g.score == 0 && gridIsEmpty(g))
    }

    // guards: 7x8 / ragged / 9x8 / nil boards decode but apply NOTHING (all-or-nothing validation)
    @Test func restoreRejectsBadBoardDimensions() throws {
        let row8 = Array(repeating: BlockColor?.none, count: 8)
        var ragged = Array(repeating: row8, count: 8)
        ragged[3] = Array(repeating: BlockColor?.none, count: 9)
        let boards: [[[BlockColor?]]?] = [
            Array(repeating: row8, count: 7),
            ragged,
            Array(repeating: row8, count: 9),
            nil,
        ]
        for board in boards {
            let g = TikiStacksGame()
            let ids = g.tray.map { $0?.id }
            let p = TikiStacksGame.SavePayload(
                seenHowTo: false, score: 55, streak: 1, board: board,
                tray: [dot(), nil, nil], fireflies: nil, glowingTray: nil
            )
            #expect(g.restore(from: try encodePayload(p)) != nil) // payload still returned for seenHowTo
            #expect(g.score == 0 && g.tray.map { $0?.id } == ids) // nothing applied
        }
    }

    // guards: tray must be exactly 3 slots with at least one piece; the minimal valid shape applies fully
    @Test func restoreRejectsBadTrayShapesAndAppliesValidOne() throws {
        var marker = emptyGrid()
        marker[0][0] = BlockColor.coral
        let badTrays: [[Piece?]] = [[dot(), nil], [dot(), nil, nil, nil], [nil, nil, nil]]
        for tray in badTrays {
            let g = TikiStacksGame()
            let p = TikiStacksGame.SavePayload(
                seenHowTo: false, score: 55, streak: 0, board: marker,
                tray: tray, fireflies: nil, glowingTray: nil
            )
            #expect(g.restore(from: try encodePayload(p)) != nil)
            #expect(g.score == 0 && g.grid[0][0] == nil)
        }
        let g = TikiStacksGame()
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: 55, streak: 2, board: marker,
            tray: [dot(), nil, nil], fireflies: nil, glowingTray: nil
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        #expect(g.score == 55 && g.streak == 2 && g.grid[0][0] == .coral && g.tray[1] == nil)
    }

    // SUSPECTED-BUG(empty-piece-trap): the `!cells.isEmpty &&` short-circuit is the ONLY thing between this payload and a decode-triggered force-unwrap crash — this test catches any reorder of that &&
    // guards: empty-cells and oversized (10-wide / 10-tall) tray pieces are rejected whole-payload, without trapping
    @Test func restoreRejectsInvalidPieces() throws {
        var marker = emptyGrid()
        marker[0][0] = BlockColor.coral
        let badPieces: [Piece] = [
            Piece(id: UUID(), cells: [], color: .teal),
            Piece(id: UUID(), cells: [GridPos(row: 0, col: 0), GridPos(row: 0, col: 9)], color: .teal),
            Piece(id: UUID(), cells: [GridPos(row: 9, col: 0)], color: .teal),
        ]
        for piece in badPieces {
            let g = TikiStacksGame()
            let p = TikiStacksGame.SavePayload(
                seenHowTo: false, score: 55, streak: 0, board: marker,
                tray: [piece, nil, nil], fireflies: nil, glowingTray: nil
            )
            #expect(g.restore(from: try encodePayload(p)) != nil)
            #expect(g.score == 0 && g.grid[0][0] == nil)
        }
    }

    // SUSPECTED-BUG(dup-cell-score-inflation): pins the validation gap — a crafted duplicate-cell piece scores cells.count == 2 while filling one cell (score conservation break)
    // guards: current restore acceptance + scoring of duplicate-cell pieces from tampered saves
    @Test func restoreAcceptsDuplicateCellPieceScoreInflation() throws {
        let g = TikiStacksGame()
        let dup = Piece(id: UUID(), cells: [GridPos(row: 0, col: 0), GridPos(row: 0, col: 0)], color: .teal)
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: 0, streak: 0, board: emptyGrid(),
            tray: [dup, nil, nil], fireflies: nil, glowingTray: nil
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        #expect(g.tray[0]?.cells.count == 2)
        #expect(g.place(slot: 0, at: GridPos(row: 5, col: 5)) == true)
        let filled = g.grid.flatMap { $0 }.compactMap { $0 }.count
        #expect(g.score == 2 && filled == 1)
    }

    // SUSPECTED-BUG(negative-coord-piece-restore): pins the validation gap — negative cell coordinates pass rows/cols <= 8 and restore as placeable pieces
    // guards: current acceptance + placement geometry of a cells-above-anchor piece from a tampered save
    @Test func restoreAcceptsNegativeCoordPiece() throws {
        let g = TikiStacksGame()
        let neg = Piece(id: UUID(), cells: [GridPos(row: -1, col: 0), GridPos(row: 0, col: 0)], color: .teal)
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: 0, streak: 0, board: emptyGrid(),
            tray: [neg, nil, nil], fireflies: nil, glowingTray: nil
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        let piece = try #require(g.tray[0])
        #expect(g.canPlace(piece, at: GridPos(row: 0, col: 0)) == false) // cell at row -1
        #expect(g.canPlace(piece, at: GridPos(row: 1, col: 0)) == true)  // cells land on rows 0..1
    }

    // guards: negative persisted score/streak clamp to 0 while the rest of the payload applies
    @Test func restoreClampsNegativePersistedNumbers() throws {
        let g = TikiStacksGame()
        var marker = emptyGrid()
        marker[0][0] = BlockColor.coral
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: -100, streak: -5, board: marker,
            tray: [dot(), nil, nil], fireflies: nil, glowingTray: nil
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        #expect(g.score == 0 && g.streak == 0 && g.grid[0][0] == .coral)
    }

    // FIXED-BUG(restore-overflow-clamp): permanent regression test for the 2026-07-17 fix.
    // restore used to have no upper clamp: score/streak restored as Int.max, and the very next place()
    // trapped on `score += piece.cells.count` (a persistent crash loop, since the poisoned save reloads
    // on relaunch). restore now clamps to 99_999_999 / 9_999. Deliberately does NOT call place() — if the
    // clamp regresses, the trap would kill the whole test runner. The behavior asserted here is a
    // score ceiling of 100_000_000 and a streak ceiling of 10_000 — bounds that keep all downstream
    // arithmetic (+cells, +lines*10*streak, streak+1; worst next step ~1.02e8) trap-free.
    // guards: tampered saves with near-Int.max numbers cannot arm an arithmetic-overflow crash loop
    @Test func restoreClampsOverflowNumbers() throws {
        let g = TikiStacksGame()
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: Int.max, streak: Int.max, board: emptyGrid(),
            tray: [dot(), nil, nil], fireflies: nil, glowingTray: nil
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        #expect(g.score <= 100_000_000, "score ceiling must leave headroom for every downstream += (worst clear ~1.6M points)")
        #expect(g.streak <= 10_000, "streak ceiling must keep lines * 10 * streak far from Int.max")
    }

    // guards: an invalid BlockColor raw value anywhere in the payload rejects the WHOLE payload (decode throws, restore returns nil)
    @Test func restoreRejectsInvalidEnumRawValues() {
        let g = TikiStacksGame()
        let boardWithBadColor = #"{"seenHowTo":false,"score":0,"streak":0,"board":[[99]]}"#
        #expect(g.restore(from: boardWithBadColor) == nil)
        let trayWithBadColor = #"{"seenHowTo":false,"score":0,"streak":0,"tray":[{"id":"00000000-0000-0000-0000-000000000000","cells":[{"row":0,"col":0}],"color":-1}]}"#
        #expect(g.restore(from: trayWithBadColor) == nil)
        #expect(g.score == 0 && gridIsEmpty(g))
    }

    // guards: unknown keys (emoji names, hostile string values) are ignored and the valid payload still applies
    @Test func restoreIgnoresUnknownKeysWithHostileStrings() {
        let g = TikiStacksGame()
        var rowsJSON: [String] = []
        for r in 0..<8 {
            var cellsJSON: [String] = []
            for c in 0..<8 {
                let v: String = (r == 0 && c == 0) ? "0" : "null"
                cellsJSON.append(v)
            }
            rowsJSON.append("[" + cellsJSON.joined(separator: ",") + "]")
        }
        let boardJSON = "[" + rowsJSON.joined(separator: ",") + "]"
        let json = #"{"seenHowTo":true,"score":7,"streak":1,"board":"# + boardJSON +
            #","tray":[{"id":"11111111-2222-3333-4444-555555555555","cells":[{"row":0,"col":0}],"color":2},null,null],"🌺junk":"z‮algo","extra":[1,2,3]}"#
        let payload = g.restore(from: json)
        #expect(payload != nil && payload?.seenHowTo == true)
        #expect(g.score == 7 && g.grid[0][0] == .coral && g.tray[0]?.color == .gold)
    }

    // guards: payload/restore round-trips grid, tray (ids, colors, cells), score, streak, fireflies, and glow exactly; seenHowTo survives
    @Test func payloadRestoreRoundTrip() throws {
        let g1 = TikiStacksGame()
        var board = emptyGrid()
        board[1][1] = BlockColor.teal
        board[2][2] = BlockColor.gold
        let pa = Piece(id: UUID(), cells: [GridPos(row: 0, col: 0), GridPos(row: 0, col: 1)], color: .orange)
        let p0 = TikiStacksGame.SavePayload(
            seenHowTo: true, score: 123, streak: 2, board: board,
            tray: [pa, nil, dot()], fireflies: [GridPos(row: 1, col: 1)], glowingTray: [pa.id]
        )
        #expect(g1.restore(from: try encodePayload(p0)) != nil)
        #expect(g1.score == 123 && g1.glowingPieceIDs == [pa.id])
        let snapshot = g1.payload(seenHowTo: true)
        let g2 = TikiStacksGame()
        let decoded = g2.restore(from: snapshot)
        #expect(decoded?.seenHowTo == true)
        #expect(g2.grid == g1.grid)
        #expect(g2.tray == g1.tray)
        #expect(g2.score == 123 && g2.streak == 2)
        #expect(g2.fireflyCells == g1.fireflyCells)
        #expect(g2.glowingPieceIDs == g1.glowingPieceIDs)
    }

    // guards: a game-over payload carries nil board/tray/fireflies/glow (score+streak only) and restoring it applies nothing
    @Test func gameOverPayloadNeverResurrectsBoard() throws {
        let g = TikiStacksGame()
        g.grid[0][0] = .coral
        g.score = 77
        g.streak = 3
        g.isGameOver = true
        let snapshot = g.payload(seenHowTo: false)
        let decoded = try JSONDecoder().decode(TikiStacksGame.SavePayload.self, from: Data(snapshot.utf8))
        #expect(decoded.board == nil && decoded.tray == nil && decoded.fireflies == nil && decoded.glowingTray == nil)
        #expect(decoded.score == 77 && decoded.streak == 3 && decoded.seenHowTo == false)
        let g2 = TikiStacksGame()
        let ids = g2.tray.map { $0?.id }
        #expect(g2.restore(from: snapshot) != nil) // payload returned for seenHowTo
        #expect(g2.score == 0 && gridIsEmpty(g2) && g2.tray.map { $0?.id } == ids)
    }

    // guards: seenDangerTip round-trips through payload/restore, defaults false when the caller omits it, and pre-tip payloads (no key) decode to nil
    @Test func seenDangerTipPayloadRoundTrip() {
        let g = TikiStacksGame()
        #expect(TikiStacksGame().restore(from: g.payload(seenHowTo: true, seenDangerTip: true))?.seenDangerTip == true)
        #expect(TikiStacksGame().restore(from: g.payload(seenHowTo: true))?.seenDangerTip == false)
        let legacy = #"{"seenHowTo":true,"score":0,"streak":0}"#
        #expect(TikiStacksGame().restore(from: legacy)?.seenDangerTip == nil)
    }

    // guards: glow transfers atomically piece -> board cells at placement, and the next payload lists fireflies with an empty glowingTray
    @Test func glowingPieceLifecycle() throws {
        let g = TikiStacksGame()
        let d = dot()
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: 0, streak: 0, board: emptyGrid(),
            tray: [d, nil, nil], fireflies: nil, glowingTray: [d.id]
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        #expect(g.glowingPieceIDs == [d.id])
        #expect(g.place(slot: 0, at: GridPos(row: 2, col: 3)) == true)
        #expect(g.glowingPieceIDs.isEmpty)
        #expect(g.fireflyCells == [GridPos(row: 2, col: 3)])
        let decoded = try JSONDecoder().decode(
            TikiStacksGame.SavePayload.self,
            from: Data(g.payload(seenHowTo: false).utf8)
        )
        #expect(decoded.fireflies == [GridPos(row: 2, col: 3)])
        #expect(decoded.glowingTray == [])
    }

    // SUSPECTED-BUG(zombie-restore): pins that restore never resets isGameOver — a live payload restored onto a dead instance yields a live-looking board where every place() is rejected
    // guards: current zombie behavior (unreachable via the app's fresh-instance-at-launch restore path)
    @Test func zombieRestoreKeepsGameOverLatch() throws {
        let g = TikiStacksGame()
        g.isGameOver = true
        var marker = emptyGrid()
        marker[0][0] = BlockColor.coral
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: 10, streak: 0, board: marker,
            tray: [dot(), nil, nil], fireflies: nil, glowingTray: nil
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        #expect(g.grid[0][0] == .coral && g.score == 10) // board applied...
        #expect(g.isGameOver == true)
        #expect(g.place(slot: 0, at: GridPos(row: 3, col: 3)) == false) // ...but the run is dead
    }

    // SUSPECTED-BUG(softlock-restore): pins that restore never validates placeability — a full-board payload restores into an unwinnable, unlosable run (checkGameOver only runs inside place(), which can never succeed)
    // guards: current soft-lock behavior from tampered saves (engine-generated saves can never be dead: checkGameOver runs before any save could observe one)
    @Test func softLockRestoreUndetected() throws {
        let g = TikiStacksGame()
        let full: [[BlockColor?]] = Array(repeating: Array(repeating: BlockColor.coral, count: 8), count: 8)
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: 500, streak: 0, board: full,
            tray: [dot(), nil, nil], fireflies: nil, glowingTray: nil
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        #expect(g.score == 500)
        let piece = try #require(g.tray[0])
        #expect(g.hasAnyPlacement(piece) == false)
        #expect(g.snappedOrigin(for: piece, idealRow: 3.5, idealCol: 3.5) == nil)
        #expect(g.place(slot: 0, at: GridPos(row: 4, col: 4)) == false)
        #expect(g.isGameOver == false) // never detected: unwinnable AND unlosable
    }

    // SUSPECTED-BUG(restore-bag-fairness): pins that bag state is not persisted — after restore, the visible 25-deal window is provably NOT one full bag (init consumed 3 shapes the player never saw; the saved tray duplicates shapes still in the bag)
    // guards: documents the fairness break deterministically: a 3-dot saved tray + the next 22 deals always contains >=3 dots (library has 1) and misses >=2 shapes
    @Test func restoreBreaksBagFairness() throws {
        let g = TikiStacksGame() // init dealt 3 entries from a fresh 25-bag
        let p = TikiStacksGame.SavePayload(
            seenHowTo: false, score: 0, streak: 0, board: emptyGrid(),
            tray: [dot(), dot(), dot()], fireflies: nil, glowingTray: nil
        )
        #expect(g.restore(from: try encodePayload(p)) != nil)
        let shapes = libraryShapeCells()
        var union: [[GridPos]] = g.tray.compactMap { $0 }.map(\.cells) // the 3 saved dots
        var harvested: [[GridPos]] = []
        while harvested.count < 22 {
            for slot in 0..<3 {
                #expect(g.place(slot: slot, at: GridPos(row: 0, col: 0)) == true)
                g.grid = emptyGrid() // no clears, no overlap, no game over
            }
            harvested.append(contentsOf: g.tray.compactMap { $0 }.map(\.cells))
        }
        union.append(contentsOf: harvested.prefix(22)) // exactly the bag remainder
        let indices = union.compactMap { shapes.firstIndex(of: $0) }
        #expect(indices.filter { $0 == 0 }.count >= 3) // >=3 dots in a "bag" that should hold 1
        #expect(Set(0..<25).subtracting(indices).count >= 2) // >=2 shapes the player never saw
    }
}

// MARK: - VFX timing (serialized to keep sleep margins honest)

@MainActor
@Suite("TikiStacks VFX timing", .serialized)
struct TikiStacksVFXTimingTests {

    // guards: a newer clear's flash survives the older clear's 750ms expiry task (generation guard) and still self-clears on its own schedule
    @Test func clearFlashGenerationGuard() async throws {
        let g = TikiStacksGame()
        g.grid[7][0] = .teal
        fillRow(g, 0, cols: 0..<7)
        g.tray[0] = dot()
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 7)) == true) // clear A at t~0
        #expect(!g.clearFlash.isEmpty)
        try await Task.sleep(nanoseconds: 450_000_000)
        fillRow(g, 3, cols: 0..<7)
        g.tray[0] = dot()
        #expect(g.place(slot: 0, at: GridPos(row: 3, col: 7)) == true) // clear B at t~450
        let bCells = Set((0..<8).map { GridPos(row: 3, col: $0) })
        #expect(Set(g.clearFlash) == bCells)
        try await Task.sleep(nanoseconds: 400_000_000) // t~850: A's expiry (>=750) has run; generation mismatch must no-op
        #expect(Set(g.clearFlash) == bCells)
        try await Task.sleep(nanoseconds: 650_000_000) // t~1500: B's own expiry (>=1200) has run
        #expect(g.clearFlash.isEmpty)
    }

    // guards: restart() racing pending expiry tasks — the pre-restart flash task must not truncate the new run's flash, and stale UUID-keyed popup removals must not touch new popups
    @Test func restartDoesNotLetStaleTasksClobberNewRun() async throws {
        let g = TikiStacksGame()
        g.grid[7][0] = .teal
        fillRow(g, 0, cols: 0..<7)
        g.tray[0] = dot()
        #expect(g.place(slot: 0, at: GridPos(row: 0, col: 7)) == true) // old run: flash + popups at t~0
        try await Task.sleep(nanoseconds: 350_000_000)
        g.restart() // t~350: wipes flash/popups; pending tasks still scheduled
        g.grid[7][0] = .teal
        fillRow(g, 2, cols: 0..<7)
        g.tray[0] = dot()
        #expect(g.place(slot: 0, at: GridPos(row: 2, col: 7)) == true) // new run's clear
        let bCells = Set((0..<8).map { GridPos(row: 2, col: $0) })
        #expect(Set(g.clearFlash) == bCells)
        #expect(!g.popups.isEmpty)
        try await Task.sleep(nanoseconds: 500_000_000) // t~850: old flash task (>=750) has run and must have no-opped
        #expect(Set(g.clearFlash) == bCells)
        #expect(!g.popups.isEmpty)
        try await Task.sleep(nanoseconds: 300_000_000) // t~1150: stale popup removals (>=1000) have fired; new popups (expire >=1350) must survive them
        #expect(!g.popups.isEmpty)
        try await Task.sleep(nanoseconds: 400_000_000) // t~1550: everything legitimately expired
        #expect(g.clearFlash.isEmpty)
        #expect(g.popups.isEmpty)
    }

    // guards: 10 rapid clears accumulate popups without loss (combo tiers capped at min(streak-1, 2)), then ALL drain after the 1s window with no duplicate-removal crash
    @Test func popupFloodDrains() async throws {
        let g = TikiStacksGame()
        g.grid[7][0] = .teal
        for _ in 0..<10 {
            fillRow(g, 0, cols: 0..<7)
            g.tray[0] = dot()
            #expect(g.place(slot: 0, at: GridPos(row: 0, col: 7)) == true)
        }
        #expect(g.popups.count >= 10) // points popups + escalating combos, none lost pre-expiry
        let comboTiers = g.popups.filter { $0.text.hasPrefix("COMBO") }.map(\.tier)
        #expect(comboTiers.count == 9 && comboTiers.max() == 2) // streaks 2-10: tier caps at min(streak-1, 2), never milestone tier 3
        try await Task.sleep(nanoseconds: 1_400_000_000)
        #expect(g.popups.isEmpty)
        #expect(g.clearFlash.isEmpty)
    }
}

// MARK: - Soaks & library audit

@MainActor
@Suite("TikiStacks soaks")
struct TikiStacksSoakTests {

    // guards: shuffled-bag fairness — the first two 25-deal windows of a fresh game are each an exact permutation of the 25 library shapes
    @Test func bagFairnessTwoFullBags() {
        let g = TikiStacksGame()
        let shapes = libraryShapeCells()
        var deals: [[GridPos]] = g.tray.compactMap { $0 }.map(\.cells) // deals 1-3 from init
        while deals.count < 51 {
            for slot in 0..<3 {
                #expect(g.tray[slot] != nil)
                #expect(g.place(slot: slot, at: GridPos(row: 0, col: 0)) == true)
                g.grid = emptyGrid() // wipe: no clears, no overlap, no game over
            }
            deals.append(contentsOf: g.tray.compactMap { $0 }.map(\.cells)) // refill order == deal order
        }
        func sortedIndices(_ window: ArraySlice<[GridPos]>) -> [Int] {
            window.compactMap { shapes.firstIndex(of: $0) }.sorted()
        }
        #expect(sortedIndices(deals[0..<25]) == Array(0..<25))
        #expect(sortedIndices(deals[25..<50]) == Array(0..<25))
    }

    // guards: whole-engine soak — greedy first-fit play never traps, score strictly increases per placement, no full line survives a placement, tray never ends all-nil, and the run ends only via isGameOver
    @Test func greedyBotSoak() {
        let g = TikiStacksGame()
        var moves = 0
        var lastScore = -1
        var violation: String?
        while !g.isGameOver && moves < 1500 && violation == nil {
            var placed = false
            slotLoop: for slot in 0..<3 {
                guard let piece = g.tray[slot] else { continue }
                for r in 0..<8 {
                    for k in 0..<8 where g.canPlace(piece, at: GridPos(row: r, col: k)) {
                        if !g.place(slot: slot, at: GridPos(row: r, col: k)) {
                            violation = "legal place returned false at move \(moves)"
                        }
                        placed = true
                        break slotLoop
                    }
                }
            }
            if !placed {
                // checkGameOver ran after the previous move; a live game must have a move.
                violation = "no placement found but game not over at move \(moves)"
                break
            }
            if g.score <= lastScore { violation = "score not strictly increasing at move \(moves)" }
            lastScore = g.score
            if g.grid.count != 8 || g.grid.contains(where: { $0.count != 8 }) { violation = "grid dims broke at move \(moves)" }
            for r in 0..<8 where (0..<8).allSatisfy({ g.grid[r][$0] != nil }) { violation = "full row survived at move \(moves)" }
            for k in 0..<8 where (0..<8).allSatisfy({ g.grid[$0][k] != nil }) { violation = "full col survived at move \(moves)" }
            if g.tray.allSatisfy({ $0 == nil }) { violation = "tray all-nil after place at move \(moves)" }
            moves += 1
        }
        #expect(violation == nil, "\(violation ?? "")")
    }

    // guards: the rotationless library contract — exactly 25 anchored, distinct shapes with the shipped size histogram, every one placeable on an empty board (trips on any accidental library edit or a rotation revival)
    @Test func pieceLibraryOrientationAudit() {
        let shapes = PieceLibrary.shapes
        #expect(shapes.count == 25)
        let canon = shapes.map { shape in
            shape.map { GridPos(row: $0.0, col: $0.1) }
                .sorted { ($0.row, $0.col) < ($1.row, $1.col) }
                .map { "\($0.row),\($0.col)" }
                .joined(separator: ";")
        }
        #expect(Set(canon).count == 25) // all distinct
        var histogram: [Int: Int] = [:]
        for shape in shapes { histogram[shape.count, default: 0] += 1 }
        // dot; 2x lines(2); lines(3)+4 corners; lines(4)+square+4 big-L+2 T+2 S/Z; lines(5); 2x3+3x2; 3x3.
        #expect(histogram == [1: 1, 2: 2, 3: 6, 4: 11, 5: 2, 6: 2, 9: 1])
        let g = TikiStacksGame()
        for shape in shapes {
            #expect(shape.map(\.0).min() == 0 && shape.map(\.1).min() == 0) // anchored at (0,0) bounding box
            let piece = Piece(id: UUID(), cells: shape.map { GridPos(row: $0.0, col: $0.1) }, color: .coral)
            #expect(g.hasAnyPlacement(piece)) // no shape is unplaceable-by-orientation on an empty board
        }
    }

    #if DEBUG
    // guards: firefly deals per bag are exactly 0 below NIGHTFALL, 1 at stages 2-3, 2 at GLOW TIDE, with stage sampled at bag creation
    @Test(arguments: fireflyBagCases)
    func fireflyDealsPerBagByStage(_ c: (seedScore: Int, glowPerBag: Int)) {
        let g = TikiStacksGame()
        g.score = c.seedScore
        g.debugRedealTray() // fresh bag created at the seeded stage
        var glowDeals = g.tray.compactMap { $0 }.filter { g.glowingPieceIDs.contains($0.id) }.count
        // Deal through the whole 25-piece bag: 3 initial + 7 full refills + the
        // 8th refill's slot 0 (its slots 1-2 come from the NEXT bag — excluded).
        for refill in 1...8 {
            for slot in 0..<3 {
                #expect(g.place(slot: slot, at: GridPos(row: 0, col: 0)) == true)
                g.grid = emptyGrid()
            }
            if refill < 8 {
                glowDeals += g.tray.compactMap { $0 }.filter { g.glowingPieceIDs.contains($0.id) }.count
            } else if let first = g.tray[0], g.glowingPieceIDs.contains(first.id) {
                glowDeals += 1
            }
        }
        #expect(glowDeals == c.glowPerBag)
    }
    #endif
}
