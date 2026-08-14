# Zombie Onboarding Rubric — Thorough FTUE

Grades Zombie's 4-beat first-run against the state-of-the-art of merge-2048 onboarding (Threes!, 2048, Suika Game, Merge Dragons, Zoo 2048) and the atomic-teaching canon (Vollmer GDC 2014, Anthropy, Koster).

Scope: ZombieView + ZombieGame first-run — 3 merge rounds walking tier 2 → 3 → 4 (value 16), then a 4th swipe-teach beat with the `TutorialSwipeCue`, then the READY TO MIX banner (POST_TUTORIAL_REVEAL_RUBRIC).

## Pass bar

Both must hold:

- **Average ≥ 9.3** across all ten dimensions.
- **No dimension below 8.**

---

## 1. Ladder depth

**10/10 means:** 4 beats — 3 scripted merges (1+1=2 / 2+2=4 / 4+4=8→16) walking the tier ladder, plus a 4th swipe-teach beat that hands the player the drag atom independent of any specific merge. Player leaves the tutorial having (a) seen the value 16 as the "top" of the scripted ladder and (b) internalized the drag gesture in isolation.

**Reference class:** Threes! reveals higher tiles at unlock time (Vollmer). Zoo 2048's onboarding walks 2→4→8 then hands over. Stacks: 4 rounds walking 1-line → 4-line clears.

**Concrete disqualifiers:** Fewer than 4 beats. Swipe-teach beat teaches a merge instead of the drag atom in isolation. Ladder skips a tier.

**Scoring:**
- **10** — 4 beats: 3 tiered merges + 1 pure drag atom.
- **9** — 4 beats but drag beat requires a specific direction.
- **8** — 3 beats only (regression to pre-swipe-teach).
- **7** — 4 beats but one is a repeat.
- **5** — Skips a tier.
- **1** — Single-beat tutorial.

---

## 2. Seeded per-beat success

**10/10 means:** Every beat's board is deterministic. Rounds 0-2 seed a stacked pair that a DOWN swipe merges. Round 3 seeds tier-4 at (1,3) plus tier-1s at (0,0) and (3,3) — since same-tier tiles never share a row or column, no accidental merge fires during the drag lesson (the earned 16 sits alone in its column, its tier-1 neighbors sit in orthogonal rows). Any swipe direction produces a legal slide.

**Concrete disqualifiers:** Any beat has a state where a valid swipe forces a mistake. Round 3's spawned pair can accidentally merge in a swipe. Board rendered while `tutorialActive=false` on round 3 (spawn would inject random tiles).

**Scoring:**
- **10** — All 4 rounds deterministic; round 3 same-tier tiles orthogonal so no merge possible.
- **9** — All 4 deterministic; round 3 has one swipe direction that produces a "boring" no-op.
- **8** — 3 of 4 deterministic.
- **6** — Round 3 sometimes fails to dismiss.
- **1** — Rounds don't seed.

---

## 3. Diegetic minimal-text framing

**10/10 means:** Each beat's card ≤ 4 words, uses Zombie's bar/drink vocabulary. Copy is "DOUBLE THE MUGS" / "DOUBLE AGAIN" / "ONCE MORE!" / "SWIPE TO SLIDE". First three are diegetic (bar). Fourth names the atomic verb.

**Concrete disqualifiers:** Any card > 6 words. Any generic UIKit verb ("TAP", "PRESS") without diegetic object.

**Scoring:**
- **10** — All 4 cards ≤ 4 words; first 3 diegetic; fourth explicitly gestural.
- **9** — Fourth card slightly generic ("SWIPE TO SLIDE"); others diegetic.
- **8** — All ≤ 6 words; one borderline.
- **7** — One card at 7-8 words.
- **1** — Wall-of-text.

---

## 4. Per-beat atomic clarity

**10/10 means:** Beat 0 teaches merge (1+1=2). Beat 1 teaches merge repetition. Beat 2 teaches the "climb" (higher tier). Beat 3 teaches drag-anywhere (independent atom). Each beat's card + affordance point at one atom.

**Concrete disqualifiers:** Beat 3 pulses tiles (would collide with drag cue). Beat 3 requires a specific merge to advance (not a pure drag beat).

**Scoring:**
- **10** — 4 distinct atoms, no overlap.
- **9** — 4 atoms, one round has a small overlap.
- **8** — 3 atoms + a repeat.
- **1** — Full rule dump.

---

## 5. Coach chrome craft

**10/10 means:** Rounds 0-2: pulse the seeded pair with a down arrow between them + card at top. Round 3: pulses stand down (empty positions returned by `tutorialTilePositions`), the `TutorialSwipeCue` (dashed guide rail + coral pulse ring + drag-hand glyph) rides board center, the card carries the atom's verb. Card position + cue position never overlap.

**Concrete disqualifiers:** Round 3 pulses AND cue both fire. Cue occludes an active tile. Arrow between pair points wrong way on rounds 0-2.

**Scoring:**
- **10** — Rounds 0-2 pulse pair; round 3 shows cue only; no overlap.
- **9** — Correct; cue's dashed rail extends slightly off-board once at accessibility sizes.
- **8** — Correct; ambiguity in one round.
- **1** — Debug overlay look.

---

## 6. Aesthetic congruence

**10/10 means:** Uses CoachSkin.zombie throughout (dark plank card, torch pulse, swizzle arrow glyph). TutorialSwipeCue's coral pulse + gold-lit hand + dashed capsule rail read as "bar-coaster cane path" — native to the mid-century bar interior. HowToPlayButton hides while coach is up.

**Concrete disqualifiers:** Any color not in Zombie's palette. SF Symbol renders as a stock iOS glyph. HowToPlayButton visible during coach.

**Scoring:**
- **10** — Full skin fidelity; HowToPlay gated.
- **9** — Skin correct; one minor tint drift on the cue.
- **8** — Correct skin; HowToPlay reachable during round 3.
- **1** — Debug overlay look.

---

## 7. Beat advancement legibility

**10/10 means:** Rounds 0-2 advance via `handleTutorialMerge` after a 720 ms hold that lets the merge animation and drink-lore card land. Round 3 dismisses immediately on ANY successful slide (merge or not). Ready banner (POST_TUTORIAL_REVEAL_RUBRIC) fires exactly once, on beat 3 dismiss.

**Concrete disqualifiers:** Round 3 advances to a nonexistent round 4. Round 3 dismisses on a rejected swipe (nudge only, no slide). "Beat 4 of 4" banner text.

**Scoring:**
- **10** — Silent card swap + 720 ms hold on rounds 0-2 + ready banner on round 3 dismiss.
- **9** — All correct; small flourish on round 3 dismiss.
- **8** — Correct; hold slightly short.
- **1** — Coach re-fires between beats.

---

## 8. Scaffolding + auto-cessation

**10/10 means:** Silent dismissal on beat 3's swipe. Shared CoachPulse/Arrow escalation window (6 s idle). `seenHowTo = true` persists via GameSaveState — re-launching Zombie never re-fires the ladder. Ready banner fires only on withSuccess.

**Concrete disqualifiers:** Coach re-fires on second launch. Ready banner fires on SKIP. Escalation is a louder card.

**Scoring:**
- **10** — Persistent seenHowTo; ready-banner guard on withSuccess only; escalation on affordance.
- **9** — Persistence correct; one edge case (killed-app resume) re-fires.
- **1** — Coach can't be dismissed.

---

## 9. Skippable + ready-banner integration

**10/10 means:** SKIP chip is a first-class button on every beat. One tap dismisses the whole ladder AND suppresses the READY TO MIX banner (SKIP never triggers celebration). Bundle-global via `store.onboardingSkipped`. Ready banner fires ONLY on the beat-3 success path.

**Concrete disqualifiers:** SKIP triggers ready banner. Ready banner blocks board taps after fade. Round 3 SKIP leaves board in an inputtable state without the earned 16 as a gift.

**Scoring:**
- **10** — SKIP silent; ready banner on success only; game resumes cleanly.
- **9** — SKIP silent; ready banner on success; one small state leak.
- **8** — SKIP silent; ready banner on success; HowToPlay button briefly hidden after banner.
- **1** — No skip; mid-tutorial quit loses progress.

---

## 10. No spoilers

**10/10 means:** Cards never name a mechanic the tutorial doesn't reach — THE ZOMBIE (tier 11), specific drink names beyond first-mix lore, undo, or the sunrise/end-run state. Ready banner "READY TO MIX" uses a verb, not a spoiler noun.

**Concrete disqualifiers:** Card names "THE ZOMBIE" or "FLAMING VOLCANO" or "UNDO". Card previews the endgame tile.

**Scoring:**
- **10** — Zero mentions of later payoffs.
- **9** — Zero mentions; the SCORE chip visible in chrome corner (unavoidable).
- **8** — One incidental "SCORE" mention.
- **1** — Full ladder shown.

---

## Iteration log

| version | 1. Depth | 2. Seed | 3. Diegetic | 4. Atomic | 5. Chrome | 6. Aesthetic | 7. Advance | 8. Scaffold | 9. Skip | 10. No-spoil | avg | grade | delta diagnosis |
|---------|----------|---------|-------------|-----------|-----------|--------------|------------|-------------|---------|--------------|-----|-------|-----------------|
| v0      | 8        | 10      | 10          | 10        | 10        | 10           | 10         | 10          | 10      | 10           | 9.8 | A+    | Baseline before this session's swipe-teach beat: 3 scripted merge rounds only. Player didn't know they could drag anywhere on the board after the tutorial. Ladder depth capped at 8/10. |
| v1      | 10       | 10      | 8           | 10        | 8         | 7            | 10         | 10          | 10      | 10           | 9.3 | A     | Added round 3 (swipe-teach) + TutorialSwipeCue. Multi-lens adversarial workflow (5 reviewers → 6 confirmed defects) found: card copy "SWIPE TO SLIDE" imports the UI-verb anti-pattern the shared rubric §3 explicitly flags (dim 3 → 8); SF Symbol `hand.point.up.left.fill` rotated -90° reads as an iOS onboarding sticker not a Zombie glyph AND is a pointer not a drag indicator (dim 6 → 7); cue drifts horizontally only though any direction dismisses (dim 5 → 8); no accessibilityHidden on the cue root so VoiceOver double-announces the hand icon on top of the card (dim 5 → 8). Passes only by the barest margin — all 6 findings marked confirmed by adversarial verify. |
| v2      | 10       | 10      | 10          | 10        | 9         | 10           | 10         | 10          | 10      | 10           | 9.9 | A+    | Applied every confirmed defect fix: (1) card copy → "SLIDE THE MUGS" mirroring R0's "DOUBLE THE MUGS" cadence — verb + THE + bar noun, no UI-gesture verb (dim 3 → 10); (2) custom SwizzleDrag SwiftUI glyph replaces the SF Symbol — driftwood grip Circle + torch Capsule shaft + rum-red garnish Circle + 3 trailing motion streaks, ink-shadow radius 2 matching SwizzleArrow, no SF Symbol imports, no rotation (dim 6 → 10); (3) cross-shaped guide rail (H + V dashed capsules) + `horizontalPhase` state that alternates the drift axis every full 2.8 s round-trip so the swizzle traces both cardinals (dim 5 → 9, still dashes remain a minor point vs solid ink); (4) `.accessibilityHidden(true)` + `.allowsHitTesting(false)` on TutorialSwipeCue root ZStack so VoiceOver announces only CoachCard and every future adopter gets the safe touch default (dim 5 → 10). Simulator verified: horizontal swizzle at t=2.5s, vertical swizzle at t=4.0s — axis alternation confirmed. |
|         |          |         |             |           |           |              |            |             |         |              |     |       |                 |
