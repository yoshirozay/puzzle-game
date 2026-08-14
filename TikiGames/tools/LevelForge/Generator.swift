import Foundation

/// Campaign-200 generator. Where v1 shipped one hardcoded mask per
/// archetype, this builds a SHAPE LIBRARY: 13 parameterized families, each
/// enumerating a small param space into distinct masks. Every shape is
/// column-convex **by construction** (masks are built from one contiguous
/// vertical run per column), then validated for cell count and horizontal
/// matchability. Jelly styles are computed from the mask itself (floor,
/// pockets, rim, band, blob, scatter) rather than hand-listed per shape.
enum Generator {

    // MARK: - shapes

    struct Shape {
        let family: String   // display archetype (picker card label)
        let mask: UInt64
        let cells: Int
        /// Gentleness tier for window pools: 0 gentle, 1 moderate, 2 harsh.
        let tier: Int
    }

    /// Build a mask from per-column runs: column c is playable in rows
    /// `top[c] ..< top[c]+height[c]`. height 0 = fully masked column.
    private static func mask(tops: [Int], heights: [Int]) -> UInt64 {
        precondition(tops.count == 7 && heights.count == 7)
        var m: UInt64 = 0
        for c in 0..<7 {
            precondition(heights[c] >= 0 && tops[c] >= 0 && tops[c] + heights[c] <= 7,
                         "bad column run c=\(c) top=\(tops[c]) h=\(heights[c])")
            for r in tops[c]..<(tops[c] + heights[c]) {
                m |= (1 as UInt64) << (r * 7 + c)
            }
        }
        return m
    }

    private static func mirrored(_ m: UInt64) -> UInt64 {
        var out: UInt64 = 0
        for r in 0..<7 {
            for c in 0..<7 where (m >> (r * 7 + c)) & 1 == 1 {
                out |= (1 as UInt64) << (r * 7 + (6 - c))
            }
        }
        return out
    }

    /// Count horizontal triples fully inside the mask — boards need enough
    /// horizontal lanes to feel like match-3, not a column puzzle. Also the
    /// openness proxy that caps color count (narrow boards starve at 6).
    static func horizontalTriples(_ m: UInt64) -> Int {
        var n = 0
        for r in 0..<7 {
            for c in 0..<5 {
                let a = (m >> (r * 7 + c)) & 1
                let b = (m >> (r * 7 + c + 1)) & 1
                let d = (m >> (r * 7 + c + 2)) & 1
                if a == 1 && b == 1 && d == 1 { n += 1 }
            }
        }
        return n
    }

    /// The full shape library — built once, deduped by mask, validated.
    static let shapes: [Shape] = buildShapes()

    private static func buildShapes() -> [Shape] {
        var out: [Shape] = []
        func add(_ family: String, _ m: UInt64, tier: Int) {
            let cells = m.nonzeroBitCount
            guard cells >= 24, cells <= 49 else { return }
            guard horizontalTriples(m) >= 6 else { return }
            guard !out.contains(where: { $0.mask == m }) else { return }
            out.append(Shape(family: family, mask: m, cells: cells, tier: tier))
        }
        func addWithMirror(_ family: String, _ m: UInt64, tier: Int) {
            add(family, m, tier: tier)
            add(family, mirrored(m), tier: tier)
        }

        // A1 FULL BOARD — the breather canvas.
        add("Full Board", mask(tops: .init(repeating: 0, count: 7),
                               heights: .init(repeating: 7, count: 7)), tier: 0)

        // A2 THE HEADLAND — top T rows full, left W columns run deep.
        for t in [2, 3] {
            for w in [3, 4] {
                var tops = [Int](repeating: 0, count: 7)
                var hs = [Int](repeating: 0, count: 7)
                for c in 0..<7 { tops[c] = 0; hs[c] = c < w ? 7 : t }
                addWithMirror("The Headland", mask(tops: tops, heights: hs), tier: 0)
            }
        }

        // A3 THE COVE — full board with a bottom slot carved out.
        for v in [1, 2] {                    // slot width
            for s in [3, 4] {                // slot starts at row s
                let positions = v == 1 ? [1, 2, 3] : [1, 2]
                for p in positions {
                    var tops = [Int](repeating: 0, count: 7)
                    var hs = [Int](repeating: 7, count: 7)
                    for c in p..<(p + v) { tops[c] = 0; hs[c] = s }
                    addWithMirror("The Cove", mask(tops: tops, heights: hs), tier: 0)
                }
            }
        }

        // A4 THE CHANNEL — full-height slot splits the board.
        for p in [2, 3, 4] {
            var hs = [Int](repeating: 7, count: 7)
            hs[p] = 0
            add("The Channel", mask(tops: .init(repeating: 0, count: 7), heights: hs), tier: 2)
        }

        // A5 THE WELL — top T rows full, a deep pocket runs to the floor.
        for t in [3, 4] {
            for (w, p) in [(3, 1), (3, 2), (3, 3), (4, 1), (4, 2)] {
                var tops = [Int](repeating: 0, count: 7)
                var hs = [Int](repeating: 0, count: 7)
                for c in 0..<7 { hs[c] = (c >= p && c < p + w) ? 7 : t }
                _ = tops
                addWithMirror("The Well", mask(tops: .init(repeating: 0, count: 7), heights: hs), tier: 1)
            }
        }

        // A6 THE SHELF — descending staircase floor.
        for hs in [[7, 7, 6, 5, 4, 3, 3], [7, 6, 5, 4, 3, 2, 2], [7, 7, 7, 6, 5, 4, 3]] {
            addWithMirror("The Shelf", mask(tops: .init(repeating: 0, count: 7), heights: hs), tier: 1)
        }

        // A7 THE PYRAMID — wide base, apex climbs at column A.
        for a in [2, 3, 4] {
            var hs = [Int](repeating: 0, count: 7)
            for c in 0..<7 { hs[c] = min(7, 3 + max(0, 4 - 2 * abs(c - a))) }
            let tops = hs.map { 7 - $0 }
            add("The Pyramid", mask(tops: tops, heights: hs), tier: 2)
            // Gentler slope variant.
            var hs2 = [Int](repeating: 0, count: 7)
            for c in 0..<7 { hs2[c] = min(7, 4 + max(0, 3 - abs(c - a))) }
            let tops2 = hs2.map { 7 - $0 }
            add("The Pyramid", mask(tops: tops2, heights: hs2), tier: 2)
        }

        // A8 THE FUNNEL — full brim, narrowing spout at column A.
        for a in [2, 3, 4] {
            var hs = [Int](repeating: 0, count: 7)
            for c in 0..<7 { hs[c] = min(7, 2 + max(0, 5 - 2 * abs(c - a))) }
            add("The Funnel", mask(tops: .init(repeating: 0, count: 7), heights: hs), tier: 2)
            var hs2 = [Int](repeating: 0, count: 7)
            for c in 0..<7 { hs2[c] = min(7, 3 + max(0, 4 - abs(c - a))) }
            add("The Funnel", mask(tops: .init(repeating: 0, count: 7), heights: hs2), tier: 2)
        }

        // A9 THE JETTY — boardwalk on top, piers run to the water.
        for t in [2, 3] {
            for piers in [[1, 3, 5], [0, 2, 4, 6], [1, 2, 4, 5], [0, 3, 6]] {
                var hs = [Int](repeating: 0, count: 7)
                for c in 0..<7 { hs[c] = piers.contains(c) ? 7 : t }
                add("The Jetty", mask(tops: .init(repeating: 0, count: 7), heights: hs), tier: 2)
            }
        }

        // A10 THE ATOLL — diamond: widest amidships, tapered ends.
        for hs in [[3, 5, 7, 7, 7, 5, 3], [2, 4, 6, 7, 6, 4, 2], [4, 6, 7, 7, 7, 6, 4]] {
            let tops = hs.map { (7 - $0) / 2 }
            add("The Atoll", mask(tops: tops, heights: hs), tier: 0)
        }

        // A11 THE DUNE — rolling floor / rolling surface.
        addWithMirror("The Dune", mask(tops: [2, 1, 0, 0, 0, 1, 2],
                                       heights: [5, 6, 7, 7, 7, 6, 5]), tier: 0)
        addWithMirror("The Dune", mask(tops: [0, 0, 0, 0, 0, 0, 0],
                                       heights: [5, 6, 7, 7, 7, 6, 5]), tier: 0)
        addWithMirror("The Dune", mask(tops: [0, 1, 2, 2, 1, 0, 0],
                                       heights: [7, 6, 5, 5, 6, 7, 7]), tier: 1)

        // A12 THE LAGOON — corner bites out of the full board.
        // Bottom bites: shorten heights; top bites: push tops down.
        do {
            // bottom-left + bottom-right, size 2
            add("The Lagoon", mask(tops: .init(repeating: 0, count: 7),
                                   heights: [5, 5, 7, 7, 7, 5, 5]), tier: 1)
            // top-left + top-right, size 2
            add("The Lagoon", mask(tops: [2, 2, 0, 0, 0, 2, 2],
                                   heights: [5, 5, 7, 7, 7, 5, 5]), tier: 1)
            // all four corners, size 2
            add("The Lagoon", mask(tops: [2, 2, 0, 0, 0, 2, 2],
                                   heights: [3, 3, 7, 7, 7, 3, 3]), tier: 1)
            // bottom bites, size 3
            add("The Lagoon", mask(tops: .init(repeating: 0, count: 7),
                                   heights: [4, 4, 4, 7, 7, 7, 7]), tier: 1)
        }

        // A13 THE CROSS — band and arm.
        for (bandStart, armStart) in [(2, 2), (2, 3), (3, 2), (1, 2)] {
            var tops = [Int](repeating: 0, count: 7)
            var hs = [Int](repeating: 0, count: 7)
            for c in 0..<7 {
                if c >= armStart && c < armStart + 3 {
                    tops[c] = 0; hs[c] = 7          // vertical arm
                } else {
                    tops[c] = bandStart; hs[c] = 3  // horizontal band
                }
            }
            add("The Cross", mask(tops: tops, heights: hs), tier: 1)
        }

        return out
    }

    // MARK: - cell metrics + jelly styles

    /// Per-cell reachability difficulty on a mask: fewer playable
    /// neighbors + deeper below the column surface = harder for cascades
    /// and deliberate digs alike.
    static func hardness(mask: UInt64) -> [(cell: (col: Int, row: Int), score: Int)] {
        func playable(_ c: Int, _ r: Int) -> Bool {
            guard (0..<7).contains(c), (0..<7).contains(r) else { return false }
            return (mask >> (r * 7 + c)) & 1 == 1
        }
        var colTop = [Int](repeating: 7, count: 7)
        for c in 0..<7 {
            for r in 0..<7 where playable(c, r) { colTop[c] = r; break }
        }
        var result: [(cell: (col: Int, row: Int), score: Int)] = []
        for r in 0..<7 {
            for c in 0..<7 where playable(c, r) {
                var neighbors = 0
                for (dc, dr) in [(-1, 0), (1, 0), (0, -1), (0, 1)] where playable(c + dc, r + dr) {
                    neighbors += 1
                }
                var score = (4 - neighbors) * 2 + (r - colTop[c])
                if !playable(c - 1, r) && !playable(c + 1, r) { score += 3 }  // 1-wide pier/spout
                result.append(((c, r), score))
            }
        }
        return result
    }

    /// Cells eligible to carry jelly. Excludes depth ≥ 2 cells in 1-wide
    /// column runs (pier/spout interiors): those clear only via a vertical
    /// triple landing in that exact column — near-impossible at 5–6 colors,
    /// which reads as unfair, not hard. Difficulty comes from quantity,
    /// doubles, colors, and budget tightness instead.
    static func jellyEligible(mask: UInt64) -> Set<Int> {
        func playable(_ c: Int, _ r: Int) -> Bool {
            guard (0..<7).contains(c), (0..<7).contains(r) else { return false }
            return (mask >> (r * 7 + c)) & 1 == 1
        }
        var colTop = [Int](repeating: 7, count: 7)
        for c in 0..<7 {
            for r in 0..<7 where playable(c, r) { colTop[c] = r; break }
        }
        var out = Set<Int>()
        for r in 0..<7 {
            for c in 0..<7 where playable(c, r) {
                let oneWide = !playable(c - 1, r) && !playable(c + 1, r)
                if oneWide, r - colTop[c] >= 2 { continue }
                out.insert(r * 7 + c)
            }
        }
        return out
    }

    enum JellyStyle: String, CaseIterable {
        case floor      // deepest cell of each column run
        case pockets    // low-neighbor cells
        case rim        // boundary cells
        case band       // contiguous row segment
        case blob       // BFS cluster from a seed
        case scatter    // anywhere, hardness-weighted by band
    }

    /// Place `count` jelly cells on the mask in the given style; `bias`
    /// > 0 pulls toward hard cells, < 0 toward easy ones. Deterministic
    /// under `rng`. Returns row-major cell indices.
    static func placeJelly(mask: UInt64, style: JellyStyle, count: Int,
                           bias: Int, rng: inout SplitMix) -> Set<Int> {
        let eligible = jellyEligible(mask: mask)
        let scored = hardness(mask: mask).filter { eligible.contains($0.cell.row * 7 + $0.cell.col) }
        func playableIdx(_ cell: (col: Int, row: Int)) -> Int { cell.row * 7 + cell.col }

        var pool: [Int]
        switch style {
        case .floor:
            var floors: [Int] = []
            for c in 0..<7 {
                let colCells = scored.filter { $0.cell.col == c }
                if let deepest = colCells.max(by: { $0.cell.row < $1.cell.row }) {
                    floors.append(playableIdx(deepest.cell))
                }
            }
            pool = floors
        case .pockets:
            pool = scored.sorted { $0.score > $1.score }.prefix(max(count + 4, 8)).map { playableIdx($0.cell) }
        case .rim:
            pool = scored.filter { $0.score >= 3 }.map { playableIdx($0.cell) }
        case .band:
            // Pick the widest playable row segment at a rng-chosen row.
            var best: [Int] = []
            var rows = Array(0..<7)
            // deterministic shuffle
            for i in stride(from: rows.count - 1, to: 0, by: -1) {
                rows.swapAt(i, Int(rng.next() % UInt64(i + 1)))
            }
            for r in rows {
                var run: [Int] = []
                var longest: [Int] = []
                for c in 0..<7 {
                    if (mask >> (r * 7 + c)) & 1 == 1, eligible.contains(r * 7 + c) { run.append(r * 7 + c) }
                    else { if run.count > longest.count { longest = run }; run = [] }
                }
                if run.count > longest.count { longest = run }
                if longest.count >= min(count, 3) { best = longest; break }
            }
            pool = best.isEmpty ? scored.map { playableIdx($0.cell) } : best
        case .blob:
            let seeds = scored.sorted { bias > 0 ? $0.score > $1.score : $0.score < $1.score }
            let seed = seeds[Int(rng.next() % UInt64(max(1, min(6, seeds.count))))].cell
            var visited: Set<Int> = [playableIdx(seed)]
            var frontier = [seed]
            while visited.count < count, !frontier.isEmpty {
                let cur = frontier.removeFirst()
                for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let c = cur.col + dc, r = cur.row + dr
                    guard (0..<7).contains(c), (0..<7).contains(r),
                          (mask >> (r * 7 + c)) & 1 == 1,
                          eligible.contains(r * 7 + c),
                          !visited.contains(r * 7 + c) else { continue }
                    visited.insert(r * 7 + c)
                    frontier.append((c, r))
                    if visited.count >= count { break }
                }
            }
            return visited
        case .scatter:
            let ranked = scored.sorted { bias > 0 ? $0.score > $1.score : $0.score < $1.score }
            pool = ranked.prefix(max(count + 6, 12)).map { playableIdx($0.cell) }
        }

        var picked = Set<Int>()
        var candidates = pool
        while picked.count < count, !candidates.isEmpty {
            let i = Int(rng.next() % UInt64(candidates.count))
            picked.insert(candidates.remove(at: i))
        }
        // Style pools can be smaller than big-sand counts (a band is one
        // row, floors are one-per-column) — top up from the remaining
        // eligible cells, bias-ordered, so the requested workload ships.
        if picked.count < count {
            var rest = scored
                .map { $0.cell.row * 7 + $0.cell.col }
                .filter { !picked.contains($0) }
            rest.sort()
            while picked.count < count, !rest.isEmpty {
                let i = Int(rng.next() % UInt64(rest.count))
                picked.insert(rest.remove(at: i))
            }
        }
        return picked
    }

    /// Assemble a candidate level: place jelly by style/count, promote the
    /// hardest `doubles` cells to two layers.
    static func candidate(id: Int, shape: Shape, style: JellyStyle,
                          jellyCount: Int, doubles: Int, colors: Int,
                          bias: Int, seed: UInt64) -> LuauLevel {
        var rng = SplitMix(seed: seed)
        let cappedCount = max(3, min(jellyCount, Int(Double(jellyEligible(mask: shape.mask).count) * 0.75)))
        let cells = placeJelly(mask: shape.mask, style: style,
                               count: cappedCount, bias: bias, rng: &rng)
        var jelly = [UInt8](repeating: 0, count: 49)
        for i in cells { jelly[i] = 1 }
        if doubles > 0 {
            let byHardness = hardness(mask: shape.mask)
                .filter { cells.contains($0.cell.row * 7 + $0.cell.col) }
                .sorted { $0.score > $1.score }
            for h in byHardness.prefix(doubles) {
                jelly[h.cell.row * 7 + h.cell.col] = 2
            }
        }
        return LuauLevel(id: id, mask: shape.mask, jelly: jelly, colors: colors,
                         moves: 20, movesHard: 15,   // placeholders — solver sets
                         seed: seed, archetype: shape.family)
    }

    /// Standalone SplitMix64 — generation stays reproducible independently
    /// of the engine's per-game stream.
    struct SplitMix {
        var state: UInt64
        init(seed: UInt64) { self.state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}
