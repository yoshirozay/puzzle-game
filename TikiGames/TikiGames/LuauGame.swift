import Foundation
import Observation

/// Luau — the match-3 engine. 7x7 board, six piece kinds, move-limited runs.
/// Swapping adjacent pieces must produce a 3+ line or a 2x2 square
/// (Matchington rule) or the swap reverts — and a reverted whiff still
/// spends the move (a swipe is a commitment, not a free probe). 4-LINE
/// matches spawn a line-clearing torch, 5-matches spawn the cat (color
/// bomb: swap it with any piece to clear that kind); squares clear and
/// score like any match but never spawn — spawn rewards key off run
/// length, not area. Cascades escalate a combo multiplier. Pure logic —
/// no SwiftUI.
///
/// The engine runs in one of two modes: **endless** (the historical
/// score-attack night, ENCORE-eligible) or **level** (a `LuauLevel`
/// campaign entry — masked board, jelly objective, no ENCORE, seeded RNG
/// so runs are reproducible for the LevelForge harness and CC-style
/// retries).
@Observable
final class LuauGame {
    enum Special: String, Codable {
        /// `bomb` is the AREA answer to the line torches — earned by an L or T
        /// of 5+ (two perpendicular runs sharing a corner), it clears a 3x3
        /// when its cell clears. It shipped once earned by the 2x2 square, was
        /// cut for its art (2026-07-25), and returns with a rarer faucet and
        /// the sun-compass glyph. Same raw value on purpose: saves from the
        /// square-bomb era load their bombs LIVE instead of flattening them.
        case none, lineH, lineV, cat, bomb

        /// Raw values this build has no case for but which REAL saves may
        /// hold. Empty today — the bomb sat here during its exile — but the
        /// mechanism stays: cutting a special without it destroys the
        /// player's campaign (a String enum throws on the unknown value and
        /// `restore` answers a failed payload with `newGame()`).
        private static let retired: Set<String> = []

        /// A retired special decodes as an ordinary piece; anything else is
        /// still corruption and still fails the whole payload.
        ///
        /// Both halves matter. Throwing on a retired value would fail the entire
        /// SavePayload, and `restore` answers a bad payload with `newGame()` —
        /// so cutting a special would silently take the player's campaign
        /// progress with it. Blanket tolerance is equally wrong: it would let a
        /// genuinely corrupt board load half-right, which
        /// `corruptSpecialRawValueRejectsWholePayload` exists to prevent.
        init(from decoder: any Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let known = Special(rawValue: raw) { self = known; return }
            guard Special.retired.contains(raw) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "unknown Special raw value \(raw)"))
            }
            self = .none
        }
    }

    struct Piece: Identifiable, Equatable, Codable {
        var id: UUID
        var kind: Int          // 0..<6; -1 the cat, -2 cargo — neither matches
        var special: Special
        var col: Int
        var row: Int
    }

    static let size = 7
    static let kinds = 6
    /// Cargo: a piece the board carries but can never match. The cat
    /// established the negative-kind convention (-1); cargo is -2. Every
    /// grid builder in this file already gates on `kind >= 0`, so both are
    /// excluded from matching for free — which is the whole reason cargo is
    /// a Piece rather than a parallel array.
    static let ingredientKind = -2
    static func isIngredient(_ p: Piece) -> Bool { p.kind == ingredientKind }
    static let movesPerRun = 20
    /// Bonfire depth-state ladder: FLAME / BLAZE / INFERNO (endless mode).
    static let depthThresholds = [150, 400, 700]

    private(set) var pieces: [Piece] = []
    private(set) var score = 0
    private(set) var movesLeft = LuauGame.movesPerRun
    private(set) var isOver = false
    private(set) var best = 0
    var lastRunSummary: RunSummary?

    /// One special's activation, published for the FX layer. `cells`
    /// carries the cleared pieces' art so the view can render ghosts that
    /// pop behind the traveling effect.
    struct SpecialFire {
        enum FireKind {
            case torchH, torchV, catSwap, torchCross, torchStorm, cataclysm,
                 bomb, shockwave, eruption
        }
        struct FireCell {
            let id: UUID
            let col: Int
            let row: Int
            let kind: Int
            let special: Special
        }
        let kind: FireKind
        let originCol: Int
        let originRow: Int
        /// The cat's victim kind (tints the zap lines); nil for torches.
        let targetKind: Int?
        let cells: [FireCell]
    }

    /// Specials that fired in the most recent clear event — the FX layer
    /// watches `fireBeat` and reads this. Replaced (not appended) per event.
    private(set) var lastFires: [SpecialFire] = []
    private(set) var fireBeat = 0

    /// Juice signals for the view, refreshed per resolve step.
    private(set) var clearBeat = 0
    private(set) var lastClearCount = 0
    private(set) var lastCascade = 0
    private(set) var lastClearCenters: [(col: Int, row: Int)] = []
    /// One entry per plain match in the last resolve step — its middle cell and
    /// the kind that died — so the view can draw a small kind-tinted pop where
    /// each match was. A plain 3-match is the commonest action in the game and
    /// had no burst at all; bursts lived only behind the specials FX path, so
    /// the feedback ladder had a ceiling and no floor. The specials paths leave
    /// this alone: they already run a full show.
    private(set) var lastPlainPops: [(col: Int, row: Int, kind: Int)] = []
    /// The two cells of the swap that started the current resolve, or nil in a
    /// cascade round (nothing was swapped — the board fell into place).
    /// Consumed by the FIRST resolveStep so cascades fall back to a run-relative
    /// spawn; a player only "places" the special they actually made.
    private var swapCells: ((col: Int, row: Int), (col: Int, row: Int))?
    /// Points awarded by the most recent clear — views display this rather
    /// than re-deriving (cat swaps and cascades score differently).
    private(set) var lastGain = 0
    private(set) var shuffleBeat = 0
    /// Cumulative count of resolve rounds at cascade ≥ 3 — each bump feeds
    /// the bonfire a one-shot ember burst in the scene.
    private(set) var cascadeBeat = 0
    /// ENCORE — "the band plays on": +2 bonus moves the first time a run
    /// reaches INFERNO (score 700). Once per run, never during the tutorial,
    /// **never in level mode** (would invalidate the solver's move budget).
    static let encoreMoves = 2
    private(set) var encoreBeat = 0
    private var encoreFired = false

    // MARK: level mode

    /// Non-nil while a campaign level is loaded. `newGame()` clears it back
    /// to nil (endless mode).
    private(set) var currentLevel: LuauLevel?

    /// Active jelly layer counts, row-major (49 entries). Zero everywhere in
    /// endless mode; matches `currentLevel.jelly` at level start and
    /// decrements as pieces clear on jellied cells.
    private(set) var jelly: [UInt8] = Array(repeating: 0, count: LuauLevel.cellCount)

    /// The attempt-salt applied to the level seed, so retries re-seed the
    /// spawn stream while keeping the layout fixed (CC-style).
    private(set) var attemptSeed: UInt64 = 0

    /// Campaign progress. Persisted in the save payload — the level select
    /// UI (Stage D) reads this. Lifetime, not per-run.
    private(set) var completedLevels: [Int] = []

    /// Set true when the current level's jelly hits zero; the view uses
    /// this to distinguish the SUNRISE win panel from the OUT-OF-MOVES lose
    /// panel.
    private(set) var didWinLevel = false

    /// Cargo delivered to the shore this level. Single writer:
    /// `collectLandedIngredients`.
    private(set) var ingredientsCollected = 0
    /// Cargo still to deliver. Zero on every level that declares none, which
    /// is what keeps the win test below bit-identical for all 200 shipped
    /// levels.
    var ingredientsRemaining: Int {
        (currentLevel?.ingredientTotal ?? 0) - ingredientsCollected
    }

    /// Consecutive nights cleared without a defeat. The one thing that spans
    /// levels: `newLevel` resets score, moves, cascade and bonus to zero, so
    /// before this there was nothing at all to carry across the seam between
    /// nights and each level began from a standing start. Bumped on a win,
    /// dropped to zero on a defeat, deliberately untouched by `newLevel` and
    /// `newGame` (like `completedLevels`, it is progress, not run state).
    /// Awards nothing yet — the score economy is a separate decision.
    private(set) var nightStreak = 0

    /// Points per unused move when a level is won. Priced above a typical
    /// single move's score (~40–150) so taking the win NOW always beats
    /// milking the remaining budget for score and clearing the last sand
    /// on the final move — the pre-payout dominant strategy.
    static let spareMoveBonus = 100
    /// The payout of the most recent level win (movesLeft × spareMoveBonus,
    /// already folded into `score`); the SUNRISE panel itemizes it.
    private(set) var lastSpareBonus = 0

    /// Every piece a blast is allowed to destroy. Cargo is not: it leaves
    /// the board by reaching the shore, never by being cleared. Filtering at
    /// the source beats remembering at each of the nine destruction sites —
    /// which is exactly how chained detonation once went missing from two
    /// hand-synced copies of the same logic.
    private var clearablePieces: [Piece] { pieces.filter { !Self.isIngredient($0) } }

    /// The cells a bomb at (col,row) takes out: itself and its 8 neighbours,
    /// clipped by the board edge and mask for free (only real pieces are in
    /// `pieces`). `radius` is 1 for a matched bomb (3x3) and 2 for a bomb
    /// detonated in a combo (5x5). Cargo is immune, the same rule every other
    /// blast follows. ONE function on purpose — the preview and the real clear
    /// both read it, so they cannot drift.
    func blastPieces(col: Int, row: Int, radius: Int = 1) -> [Piece] {
        clearablePieces.filter { abs($0.col - col) <= radius && abs($0.row - row) <= radius }
    }

    var isLevelMode: Bool { currentLevel != nil }
    var jellyRemaining: Int { jelly.reduce(0) { $0 + Int($1) } }
    var jellyTotal: Int { currentLevel?.jellyTotal ?? 0 }

    // MARK: lounge cat (comped placement)

    /// DANGER: a live campaign night about to fail — sand still standing
    /// with three or fewer moves on the clock (the MOVES chip's coral
    /// threshold). The window where the Lounge Cat earns its one-time comp.
    var inDanger: Bool {
        !isOver && !tutorialActive && isLevelMode
            && (jellyRemaining > 0 || ingredientsRemaining > 0)
            && movesLeft >= 1 && movesLeft <= 3
    }

    /// Places the comped Lounge Cat on (col, row), replacing the normal
    /// piece there. A gift, not a move — spends nothing, scores nothing,
    /// and triggers no resolve (kind -1 matches nothing; the piece is
    /// replaced in place, so gravity never runs). Refuses masked/empty
    /// cells, existing specials, dead runs, and the tutorial. Returns
    /// whether the cat landed so the caller knows to spend the comp.
    @discardableResult
    func placeCat(col: Int, row: Int) -> Bool {
        guard !isOver, !tutorialActive,
              let idx = pieces.firstIndex(where: { $0.col == col && $0.row == row }),
              pieces[idx].special == .none,
              // Never on cargo: the comp would delete the objective.
              !Self.isIngredient(pieces[idx])
        else { return false }
        pieces[idx] = Piece(id: UUID(), kind: -1, special: .cat, col: col, row: row)
        return true
    }

    // MARK: seeded RNG (SplitMix64)

    /// Internal state for the level-mode spawn stream. Enabled only when
    /// `currentLevel` is set; endless mode uses the system RNG (existing
    /// behavior, non-reproducible by design).
    private var rngState: UInt64 = 0
    private var rngEnabled: Bool = false

    private func nextRandom() -> UInt64 {
        rngState &+= 0x9E37_79B9_7F4A_7C15
        var z = rngState
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Every spawn/shuffle path in this engine routes through here so that
    /// determinism (level mode) OR the historical system-RNG behavior
    /// (endless) is preserved as-is per call site.
    private func nextKind(upperBound: Int) -> Int {
        precondition(upperBound > 0)
        if rngEnabled {
            return Int(nextRandom() % UInt64(upperBound))
        }
        return Int.random(in: 0..<upperBound)
    }

    // MARK: shape helpers

    /// Number of colors in play (from the level, else the historical 6).
    private var activeColors: Int { currentLevel?.colors ?? Self.kinds }

    /// Whether the cell exists on the current board. Always true in
    /// endless mode (49-cell canvas).
    private func isPlayable(col: Int, row: Int) -> Bool {
        currentLevel?.isPlayable(col: col, row: row) ?? true
    }

    /// The playable rows in a column, top-to-bottom. Gravity iterates this.
    /// In endless mode returns 0..<7.
    private func playableRows(col: Int) -> [Int] {
        if let level = currentLevel { return level.playableRows(col: col) }
        return Array(0..<Self.size)
    }

    func configureBest(_ value: Int) { best = max(best, value) }

    // MARK: setup

    /// Fresh endless-mode run. Clears any prior level state — the score
    /// ladder, ENCORE eligibility, and system-RNG spawn behavior all come
    /// back exactly as before.
    func newGame() {
        currentLevel = nil
        jelly = Array(repeating: 0, count: LuauLevel.cellCount)
        rngEnabled = false
        rngState = 0
        attemptSeed = 0
        didWinLevel = false
        ingredientsCollected = 0
        lastSpareBonus = 0
        score = 0
        movesLeft = Self.movesPerRun
        isOver = false
        lastRunSummary = nil
        lastCascade = 0
        encoreFired = false
        cascade = 1
        tutorialActive = false
        fillFreshBoard()
    }

    /// Level-mode run. Seeds the spawn RNG so the same (level.seed, attempt)
    /// pair produces the same spawn sequence — LevelForge relies on this,
    /// as do save/restore. Disables ENCORE (would invalidate the solver's
    /// budget), respects the mask everywhere.
    func newLevel(_ level: LuauLevel, attempt: UInt64 = 1) {
        currentLevel = level
        jelly = level.jelly
        rngEnabled = true
        rngState = level.seed &+ (attempt &* 0x9E37_79B9_7F4A_7C15)
        attemptSeed = attempt
        didWinLevel = false
        ingredientsCollected = 0
        lastSpareBonus = 0
        score = 0
        movesLeft = level.moves
        isOver = false
        lastRunSummary = nil
        lastCascade = 0
        encoreFired = false
        cascade = 1
        tutorialActive = false
        fillFreshBoard()
        placeIngredients()
        // Cargo overwrites plain pieces, so it can erase the very swap
        // `fillFreshBoard` just proved existed. Re-check here — `shuffle`
        // preserves cargo, so this is safe to reach.
        if !hasLegalSwap { shuffle() }
    }

    /// Drops the level's cargo onto the fresh board, replacing whatever the
    /// fill put on those cells. Replacing rather than skipping cells inside
    /// `fillFreshBoard` is deliberate: the RNG stream stays byte-identical to
    /// a cargo-free board, so every solved move budget still holds.
    private func placeIngredients() {
        guard let level = currentLevel else { return }
        for index in level.ingredientCells {
            let col = index % Self.size, row = index / Self.size
            guard let idx = pieces.firstIndex(where: { $0.col == col && $0.row == row })
            else { continue }
            pieces[idx] = Piece(id: UUID(), kind: Self.ingredientKind,
                                special: .none, col: col, row: row)
        }
        settleCargoPlacement()
    }

    /// `fillFreshBoard` guarantees a match-free board, but it runs BEFORE cargo
    /// exists — and now that runs pass through a coconut, dropping one in can
    /// join two separated pairs into a three (red red [cargo] red). That match
    /// would resolve on the first settle, so the level would open by clearing
    /// itself. Nudge the offending kinds until the board is quiet again.
    ///
    /// Deliberately deterministic rather than re-rolling from the RNG: this must
    /// not consume a pull, or a cargo level's spawn stream would diverge from
    /// the sequence its move budget was solved against.
    private func settleCargoPlacement() {
        for _ in 0..<24 {
            let matches = findMatches()
            if matches.isEmpty { return }
            guard let victim = matches.first?.cells.first,
                  let idx = pieces.firstIndex(where: { $0.col == victim.col && $0.row == victim.row })
            else { return }
            pieces[idx].kind = (pieces[idx].kind + 1) % max(1, activeColors)
        }
    }

    /// Banks every piece of cargo now resting on the shore — row 6, which a
    /// column reaches only if it drains — and lets the board fall into the
    /// space it leaves. Loops, because collecting one piece drops its column
    /// and can land a second piece on the same shore in the same round.
    @discardableResult
    private func collectLandedIngredients() -> Bool {
        guard let level = currentLevel, !tutorialActive else { return false }
        var banked = false
        while let idx = pieces.firstIndex(where: {
            Self.isIngredient($0) && $0.row == Self.size - 1 && level.drains(col: $0.col)
        }) {
            pieces.remove(at: idx)
            ingredientsCollected += 1
            banked = true
            applyGravityAndRefill()
        }
        return banked
    }

    /// Free retry (CC-style): same level, next attempt salt. Layout stays
    /// fixed; the spawn stream is fresh.
    func retryLevel() {
        guard let level = currentLevel else { return }
        newLevel(level, attempt: attemptSeed &+ 1)
    }

    /// Marks the current level complete in the player's progress list.
    /// No-op if already recorded. The view calls this when the run's
    /// SUNRISE payoff resolves.
    func markCurrentLevelComplete() {
        guard let level = currentLevel, !completedLevels.contains(level.id) else { return }
        completedLevels.append(level.id)
        completedLevels.sort()
    }

    /// First-run seed: fill a scripted board so swapping (3,3) with (3,4) walks
    /// a sand-first ladder — every beat pops sand, and the shapes/specials are
    /// taught as better ways to pop it: pop a blob's top row → pop the
    /// survivors → 2x2 square in sand → 4-match torch in sand → 5-match cat
    /// in sand → cat-swap wiping sand scattered across the board. Each round
    /// carries its own scripted jelly;
    /// the SAND counter only ever counts down within a beat and every beat
    /// after the first ends at zero. Same swap cells across every round so the
    /// coach's pulse stays anchored. The view highlights `tutorialSwapA`/`B`.
    static let tutorialSwapA: (col: Int, row: Int) = (3, 3)
    static let tutorialSwapB: (col: Int, row: Int) = (3, 4)

    /// A cell override — kind + optional special. For torches/cats, `kind`
    /// is the underlying color (–1 for the cat, whose kind matches nothing).
    struct TutorialCell {
        let col: Int
        let row: Int
        let kind: Int
        let special: Special
    }

    struct TutorialSeed {
        let cells: [TutorialCell]
        /// Scripted sand for the round — one layer per listed cell. Every
        /// round declares its jelly explicitly so a dev-hook jump to any
        /// round stages exactly what the natural flow shows (POP THE REST's
        /// "survivors" equal what the previous beat leaves, by construction).
        let jelly: [(col: Int, row: Int)]
    }

    /// The five scripted rounds. Kinds outside these overrides come from a
    /// deterministic checkerboard (see `paintTutorialBoard`) so no accidental
    /// 3-in-a-rows can form off-target.
    static let tutorialRounds: [TutorialSeed] = [
        // Round 0 — POP THE SAND. A 2×3 sand blob (rows 3–4, cols 2–4); the
        // swap pair sits fully INSIDE it and the single row-3 match pops the
        // blob's top row. SAND 6 → 3; the row-4 survivors are round 1's
        // whole subject. One match only — the pop must be unmistakably the
        // swap's doing.
        TutorialSeed(
            cells: [
                TutorialCell(col: 2, row: 3, kind: 0, special: .none),
                TutorialCell(col: 3, row: 3, kind: 1, special: .none),
                TutorialCell(col: 4, row: 3, kind: 0, special: .none),
                TutorialCell(col: 3, row: 4, kind: 0, special: .none),
                TutorialCell(col: 3, row: 2, kind: 3, special: .none),
                TutorialCell(col: 3, row: 5, kind: 3, special: .none),
            ],
            jelly: [
                (2, 3), (3, 3), (4, 3),
                (2, 4), (3, 4), (4, 4),
            ]
        ),
        // Round 1 — POP THE REST. The board reseeds but the sand picks up
        // exactly where round 0 left it: the three row-4 survivors. The
        // mirrored swap pulls a kind-0 down into row 4 and finishes the blob.
        // SAND 3 → 0 — the wordless causality lesson (a match pops exactly
        // the cells it lands on).
        TutorialSeed(
            cells: [
                TutorialCell(col: 2, row: 4, kind: 0, special: .none),
                TutorialCell(col: 3, row: 4, kind: 1, special: .none),
                TutorialCell(col: 4, row: 4, kind: 0, special: .none),
                TutorialCell(col: 3, row: 3, kind: 0, special: .none),
                TutorialCell(col: 3, row: 2, kind: 3, special: .none),
                TutorialCell(col: 3, row: 5, kind: 3, special: .none),
            ],
            jelly: [
                (2, 4), (3, 4), (4, 4),
            ]
        ),
        // Round 2 — MATCH A SQUARE. The Matchington shape: kind-0 at (2,4),
        // (2,5), (3,5) with the completer at (3,3); the swap drops it into
        // (3,4), closing the 2x2 (cols 2-3 × rows 4-5) with sand under all
        // four cells. No 3-run exists anywhere post-swap, so the pop is
        // unmistakably the square's doing — this beat only became stageable
        // when hasLegalSwap learned squares (the settle path would otherwise
        // shuffle the board away as swap-less). SAND 4 → 0.
        TutorialSeed(
            cells: [
                TutorialCell(col: 2, row: 4, kind: 0, special: .none),
                TutorialCell(col: 2, row: 5, kind: 0, special: .none),
                TutorialCell(col: 3, row: 5, kind: 0, special: .none),
                TutorialCell(col: 3, row: 4, kind: 1, special: .none),
                TutorialCell(col: 3, row: 3, kind: 0, special: .none),
                TutorialCell(col: 3, row: 2, kind: 3, special: .none),
            ],
            jelly: [
                (2, 4), (3, 4), (2, 5), (3, 5),
            ]
        ),
        // Round 3 — MAKE A TORCH. Row-3 4-match with sand under all four
        // cells: popping sand is what spawns the torch. SAND 4 → 0.
        TutorialSeed(
            cells: [
                TutorialCell(col: 0, row: 3, kind: 3, special: .none),
                TutorialCell(col: 1, row: 3, kind: 0, special: .none),
                TutorialCell(col: 2, row: 3, kind: 0, special: .none),
                TutorialCell(col: 3, row: 3, kind: 1, special: .none),
                TutorialCell(col: 4, row: 3, kind: 0, special: .none),
                TutorialCell(col: 5, row: 3, kind: 3, special: .none),
                TutorialCell(col: 6, row: 3, kind: 3, special: .none),
                TutorialCell(col: 3, row: 4, kind: 0, special: .none),
                TutorialCell(col: 3, row: 2, kind: 3, special: .none),
                TutorialCell(col: 3, row: 5, kind: 3, special: .none),
            ],
            jelly: [
                (1, 3), (2, 3), (3, 3), (4, 3),
            ]
        ),
        // Round 4 — SUMMON THE CAT. Row-3 5-match, all five pieces within
        // sand. SAND 5 → 0; cat spawns at (3,3).
        TutorialSeed(
            cells: [
                TutorialCell(col: 0, row: 3, kind: 3, special: .none),
                TutorialCell(col: 1, row: 3, kind: 0, special: .none),
                TutorialCell(col: 2, row: 3, kind: 0, special: .none),
                TutorialCell(col: 3, row: 3, kind: 1, special: .none),
                TutorialCell(col: 4, row: 3, kind: 0, special: .none),
                TutorialCell(col: 5, row: 3, kind: 0, special: .none),
                TutorialCell(col: 6, row: 3, kind: 3, special: .none),
                TutorialCell(col: 3, row: 4, kind: 0, special: .none),
                TutorialCell(col: 3, row: 2, kind: 3, special: .none),
                TutorialCell(col: 3, row: 5, kind: 3, special: .none),
            ],
            jelly: [
                (1, 3), (2, 3), (3, 3), (4, 3), (5, 3),
            ]
        ),
        // Round 5 — SWAP THE CAT. Every kind-0 target sits ON a sand cell,
        // so the color wipe pops sand across the whole board — the finale is
        // mass sand removal. SAND 8 → 0. The cat's own cell stays sand-free
        // so the cat reads as the actor, not one of the targets.
        TutorialSeed(
            cells: [
                TutorialCell(col: 3, row: 3, kind: -1, special: .cat),
                TutorialCell(col: 3, row: 4, kind: 0, special: .none),
                TutorialCell(col: 0, row: 0, kind: 0, special: .none),
                TutorialCell(col: 5, row: 1, kind: 0, special: .none),
                TutorialCell(col: 2, row: 2, kind: 0, special: .none),
                TutorialCell(col: 0, row: 4, kind: 0, special: .none),
                TutorialCell(col: 6, row: 4, kind: 0, special: .none),
                TutorialCell(col: 2, row: 6, kind: 0, special: .none),
                TutorialCell(col: 5, row: 6, kind: 0, special: .none),
            ],
            jelly: [
                (3, 4), (0, 0), (5, 1), (2, 2),
                (0, 4), (6, 4), (2, 6), (5, 6),
            ]
        ),
    ]
    static var tutorialRoundCount: Int { tutorialRounds.count }

    /// Cells the view highlights each round. All rounds share the same pair
    /// so the coach chrome doesn't jump across the board mid-tutorial.
    static func tutorialTilePositions(round _: Int) -> [(col: Int, row: Int)] {
        [tutorialSwapA, tutorialSwapB]
    }

    /// True while a scripted round owns the board — suppresses gravity refill
    /// so intermediate rounds don't leak random pieces onto the seeded layout.
    private(set) var tutorialActive: Bool = false

    func seedTutorialBoard(round: Int) {
        let r = max(0, min(round, Self.tutorialRounds.count - 1))
        let seed = Self.tutorialRounds[r]
        // Wall the board fresh: fixed 4/5 checkerboard as the neutral base so
        // no accidental 3-in-a-rows creep in from RNG.
        pieces = []
        score = 0
        movesLeft = currentLevel?.moves ?? Self.movesPerRun
        isOver = false
        lastRunSummary = nil
        cascade = 1
        lastCascade = 0
        encoreFired = false
        // Each round paints its own scripted sand — the ladder's story, not
        // the level's layout (Night 1's real jelly returns at the handoff).
        // Round 1 declares round 0's survivors verbatim, so the counter
        // reads as one continuous 6 → 3 → 0 arc across the two beats.
        var scripted = Array(repeating: UInt8(0), count: LuauLevel.cellCount)
        for c in seed.jelly {
            scripted[c.row * Self.size + c.col] = 1
        }
        jelly = scripted
        didWinLevel = false
        tutorialActive = true
        paintTutorialBoard()
        for cell in seed.cells {
            if let i = pieces.firstIndex(where: { $0.col == cell.col && $0.row == cell.row }) {
                pieces[i].kind = cell.kind
                pieces[i].special = cell.special
            }
        }
    }

    /// Neutral base: alternating kinds 4 and 5, guaranteed to contain no
    /// horizontal or vertical 3-in-a-row — and no 2x2 square, since a
    /// checkerboard has no same-kind adjacency at all — so tutorial
    /// overrides fully control where matches can form. Respects the mask so
    /// Level-1's coach can run on the level's shape (though L1 is Full
    /// Board, the guard is cheap).
    private func paintTutorialBoard() {
        for row in 0..<Self.size {
            for col in 0..<Self.size {
                guard isPlayable(col: col, row: row) else { continue }
                let kind = (col + row) % 2 == 0 ? 4 : 5
                pieces.append(Piece(id: UUID(), kind: kind, special: .none, col: col, row: row))
            }
        }
    }

    /// View calls this after the last scripted swap resolves so real play
    /// resumes with normal refill behavior. The current board state stays —
    /// any post-tutorial holes just refill on the next resolve.
    func endTutorial() {
        tutorialActive = false
        applyGravityAndRefill()
    }

    private func fillFreshBoard() {
        pieces = []
        for row in 0..<Self.size {
            for col in 0..<Self.size {
                guard isPlayable(col: col, row: row) else { continue }
                var kind: Int
                repeat {
                    kind = nextKind(upperBound: activeColors)
                } while wouldMatch(kind: kind, col: col, row: row)
                pieces.append(Piece(id: UUID(), kind: kind, special: .none, col: col, row: row))
            }
        }
        if !hasLegalSwap { shuffle() }
    }

    /// True if placing `kind` at (col, row) would immediately extend a
    /// 3-in-a-row with cells already placed to its left/above. Ignores
    /// masked neighbors (they hold no piece), which is exactly what we
    /// want — matches never cross the mask (see `findMatches`), so a
    /// masked gap breaks the constraint too.
    private func wouldMatch(kind: Int, col: Int, row: Int) -> Bool {
        func k(_ c: Int, _ r: Int) -> Int? { pieces.first { $0.col == c && $0.row == r }?.kind }
        if col >= 2, k(col - 1, row) == kind, k(col - 2, row) == kind { return true }
        if row >= 2, k(col, row - 1) == kind, k(col, row - 2) == kind { return true }
        // 2x2: fill is row-major, so this cell can only ever complete a
        // square as its bottom-right corner. At most three kinds are
        // excluded in total (left-run, up-run, square), so colors >= 4
        // always leaves a legal kind and the rejection loop terminates.
        if col >= 1, row >= 1, k(col - 1, row) == kind,
           k(col, row - 1) == kind, k(col - 1, row - 1) == kind { return true }
        return false
    }

    // MARK: swaps

    func piece(at col: Int, _ row: Int) -> Piece? {
        pieces.first { $0.col == col && $0.row == row }
    }

    private var cascade = 1

    /// Attempts to swap two adjacent cells. Returns whether the swap
    /// produced an effect (the view drives `resolveStep()` on true). A
    /// legal piece-to-piece attempt that makes no match returns false —
    /// the view springs the pieces back — but STILL spends the move:
    /// whiffs cost. Rejected gestures (dead run, no moves, non-adjacent,
    /// empty/masked cell) spend nothing.
    @discardableResult
    func attemptSwap(_ a: (col: Int, row: Int), _ b: (col: Int, row: Int)) -> Bool {
        // movesLeft > 0: isOver only latches on settle, so a second swap
        // issued between the last move and its resolve would drive movesLeft
        // negative. A LESSON IS EXEMPT, and that exemption is load-bearing: a
        // lesson never latches a defeat, so if this guard could ever close on
        // one the board would accept no input and never end — a dead board that
        // `payload`/`restore` round-trip happily, bricking the game on every
        // later launch. `spendMove` already refuses to bill a lesson, so this is
        // belt-and-braces: two independent reasons the lock cannot happen.
        guard !isOver, movesLeft > 0 || currentLevel?.isLesson == true,
              abs(a.col - b.col) + abs(a.row - b.row) == 1,
              let ia = pieces.firstIndex(where: { $0.col == a.col && $0.row == a.row }),
              let ib = pieces.firstIndex(where: { $0.col == b.col && $0.row == b.row })
        else { return false }

        // Any previous swap is stale from here on: a whiff, a cat swap and a
        // combo all leave no "placed" cell, and their cascades must not inherit
        // one from an earlier move.
        swapCells = nil

        // CARGO. It matches nothing, so it can never be the piece that completes
        // a run — but from here on it swaps like any other piece, and the
        // partner it displaces can. Every pairing except cargo↔plain, into a
        // column that drains, is rejected free, like dragging at a masked cell.
        // Rejecting HERE, ahead of the combo and cat branches, is also what
        // stops a cat↔cargo swap from reading -2 as a colour and wiping every
        // piece of cargo on the board at once.
        //
        // NOTHING ABOUT A COCONUT MOVES FOR FREE. Steering used to COMMIT
        // whether or not anything cleared, so the coconut could be walked
        // sideways at no cost. That rule does not survive contact with vertical
        // swaps: the same free commit would let a player drop the coconut
        // straight down to the shore a row at a time and take every Ingredients
        // night without ever spending a move. So this branch now settles
        // legality only and falls through to the ordinary swap below — a cargo
        // swap that clears something is charged like any other, and one that
        // clears nothing springs back as a whiff.
        if Self.isIngredient(pieces[ia]) || Self.isIngredient(pieces[ib]),
           !canShove(ia: ia, ib: ib) {
            return false
        }

        // Special x special: the two detonate together — the payoff layer.
        if pieces[ia].special != .none, pieces[ib].special != .none {
            return performComboSwap(ia: ia, ib: ib)
        }

        // Cat swap: clears every piece of the partner's kind (plus the cat).
        if pieces[ia].special == .cat || pieces[ib].special == .cat {
            let catIndex = pieces[ia].special == .cat ? ia : ib
            let otherIndex = catIndex == ia ? ib : ia
            let targetKind = pieces[otherIndex].kind
            // Capture before removeAll: reading `pieces` inside its own
            // removeAll predicate is an exclusivity violation, and a cat-cat
            // swap (targetKind -1) must not count the acting cat twice.
            let catID = pieces[catIndex].id
            let wiped = clearablePieces.filter { $0.kind == targetKind || $0.id == catID }
            // A TORCH ON THE WIPED COLOUR STILL BURNS. The colour sweep is a
            // blast like any other, so a 4-match torch caught in it fires its
            // lane instead of dying quietly — which is what a torch across the
            // board already does when another torch sweeps it up.
            let (removedIDs, chainedFires) = chainSpecials(sweptUpBy: Set(wiped.map(\.id)))
            let removed = pieces.filter { removedIDs.contains($0.id) }
            let cleared = removed.map { (col: $0.col, row: $0.row) }
            lastFires = [SpecialFire(
                kind: .catSwap,
                originCol: pieces[catIndex].col, originRow: pieces[catIndex].row,
                targetKind: targetKind,
                // The cat's own show lists only the colour it zapped; every
                // chained torch draws its own lane after it.
                cells: wiped.map { .init(id: $0.id, col: $0.col, row: $0.row, kind: $0.kind, special: $0.special) }
            )] + chainedFires
            fireBeat += 1
            pieces.removeAll { removedIDs.contains($0.id) }
            let gain = cleared.count * 20
            score += gain
            decrementJelly(at: cleared)
            registerClear(count: cleared.count, cascade: 1, centers: cleared, gain: gain)
            spendMove()
            applyGravityAndRefill()
            collectLandedIngredients()
            cascade = 2
            return true
        }

        pieces[ia].col = b.col; pieces[ia].row = b.row
        pieces[ib].col = a.col; pieces[ib].row = a.row
        if findMatches().isEmpty {
            pieces[ia].col = a.col; pieces[ia].row = a.row
            pieces[ib].col = b.col; pieces[ib].row = b.row
            // A WHIFF IS FREE. A legal adjacent swap that happens to make no
            // match reverts and costs nothing — only a swap that actually
            // clears something spends. Charging for it made the board a place
            // to be careful rather than a place to experiment, and the cost was
            // invisible: a whiff and an illegal drag looked identical, so a run
            // could bleed moves with nothing on screen saying why.
            //
            // The old soft-lock this branch guarded against — a last-move whiff
            // driving movesLeft to 0 with isOver never latching, because no
            // resolve follows an uncommitted swap — cannot happen now. Entry
            // already guards `movesLeft > 0`, and a whiff no longer decrements,
            // so a whiff can never be the thing that ends a run.
            return false
        }
        // Committed, so this swap owns where its special lands.
        swapCells = (a, b)
        spendMove()
        cascade = 1
        return true
    }

    /// Whether `ia`↔`ib` is a legal cargo swap. Exactly one of the two holds
    /// cargo; its partner is a plain piece; and the column the cargo lands in
    /// must drain. That last clause is what makes stranding impossible by
    /// construction — cargo starts in a draining column and can only ever move
    /// into another one, and a draining column is playable from its top all the
    /// way down to the shore, so a route out always exists. A VERTICAL swap
    /// satisfies it for free: cargo stays in its own column, so `partner.col`
    /// is the column it is already in.
    ///
    /// LEGALITY ONLY. Whether the swap commits is the ordinary match rule, which
    /// `attemptSwap` applies to cargo exactly as it does to a plain piece — the
    /// coconut is not steerable and nothing moves it for free.
    ///
    /// `hasLegalSwap` and `findLegalSwap` mirror this rule exactly. If they
    /// ever drift looser, they promise moves `attemptSwap` refuses; tighter,
    /// and a board whose only move is a cargo swap is declared stuck, shuffles,
    /// and falls through to `fillFreshBoard` — which would rebuild the board
    /// and destroy the cargo.
    private func canShove(ia: Int, ib: Int) -> Bool {
        let a = pieces[ia], b = pieces[ib]
        guard Self.isIngredient(a) != Self.isIngredient(b) else { return false }
        let partner = Self.isIngredient(a) ? b : a
        return partner.special == .none && partner.kind >= 0
            && currentLevel?.drains(col: partner.col) == true
    }

    /// Whether `attemptSwap(a, b)` would even CONSIDER this pairing — every
    /// entry guard except the match requirement. PURE — no mutation. False is
    /// an outright rejection (dead run, non-adjacent, empty/masked cell,
    /// illegal cargo pairing); true alongside a false from `attemptSwap` is a
    /// whiff — legal pieces, just no match. The view sorts feedback on this:
    /// a whiff gets the light registered tap, a rejection the .error buzz.
    /// Specials and cats also read true, but those pairings always commit, so
    /// the uncommitted branch never sees them.
    func isLegalPairing(_ a: (col: Int, row: Int), _ b: (col: Int, row: Int)) -> Bool {
        guard !isOver, movesLeft > 0 || currentLevel?.isLesson == true,
              abs(a.col - b.col) + abs(a.row - b.row) == 1,
              let ia = pieces.firstIndex(where: { $0.col == a.col && $0.row == a.row }),
              let ib = pieces.firstIndex(where: { $0.col == b.col && $0.row == b.row })
        else { return false }
        if Self.isIngredient(pieces[ia]) || Self.isIngredient(pieces[ib]) {
            return canShove(ia: ia, ib: ib)
        }
        return true
    }

    private func spendMove() {
        // A LESSON HAS NO MOVE ECONOMY, and pretending otherwise froze the
        // board. A lesson cannot be failed — `evaluateEndCondition` skips the
        // defeat branch for one — but `attemptSwap` gates on `movesLeft > 0`,
        // so a lesson that ticked down to 0 accepted no further input while
        // `isOver` never latched. The result was a permanently dead board that
        // persisted across launches: no swap, no end, no way out but deleting
        // the app. Reachable on the cargo lesson because its single objective
        // cell can only be cleared by a horizontal bottom-row match, so a
        // player matching elsewhere can burn the whole budget without touching
        // it — measured at 11% of seeded attempts under a topmost-match policy.
        // Sand lessons never hit it because their sand is unavoidable.
        guard currentLevel?.isLesson != true else { return }
        movesLeft -= 1
    }

    // MARK: FX previews (pure — no mutation)

    /// What the NEXT resolveStep's special activations will be, without
    /// mutating anything. The FX layer plays the show over the live board
    /// first, then the real step collapses it. Must mirror resolveStep's
    /// scan exactly (both call findMatches on identical state).
    /// Everything one round of matches destroys, and the shows that destruction
    /// triggers. PURE — it mutates nothing — so the FX preview and the real
    /// clear read the same answer and cannot drift apart. They used to be two
    /// hand-maintained copies, which is how chained detonation came to be
    /// missing from both.
    private func detonationPlan(for matches: [Match]) -> (cleared: Set<UUID>, fires: [SpecialFire]) {
        var cleared = Set<UUID>()
        var fires: [SpecialFire] = []
        var firedSpecials = Set<UUID>()

        /// Fires one special: everything it destroys joins `cleared`, and its
        /// show is recorded. `extra` is the match that set it off, which a lane
        /// also consumes; empty for a special caught in someone else's blast.
        func detonate(_ p: Piece, alsoTaking extra: [Piece]) {
            guard p.special != .none, !firedSpecials.contains(p.id) else { return }
            let hit: [Piece]
            let kind: SpecialFire.FireKind
            switch p.special {
            case .lineH:
                hit = clearablePieces.filter { f in f.row == p.row || extra.contains(where: { $0.id == f.id }) }
                kind = .torchH
            case .lineV:
                hit = clearablePieces.filter { f in f.col == p.col || extra.contains(where: { $0.id == f.id }) }
                kind = .torchV
            case .bomb:
                hit = clearablePieces.filter { f in
                    (abs(f.col - p.col) <= 1 && abs(f.row - p.row) <= 1)
                        || extra.contains(where: { $0.id == f.id })
                }
                kind = .bomb
            case .cat, .none:
                // The cat only ever fires by being SWAPPED — that is where its
                // victim colour comes from. Caught in someone else's blast it
                // simply dies; there is no defined kind for it to wipe.
                return
            }
            firedSpecials.insert(p.id)
            for x in hit { cleared.insert(x.id) }
            fires.append(SpecialFire(
                kind: kind, originCol: p.col, originRow: p.row, targetKind: nil,
                cells: hit.map { .init(id: $0.id, col: $0.col, row: $0.row, kind: $0.kind, special: $0.special) }
            ))
        }

        for match in matches {
            let matchPieces = match.cells.compactMap { piece(at: $0.col, $0.row) }
            for cell in match.cells {
                if let p = piece(at: cell.col, cell.row) {
                    detonate(p, alsoTaking: matchPieces)
                    cleared.insert(p.id)
                }
            }
        }

        // CHAIN REACTION, to a fixed point. A special swept up by another
        // special fires too — a vertical torch that takes out a horizontal one
        // must set it off. It did not, because both copies of this logic only
        // ever inspected the cells of the MATCH, so anything caught in a lane
        // landed in the clear set and died silently. Fixed point rather than one
        // extra pass, so a chain can run through more than one special;
        // `firedSpecials` is what makes it terminate when two sweep each other up.
        var chained = true
        while chained {
            chained = false
            for p in pieces where cleared.contains(p.id)
                && p.special != .none && !firedSpecials.contains(p.id) {
                let before = firedSpecials.count
                detonate(p, alsoTaking: [])
                if firedSpecials.count != before { chained = true }
            }
        }
        return (cleared, fires)
    }

    func previewStepFires() -> [SpecialFire] {
        detonationPlan(for: findMatches()).fires
    }

    /// Fires every torch and bomb swept up by a clear that did NOT come from a
    /// match. `detonationPlan` chains specials caught in another special's
    /// blast, but the paths that clear inside `attemptSwap` had no equivalent:
    /// a 4-match torch standing on the colour a cat wiped was removed without
    /// ever burning its row. Runs to a fixed point so a special lit by a
    /// chained special fires too — a torch can set off a bomb that sets off
    /// another torch — and `fired` is what makes that terminate. A cat caught
    /// in the blast just dies — same rule as `detonate`, since without a swap
    /// of its own it has no victim colour to wipe.
    ///
    /// `alreadyFired` are specials that have ALREADY had their say — the two
    /// participants in a combo, whose blast is the combo itself. Without it a
    /// torch+torch cross would fire one of its own halves a second time as if
    /// it were a bystander, quietly undoing the anchored-on-`b` geometry that
    /// `torchCrossOrderAsymmetry` pins. Only bystanders chain.
    private func chainSpecials(
        sweptUpBy seed: Set<UUID>, alreadyFired: Set<UUID> = []
    ) -> (cleared: Set<UUID>, fires: [SpecialFire]) {
        var cleared = seed
        var fired = alreadyFired
        var fires: [SpecialFire] = []
        var chaining = true
        while chaining {
            chaining = false
            for p in pieces where cleared.contains(p.id) && !fired.contains(p.id) {
                let hit: [Piece]
                let kind: SpecialFire.FireKind
                switch p.special {
                case .lineH: hit = clearablePieces.filter { $0.row == p.row }; kind = .torchH
                case .lineV: hit = clearablePieces.filter { $0.col == p.col }; kind = .torchV
                case .bomb: hit = blastPieces(col: p.col, row: p.row); kind = .bomb
                case .cat, .none: continue
                }
                fired.insert(p.id)
                for x in hit { cleared.insert(x.id) }
                fires.append(SpecialFire(
                    kind: kind, originCol: p.col, originRow: p.row, targetKind: nil,
                    cells: hit.map { .init(id: $0.id, col: $0.col, row: $0.row, kind: $0.kind, special: $0.special) }
                ))
                chaining = true
            }
        }
        return (cleared, fires)
    }

    /// What swapping a↔b would detonate, without mutating anything —
    /// non-empty only for cat swaps and special×special combos (the paths
    /// that clear inside attemptSwap). Mirrors those branches exactly.
    func previewSwapFires(_ a: (col: Int, row: Int), _ b: (col: Int, row: Int)) -> [SpecialFire] {
        guard !isOver, movesLeft > 0,
              abs(a.col - b.col) + abs(a.row - b.row) == 1,
              let ia = pieces.firstIndex(where: { $0.col == a.col && $0.row == a.row }),
              let ib = pieces.firstIndex(where: { $0.col == b.col && $0.row == b.row })
        else { return [] }
        let pa = pieces[ia], pb = pieces[ib]

        // Cargo shows nothing. A shove is a quiet move and every other cargo
        // pairing is refused — and the VIEW consults this before it calls
        // attemptSwap, so without this guard a cat↔cargo drag would render a
        // full board wipe (targetKind -2 matching every piece of cargo) for a
        // gesture the engine then rejects.
        if Self.isIngredient(pa) || Self.isIngredient(pb) { return [] }

        if pa.special != .none, pb.special != .none {
            // One table, shared with performComboSwap — see comboPlan. The
            // bomb's first life kept the pairing switch only in the swap path,
            // and the preview treated every non-cat special as a torch.
            let plan = comboPlan(pa, pb)
            let struck = pieces.filter { plan.clearIDs.contains($0.id) }
            let chainedFires: [SpecialFire] = plan.combo == .cataclysm
                ? []
                : chainSpecials(sweptUpBy: plan.clearIDs, alreadyFired: [pa.id, pb.id]).fires
            return [SpecialFire(
                kind: plan.fireKind,
                originCol: plan.origin.col, originRow: plan.origin.row,
                targetKind: plan.targetKind,
                cells: struck.map { .init(id: $0.id, col: $0.col, row: $0.row, kind: $0.kind, special: $0.special) }
            )] + chainedFires
        }

        if pa.special == .cat || pb.special == .cat {
            let cat = pa.special == .cat ? pa : pb
            let other = pa.special == .cat ? pb : pa
            let wiped = clearablePieces.filter { $0.kind == other.kind || $0.id == cat.id }
            let (_, chainedFires) = chainSpecials(sweptUpBy: Set(wiped.map(\.id)))
            return [SpecialFire(
                kind: .catSwap, originCol: cat.col, originRow: cat.row,
                targetKind: other.kind,
                cells: wiped.map { .init(id: $0.id, col: $0.col, row: $0.row, kind: $0.kind, special: $0.special) }
            )] + chainedFires
        }
        return []
    }

    /// Which special x special combo fired last (banner copy) and its beat.
    enum ComboKind {
        case torchCross, torchStorm, cataclysm, blast, shockwave, eruption
    }
    private(set) var lastCombo: ComboKind?
    private(set) var comboBeat = 0

    /// Which combo swapping a↔b WOULD fire — nil unless this is a legal
    /// special×special pairing. PURE. The view keys the banner, haptic, and
    /// sound on this, not on the fires' kinds: the panel's review caught all
    /// three new banners dead because the special-swap path always resolves
    /// through the preview show and never reached `comboBannerText`'s
    /// `lastCombo` read — and fire kinds are the SHOW, not the combo.
    func previewCombo(_ a: (col: Int, row: Int), _ b: (col: Int, row: Int)) -> ComboKind? {
        guard !isOver, movesLeft > 0 || currentLevel?.isLesson == true,
              abs(a.col - b.col) + abs(a.row - b.row) == 1,
              let ia = pieces.firstIndex(where: { $0.col == a.col && $0.row == a.row }),
              let ib = pieces.firstIndex(where: { $0.col == b.col && $0.row == b.row }),
              pieces[ia].special != .none, pieces[ib].special != .none,
              !Self.isIngredient(pieces[ia]), !Self.isIngredient(pieces[ib])
        else { return nil }
        return comboPlan(pieces[ia], pieces[ib]).combo
    }

    /// What swapping specials a↔b together destroys DIRECTLY, and how the
    /// show anchors. PURE and SHARED: `performComboSwap` mutates from it and
    /// `previewSwapFires` renders from it, so the combo table exists exactly
    /// once — the bomb's first life kept this switch only in the swap path,
    /// and the preview quietly treated every non-cat special as a torch.
    ///
    /// The table: torch+torch a cross anchored on `b` (the documented
    /// direction-dependence), cat+torch a storm from the torch, cat+cat the
    /// cataclysm, and the bomb always makes the result BIGGER — that is the
    /// whole promise of combining two specials: bomb+torch fattens the line
    /// into three full rows AND columns (SHOCKWAVE), bomb+bomb trades 3x3 for
    /// 5x5 (DOUBLE BLAST), cat+bomb wipes the bomb's colour plus a 5x5 where
    /// it sat (ERUPTION).
    private func comboPlan(_ a: Piece, _ b: Piece)
        -> (clearIDs: Set<UUID>, combo: ComboKind, perPiece: Int,
            fireKind: SpecialFire.FireKind, origin: Piece, targetKind: Int?) {
        var clearIDs = Set<UUID>()
        func clearRow(_ row: Int) { for p in clearablePieces where p.row == row { clearIDs.insert(p.id) } }
        func clearCol(_ col: Int) { for p in clearablePieces where p.col == col { clearIDs.insert(p.id) } }
        // Valid only in the cases that read it — each of those pairings
        // guarantees exactly one of the two is the bomb.
        let bomb = a.special == .bomb ? a : b

        switch (a.special, b.special) {
        case (.cat, .cat):
            clearIDs = Set(clearablePieces.map(\.id))
            return (clearIDs, .cataclysm, 20, .cataclysm, b, nil)

        case (.cat, .bomb), (.bomb, .cat):
            // The colour wipe the cat promises, delivered with the bomb's
            // area. Its OWN fire kind: it borrowed the storm's show at first,
            // and the review panel measured the lie — the storm's render
            // glows two full lanes an eruption never clears, and gives the
            // off-colour 5x5 cells no agent at all before they pop.
            for p in clearablePieces where p.kind == bomb.kind { clearIDs.insert(p.id) }
            for p in blastPieces(col: bomb.col, row: bomb.row, radius: 2) { clearIDs.insert(p.id) }
            clearIDs.insert(a.id); clearIDs.insert(b.id)
            return (clearIDs, .eruption, 25, .eruption, bomb, bomb.kind)

        case (.cat, _), (_, .cat):
            let torch = a.special == .cat ? b : a
            for p in clearablePieces where p.kind == torch.kind { clearIDs.insert(p.id) }
            clearRow(torch.row); clearCol(torch.col)
            clearIDs.insert(a.id); clearIDs.insert(b.id)
            // The cross bursts from the TORCH's cell, not the swap target.
            return (clearIDs, .torchStorm, 25, .torchStorm, torch, torch.kind)

        case (.bomb, .bomb):
            // Twice the bomb: a 5x5 instead of a 3x3, anchored where the
            // swap landed — the same rule as the cross.
            for p in blastPieces(col: b.col, row: b.row, radius: 2) { clearIDs.insert(p.id) }
            clearIDs.insert(a.id); clearIDs.insert(b.id)
            return (clearIDs, .blast, 20, .bomb, b, nil)

        case (.bomb, _), (_, .bomb):
            // The torch's line, fattened by the bomb: three full rows AND
            // three full columns through the bomb's cell. Its own fire kind —
            // the single-cross show it borrowed left the offset lanes popping
            // with no agent on them.
            for d in -1...1 {
                clearRow(bomb.row + d)
                clearCol(bomb.col + d)
            }
            clearIDs.insert(a.id); clearIDs.insert(b.id)
            return (clearIDs, .shockwave, 20, .shockwave, bomb, nil)

        default:
            clearRow(b.row); clearCol(b.col)
            clearIDs.insert(a.id); clearIDs.insert(b.id)
            return (clearIDs, .torchCross, 15, .torchCross, b, nil)
        }
    }

    /// Swapping two specials into each other detonates both at once — the
    /// payoff table lives in `comboPlan`.
    private func performComboSwap(ia: Int, ib: Int) -> Bool {
        let a = pieces[ia], b = pieces[ib]
        let plan = comboPlan(a, b)
        lastCombo = plan.combo

        // A bystander special swept up by the combo fires too, exactly as one
        // swept up by the cat's colour wipe does. Skipped for a cataclysm,
        // which already takes every clearable piece — a chain there could add
        // no cell, only a redundant show over a board that is already going.
        var allIDs = plan.clearIDs
        var chainedFires: [SpecialFire] = []
        if plan.combo != .cataclysm {
            (allIDs, chainedFires) = chainSpecials(sweptUpBy: plan.clearIDs,
                                                   alreadyFired: [a.id, b.id])
        }
        let struck = pieces.filter { plan.clearIDs.contains($0.id) }
        let removed = pieces.filter { allIDs.contains($0.id) }
        let cleared = removed.map { (col: $0.col, row: $0.row) }
        lastFires = [SpecialFire(
            kind: plan.fireKind,
            originCol: plan.origin.col, originRow: plan.origin.row,
            targetKind: plan.targetKind,
            // The combo's own show lists only what IT struck; every chained
            // special draws its own show after it.
            cells: struck.map { .init(id: $0.id, col: $0.col, row: $0.row, kind: $0.kind, special: $0.special) }
        )] + chainedFires
        fireBeat += 1
        pieces.removeAll { allIDs.contains($0.id) }
        let gain = removed.count * plan.perPiece
        score += gain
        decrementJelly(at: cleared)
        registerClear(count: removed.count, cascade: 1, centers: cleared, gain: gain)
        comboBeat += 1
        spendMove()
        applyGravityAndRefill()
        collectLandedIngredients()
        cascade = 2
        return true
    }

    /// Removes one jelly layer per cell listed. No-op in endless mode
    /// (currentLevel == nil). Called from every clear path (matches +
    /// triggered specials, cat swap, combo swap) so jelly can't leak.
    private func decrementJelly(at cells: [(col: Int, row: Int)]) {
        guard currentLevel != nil else { return }
        for cell in cells {
            let i = cell.row * Self.size + cell.col
            guard (0..<jelly.count).contains(i) else { continue }
            if jelly[i] > 0 { jelly[i] -= 1 }
        }
    }

    // MARK: matching

    private struct Match {
        var cells: [(col: Int, row: Int)]
        var kind: Int
        var isRow: Bool
        /// 2x2 square match — clears like any match but never spawns a
        /// special (the count==4 spawn rule reads run LENGTH; a square
        /// is area, and paying it a torch would double the line reward).
        var isSquare = false
    }

    /// Runs along ONE line, with cargo TRANSPARENT: a coconut neither breaks a
    /// run nor counts toward it, so `red [coconut] red red` is a three-match of
    /// the reds. Returns the indices of the MATCHING cells only — never the
    /// cargo cell — which is what keeps a coconut out of every clear set and
    /// stops a special ever spawning on top of it.
    ///
    /// Cargo used to block runs. That was a defensible obstacle rule and it was
    /// wrong for this game: it made the cell beneath a coconut clearable ONLY by
    /// a horizontal match (a vertical run through it hit the coconut), which is
    /// why 153 of 200 shipped levels failed a bottom-row width test and why a
    /// narrow lesson board delivered in just 59 of 120 bot runs. It also simply
    /// read as broken — a line you can see and cannot make.
    ///
    /// `line[i]` is the kind at position i: -9 masked, -1 cat, -2 cargo.
    static func lineRuns(_ line: [Int]) -> [(idx: [Int], kind: Int)] {
        var out: [(idx: [Int], kind: Int)] = []
        var i = 0
        while i < line.count {
            let kind = line[i]
            guard kind >= 0 else { i += 1; continue }
            var idx = [i]
            var j = i
            while j + 1 < line.count {
                let next = line[j + 1]
                if next == kind {
                    idx.append(j + 1); j += 1
                } else if next == ingredientKind {
                    j += 1                      // spanned, deliberately uncounted
                } else {
                    break
                }
            }
            if idx.count >= 3 { out.append((idx, kind)) }
            // Resume one past the last MATCHED cell, not past the spanned cargo:
            // a trailing coconut must not swallow the cell behind it.
            i = (idx.last ?? i) + 1
        }
        return out
    }

    /// Whether a grid holds any match at all. `hasLegalSwap`, `findLegalSwap`
    /// and the previews all consult THIS rather than each carrying its own copy
    /// of the rule — six scanners that have to agree about cargo is exactly the
    /// shape of every bug this mechanic has produced so far.
    static func gridHasMatch(_ g: [[Int]]) -> Bool {
        for r in 0..<size where !lineRuns(g[r]).isEmpty { return true }
        for c in 0..<size {
            if !lineRuns((0..<size).map { g[$0][c] }).isEmpty { return true }
        }
        // A 2x2 square needs four real pieces, so cargo cannot form one.
        for r in 0..<(size - 1) {
            for c in 0..<(size - 1) {
                let k = g[r][c]
                if k >= 0, g[r][c + 1] == k, g[r + 1][c] == k, g[r + 1][c + 1] == k {
                    return true
                }
            }
        }
        return false
    }

    private func findMatches() -> [Match] {
        var grid = [[Int]](repeating: [Int](repeating: -9, count: Self.size), count: Self.size)
        for p in pieces { grid[p.row][p.col] = p.kind }
        var matches: [Match] = []
        // Rows.
        for r in 0..<Self.size {
            for run in Self.lineRuns(grid[r]) {
                matches.append(Match(cells: run.idx.map { ($0, r) }, kind: run.kind, isRow: true))
            }
        }
        // Columns.
        for c in 0..<Self.size {
            let column = (0..<Self.size).map { grid[$0][c] }
            for run in Self.lineRuns(column) {
                matches.append(Match(cells: run.idx.map { (c, $0) }, kind: run.kind, isRow: false))
            }
        }
        // 2x2 squares (Matchington rule). Overlaps with line matches — and
        // between squares — dedup through resolveStep's toClear set, so a
        // same-kind 3x2 block is just two overlapping squares plus two
        // 3-runs: all six cells clear once. kind >= 0 keeps the cat (-1)
        // and masked cells (-9) out, so squares never cross the mask.
        for r in 0..<(Self.size - 1) {
            for c in 0..<(Self.size - 1) {
                let kind = grid[r][c]
                if kind >= 0, grid[r][c + 1] == kind,
                   grid[r + 1][c] == kind, grid[r + 1][c + 1] == kind {
                    matches.append(Match(
                        cells: [(c, r), (c + 1, r), (c, r + 1), (c + 1, r + 1)],
                        kind: kind, isRow: false, isSquare: true
                    ))
                }
            }
        }
        return matches
    }

    // MARK: resolution (stepped — one cascade round per call)

    /// Clears one round of matches and refills. Returns false once the board
    /// has settled (no matches): finalizes shuffle/game-over bookkeeping.
    @discardableResult
    func resolveStep() -> Bool {
        // A finished run is read-only: the view stops driving on isOver, so
        // any stray caller (FX replay, stale timer) must not clear, score,
        // or shuffle the corpse board.
        guard !isOver else { return false }
        let matches = findMatches()
        if matches.isEmpty {
            // Scripted-tutorial cascades must not pollute the displayed best.
            if !tutorialActive { best = max(best, score) }
            if !hasLegalSwap { shuffle() }
            evaluateEndCondition()
            return false
        }

        // One shared, pure answer for what this round destroys and what it
        // shows — see detonationPlan. resolveStep and previewStepFires used to
        // keep separate copies of this, and chained detonation was missing from
        // both as a result.
        let plan = detonationPlan(for: matches)
        var toClear = plan.cleared
        let fires = plan.fires
        var spawns: [(kind: Int, special: Special, col: Int, row: Int)] = []
        var centers: [(col: Int, row: Int)] = []
        var pops: [(col: Int, row: Int, kind: Int)] = []

        for match in matches {
            let center = match.cells[match.cells.count / 2]
            centers.append(center)
            pops.append((col: center.col, row: center.row, kind: match.kind))
        }
        spawns = spawnPlan(for: matches)

        // Consumed: only the round the player actually swapped in gets to
        // place its special. Cascade rounds fall back to the run-relative cell.
        swapCells = nil

        // Positions of every cleared piece, resolved before removeAll so we
        // can decrement jelly. Matches, triggered torches, and cats all
        // funnel through this set.
        let clearedPositions = pieces
            .filter { toClear.contains($0.id) }
            .map { (col: $0.col, row: $0.row) }

        if !fires.isEmpty {
            lastFires = fires
            fireBeat += 1
        }

        let clearedCount = toClear.count
        let gain = clearedCount * 10 * cascade
        score += gain
        decrementJelly(at: clearedPositions)
        lastPlainPops = pops
        registerClear(count: clearedCount, cascade: cascade, centers: centers, gain: gain)
        pieces.removeAll { toClear.contains($0.id) }
        for s in spawns {
            pieces.append(Piece(id: UUID(), kind: s.kind, special: s.special, col: s.col, row: s.row))
        }
        applyGravityAndRefill()
        // A vertical torch in the cargo's column empties it, gravity drops the
        // lone survivor to the shore, and it banks here — in the same step.
        collectLandedIngredients()
        cascade += 1
        return true
    }

    /// Decides whether the board's rest state is a win, a loss, or just a
    /// pause between moves — called on every settle. Level and endless
    /// modes differ only here.
    private func evaluateEndCondition() {
        // Scripted coach rounds never end a run: sand they pop (and moves
        // they spend) are demonstration, not play. Flipping isOver here
        // would also hide the coach card mid-ladder (the view gates it on
        // !isOver). Night 1 is won for real on the post-coach fresh board.
        if tutorialActive { return }
        if currentLevel != nil {
            if jellyRemaining == 0, ingredientsRemaining == 0 {
                isOver = true
                didWinLevel = true
                // Unused moves pay out with the win. Paid here — the single
                // point where a win latches — so every downstream reader of
                // the final score (recordRun's leaderboard/wallet/strand,
                // the milestone check, the panel) sees one consistent
                // number. `best` re-syncs because the settle path updated
                // it before this ran.
                // A LESSON IS NOT A NIGHT: it pays no spare bonus and does not
                // extend the streak. Since a lesson never spends moves, the
                // ordinary payout would hand over its entire authored budget —
                // 9,900 points on a 99-move lesson — for a board that cannot be
                // failed and can be replayed from the level picker. That is a
                // risk-free faucet worth several times a real night.
                let teaching = currentLevel?.isLesson == true
                lastSpareBonus = teaching ? 0 : movesLeft * Self.spareMoveBonus
                score += lastSpareBonus
                best = max(best, score)
                markCurrentLevelComplete()
                if !teaching { nightStreak += 1 }
            } else if movesLeft <= 0, currentLevel?.isLesson != true {
                // A LESSON CANNOT BE FAILED. Running out of moves while being
                // taught something teaches the wrong thing — that the mechanic
                // is a trap. The board simply stays open until the lesson's
                // objective is met.
                isOver = true
                didWinLevel = false
                nightStreak = 0
            }
        } else {
            if movesLeft <= 0 { isOver = true }
        }
    }

    /// The cell a match's special should appear on: the swapped cell the match
    /// runs through, else the run-relative fallback for cascade-formed matches.
    /// Which specials this round's matches mint, bigger shapes first — the
    /// Candy Crush priority ladder: a straight five is a CAT and consumes its
    /// run; two leftover perpendicular runs of the same kind sharing a corner
    /// (an L, a T, or a +) of 5+ distinct cells merge into a BOMB; a leftover
    /// straight four is a TORCH; a 3-arm whose partner was consumed just
    /// clears. Squares never participate (area already stopped paying — the
    /// bomb's faucet is the CORNER now, deliberate and rare, not the cheapest
    /// shape on the board).
    ///
    /// WHERE a special lands is the player's decision, not the shape's
    /// geometry: the cell they moved the last piece into, if it is anywhere in
    /// the shape. A cascade round has no swap, so a run falls back to its
    /// run-relative cell (`spawnCell`) and a corner shape to its corner — the
    /// elbow, which is where the genre puts it.
    ///
    /// Bombs are suppressed while the coach runs: the scripted first-run
    /// ladder teaches square → torch → cat, and a special the player has not
    /// been taught appearing mid-demonstration is off-script (the same guard
    /// the square-era bomb shipped with).
    private func spawnPlan(for matches: [Match]) -> [(kind: Int, special: Special, col: Int, row: Int)] {
        var spawns: [(kind: Int, special: Special, col: Int, row: Int)] = []
        var consumed = Set<Int>()
        let runs = matches.indices.filter { !matches[$0].isSquare }

        for i in runs where matches[i].cells.count >= 5 {
            let at = spawnCell(for: matches[i])
            spawns.append((-1, .cat, at.col, at.row))
            consumed.insert(i)
        }

        if !tutorialActive {
            // A row-run and a column-run can share at most one cell, so the
            // shared cell IS the corner. Largest union first; ties break on
            // corner position so the plan is deterministic for a given board.
            var pairs: [(r: Int, c: Int, corner: (col: Int, row: Int), size: Int)] = []
            for r in runs where !consumed.contains(r) && matches[r].isRow {
                for c in runs where !consumed.contains(c) && !matches[c].isRow
                    && matches[c].kind == matches[r].kind {
                    guard let corner = matches[r].cells.first(where: { rc in
                        matches[c].cells.contains { $0.col == rc.col && $0.row == rc.row }
                    }) else { continue }
                    let size = matches[r].cells.count + matches[c].cells.count - 1
                    guard size >= 5 else { continue }
                    pairs.append((r, c, corner, size))
                }
            }
            pairs.sort {
                if $0.size != $1.size { return $0.size > $1.size }
                if $0.corner.row != $1.corner.row { return $0.corner.row < $1.corner.row }
                return $0.corner.col < $1.corner.col
            }
            for pair in pairs where !consumed.contains(pair.r) && !consumed.contains(pair.c) {
                consumed.insert(pair.r); consumed.insert(pair.c)
                let union = matches[pair.r].cells + matches[pair.c].cells
                let at = swapCells.flatMap { swap in
                    [swap.0, swap.1].first { s in
                        union.contains { $0.col == s.col && $0.row == s.row }
                    }
                } ?? pair.corner
                spawns.append((matches[pair.r].kind, .bomb, at.col, at.row))
            }
        }

        for i in runs where !consumed.contains(i) && matches[i].cells.count == 4 {
            let m = matches[i]
            let at = spawnCell(for: m)
            spawns.append((m.kind, m.isRow ? .lineV : .lineH, at.col, at.row))
        }
        return spawns
    }

    private func spawnCell(for match: Match) -> (col: Int, row: Int) {
        let fallback = match.cells[match.cells.count == 4 ? 1 : 2]
        guard let swap = swapCells else { return fallback }
        for candidate in [swap.0, swap.1]
        where match.cells.contains(where: { $0.col == candidate.col && $0.row == candidate.row }) {
            return candidate
        }
        return fallback
    }

    private func registerClear(count: Int, cascade: Int, centers: [(col: Int, row: Int)], gain: Int) {
        lastClearCount = count
        lastCascade = cascade
        lastClearCenters = centers
        lastGain = gain
        clearBeat += 1
        if cascade >= 3 { cascadeBeat += 1 }
        // ENCORE: the band plays on. Endless-mode only — the +2 surprise
        // moves would invalidate the level solver's move budget, so a run
        // that's crossed into a level never pays it.
        if currentLevel == nil,
           score >= Self.depthThresholds[2],
           !encoreFired,
           !tutorialActive {
            encoreFired = true
            movesLeft += Self.encoreMoves
            encoreBeat += 1
        }
    }

    private func applyGravityAndRefill() {
        for col in 0..<Self.size {
            let rowsForCol = playableRows(col: col)
            if rowsForCol.isEmpty { continue }

            // Gather this column's pieces (any order — we're about to
            // re-slot them bottom-up).
            var column = pieces.filter { $0.col == col }
            column.sort { $0.row > $1.row }

            // Playable rows top-to-bottom; we fill bottom-most first.
            var slot = rowsForCol.count - 1
            for p in column {
                guard slot >= 0 else { break }
                if let idx = pieces.firstIndex(where: { $0.id == p.id }) {
                    pieces[idx].row = rowsForCol[slot]
                }
                slot -= 1
            }

            // Skip refill while the tutorial owns the board so intermediate
            // rounds don't leak RNG pieces onto the seeded layout — the next
            // seed rebuilds the base checkerboard anyway.
            if tutorialActive { continue }

            // Refill unfilled top slots. In endless mode this floods row 0
            // as always; in level mode spawns enter at the top of each
            // column's playable run (may be < row 0 for e.g. Pyramid).
            while slot >= 0 {
                pieces.append(Piece(
                    id: UUID(),
                    kind: nextKind(upperBound: activeColors),
                    special: .none,
                    col: col,
                    row: rowsForCol[slot]
                ))
                slot -= 1
            }
        }
    }

    // MARK: legal moves + shuffle

    var hasLegalSwap: Bool {
        // Special-aware scan first, mirroring attemptSwap's accept rules:
        // a cat swaps with ANY adjacent piece (color wipe), and two adjacent
        // specials always combo — neither needs a kind match. A cat with no
        // adjacent piece (isolated masked pocket) is NOT a legal swap.
        for p in pieces where p.special != .none {
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                guard let neighbor = piece(at: p.col + dc, p.row + dr) else { continue }
                if neighbor.special != .none { return true }
                // A cat swaps with any piece EXCEPT cargo, which attemptSwap
                // refuses. Counting that pairing here would report a move the
                // engine rejects and leave a genuinely stuck board unshuffled.
                if p.special == .cat, !Self.isIngredient(neighbor) { return true }
            }
        }
        var grid = [[Int]](repeating: [Int](repeating: -9, count: Self.size), count: Self.size)
        for p in pieces { grid[p.row][p.col] = p.kind }
        // One rule, shared with findMatches and findLegalSwap. These used to be
        // three hand-maintained copies whose comments begged each other to stay
        // in lockstep; cargo transparency is the third rule they would have had
        // to agree on and the first that none of them could express.
        let matchesAfterSwap = Self.gridHasMatch
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                // Both cells must actually hold pieces — masked cells sit
                // at the -9 sentinel and swapping into them would falsely
                // pass on a synthetic grid change.
                // A SHOVE COUNTS ONLY IF IT MAKES A MATCH. Cargo can almost
                // always be pushed somewhere, so treating a bare shove as "the
                // board has a move" left `hasLegalSwap` permanently true: a
                // player out of matches could slide the coconut forever and the
                // board would never reshuffle. Steering is still legal (see
                // `canShove`) — it just no longer suppresses the safety net.
                // Safe to shuffle now because `shuffle()` puts cargo back.
                if canShoveMakingMatch(grid, col: c, row: r, matches: matchesAfterSwap) {
                    return true
                }
                guard grid[r][c] >= 0 else { continue }
                if c + 1 < Self.size, grid[r][c+1] >= 0 {
                    var g = grid; g[r].swapAt(c, c + 1)
                    if matchesAfterSwap(g) { return true }
                }
                if r + 1 < Self.size, grid[r+1][c] >= 0 {
                    var g = grid; let t = g[r][c]; g[r][c] = g[r+1][c]; g[r+1][c] = t
                    if matchesAfterSwap(g) { return true }
                }
            }
        }
        return false
    }

    /// Whether swapping the cargo at (col, row) with a neighbour would produce
    /// a match. Mirrors `canShove`'s legality (plain partner, draining
    /// destination, any of the four directions) and then adds what `canShove`
    /// leaves to `attemptSwap`: that the displaced piece actually completes a
    /// run, which is the only reason a cargo swap commits at all.
    private func canShoveMakingMatch(
        _ grid: [[Int]], col: Int, row: Int, matches: ([[Int]]) -> Bool
    ) -> Bool {
        guard grid[row][col] == Self.ingredientKind else { return false }
        for (dc, dr) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            let c2 = col + dc, r2 = row + dr
            guard c2 >= 0, c2 < Self.size, r2 >= 0, r2 < Self.size,
                  let partner = piece(at: c2, r2),
                  partner.special == .none, partner.kind >= 0,
                  currentLevel?.drains(col: c2) == true
            else { continue }
            var g = grid
            g[row][col] = partner.kind
            g[r2][c2] = Self.ingredientKind
            if matches(g) { return true }
        }
        return false
    }

    /// Finds one legal swap (autoplay + hint use).
    func findLegalSwap() -> ((col: Int, row: Int), (col: Int, row: Int))? {
        var grid = [[Int]](repeating: [Int](repeating: -9, count: Self.size), count: Self.size)
        for p in pieces { grid[p.row][p.col] = p.kind }
        let hasMatch = Self.gridHasMatch
        for r in 0..<Self.size {
            for c in 0..<Self.size {
                guard grid[r][c] >= 0 else { continue }
                if c + 1 < Self.size, grid[r][c+1] >= 0 {
                    var g = grid; g[r].swapAt(c, c + 1)
                    if hasMatch(g) { return ((c, r), (c + 1, r)) }
                }
                if r + 1 < Self.size, grid[r+1][c] >= 0 {
                    var g = grid; let t = g[r][c]; g[r][c] = g[r+1][c]; g[r+1][c] = t
                    if hasMatch(g) { return ((c, r), (c, r + 1)) }
                }
            }
        }
        // Cargo fallback, in lockstep with hasLegalSwap: only a cargo swap that
        // MAKES a match is a move worth pointing at — and, since the coconut no
        // longer moves for free, it is also the only one the engine commits.
        for p in pieces where Self.isIngredient(p) {
            for (dc, dr) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                guard let partner = piece(at: p.col + dc, p.row + dr),
                      partner.special == .none, partner.kind >= 0,
                      currentLevel?.drains(col: partner.col) == true
                else { continue }
                var g = grid
                g[p.row][p.col] = partner.kind
                g[partner.row][partner.col] = Self.ingredientKind
                if hasMatch(g) { return ((p.col, p.row), (partner.col, partner.row)) }
            }
        }
        return nil
    }

    private func shuffle() {
        // Permute only plain pieces: specials keep their cells, and a cat's
        // -1 kind must never migrate onto a plain piece (unmatchable strand).
        // `kind >= 0` excludes cargo: its -2 migrating onto a plain piece is
        // exactly the unmatchable-strand bug the cat comment warns about. This
        // is a no-op on every cargo-free board, so the shuffle RNG stream is
        // byte-identical to before.
        let movable = pieces.indices.filter { pieces[$0].special == .none && pieces[$0].kind >= 0 }
        var kinds = movable.map { pieces[$0].kind }
        for _ in 0..<8 {
            shuffleKinds(&kinds)
            for (slot, i) in movable.enumerated() { pieces[i].kind = kinds[slot] }
            if findMatches().isEmpty, hasLegalSwap {
                shuffleBeat += 1
                return
            }
        }
        // Last resort: rebuild. Cargo is the level's objective, not the
        // board's to regenerate — snapshot where it stands and put it back, or
        // a level that shuffles its way here loses the thing it asked for.
        let cargo = pieces.filter { Self.isIngredient($0) }.map { (col: $0.col, row: $0.row) }
        fillFreshBoard()
        for c in cargo {
            guard let idx = pieces.firstIndex(where: { $0.col == c.col && $0.row == c.row })
            else { continue }
            pieces[idx] = Piece(id: UUID(), kind: Self.ingredientKind,
                                special: .none, col: c.col, row: c.row)
        }
        shuffleBeat += 1
    }

    /// Fisher-Yates via the current RNG source. Endless mode uses the
    /// system RNG (matching the historical `Array.shuffle` behavior);
    /// level mode uses the seeded stream so retries/harness runs are
    /// reproducible.
    private func shuffleKinds(_ kinds: inout [Int]) {
        var i = kinds.count - 1
        while i > 0 {
            let j = nextKind(upperBound: i + 1)
            kinds.swapAt(i, j)
            i -= 1
        }
    }

    // MARK: persistence

    struct SavePayload: Codable {
        var seenHowTo: Bool
        var score: Int
        var movesLeft: Int
        var board: [Piece]?
        // Level-mode fields — nil for endless and legacy payloads.
        var levelID: Int?
        var jelly: [UInt8]?
        var attemptSeed: UInt64?
        var completedLevels: [Int]?
        /// Nil for pre-streak payloads — a legacy save resumes at streak 0.
        var nightStreak: Int?
        /// Cargo already delivered. Positions need no field — cargo pieces ride
        /// in `board` like any other. Nil for legacy and cargo-free payloads.
        var ingredientsCollected: Int?
    }

    func payload(seenHowTo: Bool) -> String {
        // A scripted coach board is demonstration, not a run — persist it
        // with no live-run fields so a mid-coach kill can't resume a
        // half-tutorial Night 1 (the coach restarts from round 0 while
        // seenHowTo is false; a skip elsewhere falls back to the picker).
        let inLevel = currentLevel != nil && !tutorialActive
        let state = SavePayload(
            seenHowTo: seenHowTo,
            score: score,
            movesLeft: movesLeft,
            board: (isOver || tutorialActive) ? nil : pieces,
            levelID: inLevel ? currentLevel?.id : nil,
            jelly: inLevel ? jelly : nil,
            attemptSeed: inLevel ? attemptSeed : nil,
            completedLevels: completedLevels.isEmpty ? nil : completedLevels,
            nightStreak: nightStreak == 0 ? nil : nightStreak,
            ingredientsCollected: inLevel && ingredientsCollected > 0 ? ingredientsCollected : nil
        )
        guard let data = try? JSONEncoder().encode(state) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Restores a saved run. Three cases:
    /// (A) level payload — level id + board + jelly present, board.count
    ///     matches the level's playable cell count → resume mid-level;
    /// (B) legacy endless payload — 49-piece full board, no level fields →
    ///     resume mid-endless (matches the pre-levels shape byte-for-byte);
    /// (C) missing/incomplete/unknown level → fall back to a fresh endless
    ///     game (existing behavior on bad restore).
    /// Legacy JSON with none of the new fields decodes cleanly because
    /// every new field is optional.
    @discardableResult
    func restore(from json: String?) -> SavePayload? {
        guard let json, let data = json.data(using: .utf8),
              let state = try? JSONDecoder().decode(SavePayload.self, from: data) else {
            newGame()
            return nil
        }

        // Always restore lifetime completed-levels first — even a fresh
        // endless resume should keep the campaign progress list intact.
        // A payload WITHOUT the field must not wipe in-memory progress
        // (matching the full-decode-failure path, which preserves it).
        if let savedProgress = state.completedLevels {
            completedLevels = savedProgress
        }
        // Lifetime-ish progress like completedLevels: restore it before any of
        // the run-shape branches below, and never let a payload lacking the
        // field wipe what is already in memory.
        if let savedStreak = state.nightStreak {
            nightStreak = savedStreak
        }

        // Case A: level payload. Every saved piece must sit on a cell the
        // level's CURRENT mask calls playable — campaign regenerations can
        // change a level's board under an old mid-run save, and restoring
        // that board would scatter pieces onto masked cells. A stale save
        // falls through to Case C (fresh endless + picker); lifetime
        // progress was already restored above.
        if let levelID = state.levelID,
           let level = LuauLevels.level(id: levelID),
           let board = state.board,
           let savedJelly = state.jelly,
           savedJelly.count == LuauLevel.cellCount,
           board.count == level.playableCount,
           board.allSatisfy({ level.isPlayable(col: $0.col, row: $0.row) }),
           boardCellsAreSane(board),
           // Jelly on a masked cell can never be cleared — a corrupt save
           // with one would soft-lock the objective.
           savedJelly.enumerated().allSatisfy({ i, layers in
               layers == 0 || level.isPlayable(col: i % Self.size, row: i / Self.size)
           }),
           // Cargo is conserved: what is still on the board plus what has been
           // delivered must be exactly what the level asked for. A save that
           // lost a piece falls to Case C rather than resuming a level that can
           // never be won — or, worse, one already silently won.
           board.filter({ Self.isIngredient($0) }).count
               + (state.ingredientsCollected ?? 0) == level.ingredientTotal,
           // And none of it may already be stranded off a draining column.
           board.allSatisfy({ !Self.isIngredient($0) || level.drains(col: $0.col) }) {
            currentLevel = level
            pieces = board
            jelly = savedJelly
            score = sanitizedScore(state.score)
            // A LESSON RESUMES WITH A FULL BUDGET. It has no move economy, so
            // there is nothing to restore — and this is the repair path for
            // saves already frozen by an earlier build, which persisted a lesson
            // at movesLeft 0 with isOver false. Without this they resume dead
            // forever; a shipped build can brick a player's Luau this way, and a
            // fix that only prevents NEW freezes leaves them stuck.
            movesLeft = level.isLesson ? level.moves : sanitizedMoves(state.movesLeft)
            isOver = false
            didWinLevel = false
            attemptSeed = state.attemptSeed ?? 0
            ingredientsCollected = state.ingredientsCollected ?? 0
            // Re-seed from (level.seed, attemptSeed). We don't track how
            // many pulls happened before the save, so downstream spawns
            // won't match the "as if uninterrupted" stream — but they will
            // be deterministic from the resume point, which is what save/
            // resume needs. CC-style retries re-seed anyway.
            rngState = level.seed &+ (attemptSeed &* 0x9E37_79B9_7F4A_7C15)
            rngEnabled = true
            encoreFired = false  // level mode never fires it
            return state
        }

        // Case B: legacy endless payload. levelID == nil is required — a
        // level save that failed Case A (stale mask, unknown id, corrupt
        // jelly) must fall to Case C, not resume as a mid-endless run
        // carrying the level's score and board.
        if state.levelID == nil,
           let board = state.board,
           board.count == LuauLevel.cellCount,
           // Endless mode has no objective and no shore, so cargo there could
           // never be delivered. This clause is what lets
           // `collectLandedIngredients` stay guarded on `currentLevel != nil`.
           board.allSatisfy({ !Self.isIngredient($0) }),
           boardCellsAreSane(board) {
            currentLevel = nil
            jelly = Array(repeating: 0, count: LuauLevel.cellCount)
            rngEnabled = false
            rngState = 0
            attemptSeed = 0
            ingredientsCollected = 0
            pieces = board
            score = sanitizedScore(state.score)
            movesLeft = sanitizedMoves(state.movesLeft)
            isOver = false
            didWinLevel = false
            encoreFired = score >= Self.depthThresholds[2]
            return state
        }

        // Case C: incomplete — fresh endless.
        newGame()
        return state
    }

    /// A restored board is structurally sound only when every piece sits on
    /// a distinct in-range cell — the engine's grids index [row][col]
    /// directly, so an out-of-range coordinate traps and a duplicate cell
    /// corrupts gravity and `piece(at:)`.
    private func boardCellsAreSane(_ board: [Piece]) -> Bool {
        var seen = Set<Int>()
        for p in board {
            guard (0..<Self.size).contains(p.col), (0..<Self.size).contains(p.row),
                  seen.insert(p.row * Self.size + p.col).inserted else { return false }
        }
        return true
    }

    /// Restored numerics are clamped into ranges the engine's arithmetic can
    /// never overflow from — a tampered or bit-rotted save must not trap on
    /// the next `score += gain` or `movesLeft -= 1`. Bounds sit far above
    /// anything a legitimate run can reach.
    private func sanitizedScore(_ n: Int) -> Int { min(max(0, n), 9_999_999) }
    private func sanitizedMoves(_ n: Int) -> Int { min(max(0, n), 999) }

    #if DEBUG
    /// Staging hook (SIMCTL_CHILD_TIKI_LUAU_SCORE=<n>): fresh board with a
    /// seeded score so every bonfire state can be staged on demand.
    func debugSeedScore(_ n: Int) {
        tutorialActive = false
        newGame()
        score = n
        encoreFired = n >= Self.depthThresholds[2]
    }

    /// Staging hook (SIMCTL_CHILD_TIKI_LUAU_LEVEL=<id>): launch straight
    /// into a campaign level. Returns false if the id isn't in the table
    /// so the caller can fall through to a normal start.
    @discardableResult
    func debugSeedLevel(id: Int, attempt: UInt64 = 1) -> Bool {
        guard let level = LuauLevels.level(id: id) else { return false }
        newLevel(level, attempt: attempt)
        return true
    }

    /// Staging hook (SIMCTL_CHILD_TIKI_LUAU_DEFEAT=1): drive the live level
    /// run straight to OUT OF MOVES so the defeat panel stages on demand.
    /// Mirrors the real latch at settle: moves gone, level lost, streak dead.
    func debugStageDefeat() {
        guard isLevelMode, !isOver else { return }
        movesLeft = 0
        isOver = true
        didWinLevel = false
        nightStreak = 0
    }

    /// Staging hook (SIMCTL_CHILD_TIKI_LUAU_FIRE=<scenario>): arrange the
    /// board so one scripted swap detonates the requested effect; returns
    /// that swap for the view to perform. Guard kinds are planted around
    /// the stage so displaced pieces can't form accidental matches.
    func debugStageFire(_ scenario: String) -> ((col: Int, row: Int), (col: Int, row: Int))? {
        func put(_ col: Int, _ row: Int, _ kind: Int, _ special: Special = .none) {
            if let i = pieces.firstIndex(where: { $0.col == col && $0.row == row }) {
                pieces[i].kind = kind
                pieces[i].special = special
            }
        }
        switch scenario {
        case "torch":
            // Swapping the torch left completes a kind-0 row → lineH fires.
            put(1, 3, 0); put(2, 3, 0); put(3, 3, 1); put(4, 3, 0, .lineH)
            put(3, 2, 2); put(3, 4, 3); put(4, 2, 4); put(4, 4, 5); put(5, 3, 2)
            return ((4, 3), (3, 3))
        case "torchv":
            // Vertical variant: swapping down completes a kind-0 column.
            put(3, 1, 0); put(3, 2, 0); put(3, 3, 1); put(3, 4, 0, .lineV)
            put(2, 3, 2); put(4, 3, 3); put(2, 4, 4); put(4, 4, 5); put(3, 5, 2)
            return ((3, 4), (3, 3))
        case "cat":
            put(3, 3, -1, .cat); put(4, 3, 0)
            return ((3, 3), (4, 3))
        case "cross":
            put(3, 3, 0, .lineH); put(4, 3, 1, .lineV)
            return ((3, 3), (4, 3))
        case "bomb":
            // Swapping the bomb left completes a kind-0 row → 3x3 blast.
            put(1, 3, 0); put(2, 3, 0); put(3, 3, 1); put(4, 3, 0, .bomb)
            put(3, 2, 2); put(3, 4, 3); put(4, 2, 4); put(4, 4, 5); put(5, 3, 2)
            return ((4, 3), (3, 3))
        case "blast":
            put(3, 3, 0, .bomb); put(4, 3, 1, .bomb)
            return ((3, 3), (4, 3))
        case "shockwave":
            put(3, 3, 0, .bomb); put(4, 3, 1, .lineV)
            return ((3, 3), (4, 3))
        case "eruption":
            put(3, 3, -1, .cat); put(4, 3, 2, .bomb)
            return ((3, 3), (4, 3))
        case "storm":
            put(3, 3, -1, .cat); put(4, 3, 2, .lineV)
            return ((3, 3), (4, 3))
        case "cataclysm":
            put(3, 3, -1, .cat); put(4, 3, -1, .cat)
            return ((3, 3), (4, 3))
        case "catmask":
            // Masked-board variant staged on row 0 (full in every shape
            // family's top rows) — pair with TIKI_LUAU_LEVEL.
            put(3, 0, -1, .cat); put(4, 0, 0)
            return ((3, 0), (4, 0))
        case "crossmask":
            put(3, 0, 0, .lineH); put(4, 0, 1, .lineV)
            return ((3, 0), (4, 0))
        default:
            return nil
        }
    }

    /// Staging hook (SIMCTL_CHILD_TIKI_LUAU_SPECIALS=1): plant a row torch,
    /// a cat, and a column torch across the board center — a deterministic
    /// capture surface for the specials' art.
    func debugPlantSpecials() {
        let plants: [(col: Int, row: Int, kind: Int, special: Special)] = [
            (2, 3, 1, .lineH),   // gold plate, beam across
            (3, 3, -1, .cat),
            (4, 3, 3, .lineV),   // teal plate, beam upright
            (5, 3, 0, .bomb),    // coral plate, sun-compass
        ]
        for p in plants {
            if let i = pieces.firstIndex(where: { $0.col == p.col && $0.row == p.row }) {
                pieces[i].kind = p.kind
                pieces[i].special = p.special
            }
        }
    }

    // MARK: test rig — Stage A self-test only

    /// The engine's stored properties are `private(set)`; these DEBUG-only
    /// setters exist so `LuauSelfTest` can construct specific board states
    /// without breaking encapsulation for production callers. Same-file
    /// scope so we can touch storage; never call from view code.
    func testSetKind(_ kind: Int, col: Int, row: Int) {
        if let idx = pieces.firstIndex(where: { $0.col == col && $0.row == row }) {
            pieces[idx].kind = kind
            pieces[idx].special = .none
        }
    }
    func testSetPiece(kind: Int, special: Special, col: Int, row: Int) {
        if let idx = pieces.firstIndex(where: { $0.col == col && $0.row == row }) {
            pieces[idx].kind = kind
            pieces[idx].special = special
        }
    }
    func testSetMovesLeft(_ n: Int) { movesLeft = n }
    func testSetScore(_ n: Int) { score = n }
    func testSetIngredientsCollected(_ n: Int) { ingredientsCollected = n }
    /// Exposes the accept rule so a test can prove a shove is still LEGAL on a
    /// board `hasLegalSwap` now (correctly) calls stuck.
    func canShoveForTest(from a: (col: Int, row: Int), to b: (col: Int, row: Int)) -> Bool {
        guard let ia = pieces.firstIndex(where: { $0.col == a.col && $0.row == a.row }),
              let ib = pieces.firstIndex(where: { $0.col == b.col && $0.row == b.row })
        else { return false }
        return canShove(ia: ia, ib: ib)
    }
    /// Drives the reshuffle path directly — the only way to test that a
    /// shuffle preserves cargo without first engineering a stuck board.
    func testShuffle() { shuffle() }
    func testSetJelly(_ j: [UInt8]) {
        precondition(j.count == LuauLevel.cellCount)
        jelly = j
    }
    #endif
}
