#if DEBUG
import Foundation

/// Stage A headless verification. Invoked from `ContentView` when
/// `SIMCTL_CHILD_TIKI_LUAU_SELFTEST=1` is set, so tests run in-process on
/// the simulator with stdout streamed via `simctl launch --console`.
/// Prints one line per check; anything starting with "FAIL" is a
/// regression, and a trailing SUMMARY names the totals.
enum LuauSelfTest {

    static func run() {
        var passed = 0
        var failed = 0
        func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
            let d = detail()
            let head = ok ? "PASS" : "FAIL"
            let suffix = d.isEmpty ? "" : "  — \(d)"
            print("[luau-selftest] \(head)  \(name)\(suffix)")
            if ok { passed += 1 } else { failed += 1 }
        }

        // 1. Level parsing + shape invariants ------------------------------
        for lvl in LuauLevels.all {
            check("level \(lvl.id) (\(lvl.archetype)) column-convex", lvl.isColumnConvex)
            check("level \(lvl.id) mask bit-count == playableCount",
                  lvl.mask.nonzeroBitCount == lvl.playableCount)
            check("level \(lvl.id) jelly array has 49 entries",
                  lvl.jelly.count == LuauLevel.cellCount)
            let onlyOnPlayable = (0..<LuauLevel.cellCount).allSatisfy { i in
                if lvl.jelly[i] > 0 {
                    let row = i / LuauLevel.size, col = i % LuauLevel.size
                    return lvl.isPlayable(col: col, row: row)
                }
                return true
            }
            check("level \(lvl.id) jelly only on playable cells", onlyOnPlayable)
        }

        // 2. Determinism — same (level, attempt) → same fill ---------------
        let g1 = LuauGame(); g1.newLevel(LuauLevels.debugL1, attempt: 42)
        let g2 = LuauGame(); g2.newLevel(LuauLevels.debugL1, attempt: 42)
        let g3 = LuauGame(); g3.newLevel(LuauLevels.debugL1, attempt: 43)
        check("determinism: same (level, attempt) → identical fill",
              signature(of: g1) == signature(of: g2))
        check("determinism: different attempt → different fill",
              signature(of: g1) != signature(of: g3))

        // 3. Mask gravity — pieces only on playable cells ------------------
        let well = LuauGame(); well.newLevel(LuauLevels.debugWell, attempt: 1)
        let lvlWell = LuauLevels.debugWell
        check("Well: piece count == playableCount",
              well.pieces.count == lvlWell.playableCount,
              "\(well.pieces.count) vs \(lvlWell.playableCount)")
        check("Well: no piece on a masked cell",
              well.pieces.allSatisfy { lvlWell.isPlayable(col: $0.col, row: $0.row) })

        // Well cols 0 and 1 are masked at rows 4-6 (`..###..`) → filled
        // rows there are exactly {0,1,2,3}. Cols 2/3/4 span the whole 0..6.
        let col0Rows = Set(well.pieces.filter { $0.col == 0 }.map(\.row))
        let col2Rows = Set(well.pieces.filter { $0.col == 2 }.map(\.row))
        check("Well col 0: filled rows are exactly [0..3] (truncated)",
              col0Rows == Set([0, 1, 2, 3]),
              "got \(col0Rows.sorted())")
        check("Well col 2: filled rows are exactly [0..6] (full)",
              col2Rows == Set([0, 1, 2, 3, 4, 5, 6]),
              "got \(col2Rows.sorted())")

        // 4. Matches never span masked gaps (The Channel) ------------------
        let (chMask, chJelly) = LuauLevel.parse([
            "###.###", "###.###", "###.###", "###.###",
            "###.###", "###.###", "###.###",
        ])
        let channel = LuauLevel(id: 99, mask: chMask, jelly: chJelly, colors: 4,
                                moves: 20, movesHard: 15, seed: 0xCAFE_BABE_DEAD_C0DE,
                                archetype: "The Channel")
        let ch = LuauGame(); ch.newLevel(channel, attempt: 1)
        check("Channel: piece count == 42", ch.pieces.count == 42)
        check("Channel: col 3 fully empty", ch.pieces.allSatisfy { $0.col != 3 })
        // Now install a row with kind X on cols 0,1,2 and cols 4,5,6, and
        // verify hasLegalSwap doesn't hallucinate a legal match spanning
        // the masked col 3.
        for r in 0..<LuauGame.size {
            for c in 0..<LuauGame.size where c != 3 {
                ch.testSetKind(9, col: c, row: r)  // sentinel that never matches
            }
        }
        // Row 3, cols 0,1,2 = kind 5. Cols 4,5,6 = kind 5. Both sides are a
        // 3-in-a-row already (they'd match on both sides), but let's set
        // cols 0,1 = 5 and col 2 = 6, and cols 4,5,6 = 5. If matches
        // spanned the mask, findLegalSwap would find a swap that connects
        // them. They can't, so any legal swap must come from within one
        // reef.
        for c in 0..<3 { ch.testSetKind(9, col: c, row: 3) }
        for c in 4..<7 { ch.testSetKind(9, col: c, row: 3) }
        // Set cols 0,1 = 5, col 2 = 6 (blocker), cols 4,5,6 = 5. Set
        // (2,2) = 5 (so swap (2,3)↔(2,2) would create col-2 vertical 5s,
        // but that's within the left reef — legit). We're only asserting
        // that a would-be *horizontal* 5,5,X,5,5,5 (cols 0,1,2,4,5,6)
        // does NOT count as a match spanning the mask, because the -9 at
        // col 3 breaks the run in findMatches. Verify no matches after a
        // fake state:
        ch.testSetKind(5, col: 0, row: 3)
        ch.testSetKind(5, col: 1, row: 3)
        ch.testSetKind(6, col: 2, row: 3)
        ch.testSetKind(5, col: 4, row: 3)
        ch.testSetKind(5, col: 5, row: 3)
        ch.testSetKind(5, col: 6, row: 3)
        // On row 3 the right reef holds three 5s → that IS a valid match on
        // one side. We assert only that the LEFT and RIGHT don't merge into
        // one super-match. Direct assertion: after resolveStep, only the
        // right-reef three pieces clear; col 2 is not disturbed.
        _ = ch.resolveStep()
        let col2Row3 = ch.pieces.first { $0.col == 2 && $0.row == 3 }
        check("Channel: match on right reef does not clear left of mask",
              col2Row3 != nil,
              "(2,3) present? \(col2Row3 != nil)")

        // 5. Jelly decrement — every clear path ---------------------------
        // Original jelly mask for L1 (recomputed for post-comparison).
        let (_, jL1) = LuauLevel.parse([
            "#######", "#######", "#######",
            "##ooo##",
            "#######", "#######", "#######",
        ])

        // (a) Regular 3-match on row 3.
        let mg = LuauGame(); mg.newLevel(LuauLevels.debugL1, attempt: 1)
        check("L1: jellyRemaining starts at 3", mg.jellyRemaining == 3)
        for r in 0..<LuauGame.size { for c in 0..<LuauGame.size { mg.testSetKind(2, col: c, row: r) } }
        for c in [2, 3, 4] { mg.testSetKind(0, col: c, row: 3) }
        while mg.resolveStep() {}
        let matchRemaining = (0..<LuauLevel.cellCount)
            .filter { jL1[$0] > 0 }
            .map { Int(mg.jelly[$0]) }
            .reduce(0, +)
        check("L1 match clears jelly on match cells", matchRemaining == 0,
              "remaining=\(matchRemaining)")

        // (b) Cat swap wipes all kind-0 → jelly cleared where kind-0 sat.
        let cg = LuauGame(); cg.newLevel(LuauLevels.debugL1, attempt: 1)
        for r in 0..<LuauGame.size { for c in 0..<LuauGame.size { cg.testSetKind(0, col: c, row: r) } }
        cg.testSetPiece(kind: -1, special: .cat, col: 3, row: 3)
        cg.testSetKind(0, col: 3, row: 4)
        _ = cg.attemptSwap((3, 3), (3, 4))
        while cg.resolveStep() {}
        let catRemaining = (0..<LuauLevel.cellCount)
            .filter { jL1[$0] > 0 }
            .map { Int(cg.jelly[$0]) }
            .reduce(0, +)
        check("L1 cat swap clears jelly on wiped cells", catRemaining == 0,
              "remaining=\(catRemaining)")

        // (c) Triggered vertical torch (from row-3 kind-0 3-match): torch
        //     lives at (3,3) with .lineV; row 3 match includes it → clears
        //     entire col 3. Row-3 jelly at (2,3) and (4,3) still clear from
        //     the match itself; (3,3) clears via torch trigger.
        let tg = LuauGame(); tg.newLevel(LuauLevels.debugL1, attempt: 1)
        for r in 0..<LuauGame.size { for c in 0..<LuauGame.size { tg.testSetKind(2, col: c, row: r) } }
        for c in [2, 3, 4] { tg.testSetKind(0, col: c, row: 3) }
        tg.testSetPiece(kind: 0, special: .lineV, col: 3, row: 3)
        while tg.resolveStep() {}
        let torchRemaining = (0..<LuauLevel.cellCount)
            .filter { jL1[$0] > 0 }
            .map { Int(tg.jelly[$0]) }
            .reduce(0, +)
        check("L1 triggered torch clears jelly on triggering match",
              torchRemaining == 0,
              "remaining=\(torchRemaining)")

        // (d) Combo swap (torch + torch) clears a cross including (3,3).
        let bg = LuauGame(); bg.newLevel(LuauLevels.debugL1, attempt: 1)
        for r in 0..<LuauGame.size { for c in 0..<LuauGame.size { bg.testSetKind(2, col: c, row: r) } }
        bg.testSetPiece(kind: 0, special: .lineV, col: 3, row: 3)
        bg.testSetPiece(kind: 0, special: .lineH, col: 3, row: 4)
        let comboOK = bg.attemptSwap((3, 3), (3, 4))
        check("combo swap (torch+torch) accepted", comboOK)
        while bg.resolveStep() {}
        let combo33 = bg.jelly[3 * LuauLevel.size + 3]
        check("L1 combo clears (3,3) jelly", combo33 == 0)

        // 6. Level win/lose edges -----------------------------------------
        let wg = LuauGame(); wg.newLevel(LuauLevels.debugL1, attempt: 1)
        wg.testSetJelly(Array(repeating: 0, count: LuauLevel.cellCount))
        while wg.resolveStep() {}
        check("win: isOver && didWinLevel when jellyRemaining==0",
              wg.isOver && wg.didWinLevel)

        let lg = LuauGame(); lg.newLevel(LuauLevels.debugL1, attempt: 1)
        lg.testSetMovesLeft(0)
        while lg.resolveStep() {}
        check("lose: isOver && !didWinLevel when moves==0 && jelly>0",
              lg.isOver && !lg.didWinLevel && lg.jellyRemaining > 0,
              "isOver=\(lg.isOver) didWin=\(lg.didWinLevel) jelly=\(lg.jellyRemaining)")

        // 7. ENCORE off in level mode -------------------------------------
        let eg = LuauGame(); eg.newLevel(LuauLevels.debugL1, attempt: 1)
        let movesStart = eg.movesLeft
        eg.testSetScore(699)  // one clear from INFERNO
        for r in 0..<LuauGame.size { for c in 0..<LuauGame.size { eg.testSetKind(2, col: c, row: r) } }
        for c in 0..<LuauGame.size { eg.testSetKind(3, col: c, row: 3) }  // row-3 seven-of-kind-3
        while eg.resolveStep() {}
        check("level mode: crossing INFERNO does not extend movesLeft",
              eg.movesLeft <= movesStart,
              "movesLeft=\(eg.movesLeft) (start \(movesStart)) encoreBeat=\(eg.encoreBeat)")

        // Endless mode still fires ENCORE (regression guard).
        let ee = LuauGame(); ee.newGame()
        let endlessStart = ee.movesLeft
        ee.testSetScore(699)
        for r in 0..<LuauGame.size { for c in 0..<LuauGame.size { ee.testSetKind(2, col: c, row: r) } }
        for c in 0..<LuauGame.size { ee.testSetKind(3, col: c, row: 3) }
        while ee.resolveStep() {}
        check("endless mode: ENCORE still fires on crossing INFERNO",
              ee.encoreBeat == 1 && ee.movesLeft > endlessStart - 1,
              "encoreBeat=\(ee.encoreBeat) movesLeft=\(ee.movesLeft) start=\(endlessStart)")

        // 8. Legacy payload decode ----------------------------------------
        let legacyJSON = "{\"seenHowTo\":true,\"score\":420,\"movesLeft\":7,\"board\":\(legacy49BoardJSON())}"
        let leg = LuauGame(); _ = leg.restore(from: legacyJSON)
        check("legacy payload → endless mode with fields intact",
              leg.currentLevel == nil && leg.score == 420 && leg.movesLeft == 7 && leg.pieces.count == 49,
              "level=\(leg.currentLevel?.id ?? -1) score=\(leg.score) moves=\(leg.movesLeft) pcs=\(leg.pieces.count)")

        // 9. Level payload roundtrip -- mid-level state, not game-won ------
        //    A completed level correctly saves board=nil (nothing to
        //    resume); the roundtrip test uses a still-in-progress state.
        let rtA = LuauGame(); rtA.newLevel(LuauLevels.debugL1, attempt: 5)
        // Force a small mutation so state is non-trivial: burn one move
        // but keep jelly intact. A failed swap does neither, so scribble
        // score/moves via the test setters.
        rtA.testSetScore(120)
        rtA.testSetMovesLeft(11)
        let payload = rtA.payload(seenHowTo: true)
        let rtB = LuauGame(); _ = rtB.restore(from: payload)
        let rtOK = rtB.currentLevel?.id == LuauLevels.debugL1.id
            && rtB.score == rtA.score
            && rtB.movesLeft == rtA.movesLeft
            && rtB.jelly == rtA.jelly
            && rtB.pieces.count == rtA.pieces.count
        check("level payload roundtrip preserves level/score/moves/jelly/pieces",
              rtOK,
              "A(id=\(rtA.currentLevel?.id ?? -1) sc=\(rtA.score) mv=\(rtA.movesLeft) pcs=\(rtA.pieces.count)) " +
              "B(id=\(rtB.currentLevel?.id ?? -1) sc=\(rtB.score) mv=\(rtB.movesLeft) pcs=\(rtB.pieces.count))")

        // 9b. Won-level save intentionally has no board — restore falls
        //     to Case C (fresh endless). This is the design; verify it.
        let wonA = LuauGame(); wonA.newLevel(LuauLevels.debugL1, attempt: 1)
        wonA.testSetJelly(Array(repeating: 0, count: LuauLevel.cellCount))
        while wonA.resolveStep() {}
        let wonPayload = wonA.payload(seenHowTo: true)
        let wonB = LuauGame(); _ = wonB.restore(from: wonPayload)
        check("won-level payload: no board → restore drops to endless",
              wonB.currentLevel == nil && wonB.pieces.count == LuauLevel.cellCount,
              "level=\(wonB.currentLevel?.id ?? -1) pcs=\(wonB.pieces.count)")
        check("won-level payload: completedLevels carries the level id",
              wonB.completedLevels.contains(LuauLevels.debugL1.id),
              "completed=\(wonB.completedLevels)")

        // 10. Retry re-seeds spawn stream ---------------------------------
        let ra = LuauGame(); ra.newLevel(LuauLevels.debugL1, attempt: 1)
        ra.retryLevel()
        let rb = LuauGame(); rb.newLevel(LuauLevels.debugL1, attempt: 2)
        check("retryLevel salts the attempt: matches attempt=2 seed exactly",
              signature(of: ra) == signature(of: rb))

        print("[luau-selftest] SUMMARY  passed=\(passed) failed=\(failed)")
    }

    // MARK: helpers

    private static func signature(of g: LuauGame) -> String {
        g.pieces
            .sorted { ($0.row, $0.col) < ($1.row, $1.col) }
            .map { "\($0.col),\($0.row):\($0.kind):\($0.special.rawValue)" }
            .joined(separator: "|")
    }

    private static func legacy49BoardJSON() -> String {
        var arr: [[String: Any]] = []
        for r in 0..<LuauGame.size {
            for c in 0..<LuauGame.size {
                let kind = (c + r) % 2 == 0 ? 4 : 5
                arr.append([
                    "id": UUID().uuidString,
                    "kind": kind,
                    "special": "none",
                    "col": c,
                    "row": r,
                ])
            }
        }
        let data = try? JSONSerialization.data(withJSONObject: arr)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }
}
#endif
