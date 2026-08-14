import Foundation

/// Runs the greedy `LuauBot` against a `LuauLevel` at a chosen move budget,
/// gathering the stats a rubric grader (Stage F) and the solver (below)
/// consume. Deterministic given `(level.seed, attempt)` per attempt — same
/// inputs → identical `AttemptResult`.
enum Evaluator {

    /// Which policy plays the attempt. Defaults to the greedy `LuauBot`
    /// everywhere, so the solver and campaign paths behave exactly as before;
    /// `.strong` exists to measure the skill ceiling the budgets leave unused.
    enum Policy: String {
        case greedy, strong
        func playToEnd(in game: LuauGame) {
            switch self {
            case .greedy: LuauBot.playToEnd(in: game)
            case .strong: LuauStrongBot.playToEnd(in: game)
            }
        }
    }

    /// One bot playthrough of one attempt salt.
    struct AttemptResult {
        let won: Bool
        let movesUsed: Int
        let jellyRemaining: Int
        let jellyTouched: Set<Int>   // row*7+col of every cell whose jelly ever hit 0
        let score: Int
    }

    /// Aggregated stats over N attempts.
    struct EvalResult {
        let level: LuauLevel
        let movesBudget: Int
        let attempts: Int
        let wins: Int
        let winRate: Double
        let medianMovesLeftOnWin: Int
        let jellyEverCleared: Set<Int>
        let scoreMedian: Int

        var summary: String {
            let pct = String(format: "%.1f%%", winRate * 100)
            return "L\(level.id) [\(level.archetype)] moves=\(movesBudget) attempts=\(attempts) wins=\(wins) rate=\(pct) medMovesLeft=\(medianMovesLeftOnWin) medScore=\(scoreMedian)"
        }
    }

    /// Runs one attempt at a specific move budget. Used both by the
    /// aggregator below and by the harness verify command (single-attempt
    /// deep dive).
    static func attempt(level: LuauLevel, movesBudget: Int, attempt: UInt64,
                        policy: Policy = .greedy) -> AttemptResult {
        let game = LuauGame()
        // Snapshot the level with the desired budget in place. Goes through
        // `with(moves:)` rather than re-listing fields, so a field added to
        // LuauLevel can never be silently dropped here.
        let staged = level.with(moves: movesBudget)
        game.newLevel(staged, attempt: attempt)
        // Track jelly-touched cells across the whole run.
        let jellyStart = game.jelly
        policy.playToEnd(in: game)
        var touched = Set<Int>()
        for i in 0..<jellyStart.count where jellyStart[i] > Int(game.jelly[i]) {
            touched.insert(i)
        }
        return AttemptResult(
            won: game.didWinLevel,
            movesUsed: staged.moves - game.movesLeft,
            jellyRemaining: game.jellyRemaining,
            jellyTouched: touched,
            score: game.score
        )
    }

    /// Runs N attempts at a fixed move budget, then aggregates. The plan's
    /// N is 400 — smaller for probe/verify commands.
    static func evaluate(level: LuauLevel, movesBudget: Int, attempts: Int,
                         policy: Policy = .greedy) -> EvalResult {
        var wins = 0
        var jellyEver = Set<Int>()
        var movesLeftOnWin: [Int] = []
        var scores: [Int] = []
        for a in 0..<attempts {
            let res = attempt(level: level, movesBudget: movesBudget,
                              attempt: UInt64(a &+ 1), policy: policy)
            if res.won {
                wins += 1
                movesLeftOnWin.append(movesBudget - res.movesUsed)
            }
            jellyEver.formUnion(res.jellyTouched)
            scores.append(res.score)
        }
        let winRate = attempts > 0 ? Double(wins) / Double(attempts) : 0
        return EvalResult(
            level: level,
            movesBudget: movesBudget,
            attempts: attempts,
            wins: wins,
            winRate: winRate,
            medianMovesLeftOnWin: median(movesLeftOnWin),
            jellyEverCleared: jellyEver,
            scoreMedian: median(scores)
        )
    }

    private static func median(_ xs: [Int]) -> Int {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        return s[s.count / 2]
    }
}
