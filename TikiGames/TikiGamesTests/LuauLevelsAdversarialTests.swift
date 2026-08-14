import Foundation
import Testing
@testable import Tiki_Lounge

// Adversarial tests for the LuauLevels module: LuauLevel codec/shape,
// LuauLevels catalog, LuauGame engine surfaces (newLevel/attemptSwap/
// resolveStep/payload/restore), and LuauBot policy.
//
// All boards are driven single-threaded. Level mode is fully seeded
// (SplitMix64), so crafted-board tests are deterministic; endless-mode
// tests assert only invariants that hold for every RNG outcome.
//
// SUSPECTED-BUG tests assert the CORRECT behavior and are expected to
// FAIL until the product fix lands. Do not weaken them.

// MARK: - shared helpers

private let fullBoardMask: UInt64 = 0x1_FFFF_FFFF_FFFF  // (1 << 49) - 1

private let knownArchetypes: Set<String> = [
    "Full Board", "The Headland", "The Cove", "The Dune", "The Well",
    "The Cross", "The Lagoon", "The Atoll", "The Shelf", "The Pyramid",
    "The Jetty", "The Channel", "The Funnel", "Twin Coves",
]

/// UUID-free board signature (position + kind + special), the self-test idiom.
private func boardSignature(_ game: LuauGame) -> String {
    game.pieces
        .sorted { ($0.row, $0.col) < ($1.row, $1.col) }
        .map { "\($0.col),\($0.row):\($0.kind):\($0.special.rawValue)" }
        .joined(separator: "|")
}

/// Drives resolveStep to fixed point with a hard cap so no test can hang.
@discardableResult
private func settle(_ game: LuauGame, cap: Int = 300) -> Int {
    var steps = 0
    while steps < cap, game.resolveStep() { steps += 1 }
    return steps
}

/// Carpets the board with a 4-kind pattern (kinds 10...13) that admits NO
/// legal swap and no match anywhere: rows cycle with period 4 (no 3-run,
/// and cells two apart in a row differ by 2 mod 4), columns alternate with
/// period 2 (cells two apart are equal, but a swapped-in kind never lines
/// up with both vertical neighbors). Verified empirically: hasLegalSwap is
/// false on a pure carpet.
private func carpetNoLegalSwaps(_ game: LuauGame) {
    for row in 0..<7 {
        for col in 0..<7 {
            game.testSetKind(10 + ((col + 2 * row) % 4), col: col, row: row)
        }
    }
}

/// Carpets every cell with one kind (used to stage guaranteed clears).
private func carpetUniform(_ game: LuauGame, kind: Int) {
    for row in 0..<7 {
        for col in 0..<7 {
            game.testSetKind(kind, col: col, row: row)
        }
    }
}

/// Full observable-state snapshot for no-op assertions (all six juice beats).
private struct GameSnapshot: Equatable {
    let pieces: [LuauGame.Piece]
    let score: Int
    let movesLeft: Int
    let jelly: [UInt8]
    let isOver: Bool
    let didWinLevel: Bool
    let clearBeat: Int
    let fireBeat: Int
    let comboBeat: Int
    let shuffleBeat: Int
    let cascadeBeat: Int
    let encoreBeat: Int
    let completedLevels: [Int]

    init(_ game: LuauGame) {
        pieces = game.pieces
        score = game.score
        movesLeft = game.movesLeft
        jelly = game.jelly
        isOver = game.isOver
        didWinLevel = game.didWinLevel
        clearBeat = game.clearBeat
        fireBeat = game.fireBeat
        comboBeat = game.comboBeat
        shuffleBeat = game.shuffleBeat
        cascadeBeat = game.cascadeBeat
        encoreBeat = game.encoreBeat
        completedLevels = game.completedLevels
    }
}

private func decodePayload(_ json: String) throws -> LuauGame.SavePayload {
    try JSONDecoder().decode(LuauGame.SavePayload.self, from: Data(json.utf8))
}

private func encodePayload(_ payload: LuauGame.SavePayload) throws -> String {
    String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
}

/// Legacy-shaped endless payload built from a live endless game (49-piece
/// board, no level fields, no completedLevels).
private func legacyEndlessPayload(score: Int, movesLeft: Int) -> String {
    let game = LuauGame()
    game.newGame()
    game.testSetScore(score)
    game.testSetMovesLeft(movesLeft)
    return game.payload(seenHowTo: true)
}

// MARK: - LuauLevel shape + codec

@MainActor
struct LuauLevelShapeTests {

    // guards: out-of-range coordinate guard runs before shift/index arithmetic — no trap, false/0 for every hostile input
    @Test(arguments: [
        (col: -1, row: 0), (col: 0, row: -1), (col: 7, row: 0), (col: 0, row: 7),
        (col: Int.min, row: 0), (col: Int.max, row: Int.max),
    ])
    func hostileCoordinatesAreRejected(coordinate: (col: Int, row: Int)) throws {
        let level = try #require(LuauLevels.level(id: 14))  // full board, 49 playable
        #expect(level.mask == fullBoardMask)
        #expect(!level.isPlayable(col: coordinate.col, row: coordinate.row))
        #expect(level.jellyAt(col: coordinate.col, row: coordinate.row) == 0)
        #expect(level.playableRows(col: coordinate.col).isEmpty || (0..<7).contains(coordinate.col))
    }

    // guards: bit index r*7+c — every in-range cell of a full-board mask is playable and jellyAt mirrors the jelly array
    @Test func fullBoardCoversAllInRangeCells() throws {
        let level = try #require(LuauLevels.level(id: 14))
        #expect(level.playableCount == 49)
        for row in 0..<7 {
            for col in 0..<7 {
                #expect(level.isPlayable(col: col, row: row))
                #expect(level.jellyAt(col: col, row: row) == Int(level.jelly[row * 7 + col]))
            }
        }
    }

    // guards: bit layout at both extremes of the 49-bit range — single-cell corner masks decode to exactly one playable cell
    @Test(arguments: [(bit: 0, col: 0, row: 0), (bit: 48, col: 6, row: 6)])
    func singleCellCornerMask(corner: (bit: Int, col: Int, row: Int)) {
        var jelly = [UInt8](repeating: 0, count: 49)
        jelly[corner.bit] = 2
        let level = LuauLevel(id: 9990, mask: 1 << UInt64(corner.bit), jelly: jelly,
                              colors: 4, moves: 5, movesHard: 4, seed: 1, archetype: "X")
        #expect(level.playableCount == 1)
        #expect(level.isColumnConvex)
        #expect(level.jellyAt(col: corner.col, row: corner.row) == 2)
        var playable: [(Int, Int)] = []
        for row in 0..<7 {
            for col in 0..<7 where level.isPlayable(col: col, row: row) {
                playable.append((col, row))
            }
        }
        #expect(playable.count == 1)
        #expect(playable.first?.0 == corner.col && playable.first?.1 == corner.row)
    }

    // guards: isColumnConvex rejects a mid-column hole (rows 0 and 2 of col 0 playable, row 1 masked); an all-masked board is vacuously convex
    @Test func midColumnHoleBreaksColumnConvexity() {
        let mask: UInt64 = (1 << 0) | (1 << 14)  // (0,0) and (0,2)
        let level = LuauLevel(id: 9991, mask: mask, jelly: [UInt8](repeating: 0, count: 49),
                              colors: 4, moves: 5, movesHard: 4, seed: 1, archetype: "X")
        #expect(!level.isColumnConvex)
        #expect(level.playableRows(col: 0) == [0, 2])
        let empty = LuauLevel(id: 9994, mask: 0, jelly: [UInt8](repeating: 0, count: 49),
                              colors: 4, moves: 5, movesHard: 4, seed: 1, archetype: "X")
        #expect(empty.isColumnConvex)  // vacuously true — no playable cells, no split
    }

    // guards: parse legend ('#'/'o'/'@'/'.') maps to exact mask bits and jelly layers at row*7+col
    @Test func parseLegendMapsBitsAndJelly() {
        let (mask, jelly) = LuauLevel.parse([
            "#......",
            ".......",
            "...o...",
            ".......",
            ".......",
            ".......",
            "......@",
        ])
        #expect(mask == (1 << 0) | (1 << 17) | (1 << 48))
        #expect(jelly[0] == 0)   // '#': playable, no jelly
        #expect(jelly[17] == 1)  // 'o': jelly x1 at (col 3, row 2)
        #expect(jelly[48] == 2)  // '@': jelly x2 at (6,6)
        #expect(jelly.reduce(0) { $0 + Int($1) } == 3)
        let level = LuauLevel(id: 9992, mask: mask, jelly: jelly, colors: 4,
                              moves: 5, movesHard: 4, seed: 1, archetype: "X")
        #expect(level.isPlayable(col: 0, row: 0))
        #expect(level.isPlayable(col: 3, row: 2))
        #expect(level.jellyAt(col: 6, row: 6) == 2)
        #expect(!level.isPlayable(col: 1, row: 0))
    }

    // guards: playableRows is exact for truncated columns and empty for masked/hostile columns
    @Test func playableRowsOnTruncatedMaskedAndHostileColumns() {
        let well = LuauLevels.debugWell
        #expect(well.playableRows(col: 0) == [0, 1, 2, 3])
        #expect(well.playableRows(col: 2) == [0, 1, 2, 3, 4, 5, 6])
        #expect(well.playableRows(col: -1).isEmpty)
        #expect(well.playableRows(col: 7).isEmpty)
        let (mask, jelly) = LuauLevel.parse([
            "###.###", "###.###", "###.###", "###.###", "###.###", "###.###", "###.###",
        ])
        let channel = LuauLevel(id: 9993, mask: mask, jelly: jelly, colors: 4,
                                moves: 5, movesHard: 4, seed: 1, archetype: "The Channel")
        #expect(channel.playableRows(col: 3).isEmpty)
    }

    // guards: documented hazard — Codable accepts a structurally invalid short-jelly level (no validation); catalog sweep proves shipped data never hits jellyAt's unguarded index
    @Test func codableAcceptsShortJellyWithoutValidation() throws {
        let json = #"{"id":1,"mask":3,"jelly":[1,0],"colors":4,"moves":5,"movesHard":4,"seed":1,"archetype":"X"}"#
        let level = try JSONDecoder().decode(LuauLevel.self, from: Data(json.utf8))
        #expect(level.jelly.count == 2)      // accepted verbatim — jellyAt(high cell) would trap
        #expect(level.playableCount == 2)
        #expect(level.jellyTotal == 1)
        // NOTE: never call level.jellyAt on high cells here — unguarded index.
    }
}

// MARK: - catalog

@MainActor
struct LuauCatalogTests {

    // guards: catalog shape. The campaign is 200 NIGHTS with ids exactly 1...200
    // ascending; LESSONS are interleaved among them and are deliberately NOT
    // nights — they carry ids outside that range so inserting one can never
    // renumber a night or collide with a saved completedLevels entry.
    @Test func catalogShapeAndIDs() {
        let all = LuauLevels.all
        let nights = all.filter { !$0.isLesson }
        let lessons = all.filter(\.isLesson)

        #expect(nights.count == 200)
        #expect(nights.map(\.id) == Array(1...200))
        #expect(LuauLevels.handAuthored.filter { !$0.isLesson }.map(\.id) == Array(1...12))
        #expect(LuauLevels.generated.count == 188)
        #expect(LuauLevels.generated.allSatisfy { !$0.isLesson })

        // The invariant that protects saved progress: no lesson id may ever land
        // inside the night range, and none may shadow a debug fixture.
        let nightIDs = Set(nights.map(\.id))
        #expect(lessons.allSatisfy { !nightIDs.contains($0.id) },
                "a lesson id inside 1...200 would collide with a night in completedLevels")
        #expect(lessons.allSatisfy { !(1...200).contains($0.id) })
        #expect(Set(lessons.map(\.id)).count == lessons.count, "lesson ids must be unique")

        // Night numbering ignores lessons entirely, so the level after a lesson
        // keeps the number it had before the lesson existed.
        #expect(LuauLevels.nightNumber(of: 5) == 5)
        #expect(LuauLevels.nightNumber(of: 200) == 200)
        #expect(lessons.allSatisfy { LuauLevels.nightNumber(of: $0.id) == nil })

        #expect(LuauLevels.debugFixtures.map(\.id) == [1001, 1002, 1003, 1004, 1005])
        let campaignIDs = Set(all.map(\.id))
        #expect(LuauLevels.debugFixtures.allSatisfy { !campaignIDs.contains($0.id) })
    }

    // guards: level(id:) resolves every shipped id (campaign + DEBUG fixtures) to a level with a matching id
    @Test(arguments: [1, 12, 13, 200, 1001, 1004, 1005])
    func levelLookupResolvesValidIDs(id: Int) throws {
        let level = try #require(LuauLevels.level(id: id))
        #expect(level.id == id)
    }

    // guards: level(id:) totality — hostile and off-by-one ids return nil, no trap
    @Test(arguments: [0, 201, -1, 1000, 1006, Int.min, Int.max])
    func levelLookupRejectsInvalidIDs(id: Int) {
        #expect(LuauLevels.level(id: id) == nil)
    }

    // guards: per-level structure for all 204 shipped levels — mask fits 49 bits (replaces the self-test's tautological bit-count check), jelly shape/values, budgets, seeds, archetypes, convexity
    @Test func perLevelStructuralInvariants() {
        for level in LuauLevels.all + LuauLevels.debugFixtures {
            #expect(level.mask != 0, "level \(level.id)")
            #expect(level.mask >> 49 == 0, "level \(level.id): mask bits above cell 48")
            #expect(level.jelly.count == LuauLevel.cellCount, "level \(level.id)")
            #expect(level.jelly.allSatisfy { $0 <= 2 }, "level \(level.id)")
            // A cargo-only level is legal — delivery is an objective too.
            #expect(level.jellyTotal + level.ingredientTotal > 0,
                    "level \(level.id): would insta-win")
            for i in level.ingredientCells {
                #expect((0..<LuauLevel.cellCount).contains(i),
                        "level \(level.id): cargo index out of range")
                #expect(level.isPlayable(col: i % 7, row: i / 7),
                        "level \(level.id): cargo on a masked cell")
                // Cargo may only START in a column that reaches the shore —
                // the authoring half of the invariant whose engine half is
                // `canShove`'s drains check. Together they make stranding
                // impossible without any reachability search.
                #expect(level.drains(col: i % 7),
                        "level \(level.id): cargo starts in a column that never drains")
                #expect(i / 7 != LuauLevel.size - 1,
                        "level \(level.id): cargo starts already delivered")
            }
            #expect(Set(level.ingredientCells).count == level.ingredientCells.count,
                    "level \(level.id): duplicate cargo index")
            for i in 0..<LuauLevel.cellCount where level.jelly[i] > 0 {
                #expect(level.isPlayable(col: i % 7, row: i / 7),
                        "level \(level.id): jelly on masked cell \(i)")
            }
            #expect((4...6).contains(level.colors), "level \(level.id)")
            #expect(level.movesHard > 0 && level.movesHard <= level.moves,
                    "level \(level.id): movesHard==moves is legal, > is not")
            #expect(level.seed != 0, "level \(level.id)")
            // Lessons are scripted demonstrations, not generated campaign
            // shapes, so they are exempt from the archetype whitelist.
            if !level.isLesson {
                #expect(knownArchetypes.contains(level.archetype), "level \(level.id): \(level.archetype)")
            }
            #expect(level.isColumnConvex, "level \(level.id)")
        }
    }

    // guards: Stage C ordering — no archetype twice in adjacent levels from id 13 on (includes the 12->13 boundary; the L1-L5 teaching arc legitimately repeats)
    @Test func generatedAdjacentArchetypesNeverRepeat() {
        let all = LuauLevels.all
        for i in 1..<all.count where all[i].id >= 13 {
            #expect(all[i].archetype != all[i - 1].archetype,
                    "ids \(all[i - 1].id)->\(all[i].id) repeat \(all[i].archetype)")
        }
    }

    // guards: no two campaign levels share the (mask, jelly, seed) triple — a duplicate would ship the same run twice
    @Test func noDuplicateMaskJellySeedTriples() {
        var seen = Set<String>()
        for level in LuauLevels.all {
            let key = "\(level.mask)|\(level.jelly.map(String.init).joined(separator: ","))|\(level.seed)"
            #expect(seen.insert(key).inserted, "level \(level.id) duplicates an earlier level")
        }
    }

    // guards: every shipped mask admits a 3-in-line of playable cells — the only guard against the fillFreshBoard<->shuffle infinite recursion (a mask without this geometry hangs newLevel; not executed here by design)
    @Test func everyMaskAdmitsThreeInLineGeometry() {
        for level in LuauLevels.all + LuauLevels.debugFixtures {
            var hasRun = false
            for row in 0..<7 {
                for col in 0..<5 where level.isPlayable(col: col, row: row)
                    && level.isPlayable(col: col + 1, row: row)
                    && level.isPlayable(col: col + 2, row: row) {
                    hasRun = true
                }
            }
            for col in 0..<7 {
                for row in 0..<5 where level.isPlayable(col: col, row: row)
                    && level.isPlayable(col: col, row: row + 1)
                    && level.isPlayable(col: col, row: row + 2) {
                    hasRun = true
                }
            }
            #expect(hasRun, "level \(level.id): no 3-in-line geometry — newLevel would hang")
        }
    }

    // guards: fillFreshBoard postconditions for every shipped level — right piece count on unique playable cells, kinds in 0..<colors, no specials, full move budget, no pre-existing match, a legal swap, jelly initialized from the level
    @Test func everyShippedLevelBuildsALegalBoard() {
        for level in LuauLevels.all + LuauLevels.debugFixtures {
            let game = LuauGame()
            game.newLevel(level, attempt: 1)
            #expect(game.pieces.count == level.playableCount, "level \(level.id)")
            #expect(Set(game.pieces.map { $0.row * 7 + $0.col }).count == game.pieces.count,
                    "level \(level.id): two pieces share a cell")
            #expect(game.pieces.allSatisfy { level.isPlayable(col: $0.col, row: $0.row) },
                    "level \(level.id): piece on masked cell")
            #expect(game.pieces.allSatisfy {
                LuauGame.isIngredient($0) || (0..<level.colors).contains($0.kind)
            }, "level \(level.id): kind outside 0..<colors")
            // Cargo placement is pinned exactly where board legality is pinned:
            // it overwrites pieces from the fresh fill, so a silent miss here
            // would ship a level whose objective cannot be met.
            #expect(game.pieces.filter(LuauGame.isIngredient).count == level.ingredientTotal,
                    "level \(level.id): cargo count != declared")
            #expect(game.hasLegalSwap, "level \(level.id): fresh board has no move")
            #expect(game.pieces.allSatisfy { $0.special == .none },
                    "level \(level.id): fresh fill spawned a special")
            #expect(game.movesLeft == level.moves, "level \(level.id)")
            #expect(game.hasLegalSwap, "level \(level.id)")
            let before = boardSignature(game)
            #expect(!game.resolveStep(), "level \(level.id): fresh board has a pre-existing match")
            #expect(boardSignature(game) == before, "level \(level.id): settle mutated a fresh board")
            #expect(game.jellyRemaining == level.jellyTotal, "level \(level.id)")
            #expect(game.jelly == level.jelly, "level \(level.id)")
        }
    }
}

// MARK: - lifecycle + determinism

@MainActor
struct LuauGameLifecycleTests {

    // guards: seeded determinism — identical (level, attempt) yields identical fill, different attempt yields a different fill
    @Test func seededFillDeterminism() {
        let a = LuauGame(); a.newLevel(LuauLevels.debugL1, attempt: 42)
        let b = LuauGame(); b.newLevel(LuauLevels.debugL1, attempt: 42)
        let c = LuauGame(); c.newLevel(LuauLevels.debugL1, attempt: 43)
        #expect(boardSignature(a) == boardSignature(b))
        #expect(boardSignature(a) != boardSignature(c))
    }

    // guards: retryLevel is exactly newLevel(level, attempt: attemptSeed &+ 1)
    @Test func retryLevelSaltsAttempt() {
        let a = LuauGame(); a.newLevel(LuauLevels.debugL1, attempt: 1)
        a.retryLevel()
        let b = LuauGame(); b.newLevel(LuauLevels.debugL1, attempt: 2)
        #expect(a.attemptSeed == 2)
        #expect(boardSignature(a) == boardSignature(b))
    }

    // guards: attempt salt uses wrapping arithmetic — UInt64.max does not trap and retry wraps to attempt 0
    @Test func attemptSaltWrapsAtUInt64Max() {
        let a = LuauGame(); a.newLevel(LuauLevels.debugL1, attempt: UInt64.max)
        #expect(a.attemptSeed == UInt64.max)
        a.retryLevel()
        #expect(a.attemptSeed == 0)
        let b = LuauGame(); b.newLevel(LuauLevels.debugL1, attempt: 0)
        #expect(boardSignature(a) == boardSignature(b))
    }

    // guards: whole-run determinism — two full bot playthroughs of the same (level, attempt) produce identical trajectories (a divergence means a stray system-RNG call leaked into level mode)
    @Test func wholeRunBotTrajectoryIsDeterministic() throws {
        let level = try #require(LuauLevels.level(id: 13))
        func run() -> (turns: Int, score: Int, movesLeft: Int, jelly: [UInt8], sig: String) {
            let game = LuauGame()
            game.newLevel(level, attempt: 1)
            let turns = LuauBot.playToEnd(in: game)
            return (turns, game.score, game.movesLeft, game.jelly, boardSignature(game))
        }
        let first = run()
        let second = run()
        #expect(first.turns == second.turns)
        #expect(first.score == second.score)
        #expect(first.movesLeft == second.movesLeft)
        #expect(first.jelly == second.jelly)
        #expect(first.sig == second.sig)
    }

    // guards: newLevel mid-run fully resets score/moves/jelly/flags to the new level's fresh state
    @Test func newLevelFullyResetsMidRunState() throws {
        let level13 = try #require(LuauLevels.level(id: 13))
        let game = LuauGame()
        game.newLevel(level13, attempt: 1)
        LuauBot.playToEnd(in: game, maxTurns: 3)
        #expect(game.score > 0)  // precondition: the run actually mutated state
        game.newLevel(LuauLevels.debugL1, attempt: 7)
        #expect(game.currentLevel?.id == 1001)
        #expect(game.score == 0)
        #expect(game.movesLeft == LuauLevels.debugL1.moves)
        #expect(game.jelly == LuauLevels.debugL1.jelly)
        #expect(game.jellyRemaining == 3)
        #expect(!game.isOver && !game.didWinLevel)
        #expect(game.attemptSeed == 7)
        #expect(game.lastCascade == 0)
        #expect(game.pieces.count == 49)
    }

    // guards: newGame clears level state and jelly but PRESERVES lifetime completedLevels
    @Test func newGamePreservesCompletedLevelsAndClearsLevelState() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.testSetJelly([UInt8](repeating: 0, count: 49))
        settle(game)
        #expect(game.completedLevels == [1001])
        game.newGame()
        #expect(game.completedLevels == [1001])
        #expect(game.currentLevel == nil)
        #expect(game.jelly == [UInt8](repeating: 0, count: 49))
        #expect(game.pieces.count == 49)
        #expect(game.score == 0)
        #expect(game.movesLeft == LuauGame.movesPerRun)
        #expect(!game.isOver && !game.didWinLevel)
    }

    // guards: retryLevel with no current level is a strict no-op (state untouched)
    @Test func retryLevelInEndlessModeIsNoOp() {
        let game = LuauGame()
        game.newGame()
        game.testSetScore(33)
        let before = GameSnapshot(game)
        game.retryLevel()
        #expect(GameSnapshot(game) == before)
        #expect(game.currentLevel == nil)
    }

    // guards: completedLevels stays sorted and duplicate-free across repeated completion calls and out-of-order wins
    @Test func levelCompletionIsIdempotentAndSorted() throws {
        let level5 = try #require(LuauLevels.level(id: 5))
        let level2 = try #require(LuauLevels.level(id: 2))
        let game = LuauGame()
        game.newLevel(level5, attempt: 1)
        game.testSetJelly([UInt8](repeating: 0, count: 49))
        settle(game)
        #expect(game.completedLevels == [5])
        game.markCurrentLevelComplete()
        game.markCurrentLevelComplete()
        #expect(game.completedLevels == [5])
        game.newLevel(level2, attempt: 1)
        game.testSetJelly([UInt8](repeating: 0, count: 49))
        settle(game)
        #expect(game.completedLevels == [2, 5])
    }

    // guards: lose edge — movesLeft 0 with jelly remaining is a loss, and pickMove returns nil on a terminal board
    @Test func loseEdgeKeepsJellyAndStopsBot() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.testSetMovesLeft(0)
        settle(game)
        #expect(game.isOver && !game.didWinLevel)
        #expect(game.jellyRemaining > 0)
        #expect(LuauBot.pickMove(for: game) == nil)
    }
}

// MARK: - swaps + resolution

enum RejectedSwapCase: String, CaseIterable {
    // noMatchAdjacent left this list when whiffs started costing a move —
    // that contract lives in whiffedSwapSpendsTheMoveAndNothingElse below.
    case sameCell, diagonal, distanceTwo, offBoardNegative, offBoardHigh,
         maskedTarget, afterGameOver, afterGameOverWithMovesLeft
}

enum JellyClearPath: String, CaseIterable {
    case plainMatch, triggeredTorch, catSwap, comboTorchTorch
}

@MainActor
struct LuauSwapResolveTests {

    // guards: every REJECTED gesture is a pure no-op — zero mutation of pieces/score/moves/jelly/beats for hostile pairs, off-board cells, masked targets, and terminal boards; the isOver latch alone must reject a genuinely matching swap even with moves in hand. (A legal adjacent WHIFF is not a rejection — it spends; see the whiff tests below.)
    @Test(arguments: RejectedSwapCase.allCases)
    func rejectedSwapsMutateNothing(rejection: RejectedSwapCase) {
        let game = LuauGame()
        let pair: ((col: Int, row: Int), (col: Int, row: Int))
        switch rejection {
        case .sameCell:
            game.newLevel(LuauLevels.debugL1, attempt: 1)
            carpetNoLegalSwaps(game)
            pair = ((3, 3), (3, 3))
        case .diagonal:
            game.newLevel(LuauLevels.debugL1, attempt: 1)
            carpetNoLegalSwaps(game)
            pair = ((0, 0), (1, 1))
        case .distanceTwo:
            game.newLevel(LuauLevels.debugL1, attempt: 1)
            carpetNoLegalSwaps(game)
            pair = ((0, 0), (2, 0))
        case .offBoardNegative:
            game.newLevel(LuauLevels.debugL1, attempt: 1)
            carpetNoLegalSwaps(game)
            pair = ((-1, 0), (0, 0))
        case .offBoardHigh:
            game.newLevel(LuauLevels.debugL1, attempt: 1)
            carpetNoLegalSwaps(game)
            pair = ((7, 3), (6, 3))
        case .maskedTarget:
            game.newLevel(LuauLevels.debugWell, attempt: 1)
            pair = ((0, 3), (0, 4))  // (0,4) is masked on The Well
        case .afterGameOver:
            game.newLevel(LuauLevels.debugL1, attempt: 1)
            game.testSetMovesLeft(0)
            settle(game)
            pair = ((0, 0), (1, 0))
        case .afterGameOverWithMovesLeft:
            // Isolates the !isOver guard: latch game over, then hand moves back
            // so ONLY the latch can reject — and plant a swap that WOULD match,
            // so a mutant dropping !isOver accepts it and mutates the snapshot.
            game.newLevel(LuauLevels.debugL1, attempt: 1)
            game.testSetMovesLeft(0)
            settle(game)
            carpetNoLegalSwaps(game)
            game.testSetKind(0, col: 1, row: 0)
            game.testSetKind(1, col: 2, row: 0)
            game.testSetKind(0, col: 3, row: 0)
            game.testSetKind(0, col: 2, row: 1)
            game.testSetMovesLeft(5)  // testSetMovesLeft never un-latches isOver
            pair = ((2, 0), (2, 1))   // would complete row 0 cols 1-3
        }
        let before = GameSnapshot(game)
        #expect(!game.attemptSwap(pair.0, pair.1))
        #expect(GameSnapshot(game) == before)
    }

    // guards: play order is POSITIONAL, not id arithmetic. This is what lets a
    // teaching level carry an id outside the 1...200 campaign range and still be
    // inserted between two nights — renumbering to make room is impossible,
    // because completedLevels persists IDs and shifting them would hand every
    // existing player someone else's progress.
    @Test func playOrderIsPositionalAndToleratesUnknownIds() {
        let all = LuauLevels.all
        #expect(LuauLevels.playIndex(of: all[0].id) == 0)
        #expect(LuauLevels.playIndex(of: all[4].id) == 4)
        #expect(LuauLevels.playIndex(of: 987_654) == nil)

        // Frontier is one PAST the furthest position reached, and reads
        // positions rather than max(id).
        #expect(LuauLevels.frontierIndex(completed: []) == 0)
        #expect(LuauLevels.frontierIndex(completed: [all[0].id]) == 1)
        #expect(LuauLevels.frontierIndex(completed: [all[3].id, all[1].id]) == 4)

        // An id that is not in the campaign — a teaching level from a build that
        // has since removed it, or corrupt save data — must be IGNORED, never
        // allowed to run the frontier off the end or drag it backwards.
        #expect(LuauLevels.frontierIndex(completed: [987_654]) == 0)
        #expect(LuauLevels.frontierIndex(completed: [all[2].id, 987_654]) == 3)

        // Stepping is positional too, and terminates.
        #expect(LuauLevels.next(after: all[0].id)?.id == all[1].id)
        #expect(LuauLevels.next(after: all[all.count - 1].id) == nil)
        #expect(LuauLevels.next(after: 987_654) == nil)

        // Frontier level clamps at the end rather than falling off it.
        let allDone = all.map(\.id)
        #expect(LuauLevels.frontierLevel(completed: allDone)?.id == all[all.count - 1].id)
    }

    // guards: the WHIFF contract — a legal piece-to-piece attempt that makes no match
    // reverts the board and is FREE. Only a swap that clears something spends.
    // Every other observable stays untouched, exactly as for a rejection.
    @Test func whiffedSwapIsFreeAndChangesNothing() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        carpetNoLegalSwaps(game)
        let before = GameSnapshot(game)
        #expect(!game.attemptSwap((3, 3), (3, 4)))  // adjacent; carpet admits no match
        #expect(game.movesLeft == before.movesLeft, "a whiff must not spend")
        #expect(game.pieces == before.pieces)
        #expect(game.score == before.score)
        #expect(game.jelly == before.jelly)
        #expect(!game.isOver)
        #expect(game.clearBeat == before.clearBeat)
        #expect(game.fireBeat == before.fireBeat)
        #expect(game.shuffleBeat == before.shuffleBeat)
        #expect(game.cascadeBeat == before.cascadeBeat)
    }

    // guards: a whiff on the FINAL move now ends NOTHING. It is free, so it cannot
    // drive movesLeft to 0, which is what the old in-place loss latch existed to
    // rescue (no resolution follows an uncommitted swap, so isOver would never
    // fire and the run would soft-lock). The last move stays in hand.
    @Test func whiffOnFinalMoveIsFreeAndEndsNothing() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        carpetNoLegalSwaps(game)
        game.testSetMovesLeft(1)
        #expect(!game.attemptSwap((3, 3), (3, 4)))
        #expect(game.movesLeft == 1, "the final move survives a whiff")
        #expect(!game.isOver)
        #expect(!game.didWinLevel)
        #expect(game.lastSpareBonus == 0)
        #expect(game.completedLevels.isEmpty)
    }

    // guards: endless behaves identically — a free whiff ends nothing there either
    @Test func whiffOnFinalMoveEndlessEndsNothing() {
        let game = LuauGame()
        game.newGame()
        carpetNoLegalSwaps(game)
        game.testSetMovesLeft(1)
        #expect(!game.attemptSwap((3, 3), (3, 4)))
        #expect(game.movesLeft == 1)
        #expect(!game.isOver)
    }

    // guards: coach fumbles cost nothing at all now — the whiff is free, so a
    // fumbling new player cannot even burn the chip, let alone end the night
    @Test func coachWhiffNeverEndsTheRun() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.seedTutorialBoard(round: 0)
        game.testSetMovesLeft(1)
        // (0,0)<->(1,0): checkerboard corner, guaranteed matchless swap.
        #expect(!game.attemptSwap((0, 0), (1, 0)))
        #expect(game.movesLeft == 1)
        #expect(!game.isOver)
        #expect(!game.didWinLevel)
    }

    // guards: resolveStep on a settled board with a legal swap is idempotent — returns false and mutates nothing (no shuffle while hasLegalSwap)
    @Test func resolveStepIsIdempotentOnceSettled() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        #expect(game.hasLegalSwap)
        let before = GameSnapshot(game)
        for _ in 0..<10 {
            #expect(!game.resolveStep())
        }
        #expect(GameSnapshot(game) == before)
    }

    // guards: masked gravity — the fresh fill AND post-clear gravity/refill land pieces on exactly the playable rows of masked boards, including top-truncated columns (refill must enter at the top of each column's playable run, not absolute row 0)
    @Test func maskedGravityFillsExactPlayableRows() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugWell, attempt: 1)
        for col in 0..<7 {
            let expected = Set(LuauLevels.debugWell.playableRows(col: col))
            let actual = Set(game.pieces.filter { $0.col == col }.map(\.row))
            #expect(actual == expected, "col \(col)")
        }
        // Post-clear gravity + refill on The Well: clear a bottom H3, settle,
        // and every column must fill exactly its playable rows again.
        carpetNoLegalSwaps(game)
        game.testSetKind(0, col: 2, row: 6)
        game.testSetKind(0, col: 3, row: 6)
        game.testSetKind(0, col: 4, row: 6)
        #expect(game.resolveStep())
        settle(game)
        for col in 0..<7 {
            let expected = Set(LuauLevels.debugWell.playableRows(col: col))
            let actual = Set(game.pieces.filter { $0.col == col }.map(\.row))
            #expect(actual == expected, "well col \(col) after clear")
        }
        #expect(game.pieces.count == LuauLevels.debugWell.playableCount)
        // Top-truncated fixture: col 0's playable run starts at row 1, so a
        // refill entering at absolute row indices would drop a piece onto the
        // masked row 0 and strand a hole at the bottom of the run.
        let (mask, jelly) = LuauLevel.parse([
            ".#####.",
            "#######",
            "#######",
            "###o###",
            "#######",
            "#######",
            "#######",
        ])
        let notch = LuauLevel(id: 9902, mask: mask, jelly: jelly, colors: 4,
                              moves: 20, movesHard: 15, seed: 0xD00D_F00D_BAAD_5EED,
                              archetype: "The Headland")
        game.newLevel(notch, attempt: 1)
        carpetNoLegalSwaps(game)
        game.testSetKind(0, col: 0, row: 2)
        game.testSetKind(0, col: 0, row: 3)
        game.testSetKind(0, col: 0, row: 4)
        #expect(game.resolveStep())
        settle(game)
        for col in 0..<7 {
            #expect(Set(game.pieces.filter { $0.col == col }.map(\.row))
                    == Set(notch.playableRows(col: col)), "notch col \(col)")
        }
        #expect(game.pieces.count == notch.playableCount)
    }

    // guards: the -9 sentinel breaks runs at masked columns — a right-reef 3-match clears without disturbing the left reef
    @Test func matchesNeverSpanMaskedColumn() {
        let (mask, jelly) = LuauLevel.parse([
            "###.###", "###.###", "###.###", "###.###", "###.###", "###.###", "###.###",
        ])
        let channel = LuauLevel(id: 9901, mask: mask, jelly: jelly, colors: 4,
                                moves: 20, movesHard: 15, seed: 0xCAFE_BABE_DEAD_C0DE,
                                archetype: "The Channel")
        let game = LuauGame()
        game.newLevel(channel, attempt: 1)
        #expect(game.pieces.count == 42)
        #expect(game.pieces.allSatisfy { $0.col != 3 })
        // Match-free, swap-free base (a uniform carpet would self-match).
        carpetNoLegalSwaps(game)
        // Left reef: 5,5,6 — right reef: 5,5,5. A horizontal 5,5,6,[mask],5,5,5
        // must clear ONLY the right reef.
        game.testSetKind(5, col: 0, row: 3)
        game.testSetKind(5, col: 1, row: 3)
        game.testSetKind(6, col: 2, row: 3)
        game.testSetKind(5, col: 4, row: 3)
        game.testSetKind(5, col: 5, row: 3)
        game.testSetKind(5, col: 6, row: 3)
        #expect(game.resolveStep())
        #expect(game.piece(at: 0, 3)?.kind == 5)
        #expect(game.piece(at: 1, 3)?.kind == 5)
        #expect(game.piece(at: 2, 3)?.kind == 6)
        // The right reef itself cleared (refill enters at row 0 only, so
        // these cells now hold former carpet pieces, never kind 5).
        #expect([4, 5, 6].allSatisfy { game.piece(at: $0, 3)?.kind != 5 })
    }

    // guards: jelly decrements on every clear path and jellyRemaining never increases at any intermediate resolve step
    @Test(arguments: JellyClearPath.allCases)
    func jellyClearPathsDecrementAndNeverRegress(path: JellyClearPath) {
        // debugL1 jelly sits at indices 23/24/25 = (2,3),(3,3),(4,3).
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        carpetNoLegalSwaps(game)
        switch path {
        case .plainMatch:
            game.testSetKind(0, col: 2, row: 3)
            game.testSetKind(0, col: 3, row: 3)
            game.testSetKind(0, col: 4, row: 3)
            #expect(game.resolveStep())
            #expect(game.jelly[23] == 0 && game.jelly[24] == 0 && game.jelly[25] == 0)
        case .triggeredTorch:
            game.testSetKind(0, col: 2, row: 3)
            game.testSetKind(0, col: 4, row: 3)
            game.testSetPiece(kind: 0, special: .lineV, col: 3, row: 3)
            #expect(game.resolveStep())
            #expect(game.fireBeat >= 1)  // the torch lane actually fired
            #expect(game.jelly[23] == 0 && game.jelly[24] == 0 && game.jelly[25] == 0)
        case .catSwap:
            game.testSetKind(0, col: 2, row: 3)
            game.testSetKind(0, col: 4, row: 3)
            game.testSetPiece(kind: -1, special: .cat, col: 2, row: 2)
            #expect(game.attemptSwap((2, 2), (2, 3)))
            // Cat wipes every kind-0 piece: jelly under (2,3) and (4,3) clears, (3,3) survives.
            #expect(game.jelly[23] == 0 && game.jelly[25] == 0)
            #expect(game.jelly[24] == 1)
        case .comboTorchTorch:
            game.testSetPiece(kind: 0, special: .lineV, col: 3, row: 3)
            game.testSetPiece(kind: 0, special: .lineH, col: 3, row: 4)
            #expect(game.attemptSwap((3, 3), (3, 4)))
            // torchCross clears row 4 + col 3: only (3,3)'s jelly is on the cross.
            #expect(game.jelly[24] == 0)
            #expect(game.jelly[23] == 1 && game.jelly[25] == 1)
        }
        var previous = game.jellyRemaining
        var steps = 0
        while steps < 300, game.resolveStep() {
            #expect(game.jellyRemaining <= previous, "jelly regrew mid-cascade")
            previous = game.jellyRemaining
            steps += 1
        }
        #expect(steps < 300)
    }

    // guards: move + score accounting across a full seeded run — one move per accepted swap, resolveStep never touches movesLeft in level mode, every score increase equals lastGain; the win-latching settle pays exactly the spare-move bonus
    @Test func scoreAndMoveAccountingAcrossSeededRun() throws {
        let level = try #require(LuauLevels.level(id: 13))
        let game = LuauGame()
        game.newLevel(level, attempt: 1)
        var turns = 0
        while !game.isOver, turns < 60 {
            guard let move = LuauBot.pickMove(for: game) else { break }
            let movesBefore = game.movesLeft
            let scoreBefore = game.score
            #expect(game.attemptSwap(move.0, move.1))
            #expect(game.movesLeft == movesBefore - 1)
            let swapDelta = game.score - scoreBefore
            #expect(swapDelta == 0 || swapDelta == game.lastGain)  // cat/combo swaps score inside attemptSwap
            var steps = 0
            while steps < 300 {
                let stepScore = game.score
                let stepMoves = game.movesLeft
                let cleared = game.resolveStep()
                #expect(game.movesLeft == stepMoves, "resolveStep changed movesLeft in level mode")
                if cleared {
                    #expect(game.score - stepScore == game.lastGain)
                    #expect(game.score >= stepScore)
                } else if game.isOver, game.didWinLevel {
                    // The settle that latches a WIN pays out the unused
                    // moves — and nothing else.
                    #expect(game.lastSpareBonus == game.movesLeft * LuauGame.spareMoveBonus)
                    #expect(game.score == stepScore + game.lastSpareBonus)
                    break
                } else {
                    #expect(game.score == stepScore)
                    break
                }
                steps += 1
            }
            turns += 1
        }
        #expect(game.isOver)  // level 13, attempt 1 finishes (verified deterministic)
        #expect(game.encoreBeat == 0)
        #expect(game.movesLeft >= 0)
    }

    // ENCORE latch coverage (once-per-run, level-mode suppression, tutorial
    // suppression) is canonical in LuauGameAdversarialTests' LuauEncoreTests;
    // the restore-side 699/700 boundary is caseBEncoreLatchBoundary below.
}

// MARK: - save/restore

@MainActor
struct LuauRestoreTests {

    // guards: every undecodable payload falls back to a fresh endless game with no partial state, and preserves in-memory completedLevels (matching the newGame path)
    @Test(arguments: [
        nil, "", "not json", "{}", "[]",
        #"{"seenHowTo":true}"#,                                  // missing required score/movesLeft
        #"{"seenHowTo":true,"score":"high","movesLeft":3}"#,     // wrong type
        #"{"seenHowTo":true,"score":7,"movesLeft":5,"jelly":[300]}"#,  // 300 does not fit UInt8
        #"{"seenHowTo":true,"score":7,"movesLeft":5,"jelly":[-1]}"#,   // negative jelly
    ] as [String?])
    func undecodablePayloadFallsBackToFreshEndless(payload: String?) {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.testSetJelly([UInt8](repeating: 0, count: 49))
        settle(game)
        #expect(game.completedLevels == [1001])
        let result = game.restore(from: payload)
        #expect(result == nil)
        #expect(game.currentLevel == nil)
        #expect(game.pieces.count == 49)
        #expect(game.score == 0)
        #expect(game.movesLeft == LuauGame.movesPerRun)
        #expect(!game.isOver)
        #expect(game.jelly == [UInt8](repeating: 0, count: 49))
        #expect(game.completedLevels == [1001])  // full-decode failure preserves lifetime progress
    }

    // guards: mid-level payload round-trips level id, score, moves, jelly, pieces, and attempt salt field-for-field
    @Test func midLevelPayloadRoundTrips() {
        let a = LuauGame()
        a.newLevel(LuauLevels.debugL1, attempt: 5)
        a.testSetScore(120)
        a.testSetMovesLeft(11)
        let b = LuauGame()
        let result = b.restore(from: a.payload(seenHowTo: true))
        #expect(result != nil)
        #expect(b.currentLevel?.id == 1001)
        #expect(b.score == 120)
        #expect(b.movesLeft == 11)
        #expect(b.jelly == a.jelly)
        #expect(b.pieces == a.pieces)
        #expect(b.attemptSeed == 5)
        #expect(!b.isOver && !b.didWinLevel)
    }

    // guards: a won level saves board=nil by design — restore drops to a fresh endless game while completedLevels carries the id
    @Test func wonLevelPayloadDropsToEndless() {
        let a = LuauGame()
        a.newLevel(LuauLevels.debugL1, attempt: 1)
        a.testSetJelly([UInt8](repeating: 0, count: 49))
        settle(a)
        #expect(a.isOver && a.didWinLevel)
        let b = LuauGame()
        let result = b.restore(from: a.payload(seenHowTo: true))
        #expect(result != nil)
        #expect(b.currentLevel == nil)
        #expect(b.pieces.count == 49)
        #expect(b.score == 0)
        #expect(b.completedLevels.contains(1001))
    }

    // guards: an endless mid-run payload round-trips through Case B with pieces/score/moves intact
    @Test func endlessMidRunPayloadRoundTrips() {
        let a = LuauGame()
        a.newGame()
        a.testSetScore(345)
        a.testSetMovesLeft(9)
        let b = LuauGame()
        let result = b.restore(from: a.payload(seenHowTo: true))
        #expect(result != nil)
        #expect(b.currentLevel == nil)
        #expect(b.score == 345)
        #expect(b.movesLeft == 9)
        #expect(b.pieces == a.pieces)
        #expect(b.jelly == [UInt8](repeating: 0, count: 49))
    }

    // guards: the flip side of atomic corruption rejection — "bomb" is a LIVE
    // raw value again (the special returned 2026-07-31 with the L/T faucet),
    // so a save carrying bombs loads them AS bombs, score intact. This test
    // used to pin the opposite: during the bomb's exile the value sat in
    // Special.retired and decoded to .none so square-era saves wouldn't be
    // destroyed. If the bomb is ever cut again, resurrect that shim —
    // deleting the case without it fails whole payloads and restore answers
    // with newGame(), taking the player's campaign with it.
    @Test func bombRawValueLoadsLiveInASave() {
        let a = LuauGame()
        a.newGame()
        a.testSetScore(50)
        let withBomb = a.payload(seenHowTo: true)
            .replacingOccurrences(of: #""special":"none""#, with: #""special":"bomb""#)
        #expect(withBomb.contains("bomb"))  // precondition
        let b = LuauGame()
        let result = b.restore(from: withBomb)
        #expect(result != nil, "a save holding bombs must load")
        #expect(b.score == 50, "and must keep the run it was carrying")
        #expect(b.pieces.allSatisfy { $0.special == .bomb },
                "every piece was rewritten to a bomb, so every piece loads as one")
    }

    @Test func corruptSpecialRawValueRejectsWholePayload() {
        let a = LuauGame()
        a.newGame()
        a.testSetScore(50)
        let corrupted = a.payload(seenHowTo: true)
            .replacingOccurrences(of: #""special":"none""#, with: #""special":"nøne""#)
        #expect(corrupted.contains("nøne"))  // precondition: the payload was actually corrupted
        let b = LuauGame()
        let result = b.restore(from: corrupted)
        #expect(result == nil)
        #expect(b.currentLevel == nil)
        #expect(b.score == 0)
        #expect(b.movesLeft == LuauGame.movesPerRun)
        #expect(b.pieces.count == 49)
    }

    // guards: Case A jelly-length guard — a 48-entry jelly on a non-full-board level routes to fresh endless (board 37 pieces can't hijack Case B) while payload completedLevels still applies
    @Test func wrongJellyLengthNonFullBoardFallsToFreshEndless() throws {
        let level = try #require(LuauLevels.level(id: 13))
        #expect(level.playableCount < 49)
        let a = LuauGame()
        a.newLevel(level, attempt: 1)
        var payload = try decodePayload(a.payload(seenHowTo: true))
        payload.jelly = Array(try #require(payload.jelly).dropLast())
        payload.completedLevels = [3, 7]
        let b = LuauGame()
        let result = b.restore(from: try encodePayload(payload))
        #expect(result != nil)
        #expect(b.currentLevel == nil)
        #expect(b.pieces.count == 49)
        #expect(b.score == 0)
        #expect(b.movesLeft == LuauGame.movesPerRun)
        #expect(b.completedLevels == [3, 7])
    }

    // guards: a level payload that fails Case A validation must fall to a FRESH endless game (the documented behavior) — not resume the level's board/score as a mid-endless run
    @Test func invalidLevelPayloadMustNotHijackEndlessResume() throws {
        // Scenario 1: full-board level (49 pieces) with a corrupt jelly length.
        let fullBoard = try #require(LuauLevels.level(id: 14))
        #expect(fullBoard.playableCount == 49)
        let a = LuauGame()
        a.newLevel(fullBoard, attempt: 1)
        a.testSetScore(555)
        var payload = try decodePayload(a.payload(seenHowTo: true))
        payload.jelly = Array(try #require(payload.jelly).dropLast())
        let b = LuauGame()
        _ = b.restore(from: try encodePayload(payload))
        #expect(b.currentLevel == nil)
        // SUSPECTED-BUG(restore-case-b-hijack): expected to FAIL until product fix.
        #expect(b.score == 0, "level save resumed as mid-endless run carrying score")
        #expect(b.movesLeft == LuauGame.movesPerRun, "level save resumed carrying the level's movesLeft")

        // Scenario 2: unknown levelID with a 49-piece board.
        payload = try decodePayload(a.payload(seenHowTo: true))
        payload.levelID = 999
        payload.completedLevels = [4]
        let c = LuauGame()
        _ = c.restore(from: try encodePayload(payload))
        #expect(c.currentLevel == nil)
        #expect(c.completedLevels == [4])  // lifetime progress survives the fall-through
        // SUSPECTED-BUG(restore-case-b-hijack): expected to FAIL until product fix.
        #expect(c.score == 0, "unknown-level save resumed as mid-endless run carrying score")
    }

    // guards: the engine must never hold two pieces on one cell — restore must reject a board with duplicate positions (gravity and piece(at:) corrupt otherwise)
    @Test func restoreRejectsBoardsWithOverlappingPieces() throws {
        let level = try #require(LuauLevels.level(id: 14))
        let a = LuauGame()
        a.newLevel(level, attempt: 1)
        var payload = try decodePayload(a.payload(seenHowTo: true))
        var board = try #require(payload.board)
        board[0].col = board[1].col
        board[0].row = board[1].row
        payload.board = board
        let b = LuauGame()
        _ = b.restore(from: try encodePayload(payload))
        let uniquePositions = Set(b.pieces.map { $0.row * 7 + $0.col })
        // SUSPECTED-BUG(restore-duplicate-positions): expected to FAIL until product fix.
        #expect(uniquePositions.count == b.pieces.count,
                "restore accepted a board with two pieces on one cell")
    }

    // guards: restored jelly must be clearable — jelly on a masked cell can never be decremented (no piece ever clears there), soft-locking the objective
    @Test func restoreRejectsJellyOnMaskedCells() throws {
        let level = try #require(LuauLevels.level(id: 13))
        let maskedIndex = try #require(
            (0..<49).first { !level.isPlayable(col: $0 % 7, row: $0 / 7) })
        let a = LuauGame()
        a.newLevel(level, attempt: 1)
        var payload = try decodePayload(a.payload(seenHowTo: true))
        var jelly = try #require(payload.jelly)
        jelly[maskedIndex] = 1
        payload.jelly = jelly
        let b = LuauGame()
        _ = b.restore(from: try encodePayload(payload))
        // SUSPECTED-BUG(restore-jelly-on-masked): expected to FAIL until product fix.
        let jellyOnlyOnPlayable = b.jelly.enumerated().allSatisfy { index, layers in
            layers == 0 || (b.currentLevel?.isPlayable(col: index % 7, row: index / 7) ?? true)
        }
        #expect(jellyOnlyOnPlayable, "restore accepted unclearable jelly on a masked cell")
    }

    // guards: lifetime campaign progress must survive restoring a decodable payload that lacks the completedLevels field (the undecodable path already preserves it — the two must agree)
    @Test func restorePreservesLifetimeProgressWhenFieldAbsent() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.testSetJelly([UInt8](repeating: 0, count: 49))
        settle(game)
        #expect(game.completedLevels == [1001])
        // A legacy endless payload has no completedLevels key (nil is omitted).
        let legacy = legacyEndlessPayload(score: 420, movesLeft: 7)
        #expect(!legacy.contains("completedLevels"))
        _ = game.restore(from: legacy)
        #expect(game.score == 420 && game.movesLeft == 7)  // Case B resume worked
        // SUSPECTED-BUG(restore-wipes-completed-levels): expected to FAIL until product fix.
        #expect(game.completedLevels.contains(1001),
                "restore wiped lifetime campaign progress because the payload lacked the field")
    }

    // guards: a restored level save with movesLeft 0 must not allow spending a move into negative territory (the run should already read as out of moves)
    @Test func restoredZeroMoveLevelCannotSpendExtraMoves() throws {
        let a = LuauGame()
        a.newLevel(LuauLevels.debugL1, attempt: 1)
        a.testSetMovesLeft(0)
        let b = LuauGame()
        _ = b.restore(from: a.payload(seenHowTo: true))
        #expect(b.currentLevel?.id == 1001)
        #expect(b.movesLeft == 0)
        let swap = try #require(b.findLegalSwap())
        _ = b.attemptSwap(swap.0, swap.1)
        // SUSPECTED-BUG(negative-moves-after-restore): expected to FAIL until product fix.
        #expect(b.movesLeft >= 0, "restore let a zero-move run spend a move to movesLeft == -1")
        settle(b)
        #expect(b.isOver)  // the run still terminates either way
    }

    // guards: Case B latches encoreFired at exactly score 700 — a resumed run at 699 still earns ENCORE, at 700 it never re-awards
    @Test(arguments: [
        (savedScore: 699, expectedBeat: 1, expectedMoves: 9),
        (savedScore: 700, expectedBeat: 0, expectedMoves: 7),
    ])
    func caseBEncoreLatchBoundary(scenario: (savedScore: Int, expectedBeat: Int, expectedMoves: Int)) {
        let game = LuauGame()
        _ = game.restore(from: legacyEndlessPayload(score: scenario.savedScore, movesLeft: 7))
        #expect(game.currentLevel == nil && game.score == scenario.savedScore)
        carpetUniform(game, kind: 2)
        for col in 0..<7 { game.testSetKind(3, col: col, row: 3) }
        settle(game)
        #expect(game.encoreBeat == scenario.expectedBeat)
        #expect(game.movesLeft == scenario.expectedMoves)
    }

    // guards: a Case-A payload with all-zero jelly restores alive and wins on the first settle — no way to be stuck 'alive' with zero jelly
    @Test func wonStateCaseAPayloadWinsOnFirstSettle() {
        let a = LuauGame()
        a.newLevel(LuauLevels.debugL1, attempt: 1)
        a.testSetJelly([UInt8](repeating: 0, count: 49))
        // Not settled — isOver still false, so the payload carries the board.
        let b = LuauGame()
        _ = b.restore(from: a.payload(seenHowTo: true))
        #expect(b.currentLevel?.id == 1001)
        #expect(!b.isOver)
        #expect(!b.resolveStep())
        #expect(b.isOver && b.didWinLevel)
        #expect(b.completedLevels.contains(1001))
    }

    // guards: giant payloads stay bounded — oversized jelly/board arrays and megabyte padding route through count guards to a fresh endless game without hanging or trapping
    @Test func giantPayloadsRouteToFreshEndless() throws {
        var payload = LuauGame.SavePayload(
            seenHowTo: true, score: 5, movesLeft: 5, board: nil,
            levelID: 13, jelly: [UInt8](repeating: 1, count: 100_000),
            attemptSeed: 1, completedLevels: nil)
        let a = LuauGame()
        _ = a.restore(from: try encodePayload(payload))
        #expect(a.currentLevel == nil && a.pieces.count == 49 && a.score == 0)

        let donor = LuauGame()
        donor.newGame()
        payload.jelly = nil
        payload.board = Array(repeating: donor.pieces[0], count: 10_000)
        let b = LuauGame()
        _ = b.restore(from: try encodePayload(payload))
        #expect(b.currentLevel == nil && b.pieces.count == 49 && b.score == 0)

        let padded = String(repeating: " ", count: 1_000_000)
            + #"{"seenHowTo":true,"score":3,"movesLeft":9}"#
        let c = LuauGame()
        _ = c.restore(from: padded)
        #expect(c.currentLevel == nil && c.pieces.count == 49 && c.score == 0)
        #expect(c.movesLeft == LuauGame.movesPerRun)
    }
}

// MARK: - bot policy

@MainActor
struct LuauBotTests {

    // guards: playToEnd maxTurns bounds — 0 plays nothing and touches nothing, 1 plays exactly one move
    @Test func playToEndRespectsMaxTurnsBounds() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        let before = boardSignature(game)
        let movesBefore = game.movesLeft
        #expect(LuauBot.playToEnd(in: game, maxTurns: 0) == 0)
        #expect(boardSignature(game) == before)
        #expect(game.movesLeft == movesBefore)
        #expect(LuauBot.playToEnd(in: game, maxTurns: 1) == 1)
        #expect(game.movesLeft == movesBefore - 1)
    }

    // guards: pickMove is a pure function of game state — repeated calls return the identical move, and equal-scoring swaps resolve first-in-row-major
    @Test func pickMoveIsDeterministicAndTieBreaksRowMajor() throws {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        carpetNoLegalSwaps(game)
        // Two mirror-image 3-match options at equal proximity to the sand row:
        // completing row 1 via (2,0)v(2,1), or row 5 via (2,5)v(2,6).
        game.testSetKind(1, col: 0, row: 1)
        game.testSetKind(1, col: 1, row: 1)
        game.testSetKind(1, col: 2, row: 0)
        game.testSetKind(1, col: 0, row: 5)
        game.testSetKind(1, col: 1, row: 5)
        game.testSetKind(1, col: 2, row: 6)
        #expect(!game.resolveStep())  // staged board is settled
        let first = try #require(LuauBot.pickMove(for: game))
        let second = try #require(LuauBot.pickMove(for: game))
        #expect(first.0 == second.0 && first.1 == second.1)
        #expect(first.0.col == 2 && first.0.row == 0)  // row-major winner, not the row-5 twin
        #expect(first.1.col == 2 && first.1.row == 1)
    }

    // guards: all four debug fixtures honor their 'engineered bot-solvable' contract at attempt 1
    @Test func debugFixturesAreBotSolvable() {
        for fixture in LuauLevels.debugFixtures {
            let game = LuauGame()
            game.newLevel(fixture, attempt: 1)
            let turns = LuauBot.playToEnd(in: game)
            #expect(turns <= fixture.moves, "fixture \(fixture.id)")
            #expect(game.isOver, "fixture \(fixture.id)")
            #expect(game.didWinLevel, "fixture \(fixture.id) should be bot-solvable")
            #expect(game.jellyRemaining == 0, "fixture \(fixture.id)")
        }
    }

    // guards: playToEnd finishes every sampled campaign level within its move budget (isOver now asserted — the cat-stall this previously excluded is fixed and pinned by botMustNotStallWhenOnlyLegalSwapIsACat)
    @Test func campaignSampleStaysWithinMoveBudget() {
        for level in LuauLevels.all where level.id % 20 == 0 {
            let game = LuauGame()
            game.newLevel(level, attempt: 1)
            let turns = LuauBot.playToEnd(in: game)
            #expect(turns <= level.moves, "level \(level.id)")
            #expect(game.movesLeft >= 0, "level \(level.id)")
            #expect(game.isOver, "level \(level.id): bot run did not finish")
        }
    }

    // guards: 'the bot never stalls where a legal swap exists' (LuauBot.swift comment) — when the only legal move is a cat swap, pickMove must still return a move
    @Test func botMustNotStallWhenOnlyLegalSwapIsACat() {
        func makeStallBoard() -> LuauGame {
            let game = LuauGame()
            game.newLevel(LuauLevels.debugL1, attempt: 1)
            carpetNoLegalSwaps(game)
            game.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
            return game
        }
        let game = makeStallBoard()
        #expect(game.hasLegalSwap)                       // the engine sees the cat as a legal swap
        #expect(game.findLegalSwap() == nil)             // ...but the plain-kind scan cannot find it
        let twin = makeStallBoard()
        #expect(twin.attemptSwap((3, 3), (3, 4)))        // the cat swap really is legal
        // SUSPECTED-BUG(bot-cat-stall): expected to FAIL until product fix.
        // Real-world impact confirmed: campaign level 20 (attempt 1) ends its
        // bot run stalled with the game not over.
        #expect(LuauBot.pickMove(for: game) != nil,
                "bot stalls (and playToEnd exits with the game unfinished) while a legal cat swap exists")
    }

    // guards: scoreSwap must evaluate specials at their POST-swap cells — a swap that moves a torch into a match clears the torch's lane (with its sand), and must outscore a sandless 4-match
    @Test func botPrefersTorchLaneSandOverLesserMatch() throws {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        carpetNoLegalSwaps(game)
        // Option A (correct pick): swapping (2,0)v(2,1) moves a kind-1 lineV
        // torch into a row-0 triple; the triggered lane clears col 2, which
        // holds jelly at (2,3) -> worth 3 + 6 lane cells + 18 lane-sand = 27.
        game.testSetKind(1, col: 0, row: 0)
        game.testSetKind(1, col: 1, row: 0)
        game.testSetKind(0, col: 2, row: 0)
        game.testSetPiece(kind: 1, special: .lineV, col: 2, row: 1)
        // Option B (skewed pick): a sandless 4-match at row 6 via (5,5)v(5,6),
        // worth 4 + 6 torch spawn + 3 proximity = 13.
        game.testSetKind(2, col: 3, row: 6)
        game.testSetKind(2, col: 4, row: 6)
        game.testSetKind(3, col: 5, row: 6)
        game.testSetKind(2, col: 6, row: 6)
        game.testSetKind(2, col: 5, row: 5)
        #expect(!game.resolveStep())  // staged board is settled
        let move = try #require(LuauBot.pickMove(for: game))
        // SUSPECTED-BUG(bot-preswap-special-scoring): expected to FAIL until product fix.
        // scoreSwap reads the PRE-swap special grid, so option A's lane never
        // scores (3 + 4 proximity = 7) and the bot takes the weaker option B.
        #expect(move.0.col == 2 && move.0.row == 0 && move.1.col == 2 && move.1.row == 1,
                "bot preferred a sandless 4-match over a torch-lane swap that clears sand")
    }
}
