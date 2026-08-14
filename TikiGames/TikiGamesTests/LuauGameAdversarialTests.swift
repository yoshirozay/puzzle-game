import Foundation
import Testing
@testable import Tiki_Lounge

// ADVERSARIAL tests for LuauGame / LuauLevel (pure-logic match-3 engine).
//
// Determinism strategy: endless mode uses the system RNG, so every board these
// tests reason about is first overwritten cell-by-cell with the "null pattern"
// kind = (col + 2*row) % 5 — externally verified to contain NO matches and NO
// legal swaps (7x7, 5 kinds). Both properties survive the 2x2 square rule:
// the pattern has no same-kind adjacent pair anywhere (horizontal neighbors
// differ by 1, vertical by 2, mod 5), and completing a square via one swap
// needs two stationary same-kind adjacent pairs no single swap can supply.
// Kind 5 is unused by the pattern and serves as a guaranteed-unique plant.
// Level mode is SplitMix64-seeded and fully reproducible per
// (level.seed, attempt).
//
// LuauGame is @Observable but NOT actor-isolated and has no internal locking;
// suites are @MainActor so every instance stays confined to one executor.

// MARK: - Shared helpers

/// Null-pattern kind for a cell: no 3-runs anywhere and no swap can create one.
private func patternKind(col: Int, row: Int) -> Int { (col + 2 * row) % 5 }

@MainActor
private func paintPattern(_ game: LuauGame) {
    for row in 0..<7 {
        for col in 0..<7 {
            game.testSetKind(patternKind(col: col, row: row), col: col, row: row)
        }
    }
}

/// Pattern plus a single planted horizontal 3-match at row 0, cols 1-3 (kind 0).
@MainActor
private func plantTriple(_ game: LuauGame) {
    paintPattern(game)
    game.testSetKind(1, col: 0, row: 0)
    game.testSetKind(0, col: 1, row: 0)
    game.testSetKind(0, col: 2, row: 0)
    game.testSetKind(0, col: 3, row: 0)
}

/// Drives resolveStep until settled, bounded. Returns rounds consumed.
@MainActor
@discardableResult
private func settle(_ game: LuauGame, maxRounds: Int = 60) -> Int {
    var rounds = 0
    while rounds < maxRounds, game.resolveStep() { rounds += 1 }
    return rounds
}

@MainActor
private func occupancyUnique(_ game: LuauGame) -> Bool {
    Set(game.pieces.map { $0.row * 7 + $0.col }).count == game.pieces.count
}

/// Position+kind+special signature (ids intentionally excluded — determinism
/// contracts compare boards, not UUIDs).
@MainActor
private func gridSignature(_ game: LuauGame) -> Set<String> {
    Set(game.pieces.map { "\($0.col),\($0.row):\($0.kind):\($0.special.rawValue)" })
}

private func fireCellSet(_ fire: LuauGame.SpecialFire) -> Set<Int> {
    Set(fire.cells.map { $0.row * 7 + $0.col })
}

private func payloadJSON(_ payload: LuauGame.SavePayload) -> String {
    guard let data = try? JSONEncoder().encode(payload) else { return "{}" }
    return String(data: data, encoding: .utf8) ?? "{}"
}

/// 49 pattern pieces — a valid legacy-endless board for restore payloads.
private func patternPieces() -> [LuauGame.Piece] {
    var out: [LuauGame.Piece] = []
    for row in 0..<7 {
        for col in 0..<7 {
            out.append(LuauGame.Piece(
                id: UUID(), kind: patternKind(col: col, row: row),
                special: .none, col: col, row: row
            ))
        }
    }
    return out
}

private func endlessPayload(score: Int, movesLeft: Int, board: [LuauGame.Piece]?) -> LuauGame.SavePayload {
    LuauGame.SavePayload(
        seenHowTo: false, score: score, movesLeft: movesLeft, board: board,
        levelID: nil, jelly: nil, attemptSeed: nil, completedLevels: nil
    )
}

/// Masked level whose (0,0) cell is an isolated 1-cell pocket (column-convex,
/// so it passes the engine's own gravity precondition).
private let isolatedPocketLevel: LuauLevel = {
    let (m, j) = LuauLevel.parse([
        "#.#####",
        ".######",
        ".######",
        ".######",
        ".######",
        ".######",
        ".#####o",
    ])
    return LuauLevel(id: 990_001, mask: m, jelly: j, colors: 4,
                     moves: 10, movesHard: 8, seed: 42, archetype: "Test Pocket")
}()

/// Full-board level whose jelly totals zero — invalid LevelForge output.
private let zeroJellyLevel = LuauLevel(
    id: 990_002, mask: ((1 as UInt64) << 49) - 1,
    jelly: Array(repeating: 0, count: LuauLevel.cellCount),
    colors: 4, moves: 10, movesHard: 8, seed: 7, archetype: "Zero Jelly"
)

// MARK: - Swap legality

@MainActor
struct LuauSwapLegalityTests {

    // Rejection no-op coverage (illegal pairs, no-match reverts, post-game-over)
    // lives in LuauLevelsAdversarialTests.rejectedSwapsMutateNothing.

    // guards: corner-adjacent pairs follow normal match rules (no perimeter special-casing)
    @Test func cornerAdjacentSwapFollowsNormalRules() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        // Kind 5 is outside the pattern: swap (6,6) into (6,5) completes
        // a vertical 3 at col 6 rows 3-5 (verified externally).
        game.testSetKind(5, col: 6, row: 3)
        game.testSetKind(5, col: 6, row: 4)
        game.testSetKind(5, col: 6, row: 6)
        #expect(game.attemptSwap((6, 6), (6, 5)))
        #expect(game.movesLeft == LuauGame.movesPerRun - 1)
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 3)
        #expect(game.lastGain == 30)
    }

    // guards: movesLeft can never go negative — a swap issued after the last move must be rejected
    // SUSPECTED-BUG(swap-accepts-move-debt): expected to FAIL until product fix —
    // attemptSwap never checks movesLeft, so a second swap before resolveStep
    // drives movesLeft to -1 (spendMove is a bare -= 1, LuauGame.swift:451).
    @Test func attemptSwapNeverDrivesMovesNegative() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        // Two independent pre-verified match swaps (A and B).
        game.testSetKind(2, col: 0, row: 0)
        game.testSetKind(0, col: 1, row: 0)
        game.testSetKind(1, col: 2, row: 0)
        game.testSetKind(0, col: 3, row: 0)
        game.testSetKind(0, col: 2, row: 1)
        game.testSetKind(2, col: 3, row: 6)
        game.testSetKind(2, col: 4, row: 5)
        game.testSetMovesLeft(1)
        #expect(game.attemptSwap((2, 0), (2, 1)))  // spends the last move
        #expect(game.movesLeft == 0)
        let second = game.attemptSwap((4, 5), (4, 6))  // issued before any resolveStep
        #expect(!second)
        #expect(game.movesLeft >= 0)
    }
}

// MARK: - Spawns, cascades, specials

struct SpawnCase: Sendable {
    let name: String
    let overrides: [[Int]]  // [kind, col, row]
    let special: LuauGame.Special
    let kind: Int
    let col: Int
    let row: Int
    let clearCount: Int
}

/// Spawn positions account for the post-clear gravity pass (externally
/// verified against the pattern board).
let spawnCases: [SpawnCase] = [
    SpawnCase(name: "H4 -> lineV torch at cells[1]",
              overrides: [[0, 1, 3], [0, 2, 3], [0, 3, 3], [0, 4, 3]],
              special: .lineV, kind: 0, col: 2, row: 3, clearCount: 4),
    SpawnCase(name: "V4 -> lineH torch at cells[1] (falls to row 4)",
              overrides: [[2, 3, 1], [2, 3, 2], [2, 3, 3], [2, 3, 4]],
              special: .lineH, kind: 2, col: 3, row: 4, clearCount: 4),
    SpawnCase(name: "H5 -> cat at cells[2]",
              overrides: [[0, 1, 3], [0, 2, 3], [0, 3, 3], [0, 4, 3], [0, 5, 3]],
              special: .cat, kind: -1, col: 3, row: 3, clearCount: 5),
    SpawnCase(name: "H7 full row -> exactly one cat at cells[2]",
              overrides: [[0, 0, 3], [0, 1, 3], [0, 2, 3], [0, 3, 3], [0, 4, 3], [0, 5, 3], [0, 6, 3]],
              special: .cat, kind: -1, col: 2, row: 3, clearCount: 7),
]

@MainActor
struct LuauSpawnAndCascadeTests {

    // guards: a special lands on the cell the player SWAPPED INTO, not at a
    // fixed index along the run. Placement is the player's decision — it is what
    // makes aiming a torch possible — and it previously surfaced at
    // match.cells[1], somewhere unrelated to the move, which read as random.
    // Note the spawnCases above drive resolveStep() directly with no swap, so
    // they only ever covered the cascade fallback; nothing covered this.
    @Test func specialSpawnsWhereThePlayerSwapped() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        // Null pattern is (col + 2*row) % 5, so row 3 col 4 is already kind 0.
        // Plant kind 0 at row 3 cols 1, 2 and 4, leave col 3 unmatched, and put
        // the fourth piece directly BELOW at (3,4) so one swap completes the run.
        game.testSetKind(0, col: 1, row: 3)
        game.testSetKind(0, col: 2, row: 3)
        game.testSetKind(0, col: 3, row: 4)
        #expect(game.attemptSwap((col: 3, row: 4), (col: 3, row: 3)))
        #expect(game.resolveStep())
        // Exactly four cells: proves the planted run was the ONLY match, so the
        // spawn position below is unambiguous.
        #expect(game.lastClearCount == 4)

        // The run is cols 1...4 of row 3, so the old fixed index cells[1] was
        // (2,3). It must now be the swapped-into cell instead.
        let placed = game.piece(at: 3, 3)
        #expect(placed?.special == .lineV, "torch should sit on the swapped cell (3,3)")
        #expect(game.piece(at: 2, 3)?.special == LuauGame.Special.none,
                "nothing should spawn at the old cells[1] position (2,3)")
    }

    // guards: exact match lengths spawn the right special (kind, special, post-gravity cell), exact gain, and piece-count conservation
    @Test("match-length spawn boundaries", arguments: spawnCases)
    func matchLengthSpawns(spawnCase: SpawnCase) {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        for o in spawnCase.overrides { game.testSetKind(o[0], col: o[1], row: o[2]) }
        #expect(game.resolveStep())
        #expect(game.lastClearCount == spawnCase.clearCount)
        #expect(game.lastGain == spawnCase.clearCount * 10)  // cascade 1
        let spawned = game.piece(at: spawnCase.col, spawnCase.row)
        #expect(spawned?.special == spawnCase.special, "\(spawnCase.name)")
        #expect(spawned?.kind == spawnCase.kind, "\(spawnCase.name)")
        // A 5/6/7-run spawns exactly ONE special, never two.
        if spawnCase.clearCount >= 5 {
            #expect(game.pieces.filter { $0.special != .none }.count == 1)
        }
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
        #expect(settle(game) < 60)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: intersecting H4+V4 sharing one cell dedupe the shared clear (7
    // pieces) and mint ONE bomb — the corner rule outranks the two torches
    // this shape paid before 2026-07-31, and the board stays consistent
    // through the overlapping-clear + spawn + gravity sequence
    @Test func tShapedCornerMintsOneBombAndKeepsBoardConsistent() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        // H4 cols 2-5 row 3 and V4 rows 2-5 col 3, sharing (3,3).
        for c in 2...5 { game.testSetKind(0, col: c, row: 3) }
        for r in 2...5 { game.testSetKind(0, col: 3, row: r) }
        game.testSetKind(3, col: 3, row: 1)
        game.testSetKind(3, col: 3, row: 6)
        // Pattern cell (2,4) is kind 0 and would complete a 2x2 with the
        // T's armpit (2,3)/(3,3)/(3,4) — a real match under the square
        // rule, but this test pins H4+V4 corner geometry (squares have
        // their own suite). Neutralize the collision.
        game.testSetKind(2, col: 2, row: 4)
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 7)  // shared (3,3) counted once
        #expect(game.lastGain == 70)
        let specials = game.pieces.filter { $0.special != .none }
        #expect(specials.count == 1)
        #expect(specials.first?.special == .bomb)
        #expect(specials.first?.kind == 0)
        // Spawned at the corner (3,3); col 3 lost rows 2-5, so it packs down.
        #expect(game.piece(at: 3, 5)?.special == .bomb)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
        #expect(settle(game) < 60)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: cascade round N scores cleared*10*N; lastCascade tracks the round; cascadeBeat only fires at cascade >= 3
    @Test func cascadeMultiplierExactArithmetic() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        // Round 1: V3 col 2 rows 2-4 (kind 0). The kind-1 piece at (2,1) falls
        // to (2,4) and completes H3 row 4 cols 1-3 for round 2 (verified).
        game.testSetKind(0, col: 2, row: 2)
        game.testSetKind(0, col: 2, row: 3)
        game.testSetKind(0, col: 2, row: 4)
        game.testSetKind(1, col: 2, row: 1)
        game.testSetKind(1, col: 1, row: 4)
        #expect(game.resolveStep())
        #expect(game.lastCascade == 1)
        #expect(game.lastClearCount == 3)
        #expect(game.lastGain == 30)
        #expect(game.resolveStep())  // the engineered collapse cascade
        #expect(game.lastCascade == 2)
        #expect(game.lastClearCount >= 3)  // random refill may enlarge the round
        #expect(game.lastGain == game.lastClearCount * 10 * 2)
        #expect(game.cascadeBeat == 0)  // rounds 1 and 2 never bump the beat
        // Round 3 (engineered): no swap has reset the chain, so this round
        // registers at cascade 3 — the beat must fire, and clearBeat must
        // have pulsed exactly once per resolve round.
        plantTriple(game)
        #expect(game.resolveStep())
        #expect(game.lastCascade == 3)
        #expect(game.lastGain == 90)  // 3 * 10 * 3
        #expect(game.cascadeBeat == 1)
        #expect(game.clearBeat == 3)
    }

    // guards: a torch inside a match clears its whole lane exactly once, and a
    // SECOND torch caught in that lane now CHAINS — it fires its own line rather
    // than dying silently. This reverses a deliberate earlier decision at
    // Carson's request: he set off a vertical torch that swallowed a horizontal
    // one, the horizontal never fired, and it read as a bug. Genre convention
    // agrees with him; Candy Crush chains stripes.
    //
    // The CAT is the deliberate exception and still dies as plain collateral: it
    // only ever fires by being SWAPPED, which is where its victim colour comes
    // from, so there is no defined kind for it to wipe when something else
    // destroys it.
    @Test func triggeredTorchChainsIntoLaneTorchButNotTheCat() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        // H3 cols 1-3 row 3 with a lineH torch at (2,3); a cat at (5,3) and a
        // lineV torch at (6,3) sit in the lane but outside the match.
        game.testSetKind(0, col: 1, row: 3)
        game.testSetPiece(kind: 0, special: .lineH, col: 2, row: 3)
        game.testSetKind(0, col: 3, row: 3)
        game.testSetKind(1, col: 4, row: 3)
        game.testSetPiece(kind: -1, special: .cat, col: 5, row: 3)
        game.testSetPiece(kind: 2, special: .lineV, col: 6, row: 3)
        #expect(game.resolveStep())
        // Two shows: the matched horizontal torch, and the vertical one its lane
        // swept up.
        #expect(game.lastFires.count == 2)
        #expect(game.lastFires.contains { $0.kind == .torchH && $0.originCol == 2 && $0.originRow == 3 })
        #expect(game.lastFires.contains { $0.kind == .torchV && $0.originCol == 6 && $0.originRow == 3 })
        #expect(game.fireBeat == 1)
        // Row 3 is 7 cells; the chained vertical takes all 7 of column 6; they
        // share exactly one cell at (6,3).
        #expect(game.lastClearCount == 13)
        #expect(game.lastGain == 130)
        // The cat died as collateral without wiping its colour.
        #expect(game.pieces.allSatisfy { $0.special == .none })
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: cat+plain always succeeds (even a unique partner kind): 2 removed, gain *20, one move, catSwap fire, and the NEXT round scores at cascade 2
    @Test func catSwapWithUniquePartnerKind() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
        game.testSetKind(5, col: 4, row: 3)  // kind 5: unique on the pattern board
        #expect(game.attemptSwap((3, 3), (4, 3)))
        #expect(game.score == 40)  // 2 cleared * 20
        #expect(game.lastGain == 40)
        #expect(game.lastClearCount == 2)
        #expect(game.movesLeft == LuauGame.movesPerRun - 1)
        #expect(game.fireBeat == 1)
        #expect(game.lastFires.first?.kind == .catSwap)
        #expect(game.lastFires.first?.targetKind == 5)
        #expect(game.lastFires.first?.originCol == 3)
        #expect(game.lastFires.first?.originRow == 3)
        #expect(game.pieces.count == 49)  // refilled inside the swap
        #expect(occupancyUnique(game))
        // Cat swaps pre-set cascade = 2 for their follow-up rounds.
        plantTriple(game)
        #expect(game.resolveStep())
        #expect(game.lastCascade == 2)
        #expect(game.lastGain == 60)  // 3 * 10 * 2
    }

    // guards: isLegalPairing separates whiffs from rejections — the view's feedback branch reads it, so a drift here buzzes MISTAKE at legal gestures
    @Test func legalPairingSeparatesWhiffsFromRejections() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        // Null pattern: every adjacent pair is a legal pairing that whiffs.
        #expect(game.isLegalPairing((3, 3), (4, 3)))
        #expect(game.attemptSwap((3, 3), (4, 3)) == false)  // the whiff itself
        #expect(game.isLegalPairing((3, 3), (4, 3)), "a whiff must not poison later reads")
        // Rejections: gap, diagonal, off-board, same cell.
        #expect(game.isLegalPairing((3, 3), (5, 3)) == false)
        #expect(game.isLegalPairing((3, 3), (4, 4)) == false)
        #expect(game.isLegalPairing((0, 0), (-1, 0)) == false)
        #expect(game.isLegalPairing((3, 3), (3, 3)) == false)
        // A dead run rejects everything — mirroring attemptSwap's entry guard.
        game.testSetMovesLeft(0)
        #expect(game.isLegalPairing((3, 3), (4, 3)) == false)
    }

    // guards: a torch standing on the wiped colour DETONATES instead of dying quietly — the cat's sweep chains like any other blast, and previewSwapFires shows the same two fires
    @Test func catSwapDetonatesTorchOnTheWipedColour() throws {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
        game.testSetKind(5, col: 4, row: 3)                             // swap partner
        game.testSetPiece(kind: 5, special: .lineH, col: 1, row: 6)     // same colour, across the board

        // The preview the FX layer renders must already show both fires.
        let preview = game.previewSwapFires((3, 3), (4, 3))
        #expect(preview.count == 2)
        #expect(preview.first?.kind == .catSwap)
        #expect(preview.last?.kind == .torchH)

        #expect(game.attemptSwap((3, 3), (4, 3)))
        // cat + partner + torch (3), then the torch burns row 6 (7) minus itself.
        #expect(game.lastClearCount == 9)
        #expect(game.lastGain == 180)  // 9 * 20
        #expect(game.score == 180)

        let fires = game.lastFires
        #expect(fires.count == 2)
        #expect(fires.first?.kind == .catSwap)
        #expect(fires.first?.targetKind == 5)
        #expect(fireCellSet(try #require(fires.first)).count == 3)  // colour sweep only
        let burn = try #require(fires.last)
        #expect(burn.kind == .torchH)
        #expect(burn.originRow == 6)
        #expect(fireCellSet(burn) == Set((0..<7).map { 6 * 7 + $0 }))

        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: torch+torch cross anchors on the SECOND argument's piece — the two swap orders clear different cell sets (documented direction-dependence)
    @Test func torchCrossOrderAsymmetry() throws {
        func stage() -> LuauGame {
            let game = LuauGame()
            game.newGame()
            paintPattern(game)
            game.testSetPiece(kind: 4, special: .lineH, col: 3, row: 3)
            game.testSetPiece(kind: 0, special: .lineV, col: 4, row: 3)
            return game
        }
        let ab = stage()
        #expect(ab.attemptSwap((3, 3), (4, 3)))
        #expect(ab.lastCombo == .torchCross)
        #expect(ab.lastFires.first?.originCol == 4)  // anchored at b = (4,3)
        #expect(ab.lastClearCount == 13)  // row 3 (7) + col 4 (7) - overlap
        #expect(ab.lastGain == 13 * 15)
        let abCells = fireCellSet(try #require(ab.lastFires.first))

        let ba = stage()
        #expect(ba.attemptSwap((4, 3), (3, 3)))
        #expect(ba.lastFires.first?.originCol == 3)  // anchored at b = (3,3)
        #expect(ba.lastClearCount == 13)
        let baCells = fireCellSet(try #require(ba.lastFires.first))

        #expect(abCells.contains(0 * 7 + 4))   // (4,0): col 4 cleared in a->b
        #expect(!abCells.contains(0 * 7 + 3))  // (3,0): col 3 spared in a->b
        #expect(baCells.contains(0 * 7 + 3))
        #expect(!baCells.contains(0 * 7 + 4))
        #expect(abCells != baCells)
    }

    // guards: a BYSTANDER torch swept up by a storm fires its own lane, while the storm's two participants do not fire twice
    @Test func torchStormDetonatesABystanderTorchButNotItsOwnHalves() throws {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
        game.testSetPiece(kind: 5, special: .lineV, col: 4, row: 3)   // the storm's torch
        game.testSetPiece(kind: 5, special: .lineH, col: 1, row: 6)   // bystander, same colour
        #expect(game.attemptSwap((3, 3), (4, 3)))
        #expect(game.lastCombo == .torchStorm)

        // Storm alone: row 3 (7) + col 4 (7, sharing (4,3)) + the bystander = 14.
        // The bystander then burns row 6, of which (1,6) and (4,6) were already
        // taken — 5 new cells, so 19. Before the chain existed this was 14.
        #expect(game.lastClearCount == 19)
        #expect(game.lastGain == 19 * 25)
        let fires = game.lastFires
        #expect(fires.count == 2, "the bystander must draw its own lane")
        #expect(fires.first?.kind == .torchStorm)
        #expect(fireCellSet(try #require(fires.first)).count == 14,
                "the storm's own show must not absorb the chained cells")
        let burn = try #require(fires.last)
        #expect(burn.kind == .torchH)
        #expect(burn.originRow == 6)
        #expect(fireCellSet(burn) == Set((0..<7).map { 6 * 7 + $0 }))
        #expect(game.previewSwapFires((3, 3), (4, 3)).isEmpty,
                "the swap already resolved; nothing left to preview")
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: cat+torch storm clears the torch's kind plus its full cross at gain *25, origin at the torch, targetKind = torch kind
    @Test func torchStormClearsKindPlusCross() throws {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
        game.testSetPiece(kind: 2, special: .lineV, col: 4, row: 3)
        #expect(game.attemptSwap((3, 3), (4, 3)))
        #expect(game.lastCombo == .torchStorm)
        #expect(game.comboBeat == 1)
        #expect(game.movesLeft == LuauGame.movesPerRun - 1)
        let fire = try #require(game.lastFires.first)
        #expect(fire.kind == .torchStorm)
        #expect(fire.originCol == 4)
        #expect(fire.originRow == 3)
        #expect(fire.targetKind == 2)
        #expect(game.lastGain == game.lastClearCount * 25)
        #expect(fire.cells.count == game.lastClearCount)
        let cells = fireCellSet(fire)
        #expect(cells.contains(1 * 7 + 5))   // (5,1): kind-2 far from the cross
        #expect(cells.contains(3 * 7 + 0))   // (0,3): row of the cross
        #expect(cells.contains(6 * 7 + 4))   // (4,6): column of the cross
        #expect(!cells.contains(0))          // (0,0): kind 0, untouched
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: cat+cat cataclysm clears all 49 at *20, decrements jelly everywhere, and the settle wins the level (jelly hit zero)
    @Test func cataclysmClearsBoardAndWinsLevel() throws {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        let jellyBefore = game.jellyRemaining
        #expect(jellyBefore == LuauLevels.debugL1.jellyTotal)
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
        game.testSetPiece(kind: -1, special: .cat, col: 4, row: 3)
        #expect(game.attemptSwap((3, 3), (4, 3)))
        #expect(game.lastCombo == .cataclysm)
        #expect(game.score == 49 * 20)
        let fire = try #require(game.lastFires.first)
        #expect(fire.kind == .cataclysm)
        #expect(fire.cells.count == 49)
        #expect(game.jellyRemaining == 0)  // every cell's jelly decremented
        #expect(game.movesLeft == LuauLevels.debugL1.moves - 1)
        #expect(game.pieces.count == 49)
        #expect(settle(game) < 60)
        #expect(game.isOver)
        #expect(game.didWinLevel)
        #expect(game.completedLevels.contains(LuauLevels.debugL1.id))
    }
}

// MARK: - Preview purity and parity

@MainActor
struct LuauPreviewTests {

    // guards: previewSwapFires mutates nothing and exactly mirrors attemptSwap's fires for cat+plain, cross, storm, and cataclysm
    @Test func previewSwapFiresIsPureAndMatchesActual() throws {
        enum Combo: CaseIterable { case catPlain, cross, storm, cataclysm }
        for combo in Combo.allCases {
            let game = LuauGame()
            game.newGame()
            paintPattern(game)
            switch combo {
            case .catPlain:
                game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
                game.testSetKind(5, col: 4, row: 3)
            case .cross:
                game.testSetPiece(kind: 4, special: .lineH, col: 3, row: 3)
                game.testSetPiece(kind: 0, special: .lineV, col: 4, row: 3)
            case .storm:
                game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
                game.testSetPiece(kind: 2, special: .lineV, col: 4, row: 3)
            case .cataclysm:
                game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
                game.testSetPiece(kind: -1, special: .cat, col: 4, row: 3)
            }
            let piecesBefore = game.pieces
            let scoreBefore = game.score
            let fireBeatBefore = game.fireBeat
            let preview = game.previewSwapFires((3, 3), (4, 3))
            #expect(game.pieces == piecesBefore, "preview mutated pieces (\(combo))")
            #expect(game.score == scoreBefore, "preview mutated score (\(combo))")
            #expect(game.fireBeat == fireBeatBefore, "preview bumped fireBeat (\(combo))")
            let previewFire = try #require(preview.first, "no preview fire (\(combo))")
            #expect(game.attemptSwap((3, 3), (4, 3)))
            let actual = try #require(game.lastFires.first, "no actual fire (\(combo))")
            #expect(previewFire.kind == actual.kind, "\(combo)")
            #expect(previewFire.originCol == actual.originCol, "\(combo)")
            #expect(previewFire.originRow == actual.originRow, "\(combo)")
            #expect(previewFire.targetKind == actual.targetKind, "\(combo)")
            #expect(Set(previewFire.cells.map(\.id)) == Set(actual.cells.map(\.id)), "\(combo)")
        }
    }

    // guards: previewStepFires mutates nothing and mirrors the next resolveStep's torch fires cell-for-cell
    @Test func previewStepFiresIsPureAndMatchesResolve() throws {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetKind(0, col: 1, row: 3)
        game.testSetPiece(kind: 0, special: .lineH, col: 2, row: 3)
        game.testSetKind(0, col: 3, row: 3)
        game.testSetKind(1, col: 4, row: 3)
        let piecesBefore = game.pieces
        let clearBeatBefore = game.clearBeat
        let preview = game.previewStepFires()
        #expect(game.pieces == piecesBefore)
        #expect(game.clearBeat == clearBeatBefore)
        let previewFire = try #require(preview.first)
        #expect(preview.count == 1)
        #expect(previewFire.kind == .torchH)
        #expect(game.resolveStep())
        let actual = try #require(game.lastFires.first)
        #expect(game.lastFires.count == 1)
        #expect(previewFire.kind == actual.kind)
        #expect(previewFire.originCol == actual.originCol)
        #expect(previewFire.originRow == actual.originRow)
        #expect(Set(previewFire.cells.map(\.id)) == Set(actual.cells.map(\.id)))
    }
}

// MARK: - ENCORE

@MainActor
struct LuauEncoreTests {

    // guards: ENCORE fires exactly once per endless run, +2 moves, at the score-700 crossing — and never re-fires on a later crossing
    @Test func encoreFiresExactlyOnceAtThreshold() {
        let game = LuauGame()
        game.newGame()
        game.testSetScore(699)
        plantTriple(game)
        #expect(game.resolveStep())  // gain 30 -> 729 crosses INFERNO
        #expect(game.score == 729)
        #expect(game.movesLeft == LuauGame.movesPerRun + LuauGame.encoreMoves)
        #expect(game.encoreBeat == 1)
        // Second crossing in the same run: nothing.
        game.testSetScore(699)
        plantTriple(game)
        #expect(game.resolveStep())
        #expect(game.movesLeft == LuauGame.movesPerRun + LuauGame.encoreMoves)
        #expect(game.encoreBeat == 1)
    }

    // guards: debugSeedScore(700) pre-arms encoreFired so a staged INFERNO board never pays a retroactive ENCORE
    @Test func debugSeedScorePreArmsEncore() {
        let game = LuauGame()
        game.debugSeedScore(700)
        plantTriple(game)
        #expect(game.resolveStep())
        #expect(game.movesLeft == LuauGame.movesPerRun)
        #expect(game.encoreBeat == 0)
    }

    // guards: level mode never pays ENCORE (would invalidate the solver's move budget)
    @Test func encoreNeverFiresInLevelMode() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.testSetScore(699)
        plantTriple(game)
        #expect(game.resolveStep())
        #expect(game.score == 729)
        #expect(game.movesLeft == LuauLevels.debugL1.moves)  // no swap, no bonus
        #expect(game.encoreBeat == 0)
    }

    // guards: tutorialActive suppresses ENCORE even when a scripted clear crosses the threshold
    @Test func encoreNeverFiresDuringTutorial() {
        let game = LuauGame()
        game.newGame()
        game.seedTutorialBoard(round: 0)
        game.testSetScore(699)
        #expect(game.attemptSwap((3, 3), (3, 4)))
        #expect(game.resolveStep())
        #expect(game.score == 729)  // 699 + 30 (round 0's single 3-match), crossed the threshold
        #expect(game.movesLeft == LuauGame.movesPerRun - 1)  // swap only, no +2
        #expect(game.encoreBeat == 0)
    }

    // The restore-side encore latch (699 armed / 700 spent, exact boundary) is
    // pinned by LuauLevelsAdversarialTests.caseBEncoreLatchBoundary.
}

// MARK: - Level mode

@MainActor
struct LuauLevelModeTests {

    // Fresh LEVEL fill invariants (all 204 shipped levels, superset of the old
    // debug-fixture sweep) live in LuauLevelsAdversarialTests.everyShippedLevelBuildsALegalBoard.

    // guards: fresh endless boards are matchless, swap-viable, 49 unique cells, six-kind palette, zero jelly
    @Test func freshEndlessBoardInvariants() {
        let game = LuauGame()
        game.newGame()
        #expect(!game.isLevelMode)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
        #expect(game.pieces.allSatisfy { (0..<LuauGame.kinds).contains($0.kind) && $0.special == .none })
        #expect(game.jellyRemaining == 0)
        #expect(game.movesLeft == LuauGame.movesPerRun)
        #expect(game.hasLegalSwap)
        #expect(!game.resolveStep())
    }

    // guards: identical (level, attempt) + identical swaps reproduce the whole run; a different attempt salt diverges from move zero
    @Test func levelRunsAreDeterministicPerAttempt() throws {
        let level = LuauLevels.debugWell
        let g1 = LuauGame()
        let g2 = LuauGame()
        g1.newLevel(level, attempt: 1)
        g2.newLevel(level, attempt: 1)
        let initial = gridSignature(g1)
        #expect(gridSignature(g2) == initial)
        for _ in 0..<3 {
            if g1.isOver { break }
            let swap = try #require(g1.findLegalSwap())
            #expect(g1.attemptSwap(swap.0, swap.1))
            #expect(g2.attemptSwap(swap.0, swap.1))
            #expect(settle(g1) < 60)
            #expect(settle(g2) < 60)
            #expect(gridSignature(g1) == gridSignature(g2))
            #expect(g1.score == g2.score)
            #expect(g1.jelly == g2.jelly)
            #expect(g1.movesLeft == g2.movesLeft)
            #expect(g1.isOver == g2.isOver)
        }
        let g3 = LuauGame()
        g3.newLevel(level, attempt: 2)
        #expect(gridSignature(g3) != initial)  // different salt, different stream
    }

    // guards: retryLevel bumps the attempt salt (wrapping, never trapping), keeps mask/jelly layout, reshuffles kinds; no-op without a level
    @Test func retryLevelSemanticsAndWrap() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 5)
        let sig5 = gridSignature(game)
        game.retryLevel()
        #expect(game.attemptSeed == 6)
        #expect(game.jelly == LuauLevels.debugL1.jelly)
        #expect(game.pieces.count == LuauLevels.debugL1.playableCount)
        #expect(gridSignature(game) != sig5)

        let idle = LuauGame()
        idle.newGame()
        let before = idle.pieces
        idle.retryLevel()  // guarded no-op
        #expect(idle.pieces == before)
        #expect(idle.currentLevel == nil)
        #expect(idle.attemptSeed == 0)

        let wrap = LuauGame()
        wrap.newLevel(LuauLevels.debugL1, attempt: UInt64.max)
        wrap.retryLevel()  // &+ 1 wraps to 0 without trapping
        #expect(wrap.attemptSeed == 0)
    }

    // guards: clearing the last jelly WITH the last move is a WIN — jelly==0 checked before movesLeft<=0
    @Test func winOnFinalMoveBeatsOutOfMoves() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        paintPattern(game)
        // Swap (2,0)<->(2,1) completes row 0 cols 1-3, clearing (2,0)'s jelly.
        game.testSetKind(2, col: 0, row: 0)
        game.testSetKind(0, col: 1, row: 0)
        game.testSetKind(1, col: 2, row: 0)
        game.testSetKind(0, col: 3, row: 0)
        game.testSetKind(0, col: 2, row: 1)
        var jelly = [UInt8](repeating: 0, count: 49)
        jelly[2] = 1  // (2,0) only
        game.testSetJelly(jelly)
        game.testSetMovesLeft(1)
        #expect(game.attemptSwap((2, 0), (2, 1)))
        #expect(game.movesLeft == 0)
        #expect(settle(game) < 60)
        #expect(game.jellyRemaining == 0)
        #expect(game.isOver)
        #expect(game.didWinLevel)
        #expect(game.completedLevels.contains(LuauLevels.debugL1.id))
    }

    // guards: unreachable jelly on the last move is a LOSS — no completion recorded
    @Test func loseWhenJellyRemainsOnLastMove() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        paintPattern(game)
        game.testSetKind(2, col: 0, row: 0)
        game.testSetKind(0, col: 1, row: 0)
        game.testSetKind(1, col: 2, row: 0)
        game.testSetKind(0, col: 3, row: 0)
        game.testSetKind(0, col: 2, row: 1)
        var jelly = [UInt8](repeating: 0, count: 49)
        jelly[48] = 200  // (6,6): 200 layers — no cascade can zero it
        game.testSetJelly(jelly)
        game.testSetMovesLeft(1)
        #expect(game.attemptSwap((2, 0), (2, 1)))
        #expect(settle(game) < 60)
        #expect(game.jellyRemaining > 0)
        #expect(game.isOver)
        #expect(!game.didWinLevel)
        #expect(game.completedLevels.isEmpty)
    }

    /// Seeded near-win: one sand layer at (2,0), winning swap (2,0)<->(2,1).
    /// Same (seed, attempt, board, swap) each call — the resolution stream is
    /// identical regardless of movesLeft, so two runs differing only in the
    /// move budget isolate the spare-move payout exactly.
    private func nearWin(movesLeft: Int) -> LuauGame {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        paintPattern(game)
        game.testSetKind(2, col: 0, row: 0)
        game.testSetKind(0, col: 1, row: 0)
        game.testSetKind(1, col: 2, row: 0)
        game.testSetKind(0, col: 3, row: 0)
        game.testSetKind(0, col: 2, row: 1)
        var jelly = [UInt8](repeating: 0, count: 49)
        jelly[2] = 1  // (2,0) only
        game.testSetJelly(jelly)
        game.testSetMovesLeft(movesLeft)
        #expect(game.attemptSwap((2, 0), (2, 1)))
        #expect(settle(game) < 60)
        #expect(game.isOver)
        #expect(game.didWinLevel)
        return game
    }

    // guards: DOMINANCE — winning with spare moves pays exactly movesLeft × spareMoveBonus,
    // and that payout is the ONLY score delta vs the same seeded run won on its final move.
    // Kills the pre-payout exploit (milk the whole budget for score, clear the last sand on
    // the last move): each banked move pays 100, above a typical milked move's take.
    @Test func spareMovesPayExactBonusOnWin() {
        let lastMove = nearWin(movesLeft: 1)  // wins with 0 left
        let early = nearWin(movesLeft: 6)     // same stream, wins with 5 left
        #expect(lastMove.lastSpareBonus == 0)
        #expect(early.lastSpareBonus == 5 * LuauGame.spareMoveBonus)
        #expect(early.movesLeft == 5)  // panel copy reads it post-win
        #expect(early.score == lastMove.score + 5 * LuauGame.spareMoveBonus)
        #expect(early.best == early.score)  // best re-synced after the payout
        // A settled win is read-only — a stray resolveStep must not pay twice.
        let paid = early.score
        #expect(!early.resolveStep())
        #expect(early.score == paid)
    }

    // guards: a LOSS pays nothing — lastSpareBonus stays 0 through an out-of-moves end
    @Test func lossKeepsSpareBonusZero() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        paintPattern(game)
        game.testSetKind(2, col: 0, row: 0)
        game.testSetKind(0, col: 1, row: 0)
        game.testSetKind(1, col: 2, row: 0)
        game.testSetKind(0, col: 3, row: 0)
        game.testSetKind(0, col: 2, row: 1)
        var jelly = [UInt8](repeating: 0, count: 49)
        jelly[48] = 200  // (6,6): unreachable — forces the loss branch
        game.testSetJelly(jelly)
        game.testSetMovesLeft(1)
        #expect(game.attemptSwap((2, 0), (2, 1)))
        #expect(settle(game) < 60)
        #expect(game.isOver)
        #expect(!game.didWinLevel)
        #expect(game.lastSpareBonus == 0)
    }

    // guards: ENDLESS never pays — no win state exists, the run only ends by exhaustion,
    // so the score-attack ladder (depth states, ENCORE) keeps its historical economy
    @Test func endlessRunNeverPaysSpareBonus() throws {
        let game = LuauGame()
        game.newGame()
        game.testSetMovesLeft(1)
        let move = try #require(game.findLegalSwap())  // fillFreshBoard guarantees one
        #expect(game.attemptSwap(move.0, move.1))
        #expect(settle(game) < 60)
        #expect(game.isOver)
        #expect(!game.didWinLevel)
        #expect(game.lastSpareBonus == 0)
    }

    // guards: retry/newLevel wipe the previous win's payout — no stale banner on the next run
    @Test func retryClearsSpareBonus() {
        let game = nearWin(movesLeft: 6)
        #expect(game.lastSpareBonus > 0)
        game.retryLevel()
        #expect(game.lastSpareBonus == 0)
        #expect(game.score == 0)
        #expect(game.movesLeft == LuauLevels.debugL1.moves)
    }

    // guards: jelly decrements by exactly 1 per cleared cell, floors at 0 (no UInt8 underflow), untouched elsewhere
    @Test func jellyDecrementsAndFloorsAtZero() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        paintPattern(game)
        game.testSetKind(1, col: 0, row: 0)
        game.testSetKind(0, col: 1, row: 0)
        game.testSetKind(0, col: 2, row: 0)
        game.testSetKind(0, col: 3, row: 0)  // planted H3 at row 0 cols 1-3
        var jelly = [UInt8](repeating: 0, count: 49)
        jelly[1] = 2  // (1,0) double layer
        jelly[2] = 1  // (2,0) single layer
        jelly[3] = 0  // (3,0) bare — must stay 0
        jelly[10] = 3 // (3,1) NOT cleared — must be untouched
        game.testSetJelly(jelly)
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 3)
        #expect(game.jelly[1] == 1)
        #expect(game.jelly[2] == 0)
        #expect(game.jelly[3] == 0)
        #expect(game.jelly[10] == 3)
        #expect(game.jellyRemaining == 4)
    }

    // guards: PINS the engine's trust in LevelForge — a zero-jelly level auto-wins on the first settle with no move made.
    // Current behavior by design (evaluateEndCondition treats jelly==0 as SUNRISE unconditionally);
    // the campaign-integrity sweep below is the guard that keeps such levels out of shipping data.
    @Test func zeroJellyLevelAutoWinsOnFirstSettlePinned() {
        let game = LuauGame()
        game.newLevel(zeroJellyLevel, attempt: 1)
        #expect(!game.isOver)  // fillFreshBoard does not evaluate end conditions
        #expect(!game.resolveStep())
        #expect(game.isOver)
        #expect(game.didWinLevel)
        #expect(game.completedLevels.contains(zeroJellyLevel.id))
    }

    // guards: full-run conservation on a masked level — every settle terminates with playableCount unique in-mask pieces, a legal swap, in-palette kinds, monotone score, one move per swap
    @Test func conservationSoakOnMaskedLevel() throws {
        let level = LuauLevels.debugWell
        let game = LuauGame()
        game.newLevel(level, attempt: 1)
        var lastScore = 0
        for _ in 0..<30 {
            if game.isOver { break }
            // Prefer the engine's own hint; if it comes up empty while a cat is
            // on the board (hasLegalSwap's known cat shortcut), play the cat —
            // cat swaps are always accepted.
            var chosen = game.findLegalSwap()
            if chosen == nil, let cat = game.pieces.first(where: { $0.special == .cat }) {
                for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)]
                where game.piece(at: cat.col + dc, cat.row + dr) != nil {
                    chosen = ((cat.col, cat.row), (cat.col + dc, cat.row + dr))
                    break
                }
            }
            let swap = try #require(chosen, "settled board must offer a playable move")
            let movesBefore = game.movesLeft
            #expect(game.attemptSwap(swap.0, swap.1))
            #expect(game.movesLeft == movesBefore - 1)
            #expect(settle(game) < 60)
            #expect(game.pieces.count == level.playableCount)
            #expect(occupancyUnique(game))
            #expect(game.pieces.allSatisfy { level.isPlayable(col: $0.col, row: $0.row) })
            #expect(game.pieces.allSatisfy {
                $0.special == .cat ? $0.kind == -1 : (0..<level.colors).contains($0.kind)
            })
            if !game.isOver { #expect(game.hasLegalSwap) }
            #expect(game.score >= lastScore)
            lastScore = game.score
        }
        #expect(game.isOver)
        if game.didWinLevel {
            #expect(game.completedLevels.contains(level.id))
        } else {
            #expect(game.movesLeft <= 0)
        }
    }

    // guards: markCurrentLevelComplete is idempotent and keeps completedLevels sorted and duplicate-free
    @Test func markCompleteIdempotentAndSorted() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugWell, attempt: 1)  // id 1002
        game.markCurrentLevelComplete()
        game.markCurrentLevelComplete()
        #expect(game.completedLevels == [1002])
        game.newLevel(LuauLevels.debugL1, attempt: 1)    // id 1001, lower
        game.markCurrentLevelComplete()
        #expect(game.completedLevels == [1001, 1002])
    }
}

// MARK: - Shuffle and legal-swap detection

@MainActor
struct LuauShuffleTests {

    // guards: a settle with no legal swap shuffles exactly once into a matchless, swap-viable board; the normal path preserves specials in place
    // (documents bug: the 8-attempt-exhausted last resort rebuilds via fillFreshBoard and silently DESTROYS earned specials)
    @Test func settleShufflesWhenNoLegalSwap() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)  // seeded -> deterministic shuffle
        paintPattern(game)  // pattern board: zero legal swaps
        game.testSetPiece(kind: 3, special: .lineV, col: 6, row: 6)
        #expect(!game.hasLegalSwap)
        #expect(!game.resolveStep())  // settle path runs shuffle
        #expect(game.shuffleBeat == 1)
        #expect(game.hasLegalSwap)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
        #expect(game.jelly == LuauLevels.debugL1.jelly)  // shuffle never touches jelly
        let specials = game.pieces.filter { $0.special != .none }
        // Deterministic for (debugL1, attempt 1): the seeded shuffle takes the
        // normal permutation path, which must preserve the torch in place.
        // If this ever fails on the specials count, shuffle fell to its
        // fillFreshBoard last resort and destroyed an earned special — the
        // regression this pin exists to catch (re-verify before re-pinning).
        #expect(specials.count == 1)
        let torch = game.piece(at: 6, 6)
        #expect(torch?.special == .lineV)
        #expect(torch?.kind == 3)
        // Re-settling must not shuffle again.
        #expect(!game.resolveStep())
        #expect(game.shuffleBeat == 1)
    }

    // guards: hasLegalSwap must report true when the only playable move is a special x special combo (attemptSwap WOULD accept it)
    // SUSPECTED-BUG(haslegalswap-blind-to-combos): expected to FAIL until product fix —
    // hasLegalSwap only scans kind-grid swaps + any-cat, so a board whose only move
    // is torch+torch gets shuffled away by settle (LuauGame.swift:828-859).
    @Test func hasLegalSwapSeesComboSwaps() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: 4, special: .lineH, col: 3, row: 3)
        game.testSetPiece(kind: 0, special: .lineV, col: 4, row: 3)
        // The combo IS playable — the pure preview proves it without mutating.
        #expect(!game.previewSwapFires((3, 3), (4, 3)).isEmpty)
        #expect(game.hasLegalSwap)
    }

    // guards: hasLegalSwap and findLegalSwap must agree — a cat sealed in an isolated 1-cell pocket has NO legal swap (soft-lock: shuffle never triggers)
    // SUSPECTED-BUG(haslegalswap-isolated-cat): expected to FAIL until product fix —
    // hasLegalSwap returns true for ANY cat regardless of adjacency (LuauGame.swift:829)
    // while findLegalSwap returns nil for the same board.
    @Test func hasLegalSwapAgreesWithFindLegalSwapForIsolatedCat() {
        let game = LuauGame()
        game.newLevel(isolatedPocketLevel, attempt: 1)
        paintPattern(game)  // masked subset of a no-swap pattern is still swap-free
        game.testSetPiece(kind: -1, special: .cat, col: 0, row: 0)  // isolated pocket
        // Both neighbors are masked: no swap involving the cat can even start.
        #expect(!game.attemptSwap((0, 0), (1, 0)))
        #expect(!game.attemptSwap((0, 0), (0, 1)))
        #expect(game.findLegalSwap() == nil)
        #expect(!game.hasLegalSwap)
    }
}

// MARK: - Tutorial

@MainActor
struct LuauTutorialTests {

    // guards: seedTutorialBoard clamps out-of-range rounds, paints a deterministic matchless 4/5 checkerboard, and anchors the coach at (3,3)/(3,4)
    @Test func tutorialRoundClampAndDeterministicBoard() {
        let low = LuauGame()
        low.newGame()
        low.seedTutorialBoard(round: -1)  // clamps to round 0
        #expect(low.piece(at: 2, 3)?.kind == 0)
        #expect(low.piece(at: 3, 3)?.kind == 1)
        #expect(low.piece(at: 0, 0)?.kind == 4)  // checkerboard base
        #expect(low.piece(at: 1, 0)?.kind == 5)
        #expect(low.pieces.count == 49)
        #expect(low.tutorialActive)
        #expect(low.movesLeft == LuauGame.movesPerRun)
        #expect(!low.resolveStep())  // seeded board contains no matches

        let high = LuauGame()
        high.newGame()
        high.seedTutorialBoard(round: 99)  // clamps to round 5 (SWAP THE CAT)
        #expect(high.piece(at: 3, 3)?.kind == -1)
        #expect(high.piece(at: 3, 3)?.special == .cat)
        #expect(high.piece(at: 3, 4)?.kind == 0)

        let summon = LuauGame()
        summon.newGame()
        summon.seedTutorialBoard(round: 4)  // SUMMON THE CAT — 5-match seed
        #expect(summon.piece(at: 3, 3)?.kind == 1)
        #expect(summon.piece(at: 1, 3)?.kind == 0)
        #expect(summon.piece(at: 5, 3)?.kind == 0)
        #expect(summon.piece(at: 3, 4)?.kind == 0)

        let tiles = LuauGame.tutorialTilePositions(round: 2)
        #expect(tiles.count == 2)
        #expect(tiles[0] == (col: 3, row: 3))
        #expect(tiles[1] == (col: 3, row: 4))
    }

    // guards: round-0 swap clears exactly ONE 3-match (the pop must be unmistakably
    // the swap's doing), refill is suppressed (46 pieces), tutorial clears never touch best
    @Test func tutorialRound0ClearsWithoutRefillAndBestSuppressed() {
        let game = LuauGame()
        game.newGame()
        game.seedTutorialBoard(round: 0)
        #expect(game.attemptSwap((3, 3), (3, 4)))
        #expect(game.movesLeft == LuauGame.movesPerRun - 1)
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 3)  // one match, no companion
        #expect(game.lastGain == 30)
        #expect(game.score == 30)
        #expect(game.pieces.count == 46)  // no refill while tutorialActive
        #expect(occupancyUnique(game))
        #expect(settle(game) < 60)
        #expect(game.best == 0)  // tutorial score never pollutes best
        game.endTutorial()
        #expect(!game.tutorialActive)
        #expect(game.pieces.count == 49)  // holes refilled
        #expect(occupancyUnique(game))
    }

    // guards: the MATCH A SQUARE beat (round 2) — the anchored swap's only product is
    // the 2x2: exactly the four square cells clear, all four sand layers pop (4→0),
    // nothing spawns, refill stays suppressed, and the board settles in one round.
    // Runs over Night 1 like the real coach (sand only decrements in level mode).
    @Test func tutorialSquareRoundPopsAllFourSand() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.seedTutorialBoard(round: 2)
        #expect(game.jellyRemaining == 4)
        #expect(game.hasLegalSwap)  // the anchored square swap IS the board's move
        #expect(game.attemptSwap((3, 3), (3, 4)))
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 4)
        #expect(game.jellyRemaining == 0)
        #expect(game.pieces.allSatisfy { $0.special == .none })
        #expect(game.pieces.count == 45)  // no refill while tutorialActive
        #expect(!game.resolveStep())  // one round, then quiet
        #expect(occupancyUnique(game))
        #expect(!game.isOver)  // coach sand hitting zero never latches the win
    }

    // guards: endTutorial without a tutorial (and called twice) is a harmless identity on a full board
    @Test func endTutorialIdempotentOnFullBoard() {
        let game = LuauGame()
        game.newGame()
        let before = game.pieces
        game.endTutorial()
        #expect(game.pieces == before)
        #expect(!game.tutorialActive)
        game.endTutorial()
        #expect(game.pieces == before)
    }

    // guards: PINS the tutorial-over-level contract — currentLevel and the level's
    // move budget survive, but sand becomes the ROUND'S scripted layout (the coach
    // tells its own sand story; Night 1's real jelly returns at the handoff), and
    // the checkerboard still paints kinds 4/5 even on a 4-color level (out-of-palette).
    @Test func tutorialOverLevelPaintsScriptedSandPinned() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)  // colors: 4, moves: 15
        game.testSetJelly([UInt8](repeating: 0, count: 49))  // mid-run: all sand popped
        game.seedTutorialBoard(round: 0)
        #expect(game.currentLevel?.id == LuauLevels.debugL1.id)  // NOT cleared
        // Round 0's scripted blob: rows 3–4 × cols 2–4, one layer each.
        var blob = [UInt8](repeating: 0, count: 49)
        for (col, row) in [(2, 3), (3, 3), (4, 3), (2, 4), (3, 4), (4, 4)] {
            blob[row * 7 + col] = 1
        }
        #expect(game.jelly == blob)                              // scripted, not the level's
        #expect(game.movesLeft == LuauLevels.debugL1.moves)      // reset to level budget
        #expect(game.tutorialActive)
        #expect(!game.didWinLevel)
        // Palette leak: base checkerboard is kinds 4/5 — outside colors 0..<4.
        #expect(game.piece(at: 0, 0)?.kind == 4)
        #expect(game.piece(at: 1, 0)?.kind == 5)
    }

    // guards: the two-beat blob arc — round 0 pops the blob's top row (6→3),
    // round 1's seed carries the SAME three survivors (no counter bounce-up),
    // and the mirrored swap finishes them (3→0)
    @Test func tutorialBlobArcPopsSixToThreeToZero() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.seedTutorialBoard(round: 0)
        #expect(game.jellyRemaining == 6)
        #expect(game.attemptSwap((3, 3), (3, 4)))
        #expect(settle(game) < 60)
        #expect(game.jellyRemaining == 3)  // top row popped, survivors remain
        for (col, row) in [(2, 4), (3, 4), (4, 4)] {
            #expect(game.jelly[row * 7 + col] == 1, "survivor (\(col),\(row))")
        }
        game.seedTutorialBoard(round: 1)
        #expect(game.jellyRemaining == 3)  // continuity: same survivors, no bounce-up
        for (col, row) in [(2, 4), (3, 4), (4, 4)] {
            #expect(game.jelly[row * 7 + col] == 1, "survivor (\(col),\(row))")
        }
        #expect(game.attemptSwap((3, 3), (3, 4)))
        #expect(settle(game) < 60)
        #expect(game.jellyRemaining == 0)  // POP THE REST finishes the blob
    }

    // guards: scripted sand pops never end the run — no win, no completion, no isOver
    // while tutorialActive (a mid-coach win would hide the coach card and fire the
    // sunrise panel); the out-of-moves branch is gated the same way
    @Test func tutorialSandPopNeverEndsRunWhileActive() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.seedTutorialBoard(round: 1)
        #expect(game.attemptSwap((3, 3), (3, 4)))
        #expect(settle(game) < 60)
        #expect(game.jellyRemaining == 0)
        #expect(!game.isOver)
        #expect(!game.didWinLevel)
        #expect(game.completedLevels.isEmpty)
        game.testSetMovesLeft(0)
        #expect(!game.resolveStep())  // settled board re-runs the end evaluation
        #expect(!game.isOver)         // moves gate stays closed too while scripted
    }

    // guards: the torch beat's 4-match sits on exactly its four sand cells — popping
    // sand is what spawns the torch; refill suppressed, best untouched
    @Test func tutorialTorchBeatPopsItsSandAndSpawnsTorch() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.seedTutorialBoard(round: 3)
        #expect(game.jellyRemaining == 4)
        #expect(game.attemptSwap((3, 3), (3, 4)))
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 4)
        #expect(game.jellyRemaining == 0)
        #expect(game.pieces.contains { $0.special == .lineV || $0.special == .lineH })
        #expect(occupancyUnique(game))
        #expect(settle(game) < 60)
        #expect(game.best == 0)
        #expect(!game.isOver)
    }

    // guards: the summon beat's 5-match sits wholly within sand (5→0) and spawns the cat
    @Test func tutorialSummonBeatPopsFiveAndSpawnsCat() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.seedTutorialBoard(round: 4)
        #expect(game.jellyRemaining == 5)
        #expect(game.attemptSwap((3, 3), (3, 4)))
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 5)
        #expect(game.jellyRemaining == 0)
        #expect(game.pieces.contains { $0.special == .cat })
        #expect(settle(game) < 60)
        #expect(!game.isOver)
    }

    // guards: the finale cat-swap wipes sand scattered across the whole board
    // (every kind-0 target is jellied — 8→0), and the win gate still holds
    @Test func tutorialCatWipePopsScatteredSand() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.seedTutorialBoard(round: 5)
        #expect(game.jellyRemaining == 8)
        #expect(game.attemptSwap((3, 3), (3, 4)))  // cat swap fires the wipe
        #expect(settle(game) < 60)
        #expect(game.jellyRemaining == 0)
        #expect(!game.isOver)
        #expect(!game.didWinLevel)
        #expect(game.completedLevels.isEmpty)
    }

    // guards: the dismissal handoff reopens the win gate — after endTutorial + the
    // fresh Night 1 newLevel, a real pop-to-zero wins and records completion
    @Test func winGateReopensAfterTutorialEnds() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.seedTutorialBoard(round: 1)
        #expect(game.attemptSwap((3, 3), (3, 4)))
        #expect(settle(game) < 60)
        game.endTutorial()
        game.newLevel(LuauLevels.debugL1, attempt: 1)  // dismissCoach's fresh Night 1
        #expect(game.jellyRemaining == 3)
        #expect(!game.tutorialActive)
        // Real play: stage a guaranteed match over one remaining sand cell.
        paintPattern(game)
        game.testSetKind(2, col: 0, row: 0)
        game.testSetKind(0, col: 1, row: 0)
        game.testSetKind(1, col: 2, row: 0)
        game.testSetKind(0, col: 3, row: 0)
        game.testSetKind(0, col: 2, row: 1)
        var jelly = [UInt8](repeating: 0, count: 49)
        jelly[2] = 1  // (2,0) only
        game.testSetJelly(jelly)
        #expect(game.attemptSwap((2, 0), (2, 1)))
        #expect(settle(game) < 60)
        #expect(game.isOver)
        #expect(game.didWinLevel)
        #expect(game.completedLevels.contains(LuauLevels.debugL1.id))
    }
}

// MARK: - Persistence

// Undecodable-payload fallback (9-payload corpus incl. unknown Special rawValue)
// is covered by LuauLevelsAdversarialTests.undecodablePayloadFallsBackToFreshEndless
// and corruptSpecialRawValueRejectsWholePayload.

@MainActor
struct LuauPersistenceTests {

    // guards: a mid-coach payload carries no live-run fields — a kill during the
    // scripted rounds can't resume a half-tutorial Night 1 (restore falls to fresh
    // endless; the view re-fires the coach while seenHowTo stays false)
    @Test func tutorialPayloadPersistsNoLiveRun() {
        let g1 = LuauGame()
        g1.newLevel(LuauLevels.debugL1, attempt: 1)
        g1.seedTutorialBoard(round: 2)
        let json = g1.payload(seenHowTo: false)
        let decoded = try? JSONDecoder().decode(LuauGame.SavePayload.self, from: Data(json.utf8))
        #expect(decoded != nil)
        #expect(decoded?.levelID == nil)
        #expect(decoded?.board == nil)
        #expect(decoded?.jelly == nil)

        let g2 = LuauGame()
        let state = g2.restore(from: json)
        #expect(state?.seenHowTo == false)
        #expect(!g2.isLevelMode)      // Case C: fresh endless, not a zombie level
        #expect(!g2.tutorialActive)
    }

    // guards: a mid-run endless payload round-trips board (kind/special/col/row), score, and movesLeft through Case B
    @Test func endlessPayloadRoundTrip() {
        let g1 = LuauGame()
        g1.newGame()
        paintPattern(g1)
        g1.testSetKind(2, col: 0, row: 0)
        g1.testSetKind(0, col: 1, row: 0)
        g1.testSetKind(1, col: 2, row: 0)
        g1.testSetKind(0, col: 3, row: 0)
        g1.testSetKind(0, col: 2, row: 1)
        #expect(g1.attemptSwap((2, 0), (2, 1)))  // mid-swap: match pending
        let json = g1.payload(seenHowTo: true)
        let g2 = LuauGame()
        #expect(g2.restore(from: json) != nil)
        #expect(g2.currentLevel == nil)
        #expect(gridSignature(g2) == gridSignature(g1))
        #expect(g2.score == 0)
        #expect(g2.movesLeft == LuauGame.movesPerRun - 1)
        #expect(!g2.isOver)
        // Both resolve the same pending match for the same gain.
        #expect(g1.resolveStep())
        #expect(g2.resolveStep())
        #expect(g1.lastGain == 30)
        #expect(g2.lastGain == 30)
    }

    // guards: a mid-level payload restores level id, board, jelly, attemptSeed, score, movesLeft — and two restores of one payload replay identically
    @Test func levelPayloadRoundTripAndRestorePointDeterminism() throws {
        let level = LuauLevels.debugL1
        let g1 = LuauGame()
        g1.newLevel(level, attempt: 3)
        // Heavy jelly so no cascade can accidentally win mid-test.
        g1.testSetJelly(Array(repeating: 9, count: 49))
        let s1 = try #require(g1.findLegalSwap())
        #expect(g1.attemptSwap(s1.0, s1.1))
        #expect(settle(g1) < 60)
        try #require(!g1.isOver)
        let json = g1.payload(seenHowTo: true)

        let g2 = LuauGame()
        let g3 = LuauGame()
        #expect(g2.restore(from: json) != nil)
        #expect(g3.restore(from: json) != nil)
        for restored in [g2, g3] {
            #expect(restored.currentLevel?.id == level.id)
            #expect(restored.attemptSeed == 3)
            #expect(restored.score == g1.score)
            #expect(restored.movesLeft == g1.movesLeft)
            #expect(restored.jelly == g1.jelly)
            #expect(gridSignature(restored) == gridSignature(g1))
            #expect(!restored.isOver)
        }
        // The re-derived RNG stream is deterministic FROM THE RESTORE POINT:
        // both restores must replay the same swap to identical states.
        let s2 = try #require(g2.findLegalSwap())
        #expect(g2.attemptSwap(s2.0, s2.1))
        #expect(g3.attemptSwap(s2.0, s2.1))
        #expect(settle(g2) < 60)
        #expect(settle(g3) < 60)
        #expect(gridSignature(g2) == gridSignature(g3))
        #expect(g2.score == g3.score)
        #expect(g2.jelly == g3.jelly)
    }

    // guards: wrong-size boards fall through Case A and B to a fresh endless game while preserving lifetime completedLevels
    @Test func wrongSizeBoardsFallToFreshEndlessKeepingProgress() {
        let cases: [LuauGame.SavePayload] = [
            // 48-piece endless board.
            LuauGame.SavePayload(seenHowTo: false, score: 90, movesLeft: 4,
                                 board: Array(patternPieces().dropFirst()),
                                 levelID: nil, jelly: nil, attemptSeed: nil,
                                 completedLevels: [5, 9]),
            // 50-piece endless board.
            LuauGame.SavePayload(seenHowTo: false, score: 90, movesLeft: 4,
                                 board: patternPieces() + [LuauGame.Piece(id: UUID(), kind: 0, special: .none, col: 0, row: 0)],
                                 levelID: nil, jelly: nil, attemptSeed: nil,
                                 completedLevels: [5, 9]),
            // Level save whose board no longer matches the level's playable count.
            LuauGame.SavePayload(seenHowTo: false, score: 90, movesLeft: 4,
                                 board: Array(patternPieces().dropFirst()),
                                 levelID: LuauLevels.debugL1.id,
                                 jelly: Array(repeating: 0, count: 49), attemptSeed: 2,
                                 completedLevels: [5, 9]),
        ]
        for payload in cases {
            let game = LuauGame()
            #expect(game.restore(from: payloadJSON(payload)) != nil)
            #expect(game.pieces.count == 49)
            #expect(game.score == 0)
            #expect(game.movesLeft == LuauGame.movesPerRun)
            #expect(game.currentLevel == nil)
            #expect(!game.isOver)
            #expect(game.completedLevels == [5, 9])  // restored before the case ladder
        }
    }

    // guards: an isOver run saves with board == nil and restores as a fresh endless game; completedLevels survives Case C
    @Test func isOverPayloadOmitsBoardAndRestoresFresh() throws {
        let over = LuauGame()
        over.newGame()
        over.testSetMovesLeft(0)
        #expect(!over.resolveStep())
        #expect(over.isOver)
        let json = over.payload(seenHowTo: true)
        let decoded = try #require(try? JSONDecoder().decode(LuauGame.SavePayload.self, from: Data(json.utf8)))
        #expect(decoded.board == nil)

        let fresh = LuauGame()
        _ = fresh.restore(from: payloadJSON(
            LuauGame.SavePayload(seenHowTo: false, score: 500, movesLeft: 0, board: nil,
                                 levelID: nil, jelly: nil, attemptSeed: nil,
                                 completedLevels: [3, 1])
        ))
        #expect(fresh.pieces.count == 49)
        #expect(fresh.score == 0)
        #expect(fresh.movesLeft == LuauGame.movesPerRun)
        #expect(!fresh.isOver)
        #expect(fresh.completedLevels == [3, 1])
    }

    // guards: restore must never install pieces outside the 7x7 board — the next findMatches/hasLegalSwap would crash on grid[p.row][p.col]
    // SUSPECTED-BUG(restore-accepts-oob-coords): expected to FAIL until product fix —
    // Case B validates only board.count == 49 (LuauGame.swift:1008); a col:99 piece
    // restores fine and index-traps on first use (:632, :831). This test deliberately
    // avoids calling resolveStep/hasLegalSwap so the suite survives to report.
    @Test func restoreRejectsOutOfRangeCoordinates() {
        var board = patternPieces()
        board[0].col = 99
        let game = LuauGame()
        _ = game.restore(from: payloadJSON(endlessPayload(score: 100, movesLeft: 10, board: board)))
        #expect(game.pieces.allSatisfy { (0..<7).contains($0.col) && (0..<7).contains($0.row) })
    }

    // Unknown-levelID fall-through (incl. completedLevels preservation) is pinned by
    // LuauLevelsAdversarialTests.invalidLevelPayloadMustNotHijackEndlessResume.

    // guards: restore must sanitize absurd scores — score near Int.max traps on the next `score += gain`
    // SUSPECTED-BUG(restore-unsanitized-score-overflow): expected to FAIL until product fix —
    // restore keeps score verbatim (LuauGame.swift:1015); the first clear after this
    // restore crashes with signed overflow at :735. Asserting generous headroom
    // instead of playing a move so the suite survives to report.
    @Test func restoreSanitizesAbsurdScore() {
        let game = LuauGame()
        _ = game.restore(from: payloadJSON(endlessPayload(score: Int.max, movesLeft: 10, board: patternPieces())))
        #expect(game.score < Int.max / 2)
    }

    // guards: restore must sanitize absurd movesLeft — Int.min traps in spendMove's `movesLeft -= 1`, and negatives leave a dead-but-not-over run
    // SUSPECTED-BUG(restore-unsanitized-movesleft): expected to FAIL until product fix —
    // restore keeps movesLeft verbatim (LuauGame.swift:1016) with isOver forced false.
    @Test func restoreSanitizesAbsurdMovesLeft() {
        let game = LuauGame()
        _ = game.restore(from: payloadJSON(endlessPayload(score: 10, movesLeft: Int.min, board: patternPieces())))
        #expect(game.movesLeft >= 0)
    }

    // Duplicate-cell board rejection is pinned by
    // LuauLevelsAdversarialTests.restoreRejectsBoardsWithOverlappingPieces.
}

// MARK: - End conditions and bookkeeping

@MainActor
struct LuauEndConditionTests {

    // guards: a finished run is read-only — resolveStep after isOver must not clear, score, or touch best
    // SUSPECTED-BUG(resolvestep-ignores-isover): expected to FAIL until product fix —
    // resolveStep has no isOver guard (LuauGame.swift:670), so any post-mortem call
    // clears matches and mutates the finished run's score and best.
    @Test func resolveStepAfterGameOverIsInert() {
        let game = LuauGame()
        game.newGame()
        game.testSetMovesLeft(0)
        #expect(!game.resolveStep())
        #expect(game.isOver)
        plantTriple(game)  // fresh deterministic 3-match on the corpse board
        let scoreBefore = game.score
        let bestBefore = game.best
        _ = game.resolveStep()
        #expect(game.score == scoreBefore)
        #expect(game.best == bestBefore)
    }

    // guards: best only ratchets up (configureBest is a max), and only settles publish score into best
    @Test func bestRatchetsUpOnlyOnSettle() {
        let game = LuauGame()
        game.newGame()
        game.configureBest(500)
        #expect(game.best == 500)
        game.configureBest(100)  // never lowers
        #expect(game.best == 500)
        game.testSetScore(300)
        #expect(game.best == 500)  // score alone does not move best
        #expect(!game.resolveStep())
        #expect(game.best == 500)  // 300 < 500: settle keeps the max
        game.testSetScore(750)
        #expect(!game.resolveStep())
        #expect(game.best == 750)  // settle ratchets up
    }
}

// The LuauLevel value-type suite (accessor totality, parse legend, column
// convexity, shipped-catalog integrity) lives in LuauLevelsAdversarialTests —
// LuauLevelShapeTests / LuauCatalogTests cover it strictly more thoroughly.

// MARK: - Lounge cat (comped placement)

@MainActor
@Suite("Luau lounge cat")
struct LuauLoungeCatTests {
    // guards: placement is a gift, not a move — the target piece becomes the cat and nothing else changes
    @Test func placeCatReplacesOnlyTheTargetPiece() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        let movesBefore = game.movesLeft
        let scoreBefore = game.score
        let sandBefore = game.jellyRemaining
        let countBefore = game.pieces.count
        #expect(game.placeCat(col: 3, row: 3))
        let cat = game.piece(at: 3, 3)
        #expect(cat?.special == .cat)
        #expect(cat?.kind == -1)
        #expect(game.pieces.count == countBefore)
        #expect(game.movesLeft == movesBefore, "a comp never spends a move")
        #expect(game.score == scoreBefore, "placement never scores")
        #expect(game.jellyRemaining == sandBefore, "placement never pops sand")
    }

    // guards: the comp can't overwrite an earned special
    @Test func placeCatRefusesExistingSpecials() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.testSetPiece(kind: 0, special: .lineH, col: 3, row: 3)
        #expect(!game.placeCat(col: 3, row: 3))
        #expect(game.piece(at: 3, 3)?.special == .lineH, "the torch survives")
    }

    // guards: masked and out-of-range cells refuse — no cat floating off the board
    @Test func placeCatRefusesMaskedAndOutOfRangeCells() throws {
        let masked = try #require(LuauLevels.debugFixtures.first { $0.playableCount < 49 })
        var hole: (col: Int, row: Int)?
        outer: for r in 0..<LuauLevel.size {
            for c in 0..<LuauLevel.size where !masked.isPlayable(col: c, row: r) {
                hole = (c, r); break outer
            }
        }
        let cell = try #require(hole)
        let game = LuauGame()
        game.newLevel(masked, attempt: 1)
        #expect(!game.placeCat(col: cell.col, row: cell.row))
        #expect(!game.placeCat(col: -1, row: 0))
        #expect(!game.placeCat(col: 7, row: 7))
    }

    // guards: no placement during the scripted coach or after the night ends
    @Test func placeCatRefusesTutorialAndFinishedNights() {
        let coach = LuauGame()
        coach.newLevel(LuauLevels.debugL1, attempt: 1)
        coach.seedTutorialBoard(round: 0)
        #expect(!coach.placeCat(col: 3, row: 3))
        let won = LuauGame()
        won.newLevel(LuauLevels.debugL1, attempt: 1)
        won.testSetJelly(Array(repeating: 0, count: LuauLevel.cellCount))
        _ = won.resolveStep()   // no-match settle → evaluateEndCondition → win latches
        #expect(won.isOver)
        #expect(!won.placeCat(col: 3, row: 3))
    }

    // guards: the placed cat is a REAL cat — swapping it clears the partner's whole color through the normal engine path
    @Test func placedCatSwapClearsThePartnerColor() throws {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        #expect(game.placeCat(col: 3, row: 3))
        let partner = try #require(game.piece(at: 4, 3))
        let victims = game.pieces.filter { $0.kind == partner.kind }.count
        let scoreBefore = game.score
        let movesBefore = game.movesLeft
        let beatBefore = game.fireBeat
        #expect(game.attemptSwap((3, 3), (4, 3)))
        #expect(game.fireBeat == beatBefore + 1)
        #expect(game.lastFires.first?.kind == .catSwap)
        #expect(game.lastFires.first?.targetKind == partner.kind)
        #expect(game.score == scoreBefore + (victims + 1) * 20,
                "every piece of the color plus the cat, 20 each")
        #expect(game.movesLeft == movesBefore - 1, "the swap itself is a real move")
    }

    // guards: a comped cat survives save/restore like any earned special
    @Test func placedCatSurvivesSaveRestore() throws {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        #expect(game.placeCat(col: 2, row: 1))
        let saved = game.payload(seenHowTo: true)
        let fresh = LuauGame()
        try #require(fresh.restore(from: saved) != nil)
        let cat = fresh.piece(at: 2, 1)
        #expect(cat?.special == .cat)
        #expect(cat?.kind == -1)
    }

    // guards: DANGER is exactly "live campaign night, sand standing, 1...3 moves"
    @Test func dangerThresholds() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        #expect(!game.inDanger, "15 moves is open water")
        game.testSetMovesLeft(4)
        #expect(!game.inDanger)
        game.testSetMovesLeft(3)
        #expect(game.inDanger)
        game.testSetMovesLeft(1)
        #expect(game.inDanger)
        game.testSetMovesLeft(0)
        #expect(!game.inDanger)
        game.testSetMovesLeft(3)
        game.testSetJelly(Array(repeating: 0, count: LuauLevel.cellCount))
        #expect(!game.inDanger, "no sand left is winning, not danger")
        let endless = LuauGame()
        endless.newGame()
        endless.testSetMovesLeft(3)
        #expect(!endless.inDanger, "endless nights never comp")
        let coach = LuauGame()
        coach.newLevel(LuauLevels.debugL1, attempt: 1)
        coach.seedTutorialBoard(round: 0)
        coach.testSetMovesLeft(3)
        #expect(!coach.inDanger, "the coach never comps")
    }
}

// MARK: - 2x2 square matches (Matchington rule)

@MainActor
struct LuauSquareMatchTests {

    /// Pattern + a square one swap from completion: kind-5 (never in the
    /// pattern) at (1,1), (2,1), (1,2), and (2,3); swapping (2,2)<->(2,3)
    /// brings the fourth 5 to (2,2). No 3-run exists anywhere post-swap —
    /// acceptance can only come from the square rule.
    private func plantSquareSetup(_ game: LuauGame) {
        paintPattern(game)
        game.testSetKind(5, col: 1, row: 1)
        game.testSetKind(5, col: 2, row: 1)
        game.testSetKind(5, col: 1, row: 2)
        game.testSetKind(5, col: 2, row: 3)
    }

    // guards: a swap whose ONLY product is a 2x2 is legal, spends a move, clears exactly
    // the four square cells at 10/piece, and spawns NO special — the count==4 spawn rule is
    // line-only, so without the isSquare guard every square would mint a torch. (An
    // area-clear bomb was tried here and cut; squares earn nothing again.)
    @Test func squareSwapMatchesClearsFourNoSpawn() {
        let game = LuauGame()
        game.newGame()
        plantSquareSetup(game)
        let movesBefore = game.movesLeft
        #expect(game.attemptSwap((2, 2), (2, 3)))
        #expect(game.movesLeft == movesBefore - 1)
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 4)
        #expect(game.lastGain == 40)  // 4 pieces x 10 x cascade 1
        #expect(game.pieces.allSatisfy { $0.special == .none })
        settle(game)
    }

    // guards: the Matchington follow-up made executable — a 3x2 same-kind block is a
    // match too: two overlapping squares + two 3-runs, all six cells clear exactly once
    // (toClear dedup), still no spawn (3-runs and squares both earn nothing)
    @Test func threeByTwoBlockClearsAllSixOnce() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        for (c, r) in [(1, 1), (2, 1), (3, 1), (1, 2), (2, 2)] {
            game.testSetKind(5, col: c, row: r)
        }
        game.testSetKind(5, col: 3, row: 3)
        #expect(game.attemptSwap((3, 2), (3, 3)))  // completes rows 1-2 x cols 1-3
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 6)
        #expect(game.lastGain == 60)
        #expect(game.pieces.allSatisfy { $0.special == .none })
        settle(game)
    }

    // guards: LOCKSTEP — hasLegalSwap and findLegalSwap both see square-forming swaps.
    // If they diverge, a square-only board passes the shuffle check yet yields no
    // hint/autoplay move and the run stalls.
    @Test func squareOnlyBoardHasLegalSwapAndHint() throws {
        let game = LuauGame()
        game.newGame()
        plantSquareSetup(game)
        #expect(game.hasLegalSwap)
        let hint = try #require(game.findLegalSwap())
        #expect(game.attemptSwap(hint.0, hint.1))
    }

    // guards: rejection sampling — fresh boards (endless system-RNG and seeded level
    // mode) never open with a ready-made 2x2, mirroring the existing no-3-run guarantee
    @Test func freshBoardsNeverOpenWithSquares() throws {
        func hasSquare(_ game: LuauGame) -> Bool {
            var grid = [[Int]](repeating: [Int](repeating: -9, count: 7), count: 7)
            for p in game.pieces { grid[p.row][p.col] = p.kind }
            for r in 0..<6 {
                for c in 0..<6 {
                    let k = grid[r][c]
                    if k >= 0, grid[r][c+1] == k, grid[r+1][c] == k, grid[r+1][c+1] == k {
                        return true
                    }
                }
            }
            return false
        }
        let endless = LuauGame()
        for _ in 0..<10 {
            endless.newGame()
            #expect(!hasSquare(endless))
        }
        let level = LuauGame()
        for attempt in 1...5 {
            level.newLevel(LuauLevels.debugL1, attempt: UInt64(attempt))
            #expect(!hasSquare(level))
        }
        let campaign = try #require(LuauLevels.level(id: 13))
        level.newLevel(campaign, attempt: 1)
        #expect(!hasSquare(level))
    }
}

// MARK: - The bomb (sun-compass): L/T corner shapes

/// The bomb's SECOND life. Its first was earned by the 2x2 square and died
/// for its art; the mechanic returns 2026-07-31 with the corner faucet — an
/// L, T, or + of 5+ distinct cells (two perpendicular runs of one kind
/// sharing exactly one cell) mints a bomb that clears 3x3 when its cell
/// clears. Priority is the genre's: straight-5 cat > corner bomb > straight-4
/// torch, and every kind-5 plant below rides the null pattern's guarantee
/// that kind 5 appears nowhere else, so shapes are exactly what was planted.
struct CornerCase: Sendable {
    let name: String
    let cells: [(col: Int, row: Int)]
    let finalCell: (col: Int, row: Int)
    let clearCount: Int
}

/// All four L elbows, all four T stems, and the +. `finalCell` is
/// POST-GRAVITY: a corner with cleared cells beneath it rides its
/// column down before the board settles.
let cornerCases: [CornerCase] = [
        .init(name: "L elbow SW", cells: [(0, 6), (1, 6), (2, 6), (0, 5), (0, 4)],
              finalCell: (0, 6), clearCount: 5),
        .init(name: "L elbow SE", cells: [(4, 6), (5, 6), (6, 6), (6, 5), (6, 4)],
              finalCell: (6, 6), clearCount: 5),
        .init(name: "L elbow NW", cells: [(0, 4), (1, 4), (2, 4), (0, 5), (0, 6)],
              finalCell: (0, 6), clearCount: 5),
        .init(name: "L elbow NE", cells: [(4, 4), (5, 4), (6, 4), (6, 5), (6, 6)],
              finalCell: (6, 6), clearCount: 5),
        .init(name: "T stem down", cells: [(2, 4), (3, 4), (4, 4), (3, 5), (3, 6)],
              finalCell: (3, 6), clearCount: 5),
        .init(name: "T stem up", cells: [(2, 6), (3, 6), (4, 6), (3, 4), (3, 5)],
              finalCell: (3, 6), clearCount: 5),
        .init(name: "T stem right", cells: [(2, 3), (2, 4), (2, 5), (3, 4), (4, 4)],
              finalCell: (2, 5), clearCount: 5),
        .init(name: "T stem left", cells: [(4, 3), (4, 4), (4, 5), (2, 4), (3, 4)],
              finalCell: (4, 5), clearCount: 5),
        .init(name: "plus", cells: [(3, 3), (3, 4), (3, 5), (2, 4), (4, 4)],
              finalCell: (3, 5), clearCount: 5),
]

@MainActor
struct LuauBombSuite {

    // guards: every rotation of the corner shape mints exactly one bomb, at the
    // corner (post-gravity), carrying the shape's kind — and nothing else spawns
    @Test("corner shapes mint the bomb", arguments: cornerCases)
    func cornerShapeMintsABomb(c: CornerCase) {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        for cell in c.cells { game.testSetKind(5, col: cell.col, row: cell.row) }
        #expect(game.resolveStep(), "\(c.name): the planted shape must clear")
        #expect(game.lastClearCount == c.clearCount, "\(c.name)")
        #expect(game.lastGain == c.clearCount * 10, "\(c.name)")
        let specials = game.pieces.filter { $0.special != .none }
        #expect(specials.count == 1, "\(c.name): exactly one special")
        #expect(specials.first?.special == .bomb, "\(c.name)")
        #expect(specials.first?.kind == 5, "\(c.name): bomb carries the shape's kind")
        let placed = game.piece(at: c.finalCell.col, c.finalCell.row)
        #expect(placed?.special == .bomb, "\(c.name): bomb at \(c.finalCell)")
        #expect(game.pieces.count == 49, "\(c.name)")
        #expect(occupancyUnique(game), "\(c.name)")
        #expect(settle(game) < 60, "\(c.name)")
        #expect(game.pieces.count == 49, "\(c.name)")
    }

    // guards: the priority ladder's top rung — a 5-run with a 3-arm off its end
    // pays the CAT only; the arm just clears, and no bomb or torch rides along
    @Test func aStraightFiveWithAnArmPaysOnlyTheCat() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        for col in 1...5 { game.testSetKind(5, col: col, row: 6) }
        game.testSetKind(5, col: 1, row: 4)
        game.testSetKind(5, col: 1, row: 5)
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 7)
        let specials = game.pieces.filter { $0.special != .none }
        #expect(specials.count == 1)
        #expect(specials.first?.special == .cat)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: a 4+4 L pays ONE bomb and zero torches — both arms are consumed
    // by the corner, so neither is left over to mint a lane
    @Test func aFourPlusFourLPaysOneBombAndNoTorches() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        for col in 3...6 { game.testSetKind(5, col: col, row: 6) }
        for row in 3...5 { game.testSetKind(5, col: 6, row: row) }
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 7)
        let specials = game.pieces.filter { $0.special != .none }
        #expect(specials.count == 1)
        #expect(specials.first?.special == .bomb)
        #expect(game.piece(at: 6, 6)?.special == .bomb)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: a double-T (one row shared by two stems) pays ONE bomb,
    // deterministically at the leftmost corner; the orphaned stem just clears
    @Test func aDoubleTPaysOneBombDeterministically() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        for col in 1...4 { game.testSetKind(5, col: col, row: 6) }
        game.testSetKind(5, col: 1, row: 4); game.testSetKind(5, col: 1, row: 5)
        game.testSetKind(5, col: 4, row: 4); game.testSetKind(5, col: 4, row: 5)
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 8)
        let specials = game.pieces.filter { $0.special != .none }
        #expect(specials.count == 1)
        #expect(specials.first?.special == .bomb)
        #expect(game.piece(at: 1, 6)?.special == .bomb,
                "tie breaks to the leftmost corner")
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: a swap-formed L mints its bomb on the swapped-into cell (which for
    // a single swap is necessarily the corner — both arms complete there)
    @Test func aSwapFormedLMintsTheBombAtTheSwap() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetKind(5, col: 1, row: 6)
        game.testSetKind(5, col: 2, row: 6)
        game.testSetKind(5, col: 3, row: 4)
        game.testSetKind(5, col: 3, row: 5)
        game.testSetKind(5, col: 4, row: 6)  // the mover
        #expect(game.attemptSwap((4, 6), (3, 6)))
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 5)
        #expect(game.piece(at: 3, 6)?.special == .bomb)
        #expect(game.piece(at: 3, 6)?.kind == 5)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: bombs never mint during the scripted coach — the ladder teaches
    // square → torch → cat, and an untaught special mid-demonstration is
    // off-script (the guard the square-era bomb shipped with, kept for corners)
    @Test func theCoachSuppressesBombMinting() {
        let game = LuauGame()
        game.newGame()
        game.seedTutorialBoard(round: 0)
        #expect(game.tutorialActive)
        for cell in [(0, 6), (1, 6), (2, 6), (0, 5), (0, 4)] {
            game.testSetPiece(kind: 5, special: .none, col: cell.0, row: cell.1)
        }
        #expect(game.resolveStep(), "the planted L must still clear")
        #expect(game.pieces.allSatisfy { $0.special != .bomb },
                "no bomb may appear mid-coach")
    }

    // MARK: firing

    // guards: v1's resurrection oath — a bomb is an ORDINARY MATCHABLE PIECE
    // that happens to be special: it carries a kind, matches by that colour
    // like any piece, and fires its 3x3 when it does
    @Test func bombIsMatchableByItsOwnColourAndFires() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetKind(5, col: 1, row: 3)
        game.testSetKind(5, col: 2, row: 3)
        game.testSetPiece(kind: 5, special: .bomb, col: 3, row: 3)
        #expect(game.piece(at: 3, 3)?.kind == 5, "a bomb must carry a real colour")
        #expect(game.resolveStep())
        #expect(game.lastFires.count == 1)
        #expect(game.lastFires.first?.kind == .bomb)
        // The 3-run plus the 3x3 it sets off, overlapping.
        #expect(game.lastClearCount == 10)
        #expect(game.pieces.allSatisfy { $0.special != .bomb }, "the bomb spent itself")
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: the blast clips at the board edge — a cornered bomb takes its
    // quadrant, not phantom off-board cells
    @Test func theBlastClipsAtTheBoardEdge() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: 5, special: .bomb, col: 0, row: 0)
        game.testSetKind(5, col: 1, row: 0)
        game.testSetKind(5, col: 2, row: 0)
        #expect(game.resolveStep())
        // Run (0..2,0) ∪ blast quadrant (0..1, 0..1) = 5 distinct cells.
        #expect(game.lastClearCount == 5)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: chained detonation runs THROUGH the bomb — a torch lane sets it
    // off, and its blast sets off a second torch, all in one round's plan
    @Test func aTorchLaneDetonatesABombWhichDetonatesATorch() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: 5, special: .lineH, col: 1, row: 3)
        game.testSetKind(5, col: 2, row: 3)
        game.testSetKind(5, col: 3, row: 3)
        game.testSetPiece(kind: (5 + 6) % 5, special: .bomb, col: 5, row: 3)
        game.testSetPiece(kind: (6 + 8) % 5, special: .lineV, col: 6, row: 4)
        #expect(game.resolveStep())
        let kinds = game.lastFires.map(\.kind)
        #expect(kinds.count == 3)
        #expect(kinds.contains(.torchH))
        #expect(kinds.contains(.bomb))
        #expect(kinds.contains(.torchV))
        // Row 3 (7) ∪ blast rows 2-4 cols 4-6 (+6) ∪ col 6 (+4) = 17.
        #expect(game.lastClearCount == 17)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: a bomb standing on the colour a cat wipes DETONATES instead of
    // dying quietly — the same rule the torch won in b680313's fix
    @Test func aCatWipeDetonatesABombOfTheWipedColour() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
        game.testSetKind(5, col: 4, row: 3)                          // swap partner
        game.testSetPiece(kind: 5, special: .bomb, col: 0, row: 6)   // same colour, far corner
        let preview = game.previewSwapFires((3, 3), (4, 3))
        #expect(preview.count == 2)
        #expect(preview.first?.kind == .catSwap)
        #expect(preview.last?.kind == .bomb)
        #expect(game.attemptSwap((3, 3), (4, 3)))
        // cat + partner + bomb (3) ∪ blast quadrant (0,5),(1,5),(1,6) (+3) = 6.
        #expect(game.lastClearCount == 6)
        #expect(game.lastGain == 120)
        #expect(game.lastFires.count == 2)
        #expect(game.lastFires.last?.kind == .bomb)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // MARK: combos

    // guards: bomb+torch = SHOCKWAVE — three full rows AND columns through the
    // bomb at 20/piece, banner set, fire anchored on the bomb
    @Test func shockwaveClearsThreeRowsAndThreeColumns() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: 5, special: .bomb, col: 3, row: 3)
        game.testSetPiece(kind: (4 + 6) % 5, special: .lineV, col: 4, row: 3)
        #expect(game.previewCombo((3, 3), (4, 3)) == .shockwave,
                "the view's banner keys on this")
        #expect(game.attemptSwap((3, 3), (4, 3)))
        #expect(game.lastCombo == .shockwave)
        // Rows 2-4 (21) + cols 2-4 (21) − overlap (9) = 33.
        #expect(game.lastClearCount == 33)
        #expect(game.lastGain == 33 * 20)
        #expect(game.lastFires.first?.kind == .shockwave,
                "its own show — the borrowed single cross left offset lanes unexplained")
        #expect(game.lastFires.first?.originCol == 3)
        #expect(game.lastFires.first?.originRow == 3)
        #expect(game.movesLeft == LuauGame.movesPerRun - 1)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: bomb+bomb = DOUBLE BLAST — a 5x5 anchored where the swap landed
    // (the cross's rule) at 20/piece
    @Test func doubleBlastClearsFiveByFive() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: 5, special: .bomb, col: 3, row: 3)
        game.testSetPiece(kind: (4 + 6) % 5, special: .bomb, col: 4, row: 3)
        #expect(game.attemptSwap((3, 3), (4, 3)))
        #expect(game.lastCombo == .blast)
        // 5x5 centered (4,3): cols 2-6, rows 1-5 = 25; both bombs inside it.
        #expect(game.lastClearCount == 25)
        #expect(game.lastGain == 25 * 20)
        #expect(game.lastFires.first?.kind == .bomb)
        #expect(game.lastFires.first?.originCol == 4)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: cat+bomb = ERUPTION — the bomb's colour everywhere plus a 5x5
    // where it sat, at 25/piece, targetKind tinting to the bomb's colour
    @Test func eruptionWipesTheColourPlusTheArea() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
        game.testSetPiece(kind: 5, special: .bomb, col: 4, row: 3)
        game.testSetKind(5, col: 0, row: 0)   // same colour, outside the 5x5
        #expect(game.previewCombo((3, 3), (4, 3)) == .eruption,
                "the view's banner keys on this")
        #expect(game.attemptSwap((3, 3), (4, 3)))
        #expect(game.lastCombo == .eruption)
        // 5x5 at (4,3) = 25 (cat inside) ∪ the kind-5 at (0,0) = 26.
        #expect(game.lastClearCount == 26)
        #expect(game.lastGain == 26 * 25)
        #expect(game.lastFires.first?.kind == .eruption,
                "its own show — the borrowed storm suit glowed lanes it never cleared")
        #expect(game.lastFires.first?.targetKind == 5)
        #expect(game.lastFires.first?.originCol == 4)
        #expect(game.pieces.count == 49)
        #expect(occupancyUnique(game))
    }

    // guards: the preview and the engine read ONE combo table — for every bomb
    // pairing the previewed cells equal exactly what the swap then destroys
    @Test func previewMirrorsEveryBombCombo() {
        func stage(_ second: (Int, LuauGame.Special)) -> LuauGame {
            let game = LuauGame()
            game.newGame()
            paintPattern(game)
            game.testSetPiece(kind: 5, special: .bomb, col: 3, row: 3)
            game.testSetPiece(kind: second.0, special: second.1, col: 4, row: 3)
            return game
        }
        for second in [((4 + 6) % 5, LuauGame.Special.lineV),
                       ((4 + 6) % 5, .bomb),
                       (-1, .cat)] {
            let game = stage(second)
            let previewed = Set(game.previewSwapFires((3, 3), (4, 3))
                .flatMap(\.cells).map { $0.row * 7 + $0.col })
            #expect(!previewed.isEmpty)
            #expect(game.attemptSwap((3, 3), (4, 3)))
            let cleared = Set(game.lastFires.flatMap(\.cells).map { $0.row * 7 + $0.col })
            #expect(previewed == cleared,
                    "preview and swap disagree for \(second.1)")
        }
    }

    // MARK: persistence + liveness

    // guards: a bomb round-trips a save with its cell, kind, and special intact
    @Test func aBombRoundTripsThroughASave() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: 5, special: .bomb, col: 2, row: 2)
        let saved = game.payload(seenHowTo: true)
        let fresh = LuauGame()
        #expect(fresh.restore(from: saved) != nil)
        let bomb = fresh.piece(at: 2, 2)
        #expect(bomb?.special == .bomb)
        #expect(bomb?.kind == 5)
    }

    // guards: a board whose only move is bomb×special adjacency still reads as
    // playable — hasLegalSwap's special scan covers the bomb like any special
    @Test func bombAdjacencyKeepsTheBoardAlive() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: 5, special: .bomb, col: 3, row: 3)
        game.testSetPiece(kind: (4 + 6) % 5, special: .lineV, col: 4, row: 3)
        #expect(game.hasLegalSwap)
    }

    // guards: previewCombo answers ONLY legal special×special pairings — nil
    // for plain pieces, cat swaps, non-adjacent specials, and dead runs. The
    // view keys banner/haptic/shake on this, so a false positive would flash
    // combo juice on an ordinary swap.
    @Test func previewComboAnswersOnlyRealCombos() {
        let game = LuauGame()
        game.newGame()
        paintPattern(game)
        game.testSetPiece(kind: 5, special: .bomb, col: 3, row: 3)
        game.testSetPiece(kind: -1, special: .cat, col: 4, row: 3)
        #expect(game.previewCombo((3, 3), (4, 3)) == .eruption)
        #expect(game.previewCombo((4, 3), (3, 3)) == .eruption, "order-blind")
        #expect(game.previewCombo((3, 3), (2, 3)) == nil, "bomb×plain is a match, not a combo")
        #expect(game.previewCombo((4, 3), (5, 3)) == nil, "cat×plain is a cat swap, not a combo")
        #expect(game.previewCombo((3, 3), (5, 3)) == nil, "not adjacent")
        game.testSetMovesLeft(0)
        #expect(game.previewCombo((3, 3), (4, 3)) == nil, "dead run answers nothing")
    }
}
