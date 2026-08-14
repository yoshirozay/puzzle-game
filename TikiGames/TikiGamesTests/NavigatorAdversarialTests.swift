import Foundation
import Testing
@testable import Tiki_Lounge

/// Adversarial tests for the Navigator engine (NavigatorGame / NavigatorLevel).
///
/// Every hard-coded expected value in this file was verified 2026-07-17 by
/// compiling the two source files into a standalone harness and running it
/// (arm64 macOS, same libm as the simulator). Notable measured facts:
///   - currentPeekMs at loop 3 is 1155, NOT 1156 (Int() truncates
///     1600 * pow(0.85, 2) = 1155.999...).
///   - Zero filled 2x2 blocks shipped across all 60 levels x attempts 1...200.
///   - Four restore/forge scenarios used to SIGTRAP (exit 133, harness-
///     proven); the 2026-07-17 hardening pass clamps those conversions, and
///     the formerly .disabled trap tests now run enabled as regressions.
///   - The 2026-07-17 fix pass also changed the advance salt to
///     runNumber + (loopNumber - 1) * 997 (injective across (run, loop)
///     diagonals); attempt fixtures in this file pin the NEW formula.
///
/// NavigatorGame is @Observable, non-@MainActor, non-Sendable, with no global
/// state — a fresh instance per test is complete isolation. No UserDefaults,
/// SwiftData, or singletons are touched anywhere in this file.

// MARK: - Helpers

@MainActor
private func driveToInput(_ g: NavigatorGame) {
    g.beginPeek()
    while g.advanceWave() {}
}

/// Wins the loaded passage legitimately (peek → input → tap every star).
@MainActor
private func winPassage(_ g: NavigatorGame) {
    driveToInput(g)
    for c in g.pattern { _ = g.tap(c) }
}

/// Loses the loaded passage legitimately, by spending the whole mistake budget
/// on cells that are not stars.
@MainActor
private func losePassage(_ g: NavigatorGame) {
    driveToInput(g)
    let budget = g.mistakesLeft            // capture: tap() decrements it
    let blanks = (0..<g.cellCount).filter { !g.pattern.contains($0) }
    for c in blanks.prefix(budget) { _ = g.tap(c) }
}

@MainActor
private func forgedLevel(
    grid: Int, targets: Int, waves: Int = 1, decoys: Int = 0,
    peekMs: Int = 1000, peeks: Int = 1, mistakes: Int = 3, seed: UInt64 = 42
) -> NavigatorLevel {
    NavigatorLevel(
        id: 999, grid: grid, targets: targets, scatter: 0, waves: waves,
        decoys: decoys, peekMs: peekMs, peeks: peeks, mistakes: mistakes,
        seed: seed, family: "Forged"
    )
}

@MainActor
private func decodePayload(_ json: String) throws -> NavigatorGame.SavePayload {
    try JSONDecoder().decode(NavigatorGame.SavePayload.self, from: Data(json.utf8))
}

/// Field-by-field SavePayload comparison (struct is not Equatable in source).
@MainActor
private func samePayload(_ a: NavigatorGame.SavePayload, _ b: NavigatorGame.SavePayload) -> Bool {
    a.seenHowTo == b.seenHowTo
        && a.bestTotalPassages == b.bestTotalPassages
        && a.bestPassage == b.bestPassage
        && a.lifetimeStars == b.lifetimeStars
        && a.runNumber == b.runNumber
        && a.currentPassage == b.currentPassage
        && a.attempt == b.attempt
        && a.loopNumber == b.loopNumber
        && a.totalPassages == b.totalPassages
}

/// Test-side oracle: any 2x2 block fully starred (mirrors the private guard).
@MainActor
private func hasFilledBlock(_ cells: Set<Int>, grid: Int) -> Bool {
    guard grid >= 2 else { return false }
    for r in 0..<(grid - 1) {
        for c in 0..<(grid - 1) {
            let a = r * grid + c
            if cells.contains(a), cells.contains(a + 1),
               cells.contains(a + grid), cells.contains(a + grid + 1) {
                return true
            }
        }
    }
    return false
}

// MARK: - Level table

@MainActor
struct NavigatorLevelTableTests {

    // guards: campaign is exactly 60 levels with ids 1...60 in order (code, all.count, and justCompletedLoop are all consistent at 60; the stale "180 passages" doc comment this test used to contradict was corrected 2026-07-25)
    @Test func levelTableShape() {
        #expect(NavigatorLevels.all.count == 60)
        for (i, lvl) in NavigatorLevels.all.enumerated() {
            #expect(lvl.id == i + 1)
        }
    }

    // guards: level(id:) returns nil outside 1...60 and never traps, even at Int.min/Int.max
    @Test(arguments: [
        (Int.min, false), (-1, false), (0, false), (1, true),
        (60, true), (61, false), (Int.max, false),
    ] as [(Int, Bool)])
    func levelLookupBoundaries(_ probe: (id: Int, exists: Bool)) {
        let lvl = NavigatorLevels.level(id: probe.id)
        #expect((lvl != nil) == probe.exists)
        if let lvl { #expect(lvl.id == probe.id) }
    }

    // CHANGED 2026-07-25 (prefix compression): the opening is now one passage
    // per star count, 3…8 over ids 1…6, reaching the first losable board at
    // id 11 (was id 28 under the monotone ramp, id 19 shipped). Band 1 is only
    // ids 1…3 now, so this probes the whole compressed opening rather than one
    // band — that opening IS the change, and its length is what a defeat used
    // to make the player replay.
    // guards: star-plateau off-by-one boundaries across the compressed opening
    @Test(arguments: [
        (1, 3), (2, 4), (3, 5), (4, 6), (5, 7), (6, 8),
        (7, 8), (10, 8), (11, 9),
    ] as [(Int, Int)])
    func openingRampPlateaus(_ probe: (id: Int, targets: Int)) {
        #expect(NavigatorLevels.level(id: probe.id)?.targets == probe.targets)
    }

    // CHANGED 2026-07-25 twice. First for the monotone ramp: band ranges/peeks/
    // star ranges re-pinned, and the monotonicity check promoted from
    // within-a-band to across-the-whole-campaign — that global check IS the fix
    // it exists to protect (the old table stepped targets DOWN at every band
    // boundary: 9->6 at 20/21, 11->7 at 32/33, 13->8 at 46/47).
    // Then again for prefix compression: the bands were re-cut so the opening
    // spends 6 passages below 9 stars instead of 27. Measured, 1200 seeds:
    // passages a Cowan-4 player cannot lose fell 27 -> 10 and contested rose
    // 8 -> 14, with the soft-capacity series confirming (contested 46 -> 50,
    // largest adjacent swing 0.285 -> 0.273). Nothing about the invariants
    // themselves relaxed — only the band cut points moved.
    // guards: whole-table invariants — locked knobs (waves 1 / decoys 0 / mistakes 3 / peeks 1), targets non-decreasing across ALL 60 passages, starMin at band start, starMax reached at band end, targets always < grid^2, star density never above 1/3 of the board
    @Test func bandTableInvariants() {
        let bands: [(ids: ClosedRange<Int>, grid: Int, starMin: Int, starMax: Int, peek: Int)] = [
            (1...3, 4, 3, 5, 1600), (4...6, 5, 6, 8, 2200), (7...20, 6, 8, 9, 2700),
            (21...36, 7, 9, 10, 3100), (37...60, 8, 11, 13, 3500),
        ]
        var prev = 0
        for band in bands {
            for id in band.ids {
                let lvl = NavigatorLevels.level(id: id)!
                #expect(lvl.grid == band.grid)
                #expect(lvl.peekMs == band.peek)
                #expect(lvl.waves == 1)
                #expect(lvl.decoys == 0)
                #expect(lvl.mistakes == 3)
                #expect(lvl.peeks == 1)
                #expect(lvl.targets >= prev, "targets must not decrease anywhere in the campaign (id \(id))")
                #expect(lvl.targets >= band.starMin && lvl.targets <= band.starMax)
                #expect(lvl.targets < lvl.grid * lvl.grid)
                #expect(lvl.targets * 3 <= lvl.grid * lvl.grid, "star density above 1/3 (id \(id))")
                prev = lvl.targets
            }
            #expect(NavigatorLevels.level(id: band.ids.lowerBound)!.targets == band.starMin)
            #expect(NavigatorLevels.level(id: band.ids.upperBound)!.targets == band.starMax)
        }
        // the ramp must actually climb, not just refuse to fall
        #expect(NavigatorLevels.all.first!.targets == 3)
        #expect(NavigatorLevels.all.last!.targets == 13)
    }
}

// MARK: - Board generation

@MainActor
struct NavigatorGenerationTests {

    // guards: (level, attempt) fully determines pattern/waveGroups/decoyCells across instances — the save/resume "same star roll" contract rests on this
    @Test func boardDeterminismAcrossInstances() {
        for (id, attempt) in [(5, 3), (60, 1), (33, 12)] {
            let lvl = NavigatorLevels.level(id: id)!
            let a = NavigatorGame(); a.newLevel(lvl, attempt: attempt)
            let b = NavigatorGame(); b.newLevel(lvl, attempt: attempt)
            #expect(a.pattern == b.pattern)
            #expect(a.waveGroups == b.waveGroups)
            #expect(a.decoyCells == b.decoyCells)
        }
    }

    // guards: attempt salt and run-number salt actually produce different boards (harness-verified for these exact inputs — not probabilistic)
    @Test func attemptAndRunSaltDiverge() {
        let l5 = NavigatorLevels.level(id: 5)!
        let a = NavigatorGame(); a.newLevel(l5, attempt: 3)
        let c = NavigatorGame(); c.newLevel(l5, attempt: 4)
        #expect(a.pattern != c.pattern)
        let l1 = NavigatorLevels.level(id: 1)!
        let r1 = NavigatorGame(); r1.newLevel(l1, attempt: 1)  // run 1's P1
        let r2 = NavigatorGame(); r2.newLevel(l1, attempt: 2)  // run 2's P1
        #expect(r1.pattern != r2.pattern)
    }

    // guards: pattern integrity for 6,000 real boards — unique in-range cells, count == targets, wave slicing conserves the pattern, no decoys, and NO filled 2x2 block ever ships (harness measured 0 blocks over 12,000 boards; deterministic, so stable)
    @Test func generationSweepInvariants() {
        for lvl in NavigatorLevels.all {
            for attempt in 1...100 {
                let g = NavigatorGame()
                g.newLevel(lvl, attempt: attempt)
                let cells = Set(g.pattern)
                #expect(g.pattern.count == lvl.targets, "id \(lvl.id) attempt \(attempt)")
                #expect(cells.count == g.pattern.count, "duplicate cells id \(lvl.id) attempt \(attempt)")
                #expect(g.pattern.allSatisfy { $0 >= 0 && $0 < lvl.grid * lvl.grid })
                #expect(g.waveGroups.flatMap { $0 } == g.pattern)
                #expect(g.waveGroups.count == 1)  // campaign waves locked to 1
                #expect(g.decoyCells.isEmpty)     // campaign decoys locked to 0
                #expect(!hasFilledBlock(cells, grid: lvl.grid), "2x2 block shipped id \(lvl.id) attempt \(attempt)")
            }
        }
    }

    // guards: hostile density clamps — targets >= grid^2 clamps to grid^2-1 without hanging; waves clamp to pattern.count; decoys clamp to the free cells and stay disjoint from stars
    @Test func maxDensityClamps() {
        let g = NavigatorGame()
        g.newLevel(forgedLevel(grid: 4, targets: 100, waves: 1000, decoys: 1000), attempt: 7)
        #expect(g.pattern.count == 15)                       // grid^2 - 1
        #expect(Set(g.pattern).count == 15)
        #expect(g.waveGroups.count == 15)                    // waves clamped to pattern.count
        #expect(g.waveGroups.flatMap { $0 } == g.pattern)
        #expect(g.decoyCells.count == 1)                     // only 1 free cell remains
        #expect(Set(g.decoyCells).isDisjoint(with: Set(g.pattern)))

        let h = NavigatorGame()
        h.newLevel(forgedLevel(grid: 4, targets: 15), attempt: 3)
        #expect(h.pattern.count == 15)                       // exactly grid^2 - 1 terminates
    }

    // guards: degenerate forged levels never trap — and documents the empty-pattern soft-lock: with pattern == [], tap() can NEVER return .passageWon (the win check lives inside the star branch), so the passage is unwinnable and mistakes-0 makes the FIRST wrong tap a .runOver. Unreachable from the shipped table (targets 3...15); pinned, not expected-fail, because correct behavior for forged levels is undefined (newLevel performs no validation — see analyst empty-pattern-unwinnable)
    @Test func degenerateLevelsAreSafe() {
        let g0 = NavigatorGame()
        g0.newLevel(forgedLevel(grid: 0, targets: 5), attempt: 1)
        #expect(g0.pattern.isEmpty)
        #expect(g0.waveGroups == [[]])          // one empty wave, litCells stays safe
        g0.beginPeek()
        #expect(g0.litCells.isEmpty)
        #expect(g0.advanceWave() == false)      // straight to input
        #expect(g0.phase == .input)
        #expect(g0.tap(0) == .ignored)          // cellCount 0 — every tap out of bounds

        let g1 = NavigatorGame()
        g1.newLevel(forgedLevel(grid: 1, targets: 0, waves: 0, decoys: -3, peeks: -2, mistakes: 0), attempt: 1)
        #expect(g1.pattern.isEmpty)
        #expect(g1.decoyCells.isEmpty)          // negative decoys -> []
        #expect(g1.waveGroups.count == 1)       // waves 0 clamps to 1
        driveToInput(g1)
        #expect(g1.usePeek() == false)          // negative peek budget unusable
        #expect(g1.tap(0) == .runOver)          // mistakes 0: first wrong tap ends the run
        #expect(g1.phase == .runOver)           // soft-lock documented: no win path existed
    }

    // guards: wave slicing puts larger groups first (7 into 3 -> [3,2,2]) and litCells tracks exactly the current wave, emptying outside .peek
    @Test func waveSlicingLargerGroupsFirst() {
        let g = NavigatorGame()
        g.newLevel(forgedLevel(grid: 5, targets: 7, waves: 3, seed: 12345), attempt: 1)
        #expect(g.waveGroups.map(\.count) == [3, 2, 2])
        #expect(g.waveGroups.flatMap { $0 } == g.pattern)
        #expect(g.litCells.isEmpty)                       // .idle — no lights
        g.beginPeek()
        #expect(g.phase == .peek(0))
        #expect(g.litCells == Set(g.waveGroups[0]))
        #expect(g.advanceWave() == true)
        #expect(g.litCells == Set(g.waveGroups[1]))
        #expect(g.advanceWave() == true)
        #expect(g.litCells == Set(g.waveGroups[2]))
        #expect(g.advanceWave() == false)
        #expect(g.phase == .input)
        #expect(g.litCells.isEmpty)                       // .input — no lights
    }
}

// MARK: - Phase machine

@MainActor
struct NavigatorPhaseMachineTests {

    // guards: the canonical phase walk idle -> peek(0) -> input -> passageWon, with advanceWave an idempotent no-op once input begins — and taps during the peek are dead (no see-and-tap)
    @Test func happyPathPhases() {
        let g = NavigatorGame()
        g.startNewRun()
        #expect(g.phase == .idle)
        #expect(g.level?.id == 1)
        g.beginPeek()
        #expect(g.phase == .peek(0))
        #expect(g.litCells == Set(g.pattern))   // waves == 1: whole chart in wave 0
        #expect(g.tap(g.pattern[0]) == .ignored)   // taps during the peek are dead — no see-and-tap
        #expect(g.found.isEmpty)
        #expect(g.levelScore == 0)
        #expect(g.advanceWave() == false)
        #expect(g.phase == .input)
        #expect(g.advanceWave() == false)       // idempotent in .input
        #expect(g.phase == .input)
        for c in g.pattern { _ = g.tap(c) }
        #expect(g.phase == .passageWon)
        #expect(g.litCells.isEmpty)
    }

    // guards: out-of-bounds taps (-1, cellCount, Int.max, Int.min) are .ignored with zero state mutation and no trap
    @Test func tapBoundsIgnored() {
        let g = NavigatorGame()
        g.startNewRun()
        driveToInput(g)
        for cell in [-1, g.cellCount, Int.max, Int.min] {
            #expect(g.tap(cell) == .ignored)
        }
        #expect(g.found.isEmpty)
        #expect(g.wrong.isEmpty)
        #expect(g.mistakesLeft == 3)
        #expect(g.levelScore == 0)
        #expect(g.phase == .input)
    }

    // guards: mistake budget exactness — exactly 3 DISTINCT wrong taps end the run; the 3rd returns .runOver; a duplicate wrong tap never burns budget
    @Test func mistakeBudgetExactness() {
        let g = NavigatorGame()
        g.startNewRun()
        driveToInput(g)
        let bad = (0..<g.cellCount).filter { !g.pattern.contains($0) }
        #expect(g.tap(bad[0]) == .miss)
        #expect(g.mistakesLeft == 2)
        #expect(g.tap(bad[0]) == .duplicate)    // re-tap same wrong cell
        #expect(g.mistakesLeft == 2)            // no budget burned
        #expect(g.tap(bad[1]) == .miss)
        #expect(g.mistakesLeft == 1)
        #expect(g.phase == .input)
        #expect(g.tap(bad[2]) == .runOver)
        #expect(g.mistakesLeft == 0)
        #expect(g.phase == .runOver)
    }

    // guards: duplicate star taps are inert — no double score, no double lifetimeStars, no phantom win progress
    @Test func duplicateTapsAreInert() {
        let g = NavigatorGame()
        g.startNewRun()
        driveToInput(g)
        let star = g.pattern[0]
        #expect(g.tap(star) == .star)
        let score = g.levelScore
        let stars = g.lifetimeStars
        #expect(g.tap(star) == .duplicate)
        #expect(g.levelScore == score)
        #expect(g.lifetimeStars == stars)
        #expect(g.found.count == 1)
        #expect(g.chartBeat == 1)
    }

    // guards: .passageWon and .runOver reject tap/usePeek/advanceWave with zero mutation (beginPeek is the known breach, pinned separately)
    @Test func terminalPhaseImmunity() {
        let won = NavigatorGame()
        won.startNewRun()
        winPassage(won)
        #expect(won.phase == .passageWon)
        let wonScore = won.levelScore
        #expect(won.tap(0) == .ignored)
        #expect(won.usePeek() == false)
        #expect(won.advanceWave() == false)
        #expect(won.levelScore == wonScore)
        #expect(won.phase == .passageWon)

        let dead = NavigatorGame()
        dead.startNewRun()
        driveToInput(dead)
        let bad = (0..<dead.cellCount).filter { !dead.pattern.contains($0) }
        for c in bad.prefix(3) { _ = dead.tap(c) }
        #expect(dead.phase == .runOver)
        #expect(dead.tap(dead.pattern[0]) == .ignored)
        #expect(dead.usePeek() == false)
        #expect(dead.advanceWave() == false)
        #expect(dead.found.isEmpty)
        #expect(dead.phase == .runOver)
    }

    // guards: peek budget spends exactly once (campaign peeks == 1) and usePeek is refused outside .input (.idle and .peek probed here, terminal phases in terminalPhaseImmunity)
    @Test func peekBudget() {
        let g = NavigatorGame()
        g.startNewRun()
        #expect(g.usePeek() == false)           // .idle — refused
        g.beginPeek()
        #expect(g.usePeek() == false)           // .peek — refused, no budget spent
        #expect(g.peeksLeft == 1)
        driveToInput(g)
        #expect(g.usePeek() == true)
        #expect(g.peeksLeft == 0)
        #expect(g.usePeek() == false)           // budget exhausted
        #expect(g.peeksUsed == 1)
    }

    // REGRESSION(beginpeek-free-repeek, fixed 2026-07-17): beginPeek used to guard
    // only `level != nil`, so calling it from .input re-showed the whole chart with
    // found-progress intact and NO peek budget spent — unlimited free re-peeks.
    // beginPeek is now only legal from .idle.
    // guards: beginPeek is rejected mid-input — re-showing the chart must cost the peek budget
    @Test func beginPeekRejectedMidInput() {
        let g = NavigatorGame()
        g.startNewRun()
        driveToInput(g)
        _ = g.tap(g.pattern[0])
        _ = g.tap(g.pattern[1])
        g.beginPeek()
        #expect(g.phase == .input, "beginPeek from .input must be a no-op — free chart re-show")
        #expect(g.peeksLeft == 1)               // budget untouched either way
        #expect(g.found.count == 2)
    }

    // REGRESSION(runover-resurrection, fixed 2026-07-17): beginPeek used to
    // resurrect the corpse after .runOver (peek -> input -> tap the remaining stars
    // -> .passageWon) and the win branch recorded totalPassages / lifetimeStars
    // AFTER the run ended. The .idle-only guard on beginPeek makes .runOver
    // terminal until startNewRun/abandonLevel.
    // guards: .runOver is terminal — a dead run can never re-enter play or record stats
    @Test func runOverIsTerminal() {
        let g = NavigatorGame()
        g.startNewRun()
        driveToInput(g)
        let bad = (0..<g.cellCount).filter { !g.pattern.contains($0) }
        for c in bad.prefix(3) { _ = g.tap(c) }
        #expect(g.phase == .runOver)
        // Resurrection attempt:
        g.beginPeek()
        while g.advanceWave() {}
        for c in g.pattern { _ = g.tap(c) }
        #expect(g.phase == .runOver, "dead run must stay dead")
        #expect(g.totalPassages == 0, "no passage may be recorded after run-over")
        #expect(g.lifetimeStars == 0, "no stars may be charted after run-over")
    }

    // REGRESSION(advanceafterwin-skip, fixed 2026-07-17): advanceAfterWin had no
    // phase guard — callable from .idle (or .runOver) to skip to any passage, or any
    // loop, without winning. It now requires .passageWon.
    // guards: advanceAfterWin without a .passageWon is a no-op — passages cannot be skipped (probed from .idle, mid-passage .input, and .runOver: a dead run must not be revived onto the next passage)
    @Test func advanceAfterWinRequiresWin() {
        let g = NavigatorGame()
        g.startNewRun()
        #expect(g.phase == .idle)
        g.advanceAfterWin()                     // never won anything
        #expect(g.level?.id == 1, "advancing without a win must not move the run forward")
        driveToInput(g)
        g.advanceAfterWin()                     // .input — mid-passage skip attempt
        #expect(g.level?.id == 1)
        #expect(g.phase == .input)
        let bad = (0..<g.cellCount).filter { !g.pattern.contains($0) }
        for c in bad.prefix(3) { _ = g.tap(c) }
        #expect(g.phase == .runOver)
        g.advanceAfterWin()                     // .runOver — resurrection attempt
        #expect(g.phase == .runOver, "advanceAfterWin must not revive a dead run")
        #expect(g.level?.id == 1)
    }
}

// MARK: - Scoring

@MainActor
struct NavigatorScoringTests {

    // guards: exact scoring formula — per-star deltas 25,30,35,40,45 then capped at 50, final star carries win bonus 30+10*targets plus 50 perfect (harness-verified on an 8-star board, attempt 1: deltas [25,30,35,40,45,50,50,210], total 485)
    @Test func streakScoringPin() {
        let g = NavigatorGame()
        // CHANGED 2026-07-25, twice: the 8-star fixture moved 47 -> 19 when the
        // star ramp was made monotone (47 became 11 stars), then 19 -> 7 when
        // the opening was compressed (19 became 9 stars). Passage 7 is the same
        // board the fixture has always described — grid 6, targets 8 — so every
        // pinned constant below is unchanged. They depend on targets == 8, not
        // on which passage carries it.
        g.newLevel(NavigatorLevels.level(id: 7)!, attempt: 1)    // grid 6, targets 8
        driveToInput(g)
        var deltas: [Int] = []
        var prev = 0
        for c in g.pattern {
            _ = g.tap(c)
            deltas.append(g.levelScore - prev)
            prev = g.levelScore
        }
        #expect(deltas == [25, 30, 35, 40, 45, 50, 50, 210])     // 210 = 50 + (30+80) + 50 perfect
        #expect(g.levelScore == 485)
        #expect(g.isPerfect)
        #expect(g.phase == .passageWon)
    }

    // guards: a miss scores nothing, costs a mistake, and resets the streak to the 25 base — and forfeits the perfect bonus (total 390 = 485 - 45 streak loss - 50 perfect, harness-derived)
    @Test func missResetsStreak() {
        let g = NavigatorGame()
        g.newLevel(NavigatorLevels.level(id: 7)!, attempt: 1)    // grid 6, targets 8
        driveToInput(g)
        _ = g.tap(g.pattern[0])
        _ = g.tap(g.pattern[1])
        #expect(g.levelScore == 55)
        let bad = (0..<g.cellCount).first { !g.pattern.contains($0) }!
        #expect(g.tap(bad) == .miss)
        #expect(g.levelScore == 55)             // miss costs no points
        #expect(g.streak == 0)
        _ = g.tap(g.pattern[2])
        #expect(g.levelScore == 80)             // streak restarted at base 25
        for c in g.pattern[3...] { _ = g.tap(c) }
        #expect(g.levelScore == 390)            // no +50 perfect after a wrong tap
        #expect(g.isPerfect == false)
    }

    // guards: using the re-peek forfeits ONLY the +50 perfect bonus (flawless taps still score fully: 435 = 485 - 50)
    @Test func usePeekForfeitsPerfectBonus() {
        let g = NavigatorGame()
        g.newLevel(NavigatorLevels.level(id: 7)!, attempt: 1)    // grid 6, targets 8
        driveToInput(g)
        #expect(g.usePeek() == true)
        for c in g.pattern { _ = g.tap(c) }
        #expect(g.levelScore == 435)
        #expect(g.isPerfect == false)           // peeksUsed == 1 kills perfect
        #expect(g.phase == .passageWon)
    }
}

// MARK: - Run lifecycle

@MainActor
struct NavigatorRunLifecycleTests {

    // guards: startNewRun bumps runNumber, resets the star tally, loads the campaign position salted by runNumber (P1 here — this save has never taken a defeat, so nothing has rewound it), clears tutorial flag — and leaves persistent meta intact, including through a subsequent low win (high-water records are max-semantics, never overwritten downward)
    @Test func startNewRunResets() {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"bestTotalPassages":9,"bestPassage":6,"lifetimeStars":50,"runNumber":4}"#)
        g.startNewRun()
        #expect(g.runNumber == 5)
        #expect(g.loopNumber == 1)
        #expect(g.totalPassages == 0)
        #expect(g.runStarsCharted == 0)
        #expect(g.level?.id == 1)
        #expect(g.attempt == 5)
        #expect(g.phase == .idle)
        #expect(g.isTutorial == false)
        #expect(g.bestTotalPassages == 9)       // meta survives a new run
        #expect(g.lifetimeStars == 50)
        winPassage(g)                            // P1 win: totalPassages 1, below both records
        #expect(g.totalPassages == 1)
        #expect(g.bestTotalPassages == 9, "a lower run must not overwrite the high-water record")
        #expect(g.bestPassage == 6, "clearing P1 must not overwrite the passage high-water")
    }

    // NEW 2026-07-25: a defeat costs a life (spent view-side) and position, but
    // no longer the whole campaign. Before this, run-over reset to Passage 1,
    // so every defeat made the player replay the campaign's unloseable opening
    // before the game could be lost again.
    // guards: the rewind lands rewindPassages back, and the run tally is seeded with the kept depth so totalPassages — the live Game Center score — still reads as campaign depth rather than being measured from the rewind point
    @Test func defeatRewindsAndKeepsScoreDepth() {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"runNumber":0,"currentPassage":30,"attempt":1,"loopNumber":1,"totalPassages":29}"#)
        losePassage(g)
        #expect(g.phase == .runOver)
        #expect(g.resumePassage == 25, "5 back from P30, clear of band 4's floor at P21")
        g.startNewRun()
        #expect(g.level?.id == 25)
        #expect(g.totalPassages == 24, "seeded with kept depth")
        winPassage(g)
        #expect(g.totalPassages == 25, "clearing P25 scores 25 — same as an unbroken run reaching P25")
    }

    // guards: the rewind floors at the band's opening passage, so a player never replays a board size they graduated from — falling early in a band therefore costs less than the full rewindPassages, and falling in band 1 still lands on Passage 1
    @Test(arguments: [(30, 25), (50, 45), (23, 21), (21, 21), (8, 7), (37, 37), (2, 1), (1, 1)] as [(Int, Int)])
    func defeatRewindFloorsAtBandStart(_ probe: (fell: Int, resume: Int)) {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"runNumber":0,"currentPassage":\#(probe.fell),"attempt":1,"loopNumber":1}"#)
        #expect(g.level?.id == probe.fell)
        losePassage(g)
        #expect(g.resumePassage == probe.resume, "fell at P\(probe.fell)")
        #expect(g.resumePassage <= probe.fell, "a rewind may only ever move backward")
    }

    // guards: campaign position is persisted meta, not in-flight run state — quitting from the run-over panel must not silently turn the rewind back into a full reset to Passage 1
    @Test func rewindSurvivesRelaunch() {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"runNumber":0,"currentPassage":30,"attempt":1,"loopNumber":1}"#)
        losePassage(g)
        let saved = g.payload(seenHowTo: true)
        let relaunched = NavigatorGame()
        relaunched.restore(from: saved)
        #expect(relaunched.resumePassage == 25)
        relaunched.startNewRun()
        #expect(relaunched.level?.id == 25)
    }

    // guards: a save written before the rewind shipped carries no campaign position — it must migrate to Passage 1 rather than resume nowhere
    @Test func preRewindSaveMigratesToPassageOne() {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"bestTotalPassages":30,"bestPassage":30,"runNumber":4}"#)
        #expect(g.resumePassage == 1)
        #expect(g.resumeLoop == 1)
        g.startNewRun()
        #expect(g.level?.id == 1)
        #expect(g.totalPassages == 0, "a migrating save starts a run exactly as before")
    }

    // guards: the coach board cannot reach run-over at all (99-mistake budget), so it can never move campaign position — every blank cell on the board is tapped here and the run must still be alive
    @Test func tutorialBoardCannotRewindPosition() {
        let coach = NavigatorGame()
        coach.seedTutorialBoard()
        driveToInput(coach)
        for c in (0..<coach.cellCount).filter({ !coach.pattern.contains($0) }) { _ = coach.tap(c) }
        #expect(coach.phase != .runOver, "the coach board must survive every wrong tap available")
        #expect(coach.mistakesLeft > 0)
        #expect(coach.resumePassage == 1)
    }

    // guards: beating P60 loops to P1 with loopNumber 2, the 997-weighted loop salt (attempt 0+(2-1)*997=997), justCompletedLoop true exactly during the P60 .passageWon, and the loop-2 peek shrunk to 1360 — while P59 wins never claim the loop
    @Test func loopAroundAtP60() {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"runNumber":0,"currentPassage":60,"attempt":1,"loopNumber":1,"totalPassages":59}"#)
        #expect(g.justCompletedLoop == false)   // requires .passageWon phase
        winPassage(g)
        #expect(g.phase == .passageWon)
        #expect(g.justCompletedLoop == true)
        #expect(g.totalPassages == 60)
        g.advanceAfterWin()
        #expect(g.level?.id == 1)
        #expect(g.loopNumber == 2)
        #expect(g.attempt == 997)               // runNumber 0 + (2-1) * 997
        #expect(g.phase == .idle)
        #expect(g.justCompletedLoop == false)
        #expect(g.currentPeekMs == 1360)        // loop 2: 1600 * 0.85

        let h = NavigatorGame()
        h.restore(from: #"{"seenHowTo":true,"currentPassage":59,"attempt":1,"loopNumber":1}"#)
        winPassage(h)
        #expect(h.justCompletedLoop == false)   // P59 is not the loop boundary
    }

    // guards: backing out mid-passage (from .peek AND .input) drops exactly one passage floored at 1 — and documents that at P1 the floor makes back-out a ZERO-COST fresh reroll of P1 (attempt+1, different board, no other penalty)
    @Test func backOutDropsOnePassageFlooredAtP1() {
        let g = NavigatorGame()
        g.startNewRun()                          // P1, attempt == runNumber == 1
        let original = g.pattern
        g.beginPeek()                            // mid-passage
        g.backOutOfRun()
        #expect(g.level?.id == 1)                // floor: stays on P1
        #expect(g.attempt == 2)                  // fresh roll
        #expect(g.pattern != original)           // free P1 reroll (documented exploit shape)
        #expect(g.loopNumber == 1)
        #expect(g.totalPassages == 0)
        #expect(g.phase == .idle)
        driveToInput(g)                          // penalty must also fire from .input
        g.backOutOfRun()
        #expect(g.level?.id == 1)
        #expect(g.attempt == 3)                  // fresh roll again
        #expect(g.phase == .idle)
    }

    // guards: backOutOfRun is a strict no-op outside .peek/.input (idle between passages, runOver, passageWon — backing out during the win celebration must not claw back the won passage)
    @Test func backOutNoOpOutsideMidPassage() {
        let g = NavigatorGame()
        g.startNewRun()
        #expect(g.phase == .idle)
        let attempt = g.attempt
        g.backOutOfRun()                         // .idle — not mid-passage
        #expect(g.level?.id == 1)
        #expect(g.attempt == attempt)

        driveToInput(g)
        let bad = (0..<g.cellCount).filter { !g.pattern.contains($0) }
        for c in bad.prefix(3) { _ = g.tap(c) }
        #expect(g.phase == .runOver)
        g.backOutOfRun()
        #expect(g.phase == .runOver)             // dead run: nothing to back out of
        #expect(g.level?.id == 1)

        let w = NavigatorGame()
        w.startNewRun()
        winPassage(w)
        #expect(w.phase == .passageWon)
        let wonAttempt = w.attempt
        w.backOutOfRun()                         // between passages — nothing to back out of
        #expect(w.phase == .passageWon)
        #expect(w.attempt == wonAttempt)
        #expect(w.totalPassages == 1, "backing out after a win must not hand back the won passage")
    }

    // guards: anti-reroll on flee — backing out of P6 and re-winning P5 returns to the IDENTICAL P6 board (attempt salt returns to runNumber + (loopNumber-1)*997), while the replayed P5 was a fresh roll (scratch-verified against the 2026-07-17 salt).
    // NOTE the freshness pair is P5 attempts 1 vs 2, chosen MEASURED-different:
    // consecutive attempts produce one-shift-correlated SplitMix64 streams (the
    // attempt salt multiplier equals the generator's internal increment), and on
    // some levels (e.g. P3/P6/P10) attempts 1 and 2 collide to the identical
    // ordered board — a generation-quality weakness worth a product look, but only
    // the salt-level freshness (attempt bump) is the engine's contract.
    @Test func antiRerollOnFlee() {
        let g = NavigatorGame()
        g.startNewRun()                          // runNumber 1
        for _ in 0..<5 { winPassage(g); g.advanceAfterWin() }
        #expect(g.level?.id == 6)
        #expect(g.attempt == 1)                  // runNumber 1 + (loopNumber 1 - 1) * 997
        let fled = g.pattern
        g.beginPeek()                            // mid-passage
        g.backOutOfRun()
        #expect(g.level?.id == 5)
        #expect(g.attempt == 2)                  // fresh roll on the dropped passage
        let originalP5 = NavigatorGame()
        originalP5.newLevel(NavigatorLevels.level(id: 5)!, attempt: 1)
        #expect(g.pattern != originalP5.pattern) // replayed P5 differs from first visit
        winPassage(g)
        g.advanceAfterWin()
        #expect(g.level?.id == 6)
        #expect(g.attempt == 1)                  // salt snapped back
        #expect(g.pattern == fled)               // the fled board cannot be rerolled
    }

    // REGRESSION(cross-run-salt-collision, fixed 2026-07-17): the old salt
    // attempt = runNumber + loopNumber was not injective — run 3 on loop 2 and
    // run 4 on loop 1 both salted P5 with attempt 5, so run N+1's loop 1 replayed
    // run N's loop 2 boards verbatim, defeating runNumber's documented purpose
    // ("blocks memorize-and-repeat"). The 997-weighted salt separates the diagonal.
    // guards: cross-run seed divergence — the same passage in different runs must not repeat a board across the (run, loop) diagonal
    @Test func crossRunSaltInjective() {
        let a = NavigatorGame()
        a.restore(from: #"{"seenHowTo":true,"runNumber":2}"#)
        a.startNewRun()                          // runNumber 3
        for _ in 0..<59 { winPassage(a); a.advanceAfterWin() }
        #expect(a.level?.id == 60)
        winPassage(a); a.advanceAfterWin()       // loop 2 P1
        #expect(a.loopNumber == 2)
        for _ in 0..<4 { winPassage(a); a.advanceAfterWin() }
        #expect(a.level?.id == 5)                // run 3, loop 2, P5 → attempt 5

        let b = NavigatorGame()
        b.restore(from: #"{"seenHowTo":true,"runNumber":3}"#)
        b.startNewRun()                          // runNumber 4
        for _ in 0..<4 { winPassage(b); b.advanceAfterWin() }
        #expect(b.level?.id == 5)                // run 4, loop 1, P5 → attempt 5

        #expect(a.pattern != b.pattern, "different (run, loop) contexts must not replay the identical board")
    }

    // REGRESSION(besttotal-farming, fixed 2026-07-17): win P2 → advance to P3 →
    // beginPeek → backOutOfRun (back to P2) → win P2 again used to increment
    // totalPassages on every re-win with back-out never decrementing, inflating
    // totalPassages / bestTotalPassages unboundedly while never passing P3.
    // backOutOfRun now hands back one tally (clamped at 0), making the cycle net zero.
    // guards: the persistent run record reflects real forward progress — re-winning a passage after backing out must not inflate it
    @Test func totalPassagesNotFarmable() {
        let g = NavigatorGame()
        g.startNewRun()
        winPassage(g); g.advanceAfterWin()       // P1 won → P2
        winPassage(g)                            // P2 won: totalPassages 2
        for _ in 0..<3 {                         // farm cycle: never passes P3
            g.advanceAfterWin()                  // → P3
            g.beginPeek()                        // mid-passage
            g.backOutOfRun()                     // → P2, fresh roll
            winPassage(g)                        // re-win P2
        }
        #expect(g.totalPassages == 2, "re-winning the same passage must not inflate the run tally")
        #expect(g.bestTotalPassages == 2, "the persistent record must not be farmable")
    }

    // guards: pins the current isRunActive-vs-payload disagreement — right after startNewRun the run is NOT "active" (.idle) yet the payload persists it as in-flight; any future change to either definition must be conscious
    @Test func isRunActivePayloadMismatchPin() throws {
        let g = NavigatorGame()
        g.startNewRun()
        #expect(g.isRunActive == false)          // .idle is excluded from isRunActive
        let decoded = try decodePayload(g.payload(seenHowTo: true))
        #expect(decoded.currentPassage == 1)     // ...but the save says in-flight
        #expect(decoded.attempt == 1)
    }

    // guards: configureBest is max-semantics and idempotent — lower/negative values ignored, Int.max accepted without trap
    @Test func configureBestMonotone() {
        let g = NavigatorGame()
        g.configureBest(10)
        g.configureBest(5)
        g.configureBest(10)
        g.configureBest(-1)
        #expect(g.best == 10)
        g.configureBest(Int.max)
        #expect(g.best == Int.max)
    }
}

// MARK: - Peek decay

@MainActor
struct NavigatorPeekDecayTests {

    // guards: exact loop-decay table for base 1600 — loop 1 IS the base (multiplier uses loopNumber-1), floor is a hard 600 from loop 8 onward, pow underflow at loop 500 still floors cleanly. NOTE loop 3 == 1155 (harness-measured): Int() TRUNCATES 1600*0.85^2 = 1155.999…, pinning truncation-not-rounding semantics
    @Test(arguments: [
        (1, 1600), (2, 1360), (3, 1155), (7, 603), (8, 600), (20, 600), (500, 600),
    ] as [(Int, Int)])
    func peekDecayTable(_ probe: (loop: Int, expectedMs: Int)) {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"currentPassage":1,"attempt":1,"loopNumber":\#(probe.loop)}"#)
        #expect(g.loopNumber == probe.loop)
        #expect(g.currentPeekMs == probe.expectedMs)
    }

    // guards: currentPeekMs never increases as loops climb and never dips below the 600 floor (loops 1...30)
    @Test func peekDecayMonotone() {
        var prev = Int.max
        for loop in 1...30 {
            let g = NavigatorGame()
            g.restore(from: #"{"seenHowTo":true,"currentPassage":1,"attempt":1,"loopNumber":\#(loop)}"#)
            let ms = g.currentPeekMs
            #expect(ms <= prev)
            #expect(ms >= 600)
            prev = ms
        }
    }

    // guards: a negative loopNumber in a save cannot inflate or trap the peek clock — the max(0, loopNumber-1) guard clamps the multiplier to 1x
    @Test func negativeLoopNumberPeekGuard() {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"currentPassage":1,"attempt":1,"loopNumber":-5}"#)
        #expect(g.currentPeekMs == 1600)
        let empty = NavigatorGame()
        #expect(empty.currentPeekMs == 0)       // no level -> 0, no trap
    }
}

// MARK: - Tutorial

@MainActor
struct NavigatorTutorialTests {

    // guards: tutorial isolation — a tutorial win records NO persistent stats (bestPassage/totalPassages/bestTotalPassages/lifetimeStars) and the coach board carries the lifted 99-mistake budget and 99 salt
    @Test func tutorialWinDoesNotPollute() {
        let g = NavigatorGame()
        g.seedTutorialBoard()
        #expect(g.isTutorial)
        #expect(g.mistakesLeft == 99)
        #expect(g.attempt == 99)
        #expect(g.level?.id == 1)
        winPassage(g)
        #expect(g.phase == .passageWon)
        #expect(g.bestPassage == 0)
        #expect(g.totalPassages == 0)
        #expect(g.bestTotalPassages == 0)
        #expect(g.lifetimeStars == 0)
    }

    // REGRESSION(tutorial-stat-freeze, fixed 2026-07-17): isTutorial used to be
    // cleared only by startNewRun/abandonLevel — advanceAfterWin/newLevel left it
    // set, so every passage after the coach silently recorded ZERO persistent
    // stats. newLevel now sheds coach mode (seedTutorialBoard re-sets it).
    // guards: leaving the tutorial board via advanceAfterWin must shed tutorial mode so real wins record
    @Test func tutorialFlagClearsOnAdvance() {
        let g = NavigatorGame()
        g.seedTutorialBoard()
        winPassage(g)
        g.advanceAfterWin()
        #expect(g.level?.id == 2)
        #expect(g.isTutorial == false, "a real passage after the coach must not inherit tutorial mode")
        let p2Stars = g.pattern.count
        winPassage(g)
        #expect(g.totalPassages == 1, "a non-tutorial win must record the passage")
        #expect(g.bestPassage == 2)
        #expect(g.lifetimeStars == p2Stars)
    }

    // REGRESSION(tutorial-save-leak, fixed 2026-07-17): payload() used to treat the
    // tutorial board as an in-flight run (currentPassage 1, attempt 99); restoring
    // that payload resumed the coach board as a REAL run with isTutorial false and
    // the normal 3-mistake budget. inFlight now excludes isTutorial.
    // guards: the scripted coach board must never persist as a resumable real run
    @Test func tutorialNotPersistedAsRun() throws {
        let g = NavigatorGame()
        g.seedTutorialBoard()
        let decoded = try decodePayload(g.payload(seenHowTo: false))
        #expect(decoded.currentPassage == nil, "tutorial must not be saved as an in-flight run")
        #expect(decoded.attempt == nil)
    }
}

// MARK: - Persistence

@MainActor
struct NavigatorPersistenceTests {

    // guards: garbage/hostile payloads are rejected wholesale with ZERO state mutation — including "{}" (proving payload()'s own encode-failure fallback string is un-restorable because seenHowTo is non-optional) and type mismatches (whole-payload rejection: one bad field silently discards ALL meta — documented data-loss mode)
    @Test(arguments: [
        "", "not json", "{}", "[]", "null",
        #"{"seenHowTo":"yes"}"#,                      // type-hostile bool
        #"{"seenHowTo":true,"attempt":1.5}"#,         // type-hostile int
    ] as [String])
    func garbageRestoreRejectsAtomically(_ junk: String) {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"bestTotalPassages":9,"bestPassage":6,"lifetimeStars":50,"runNumber":4}"#)
        #expect(g.restore(from: junk) == nil)
        #expect(g.restore(from: nil) == nil)
        #expect(g.bestTotalPassages == 9)             // prior state untouched
        #expect(g.bestPassage == 6)
        #expect(g.lifetimeStars == 50)
        #expect(g.runNumber == 4)
        #expect(g.level == nil)
    }

    // guards: the minimal valid payload restores with all meta zeroed and no phantom passage
    @Test func minimalPayloadRestores() {
        let g = NavigatorGame()
        let state = g.restore(from: #"{"seenHowTo":true}"#)
        #expect(state != nil)
        #expect(state?.seenHowTo == true)
        #expect(g.bestTotalPassages == 0)
        #expect(g.bestPassage == 0)
        #expect(g.lifetimeStars == 0)
        #expect(g.runNumber == 0)
        #expect(g.level == nil)
        #expect(g.phase == .idle)
    }

    // guards: legacy migration — completedLevels.max() seeds bestPassage AND bestTotalPassages; a legacy levelID resumes that passage with attempt 1 / loop 1 / totalPassages 0 defaults
    @Test func legacyMigration() {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"completedLevels":[3,12,7]}"#)
        #expect(g.bestPassage == 12)
        #expect(g.bestTotalPassages == 12)            // falls back to bestPassage
        #expect(g.lifetimeStars == 0)                 // unrecoverable from old schema
        #expect(g.runNumber == 0)
        #expect(g.level == nil)                       // completedLevels alone: no in-flight

        let h = NavigatorGame()
        h.restore(from: #"{"seenHowTo":true,"levelID":12}"#)
        #expect(h.level?.id == 12)
        #expect(h.attempt == 1)
        #expect(h.loopNumber == 1)
        #expect(h.totalPassages == 0)
    }

    // guards: out-of-range currentPassage (0, 61, -5, Int.max) restores the meta but loads no phantom passage and never traps; currentPeekMs stays 0 with no level
    @Test(arguments: [0, 61, -5, Int.max])
    func outOfRangePassageRestores(_ id: Int) {
        let g = NavigatorGame()
        let state = g.restore(from: #"{"seenHowTo":true,"bestTotalPassages":7,"currentPassage":\#(id)}"#)
        #expect(state != nil)                         // meta half still restores
        #expect(g.level == nil)
        #expect(g.bestTotalPassages == 7)
        #expect(g.phase == .idle)
        #expect(g.currentPeekMs == 0)
    }

    // guards: payload in-flight matrix — currentPassage/attempt/loopNumber/totalPassages present exactly in {.idle-with-level, .peek, .input}, absent in fresh-idle/.passageWon/.runOver; meta present in every phase (the .passageWon gap = documented run-loss-on-kill edge)
    @Test func payloadPhaseMatrix() throws {
        let g = NavigatorGame()
        var p = try decodePayload(g.payload(seenHowTo: true))
        #expect(p.currentPassage == nil)              // fresh .idle, no level
        #expect(p.bestTotalPassages == 0)             // meta always present

        g.startNewRun()
        p = try decodePayload(g.payload(seenHowTo: true))
        #expect(p.currentPassage == 1)                // .idle with level: in-flight

        g.beginPeek()
        p = try decodePayload(g.payload(seenHowTo: true))
        #expect(p.currentPassage == 1)                // .peek: in-flight

        while g.advanceWave() {}
        p = try decodePayload(g.payload(seenHowTo: true))
        #expect(p.currentPassage == 1)                // .input: in-flight
        #expect(p.attempt == 1)
        #expect(p.loopNumber == 1)
        #expect(p.totalPassages == 0)

        for c in g.pattern { _ = g.tap(c) }
        #expect(g.phase == .passageWon)
        p = try decodePayload(g.payload(seenHowTo: true))
        #expect(p.currentPassage == nil)              // celebration: not persisted
        #expect(p.bestTotalPassages == 1)             // meta still full

        let dead = NavigatorGame()
        dead.startNewRun()
        driveToInput(dead)
        let bad = (0..<dead.cellCount).filter { !dead.pattern.contains($0) }
        for c in bad.prefix(3) { _ = dead.tap(c) }
        p = try decodePayload(dead.payload(seenHowTo: true))
        #expect(p.currentPassage == nil)              // .runOver: not persisted
        #expect(p.runNumber == 1)
    }

    // guards: payload -> restore -> payload is a field-for-field fixed point, so loopNumber/totalPassages (and therefore currentPeekMs) are correct on the first frame after resume
    @Test func saveRoundTripFixedPoint() throws {
        let g = NavigatorGame()
        g.restore(from: #"{"seenHowTo":true,"bestTotalPassages":9,"lifetimeStars":50,"runNumber":4}"#)
        g.startNewRun()
        driveToInput(g)
        _ = g.tap(g.pattern[0])
        let first = g.payload(seenHowTo: true)
        let fresh = NavigatorGame()
        #expect(fresh.restore(from: first) != nil)
        let second = fresh.payload(seenHowTo: true)
        #expect(samePayload(try decodePayload(first), try decodePayload(second)))
        #expect(fresh.loopNumber == g.loopNumber)
        #expect(fresh.currentPeekMs == g.currentPeekMs)
    }

    // guards: resume determinism — an in-flight save resumes the byte-identical board (same level+attempt salt). Also PINS the budget-refill behavior: mistakesLeft/peeksLeft/found/wrong reset to full on resume (kill-scum: a player at 0 mistakes who memorized the board gets a clean slate on the identical pattern). Concluded design decision, not expected-fail: SavePayload's found/wrong/peeksLeft fields are explicitly legacy and deliberately no longer written — flagged for product review, do NOT "fix" silently
    @Test func resumeIdentityAndBudgetRefillPin() {
        let g = NavigatorGame()
        g.startNewRun()
        driveToInput(g)
        let bad = (0..<g.cellCount).filter { !g.pattern.contains($0) }
        _ = g.tap(bad[0])
        _ = g.tap(bad[1])
        _ = g.usePeek()
        #expect(g.mistakesLeft == 1)
        let saved = g.payload(seenHowTo: true)

        let fresh = NavigatorGame()
        #expect(fresh.restore(from: saved) != nil)
        #expect(fresh.level?.id == g.level?.id)
        #expect(fresh.attempt == g.attempt)
        #expect(fresh.pattern == g.pattern)           // identical star roll — the design contract
        #expect(fresh.mistakesLeft == 3)              // PIN: budgets refill on resume
        #expect(fresh.peeksLeft == 1)
        #expect(fresh.found.isEmpty)
        #expect(fresh.wrong.isEmpty)
    }

    // guards: pins that restore() silently replaces a LIVE run mid-input with the saved one — no guard, no merge; callers own the ordering
    @Test func restoreClobbersLiveRun() {
        let g = NavigatorGame()
        g.startNewRun()
        driveToInput(g)
        _ = g.tap(g.pattern[0])
        #expect(g.found.count == 1)
        let state = g.restore(from: #"{"seenHowTo":true,"runNumber":7,"currentPassage":5,"attempt":9,"loopNumber":2,"totalPassages":10}"#)
        #expect(state != nil)
        #expect(g.level?.id == 5)                     // live run silently replaced
        #expect(g.attempt == 9)
        #expect(g.loopNumber == 2)
        #expect(g.totalPassages == 10)
        #expect(g.runNumber == 7)
        #expect(g.found.isEmpty)
        #expect(g.phase == .idle)
    }

    // guards: abandonLevel residue pin — level nils and payload correctly reports not-in-flight, but pattern/found stay stale and peeksUsed reads a ghost -1 ((nil level -> 0) - peeksLeft); documents why instances must not be reused across unrelated assertions
    @Test func abandonLevelResiduePin() throws {
        let g = NavigatorGame()
        g.startNewRun()
        driveToInput(g)
        _ = g.tap(g.pattern[0])
        g.abandonLevel()
        #expect(g.level == nil)
        #expect(g.phase == .idle)
        #expect(g.isTutorial == false)
        let decoded = try decodePayload(g.payload(seenHowTo: true))
        #expect(decoded.currentPassage == nil)        // correctly not in-flight
        #expect(g.pattern.count == 3)                 // PIN: stale ghost board
        #expect(g.found.count == 1)                   // PIN: stale progress
        #expect(g.peeksUsed == -1)                    // PIN: ghost negative accounting
        #expect(g.starsTotal == 3)                    // PIN: ghost star count
    }

    // guards: decoder robustness — deeply nested unknown values (256 levels) and a 5,000-key payload decode without hanging or corrupting the known fields
    @Test func hostileJSONRobustness() {
        let g = NavigatorGame()
        let nested = #"{"seenHowTo":true,"bestTotalPassages":3,"junk":"#
            + String(repeating: "[", count: 256) + "1" + String(repeating: "]", count: 256) + "}"
        #expect(g.restore(from: nested) != nil)       // unknown keys skipped, known kept
        #expect(g.bestTotalPassages == 3)

        var big = #"{"seenHowTo":true,"lifetimeStars":12"#
        for i in 0..<5000 { big += ",\"k\(i)\":\(i)" }
        big += "}"
        let h = NavigatorGame()
        #expect(h.restore(from: big) != nil)
        #expect(h.lifetimeStars == 12)
    }
}

// MARK: - Stress (all bounded well under 2s in debug builds — harness-timed)

@MainActor
struct NavigatorStressTests {

    // guards: 10,000 consecutive runs stay stable — runNumber exact, per-level arrays replaced not accumulated, always landing on a valid P1
    @Test func tenThousandRunsStable() {
        let g = NavigatorGame()
        for _ in 0..<10_000 { g.startNewRun() }
        #expect(g.runNumber == 10_000)
        #expect(g.level?.id == 1)
        #expect(g.pattern.count == 3)
        #expect(g.phase == .idle)
        #expect(g.totalPassages == 0)
    }

    // guards: a legit 10-loop marathon (600 real passage wins) keeps every counter exact and the peek floor holds at 600; a loop-500 save proves pow underflow still floors cleanly
    @Test func loopMarathonPeekFloor() {
        let g = NavigatorGame()
        g.startNewRun()
        for _ in 0..<(10 * 60) {
            winPassage(g)
            g.advanceAfterWin()
        }
        #expect(g.loopNumber == 11)
        #expect(g.level?.id == 1)
        #expect(g.totalPassages == 600)
        #expect(g.currentPeekMs == 600)               // floor: 1600 * 0.85^10 ≈ 314 -> 600

        let z = NavigatorGame()
        z.restore(from: #"{"seenHowTo":true,"currentPassage":1,"attempt":1,"loopNumber":500}"#)
        #expect(z.currentPeekMs == 600)               // pow underflow, floor holds
    }

    // guards: tap spam on a full 8x8 board with a forged huge mistake budget — every cell scores/penalizes exactly once, duplicates are free forever (1,000 spam taps), and the final accounting is exact (49 wrongs, 15 stars, score 855 = 675 streak + 180 win, no perfect)
    @Test func tapSpamExactAccounting() {
        let g = NavigatorGame()
        g.newLevel(forgedLevel(grid: 8, targets: 15, mistakes: 1000), attempt: 7)
        driveToInput(g)
        let bad = (0..<g.cellCount).filter { !g.pattern.contains($0) }
        #expect(bad.count == 49)
        for c in bad { #expect(g.tap(c) == .miss) }
        #expect(g.mistakesLeft == 1000 - 49)
        for c in bad { #expect(g.tap(c) == .duplicate) }
        #expect(g.mistakesLeft == 1000 - 49)          // duplicates are free
        for _ in 0..<1000 { #expect(g.tap(bad[0]) == .duplicate) }
        #expect(g.wrong.count == 49)

        for c in g.pattern.dropLast() {
            #expect(g.tap(c) == .star)
            #expect(g.tap(c) == .duplicate)           // instant re-tap scores nothing
        }
        #expect(g.lifetimeStars == 14)
        #expect(g.tap(g.pattern.last!) == .passageWon)
        #expect(g.lifetimeStars == 15)
        #expect(g.runStarsCharted == 15)
        #expect(g.found.count == 15)
        #expect(g.chartBeat == 15)
        #expect(g.levelScore == 855)                  // (25+30+35+40+45 + 50*10) + (30+150)
        #expect(g.isPerfect == false)
        #expect(g.tap(g.pattern[0]) == .ignored)      // post-win immunity
    }
}

// MARK: - Trap regressions (formerly .disabled — all four SIGTRAPed pre-fix)
//
// Each crash was PROVEN 2026-07-17 by compiling NavigatorGame/NavigatorLevel
// into a standalone harness: all four scenarios exited 133 (SIGTRAP). The
// same-day hardening pass clamps restore()'s numeric fields, newLevel's
// attempt, and currentPeekMs's Double->Int conversion, so these now run
// enabled as permanent regressions against the crash-loop-at-launch class.

@MainActor
struct NavigatorTrapDocumentationTests {

    // REGRESSION(negative-attempt-trap, fixed 2026-07-17): restore() used to feed
    // attempt:-1 straight into `UInt64(attempt)` — a fatal trapping conversion.
    // Because restore runs on launch from the SwiftData-stored payload, one corrupt
    // save was a permanent crash loop until the row was deleted. Both restore() and
    // newLevel now clamp attempt to >= 0.
    // guards: a corrupt save with a negative attempt must be rejected or clamped, never crash the app at launch
    @Test func negativeAttemptRestoreMustNotTrap() {
        let g = NavigatorGame()
        _ = g.restore(from: #"{"seenHowTo":true,"currentPassage":1,"attempt":-1}"#)
        #expect(g.attempt >= 0)                       // sanitized resume
        #expect(g.level?.id == 1)                     // passage still loads
    }

    // REGRESSION(negative-runnumber-trap, fixed 2026-07-17): restore used to accept
    // runNumber:-10 unchecked; the next startNewRun computed attempt == -9 and
    // trapped in the same UInt64 conversion. restore now clamps runNumber >= 0.
    // guards: a corrupt save with a negative runNumber must not crash the next run start
    @Test func negativeRunNumberStartMustNotTrap() {
        let g = NavigatorGame()
        _ = g.restore(from: #"{"seenHowTo":true,"runNumber":-10}"#)
        g.startNewRun()
        #expect(g.runNumber >= 1)
        #expect(g.level?.id == 1)
    }

    // REGRESSION(negative-loop-trap, fixed 2026-07-17): restore used to accept
    // loopNumber:-5; winning P60 then advanceAfterWin computed a negative attempt
    // salt and trapped in UInt64(). restore now clamps loopNumber >= 1.
    // (currentPeekMs itself always survived negative loops — pinned in
    // negativeLoopNumberPeekGuard — the trap was in the salt arithmetic.)
    // guards: a corrupt save with a negative loopNumber must not crash the loop-around after P60
    @Test func negativeLoopAdvanceMustNotTrap() {
        let g = NavigatorGame()
        _ = g.restore(from: #"{"seenHowTo":true,"currentPassage":60,"attempt":1,"loopNumber":-5}"#)
        winPassage(g)
        g.advanceAfterWin()
        #expect(g.attempt >= 0)
        #expect(g.level?.id == 1)
    }

    // REGRESSION(peekms-overflow-trap, fixed 2026-07-17): currentPeekMs computed
    // `Int(Double(base) * multiplier)`; Double(Int.max) rounds up to 2^63,
    // unrepresentable in Int — fatal conversion. Only reachable via forged/future
    // levels (campaign peeks <= 3500), but a computed property must be total.
    // The conversion is now min-clamped below 2^63.
    // guards: currentPeekMs must be total for any level the (unvalidated) newLevel seam accepts
    @Test func hugePeekMsMustNotTrap() {
        let g = NavigatorGame()
        g.newLevel(forgedLevel(grid: 4, targets: 3, peekMs: Int.max), attempt: 1)
        #expect(g.currentPeekMs >= 600)
    }
}

// MARK: - Concurrency posture

/// Deliberately NOT @MainActor: NavigatorGame is @Observable but carries no
/// actor isolation, no timers, and no Date() — the view owns the clock. Swift 6
/// prevents cross-actor sharing of this non-Sendable class at compile time, so
/// the only runtime-checkable posture is that a full run drives cleanly off the
/// main actor with no hidden MainActor assertions or dispatch.
struct NavigatorConcurrencyTests {

    // guards: the engine is pure and isolation-agnostic — a complete startNewRun -> win -> advanceAfterWin cycle succeeds off the main actor
    @Test func engineDrivesOffMainActor() async {
        let g = NavigatorGame()
        g.startNewRun()
        g.beginPeek()
        while g.advanceWave() {}
        for c in g.pattern { _ = g.tap(c) }
        #expect(g.phase == .passageWon)
        #expect(g.totalPassages == 1)
        g.advanceAfterWin()
        #expect(g.level?.id == 2)
        #expect(g.phase == .idle)
    }
}
