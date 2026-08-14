# App Store assets — screenshot set + preview video rubric

Grading scale per dimension: 0–10. **A+ bar: average ≥ 9.3 with no dimension below 8.**
The screenshot SET is graded as one unit (order matters); the preview video is graded
separately. Every iteration gets rendered at final resolution, viewed at thumbnail
size, and graded honestly. Improvements target the lowest dimensions first.

Grounded in what converts on the store: the first 3 screenshots drive ~60% of
install decisions; previews autoplay muted; Apple guideline 2.3.3 requires assets to
show the app in actual use. Reference class: Toon Blast / Two Dots / Monument Valley
store pages — caption-forward, brand-saturated, gameplay-honest.

## Hard spec gates (any failure = not shippable, regardless of score)

Screenshots (6.9" tier): exactly 1320×2868 portrait, PNG or JPEG, no alpha,
max 10 images. Preview video: 15–30 s (target 20–25 s), 886×1920 portrait,
H.264 `.mp4`/`.mov`, ≤ 30 fps, ≤ 500 MB, footage captured from the app itself —
no live action, no hands, no simulator chrome.

## Screenshot set — dimensions

| # | Dimension | What 10/10 looks like |
|---|---|---|
| 1 | First-frame hook | Screenshot 1 stops the scroll on its own: the most dramatic single image, value obvious at thumbnail size. The "6 games, one tiki world" USP lands before the user reads anything else. |
| 2 | Thumbnail readability | Captions legible at ~150 px wide: big type, ≤ 5 words, high contrast against its panel, one idea per frame. Nothing critical hidden under App Store UI overlap zones (bottom edge). |
| 3 | Benefit-led messaging | Captions sell outcomes and feelings ("Six games. One lounge."), not feature lists. The differentiators — one price, no ads, one illustrator's world, meta-progression — are explicit somewhere in the set. |
| 4 | Story arc | The set reads as a narrative: hook → core mechanics → variety across the 6 games → lounge meta-payoff → identity close. Each frame adds NEW information; no two frames make the same point. |
| 5 | Real, rich content | Every frame is genuine app UI in its most flattering populated state: mid-combo boards, solved puzzles, a filled lounge. No empty states, no mocked UI, nothing the shipping app can't show (Apple 2.3.3). |
| 6 | Brand cohesion | One palette (Palette.swift values), one type voice, mid-century flat-vector panel design. The marketing chrome looks like it was drawn by the same hand as the game. The set is unmistakably THIS app. |
| 7 | Craft | Pixel-crisp native-resolution renders, consistent margins and caption baselines across frames, clean device masking if framed, no compression artifacts, no clipped descenders, no stray status-bar oddities. |

## Preview video — dimensions

| # | Dimension | What 10/10 looks like |
|---|---|---|
| 1 | 3-second hook | Opens inside the world in motion — gameplay or living lounge — within the first second. No logo card, no title fade-in. The poster frame (chosen frame, not frame 0 by accident) works as a still. |
| 2 | Muted legibility | The whole story lands with sound off: short caption cards or in-world text carry the message; interactions are visually obvious (pieces snapping, tiles matching) without narration. |
| 3 | Scene economy | 1–3 core ideas max, each scene 2–4 s, hard cuts, zero dead time: no menu wandering, no loading, no repeated beats. Total runtime lands in the 20–25 s sweet spot. |
| 4 | Value narrative | Arc: world hook → real play across games (variety beat) → lounge fills up (meta payoff) → identity close (title + price promise). A viewer can retell the pitch after one muted watch. |
| 5 | Authenticity | Continuous real gameplay at believable speed, actual shipping UI, actual game feel (juice, springs, bursts visible). Nothing staged that the app can't do. |
| 6 | Brand cohesion | Caption cards use the app's own palette and type voice; transitions feel mid-century (hard cuts / flat wipes, no default cross-dissolves); reads as one piece with the screenshot set. |
| 7 | Craft | Smooth constant 30 fps, no stutter or dropped frames at cuts, clean 886×1920 crop with no letterbox slivers or simulator chrome, caption timing comfortable (≥ 1.5 s per card). |

## Iteration log — screenshot set

| Iter | 1 Hook | 2 Thumb | 3 Benefit | 4 Arc | 5 Content | 6 Brand | 7 Craft | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|
| v1 | 7.5 | 8.5 | 9 | 8.5 | 9 | 9 | 6.5 | 8.3 | B+ |
| v2 | 9.5 | 9.5 | 9 | 9.5 | 9 | 9.5 | 9 | 9.29 | A |
| v3 | 9.5 | 9.5 | 9.5 | 9.5 | 9.5 | 9.5 | 9 | 9.43 | **A+** |

v1 notes: lounge-full as frame 1 had a dead middle zone at thumbnail size; the
accent bar collided with headline descenders on every frame (read as a stray
underline); cipher/blueprints raws showed win modals instead of mechanics.

v2 notes (home title-card as hook, lounge moved to the $4.99 close, bar spacing
fixed, mid-play recaptures): hook now instantly legible; set order home → 5
mechanics → meta+price close. Zombie board still sparse; stacks sub was a label,
not a benefit.

v3 notes (zombie recaptured at 16 s autoplay for a dense 256-tile board; stacks
sub → "No timers. No pressure. Just stacking."): A+ bar met. Files:
`appstore/screenshots/final/*.png` + `final-jpg/*.jpg` (upload the JPEGs).

## Iteration log — preview video

| Iter | 1 Hook | 2 Muted | 3 Economy | 4 Narrative | 5 Authentic | 6 Brand | 7 Craft | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|
| v1 | 9 | 4 | 5 | 3 | 6 | 9 | 8 | 6.3 | D+ |
| v2 | 9.5 | 9 | 9 | 9 | 9.5 | 9.5 | 8.5 | 9.14 | A- |
| v3 | 9.5 | 9.5 | 9.5 | 9.5 | 9.5 | 9.5 | 9.5 | 9.5 | **A+** |

v1 notes: zsh env-passing bug (`env $2` without word-split) launched every
"game" scene on the home screen — the whole middle of the video was the same
menu. Caught by contact-sheet review, not by spec checks.

v2 notes (clips re-recorded with `${=2}`): real gameplay everywhere, but luau's
trim window landed entirely on its NEW BEST modal and zombie's fresh-launch
board was nearly empty; opening card flashed at 0.8 s.

v3 notes (luau re-shot with 0.4 s settle to catch live cascades, zombie re-shot
with 4 s autoplay lead-in, all cards ≥1.6 s): 26.2 s, 886×1920 H.264 30 fps
CFR, silent AAC track for uploader compatibility, one reward modal (CRACKED!)
kept as the story's payoff beat. A+ bar met. File:
`appstore/preview/tiki-games-preview.mp4`; poster frame suggestion at 22.2 s
(`poster-frame.png`, the populated lounge).

v4 (Carson's cut): gameplay only — opens directly on Tiki Stacks, drops the
home intro / title card / meta + price cards / lounge scene, ends when the
last game (Blueprints) finishes on its DRAFTED! modal. 16.2 s, same encode
settings; poster frame suggestion moved to 4.8 s (luau cascade).

Staging hooks (all DEBUG-only, prefix with `SIMCTL_CHILD_`): `TIKI_BG=<lounge|stacks|luau|zombie|cipher|blueprints|navigator|lagoon>` routes to a scene; `TIKI_POINTS=<n>` + `TIKI_BUY=all` stage the full lounge; `TIKI_AUTOPLAY=1` makes games play themselves (mid-combo boards, video footage); `TIKI_PUZZLE=<id>` opens a specific blueprint. Capture on iPhone 17 Pro Max sim (native 1320×2868); video via `simctl io recordVideo` → ffmpeg to 886×1920.

Navigator pacing knobs (DEBUG-only, for preview captures — defaults match live
game when unset): `TIKI_NAVIGATOR_SKY_MS` (watch-the-sky beat, 850),
`TIKI_NAVIGATOR_PEEK_MS` (exposure per wave, band value), `TIKI_NAVIGATOR_TAP_MS`
(autoplay tap cadence, 400), `TIKI_NAVIGATOR_WIN_MS` (autoplay dwell on win
panel, 900). In-app picker clip recipe (2026-07-16, `Previews/preview-navigator.mp4`):
`TIKI_NAVIGATOR_LEVEL=19` + AUTOPLAY + HIDE_CHROME + SKIP_COACH with
SKY_MS=350 / PEEK_MS=1050 / TAP_MS=170 / WIN_MS=650; record ~21 s on the
ProMax sim, trim P20-stars-lit → last frame before P22-stars-lit (two
passages incl. the 5×5→6×6 band jump; the loop seam lands on the peek flash),
encode `fps=30,crop=1320:2708:0:160,scale=930:1908` crf 21 → 7.2 s loop;
poster = frame 0.
