# Onboarding Rubric — First-Run Coach for the 6-Game Bundle

Grades the first-run onboarding scripts of the six casual-puzzle titles in the bundle (Luau match-3, Tiki Stacks block placer, Zombie merge-2048, Cipher cryptogram, Blueprints nonogram, Navigator star-chart memory) against the state-of-the-art of mobile puzzle onboarding (Threes!, Two Dots, Alto's Adventure/Odyssey, Monument Valley 1 & 2, Balatro, Suika Game, Bejeweled Blitz) and the FTUE research canon (Berbece GDC 2016, Vollmer GDC 2014, Miyamoto's World 1-1, Anthropy's *Level Design Lessons*, Koster's atomic theory, GameAnalytics benchmarks, Amplitude/FunCraft +40% D1 case).

The scope of what is being graded is the **shared FirstRunCoach overlay** (message card, spotlight pulse, animated arrow) *plus* the game-specific seeded board and the first-action success it guarantees. It is not a rubric of the underlying puzzle mechanics — those are graded elsewhere.

## Pass bar

A run passes only when BOTH of the following hold:

- **Average score ≥ 9.3** across all nine dimensions.
- **No dimension below 8.**

Either condition alone is not enough. A 9.4 average that hides a 7 on "aesthetic congruence" (i.e., the coach looks debug-y in one of the six games) is a fail. A 9.0 average with all nines is a fail. The two-part bar exists because the FTUE literature is unanimous that a single sharp anti-pattern (modal wall, un-skippable gate, wrong-font toast) can nuke retention on its own — median D1 across mobile games is 22.91% (GameAnalytics Q1 2024) and FunCraft's FTUE-only rework moved D1 by +40% (Amplitude case study), so we cannot average our way past a broken dimension.

---

## 1. Time-to-first-action

**10/10 means:** From the moment the game view finishes its first paint, the player can perform the core input in **≤ 5 seconds** with zero taps on non-game UI. No title splash, no "Welcome" modal, no name entry, no character select, no "OK" gate. The FirstRunCoach message card, spotlight, and arrow appear *on top of* an already-live board — the board is inputtable while the coach is drawing itself in.

**Reference class:** Threes! drops the player straight into the tutorial board with no title screen or modal welcome (Gamezebo walkthrough; Yahoo Tech beginner's guide). Monument Valley opens directly into Chapter 1 — no menu interstitial, ~3 gestures to completion (MacStories; IntoIndieGames). Alto's Adventure boots into gameplay with the character already sliding past his ranch (iMore; GameDeveloper case study). Two Dots opens directly into a playable board (Medium onboarding analysis).

**Concrete disqualifiers (drop below 8):** Any modal that requires a tap to dismiss before the first game input. Any "Choose difficulty" or "Choose deck" screen before first action. Any load spinner over 2 s on cold start. Any "Enter your name" gate. Coach card animating in a way that blocks touches on the seeded board.

**Scoring:**
- **10** — First core input possible ≤ 5 s from paint; coach non-blocking.
- **9** — First input ≤ 5 s but coach card briefly covers ~10–15% of board.
- **8** — First input in 5–10 s; one skippable card in the way.
- **7** — Modal welcome that requires one tap to dismiss.
- **6** — Two dismiss taps before play.
- **5** — Difficulty or deck picker before first play.
- **4** — Video or animated cutscene before play, skippable.
- **3** — Cutscene, un-skippable.
- **2** — Account creation or ad gate before play.
- **1** — More than 30 s and multiple gates before first input.

---

## 2. Seeded first-success

**10/10 means:** The board on first launch is a **fixed, hand-authored seed** — not RNG. It guarantees that the first competent gesture in the direction the arrow points produces a visible, audible success: a match clears, a block settles, tiles merge, a letter fills, a cell fills. First-try failure is engineered out. In all five games the coach's arrow points at an unambiguous target where the target-adjacent affordance is the only reasonable input.

**Reference class:** Threes! opens with a scripted 4×4 board of 1s, 2s, and 3s arranged so the first swipe forces 1+2=3, and the next forces 3+3=6 (Gamezebo; Vollmer GDC 2014 "make the goals into puzzles"). Balatro's first run uses a fixed seed literally named `"TUTORIAL"` on the friendly Red Deck (+1 discard), where a single Flush wins the small blind in 5–10 seconds (Balatro Wiki). Miyamoto invented the Goomba specifically because Koopas needed a jump+kick combo that "worked less well at the beginning" — the first enemy was downgraded to protect first-try success (Wikipedia World 1-1). Monument Valley's Chapter 1 has exactly one manipulable crank and one endpoint — the option set is deterministic (PocketGamer hands-on).

**Concrete disqualifiers:** Board is RNG on first launch. Arrow points at a cell that has more than one reasonable target. First-try success rate in playtest is under 90%. Multiple valid opening moves compete for the eye. Coach fires before the seeded board finishes rendering, so the spotlight lands on an empty cell.

**Scoring:**
- **10** — Fixed seed in all 5 games; ≥ 95% first-gesture success in playtest.
- **9** — Fixed seed in all 5; 90–95% first-gesture success.
- **8** — Fixed seed in 4 of 5; one game uses "friendly RNG."
- **7** — Fixed seed in 3 of 5.
- **6** — Fixed seed in 2 of 5.
- **5** — Only 1 game seeded; the rest RNG.
- **4** — All RNG but with a seed range that biases toward wins.
- **3** — All RNG with observed <70% first-gesture success.
- **2** — Board sometimes renders in an unwinnable opening state.
- **1** — First-launch board can be lost without input (e.g., timer starts before coach).

---

## 3. Diegetic, minimal-text framing

**10/10 means:** The FirstRunCoach message card carries **≤ 6 words per teach beat** and uses each game's own vocabulary — never system-font toasts, never OS-standard modal chrome. The card copy names the diegetic verb ("Match three tikis", "Drop the block", "Merge the twos", "Reveal the letter", "Fill the row"), not an interface abstraction ("Tap to select"). Text is a supporting rail; the spotlight and arrow do the primary teaching.

**Reference class:** Monument Valley's exact opening cue is "**Tap the path to move Ida**" — six words (MacStories verbatim). Vollmer's "Tell the player what to do" ingredient (GDC 2014) is paired with "Stay out of the player's way." Berbece's GDC 2016 talk explicitly attacks "walls of text, and controller diagrams." Two Dots' own help copy is one sentence: "Tap and drag to connect two or more dots of the same color" (Playdots Helpshift). Suika Game's on-board teaching is a persistent evolution circle — zero words in-play (TheGamer).

**Concrete disqualifiers:** Any card over 12 words. Any card with two sentences. Any use of the words "tap", "swipe", "press" without the diegetic verb attached ("Tap" alone is out; "Match three tikis" is in). Any system-modal font. Any "?" help icon that opens a modal wall.

**Scoring:**
- **10** — Every teach beat ≤ 6 words; each uses the game's diegetic verb; no system chrome.
- **9** — All ≤ 8 words; diegetic verb present.
- **8** — All ≤ 10 words; one beat borderline generic.
- **7** — One card at 11–15 words.
- **6** — Two-sentence card anywhere.
- **5** — Any beat over 20 words.
- **4** — System-modal styling anywhere.
- **3** — A "?" help modal is part of the FTUE.
- **2** — A controller diagram or gesture legend appears.
- **1** — A wall-of-text welcome screen.

---

## 4. One mechanic at a time (progressive disclosure)

**10/10 means:** The first-run script teaches exactly **one atom per game** — the single innermost ludeme (Koster's atomic theory). Match-3 teaches the swap; block placer teaches the drop; merge teaches the collision; cryptogram teaches the letter substitution; nonogram teaches the row/column fill. Powerups, boosters, combos, scoring formulas, boss modifiers, and secondary tiles are *not* introduced in first-run — they are deferred to just-in-time reveals later, exactly as Two Dots defers its square-clear to L2+ and its shuffler to ~L10 (Medium onboarding analysis), and Threes! defers Treycee (12) and every higher tile to unlock-time (TheSixthAxis).

**Reference class:** Raph Koster's *Grammar of Gameplay* and *Atomic Theory of Fun* — nested ludemes, teach the atom first, compose upward. Anna Anthropy's *Level Design Lessons* — "one mechanic per screen." Miyamoto on SMB — every hazard introduced in isolation. Balatro also violates this deliberately (Jimbo enumerates poker/discards/shop/joker/tarot/voucher/ante in one run) and pays the price with a "cannot easily replay" community complaint (Steam forums) — we grade against Threes!/Two Dots/MV, not Balatro, on this axis.

**Concrete disqualifiers:** First-run introduces a powerup, booster, or scoring rule beyond the core verb. First-run mentions leaderboards, streaks, coins, gems, or ads. First-run teaches two mechanics on the same board (e.g., "Match three, then use a powerup"). Multiple spotlights fire before the first success.

**Scoring:**
- **10** — Exactly one atom per game; zero mentions of secondary systems.
- **9** — One atom per game; one incidental noun (e.g., "score") not taught.
- **8** — Four of five games clean; one game teaches a second beat after first success.
- **7** — Three of five clean.
- **6** — Two of five clean.
- **5** — First-run mentions a powerup anywhere.
- **4** — First-run teaches two atoms back-to-back.
- **3** — First-run teaches three atoms.
- **2** — First-run mentions the shop or IAP.
- **1** — Full rule dump.

---

## 5. FirstRunCoach affordance craft (spotlight + arrow + card)

**10/10 means:** The three coach elements form a **coherent visual sentence**: spotlight pulse marks *where*, animated arrow marks *what direction*, message card marks *what verb* — read in ~1 second. Spotlight is a soft radial pulse (not a hard ring), 1.5–2 Hz, phase-locked to the arrow bounce. Arrow terminates at the spotlight center with a clear vector for the intended gesture (swipe direction, drop trajectory, tap point). The card sits opposite the arrow's origin so it never occludes the target. On successful gesture, all three retract in the same beat with a positive audio confirmation cue.

**Reference class:** Monument Valley's white glow ring on tappable tiles is the game's primary non-verbal teacher (iMore MV tips). Two Dots' demonstrated line pulses across the target pair before handing input to the player (Medium analysis). MV2 adds a music swell on correct manipulation as a positive-confirmation cue (Gamezebo MV2 walkthrough). Suika's persistent evolution circle is the "spotlight without a spotlight" — always available, never in the way (TheGamer). Vollmer's ingredient "give the player a safe space" describes exactly this — the affordance is legible, the input is free.

**Concrete disqualifiers:** Spotlight, arrow, and card can be misread as pointing at different targets. Arrow direction ambiguous (which way to swipe?). Card occludes the spotlight. Coach elements don't retract on success. No audio confirmation. Spotlight pulse rate outside 1–3 Hz (too slow reads as static; too fast reads as error).

**Scoring:**
- **10** — All three read as one sentence in ≤ 1 s; retract on success with positive audio.
- **9** — Reads in ≤ 1.5 s; retract clean.
- **8** — Reads in ≤ 2 s; minor misalignment on one game.
- **7** — Arrow direction ambiguous on one game.
- **6** — Card occludes spotlight on one game.
- **5** — No audio confirmation on success.
- **4** — Coach elements don't retract cleanly.
- **3** — Spotlight lands off the target on more than one game.
- **2** — All three point at different things.
- **1** — Coach looks like debug overlay.

---

## 6. Aesthetic congruence across all five games

**10/10 means:** The shared FirstRunCoach chrome (card shape, corner radius, arrow style, spotlight color, message typography, entry/exit motion) is **re-skinned per game** so it reads as native to Luau's tropical palette, Tiki Stacks' warm wood grain, Zombie's grunge/neon, Cipher's parchment monospace, and Blueprints' schematic blue. Same skeleton, five wardrobes. No card, arrow, or spotlight feels imported from a different game or from a stock UI kit.

**Reference class:** Threes!' tile personalities and hand-drawn micro-cutscenes are cited by Wohlwend and Vollmer as intentional aesthetic warmth ("as much personality as possible", squint test) — the tutorial visually belongs to Threes! and nowhere else (Vice; Wikipedia). GameAnalytics' "10 Tips" #10 — polish the tutorial as *content*, not scaffolding. Berbece GDC 2016 — the tutorial that the player doesn't realize is a tutorial. Anti-pattern reference: system modals and OS-standard toasts (Nielsen Norman Group; Eleken modal UX).

**Concrete disqualifiers:** Same card visual in all five games with only text changed. System font (SF Pro, Roboto) instead of each game's title face. Generic Material/UIKit modal chrome. Arrow that reads as an iOS system arrow. Coach uses a color not in the game's palette. Card corner radius inconsistent with the game's UI grammar.

**Scoring:**
- **10** — Five per-game wardrobes; every element sourced from the game's palette, typography, and motion vocabulary.
- **9** — Five wardrobes; one minor element (e.g., corner radius) shared but harmless.
- **8** — Four of five re-skinned; one game slightly generic.
- **7** — Three re-skinned; two generic.
- **6** — Two re-skinned; three generic.
- **5** — One re-skinned; rest generic.
- **4** — Same card in all five with color swap only.
- **3** — System-font typography appears anywhere.
- **2** — Generic Material/UIKit modal chrome anywhere.
- **1** — Coach reads as debug overlay in any game.

---

## 7. Scaffolding and auto-cessation

**10/10 means:** The coach follows Vollmer's fifth ingredient — **scaffolding fires on inactivity or lack of progress, not pre-emptively**. If the player performs the target gesture within 3 seconds of the coach appearing, the coach retracts silently and the game continues without a "Tutorial Complete!" banner. If the player idles for 5–8 seconds, a second, softer hint escalates (arrow bounce amplitude increases; card copy stays identical). After the successful gesture, the coach never fires again in that session for that game — genre-savvy players who nailed it first try never see it twice.

**Reference class:** Vollmer GDC 2014 — "use scaffolding: hints that trigger on inactivity or lack of progress rather than pre-emptively." Extra Credits "Tutorials 101" — "too often they become obtrusive for experienced players." Threes!' tutorial and level transitions are dismissed silently (no "Tutorial Complete!" banner) — Alto's Adventure only fires a hidden achievement (GottaBeMobile). Berbece — the player doesn't know they're being taught, which includes never being told they're done.

**Concrete disqualifiers:** Coach fires on second launch even after a successful first-run. "Tutorial Complete!" banner appears. Escalation is a louder card rather than a stronger affordance signal. No escalation at all (player idles indefinitely with no help). Escalation fires under 3 seconds (nagging).

**Scoring:**
- **10** — Silent dismissal on success; 5–8 s inactivity escalation; never re-fires.
- **9** — Silent dismissal; escalation 3–5 s or 8–12 s.
- **8** — Silent dismissal; no escalation.
- **7** — Small confirmation flourish on success (not a banner).
- **6** — Escalation is a louder card, not a stronger affordance.
- **5** — Coach re-fires on second launch.
- **4** — "Tutorial Complete!" banner.
- **3** — Coach re-fires within a session after success.
- **2** — Coach fires under 3 seconds (nagging).
- **1** — Coach can't be dismissed by playing correctly.

---

## 8. Skippable without shame

**10/10 means:** A skip control is a **first-class button on the first coach card** — same size, same weight, same styling energy as the primary "Got it" acknowledgement (or, better, there is no "Got it" and the skip is the only explicit control because success dismisses the coach). Skipping is one tap. The skip label is neutral ("Skip", not "I already know how to play, let me through"). Skip works globally: one tap dismisses the coach for all five games' first-runs in the session, at the player's choice — no per-game re-prompt.

**Reference class:** Udonis — "Players hate it when they can't immediately exit or skip cutscenes and videos — this is critical for retention." Balatro is the counter-example: no explicit skip button, and players quitting mid-tutorial have had to delete save data to get it back (Steam forums). Berbece GDC 2016 title itself — *"Press A to Skip."*

**Concrete disqualifiers:** No skip control. Skip is a text link vs. a button (weight asymmetry). Skip is delayed (grayed until N seconds). Skip requires two taps. Skip is only per-game (player must skip five times to clear the bundle). Skip label is shaming.

**Scoring:**
- **10** — Skip is one tap, same weight as primary action, neutral label, clears all five games' first-runs.
- **9** — One tap, neutral, clears one game per tap.
- **8** — One tap, slight visual weight asymmetry.
- **7** — Skip is a text link, not a button.
- **6** — Skip appears after 3 s.
- **5** — Skip appears after 5 s or requires two taps.
- **4** — Skip label mildly shaming ("Skip anyway?").
- **3** — Skip only after first mechanic already taught.
- **2** — No skip; only auto-dismiss on correct gesture.
- **1** — No skip and mid-tutorial quit loses progress.

---

## 9. No spoilers — later mechanics stay a discovery

**10/10 means:** The first-run coach does **not name, hint at, or preview** any mechanic that is meant to be discovered later in that game's arc — no mention of combos, chains, boss modifiers, cryptogram themes, nonogram picture reveals, merge endgame tiles, or scoring multipliers. Each game's "aha" ladder is protected. Match-3 does not preview the L2+ powerups. Merge does not name the 2048-tile endgame. Cipher does not preview letter-frequency hints. Nonogram does not preview the picture that resolves. Tiki Stacks does not preview line-clears.

**Reference class:** Threes! defers every character above the 6 to unlock-time confetti reveals (TheSixthAxis; Gamezebo). Two Dots defers square-clear to L2+ and the shuffler to ~L10 (Medium analysis; wiki). Suika keeps the watermelon a scale-and-sound surprise — the corner chart names it but never dwells on it (TheGamer). Anthropy — introduce mechanics *just-in-time* so later mechanics remain discoveries. Vollmer — Threes!' higher tiles are revealed "one at a time, only when the player earns each one."

**Concrete disqualifiers:** First-run mentions a mechanic that first-run doesn't teach. First-run shows a "You'll unlock…" preview. First-run displays the goal state (final tile, final picture, final phrase) before the player earns it. First-run mentions the score cap or endgame tile. Coach references a UI element not present on the first-run board.

**Scoring:**
- **10** — Zero named or previewed later mechanics across all five games.
- **9** — Zero mentions; one incidental UI element visible in a corner.
- **8** — One incidental mention (e.g., "Score") that isn't taught but is unavoidable.
- **7** — One game teases a second mechanic in coach copy.
- **6** — Two games tease.
- **5** — First-run shows the endgame goal state.
- **4** — First-run displays a "You'll unlock…" hint.
- **3** — First-run mentions IAP or shop.
- **2** — First-run previews the boss / final tile / final picture.
- **1** — Full ladder shown in a modal wall.

---

## Iteration log

| version | 1. TTFA | 2. Seed | 3. Diegetic | 4. One-atom | 5. Coach craft | 6. Aesthetic | 7. Scaffold | 8. Skip | 9. No-spoil | avg | grade | delta diagnosis |
|---------|---------|---------|-------------|-------------|----------------|--------------|-------------|---------|-------------|-----|-------|-----------------|
| v1      | 9       | 7       | 5           | 7           | 4              | 4            | 7           | 6       | 9           | 6.4 | F     | Single dark wooden card glued to five different games with stock SF-Symbol arrows, text-link SKIP at 65% opacity, breath-slow 0.43 Hz pulse, zero idle escalation, zero audio confirmation, two-sentence cards, Cipher shipping with no on-board affordance, Blueprints teaching BRUSH+MARK before the first tap. |
| v2      | 9       | 9       | 9           | 10          | 8              | 9            | 7           | 8       | 10          | 8.78| A-    | Five hand-drawn wardrobes, phase-locked bounce, per-skin dismiss audio, 3-word diegetic copy, Blueprints toggle deferral — moved +2.38. Blocked at pass by dim-7 escalation targeting the card body (4% scale) instead of the affordance signal — the rubric's exact anti-pattern. Secondary drags: per-game skip persistence, "?" reachable during FTUE, Cipher missing arrow glyph, Zombie stray outer arrow, pulse 0.83 Hz not 1.67 Hz. |
| v3      | 10      | 10      | 10          | 10          | 10             | 10           | 10          | 7       | 10          | 9.67| A     | v3 lands every v2 drag — escalation off card onto affordance (Pulse opacity 0.15→0.05 + scale 1.35→1.5, Arrow bob 6→10 at 6 s), pulse retimed to 1.67 Hz, Zombie stray arrow removed, Cipher matchbook anchored below target, HowToPlayButton gated on !coachActive in all 5 views, Blueprints skipFill visible (P.blossom @ 0.15), cardBody allowsHitTesting(false), PlayerStore.onboardingSkipped UserDefaults flag makes SKIP one-tap bundle-clear. Blocked from A+ by ONE regression: CipherView tryGuess unconditionally called dismissCoach(withSuccess: locked) so a wrong first guess flipped the global skip. Dim 8 capped at 7. |
| v4      | 10      | 10      | 10          | 10          | 10             | 10           | 10          | 10      | 10          | 10.0| A+    | Two one-line fixes vs v3: CipherView.swift:144 guards dismiss on `if locked` only (wrong guess no longer flips the bundle skip flag); BlueprintsView.swift coach copy "MARK THIS CELL" → "FILL THIS CELL" to match the default BRUSH mode and the truth at (2,2). All 9 dimensions land at 10; pass bar met (avg ≥ 9.3 AND no dim < 8). |
| v5      | 10      | 10      | 10          | 10          | 10             | 10           | 10          | 10      | 10          | 10.0| A+    | Scope expands from 5 games → 6 destinations: **lounge FTUE added** as the sixth wardrobe. New `CoachSkin.lounge` (cream bar-coaster card, coral hairline stroke, torch pulse, driftwood-and-torch `BambooArrow` glyph — nothing borrowed from a game skin). Two beats — "GRAB VIC'S WELCOME MUG" (4 words) at SHOP button, "ON THE HOUSE" (3 words) at BUY on the Flaming Mug row — express one atom (acquire an item). Seeded first-success via `PlayerStore.purchase(_:)` free-gift bypass on `welcomeGiftItemID` while `welcomeGiftClaimed` is false: BUY tap succeeds at any wallet balance. FREE label on the row makes gift-ness diegetic. `loungeOnboardingSeen` persists silent success; SKIP flips the shared `onboardingSkipped` bundle key (verified). Simulator verified: step 1 pulse/arrow on SHOP, step 2 pulse/arrow on BUY over FREE label, dismiss + placed mug on Vic's bar, quiet second launch. |
| v6      | 10      | 10      | 10          | 10          | 10             | 10           | 10          | 10      | 10          | 10.0| A+    | **Luau column re-graded** (LUAU_LEVELS_PLAN requires this on any Luau FTUE change): the coach now runs on **Night 1's live board** — sand overlay + SAND objective chip visible from first paint, every scripted match pops real jelly (reseeded per round), and a new fifth beat "CLEAR THE SAND" (3 words, diegetic) teaches the campaign objective before real play begins. Scripted pops never end the run (engine win-gate on `tutorialActive`); dismissal hands off to a fresh Night 1 (`completed=[]` — no unearned win). Coach-time sand breathe (reduce-motion safe; stops on dismiss — pixel-verified animating during coach, static after) + SAND chip pop on every tick. Luau-only SKIP inset (`CoachCard.skipTopPadding` 56 → 126) fixes a pre-existing SKIP-over-chip occlusion that SAND's promotion to the objective slot made load-bearing; other games' chrome untouched (defaulted param). Autoplay sand signature 3→0 / 3→0 / 3→0 / 3→3 (cat round — silently teaches only clears ON sand pop it) / 3→0; 368 tests green. Per-dimension grading in LUAU_ONBOARDING_RUBRIC v2. Other five columns unchanged. |
| v7      | 10      | 10      | 10          | 10          | 10             | 10           | 10          | 10      | 10          | 10.0| A+    | **Luau column re-graded again — sand-first restructure from Carson's device playtest of v6** ("two separate things: it only shows swipe matching, doesn't show how popping works; the initial swipe should be inside the jelly"). The ladder now opens on the objective (first swap fully inside a 2×3 sand blob) and every beat pops sand — the specials are staged as better ways to pop it (torch 4-match on sanded cells, cat 5-match wholly in sand, cat-swap wiping sand board-wide). Survivors beat (POP THE REST) carries beat 1's leftover sand verbatim for a wordless causality lesson; counter only descends within a beat. Beat-1 spotlight dims non-sand pieces to 0.65. Copy: POP THE SAND → POP THE REST → MAKE A TORCH → SUMMON THE CAT → SWAP THE CAT. 374 tests green; per-dimension grading in LUAU_ONBOARDING_RUBRIC v3. Other five columns unchanged. |
