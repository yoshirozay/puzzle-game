import Foundation

/// A stronger Luau policy than `LuauBot`, for measuring the campaign's real
/// skill ceiling and for calibrating move budgets against competent play
/// rather than against the floor.
///
/// **This lives in LevelForge, not the app.** `LuauBot` is the shipped
/// autoplay policy AND the policy every existing move budget was solved
/// against, so it must not change: touching it would silently invalidate all
/// 200 budgets. This is a second opinion that sits beside it.
///
/// Where `LuauBot` is deliberately weak (its own comment: "cat swaps are
/// deliberately not played — humans use cats, so leaving them out biases
/// solved budgets slightly generous"), this policy plays the game the way a
/// competent human does:
///
///   1. **It plays cat swaps**, and prices them exactly. `previewSwapFires`
///      reports the precise cell set a cat swap or a special×special combo
///      would clear without mutating anything, so the sand it would remove is
///      known rather than guessed.
///   2. **It plays 2×2 squares.** `LuauBot.scoreSwap` returns 0 for them, so
///      the greedy policy only ever plays a square when `findLegalSwap`'s
///      fallback forces it. Squares are a quarter of the Matchington rule set.
///   3. **It counts sand LAYERS, not sand cells.** A two-layer cell needs
///      hitting twice, so the objective is layers removed, and everything
///      else — specials, position, setup — is priced in units of that.
///   4. **It values a special by what it will kill**, not by existing.
///   5. **It breaks ties downward.** Clearing low collapses more of the board,
///      which is where cascades come from.
///
/// Fully deterministic given the engine's RNG state: every enumeration is in
/// row-major order and ties resolve to the first candidate found, so
/// `(level.seed, attempt)` still reproduces a run exactly.
enum LuauStrongBot {

    // Everything is priced in sand-layers-equivalent, x100 for integer math.
    private static let layer = 100          // one jelly layer removed
    private static let spawnCatValue = 34   // a cat is worth ~1/3 of a layer-clearing move later
    private static let spawnTorchValue = 16
    private static let piecePicked = 1      // faint preference for bigger clears
    private static let lowRowBonus = 2      // per row down, tie-break toward collapse
    private static let proximityMax = 8     // shaping when no sand is reachable at all

    /// Highest-value legal move, or nil when the board is terminal.
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
        for i in 0..<jelly.count where jelly[i] > 0 { sandCells.append((i % n, i / n)) }

        var best: (score: Int, move: ((col: Int, row: Int), (col: Int, row: Int)))?

        for r in 0..<n {
            for c in 0..<n where kind[r][c] != -9 {
                for (dc, dr) in [(1, 0), (0, 1)] {
                    let c2 = c + dc, r2 = r + dr
                    guard c2 < n, r2 < n, kind[r2][c2] != -9 else { continue }
                    let a = (col: c, row: r), b = (col: c2, row: r2)

                    // Specials and combos first: the engine will tell us the
                    // exact cell set, so no estimation is needed.
                    let fires = game.previewSwapFires(a, b)
                    let s: Int
                    if !fires.isEmpty {
                        s = scoreFires(fires, jelly: jelly)
                    } else {
                        s = scorePlainSwap(kind, special: special, jelly: jelly,
                                           a: a, b: b, sandCells: sandCells)
                    }
                    if s > 0, s > (best?.score ?? 0) { best = (s, (a, b)) }
                }
            }
        }
        if let best { return best.move }
        // Nothing scored: fall back to the engine's own legality scan, then to
        // any special swap, mirroring LuauBot's tail so a cat-only board still
        // finds its move instead of stalling.
        if let plain = game.findLegalSwap() { return plain }
        for p in game.pieces where p.special != .none {
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                guard let nb = game.piece(at: p.col + dc, p.row + dr) else { continue }
                if p.special == .cat || nb.special != .none {
                    return ((p.col, p.row), (nb.col, nb.row))
                }
            }
        }
        return nil
    }

    /// Exact value of a detonation: every reported cell is going to clear, so
    /// its jelly layer is banked for certain.
    private static func scoreFires(_ fires: [LuauGame.SpecialFire], jelly: [UInt8]) -> Int {
        let n = LuauGame.size
        var cells = Set<Int>()
        for fire in fires {
            for cell in fire.cells { cells.insert(cell.row * n + cell.col) }
        }
        var pts = 0
        for i in cells {
            if jelly[i] > 0 { pts += layer }
            pts += piecePicked
        }
        return pts
    }

    /// Value of a swap that produces an ordinary match. Mirrors the engine's
    /// accept rules — 3+ runs through either swapped cell, plus 2×2 squares
    /// containing one — and adds the lane a matched torch would fire.
    private static func scorePlainSwap(_ grid: [[Int]], special: [[LuauGame.Special]],
                                       jelly: [UInt8],
                                       a: (col: Int, row: Int), b: (col: Int, row: Int),
                                       sandCells: [(col: Int, row: Int)]) -> Int {
        let n = LuauGame.size
        var g = grid
        let t = g[a.row][a.col]; g[a.row][a.col] = g[b.row][b.col]; g[b.row][b.col] = t
        var sp = special
        let st = sp[a.row][a.col]; sp[a.row][a.col] = sp[b.row][b.col]; sp[b.row][b.col] = st

        var matched = Set<Int>()
        var bestRun = 0

        func runs(through cell: (col: Int, row: Int)) {
            let k = g[cell.row][cell.col]
            guard k >= 0 else { return }
            var c0 = cell.col, c1 = cell.col
            while c0 > 0, g[cell.row][c0 - 1] == k { c0 -= 1 }
            while c1 + 1 < n, g[cell.row][c1 + 1] == k { c1 += 1 }
            if c1 - c0 + 1 >= 3 {
                bestRun = max(bestRun, c1 - c0 + 1)
                for c in c0...c1 { matched.insert(cell.row * n + c) }
            }
            var r0 = cell.row, r1 = cell.row
            while r0 > 0, g[r0 - 1][cell.col] == k { r0 -= 1 }
            while r1 + 1 < n, g[r1 + 1][cell.col] == k { r1 += 1 }
            if r1 - r0 + 1 >= 3 {
                bestRun = max(bestRun, r1 - r0 + 1)
                for r in r0...r1 { matched.insert(r * n + cell.col) }
            }
        }

        /// 2×2 squares touching a swapped cell — the quarter of the rule set
        /// the greedy policy scores at zero and therefore never chooses.
        func squares(through cell: (col: Int, row: Int)) {
            let k = g[cell.row][cell.col]
            guard k >= 0 else { return }
            for dr in -1...0 {
                for dc in -1...0 {
                    let r = cell.row + dr, c = cell.col + dc
                    guard r >= 0, c >= 0, r + 1 < n, c + 1 < n else { continue }
                    if g[r][c] == k, g[r][c + 1] == k, g[r + 1][c] == k, g[r + 1][c + 1] == k {
                        for (cc, rr) in [(c, r), (c + 1, r), (c, r + 1), (c + 1, r + 1)] {
                            matched.insert(rr * n + cc)
                        }
                    }
                }
            }
        }

        runs(through: a); runs(through: b)
        squares(through: a); squares(through: b)
        guard !matched.isEmpty else { return 0 }

        var pts = 0
        var sandHits = 0
        var lane = Set<Int>()
        for i in matched {
            // Positional preference is a TIE-BREAK among sand-clearing moves
            // only. Applied to every match it reached +48, which swamped the
            // max +8 of the dig-toward-sand shaping below — so on a sparse-sand
            // board, where most matches touch nothing, the bot would match
            // idly at the bottom while the sand sat untouched at the top. That
            // cost up to 19pp on loose levels (The Headland worst).
            if jelly[i] > 0 { pts += layer; sandHits += 1; pts += (i / n) * lowRowBonus }
            pts += piecePicked
            switch sp[i / n][i % n] {
            case .lineH:
                let row = i / n
                for c in 0..<n where g[row][c] != -9 { lane.insert(row * n + c) }
            case .lineV:
                let col = i % n
                for r in 0..<n where g[r][col] != -9 { lane.insert(r * n + col) }
            default: break
            }
        }
        for i in lane.subtracting(matched) {
            if jelly[i] > 0 { pts += layer; sandHits += 1 }
            pts += piecePicked
        }

        // A spawn is only worth what it will eventually kill, so it is priced
        // well below an actual layer — never trade a layer for a torch.
        if bestRun >= 5 { pts += spawnCatValue }
        else if bestRun == 4 { pts += spawnTorchValue }

        // Nothing reachable touches sand: dig toward it rather than matching
        // idly in a clean corner.
        if sandHits == 0, !sandCells.isEmpty {
            var dist = Int.max
            for s in sandCells {
                dist = min(dist, abs(s.col - a.col) + abs(s.row - a.row))
                dist = min(dist, abs(s.col - b.col) + abs(s.row - b.row))
            }
            // Weighted to dominate every other non-sand term: when nothing on
            // the board can be cleared for sand, the ONLY thing that matters
            // is getting closer to sand for next turn.
            pts += max(0, proximityMax - dist) * 6
        }
        return pts
    }

    @discardableResult
    static func playOne(in game: LuauGame) -> ((col: Int, row: Int), (col: Int, row: Int))? {
        guard let move = pickMove(for: game) else { return nil }
        _ = game.attemptSwap(move.0, move.1)
        while game.resolveStep() {}
        return move
    }

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
