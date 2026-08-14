import Foundation

/// One passage of the Navigator campaign. The board is `grid`×`grid` sky
/// cells; `targets` stars glow for `peekMs`, fade, and must be charted from
/// memory. Budgets are per-attempt: `mistakes` wrong taps end the attempt
/// (retry free, attempt-salted), `peeks` re-show the remaining stars.
///
/// The current campaign locks `scatter`/`waves`/`decoys` to defaults — the
/// pattern generator is uniform random and difficulty rides on just star
/// count and peek duration (the two-dial ramp Carson landed on 2026-07-15).
/// The struct fields survive because the engine, view, and save schema all
/// read them; they're the levers a future expert mode or one-off scripted
/// passage would reach for.
struct NavigatorLevel: Codable, Identifiable, Equatable {
    let id: Int              // 1-based campaign order
    let grid: Int            // 4...8 cells per side (was 3...6 pre-2026-07-15)
    let targets: Int         // stars to chart
    let scatter: Double      // reserved — pattern generator ignores it today
    let waves: Int           // reveal phases, 1...3 (locked to 1 in the ramp)
    let decoys: Int          // false flashes during the peek (locked to 0)
    let peekMs: Int          // exposure per wave
    let peeks: Int           // re-peek budget
    let mistakes: Int        // wrong-tap budget (3rd wrong of 3 fails)
    let seed: UInt64         // base RNG seed (attempt # salts it)
    let family: String       // constellation family (picker card copy)
}

enum NavigatorLevels {
    /// Invented Pacific-motif constellation families — trademark-safe, no
    /// real star lore (Stage 0 cultural-care note). Card copy only; the
    /// generator has been uniform-random since 2026-07-12 (Carson's L30
    /// field call — "just a random distribution of tiles").
    static let families = [
        "The Canoe", "The Sail", "The Frigate Bird", "The Honu",
        "The Paddle", "The Hibiscus", "The Swell", "The Reef",
        "The Current", "The Crossing",
    ]

    /// One difficulty band = one board size. Star count is the campaign's
    /// only dial that measurably changes how hard a passage is: measured
    /// 2026-07-25, ρ(targets, difficulty) = 0.993 against ρ(grid,
    /// difficulty) = 0.791, and the same star count on a different board
    /// moves clear probability by 0.011 while the same board with a
    /// different star count moves it by 0.327. Board size is escalation the
    /// player SEES; star count is difficulty the player FEELS.
    ///
    /// So the ramp is written out as explicit star plateaus that never step
    /// down — not within a band and not across one — and the board grows
    /// underneath them purely to keep star density in a readable range
    /// (every passage stays under ~31 % of cells filled). Peek time is
    /// still FIXED per band (Simon-family model, one exposure window per
    /// tier), so the peek/star ratio tightens as stars climb inside a band
    /// and resets generously when the board grows: that reset is the
    /// graduation beat, and it now costs the player nothing in progress.
    ///
    /// This replaced a starMin…starMax-per-band ramp that reset the star
    /// count at every band boundary — 9→6, 11→7, 13→8. Because targets is
    /// the only real dial, those resets were the difficulty curve stepping
    /// backwards three times, hardest passage to easiest in a single tap.
    private struct Band {
        let boardSize: Int
        let peek: Int                            // fixed exposure per band, in ms
        /// (star count, consecutive passages at it), in ascending order.
        let plateaus: [(stars: Int, count: Int)]
        var count: Int { plateaus.reduce(0) { $0 + $1.count } }
    }

    /// Peek times are calibrated to the band's ceiling star count at
    /// ~270–320 ms per item (Carson's anchor: 9 stars at 2600 ms = 289
    /// ms/star = "rewarding"). Later bands compress the ratio at their
    /// ceiling for a finale-feel; the tightest in the campaign is the last
    /// band's 13 stars over 3500 ms = 269 ms/star.
    ///
    /// The opening is deliberately BRIEF — one passage each at 3…8 stars.
    /// Measured 2026-07-25: every star count at or below 8 clears at p ≥ 0.99
    /// for a Cowan-4 player, because the free re-peek buys a second encoding
    /// and 4+4 covers an 8-star board. Those passages cannot be lost, so
    /// spending 27 of 60 on them (the previous ramp) meant a player who fell
    /// at their ceiling replayed ~4 minutes of guaranteed clears to get back
    /// to a passage that could go either way. Six is enough to teach the
    /// verb; the campaign's mass now sits at 9…11 stars, where the outcome
    /// is actually in doubt.
    ///
    /// Passage ranges: 1…3 · 4…6 · 7…20 · 21…36 · 37…60.
    /// Star ramp end to end: 3 4 5 · 6 7 8 · 8×4 9×10 · 9×4 10×12 ·
    /// 11×14 12×8 13 13.
    private static let bands: [Band] = [
        Band(boardSize: 4, peek: 1600, plateaus: [(3, 1), (4, 1), (5, 1)]),
        Band(boardSize: 5, peek: 2200, plateaus: [(6, 1), (7, 1), (8, 1)]),
        Band(boardSize: 6, peek: 2700, plateaus: [(8, 4), (9, 10)]),
        Band(boardSize: 7, peek: 3100, plateaus: [(9, 4), (10, 12)]),
        Band(boardSize: 8, peek: 3500, plateaus: [(11, 14), (12, 8), (13, 2)]),
    ]

    /// 60 passages across 5 bands — deterministic from id so the campaign is
    /// stable across launches (per-attempt star rolls stay salted).
    static let all: [NavigatorLevel] = (1...bands.reduce(0) { $0 + $1.count }).map { generated(id: $0) }

    static func level(id: Int) -> NavigatorLevel? {
        guard id >= 1, id <= all.count else { return nil }
        return all[id - 1]
    }

    /// First passage of the band containing `id`. This is the floor a defeat
    /// rewind drops to (`NavigatorGame.rewindAfterDefeat`): a player never
    /// replays a board size they have already graduated from, so the setback
    /// costs passages without costing the tier they earned.
    static func bandStart(for id: Int) -> Int {
        var start = 1
        for band in bands {
            if id < start + band.count { return start }
            start += band.count
        }
        // Past the campaign — clamp to the last band's opening passage.
        return start - (bands.last?.count ?? 0)
    }

    /// Resolves a passage id to (band, position-in-band). Position is
    /// 0-based; band 0 is the 4×4 opener.
    private static func locate(id: Int) -> (band: Band, offset: Int) {
        var remaining = id - 1
        for band in bands {
            if remaining < band.count { return (band, remaining) }
            remaining -= band.count
        }
        // Past the last band — clamp to the last passage of the last band so
        // out-of-range ids don't crash (level(id:) already guards, but this
        // keeps generated() total for safety).
        let last = bands.last!
        return (last, last.count - 1)
    }

    private static func generated(id: Int) -> NavigatorLevel {
        let (band, offset) = locate(id: id)

        // Stars: walk the band's plateaus. Offsets past the last plateau
        // can't happen (locate clamps into range) but the fallthrough leaves
        // `targets` on the band ceiling, which keeps this function total.
        var remaining = offset
        var targets = band.plateaus.last?.stars ?? 0
        for plateau in band.plateaus {
            if remaining < plateau.count { targets = plateau.stars; break }
            remaining -= plateau.count
        }

        return NavigatorLevel(
            id: id,
            grid: band.boardSize,
            targets: targets,
            scatter: 0,        // pattern generator ignores it
            waves: 1,          // single reveal
            decoys: 0,         // no false flashes
            peekMs: band.peek, // fixed per band — stars carry within-band difficulty
            peeks: 1,          // one re-peek per attempt
            mistakes: 3,       // 3 wrong taps = fail
            seed: 0x51A9_0000 &+ UInt64(id) &* 0x9E37_79B9,
            family: families[(id * 3) % families.count]
        )
    }
}
