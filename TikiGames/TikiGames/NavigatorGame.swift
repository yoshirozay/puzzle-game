import Foundation
import Observation

/// Navigator engine — pure state machine for the memory-flash game
/// (show the chart → clouds roll over → chart it back from memory). No
/// SwiftUI, no timers: the view owns the clock and drives phase advances
/// (`beginPeek`/`advanceWave`); the engine owns the truth.
///
/// **Run model (2048-shaped, 2026-07-15; rewind 2026-07-25):** a "run" is a
/// single attempt to chart as many consecutive passages as possible. 3
/// mistakes per passage; fail the passage → run ends → the next run resumes
/// `rewindPassages` back, floored at the current band's opening passage
/// (was: back to Passage 1). Free retry is retired — a defeat still costs a
/// life, and now costs position too, just not the whole campaign.
/// Persistent meta: `bestPassage` high-water mark + `lifetimeStars` total.
/// Back-out mid-passage drops one passage (min 1) as a mild anti-abuse
/// deterrent — the player can leave to play another game without ending
/// the run, but gets nudged back a step. App-kill preserves the run and
/// same star roll (attempt unchanged) so genuine interruptions don't cost.
@Observable
final class NavigatorGame {
    enum Phase: Equatable {
        case idle              // no run in flight — run-start screen owns
        case peek(Int)         // showing wave n of the chart
        case input             // clouds closed — chart from memory
        case passageWon        // passage cleared; view auto-advances
        case runOver           // run ended (passage lost); summary shown
    }

    enum TapResult {
        case ignored, duplicate, star, miss, passageWon, runOver
    }

    private(set) var level: NavigatorLevel?
    private(set) var phase: Phase = .idle
    private(set) var pattern: [Int] = []
    private(set) var waveGroups: [[Int]] = []
    private(set) var decoyCells: [Int] = []
    private(set) var found: Set<Int> = []
    private(set) var wrong: Set<Int> = []
    private(set) var mistakesLeft = 0
    private(set) var peeksLeft = 0
    private(set) var attempt = 1
    private(set) var levelScore = 0
    private(set) var streak = 0
    private(set) var chartBeat = 0

    /// Which loop of the campaign the current run is on. Starts at 1;
    /// increments each time the player beats Passage 60 (BrickBreaker
    /// precedent — the game never ends, it just gets faster).
    private(set) var loopNumber = 1
    /// Passages cleared in this run, cumulative across loops. Beat P60 →
    /// this is 60 → beat loop 2's P15 → this is 75. The primary run meta.
    private(set) var totalPassages = 0
    /// Persistent high-water mark: greatest `totalPassages` ever reached in
    /// a single run. Displayed on the run-start screen.
    private(set) var bestTotalPassages = 0
    /// Legacy: single-loop high-water, kept for save-migration fallback.
    private(set) var bestPassage = 0
    /// Persistent total stars ever charted across every run.
    private(set) var lifetimeStars = 0
    /// Persistent count of runs started — folded into the RNG so the same
    /// passage rolls differently across runs (blocks memorize-and-repeat).
    private(set) var runNumber = 0
    /// How far a defeat sets the player back. A defeat costs a life AND
    /// position, but not the whole campaign — see `rewindAfterDefeat`.
    static let rewindPassages = 5
    /// Where the next run begins, and in which loop. A defeat rewinds these;
    /// nothing else moves them, so they are the player's campaign position.
    /// Persisted (unlike in-flight passage state) so quitting after a defeat
    /// does not silently cost the rewind.
    private(set) var resumePassage = 1
    private(set) var resumeLoop = 1
    /// This run's tally, for the run-over summary.
    private(set) var runStarsCharted = 0
    /// Best score across passages (unchanged bundle-wide record).
    private(set) var best = 0
    /// True while the first-run coach is running its scripted P1. In this
    /// mode, tap()'s passage-win branch skips all persistent stat updates
    /// (bestPassage / totalPassages / bestTotalPassages / lifetimeStars) —
    /// tutorial completions shouldn't seed the player's records.
    /// Any real passage load (newLevel) sheds the flag; seedTutorialBoard
    /// re-sets it after seeding, and abandonLevel clears it too.
    private(set) var isTutorial = false

    var grid: Int { level?.grid ?? 5 }
    var cellCount: Int { grid * grid }
    var starsTotal: Int { pattern.count }
    var starsFound: Int { found.count }
    var peeksUsed: Int { (level?.peeks ?? 0) - peeksLeft }
    var isPerfect: Bool { wrong.isEmpty && peeksUsed == 0 }
    var isRunActive: Bool { level != nil && (phase != .idle && phase != .runOver) }

    /// Peek time actually used at runtime — the level's base peek shrunk by
    /// 15% per loop (BrickBreaker "faster ball" mechanic). Floored at 600 ms
    /// so extreme loops don't collapse below reflex time; past that the
    /// difficulty stops climbing and players just eventually fail.
    var currentPeekMs: Int {
        guard let base = level?.peekMs else { return 0 }
        let multiplier = pow(0.85, Double(max(0, loopNumber - 1)))
        // Clamp before Int(): Double(Int.max) rounds up to 2^63, which
        // Int() traps on. Only reachable via forged/hostile peekMs values
        // (campaign tops out at 3500), but a computed property must be total.
        return max(600, Int(min(Double(base) * multiplier, 9.0e18)))
    }
    /// True if the current passage-win transition also completes a loop —
    /// the win panel and next-run copy read this to change wording.
    var justCompletedLoop: Bool {
        phase == .passageWon && level?.id == NavigatorLevels.all.count
    }
    /// True only during the recall window — the penalty for backing out
    /// applies here (peek/input); it does NOT apply between passages or
    /// after run-over, when nothing is left to lose.
    var isMidPassage: Bool {
        switch phase {
        case .peek, .input: return true
        default: return false
        }
    }

    func configureBest(_ value: Int) { best = max(best, value) }

    // MARK: run lifecycle

    /// Starts a run: bumps runNumber (for cross-run seed divergence), resets
    /// the star tally, and loads the player's campaign position — Passage 1
    /// for a new player, otherwise wherever the last defeat rewound them to.
    func startNewRun() {
        isTutorial = false
        runNumber += 1
        loopNumber = resumeLoop
        // Seed the tally with the depth the player keeps. `totalPassages` is
        // the Game Center score (NavigatorView submits it), and before the
        // rewind existed a run always started at Passage 1, so the number was
        // campaign depth. Seeding preserves exactly that meaning: resuming at
        // Passage 25 and falling at 35 scores 34, the same as an unbroken run
        // that reached 35. Without it every score after a defeat would be
        // measured from the rewind point and the live leaderboard's history
        // would become unreachable.
        totalPassages = (resumeLoop - 1) * NavigatorLevels.all.count + (resumePassage - 1)
        runStarsCharted = 0
        guard let start = NavigatorLevels.level(id: resumePassage) else { return }
        newLevel(start, attempt: runNumber)
    }

    /// A defeat costs a life (spent view-side) and position (spent here).
    /// The next run restarts `rewindPassages` back, floored at the first
    /// passage of the band the player had reached — so the setback bites
    /// without dropping anyone to the 4×4 opener. This replaced a full reset
    /// to Passage 1, which made every defeat cost a replay of the campaign's
    /// unloseable opening before the game could be lost again.
    ///
    /// Not the unearned skip that `advanceAfterWin`'s guard exists to block:
    /// this only ever moves the player BACKWARD from a passage they reached,
    /// and the boards re-roll (runNumber salts the attempt) so the replayed
    /// stretch is never the same chart twice.
    private func rewindAfterDefeat(from fallen: Int) {
        resumePassage = max(NavigatorLevels.bandStart(for: fallen), fallen - Self.rewindPassages)
        resumeLoop = loopNumber
    }

    /// Called by the view after `.passageWon` — advances to the next
    /// passage. If the current passage was the last, loops back to
    /// Passage 1 with the loop counter bumped (peek time shrinks — see
    /// `currentPeekMs`). The run never ends on a passage-win; only a
    /// mistake budget wipe (→ .runOver) can end it.
    func advanceAfterWin() {
        // Only legal from .passageWon — without the guard this was callable
        // from .idle/.runOver to skip to any passage (or loop) unearned.
        guard phase == .passageWon, let lvl = level else { return }
        // Salt weights the loop by 997 so distinct (run, loop) pairs never
        // collide: the old runNumber + loopNumber made run N+1's loop 1
        // replay run N's loop 2 boards verbatim (memorize-and-repeat
        // through the diagonal). Loop 1 matches startNewRun's P1 salt.
        if let next = NavigatorLevels.level(id: lvl.id + 1) {
            newLevel(next, attempt: runNumber + (loopNumber - 1) * 997)
        } else {
            loopNumber += 1
            guard let p1 = NavigatorLevels.level(id: 1) else { return }
            newLevel(p1, attempt: runNumber + (loopNumber - 1) * 997)
        }
    }

    /// Back-out anti-abuse penalty (only fires mid-passage — .peek/.input).
    /// Drops the current passage by 1 (min 1) with a fresh roll on the new
    /// passage, so backing out to skip a hard pattern costs one easy replay.
    /// No-op if not mid-passage.
    func backOutOfRun() {
        guard isMidPassage, let lvl = level else { return }
        let dropped = max(1, lvl.id - 1)
        guard let target = NavigatorLevels.level(id: dropped) else { return }
        // Hand back the dropped passage's tally too, so win → back out →
        // re-win is net zero: totalPassages (and through it
        // bestTotalPassages) can't be farmed without forward progress.
        totalPassages = max(0, totalPassages - 1)
        newLevel(target, attempt: attempt + 1)
    }

    // MARK: passage lifecycle

    /// Loads a passage and derives its chart from the level seed salted by
    /// the attempt (Luau precedent: parameters fixed, stars fresh per try —
    /// same-pattern retries would collapse the memory challenge).
    func newLevel(_ lvl: NavigatorLevel, attempt: Int) {
        level = lvl
        // Clamp: a negative attempt (corrupt save) fed UInt64() below and
        // trapped — a permanent crash loop, since restore runs at launch.
        self.attempt = max(0, attempt)
        // Loading any real passage sheds coach mode (seedTutorialBoard
        // re-sets it) — otherwise every passage after the tutorial would
        // silently skip persistent stat updates.
        isTutorial = false
        var rng = NavRandom(seed: lvl.seed &+ UInt64(self.attempt) &* 0x9E37_79B9_7F4A_7C15)
        pattern = Self.makePattern(grid: lvl.grid, targets: lvl.targets, scatter: lvl.scatter, family: lvl.family, rng: &rng)
        waveGroups = Self.slice(pattern, into: lvl.waves)
        decoyCells = Self.makeDecoys(grid: lvl.grid, avoiding: Set(pattern), count: lvl.decoys, rng: &rng)
        found = []
        wrong = []
        mistakesLeft = lvl.mistakes
        peeksLeft = lvl.peeks
        levelScore = 0
        streak = 0
        phase = .idle
    }

    func abandonLevel() {
        level = nil
        phase = .idle
        isTutorial = false
    }

    // MARK: phase advances (view-clocked)

    func beginPeek() {
        // Only legal from .idle: from .input it was a free re-show of the
        // chart (usePeek is the paid path), and from .runOver it
        // resurrected a dead run into a stat-recording zombie.
        guard phase == .idle, level != nil else { return }
        phase = .peek(0)
    }

    /// Returns true while more waves remain; false once input begins.
    @discardableResult
    func advanceWave() -> Bool {
        guard case .peek(let w) = phase else { return false }
        if w + 1 < waveGroups.count {
            phase = .peek(w + 1)
            return true
        }
        phase = .input
        return false
    }

    /// Cells lit during the current peek wave.
    var litCells: Set<Int> {
        guard case .peek(let w) = phase else { return [] }
        return Set(waveGroups[w])
    }

    // MARK: input

    func tap(_ cell: Int) -> TapResult {
        guard phase == .input, let lvl = level, cell >= 0, cell < cellCount else { return .ignored }
        if found.contains(cell) || wrong.contains(cell) { return .duplicate }
        if pattern.contains(cell) {
            found.insert(cell)
            streak += 1
            levelScore += 25 + min(streak - 1, 5) * 5
            chartBeat += 1
            runStarsCharted += 1
            if !isTutorial { lifetimeStars += 1 }
            if found.count == pattern.count {
                levelScore += 30 + 10 * lvl.targets
                if isPerfect { levelScore += 50 }
                if !isTutorial {
                    if lvl.id > bestPassage { bestPassage = lvl.id }
                    totalPassages += 1
                    if totalPassages > bestTotalPassages {
                        bestTotalPassages = totalPassages
                    }
                }
                phase = .passageWon
                return .passageWon
            }
            return .star
        }
        wrong.insert(cell)
        streak = 0
        mistakesLeft -= 1
        if mistakesLeft <= 0 {
            phase = .runOver
            // Tutorial boards can't lose (mistakesLeft 99), but guard anyway —
            // a coach defeat must not move the player's campaign position.
            if !isTutorial { rewindAfterDefeat(from: lvl.id) }
            return .runOver
        }
        return .miss
    }

    /// Spends a re-peek. The view shows `remainingStars` briefly; the
    /// engine only accounts for the budget.
    func usePeek() -> Bool {
        guard phase == .input, peeksLeft > 0 else { return false }
        peeksLeft -= 1
        return true
    }

    var remainingStars: Set<Int> { Set(pattern).subtracting(found) }

    // MARK: tutorial seed

    /// Fixed first board for the coach: passage 1, tutorial-salted so the
    /// pattern differs from real-run P1. Marks isTutorial so wins don't
    /// pollute the player's persistent stats and mistake budget is lifted
    /// so a misclick during the coach doesn't punish the beginner.
    func seedTutorialBoard() {
        guard let l1 = NavigatorLevels.level(id: 1) else { return }
        newLevel(l1, attempt: 99)
        isTutorial = true
        mistakesLeft = 99
    }

    // MARK: generation — random charts

    /// Uniform random star placement — Carson's call after three rounds of
    /// figure generators all read as "common": "just a random distribution
    /// of tiles." Random points connected by the win lines still draw a
    /// constellation (real ones ARE random stars plus imagined lines), and
    /// no two charts share a signature. One invisible guard: re-roll rolls
    /// that land four stars in a 2x2 block — pure luck-clumps read as a
    /// defect, not as randomness. `scatter` and `family` are flavor/reserved
    /// (family stays as the passage card's copy).
    private static func makePattern(grid: Int, targets: Int, scatter: Double, family: String, rng: inout NavRandom) -> [Int] {
        let count = min(targets, grid * grid - 1)
        var best: [Int] = []
        var bestScore = -1.0
        for _ in 0..<8 {
            var cells: [Int] = []
            var seen = Set<Int>()
            while cells.count < count {
                let candidate = Int(rng.next() % UInt64(grid * grid))
                if seen.insert(candidate).inserted { cells.append(candidate) }
            }
            let score = spacingScore(cells, grid: grid)
            if score > bestScore {
                bestScore = score
                best = cells
            }
            if !hasFilledBlock(seen, grid: grid) {
                best = cells
                break
            }
        }
        return best
    }

    /// True when any 2x2 block is fully starred — the one layout randomness
    /// isn't allowed to ship.
    private static func hasFilledBlock(_ cells: Set<Int>, grid: Int) -> Bool {
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

    private static func chebyshev(_ a: Int, _ b: Int, grid: Int) -> Int {
        max(abs(a / grid - b / grid), abs(a % grid - b % grid))
    }

    /// Mean nearest-neighbor distance — tie-breaker among re-rolls.
    private static func spacingScore(_ cells: [Int], grid: Int) -> Double {
        guard cells.count > 1 else { return 0 }
        var total = 0.0
        for a in cells {
            let nearest = cells.filter { $0 != a }.map { chebyshev(a, $0, grid: grid) }.min() ?? 0
            total += Double(nearest)
        }
        return total / Double(cells.count)
    }

    private static func slice(_ pattern: [Int], into waves: Int) -> [[Int]] {
        let n = max(1, min(waves, pattern.count))
        let base = pattern.count / n
        let extra = pattern.count % n
        var groups: [[Int]] = []
        var idx = 0
        for w in 0..<n {
            let size = base + (w < extra ? 1 : 0)
            groups.append(Array(pattern[idx..<idx + size]))
            idx += size
        }
        return groups
    }

    private static func makeDecoys(grid: Int, avoiding: Set<Int>, count: Int, rng: inout NavRandom) -> [Int] {
        guard count > 0 else { return [] }
        var pool = (0..<(grid * grid)).filter { !avoiding.contains($0) }
        var picks: [Int] = []
        for _ in 0..<min(count, pool.count) {
            let i = Int(rng.next() % UInt64(pool.count))
            picks.append(pool.remove(at: i))
        }
        return picks
    }

    // MARK: persistence

    struct SavePayload: Codable {
        var seenHowTo: Bool
        // Persistent roguelike meta — always written when present, all
        // optional so historical payloads still decode.
        var bestTotalPassages: Int?
        var bestPassage: Int?
        var lifetimeStars: Int?
        var runNumber: Int?
        // Campaign position. Persisted always (not in-flight state): it must
        // survive a quit taken from the run-over panel, or the defeat rewind
        // would silently become a full reset to Passage 1.
        var resumePassage: Int?
        var resumeLoop: Int?
        // In-flight run state — only present while a run is mid-passage;
        // cleared between passages/on runOver so the next launch lands on
        // the run-start screen.
        var currentPassage: Int?
        var attempt: Int?
        var loopNumber: Int?
        var totalPassages: Int?
        // Legacy campaign fields — kept optional for one-time migration.
        var completedLevels: [Int]?
        var levelID: Int?
        var found: [Int]?
        var wrong: [Int]?
        var peeksLeft: Int?
        var levelScore: Int?
    }

    /// Persists the run-level meta always; passage-in-flight is persisted
    /// while phase is .peek or .input so an app kill can resume the same
    /// passage with the same star roll (attempt unchanged — no fresh look).
    /// Between passages / after run-over, currentPassage clears so the next
    /// launch lands on the run-start screen.
    func payload(seenHowTo: Bool) -> String {
        // Persist in-flight run state during peek, input, AND the transient
        // .idle window after advanceAfterWin / startNewRun / backOutOfRun
        // (level is loaded, runPeek queued). Skip celebration (.passageWon,
        // where an app-kill loses the run — small edge case) and .runOver.
        // The tutorial board never persists as in-flight: restoring it
        // would resume the coach's scripted P1 as a real run.
        let inFlight: Bool
        switch phase {
        case .peek, .input, .idle: inFlight = level != nil && !isTutorial
        case .passageWon, .runOver: inFlight = false
        }
        let state = SavePayload(
            seenHowTo: seenHowTo,
            bestTotalPassages: bestTotalPassages,
            bestPassage: bestPassage,
            lifetimeStars: lifetimeStars,
            runNumber: runNumber,
            resumePassage: resumePassage,
            resumeLoop: resumeLoop,
            currentPassage: inFlight ? level?.id : nil,
            attempt: inFlight ? attempt : nil,
            loopNumber: inFlight ? loopNumber : nil,
            totalPassages: inFlight ? totalPassages : nil
        )
        guard let data = try? JSONEncoder().encode(state) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Restores persistent meta and any in-flight run. Legacy payloads
    /// migrate: completedLevels.max() seeds bestPassage; bestTotalPassages
    /// falls back to bestPassage; lifetimeStars starts at 0 (unrecoverable
    /// from the old schema).
    @discardableResult
    func restore(from json: String?) -> SavePayload? {
        guard let json, let data = json.data(using: .utf8),
              let state = try? JSONDecoder().decode(SavePayload.self, from: data) else {
            return nil
        }
        // Corrupt/hostile saves: clamp every counter into a sane range.
        // Negative values reached UInt64()/salt arithmetic and trapped
        // (a crash loop, since restore runs at launch); the upper caps
        // keep the later +1 / *997 salt arithmetic overflow-free.
        bestPassage = max(0, state.bestPassage ?? state.completedLevels?.max() ?? 0)
        bestTotalPassages = max(0, state.bestTotalPassages ?? bestPassage)
        lifetimeStars = max(0, state.lifetimeStars ?? 0)
        runNumber = max(0, min(state.runNumber ?? 0, 1_000_000))
        // Absent in pre-rewind payloads → Passage 1, which is exactly what a
        // migrating save should resume from.
        resumePassage = min(max(1, state.resumePassage ?? 1), NavigatorLevels.all.count)
        resumeLoop = max(1, min(state.resumeLoop ?? 1, 1_000_000))
        let passageID = state.currentPassage ?? state.levelID
        if let id = passageID, let lvl = NavigatorLevels.level(id: id) {
            // Restore loop context and in-run tally before newLevel, so
            // scenePhase and currentPeekMs read the right numbers on the
            // very first frame after resume.
            loopNumber = max(1, min(state.loopNumber ?? 1, 1_000_000))
            totalPassages = max(0, state.totalPassages ?? 0)
            // Same attempt as saved → same star roll on resume. Only
            // back-out and advance bump the salt.
            newLevel(lvl, attempt: max(0, min(state.attempt ?? 1, 1_000_000)))
        }
        return state
    }
}

/// SplitMix64 — deterministic, attempt-salted (Luau seeded-RNG precedent).
private struct NavRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func double() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
