# Luau area special — the L/T bomb (revival plan)

Status: **COMPLETE 2026-08-01 (Phases 1–6).** The three items left open
after the first ship are all closed — see PHASE 6 (balance, measured),
PHASE 4 TAIL (FX rubric, graded A), and PHASE 5 TAIL (corner lesson,
shipped) below.

### PHASE 6 — BALANCE, MEASURED (closed, no action needed)

Controlled A/B, not a guess: LevelForge built at `d7af236` (pre-bomb)
and at HEAD, `compare 1 200 200` on both — same 200 levels, same bot,
same seeds, 200 attempts per policy per level.

| policy | pre | post | mean drift |
|---|---|---|---|
| greedy (the policy every budget was solved against) | 68.0% | 68.8% | **+0.82pp** |
| strong (skilled play) | 76.9% | 78.4% | **+1.52pp** |

The plan's own rule was ">~5pp on the tuned band → compensate". Drift is
a sixth of that, and it is UPWARD — the campaign got very slightly
easier, as expected when a new special enters. **No compensation.**

Individual movers were checked rather than trusted: at 200 attempts the
noise floor is ±3.5pp, so the six levels that moved >5pp were re-run at
400. Two apparent regressions evaporated — L109 and L182 "crossed below
50%" only in the noisy run; measured, both were ALREADY below 50%
pre-bomb (46.0%, 48.2%) and both went UP. The one real decline is L134
(61.0% → 55.5%), which lands comfortably above the campaign's hard end
(L147 is 31%). Real gains: L172 +6.2pp, L155 +7.5pp.

Known limitation, stated rather than hidden: **both bots are blind to
the bomb** — `LuauBot` scores corner shapes at zero and never aims for
one, and the tool-side `StrongBot` likewise. So these numbers measure
the drift a player gets from the rule change *without* anyone hunting
corners; a player who deliberately builds them does better than
+0.82pp. `LuauBot` was deliberately NOT taught the bomb: it is both the
shipped autoplay and the reference policy all 200 budgets were solved
against, so changing it would invalidate the very baseline this
measurement rests on.

### PHASE 4 TAIL — FX RUBRIC (closed, graded A)

Two rounds against `LUAU_SPECIALS_FX_RUBRIC.md`, logged there in full.
v1 scored 9.06 (A−) — under the 9.3 bar on two honest counts: shockwave
ran traveling heads down the centre lanes only, and solo BOMB vs DOUBLE
BLAST shared one visual language separated only by scale. v2 fixed both
(every lane gets its own head; the 5x5 wears a second thin trailing
ring keyed on `blastReach() > 2`) and scores **9.31 — passes, no
dimension below 8**. Reduce Motion is code-verified rather than
frame-verified: `if !reduceMotion { agents }` wraps the whole per-kind
switch, so a new FireKind cannot bypass it.

### PHASE 5 TAIL — THE CORNER LESSON (shipped)

`cornerLesson` (id 903), inserted **before Night 8** — early, unlike
cargo's Night 42, because a bomb can spawn on Night 1 and a lesson
behind the player's frontier is invisible to them. Seed searched over
20k candidates for a quiet board whose ONLY bomb-minting swap is one
move, and the sand sits on exactly the five cells of the corner it
teaches — so the objective literally draws the L the player must make.
Pinned by `cornerLessonMintsABombInASingleSwap`.

---

Original status line: **IMPLEMENTED 2026-08-01 (Phases 1–5).** Carson picked the
sun-compass; engine + detection + combos + art + copy are in and gated:
560 tests / 91 suites green, sun-compass verified rendering in-app
beside its siblings, fire show captured on video (windup → shock ring →
staggered pops), and a cascade organically minted a bomb during the
capture — the corner earn works in live play. The old spawn economics
paid an accidental TWO TORCHES for an H4+V4; fixture 1002's seed was a
pathological loser under the new rule and was re-measured (254/256
seeds win; see LuauLevels.swift). Remaining: the FX-rubric judging pass
for the bomb's show (Phase 4 tail), the optional lesson night (Phase
5), and the Phase 6 fun-audit re-measure across the campaign.
History below is preserved as written. §2 resolved 2026-07-31 — the
kill was the ART, not the mechanic.

## 1. The history this plan lives inside

This game already had an area bomb. It lived for two and a half hours on
2026-07-25:

| When (07-25) | Commit | What |
|---|---|---|
| 17:06 | `e072c84` | Bomb added — **earned by the 2x2 square**, 3x3 blast when matched |
| 18:49 | `e9ac727` | **Carson's own bomb art** replaces the placeholder |
| 19:0x | `62c71fc` | Chained detonation (kept to this day) + three bomb combos |
| 19:1x | `f6d8dbf`, `dedc88a` | Colour plate, glyph sizing |
| 19:26 | `17edbd9` | **"Remove the bomb. Carson doesn't want it."** |

What survived the kill and is live in today's engine: transitive chained
detonation, `detonationPlan` as the single source of destroy+show truth,
and a save-format shim that decodes the retired `"bomb"` raw value as a
plain piece so bomb-era saves never destroy campaign progress.

## 2. The question that gates everything

The removal commit records the verdict but not the reason. Two readings:

- **(a) The earn rule was wrong.** Squares are the cheapest shape in the
  game — they form constantly, by accident, so square-earned bombs made
  specials rain. The bomb itself was fine; its faucet was broken.
- **(b) The bomb concept was wrong** — one special too many, wrong feel,
  wrong noise, regardless of how it's earned.

**ANSWERED — it was neither. Carson, 2026-07-31: "probably the art
style, i thought it looked ugly."** The mechanic was never on trial; the
asset was. Consequences: the mechanics revive wholesale; the L/T earn
still replaces the square earn on the frequency argument (§3), which
stands on its own genre logic; the old asset is DISQUALIFIED as a
deliverable and survives in git only as a what-not-to-do reference; and
Phase 4 is now the critical path — the one thing that killed v1 is the
one thing v2 must get right before it ships.

## 3. What v2 changes — the earn rule, and only the earn rule

| | v1 (killed) | v2 (this plan) |
|---|---|---|
| Earned by | 2x2 square | **L or T of 5+ (corner shape)** |
| Square pays | a bomb | **nothing — unchanged from today** |
| Fire | 3x3 when its cell clears | same |
| Combos | shockwave / blast / eruption | same three, resurrected |
| Art | cannonball + fuse (killed the feature) | **redrawn from scratch — brief in Phase 4** |

Frequency math: a square needs four pieces in the cheapest arrangement the
board offers. An L/T needs **two perpendicular 3-runs completed by one
swap** — rarity comparable to the straight-5 that mints the cat, the
game's rarest earn. This is also the Candy Crush ladder exactly: 4-line =
line blast (torch ✓), L/T = area blast (missing), 5-line = colour wipe
(cat ✓). Our torch even fires perpendicular to its run, matching CC's
stripe convention — the ladder is already two-thirds theirs.

Optional pre-ship measurement: instrument LuauBot runs (LevelForge recipe
in the fun audit) to count bomb earns per run and confirm the rarity claim
with a number instead of an argument.

## 4. Player-facing rules

### Detection

A **corner shape**: one row-run (≥3) and one column-run (≥3) of the same
kind sharing exactly one cell, total distinct cells ≥5. This covers every
L rotation (corner at the end of both runs), every T rotation (corner
mid-run of one), and the + (corner mid-run of both).

Priority, resolved per shape, biggest first — Candy Crush convention:

1. A straight run of ≥5 mints a **cat** and consumes that run (as today).
2. Remaining runs pair into corner shapes → **bomb** at the corner.
   Each run pairs at most once; largest union first, deterministically.
3. Remaining straight 4s → **torch** (as today).
4. Squares never participate in any of this and never spawn (as today).

Edge cases pinned by tests, not prose: an L with a 5-long arm pays a cat
only (the 3-arm just clears); a 4+4 L pays one bomb and zero torches; a
double-T sharing one long row pays one bomb plus whatever the leftover
vertical earns on its own length; a 3x2 block is still two squares + two
3-runs = plain clear.

### Placement

`spawnCell`'s existing intent rule: the cell the player swapped into, if
it's part of the shape; otherwise the corner cell (the natural "elbow" —
also where CC puts the wrapped on cascades). Cascade-formed shapes use the
corner.

### Firing

The bomb carries its match's colour, like a torch, and fires **when its
cell clears** — matched in a run, swept by a torch lane, caught in a cat
wipe, or hit by another bomb. The blast is a 3x3 centered on its cell,
clipped by board edge and mask; cargo is immune (`clearablePieces`, same
as every other blast). It chains transitively through the existing
fixed-point machinery — `detonationPlan` gets its `.bomb` case back, and
`chainTorches` grows one (and probably the name `chainSpecials`).

**No double blast.** CC's wrapped explodes a second time after it falls.
Parked deliberately: it needs a live "spent bomb" remnant to survive one
resolve round (stepped-resolver + save-format complexity), and our 3x3 on
a 7x7 board is already proportionally bigger than CC's 3x3 on 9x9.
Revisit only if the single blast feels thin in hand.

### Combos — v1's table, resurrected verbatim

Swapping the bomb into another special (all mirrored in
`previewSwapFires`; chained bystanders fire, per the b680313-era rule):

| Pairing | Name (v1) | Effect | perPiece |
|---|---|---|---|
| bomb + torch | **SHOCKWAVE** | three full rows AND three full columns through the bomb | 20 |
| bomb + bomb | **BLAST** | 5x5 at the swap | 20 |
| bomb + cat | **ERUPTION** | wipe the bomb's colour + 5x5 where it sat | 25 |

Existing three (cross 15 / storm 25 / cataclysm 20) unchanged. Cell-count
ladder on 7x7: solo bomb 9 < cross 13 < storm ~20 < blast 25 < shockwave
~33 < cataclysm 49. Banner strings need Carson's ear (§9).

### Scoring

Solo bomb fires score through the existing `registerClear` path with
cascade multipliers, like triggered torches. Combos per the table.

## 5. Engine plan — phased, each phase verified

- **Phase 0 — Carson gate.** ~~Answer §2~~ (done: the art). Remaining:
  pick the glyph motif from the Phase 4 brief and settle names (§9).
- **Phase 1 — Resurrect the special, minus its old faucet.** Hand-restore
  from `e072c84` + `62c71fc` + `f6d8dbf`: the enum case (raw value
  `"bomb"` — see §6), `blastPieces`, the `.bomb` detonate case, chain
  case, FX kinds, combo switch, solver scoring. Square spawn stays dead.
  Verify: suite green; new tests for blast clipping, chaining both
  directions (torch→bomb, bomb→torch), cat-wipe sweeping a bomb.
- **Phase 2 — L/T detection (the genuinely new engineering).** A merge
  pass over `findMatches`' runs before the spawn loop: same-kind
  row×column pairs sharing one cell → corner matches; priority ordering
  of §4. Verify: rotation battery (4 Ls, 4 Ts, +), edge-case battery,
  every existing straight-4/5/square test untouched.
- **Phase 3 — Swap-path parity.** `performComboSwap` + `previewSwapFires`
  cases; preview-mirrors-engine tests for all three combos.
- **Phase 4 — Art + FX. THE CRITICAL PATH — art is what killed v1.**

  *Post-mortem of the dead asset* (`git show
  e9ac727:assets/game/luau/luau-piece-special-bomb.svg`, rendered and
  examined 2026-07-31). It was a literal cartoon cannonball: near-black
  ball (`#1C120A`), brown fuse arcing out of a collar, flame at the tip,
  gold 8-spike starburst with a red octagon core. Why it read ugly in
  this set:
  1. **A circle in a game of rounded squares.** Every piece — including
     the cat special — is a flat rounded-square PLATE filling the cell.
     The bomb was a floating ball with appendages; it abandoned the one
     silhouette convention the whole board obeys.
  2. **A skeuomorphic object in a set of flat emblems.** Fuse + flame +
     ball is generic match-3 clip-art; the set's language is hard-edged
     glyph-on-plate. (Same "wrong language" critique the frond commit
     made about the point-cloud plant.)
  3. **Busy at 53pt:** spikes + octagon + fuse + flame — four ideas in
     one cell. `e9ac727` judged it "reads well" by compositing it into
     a screenshot; distinct-from-the-set was optimized into
     alien-to-the-set.

  *Brief for the redraw:* rounded-square colour plate showing its kind
  exactly as the torch does; ONE flat, hard-edged glyph that radiates
  (says AREA without being taught); tiki-themed motif, not ordnance —
  candidates: pahu **drum** with shock arcs, **firework**, **puffer
  fish** (inflates = area, very lagoon), **lava ember**, fire bowl.
  Produce 3–4 SVG candidates, composite each into a REAL board
  screenshot at actual cell size, panel-grade against the set's style
  rules (house rubric method), Carson picks. No asset ships judged in
  isolation — that is how v1 died.

  **PANEL RAN 2026-07-31.** Corrections the masters forced on the brief:
  the torch does NOT wear a kind-coloured plate in its asset — specials
  are a plate-less glyph over a dark inner panel (18,16,60x62 rx12 ink
  @0.85), composited by LuauPieceView onto a code-drawn kind plate at
  cell size, marked by a glow ring. Candidates were built in that exact
  asset form and composited into a live board beside the planted torch +
  cat (TIKI_LUAU_SPECIALS=1). Three independent judges (player /
  art-director / legibility lenses) + one adversarial pass:

  - **DRUM** (6.8/5.2/4.8): killed — object-not-emblem (the cannonball
    sin), lateral-only radiation, shatters at 40px, tick marks collide
    with the torch's dash language.
  - **BURST v1** (8.5/8.7/8.8): best 40px machine, unanimous flaw:
    stock match-3 star, "rents its clarity from other games."
  - **PUFFER** (8.7/8.0/6.8): documented runner-up — wins theme and
    charm, but three independent strikes: a second creature face
    collides with the cat's category; its area signal (the spikes) is
    the first thing to die at 40px; and at squint its pale-ball-plus-
    gold-nubs-on-coral signature converges with the HIBISCUS piece.
  - **EMBER** (5.8/5.3/4.5): killed — reads as a wheel at every size;
    any radial veins inside a closed silhouette do.
  - **WINNER: SUN-COMPASS (burst v3).** v2 tiki-fied the star (carved
    cardinal grooves, wavefront arcs) and was REFUTED by the adversarial
    judge on measured 40px evidence: hollow carves inverted the ray
    hierarchy; four short diagonal arcs read as viewfinder brackets.
    v3 built to the prescription — solid cardinals r=36 with a short
    inner slit (walls ≥3u), 60° cream arcs centered on the cardinals
    (240° arc > 120° gap, so the ring propagates), long rays piercing
    the wavefront. **ADVERSARIAL RE-VERDICT: refuted=false — SHIPS.**
    Measured: cardinal dominance 2.64 at 40px (v2 was 0.20 inverted),
    ring reads as pierced wavefront not brackets, pass bar holds
    (dimension 3 at 8, rest ≥9). Judge beat v1 on five of six
    dimensions and declared the puffer question moot. Its one free
    insurance move — ring 4.5u→6u so the squint renders ~2.5px arcs —
    is applied as **v4, the recommended master**
    (`bomb-c2v4-suncompass.svg`). Judge's measurement artifacts in
    `panel/adv/`.

  Files (durable, in-repo, uncommitted): winner master
  `assets/game/luau/luau-piece-special-bomb-suncompass-DRAFT.svg`,
  runner-up `…-bomb-puffer-RUNNERUP.svg`, evidence sheet
  `TikiGames/luau-bomb-art-panel.png`. (Full versioned trail v1→v4 +
  rubric + composites lived in the session scratchpad `panel/`, which
  dies with the session — the three files above are the keepers.) At
  implementation the winner is renamed `luau-piece-special-bomb.svg`,
  gets its asset-form derivative in `LuauAssets`, and the DRAFT/
  RUNNERUP files are removed.

  *Found in passing:* the proposed coral glow ring is INVISIBLE on the
  coral (hibiscus-kind) plate — coral-on-coral. Glow colour must be
  cream (gold is the torch's, twilight the cat's).

  FX show judged against
  `LUAU_SPECIALS_FX_RUBRIC.md` exactly as torch/cat were: causality drawn
  (shockwave ring reaches every cell before it pops), radial stagger
  15–45ms/cell, 100–250ms anticipation swell on the bomb, ≥3 channels,
  ≤600ms solo / ≤1.5s combos, reduce-motion path. Extend `TIKI_LUAU_FIRE`
  staging scenarios (`bomb`, `shockwave`, `blast`, `eruption`) and grade
  from frame dumps, no score without a frame.
- **Phase 5 — Copy + onboarding.** How-to sheet gains the bomb line; the
  scripted first-run ladder does NOT teach it, so v1's `tutorialActive`
  suppression stays. An inserted lesson night (the `insertedLessons` +
  `LuauLessonBanner.teaches` mechanism the coconut already uses) is the
  right vehicle — **fast-follow, not v1**, pending §9.
- **Phase 6 — Balance.** LuauBot learns corner shapes are worth making
  (v1 solver scoring resurrects, reweighted for the rarer earn). Re-run
  the fun audit (LevelForge, campaign-stats) over a sampled band of the
  tuned curve. Expected drift: up, but small — the earn is rare and
  deliberate. Decision rule: >~5pp win-rate drift on the tuned band →
  compensate (e.g. corner shapes only mint from the swapped round, not
  cascades — CC does this too — or targeted moves-budget touch-ups, the
  `cargoExtraMoves` precedent).

## 6. Save compatibility

Re-adding `case bomb = "bomb"` makes `Special(rawValue:)` succeed again,
so the retired-value shim goes dead for that string: remove `"bomb"` from
`Special.retired`, keep the corruption contract intact
(`corruptSpecialRawValueRejectsWholePayload` unchanged). Rewrite
`retiredSpecialRawValueStillLoadsTheSave` to pin the new truth: a
bomb-era save now loads its bombs LIVE — harmless, they were
square-earned but they fire identically. Downgrade path, CORRECTED by
the review panel: builds 5–10 carry the retired-value shim (it shipped
2026-07-25) and decode a v2 save's bombs as plain pieces — safe. Build 4
and older PREDATE the shim: `"bomb"` throws, the whole payload fails,
and restore answers with `newGame()` — that save's run AND campaign
progress are lost. Accepted: nobody should install a superseded
TestFlight binary, and the write side cannot make a new special
decodable by a build that never knew the mechanism. v1's funeral
arrangements protect its own resurrection everywhere the mechanism
exists.

## 7. Test plan (~20 new)

Detection: `anLOfFivePaysABombAtTheCorner` (x4 rotations collapsed to a
parameterized test), `aTOfFivePaysABombAtTheCorner` (x4),
`aPlusPaysOneBomb`, `aStraightFiveStillPaysACatNotABomb`,
`anLWithAFiveArmPaysOnlyTheCat`, `aFourPlusFourLPaysOneBombNoTorches`,
`aDoubleTPaysOneBombDeterministically`, `squaresStillPayNothing`,
`aCascadeFormedCornerSpawnsAtTheCorner`,
`aSwappedCornerSpawnsOnTheSwapCell`.
Firing: `aBombClearsItsThreeByThree`, `theBlastClipsAtEdgesAndMask`,
`cargoSurvivesTheBlast`, `aTorchLaneDetonatesABombWhichDetonatesATorch`,
`aCatWipeDetonatesABombOfTheWipedColour`.
Combos: `shockwaveClearsThreeRowsAndColumns`, `blastClearsFiveByFive`,
`eruptionWipesColourPlusArea`, each with perPiece + banner + origin, plus
`previewMirrorsEveryBombCombo`.
Persistence: bomb round-trips a save; downgrade shim documented above.
Liveness: `hasLegalSwap` counts bomb×special adjacency (already generic);
shuffle keeps the bomb's cell.

## 8. What we copy from Candy Crush, and what we deliberately don't

Copy: the geometry ladder (line/area/colour), bigger-shape-wins priority,
intent-based placement, colour-carrying area special that fires when
cleared. Skip: the double blast (§4), the colourless wrapped body (our
art solved area-readability with the starburst — `e9ac727`'s notes),
CB+wrapped's two-wave wipe (our ERUPTION is single-step and already
scored hotter than cataclysm per piece).

## 9. Open questions for Carson

1. ~~**The §2 question.**~~ ANSWERED 2026-07-31: the art. Mechanic
   unblocked; art redrawn from scratch (Phase 4 brief).
2. **Glyph motif:** PANEL RAN (Phase 4 log). Recommendation: the
   **sun-compass** (burst v3). Documented runner-up if charm should win
   over clarity: the **puffer**, with its three strikes listed. Carson's
   eyes decide.
3. **Names/banners:** keep v1's SHOCKWAVE / BLAST / ERUPTION, or retheme
   to match the chosen motif — internal raw value stays `"bomb"` either
   way for the save story.
4. **Lesson night:** want one teaching the L/T (the coconut-lesson
   mechanism is sitting there), and if so, before which night?
5. **Square consolation:** leave squares exactly as-is (recommended), or
   add a scoring bump / distinct pop FX — never a special, per the
   frequency argument in §3.
