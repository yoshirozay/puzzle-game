# Cabana Cipher Onboarding Rubric — Thorough FTUE

Grades Cabana Cipher's first-run scripted beats against the state-of-the-art of cryptogram/word-puzzle onboarding (NYT Spelling Bee, Wordle onboarding shift 2022-2023, Cryptogram.co, Puzzle Baron's Cryptograms, Two Dots' letter-substitution research spinoffs) and the atomic-teaching canon (Vollmer GDC 2014, Koster's atomic theory).

Scope: the CipherView + CipherGame first-run — the seeded pre-reveal, the multi-beat FTUE, and the shared FirstRunCoach chrome. Does not grade the phrase catalog or the completion overlay in general.

## Pass bar

Both must hold:

- **Average ≥ 9.3** across all ten dimensions.
- **No dimension below 8.**

Cryptogram FTUEs regularly fail dim 5 (multiple pulses fire at once) and dim 7 (silent beat progression). Both bars matter.

---

## 1. Ladder depth

**10/10 means:** The FTUE walks **at least the three visible cryptogram beats** — a first guess (tap tile → tap letter), the HINT affordance, and a second guess. Three beats, each teaches one new atom or affordance. A pre-reveal (letter T) sets up "same code = same letter" as a *demonstrated fact*, not a taught lesson — the coach doesn't need to name it.

**Reference class:** Zombie: 3 rounds (1+1=2 → 2+2=4 → 4+4=8→16 spawn). NYT Spelling Bee: teach select, submit, and shuffle in three onboarding moments. Puzzle Baron auto-fills common letters (analogous to our T pre-reveal) and lets players discover the atom.

**Concrete disqualifiers:** Fewer than 3 beats. Any beat teaches two atoms at once. HINT beat happens BEFORE the player has locked at least one letter (they'd feel confused why they need help).

**Scoring:**
- **10** — 3 beats, one atom per beat, HINT sandwiched between two guess beats.
- **9** — 3 beats, but HINT is the last beat (no reinforcement guess after).
- **8** — 2 beats (basic guess + HINT).
- **7** — 3 beats but one is a repeat.
- **6** — 2 beats and both are guesses (no HINT taught).
- **5** — 1 beat only (regression to single-atom).
- **4** — 1 beat + a text card claiming more.
- **3** — Beats fire out of order (HINT before first guess).
- **2** — Beats contradict each other.
- **1** — No scripted beats.

---

## 2. Seeded per-beat success

**10/10 means:** The tutorial phrase is fixed at `phraseIndex = 0` ("THE CAT KNOWS WHO POURED THE LAST ZOMBIE"). The pre-reveal (letter T) always lands, always visible on the board when the coach fires. The pulse ALWAYS targets a valid, unrevealed tile whose plain letter is not yet on the used list. HINT's target letter is always novel (not the letter the pulse pointed to).

**Reference class:** Puzzle Baron's tutorial phrase is fixed. Wordle's first play is a fixed word for onboarded users (but not published). Zombie's `tutorialTilePositions(round:)` is a fixed pair per round. Deterministic seeds > "usually works" every time.

**Concrete disqualifiers:** Phrase index isn't pinned. Pre-reveal doesn't land (chosen letter isn't in the phrase). Pulse points at an already-solved tile. Keyboard pulse points at an already-used letter.

**Scoring:**
- **10** — Fixed phrase; pre-reveal always lands; pulses always valid across all beats.
- **9** — Fixed phrase; pre-reveal always lands; pulse valid but ambiguous once (two tiles could be "first").
- **8** — Fixed phrase; pre-reveal doesn't ALWAYS land (falls back gracefully).
- **7** — Phrase is not pinned but usually index 0 on fresh install.
- **6** — Pulse sometimes points at already-solved tile.
- **5** — Keyboard pulse sometimes points at used letter.
- **4** — HINT beat's reveal collides with next beat's target.
- **3** — Phrase varies wildly on restart.
- **2** — Coach can lock into a state with no valid target.
- **1** — Coach never has a valid target.

---

## 3. Diegetic minimal-text framing

**10/10 means:** Each beat's card is **≤ 6 words**, uses cryptogram vocabulary ("TILE", "LETTER", "HINT", "CRACK"), and escalates round-by-round. No "TAP" without a diegetic object.

**Reference class:** Zombie beat 0 "DOUBLE THE MUGS" (3 words). Monument Valley "Tap the path to move Ida" (6 words). Wordle's first-play copy: "Type your first guess."

**Concrete disqualifiers:** Any card > 8 words. Any two beats share the same copy. Copy uses only "TAP" without the diegetic noun.

**Scoring:**
- **10** — All 5 sub-cards ≤ 6 words, diegetic, distinct.
- **9** — All ≤ 6 words; one repeat allowed for phase A/B parity.
- **8** — All ≤ 8 words.
- **7** — One card at 9–12 words.
- **6** — Two cards borderline generic.
- **5** — Any card at 13+ words.
- **4** — Two beats share identical copy without phase parity justification.
- **3** — A card uses a generic UIKit verb only.
- **2** — All beats share one card.
- **1** — Wall-of-text card.

---

## 4. Per-beat atomic clarity

**10/10 means:** Beat 0 teaches the substitution atom (tap tile → tap letter → lock). Beat 1 teaches the HINT affordance in isolation — the tile/keyboard pulses stand down so the HINT button is the single unambiguous target. Beat 2 practices the substitution atom on a NEW tile — no new mechanic. Each beat teaches exactly one thing.

**Reference class:** Koster's atomic theory. Anthropy — "one mechanic per screen." Two Dots defers the square-clear to L2+.

**Concrete disqualifiers:** Beat 1 pulses both HINT and a tile simultaneously (ambiguity). Beat 0 or 2 shows a HINT pulse concurrently with the tile/keyboard pulse.

**Scoring:**
- **10** — 3 beats, 3 atoms in strict order, no overlapping pulses across beats.
- **9** — 3 beats, 3 atoms; pulses transition with a one-frame overlap.
- **8** — 2 beats + a natural third moment (game teaches by playing).
- **7** — 3 beats but one is a repeat of the prior atom.
- **6** — Two beats teach the same atom.
- **5** — Any beat teaches two atoms.
- **4** — Beats out of order.
- **3** — Powerup / boost mentioned but not taught.
- **2** — Scoring formula mentioned.
- **1** — Full rule dump.

---

## 5. Coach chrome craft (pulse + arrow + card)

**10/10 means:** The two-phase teach (tile pulse THEN keyboard pulse) never fires both at once for beats 0 and 2. Beat 1's HINT pulse suppresses the tile and keyboard pulses via `coachTargetCipher` gate (nil on beat 1). Card copy renames on beat change. Arrows point at the pulse target: `.down` for tile (arrow below) and keyboard (arrow above), and `.down` for the HINT button (arrow above, offset up).

**Reference class:** The general ONBOARDING_RUBRIC §5. Vollmer's "safe space" — legible affordance, free input.

**Concrete disqualifiers:** Tile pulse and HINT pulse fire simultaneously. Card visible while target is off-screen. Arrow direction ambiguous.

**Scoring:**
- **10** — Mutually exclusive pulses per beat; card/arrow read as one sentence.
- **9** — Pulses transition with a ≤ 200 ms overlap.
- **8** — Correct pulses; arrow direction slightly redundant.
- **7** — One beat has an ambiguous arrow.
- **6** — Card partially occludes the target once.
- **5** — Pulses can fire in wrong beat.
- **4** — HINT beat has no visible pulse.
- **3** — Pulse pointing at wrong element one beat.
- **2** — Card fully occludes target.
- **1** — Chrome reads as debug overlay.

---

## 6. Aesthetic congruence with Cipher

**10/10 means:** The coach uses `CoachSkin.cipher` — cream card, ink hairline stroke, torch pulse, matchbook arrow (parchment idiom for a cryptogram). The FTUE renders on `CipherBackgroundView` (poolside cabana), and `HowToPlayButton` hides while `coachActive` is true. Nothing borrowed from another game's wardrobe.

**Reference class:** The general ONBOARDING_RUBRIC §6. Threes! tile personalities.

**Concrete disqualifiers:** Any use of Stacks/Zombie/Luau/Blueprints skin. System font. HowToPlayButton visible during coach.

**Scoring:**
- **10** — Cipher skin + poolside scenery + HowToPlayButton gated.
- **9** — Cipher skin + gated; one minor color drift.
- **8** — Correct skin; HowToPlay reachable during FTUE.
- **7** — Correct skin; card contrast borderline.
- **6** — Card visual reused from another skin.
- **5** — System font on card.
- **4** — Board renders on wrong background.
- **3** — Chrome collides with existing UI.
- **2** — Multiple visual conflicts.
- **1** — Debug overlay look.

---

## 7. Beat advancement legibility

**10/10 means:** After the correct guess on beat 0, the coach message swaps from "NOW TAP THE LETTER" to "STUCK? TAP HINT" with an `.easeInOut(0.25)` transition. After HINT lands on beat 1, the message swaps to "KEEP CRACKING" / "TAP THE LETTER" for beat 2. No "Beat Complete!" banner. On beat 2's guess, coach retracts with `.pop` audio.

**Reference class:** Vollmer "scaffolding, not banners." Threes! silent progression. Wordle celebration lives in the win state, not per-guess.

**Concrete disqualifiers:** Any "Beat X of 3" text. Message doesn't refresh across beats. Retract without positive audio.

**Scoring:**
- **10** — Silent card swap + positive dismiss audio + no banners.
- **9** — Silent swap; audio slightly quiet.
- **8** — Silent swap; no dismiss audio.
- **7** — Card swap has a small flourish (still not a banner).
- **6** — Beat progress bar shown.
- **5** — "Beat Complete!" banner between beats.
- **4** — Coach flashes off/on between beats.
- **3** — Message doesn't update on beat change.
- **2** — Card gets replaced by a new floating card, stacking.
- **1** — Coach disappears + reappears between every beat.

---

## 8. Scaffolding and auto-cessation

**10/10 means:** Silent dismissal on beat 2 success — no "Tutorial Complete!" banner. Escalation via the shared `CoachPulse`/`CoachArrow` idle-6-s window (opacity 0.15→0.05 + scale bump, arrow bob amplification). On completion, `seenHowTo = true` persists via `GameSaveState`; re-launching Cipher never re-fires the tutorial.

**Reference class:** ONBOARDING_RUBRIC §7 lineage. Threes! silent dismissal. Alto's hidden achievement.

**Concrete disqualifiers:** Tutorial banner on final. Coach re-fires on second launch. Escalation is a louder card. Escalation < 3 s.

**Scoring:**
- **10** — Silent dismiss + shared escalation + persistent seenHowTo.
- **9** — Silent + escalation; a killed-app resume replays the tutorial.
- **8** — Silent; no escalation window at all.
- **7** — Small confirmation flourish on success.
- **6** — Escalation is a louder card.
- **5** — Coach re-fires on second launch.
- **4** — "Tutorial Complete!" banner.
- **3** — Coach nags before 3 s.
- **2** — Coach fires under 3 s (nagging).
- **1** — Coach can't be dismissed by playing correctly.

---

## 9. Skippable without shame

**10/10 means:** SKIP chip is a first-class button on every beat's coach card. One tap dismisses the whole FTUE. `store.onboardingSkipped` propagates bundle-wide. Neutral label. Wrong-guess dismissal is safely gated (existing fix from ONBOARDING_RUBRIC v4: `if locked` on the success dismiss path).

**Reference class:** ONBOARDING_RUBRIC §8, Berbece "Press A to Skip."

**Concrete disqualifiers:** SKIP absent. SKIP only skips the current beat. SKIP dismissal leaves the game in a wonky mid-tutorial state. Wrong guess triggers withSuccess:false.

**Scoring:**
- **10** — SKIP one-tap clears bundle-wide; game resumes cleanly; wrong guess doesn't false-succeed.
- **9** — One-tap clears Cipher; other games still re-fire.
- **8** — SKIP with slight visual asymmetry.
- **7** — Skip is a text link.
- **6** — Skip appears after 3 s.
- **5** — Skip requires two taps.
- **4** — Skip label mildly shaming.
- **3** — Skip only after first mechanic taught.
- **2** — No skip; auto-dismiss only.
- **1** — No skip and mid-tutorial quit loses progress.

---

## 10. No spoilers — later payoffs stay a discovery

**10/10 means:** The FTUE **doesn't preview or name** later mechanics: the mistake counter climbing, Vic's Tip's daily-availability logic, the phrase completion CRACKED overlay's clean-crack bonus, or the matchbook progression through 16 themed books. Each has its own discovery beat.

**Reference class:** ONBOARDING_RUBRIC §9 lineage. Two Dots defers square-clear. Threes! defers upper tiles to unlock-time confetti.

**Concrete disqualifiers:** Coach copy names "MISTAKES" / "CRACKED" / "MATCHBOOK". Coach shows the completion overlay preview. Coach mentions Vic's Tip's daily reset.

**Scoring:**
- **10** — Zero mentions of later payoffs.
- **9** — Zero mentions; MISTAKES counter visible in chrome corner (unavoidable).
- **8** — One incidental mention (e.g. "SCORE") that isn't taught.
- **7** — Coach copy teases the CRACKED payoff.
- **6** — Coach names the matchbook name.
- **5** — Coach shows the completion overlay directly.
- **4** — Coach shows a "You'll unlock…" hint.
- **3** — Coach mentions IAP or shop.
- **2** — Coach previews the endgame or matchbook progression.
- **1** — Full rule dump.

---

## Iteration log

| version | 1. Depth | 2. Seed | 3. Diegetic | 4. Atomic | 5. Chrome | 6. Aesthetic | 7. Advance | 8. Scaffold | 9. Skip | 10. No-spoil | avg | grade | delta diagnosis |
|---------|----------|---------|-------------|-----------|-----------|--------------|------------|-------------|---------|--------------|-----|-------|-----------------|
| v0      | 5        | 10      | 10          | 10        | 10        | 10           | —          | 10          | 10      | 10           | 9.4 | A     | Baseline before this session: single-beat tutorial (basic guess only). Depth capped at 5/10 — HINT untaught, no second reinforcement. |
| v1      | 10       | 9       | 10          | 10        | 10        | 10           | 10         | 10          | 10      | 10           | 9.9 | A+    | Three scripted beats: basic guess → HINT (with tile/keyboard pulses gated off) → second guess. `tutorialBeat` state drives everything: `coachMessage` swaps per beat; `coachTargetCipher` returns nil on beat 1 so tile pulses stand down; a new `coachHintPulseActive` overlay rings the HINT button with a matchbook arrow above. Beat 1's HINT is charge-free (tutorial hints ride on the house, so mistakes/hints score cost isn't taxed for following the coach). Simulator verified: H locks 3 tiles at beat 0, HINT reveals E at beat 1, C locks C tiles at beat 2, coach dismisses cleanly, "?" HowToPlayButton returns. Dim 2 capped at 9 because phrase isn't pinned — falls back to whatever phraseIndex the save has, but on fresh install it's always 0. |
| v2      | 10       | 10      | 10          | 10        | 10        | 10           | 10         | 10          | 10      | 10           | 10.0| A+    | Pin lift for dim 2: `start()` now calls `game.begin(index: 0)` when the tutorial fires, so the pre-reveal + beat targets are guaranteed against a killed-app resume that restored a later phrase. `tutorialBeat = 0` also reset explicitly. All 10 dims at 10; pass bar met with margin. |
|         |          |         |             |           |           |              |            |             |         |              |     |       |                 |
