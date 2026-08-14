import Foundation

/// Binary-search the move budget to land the bot's win rate inside a band.
/// The band is inclusive on the low end, exclusive on the high end —
/// e.g. teach band = [0.90, 1.01] means "at least 90%, up to 100%".
enum Solver {

    /// Win-rate bands (matching LUAU_LEVELS_PLAN.md §generation):
    ///   teach:  ≥ 90%    (also used for L1–12 exam-lite floor)
    ///   easy:   75–90%
    ///   medium: 55–75%
    ///   hard:   35–55%
    /// Callers pick the band per intended difficulty and the solver
    /// returns the smallest move budget that puts the greedy bot inside it.
    struct Band {
        let name: String
        let lowerInclusive: Double
        let upperExclusive: Double

        static let teach   = Band(name: "teach",  lowerInclusive: 0.90, upperExclusive: 1.01)
        static let easy    = Band(name: "easy",   lowerInclusive: 0.75, upperExclusive: 0.90)
        static let medium  = Band(name: "medium", lowerInclusive: 0.55, upperExclusive: 0.75)
        static let hard    = Band(name: "hard",   lowerInclusive: 0.35, upperExclusive: 0.55)

        static let all: [Band] = [.teach, .easy, .medium, .hard]

        func contains(_ rate: Double) -> Bool {
            rate >= lowerInclusive && rate < upperExclusive
        }
    }

    struct SolveResult {
        let level: LuauLevel
        let band: Band
        let moves: Int?
        let observedRate: Double
        let steps: [(moves: Int, rate: Double)]
        let converged: Bool

        var summary: String {
            let mv = moves.map(String.init) ?? "—"
            let pct = String(format: "%.1f%%", observedRate * 100)
            let path = steps.map { "\($0.moves)→\(String(format: "%.0f%%", $0.rate*100))" }.joined(separator: " ")
            return "L\(level.id) [\(level.archetype)] band=\(band.name) moves=\(mv) rate=\(pct) steps=\(steps.count): \(path) \(converged ? "✓" : "✗")"
        }
    }

    /// Search `moves ∈ [lo, hi]` for the smallest budget that lands the bot's
    /// observed win rate inside `band`. Uses a hybrid strategy:
    ///   1. Sample the endpoints — if the whole range is above the band's
    ///      upper bound at `lo`, or below the lower at `hi`, we've probed
    ///      the wrong window and return `converged = false` with the best
    ///      observed rate.
    ///   2. Binary-search by monotonicity: fewer moves → lower rate.
    /// Attempts per eval defaults to 200 (harness verify uses 100 for
    /// speed; production runs use 400 per the plan).
    static func solve(level: LuauLevel, band: Band,
                      loMoves: Int = 8, hiMoves: Int = 50,
                      attemptsPerEval: Int = 200) -> SolveResult {
        precondition(loMoves >= 1 && hiMoves > loMoves)
        var steps: [(moves: Int, rate: Double)] = []

        func rate(at m: Int) -> Double {
            let r = Evaluator.evaluate(level: level, movesBudget: m, attempts: attemptsPerEval).winRate
            steps.append((m, r))
            return r
        }

        // Bracket first.
        let rLo = rate(at: loMoves)
        let rHi = rate(at: hiMoves)

        // Case: hi is still below the band — level too hard for the range.
        if rHi < band.lowerInclusive {
            return SolveResult(level: level, band: band, moves: nil,
                               observedRate: rHi, steps: steps, converged: false)
        }
        // Case: lo is already above the band — level too easy.
        if rLo >= band.upperExclusive {
            return SolveResult(level: level, band: band, moves: nil,
                               observedRate: rLo, steps: steps, converged: false)
        }

        // Binary search: find smallest m with rate(m) >= band.lowerInclusive,
        // then verify it's < band.upperExclusive. Because rate is monotonic-
        // ish (with noise), we shrink around the boundary and accept the
        // first hit inside the band.
        var lo = loMoves, hi = hiMoves
        var bestInside: (moves: Int, rate: Double)? = nil
        var bestOutside: (moves: Int, rate: Double) = (hiMoves, rHi)

        while hi - lo > 1 {
            let m = (lo + hi) / 2
            let r = rate(at: m)
            if band.contains(r) {
                bestInside = (m, r)
                // Try to find a smaller move budget still inside band.
                hi = m
            } else if r < band.lowerInclusive {
                lo = m
            } else { // above upper — need fewer moves? No, more restrictive.
                hi = m
            }
            if abs(r - band.lowerInclusive) < abs(bestOutside.rate - band.lowerInclusive) ||
                abs(r - band.upperExclusive) < abs(bestOutside.rate - band.upperExclusive) {
                bestOutside = (m, r)
            }
        }

        if let inside = bestInside {
            return SolveResult(level: level, band: band, moves: inside.moves,
                               observedRate: inside.rate, steps: steps, converged: true)
        }
        // Never hit the band despite bracketing — very tight noise, return
        // closest attempt with converged=false so the caller can flag.
        return SolveResult(level: level, band: band, moves: bestOutside.moves,
                           observedRate: bestOutside.rate, steps: steps, converged: false)
    }
}
