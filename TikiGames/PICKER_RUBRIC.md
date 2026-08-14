# Game Picker (The Sign Rail) — screen rubric

Grading scale per dimension: 0–10. **A+ bar: average ≥ 9.3 with no dimension below 8.**
Each iteration gets screenshotted on the simulator and graded honestly; improvements
target the lowest dimensions first. This is one of the most-seen screens in the app —
the bar is the same one the lounge and the six game-feel loops already cleared.

Screenshot protocol per iteration (all via `SIMCTL_CHILD_TIKI_PICKER=1`):
(a) page 1 at rest, fresh install; (b) mid-drag between pages 1–2; (c) page 3 at rest
with a best score and a mid-run save present (via dev hooks or a real run); (d) 375x667
device; (e) Reduce Motion enabled; (f) one frame captured mid-launch-expansion;
(g) Accessibility Inspector view of one card. Code reading covers what screenshots
cannot (player policy, scroll plumbing, palette fidelity).

| # | Dimension | What 10/10 looks like | What fails (≤6) |
|---|---|---|---|
| 1 | First-glance multiplicity | Screenshot (a) alone shows ≥4 independent count signals: 27–34 pt neighbor peek with readable identity, the rail running off BOTH screen edges, "Nº 1 OF 6" counter, and six distinctly-colored mini-sign indicators. A stranger shown only this screenshot cannot believe one game exists. | Any state where the only count signal is a dot row; page 1 with no visible right peek; rail terminating inside the screen. |
| 2 | Preview prominence & honesty | Video window ≥ 65% of card area and ≥ 35% of screen area on 393x852; footage is real gameplay with the game's own HUD legible; the recorded status bar is cropped out on all six games (no second clock); poster and video share identical crop math (crossfade shows no jump in frame (b)/(c)). | Window under half the card; recorded status bar visible in any clip; a poster→video jump; footage cropped so the game is unrecognizable. |
| 3 | World cohesion | Flat fills only — zero gradients/blur/soft shadows in picker code; chunky ink outlines (≥2 pt) on board, window, stripe; wall/rail/ropes read as the bar's world; capsule is a verbatim miniature of the home PLAY recipe and the back button matches `HomeView.backButton`; resume badge reuses the lounge badge grammar. | Any gradient or shadow API in the file; chrome that could ship in any app; a second visual language for buttons. |
| 4 | Peek legibility | Squint test on (a) and (c): each neighbor shows ≥3 identity cues within its peek — ink outline, ≥12 pt of its accent stripe color, ≥12 pt of its poster slice; neighbor opacity never below 0.85; if plank-on-woodDark separation failed on device, the named wall-darkening fallback was applied (not board lightening). | Neighbor reads as a dark smudge; neighbors dimmed into the wall; peek showing only bare plank. |
| 5 | Indicator & counter craft | Six mini-signs at exactly 44 pt center pitch, each filled with its game's accent at full opacity + 1 pt ink stroke; active is larger (18x13 vs 13x9), ink-stroked 1.5 pt, dropped 1.5 pt, springs on change; each is a working 44x44 jump target; counter reads "Nº k OF 6" with `.numericText` roll and updates mid-drag. | Anonymous same-color dots; hit areas that overlap or are under 44 pt; counter absent or settle-only; indicators that don't jump on tap. |
| 6 | Motion discipline | All drag-driven properties (sway ≤2.5° anchored top-center, scale 1→0.92, opacity 1→0.85, seam tint, counter, indicator) interpolate continuously from scroll phase/progress — nothing steps mid-drag; settle = one visible oscillation + light haptic + pentatonic tick ascending [1.0→1.667]; exactly ONE idle motion (0.6°/5 s focused-card sway) beyond the video loop; entry ≤0.8 s and interactive by 0.5 s. | Stepped/snapped mid-drag states; idle motion on multiple cards; entry that locks input >1 s; flat same-pitch tick everywhere. |
| 7 | Launch handoff | Frame (f) shows the window mid-expansion with video still rendering, corner radius animating 14→0, other chrome fading; the real game view is already loaded beneath; total tap-to-playable ≤0.9 s with no black frame; implemented as an in-tree frame-animated overlay reusing the SAME player (no matchedGeometryEffect across the root swap, no player restart). | A black or frozen frame; a hard cut; a new player spun up for the transition; game view loading only after the picker is gone. |
| 8 | State truthfulness | Genre tag visible on every card in every state; "BEST n" appears iff `PlayerStore.bestScore > 0` and matches the store; RESUME capsule (coral/ember) + 13 pt corner badge appear iff a mid-run save exists, PLAY (torch/ink) otherwise; whole card launches, peeked neighbor tap centers instead of launching. | BEST 0 rendered; stale/hardcoded scores; RESUME without a save; genre hidden once a score exists; neighbor tap launching a game. |
| 9 | Performance & player discipline | Code shows ≤3 AVPlayer items alive (focused ±1), only focused playing, teardown beyond ±1 and on close/launch/background; Low Power Mode and thermalState ≥ .serious force posters; muted playback coexists with Music audio; CPU sample under drag + video within the class of the game scenes (per GAME_FEEL practice). | Six players alive; players surviving screen dismissal; music stopping when the picker opens; no low-power path; visible hitching on flick-through. |
| 10 | Accessibility | Each card one VO element with name/genre/score/"Game i of 6" (+"Game in progress"); adjustable action pages with announcements; videos/posters/rail/strip/counter hidden as decorative; all targets ≥44 pt (capsule 44 tall, back 44, mini-signs 44 pitch); Reduce Motion = posters + crossfades + zero autonomous motion while paging and static count signals remain. | Cards exposing loose children; VO unable to page; any target <44 pt; RM still playing video or dropping/nudging/swaying. |
| 11 | Typography & palette fidelity | Every color greps to `P.*` (or an `RGB.lerp` of two P colors); torch appears only as PLAY fill and BEST label; Futura-Bold chrome with specified tracking, `relativeTo: .body`; nothing under 11 pt; name survives "CABANA CIPHER" at minScale 0.75 without truncation at AX sizes. | Hex/system colors outside P; torch on decorative elements; any 9–10 pt label; a truncated name at large Dynamic Type. |
| 12 | Device-range integrity | Screenshot (d): plate 58 / stripe 4 / footer 64 / capsule 44 uncompressed; window absorbs all shrink (≥350 pt tall at 375x667) and every game still reads as gameplay under the deeper crop; peek ≥26 pt; indicator strip ≥24 pt above the screen bottom. | Footer or capsule compressed; window cropped past recognizability; indicators kissing the home-indicator region; peek collapsing to a sliver. |

## Iteration log

| Iter | 1 Multi | 2 Preview | 3 World | 4 Peek | 5 Indic | 6 Motion | 7 Launch | 8 State | 9 Perf | 10 A11y | 11 Type | 12 Devices | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 8.0 | 9.3 | 9.7 | 5.2 | 9.0 | 9.0 | 8.3 | 9.8 | 8.7 | 7.0 | 9.5 | 8.0 | 8.46 | B+ |
| v2 | 9.8 | 9.5 | 9.8 | 9.3 | 9.8 | 9.5 | 8.8 | 9.5 | 9.2 | 9.3 | 7.8 | 9.5 | 9.33 | A− |
| v3 | 9.7 | 9.5 | 10 | 9.5 | 9.8 | 9.3 | 9.5 | 9.3 | 9.2 | 9.0 | 9.0 | 9.5 | **9.44** | **A+** |

v1→v2: peek re-anchored to the neighbor's on-screen edge (root cause of dims 1/4/12),
per-card VO adjustable action, launch overlay crop-matched to the window + wall fade,
Reduce Motion player gating, lagoon/twilight accents lerped toward blossom, 930px
re-encodes. v2→v3: home menu→game swap de-animated (launch ghost), overlay poster
underlay, capped @ScaledMetric plate/footer bands + AX1 screen / xLarge top-bar clamps
(CABANA CIPHER survives AX sizes), power/thermal/RM mid-session teardown with recovery,
quantized windowFrames writes, rail-end VO announcements, TIKI_BEST hook.
Three-judge panel (craft/UX/eng), unanimous A+ at v3; no dimension below 9.

Verification hooks (all DEBUG-only): `SIMCTL_CHILD_TIKI_PICKER=1` opens the picker on
launch (exists today in `HomeView.init`). For dimension 8, grade state variants either
by real play or by adding `TIKI_BEST=<game>:<n>` / `TIKI_SAVE=<game>` hooks in the
same pattern as `TIKI_POINTS` / `TIKI_BUY`. Wipe state with `simctl uninstall`.
Reduce Motion and Low Power are toggled in simulator settings; capture (f) with a
screen recording stepped frame-by-frame, per the burst-frame practice in
GAME_FEEL_RUBRIC.md.
