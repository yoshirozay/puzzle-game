# Blueprints Onboarding Rubric — Thorough FTUE (v2)

Grades Blueprints' first-run scripted beats against the state-of-the-art of nonogram/picross onboarding (Picross S, Nonograms Katana, Nonogram.com's "Learn to Play", Cross Logic) and the atomic-teaching canon (Vollmer GDC 2014, Anthropy *Level Design Lessons*, Koster's atomic theory).

Scope: the BlueprintsView + BlueprintsGame first-run — the scripted Tiki Mug (5×5) tutorial, the auto-mode-flip, the clue spotlight, and the shared FirstRunCoach chrome. Does not grade the picker, catalog, or the DRAFT/SKETCH rules toggle.

**Why v2.** The v1 rubric graded input-atom teaching (FILL → MARK → FILL) and scored a 10.0 — yet a real first-run player (Carson, 2026-07-19) finished it unable to read a clue column ("the column that says 121"). v1's dimensions actively enforced the failure: a ≤4-word card cap (no room for a reason clause), a hidden HowToPlay button during the coach (the only clue explanation unreachable on the natural path), and no dimension anywhere asking whether the player can read the numbers — which are the game. v2 regrades around **deduction taught, not input taught**. The v1 iteration log is retired below; its scores are not comparable.

## Pass bar

Both must hold:

- **Average ≥ 9.3** across all ten dimensions.
- **No dimension below 8.**

Nonogram FTUEs are especially prone to failing dim 1 (teaching taps instead of clue-reading), dim 2 (a mark the player must take on faith), and dim 6 (stacked column digits reading as one number). Both bars matter.

---

## 1. Deduction ladder depth

**10/10 means:** The script walks **four deduction atoms**, in order:
(a) **READ** — a clue number names how many cells fill in its line, proven on a full-line clue (row says 5, board is 5 wide → the whole row fills);
(b) **EARN A MARK** — a satisfied clue proves its leftover cells empty; the cross records that conclusion;
(c) **CASH IT IN** — a stacked multi-run clue (col 1's `3 1`) resolved using earlier fills and the gap rule — the cross-axis payoff that IS nonogram play;
(d) **GENERALIZE** — a **three-run clue played out interactively** (row 3's `1 1 1`: single, gap, single, gap, single) so the n-number case is *experienced*, never left to panel text or solo inference. (v3 requirement — Carson 2026-07-19: "people don't like to read, they want to play and experience." The `1 1 1` line is fully forced by its clue on a 5-wide board, so this is also the script's only phase derivable with zero position assertion.)
BRUSH and MARK are taught *in service of* these atoms, never as bare functionality.

**Reference class:** Nonogram.com's "Learn to Play" teaches row logic before free play; Picross S and Katana both stage line-satisfaction before releasing the player; Koster: the atom is the deduction loop, not the tap.

**Concrete disqualifiers:** Any beat commanding an action with no reason stated or visible (v1's "NOW MARK EMPTY" at a cell whose emptiness nothing on screen justified). MARK taught as a gesture rather than a recorded conclusion. No stacked-clue beat. No multi-run clue beyond two numbers ever played under the coach (the v2 gap: `1/2/1`-class clues were decoded only by generalization).

**Scoring:**
- **10** — All four atoms, in READ → EARN → CASH → GENERALIZE order, each landed on the Tiki Mug's own material.
- **9** — All four atoms; ordering deviates (e.g. GENERALIZE before CASH).
- **8** — Three atoms (v2's script: 2-run stack taught, 3-run left to the runway).
- **7** — READ + EARN only (no stacked-clue payoff).
- **6** — READ only, plus input verbs.
- **5** — v1's input-only ladder (FILL → MARK → FILL, no clue ever referenced).
- **4** — Fewer than 3 beats.
- **3** — Beats out of order.
- **2** — Beats contradict each other.
- **1** — No scripted beats.

---

## 2. Seeded success & honest derivation

**10/10 means:** Every fill-beat target is true and every cross-beat target is false in the Tiki Mug truth table — first-tap success is 100% per beat, with the mode auto-flipped so the pulsed cell is always inputtable in one tap. Additionally every **mark** beat's emptiness is *forced by information already on the board when it fires* (a visibly satisfied run's leftovers, or the mandatory gap between runs) — marks are never take-it-on-faith. Fill *positions* may be coach-asserted (the pulse says where), but the fill *count* must match the clue the card names. Beats whose target is already in the required state auto-skip, so no beat can strand on a committed cell.

**Reference class:** Threes!' scripted 4×4 forcing 1+2=3 (Vollmer). `BlueprintsGame.tutorialBeats` is the deterministic seed.

**Concrete disqualifiers:** A cross beat whose emptiness isn't derivable from the current grid. A beat that can strand because its target is already filled/crossed (drag-ahead, resume, or stray-mistake paths). Mode toggle hunt mid-script.

**Scoring:**
- **10** — All targets provably right; all marks derivation-honest; auto-flip; satisfied-beats auto-skip on every path (drag-ahead, resume, mistake).
- **9** — All correct + honest; one exotic path (e.g. resume mid-phase) re-shows an already-satisfied beat for one frame.
- **8** — All correct; one mark is asserted rather than derived.
- **7** — All correct; two marks asserted.
- **6** — A drag direction or resume can strand a beat (soft-lock).
- **5** — Fill count doesn't match the named clue.
- **4** — Player can trigger a mistake on the pulsed cell.
- **3** — Target isn't fixed across runs.
- **2** — Coach pulses an already-committed cell as the live target.
- **1** — Coach never has a valid target.

---

## 3. Reasoned cards

**10/10 means:** Every card names the clue value it acts on and carries a reason clause — number, then consequence ("ROW SAYS 5 — DRAG ACROSS ALL FIVE"; "THE 3 IS DONE — CROSS OFF THE REST"). Cards stay ≤ 9 words, diegetic (SAYS / RUN / GAP / CROSS — the game's own vocabulary), distinct per phase. **The v1 ≤4-word cap is retired for this game**: Blueprints is a logic game; a card that cannot state a reason teaches ritual, not play (Carson, 2026-07-19). Action games (Totem, Top Shelf) keep their terse caps — this dimension is Blueprints-specific.

**Reference class:** Nonogram.com's teaching cards ("The numbers show how many squares to fill") — reasons, not commands. Vollmer: the card is scaffolding for a hypothesis the player then tests.

**Concrete disqualifiers:** A bare imperative with no reason on a beat that acts on a clue. A card that references no number while its beat exists because of one. Any card > 12 words. Two phases sharing exact copy.

**Scoring:**
- **10** — Every card = number + reason clause, ≤ 9 words, distinct, diegetic.
- **9** — All reasoned; one card leans generic.
- **8** — One card is a bare imperative.
- **7** — Two cards bare; numbers still named somewhere.
- **6** — Reasons present but a card exceeds 12 words (wall-of-text drift).
- **5** — Cards name numbers the beats don't act on.
- **4** — Two phases share identical copy.
- **3** — No card names any number.
- **2** — All beats share one card.
- **1** — Wall-of-text card.

---

## 4. One concept per phase

**10/10 means:** The beats group into phases, each teaching exactly one concept — READ THE ROW (fills), CROSS THE LEFTOVERS (marks), STACKED CLUE (fill–gap–fill). Card copy changes only at phase boundaries; within a phase the pulse walks cell-to-cell under one unchanged card. The mode auto-flips at every beat so BRUSH/MARK never need the toggle. No new concept rides along (no hints, no undo, no scoring).

**Reference class:** Anthropy — "one mechanic per screen." Two Dots defers the square-clear.

**Concrete disqualifiers:** Two new concepts inside one card. Mode toggle visible-and-required mid-script. A phase whose beats mix fill and cross without the card explaining the transition.

**Scoring:**
- **10** — Clean phase grouping, one concept each, copy changes only at boundaries, auto-flip throughout.
- **9** — Clean grouping; one boundary's copy change lags a beat.
- **8** — One phase teaches a mildly compound concept (fill + its leftover marks under one card).
- **7** — Concepts clean but phases not visually distinguishable.
- **6** — Two concepts in one phase.
- **5** — Any beat teaches two atoms at once.
- **4** — Beats out of order vs. the ladder.
- **3** — Hint/undo/score mentioned mid-script.
- **2** — Scoring formula mentioned.
- **1** — Full rule dump.

---

## 5. Clue spotlight binding

**10/10 means:** The clue label the current phase reasons about is itself spotlit — torch color + pulse, phase-locked to the coach cadence (~1.67 Hz half-cycle 0.3 s), moving only at phase boundaries. Card, spotlit clue, arrow, and cell pulse form one visual sentence: the card names "5", the row's 5 glows, the arrow points at the cell that satisfies it. Reduce Motion → static highlight (color + fixed scale), no pulse. Satisfied-dim never fights the spotlight (spotlight wins while active).

**Reference class:** Picross S highlights the active line's clue during its tutorial; Monument Valley's glow ring. ONBOARDING_RUBRIC §5 (one pulse, one sentence).

**Concrete disqualifiers:** A card that names a number nowhere highlighted. Two clue labels lit simultaneously. Spotlight on the wrong line. Spotlight persists after the coach dismisses.

**Scoring:**
- **10** — Right clue lit every phase, phase-locked pulse, Reduce Motion static, dim never fights it, clean removal on dismiss.
- **9** — Right clue lit; pulse cadence drifts from the cell pulse.
- **8** — Right clue lit; satisfied-dim briefly overrides mid-phase.
- **7** — Spotlight is color-only (no motion) with motion available.
- **6** — One phase's clue unlit.
- **5** — Wrong clue lit for one phase.
- **4** — Two clues lit at once.
- **3** — Spotlight survives dismiss.
- **2** — Spotlight on a non-clue element.
- **1** — No clue ever highlighted.

---

## 6. Stacked-clue legibility

**10/10 means:** Column clue digits are separated by a measurable gap — **≥ 8% of cell height** between stacked numbers — so `1/2/1` can never read as "121" (the literal reported failure, Night Torch col 4). Row clue strings keep their single-space separator (horizontal glyph gaps already read as separate numbers; the reported ambiguity is vertical) and every shipped row's clue string fits `clueW` without truncation — the width ceiling is Sunset's `1 1 1 1 1`. The satisfied-dim (0.32) and clue font (0.38 × cell) are preserved. Every shipped puzzle's clue stack (max 4 runs — Totem cols 4/5 stack `1 3 1 2`; widest single clue "10") fits its reserved band without clipping or collision at all three board sizes.

**Reference class:** Print nonogram convention (Conceptis, Nikoli) separates stacked clues by ~half a digit height; Picross S separates by a full grid-cell padding.

**Concrete disqualifiers:** Adjacent stacked digits with < 2 pt of air. Any shipped puzzle whose clue stack overflows its band or clue string overflows `clueW`. A separator glyph that reads as a clue (dots/dashes that could be runs).

**Scoring:**
- **10** — ≥8% cell-height gaps, all 30 puzzles' stacks and row strings fit at all sizes, no new glyphs.
- **9** — Gaps ≥8% but one 10×10 stack sits tight against the band edge.
- **8** — Gaps ~5–8% (visibly separate, below print convention).
- **7** — Gaps ≥8% on the tutorial size only; larger boards below 5%.
- **6** — Gaps only on the tutorial puzzle.
- **5** — v1 spacing (1 pt) anywhere.
- **4** — A stack clips its band.
- **3** — Digits collide at 10×10.
- **2** — Separator glyphs introduced that read as clues.
- **1** — Clues visually merge into multi-digit numbers.

---

## 7. Chrome craft & aesthetic congruence

**10/10 means:** `CoachSkin.blueprints` throughout — deep-leaf card, blossom hairline, blossom cell pulse, chalk-leader arrow — on `BlueprintsBackgroundView`'s night scenery. ONE **primary** pulse per beat (the act-here cell), plus quiet static group rings on every remaining cell of the current phase so the run's full shape reads at a glance — "5" is five circled squares, not a mystery walk (v4, owner call 2026-07-19). Group rings are visually subordinate (smaller, hairline, no animation), vanish as their cells commit, and never appear outside the current card's phase. Card at `.top(122)` never occludes the grid, the target cell, or the spotlit clue. The mode toggle stays hidden while `coachActive` (auto-flip owns it). **HowToPlayButton stays reachable during the coach** — v1 hid it, leaving the full rules unreachable exactly when a confused first-runner needs them; opening it must pause nothing and break nothing (coach resumes on dismiss).

**Reference class:** ONBOARDING_RUBRIC §5–6. Vollmer "safe space" — help must be reachable from inside the scaffold.

**Concrete disqualifiers:** Any foreign skin element. System font. Card occluding the spotlit clue or target column. Help unreachable during the script. Opening help derailing the script state. Two PRIMARY pulses at once, or group rings animating loudly enough to compete with the act-here pulse. A group ring lingering on a committed cell or bleeding into another phase.

**Scoring:**
- **10** — Blueprints skin + night scenery + one primary pulse with phase group rings + no occlusion + help reachable and script-safe.
- **9** — All correct; help button contrast borderline over the scenery.
- **8** — All correct; help hidden during coach (v1 rule) — reachable only after.
- **7** — Card occludes a non-referenced clue on one beat.
- **6** — Card visual reused from another skin.
- **5** — System font on card.
- **4** — Board renders on wrong background.
- **3** — Card occludes the spotlit clue.
- **2** — Multiple visual conflicts.
- **1** — Debug overlay look.

---

## 8. Advancement legibility

**10/10 means:** Within a phase the pulse walks cell-to-cell on each success; at phase boundaries the card swaps with `.easeInOut(0.25)` and the clue spotlight moves. A drag along a scripted line consumes its beats fluidly — in either drag direction (satisfied-skip absorbs out-of-order paint). No "beat X of N" text. On the final beat the coach retracts into the shared `TutorialReadyBanner` ("READY TO DRAFT", per POST_TUTORIAL_REVEAL_RUBRIC) with the skin's dismiss audio.

**Reference class:** Zombie's `handleTutorialMerge`; Vollmer "scaffolding, not banners" (the terminal banner is the sanctioned reveal moment, not a mid-script beat banner).

**Concrete disqualifiers:** Any beat counter. A drag direction that visibly stalls the script. Message failing to update at a phase boundary. Mid-script banners.

**Scoring:**
- **10** — Pulse walk + boundary swaps + direction-agnostic drags + terminal banner + audio.
- **9** — All correct; one boundary swap animates late.
- **8** — Correct; no dismiss audio.
- **7** — Reverse drag briefly shows a stale pulse before skip catches up.
- **6** — Beat progress indicator shown.
- **5** — Mid-script "phase complete" banner.
- **4** — Coach flashes off/on between beats.
- **3** — Message doesn't update across phases.
- **2** — Cards stack instead of swapping.
- **1** — Coach reappears between every beat.

---

## 9. Scaffolding, cessation & skip

**10/10 means:** Idle-6-s escalation via shared `CoachPulse`/`CoachArrow`. `seenHowTo` persists; the ladder never re-fires after success or skip. A killed app mid-script resumes at the **first unsatisfied beat** (no replay from zero, no strand). SKIP is a first-class chip on every beat; one tap clears bundle-wide (`store.onboardingSkipped`), silently (no banner). Off-target taps commit as real play but never advance or false-dismiss; a stray mistake auto-crosses and the script skips any beat it satisfied.

**Reference class:** ONBOARDING_RUBRIC §7–8; Threes! silent dismissal; Berbece "Press A to Skip."

**Concrete disqualifiers:** Resume replaying satisfied beats or stranding. Skip absent from any beat. A mistake putting the script and grid out of sync.

**Scoring:**
- **10** — Escalation + persistent cessation + first-unsatisfied resume + one-tap bundle-wide skip + mistake-proof script.
- **9** — All correct; resume recomputes with a one-frame pulse jump.
- **8** — All correct; no escalation window.
- **7** — Resume replays the current phase's card (state intact).
- **6** — Mistake mid-script desyncs pulse for one beat.
- **5** — Coach re-fires on second launch.
- **4** — Skip only skips a beat.
- **3** — Coach nags before 3 s.
- **2** — No skip; auto-dismiss only.
- **1** — Coach can't be dismissed by playing correctly.

---

## 10. Solo runway & no spoilers

**10/10 means:** The script leaves the Tiki Mug **unfinished with ≥ 6 true cells remaining**, and every remaining line resolves using ONLY taught atoms — the full-line clue reapplied (row 1's `5`, col 2's `5`), finish-the-run with cross-line info (cols 0/4 after row 1), and the stacked pattern mirrored (col 3 repeats col 1's `3 1`) — no overlap counting or advanced technique. First solo solve is the player's own. The coach never names DRAFT rules, the DRAFTED! overlay, colorization, picker sizes, or the first-solve bonus. (v3 amendment: floor lowered 8 → 6 — the owner traded two runway cells to teach the three-run clue interactively (dim 1d); the runway must still exercise READ, a stacked mirror, and one cross-line finish.)

**Reference class:** ONBOARDING_RUBRIC §9; Two Dots defers square-clear; Threes! defers upper tiles. Katana's tutorial similarly releases the player mid-puzzle.

**Concrete disqualifiers:** Script completes the puzzle (steals the reveal). Any remaining line requiring an untaught technique. Coach copy naming a deferred payoff.

**Scoring:**
- **10** — ≥6 cells of runway, all remaining lines taught-atoms-only, zero spoilers.
- **9** — Runway correct; one remaining line is easier via an untaught shortcut (taught path still exists).
- **8** — Runway < 6 cells but > 0; no spoilers.
- **7** — One remaining line genuinely needs an untaught technique.
- **6** — Coach names the DRAFT mode.
- **5** — Coach shows the completion overlay.
- **4** — "You'll unlock…" hint.
- **3** — Shop/IAP mentioned.
- **2** — Colorization previewed.
- **1** — Script finishes the puzzle.

---

## Iteration log

| version | 1. Ladder | 2. Seed | 3. Cards | 4. Atomic | 5. Spotlight | 6. Legibility | 7. Chrome | 8. Advance | 9. Scaffold | 10. Runway | avg | grade | delta diagnosis |
|---------|-----------|---------|----------|-----------|--------------|---------------|-----------|------------|-------------|------------|-----|-------|-----------------|
| v5      | 10        | 9       | 10       | 9         | 10           | 10            | 8         | 10         | 9           | 10         | 9.5 | A     | MARK press taught (Carson: "make the user hit MARK to cross off the rest first… have Mark by itself at the bottom"): first cross phase PARKS — card swaps to "THE 3 IS DONE — HIT MARK BELOW", both leftover cells wear group rings with no act-here pulse, and a solo coached MARK button (CoachCapsulePulse, view-local capsule twin of the circle-only shared CoachPulse) sits in the empty toggle slot. Pressing it flips the mode, unparks the crosses, and graduates the bottom to the FULL toggle for the rest of the script — auto-selection animates (BRUSH gold on fills, MARK on crosses) so the tool concept stays visible instead of silently flipping. introduceMark() resyncs via firstPendingBeat (stray mistake-crosses during the park can't strand), resume inside beats 8-9 re-asks for the press, resume past them derives markIntroduced. Autoplay hook presses the button when parked. Sim-verified: park frame, post-press frame (toggle visible, BRUSH selected in phase C), clean handoff MISTAKES 0. Installed on iPhone 17. Grades hold — the press is coached (pulsed button + card), not a hunt, so dim 2's no-hunt rule stands. |
| v4      | 10        | 9       | 10       | 9         | 10           | 10            | 8         | 10         | 9           | 10         | 9.5 | A     | Phase group rings (Carson's device feedback: "lets get a circle on all 5 of the squares… we should have the three circles showing which squares to pick"): every remaining cell of the live card's phase wears a quiet static hairline ring (CoachGroupRing, 0.8-cell, blossom 0.5, view-local — FirstRunCoach untouched, it's the other session's file) while the primary CoachPulse + arrow keep the act-here role; rings vanish per-cell as they commit (beat-index identity, opacity transition). beatSatisfied() extracted and shared with firstPendingBeat. Dim 7 redefined pre-change: one PRIMARY pulse + subordinate group rings; disqualifiers now target dual primaries and lingering/cross-phase rings. Sim-verified: phase A shows all five circles under "ROW SAYS 5", phase B shows the run-of-three group with the first cell already committed and its ring gone. Grades unchanged — dim 7 still 8 on the pre-existing SKIP/nav-button stack + arrow-grazes-column-clues (visible again over the col-2 "5" in the phase-B capture). Installed on Carson's iPhone 17. |
| v3      | 10        | 9       | 10       | 9         | 10           | 10            | 8         | 10         | 9           | 10         | 9.5 | A     | GENERALIZE phase added on Carson's call ("people don't like to read, they want to play"): 4 new beats play out row 3's `1 1 1` — fill, (col-1's gap cross already in place), fill, cross the gap, fill — under one card "1 1 1 — THREE SINGLES, A GAP BETWEEN EACH". Fully forced by the clue alone (unique arrangement on 5 wide), so the script's strongest-honesty phase. Rubric amended pre-build (new loop): dim 1 now REQUIRES a played three-run clue (v2's script would score 8 here); dim 10 floor 8→6 (the traded cells; runway keeps READ reapplication, the col-3 `3 1` mirror, and a cross-line finish — line-solver test still pins it). 17 beats, 7 cards, fillBeat 13; 44/44 tests; sim-verified (spotlit `1 1 1` rail, mid-slide pulse across the gap cross, clean banner + handoff at MISTAKES 0). Same 9.5 headline as v2 but under the stricter dim 1 — the ladder is now complete through the n-run case. |
| v2      | 10        | 9       | 10       | 9         | 10           | 10            | 8         | 10         | 9           | 10         | 9.5 | A     | 13-beat deduction script (READ row-2's 5 → run of 3 → EARN marks → CASH col-1's stacked `3 1`), reasoned cards ≤8 words, clue spotlight, 0.1-cell stacked-digit air, clueH 2.1→2.4 cells for Totem's 4-stack, help reachable mid-coach, firstPendingBeat flow-around. Evidence: 44/44 engine tests (marks proven forced when they fire; remainder proven single-line-solvable; geometry ceilings pinned), 8 sim screenshots (phases, banner, handoff, Totem/Sunset worst cases), adversarial review (2 majors found → fixed: completion-during-coach now retires the coach; tutorial pins sketch rules incl. draft-resume re-rail; minor fixed: "?"-close mid-coach no longer persists seenHowTo). Deductions — dim 2 (9): two accepted drag warts, off-target drift after a mid-drag mode flip can cost a counted mistake, and a reverse cross-sweep can erase the beat-8 mark unnoticed. Dim 4 (9): phase C narrates one concept across three cards — right pedagogy, letter of the dimension says boundaries only. Dim 7 (8): SKIP chip stacks over the corner nav button (pre-existing, shipped in v1) and the coach arrow grazes the column-clue digits on row-0 beats. Dim 9 (9): the completion-during-coach retire path is code-traced but not sim-reproduced (needs scripted disobedient play). Pass bar met (avg 9.5 ≥ 9.3, floor 8). Pre-grading rubric amendments logged: dim 6 rows keep single-space (Sunset width ceiling), stack ceiling corrected 3→4 runs (Totem). |

### Retired v1 log (input-atom rubric — scores not comparable)

| version | 1. Depth | 2. Seed | 3. Diegetic | 4. Atomic | 5. Chrome | 6. Aesthetic | 7. Advance | 8. Scaffold | 9. Skip | 10. No-spoil | avg | grade | delta diagnosis |
|---------|----------|---------|-------------|-----------|-----------|--------------|------------|-------------|---------|--------------|-----|-------|-----------------|
| v0      | 5        | 10      | 10          | 10        | 10        | 10           | —          | 10          | 10      | 10           | 9.4 | A     | Baseline: single-beat "FILL THIS CELL" on (2,2). Depth capped at 5/10 — MARK atom untaught, no reinforcement beat. |
| v1      | 10       | 10      | 10          | 10        | 10        | 10           | 10         | 10          | 10      | 10           | 10.0| A+    | Three scripted beats: FILL (2,2) → MARK (0,0) → FILL (2,0). Graded A+ under this rubric — then failed with a real player (couldn't read clues after finishing). The rubric measured input teaching, not deduction; retired 2026-07-19. |
