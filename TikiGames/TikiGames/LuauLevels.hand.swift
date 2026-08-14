import Foundation

/// The teaching arc — L1 through L12, transcribed verbatim from
/// `LUAU_LEVELS_PLAN.md` Appendix B (machine-validated 2026-07-10). Each
/// level's mask + jelly comes from the ASCII grid; `colors` is per the
/// Appendix header; `archetype` names the shape family; `seed` is a
/// per-level constant so runs are reproducible; `moves`/`movesHard` are
/// placeholders until LevelForge solves them (see `tools/LevelForge` +
/// the `campaign-teach-moves` command).
///
/// L1 also serves as the FTUE — Stage D wires the existing coach rounds
/// (`LuauGame.tutorialRounds`) to a board that includes L1's jelly at
/// (2,3)/(3,3)/(4,3), so the scripted match at row 3 also clears the sand.
/// The lookup surface is `LuauLevels.handAuthored`; `LuauLevels.all` prefers
/// them over the debug fixtures when built for release.
extension LuauLevels {

    static let handAuthored: [LuauLevel] = [
        L1, L2, L3, L4, packedSandLesson, L5, L6, L7, L8, L9, L10, L11, L12,
    ]

    // MARK: LESSON — "Packed sand" · sits between Night 4 and Night 5
    //
    // Night 5 is the first level in the whole campaign containing two-layer
    // sand, and until now nothing taught it: no coach round paints a double
    // (TutorialSeed.jelly is one layer per listed cell, by construction), so it
    // arrived unannounced and read as a bug — you clear the cell and the sand
    // is still there.
    //
    // Id 901 is deliberately outside the 1...200 campaign range and clear of the
    // 1001+ debug fixtures. It is placed by POSITION, so it does not renumber
    // anything: the level after it is still Night 5 to the player.
    //
    // The board is tiny and the whole point is the contrast — a row of single
    // sand beside a row of double, so "packed twice" is legible by comparison
    // the first time it is ever seen. 99 moves means it cannot be failed; the
    // engine also refuses to latch a loss on a lesson.
    /// Introduces CARGO: no sand, so delivery is the only objective, and the
    /// coconut starts one row above the shore so it leaves almost immediately.
    ///
    /// FULL WIDTH, MEASURED, NOT GUESSED. The cell directly beneath cargo can
    /// only be cleared by a HORIZONTAL match — a vertical run through it would
    /// have to pass through the coconut, which matches nothing. So bottom-row
    /// width, not depth, decides how hard delivery is. A narrow 3-wide board
    /// (the first draft, which looked more focused) needs all three bottom cells
    /// to agree and the greedy bot delivered it in only 59 of 120 runs even with
    /// 99 moves — a lesson you can get stuck in. Full width delivers 120/120,
    /// median 7 moves, worst case 38. Re-measure with tools/ if this mask moves.
    static let cargoLesson: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######", "#######", "#######", "#######", "#######", "#######", "#######",
        ])
        return LuauLevel(id: 902, mask: m, jelly: j, colors: 4,
                         moves: 99, movesHard: 99,
                         // SEED IS LOAD-BEARING, not decorative. Searched for a
                         // fresh board whose ONLY one-swap delivery sits directly
                         // beneath the coconut — swapping (2,6) with (3,6) clears
                         // the cell under it, gravity drops it to the shore and it
                         // exits. Onboarding is one swipe. `fillFreshBoard` is
                         // seeded-random and refuses to plant a ready-made match,
                         // so a scripted layout has to come from the seed.
                         // Pinned by cargoLessonExitsInASingleSwap.
                         seed: 0x5C82_43FB_0853_5DE9,
                         archetype: "Cargo Lesson",
                         ingredients: [38],   // col 3, row 5 — one above the shore
                         teaches: "ingredients")
    }()

    /// THE CORNER. The bomb is the only special the game never teaches: the
    /// scripted coach covers square → torch → cat, and an L or T is the least
    /// discoverable shape on the board — players make one by accident long
    /// before they know it is worth aiming for.
    ///
    /// SEED IS LOAD-BEARING, exactly as the cargo lesson's is. Searched (20k
    /// seeds, `bombSwaps.count == 1`) for a quiet fresh board whose ONLY
    /// bomb-minting swap is one move: dragging (3,2) right into (4,2) lands a
    /// kind-3 piece on the corner, completing the row run (4,2)(5,2)(6,2) and
    /// the column run (4,2)(4,3)(4,4) at once. Five cells, the canonical
    /// minimum corner, and the sand sits on exactly those five so the shape
    /// the player draws IS the objective — win in one swipe, with the
    /// sunburst appearing in the wreckage as the reward. It falls to (4,4)
    /// on gravity. One competing torch swap exists and is harmless.
    /// Pinned by cornerLessonMintsABombInASingleSwap.
    static let cornerLesson: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######",
            "#######",
            "####ooo",
            "####o##",
            "####o##",
            "#######",
            "#######",
        ])
        return LuauLevel(id: 903, mask: m, jelly: j, colors: 4,
                         moves: 99, movesHard: 99,
                         seed: 0xBB6A_6973_7BEF_5627,
                         archetype: "Corner Lesson",
                         teaches: "corners")
    }()

    static let packedSandLesson: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            ".......",
            ".......",
            "..ooo..",
            "..@@@..",
            "..###..",
            ".......",
            ".......",
        ])
        return LuauLevel(id: 901, mask: m, jelly: j, colors: 4,
                         moves: 99, movesHard: 99,
                         seed: 0x9010_0901_9010_0901,
                         archetype: "Packed Sand",
                         teaches: "packedSand")
    }()

    // MARK: L1 — "Clear the sand" · Full Board · 4 colors
    static let L1: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######",
            "#######",
            "#######",
            "##ooo##",
            "#######",
            "#######",
            "#######",
        ])
        return LuauLevel(id: 1, mask: m, jelly: j, colors: 4,
                         moves: 15, movesHard: 12,
                         seed: 0x1111_0001_1111_0001,
                         archetype: "Full Board")
    }()

    // MARK: L2 — counter literacy · Full Board · 4 colors
    static let L2: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######",
            "#######",
            "##oo###",
            "##oo###",
            "###oo##",
            "###oo##",
            "#######",
        ])
        return LuauLevel(id: 2, mask: m, jelly: j, colors: 4,
                         moves: 20, movesHard: 16,
                         seed: 0x2222_0002_2222_0002,
                         archetype: "Full Board")
    }()

    // MARK: L3 — free work · Full Board · 4 colors
    static let L3: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######",
            "#######",
            "##ooo##",
            "##ooo##",
            "##ooo##",
            "#######",
            "#######",
        ])
        return LuauLevel(id: 3, mask: m, jelly: j, colors: 4,
                         moves: 22, movesHard: 17,
                         seed: 0x3333_0003_3333_0003,
                         archetype: "Full Board")
    }()

    // MARK: L4 — aimed work · Full Board · 5 colors
    static let L4: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "ooooooo",
            "#######",
            "#######",
            "#######",
            "#######",
            "#######",
            "ooooooo",
        ])
        return LuauLevel(id: 4, mask: m, jelly: j, colors: 5,
                         moves: 26, movesHard: 20,
                         seed: 0x4444_0004_4444_0004,
                         archetype: "Full Board")
    }()

    // MARK: L5 — layers · Full Board · 5 colors (first `@` cells)
    static let L5: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######",
            "#######",
            "##o@o##",
            "##@#@##",
            "##o@o##",
            "#######",
            "#######",
        ])
        return LuauLevel(id: 5, mask: m, jelly: j, colors: 5,
                         moves: 24, movesHard: 19,
                         seed: 0x5555_0005_5555_0005,
                         archetype: "Full Board")
    }()

    // MARK: L6 — first mask · THE HEADLAND · 5 colors
    static let L6: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######",
            "####ooo",
            "####ooo",
            "####...",
            "####...",
            "####...",
            "####...",
        ])
        return LuauLevel(id: 6, mask: m, jelly: j, colors: 5,
                         moves: 22, movesHard: 17,
                         seed: 0x6666_0006_6666_0006,
                         archetype: "The Headland")
    }()

    // MARK: L7 — the torch tool · Full Board · 5 colors
    // (seeded opening deferred — see Stage C follow-ups)
    static let L7: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "o######",
            "o######",
            "o######",
            "o######",
            "o######",
            "o######",
            "o######",
        ])
        return LuauLevel(id: 7, mask: m, jelly: j, colors: 5,
                         moves: 22, movesHard: 17,
                         seed: 0x7777_0007_7777_0007,
                         archetype: "Full Board")
    }()

    // MARK: L8 — split flow · TWIN COVES · 5 colors
    static let L8: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######",
            "#######",
            "#######",
            "###.###",
            "#oo.oo#",
            "#oo.oo#",
            "#oo.oo#",
        ])
        return LuauLevel(id: 8, mask: m, jelly: j, colors: 5,
                         moves: 30, movesHard: 23,
                         seed: 0x8888_0008_8888_0008,
                         archetype: "Twin Coves")
    }()

    // MARK: L9 — the cat tool · Full Board · 5 colors
    // (seeded opening deferred — see Stage C follow-ups)
    static let L9: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#o##o##",
            "#######",
            "o##o##o",
            "#######",
            "##o##o#",
            "#######",
            "o##o##o",
        ])
        return LuauLevel(id: 9, mask: m, jelly: j, colors: 5,
                         moves: 30, movesHard: 24,
                         seed: 0x9999_0009_9999_0009,
                         archetype: "Full Board")
    }()

    // MARK: L10 — low traffic · THE WELL · 5 colors
    static let L10: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######",
            "#######",
            "#######",
            "#######",
            "..o@o..",
            "..o@o..",
            "..ooo..",
        ])
        return LuauLevel(id: 10, mask: m, jelly: j, colors: 5,
                         moves: 30, movesHard: 24,
                         seed: 0xAAAA_000A_AAAA_000A,
                         archetype: "The Well")
    }()

    // MARK: L11 — pockets everywhere · THE CROSS · 5 colors
    static let L11: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "..o#o..",
            "..###..",
            "o#####o",
            "#######",
            "o#####o",
            "..###..",
            "..o#o..",
        ])
        return LuauLevel(id: 11, mask: m, jelly: j, colors: 5,
                         moves: 30, movesHard: 24,
                         seed: 0xBBBB_000B_BBBB_000B,
                         archetype: "The Cross")
    }()

    // MARK: L12 — graduation · THE SHELF · 6 colors (the exam)
    static let L12: LuauLevel = {
        let (m, j) = LuauLevel.parse([
            "#######",
            "#######",
            "######o",
            "####o..",
            "###o...",
            "##o....",
            "#o.....",
        ])
        return LuauLevel(id: 12, mask: m, jelly: j, colors: 6,
                         moves: 30, movesHard: 24,
                         seed: 0xCCCC_000C_CCCC_000C,
                         archetype: "The Shelf")
    }()
}
