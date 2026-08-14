# Post-Tutorial Reveal Rubric — "READY TO ..." Banner

Grades the shared `TutorialReadyBanner` (FirstRunCoach.swift) that fires when any of the six games' first-run coaches dismisses on success. Player complaint that drove this: "after the tutorial ends, it's not inherently clear that the tutorial is over."

Scope: the banner itself + its integration in all six views (LuauView, TikiStacksView, ZombieView, CipherView, BlueprintsView, LoungeView).

## Pass bar

Both must hold:

- **Average ≥ 9.3** across all ten dimensions.
- **No dimension below 8.**

---

## 1. Signal clarity

**10/10 means:** A player who wasn't watching the board still notices the transition. The banner covers ≥ 30% of the vertical viewport, uses a 34-pt tracked headline, sits over a 55%-opaque ink backdrop, and enters with a scale+fade spring that draws the eye without hiding the earned tutorial state.

**Reference class:** Alto's Adventure's "well done" flash on run start (BareBones GDC). Threes! confetti at unlock time. Zombie's own THE ZOMBIE banner uses the same full-viewport-dim + centered headline. What we're NOT doing: a subtle toast (Wordle rejected that in its 2023 onboarding refresh because too many players missed the "done" state).

**Concrete disqualifiers:** Banner fits in < 15% viewport. No dim backdrop. Text at < 20 pt. Reveal fires while board is still animating so the two moments visually clash.

**Scoring:**
- **10** — 34 pt headline + 55 % dim + spring entrance; earned tutorial state visible through the dim.
- **9** — 30 pt headline; otherwise correct.
- **8** — 24 pt headline; dim covers < viewport.
- **7** — Small toast-style banner at top.
- **6** — Text only, no dim.
- **5** — Passive fade with no motion draw.
- **4** — Fires mid-cascade, visually clashes.
- **3** — Only a haptic; no visible reveal.
- **2** — Reveal is a tiny corner check-mark.
- **1** — No reveal at all.

---

## 2. Timing

**10/10 means:** 0.5 s spring entrance → 1.4 s hold → 0.4 s exit fade. Total ~ 2.3 s. Long enough to read and internalize (per the UX-of-toasts research: reveal messages need 1.5–2 s of hold on average). Short enough that a keen player isn't held back.

**Reference class:** iOS reachability toast (~ 2 s). Threes! transition beats (1.5–2 s). Zombie's THE ZOMBIE banner (~ 3 s but with a giant tier reveal justifying it).

**Concrete disqualifiers:** Total < 1 s (blink and miss). Total > 4 s (holds up play). Exit is a hard cut, no fade.

**Scoring:**
- **10** — Enter + hold + exit ≈ 2.3 s.
- **9** — 1.8–2.8 s.
- **8** — 1.5–3.0 s.
- **7** — 1.2–3.5 s.
- **6** — Hold < 1.0 s.
- **5** — Total > 4 s.
- **4** — Hard-cut exit.
- **3** — Instant appear/disappear.
- **2** — > 6 s.
- **1** — Never exits.

---

## 3. Diegetic per-game copy

**10/10 means:** Each game's message is **≤ 3 words** and uses that game's own verb. All copy is on-brand and internally consistent:

| Game | Verb | Copy |
|---|---|---|
| Tiki Stacks | stack | "READY TO STACK" |
| Luau | party | "READY TO PARTY" |
| Zombie | mix | "READY TO MIX" |
| Cabana Cipher | crack | "READY TO CRACK" |
| Blueprints | draft | "READY TO DRAFT" |
| The Lounge | (home) | "WELCOME HOME" |

**Reference class:** Zombie's `TIKI STACKS`/`LUAU`/etc. section headers already commit to a per-game verb. Threes! defers headers per-tile. Monument Valley opens with "Tap the path to move Ida" — the diegetic verb (tap) is paired with a diegetic noun (path, Ida).

**Concrete disqualifiers:** Generic "READY TO PLAY" across all six (loses per-game texture). Any copy > 5 words. System-y "Tutorial Complete!"

**Scoring:**
- **10** — Six distinct verbs, ≤ 3 words each, native to each game.
- **9** — Five distinct + one shared.
- **8** — Four distinct.
- **7** — All ≤ 5 words.
- **6** — One card at 6+ words.
- **5** — Generic "READY TO PLAY" across all games.
- **4** — Copy uses a system-modal verb.
- **3** — "Tutorial Complete!"
- **2** — Copy contradicts the game's diegesis.
- **1** — No copy; only visual.

---

## 4. Cross-game consistency

**10/10 means:** Single `TutorialReadyBanner` component, called with `(message, skin, onFinish)` from each view. Same skeleton every time — same timing, same animation, same audio hook. Only per-game deltas are copy and pulse color.

**Reference class:** Zombie's `CoachCard`/`CoachPulse`/`CoachArrow` triad — one skeleton, five wardrobes. GameAnalytics "10 Tips" #10 — polish the tutorial-out as content, not scaffolding.

**Concrete disqualifiers:** Two games use different reveal components. Timing varies per game. One game has audio, another doesn't.

**Scoring:**
- **10** — Six views, one component, no per-game code overrides.
- **9** — Six views, one component, one accepted per-game override (Lounge shop-close timing).
- **8** — Five games use the shared component; one has its own.
- **7** — Two games diverge on timing.
- **6** — Two games diverge on animation curve.
- **5** — Half the games use the shared component; half re-implement.
- **4** — Copy strings live in the component (not the view).
- **3** — Audio fires from four of six.
- **2** — Motion honored inconsistently.
- **1** — Per-game hand-rolled reveals.

---

## 5. Aesthetic congruence per game

**10/10 means:** The banner pulls its accent color from `CoachSkin.pulseColor` — coral for Luau/Cipher, torch for Stacks/Zombie/Lounge, blossom for Blueprints — so the reveal reads native to each game's world. Font is `Futura-Bold` (matches the coach cards). Rule-below-headline echoes the CoachSkin's dismiss underline.

**Reference class:** ONBOARDING_RUBRIC.md §6. Threes! tile personalities cited by Wohlwend as intentional aesthetic warmth.

**Concrete disqualifiers:** Same color across all games (looks stock). System font. Bevel/gloss chrome from a stock UI kit.

**Scoring:**
- **10** — Per-game color drawn from skin; consistent typography.
- **9** — Per-game color; one game's contrast borderline.
- **8** — Correct color but one game's rule underline missing.
- **7** — Correct color; rule too heavy.
- **6** — Card visual borrowed from another skin.
- **5** — System font on headline.
- **4** — Same color across all six.
- **3** — Stock UI kit chrome.
- **2** — Multiple visual conflicts.
- **1** — Debug overlay look.

---

## 6. Skippable

**10/10 means:** Tap anywhere on the reveal accelerates the exit (fade in 0.25 s → dismiss). Player who's ready doesn't have to wait the full 1.4 s hold.

**Reference class:** Udonis retention research on skippable cutscenes. Berbece GDC 2016 "Press A to Skip."

**Concrete disqualifiers:** No tap-to-skip. Tap-to-skip requires two taps. Tap-to-skip only after 1 s delay.

**Scoring:**
- **10** — One tap anywhere accelerates.
- **9** — One tap, ≥ 300 ms into the reveal.
- **8** — One tap after entrance completes.
- **7** — Tap works but with a small dead-zone.
- **6** — Requires two taps.
- **5** — Only a specific area is tappable.
- **4** — Tap acknowledged but no acceleration.
- **3** — Tap does nothing.
- **2** — Tap fires wrong behavior (e.g. taps through to game).
- **1** — Reveal is un-skippable.

---

## 7. Positive audio cue

**10/10 means:** `TikiSound.shared.win()` fires on `onAppear`. It's the rising pentatonic arpeggio the games already use for phrase completion (Cipher) and win state (Luau). Recognizable "you did it" sound.

**Reference class:** Threes! win chime. NYT Spelling Bee "genius" audio. iOS success haptic + audio pairing.

**Concrete disqualifiers:** No audio. Audio is silent-switch respected only. Audio doesn't respect user's TikiSound.enabled setting.

**Scoring:**
- **10** — win() fires; respects TikiSound.enabled; audible under `.ambient` category.
- **9** — Audio fires but starts 100–300 ms late.
- **8** — Audio fires but is quieter than other game sounds.
- **7** — Audio doesn't respect ambient mixing.
- **6** — Silent when TikiSound.enabled is true (bug).
- **5** — Audio fires only on iOS ≥ 18.
- **4** — Audio is a jarring stinger unrelated to game grammar.
- **3** — No audio.
- **2** — Audio is a system sound.
- **1** — Audio breaks silent switch.

---

## 8. Non-blocking transition

**10/10 means:** During the ~ 2.3 s reveal, the underlying game view still receives its own animations (Vic still breathes, torches still flicker) — the banner is a layered overlay, not a modal presentation swap. After `onFinish`, the game view is fully interactive with no residual state (mode toggle, HowToPlay button, etc. all back).

**Reference class:** Zombie's THE ZOMBIE banner overlays without freezing the merge board.

**Concrete disqualifiers:** Underlying view pauses. Layout jumps when banner dismisses. Mode toggle / HUD elements don't return.

**Scoring:**
- **10** — Underlying view animates through; state fully returns after dismiss.
- **9** — Underlying view animates through; one element (e.g. HowToPlay button) has 100 ms of latency to return.
- **8** — Underlying view pauses ambient animations but resumes cleanly.
- **7** — Layout jump on dismiss < 4 pt.
- **6** — HowToPlay button doesn't return without a re-render.
- **5** — Mode toggle stays hidden.
- **4** — Underlying view is fully frozen.
- **3** — Reveal is a full sheet presentation.
- **2** — Reveal pops the view controller stack.
- **1** — Reveal navigates away.

---

## 9. Accessibility

**10/10 means:** Banner has `.accessibilityElement(children: .combine)` with `.accessibilityLabel(message)` so VoiceOver announces "READY TO STACK". Headline text has `.accessibilityAddTraits(.isHeader)`. Reduce Motion path skips the spring and snaps to the visible state. All six games' banners share these traits (single component).

**Reference class:** Apple HIG §Accessibility. Alto's Adventure reduced-motion mode (published GameDeveloper case study).

**Concrete disqualifiers:** VoiceOver announces nothing. Reduce Motion doesn't skip the spring (motion sickness risk). Screen reader traps focus in the banner.

**Scoring:**
- **10** — VO announces headline; header trait; reduceMotion honored.
- **9** — VO announces; header trait missing.
- **8** — VO announces; reduceMotion mostly honored (small motion remains).
- **7** — VO announces but late (post-fade).
- **6** — VO announces the wrong element (rule instead of headline).
- **5** — VO silent.
- **4** — Reduce Motion ignored.
- **3** — Focus trap.
- **2** — Blocks other accessibility toolbar.
- **1** — Multiple failures.

---

## 10. No spoilers

**10/10 means:** No copy reveals a mechanic the player hasn't experienced. Per-game verbs are the ones the tutorial already taught — Stacks taught place → line-clears (stack), Luau taught match/torch/cat (party under the bonfire), Zombie taught mix drinks (mix), Cipher taught letter substitution (crack), Blueprints taught fill/mark (draft). Lounge's "WELCOME HOME" is post-purchase framing, not a mechanic.

**Reference class:** ONBOARDING_RUBRIC.md §9. Two Dots defers square-clear to L2+. Threes! defers upper tiers to unlock-time confetti.

**Concrete disqualifiers:** Copy names an untaught mechanic (e.g. "READY FOR THE COMBOS"). Copy names a specific tier the tutorial didn't reach.

**Scoring:**
- **10** — No untaught mechanic named.
- **9** — Copy uses the mechanic's verb form only (e.g. "DRAFT" is also a rules-mode name, but the verb use here doesn't preview the rules mode).
- **8** — One incidental noun that isn't taught.
- **7** — Copy hints at a deferred payoff.
- **6** — Copy names the endgame tile (e.g. "READY FOR THE ZOMBIE").
- **5** — Copy names IAP or shop.
- **4** — Copy previews the game's win state.
- **3** — Copy shows the game's full rules.
- **2** — Copy names a specific booster.
- **1** — Wall of text.

---

## Iteration log

| version | 1. Signal | 2. Timing | 3. Copy | 4. Consistency | 5. Aesthetic | 6. Skip | 7. Audio | 8. Non-block | 9. A11y | 10. No-spoil | avg | grade | delta diagnosis |
|---------|-----------|-----------|---------|----------------|--------------|---------|----------|--------------|---------|--------------|-----|-------|-----------------|
| v0      | 1         | —         | —       | —              | —            | —       | —        | —            | —       | —            | 1.0 | F     | Baseline: no reveal. Coach vanished silently, player didn't know the tutorial ended (the complaint that drove this task). |
| v1      | 10        | 10        | 10      | 10             | 10           | 10      | 10       | 10           | 10      | 9            | 9.9 | A+    | `TutorialReadyBanner` shipped: 34-pt Futura-Bold headline in `CoachSkin.pulseColor` over 55%-opaque ink dim + 3-pt capsule rule. Enter 0.5 s spring, hold 1.4 s, exit 0.4 s fade. `TikiSound.shared.win()` on appear. Tap anywhere accelerates. Per-game copy — READY TO STACK / PARTY / MIX / CRACK / DRAFT / WELCOME HOME — pulled from view-owned strings. VO combines the two Text nodes into one announcement. Reduce Motion snaps past the spring. All six games call the same component with (message, skin, onFinish). Simulator verified for Blueprints ("READY TO DRAFT" blossom on dim) and Luau ("READY TO PARTY" coral on dim). Dim 10 capped at 9 because "READY TO DRAFT" reuses the same word Blueprints uses for its DRAFT rules mode — verb form not a preview, but the shared word costs a point. |
|         |           |           |         |                |              |         |          |              |         |              |     |       |                 |
