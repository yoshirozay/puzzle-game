import Foundation

/// Auto-reject rules — the plan §generation step 5. A level fails one
/// of these gates → it doesn't ship, LevelForge tosses it. This filter runs
/// *after* a solve pass (we need the solver's stats to test the "insensitive
/// to ±4 moves" rule).
enum Rejector {

    enum Rejection: String {
        case unreachableJelly       // bot never cleared some jelly cell
        case luckDominated          // rate barely moves across a ±4 move window
        case solverDidNotConverge   // solver returned converged=false
        case tooFewOpeningSwaps     // starting board has < 2 legal opening swaps
    }

    struct Report {
        let level: LuauLevel
        let rejections: [Rejection]
        var accepted: Bool { rejections.isEmpty }

        var summary: String {
            if accepted {
                return "L\(level.id) [\(level.archetype)] ACCEPTED"
            }
            let list = rejections.map(\.rawValue).joined(separator: ",")
            return "L\(level.id) [\(level.archetype)] REJECTED: \(list)"
        }
    }

    /// The solve pass owns the primary win-rate + solver-converged data.
    /// `probeAttempts` is how many extra attempts we spend on the
    /// unreachable-jelly + opening-swaps checks — kept small since these
    /// are qualitative.
    static func evaluate(level: LuauLevel,
                         solve: Solver.SolveResult,
                         probeAttempts: Int = 60) -> Report {
        var rejections: [Rejection] = []

        // Solver convergence.
        if !solve.converged {
            rejections.append(.solverDidNotConverge)
        }

        // Insensitivity: sample rate(moves) and rate(moves ± 4). If the
        // three rates cluster within 5 percentage points, the level's
        // difficulty is dominated by luck rather than the move budget.
        // Skipped in the saturation region (rate ≥ 90%): teach/easy levels
        // are SUPPOSED to stay near-certain across the window — with the
        // sand-first bot they'd all false-positive here.
        if let moves = solve.moves, moves > 4, solve.observedRate < 0.90 {
            let rateAtMoves = solve.observedRate
            let low = Evaluator.evaluate(level: level, movesBudget: moves - 4,
                                         attempts: probeAttempts).winRate
            let high = Evaluator.evaluate(level: level, movesBudget: moves + 4,
                                          attempts: probeAttempts).winRate
            let spread = max(rateAtMoves, low, high) - min(rateAtMoves, low, high)
            if spread < 0.05 {
                rejections.append(.luckDominated)
            }
        }

        // Unreachable jelly: aggregate `jellyEverCleared` across a
        // moderate sample. Any jelly cell the bot NEVER cleared across N
        // attempts is unreachable-in-practice.
        var everCleared = Set<Int>()
        for a in 0..<probeAttempts {
            let res = Evaluator.attempt(level: level,
                                        movesBudget: solve.moves ?? level.moves,
                                        attempt: UInt64(a &+ 1))
            everCleared.formUnion(res.jellyTouched)
        }
        var allJellyCells = Set<Int>()
        for i in 0..<level.jelly.count where level.jelly[i] > 0 {
            allJellyCells.insert(i)
        }
        if !allJellyCells.isSubset(of: everCleared) {
            rejections.append(.unreachableJelly)
        }

        // Opening-swap availability: at least 2 distinct legal opening
        // swaps across attempt seeds keeps the first-move choice from
        // being a coin flip.
        var openings = Set<String>()
        for a in 0..<min(probeAttempts, 20) {
            let g = LuauGame()
            g.newLevel(level, attempt: UInt64(a &+ 1))
            if let mv = LuauBot.pickMove(for: g) {
                openings.insert("\(mv.0.col),\(mv.0.row)→\(mv.1.col),\(mv.1.row)")
            }
        }
        if openings.count < 2 {
            rejections.append(.tooFewOpeningSwaps)
        }

        return Report(level: level, rejections: rejections)
    }
}
