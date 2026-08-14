# The four games — build plan

**STATUS: ALL FOUR GAMES BUILT AND GRADED (2026-07-02).** Zombie A (9.06),
Blueprints A (9.25), Cabana Cipher A (9.13), Luau A (9.13) — per-game
sections + iteration logs in GAME_FEEL_RUBRIC.md. Every game: tiki assets
(A+ render-graded where applicable), how-to panel (auto-shows first run),
SwiftData save/resume via GameSaveState, recordRun wallet economy tuned to
stacks scale, autoplay dev hooks, isPlayable — the picker grid shows five
playable games, zero SOON tags. The shared honest gap to A+ everywhere:
touch feel under a real thumb + the commissioned SFX pack (see rubric
caveats — needs human playtest notes).

Working doc for the build-all-games loop. Each game: rules → asset strategy →
tiki-themed assets (A+ by render-grading) → implementation → juice/SFX/UX →
how-to-play → grade vs the GAME_FEEL_RUBRIC method until A+. Build order:
**Zombie → Blueprints → Cabana Cipher → Luau** (self-contained first, biggest last).

## Shared infrastructure (build once, with Zombie)

- **SwiftData save state** (per the brief: every game leverages SwiftData).
  New `@Model GameSaveState { @Attribute(.unique) gameID, payload: String,
  updatedAt }` — one generic row per game holding JSON state, gated through
  PlayerStore (`saveState(for:)/loadState(for:)/clearState(for:)`). Zombie
  persists the live board (a 2048 run survives app kills); Blueprints and
  Cipher persist solved-puzzle IDs + in-progress grid; Luau persists level
  progress. Scores/points continue through the existing `recordRun`/GameRecord.
- **HowToPlayButton + panel**: flat "?" circle button (top-right, under the
  scene's chrome line), opening a shop-style panel: wood header with the game
  name, cream body, 3–4 illustrated rule rows (sprite + one Futura sentence),
  "GOT IT" capsule. One reusable component, per-game content. Auto-shows on
  first launch of each game (SwiftData: `seenHowTo` flag in save state).
- **SFX**: keep the Tiki Stacks convention (AudioToolbox system percussion +
  haptics — placement pattern lives at TikiStacksView.swift:18-19, 49-53)
  with per-game sound choices; the commissioned exotica pack remains the
  pre-ship upgrade path.
- **Game-over → wallet handoff**: every game ends with recordRun + the gold
  "WALLET N · NEW ITEM IN THE LOUNGE" panel line, same as Tiki Stacks.

## 1. Zombie — 2048 merge (bar interior scene)

**Rules** (2048 canon): 4×4 grid; swipe slides all tiles; equal tiles merge
into the next tier (one merge per tile per swipe, resolved in swipe direction);
every swipe spawns a new low tile (90% tier-1, 10% tier-2) in a random empty
cell; game over when no move changes the board. Score: classic scoring adds
the merged tile's value per merge.

**Tiki skin — the drink ladder** (merge two of a drink → one stronger drink;
the board is Vic mixing): 1 Coconut Water → 2 Pineapple Juice → 3 Lime
Daiquiri → 4 Mai Tai → 5 Piña Colada → 6 Blue Hawaii → 7 Fog Cutter →
8 Scorpion Bowl → 9 Navy Grog → 10 Flaming Volcano → 11 **THE ZOMBIE**
(reaching it = the win moment; the scene's smoking vessel is the endgame's
face). Tier number pips/labels drawn in SwiftUI (SVGs carry no text).

**Assets** (`assets/game/zombie/`, imagesets under a ZombieAssets group):
11 tile SVGs `zombie-tile-01` … `zombie-tile-11`, viewBox 0 0 96 96: rounded
tile plate + centered drink glyph, escalating visual heat (cream/lagoon calm
tiers → torch/coral/ember flame tiers; THE ZOMBIE reuses the carved-vessel
look from ZombieMugView). Board frame: reuse the Tiki Stacks BoardFrame
pattern (code-drawn or reuse asset). Existing orphans drink-coconut/maitai
SVGs are concept references for tiers 1/4.

**Grading**: tile strip render-graded (readable at 40 px, ≤5 hexes each, tier
escalation legible in grayscale); gameplay graded on the GAME_FEEL_RUBRIC
dimensions adapted to merge (swipe feel replaces drag feel).

## 2. Blueprints — nonogram (volcanic cove scene)

**Rules**: grid with per-row/per-column run-length clues; fill or mark-empty;
puzzle solved when fills match the hidden picture exactly. Mistake handling:
choose "mistakes allowed, counted" (casual-friendly).

**Tiki skin**: each puzzle reveals a tiki pixel-picture (mask, palm, mug,
cat, volcano...) that colorizes on completion — the scene's star-cluster
pixel-pictures foreshadow this. Puzzle sizes 5×5 (tutorial), 8×8, 10×10.
Puzzles authored as bitmaps in code (SwiftData tracks solved IDs + the
in-progress grid).

**Assets**: mostly code-drawn (grid, clues use Futura numerals). Needs: ~12
puzzle bitmaps (authored, not SVG), a small "blueprint sheet" board chrome,
completion stamp. Light asset load.

## 3. Cabana Cipher — cryptogram (poolside scene)

**Rules**: a short phrase is letter-substitution encrypted; player assigns
letters via a keyboard of tiles; solved when all letters correct. Hints:
reveal-a-letter costs points earned that run (design in build phase).

**Tiki skin**: phrases = exotica-lounge one-liners and tiki-bar wisdom
(original copy, no quotes from living artists). Letter tiles echo the
Tiki Stacks block language.

**Assets**: letter-tile chrome (code-drawn rounded tiles), poolside-styled
solved stamp; a phrase corpus (~40 originals) authored in code. Light asset
load. SwiftData: solved-phrase IDs + current assignments.

## 4. Luau — match-3 (night bonfire scene)

**Rules**: 8×8 board; swap adjacent to make 3+ lines; matches clear, pieces
fall, refills cascade; 4/5-matches spawn specials (line-clear torch, color
bomb). Move-limited score runs (no lives/timers — respects the paid-app, no
dark patterns positioning).

**Tiki skin**: 6 piece types from the palette-native motifs: hibiscus,
tiki mask, mug, glass float, frond, flame. Specials: torch (line), the cat
(color bomb — of course it's the cat).

**Assets** (`assets/game/luau/`): 6 piece SVGs + 2 special SVGs at 96 px,
same tile-plate language as Tiki Stacks blocks. Biggest engine build:
match detection, gravity, cascade resolution, specials.

## 5. Honu — rotational hex-match (dawn lagoon scene) — game #6

Stage 0 design per NEW_GAME_BLUEPRINT.md. Hexic-canon rules verified
2026-07-11 (Wikipedia + two corroborating guides). Name locked by Carson:
**Honu** (Hawaiian green sea turtle — shell scutes are natural hexagons).

**Rules (Hexic canon, adapted)**: flat-top hex board, 7 columns falling
vertically (alternating column heights 8/7 → 53 cells; exact pt-metrics are
a Stage 3 layout decision). Tap a Y-junction where three hexes meet → the
trio tries one step **clockwise**; tapping the same junction again after a
refusal tries **counterclockwise** (alternating — Carson's tap/double-tap
call, 2026-07-12; the refusal nudge leans in the attempted direction so
the alternation reads). A spin **sticks only when it completes a match —
otherwise it springs back** (canon: pieces change position permanently
only through a match of 3+; corrected from the v1 "rotations persist"
misreading). Every attempt counts as a move and ticks urchin fuses — one
tap, one tick, like one button press in Hexic HD. The pearl's
rotate-six (when built) is the free rotation, which is what makes it
special. If no rotation anywhere can make a match, THE TIDE STIRS
(reshuffle, Luau precedent — Hexic HD also guaranteed a move). A rotation
that assembles a cluster clears it: a cluster is the union of monochrome
vertex-triangles (three same-type pieces around a shared vertex — a
same-type *line* does NOT clear; canon). Pieces fall down their columns,
refills spawn at column tops, cascades chain.

- **Flower**: six same-type pieces surrounding any center → the six clear
  and the center blooms into a **PEARL**.
- **Pearl** (starflower analog): tapping it rotates all six neighbors one
  step — **the free rotation** (canon: sticks with or without a match; it
  still ticks fuses as a move). Built 2026-07-12; CW per tap, a CCW
  gesture is an open Stage 4 item; edge pearls (incomplete ring) refuse.
  Pearls fall like pieces; three pearls in a triangle clear for mega
  points. The black-pearl tier (flower of pearls, Y-rotation,
  transcendent ending) is **CUT from v1** — logged as post-ship
  deepening; casual reach is ~zero.
- **Urchin — the bomb, and the only death**: arrives via refill as a
  colored piece wearing a move-countdown (digits are SwiftUI overlays,
  never SVG text). Every move ticks every urchin down 1. Clearing it in a
  cluster/flower of its color defuses it (+bonus). Any urchin reaching 0
  bursts → run over. There is no no-moves death (a rotation is always
  legal) — **urchin pacing IS the difficulty curve**. Fairness rule: an
  urchin's color is sampled from pieces currently on the board (weighted by
  presence), never a color the board lacks.
- **Run structure**: endless survival, no timers/lives (house positioning);
  a run ends only by urchin burst. The first urchin arrives early (~a dozen
  clears) so pre-bomb farming never dominates; spawn interval tightens and
  starting counters ease down with score. All pacing constants at one call
  site.

**Tiki skin**: dawn lagoon at first light — the unclaimed palette slot
(soft pinks/golds over wet sand and teals). Basalt columns frame the edges
(hexagonal volcanic geology keeps the board diegetic); a resident honu
glides through and surfaces for a breath; the cat watches from a basalt
column, transfixed (narrative-wit beat). Board chrome: a shell-rim "reef
mosaic" plate over the calm center band. Win moments: PEARL BLOOM (flower
clear → pearl forms) and defusing an urchin at 1.

**Pieces** (6 types + 2 specials, 96-unit tile plates, shape-first identity
that survives 40 px + grayscale): starfish (5-arm), cowrie shell (oval,
toothed slot), sea glass (rounded gem), sand dollar (etched disc), anemone
(tentacled ring), limpet scute (ribbed cone). Specials: pearl (lustrous
orb, glow), urchin (spiked ball tinted to its match color, pip ring for the
countdown). Colors from the SVG contract palette only.

**Scoring + economy**: triangle = 30, +15 per extra piece; cascade
multipliers on the established banner ladder (cream ×2 → gold ×3 →
coral ×4+); flower = 200; pearl triangle = 500; urchin defused = +150.
earnScore ≈ `score/3` (Luau-scale) — verify a decent run pays +20–40 wallet
against the Stage 6 bot distribution before locking.

**Depth ladder** (signal = run score): HATCHLING → **DRIFTER** →
**WAYFINDER** → **ANCIENT ONE** — named states light the dawn scene deeper;
thresholds are single constants tuned from bot n≥300 in Stage 6 (Luau's
pacing lesson: set from the bot floor, not intuition). Milestone bits
**18–21**: 18/19/20 = first DRIFTER/WAYFINDER/ANCIENT ONE, 21 = first pearl
bloomed. Earned aesthetic: hatchling tracks accumulate on the dawn beach
from lifetime pearls (persisted stat) — never sold, never free.

**Picker metadata**: genre chip "HEX MATCH" / spoken "Hex match". Accent:
**olive `#7A8B2E`** (retro green — the sea-turtle color; in the SVG
contract, unused by any card, not yet a `P` token — Stage 3 adds `P.olive`
and pre-audits stripe contrast on plank/woodDark, falling back to
`lerp(P.blossom, 0.25)` if the read is dark-on-dark). Torch stays reserved
for gold/points.

**Coach beats** (≤ 6 words, diegetic; seeded first board makes beat 2
succeed in one tap): "Tap where three tiles meet" → "Match three of a
kind" → READY TO DIVE banner. Urchins and pearls are NOT coached — the
first urchin spawn fires a one-shot hint (Stacks precedent), and the how-to
panel carries flower/pearl/urchin rows.

**Open for Carson (Stage 6 economy gates, per blueprint)**: Neon Sign gate
(include Honu in `signUnlocked` or freeze at launch five), House Standing
thresholds at >18 bits, aquarium fish for Honu's top bit, wallet pacing
re-check, optional Honu lounge window.

**Sizing**: Luau-class or larger (hex adjacency, junction hit-testing,
rotation resolution, hex gravity, cascades, urchin pacing) — budget the
long end per the blueprint.

## 6. Navigator — memory flash (open-ocean night scene) — game #7

Stage 0 design per NEW_GAME_BLUEPRINT.md, drafted 2026-07-12. Mechanic is the
memorize-and-reproduce pattern (Simon 1978 → Lumosity "Memory Matrix" → the
GTA-RP "thermite" minigame that prompted this). Provenance is mechanical
only — generic memory-game pattern, zero GTA/NoPixel references anywhere
in-app or in store copy (same hygiene as the art-reference sweep).
**Stage 0 gate PASSED (Carson, 2026-07-12): name Navigator · open-ocean
night scene · 150-level campaign.**

**Rules**: an n×n sky board (3×3 → 6×6 across the campaign; masked sky
shapes — cloud banks and island silhouettes — are the board-shape lever). A
star pattern glows for a **peek window** (~1.2–5 s), then fades behind
clouds; chart every star from memory by tapping cells. Correct tap = the
star ignites and stays; wrong tap = cloud puff, cell dims (won't re-trigger),
one mistake spent. Two per-level budgets, both bot-solved: **mistakes**
(2–5) and **re-peeks** (0–3; a peek re-shows only the *remaining* stars at
~60% of the original window). Input is untimed — the peek is exposure, not
pressure; house positioning holds (no timers, no lives, free instant
retry). Retry re-rolls the pattern attempt-salted (Luau precedent: the
level's parameters are fixed, the stars are fresh — same-pattern retries
would collapse difficulty). Teaching levels use fixed hand-authored seeds.
Lose line: THE CLOUDS CLOSE IN.

- **Run structure**: level campaign (Luau CAMPAIGN-200 machinery),
  **150 levels** (locked, Carson 2026-07-12), L1–12 hand-authored teaching arc, rest
  LevelForge-generated. Bands by recall-bot win rate, Luau's exactly:
  teaching ≥ 90% / easy 75–90 / medium 55–75 / hard 35–55; budget =
  min(band, median×1.35) pattern carries over. Expected-attempts texture:
  nothing in the campaign above ~3 expected attempts.
- **Difficulty levers, in order of power**: star count (3 → 12) ·
  **scatter** (pattern entropy — constellation-shaped clusters chunk, noise
  doesn't; the lever IS the fiction, see skin) · grid size · peek duration ·
  **waves** (chart revealed in 2–3 parts, L~9+) · **decoys** (shooting
  stars during the peek are not chart stars, L~10+) · budget scarcity.
  Campaign hard-caps at 6×6 / ≤ 12 stars — NoPixel-standard (14/36) is
  deliberately just past the finale. **Deferred (Carson 2026-07-12):
  7×7–8×8 expert ascent mode — revisit post-campaign.** Late-campaign
  binding mechanic (stars vs moons, chart only the called kind) is a
  Stage-C-calibration decision, not a v1 commitment.
- **LevelForge extension**: the bot is a **recall model**, not a greedy
  policy — capacity-limited memory with a chunking bonus for adjacent
  stars and decay scaling with grid size; n = 400 runs per evaluation;
  solve mistake+peek budgets into band; auto-reject luck-dominated levels
  (win rate insensitive to ±1 mistake). Calibration caveat is *bigger*
  than Luau's (human memory variance > match-3 variance): Carson
  felt-samples ~10 levels across bands, anchor ~70–80% first-try at
  medium; widen easy rather than soften the finale. Full pipeline doc =
  NAVIGATOR_LEVELS_PLAN.md when campaign work starts.

**Tiki skin**: **Navigator** (locked — the wayfinding role: you are the
one who holds the chart). Checked against shipped copy: no collisions
(Honu's WAYFINDER and Stacks' MOONRISE / GLOW TIDE ruled out the earlier
candidates); "Hōkūleʻa" deliberately avoided
(real voyaging canoe — cultural care); constellation figures are invented
generic Pacific motifs (canoe, sail, frigate bird, honu, hibiscus — no
claimed star lore). Scene: **open-ocean night passage** — sky-dominant
starfield over calm swell, outrigger silhouette low in frame, the cat
curled on the prow watching the sky (narrative-wit beat). Third night
scene, differentiated by temperature: cool silver/indigo/bioGlow against
Luau's warm bonfire and Blueprints' volcanic reds; the board floats in the
sky itself, so the calm center band is overlay-native. The mechanic is
fully diegetic: clouds roll over the chart (the fade), a break in the
clouds (re-peek), a shooting star (decoy). Win moment: the constellation
ignites and draws its figure — connecting lines trace between the charted
stars.

**Board + assets** (96-unit plates, lightest strip yet): sky cell plate,
star (idle / lit / ignited — glyph must survive 40 px + grayscale),
moon (binding kind, authored only if Stage C keeps it), shooting-star
decoy, cloud wisp, carved chart-frame chrome, 40×40 icon (star cluster
over an outrigger). Constellation families double as the archetype system
for generation (the Luau mask-family analog).

**Scoring + economy**: +25 per star, streak bonus for consecutive
no-mistake charts, clear bonus scaled by band, perfect-chart bonus (no
mistakes, no peeks). earnScore ≈ `score/3` → verify a decent session pays
+20–40 (short easy levels pay small — replay-farm-safe, Luau precedent).
All constants tuned against the Stage 6 bot distribution.

**Depth ladder** (signal = levels completed, the campaign-game precedent
from Luau Stage E): HARBOR → **REEF PASS** → **OPEN OCEAN** → **LANDFALL**
— the outrigger advances across the scene, stars multiply, landfall
silhouette rises at the horizon with first light. Thresholds ~L10/L60/L120
of 150 (final numbers from generation stats). In-level depth = stars
charted this level (Cipher's "solving IS the sunset"). Milestone bits
**22–25**: 22/23/24 = first REEF PASS / OPEN OCEAN / LANDFALL, 25 = first
perfect chart beyond the teaching arc. Earned aesthetic: perfect charts
etch small star glyphs into the chart frame (persisted `perfectCharts`) —
never sold, never free.

**Picker metadata**: genre chip "MEMORY" / spoken "Memory". Accent:
**`P.bioGlow`** (glow-tide cyan `54E8DA` — unclaimed as a card accent;
appears only as Stacks' deepest depth tint) — pre-audit stripe contrast on
plank/woodDark at Stage 3, `lerp(P.blossom, 0.25)` fallback if needed.
Torch stays reserved for gold/points.

**Coach beats** (≤ 6 words, diegetic; seeded fixed pattern, first success
≥ 95%): "Watch the stars glow" → "Chart them from memory" → READY TO SAIL
banner. The re-peek button is NOT coached — first appearance (L3) fires a
one-shot hint (Stacks precedent); the how-to panel carries peek/decoy/wave
rows.

**Open for Carson (the standing Stage 6 economy gates)**: Neon Sign gate
inclusion (precedent: frozen at launch five for Honu), House Standing
thresholds at > 22 bits, aquarium fish for the top bit, wallet pacing
re-check, optional lounge window.

**Sizing**: smallest engine yet — a pure show/fade/tap/budget state
machine, no gravity/cascade/adjacency. Cost centers shift to (1) the
LevelForge recall-bot + generation run, (2) the scene, (3) VoiceOver
design for the peek (spoken star positions become sequence memory — a
deliberate Stage 5 design, not an afterthought), (4) level-select UI
reused from Luau's campaign picker. Net: Cipher-class build, not
Luau-class.

## Status log

- 2026-07-12 (Navigator, device round 4 — Carson: "patterns still seem
  common... can't we make the patterns just a random distribution of
  tiles?"): **charts are now uniform random.** The entire figure/family
  generator machinery (walks, strides, spacing gate, repair — ~200
  lines) DELETED in favor of uniform random sampling with one invisible
  guard: re-roll any chart that fills a 2×2 block (luck-clumps read as
  defects, not randomness); best-of-8 by mean nearest-neighbor as the
  tie-break. Constellation families remain as passage-card flavor copy
  only; the win-moment lines still draw fine over random stars (real
  constellations ARE random points plus imagined lines). Field lesson
  for the levels plan, three structured-generator rounds deep: players
  read ANY generator signature as "the same pattern" — randomness is
  the variety. `scatter` is now a reserved knob (kept in level data).
  Verified random-L30/55/90.png; reinstalled on iPhone 17.
- 2026-07-12 (Navigator, device rounds 2+3 — "still clumped/lines, board
  never used" + "resumed, pattern did not show"): **spacing made
  structural, resume made humane.** (1) Root cause of the clump feel:
  figures were CONTIGUOUS cell-runs, but constellations are distant
  points you connect in your head. Reworked: walks stride mostly 2 cells
  on 5×5+ boards with a NO-SELF-CROWDING rule (a stroke point may touch
  only its immediate predecessor), edges skip instead of clamping (clamps
  piled stars into corners), figure arms stride 2, Hibiscus ring radius
  2, Reef = isolated heads min-distance 2; every non-Honu chart passes a
  SPACING GATE (bbox ≥ 70% of board span + nearest-neighbor floor scaled
  by spread and feasibility), best-of-8 deterministic re-rolls + a
  mechanical repair pass (swap worst-crowded stars for distance-seeking
  replacements) — no chart ships below the floor; Honu stays the one
  blob family (every 10th passage). scatter floor raised to 0.3 from
  L13. VERIFIED: spacing2-L30/50/90.png — full-board figures on 5×5 and
  6×6. (2) Resume: the save no longer reconstructs mid-recall input —
  a memory game can't ask you to remember through an app kill. The
  passage survives; the attempt restarts fresh (salted chart, full
  budgets) and the reveal ALWAYS runs (resume-v2.png: passage 50
  mid-peek after kill+relaunch). SavePayload fields found/wrong/
  peeksLeft/levelScore now always nil (kept for decode compat).
  NOTE for the levels plan: stride-1 stroke pairs can still chain on
  breathers (chunkiest-allowed by design) — per-family stride floors are
  a calibration knob; budgets still PROVISIONAL.
- 2026-07-12 (Navigator, device round 1 — Carson's L30 field report):
  **three fixes shipped.** (1) "All clumped / same pattern repeats" →
  constellation FAMILIES are now real figure generators, not labels:
  Canoe=bent chain, Paddle=line, Current=diagonal run, Frigate Bird=V,
  Crossing=X, Hibiscus=ring, Swell=wave, Reef=paired clumps, Sail=triangle,
  Honu=blob (the old generator, now one family of ten); scatter became
  off-figure jitter; grid bands shortened (5×5 from L25, 6×6 from L81 —
  was 28 straight 4×4s); replaying a COMPLETED passage reshuffles the
  chart (fresh attempt salt — same chart twice is no memory test).
  Verified: figures-L26/30/33.png = diagonal vs chain vs X on consecutive
  band levels. (2) "Shows 3 then 3 more, weird" → waves now read as
  intentional: WAVE n OF m chip during multi-wave peeks, 380 ms dark beat
  between strokes, and the formula holds waves until u>0.5 (teaching L9/
  L12 still introduce it). (3) "L1 pattern never showed" → peek no longer
  starts the instant a card is tapped: an 850 ms WATCH THE SKY beat
  precedes every reveal, and the peek defers while the how-to is open
  (fires on dismissal) — kills every entry race (picker fade, first-run
  how-to, cold-start jank) categorically. Rebuilt + reinstalled on the
  iPhone 17. NOTE for the levels-plan pass: figure generators need
  per-family quality gates (a folded Canoe can still read chunky), and
  the felt-sample should re-run — figures are easier to chunk than blobs
  at equal star counts, so provisional budgets may want tightening.
- 2026-07-12 (Navigator, stage 3): **Navigator Stage 3 DONE — the game is
  playable.** NavigatorLevel.swift (150-passage campaign: L1–12 hand
  teaching arc, L13–150 deterministic formula ramp w/ breathers every 5th;
  ALL post-teach budgets PROVISIONAL pending the recall-bot solve),
  NavigatorGame.swift (pure @Observable engine: SplitMix64 attempt-salted
  charts, scatter-driven constellation growth, wave slicing, decoys,
  mistake/peek budgets, SavePayload w/ mid-passage validate-or-fall-through
  restore), NavigatorView.swift (view-clocked peek/decoy/re-peek tasks,
  code-drawn cells per the Stage 2 color spec, win-moment constellation
  lines, PASSAGE/stars/mistakes/PEEK HUD, SAIL ON / LANDFALL / THE CLOUDS
  CLOSE IN panels, NavigatorLevelPicker w/ frontier auto-scroll).
  Registration complete across all compiler-enforced switches (enum, picker
  accent/genre/depthAccents, previewClipKey placeholder, ContentView
  routing, milestoneBits 22..<26 reserved — mints are Stage 6). VERIFIED on
  throwaway sim "NavigatorStage" from captures in build/navigator-shots/:
  autoplay drove passages 1→51 (stage3-autoplay-mid/late.png — peek,
  chart, win, SAIL ON advance), lose path + missed-star reveal
  (stage3-lose-a.png via new TIKI_NAVIGATOR_LOSE=1 hook), kill-test resume
  mid-passage-50 (stage3-resume.png), win panel wallet line +42/425 score
  incl. PERFECT CHART tag (stage3-burst-6.png — caught the NEXT PASSAGE
  truncation, fixed to SAIL ON), picker indicator strip shows 7 game dots
  ending in bioGlow (stage3-picker.png). Hooks: TIKI_BG=navigator,
  TIKI_NAVIGATOR_LEVEL=<id>, TIKI_NAVIGATOR_LOSE=1, TIKI_AUTOPLAY=1 (bot
  auto-dismisses first-run how-to). Bot pollution: throwaway sim only — no
  live save touched. Known Stage 4+ items: ignite springs are minimal,
  peek-window juice thin, VoiceOver peek design (Stage 5), earnScore audit
  vs +20–40 (Stage 6), Navigator card footage (Stage 7).
- 2026-07-12 (Navigator, stage 2): **Navigator Stage 2 DONE — asset strip
  A+ 9.4** (render-graded at 96 px + 40 px + grayscale via rsvg-convert;
  strip evidence in the session scratchpad, contract self-QA all-★-pass).
  Four 96-unit plates in `assets/game/navigator/` — cell (2 hexes), star
  (blossom 4-point over sanctioned 0.2/0.45 glow discs), shooting-star
  decoy (distinct-from-star at 40 px: streak+head vs 4-point), miss cloud
  (cream cumulus) — plus the 40×40 `assets/game-icons/navigator.svg`
  (constellation-sail over an ink outrigger; hull is the weakest 40 px
  read, passes). Mirrored by hand into `NavigatorAssets/` +
  `GameIcons/NavigatorIcon.imageset` (universal SVG, preserve-vector);
  `Image.navigatorCell/Star/Decoy/Cloud/Icon` accessors compile. Board
  cells will render code-drawn at Stage 3 with these as the color spec +
  how-to rows (Honu v2 mosaic precedent).
- 2026-07-12 (Navigator, later): **Navigator Stage 1 DONE — open-ocean
  night scene A+ 9.31** (`NavigatorBackgroundView.swift`;
  `TIKI_BG=navigatorbg` route; row + notes in BACKGROUND_RUBRIC.md). Six
  iterations: v1 headland path self-intersected (floating shard), v2
  staircase rebuild + crab-claw spars, v3 solid-mass regression (coast
  became a monolith — caught), v4 seats the coast on the horizon with
  torches grounded on caps, v5 hard-clamps the star field above the board
  band, v6 adds the ~31 s porpoise channel roll. VERIFIED from captures:
  board-band two-frame diff 0.01%/2.5 s vs 5.23% at the sea edge; cloud
  drift 10,967 px over 44.8 s; shooting-star cycle ×2 and porpoise ×1
  found in recorded video frames; sim CPU 10.8%. Evidence
  `build/navigator-shots/stage1-v1..v6*`. Built on throwaway sim
  "NavigatorStage" (kept alive for later stages); the other session's
  booted sims untouched; isolated derivedData in the session scratchpad.
  Stage-driven voyage ladder (headland sink, landfall rise) is
  code-complete but renders depth-0 by default — lights up with Stage 6
  wiring, per the Honu precedent. GOTCHA (cost one dead iteration): a
  background `xcodebuild` lost the shell cwd and `grep -E "BUILD|error"`
  exit-0'd on the ERROR line → the chain reinstalled the STALE app and
  the capture verified nothing. Use absolute `-project` paths and grep
  for success, not either/or. Next per blueprint: Stage 2 assets
  (star/moon/decoy/chart-frame plates + 40×40 icon) ⇄ Stage 3 engine.
- 2026-07-12 (Navigator kickoff): **Navigator (game #7) Stage 0 WRITTEN,
  GATE PASSED** — memory-flash game, section 6 above. Carson locked: name
  **Navigator**, open-ocean night scene, **150-level campaign**; deferred
  the 7×7/8×8 expert ascent to post-campaign. Milestone bits 22–25 claimed
  on paper (Honu holds 18–21); picker accent candidate P.bioGlow (Stage 3
  contrast pre-audit pending). Committed doc-only around the other
  session's in-flight Honu/Luau tree (`git commit -- GAMES_BUILD_PLAN.md`).
  Next per blueprint: Stage 1 `NavigatorBackgroundView` ⇄ Stage 2 assets.
- 2026-07-12 (evening, CORRECTION): **Line-clears REVERTED — canon
  clusters only.** The "rule amended by Carson" entry below was a
  MISREAD of his bug report ("I cleared the row" = the row got cleared
  in his game, not "rows should clear"); he confirmed we are not
  deviating from Hexic. Reverted: line detection everywhere, greedy
  line-bans, the line-clear probe (ROTTEST 12 is now a canon GUARD: a
  line of three must NOT match — locked so this can't regress either
  direction). KEPT: the piece-tap dead-zone fix (the real bug behind
  all three field reports — taps near tile corners spun arbitrary
  junctions, so visible clusters never got attempted). How-to rule 2
  now teaches the trap head-on: "bunched around a point clears —
  straight rows don't." Stage 6 urgency drops back to normal.
- 2026-07-12 (evening): **RULE AMENDED BY CARSON — straight lines of 3+
  now clear** (in addition to vertex-clump clusters), after his third
  field report and a hostile code audit. Two real defects owned and
  fixed: (1) the piece-tap intent gate had dead zones — taps within
  0.30·hexW of any tile corner bypassed the rescue (a huge share of
  real thumb taps); intent now runs FIRST for any tap on a tile
  (nearest-center containment, no vertex gate). (2) The triangle-only
  match rule, defended as canon, refused row completions an
  experienced Hexic player expects; lines along the three hex axes now
  match (axisStep detection in resolveStep/boardHasMatch/
  boardClearValue; freshBoard greedy bans line-completions so fresh
  boards stay settle-clean; flowers remain buildable — petal arcs bend,
  never straight). How-to rule 2 rewritten. ROTTEST 12/12 (new probe:
  spin-into-line-end sticks and clears). NOTE: matches are now much
  easier — the Stage 6 recalibration (urchin pacing, thresholds,
  earnScore, star economy) is now blocking before any wider playtest.
- 2026-07-12 (afternoon, 2): **Piece-tap intent** (Carson's 2nd field
  report — tapping the piece that should complete a match spun an
  arbitrary junction: a piece center is near-equidistant from its six
  vertices, so nearest-vertex resolution was a coin toss). Taps landing
  on a piece's body (vertex distance > 0.30·hexW) now ask the engine
  for the best match-producing rotation among that piece's junctions,
  both directions (`bestMatchingRotation(involvingCol:row:)`, sharing
  the bot's `boardClearValue()` eval), and play it directly — including
  CCW without the refusal dance. Vertex-precise taps and matchless
  piece taps keep classic behavior + alternation. ROTTEST 11/11 (check
  11 = his exact board: pair (4,3)/(4,4), piece at (6,4) → finds CCW
  (5,3,right) and sticks).
- 2026-07-12 (afternoon): **Carson's artist v2 tile kit implemented —
  7 colors, bonus stars, starflower, urchin overlay.** Drop 3 (flat-top
  regeneration of his pointy-top drop 2 — orientation resolved by the
  art) audited 16/16 vs the SVG contract. Assets: HonuAssets rebuilt
  with clean names (HonuTileCoral…Rum + 7 Star variants + HonuStarflower
  + HonuUrchinOverlay); legacy sea-creature sprites/imagesets deleted
  (the flagged rename, done); tiles render as images again (code-drawn
  tile()/SheenShape retired). MECHANICS: bonus stars per Hexic HD —
  ~6% refill spawn, +60/star in clears, star petal doubles a bloom, and
  **star + urchin defusal sweeps the whole color** (A STAR SWEEPS THE
  REEF toast/haptic/shake; wipeBeat signal); 7th color (rum, kind 6)
  joins the refill pool at DRIFTER (canon color-ramp in miniature);
  Piece.star optional → legacy saves decode. User-facing "pearl" renamed
  **starflower** (engine identifiers unchanged). ROTTEST 10/10 (new
  star-sweep probe). Deferred, logged: cross-color star clusters
  (changes cluster detection), full 2^n star-petal ladder, star+wipe
  Stage 6 economy audit. Verified live: stars spawning + paying on
  autoplay, rum in pool at 400+.
- 2026-07-12 (morning, round 2): **Mosaic refined to the reference +
  peaceful pacing** (Carson): tiles are now CODE-DRAWN (HexCellShape
  gained rounded corners; SheenShape = hard-edged diagonal two-tone —
  code-drawing sidesteps the SVG contract's missing lighter steps),
  90% cell side for breathing room, pearl orb + glow drawn in code on
  the same rounded tile. The 6 flat SVGs remain only as the how-to
  panel's row icons + color spec (Stage 9 reconciliation candidate).
  Animation register slowed throughout: spin 0.30→0.55 s springs w/ low
  bounce, cascade rounds 240/330→380/540 ms, refusal revolution ~0.9 s,
  pearl spin 0.6 s, popup linger 1.1 s — Hexic is peaceful (Carson).
  Shake stays quick (it's a thump). Urchin fuse ticks + arrival keep
  their haptics.
- 2026-07-12 (morning): **Honu tiles rebuilt as a flat color mosaic +
  urchin screen shake** (Carson's Hexic-reference art call: per-piece
  glyphs were "way too noisy"). Six flat hexes — coral/cream/lagoonTeal/
  gold/twilight-indigo/olive (rum dropped for indigo; P.lagoonTeal added)
  — 2 elements each (shadow step + face), specials keep their glyphs
  (noise = signal for urchin/pearl). Kind names (starfish/cowrie/…) are
  legacy slot labels now — rename is a Stage 9 cleanup candidate.
  Grayscale mids collapse without glyphs → colorblind mode logged as a
  post-ship accessibility item (Hexic HD had one). ShakeEffect: decaying
  board thump on urchin arrival (5 pt) and on every fuse tick (2.2 pt,
  3.5 pt when fuse ≤ 3), synced with the tick haptics; skipped under
  Reduce Motion. Verified live: arrival banner + fuse-9 urchin + chip
  captured mid-shake on autoplay.
- 2026-07-12 (late night): **Honu device-feel round 1 (Carson's three
  notes) + pearl rotate-six BUILT.** (1) Refusal is now a full visible
  revolution of the trio in the attempted direction (lean was too
  subtle). (2) Urchins are unmissable: warning haptic + AN URCHIN DRIFTS
  IN toast on arrival (urchinBeat signal), and a rigid fuse-tick haptic
  lands ~90 ms after every move while urchins sit on the board,
  escalating to the warning buzz at fuse ≤ 3. (3) spinPearl: tap a pearl
  → all six neighbors ride one step around it, FREE (canon starflower —
  sticks matchless, still ticks fuses); edge pearls refuse; how-to
  promise reinstated; TIKI_HONU_PEARL staging hook (NB: shares cell
  (3,3) with TIKI_HONU_URCHIN — stage one at a time). ROTTEST now 8/8
  (pearl ring-cycle proof). Open: CCW pearl spin gesture; alternation
  device-feel check.
- 2026-07-12 (night): **Honu rotation corrected to Hexic canon —
  match-or-revert.** Carson caught the v1 misreading (rotations persisted
  without a match; real Hexic HD reverts and only the starflower spins
  freely — confirmed by the deep-research pass: 90 sourced claims,
  scoring tables, achievement-verified specials ladder). New
  `attemptRotation`: tries CW then CCW, sticks on the first arrangement
  completing a cluster/flower, else springs back; every attempt (stuck or
  reverted) ticks urchin fuses (canon: fiddling costs). Refusal read =
  trio lean-and-spring-back + coral ring + mistake tick (house juice
  canon). Stalemate guard: THE TIDE STIRS reshuffle (plain kinds only;
  specials hold; playable-board invariant enforced after every settle +
  on restore). Bot rewritten for real outcomes (defusal > blooms > size).
  Tutorial seed re-derived (old seed only worked under persist rules —
  caught by the new TIKI_HONU_ROTTEST engine self-test, now 7/7). How-to
  copy corrected (also removed the unbuilt pearl rotate-six promise —
  now the top Stage 4 item, since under canon rules the pearl's FREE spin
  is what makes it special). Autoplay verified live: 1,915 pts @30 s,
  cascades firing. Stage 6 note: urchin pacing + thresholds need full
  recalibration — runs are meaningfully harder under canon permanence.
- 2026-07-12 (later): **Honu Stage 3 DONE — the game is playable.**
  HonuGame engine (53-cell flat-top hex board, junction trios, CW rotation
  with persistent non-matches, triangle-union clusters, flower→pearl
  blooms, urchin fuses w/ defuse-beats-tick ordering, weighted-color
  fairness, greedy defuse-first bot) + HonuView (junction tap targets,
  spring rotation, cascade banners, +N popups, urchin fuse badges,
  detonation panel w/ wallet line + milestone toast) + full registration
  (enum case forced every switch; picker indicator strip auto-derived the
  6th dot). Verified on throwaway sim HonuStage: autoplay full loop
  (3,750-pt run, ANCIENT ONE sky reached — the sunrise ladder works),
  forced game-over (TIKI_HONU_URCHIN=1 → burst panel, NEW BEST, WALLET 94,
  VIC BUYS A ROUND +75), resume across app kill (1,995 = 1,995 exact).
  Evidence build/honu-shots/stage3-*. Hooks: TIKI_HONU_SCORE,
  TIKI_HONU_URCHIN, TIKI_AUTOPLAY, TIKI_BG=honu|honubg. DECISIONS taken:
  Neon Sign gate FROZEN at launch five (silent re-lock avoidance; Carson
  owns the Stage 6 final call); "Game i of 5" VoiceOver literal now
  derives from allCases.count. Stage 6 to-dos: earnScore pays ~score/30
  wallet (19 pts @575) — verify +20–40 at the real run median; urchin
  pacing + depth thresholds are provisional pending bot n≥300; milestone
  hooks live but coach-guard lands with Stage 5. Stages 4 (feel), 5
  (onboarding), 6 (progression/economy), 7–9 (capture/store/sweep) remain.
- 2026-07-12: **Honu Stages 1+2 DONE.** Stage 1: HonuBackgroundView dawn
  lagoon graded A+ 9.31 over 5 iterations (BACKGROUND_RUBRIC row; two-frame
  motion diff + 22.4% sim CPU evidence; basalt rebuilt twice —
  planks → staircase silhouette masses). Stage 2: 8 tile SVGs +
  40×40 icon in assets/game/honu/ + game-icons/, hex plates (flat-top,
  +4y shadow), strip render-graded A+ 9.4 at 40 px + grayscale after one
  redraw round (cowrie de-mushroomed, sea glass frosted, anemone → rum
  plate, scute de-tented); HonuAssets imagesets + Sprites accessors
  compile. DEVIATION from the square-plate precedent: plates are hexagons
  (board-diegetic). Urchin ships as a plate-less glyph the view composites
  over any piece color — legibility over the two dark plates is a Stage 3
  verification item.
- 2026-07-11: **Honu (game #6) Stage 0 authored** — Hexic-canon rotational
  hex-match with the urchin-bomb survival ending (Carson's structure call),
  dawn lagoon scene, resident-turtle wit beat, milestone bits 18–21, olive
  accent. Name locked by Carson (Honu > Tide Pool/Basalt Bay). Pipeline:
  NEW_GAME_BLUEPRINT.md; design section 5 above.
- 2026-07-10 (night): **Luau Levels stages A–D SHIPPED** (Opus 4.7
  handoff run). LuauGame engine gains level mode w/ masks, per-cell
  jelly, seeded RNG, extended SavePayload (36-test headless verify);
  LuauBot + LevelForge macOS CLI implement evaluator+solver+rejector
  (9-test probe); L1..L12 hand-authored teaching arc plus 20 generated
  campaign levels ids 13-32 (32 levels total) via `levelforge campaign
  build`; LuauView gains a level picker overlay, SAND HUD chip, jelly
  rim rendering, three-way win/lose/endless sunrise panel. Every Stage
  A–D verification captured in
  `TikiGames/LUAU_LEVELS_PLAN.md#execution-log`. Stages E (progression
  bit remap 8–10 to levels 10/30/60) + F (rubric, capture refresh,
  Carson's device-feel calibration) remain.
- 2026-07-10: **Luau Levels initiative planned** — pivot Luau to a
  jelly-objective level campaign (60–120 generated levels, bot-solved move
  budgets, endless nights kept as a mode). Plan: LUAU_LEVELS_PLAN.md
  (stages A–F, not started). New-game pipeline reference: NEW_GAME_BLUEPRINT.md.
- 2026-07-01: plan authored; Zombie started (task #1).
- 2026-07-01 (iter 2): **Zombie tile set A+** — 11 SVGs in assets/game/zombie/
  (workflow batch; Blue Hawaii hand-redrawn — original glass silhouette failed
  40 px read). Imagesets live under Assets.xcassets/ZombieAssets/ as
  ZombieTile01–11, accessor `Image.zombieTile(_:)` in Sprites.swift.
  **GameSaveState** SwiftData model + saveState/loadState/clearState on
  PlayerStore built and compiling.
- 2026-07-01 (iter 3): **Zombie BUILT and verified end-to-end** —
  ZombieGame.swift (pure engine), ZombieView.swift (board in the wall zone
  0.545h center; swipe gestures; spawn/merge springs; "+N" GainPopup; tiered
  haptics + system SFX 1104/1057≥tier8; THE ZOMBIE win banner; LAST CALL
  game-over with +points/WALLET/lounge line), HowToPlay.swift (reusable
  button+panel, auto-shows first run, seenHowTo persisted in SwiftData
  payload), board persists every move via GameSaveState, recordRun uses new
  earnScore param (score/10 → classic-2048 scores pay stacks-scale points:
  2,392 run paid +23). `.zombie` isPlayable; ZombieView routed in
  ContentView + HomeView + picker grid. Autoplay verified: mid-merge frames,
  +8 popup frame, LAST CALL panel. Bot pollution cleaned from live save
  (zombie GameRecord deleted, wallet restored).
- 2026-07-01 (iter 4): Zombie polish (refusal nudge, tier-6+ bursts) and
  formal grade: **A (9.06)** — same honest ceiling as Tiki Stacks; caveat
  recorded in GAME_FEEL_RUBRIC.md. Task #1 done.
- 2026-07-01 (iter 5): **Blueprints BUILT** — BlueprintsGame.swift (10
  authored tiki pixel-puzzles, clue gen, mistake rules, SwiftData payload),
  BlueprintsView.swift (picker cards, blueprint board with clue gutters,
  BRUSH/MARK toggle, mistake shake, DRAFTED colorize overlay, wallet line),
  routed + isPlayable. Fixed a teardown-race crash (ForEach cells reading a
  shrunken grid — bounds guard + closePuzzle keeps grid). Autoplay verified:
  mug PERFECT DRAFT +10, then restore-from-save → hibiscus with 2 mistakes
  +8. Bot earnings cleaned.
  NEXT (iter 6): Blueprints board mid-play review (clue gutter alignment at
  8x8/10x10), polish (drag-to-paint, 5-block grid separators for 10x10
  readability), formal grade + rubric section, then start Cabana Cipher
  (task #3): phrase corpus (~40 original exotica one-liners), CipherGame
  engine (substitution map, keyboard letter tiles, reveal-hint economics),
  view over poolside scene, how-to, SwiftData (solved phrases + assignments),
  then Luau match-3 (task #4) last.
  (superseded earlier note) NEXT (iter 4): formal GAME_FEEL grade for Zombie (v1 baseline from the
  captured frames, expect ~A-; check board-bottom vs counter clearance, win
  banner unverified — needs TIKI_BUY-style forced board or accept as code
  review), record iteration log in the rubric file, small polish round, then
  mark task #1 done and start Blueprints (task #2): puzzle bitmaps (~12 tiki
  pixel-arts 5x5/8x8/10x10 authored in code), NonogramGame engine
  (clue generation from bitmaps, fill/cross, mistake counting), view over the
  volcanic-cove scene, how-to panel, SwiftData (solved IDs + in-progress
  grid), recordRun scoring (per-puzzle score by size − mistakes).
