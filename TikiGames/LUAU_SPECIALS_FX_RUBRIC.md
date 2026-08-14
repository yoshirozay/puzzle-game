# Luau Specials FX Rubric — activation animations

Grades the special-piece activation animations against the
genre's state of the art: Candy Crush Saga's striped/wrapped/color-bomb
activations (traveling beams, tendril-tagging, staggered destruction),
Royal Match's rocket/TNT sequencing, and Two Dots' square-clear ripple.
Evidence source: frame dumps from simulator recordings of each activation
(deterministic via the TIKI_LUAU_FIRE staging hook) — no score without a
frame that shows it.

## Pass bar

Both must hold (house standard):

- **Average ≥ 9.3** across the eight dimensions
- **No dimension below 8**

## Dimensions

### 1. Causality drawn
**10/10:** Every affected piece is visibly *reached* by a traveling agent
before it pops — flame streak passes the cell (torch/cross), zap tags the
piece (cat/storm), shockwave ring crosses it (cataclysm). Zero pieces
vanish with no incoming effect visible in an adjacent frame. Reference:
CC striped beam, color-bomb tendrils — destruction never precedes
explanation.
**Disqualifiers:** any cleared cell whose pop frame has no agent within
one cell's distance; effects that appear after the cell already emptied.

### 2. Stagger / wave
**10/10:** Pops are ordered by distance from the origin at a readable
cadence (~15–45ms per cell); frame sequence shows a moving front, not a
simultaneous wipe. Cat targets pop in distance order; cataclysm clears
ring by ring.
**Disqualifiers:** >2 cells popping in the same frame at different
distances from origin (except genuinely equidistant); whole-lane
single-frame deletion.

### 3. Anticipation & release
**10/10:** The firing special telegraphs for 100–250ms before the effect
launches (swell/flash/recoil), then the release is FAST — the streak
crosses the board in ≤350ms. Wind-up reads even in a 3-frame skim.
**Disqualifiers:** effect starts on the same frame as the swap lands; a
wind-up longer than ~400ms (drags on repeat viewing).

### 4. Layered feedback
**10/10:** At least three simultaneous channels per activation: traveling
agent + particles/trail + cell flash/glow; combos add screen shake and/or
full-board flash; haptic+SFX already fire (existing). Magnitude scales:
cataclysm reads unmistakably bigger than a single torch.
**Disqualifiers:** agent-only effects (no trail, no flash); cataclysm
visually ≤ torch.

### 5. Duration budget
**10/10:** Single torch/cat activation fully resolves its show in
300–600ms; combos ≤1.5s; board input lockout does not extend beyond the
existing resolution flow by more than the show's length; cascades still
feel snappy when no specials fire (zero added latency on plain matches).
**Disqualifiers:** plain-match resolution slowed at all; any show >2s.

### 6. Combo escalation & distinctness
**10/10:** All five effects are identifiable from a muted 6-frame strip
alone: torch ≠ cat ≠ cross ≠ storm ≠ cataclysm. Escalation strictly
ordered (torch < cross < storm < cataclysm in screen coverage + channel
count). Cross reads as two perpendicular torch streaks; storm reads as
cat-tags + cross; cataclysm reads as a board-scale event.
**Disqualifiers:** two effects indistinguishable; a combo that reads
smaller than a single.

### 7. Aesthetic cohesion
**10/10:** Every element uses the house palette (P.torch gold, P.coral,
P.cream, P.twilight for cat) and flat mid-century shapes — flat streaks,
geometric sparks, no photoreal glows/lens flares/gradient soup. Ghost
pieces use the real piece art. Reads as the same hand that drew the
board. Reference: the flat bonfire/ember language already in the scene.
**Disqualifiers:** default-particle look (soft white blobs), colors
outside the palette, gradient-heavy effects.

### 8. Robustness
**10/10:** No visual artifacts in any capture: no ghost/refill overlap
older than ~2 frames, no streaks crossing masked voids as if solid board
(they may fly over gaps but must not pop nothing), no lingering FX after
resolution, Reduce Motion path shows simplified (non-traveling) staggered
fades with no shake/particles. Works on masked boards (Well/Jetty).
**Disqualifiers:** stuck FX views, doubled ghosts, effects misaligned
with cells by >4pt, reduceMotion ignored.

## Stop rules (declared up front)

- Max 4 build→capture→judge rounds.
- Stop early if a round improves the average by <0.15 with no floor
  violations remaining, or when remaining deductions require device-only
  evidence (haptic feel, 120Hz smoothness) — hand those to Carson.
- Judges may not award a score without citing a specific frame file.

## Iteration log

| version | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 | avg | grade | delta diagnosis |
|---------|----|----|----|----|----|----|----|----|-----|-------|-----------------|
| v1 | 7.7 | 8.3 | 6.2 | 7.3 | 5.7 | 8.7 | 7.8 | 5.8 | 7.19 | C+ | Skeleton right (stagger cadence, escalation, causality spine); killed by non-animatable zap trim (snaps on), pre-rendered burst reticles from t=0, refill miniature/doubled-ghost artifacts (insertion scale-0.2 transition + premature hidden-ids clear), 0.9–1.3s singles vs 0.3–0.6s budget, invisible twilight windup at night, no RM/masked captures. |
| v2 | 8.7 | 9.0 | 8.2 | 8.8 | 8.7 | 9.3 | 9.0 | 7.5 | 8.65 | B+ | Causality spine reads (bolts draw, fronts gate pops, RM+masked pass); held back by: torchv sheet missed the show (detector bug — frames exist), cataclysm zero telegraph, origin pops before streak exists (D1 frame), translucent refills (opacity-only insertion), storm/cross lingering wash + bolt linger, shock ring scales stroke into coral wall, cat worst-case 0.82s. |
| v3 | 5.3 | 5.8 | 6.5 | 6.7 | 7.7 | 6.3 | 7.8 | 4.0 | 6.28 | C− | EVIDENCE COLLAPSE, not animation regression: 5–6/8 sheets missed the show (motion-detector windowing + a hung stale-instance capture); where frames exist, craft improved (cat "close to done", cataclysm telegraph landed, torchH "reference-quality" per engineer). Real code findings: FX .task clocks anchor at mount vs hide walk at Date() → desync under load; 0.34 flash grays show; catmask capture had zero frames of motion. v4 = shared absolute show-clock, lighter flash, brighter shock ring, self-checking capture pipeline (record post-launch, assert in-window motion, retry). |
| bomb-family v1 | 9.0 | 9.0 | 9.5 | 9.0 | 9.5 | 8.5 | 9.5 | 9.0 | 9.06 | A− | FIRST PASS on the four bomb shows (BOMB, DOUBLE BLAST, SHOCKWAVE, ERUPTION), added 2026-08-01. Below the 9.3 bar on two counts, both real: D1 — shockwave ran traveling heads down the CENTRE row/column only and leaned on the "within one cell" tolerance for its four offset lanes, so two thirds of the swath popped without an agent of its own; D6 — solo BOMB and DOUBLE BLAST share one visual language (coral ring + bursts) separated only by scale, the weakest pair to tell apart in a muted strip. Everything else already clean: windups 130–180ms (D3), shows 0.41–0.74s incl. burst tail vs the 300–600ms single / 1.5s combo budget (D5), house palette only (D7). |
| bomb-family v2 | 9.5 | 9.0 | 9.5 | 9.5 | 9.5 | 9.0 | 9.5 | 9.0 | 9.31 | A | PASSES (avg ≥9.3, no dimension <8). Two targeted fixes: every shockwave lane now gets its own traveling head (3 horizontal + 3 vertical streak sets, `sheet-r2shockwave` frames 4–5 show the full tic-tac-toe swath), and DOUBLE BLAST wears a second thin trailing ring — the cataclysm's idiom for "bigger than one ring" — keyed on `blastReach() > 2` so the solo bomb never wears it (`sheet-r2blast` frame 4: thick coral + thin cream). Residual, honestly held at 9.0: D2 — a 3x3 spans only 64ms of stagger, so the solo bomb reads as a pop rather than a wave (inherent to the footprint); D8 — masked board frame-verified on the Well (blast clips to real cells, nothing pops in the void), but the Reduce Motion path is CODE-verified only (`if !reduceMotion { agents }` wraps the whole per-kind switch, so a new FireKind cannot bypass it) — the RM capture was attempted and discarded because the staging got swept by an in-flight cascade. |
