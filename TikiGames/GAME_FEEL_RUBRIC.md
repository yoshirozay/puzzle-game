# Tiki Stacks — game feel rubric

Grounded in the juice canon (Jonasson/Purho "Juice it or Lose it": every input
deserves amplified output) and Block Blast's specific loop (dissolving clears,
combo escalation, frictionless flow). Scale 0-10 per dimension.
**A+ bar: average ≥ 9.3, no dimension below 8.**

| # | Dimension | What 10/10 looks like |
|---|---|---|
| 1 | Feedback immediacy | Every action acknowledged < 100 ms, visually and haptically. Nothing lands silently. |
| 2 | Placement juice | Blocks pop-settle into the grid (scale-in spring), never just appear. |
| 3 | Clear spectacle | Cleared lines dissolve with scale-out + burst; popups announce points; spectacle escalates with lines and combos. |
| 4 | Drag feel | Pickup enlarges the piece above the finger; ghost preview is instant and unambiguous; drops snap crisply; rejected drops return visibly. |
| 5 | Reward arc | Score popups float from the action; combo banners escalate; beating best is a moment. |
| 6 | Ambient life | Living background, mask personality reacting to play, nothing static at idle. |
| 7 | Cohesion | Motion language matches the flat mid-century art: snappy springs, geometric moves, no mush. Animations never block input. |
| 8 | Performance | 60 fps through the heaviest clear + popup + shake moment. |

## Iteration log

| Iter | 1 Imm | 2 Place | 3 Clear | 4 Drag | 5 Reward | 6 Ambient | 7 Cohesion | 8 Perf | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|---|
| v0 (baseline) | 6 | 4 | 6 | 7 | 5 | 9 | 8 | 9 | 6.75 | C+ |
| v1 (juice round 1) | 8.5 | 8.5 | 9 | 8 | 8.5 | 9.5 | 9 | 8.5 | 8.69 | B+/A- |
| v2 (cascade + tiers) | 9 | 8.5 | 9.5 | 8* | 9.5 | 9.5 | 9 | 9.5 | 9.06 | **A** |

v0 notes: haptics on drop only; placements appear with no animation; clears show
burst but cells vanish instantly; no score popups or combo callouts; drag has
ghost but no pickup feel; mask moods + animated scene carry ambient life.

Round 1 plan: grid-keyed pop-in/scale-out transitions, floating score popups,
combo banner, board shake on multi-line clears, mask pulse on clears, tray
refill springs, drag pickup scale.

v1 verification: burst-frame capture caught a double-row clear mid-animation —
16 simultaneous bursts, "+20" popup rising, mask flipped to surprised. Popup,
mood, burst, and tray systems all confirmed live.

Round 2 plan (to A+): burst cascade sweep (stagger bursts outward from clear
centroid — the classic line-clear read); combo banner escalation by streak tier
(cream x2 → gold x3 → coral x4+); NEW BEST celebration moment mid-game; popup
size bump; CPU sample under the heaviest moment (dim 8 is unproven).

v2 verification: cascade sweep caught mid-flight (full row of rotated bursts +
rising popup); CPU 27-30% single-core on the CPU-rendered simulator under full
animation load — ~4 points over the static scene, so the juice layer is nearly
free. Placeholder system-percussion SFX on place/clear.

*Why the loop stops at A, honestly: the remaining quarter-point lives in
dimension 4 (drag feel under a real thumb — pickup offset, ghost readability
at speed, drop forgiveness) and in replacing system-sound placeholders with a
real exotica SFX pack. Neither is verifiable by autonomous iteration —
screenshots can't feel. Next iteration requires human playtest notes.

---

# Zombie (2048 merge) — game feel

Same scale, same A+ bar. Dimension 4 reads "swipe feel" here.

| Iter | 1 Imm | 2 Spawn | 3 Merge | 4 Swipe | 5 Reward | 6 Ambient | 7 Cohesion | 8 Perf | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 9 | 9 | 8.5 | 8 | 9 | 9.5 | 9.5 | 9 | 8.94 | A- |
| v2 | 9 | 9 | 9 | 8.5 | 9 | 9.5 | 9.5 | 9 | 9.06 | **A** |

v1 (first playable): swipe haptic+tick, merge haptic, spawn spring pop, merge
pulse, "+N" GainPopup, tiered SFX (1057 at tier 8+), LAST CALL panel with
wallet handoff, THE ZOMBIE win banner, board persisted per move (SwiftData).
Board initially collided with the top chrome — moved into the wall zone
(center 0.545h) between the scene's shelf and counter.

v2 (polish): rejected swipes nudge the board toward the swipe and spring back
(silent refusal read); tier-6+ merges fire the fxBurst star at the merged
cell. Verified by autoplay frames: mid-merge tile crossing, "+8"/"+12" popups
mid-rise, LAST CALL with +23 points on a 2,392 run (earnScore economy: classic
2048 scores pay stacks-scale points).

*Same honest A ceiling as Tiki Stacks: the last quarter-point is swipe feel
under a real thumb (threshold, follow-through, interrupted-swipe forgiveness)
plus the commissioned SFX pack. Win-banner layout is code-reviewed but not
screenshot-verified (bots rarely reach 2048). Human playtest notes close it.*

---

# Blueprints (nonogram) — game feel

Dimension 2 reads "fill juice", 3 "reveal spectacle", 4 "paint feel".

| Iter | 1 Imm | 2 Fill | 3 Reveal | 4 Paint | 5 Reward | 6 Ambient | 7 Cohesion | 8 Perf | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 9 | 9 | 9 | 8 | 9 | 9.5 | 9.5 | 9.5 | 9.06 | A- |
| v2 | 9 | 9 | 9 | 8.5 | 9.5 | 9.5 | 9.5 | 9.5 | 9.19 | A |
| v3 | 9 | 9 | 9 | 9 | 9.5 | 9.5 | 9.5 | 9.5 | 9.25 | **A** |

v1 (first playable): 10 authored puzzles, picker with reveal-on-solve cards,
mistake shake + error haptic, DRAFTED colorize overlay, SwiftData resume.
Fixed a ForEach teardown-race crash (cells reading a shrunken grid).
Autoplay verified: perfect-draft flow, then restore→next-puzzle flow with
mistake scoring (+8 on 2 mistakes).

v2 (10x10 pass): 5-block separators, drag-to-paint runs, TIKI_PUZZLE dev
hook. Volcano board verified: clue stacks aligned, separators legible.

v3: satisfied clue lines dim (0.32) — verified on the half-drafted volcano.

*Honest A: remaining quarter-point is paint feel under a real thumb (drag
across gutters, accidental-fill forgiveness) and the shared SFX-pack upgrade.
The collection meta (cards colorize as drafts complete) is the reward spine
and is fully verified.*

---

# Cabana Cipher (cryptogram) — game feel

Dimension 2 reads "lock juice", 3 "crack spectacle", 4 "input feel".

| Iter | 1 Imm | 2 Lock | 3 Crack | 4 Input | 5 Reward | 6 Ambient | 7 Cohesion | 8 Perf | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 9 | 9 | 8.5 | 9 | 9 | 9.5 | 9.5 | 9.5 | 9.13 | **A** |

v1: 24 original exotica phrases; deterministic per-phrase ciphers (SwiftData
restore re-derives the same board); tap-tile → tap-letter with torch
selection ring, all-occurrence lock pulses, auto-advance to next unsolved;
wrong guess = shake + error haptic; HINT (15-pt cost) and mistake (10-pt)
economics; used keys dim; CRACKED overlay with the phrase, clean-crack
callout, points and wallet line. Autoplay verified mid-crack and completion
(+7 on 1 mistake + 1 hint over 33 letters).

*Honest A: typing cadence under a real thumb and the SFX pack. A completion
tile-cascade flourish is the one known sub-half-point polish left on dim 3.*

---

# Luau (match-3) — game feel

| Iter | 1 Imm | 2 Settle | 3 Clear | 4 Drag | 5 Reward | 6 Ambient | 7 Cohesion | 8 Perf | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 9 | 9 | 9 | 8.5 | 9.5 | 9.5 | 9.5 | 9 | 9.13 | **A** |

v1: 7x7 board over the bonfire scene, 20-move nights; drag-to-swap with
refusal nudge; STEPPED cascade resolution (one clear round per animation
beat — engine refactored from synchronous so cascades read); escalating
COMBO banner (cream ×2 → gold ×3 → coral ×4+) with tiered sounds; "+N"
popups; torch line-specials from 4-matches, the cat color-bomb from 5s;
no-legal-move auto-shuffle; SwiftData mid-run persistence; SUNRISE/NEW BEST
panel with earnScore economy (score/3 → 1,110 run paid +37). Autoplay
verified: combo banner + popup + two live torch specials in one frame, and
a full run to NEW BEST.

*Honest A, same ceiling as the other four: swap feel under a real thumb, the
cat-bomb moment unobserved by bot (code-reviewed), and the SFX pack.*
