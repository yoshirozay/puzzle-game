import Foundation
import Testing
@testable import Tiki_Lounge

// Tests for CARGO (the Ingredients win condition): a piece the board carries
// but can never match, which leaves only by reaching the shore — row 6 of a
// column that reaches it.
//
// Determinism strategy is the same "null pattern" the other Luau suites use —
// kind = (col + 2*row) % 5, which contains no matches and no legal swaps on a
// 7x7 — except it is painted AROUND the cargo, since testSetKind on a cargo
// cell would overwrite the thing under test. Replacing a pattern cell with an
// unmatchable -2 can only remove match opportunities, never create one, so the
// no-legal-plain-swap property survives. That is what makes a shove-only board
// constructible: on such a board the ONLY legal move is walking the cargo
// sideways, so every claim about the shove is tested in isolation.

@MainActor
private func paintNullAroundCargo(_ game: LuauGame) {
    for p in game.pieces where !LuauGame.isIngredient(p) {
        game.testSetKind((p.col + 2 * p.row) % 5, col: p.col, row: p.row)
    }
}

@MainActor
private func cargoCount(_ game: LuauGame) -> Int {
    game.pieces.filter(LuauGame.isIngredient).count
}

/// Cargo still on the board plus cargo already banked. This — not "still on
/// the board" — is what indestructibility means: a blast that empties the
/// cargo's column DELIVERS it, which is the mechanic working, not a loss.
@MainActor
private func conserved(_ game: LuauGame) -> Int {
    cargoCount(game) + game.ingredientsCollected
}

/// Everything a rejected gesture must leave untouched. Local rather than
/// shared because the point of these tests is the field the shared snapshot
/// predates: `ingredientsCollected`.
private struct CargoSnapshot: Equatable {
    let pieces: [LuauGame.Piece]
    let score: Int
    let movesLeft: Int
    let isOver: Bool
    let didWinLevel: Bool
    let clearBeat: Int
    let fireBeat: Int
    let comboBeat: Int
    let shuffleBeat: Int
    let ingredientsCollected: Int
}

@MainActor
private func snap(_ g: LuauGame) -> CargoSnapshot {
    CargoSnapshot(pieces: g.pieces, score: g.score, movesLeft: g.movesLeft,
                  isOver: g.isOver, didWinLevel: g.didWinLevel,
                  clearBeat: g.clearBeat, fireBeat: g.fireBeat,
                  comboBeat: g.comboBeat, shuffleBeat: g.shuffleBeat,
                  ingredientsCollected: g.ingredientsCollected)
}

/// Full board, cargo at the top of column 3, no sand — delivery is the only
/// objective. Every column reaches row 6, so every horizontal shove is legal.
private let fullCargo = LuauLevels.debugCargo

/// Column 3 stops at row 5, so it never drains. Cargo starts at (2,0); the
/// shove to column 3 must be refused and the shove to column 1 allowed.
private let ledgeCargo: LuauLevel = {
    let (m, j) = LuauLevel.parse([
        "#######", "#######", "#######", "#######", "#######", "#######", "###.###",
    ])
    return LuauLevel(id: 990_301, mask: m, jelly: j, colors: 5,
                     moves: 30, movesHard: 24, seed: 0x3013_0130_1301_3013,
                     archetype: "Test Ledge", ingredients: [2])
}()

/// Cargo plus one sand cell, to pin that BOTH objectives gate the win.
private let cargoAndSand: LuauLevel = {
    let (m, j) = LuauLevel.parse([
        "#######", "#######", "#######", "#######", "#######", "#######", "######o",
    ])
    return LuauLevel(id: 990_302, mask: m, jelly: j, colors: 5,
                     moves: 30, movesHard: 24, seed: 0x3023_0230_2302_3023,
                     archetype: "Test Both", ingredients: [3])
}()

// MARK: - Placement

@MainActor
struct LuauCargoPlacementTests {

    @Test func cargoLandsWhereTheLevelDeclaresIt() {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        #expect(cargoCount(game) == 1)
        let cargo = try! #require(game.pieces.first(where: LuauGame.isIngredient))
        #expect(cargo.col == 3 && cargo.row == 0)
        #expect(cargo.special == .none)
        // Cargo REPLACES a filled cell rather than skipping one, so the board
        // stays packed and the RNG stream is identical to a cargo-free fill.
        #expect(game.pieces.count == fullCargo.playableCount)
    }

    @Test func cargoIsCountedAsOutstandingUntilDelivered() {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        #expect(game.ingredientsRemaining == 1)
        #expect(game.ingredientsCollected == 0)
    }

    @Test func cargoFreeLevelsReportNoCargoObjective() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        #expect(game.ingredientsRemaining == 0)
        #expect(cargoCount(game) == 0)
    }

    /// Endless mode has no level and therefore no shore.
    @Test func endlessModeCarriesNoCargo() {
        let game = LuauGame()
        game.newGame()
        #expect(cargoCount(game) == 0)
        #expect(game.ingredientsRemaining == 0)
    }
}

// MARK: - Cargo survives every destructive path

@MainActor
struct LuauCargoIndestructibilityTests {

    /// Stages a board with cargo at (3,3) and returns the game.
    private func staged() -> LuauGame {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        paintNullAroundCargo(game)
        // Move the cargo off row 0 so lanes can be aimed through it.
        game.testSetKind((3 + 2 * 0) % 5, col: 3, row: 0)
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 3, row: 3)
        return game
    }

    @Test func aHorizontalTorchLaneSparesCargoInItsRow() {
        let game = staged()
        // A matched lineH torch clears its whole row — cargo included, before.
        game.testSetPiece(kind: 0, special: .lineH, col: 0, row: 3)
        game.testSetKind(0, col: 1, row: 3)
        game.testSetKind(0, col: 2, row: 3)
        #expect(game.resolveStep())
        #expect(conserved(game) == 1)
        #expect(game.pieces.count == fullCargo.playableCount)
    }

    @Test func aVerticalTorchLaneSparesCargoInItsColumn() {
        let game = staged()
        game.testSetPiece(kind: 0, special: .lineV, col: 3, row: 6)
        game.testSetKind(0, col: 2, row: 6)
        game.testSetKind(0, col: 4, row: 6)
        #expect(game.resolveStep())
        // The lane empties column 3 around the cargo; the cargo itself lives.
        #expect(conserved(game) == 1)
        #expect(game.pieces.count == fullCargo.playableCount)
    }

    @Test func aBombBlastSparesCargoInsideIt() {
        let game = staged()
        // A matched bomb at (2,2) blasts rows 1-3 x cols 1-3 — the cargo's
        // cell (3,3) is inside the footprint, and must not be taken.
        game.testSetPiece(kind: 0, special: .bomb, col: 2, row: 2)
        game.testSetKind(0, col: 0, row: 2)
        game.testSetKind(0, col: 1, row: 2)
        #expect(game.resolveStep())
        #expect(conserved(game) == 1)
        #expect(game.pieces.count == fullCargo.playableCount)
    }

    @Test func aCatWipeSparesCargo() {
        let game = staged()
        game.testSetPiece(kind: -1, special: .cat, col: 0, row: 0)
        // Swap the cat with a plain neighbour: wipes that colour board-wide.
        #expect(game.attemptSwap((0, 0), (1, 0)))
        #expect(conserved(game) == 1)
    }

    /// The one that would have been silent: a cat swapped INTO cargo reads
    /// -2 as the victim colour and matches every piece of cargo on the board.
    @Test func aCatSwappedIntoCargoIsRefusedOutright() {
        let game = staged()
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 2)
        let before = snap(game)
        #expect(game.attemptSwap((3, 2), (3, 3)) == false)
        #expect(snap(game) == before)
        #expect(cargoCount(game) == 1)
    }

    @Test func aTorchCrossSparesCargo() {
        let game = staged()
        game.testSetPiece(kind: 0, special: .lineH, col: 3, row: 4)
        game.testSetPiece(kind: 1, special: .lineV, col: 3, row: 5)
        #expect(game.attemptSwap((3, 4), (3, 5)))
        #expect(conserved(game) == 1)
    }

    @Test func aTorchStormSparesCargo() {
        let game = staged()
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 4)
        game.testSetPiece(kind: 1, special: .lineV, col: 3, row: 5)
        #expect(game.attemptSwap((3, 4), (3, 5)))
        #expect(conserved(game) == 1)
    }

    @Test func aCataclysmSparesCargo() {
        let game = staged()
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 4)
        game.testSetPiece(kind: -1, special: .cat, col: 3, row: 5)
        #expect(game.attemptSwap((3, 4), (3, 5)))
        // Cat + cat clears the entire board. The cargo is the one survivor.
        #expect(conserved(game) == 1)
    }

    @Test func aPlainMatchThroughCargosRowSparesIt() {
        let game = staged()
        game.testSetKind(0, col: 0, row: 3)
        game.testSetKind(0, col: 1, row: 3)
        game.testSetKind(0, col: 2, row: 3)
        #expect(game.resolveStep())
        #expect(conserved(game) == 1)
    }

    /// The comped Lounge Cat must not be allowed to delete the objective.
    @Test func placeCatRefusesACargoCell() {
        let game = staged()
        let before = snap(game)
        #expect(game.placeCat(col: 3, row: 3) == false)
        #expect(snap(game) == before)
    }
}

// MARK: - Delivery

@MainActor
struct LuauCargoDeliveryTests {

    @Test func clearingOnePieceBeneathCargoDropsItExactlyOneRow() {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        paintNullAroundCargo(game)
        game.testSetKind((3 + 2 * 0) % 5, col: 3, row: 0)
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 3, row: 3)
        // A horizontal 3 at row 4 takes exactly one piece out of column 3.
        game.testSetKind(0, col: 2, row: 4)
        game.testSetKind(0, col: 3, row: 4)
        game.testSetKind(0, col: 4, row: 4)
        #expect(game.resolveStep())
        let cargo = try! #require(game.pieces.first(where: LuauGame.isIngredient))
        #expect(cargo.col == 3)
        #expect(cargo.row == 4)
        #expect(game.pieces.count == fullCargo.playableCount)
    }

    /// The free emergent payoff the design was built around: a vertical torch
    /// in the cargo's column is the delivery tool.
    @Test func aVerticalTorchDeliversCargoInTheSameResolveStep() {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        paintNullAroundCargo(game)
        game.testSetKind((3 + 2 * 0) % 5, col: 3, row: 0)
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 3, row: 3)
        // Matched vertical torch in column 3: clears every other piece there.
        game.testSetPiece(kind: 0, special: .lineV, col: 3, row: 6)
        game.testSetKind(0, col: 2, row: 6)
        game.testSetKind(0, col: 4, row: 6)
        #expect(game.resolveStep())
        // Banked by the time resolveStep returns — not one step later.
        #expect(game.ingredientsCollected == 1)
        #expect(game.ingredientsRemaining == 0)
        #expect(cargoCount(game) == 0)
        #expect(game.pieces.count == fullCargo.playableCount)
    }

    @Test func deliveringTheLastCargoWinsACargoOnlyLevel() {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        paintNullAroundCargo(game)
        game.testSetKind((3 + 2 * 0) % 5, col: 3, row: 0)
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 3, row: 3)
        game.testSetPiece(kind: 0, special: .lineV, col: 3, row: 6)
        game.testSetKind(0, col: 2, row: 6)
        game.testSetKind(0, col: 4, row: 6)
        while game.resolveStep() {}
        #expect(game.ingredientsRemaining == 0)
        #expect(game.isOver)
        #expect(game.didWinLevel)
    }

    /// A cargo-only level has zero sand, so without the cargo clause it would
    /// insta-win on the very first settle.
    @Test func aCargoOnlyLevelDoesNotWinBeforeDelivery() {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        paintNullAroundCargo(game)
        #expect(game.jellyRemaining == 0)
        #expect(game.ingredientsRemaining == 1)
        while game.resolveStep() {}
        #expect(game.isOver == false)
        #expect(game.didWinLevel == false)
    }

    @Test func sandClearedButCargoOutstandingIsNotAWin() {
        let game = LuauGame()
        game.newLevel(cargoAndSand, attempt: 1)
        paintNullAroundCargo(game)
        game.testSetJelly(Array(repeating: 0, count: LuauLevel.cellCount))
        #expect(game.jellyRemaining == 0)
        #expect(game.ingredientsRemaining == 1)
        while game.resolveStep() {}
        #expect(game.didWinLevel == false)
        #expect(game.isOver == false)
    }
}

// MARK: - The shove

@MainActor
struct LuauCargoShoveTests {

    /// Full board, null pattern, cargo at (3,3): no plain swap exists
    /// anywhere, so the only legal move on this board is a shove.
    private func shoveOnly() -> LuauGame {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        paintNullAroundCargo(game)
        game.testSetKind((3 + 2 * 0) % 5, col: 3, row: 0)
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 3, row: 3)
        return game
    }

    /// CARSON'S RULE, 2026-07-29. The coconut is not steerable: it swaps like
    /// any other piece, so a swap that clears nothing springs back and costs
    /// nothing. The pairing is still LEGAL — that is what `canShoveForTest`
    /// reports — it simply has no reason to commit.
    @Test func aBareCargoSwapWhiffsInsteadOfSteering() {
        let game = shoveOnly()
        let moves = game.movesLeft
        let before = snap(game)
        #expect(game.canShoveForTest(from: (3, 3), to: (4, 3)),
                "cargo↔plain into a draining column is still a legal pairing")
        #expect(game.isLegalPairing((3, 3), (4, 3)),
                "the feedback layer must read this whiff as legal, not a mistake")
        #expect(game.attemptSwap((3, 3), (4, 3)) == false,
                "a cargo swap that matches nothing must whiff, not steer")
        #expect(snap(game) == before, "the whiff must leave the board untouched")
        let cargo = try! #require(game.pieces.first(where: LuauGame.isIngredient))
        #expect(cargo.col == 3 && cargo.row == 3, "the coconut must not have moved")
        #expect(game.movesLeft == moves, "a whiff is free")
        #expect(game.pieces.count == fullCargo.playableCount)
        #expect(Set(game.pieces.map { $0.row * 7 + $0.col }).count == game.pieces.count)
    }

    /// CARSON'S RULE again, stated as an implication over the SHIPPING boards so
    /// no hand-built fixture can flatter it: a cargo swap the engine did not
    /// COMMIT must leave the coconut exactly where it was. Checked on a real
    /// cargo night and on the lesson, because a lesson never spends a move — so
    /// "it cost nothing" is not available as the test there, and a steering rule
    /// hiding on the lesson board would otherwise go unseen.
    @Test func aCargoSwapThatDoesNotCommitNeverMovesTheCoconut() throws {
        let night = try #require(LuauLevels.all.first { $0.id == 42 })
        var attempts = 0
        for level in [night, LuauLevels.cargoLesson] {
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let game = LuauGame()
                game.newLevel(level, attempt: 1)
                let cargo = try #require(game.pieces.first(where: LuauGame.isIngredient))
                let from = (col: cargo.col, row: cargo.row)
                let to = (col: from.col + dc, row: from.row + dr)
                guard game.piece(at: to.col, to.row) != nil else { continue }
                attempts += 1
                let movesBefore = game.movesLeft
                let committed = game.attemptSwap(from, to)
                let now = try #require(game.pieces.first(where: LuauGame.isIngredient))
                guard !committed else { continue }
                #expect(now.col == from.col && now.row == from.row,
                        "level \(level.id) \(from)->\(to): an uncommitted swap steered the coconut")
                #expect(game.movesLeft == movesBefore,
                        "level \(level.id) \(from)->\(to): an uncommitted swap must be free")
            }
        }
        #expect(attempts >= 6, "fixture must actually exercise cargo pairings")
    }

    /// Vertical used to be refused outright, which killed the gesture dead:
    /// a run you could only reach by moving a piece past the coconut was
    /// unplayable. It is legal now, and whiffs like any other matchless swap.
    @Test func aVerticalCargoSwapIsLegalAndWhiffsWithoutAMatch() {
        let game = shoveOnly()
        let before = snap(game)
        #expect(game.canShoveForTest(from: (3, 3), to: (3, 4)))
        #expect(game.attemptSwap((3, 3), (3, 4)) == false)
        #expect(snap(game) == before)
    }

    @Test func liftingCargoUpwardIsLegalAndWhiffsWithoutAMatch() {
        let game = shoveOnly()
        let before = snap(game)
        #expect(game.canShoveForTest(from: (3, 3), to: (3, 2)))
        #expect(game.attemptSwap((3, 3), (3, 2)) == false)
        #expect(snap(game) == before)
    }

    @Test func cargoAgainstCargoIsRejected() {
        let game = shoveOnly()
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 4, row: 3)
        let before = snap(game)
        #expect(game.attemptSwap((3, 3), (4, 3)) == false)
        #expect(snap(game) == before)
    }

    @Test func cargoAgainstATorchIsRejected() {
        let game = shoveOnly()
        game.testSetPiece(kind: 0, special: .lineH, col: 4, row: 3)
        let before = snap(game)
        #expect(game.isLegalPairing((3, 3), (4, 3)) == false,
                "the feedback layer must read this as a rejection, not a whiff")
        #expect(game.attemptSwap((3, 3), (4, 3)) == false)
        #expect(snap(game) == before)
    }

    @Test func cargoAgainstTheCatIsRejected() {
        let game = shoveOnly()
        game.testSetPiece(kind: -1, special: .cat, col: 4, row: 3)
        let before = snap(game)
        #expect(game.attemptSwap((3, 3), (4, 3)) == false)
        #expect(snap(game) == before)
    }

    /// The clause that makes stranding impossible by construction.
    @Test func aShoveIntoANonDrainingColumnIsRejected() {
        let game = LuauGame()
        game.newLevel(ledgeCargo, attempt: 1)
        paintNullAroundCargo(game)
        let cargo = try! #require(game.pieces.first(where: LuauGame.isIngredient))
        #expect(cargo.col == 2 && cargo.row == 0)
        #expect(ledgeCargo.drains(col: 3) == false)
        let before = snap(game)
        #expect(game.attemptSwap((2, 0), (3, 0)) == false)
        #expect(snap(game) == before)
        // …while the other direction, into a column that does reach the
        // shore, is allowed. Same gesture, different shape. Legality is the
        // claim here, not commitment: the coconut no longer moves for free, so
        // this pairing whiffs until something actually clears.
        #expect(ledgeCargo.drains(col: 1))
        #expect(game.canShoveForTest(from: (2, 0), to: (1, 0)))
    }

    /// CARSON'S BUG, 2026-07-25. Cargo can almost always be pushed somewhere,
    /// so counting a bare shove as "the board has a move" left `hasLegalSwap`
    /// permanently true — a player out of matches could slide the coconut back
    /// and forth forever and the board would never reshuffle. The first version
    /// of this suite asserted the OPPOSITE and passed, which is exactly why 516
    /// green tests did not catch it. A shove is legal but it is not progress.
    @Test func aShoveOnlyBoardIsDeclaredStuckSoItCanReshuffle() {
        let game = shoveOnly()
        // A shove is still an accepted move…
        #expect(game.canShoveForTest(from: (3, 3), to: (4, 3)))
        // …but it must not, on its own, make the board look playable.
        #expect(game.hasLegalSwap == false,
                "a board whose only move is a bare shove must be shufflable")
        #expect(game.findLegalSwap() == nil,
                "a hint must never point at a shove that makes no match")
    }

    /// And the reshuffle must not cost the player the objective — this is the
    /// hazard that made the bare-shove scan look necessary in the first place.
    @Test func reshufflingAShoveOnlyBoardKeepsTheCargo() {
        let game = shoveOnly()
        let beat = game.shuffleBeat
        #expect(game.resolveStep() == false)
        #expect(game.shuffleBeat > beat, "the board should have reshuffled")
        #expect(cargoCount(game) == 1, "the reshuffle destroyed the cargo")
        #expect(game.pieces.count == fullCargo.playableCount)
        #expect(game.ingredientsCollected == 0)
    }

    /// A shove that DOES complete a run is a real move and must keep counting.
    ///
    /// THIS FIXTURE HAS BEEN WRONG TWICE, in opposite directions. First it planted
    /// kinds on the full board and passed via an unrelated plain swap, so the
    /// liveness clause was untested (an audit caught it). Then, once runs began
    /// passing THROUGH cargo, its column of 3s above and below the coconut became
    /// a standing three-match and the board was never quiet to begin with. Every
    /// cell is now set by hand and `hasLegalSwap` is asserted FALSE first, so the
    /// flip to true is attributable to the shove and to nothing else.
    @Test func aMatchMakingShoveKeepsTheBoardAlive() {
        let (m, j) = LuauLevel.parse([
            ".......", ".......", ".......", "..###..", "..###..", "..###..", "..###..",
        ])
        let level = LuauLevel(id: 990_401, mask: m, jelly: j, colors: 4,
                             moves: 30, movesHard: 24, seed: 0x4014_0140_1401_4014,
                             archetype: "Test Shove", ingredients: [38])  // (3,5)
        let game = LuauGame()
        game.newLevel(level, attempt: 1)

        // Columns 2 and 4 alternate so neither can run; column 3 holds only TWO
        // 3s, at rows 3 and 4, with a different kind under the coconut.
        let col2 = [1, 2, 1, 2], col4 = [2, 1, 2, 1]
        for (n, row) in (3...6).enumerated() {
            game.testSetKind(col2[n], col: 2, row: row)
            game.testSetKind(col4[n], col: 4, row: row)
        }
        game.testSetKind(3, col: 3, row: 3)
        game.testSetKind(3, col: 3, row: 4)
        game.testSetKind(0, col: 3, row: 6)
        #expect(cargoCount(game) == 1)
        #expect(game.hasLegalSwap == false, "fixture must start with NO legal move")

        // Now put a 3 beside the coconut. Shoving it aside slides that 3 into
        // (3,5) and completes 3,3,3 down column 3 — only a shove can do this.
        game.testSetKind(3, col: 4, row: 5)
        #expect(game.hasLegalSwap, "a match-making shove must count as a legal move")
        let found = try! #require(game.findLegalSwap())
        let cells = [found.0, found.1]
        #expect(cells.contains(where: { $0.col == 3 && $0.row == 5 }),
                "findLegalSwap should point at the shove, not something else")
        #expect(game.attemptSwap(found.0, found.1))
    }

    /// CARSON'S BUG, 2026-07-29. A vertical swap through the coconut was
    /// refused outright, so a run you could only complete by moving a piece
    /// past it was simply unplayable — the gesture died with no feedback.
    ///
    /// Same base fixture as `aMatchMakingShoveKeepsTheBoardAlive`, which is
    /// already pinned to have NO legal move, and the two cells this adds create
    /// no plain swap either. So the flip to playable is attributable to the
    /// VERTICAL cargo swap and to nothing else — including no horizontal one:
    /// sliding the coconut either way along row 5 leaves two reals spanning it,
    /// which is not a match.
    @Test func aVerticalCargoSwapThatCompletesARunCommitsAndDelivers() {
        let (m, j) = LuauLevel.parse([
            ".......", ".......", ".......", "..###..", "..###..", "..###..", "..###..",
        ])
        let level = LuauLevel(id: 990_402, mask: m, jelly: j, colors: 4,
                              moves: 30, movesHard: 24, seed: 0x4014_0140_1401_4014,
                              archetype: "Test Vertical", ingredients: [38])  // (3,5)
        let game = LuauGame()
        game.newLevel(level, attempt: 1)
        let col2 = [1, 2, 1, 2], col4 = [2, 1, 2, 1]
        for (n, row) in (3...6).enumerated() {
            game.testSetKind(col2[n], col: 2, row: row)
            game.testSetKind(col4[n], col: 4, row: row)
        }
        game.testSetKind(3, col: 3, row: 3)
        game.testSetKind(3, col: 3, row: 4)
        game.testSetKind(0, col: 3, row: 6)
        #expect(cargoCount(game) == 1)
        #expect(game.hasLegalSwap == false, "fixture must start with NO legal move")

        // Flank the coconut with the same kind that sits directly BELOW it.
        // Row 5 reads 0 [coconut] 0 — two reals spanning cargo, not a match —
        // until the 0 under the coconut is lifted into the gap.
        game.testSetKind(0, col: 2, row: 5)
        game.testSetKind(0, col: 4, row: 5)
        #expect(game.hasLegalSwap,
                "hasLegalSwap must see a match-making VERTICAL cargo swap")
        let found = try! #require(game.findLegalSwap())
        #expect([found.0, found.1].allSatisfy { $0.col == 3 && ($0.row == 5 || $0.row == 6) },
                "the only move is the vertical cargo swap at column 3")

        let moves = game.movesLeft
        #expect(game.attemptSwap((3, 5), (3, 6)))
        #expect(game.movesLeft == moves - 1, "a clearing cargo swap is billed")
        let cargo = try! #require(game.pieces.first(where: LuauGame.isIngredient))
        #expect(cargo.col == 3 && cargo.row == 6, "the coconut took the partner's cell")
        #expect(game.resolveStep(), "the lifted piece completed row 5")
        while game.resolveStep() {}
        // It landed on the shore in a draining column, so it ships.
        #expect(game.ingredientsCollected == 1)
        #expect(cargoCount(game) == 0)
    }

    /// The preview drives the FX layer and the view consults it BEFORE
    /// attemptSwap, so a preview that disagrees renders a show for a gesture
    /// the engine refuses.
    @Test func previewShowsNothingForAnyCargoPairing() {
        let game = shoveOnly()
        #expect(game.previewSwapFires((3, 3), (4, 3)).isEmpty)
        game.testSetPiece(kind: -1, special: .cat, col: 4, row: 3)
        #expect(game.previewSwapFires((3, 3), (4, 3)).isEmpty,
                "a cat previewed against cargo rendered a phantom wipe")
        game.testSetPiece(kind: 0, special: .lineV, col: 4, row: 3)
        #expect(game.previewSwapFires((3, 3), (4, 3)).isEmpty)
    }

    /// A shove is a real move: the displaced piece can complete a run.
    @Test func aShoveThatCompletesARunResolvesNormally() {
        let game = shoveOnly()
        // Put a pair of kind 0 either side, so shoving the cargo right
        // slides a kind 0 into the gap and completes a horizontal three.
        game.testSetPiece(kind: 0, special: .none, col: 4, row: 3)
        game.testSetKind(0, col: 2, row: 3)
        game.testSetKind(0, col: 1, row: 3)
        let moves = game.movesLeft
        #expect(game.attemptSwap((3, 3), (4, 3)))
        // …and a shove that DOES clear something is charged like any other
        // clearing move, or the coconut becomes a free-match machine.
        #expect(game.movesLeft == moves - 1, "a match-making shove must cost a move")
        #expect(game.resolveStep(), "the displaced piece should have matched")
        #expect(cargoCount(game) == 1)
    }
}

// MARK: - The shipping lesson

@MainActor
struct LuauCargoLessonTests {

    /// Carson asked for onboarding that is over in one swipe, so the lesson's
    /// SEED is load-bearing: it was searched for a fresh board whose only
    /// one-swap delivery sits directly beneath the coconut. `fillFreshBoard` is
    /// seeded-random and deliberately refuses to plant a ready-made match, so
    /// this arrangement cannot be authored any other way — which means any change
    /// to the fill RNG, `wouldMatch`, or the mask silently un-scripts the lesson.
    /// This test is what makes that failure loud instead of silent.
    @Test func cargoLessonExitsInASingleSwap() {
        let lesson = LuauLevels.cargoLesson
        let game = LuauGame()
        game.newLevel(lesson, attempt: 1)
        while game.resolveStep() {}

        // It must NOT deliver itself — an onboarding with no input teaches nothing.
        #expect(game.ingredientsCollected == 0, "the lesson auto-delivered with no input")
        let cargo = try! #require(game.pieces.first(where: LuauGame.isIngredient))
        #expect(cargo.col == 3 && cargo.row == 5)

        // …and the one swap directly under the coconut finishes it outright.
        #expect(game.attemptSwap((2, 6), (3, 6)), "the scripted swap was rejected")
        while game.resolveStep() {}
        #expect(game.ingredientsCollected == 1, "the scripted swap did not deliver")
        #expect(game.ingredientsRemaining == 0)
        #expect(game.didWinLevel, "delivering the only cargo should clear the lesson")
    }

    /// The lesson must stay unfailable however long it takes, since a player who
    /// misses the scripted swap has to be able to keep trying.
    @Test func theCargoLessonCannotBeFailed() {
        let lesson = LuauLevels.cargoLesson
        #expect(lesson.isLesson)
        #expect(lesson.teaches == "ingredients")
        let game = LuauGame()
        game.newLevel(lesson, attempt: 1)
        game.testSetMovesLeft(0)
        while game.resolveStep() {}
        #expect(game.isOver == false, "a lesson must never latch a defeat")
        #expect(LuauLevels.nightNumber(of: lesson.id) == nil, "a lesson is not a night")
    }
}

// MARK: - Shuffle

@MainActor
struct LuauCargoShuffleTests {

    /// Cargo's -2 must never migrate onto a plain piece — that is the
    /// unmatchable-strand bug the cat's kind guard already warns about.
    @Test func shufflePreservesCargoAndNeverSpreadsItsKind() {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        #expect(cargoCount(game) == 1)
        game.testShuffle()
        #expect(cargoCount(game) == 1)
        #expect(game.pieces.filter { $0.kind == LuauGame.ingredientKind }.count == 1)
        #expect(game.pieces.count == fullCargo.playableCount)
    }
}

// MARK: - The calibration bot

@MainActor
struct LuauCargoBotTests {

    /// LuauBot is both shipped autoplay AND the policy all 200 move budgets
    /// were solved against, so it has to keep finding moves on a cargo board.
    /// A stall here is an infinite loop in LevelForge and a frozen board on
    /// screen — and the specific way it stalls is subtle: the bot proposes a
    /// pairing `attemptSwap` rejects and then proposes it again forever.
    @Test func theBotDrivesACargoLevelToAConclusionWithoutStalling() {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        var steps = 0
        while !game.isOver, steps < 2000 {
            while game.resolveStep() { steps += 1 }
            if game.isOver { break }
            guard let move = LuauBot.pickMove(for: game) else {
                Issue.record("bot found no move; hasLegalSwap = \(game.hasLegalSwap)")
                break
            }
            game.attemptSwap(move.0, move.1)
            steps += 1
            #expect(conserved(game) == 1, "cargo went missing mid-run")
        }
        #expect(steps < 2000, "bot stalled on a cargo board")
        #expect(game.isOver, "run never concluded")
    }

    /// The engine and the bot must agree about what is playable, or one of
    /// them is wrong about when to shuffle.
    @Test func theBotAlwaysHasAMoveWhileTheEngineSaysTheBoardIsPlayable() {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        var steps = 0
        while !game.isOver, steps < 400 {
            while game.resolveStep() { steps += 1 }
            if game.isOver { break }
            if game.hasLegalSwap {
                #expect(LuauBot.pickMove(for: game) != nil,
                        "engine says playable, bot sees no move")
            }
            guard let move = LuauBot.pickMove(for: game) else { break }
            game.attemptSwap(move.0, move.1)
            steps += 1
        }
    }
}

// MARK: - The campaign schedule

@MainActor
struct LuauCargoScheduleTests {

    /// The retrofit overlay must actually land on the campaign, and land ONLY
    /// where it was declared — an overlay applied in a computed `all` is easy to
    /// get silently wrong.
    @Test func cargoLandsExactlyOnTheDeclaredNights() {
        let carrying = LuauLevels.all.filter { !$0.isLesson && $0.ingredientTotal > 0 }.map(\.id)
        #expect(Set(carrying) == LuauLevels.cargoNights,
                "nights carrying cargo do not match cargoNights")
        #expect(carrying.count == LuauLevels.cargoNights.count, "a night carries cargo twice")
    }

    /// Spacing is the whole point of the sprinkle: the rubric's Novelty bar wants
    /// something new at least every 20 levels, and cargo is the only new verb the
    /// back half of the campaign has.
    @Test func noGapBetweenCargoNightsExceedsTwenty() {
        let ids = LuauLevels.cargoNights.sorted()
        for (a, b) in zip(ids, ids.dropFirst()) {
            #expect(b - a <= 20, "gap of \(b - a) nights between L\(a) and L\(b)")
        }
        #expect(200 - (ids.last ?? 0) <= 20, "the campaign ends more than 20 nights after cargo")
    }

    /// Every host must have had headroom for an added objective. Pinned so a
    /// future regeneration that changes a mask or a budget fails loudly here
    /// rather than quietly shipping a coconut on an unwinnable board.
    @Test func everyCargoNightHasTheGeometryCargoNeeds() {
        for id in LuauLevels.cargoNights.sorted() {
            let level = try! #require(LuauLevels.level(id: id), "L\(id) missing")
            let draining = (0..<LuauLevel.size).filter { level.drains(col: $0) }
            #expect(draining.count >= 3, "L\(id): only \(draining.count) draining columns")
            let deepest = draining.map { level.playableRows(col: $0).count }.max() ?? 0
            #expect(deepest >= 5, "L\(id): deepest draining column is only \(deepest)")
            let cell = try! #require(LuauLevels.cargoCell(for: level), "L\(id): no cargo cell")
            #expect(level.ingredientCells == [cell])
            #expect(level.drains(col: cell % LuauLevel.size), "L\(id): cargo column never drains")
            #expect(cell / LuauLevel.size != LuauLevel.size - 1, "L\(id): starts delivered")
        }
    }

    /// Nights that do NOT carry cargo must be untouched by the overlay.
    @Test func theOverlayLeavesEveryOtherNightAlone() {
        for level in LuauLevels.all where !level.isLesson && !LuauLevels.cargoNights.contains(level.id) {
            #expect(level.ingredients == nil, "L\(level.id) gained cargo it never declared")
        }
    }
}

// MARK: - Cargo is transparent to matches

@MainActor
struct LuauCargoTransparencyTests {

    /// Carson, on playing it: "it plays like a bug when I can't match vertically
    /// through a coconut." Cargo used to BLOCK runs. It now neither breaks a run
    /// nor counts toward one, so pieces on either side of it connect.
    private func staged() -> LuauGame {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        paintNullAroundCargo(game)
        game.testSetKind((3 + 2 * 0) % 5, col: 3, row: 0)
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 3, row: 3)
        return game
    }

    @Test func aVerticalRunPassesThroughTheCoconut() {
        let game = staged()
        // Column 3: kind 0 at rows 1, 2 and 4 — the coconut sits at row 3.
        game.testSetKind(0, col: 3, row: 1)
        game.testSetKind(0, col: 3, row: 2)
        game.testSetKind(0, col: 3, row: 4)
        #expect(game.resolveStep(), "three pieces spanning the coconut should match")
        // The pieces went; the coconut did not.
        #expect(conserved(game) == 1)
        #expect(game.pieces.count == fullCargo.playableCount)
    }

    @Test func aHorizontalRunPassesThroughTheCoconut() {
        let game = staged()
        game.testSetKind(0, col: 1, row: 3)
        game.testSetKind(0, col: 2, row: 3)
        game.testSetKind(0, col: 4, row: 3)
        #expect(game.resolveStep(), "three pieces spanning the coconut should match")
        #expect(conserved(game) == 1)
    }

    /// Transparent, not free: the coconut still contributes NOTHING to the run,
    /// so two pieces either side of it are two pieces, not three.
    @Test func twoPiecesSpanningTheCoconutAreNotAMatch() {
        let game = staged()
        // Kind 4, not 0: the null pattern already puts a 0 at (3,1), so a pair of
        // 0s either side of the coconut was silently a THREE and this test failed
        // for the right reason on its first run. Column 3 reads 3,0,4,[coconut],4
        // — exactly two 4s spanning it.
        game.testSetKind(4, col: 3, row: 2)
        game.testSetKind(4, col: 3, row: 4)
        #expect(game.resolveStep() == false, "a coconut must not pad a run to three")
        #expect(cargoCount(game) == 1)
    }

    /// The run's cells must never include the coconut, or it lands in a clear set
    /// or hosts a spawned special.
    @Test func aRunThroughTheCoconutNeverSpawnsASpecialOnIt() {
        let game = staged()
        // Four pieces spanning the coconut — a 4-run mints a torch.
        for r in [0, 1, 2, 4] { game.testSetKind(0, col: 3, row: r) }
        #expect(game.resolveStep())
        let cargo = try! #require(game.pieces.first(where: LuauGame.isIngredient))
        #expect(cargo.special == .none, "a special spawned on the coconut")
        #expect(conserved(game) == 1)
    }

    /// Dropping cargo onto a filled board can now JOIN two separated pairs into a
    /// three, which would resolve on the first settle — the level would open by
    /// clearing itself. Every cargo level must start quiet.
    @Test func everyCargoLevelStartsWithoutAStandingMatch() {
        for level in LuauLevels.all + LuauLevels.debugFixtures where level.ingredientTotal > 0 {
            for attempt in UInt64(1)...4 {
                let game = LuauGame()
                game.newLevel(level, attempt: attempt)
                #expect(game.ingredientsCollected == 0,
                        "level \(level.id) attempt \(attempt): delivered before a move")
                #expect(game.pieces.count == level.playableCount, "level \(level.id)")
                #expect(game.hasLegalSwap, "level \(level.id) attempt \(attempt): no move")
            }
        }
    }

    /// The scanner rewrite must be behaviourally identical where no cargo exists —
    /// which is every shipped night, and every solved move budget.
    @Test func theTransparentScannerIsInertOnCargoFreeBoards() {
        for level in [LuauLevels.debugL1, LuauLevels.debugWell, LuauLevels.debugShelf6] {
            let a = LuauGame(), b = LuauGame()
            a.newLevel(level, attempt: 7)
            b.newLevel(level, attempt: 7)
            while a.resolveStep() {}
            while b.resolveStep() {}
            #expect(a.pieces.map(\.kind) == b.pieces.map(\.kind), "level \(level.id)")
            #expect(a.score == b.score)
            #expect(a.pieces.allSatisfy { !LuauGame.isIngredient($0) })
        }
    }
}

// MARK: - Lesson economy

@MainActor
struct LuauLessonEconomyTests {

    /// THE FREEZE, found by an adversarial audit and shipped in TestFlight 6.
    /// A lesson cannot be failed, but `attemptSwap` gates on `movesLeft > 0`, so
    /// a lesson that ticked to zero accepted no input while `isOver` never
    /// latched — a permanently dead board that survived relaunch. Lessons now
    /// spend no moves at all, which closes it at the source.
    @Test func aLessonNeverSpendsAMoveAndSoCanNeverFreeze() {
        let game = LuauGame()
        game.newLevel(LuauLevels.cargoLesson, attempt: 1)
        while game.resolveStep() {}
        let budget = game.movesLeft
        // The scripted delivery swap is a real clearing move; it must not bill.
        #expect(game.attemptSwap((2, 6), (3, 6)))
        while game.resolveStep() {}
        #expect(game.movesLeft == budget, "a lesson must not spend moves")
        #expect(game.movesLeft > 0, "a lesson must never reach the input gate")
    }

    /// …and the same exemption must not become a points faucet: a lesson never
    /// spends moves, so the ordinary spare-move payout would hand over its whole
    /// authored budget (9,900 on 99 moves) for an unfailable, replayable board.
    @Test func aLessonPaysNoSpareBonusAndDoesNotExtendTheStreak() {
        let game = LuauGame()
        game.newLevel(LuauLevels.cargoLesson, attempt: 1)
        while game.resolveStep() {}
        let streakBefore = game.nightStreak
        #expect(game.attemptSwap((2, 6), (3, 6)))
        while game.resolveStep() {}
        #expect(game.didWinLevel)
        #expect(game.lastSpareBonus == 0, "a lesson paid the spare-move bonus")
        #expect(game.score < LuauGame.spareMoveBonus * 10,
                "a lesson's score should be match points only, not a budget payout")
        #expect(game.nightStreak == streakBefore, "a lesson extended the night streak")
    }

    /// THE REPAIR PATH. A build already in TestFlight can persist a lesson at
    /// movesLeft 0 with isOver false, which `restore` accepts as Case A and
    /// `LuauView.start()` resumes forever — Luau is bricked. Preventing new
    /// freezes is not enough; an existing frozen save has to heal on load.
    @Test func aSaveFrozenAtZeroMovesOnALessonHealsOnRestore() {
        let game = LuauGame()
        game.newLevel(LuauLevels.cargoLesson, attempt: 1)
        while game.resolveStep() {}
        game.testSetMovesLeft(0)          // the shipped freeze, exactly
        #expect(game.isOver == false, "a lesson never latches a defeat")
        let frozen = game.payload(seenHowTo: true)

        let fresh = LuauGame()
        #expect(fresh.restore(from: frozen) != nil)
        #expect(fresh.currentLevel?.id == 902)
        #expect(fresh.movesLeft == LuauLevels.cargoLesson.moves,
                "a restored lesson must come back with a full budget")
        // And it accepts input again — the scripted delivery still works.
        #expect(fresh.attemptSwap((2, 6), (3, 6)) || fresh.hasLegalSwap,
                "the healed board must accept input")
    }

    /// Even at zero moves the input gate must not close on a lesson — the second,
    /// independent reason the freeze cannot recur.
    @Test func aLessonAtZeroMovesStillAcceptsInput() {
        let game = LuauGame()
        game.newLevel(LuauLevels.cargoLesson, attempt: 1)
        while game.resolveStep() {}
        game.testSetMovesLeft(0)
        #expect(game.attemptSwap((2, 6), (3, 6)),
                "a lesson at 0 moves rejected the swap it exists to teach")
    }

    /// A real night must still be stopped by its budget.
    @Test func arealNightAtZeroMovesStillRejectsInput() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        while game.resolveStep() {}
        game.testSetMovesLeft(0)
        let before = game.pieces
        var accepted = false
        for r in 0..<7 { for c in 0..<6 where game.attemptSwap((c, r), (c + 1, r)) { accepted = true } }
        #expect(accepted == false, "a real night at 0 moves must reject every swap")
        #expect(game.pieces == before)
    }

    /// A real night keeps the payout — proves the exemption is scoped to lessons.
    @Test func aRealNightStillPaysTheSpareBonus() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        game.testSetJelly(Array(repeating: 0, count: LuauLevel.cellCount))
        while game.resolveStep() {}
        #expect(game.didWinLevel)
        #expect(game.lastSpareBonus > 0, "a real night must still pay unused moves")
        #expect(game.nightStreak == 1)
    }

    /// The positional splice is what puts the lesson in the campaign at all, and
    /// nothing else asserted it — 902 could silently vanish with the suite green.
    @Test func theCargoLessonIsActuallyInTheCampaign() {
        let all = LuauLevels.all
        let idx = try! #require(LuauLevels.playIndex(of: 902), "cargo lesson is not in `all`")
        #expect(all[idx].teaches == "ingredients")
        // It sits immediately before the night it was declared to precede…
        #expect(LuauLevels.next(after: 902)?.id == 42)
        #expect(all[idx - 1].id == 41)
        // …and splicing it renumbered nothing.
        #expect(LuauLevels.nightNumber(of: 42) == 42)
        #expect(LuauLevels.nightNumber(of: 200) == 200)
        #expect(LuauLevels.nightNumber(of: 902) == nil)
        // A player one night short of it is sent to it next.
        #expect(LuauLevels.frontierLevel(completed: Array(1...41))?.id == 902)
        // The lesson leads straight into the cluster it teaches for.
        #expect(LuauLevels.level(id: 42)?.ingredientTotal == 1)
        #expect(LuauLevels.level(id: 43)?.ingredientTotal == 1)
        #expect(LuauLevels.level(id: 44)?.ingredientTotal == 1)
    }
}

// MARK: - Save / restore

@MainActor
struct LuauCargoSaveTests {

    private func midLevelGame() -> LuauGame {
        let game = LuauGame()
        game.newLevel(fullCargo, attempt: 1)
        paintNullAroundCargo(game)
        return game
    }

    @Test func cargoPositionRoundTripsThroughASave() {
        let game = midLevelGame()
        // Placed rather than swapped: a bare cargo swap no longer commits, and
        // what this guards is that a coconut sitting somewhere OTHER than where
        // the level declared it survives the round trip — not how it got there.
        game.testSetKind((3 + 0) % 5, col: 3, row: 0)
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 4, row: 0)
        let saved = game.payload(seenHowTo: true)
        let fresh = LuauGame()
        #expect(fresh.restore(from: saved) != nil)
        #expect(fresh.currentLevel?.id == fullCargo.id)
        let cargo = try! #require(fresh.pieces.first(where: LuauGame.isIngredient))
        #expect(cargo.col == 4 && cargo.row == 0)
        #expect(fresh.ingredientsCollected == 0)
    }

    @Test func theCollectedCounterRoundTrips() {
        let game = midLevelGame()
        game.testSetIngredientsCollected(1)
        // Remove the board cargo so conservation still balances at 1 + 0 == 1.
        game.testSetPiece(kind: 0, special: .none, col: 3, row: 0)
        let saved = game.payload(seenHowTo: true)
        let fresh = LuauGame()
        #expect(fresh.restore(from: saved) != nil)
        #expect(fresh.ingredientsCollected == 1)
        #expect(fresh.ingredientsRemaining == 0)
    }

    /// A save that lost a piece of cargo must not resume: it would either be
    /// unwinnable or already silently won.
    @Test func aSaveThatLostCargoFallsToAFreshGame() {
        let game = midLevelGame()
        // Cargo gone from the board with nothing banked: 0 + 0 != 1.
        game.testSetPiece(kind: 0, special: .none, col: 3, row: 0)
        let saved = game.payload(seenHowTo: true)
        let fresh = LuauGame()
        fresh.restore(from: saved)
        #expect(fresh.currentLevel == nil, "a cargo-losing save resumed anyway")
    }

    @Test func aSaveWithStrandedCargoFallsToAFreshGame() {
        let game = LuauGame()
        game.newLevel(ledgeCargo, attempt: 1)
        paintNullAroundCargo(game)
        // Force the cargo into the column that never drains.
        game.testSetPiece(kind: 0, special: .none, col: 2, row: 0)
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 3, row: 0)
        let saved = game.payload(seenHowTo: true)
        let fresh = LuauGame()
        fresh.restore(from: saved)
        #expect(fresh.currentLevel == nil, "a stranded save resumed anyway")
    }

    /// Endless has no shore, so cargo there could never be delivered. This is
    /// what lets collectLandedIngredients stay guarded on level mode.
    @Test func anEndlessSaveCarryingCargoFallsToAFreshGame() {
        let game = LuauGame()
        game.newGame()
        game.testSetPiece(kind: LuauGame.ingredientKind, special: .none, col: 0, row: 0)
        let saved = game.payload(seenHowTo: true)
        let fresh = LuauGame()
        fresh.restore(from: saved)
        #expect(fresh.pieces.allSatisfy { !LuauGame.isIngredient($0) })
    }

    /// Every legacy payload predates the field and must decode unchanged.
    @Test func aLegacyPayloadWithoutTheFieldRestoresAtZero() {
        let game = LuauGame()
        game.newLevel(LuauLevels.debugL1, attempt: 1)
        let saved = game.payload(seenHowTo: true)
        #expect(saved.contains("ingredientsCollected") == false,
                "a cargo-free run must not widen the payload")
        let fresh = LuauGame()
        #expect(fresh.restore(from: saved) != nil)
        #expect(fresh.ingredientsCollected == 0)
    }
}

// MARK: - The corner lesson (the sunburst)

@MainActor
struct LuauCornerLessonTests {

    /// Same contract as the cargo lesson, same reason: the SEED is the script.
    /// It was searched for a quiet fresh board whose only bomb-minting swap is
    /// one move, so any change to the fill RNG, the match scan, or the corner
    /// priority silently un-scripts the lesson. This is what makes that loud.
    @Test func cornerLessonMintsABombInASingleSwap() throws {
        let lesson = LuauLevels.cornerLesson
        let game = LuauGame()
        game.newLevel(lesson, attempt: 1)
        while game.resolveStep() {}

        // It must not solve itself — an onboarding with no input teaches nothing.
        #expect(game.pieces.allSatisfy { $0.special != .bomb },
                "the lesson minted its own bomb with no input")
        #expect(game.didWinLevel == false)
        #expect(game.jellyRemaining == 5, "sand sits on the five cells of the corner")

        // The scripted swap draws the L: row (4,2)(5,2)(6,2) and column
        // (4,2)(4,3)(4,4) complete together on the corner cell.
        #expect(game.attemptSwap((3, 2), (4, 2)), "the scripted swap was rejected")
        #expect(game.resolveStep())
        #expect(game.lastClearCount == 5, "the canonical minimum corner")
        let bomb = try #require(game.pieces.first(where: { $0.special == .bomb }),
                                "the corner did not mint a sunburst")
        #expect(bomb.kind == 3)
        while game.resolveStep() {}
        #expect(game.jellyRemaining == 0, "the corner's own cells were the objective")
        #expect(game.didWinLevel, "drawing the corner should clear the lesson")
    }

    /// Unfailable, unnumbered, and in the campaign ahead of the cargo lesson —
    /// a bomb can spawn on Night 1, so this one cannot wait until Night 42.
    @Test func theCornerLessonCannotBeFailedAndSitsEarly() throws {
        let lesson = LuauLevels.cornerLesson
        #expect(lesson.isLesson)
        #expect(lesson.teaches == "corners")
        let game = LuauGame()
        game.newLevel(lesson, attempt: 1)
        game.testSetMovesLeft(0)
        while game.resolveStep() {}
        #expect(game.isOver == false, "a lesson must never latch a defeat")
        #expect(LuauLevels.nightNumber(of: lesson.id) == nil, "a lesson is not a night")

        let order = LuauLevels.all
        let corner = try #require(order.firstIndex { $0.id == lesson.id })
        let cargo = try #require(order.firstIndex { $0.id == LuauLevels.cargoLesson.id })
        #expect(corner < cargo, "the corner is taught before cargo")
        // Sits directly ahead of the night it was placed before, and does not
        // renumber it — the whole point of positional insertion.
        #expect(order[corner + 1].id == 8)
        #expect(LuauLevels.nightNumber(of: 8) == 8, "inserting a lesson must not renumber nights")
    }
}
