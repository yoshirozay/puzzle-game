import Foundation
import Observation
import Testing
import UIKit
@testable import Tiki_Lounge

// Adversarial unit tests for BlueprintsGame (nonogram engine).
//
// Engine isolation note: BlueprintsGame is @Observable but NOT @MainActor
// (SWIFT_VERSION 6.0, no default-isolation override), so these suites adopt
// @MainActor purely as belt-and-braces consistency with SmokeTests.
//
// Formerly trap-prone probes: tap()/rowClues()/colClues()/rowSatisfied()/
// colSatisfied() used to Array-index TRAP on out-of-range input and begin()
// accepted ragged puzzles. The engine now carries bounds/validation guards,
// so the once-.disabled tests (REGRESSION-tagged below) run live.

// MARK: - Shared helpers

private func puzzle(_ id: String) -> BlueprintsGame.Puzzle {
    BlueprintsGame.puzzles.first { $0.id == id }!
}

private func emptyGrid(_ n: Int) -> [[BlueprintsGame.Cell]] {
    [[BlueprintsGame.Cell]](repeating: [BlueprintsGame.Cell](repeating: .empty, count: n), count: n)
}

private func filledGrid(rows: Int, cols: Int) -> [[BlueprintsGame.Cell]] {
    [[BlueprintsGame.Cell]](repeating: [BlueprintsGame.Cell](repeating: .filled, count: cols), count: rows)
}

/// The exact solution bitmap as a resumable grid: true cells filled, rest empty.
private func solutionGrid(of p: BlueprintsGame.Puzzle) -> [[BlueprintsGame.Cell]] {
    (0..<p.size).map { r in (0..<p.size).map { c in p.truth(r, c) ? BlueprintsGame.Cell.filled : .empty } }
}

private func trueCells(of p: BlueprintsGame.Puzzle) -> [(Int, Int)] {
    var cells: [(Int, Int)] = []
    for r in 0..<p.size {
        for c in 0..<p.size where p.truth(r, c) { cells.append((r, c)) }
    }
    return cells
}

private func firstFalseCell(of p: BlueprintsGame.Puzzle) -> (Int, Int) {
    for r in 0..<p.size {
        for c in 0..<p.size where !p.truth(r, c) { return (r, c) }
    }
    fatalError("test puzzle has no false cell")
}

/// Fill-taps every true cell. From a clean board this solves the puzzle under
/// both rule sets; taps on already-filled cells are harmlessly rejected.
private func fillAllTrueCells(_ game: BlueprintsGame, of p: BlueprintsGame.Puzzle) {
    game.mode = .fill
    for (r, c) in trueCells(of: p) { game.tap(r, c) }
}

/// Every boolean line of `length` whose run pattern equals `clues` — tiny
/// exhaustive enumeration (2^n) for forced-cell proofs on tutorial lines.
/// Every line of `length` whose run pattern equals `clues`.
///
/// Places the runs directly rather than filtering all 2^length lines: the
/// brute-force form costs 1024 arrays per call at width 10, and the
/// whole-table solvability gate calls this for every line of every puzzle
/// until fixpoint. Same set, produced in the order the runs sit.
private func lines(matching clues: [Int], length: Int) -> [[Bool]] {
    if clues == [0] { return [[Bool](repeating: false, count: length)] }
    var out: [[Bool]] = []

    func place(_ i: Int, _ from: Int, _ acc: [Bool]) {
        guard i < clues.count else {
            out.append(acc + [Bool](repeating: false, count: length - acc.count))
            return
        }
        // Leave room for this run, the remaining runs, and one gap between each.
        let tailNeed = clues[i...].reduce(0, +) + (clues.count - i - 1)
        let lastStart = length - tailNeed
        guard from <= lastStart else { return }
        for start in from...lastStart {
            var next = acc + [Bool](repeating: false, count: start - acc.count)
                            + [Bool](repeating: true, count: clues[i])
            if i < clues.count - 1 { next.append(false) }
            place(i + 1, next.count, next)
        }
    }

    place(0, 0, [])
    return out
}

/// Whether a committed cell admits a candidate value (empty admits both).
private func consistent(_ cell: BlueprintsGame.Cell, _ candidate: Bool) -> Bool {
    switch cell {
    case .filled: return candidate
    case .crossed: return !candidate
    case .empty: return true
    }
}

/// Single-line forced-cell propagation: repeatedly intersect each line's
/// candidate solutions (those consistent with committed cells) and commit
/// every cell all candidates agree on. This is exactly the deduction class
/// the tutorial teaches — no guessing, no cross-line search — so a grid it
/// solves is solvable by a player armed with only the taught atoms.
private func lineLogicSolves(_ p: BlueprintsGame.Puzzle, from grid: [[BlueprintsGame.Cell]]) -> Bool {
    var known: [[Bool?]] = grid.map { row in
        row.map { cell -> Bool? in
            switch cell {
            case .filled: return true
            case .crossed: return false
            case .empty: return nil
            }
        }
    }
    var changed = true
    while changed {
        changed = false
        for i in 0..<p.size {
            for isRow in [true, false] {
                let clues = BlueprintsGame.clues(for: (0..<p.size).map { j in isRow ? p.truth(i, j) : p.truth(j, i) })
                let current: [Bool?] = (0..<p.size).map { j in isRow ? known[i][j] : known[j][i] }
                let cands = lines(matching: clues, length: p.size).filter { cand in
                    (0..<p.size).allSatisfy { j in current[j] == nil || current[j] == cand[j] }
                }
                guard !cands.isEmpty else { return false }
                for j in 0..<p.size where current[j] == nil {
                    let agreed = Set(cands.map { $0[j] })
                    if agreed.count == 1 {
                        if isRow { known[i][j] = agreed.first! } else { known[j][i] = agreed.first! }
                        changed = true
                    }
                }
            }
        }
    }
    return (0..<p.size).allSatisfy { r in
        (0..<p.size).allSatisfy { c in known[r][c] == p.truth(r, c) }
    }
}

/// Board metrics for the tightest clue the content gate permits at this size
/// ("1 1 1 1 1" at 9 chars), so geometry assertions test the worst case rather
/// than whichever puzzle happens to be mildest.
@MainActor
private func worstCaseMetrics(_ n: Int, _ screen: CGSize) -> BlueprintsBoardMetrics {
    let runs = (n + 1) / 2                      // widest alternating line
    let clue = Array(repeating: "1", count: runs).joined(separator: " ")
    return BlueprintsBoardMetrics(size: n, screen: screen, widestClue: clue)
}

/// Deterministic mistake farm: wrong-fill a false cell (auto-cross, +1 mistake)
/// then erase the cross in cross mode, `count` times. Leaves the cell empty.
private func farmMistakes(_ game: BlueprintsGame, at cell: (Int, Int), count: Int) {
    for _ in 0..<count {
        game.mode = .fill
        game.tap(cell.0, cell.1)
        game.mode = .cross
        game.tap(cell.0, cell.1)
    }
    game.mode = .fill
}

private func payloadJSON(_ payload: BlueprintsGame.SavePayload) -> String {
    guard let data = try? JSONEncoder().encode(payload),
          let json = String(data: data, encoding: .utf8) else { return "{}" }
    return json
}

private func decodePayload(_ json: String) -> BlueprintsGame.SavePayload? {
    json.data(using: .utf8).flatMap { try? JSONDecoder().decode(BlueprintsGame.SavePayload.self, from: $0) }
}

// MARK: - Parameterized case tables (file-scope so nonisolated argument
// expressions never touch suite state)

private let clueCases: [(line: [Bool], expected: [Int])] = [
    ([], [0]),
    ([false, false], [0]),
    (Array(repeating: true, count: 10), [10]),
    ([true, false, true, false, true], [1, 1, 1]),
    ([false, true, true], [2]),
    ([true, true, false], [2]),
    ([true, false, false, true, true, true], [1, 3]),
]

private let scoreFloorCases: [(id: String, mistakes: Int, expected: Int)] = [
    ("mug", 7, 30), ("mug", 8, 20), ("mug", 9, 20),          // 5x5: floor met exactly at 8
    ("cat", 23, 26), ("cat", 24, 20),                         // 8x8: floor met exactly at 24
    ("volcano", 37, 30), ("volcano", 38, 20),                 // 10x10: floor met exactly at 38
]

private let hostileSaves: [String?] = [
    nil,
    "",
    "not json",
    "{}",                       // missing required seenHowTo/solved
    "[1,2,3]",
    "{\"seenHowTo\":true}",     // missing required solved
    String(repeating: "🗿", count: 100_000),
]

// MARK: - Clue algebra

@MainActor
struct BlueprintsClueAlgebraTests {
    // guards: clues(for:) run-length algebra — all-false lines yield [0] (never []), sum equals true count
    @Test(arguments: clueCases)
    func cluesRunLengthAlgebra(_ c: (line: [Bool], expected: [Int])) {
        let clues = BlueprintsGame.clues(for: c.line)
        #expect(clues == c.expected)
        #expect(!clues.isEmpty)
        #expect(clues.reduce(0, +) == c.line.filter { $0 }.count)
    }

    // guards: every gameplay query is inert on a fresh instance with no puzzle
    @Test func nilPuzzleQueriesAreInert() {
        let game = BlueprintsGame()
        #expect(game.rowClues(0) == [])
        #expect(game.colClues(0) == [])
        #expect(!game.rowSatisfied(0))
        #expect(!game.colSatisfied(0))
        #expect(game.completionScore == 0)
        #expect(!game.tap(0, 0))
        #expect(game.grid.isEmpty)
        #expect(!game.isComplete)
    }
}

// MARK: - Puzzle table & tutorial integrity

@MainActor
struct BlueprintsPuzzleTableTests {
    // guards: the "valid by construction" claim that makes unguarded Array(rows[r])[c] indexing safe for authored content
    @Test func puzzleTableIntegrity() {
        let puzzles = BlueprintsGame.puzzles
        #expect(puzzles.count == 60)
        #expect(Set(puzzles.map(\.id)).count == puzzles.count, "puzzle ids must be unique")
        // The drawer is a ladder: sizes only ever go up, with no gaps.
        let sizes = puzzles.map(\.size)
        #expect(sizes == sizes.sorted(), "puzzles must be ordered smallest board first")
        #expect(Set(sizes) == Set(5...10), "every tier from 5x5 to 10x10 must be represented")
        #expect(puzzles[BlueprintsGame.tutorialPuzzleIndex].id == "mug",
                "the coach's 17 beats are written against the Tiki Mug's exact bitmap")
        for p in puzzles {
            #expect((5...10).contains(p.size), "\(p.id): size must be 5...10")
            var trueCount = 0
            for row in p.rows {
                #expect(row.count == p.size, "\(p.id): every row must match rows.count (square)")
                #expect(row.allSatisfy { ".#+".contains($0) }, "\(p.id): charset must be . # +")
                trueCount += row.filter { $0 == "#" || $0 == "+" }.count
            }
            #expect(trueCount >= 1, "\(p.id): must have at least one true cell")
            for i in 0..<p.size {
                let rowLine = (0..<p.size).map { p.truth(i, $0) }
                let colLine = (0..<p.size).map { p.truth($0, i) }
                let rowRuns = BlueprintsGame.clues(for: rowLine)
                let colRuns = BlueprintsGame.clues(for: colLine)
                #expect(!rowRuns.isEmpty && !colRuns.isEmpty)
                #expect(rowRuns.reduce(0, +) == rowLine.filter { $0 }.count)
                #expect(colRuns.reduce(0, +) == colLine.filter { $0 }.count)
            }
        }
    }

    // guards: the reported "sometimes the player selects a level they just completed" — the auto-advance target must never be a drafted sheet, and never the one just finished
    @Test func nextUnsolvedNeverHandsBackSomethingDrafted() {
        let game = BlueprintsGame()
        let all = BlueprintsGame.puzzles
        // Draft everything except two sheets, one early and one late.
        let keepA = all[3].id, keepB = all[all.count - 2].id
        game.debugSeedSolved(all.count)
        for id in [keepA, keepB] { game.debugUnsolve(id) }

        for p in all {
            guard let next = game.nextUnsolved(after: p.id) else {
                Issue.record("\(p.id): drawer still has unsolved sheets but handed back nil")
                continue
            }
            #expect(next.id != p.id, "\(p.id): handed back the sheet just finished")
            #expect([keepA, keepB].contains(next.id),
                    "\(p.id): handed back \(next.id), which is already drafted")
        }
    }

    // guards: the seam ends rather than looping forever — the last sheet in the drawer has nowhere to go, which is what makes the completion panel (and its leaderboard bar) still reachable
    @Test func nextUnsolvedIsNilOnceTheDrawerIsDone() {
        let game = BlueprintsGame()
        game.debugSeedSolved(BlueprintsGame.puzzles.count)
        for p in BlueprintsGame.puzzles {
            #expect(game.nextUnsolved(after: p.id) == nil,
                    "\(p.id): drawer is fully drafted but the seam still found a target")
        }
    }

    // guards: advancing walks forward through the drawer rather than restarting at the top, so a fresh player meets the sizes in ladder order
    @Test func nextUnsolvedWalksForwardBeforeWrapping() {
        let game = BlueprintsGame()
        let all = BlueprintsGame.puzzles
        // Nothing solved: from each sheet the next one is simply the one after.
        for i in 0..<(all.count - 1) {
            #expect(game.nextUnsolved(after: all[i].id)?.id == all[i + 1].id,
                    "from \(all[i].id) the ladder should continue to \(all[i + 1].id)")
        }
        // From the last sheet it wraps to the first still-undrafted one.
        #expect(game.nextUnsolved(after: all[all.count - 1].id)?.id == all[0].id,
                "the last sheet should wrap to the start of the drawer")
    }

    // guards: the responsive rule applies ONLY from 9x9 up. Carson liked how 5x5-8x8 read and rewriting their geometry was a regression, so those tiers must reproduce the original fixed-box rule exactly, to the point.
    @Test func smallBoardsKeepTheirOriginalGeometry() {
        func old(_ n: Int, _ w: CGFloat) -> CGFloat { w * 0.72 / CGFloat(n) }
        for (name, screen) in [("SE", CGSize(width: 375, height: 667)),
                               ("15", CGSize(width: 393, height: 852)),
                               ("ProMax", CGSize(width: 430, height: 932))] {
            for n in 5...8 {
                let m = worstCaseMetrics(n, screen)
                #expect(m.isLegacy, "\(n)x\(n) must use the original geometry")
                #expect(abs(m.cell - old(n, screen.width)) < 0.001,
                        "\(name) \(n)x\(n): cell is \(m.cell)pt, was \(old(n, screen.width))pt")
                #expect(abs(m.clueW - screen.width * 0.17) < 0.001,
                        "\(name) \(n)x\(n): clue rail changed width")
                #expect(abs(m.clueFont - m.cell * 0.38) < 0.001,
                        "\(name) \(n)x\(n): clue digits changed size")
            }
        }
    }

    // guards: the reported "10x10 hurts the eyes" — the dense tiers must grow instead of holding one box and shrinking their cells. The old rule was a flat 0.72 * width / n, giving 28.3pt at 10x10.
    @Test func bigBoardsGrowInsteadOfShrinkingTheirCells() {
        // iPhone 15/16 logical points — the size Carson plays on.
        let screen = CGSize(width: 393, height: 852)
        func old(_ n: Int) -> CGFloat { screen.width * 0.72 / CGFloat(n) }

        for n in BlueprintsBoardMetrics.responsiveFloor...10 {
            let now = worstCaseMetrics(n, screen).cell
            #expect(!worstCaseMetrics(n, screen).isLegacy, "\(n)x\(n) must use the responsive rule")
            #expect(now > old(n),
                    "\(n)x\(n): cell is \(now)pt, no better than the old fixed box (\(old(n))pt)")
        }
        let ten = worstCaseMetrics(10, screen).cell
        #expect(ten >= 31, "10x10 cell is \(ten)pt — the whole point was to stop it landing near 28pt")
        // Every size stays comfortably tappable.
        for n in 5...10 {
            #expect(worstCaseMetrics(n, screen).cell >= 30, "\(n)x\(n) cell too small")
        }
        // And the ramp stays monotonic across the legacy/responsive seam: a
        // bigger puzzle must never end up with bigger cells than a smaller one.
        for n in 5..<10 {
            let a = worstCaseMetrics(n, screen).cell
            let b = worstCaseMetrics(n + 1, screen).cell
            #expect(a > b, "\(n)x\(n) should have larger cells than \(n+1)x\(n+1)")
        }
    }

    // guards: the widest clue any shipped puzzle can produce actually fits its rail, measured in the real font rather than estimated. At clueCells 1.55 the Sunset "1 1 1 1 1" rows rendered flush against the screen edge.
    @Test func widestRowClueFitsTheRail() {
        let screens: [(String, CGSize)] = [
            ("SE", CGSize(width: 375, height: 667)),
            ("15", CGSize(width: 393, height: 852)),
        ]
        // The real worst case present in the drawer, per size.
        var widest: [Int: String] = [:]
        for p in BlueprintsGame.puzzles {
            for r in 0..<p.size {
                let s = BlueprintsGame.clues(for: (0..<p.size).map { p.truth(r, $0) })
                    .map(String.init).joined(separator: " ")
                if s.count > (widest[p.size]?.count ?? 0) { widest[p.size] = s }
            }
        }
        for (name, screen) in screens {
            for (n, clue) in widest.sorted(by: { $0.key < $1.key }) {
                let m = BlueprintsBoardMetrics(size: n, screen: screen, widestClue: clue)
                guard let font = UIFont(name: "Futura-Bold", size: m.clueFont) else {
                    Issue.record("Futura-Bold unavailable — clue rail cannot be measured")
                    return
                }
                let drawn = (clue as NSString)
                    .size(withAttributes: [.font: font]).width
                let available = m.clueW - BlueprintsBoardMetrics.railPadding
                #expect(drawn <= available,
                        "\(name) \(n)x\(n): widest clue \"\(clue)\" draws \(drawn)pt into a \(available)pt rail")
            }
            // And the theoretical worst the content gate still permits.
            for n in 5...10 {
                let m = worstCaseMetrics(n, screen)
                #expect(m.clueW - BlueprintsBoardMetrics.railPadding
                        >= BlueprintsBoardMetrics.railWidth(m.widestClue, font: m.clueFont)
                           - BlueprintsBoardMetrics.railPadding * 2,
                        "\(name) \(n)x\(n): worst permitted clue does not fit its rail")
            }
        }
    }

    // guards: the board never overflows its screen — the failure the old sizing hid by letting Spacers compress. Checked on the shortest device the app supports as well as the tallest.
    @Test func boardFitsEveryScreenItCanRunOn() {
        let screens: [(String, CGSize)] = [
            ("SE", CGSize(width: 375, height: 667)),
            ("15", CGSize(width: 393, height: 852)),
            ("ProMax", CGSize(width: 430, height: 932)),
        ]
        for (name, screen) in screens {
            for n in 5...10 {
                let m = worstCaseMetrics(n, screen)
                let usedW = m.clueW + m.cell * CGFloat(n) + BlueprintsBoardMetrics.sideMargin * 2
                let usedH = m.clueH + m.cell * CGFloat(n) + BlueprintsBoardMetrics.chromeHeight
                #expect(usedW <= screen.width + 0.5,
                        "\(name) \(n)x\(n): board is \(usedW)pt wide on a \(screen.width)pt screen")
                #expect(usedH <= screen.height + 0.5,
                        "\(name) \(n)x\(n): board is \(usedH)pt tall on a \(screen.height)pt screen")
                #expect(m.clueFont >= BlueprintsBoardMetrics.minClueFont,
                        "\(name) \(n)x\(n): clue digits fell to \(m.clueFont)pt")
            }
        }
    }

    // guards: the run-placement generator that `lines(matching:)` uses is exactly the brute force it replaced. Every solvability result rests on this — a generator that dropped or invented candidates would make the whole-table gate below meaningless while still reporting green.
    @Test func lineGeneratorMatchesBruteForce() {
        for length in 1...10 {
            // Every reachable clue at this width is the clue of some line.
            var seen: Set<[Int]> = []
            for mask in 0..<(1 << length) {
                let line = (0..<length).map { mask & (1 << $0) != 0 }
                seen.insert(BlueprintsGame.clues(for: line))
            }
            for clue in seen {
                let brute = (0..<(1 << length)).compactMap { mask -> [Bool]? in
                    let line = (0..<length).map { mask & (1 << $0) != 0 }
                    return BlueprintsGame.clues(for: line) == clue ? line : nil
                }
                let fast = lines(matching: clue, length: length)
                #expect(Set(fast) == Set(brute),
                        "clue \(clue) at width \(length): generator produced \(fast.count), brute force \(brute.count)")
                #expect(fast.count == Set(fast).count,
                        "clue \(clue) at width \(length): generator emitted duplicates")
            }
        }
    }

    // guards: no shipped sheet ever forces a guess. lineLogicSolves used to be pointed only at the tutorial mug, so the other 29 boards were unverified; with a flat 3-mistake cap a single forced guess costs a third of the budget, and asymmetric art breaks this far more easily than mirrored art
    @Test func everyPuzzleFallsToLineLogicAlone() {
        for p in BlueprintsGame.puzzles {
            let game = BlueprintsGame()
            game.begin(p)
            #expect(lineLogicSolves(p, from: game.grid),
                    "\(p.id) (\(p.size)x\(p.size)) cannot be solved from an empty grid by single-line deduction — it forces a guess")
        }
    }

    // guards: the reported "totem didn't show" bug — its woodDark primary was identical to the DRAFTED card's woodDark fill (1.00:1), and 23 of 30 sheets sat under 3:1 against the panel or the picker card. The mat is derived from each palette, so this also covers art added later.
    @Test func everyRevealClearsItsMat() {
        for p in BlueprintsGame.puzzles {
            let (primary, _) = BlueprintColors.for(p.id)
            let mat = BlueprintColors.mat(for: p.id)
            let ratio = BlueprintColors.contrast(primary, mat)
            #expect(ratio >= 3.0,
                    "\(p.id): silhouette scores \(String(format: "%.2f", ratio)):1 against its mat — the picture will not read")
        }
    }

    // guards: the mat is a real choice between two sheets, not a constant that happens to pass. If both branches collapsed to one colour the gate above would still be green while dark and light subjects alike sat on the same backing.
    @Test func matPicksBothSheetsAcrossTheDrawer() {
        let mats = BlueprintsGame.puzzles.map { BlueprintColors.mat(for: $0.id) }
        let light = mats.filter { BlueprintColors.contrast($0, BlueprintColors.lightMat) == 1.0 }
        let dark = mats.filter { BlueprintColors.contrast($0, BlueprintColors.darkMat) == 1.0 }
        #expect(!light.isEmpty, "no puzzle uses the light mat")
        #expect(!dark.isEmpty, "no puzzle uses the dark mat")
        #expect(light.count + dark.count == mats.count, "a mat outside the declared pair")
    }

    // guards: the tutorial's 100%-first-tap-success promise — fill beats target true cells, cross beats false cells, and the full script never trips a mistake
    @Test func tutorialBeatsAreGuaranteedSafe() {
        let p = BlueprintsGame.puzzles[BlueprintsGame.tutorialPuzzleIndex]
        for beat in BlueprintsGame.tutorialBeats {
            switch beat.mode {
            case .fill: #expect(p.truth(beat.row, beat.col), "fill beat must target a true cell")
            case .cross: #expect(!p.truth(beat.row, beat.col), "cross beat must target a false cell")
            }
        }
        let game = BlueprintsGame()
        game.begin(p)
        for beat in BlueprintsGame.tutorialBeats {
            game.mode = beat.mode
            #expect(game.tap(beat.row, beat.col))
        }
        #expect(game.mistakes == 0, "the scripted tutorial can never produce a mistake")
        #expect(game.fillBeat == 13)  // 5 (row 2) + 3 (row 0) + 2 (col 1) + 3 (row 3)
        #expect(!game.isComplete, "the script must never finish the mug — the reveal is the player's")
        #expect(game.rowSatisfied(2) && game.rowSatisfied(0) && game.colSatisfied(1) && game.rowSatisfied(3),
                "the four taught lines end the script visibly satisfied")
    }

    // guards: rubric v2 dim 2 honesty — every cross beat is forced (provably empty in its row or its column) by the cells committed before it fires; marks are derived, never take-on-faith
    @Test func tutorialMarksAreForcedWhenTheyFire() {
        let p = BlueprintsGame.puzzles[BlueprintsGame.tutorialPuzzleIndex]
        let game = BlueprintsGame()
        game.begin(p)
        for beat in BlueprintsGame.tutorialBeats {
            if beat.mode == .cross {
                let rowCands = lines(matching: game.rowClues(beat.row), length: p.size).filter { cand in
                    (0..<p.size).allSatisfy { c in consistent(game.grid[beat.row][c], cand[c]) }
                }
                let colCands = lines(matching: game.colClues(beat.col), length: p.size).filter { cand in
                    (0..<p.size).allSatisfy { r in consistent(game.grid[r][beat.col], cand[r]) }
                }
                let rowForced = !rowCands.isEmpty && rowCands.allSatisfy { !$0[beat.col] }
                let colForced = !colCands.isEmpty && colCands.allSatisfy { !$0[beat.row] }
                #expect(rowForced || colForced,
                        "cross beat (\(beat.row),\(beat.col)) must be derivable from the board, not asserted")
            }
            game.mode = beat.mode
            #expect(game.tap(beat.row, beat.col))
        }
    }

    // guards: rubric v2 dim 3 — every card names the clue value it acts on, stays ≤ 9 words, and phases never share copy
    @Test func tutorialCardsAreReasoned() {
        for beat in BlueprintsGame.tutorialBeats {
            #expect(beat.message.contains(where: { $0.isNumber }),
                    "card \"\(beat.message)\" must name the clue value it acts on")
            let words = beat.message.split(separator: " ").filter { $0 != "—" }
            #expect(words.count <= 9, "card \"\(beat.message)\" exceeds 9 words")
        }
        #expect(Set(BlueprintsGame.tutorialBeats.map(\.message)).count == 7,
                "seven phase cards, all distinct (READ, run, marks, three stacked-clue steps, and the 1 1 1 generalizer)")
    }

    // guards: rubric v3 dim 10 — the script leaves ≥ 6 true cells of solo runway (floor lowered 8→6 when the 1 1 1 phase was added) and the remainder falls to single-line deductions alone (no guessing, no cross-line search)
    @Test func tutorialLeavesSolvableRunway() {
        let p = BlueprintsGame.puzzles[BlueprintsGame.tutorialPuzzleIndex]
        let game = BlueprintsGame()
        game.begin(p)
        for beat in BlueprintsGame.tutorialBeats {
            game.mode = beat.mode
            game.tap(beat.row, beat.col)
        }
        let remaining = trueCells(of: p).filter { game.grid[$0.0][$0.1] != .filled }.count
        #expect(remaining >= 6, "script must leave a solo runway (left \(remaining))")
        #expect(lineLogicSolves(p, from: game.grid),
                "the post-script remainder must fall to single-line deductions")
    }

    // guards: rubric v2 dim 6 — clue geometry fits the reserved bands: no shipped column stacks more than 4 runs (the clueH = 2.4-cell ceiling), no row string outgrows the rail
    @Test func clueGeometryFitsTheBands() {
        for p in BlueprintsGame.puzzles {
            for i in 0..<p.size {
                let colRuns = BlueprintsGame.clues(for: (0..<p.size).map { p.truth($0, i) })
                #expect(colRuns.count <= 4, "\(p.id) col \(i): \(colRuns.count) stacked runs would overflow the clue band")
                let rowRuns = BlueprintsGame.clues(for: (0..<p.size).map { p.truth(i, $0) })
                let rowString = rowRuns.map(String.init).joined(separator: " ")
                #expect(rowString.count <= 9, "\(p.id) row \(i): clue string \"\(rowString)\" outgrows the rail")
            }
        }
    }
}

// MARK: - Sketch rules

@MainActor
struct BlueprintsSketchRulesTests {
    // guards: sketch soundness — every branch auto-corrects so fills imply truth and crosses imply !truth
    @Test func sketchTapBranchSemantics() {
        let mug = puzzle("mug")
        let game = BlueprintsGame()
        game.begin(mug)

        #expect(game.tap(2, 2))                       // fill on true cell
        #expect(game.grid[2][2] == .filled && game.fillBeat == 1)
        #expect(game.tap(0, 0))                       // fill on FALSE cell -> auto-cross
        #expect(game.grid[0][0] == .crossed)
        #expect(game.mistakes == 1 && game.mistakeBeat == 1)
        #expect(!game.tap(2, 2), "fills are permanent in fill mode")
        #expect(!game.tap(0, 0), "crossed cells cannot be painted over in fill mode")

        game.mode = .cross
        #expect(game.tap(2, 0))                       // cross on TRUE cell -> auto-fill + mistake
        #expect(game.grid[2][0] == .filled)
        #expect(game.mistakes == 2 && game.mistakeBeat == 2)
        #expect(game.fillBeat == 1, "auto-fill from a wrong cross must not bump fillBeat")
        #expect(game.tap(0, 4))                       // cross on false cell: no mistake
        #expect(game.grid[0][4] == .crossed && game.mistakes == 2)
        #expect(game.tap(0, 0))                       // crosses are erasable in cross mode
        #expect(game.grid[0][0] == .empty)
        #expect(!game.tap(2, 2), "fills are permanent in cross mode too")

        for r in 0..<mug.size {
            for c in 0..<mug.size {
                if game.grid[r][c] == .filled { #expect(mug.truth(r, c)) }
                if game.grid[r][c] == .crossed { #expect(!mug.truth(r, c)) }
            }
        }
    }

    // guards: sketch completion fires exactly on the last true fill — including when it arrives via the wrong-cross auto-fill branch — and a flawless sketch never stamps the draft-exclusive FAIR COPY
    @Test func sketchCompletesExactlyOnLastTrueFillAndNeverStampsFairCopy() {
        let mug = puzzle("mug")
        let game = BlueprintsGame()
        game.begin(mug)
        let cells = trueCells(of: mug)
        for (r, c) in cells.dropLast() {
            #expect(game.tap(r, c))
            #expect(!game.isComplete)
        }
        let last = cells.last!
        #expect(game.tap(last.0, last.1))
        #expect(game.isComplete)
        #expect(game.completedFirstSolve)
        #expect(game.solvedIDs == ["mug"])
        #expect(game.mistakes == 0)
        #expect(game.completionScore == 100)          // 5*5*4 - 0

        // completion must ALSO fire when the last true cell arrives via a wrong cross
        // (sketchTap's cross-on-true auto-fill branch calls checkComplete too)
        game.begin(mug)
        for (r, c) in cells.dropLast() { #expect(game.tap(r, c)) }
        game.mode = .cross
        #expect(game.tap(last.0, last.1))             // wrong cross -> auto-fill + mistake
        #expect(game.isComplete, "auto-fill of the final true cell from a wrong cross must complete the puzzle")
        #expect(game.mistakes == 1)
        #expect(game.completionScore == 90)           // 5*5*4 - 1*10
    }

    // guards: post-completion freeze — no tap in any mode can mutate a solved board
    @Test func completedBoardFreezesAllTaps() {
        let mug = puzzle("mug")
        let game = BlueprintsGame()
        game.begin(mug)
        fillAllTrueCells(game, of: mug)
        #expect(game.isComplete)
        let grid = game.grid
        let counters = (game.mistakes, game.fillBeat, game.mistakeBeat)
        for m in [BlueprintsGame.Mode.fill, .cross] {
            game.mode = m
            for r in 0..<mug.size {
                for c in 0..<mug.size { #expect(!game.tap(r, c)) }
            }
        }
        #expect(game.grid == grid)
        #expect((game.mistakes, game.fillBeat, game.mistakeBeat) == counters)
        #expect(game.isComplete)
        #expect(game.solvedIDs == ["mug"], "Set semantics: no double insert")
    }

    // guards: SUSPECTED-BUG(mistake-farming) PROVEN — under the coach shield, mistakes stay farmable on a single cell (fill-wrong/erase loop); the live cap only applies outside the shield
    @Test func mistakesAreFarmableOnASingleCell() {
        let game = BlueprintsGame()
        game.begin(puzzle("mug"))
        game.setCoachShield(true)
        farmMistakes(game, at: (0, 0), count: 5)
        #expect(game.mistakes == 5 && game.mistakeBeat == 5)
        #expect(game.grid[0][0] == .empty)
        #expect(game.fillBeat == 0)
        #expect(!game.isFailed, "coach shield never trips the cap")
    }

    // guards: sketch score formula max(20, n^2*4 - mistakes*10) at the exact floor thresholds for all three board sizes
    @Test(arguments: scoreFloorCases)
    func sketchScoreFloor(_ c: (id: String, mistakes: Int, expected: Int)) {
        let p = puzzle(c.id)
        let game = BlueprintsGame()
        game.begin(p)
        // Score algebra probes need counters past the live cap — shield on.
        game.setCoachShield(true)
        farmMistakes(game, at: firstFalseCell(of: p), count: c.mistakes)
        fillAllTrueCells(game, of: p)
        #expect(game.isComplete)
        #expect(game.mistakes == c.mistakes)
        #expect(game.completionScore == c.expected)
    }

    // guards: SUSPECTED-BUG(sketch-wrong-picture) PROVEN — sketch checkComplete only audits true cells, so a hostile resume with filled FALSE cells still completes (pinned; organic sketch play cannot reach this)
    @Test func sketchCompletionIgnoresFilledFalseCells() {
        let mug = puzzle("mug")
        var seeded = emptyGrid(5)
        seeded[0][0] = .filled                        // false cell
        seeded[4][4] = .filled                        // false cell
        let game = BlueprintsGame()
        game.begin(mug, resuming: seeded)
        fillAllTrueCells(game, of: mug)
        #expect(game.isComplete, "sketch completion never audits false cells — wrong picture completes")
        #expect(game.grid[0][0] == .filled && game.grid[4][4] == .filled)
    }

    // guards: completedFirstSolve computed from solvedIDs BEFORE insert; PROVES SUSPECTED-BUG(first-solve-stale, benign) — begin() never resets it, so it carries the previous run's value until the next completion
    @Test func firstSolveFlagRecomputesPerCompletionButIsStaleBetween() {
        let mug = puzzle("mug")
        let hibiscus = puzzle("hibiscus")
        let game = BlueprintsGame()
        game.begin(mug)
        fillAllTrueCells(game, of: mug)
        #expect(game.completedFirstSolve)

        game.begin(mug)
        fillAllTrueCells(game, of: mug)
        #expect(!game.completedFirstSolve, "replay of an already-solved id must report false")
        #expect(game.solvedIDs == ["mug"])

        game.begin(hibiscus)
        #expect(!game.completedFirstSolve, "pinned staleness: begin() does not reset the flag")
        fillAllTrueCells(game, of: hibiscus)
        #expect(game.completedFirstSolve, "recomputed correctly at the next completion")
    }
}

// MARK: - Boundary & degenerate input

@MainActor
struct BlueprintsBoundaryTests {
    // REGRESSION(tap-bounds): tap() used to trap on grid[r][c] / Array(rows[r])[c]
    // for out-of-range coordinates; it now carries a bounds guard.
    // guards: out-of-bounds taps return false without mutation
    @Test(arguments: [(-1, 0), (0, -1), (5, 0), (0, 5), (5, 5), (-1, -1)] as [(Int, Int)])
    func outOfBoundsTapReturnsFalseWithoutMutation(_ rc: (Int, Int)) {
        let game = BlueprintsGame()
        game.begin(puzzle("mug"))
        let before = game.grid
        #expect(!game.tap(rc.0, rc.1))
        #expect(game.grid == before)
        #expect(game.mistakes == 0 && game.fillBeat == 0 && game.mistakeBeat == 0)
    }

    // REGRESSION(line-query-bounds): rowSatisfied(-1) used to trap on grid[-1],
    // colSatisfied had no column guard, and rowClues/colClues routed bad indices
    // into Puzzle.truth's unguarded indexing. All four are now range-guarded.
    // rowSatisfied(size) was always the one graceful path pre-fix — kept here so
    // the upper bound stays pinned.
    // guards: out-of-range line queries are inert (false / [])
    @Test
    func outOfBoundsLineQueriesAreInert() {
        let game = BlueprintsGame()
        game.begin(puzzle("mug"))
        #expect(!game.rowSatisfied(5))
        #expect(!game.rowSatisfied(-1))
        #expect(!game.colSatisfied(-1))
        #expect(!game.colSatisfied(5))
        #expect(game.rowClues(5) == [])
        #expect(game.rowClues(-1) == [])
        #expect(game.colClues(5) == [])
        #expect(game.colClues(-1) == [])
    }

    // guards: minimal 1x1 board completes on a single tap with the score floor dominating
    @Test func oneByOnePuzzleCompletesInOneTap() {
        let tiny = BlueprintsGame.Puzzle(id: "dot", name: "Dot", rows: ["#"])
        let game = BlueprintsGame()
        game.begin(tiny)
        #expect(game.grid == [[.empty]])
        #expect(game.tap(0, 0))
        #expect(game.isComplete)
        #expect(game.completedFirstSolve)
        #expect(game.solvedIDs == ["dot"])
        #expect(game.completionScore == 20)           // max(20, 1*1*4 - 0)
    }

    // guards: SUSPECTED-BUG(degenerate-puzzle) PROVEN — begin() performs no puzzle validation: a zero-cell board is accepted and the score floor pays 20 for it (pinned absurdity; the static-table audit is the compensating control)
    @Test func emptyPuzzleAcceptedWithFloorScore() {
        let void = BlueprintsGame.Puzzle(id: "void", name: "Void", rows: [])
        let game = BlueprintsGame()
        game.begin(void)
        #expect(game.puzzle != nil)
        #expect(game.grid.isEmpty)
        #expect(!game.isComplete)
        #expect(game.completionScore == 20, "pinned: the score floor pays 20 for a zero-cell board")
    }

    // REGRESSION(puzzle-validation): a ragged Puzzle built via the accessible
    // memberwise init used to pass begin() silently and Puzzle.truth trapped on
    // the first tap into the missing column. begin() now rejects ragged puzzles
    // at the door (puzzle stays nil, all gameplay inert).
    // guards: hostile non-square puzzles are rejected by begin()
    @Test func raggedPuzzleTapIsRejected() {
        let ragged = BlueprintsGame.Puzzle(id: "bad", name: "Bad", rows: ["##", "#"])
        let game = BlueprintsGame()
        game.begin(ragged)
        #expect(game.puzzle == nil, "ragged puzzles are rejected at the door")
        #expect(!game.tap(1, 1))
    }

    #if DEBUG
    // guards: debugSeedSolved prefix-clamps to the table size at 0 / partial / exact / overshoot. Expressed against puzzles.count rather than a literal so growing the drawer can't leave this asserting a stale size.
    @Test(arguments: [0, 30, BlueprintsGame.puzzles.count, 130])
    func debugSeedClampsToTable(_ n: Int) {
        let game = BlueprintsGame()
        game.debugSeedSolved(n)
        #expect(game.solvedIDs.count == min(n, BlueprintsGame.puzzles.count))
    }

    // REGRESSION(debug-seed-negative): prefix(-1) used to trip Array.prefix's
    // negative-length precondition, so a stray "-1" in the TIKI_BLUEPRINTS_SOLVED
    // scheme env killed the app at launch. Negative counts now clamp to zero.
    // guards: negative seed counts are treated as zero
    @Test func debugSeedNegativeIsTreatedAsZero() {
        let game = BlueprintsGame()
        game.debugSeedSolved(-1)
        #expect(game.solvedIDs.isEmpty)
    }
    #endif
}

// MARK: - Lifecycle

@MainActor
struct BlueprintsLifecycleTests {
    // guards: begin-over-begin resets run state (grid/counters/flags/mode/summary) but preserves progress sets and instance-lifetime juice counters
    @Test func beginOverBeginResetsRunStateKeepsProgressAndJuice() {
        let game = BlueprintsGame()
        game.begin(puzzle("mug"))
        #expect(game.tap(2, 2)); #expect(game.tap(2, 0))                    // 2 fills
        for cell in [(0, 0), (0, 4), (4, 0)] { #expect(game.tap(cell.0, cell.1)) }  // 3 mistakes → fail
        #expect(game.isFailed)
        game.mode = .cross
        game.lastRunSummary = RunSummary(best: 1, isNewBest: false, pointsEarned: 1, totalPoints: 1)
        #expect(game.mistakes == 3 && game.fillBeat == 2)

        game.begin(puzzle("hibiscus"))
        #expect(game.puzzle?.id == "hibiscus")
        #expect(game.grid == emptyGrid(5))
        #expect(game.mistakes == 0)
        #expect(!game.isComplete)
        #expect(!game.isFailed)
        #expect(game.lastRunSummary == nil)
        #expect(game.mode == .fill)
        #expect(game.fillBeat == 2 && game.mistakeBeat == 3, "juice counters are instance-lifetime monotone — begin does not reset them")
        #expect(game.solvedIDs.isEmpty)
    }

    // guards: the documented SwiftUI-teardown contract — closePuzzle keeps the grid populated but makes every gameplay API inert
    @Test func closePuzzleMakesGameplayInertButKeepsGrid() {
        let game = BlueprintsGame()
        game.begin(puzzle("mug"))
        #expect(game.tap(2, 2))
        game.closePuzzle()
        #expect(game.puzzle == nil)
        #expect(!game.isComplete)
        #expect(!game.tap(2, 3))
        #expect(!game.rowSatisfied(0) && !game.colSatisfied(0))
        #expect(game.rowClues(0) == [] && game.colClues(0) == [])
        #expect(game.completionScore == 0)
        #expect(game.grid.count == 5, "grid deliberately stays populated for ForEach teardown — do not 'fix' this into a crash")
        #expect(game.grid[2][2] == .filled)
    }

    // guards: completionScore must be captured before closePuzzle — the payoff drops to 0 the moment the puzzle nils
    @Test func completionScoreMustBeReadBeforeClose() {
        let cat = puzzle("cat")
        let game = BlueprintsGame()
        game.begin(cat)
        fillAllTrueCells(game, of: cat)
        #expect(game.isComplete)
        #expect(game.completionScore == 256)          // 8*8*4, no mistakes
        game.closePuzzle()
        #expect(game.completionScore == 0)
    }

}

// MARK: - Persistence

@MainActor
struct BlueprintsPersistenceTests {
    // guards: restore of garbage payloads returns nil and leaves ALL previously-restored state untouched (decode is atomic)
    @Test(arguments: hostileSaves)
    func restoreRejectsGarbageAtomically(_ json: String?) {
        let game = BlueprintsGame()
        let seed = payloadJSON(.init(
            seenHowTo: true, solved: ["mug", "hibiscus"], currentID: nil, currentGrid: nil,
            currentMistakes: nil, mistakeHint: nil))
        #expect(game.restore(from: seed) != nil)
        #expect(game.restore(from: json) == nil)
        #expect(game.solvedIDs == ["mug", "hibiscus"])
        #expect(game.puzzle == nil)
    }

    // guards: an invalid Cell raw value fails the whole decode atomically — the hostile payload's solved list must not leak in
    @Test func invalidCellRawValueDecodeIsAtomic() {
        let game = BlueprintsGame()
        let seed = payloadJSON(.init(
            seenHowTo: false, solved: ["anchor"], currentID: nil, currentGrid: nil,
            currentMistakes: nil, mistakeHint: nil))
        #expect(game.restore(from: seed) != nil)

        let row = "[\"empty\",\"empty\",\"empty\",\"empty\",\"empty\"]"
        let badRow = "[\"filled\",\"BANANA\",\"empty\",\"empty\",\"empty\"]"
        let hostile = "{\"seenHowTo\":true,\"solved\":[\"hibiscus\",\"mug\"],\"currentID\":\"mug\",\"currentGrid\":[\(badRow),\(row),\(row),\(row),\(row)],\"currentMistakes\":0,\"currentRules\":\"sketch\",\"preferredRules\":\"draft\",\"fairCopies\":[\"mug\"],\"currentSlips\":0}"
        #expect(game.restore(from: hostile) == nil)
        #expect(game.solvedIDs == ["anchor"], "hostile solved list must not leak in on a mid-payload decode failure")
        #expect(game.puzzle == nil)
    }

    // guards: unicode ids survive restore + payload losslessly, duplicates collapse, unknown currentID falls back safely
    @Test func unicodeIDsSurviveRoundTrip() {
        let hostile = BlueprintsGame.SavePayload(
            seenHowTo: true,
            solved: ["mug", "mug", "🗿🌺", "\u{0}weird", "é"],
            currentID: "🗿",
            currentGrid: nil, currentMistakes: nil, mistakeHint: nil)
        let game = BlueprintsGame()
        #expect(game.restore(from: payloadJSON(hostile)) != nil)
        #expect(game.solvedIDs == ["mug", "🗿🌺", "\u{0}weird", "é"])
        #expect(game.puzzle == nil, "currentID \"🗿\" matches no puzzle in the table")

        let second = BlueprintsGame()
        #expect(second.restore(from: game.payload(seenHowTo: true, mistakeHint: false)) != nil)
        #expect(second.solvedIDs == game.solvedIDs)
    }

    // guards: negative persisted counters clamp to 0 (not stuck negative) — a subsequent flawless finish still scores clean
    @Test func negativeSavedCountersClampToZero() {
        let mug = puzzle("mug")
        var grid = solutionGrid(of: mug)
        grid[2][2] = .empty                           // one true cell left to fill
        let payload = BlueprintsGame.SavePayload(
            seenHowTo: false, solved: [], currentID: "mug", currentGrid: grid,
            currentMistakes: -999, mistakeHint: nil)
        let game = BlueprintsGame()
        #expect(game.restore(from: payloadJSON(payload)) != nil)
        #expect(game.mistakes == 0)
        #expect(game.tap(2, 2))
        #expect(game.isComplete)
        #expect(game.completionScore == 100)          // 5*5*4, clamped mistakes
    }

    // guards: every dimension-hostile resume is rejected into a fresh empty grid, and the saved mistakes do not leak through the rejection
    @Test(arguments: ["4x5", "5x4", "ragged", "8x8", "1000x1000"])
    func hostileResumeDimensionsRejected(_ tag: String) {
        let hostile: [[BlueprintsGame.Cell]]
        switch tag {
        case "4x5": hostile = filledGrid(rows: 4, cols: 5)
        case "5x4": hostile = filledGrid(rows: 5, cols: 4)
        case "ragged":
            var g = filledGrid(rows: 5, cols: 5)
            g[3].append(.filled)
            hostile = g
        case "8x8": hostile = filledGrid(rows: 8, cols: 8)
        default: hostile = filledGrid(rows: 1000, cols: 1000)
        }
        let game = BlueprintsGame()
        game.begin(puzzle("mug"), resuming: hostile, mistakes: 9)
        #expect(game.grid == emptyGrid(5))
        #expect(game.mistakes == 0, "saved mistakes must not survive a rejected resume")
    }

    // guards: forward compat (unknown keys ignored) and backward compat (vintage and DRAFT-era payloads decode with safe defaults)
    @Test func forwardAndBackwardCompatiblePayloads() throws {
        let future = "{\"seenHowTo\":false,\"solved\":[\"mug\"],\"futureField\":42}"
        let game = BlueprintsGame()
        #expect(game.restore(from: future) != nil)
        #expect(game.solvedIDs == ["mug"])
        #expect(game.puzzle == nil)

        var grid = emptyGrid(5)
        grid[2][2] = .filled
        let gridJSON = String(data: try JSONEncoder().encode(grid), encoding: .utf8)!
        let vintage = "{\"seenHowTo\":true,\"solved\":[],\"currentID\":\"mug\",\"currentGrid\":\(gridJSON)}"
        let game2 = BlueprintsGame()
        #expect(game2.restore(from: vintage) != nil)
        #expect(game2.puzzle?.id == "mug")
        #expect(game2.grid[2][2] == .filled)
        #expect(game2.mistakes == 0)
    }

    // guards: mid-solve payload->restore reproduces the exact grid and a POSITIVE mistake count with mode and juice reset, and a second round trip is a field-wise fixed point
    @Test func midSolveRoundTripIsFixedPoint() {
        let cat = puzzle("cat")
        let g1 = BlueprintsGame()
        g1.begin(cat)
        #expect(g1.tap(0, 2)); #expect(g1.tap(0, 3))                  // 2 wrong fills -> auto-crossed mistakes
        #expect(g1.mistakes == 2)
        g1.mode = .cross
        #expect(g1.tap(0, 4)); #expect(g1.tap(0, 5)); #expect(g1.tap(5, 3))   // 3 crosses
        g1.mode = .fill
        #expect(g1.tap(2, 0)); #expect(g1.tap(2, 1)); #expect(g1.tap(2, 2)); #expect(g1.tap(2, 3))  // 4 correct fills
        g1.mode = .cross

        let saved = g1.payload(seenHowTo: true, mistakeHint: false)
        let g2 = BlueprintsGame()
        #expect(g2.restore(from: saved) != nil)
        #expect(g2.puzzle?.id == "cat")
        #expect(g2.grid == g1.grid)
        #expect(g2.mistakes == 2, "positive mistakes must survive the save round trip")
        #expect(!g2.isComplete)
        #expect(g2.mode == .fill, "mode is not persisted — resets to .fill")
        #expect(g2.fillBeat == 0 && g2.mistakeBeat == 0, "juice counters are not persisted")
        #expect(g2.solvedIDs == g1.solvedIDs)

        let p1 = decodePayload(saved)
        let p2 = decodePayload(g2.payload(seenHowTo: true, mistakeHint: false))
        #expect(p1 != nil && p2 != nil)
        if let p1, let p2 {
            #expect(p1.seenHowTo == p2.seenHowTo)
            #expect(p1.seenHowTo, "payload must write the caller's seenHowTo, not a constant")
            #expect(Set(p1.solved) == Set(p2.solved))
            #expect(p1.currentID == p2.currentID)
            #expect(p1.currentGrid == p2.currentGrid)
            #expect(p1.currentMistakes == p2.currentMistakes)
            #expect(p1.mistakeHint == p2.mistakeHint)
        }

    }

    // guards: the `live` gate — a completed game persists no board, restores to puzzle nil, and replay detection survives the round trip
    @Test func completedGameRoundTripDropsBoard() {
        let mug = puzzle("mug")
        let g1 = BlueprintsGame()
        g1.begin(mug)
        fillAllTrueCells(g1, of: mug)
        #expect(g1.isComplete)

        let saved = g1.payload(seenHowTo: true, mistakeHint: false)
        let decoded = decodePayload(saved)
        #expect(decoded?.currentID == nil)
        #expect(decoded?.currentGrid == nil)
        #expect(decoded?.currentMistakes == nil)
        #expect(decoded?.solved.contains("mug") == true)

        let g2 = BlueprintsGame()
        #expect(g2.restore(from: saved) != nil)
        #expect(g2.puzzle == nil)
        g2.begin(mug)
        fillAllTrueCells(g2, of: mug)
        #expect(g2.isComplete)
        #expect(!g2.completedFirstSolve, "replay detection must survive the save round trip")
    }

    // guards: SUSPECTED-BUG(restore-half-overwrite) PROVEN — restore on a live game with currentID nil wholesale-replaces the progress sets while leaving the in-progress puzzle untouched (pinned footgun; the app only restores at view-appear on a fresh instance)
    @Test func restoreLeavesLivePuzzleButReplacesProgressSets() {
        let game = BlueprintsGame()
        game.begin(puzzle("mug"))
        #expect(game.tap(2, 2)); #expect(game.tap(2, 0))
        let payload = BlueprintsGame.SavePayload(
            seenHowTo: false, solved: ["hibiscus"], currentID: nil, currentGrid: nil,
            currentMistakes: nil, mistakeHint: nil)
        #expect(game.restore(from: payloadJSON(payload)) != nil)
        #expect(game.puzzle?.id == "mug", "restore never closes a live puzzle")
        #expect(game.grid[2][2] == .filled && game.grid[2][0] == .filled)
        #expect(game.solvedIDs == ["hibiscus"], "but the progress sets were wholesale replaced mid-solve")
    }

    // REGRESSION(sketch-resume-softlock): begin() used to skip checkComplete on
    // a resumed grid, and sketchTap only checks completion when filling an EMPTY
    // true cell — so a restored fully-solved sketch grid could never complete
    // (the engine's only unrecoverable state). begin() now re-runs checkComplete
    // after installing a validated resume grid. The probe stays fix-agnostic: it
    // passes if restore re-checks completion OR if hostile grids are rejected.
    // guards: a restored fully-solved sketch board must be complete or completable
    @Test func restoredSolvedSketchGridMustBeCompletable() {
        let mug = puzzle("mug")
        let payload = BlueprintsGame.SavePayload(
            seenHowTo: false, solved: [], currentID: "mug", currentGrid: solutionGrid(of: mug),
            currentMistakes: 0, mistakeHint: nil)
        let game = BlueprintsGame()
        #expect(game.restore(from: payloadJSON(payload)) != nil)
        #expect(game.puzzle?.id == "mug")
        if !game.isComplete {
            for m in [BlueprintsGame.Mode.fill, .cross] {
                game.mode = m
                for r in 0..<5 {
                    for c in 0..<5 { game.tap(r, c) }
                }
            }
        }
        #expect(game.isComplete, "fully-solved restored sketch board is soft-locked: no tap can ever fire checkComplete")
    }

}

// MARK: - Resource bounds

@MainActor
struct BlueprintsResourceTests {
    // guards: 200k-id persisted sets restore and round-trip without dedupe loss or pathological cost
    @Test func hugeSolvedSetsRoundTripQuickly() {
        let realIDs = BlueprintsGame.puzzles.map(\.id)
        let junk = (0..<200_000).map { "junk-\($0)" }
        let payload = BlueprintsGame.SavePayload(
            seenHowTo: true, solved: junk + realIDs, currentID: nil, currentGrid: nil,
            currentMistakes: nil, mistakeHint: nil)
        let json = payloadJSON(payload)

        let game = BlueprintsGame()
        let duration = ContinuousClock().measure {
            #expect(game.restore(from: json) != nil)
            _ = game.payload(seenHowTo: true, mistakeHint: false)
        }
        #expect(game.solvedIDs.count == 200_000 + realIDs.count)
        #expect(realIDs.allSatisfy { game.solvedIDs.contains($0) }, "real ids must not be lost among the junk")
        let round = decodePayload(game.payload(seenHowTo: true, mistakeHint: false))
        #expect(Set(round?.solved ?? []).count == 200_000 + realIDs.count)
        #expect(duration < .seconds(2), "restore+payload of 200k ids must stay interactive")
    }

    // guards: 10k cross/uncross toggles keep counters exact (no fillBeat, no mistakes) and stay interactive
    @Test func crossToggleChurnKeepsCountersCoherent() {
        let volcano = puzzle("volcano")
        #expect(volcano.size == 10)
        #expect(!volcano.truth(0, 0))
        let game = BlueprintsGame()
        game.begin(volcano)
        game.mode = .cross
        let duration = ContinuousClock().measure {
            for _ in 0..<5_000 {
                game.tap(0, 0)                        // cross
                game.tap(0, 0)                        // erase the cross
            }
        }
        #expect(game.fillBeat == 0, "crosses never bump fillBeat")
        #expect(game.mistakes == 0, "crossing a FALSE cell is never a mistake")
        #expect(game.grid[0][0] == .empty)
        #expect(!game.isComplete)
        #expect(duration < .seconds(2))
    }
}

// NOTE: a former BlueprintsReentrancyTests suite drove tap() re-entrantly from
// inside an @Observable willSet (withObservationTracking onChange). That is an
// overlapping-modify exclusivity violation — it crashes or passes depending on
// the toolchain's access-scope emission, and no app path can trigger it (SwiftUI
// onChange only schedules invalidation). It tested Swift's memory model, not the
// game, so it was removed rather than kept as a flaky suite-killer.

// MARK: - Mistake cap + lives economy

@MainActor
struct BlueprintsMistakeCapTests {
    // guards: the (cap−1)th wrong fill does not fail; the (cap)th fails exactly once and freezes the board
    @Test func capFailsExactlyOnTheNthMistake() {
        let mug = puzzle("mug")
        let game = BlueprintsGame()
        game.begin(mug)
        var falseCells: [(Int, Int)] = []
        for r in 0..<mug.size {
            for c in 0..<mug.size where !mug.truth(r, c) { falseCells.append((r, c)) }
        }
        #expect(falseCells.count >= BlueprintsGame.mistakeCap)
        for i in 0..<(BlueprintsGame.mistakeCap - 1) {
            let cell = falseCells[i]
            #expect(game.tap(cell.0, cell.1))
            #expect(game.mistakes == i + 1)
            #expect(!game.isFailed, "mistake \(i + 1) must not end the sketch")
        }
        let last = falseCells[BlueprintsGame.mistakeCap - 1]
        #expect(game.tap(last.0, last.1))
        #expect(game.mistakes == BlueprintsGame.mistakeCap)
        #expect(game.isFailed)
        // Frozen — further taps refuse.
        #expect(!game.tap(falseCells[BlueprintsGame.mistakeCap].0,
                          falseCells[BlueprintsGame.mistakeCap].1))
        #expect(game.mistakes == BlueprintsGame.mistakeCap)
        #expect(!game.isComplete)
    }

    // guards: coach shield never fails the board even past the cap
    @Test func coachShieldNeverFails() {
        let mug = puzzle("mug")
        let game = BlueprintsGame()
        game.begin(mug)
        game.setCoachShield(true)
        farmMistakes(game, at: firstFalseCell(of: mug), count: BlueprintsGame.mistakeCap + 2)
        #expect(game.mistakes == BlueprintsGame.mistakeCap + 2)
        #expect(!game.isFailed)
    }

    // guards: reset-on-retry (begin same puzzle) starts at zero mistakes and clears isFailed
    @Test func retrySamePuzzleResetsMistakes() {
        let mug = puzzle("mug")
        let game = BlueprintsGame()
        game.begin(mug)
        var n = 0
        for r in 0..<mug.size {
            for c in 0..<mug.size where !mug.truth(r, c) {
                game.tap(r, c)
                n += 1
                if n >= BlueprintsGame.mistakeCap { break }
            }
            if n >= BlueprintsGame.mistakeCap { break }
        }
        #expect(game.isFailed)
        game.begin(mug)
        #expect(game.puzzle?.id == "mug")
        #expect(game.mistakes == 0)
        #expect(!game.isFailed)
        #expect(game.grid == emptyGrid(5))
    }

    // guards: mistake counter survives a kill-and-relaunch mid-round (payload round-trip)
    @Test func mistakesSurviveRelaunchMidRound() {
        let mug = puzzle("mug")
        let origin = BlueprintsGame()
        origin.begin(mug)
        let f = firstFalseCell(of: mug)
        #expect(origin.tap(f.0, f.1))
        #expect(origin.mistakes == 1)
        let json = origin.payload(seenHowTo: true, mistakeHint: false)
        let copy = BlueprintsGame()
        #expect(copy.restore(from: json) != nil)
        #expect(copy.puzzle?.id == "mug")
        #expect(copy.mistakes == 1)
        #expect(!copy.isFailed)
        // Cap still live after restore.
        var falseCells: [(Int, Int)] = []
        for r in 0..<mug.size {
            for c in 0..<mug.size where !mug.truth(r, c) && copy.grid[r][c] == .empty {
                falseCells.append((r, c))
            }
        }
        for i in 0..<(BlueprintsGame.mistakeCap - 1) {
            #expect(copy.tap(falseCells[i].0, falseCells[i].1))
        }
        #expect(copy.isFailed)
        #expect(copy.mistakes == BlueprintsGame.mistakeCap)
    }

    // guards: restoring at the cap re-arms isFailed so force-quit cannot launder a ruined sketch
    @Test func restoreAtCapRearmsFailure() {
        let mug = puzzle("mug")
        let origin = BlueprintsGame()
        origin.begin(mug)
        var n = 0
        for r in 0..<mug.size {
            for c in 0..<mug.size where !mug.truth(r, c) {
                origin.tap(r, c)
                n += 1
                if n >= BlueprintsGame.mistakeCap { break }
            }
            if n >= BlueprintsGame.mistakeCap { break }
        }
        #expect(origin.isFailed)
        let json = origin.payload(seenHowTo: false, mistakeHint: true)
        let copy = BlueprintsGame()
        #expect(copy.restore(from: json) != nil)
        #expect(copy.mistakes == BlueprintsGame.mistakeCap)
        #expect(copy.isFailed)
        #expect(!copy.isComplete)
        #expect(copy.solvedIDs.isEmpty, "a defeat never mints a solve")
    }

    // guards: a defeat never marks the puzzle solved and never leaves a lastRunSummary (recordRun is solve-only)
    @Test func defeatNeverSolvesOrRecordsRun() {
        let mug = puzzle("mug")
        let game = BlueprintsGame()
        game.begin(mug)
        var n = 0
        for r in 0..<mug.size {
            for c in 0..<mug.size where !mug.truth(r, c) {
                game.tap(r, c)
                n += 1
                if n >= BlueprintsGame.mistakeCap { break }
            }
            if n >= BlueprintsGame.mistakeCap { break }
        }
        #expect(game.isFailed)
        #expect(!game.isComplete)
        #expect(game.solvedIDs.isEmpty)
        #expect(game.lastRunSummary == nil)
    }
}
