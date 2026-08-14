# Adding a game to Tiki Games — the blueprint

The repeatable pipeline for game #6 and beyond. Distilled from how the last four
games were actually built (GAMES_BUILD_PLAN.md, the rubric iteration logs, and
the code as of 2026-07-10). First target: **Hexic Arcade** (worked example at the
bottom).

Every file path below is relative to `TikiGames/TikiGames/` unless it starts
with `assets/`, `appstore/`, or `.github/`.

## The house method (applies to every stage)

- **Rubric first.** Before building a stage, add its section/row to the relevant
  rubric file. A+ bar everywhere: **average ≥ 9.3, no dimension below 8**.
  Screenshot on the simulator, grade honestly, iterate the lowest dimension
  first, log every iteration in the rubric file.
- **Verify by staging hooks, not by hope.** Every claim comes from a captured
  frame. `SIMCTL_CHILD_TIKI_*` env vars route and stage the app; `TIKI_AUTOPLAY=1`
  makes games play themselves. Stage runs on a **throwaway simulator**; after any
  autoplay on the live save, **clean bot pollution** (delete the bot `GameRecord`,
  restore wallet) — precedent in GAMES_BUILD_PLAN.md iter 3.
- **Honest ceilings.** Games historically stop at **A (~9.0–9.25)**: the last
  quarter-point is touch feel under a real thumb + the commissioned SFX pack.
  Record the caveat in the rubric log; don't inflate.
- **One commit per stage**, rubric-log update included (see git history:
  picker+pipeline, coach, progression each landed as one feature commit).
- **`xcodegen generate` after adding files.** `project.yml` globs the whole
  source folder, so there's no file list to edit — but the checked-in
  `.xcodeproj` must be regenerated.

## Stage map

| # | Stage | Main output | Gate |
|---|---|---|---|
| 0 | Define the game | Design section in GAMES_BUILD_PLAN.md | Carson signs off on name/skin/scene |
| 1 | Background scene | `<Name>BackgroundView.swift` | A+ row in BACKGROUND_RUBRIC.md game-scenes table |
| 2 | Game assets | SVGs in `assets/game/<name>/` + icon + imagesets | Render-graded A+ (40 px + grayscale reads) |
| 3 | Engine + view + registration | `<Name>Game.swift`, `<Name>View.swift`, all switches | Full loop verified via autoplay; clean build |
| 4 | Game feel | Juice pass | A row in GAME_FEEL_RUBRIC.md (caveats logged) |
| 5 | Onboarding | How-to panel + FirstRunCoach script | `<NAME>_ONBOARDING_RUBRIC.md` pass (both-condition bar) |
| 6 | Progression + economy | Depth states, milestone bits, lounge hooks | PROGRESSION_RUBRIC re-check + economy decisions made |
| 7 | Picker preview capture | `preview-<key>.mp4` + `poster-<key>.png` | PICKER_SPEC §14 acceptance |
| 8 | App Store assets | New raw/final screenshots, re-cut preview video | APPSTORE_ASSETS_RUBRIC A+ re-met |
| 9 | Counting sweep + ship | grep sweep, CI line, docs | Checklist below fully green |

Stages 1–2 can run in either order (both feed 3). Stages 4–6 iterate together
in practice. 7–8 need a playable, juiced game — footage is marketing, so it
comes last.

---

## Stage 0 — Define the game on paper

Add a numbered section to GAMES_BUILD_PLAN.md with:

- **Rules**: the canon mechanic, stated precisely (the 2048/nonogram/cryptogram
  sections are the model). Decide the run structure — move-limited score runs
  (Luau), endless-until-dead (Zombie/Stacks), or puzzle collection
  (Blueprints/Cipher). House positioning: **no timers, no lives, no dark
  patterns**.
- **Tiki skin**: name, scene concept, piece motifs, and the win moment. Names
  are tiki-native and trademark-safe (the 2048 clone is "Zombie", not "2048").
  Motifs come from the palette-native language (masks, mugs, hibiscus, fronds,
  the cat).
- **Scoring + economy**: how raw score maps to wallet points via
  `recordRun(game:score:earnScore:)` — tune so a decent run pays stacks-scale
  points (~+20–40). Precedents: Zombie `score/10`, Luau `score/3`.
- **Depth ladder** (progression): the one honest depth signal (score, tier,
  completion %) → 3–4 **named depth states** with thresholds. These become
  background stages and milestone bits (Stage 6).
- **Asset manifest**: tile SVGs (96-unit viewBox), specials, board chrome,
  one 40×40 game icon. Note which existing components get reused.
- **Picker metadata**: genre tag (e.g. "MATCH-3"), spoken genre, and an accent
  color — an unused `P.*` token, contrast pre-audited on plank/woodDark per
  PICKER_SPEC.md §5 (torch is reserved: it only ever means "gold/points").
- **Coach beats**: 2–3 tutorial beats, ≤ 6 words each, diegetic verbs
  ("Match three tikis", never "Tap to select").

## Stage 1 — Background scene

One new file: `<Name>BackgroundView.swift`. Copy the structural skeleton of
`LuauBackgroundView.swift`:

- `var phase: ProgressPhase = ProgressPhase()` — default renders today's scene
  exactly; depth/stage/tier/beat drive progression visuals later.
- One `TimelineView(.animation, paused: reduceMotion)` clock drives everything;
  ease depth with `DepthDial`; `.ignoresSafeArea()`.
- Inner `private struct <Name>Scene` composes flat `Canvas`/shape layers.
  Reuse `TikiScenery.swift` primitives (`P` palette, `PalmView`, `FlameShape`,
  `CatView`, …). Palette breathes on the ~90 s cycle; depth raises the breath's
  floor, never replaces it.
- Pick a time-of-day/palette slot not yet taken (current scenes: purple-sunset
  deck, night bonfire, bar interior, poolside day, volcanic-cove night, lagoon).

Wire a preview route: add the scene to the `TIKI_BG` switch in
`ContentView.swift:15-24`, then iterate with
`SIMCTL_CHILD_TIKI_BG=<name>` launches.

Grade against BACKGROUND_RUBRIC.md (8 dimensions) and add a row to its
game-scenes table. **Overlay readiness is the game-critical dimension**: the
center band (~15–85% width, ~45–75% height) stays calm and low-contrast so the
board sits legibly; motion lives at the edges. Known traps from the logs: dead
middle zones at thumbnail size, stars against warm bands, silhouettes that
don't survive a squint, islands straddling the horizon.

**Exit:** A+ row logged. Include the narrative-wit beat (something is
happening: a cat watching, a silent story).

## Stage 2 — Game assets

- Author SVGs in `assets/game/<name>/` per the **SVG_ASSET_PROMPT.md contract**:
  root `<svg viewBox>` only (no width/height), **no `<text>` ever**, ≤ 40
  elements, ≤ 8 KB, ≤ 1-decimal coords, **palette hexes only** (the ~24 allowed
  colors are enumerated there — same values as `P.*`). Tiles use the 96-unit
  tile-plate language (`assets/game/zombie/` and `/luau/` are the models).
- Game icon: one **40×40 SVG** in `assets/game-icons/<name>.svg`.
- Mirror by hand into the asset catalog (there is no sync script): tiles under
  `Assets.xcassets/<Name>Assets/`, icon as
  `Assets.xcassets/GameIcons/<Name>Icon.imageset` — universal SVG,
  `preserves-vector-representation: true` (SVGs ship as vectors; nothing is
  rasterized).
- Add typed accessors in `Sprites.swift` (pattern: `Image.zombieTile(_:)`,
  icon statics at `Sprites.swift:67-71`).
- **Render-grade the strip**: every tile readable at 40 px, tier/type
  escalation legible in grayscale, ≤ 5 hexes each. Precedent: one Zombie tile
  was hand-redrawn after failing the 40 px read. Grade prompts with
  SVG_PROMPT_RUBRIC.md if workflow-authoring the art.

**Exit:** strip render-graded A+; accessors compile.

## Stage 3 — Engine + view + registration

**Engine — `<Name>Game.swift`** (~380–710 lines by precedent):
`@Observable final class`, pure state machine, no timers/CADisplayLink. Must
have: `static depthThresholds`, `configureBest(_:)`, seeded-tutorial-board
support (`seedTutorialBoard/Reveal`), and a nested `struct SavePayload: Codable`
(including `seenHowTo`) with `payload(seenHowTo:) -> String` / `restore(from:)`.
Where restore must reproduce a board, derive it deterministically (Cipher's
per-phrase ciphers are the precedent).

**View — `<Name>View.swift`** (~710–1030 lines):
`@Environment(PlayerStore.self)`, `@State private var game = <Name>Game()`,
body = `GeometryReader { ZStack { <Name>BackgroundView(phase: scenePhase);
chrome; board; overlays } }.ignoresSafeArea()`, a computed
`scenePhase: ProgressPhase` mapping engine state to the background, own haptic
generators (no shared service). Canonical `start()`:
`guard !started` → `configureBest(store.bestScore(for:))` →
`restore(from: store.loadState(for:))` → onboarding decision → `persist()` →
DEBUG env hooks. Game-over path: milestone bits → `store.recordRun(...)` →
panel with `RunSummary` + gold "WALLET N · NEW ITEM IN THE LOUNGE" line +
`MilestoneToast`. Persist state on every move via
`saveState/loadState/clearState(for:)` — a run must survive an app kill.

**Registration** — adding the enum case makes the compiler enforce most of the
checklist. Switches that must gain a case:

| What | Where |
|---|---|
| `case <name>` + `displayName` + `icon` | `Sprites.swift:74/82/92` |
| `pickerAccent` / `pickerGenre` / `pickerGenreSpoken` / `depthAccents` | `GamePickerView.swift:1152/1162/1172/1185` |
| `previewClipKey` | `GamePreview.swift:96` |
| `milestoneBits(for:)` | `PlayerStore.swift:320` (Stage 6) |
| `gameView(for:)` routing | `ContentView.swift:79` |
| `TIKI_BG` direct-launch case | `ContentView.swift:15-24` |

Not compiler-enforced (easy to forget): icon imageset, preview media files
(Stage 7 — a placeholder poster is fine until then; the poster always underlays
so a missing clip degrades gracefully), `CoachSkin` (Stage 5), retro-credit
branch (Stage 6), `xcodegen generate`.

SwiftData needs **no schema change** — `GameRecord` and `GameSaveState` rows
are keyed by `TikiGame.rawValue` and fetch-or-created lazily.

**Autoplay driver**: every game view implements a `TIKI_AUTOPLAY=1` bot (plus
per-game staging hooks like `TIKI_PUZZLE=<id>` where useful). This is not
optional polish — it's how mid-action frames get captured for grading (Stage 4)
and how all footage gets recorded (Stages 7–8).

**Exit:** on a throwaway sim, autoplay drives the full loop — play → game over
→ wallet line → relaunch → resume from save. Sound via the shared `TikiSound`
vocabulary only (`tick/pop/clear(intensity:)/mistake/win/gameOver` — no new
audio assets). Build clean; bot pollution removed from any live save.

## Stage 4 — Game feel to A

Add a section to GAME_FEEL_RUBRIC.md; keep dims 1/5–8, rename 2–4 to the
mechanic (Zombie's "swipe feel", Blueprints' "paint feel"). The juice canon:

- Every input acknowledged < 100 ms, visually + haptically; nothing lands
  silently. Pieces pop-settle with springs, never just appear.
- Clear spectacle escalates: dissolve + burst, "+N" popups floating from the
  action, combo banners on the established ladder (cream ×2 → gold ×3 →
  coral ×4+), NEW BEST as a moment.
- **Refusal reads**: rejected moves nudge-and-spring-back (Zombie's rejected
  swipe, Luau's swap-and-return) — silent refusal is a bug.
- Animations never block input; 60 fps through the heaviest clear (CPU-sample
  the worst moment; ~24–30% single-core on the CPU-rendered sim is the
  established healthy range).

Capture mid-action frames via autoplay and grade. **Exit:** A row (≥ 9.0)
logged with the standard honest-ceiling caveat (thumb feel + SFX pack — needs
human playtest notes to go further).

## Stage 5 — Onboarding (two layers)

**Reference layer — HowToPlay panel**: build a `[HowToRule]` list (3–4
illustrated rows, sprite + one Futura sentence) + title, wire
`HowToPlayButton` top-right. Auto-shows on first run via `seenHowTo` in the
save payload. Model: `CipherView.swift:60-68`.

**Coached layer — FirstRunCoach**: one skeleton, per-game wardrobe.
- Add a `CoachSkin` static in `FirstRunCoach.swift` (colors, radii,
  `arrowGlyph`, `dismissSound`, `cardPosition`). Reuse an arrow glyph or add
  one (enum at `:14`, shapes at `:603-792`).
- **Seeded first board**: fixed, hand-authored — first competent gesture
  succeeds ≥ 95% of the time. RNG on first launch is a disqualifier.
- Script 2–3 beats: card copy ≤ 6 words, diegetic verbs; `CoachPulse` +
  `CoachArrow` track live targets; advance only on real success; SKIP sets
  `store.onboardingSkipped` (bundle-global — respect it on entry); success ends
  with `TutorialReadyBanner("READY TO <VERB>")`.
- The end-to-end pattern to copy is Cipher: `CipherView.swift`
  `start()`/`coachMessage`/`advanceTutorial()`/`dismissCoach(withSuccess:)`.

Write `<NAME>_ONBOARDING_RUBRIC.md` on the shared 9-dimension method
(ONBOARDING_RUBRIC.md): time-to-first-action ≤ 5 s, seeded first-success,
minimal-text framing, etc. **Pass bar is two-part** (avg ≥ 9.3 AND no dim < 8).
Also check the post-tutorial reveal against POST_TUTORIAL_REVEAL_RUBRIC.md.

**Exit:** rubric pass, verified from captured first-run frames on a fresh
install.

## Stage 6 — Progression + economy wiring

The background is the score display (PROGRESSION_PLAN.md): map the engine's
depth signal onto `ProgressPhase` and light the named states up in the scene.

Mechanical checklist:
- Claim the **next free milestone bit range** — bits 0–17 are taken (Stacks
  0–3, Zombie 4–7, Luau 8–10, Blueprints 11–13, Cipher 14–17); a new game
  starts at 18. Add the case in `milestoneBits(for:)` (`PlayerStore.swift:320`).
- Bit-check loop in the game-over path (pattern `LuauView.swift:171-183`);
  each first reach pays the +75 mint via `recordMilestone` and shows the toast.
  Never route bonuses through `recordRun` (it pollutes `gamesPlayed`).
- Add the case to `retroCreditMilestonesIfNeeded()` (`PlayerStore.swift:496-526`)
  — a no-op returning nothing for a brand-new game (no history exists), but
  the switch stays exhaustive and the pattern stays complete.
- One **earned aesthetic**: a permanent scene decoration derived from persisted
  stats (Luau's lantern count from bestScore is the model). Never sold, never
  free.
- `depthAccents` for the picker card tint (deepest-state trophy read).

**Decisions that need Carson** (a new game shifts the economy):
1. **Neon Sign gate** — `signUnlocked` (`PlayerStore.swift:356`) requires a
   milestone bit in *every* game. Include game #6 (purist) or freeze the gate
   at the launch five? Existing owners are unaffected either way.
2. **House Standing thresholds** (`houseStanding`, tiers from total milestone
   count) — adding ~3–4 bits raises the max; re-check tier feel.
3. **Aquarium fish** (`PlayerStore.swift:364-366`) — does the new game's top
   bit stock a fish?
4. **Wallet pacing** — +75 × N new mints plus a sixth earner; re-check against
   shop prices (evidence shots go in `build/progression-shots/economy/`).
5. **Lounge window** — optionally gate a `LiveWindowView.WindowViewKind` scene
   on the new game's top bit.

**Exit:** depth states verified in-scene by screenshot ladder
(`depth0…` shots), PROGRESSION_RUBRIC re-check, decisions logged.

## Stage 7 — Picker preview capture (the in-app screen recording)

The picker's live gameplay window needs two committed bundle assets in
`Previews/`:

- `preview-<key>.mp4` — **930×1908 portrait, ~6–8 s loop, muted**, real
  gameplay (autoplay), near-full-screen capture with the game HUD visible,
  top-cropped below the recorded status bar.
- `poster-<key>.png` — a matching still through the **exact same crop math**
  (poster→video crossfade must be pixel-aligned).

Recipe: boot the capture sim → launch with
`SIMCTL_CHILD_TIKI_BG=<name> SIMCTL_CHILD_TIKI_AUTOPLAY=1` →
`xcrun simctl io <sim> recordVideo clip.mov` → trim to the best 6–8 s of
mid-action play → ffmpeg to 930×1908 H.264. `previewClipKey`
(`GamePreview.swift:96`) maps the enum case to the filenames.

**Exit:** PICKER_SPEC.md §14 acceptance — status bar absent, HUD visible,
board readable in-window at 393×852 AND 375×667, no black frames on fast
paging, launch-expansion seam acceptable.

## Stage 8 — App Store assets refresh

Adding a game reopens both A+ logs in APPSTORE_ASSETS_RUBRIC.md. Hard gates:
screenshots exactly 1320×2868 (≤ 10, no alpha); preview video 15–30 s,
886×1920, H.264, ≤ 30 fps, footage from the app itself, no simulator chrome.

- **CI capture line**: add a `shoot NN-<name> <sleep> SIMCTL_CHILD_TIKI_BG=<name>
  SIMCTL_CHILD_TIKI_AUTOPLAY=1` entry to `.github/workflows/build.yml`.
- **Screenshots**: capture `raw/<name>-mid.png` on the iPhone 17 Pro Max sim
  (native 1320×2868) with autoplay warmed up enough for a **dense, mid-action
  board** (Zombie's sparse first-frame board forced a re-shoot at 16 s — give
  the bot a lead-in). Add a `Frame` entry to
  `appstore/tools/compose_screenshots.swift`, re-run
  `swift compose_screenshots.swift <rawDir> <outDir>`, re-grade the SET as a
  unit (order/arc may change), and re-export the upload JPEGs.
- **Preview video**: record `appstore/preview/clips/<name>.mov`, re-cut
  (the shipping cut is Carson's v4: gameplay-only, opens on Stacks — a sixth
  game extends it; keep 20–25 s by tightening beats), re-encode 886×1920 CFR
  30 fps with the silent AAC track. **Always contact-sheet the cut** (frames in
  `appstore/preview/frames/`) — the v1 zsh env bug shipped a video of five
  identical menu shots and only the contact sheet caught it. When invoking the
  env-per-scene recording pattern from zsh, remember the `${=var}` word-split
  fix.
- **Copy sweep in the marketing set**: "FIVE GAMES. / ONE LOUNGE." (hook
  frame), `card-fivegames.png` (`compose_cards.swift`), and the $4.99 close all
  hard-code the count.

**Exit:** both iteration logs re-graded to A+ at the new content.

## Stage 9 — The counting sweep + ship checklist

The app's identity says "five games" in many places. Sweep before ship:

- [ ] `grep -ri "five\|of 5\|5 games\|5-game" TikiGames/ appstore/ assets/ README.md`
      — fix or consciously keep each hit.
- [ ] Picker: counter ("Nº k OF n"), indicator strip, and VoiceOver labels
      ("game i of n") — verify they derive from `PickerSlot.all.count`, not a
      literal 5.
- [ ] `TikiSound.railTick(step:)` pentatonic settle ladder — confirm it has a
      note for the new page index (spec shipped 5 rate multipliers).
- [ ] ONBOARDING_RUBRIC.md scope text ("the five casual-puzzle titles") and any
      rubric that enumerates games.
- [ ] README.md product copy + App Store description.
- [ ] `xcodegen generate` run; clean build; CI green with the new shoot line.
- [ ] GAMES_BUILD_PLAN.md status entry + all rubric logs updated.
- [ ] SwiftData **upgrade-in-place test** from the current TestFlight build
      (mandatory per PROGRESSION_PLAN.md whenever persisted shapes change).
- [ ] Bot pollution cleaned from any live save used during capture.
- [ ] Existing pre-ship items still tracked separately (commissioned SFX pack;
      the docs art-reference sweep).

---

## Worked example — Stage 0 draft for Hexic Arcade

**Mechanic** (rotational hex-match, the Pajitnov design): offset hex grid
(~7 columns). Tap a Y-junction where three hexes meet → the trio rotates one
step (tap again within the window to keep rotating — same input language as
Stacks tap-to-rotate). A rotation that forms a cluster of 3+ like pieces clears
it; pieces fall down hex columns; cascades chain. A **flower** (6 alike around
one center) births a special. Run structure to decide: move-limited
("N rotations per night", Luau precedent — matches can refund moves) vs.
endless with no-move-left ending. No timers either way.

**Name** — "Hexic" is a Microsoft trademark; the working title stays internal.
Tiki-native candidates, Carson's call:
- **Tide Pool** — dawn rocky-shore scene; hexagonal **basalt columns** (real
  volcanic geology) make the hex board diegetic.
- **Honu** — sea-turtle shell scutes are natural hexagons.
- **Basalt Bay** — same geology, moodier read.

**Scene** (Stage 1): dawn/low-tide shore — an unclaimed palette slot (soft
pinks/golds over wet-sand neutrals). Basalt column terraces frame the edges;
tide pools glint; the cat prods a starfish. Board floats over the calm
center band.

**Pieces** (6 types + specials, 96-unit plates): turtle scute, pineapple cell,
honeycomb, sea glass, shell, urchin. Flower-special candidates: torch
(line-clear analog) and the cat (board-wide, of course it's the cat).

**Depth ladder**: signal = score. Named states, tide-themed: FIRST LIGHT →
TIDE TURN → HIGH TIDE → KING TIDE (milestone bits 18–21; thresholds tuned in
playtest, single constants at the call site).

**Economy**: earnScore ≈ `score/3` (Luau-scale cascade scoring) — verify a
decent run pays +20–40.

**Picker**: genre "HEX MATCH" / spoken "Hex match"; accent = an unused `P.*`
(likely a green/fern token if free — contrast pre-audit on plank/woodDark, with
the `lerp(P.blossom, 0.25)` fallback if it's dark-on-dark).

**Coach beats** (≤ 6 words): "Spin the tide pool" → "Match three shells" →
"Flowers make magic" (exact copy in Stage 5).

**Sizing**: Luau-class engine — the biggest build class (hex adjacency,
rotation resolution, gravity along hex columns, stepped cascades). History says
budget for it: Zombie took 4 logged iterations, Blueprints 3, Cipher/Luau 1–2
each *after* the shared infrastructure existed. Hexic adds a new scene + full
asset set + the usual pipeline, so expect the long end.
