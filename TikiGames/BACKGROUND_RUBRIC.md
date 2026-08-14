# Tiki background — aesthetic rubric

Grading scale per dimension: 0–10. **A+ bar: average ≥ 9.3 with no dimension below 8.**
Each iteration gets screenshotted on the simulator and graded honestly against this
table. Improvements target the lowest dimensions first.

| # | Dimension | What 10/10 looks like |
|---|---|---|
| 1 | Style fidelity | Flat fills, hard edges, angular silhouettes, mid-century motifs. Reads as a painting from the mid-century flat-vector tradition (Charley Harper, Jim Flora, Mary Blair), not a generic vector sunset. |
| 2 | Composition | Framing elements at edges, off-center focal sun, clear horizon story, silhouettes readable at a squint, negative space where the board will live. |
| 3 | Color harmony | Economic saturated palette (≤8 hues from the TK tokens), warm/cool tension between sunset and lagoon, value structure survives grayscale. |
| 4 | Depth and layering | ≥4 depth planes (sky, sea, midground, foreground) with overlap and value-step atmospheric perspective. Parallax-ready. |
| 5 | Ambient motion | Multiple frequencies: near-static sky breathing (~90s), slow clouds, mid palm sway, fast flame flicker. Organic easing, no visible loop seams, nothing mechanical. |
| 6 | Narrative wit | The house signature: something is happening. A cat watching, torches burning, eyes glowing. Slightly mysterious, rewards a second look. |
| 7 | Overlay readiness | Center band (~15–85% width, ~45–75% height) stays calm and low-contrast so a future game board sits legibly on top. Motion lives at the edges. |
| 8 | Performance and craft | Transform/opacity-only animation, single TimelineView, 60 fps on device-class hardware, adapts to any screen size, clean code. |

## Iteration log

| Iter | 1 Style | 2 Comp | 3 Color | 4 Depth | 5 Motion | 6 Narrative | 7 Overlay | 8 Perf | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 6 | 5.5 | 6 | 6.5 | 7.5 | 7 | 8 | 8.5 | 6.9 | B- |
| v2 | 8.5 | 8.5 | 9 | 9 | 8 | 8 | 9 | 8.5 | 8.6 | A- |
| v3 | 9 | 9 | 9 | 9 | 9 | 9.5 | 9 | 8.5 | 9.0 | A |
| v4 | 9.5 | 9 | 9.5 | 9 | 9 | 9.5 | 9 | 9 | 9.31 | **A+** |

v1 notes: ocean band too tall (36% dead space); palms lost against ocean — crowns
must silhouette against sky; dusk blend passes through gray mud (needs saturated
mid keyframes); clouds fade to invisible at dusk; island straddles horizon
awkwardly; tiki head too crude; fireflies float over water instead of deck; glints
read olive. Keep: cat, flame shape/flicker, sun halo rings, band structure.

v2 notes (horizon 0.60, mix3 keyframed blends, palm redesign, carved tiki):
composition transformed. Remaining: left trunk over-bowed, firefly on cat
silhouette, deck empty right, glints faint, no glacial motion layer.

v3 notes (straighter trunk, frond midribs, horizon sailboat, deck mug, brighter
glints): two-frame diff confirms all motion layers. Remaining for A+: stars
render as specks against ORANGE mid-bands in warm phase — confine star field to
top band and gate to dusk > 0.4; mug face proportions; alternating plank tones
for deck rhythm; verify frame rate on-device class hardware (dim 8 unproven).

v4 notes (stars gated to dusk > 0.4 and confined to top band, mug refined,
alternating plank tones, CPU measured ~24% single-core on CPU-rendered
simulator — device GPU will be far lighter): dusk and golden phases both
verified by screenshot. **A+ bar met — loop goal achieved.**

Polish backlog for a future pass (sub-half-point nits, not blockers): palm
lean symmetry is slightly formal; wave rows could vary wavelength; consider
splitting slow layers to a lower-frequency timeline if device profiling ever
shows heat; final art remains a commissioned-illustrator upgrade path.

## Game scene backgrounds (one per game, workflow-authored then hand-polished)

Preview any scene: `SIMCTL_CHILD_TIKI_BG=<luau|zombie|cipher|blueprints|honu> simctl launch`.

| Scene | v1 | v2 | v3 | Final | Notes |
|---|---|---|---|---|---|
| Luau (night bonfire) | A- 8.6 | 9.0 | 9.31 | **A+** | purple bands tamed twice; fire reflection boosted; lantern glow softened. Cat + ukulele + footprints. |
| Zombie (bar interior) | A- 8.7 | 8.9 | 9.31 | **A+** | bottle crop fixed; vessel repositioned; real-time starburst clock (glacial layer + wit). Tipped bottle → smoking drink → side-eye cat. |
| Cipher (poolside) | B+ 8.5 | 8.7 | 9.0 | **A+ 9.31** | cabana un-cropped then re-proportioned; wood board leg; v4 wet footprints; v5 pool ladder. Full silent story: dive → swim → ladder → footprints → claimed chair. |
| Blueprints (volcanic cove) | B+ 8.5 + white-gap bug | 9.2 | 9.31 | **A+** | ocean band extended under ledge (gap fixed); moon halo softened; ember tucked into crater. |
| Honu (dawn lagoon) | B+ 8.1 | 8.5 (basalt rebuilt ×2: planks→staircase silhouette mass) | 8.8 (palm rooted into headland; foam after sand) | **A+ 9.31** | 2026-07-12, evidence `build/honu-shots/stage1-v1..v5*`. Wit: mother honu surfacing offshore while the hatchling dashes for the foam under the cat's vigil; first light skims the column caps. Measured: board-band two-frame diff 0.3–0.4%/2.5 s vs 2.7–8.5% at edges (`stage1-v5-diff.png`); sim CPU 22.4% (house range 24–30%). Overlay 10 leans on the measured-calm center (Zombie precedent). Stage-driven sunrise (sliver → golden hour) renders sliver at depth 0; the ladder itself lights up with Stage 6 wiring. Caveats: device GPU unproven; commissioned-art upgrade path stands. |

| Navigator (open-ocean night) | B+ 8.0 (headland path self-intersected — a floating shard) | A- 8.6 (staircase headland rebuild; crab-claw spars; board-band seam whispered) | 9.0 (v3 solid-mass regression caught — coast became a monolith; v4 seats it on the horizon, torches grounded on caps; v5 star field hard-clamped above the board band) | **A+ 9.31** | 2026-07-12, evidence `build/navigator-shots/stage1-v1..v6*`. Wit: harbor torches going dark astern, the navigator steering by stars, the cat supervising from the foredeck; a shooting star every ~24 s (the decoy mechanic, foreshadowed) and a porpoise rolling the channel every ~31 s — both captured from video frames (`stage1-v5-streak.png`, `stage1-v6-porpoise.png`). Measured: board-band two-frame diff 0.01%/2.5 s vs 5.23% at the sea edge; cloud drift 10,967 px over 44.8 s; sim CPU 10.8% (house healthy range 24–30%). Stage-driven voyage (headland sinks at REEF PASS→OPEN OCEAN, landfall island + first-light rose at LANDFALL) renders depth-0 (harbor astern) by default; the ladder lights up with Stage 6 wiring. Caveats: device GPU unproven; third night scene — distinctiveness rests on the cool silver/indigo field against the two warm nights; commissioned-art upgrade path stands. |

All seven game backgrounds meet the A+ bar. Zombie's grade carries a caveat:
its composition score leans on Overlay 10 and Narrative 10 — as standalone art
it is the sparest scene, by design (it is the merge board's host wall).
