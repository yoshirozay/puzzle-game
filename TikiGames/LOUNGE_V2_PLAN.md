# LOUNGE V2 PLAN — the wide lounge

*2026-07-10. Handoff-grade technical plan: written so a fresh session (any model,
zero conversation context) can execute it end-to-end. Design decisions below are
LOCKED by Carson — do not re-litigate them; open items are listed in §9.*

---

## 0. What this is

Rebuild the lounge meta-room from one static screen into a **wide, panning room
(~2.2 screens)** furnished with the 48 newly delivered SVG assets
(`assets/sprites-v2/`). Carson's direction: *"I want the lounge to be awesome
from the start, we're not shipping yet"* — no phasing, the full vision lands
before ship. His specific feedback driving this: the flat framed "wall
paintings" are weak, and the room feels small. His favorite new asset is the
piano.

**Locked decisions:**
1. One wide panning room (drag to pan). Camera opens on the bar (east end), the
   familiar view; the room extends west into a seating lounge and a music
   corner anchored by the piano. No Back Room door — the panning room replaces
   plan item 22's wing concept; the long-horizon want is carried by the
   piano's price, not a gate.
2. Flat wall paintings die. The Sunset Window sprite and the delivered
   `window-beach/volcano/water.svg` are NOT hung as framed pictures. Instead:
   one or two big **code-drawn architectural windows with live views** — palette
   sky bands + sun/moon breathing on the same 90-second clock as the game
   scenes (reuse `TikiScenery` P tokens). The three delivered window SVGs stay
   in `sprites-v2/` as palette/composition reference only.
3. The six Tier-A placeholder code sprites are replaced by the delivered SVG
   art (stools, fan + 3 blade frames, marlin, parrot, neon sign + glow,
   aquarium + 5 fish), plus trophy mug + glow and the 16 matchbook covers.
4. Aquarium caps at **5 fish** (Carson: "the aquarium with the 5 fish";
   delivery has no fish-6).
5. Patrons arrive by House Standing, never sold: couch occupied at REGULAR,
   high table occupied at ISLANDER (sprite swap, not overlay — the occupied
   variants are complete compositions).
6. Rug ships with **free colorway toggle** (cream/lagoon/midnight/rum) — the
   first expression mechanic.
7. **Drag placement**: long-press to lift any owned item, drag along its band
   (floor/wall/ceiling), drop anywhere in-band. Defaults = curated layout.
   "VIC TIDIES UP" resets.

Concept reference: this layout was mocked from the real assets and approved in
direction — west→east: live window · high-table couple · piano · rug ·
couch couple · aquarium (wall) · plants · marlin · tiki statue · palm · cat ·
neon sign · back bar/Vic · stools. (Mock lived in session scratchpad; treat the
zone table in §3 as the source of truth.)

## 1. Current architecture facts (verified 2026-07-10)

- `TikiGames/TikiGames/LoungeView.swift` (~950 lines): room renders inside
  `GeometryReader` (line ~33), one screen. **Anchors are fractions of W/H**
  with aspect = sprite viewBox h/w (comment at line ~514); scene re-composes
  a 680×440 design space (comments at lines 5, 434). `anchorFrame(for:)`
  (line ~489) maps item id → CGRect; the purchase burst fires at that frame
  (line ~480). Economy-pass anchors at line ~540.
- Two render paths (line ~685–728): `placedImage(.assetName, frame)` for
  imageset-backed items; `placedSprite(SomeSprite(t:), frame)` for the six
  code-drawn placeholders in `LoungeItemSprites.swift` (fan/marlin/sign/
  aquarium/parrot/stools; each marked `// PLACEHOLDER ART`). Trophy mug is
  `ZombieMugView` (from `ZombieBackgroundView.swift`) gated on Zombie
  milestone bit 7, with code-drawn eye flicker (`mugFlicker`, LoungeView
  ~736–747).
- Shop: `shopPanel(geo.size)` overlay (line ~49) with its own ScrollView; the
  SHOP button and wallet chip are screen-fixed overlays — the lounge FTUE
  coach (welcome mug flow: SHOP beat → BUY beat on the Flaming Mug row)
  targets them, so they must STAY screen-fixed, not scroll with the room.
- `PlayerStore.swift`: 19-item catalog in `syncLoungeCatalog()` (upserts every
  launch — prices retunable without migration), `milestoneMask` bit table
  documented at `recordMilestone` (Stacks 0–3, Zombie 4–7, Luau 8–10,
  Blueprints 11–13, Cipher 14–17), `houseStanding` (WALK-IN 0–4 / REGULAR 5–9 /
  ISLANDER 10–14 / NAME ON THE DOOR 15–18), `aquariumFish` (currently
  1 + count of top bits {3,7,10,13,17}, max 6 — **change cap to 5**),
  `grant(points:)`, `signUnlocked` gating, welcome-gift one-shot pattern,
  DEBUG hooks `TIKI_MASK` / `TIKI_CATALOG`.
- Matchbooks: `CipherView.swift` `MatchbookCover` (~line 745) draws cream
  cover + code `Text(name)` + match strike; used in the LAST CALL ceremony
  wall and book banners. The 16 names in code order: HOUSE RULES, THE
  REGULARS, NIGHT AIR, LAST CALL, VICS ADVICE, THE LAGOON, THE BAND, THE CAT,
  WEATHER REPORT, THE MENU, ISLAND TIME, THE TOTEM, CASTAWAY MAIL, THE
  VOLCANO SPEAKS, MOONLIGHT SWIM, THE PHILOSOPHY SHELF.
- Assets: shipped sprites in `assets/sprites/` (15 files) mirror into
  `TikiGames/TikiGames/Assets.xcassets/*.imageset` (one universal SVG,
  preserve-vector). **New delivery: `assets/sprites-v2/` (48 files)** — all 48
  pass the ★ gates (palette-only hexes, no gradients/filters/text, ≤8 KB;
  audited 2026-07-10). ViewBoxes: stools 150×95, fan set 220×120 ×4 (base is
  bladeless; blades-a/b/c are phase overlays, a = resting), marlin 200×76,
  parrot 90×110, sign 64×190 ×2 (base + glow overlay), aquarium 220×110 ×6
  (tank + fish-1..5 as same-box static overlays), trophy 100×170 ×2 (base +
  eyes-glow overlay), matchbooks 96×128 ×16 (motif-only, lower ⅔ — code Text
  stays on top), piano 220×150, couch/couch-couple 240×110, high-table(-couple)
  150×114, plants 110×150 / 100×170 / 130×160, rugs 300×56 ×4.
- Build: `cd TikiGames && xcodegen` (needed only when files are added to the
  target), then
  `xcodebuild -project TikiGames.xcodeproj -scheme TikiGames -destination
  'platform=iOS Simulator,name=TikiGames ProMax' build`. Baseline: green with
  exactly 3 pre-existing warnings (LuauGame `var column`; GamePickerView
  Sendable ×2) — a pending task chip exists to fix them; zero NEW warnings is
  the bar.

## 2. Stage A — asset intake & art swap (S/M)

1. Copy the needed SVGs from `assets/sprites-v2/` into new imagesets under
   `Assets.xcassets` (mirror the existing imageset format: universal,
   preserve-vector). Needed now: bar-stools, ceiling-fan, ceiling-fan-blades-a/
   b/c, marlin, parrot, neon-tiki-sign, neon-tiki-sign-glow, aquarium,
   aquarium-fish-1..5, zombie-trophy-mug, zombie-trophy-mug-glow,
   matchbook-01..16, piano, couch, couch-couple, high-table,
   high-table-couple, plant-bush, plant-snake, plant-tiered, rug, rug-lagoon,
   rug-midnight, rug-rum. (Leave window-*.svg out — reference only.)
2. Replace `placedSprite(...)` calls with `placedImage(...)` for the six
   items. Fan: base image + ONE blade frame composited over it; idle shows
   blades-a; "spinning" cycles a→b→c on a timer (~0.12 s/frame; pause under
   reduceMotion — show blades-a static). Sign: base + glow overlay where the
   current code flicker drives the glow layer's opacity (keep the existing
   flicker cadence). Aquarium: tank + fish-1..N stacked (same viewBox = same
   frame). Trophy: base + eyes-glow overlay driven by the existing
   `mugFlicker` value; delete the now-dead placeholder sprites in
   `LoungeItemSprites.swift` ONLY after the swap verifies (keep
   `HouseStandingPlaque`).
3. `PlayerStore.aquariumFish`: cap at 5 (`min(5, 1 + topBits)`).
4. Matchbooks: in `MatchbookCover`, render `Image("matchbook-NN")` (index =
   book order) as the cover art with the existing `Text(name)` overlaid in the
   upper ⅓ (the SVG motifs deliberately sit in the lower ⅔). Keep the code
   strike as fallback if an asset is missing.
5. VERIFY: build green; sim screenshots of the room with `TIKI_POINTS=20000
   TIKI_BUY=all` (all items placed, fan animating, sign flickering, 5 fish);
   LAST CALL wall staged via `TIKI_CIPHER_SOLVED=95` + one solve. Depth-0
   check: fresh install room must look unchanged EXCEPT the six art swaps.

## 3. Stage B — the wide room (L, the structural piece)

1. World space: extend the 680×440 design box to **1500×440** (≈2.2×). Keep
   anchors as fractions but of the WORLD box. Render the room inside a
   horizontal `ScrollView` whose content is `worldW = geo.size.height / 440 *
   1500` wide (height-fit, width scrolls). Open scrolled to the east end
   (bar). Disable bounce-vertical; keep the existing safe-area treatment.
2. Zone layout (world-x fractions; y logic unchanged — wall band, floor band,
   ceiling line as today):
   - **West / music corner (0.00–0.33):** live window W1 (big, ~0.04–0.24 wall),
     plant-snake (floor far west), high-table + couple (~0.26), piano
     (~0.30–0.46 floor — the statement piece), rug slot A under it.
   - **Mid / seating (0.33–0.66):** rug slot B (~0.44), couch + couple (~0.48),
     aquarium on wall above couch (~0.47), plant-tiered (~0.60), marlin on
     wall (~0.62), ceiling fan overhead (~0.42).
   - **East / bar (0.66–1.00):** existing bar composition preserved nearly
     as-is (tiki statue, palm, cat, credenza + disc + trophy, patrons
     martini/highball, corner fronds, glass float, blowfish lamp, neon sign,
     back bar, Vic + mug, stools, standing plaque, sunset-window slot becomes
     live window W2 — smaller). Keep relative spacing; the point is the east
     end alone still composes like today's room.
3. Screen-fixed chrome: SHOP button, wallet chip, standing plaque? — plaque
   stays on the wall (world); SHOP + wallet stay fixed overlays (FTUE coach
   targets them). Purchase burst: `anchorFrame(for:)` must return the frame in
   the CURRENT scroll context — on purchase, first auto-scroll the room to the
   new item's anchor, then fire the burst (juice guideline: the room shows you
   what you bought).
4. First-run: camera opens at east; a one-time soft auto-pan hint (slow 1 s
   drift west and back, or a small chevron) — diegetic, no tutorial card.
5. VERIFY: pan smoothness on sim (60 fps; the room layers are cheap flat
   shapes but the 90 s `TimelineView` now draws a 2.2× canvas — if profiling
   shows pain, split static layers into a cached `drawingGroup()`); FTUE
   welcome-mug flow END-TO-END on fresh install (coach beats must land on the
   fixed SHOP/BUY targets regardless of scroll position); purchase burst +
   auto-scroll for a west-zone item (buy piano via `TIKI_POINTS`); screenshot
   sweep at east/mid/west.

## 4. Stage C — live windows (M)

1. New `LoungeWindowView(t:size:view:)` — code-drawn architectural window:
   woodDark frame + mullions (1 vertical + 1 horizontal), inside it palette
   sky bands + sun/moon disc + water glints, breathing on the same 90 s clock
   (`dusk` blend) the game scenes use. Reuse `P.*` + `mix3`/`lerp` from
   `TikiScenery.swift`. NO SwiftUI opacity gradients — flat bands, hard steps,
   exactly like the scene backgrounds.
2. Views (variants of what's outside): `sunset` (default), `beach` (earned:
   Luau bit 10 — INFERNO), `volcanoNight` (earned: Zombie bit 7 — THE ZOMBIE),
   `glowTide` (earned: Stacks bit 3 — GLOW TIDE). Derive unlocks from
   `milestoneMask` — nothing sold. Tap the owned window to cycle unlocked
   views (persist selection per window: two defaulted string fields on
   `PlayerProfile`, e.g. `windowViewW1`/`windowViewW2` — lightweight
   migration, same class as `milestoneMask`).
3. Catalog: the existing "Sunset Window" item (400 pts) BECOMES live window
   W2 (same id, same price — owners get the upgrade free; rename display to
   "PICTURE WINDOW" if the shop copy reads better). New row "THE BAY WINDOW"
   (W1, west wall, 1,200 pts — it's huge). Locked-window slots show the ghost
   hook treatment like other unowned anchors.
4. VERIFY: staged screenshots of all four views at two breath phases each;
   view toggle persists across relaunch; unlock gating via `TIKI_MASK`;
   reduceMotion holds a static frame (no churn).

## 5. Stage D — catalog, patrons, rug (M)

1. New rows in `syncLoungeCatalog()` (append; upsert handles the rest):
   | id | display | price | anchor |
   |---|---|---|---|
   | bayWindow | THE BAY WINDOW | 1,200 | west wall (Stage C) |
   | loungeRug | THE RUG | 700 | rug slot B (mid) |
   | loungeCouch | THE DAVENPORT | 1,400 | mid floor |
   | highTable | THE TALL TABLE | 900 | west floor |
   | grandPiano | THE BABY GRAND | 3,000 | music corner |
   | plantBush | POTTED BUSH | 300 | east/mid filler |
   | plantSnake | SNAKE PLANT | 350 | far west |
   | plantTiered | THE TOPIARY | 400 | mid |
   New ceiling: 12,780 + 8,250 = **21,030 real spend** (faucets 2,950 ≈ 14% —
   fine). Sanity-check `TIKI_CATALOG` prints after implementing.
2. Patrons by standing (in the room render, not the catalog): couch renders
   `couch` when owned; swaps to `couch-couple` when `houseStanding ≥ REGULAR`.
   High table → `high-table-couple` at `≥ ISLANDER`. Swap with a soft
   crossfade on the standing change; patrons are never listed in the shop.
   Diegetic beat (one-time, per table): a small "the regulars found the good
   seats" toast line — reuse MilestoneToast styling, no new system.
3. Rug colorways: owned rug taps cycle rug → rug-lagoon → rug-midnight →
   rug-rum (persist a defaulted `rugColorway` string on the item or profile).
   Free, unlimited — expression, not economy.
4. VERIFY: standing swap via `TIKI_MASK` staging (5 bits → couch couple
   appears; 10 → table couple); wallet math on all new purchases; no shop
   leaks (patrons/colorways not purchasable); `rows=27` stable across
   relaunches (no dupes).

## 6. Stage E — drag placement (M/L)

1. Model: add defaulted fields to the lounge item model — `posX: Double = -1`
   (fraction of world W; -1 = "use default anchor") and `band: String = ""`
   (informational; band is derived from item type, stored for safety).
   Lightweight migration — additive defaulted fields, the `milestoneMask`
   pattern. **Run the upgrade-in-place test** (§8.3).
2. Interaction: long-press (~0.35 s) on an owned, movable item lifts it —
   haptic, scale 1.06, soft hard-edged shadow (flat, palette — no blur).
   While lifted, horizontal drag moves it along its band (floor items keep
   their baseline y; wall items their wall y; hanging items the ceiling
   line); the room does NOT pan while an item is lifted. Drop = spring-settle
   + tick sound. Out-of-band or over-a-fixed-item drops spring back.
   Overlap resolution: allow overlap, z-sort floor items by x so
   neighbors layer deterministically; clamp within the band's world range.
3. Fixed (non-movable): Vic, bar counter, back-bar shelf, standing plaque,
   both windows (architecture), and child layers (flaming mug, record disc,
   trophy mug on credenza, fish, patrons — they ride their parents).
4. "VIC TIDIES UP" row at the bottom of the shop: resets all posX to -1
   (default anchors) with one confirm ("Vic likes it how it was.").
5. Coach beat, one-time after first manual purchase: "MAKE YOURSELF AT HOME"
   (hold-to-move hint) via the existing FirstRunCoach chassis — 4 words, skip
   respects `onboardingSkipped`.
6. VERIFY: drag an item to each extreme, relaunch → position persists;
   VIC TIDIES UP restores; FTUE unaffected; `TIKI_BUY=all` still stages the
   DEFAULT layout (staging never reads posX overrides — screenshots stay
   reproducible); reduceMotion: lift/settle animations snap.

## 7. Stage F — regression + re-staging (M)

1. Full pass against `TikiGames/LOUNGE_RUBRIC.md` (the original room rubric)
   PLUS a new `LOUNGE_V2_RUBRIC.md` — write it BEFORE grading, dimensions at
   minimum: Spaciousness (does it feel like a place, not a screen), Zone
   composition (each zone composes like a poster on its own), Live-window
   depth, Discovery (panning reveals, patron arrivals), Expression (drag +
   colorways + views), Economy horizon (21,030 ceiling, no dead zones),
   Performance (pan fps, TimelineView cost), Regression safety (FTUE, saves,
   migration, reduceMotion, screenshots pipeline). Pass bar: avg ≥ 9.3, no
   dim < 8, honest grades from staged screenshots.
2. Re-stage App Store assets LAST (they feature the lounge):
   `appstore/tools/compose_screenshots.swift` + `compose_cards.swift` on the
   "TikiGames ProMax" sim. The preview video's lounge segment may also need a
   re-cut — check `appstore/preview/`.
3. Migration/FTUE matrix: fresh install; upgrade-in-place from a pre-v2
   store (§8.3); veteran with all 19 items owned (retro placement = default
   anchors); `onboardingSkipped` path.

## 8. House gotchas (hard-won this project — respect these)

1. **Never write @State from inside a TimelineView render window** — writes
   get silently dropped. This bug shipped twice (Zombie banner, Blueprints
   mint toast). Hold animation-triggering flags in the engine/model
   (`@Observable`), not view @State, when a TimelineView is on screen.
2. **SwiftData migrations**: additive defaulted fields only; test
   upgrade-in-place on the sim (install old build → create data → install new
   build over it). One-shot flags via UserDefaults with the
   `welcomeGiftClaimed` pattern.
3. **Clearing one-shot flags on the sim**: live-sim plist edits are NOT
   cfprefsd-safe. Sequence: `simctl shutdown` → edit plist → `boot`.
4. **zsh env staging**: `env $VAR` doesn't word-split; use `env ${=VAR}` when
   passing SIMCTL_CHILD_* strings.
5. **xcodegen** regenerates the project — run it after adding files, never
   hand-edit the pbxproj.
6. **Staging hooks are the verification backbone** (all DEBUG-only):
   `TIKI_POINTS=<n>`, `TIKI_BUY=<ids|all>`, `TIKI_SHOP=1`, `TIKI_MASK=<per-game
   bit staging, mints nothing>`, `TIKI_CATALOG` (prints rows/sums), per-game
   `TIKI_STACKS_SCORE`/`TIKI_ZOMBIE_BOARD`/`TIKI_LUAU_SCORE`/
   `TIKI_CIPHER_SOLVED`/`TIKI_BLUEPRINTS_SOLVED` etc. Wipe state:
   `simctl uninstall`. Add new hooks in the same style for anything v2 needs
   (e.g. `TIKI_STANDING` if `TIKI_MASK` staging proves clumsy).
7. **Coach guards**: any new interactive surface must respect
   `coachActive`/FTUE (the tutorial-exploit class of bugs — Luau/Stacks coaches
   once minted milestones; guards were added; don't regress them).
8. **Grading is evidence-only**: staged simulator screenshots, wallet math,
   measured behavior. Never grade from intent. Iteration log lives in the
   rubric file.

## 9. Open items (Carson's calls, defaults stated)

1. Prices in §5 are proposed, not blessed (default: as listed).
2. Piano idle animation (keys ripple when the record disc spins — music
   corner synergy)? Default: YES, subtle, reduceMotion-safe.
3. Second live window W2 replacing Sunset Window at same price — confirm
   owners get it free (default: yes, same item id upgrades in place).
4. The 3 pre-existing compiler warnings have a pending fix chip — land it
   with Stage A (default: yes).
5. Preview video re-cut scope (lounge segment only vs full re-cut). Default:
   defer until v2 is graded, then decide.

## 10. Execution log

- **Stage A — DONE, verified (2026-07-10).** 45 imagesets created under
  `Assets.xcassets/Sprites/` (windows excluded per §0.2); `Image` statics added
  in `Sprites.swift` (incl. Stage-D items, unused until then);
  six `placedSprite` sites → `placedImage` in LoungeView (fan = bladeless base
  + `ceilingFanBlades[Int(t/0.18) % 3]`; sign = base + glow overlay at
  flicker opacity; aquarium = tank + fish 1...count stack; trophy = base +
  glow at `0.35 + 0.65*breath`); shop thumbnails collapsed to `image(for:)`;
  `aquariumFish` capped at 5; `MatchbookCover` renders `Image.matchbookCover
  (index+1)` under the code Text; dead placeholder sprites deleted
  (LoungeItemSprites.swift now holds only `HouseStandingPlaque`). Build green,
  only the 3 known pre-existing warnings. VERIFIED on sim: full room staged
  (`TIKI_BUY=all` — wallet 25,000−12,780=12,220 exact), sign appears only
  with all-five-games mask (gating intact), plaque REGULAR at 5 bits, 5 fish
  stacked with correct placement, blade frames cycle (pixel-diff), LAST CALL
  shows all 16 illustrated covers w/ titles overlaid. Evidence:
  `build/progression-shots/loungev2/`. Deviations: fan shop thumbnail now
  shows the full 220×120 fan (old rodLength-14 crop hack retired); trophy
  pop-in transition preserved via placedImage.
- **Stage B — DONE, verified (2026-07-10).** The room is a 2.2-screen world in
  a horizontal ScrollView (`LoungeRoomView.worldScreens = 2.2`), camera opens
  east via `.defaultScrollAnchor(.trailing)`; chrome/shop/coach stay
  screen-fixed. Anchor conversion via `east(_:)`/`span(_:)` helpers — the
  original composition occupies the EASTMOST screenful exactly (note: this
  makes the east frame start at world 0.545, NOT the plan sketch's 0.66;
  mid-zone anchors were re-derived accordingly: fan cx 0.34, aquarium 0.36,
  marlin 0.44 — first attempt at 0.42/0.47/0.62 bled into the opening frame).
  Bar canvas/rug trapezoid east-remapped; planks 8→18; dust motes 7→16 seeds.
  Purchase auto-scroll: invisible `scroll-<id>` markers in the room +
  `onChange(of: model.justPlaced)` scrollTo; VERIFIED live via new DEBUG hook
  `TIKI_BUY_LATE=<id>` (mirrors buy(_:) incl. `model.justPlaced` — plain
  `store.purchase()` does NOT fire the burst/scroll; launch-time TIKI_BUY
  can't either, onChange attaches later). New staging hook
  `TIKI_LOUNGE_ZONE=west|mid` parks the camera (zone markers at 0.02/0.5/
  0.98). VERIFIED: east frame = classic room; mid frame correct+sparse
  (awaits C/D); FTUE coach lands on fixed SHOP over east; west purchase
  auto-scrolls + bursts at the aquarium. Evidence:
  build/progression-shots/loungev2/stageB-*.png. DEFERRED: first-run pan
  hint → Stage D (west is empty until then); pan-fps profiling → Stage F.
- **Stages C + D — DONE, verified (2026-07-10, one combined pass).**
  C: `LiveWindowView.swift` (new; xcodegen run) — Canvas-drawn architectural
  window, 4 views (sunset default; beach/volcanoNight/glowTide earned via
  bits 10/7/3), compositions mirror sprites-v2/window-*.svg; breath drives
  band mix/sun sink/glint alpha; mullions overdrawn. East window = existing
  sunsetWindow item (upgraded free, live); west = new bayWindow row.
  Tap-cycles through EARNED views via `store.setWindowView`;
  `combinedMilestoneMask` made non-private for the unlock check.
  D: PlayerProfile +3 defaulted fields (windowViewEast/West, rugColorway —
  mirrored on the store like `points`); catalog +8 rows (rows=27, realSpend
  = 21,030 VERIFIED via TIKI_CATALOG and by wallet math 30,000−21,030=8,970
  through real purchases); west-wing anchors (bayWindow 0.13, highTable
  0.20, piano 0.335, couch/aquarium/rug column 0.46, plants 0.035/0.29/
  0.52); rug renders beneath floor items, tap cycles 4 colorways;
  patrons-by-standing: couch swaps to couchCouple at tier ≥1, highTable
  STACKS highTableCouple overlay at tier ≥2 (the couple SVG is an overlay
  sharing the table's viewBox — swap made the table vanish; fixed).
  VERIFIED: patrons-negative (WALK-IN → empty Davenport, wallet 700 =
  3,000−2,300 exact); couple present at tier 2; window persistence across
  relaunch (volcanoNight survived); migration upgrade-in-place over a
  HUMAN-PLAYED pre-C+D store (mug/statue/martiniWoman/aquarium, wallet 50 —
  all intact, fields defaulted); rug colorways staged (midnight, lagoon).
  New DEBUG hooks: TIKI_WINDOW=east:<view>,west:<view> · TIKI_RUG=<0-3>
  (+ Stage B's TIKI_BUY_LATE/TIKI_LOUNGE_ZONE; zone-park now delays 400 ms —
  it raced defaultScrollAnchor's initial layout).
  Evidence: build/progression-shots/loungev2/stageCD-*.png.
  KNOWN/ACCEPTED: occupied couch is the artist's complete composition (a
  smaller loveseat) so the furniture visibly changes when the couple
  arrives — flag for Carson; volcano crater glow reads as an eruption puff;
  window breath verified by construction + static frames only (two-phase
  capture → Stage F); "the regulars found the good seats" toast deferred
  (Stage F polish); first-run pan hint still deferred to Stage E/F.
- **Stage E — DONE, verified within simctl's limits (2026-07-10).**
  `LoungeItem.posX: Double = -1` (defaulted; migration verified by
  install-over on the ISLANDER store); store mirror `itemPositions` +
  `setItemPosition`/`resetPlacements`; room takes `positions` +
  `commitPlacement`; effective-cx helper `cx(id, default)` threads player
  placement through ~20 anchors (lift > persisted > default); `movableImage`
  wrapper = lift scale 1.06 + flat ground-shadow ellipse + long-press(0.35s)→
  drag gesture in the room coordinate space, clamped half-width-aware to
  [0.01, 0.99]; scroll doesn't pan while lifted (sequenced gesture holds the
  touch). Movable: 20 decor items; FIXED: Vic/bar/shelf/windows/plaque/
  parrot/umbrella drink/ceiling fan (fan+sign glow overlays + fish + disc +
  trophy + table couple are hit-transparent children that ride their
  parents — VERIFIED: credenza dragged west carried disc + trophy).
  VIC TIDIES UP shop row (shows only when placements exist, one confirm) +
  one-shot "MAKE YOURSELF AT HOME — HOLD TO MOVE ANY PIECE" CoachCard after
  the first non-gift purchase. Staging hooks TIKI_PLACE=<id>:<cx>,... and
  TIKI_TIDY=1. VERIFIED: staged placements render; persist across plain
  relaunch; tidy-up restores designed layout. Evidence: stageE-*.png.
  NOT verifiable headless: the gesture itself (simctl cannot synthesize
  long-press-drag) — Carson's device check, listed in LOUNGE_V2_RUBRIC.
  Deviations: fan kept fixed (near-architecture; blade overlay complicates
  lift); floor z-sort by x skipped (declaration-order layering, overlaps
  allowed); settle sound skipped.
- **Scale unification pass — DONE (2026-07-10, Carson's direction: legacy
  elements must match the v2 set's scale).** The delivered set implies a
  ~75 pt person; legacy cast rendered ~2.5×. All legacy east-zone items
  retuned to the new implied scale (v2 pieces untouched as reference):
  patrons span 0.062/0.048 bottom 0.90; Vic span(0.10) bottom 0.744 behind
  a raised bar (canvas top 0.615→0.72, x0 east(0.58), slab 0.008, front
  bottom 0.80); statue 0.085 · palm 0.15 · cat 0.055 · credenza 0.16 ·
  stools 0.13 bottom 0.87 · fronds 0.12 · drink 0.035 on the counter ·
  parrot 0.062 ON the bar (bottom 0.718) · shelf 0.22 top 0.60 · plaque
  0.22 top 0.52 (0.17 truncated ISLANDER — widened) · blowfish 0.075 ·
  float 0.05 · trophy span 0.028; east rug trapezoid tightened under the
  patrons (east 0.46–0.86, y 0.85). East cx nudges for composition:
  statue 0.18, palm 0.30, cat 0.42, credenza 0.52, woman 0.62, stools
  0.88, parrot 0.93. Evidence: scale-east2.png, scale-mid.png. NOTE for
  Stage F re-grade: the plan §3.2's "east frame = classic room exactly" is
  SUPERSEDED by this pass — the east frame is now the classic room at the
  unified scale; depth-0 identity claims no longer apply to the lounge.
- **Stage F — rubric written + v1 graded (B+ 8.44, below bar BY DESIGN);
  remainder listed in LOUNGE_V2_RUBRIC.md §Stage F**: device gesture/fps
  pass (Carson), first-run pan hint, App Store re-staging, re-grade
  (include the scale pass in the v2 evidence set).

## 10b. Effort map

| Stage | What | Effort |
|---|---|---|
| A | asset intake + art swap + fish cap + matchbook covers | M |
| B | wide panning room, world anchors, burst auto-scroll | L |
| C | live windows + earned views | M |
| D | catalog rows, patrons-by-standing, rug colorways | M |
| E | drag placement + persistence + tidy-up | M/L |
| F | rubric pass + store-asset re-staging | M |

Sequential dependency: A → B → (C, D in either order) → E → F. Roughly 5–7
focused dev-days total.
