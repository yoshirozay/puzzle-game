# LOUNGE V2 RUBRIC

Grades the wide-lounge rebuild (LOUNGE_V2_PLAN.md). **Pass bar: avg ≥ 9.3 AND
no dimension < 8.** Grade from staged simulator screenshots, wallet math, and
measured behavior — never from intent. Evidence:
`build/progression-shots/loungev2/`.

## Dimensions

1. **Spaciousness** — the lounge reads as a place, not a screen; panning feels
   like moving through a room; item scale stays generous.
2. **Zone composition** — each zone (west music corner / mid seating / east
   bar) composes like a poster on its own; the east opening frame preserves
   the classic room.
3. **Live-window depth** — windows read as architecture with a world outside:
   breath alive, earned views distinct, selection persists.
4. **Discovery** — panning reveals, patrons arrive with standing, purchases
   auto-scroll + burst; a first-run affordance hints that west exists.
5. **Expression** — drag placement, rug colorways, window views: the player
   can make the room theirs; defaults stay curated; reset exists.
6. **Economy horizon** — ceiling ≥ 20k verified through real purchases; the
   ladder from 300 to 3,000 leaves an affordable next want at every rung.
7. **Performance** — pan at 60 fps on device; the 2.2-screen TimelineView
   redraw stays cheap; no jank on lift-drag.
8. **Regression safety** — FTUE intact; migrations verified on real stores;
   staging hooks reproduce every state; build green, zero new warnings.

## Iteration log

| version | 1 Space | 2 Zones | 3 Windows | 4 Discovery | 5 Expression | 6 Economy | 7 Perf | 8 Regress | avg | grade | delta diagnosis |
|---------|---------|---------|-----------|-------------|--------------|-----------|--------|-----------|-----|-------|-----------------|
| v1 (Stages A–E) | 9 | 8.5 | 9 | 8 | 8 | 9 | 7 | 9 | 8.44 | B+ | Graded from the A–E evidence set. Strong: east frame = classic room; live windows persist earned views (volcanoNight survived relaunch); patrons verified both ways (empty at WALK-IN w/ exact wallet 700, occupied at tier 2); drag placements persist + children ride parents (disc/trophy rode the credenza west) + VIC TIDIES UP restores; ceiling 21,030 verified twice via real purchases; migrations passed on real stores twice (C+D fields over a human-played store; E field over the ISLANDER store). Docks: **Perf 7 — unprofiled** (code-read only; full-world TimelineView redraw); Discovery 8 — first-run pan hint still unimplemented; Expression 8 — the long-press gesture itself is UNVERIFIABLE via simctl (staged via TIKI_PLACE) and needs a human hand on device; Zones 8.5 — mid zone sparse until purchases land, couch composition changes when occupied (artist's loveseat — Carson to bless). Below pass bar BY DESIGN until Stage F closes: device gesture feel, fps profile, pan hint, App Store re-staging. |
| v2 (fresh-eyes re-grade, post scale pass) | 9.5 | 8.5 | 9 | 8 | 8.5 | 9.5 | 7.5 | 9 | 8.69 | B+ | Independent re-verification, evidence `freshgrade-*.png` (9 staged states, fresh build; CORRECTION same-day: the "zero warnings" read was an incremental-build artifact — a later full recompile showed the 3 documented pre-existing warnings persist in GamePickerView/LuauGame, none in lounge files). UP: wallet re-proven 8,970 = 30,000−21,030 EXACT through the real purchase flow incl. Sign; window persistence re-proven twice more (volcanoNight AND glowTide survived plain relaunches); placement staging + tidy-up re-proven (piano 0.335→0.60→restored); FTUE coach correct in both beats incl. shop-already-open edge case; first sim perf numbers — idle full room 30–36% CPU vs lagoon baseline 21–27%, empty lounge 29–30% → full-world redraw ≤1.4× an accepted shipped scene (Perf 7→7.5; device fps still unmeasured). NEW DEFECT: tier-3 plaque renders "NAME ON THE…" — the scale pass widened for ISLANDER but NAME ON THE DOOR (16 ch, 7.5pt fixed, lineLimit 1) still truncates at the apex reward moment; confirmed in 2 shots + code (`HouseStandingPlaque`). Still docked: pan hint absent (grep-confirmed), App Store assets predate v2 (final-jpg dated Jul 7), device gesture/fps pass pending. Nits (no dock): aquarium-frame ~20 pt sliver intrudes on the east opening frame; plantBush default anchor overlaps piano's left end; movableImage slop hit-areas overlap on dense west furniture (device check will tell). Below bar on the avg AND the Perf<8 floor — same Stage F wall as v1, plus one new concrete fix. |

## Stage F remainder (the last mile to the bar)

1. Device pass (CARSON): long-press lift feel, drag vs pan conflict, thermals,
   pan fps — Instruments or eyeball at 120 Hz. ROUND 1 (2026-07-16, iPhone
   17): pan fought the furniture — `movableImage` slop was
   max(24, halfMinDim) so the big pieces blanketed the floor band in
   gesture surface; now 18 pt for small pieces, 6 pt for large. Ghost
   items also gained tap-to-shop (Carson request): tapping an unowned
   silhouette opens the shop scrolled to its row (coach-safe: unscrolled
   during FTUE so the BUY beat stays on the mug; staging hook
   TIKI_GHOST_TAP=<id>; taps never claim moving touches, so pans over
   ghosts still win). Feel re-check pending.
2. ~~First-run pan hint~~ DONE 2026-07-16: one-time discovery drift
   (camera eases to world 0.65 and settles back east when the west wing
   has content; one-shot `loungePanHintShown`, skips under coach/shop/
   reduceMotion/zone staging). Proven live: console line + burst frames,
   evidence `freshfix-drift-hold.png`.
3. Re-stage App Store screenshots + preview lounge segment
   (`appstore/tools/compose_screenshots.swift`, sim "TikiGames ProMax") — the
   current store assets show the one-screen lounge.
4. ~~NEW (v2 fresh-eyes): fix tier-3 plaque truncation~~ DONE 2026-07-16:
   long standings engrave on two lines split at the middle space —
   "NAME ON / THE DOOR" reads whole (evidence `freshfix-plaque-zoom.png`).
5. Re-grade this rubric after 1–4 (v2 fresh-eyes row added 2026-07-10; v3
   after Stage F closes).

### New-user fresh-eyes pass (2026-07-16, evidence `freshuser-*` / `freshfix-*`)

Day-one walkthrough (fresh install → early buys → full room) surfaced and
fixed four more, all sim-verified, audit 40/40 PASS, build green:

- **Purchase auto-scroll never centered** — scroll markers carried `.id`
  outside `.position`, so scrollTo resolved the full 2.2-screen world and
  every purchase parked at the viewport edge (Baby Grand half-cut,
  `freshuser-burst-2.png`). Markers are now layout-true (spacer-offset);
  a fresh purchase lands centered (`freshfix-piano-centered.png`). Zone
  parks unchanged by design (west clamps to the wall).
- **Ceiling void** — the water-pass roof read as empty sky in stills. Two
  cues sell "looking up at the lagoon" now: a stepped sun-refraction disc
  over the east frame (sways/sinks on the 90 s breath) and three slow
  flat-ink fish crossing on their own lanes; wavelets bumped 0.22→0.26.
  All ride `t` — reduceMotion holds a still frame.
- **Ghost hooks became silhouettes** — unowned anchors render the actual
  art desaturated (wall 0.20, floor 0.16) instead of blank patches; west
  statement trio (piano/couch/tall table) added to the floor set so
  panning has a visible promise (`freshfix-ghosts-east.png`).
- **Seam lantern** — pendant at world 0.54 straddled the east opening
  frame edge (0.545); moved to 0.56.
- Verified existing but unproven: shop header shows "EARN POINTS PLAYING
  ANY GAME" exactly when nothing is affordable (`freshfix-shop-hint.png`).

### Fresh-eyes round 2 + light pass (2026-07-16, evidence `round2fix-*`)

Second from-scratch pass (day-1 → full room at three parks, eight zoom
crops). Ten nits + the first cast-light layer, all sim-verified same day,
audit 40/40 PASS (bush tuck allowlist moved with its anchor), build green:

- **Pendant cords skewered their fixtures** — HangingSprite ran the cord
  to `frame.maxY`, over and past the art (both sprites carry their own
  cord stub). Cord now stops 14% into the frame; blowfish art recentered
  in its viewBox (translate −140→−136.5) so cord meets stub dead-on.
- **Bamboo bar front read as tartan** — 50/50 slats + bright full-width
  rope bands. Now 14 poles (deep seam + light catch each), staggered
  joint lines on a 3-pole cycle, twine lashings dimmed/tightened, and an
  overhang shadow under the slab so patrons read in front of the counter.
- **Ghost grammar unified** — hook cards read as wall stains while floor
  silhouettes read as owned furniture (the credenza fooled this pass
  too). Cards gone; one bare-art grammar, wall 0.26 / floor 0.12.
- **Bush default 0.26→0.41** — out of the piano's underside (read as a
  stuck render), now crown-over-the-couch-arm mirroring the tiered pot.
- **Couch woman reseated… then REVERTED (Carson's call, same night)** —
  the crossed-legs/leaned-head pose went in with this round, but Carson
  preferred the original on device ("can we revert that change") —
  couch-couple.svg is back to its pre-round-2 straight-leg pose,
  restored line-for-line from the pre-edit read. Taste beats theory;
  the "doesn't read as seated" note stays here for the record only.
  THEN CUDDLED (Carson's direction, minutes later): she shifted 30
  units left to sit pressed beside him, his arm re-routed BEHIND her
  (path moved before her head in draw order, `M91 38 Q114 22 134 30`)
  with a skin-dot hand emerging on her far shoulder, and her arm now
  lands on his knee. Original straight legs kept. Evidence
  `couple-cuddle.png`.
- **Toast couple actually toasts** — arms rose from a droop to a cheers
  angle, cobalt tumblers became coral cups, clink-adjacent over the
  table center.
- **Glass float got its net** — two ±45° meridian ellipses + a top knot;
  no longer an atom diagram.
- **Welcome coach points at the world** — copy names Vic's mug, so the
  mug's spot answers: pulse on Vic's raised hand during the SHOP beat,
  and tapping Vic (ghost grammar: he holds the unclaimed gift) opens the
  shop at the FREE row. Handler path verified via TIKI_GHOST_TAP
  (`round2fix-mugtap-shop.png`); the literal tap needs Carson's finger
  (round-2 lesson: hooks don't verify hit-testing). Layers above Vic are
  all `allowsHitTesting(false)` on day 1, so the zone is structurally
  reachable. SKIP was woodDark-on-lagoon (invisible); now ink capsule +
  cream text.
- **Light pass (first cast light in the room)** — warm radial pools
  under all four pendant lanterns (per-lantern 7 s breathing); coral
  wall halo behind the neon TIKI sign (13 s breath, ~0.5 s dip every
  ~47 s reads as a neon hiccup); owned windows spill a low-sun wedge
  onto the planks (drawn under ghosts/furniture); five caustic dapple
  ellipses drift just under the beam, tying lagoon to room. All ride
  `t` on the existing TimelineView — reduceMotion holds a still frame.

Deliberately not done this round (candidates for next): ambience audio
(the record spins silently), patron micro-loops (sip/clink/parrot bob/
cat tail), idle camera drift-ins or pinch zoom, shop flavor captions +
menu categories, seated-on-stool patron pose, foreground silhouette
plane, warmth-scales-with-ownership, time-of-day.

### Floor depth (2026-07-16, evidence `band-*` / `depth-*`)

Shipped twice in one evening. v1 was a two-band snap (rail + one
downstage band at 0.91h/×1.12, audit 58/58, evidence `band-*`). Carson's
device pass killed the snap within the hour: "I still don't understand
how to move the pieces on the wood floor… items should get slightly
larger the further down you move it, smallest against the wall" — the
piece not tracking the finger vertically read as broken, and he's
right that depth is continuous. v2 (audit 66/66, evidence `depth-*`):

- **Model**: eligible pieces carry `posDepth` 0…1. Foot lerps from the
  piece's designed rail (0.795–0.815h) to `deepFoot` 0.93h; width grows
  linearly to ×1.16 (`deepScale`). Depth 1 puts feet ON the rug.
- **Eligible: every standing floor piece** (13 — plants ×3, palm, cat,
  stools, tall table, couch, piano, credenza, statue, both patrons).
  v2 launched with 8 and a "skyline stays on the rail" rule; Carson's
  next device pass killed that too ("I should be able to move any piece
  horizontally and vertically" — a piano that only slides sideways
  reads as broken). Only the rug (floor-flat ground) and corner fronds
  (screen-edge framing, feet below deepFoot) keep fixed y; wall-hung
  pieces stay horizontal-only (hanging height would be its own
  feature). Audit 81/81 (13×3 depth checks + rug/fronds-fixed).
- **Gesture**: during the long-press lift the piece's foot tracks the
  finger's height continuously between the rail and 0.93h — direct
  manipulation, no snap, no flip haptic. Horizontal unchanged.
- **Z-order**: every floor piece gets `.zIndex(frame.maxY)` — stacking
  by feet, continuously. Rail pieces tie at their designed feet, which
  preserves the curated declaration order (bush/tiered tucks intact).
- **Persistence**: `LoungeItem.posDepth: Double = 0` (additive →
  lightweight migration; replaced the hours-old `posBand` pre-release),
  mirrored as `store.itemDepths`; VIC TIDIES UP resets depths.
- **Staging**: `SIMCTL_CHILD_TIKI_DEPTH=<id>:<0..1>,…` through the real
  path. Audit: 8×3 checks (full-depth foot 0.925–0.935, full-depth
  scale 1.155–1.165, half-depth foot lerps to 0.48–0.52 of the range) +
  2 skyline-ignores-depth checks.
- **Move hint retuned with it (Carson's same message)**: the purchase
  trigger now fires on the first MOVABLE purchase (`movableIDs`, 20 of
  27 — firing on the Umbrella Drink taught a gesture the player
  couldn't perform on anything), and the room-entry fallback requires
  ≥1 movable piece owned instead of ≥2 of anything.

### THE GRAND RETUNE (2026-07-16 night, Carson: "I like this way more —
### make the lounge wider, do the full re-anchor pass", evidence `grand-*`)

The itemScale=2 experiment (65/96 audit, pile-ups, dwarf Vic) became
the new canon. The trick that made "redo everything" tractable:
**double the world with the items** — worldScreens 2.2 → 4.4, and every
anchor converted from `east(x)` screen-fractions to its old-world
NUMERIC fraction (east(x) = (1.2+x)/2.2 at the old size). Same
composition, twice the size, seen through a half-as-wide camera. The
`east()` helper is deleted. Audit re-canonized: **81/81** at the new P
(≈2× ≈ 0.178h).

What moved beyond the doubling:
- **Bar counter 0.744h → 0.690h** (chest on the 2× patron), slab ×2,
  overhang ×2, joints/twine thickened; audit's own stale `barTop` was
  four of the fifteen first-run failures.
- **Vic scales with the canon** (fixture, but a 1× bartender at a 2×
  bar read as a child); bottom 0.765 → 0.755 keeps his
  hidden-behind-counter fraction in range. Bob ×2.
- **Mid-wall restack** (real bug the audit caught: doubled marlin +
  aquarium = 0.243h of art over 0.231h of wall, aquarium overlapped the
  couch by 54 pt): marlin west over the piano (cx 0.32, top 0.43),
  aquarium up and recentered over the couch (cx 0.47, top 0.46), fan
  east between them (cx 0.42).
- **Plaque ×1.5 via scaleEffect** (fixed-size engraving fonts scale
  with the plate). Drink/parrot bottoms follow the new counter (0.688).
- **Windows and roof hangings stay 1× per Carson's exclusion** — their
  audit ranges are the old canon halved. They now read distant/small
  against the 2× furniture; flagged as his call to revisit.
- Wall = 2.14 P (cozy canon, range re-set 1.8–3.2 from 2.5–4.5).

**Grand-retune device note (pan feel):** "panning isn't as smooth at 2×,
the gesture doesn't register sometimes." Two mechanisms, both fixed:
(1) the ambient TimelineView redrew 6+ full-world Canvases at the
display's 120 Hz and the retune doubled their raster area — main-thread
saturation stuttered pans and delayed touches; the ambient clock is now
capped at 30 fps (`minimumInterval: 1/30` — breath/sway/flicker read
identically, native scroll keeps full rate). (2) 2× furniture blankets
the screen, so most pans start on a movable piece and a touch-down
dwell ≥0.2 s became a lift; big pieces (max dim > 220 pt) now INSET
their hit surface 10 pt (small pieces keep +18, mid +6) and the
long-press tolerates only 8 pt of wander (was 10). Audit 81/81.
Verified by mechanism + sim render; the smoothness verdict is Carson's
finger on device.

**Round 2 (Carson: "the drag gesture is hijacking the panning"):** he
was right — the deeper bug was ARBITRATION, not just load. The lift was
attached with `.gesture`, which claims the touch at finger-down while
the long-press deliberates; when the press FAILS (finger moved — i.e. a
pan), the ScrollView never gets the touch back and the swipe dies.
Tried: `.simultaneousGesture` + `.scrollDisabled(roomLifting)` via an
`onLift` callback + a scenePhase reset. **REVERTED on Carson's device
verdict** — back to plain `.gesture`; the 30 fps ambient cap, the
hit-surface tiers, and maximumDistance 8 (the previous round) remain
the shipped mitigation. Plausible failure of the simultaneous scheme:
the pan tracked the same touch as an in-flight lift-drag before
scrollDisabled could bite (dual movement), or lifts got harder to
start under a live scroll — unconfirmed; the arbitration theory itself
stays plausible-but-unproven. If pan feel degrades again, profile with
Instruments before re-theorizing.

### The Lagoon (2026-07-16 night, Carson's "Water scene SVGs" delivery,
### evidence `lagoon-*`)

11 shop items that live in the WATER band — bought, not placed: they
drift, bob, and stand watch on their own (none draggable — you buy
life, not furniture). Catalog 27 → 38, ascending lagoon ladder 400 →
5,000 (The Buoy, The Lagoon Duck, Message in a Bottle, The Dolphin,
Honu the Turtle, The Sailboat, The Shark, The Orca, The Far Island,
The Volcano, The Yacht — total sink 20,700).

- **Import hygiene**: every delivered SVG carried a baked cream wavelet
  (would double the room's own water and bob WITH the item — wrong
  physics) — stripped; all rgba() fills pre-blended to solid hexes
  against what they overlay (Xcode's SVG importer ignores fill alpha —
  the July lesson, applied at import this time).
- **Motion**: `LagoonItem` config — drifters wrap the 4.4-screen world
  with per-item period/direction matched to each sprite's native facing
  (nothing renders mirrored); moored floaters (buoy, bottle) ride a
  swell with a little roll; landmarks (island 0.10, volcano 0.52) hold
  position. Volcano crater gets a breathing torch glow.
- **Message in a Bottle is the interactive one**: tap → a note in Vic's
  voice (6 rotating lines, "WISH YOU WERE HERE — NOBODY" …), CoachCard
  vehicle, defers to coach/move-hint.
- Purchase scroll + burst chase the drift (anchorFrame returns the
  live waterFrame). Audit 81 → **92/92** (each item's swell frame stays
  inside the water band above the beam).
- Nudges from the first render: volcano 0.58 → 0.52 (was under the
  SHOP button at mid park), bottle lane 0.055 → 0.078 (was brushing
  the status-bar clock).

### Device round 3 (2026-07-16, Carson on iPhone, evidence `devfix3-*`)

Three reports, all fixed + sim-verified, audit 40/40:

- **"ISLAN…" plaque** — the two-line engraving splits at a SPACE;
  ISLANDER (8 glyphs, no space) stayed on the 11 pt line that fits ~7.
  New squeeze tier: long single words engrave at 9 pt / tracking 1.0
  (`devfix3-plaque-islander.png` reads whole).
- **Drag-to-move never taught** — the v1 hint fired once on the
  first-ever purchase, 6 s, gated by a consumed UserDefaults flag; live
  saves never see it again. Key bumped to `tikiMoveHintSeen.v2`
  (re-teaches everyone once), a room-entry fallback shows it in any
  furnished room (≥2 non-gift pieces, coach idle, shop closed), and the
  card now demos itself: one owned piece does two spring hops (wiggleID
  → movableImage offset — the same lift the finger gets). Hop verified
  by mechanism + card on screen; the motion itself is a live animation.
- **Cat invisible** — span 0.04 → 0.058 (~18 pt → ~26 pt wide, ~0.44 P
  tall); the Suspicious Cat finally reads beside the credenza, amber
  eyes and all. cat|credenza tuck already allowlisted; audit clean.
