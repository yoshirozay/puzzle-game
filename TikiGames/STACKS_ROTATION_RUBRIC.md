# STACKS ROTATION RUBRIC

**FEATURE REMOVED 2026-07-16 (Carson's call).** Tap-to-rotate shipped
2026-07-10 (126abf5, graded A 9.5 below) and was removed six days later:
the tap gesture, spin presentation, one-shot hint, how-to line,
any-orientation game-over, bot rotation fallback, and the
ROTTEST/ROTATE/ROTATE_LATE/HINT hooks are all gone; game-over is
single-orientation `hasAnyPlacement` again. Old saves with rotated tray
pieces restore fine (the payload stores raw cells, so a rotated piece just
loads as that shape). This rubric stays as the feature's historical record.

Grades clockwise piece rotation in Tiki Stacks (tap a tray piece to spin it
90° CW before placing). **Target grade: A = avg ≥ 9.0 AND no dimension < 8**
(A+ stretch = 9.3). Grade from executable validation, staged simulator
screenshots, bot distributions, and measured behavior — never from intent.
Evidence: `build/progression-shots/stacksrot/`.

Reference class: Block Blast / Blockudoku tray conventions (tap is the only
spare gesture on a tray piece; drag is sacred for placement), Tetris Guideline
CW-on-primary-input, Apple HIG 44 pt touch targets. House grammar:
GAME_FEEL_RUBRIC (springs, tick/pop/clear SFX ladder, one-shot hints via
UserDefaults, DEBUG env staging hooks, GameSaveState resume).

## Dimensions

1. **Rotation correctness** — `rotatedCW` is an exact 90° CW map for all 25
   library shapes (count corrected from 26 — tallying error, noted v1): 4× rotation = identity, results stay normalized (min
   row/col = 0), rows/cols swap, id/color/firefly-glow survive. Proven by
   executable validation running inside the real app code, not by reading.
2. **Seamless input** — tap rotates, drag places, nothing else changes: no
   piece flicker on tap (better than today's one-frame lift), drag pickup
   unchanged past a movement threshold ≤ 10 pt, no dead zones between slots,
   taps during the scripted tutorial are safely inert, empty slots ignore
   taps.
3. **Rotation juice** — the spin is felt as clockwise: snap-then-settle
   spring (≤ 0.4 s, house spring family), every rotate gives feedback even on
   symmetric pieces (scale pulse), distinct light haptic, `tick()` SFX; no
   cell-slide mush from the tray's implicit animation.
4. **Game-logic integrity** — game over accounts for all four orientations
   (no run ends while a rotation could save it); ghost preview, placement,
   scoring, combos, fireflies, sweeps all operate on the rotated cells with
   zero special cases; restart and tutorial-seed paths untouched.
5. **Persistence & compatibility** — a rotated tray survives kill + relaunch
   (rotation persists on every rotate, not just on placement); legacy
   payloads still decode (no schema change); restore validation still holds.
6. **Discoverability** — a one-shot "tap to spin" hint in the house pattern
   (UserDefaults-gated, auto-fades, dismissed by first rotate), a HOW TO
   STACK rule line, and the FTUE tutorial neither teaches nor breaks on it.
7. **Economy impact measured** — greedy-bot score distributions with and
   without rotation (n ≥ 150 each) quantified; the depth-threshold
   implication (150/400/800/1500) stated with numbers and flagged as
   Carson's retune call — no silent difficulty shift shipped as fact.
8. **Regression safety** — build green, zero warnings; stacks tutorial
   autoplay still passes end-to-end; full-game autoplay (now
   rotation-capable) finishes runs; staging hooks reproduce every state;
   no other game touched.

## Iteration log

| version | 1 Correct | 2 Input | 3 Juice | 4 Logic | 5 Persist | 6 Discover | 7 Economy | 8 Regress | avg | grade | delta diagnosis |
|---------|-----------|---------|---------|---------|-----------|------------|-----------|-----------|-----|-------|-----------------|
| v1 (tap-to-rotate as first built) | 10 | 8 | 8 | 9.5 | 10 | 9.5 | 9 | 9.5 | 9.19 | A− (held) | Evidence: TIKI_STACKS_ROTTEST 25/25 shapes 0 failures (executable, real code); bot n=150×2 — median 139→167 (+20%), p75 202→253 (+25%) with rotation, so the relaxed any-orientation game-over demonstrably extends runs; rot-A/B/C screenshots prove exact CW cells (S-piece pixel-matches the transform), symmetric no-op, untouched slots, one-shot hint consumed, and persistence across relaunch; how-to 5-rule panel renders; tutorial autoplay 4/4 ends 0/0/0; full autoplay finishes (211, DUSK). Held at A− despite the 9.0 numeric bar: Input 8 and Juice 8 were evidence-free hypotheses — the spin animation was never observed and the 8 pt lift threshold left the drag's first 8 pt with zero touch feedback. Suspecting a too-kind v1 per the discipline, iterated on both instead of celebrating. |
| v2 (touch-down perk + observed tap path) | 10 | 9 | 9.5 | 9.5 | 10 | 9.5 | 9 | 9.5 | 9.5 | **A** | Added: instant touch-down perk (1.05 scale the frame a finger lands, settled on every refusal path — closes the pre-lift dead window) and TIKI_STACKS_ROTATE_LATE, which drives the real rotateTapped end-to-end post-launch. OBSERVED (rot-I burst): the 5-line mid-spin at ~-55° turning as a rigid unit with the 1.12 pulse visible and the hint chip simultaneously mid-fade (first-rotate dismissal live), settling exactly vertical next frame — Juice is fact, not pattern-trust. Tutorial re-passed on the final binary. Letter capped at A, not A+, despite the 9.5 avg: tap accuracy, perk feel, haptic weight, and accidental-rotate rate on sloppy pickups are thumb-on-glass questions no simulator loop can answer — Carson's device pass owns them (same residual class as the lounge's drag). Economy flag for Carson: rotation makes Stacks measurably easier (bot +20% median as a LOWER bound — humans rotate strategically, bots only when stuck); the 150/400/800/1500 depth ladder and DUSK-at-150 in particular may want a nudge. |
