# Cipher 2.0 (WoF model) — Game Experience Rubric (v1, LOCKED 2026-07-31)

Grades the SHIPPED EXPERIENCE of the rebuilt Cabana Cipher (hangman input,
300-phrase catalog, categories), not the phrase content — content has its own
gate (`CIPHER_PHRASE_RUBRIC.md`, all 300 phrases A).

Pass bar (Carson's ask: **A+**): **average ≥ 9.3 AND no dimension below 8.**
Evidence-only scoring: every score cites a screenshot, code line, or test run.
Reference class: Wordle's keyboard-state language, Wheel of Fortune's board,
Two Dots' first-session teach, and the other five Tiki Lounge games' house
motion idioms.

## Dimensions (0–10 each)

### 1. INPUT CLARITY
10 = a first-time player understands "tap letters, they fill in" within one
glance; every keyboard state (live / ghosted-solved / struck-miss / spotlit)
is distinguishable at arm's length; nothing non-interactive looks tappable;
no dead taps. The pivot's entire purpose lands here.

### 2. RECOGNITION LOOP
10 = the category strip + house pour give immediate traction; partial reveals
produce the "of course!" completion moment; the symbol layer visibly aids
(same symbol = same letter reads); no recognition stalls in normal play.

### 3. FTUE
10 = coach teaches the full mechanic in ≤2 beats and ≤15 seconds; the taught
tap is unmissable (spotlight); SKIP is present and silent; the how-to panel
teaches the changed rules only, in ≤4 rules; nothing references the old
cursor model anywhere.

### 4. JUICE & MOTION
10 = the cascade flip is the hero moment and reads as one wave; misses have
weight (shake + strike + haptic + SFX); CRACKED / defeat / LAST CALL land
with house-idiom timing; Reduce Motion respected; no animation fights.

### 5. VISUAL COMPOSITION
10 = chrome is overlap-free in every state (coach, panels, ceremony, restore);
the strike-strip sits naturally with the board; keyboard rows balanced;
palette/typography match the app; the 50-cover wall composes cleanly.

### 6. FAIRNESS & ECONOMY
10 = a player who knows the saying rarely dies; misses always feel earned
(the letter genuinely wasn't there); the life spend is legible; scoring and
CLEAN STRIKE are comprehensible; vocabulary is consistent (MISSES everywhere).

### 7. INTEGRITY
10 = saves round-trip completely (board, misses, counters); pre-hangman and
content-drift saves migrate safely; boards are deterministic (golden-pinned);
full suite green; shared systems (lives, wallet, milestones, leaderboard)
unregressed.

## Protocol

Differentiated judge panel grades all 7 dimensions from evidence (screenshots,
code, test output) with findings in blocker/major/minor/nit vocabulary;
findings dedup by (location, normalized title) keeping max severity; every
non-nit goes to an adversarial verifier (REFUTE-default); a completeness
critic hunts gaps in the confirmed list. Fixes track to zero, then re-judge
hunting regressions. Stop early only when remaining points require evidence
the loop cannot generate (device-feel, Carson-only taste calls) — say so and
hand those items over.

## Iteration log

| round | per-dimension (IC RL FT JM VC FE IN) | avg | grade | delta diagnosis |
|-------|--------------------------------------|-----|-------|-----------------|
| 1 | 8 · 8.5 · 8.5 · 8 · 7.5 · 8.25 · 8.75 | 8.21 | B+ | 6-judge panel + 8/8 findings adversarially CONFIRMED (0 refuted): beat-0 pulses 3 inert tiles, struck key invisible (Δ4 lum), chevron/header overlap every state, symbol twin pairs co-occur, pre-pivot players get no re-teach, ANATOMY doc teaches dead cursor, CRACKED pre-empts hero cascade, chevron/subtitle. Critic: coach-shield misses detonate on dismissal; Reduce Motion ungated; how-to/CLEAN STRIKE states unevidenced. Promoted from dropped queue: solvedCount restore unclamped (overflow trap). |
| 2 | post-R1 build | 6 judges → 44 deduped (26 non-nit), top 8 verified: 8 CONFIRMED, 0 refuted — translucent struck/ghost keys let props wash the burn (R1-fix regression, 3 findings), coach has no completion path on solve (shield rides into phrase 2+, defeats impossible), CLEAN STRIKE +15 in invisible currency, defeat forks the MISSES vocabulary, post-win dead-tap window. ALL FIXED same round + 12-nit sweep (opaque key bases, coach graduates on solve, unnumbered CLEAN STRIKE badge, OUT OF MISSES, board dims post-solve, cancellable fanfare, Vic-tip coach guard, ceremony scroll fade, cover-title fit, VoiceOver key states, figure hygiene). Scores 8.75 · 9 · 8.875 · 8.625 · 8.5 · 8.5 · 9.125 | 8.77 | A− | floor met (min 8.5); bar (9.3) not yet — R3 re-judge scheduled after the subagent limit reset |
| 3 | post-R2 build | **INVALID GRADE — NOT A PASS.** 8 of 10 panel agents died on usage credits (4 of 6 judges, all 3 adversarial verifiers, the completeness critic). The 2 judges that completed scored IC 9.5 · RL 9.5 · FT 9.25 · JM 9.5 · VC 9.5 · FE 9 · IN 9.625 (avg 9.41) but a 2-judge median with zero verification is not the protocol this rubric specifies, and unverified findings cannot be scored. Their 6 findings were fixed anyway (Vic's-tip guard-ordering BUG — the day-stamp preceded the completion guard so a post-solve tap burned the freebie; tip now recedes + stops hit-testing for the whole coach; silent graduation via dismissCoach(playSound:); livesCap in the defeat a11y label). | — | n/a | Re-run the FULL 6-judge + verify + critic panel when credits reset; only that result can close the loop. |
