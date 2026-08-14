# PROGRESSION PLAN

*Tiki Games — final synthesized design. 2026-07-09. Built on the LIVING-WORLD skeleton (panel winner), with SHIP-FIRST's zero-schema persistence and implementation blueprint and COLLECTOR's retroactive credit, LAST CALL ceremony, and grant plumbing grafted in per the judges. Successor to `PROGRESSION_RESEARCH.md`; every file/line cited below was re-verified against the repo before writing.*

---

## 0. Design thesis

The five backgrounds stop being wallpaper and become the score display. Each game maps its one honest depth signal — score, highest tier on board, letters locked, cells drafted — onto a small ladder of **named depth states**: the lagoon sinks from golden hour to a bioluminescent night, the bar wall darkens toward volcano watch, the bonfire grows from kindling to inferno. A player who glances at the screen knows how deep this run has gone without reading a number (research principle 1). Every state reached is permanently recorded in a per-game `milestoneMask` and re-expressed as **earned aesthetics**: bottles on the Zombie shelf, constellations in the Blueprints sky, lanterns on the Luau strand, pennants on the Cipher deck, palette tints on the game-picker cards — all derived from state the app already persists, never sold, never given free (principle 4). Each game carries one bounded, player-favorable rule twist welded to its deepest states (principle 2, scoped to what a solo dev can QA before ship; the full per-state twist ladder completes in v1.x). The economy gains six flagship items Carson already owes art for, lifting the spend ceiling 4.5× at launch, with the 3,500-pt Aquarium as the Alto's-wingsuit savings goal whose fish are stocked by cross-game mastery. The 90-second breath survives everywhere at 0.3 amplitude — depth raises the breath's floor, it never replaces the breath. Nothing decays, nothing times out, nothing punishes absence.

---

## 1. The shared plumbing — `ProgressPhase` → backgrounds

**New file: `TikiGames/TikiGames/ProgressPhase.swift` (~55 lines).** The one value a game hands its background. Games compute it; scenes render it.

```swift
/// Game → scene progress signal. Equatable so views cheaply detect changes.
struct ProgressPhase: Equatable {
    var stage: Int = 0        // index into the game's named depth-state ladder
    var depth: Double = 0     // 0...1 continuous ladder position
    var tier: Int = 0         // persistent cross-run mark (bottles, lanterns, pennants, constellations)
    var beat: Int = 0         // increments on clear/merge/cascade/solve — one-shot flourishes
}

/// Frame-exact easing inside TimelineView scenes (Canvas fills can't take
/// implicit animation, so we smoothstep against the clock the scenes already have).
struct DepthDial {
    private(set) var target: Double = 0
    private var previous: Double = 0
    private var changedAt: TimeInterval = 0
    mutating func set(_ v: Double, at t: TimeInterval) {
        guard abs(v - target) > 0.001 else { return }
        previous = eased(at: t); target = v; changedAt = t
    }
    func eased(at t: TimeInterval, duration: Double = 4) -> Double {
        let x = min(1, max(0, (t - changedAt) / duration))
        return previous + (target - previous) * x * x * (3 - 2 * x)
    }
}
```

**Each `*BackgroundView` gains one defaulted property** — `ContentView.swift:20`'s `"lagoon"` preview case, `GamePreview.swift`, and every `#Preview` keep compiling unchanged:

```swift
struct TikiBackgroundView: View {
    var phase: ProgressPhase = ProgressPhase()   // NEW; default = today's behavior exactly
    @State private var dial = DepthDial()
    // TimelineView threads `phase` + eased depth into TikiScene;
    // dial.set(phase.depth, at:) fires in onChange(of: phase.depth).
}
```

**The breath survives — depth raises its floor (verified against `TikiBackgroundView.swift:23`):**

```swift
// was: var dusk: Double { (1 - cos(t * 2 * .pi / 90)) / 2 }
var dusk: Double {
    let breath = (1 - cos(t * 2 * .pi / 90)) / 2
    return min(1, dial.eased(at: t) * 0.7 + breath * 0.3)   // depth anchors, breath keeps 0.3 amplitude
}
```

At `depth == 0` the scene is today's scene with a gentler swing; discrete features (star count, moon vs. sun, firefly count, smoke strands) switch on `phase.stage`; `phase.beat` keys one-shot Canvas flourishes. `TikiScenery.swift`'s `PalmView`/`TorchView` already take `dusk` and inherit depth for free. `reduceMotion` pauses the TimelineView, `t` freezes, and `eased(at:)` holds — no special casing.

**The five call sites (verified):** `TikiStacksView.swift:35`, `ZombieView.swift:55`, `LuauView.swift:42`, `CipherView.swift:31`, `BlueprintsView.swift:30` — each becomes `XBackgroundView(phase: ...)` computed from the `@Observable` engine already in scope, so the phase recomputes automatically. Mappings in §2.

**Persistence (`PlayerStore.swift`):**
- `GameRecord` gains `var milestoneMask: Int = 0` — additive defaulted field, SwiftData lightweight migration. **Mandatory: test upgrade-in-place from the current TestFlight build before ship.** No other schema changes anywhere in Phase 1.
- `func recordMilestone(game: TikiGame, bit: Int) -> Bool` — sets the bit, pays the 75-pt mint exactly once, returns whether it was new (drives the game-over toast).
- `func grant(points: Int)` — the clean bonus path for milestone mints and matchbook bonuses (never route bonuses through `recordRun`; it would pollute `gamesPlayed`/`totalScore`).
- **Retroactive credit pass** on first launch after the update, guarded by a `UserDefaults` one-shot flag (`tikiProgressionRetroCredit`, same pattern as `welcomeGiftClaimed`, idempotent): evaluate `milestoneMask` from existing `bestScore` (Stacks, Luau), `loreSeen` (Zombie payload), `solvedPuzzleIDs.count` (Blueprints payload), `solvedCount / 6` (Cipher payload) and pay the mints. Veterans wake up with their tints, standing, and Sign progress already earned — never make a returning player re-earn demonstrated play.

Estimated plumbing cost: ~55 lines shared + ~10 lines per game view + ~40 lines in `PlayerStore`.

---

## 2. Per-game designs

Shared shape: continuous `depth` drives the eased palette floor; named **states** are where discrete extras switch on and a milestone bit is recorded (first time ever, +75 pts). Thresholds are single constants at each call site — playtest-tunable, not architecture. In-run states reset at game over by design; only the mask persists.

### 2.1 Tiki Stacks — *The Lagoon Deepens* (`TikiBackgroundView.swift`)

Depth signal: `game.score`. `depth = min(1, score/1500)`; `beat` = line-clear counter.

| State | Score | Scene change | Coupled rule |
|---|---|---|---|
| GOLDEN HOUR | 0 | today's scene, breath intact | base rules |
| **DUSK** | 150 | sun sinks to the horizon, deck torches flare, boat lantern lights | — (Phase 2: Ember Grace) |
| **NIGHTFALL** | 400 | sky bands to twilight/ink, star Canvas 18 → 40, fireflies +4 | **Moonlit Sweep** — `cleanSweepBonus` 120 → 240 (`TikiStacksGame.swift:98`); copy: "MOONLIT SWEEP! +240". **Firefly Piece** — one piece per shuffled bag glows; a line clear containing it pays +25 |
| **MOONRISE** | 800 | moon rises where the sun was; sun-glint rows become a silver moonglade | — (Phase 2: Moonglade Row 2× line) |
| **GLOW TIDE** | 1,500 | bioluminescent cyan wavelets in the wave Canvas, fireflies ×2, clears emit glow bursts | firefly pieces: 2 per bag |

**Persists:** milestone bits at 150/400/800/1,500. Once GLOW TIDE is ever reached, a permanent lantern strand hangs on the deck (reuse the Luau strand component) — the deck remembers you've seen night. Picker card tints to the deepest palette ever reached (§3).

### 2.2 Zombie — *The Bar Darkens Toward the Volcano* (`ZombieBackgroundView.swift`)

Depth signal: highest tier currently on the board (monotonic within a run — merges only create higher tiles, so no downgrade logic exists or is needed). `depth = min(1, Double(maxTier - 3) / 8)`; `beat` = merge counter.

| State | Highest tier on board | Scene change | Coupled rule |
|---|---|---|---|
| DAY BAR | ≤ 4 | today's coral breath | spawn 90/10 tier-1/2 (unchanged) |
| **DUSK BLINDS** | 5 | slatted dusk light rakes the wall, candle brightens | — |
| **NIGHT NEON** | 7 | wall locks toward rum, blowfish-lamp glow pool widens, dust motes become slow smoke | — |
| **VOLCANO WATCH** | 9 | ember flecks drift, wall pulses faintly, triple smoke strands | **Doubles After Midnight** — while a tier-8+ tile is on board, tier-2 spawn chance 10% → 20% (one line in `ZombieGame` spawn). Diegetic: "Vic pours doubles after midnight." A late-game kindness, not a spike |
| **THE ZOMBIE** | 11 | eruption glow — the existing win moment made environmental; play continues | — |

**Persists:** the shelf's 12 authored bottle specs render `1 + (game.loreSeen.max() ?? 0)` bottles instead of all 12 — `loreSeen` is already in the save payload (`ZombieGame.swift:44,272`), **zero schema change**. Lifetime best tier = a visibly fuller back bar, the full 12-bottle lineup at THE ZOMBIE. (Known caveat: lore starts at tier 3, so tiers below 3 show the baseline bottle — accepted to avoid schema churn.) Milestone bits at tiers 5/7/9/11. Reaching THE ZOMBIE auto-places a small trophy Zombie mug on the lounge credenza (milestone, never sold). Phase 2: full spawn ladder (88/12 at DUSK BLINDS, 85/15 at NIGHT NEON, 80/15/5 with tier-3 spawns at VOLCANO WATCH).

### 2.3 Luau — *Feed the Bonfire* (`LuauBackgroundView.swift`)

Depth signal: `game.score` (retro-creditable from `bestScore`, unlike a cascade counter). `depth = min(1, score/700)`; `beat` bumps when `game.lastCascade >= 3` (`LuauGame.swift:37,418`), firing a one-shot ember burst from the existing embers layer — cascades visibly feed the fire.

| State | Score | Scene change | Coupled rule |
|---|---|---|---|
| KINDLING | 0 | today's scene | base rules |
| **FLAME** | 150 | fire grows, sparks rise, lanterns brighten | — (Phase 2: cascade multiplier +1 step) |
| **BLAZE** | 400 | dancer silhouettes circle the fire, drums join | — (Phase 2: torch chains) |
| **INFERNO** | 700 | sky ember-tinted, sparks column, fire dominates | **ENCORE** — "the band plays on": +2 bonus moves, once per run, guarded against the tutorial. In a 20-move game, an earned extension lands as an environmental gift |

The fire never shrinks within a run — cascades only feed it; the 90-second breath supplies the flicker.

**Persists:** lantern count on the existing strand (`LuauBackgroundView.swift:230`) = `3 + bestScore/150`, capped at 9 — your best run hangs more lights at every future luau. Milestone bits at 150/400/700.

### 2.4 Cabana Cipher — *Golden Hour Arrives As You Solve* (`CipherBackgroundView.swift`)

Depth signal: `depth = solvedLetters / uniqueCipherLetters` — the poolside afternoon drifts to golden hour exactly as the phrase completes. Solving IS the sunset. No thresholds needed; the ladder is the phrase itself. `beat` fires on each locked letter.

**Coupled rule — CLEAN STRIKE:** finishing a phrase with 0 mistakes and 0 hints strikes a match on the table (visual beat) and adds +15 to `completionScore`, landing at the golden-hour peak.

**Persists — the matchbook spine (zero new storage):** phrases advance linearly, so `completedBooks = game.solvedCount / 6`. Each completed book:
- fires a "MATCHBOOK COMPLETE — {NAME}" banner and pays **+100 pts** via `store.grant(points:)`;
- hangs one pennant flag on a string across the existing `farDeck` (`CipherBackgroundView.swift:152`) — 16 colored triangles, one per book, permanent.

Milestone bits at 1/4/8/16 books.

**The loop, acknowledged — LAST CALL:** at phrase 96 the game currently loops silently. Replace with the full-screen matchbook-wall ceremony — all 16 struck covers, then Vic: "LAST CALL... second round, house shuffle." No re-derivation work needed: `buildMapping` seeds from the raw un-wrapped `phraseIndex` (`CipherGame.swift:226`), so round-two ciphers are already fresh. Looped phrases pay ¼ (matching the Blueprints replay precedent) — **this nerf ships in the same build as the +100 book bonuses, never before them** (net: the 96-phrase devotee comes out +1,600 ahead).

### 2.5 Blueprints — *The Sky Fills With What You've Drafted* (`BlueprintsBackgroundView.swift`)

Depth signal: `depth = correctlyFilledTrueCells / totalTrueCells` — the moon-glow and desk-lamp warmth rise as the reveal approaches; a quiet, glanceable "almost there." `beat` fires on solve, triggering the existing shooting-star layer. No mid-puzzle spectacle — nonogram purity.

**Coupled rule — FAIR COPY:** solving in DRAFT mode with 0 mistakes stamps the sheet with a gold seal (a `fairCopyIDs` set added to the game's JSON payload — payload change, not a schema migration) and pays **3×** first-solve instead of DRAFT's 2×. Thirty seals give the finite set a second mastery lap without authoring content.

**Persists — the flagship reuse:** the scene's existing `constellations` layer (`BlueprintsBackgroundView.swift:98` — star clusters joined into pixel-pictures, already a nod to nonogram reveals) gates on the collection: render `solvedPuzzleIDs.count / 3` constellation groups. Every three drafts hangs a new picture in the sky, permanently. Highest felt-progress-per-line item in the plan — the layer exists, the data exists. Milestone bits at 5/15/30 solved.

**Finite-content answer (Phase 2):** *Vic's Commissions* — 12 new 10×10 puzzles unlocked by earning 15 Fair Copy seals (demonstrated mastery, principle 4).

---

## 3. Cross-game milestones & collections

**One shared spine: `GameRecord.milestoneMask`.** 18 milestone bits total — Stacks 4 + Zombie 4 + Luau 3 + Blueprints 3 + Cipher 4. Each first reach pays a **+75-pt mint** ("Vic buys a round") — 1,350 pts lifetime — and shows one line on the game-over toast.

**House Standing** — named tiers from total milestone count, displayed quietly on the Home header and nowhere else. Diegetic bar-standing names (the DIRECTOR's tone call — no "Tourist/Legend" system-speak):

| Standing | Milestones | Earns (free, never sold) |
|---|---|---|
| WALK-IN | 0–4 | — |
| REGULAR | 5–9 | Phase 2: the cat naps on the credenza |
| ISLANDER | 10–14 | Phase 2: occasional soft rain on the Sunset Window |
| NAME ON THE DOOR | 15–18 | Phase 2: lounge night-mode toggle |

**Picker-card tint** (`GamePickerView.swift`): each game's card renders in the palette of the deepest state ever reached — the picker becomes a quiet trophy row of "how deep have I ever gone," per game. (S — reads `milestoneMask`.)

**The one gated purchase:** the **Neon Tiki Sign** (2,200 pts) unlocks in the shop only after the *first* milestone bit in each of the five games (Stacks 150 / Zombie tier 5 / Luau 150 / Blueprints 5 drafted / Cipher 1 book — deliberately modest). The locked shop row shows flavor copy — "VIC SAVES THIS FOR REGULARS" — plus the shortest unmet requirement ("DRAFT 2 MORE BLUEPRINTS"). It gates on play, never payment; every other item is wallet-only, so no one is starved of sinks. Owning the Sign says *I've been everywhere in this bundle*.

**In-scene collections stay in their scenes** (no ledger UI, no postcard rack — the marks ARE the collection): Zombie's bottle shelf, Cipher's pennant string, Blueprints' constellation sky, Luau's lantern strand, Stacks' night-deck lanterns, plus the existing lore cards and matchbook names.

**Slow-cycle ambient surprises (Phase 2, all S, principle 7 — absence never punished):** the **green flash** (~1-in-20 DUSK transitions in the lagoon), **Vic's Comet** (~1-in-30 night-state runs in any game with a sky), the catamaran rarely being a **cat in a rowboat**, the Sunset Window's moon following the **real lunar calendar** (~20 lines, date-computed), and the purchased **parrot occasionally squawking a fragment of a cipher phrase the player actually solved** — cross-game memory, diegetically, at near-zero cost.

---

## 4. Economy retune

**Current faucets (verified):** `recordRun` pays `max(1, (earnScore ?? score)/10)` (`PlayerStore.swift:186`). Effective: Stacks score/10 (`TikiStacksView.swift:99`), Zombie score/100 (`ZombieView.swift:316–317`), Luau score/30 (`LuauView.swift:263–264`), Cipher completionScore/10 (`CipherView.swift:240`), Blueprints score/10 first-solve then ¼ (`BlueprintsView.swift:196–199`). A decent mixed session earns ~40–150 pts. **Divisors are untouched** — no earn inflation, FTUE arc preserved.

**Current ceiling:** 13 items, 2,830 pts of real spend (Flaming Mug is the free gift). Hit in ~6–8 hours, then points are inert (Gap C).

**Six new catalog rows — all art Carson already owes** — appended to `syncLoungeCatalog()` (`PlayerStore.swift:306`, upserts safely every launch, prices retunable post-ship without migration), plus one anchor each in `LoungeView.swift` and sprites in the lounge sprite set:

| Item | Price | Gate | Notes |
|---|---|---|---|
| Bar Stools (pair) | 650 | wallet only | floor zone, by the bar |
| Ceiling Fan | 800 | wallet only | hanging layer, slow spin (reuse the spinning-disc pattern) |
| The Marlin | 1,200 | wallet only | wall trophy above the window |
| Parrot | 1,600 | wallet only | back-bar perch; Phase 2: squawks solved cipher fragments |
| Neon Tiki Sign | 2,200 | **milestone-locked** (§3) | flicker via the candle trick; Phase 2: night-mode toggle for owners |
| **The Aquarium** | **3,500** | wallet only | **flagship savings goal** — ships with 1 fish; each game whose *top* depth state has ever been reached adds a species, to 5 fish. Stocking it is play, not payment |

**Ceiling math:** new sinks 9,950 → total real spend **12,780 pts (4.5×)** — roughly 30+ hours of runway at current rates, honest multi-week savings arcs, all shipping in v1.0. New faucets: milestone mints +1,350 and matchbook bonuses +1,600 (both one-time, lifetime cap +2,950) fund roughly one mid-tier item and keep mid-game pacing honest. One free earned trophy (Zombie mug) is a milestone, never sold. "THE ROOM IS COMPLETE" now lands ~4.5× later; Phase 2's Back Room wing (2,000-pt door + ~1,800 pts of items, 6 new anchors) pushes the eventual ceiling toward ~16,500 — and item 22 below exists because a ceiling is still a ceiling.

---

## 5. Scope phasing

Phase 1 = v1.0 (highest felt-reward-per-effort, bounded QA surface); Phase 2 = v1.x. Effort: S ≤ half-day, M ≈ 1–2 days, L ≈ 3+ days.

| # | Item | Phase | Effort |
|---|---|---|---|
| 1 | `ProgressPhase.swift` + `DepthDial`; defaulted `phase` param threaded into all 5 background views | 1 | S |
| 2 | Breath floor-lift blend (0.7/0.3) in all 5 scenes | 1 | S |
| 3 | Five call-site phase mappings (verified lines, §1) | 1 | S |
| 4 | `GameRecord.milestoneMask` + `recordMilestone` + `grant(points:)` + 75-pt mints + game-over toast line | 1 | S |
| 5 | Retroactive credit pass (one-shot flag) + **upgrade-in-place migration test from current TestFlight build** | 1 | S |
| 6 | Stacks: 4 named states + Moonlit Sweep ×2 + Firefly Piece + permanent deck lanterns | 1 | M |
| 7 | Zombie: 4 wall states + Doubles After Midnight + shelf bottles = `1 + bestLoreTier` | 1 | M |
| 8 | Luau: 3 fire states + cascade ember beat + ENCORE (+tutorial guard) + lantern strand = `3 + bestScore/150` | 1 | M |
| 9 | Cipher: solve-fraction golden hour + CLEAN STRIKE + matchbook banner/+100/pennants + LAST CALL ceremony + ¼-pay-on-loop (ships together) | 1 | M |
| 10 | Blueprints: fill-fraction warmth + shooting-star-on-solve + constellations = `solvedCount/3` + Fair Copy seals (payload) 3× | 1 | M |
| 11 | Picker-card tint from deepest state ever (`GamePickerView.swift`) | 1 | S |
| 12 | House Standing names on Home header | 1 | S |
| 13 | Six catalog rows + lounge anchors + milestone-locked Sign shop row with unmet-requirement copy | 1 | M |
| 14 | Six item sprites (stools, fan, marlin, parrot, sign, aquarium) — art already owed | 1 | L (art) |
| 15 | Aquarium fish = 1 + count of games at top state (reads `milestoneMask`) | 1 | S |
| 16 | Zombie trophy mug auto-placed at tier 11 | 1 | S |
| 17 | Regression pass: engine tests, depth-0 visual identity, previews compile, `reduceMotion` | 1 | S |
| 18 | Per-state twist completion: Ember Grace + Moonglade Row (Stacks), full Zombie spawn ladder w/ tier-3 spawns, Luau cascade extension + torch chains | 2 | M |
| 19 | Ambient rarities: green flash, Vic's Comet, rowboat cat, lunar-phase Sunset Window | 2 | S each |
| 20 | Standing ambience (cat nap / rain / night toggle) + Sign night-mode for owners + parrot cipher squawk | 2 | M |
| 21 | Blueprints *Vic's Commissions* (12 new 10×10s gated on 15 Fair Copies) + Cipher Night Shift mode | 2 | M each |
| 22 | The Back Room wing (2,000-pt door, 6 anchors, ~1,800 pts of items) + post-completion prestige design | 2 | L |

Phase 1 code ≈ 6–9 dev-days plus the already-committed art: one S plumbing layer, five M per-game passes on files that already exist, one M shop pass, exactly one lightweight migration, and five bounded player-favorable rule changes (Moonlit Sweep, Firefly Piece, Doubles After Midnight, ENCORE, CLEAN STRIKE, Fair Copy — all additive to score or spawn odds, none touching core loop legality).

---

## 6. PROGRESSION_RUBRIC dimensions (for the implementation loop)

Grade each 1–10 per game per iteration; ship bar = no dimension below 8.

1. **Glanceability** — mid-run, eyes on the scene only: can you name how deep this run is? Do state transitions read within 4 s without being watched for?
2. **Breath fidelity** — is the 90-second breath alive in every state (≥0.3 amplitude)? Is `depth == 0` visually indistinguishable from the shipped v0 scene?
3. **Mechanical honesty** — does every Phase 1 game carry at least one live rule twist welded to a visible state? Is every twist player-favorable and bounded?
4. **Earned-ness** — is every persistent mark traceable to demonstrated play (a specific bestScore/tier/count)? Nothing free, nothing sold, retro-credit correct for veterans?
5. **Pacing** — does the *median* run reach state 1 and a good run reach state 2? No milestone droughts > ~3 sessions early, no showers (> 2 milestones per run routinely)?
6. **Economy horizon** — after any purchase, is there both an affordable next want (< 2 sessions away) and a flagship want (> 2 weeks away)? Do mint/bonus faucets stay < 25% of lifetime earnings?
7. **Tone** — warm, unhurried, vacation-at-dusk: is every name and copy line diegetic (Vic's voice, no system-speak)? Would the DIRECTOR call any element a meter wearing a tiki shirt?
8. **Ethical cleanliness** — nothing punishes absence; no decay, timers, streak loss; nerfs never ship before their paired bonuses.
9. **Regression safety** — engine tests pass, all previews compile, SwiftData upgrade-in-place verified, `reduceMotion` behavior unchanged, ENCORE cannot fire in tutorial.

---

## 7. Risks & open playtest questions

1. **Every threshold is theory-grounded guesswork** (research open question 3). 150/400/800/1,500 (Stacks), tiers 5/7/9/11 (Zombie), 150/400/700 (Luau) come from scoring math, not telemetry. They are single constants per call site; budget one rubric-iteration pass. **Playtest question: does the median run reach state 1, and a good run state 2?** If a strong player outruns the ladder in 5 minutes or a casual one never leaves GOLDEN HOUR, retune before Phase 2 prices are locked.
2. **Five scoring/spawn changes land pre-ship.** All are additive and bounded, but they shift best-score comparability and need a regression pass per engine (rubric dim 9). ENCORE needs its tutorial guard tested explicitly.
3. **One SwiftData lightweight migration** (`milestoneMask`, defaulted). Safe by the book, but `PlayerStore`'s container has no versioned schema — the upgrade-in-place test from the live TestFlight build (item 5/17) is non-negotiable, and the retroactive pass must stay idempotent behind its one-shot flag or a bad launch double-pays 1,350 pts.
4. **`loreSeen.max()` as best-tier proxy** only registers tiers ≥ 3. Accepted deliberately over schema churn days before ship; below tier 3 the shelf shows the baseline bottle.
5. **The ¼-pay Cipher loop nerf must ship in the same build as the +100 book bonuses** — sequenced wrong, it's a pure nerf to the most devoted player.
6. **Phase 1 ships some visual-only states** (DUSK, MOONRISE, DUSK BLINDS, NIGHT NEON, FLAME, BLAZE) — a deliberate, named scope decision resolving the winning proposal's overload: one twist per game at v1.0, per-state twists completing in v1.x (item 18). This is a temporary, scheduled exception to principle 2, not a forgotten one.
7. **Milestone-locking the Sign** may annoy a single-game devotee; its five requirements are the first rung in each game and every other item is wallet-only. **Playtest question (research OQ4): does the shared spine dilute per-game competence feedback?** Watch whether game-over toasts or the Home standing read as the reward center.
8. **Does the decoration meta transfer to premium?** (research OQ2). The 3,500-pt Aquarium is the bet; `syncLoungeCatalog()` retunes unpurchased prices on launch, so repricing post-ship needs no migration. Watch wallets: if players stall > 2 weeks below 50% of a flagship, prices are too high.
9. **12,780 is still a ceiling.** It buys ~30 hours of runway, not infinite retention — Phase 2 items 21–22 (new puzzles, Night Shift, Back Room, prestige) exist because this plan does not pretend otherwise.

---

*Implementation order: items 1–5 (plumbing + persistence) first — everything else hangs off them; then 6–10 one game at a time, each closing with rubric dims 1–3 + 9; then 11–17. Key files: `ProgressPhase.swift` (new), `PlayerStore.swift`, the five `*BackgroundView.swift` + `TikiScenery.swift`, the five `*View.swift` call sites, `GamePickerView.swift`, `LoungeView.swift`.*