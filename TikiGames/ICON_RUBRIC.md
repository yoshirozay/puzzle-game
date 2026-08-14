# App Icon — rubric (Sign Rail identity)

The icon distills the game picker — the app's most recognizable screen: a carved
wooden sign hanging from a rail, its routed window glowing with the tiki world.

Grading scale per dimension 0–10. **A+ bar: average ≥ 9.3 AND no dimension below 8.**
Reference class for dimension 1: the puzzle-shelf icons this sits beside — Two Dots,
Monument Valley, Alto's Odyssey, Toon Blast. Platform rules: no text, no alpha in the
1024 marketing slot, iOS squircle mask (~22.4% corner radius) crops the square.
Judged artifacts are the RASTERS at deployed sizes (1024 / 180 / 120 / 58), never the SVG.

| # | Dimension | What 10/10 looks like | What fails (≤6) |
|---|---|---|---|
| 1 | Shelf identity | Unique, ownable silhouette among the reference class; recognizable from the shape alone in a 6-icon row; nothing generic-tropical (no bare palm-on-sunset cliché as the whole idea). | Could be any tiki bar app; silhouette vanishes among rounded-rect gradients. |
| 2 | Screen kinship | Instantly reads as the Sign Rail distilled: rail + ropes + hanging plank + routed glowing window. Someone who used the app says "that's the picker." | Kinship requires explanation; sign reads as a generic frame or billboard. |
| 3 | 58 px legibility | At the Settings slot every load-bearing element survives: rail line, both ropes, board, window scene. Squint test passes; no element collapses to noise. | Ropes/stripe vanish; window contents smear; icon reads as a brown blob. |
| 4 | Palette & technique fidelity | Every fill is a verbatim P-token hex (or a stated lerp of two); flat fills ONLY — zero gradients, filters, or soft shadows; chunky ink outlines per house weight; construction matches TikiScenery's flat-vector contract. | Any invented hex, gradient, blur, or off-house stroke weight. |
| 5 | Squircle & shelf composition | Balanced mass inside the iOS mask; nothing load-bearing inside the corner-crop zones; deliberate margins; sits well on both light and dark springboards; rail running off both edges survives the mask as a feature, not a casualty. | Corner-clipped ropes/knots; icon hugs edges; floats pale on dark wallpaper. |
| 6 | Craft economy | ≤ ~10 meaningful shapes, each earning its place; the window scene is one idea told boldly; no living-artist signature elements (pre-ship rule); concept + why baked into the SVG comment. | Miniature screenshot syndrome — the whole picker crammed in; decorative noise. |
| 7 | Tap appetite | Warm, lit, inviting — the window glows like a place that's open; the icon promises play, not décor. | Murky browns; the window reads dark/closed; static signage with no life. |

Pass = average ≥ 9.3 with no dimension below 8. Judged by a 3-persona panel
(awards juror / mobile-shelf UX / flat-vector craft engineer) on the rasters.

Stop rules (locked before round 1): max 4 iterations; each round targets the
lowest dimension first; stop early if remaining points require user-taste
evidence (final color-variant choice is explicitly the user's call) — say so
rather than idle.

## Iteration log

| Iter | 1 Shelf | 2 Kinship | 3 58px | 4 Palette | 5 Squircle | 6 Economy | 7 Appetite | Avg | Grade | Delta diagnosis |
|---|---|---|---|---|---|---|---|---|---|---|
| v1 (3 concepts) | — | — | — | — | — | — | — | — | — | 4 concepts (Immersive/Craft-Object/Poster/Postcard-analog naming doesn't apply here — actual v1 set was A "Sign Rail", B "Through the Window", C "Open Late"). Panel picked A as base (won 2/3 judge votes); grafted C's twilight-field idea as a stated color variant instead of forcing one winner. |
| v2 (synthesis) | 9.0 | 9.83 | 8.67 | 8.83* | 9.43 | 8.83 | 9.17 | 9.11 | A− | First synthesis: A+grafts (window grown ~8%, 2 glints→1, ropes tightened 324→260px, palm 5 fronds→3 thicker trunk). *dim4: one judge flagged `#59391F`/`#1A5A6B` as invented hexes vs. nonexistent comparison tokens ("bambooDeep", "lagoonTeal") — independently verified FALSE by computing P.plank/P.lagoon directly from TikiScenery.swift; both are exact matches. Corrected dim4 (2 accurate judges only) = 9.75, corrected avg = 9.24. Real gap: palm still read ambiguous at 58px (2 of 3 judges flagged, self-check with a 4x-zoomed proxy missed it). |
| v3 (palm→lens fronds) | 8.67 | 9.33 | 7.83 | 9.67 | 9.0 | 8.67 | 9.33 | 8.87 | B+ | Rebuilt palm using the app's own PalmView technique (lens/teardrop fronds from one crown, TikiScenery.swift:155-176) instead of thin wedges. Looked right in the 1024 vector and in a 4x-zoomed proxy — but two judges independently blur/squint-tested the TRUE native 58px raster and found it still collapsed to a starburst/antenna. Lesson: a zoomed nearest-neighbor crop is not a valid proxy for "does this survive rasterization"; blur-testing the actual output pixels is. |
| v4 (palm removed) | 9.3 | 9.33 | 9.47 | 9.77 | 9.47 | 9.33 | 9.27 | **9.42** | **A+** | Palm deleted entirely from all 3 variants — window scene is sun/horizon/sea alone. Two prior attempts both failed the same load-bearing claim at 58px; both round-3 judges independently recommended removal as the safe fix. All three judges re-verified with true-58px blur tests: legibility gap fully closed, no regression to shelf identity/kinship/appetite, craft economy improved (fewer competing shapes). Unanimous MEETS_A_PLUS: yes. |
