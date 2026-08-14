# Luau Onboarding Rubric — Thorough FTUE

Grades Luau's first-run scripted rounds against the state-of-the-art of match-3 onboarding (Candy Crush's 5-level tutorial arc, Bejeweled Blitz's scripted openings, Two Dots' L1–L10 disclosure ladder) and the atomic-teaching canon (Vollmer GDC 2014, Koster's atomic theory, Miyamoto's World 1-1).

Scope: the LuauView + LuauGame first-run — the multi-round scripted ladder plus the shared FirstRunCoach chrome. As of v3 the ladder is **sand-first**: it opens on the campaign objective (first swap inside a sand blob), and every beat — including all three specials beats — pops sand. The SAND chip is present from first paint and only ever counts down within a beat. As of v4 the ladder is **six beats**: the 2x2 square (the Matchington shape, a match since the square-rule engine change) gets its own beat between the causality beat and the torch. Does not grade the general match-3 engine.

## Pass bar

Both must hold:

- **Average ≥ 9.3** across all ten dimensions.
- **No dimension below 8.**

The general onboarding pass bar catches shallow tutorials that grade well on average by failing one axis (a single 6 for "ladder depth" would let a one-swap tutorial post a 9.0 average). Thorough onboarding must clear both bars.

---

## 1. Ladder depth

**10/10 means:** The scripted arc **opens on the objective and never leaves it**: (1) the player's first swap sits fully inside a sand blob and pops it, (2) a survivors beat proves pop causality on the same sand story, (3) the 2x2 square beat teaches the second matchable shape with sand under all four cells, then (4–6) the three specials tiers — 4-match torch, 5-match cat, cat-swap wipe — each staged so their payoff **pops sand** (shapes and specials alike are taught as better ways to pop). Six beats; every beat pops sand; the counter never rises mid-beat.

**Reference class:** Tiki Stacks: 4 scripted rounds walking 1-line → 2-line → 3-line → 4-line clears (fixed roundset in `TutorialRound`). Zombie: 3 rounds walking tier 2 → 3 → 4 (value 4 → 8 → 16). Candy Crush's opening levels each introduce one new tile type. Two Dots defers square-clear to L2+ and shuffler to ~L10 — mechanics unlock one at a time.

**Concrete disqualifiers:** Fewer than 3 rounds. Any round teaches two mechanics at once. The payoff round teaches a mechanic that isn't seeded on the board (e.g., "swap the cat" without a cat on the board).

**Scoring:**
- **10** — sand-first 5-beat ladder: objective opens, causality beat, all three specials staged to pop sand.
- **9** — objective opens and closes but the specials beats play off-sand (mechanics interlude).
- **8** — objective taught only as the FINAL beat after a mechanics-first ladder (the v2 shape — reads as two separate tutorials).
- **7** — 3 rounds but one round teaches a secondary beat.
- **6** — 2 rounds.
- **5** — 1 round only (regression to single-atom).
- **4** — 1 round + a text card claiming more.
- **3** — Rounds run out of order or skip a tier.
- **2** — Rounds contradict each other.
- **1** — No scripted ladder at all.

---

## 2. Seeded per-round success

**10/10 means:** Every scripted round's pulsed swap is a **fixed guaranteed match**. First-gesture success rate is 100% across all rounds — the coach's pulse never lies. Non-tutorial cells are filled from a deterministic checkerboard base (kinds 4/5 alternating), so no accidental 3-in-a-row can form off-target and steal the round's payoff.

**Reference class:** Zombie: fixed pair at (1,0) and (1,1), swipe DOWN always merges (`ZombieGame.tutorialTilePositions(round:)`). Stacks: shape auto-drops into the seeded well (`TikiStacksGame.tutorialRounds`). Threes! opens with a scripted board where the first swipe is 1+2=3 (Gamezebo). Balatro tutorial uses seed `"TUTORIAL"` on Red Deck.

**Concrete disqualifiers:** Any round has 3-in-a-row before the swap. Any round's swap doesn't produce the intended tier. Non-tutorial cells contain the tutorial kind and can accidentally chain into the match.

**Scoring:**
- **10** — 100% first-gesture success on all rounds; base kinds are provably match-free.
- **9** — 100% first-gesture success; base kinds could in principle form a match but don't at the current seed.
- **8** — 100% success on 3 of 4 rounds.
- **7** — 100% success on 2 of 4.
- **6** — 90–99% success (rare RNG defeat).
- **5** — <90% success on any round.
- **4** — Swap sometimes produces a different tier than intended.
- **3** — Swap sometimes produces no match at all.
- **2** — Board renders in a state where the pulsed swap is invalid (non-adjacent).
- **1** — Rounds don't seed at all.

---

## 3. Diegetic minimal-text framing

**10/10 means:** Each round's card is **≤ 6 words**, uses Luau's vocabulary ("MATCH", "TORCH", "CAT", "SUMMON", "SWAP"), and names the diegetic verb — never "tap" or "swipe" alone. Copy escalates round-by-round without repeating the same phrase.

**Reference class:** Monument Valley "Tap the path to move Ida" (6 words). Two Dots "Tap and drag to connect two or more dots of the same color" (13 words — too long, our reference for what NOT to do). Threes! uses the game's own tile faces to teach.

**Concrete disqualifiers:** Any card > 8 words. Any generic verb ("TAP", "SWIPE") without the diegetic object. Same card copy on two rounds.

**Scoring:**
- **10** — All 4 cards ≤ 6 words, diegetic verb, escalating copy.
- **9** — All ≤ 6 words; one card verb slightly generic.
- **8** — One card at 7–8 words.
- **7** — One card at 9–12 words.
- **6** — Two cards borderline generic.
- **5** — Any card at 13+ words.
- **4** — Two rounds share identical copy.
- **3** — A card uses a generic UIKit verb only.
- **2** — All rounds share one card.
- **1** — Wall-of-text card.

---

## 4. Per-round atomic clarity

**10/10 means:** Each round teaches **exactly one new beat**. R0 = POP THE SAND — swipe, match, and pop fused into the game's core loop (the swap pair sits inside the blob). R1 = POP THE REST — causality: beat 0's match popped exactly the cells it landed on, and the survivors it left ARE this beat. R2 = MATCH A SQUARE — the 2x2 is the second matchable shape, staged with sand under all four cells. R3 = MAKE A TORCH — a 4-match is a bigger pop (all four cells sanded). R4 = SUMMON THE CAT — a 5-match, wholly in sand. R5 = SWAP THE CAT — the wipe pops sand across the whole board: specials are mass sand removal. No round smuggles combos, scoring rules, or moves-limit into its lesson. Reusing the swap gesture for a new lesson is the Two Dots pattern, not a repeat — the atom is the lesson, not the gesture.

**Reference class:** Koster's atomic theory — nested ludemes, teach the atom first, compose upward. Anthropy's *Level Design Lessons* — "one mechanic per screen." Miyamoto — Goomba invented so first enemy needed only jump, not jump+kick.

**Concrete disqualifiers:** A round teaches two new mechanics. A round teaches the SAME mechanic as the previous round with no new twist. Scoring or leaderboards mentioned.

**Scoring:**
- **10** — 4 rounds, 4 distinct atoms in strict ladder order.
- **9** — 4 rounds, 4 atoms, one incidental noun ("score") shown.
- **8** — 3 rounds, 3 atoms, strict order.
- **7** — 4 rounds but one is a repeat of the prior atom.
- **6** — Two rounds teach the same atom.
- **5** — Any round teaches two atoms.
- **4** — Rounds out of order.
- **3** — Powerup mentioned but not taught.
- **2** — Combo scoring formula mentioned.
- **1** — Full rule dump.

---

## 5. Coach chrome craft (pulse + arrow + card)

**10/10 means:** Pulse rings anchor the swap pair, `CoachSwapArrows` sits between them, card lives at the bottom (opposite the target). Pulse is 1.5–2 Hz (phase-locked, per shared `CoachPulse`). **Anchor cells stay identical across all rounds** — the chrome doesn't chase across the board mid-tutorial. Pulses hide during the ~900 ms round transition so they don't float over a mid-collapse board. The beat-1 spotlight (non-sand pieces at 0.65 opacity, dead after the first round) is chrome doing the framing so the card doesn't have to.

**Reference class:** The general ONBOARDING_RUBRIC §5 (Monument Valley's white glow ring, Two Dots' demonstrated line pulse). Vollmer "give the player a safe space" — legible affordance, free input.

**Concrete disqualifiers:** Pulse cells change between rounds. Pulse visible during round reseed (jumps over falling pieces). Arrow direction ambiguous. Card occludes the swap pair.

**Scoring:**
- **10** — Fixed anchor cells; pulses hide during transitions; card at bottom clear.
- **9** — Fixed anchor; pulses briefly ghost through one transition frame.
- **8** — Fixed anchor; no transition hide.
- **7** — Anchor cells move once during the ladder.
- **6** — Card partially occludes the swap pair once.
- **5** — No transition hide + anchor cells move.
- **4** — Arrow direction ambiguous on one round.
- **3** — Pulse pointing at wrong cell one round.
- **2** — Card fully occludes target.
- **1** — Chrome reads as debug overlay.

---

## 6. Aesthetic congruence with Luau

**10/10 means:** The coach uses `CoachSkin.luau` — plank card, ember stroke, coral pulse, torch arrow — nothing borrowed from another game's wardrobe. The scripted board renders on the same bonfire scenery the run uses (`LuauBackgroundView`); lanterns and score chrome sit above; the "?" glossary button hides while the coach is up (`!coachActive` gate).

**Reference class:** The general ONBOARDING_RUBRIC §6 — five hand-drawn wardrobes. Threes! tile personalities cited by Wohlwend as intentional aesthetic warmth. GameAnalytics "polish the tutorial as content, not scaffolding."

**Concrete disqualifiers:** Any use of Stacks/Zombie/Cipher/Blueprints skin. System font in card. HowToPlayButton visible during coach. Board renders on a different background than the run.

**Scoring:**
- **10** — Luau skin + Luau scenery + HowToPlayButton gated + coach card contrast passes.
- **9** — Luau skin + gated; one minor color drift.
- **8** — Correct skin; HowToPlayButton reachable during FTUE.
- **7** — Correct skin; card contrast borderline on one round.
- **6** — Card visual reused from another skin.
- **5** — System font on card.
- **4** — Board renders on wrong background.
- **3** — Score/moves chrome visually collides with the coach chrome.
- **2** — Multiple visual conflicts.
- **1** — Reads as debug overlay.

---

## 7. Round advancement legibility

**10/10 means:** After each successful swap the game **waits ~900 ms** for the cascade + specials spawn animation to breathe, then respawns the next round's board with a spring transition. The `roundTransitioning` gate prevents the pulse from ghosting over mid-collapse pieces. On the final round, the same 900 ms respect precedes the dismiss so the payoff (cat color wipe) reads before the coach exits with its positive audio cue (`CoachSkin.luau.dismissSound` = clear-1 pentatonic tick).

**Reference class:** Zombie's `handleTutorialMerge` — 720 ms hold then reseed. Stacks' equivalent timing. Vollmer "scaffolding, not banners" — the round advance is silent, no "Round Complete!" text.

**Concrete disqualifiers:** No pause between rounds (visually chops). "Round Complete!" banner. Payoff round exits before the specials animation renders. Positive audio missing.

**Scoring:**
- **10** — 900 ms pause, spring reseed, no banner, positive audio on final.
- **9** — 900 ms pause; one round transition slightly jarring.
- **8** — 700–900 ms pause on all rounds.
- **7** — < 700 ms pause on any round.
- **6** — Final round exits without hearing the audio.
- **5** — "Round Complete!" banner.
- **4** — No pause at all — instant reseed.
- **3** — Pulses visible during reseed (ghost frame).
- **2** — Reseed doesn't reset the moves counter (chrome lies).
- **1** — Round never advances.

---

## 8. Scaffolding and auto-cessation

**10/10 means:** Silent dismissal on the final round's success (no "Tutorial Complete!" banner). Escalation via the shared `CoachPulse`/`CoachArrow` escalation window (6 s idle → opacity 0.15→0.05 + scale 1.35→1.5, arrow bob 6→10) — never a louder card. On successful FTUE completion, `seenHowTo = true` persists via `GameSaveState`, so a re-launched Luau never re-fires the ladder.

**Reference class:** The general ONBOARDING_RUBRIC §7 lineage. Threes!' silent dismissal. Alto's hidden achievement, no banner (GottaBeMobile).

**Concrete disqualifiers:** "Tutorial Complete!" banner. Coach re-fires on second launch. Escalation is a louder card, not stronger affordance. Escalation < 3 s (nagging).

**Scoring:**
- **10** — Silent dismiss + shared escalation + persistent `seenHowTo` across launches.
- **9** — Silent dismiss + escalation; persistence works but a partial-round resume replays.
- **8** — Silent dismiss + escalation; persistence flag doesn't survive killed-app resume.
- **7** — Small confirmation flourish on success.
- **6** — Escalation is a louder card, not stronger affordance.
- **5** — Coach re-fires on second launch.
- **4** — "Round Complete!" text.
- **3** — Coach nags before 3 s.
- **2** — Coach fires under 3 s.
- **1** — Coach can't be dismissed by playing correctly.

---

## 9. Skippable without shame

**10/10 means:** SKIP chip is a first-class button on the first coach card, same styling as the game skins (weight parity). One tap dismisses the whole scripted ladder. `store.onboardingSkipped` propagates to the other games' first-runs (bundle-global — verified in ONBOARDING_RUBRIC v3/v4). Neutral label. `game.endTutorial()` restores the standard board so play resumes cleanly. SKIP never occludes live chrome — with SAND promoted to the objective chip during the coach, Luau passes a deep `skipTopPadding` so the pill sits below the chip row, not over it.

**Reference class:** The general ONBOARDING_RUBRIC §8 + Berbece GDC 2016 "Press A to Skip." Balatro is the counter-example (no explicit skip → players deleted save data).

**Concrete disqualifiers:** SKIP absent. SKIP only skips the current round (player must skip 4 times). SKIP dismisses coach but leaves a broken half-tutorial board. SKIP label is shaming.

**Scoring:**
- **10** — SKIP one-tap clears bundle-wide; game resumes cleanly.
- **9** — One-tap clears Luau; other games still re-fire.
- **8** — SKIP with slight visual weight asymmetry.
- **7** — Skip is a text link, not a button.
- **6** — Skip appears after 3 s.
- **5** — Skip requires two taps.
- **4** — Skip label mildly shaming.
- **3** — Skip only after first mechanic already taught.
- **2** — No skip; auto-dismiss only.
- **1** — No skip, mid-tutorial quit loses progress.

---

## 10. No spoilers — later payoffs stay a discovery

**10/10 means:** The scripted ladder **doesn't preview or name** the mechanics deferred past first-run — torch×torch (FIRE CROSS!), torch×cat (TORCH STORM!), cat×cat (CATACLYSM!), the moves limit, cascade combo multipliers, or the sunrise game-over. Each of those has its own discovery beat in the run itself. The SAND chip and sand film are **taught content** as of v2 (the objective is the point of the FTUE), not spoilers; the MOVES counter stays an unavoidable chrome noun, unspoken by any card.

**Reference class:** Threes! defers every tile above 6 to unlock-time confetti. Two Dots defers the square-clear to L2+. Suika keeps the watermelon a surprise. Anthropy — introduce mechanics *just-in-time* so later ones remain discoveries.

**Concrete disqualifiers:** Coach copy names "FIRE CROSS" / "TORCH STORM" / "CATACLYSM". Coach mentions the moves counter or "night ends." Coach shows the cascade multiplier UI.

**Scoring:**
- **10** — Zero mentions of later payoffs; moves/cascade/sunrise all discovery.
- **9** — Zero mentions; one deferred noun visible in the chrome corner (MOVES counter — unavoidable).
- **8** — One incidental mention (e.g. "SCORE") that isn't taught.
- **7** — Coach copy teases a special×special combo.
- **6** — Coach copy names the 20-moves limit.
- **5** — Coach shows the cascade multiplier UI directly.
- **4** — Coach shows the sunrise game-over preview.
- **3** — Coach mentions IAP or shop.
- **2** — Coach previews all three combos.
- **1** — Full rule dump.

---

## Iteration log

| version | 1. Depth | 2. Seed | 3. Diegetic | 4. Atomic | 5. Chrome | 6. Aesthetic | 7. Advance | 8. Scaffold | 9. Skip | 10. No-spoil | avg | grade | delta diagnosis |
|---------|----------|---------|-------------|-----------|-----------|--------------|------------|-------------|---------|--------------|-----|-------|-----------------|
| v0      | 5        | 10      | 10          | 10        | 10        | 10           | —          | 10          | 10      | 10           | 9.4 | A     | Baseline before this session: single-round tutorial teaching only the 3-match. Ladder depth capped at 5/10 — no torch, no cat, no payoff. Scored A on the general rubric because it never claimed to be thorough. |
| v1      | 10       | 10      | 10          | 10        | 10        | 10           | 10         | 10          | 10      | 10           | 10.0| A+    | Four scripted rounds: swap → 3-match / 4-torch / 5-cat / cat wipe. Same anchor cells (3,3)(3,4) across all rounds so chrome doesn't jump. Neutral 4/5 checkerboard base guarantees no accidental match. `tutorialActive` suppresses refill so intermediate rounds stay pure. `roundTransitioning` hides pulses during 900 ms reseed. Card copy escalates diegetically (MATCH THREE → MAKE A TORCH → SUMMON THE CAT → SWAP THE CAT). Simulator verified all 4 round layouts (debug `TIKI_LUAU_TUTORIAL=0..3`). Post-campaign gap (known, Stage D+1): ladder played on an endless board — jelly, the SAND chip, and the campaign objective went untaught. |
| v2      | 10       | 10      | 10          | 10        | 10        | 10           | 10         | 10          | 10      | 10           | 10.0| A+    | **The Stage D+1 objective integration.** Coach runs on Night 1's live board (`newLevel(L1)` before every seed): sand film + SAND chip from first paint, scripted matches pop real jelly, jelly reseeds per round (fresh vignette). New fifth beat "CLEAR THE SAND" (3 words) — one precise 3-match exactly on the three sand cells, no companion match. R3's cat wipe leaves sand untouched — silent lesson that only clears ON sand pop it. Engine: `evaluateEndCondition` gated on `tutorialActive` (scripted pops can't win the night or flip `isOver` under the coach card); tutorial payloads persist no live-run fields (mid-coach kill → clean coach restart, never a half-tutorial resume). Sand film breathes during the coach (0.55 s half-period — subordinate to the 0.3 s swap pulse; Reduce Motion static; stops on dismiss — pixel-verified animating during coach, 4/560 static after). SAND chip pops on every tick, silent on reseeds. Luau-only `skipTopPadding` 126 fixes the SKIP-over-chip occlusion. Evidence: sim screenshots rounds 0–4 (`TIKI_LUAU_TUTORIAL=0..4`), autoplay sand signature 3→0/3→0/3→0/3→3/3→0 through the real first-run path, handoff `night=1 sand=3 completed=[]`, 368 tests green (5 new: reseed pin, win-gate, R4 precision, gate-reopen, tutorial-payload). |
| v3      | 10       | 10      | 10          | 10        | 10        | 10           | 10         | 10          | 10      | 10           | 10.0| A+    | **Sand-first restructure, from Carson's device verdict on v2** ("it's two separate things — the swipe tutorial and the jelly never integrate; the initial swipe should be inside the jelly"). The ladder now opens on the objective and never leaves it: R0 POP THE SAND (2×3 blob, swap pair fully inside, single match pops the top row, 6→3) → R1 POP THE REST (board reseeds, sand carries the survivors verbatim — wordless causality, 3→0) → R2 MAKE A TORCH (4-match on 4 sanded cells, 4→0) → R3 SUMMON THE CAT (5-match wholly in sand, 5→0) → R4 SWAP THE CAT (every wipe target on sand: mass removal, 8→0). Per-round scripted jelly in `TutorialSeed` (rounds declare sand explicitly; R1 = R0's survivors by construction, so dev-hook round jumps stage exactly what natural flow shows). Counter never rises mid-beat; every beat after the first ends at zero. Beat-1 spotlight: non-sand pieces dim to 0.65 while the first card is up. Anchors stay (3,3)/(3,4) through all five beats — §5 holds without exception. v2's "cat wipe leaves sand untouched" inversion deleted (Carson's critique: every beat must reinforce the loop, not counterpoint it). Evidence: beat screenshots 0–4, autoplay 6→3/3→0/4→0/5→0 + wipe pinned by test (FX show delays the engine swap past the capture hook's sample — caveat documented in the hook), handoff `night=1 sand=3 completed=[]`, 374 tests green (blob-arc continuity, per-beat sand coverage, cat-wipe 8→0, ENCORE test rebased to the single-match R0). |
| v4      | 10       | 10      | 10          | 10        | 10        | 10           | 10         | 10          | 10      | 10           | 10.0| A+    | **MATCH A SQUARE beat (round 2) — the 2x2 Matchington shape joined the engine's match rules, so the ladder teaches it before the specials.** Kind-0 trio at (2,4)/(2,5)/(3,5), completer at (3,3): the anchored swap drops it into (3,4), closing the square (cols 2-3 × rows 4-5) with sand under all four cells — SAND 4→0, no 3-run anywhere post-swap, so the pop is unmistakably the square's. Torch/cat/wipe shift to rounds 3/4/5 (`spawnRounds` pacing follows); anchors stay (3,3)/(3,4) through all six beats; checkerboard base is square-proof by construction (no same-kind adjacency). Beat only stageable because `hasLegalSwap` learned squares — pre-square engines would shuffle the seeded board away as swap-less. `TIKI_LUAU_TUTORIAL` hook gained the missing `pickerOpen = false` (frontier picker was covering staged rounds). Evidence: beat-2 sim screenshot (card + staged square + SAND 4), full 6-beat ladder autoplay to the frontier handoff, per-beat engine tests re-indexed + `tutorialSquareRoundPopsAllFourSand` (4 clears / 4→0 / no spawn / no refill / one round / no win latch), 410 tests green. |
