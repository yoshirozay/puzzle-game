import Foundation

/// Sand-first Luau policy, engine-side and deterministic given the engine's
/// RNG state. This IS the LuauView autoplay policy AND the LevelForge
/// calibration player (single source of truth): budgets are only honest if
/// the calibrating bot plays the objective the way a competent human does —
/// clear sand first, take value otherwise.
///
/// Policy (no lookahead beyond the immediate resolve round):
///   1. Enumerate every legal plain-kind swap (same legality scan as
///      `findLegalSwap`; cat swaps are deliberately not played — humans use
///      cats, so leaving them out biases solved budgets slightly generous
///      rather than slightly cruel. 2x2-square swaps score 0 here for the
///      same reason: the bot doesn't chase them, and the findLegalSwap
///      fallback below still plays one when it's the board's only move).
///   2. Statically score the swap's first clear: sand hit ≫ torch-lane sand
///      ≫ special spawn ≫ match size; swaps nearer remaining sand break
///      score-zero ties.
///   3. Pick the best; equal scores resolve first-in-row-major, so the
///      policy is fully deterministic.
enum LuauBot {

    // Scoring weights — sand dominates everything else by design.
    private static let sandHit = 24       // matched cell that carries jelly
    private static let laneSandHit = 18   // jelly cleared via triggered torch lane
    private static let spawnCat = 10      // 5-run: cat spawn
    private static let spawnTorch = 6     // 4-run: torch spawn
    private static let proximityMax = 6   // shaping when no sand is reachable
    // CARGO IS AN OBJECTIVE, so it is weighted like one. Without these the bot
    // scored a coconut level exactly as if the coconut were not there: it
    // cleared the sand greedily and then flailed until delivery happened by
    // accident. Measured, that blindness cost L48 twenty-six extra moves to
    // restore its original win rate — a number that described the policy, not
    // the level, and would have shipped budgets far too generous for a human who
    // simply clears underneath the thing.
    private static let cargoDrop = 26     // cleared cell beneath cargo: it descends a row
    private static let cargoDeliver = 60  // the clear that lands it on the shore

    /// The pick — highest-scoring legal swap. Shared with `LuauView.autoplay()`
    /// so screenshots and harness stats can never drift on move choice.
    /// Returns nil when the board is terminal or no legal swap exists.
    static func pickMove(for game: LuauGame) -> ((col: Int, row: Int), (col: Int, row: Int))? {
        guard !game.isOver else { return nil }
        let n = LuauGame.size

        var kind = [[Int]](repeating: [Int](repeating: -9, count: n), count: n)
        var special = [[LuauGame.Special]](repeating: [LuauGame.Special](repeating: .none, count: n), count: n)
        for p in game.pieces {
            kind[p.row][p.col] = p.kind
            special[p.row][p.col] = p.special
        }
        let jelly = game.jelly
        var sandCells: [(col: Int, row: Int)] = []
        for i in 0..<jelly.count where jelly[i] > 0 {
            sandCells.append((i % n, i / n))
        }
        var cargoCells: [(col: Int, row: Int)] = []
        for r in 0..<n {
            for c in 0..<n where kind[r][c] == LuauGame.ingredientKind {
                cargoCells.append((c, r))
            }
        }

        var best: (score: Int, move: ((col: Int, row: Int), (col: Int, row: Int)))?
        for r in 0..<n {
            for c in 0..<n where kind[r][c] >= 0 {
                for (dc, dr) in [(1, 0), (0, 1)] {
                    let c2 = c + dc, r2 = r + dr
                    guard c2 < n, r2 < n, kind[r2][c2] >= 0 else { continue }
                    var g = kind
                    let t = g[r][c]; g[r][c] = g[r2][c2]; g[r2][c2] = t
                    // Specials move with their pieces: score against the
                    // POST-swap special grid, or a torch relocated by this
                    // very swap would credit its lane at the wrong cell.
                    var sp = special
                    let st = sp[r][c]; sp[r][c] = sp[r2][c2]; sp[r2][c2] = st
                    let s = scoreSwap(g, special: sp, jelly: jelly,
                                      a: (c, r), b: (c2, r2), sandCells: sandCells,
                                      cargoCells: cargoCells)
                    if s > 0, s > (best?.score ?? 0) {
                        best = (s, ((c, r), (c2, r2)))
                    }
                }
            }
        }
        if let best { return best.move }
        // No plain-kind swap matches — fall back to the engine's first-legal
        // scan, then to special swaps (a cat swaps with ANY adjacent piece;
        // two adjacent specials always combo). findLegalSwap only simulates
        // plain-kind swaps, so without the special pass the bot stalls on a
        // board whose only legal move is a cat — the engine (hasLegalSwap)
        // rightly never shuffles such a board.
        if let plain = game.findLegalSwap() { return plain }
        for p in game.pieces where p.special != .none {
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                guard let neighbor = game.piece(at: p.col + dc, p.row + dr) else { continue }
                // Mirrors the engine's accept rule: a cat swaps with any piece
                // EXCEPT cargo, which attemptSwap refuses. Proposing that pair
                // would have the bot re-offer a rejected move forever. Cargo
                // only exists on levels that declare it, so this clause is
                // unreachable on all 200 shipped levels and cannot disturb the
                // budgets solved against this policy.
                if neighbor.special != .none
                    || (p.special == .cat && !LuauGame.isIngredient(neighbor)) {
                    return ((p.col, p.row), (neighbor.col, neighbor.row))
                }
            }
        }
        return nil
    }

    /// Static score of one swap's immediate clear on the post-swap grid.
    /// Returns 0 when the swap creates no match (illegal).
    private static func scoreSwap(_ g: [[Int]], special: [[LuauGame.Special]],
                                  jelly: [UInt8],
                                  a: (col: Int, row: Int), b: (col: Int, row: Int),
                                  sandCells: [(col: Int, row: Int)],
                                  cargoCells: [(col: Int, row: Int)] = []) -> Int {
        let n = LuauGame.size
        var matched = Set<Int>()
        var bestRun = 0

        // Runs through a swapped cell only — on a stable board every new
        // match passes through one of the two swapped cells.
        // Routed through the ENGINE's own run rule rather than walking outward
        // by hand. Cargo is transparent to runs, so a bot with its own scanner
        // would never see — and therefore never play — a match through a
        // coconut, while the engine happily resolved one. On a cargo-free line
        // `lineRuns` finds exactly the maximal same-kind runs this used to walk
        // to, which is why the 200 shipped budgets do not move.
        func collectRuns(through cell: (col: Int, row: Int)) {
            guard g[cell.row][cell.col] >= 0 else { return }
            for run in LuauGame.lineRuns(g[cell.row]) where run.idx.contains(cell.col) {
                bestRun = max(bestRun, run.idx.count)
                for c in run.idx { matched.insert(cell.row * n + c) }
            }
            let column = (0..<n).map { g[$0][cell.col] }
            for run in LuauGame.lineRuns(column) where run.idx.contains(cell.row) {
                bestRun = max(bestRun, run.idx.count)
                for r in run.idx { matched.insert(r * n + cell.col) }
            }
        }
        collectRuns(through: a)
        collectRuns(through: b)
        guard !matched.isEmpty else { return 0 }

        var pts = matched.count
        var laneCells = Set<Int>()
        for i in matched {
            if jelly[i] > 0 { pts += sandHit }
            // A matched torch fires its lane — count the lane's sand.
            switch special[i / n][i % n] {
            case .lineH:
                let row = i / n
                for c in 0..<n where g[row][c] >= -1 { laneCells.insert(row * n + c) }
            case .lineV:
                let col = i % n
                for r in 0..<n where g[r][col] >= -1 { laneCells.insert(r * n + col) }
            default:
                break
            }
        }
        for i in laneCells.subtracting(matched) {
            pts += 1
            if jelly[i] > 0 { pts += laneSandHit }
        }
        if bestRun >= 5 { pts += spawnCat }
        else if bestRun == 4 { pts += spawnTorch }

        // CARGO PROGRESS. A coconut descends one row per cleared cell beneath it
        // in its own column, so that is exactly what gets paid for — and the
        // clear that carries it all the way to the shore pays a bonus, since
        // delivery is the objective and a near-miss is not.
        if !cargoCells.isEmpty {
            let cleared = matched.union(laneCells)
            for cargo in cargoCells {
                let below = cleared.filter { $0 % n == cargo.col && $0 / n > cargo.row }.count
                guard below > 0 else { continue }
                pts += below * cargoDrop
                if cargo.row + below >= n - 1 { pts += cargoDeliver }
            }
        }

        // No sand in reach this turn — nudge toward the remaining sand so
        // the bot digs in the right region instead of matching far corners.
        // Cargo joins the same tie-break as sand: with nothing scoring this
        // turn, dig in the region that matters instead of a far corner.
        let targets = sandCells + cargoCells.map { (col: $0.col, row: min(n - 1, $0.row + 1)) }
        if !targets.isEmpty, matched.allSatisfy({ jelly[$0] == 0 }), laneCells.isEmpty {
            var dist = Int.max
            for s in targets {
                dist = min(dist, abs(s.col - a.col) + abs(s.row - a.row))
                dist = min(dist, abs(s.col - b.col) + abs(s.row - b.row))
            }
            pts += max(0, proximityMax - dist)
        }
        return pts
    }

    /// Plays one move in place, then drives `resolveStep()` to fixed point
    /// synchronously (no animation delays). Returns the swap made or nil
    /// when the game is terminal.
    @discardableResult
    static func playOne(in game: LuauGame) -> ((col: Int, row: Int), (col: Int, row: Int))? {
        guard let move = pickMove(for: game) else { return nil }
        _ = game.attemptSwap(move.0, move.1)
        while game.resolveStep() {}
        return move
    }

    /// Plays until the game is over or `maxTurns` is exhausted. Returns the
    /// number of turns actually played. The cap defends against stall loops
    /// (findLegalSwap forcing shuffles that never end).
    @discardableResult
    static func playToEnd(in game: LuauGame, maxTurns: Int = 500) -> Int {
        var turns = 0
        while !game.isOver, turns < maxTurns {
            guard playOne(in: game) != nil else { break }
            turns += 1
        }
        return turns
    }
}
