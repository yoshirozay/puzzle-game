# PROGRESSION RUBRIC

Grades the depth-state progression system (PROGRESSION_PLAN.md Phase 1) per game,
per iteration. **Pass bar: avg ≥ 9.3 AND no dimension < 8.** Grade honestly against
staged simulator screenshots + code reading — never from intent.

## Dimensions

### 1. Glanceability
Mid-run, eyes on the scene only: can you name how deep this run is?
- **10** — Every state is identifiable from a single screenshot by someone who has
  read only the state names; transitions read within 4 s without being watched for.
- **8** — All states distinct, but two adjacent states need a side-by-side to tell apart.
- **5** — Only the deepest state is obviously different; middle states blur together.
- **1** — You need the score number to know the depth.

### 2. Breath fidelity
The 90-second ambient breath survives every state; depth 0 is the shipped scene.
- **10** — depth == 0 is bit-for-bit today's scene; every deeper state still visibly
  breathes (≥ 0.3 amplitude); reduceMotion behavior unchanged.
- **8** — depth 0 identical; deepest state's breath is faint but present.
- **5** — depth 0 subtly differs from shipped scene (violates the acceptance bar).
- **1** — any state renders static.

### 3. Mechanical honesty
Visual states are welded to real rules (principle 2), player-favorable and bounded.
- **10** — The game's Phase-1 twist is live, fires exactly at its named state, has
  diegetic copy, cannot fire outside it (incl. tutorial guards), and is additive-only.
- **8** — Twist live and correct but copy is system-speak, or an edge guard is untested.
- **5** — Twist implemented but decoupled from the visual state (fires at wrong depth).
- **1** — States are pure wallpaper (no twist landed in this game's Phase 1 scope).

### 4. Earned-ness
Persistent marks trace to demonstrated play; retro-credit correct.
- **10** — Every persistent mark (lanterns, bottles, pennants, constellations, tints)
  derives from recorded state; milestone bits fire once, +75 mint exactly once;
  veterans retro-credited; nothing free, nothing sold.
- **8** — Marks correct but one derivation uses a proxy with a documented gap.
- **5** — A mark can appear without the play that earns it (or double-pays).
- **1** — Marks granted unconditionally.

### 5. Pacing
- **10** — Median run reaches state 1; a good run reaches state 2; milestone mints
  arrive ≤ 1 per run typically; no drought > ~3 sessions early on.
- **8** — One threshold clearly too near/far but the ladder shape holds.
- **5** — Most runs end in state 0, or routine runs shower 2+ milestones.
- **1** — Ladder unreachable or trivially exhausted in one session.

### 6. Economy horizon
- **10** — After any purchase there is an affordable next want (< 2 sessions) and a
  flagship want (> 2 weeks); mints+bonuses < 25% of lifetime earnings; ceiling ≥ 4×.
- **8** — Horizon holds but one price point is visibly out of curve.
- **5** — Dead zone: nothing affordable within 2 sessions at normal earn rates.
- **1** — Ceiling unchanged (points still go inert at 2,830).

### 7. Tone
- **10** — Every name/copy line is diegetic (Vic's voice); nothing reads as a meter
  wearing a tiki shirt; palettes stay inside the flat mid-century world.
- **8** — One label drifts into system-speak.
- **5** — HUD-style progress UI appears in-scene.
- **1** — XP bars.

### 8. Ethical cleanliness
- **10** — Nothing punishes absence; no decay/timers/streak loss; nerfs ship in the
  same build as their paired bonuses; nothing earned is ever sold.
- **8** — Clean, but one pairing's sequencing is unverified.
- **5** — A nerf shipped before its paired bonus.
- **1** — Absence-punishing mechanic present.

### 9. Regression safety
- **10** — Build green, zero warnings; previews compile; depth-0 screenshot matches
  pre-change capture; SwiftData upgrade-in-place verified; engine changes covered by
  the staging hooks; tutorial guards verified.
- **8** — Green but one verification is code-read-only (not run).
- **5** — Builds, but a preview or staging hook broke.
- **1** — Build red or migration untested.

## Iteration log

| version | scope | 1 Glance | 2 Breath | 3 Mech | 4 Earned | 5 Pacing | 6 Economy | 7 Tone | 8 Ethics | 9 Regress | avg | grade | delta diagnosis |
|---------|-------|----------|----------|--------|----------|----------|-----------|--------|----------|-----------|-----|-------|-----------------|
| v1      | plumbing (items 1–5) | — | 10 | — | 10 | — | — | — | 10 | 8 | — | — | ProgressPhase + DepthDial in all 5 scenes; depth-0 algebraic identity (lerp variant, deliberate deviation from plan's 0.3-fixed blend); milestoneMask + grant + retro-credit verified idempotent per-bit on sim with real legacy save; build green zero warnings. Regress 9 capped at 8: upgrade-in-place tested against local store, not the shipped TestFlight artifact. Dims 1/3/5/6/7 ungradeable until per-game passes land. |
| v2      | + Stacks (item 6) | 9 | 9 | 8 | 9 | 8 | — | 9 | 10 | 8 | 8.75 | B+ | Lagoon ladder verified from screenshots (main-session grade of ladder-strip.png + baseline-preedit.png): five states each identifiable in a single same-phase shot (sun high → waterline → ink+stars → moon → moon+lanterns+cyan); depth-0 matches pre-edit capture. Firefly Piece observed live end-to-end; earned strand gated on mask bit 3 across launches; mints exactly-once by wallet math. Drags: Moonlit Sweep never runtime-observed (dim 3, clean sweeps rare — force one via debug in item-17 pass); pacing thresholds are still plan guesswork (dim 5, needs playtest); reduceMotion + TestFlight upgrade still code-read-only (dim 9). Meets the per-game ship bar (no dim < 8); 9.3 A+ bar deferred to full-system regression pass. |
| v3      | + Zombie (item 7 + 16) | 9 | 9 | 9 | 9 | 8 | — | 9 | 10 | 8 | 8.88 | B+ | Bar ladder verified from ladder-strip.png (main-session grade): slat-light → lamp pool → volcanic tint + embers → eruption wash all read single-shot (2↔3 the closest pair); shelf visibly fills with staged tier; depth-0 pixel-diff exact vs baseline. Doubles After Midnight MEASURED live: 9.4% tier-2 control vs 23.0% pooled after-midnight (n=209) — the 10→20 doubling holds; announcement diegetic via lore chassis, once-per-run. Trophy mug renders direct in LoungeView on bit 7 (catalog row would leak into shop counts — right call). Latent banner-replay bug found and fixed (celebrated flag → engine). Drags unchanged: pacing guesswork (dim 5), reduceMotion/tutorial-guard code-read-only, session-local store test (dim 9). |
| v4      | + Luau (item 8, two agents — first died at session limit mid-scene, continuation repaired nothing and finished) | 9 | 9 | 9 | 9 | 8 | — | 9 | 10 | 8 | 8.88 | B+ | Bonfire ladder verified from ladder-strip.png (main-session grade): fire growth → dancers at BLAZE → ember-maroon sky lock all read; KINDLING↔FLAME is magnitude-only (honest dock). ENCORE proven exactly-once TWO ways (moves ledger 20−1+2=21 then monotonic; second run re-crossed 700 with no re-fire); wallet math exact on two stores; strand verified 3/6/9; depth-0 quantitative (Δ ≤ 0.53/255). Deliberate trade logged: fresh players start at 3 lanterns where shipped v0 showed 6 (plan's 3+best/150 formula) — the shipped look is now the earned best-450 state. Pacing flag: 20-move scoring math suggests median runs may reach BLAZE (state 2), slightly hot vs the median→state-1 target — playtest. Dim-9 drags unchanged. |
| v5      | + Cipher (item 9) | 9 | 9 | 8 | 9 | 8 | — | 9 | 10 | 8 | 8.75 | B+ | Golden-hour drift verified from ladder-strip.png (main-session grade): pale→amber end-to-end clear, adjacent-subtle by design (thresholdless per-phrase ladder). LAST CALL ceremony graded from lastcall.png: 16 struck covers, Vic's copy, POUR THE SECOND ROUND — pitch-perfect tone. buildMapping raw-index claim VERIFIED (scratch replication: 0/19 letters identical round 1 vs 2; confirmed on-device). Book +100, ¼ loop pay, and LAST CALL-at-96 all wallet/negative-tested; pennants persist across relaunch; depth-0 ≤ 1/255 static regions. Dim 3 dock: "0 hints" counts only charged hints (shipped CLEAN CRACK precedent) — free tip can't void CLEAN STRIKE; bounded +15 loophole, accepted. Known edge: kill on the 96 CRACKED panel skips the ceremony on restore (pre-existing save-forward semantics). Nerf/bonus pairing shipped together (dim 8 = 10). |
| v6      | + Blueprints (item 10) — ALL FIVE GAMES DONE | 8 | 9 | 9 | 9 | 8 | — | 9 | 10 | 8 | 8.75 | B+ | Sky ladder verified from ladder-strip.png (main-session grade): empty → 3 pictures at 9 drafts → full sky at 30, unmistakable; fill-warmth 3%→90% is quiet-by-design (halo 68.7→72.0 measured). FAIR COPY wallet-exact: flawless DRAFT +120 (3×) vs slip-run +80 (2×) vs flawless replay +30 (¼); seals + constellations persist across relaunch; silent draft-slip tally preserves honest picross (no mid-run leak). SECOND latent bug found+fixed (Task-deferred @State mint-toast write dropped inside TimelineView render window — same class as v3's). Fresh-sky trade logged (shipped 4 constellations = earned at 12 drafts; Luau v4 precedent, tier-0 sentinel keeps previews right). Dim-9 drags unchanged (reduceMotion/TestFlight artifact). |
| v7      | + economy (items 11–13, 15 + placeholder sprites) | — | — | — | 9 | — | 9 | 9 | 10 | 8 | — | — | Room + shop graded from room-full.png / shop-locked.png (main-session): six sprites land convincingly in the house idiom (marlin plaque, glowing neon sign, stocked aquarium, parrot, coral stools, fan w/ downrod fix); locked Sign row diegetic and honest (price shown, no BUY, "VIC SAVES THIS FOR REGULARS / STACK TO 150"). Ceiling VERIFIED through real purchase flow: 13,000 − all 19 = 220 → real spend exactly 12,780 (4.5×); faucets 2,950/12,780 = 23% < 25%; Sign gate negative+positive tested; upsert no-dupe over ~8 relaunches; plaque truncation found+fixed. Sprites are PLACEHOLDER — Carson to bless/replace. Standing plaque = back-bar engraving (Home retired). Prices remain playtest-theory (plan risk 8). |
| v8      | item 17 — full-system regression (FINAL Phase 1 pass) | — | — | 9 | 9 | 7 | — | — | 10 | 9 | — | — | Every dim-9 drag converted from code-read to MEASURED; evidence in build/progression-shots/regression/. Moonlit Sweep runtime-observed: "MOONLIT SWEEP! +240" verbatim, wallet math exact (901 = 500+1+160+240), negative control +120 at golden hour (285); boundary: stage evaluates post-clear-points (the sweep that crosses 400 pays moonlit — player-favorable, scene-coherent, documented). reduceMotion MEASURED: twin frames bit-identical ×5 staged-deep games, responsive under RM — and a REAL BUG found+fixed (paused clock froze DepthDial at launch depth 0; deep states rendered golden hour for RM users; 5-view bypass renders phase depth statically). FOUR coach bugs found+fixed: Luau coach minted FLAME+BLAZE on a fresh install (mask=768, wallet=150 observed) via cat-wipe 180 + post-tutorial refill shower to 680/700 (20 pts shy of unearned ENCORE) — fixed (checkMilestones coach guard + fresh newGame at dismiss); Stacks coach accumulated 788 via streak-carry + per-round clean-sweep +120 — fixed (per-round reset + sweep guard, on-device ceiling now 11/21/32/44, end 0/0/0); in-run best display polluted by scripted play in 3 engines (BEST 680 shown to fresh player) — fixed. ENCORE runtime-proven un-firable in coach (encoreBeat 0 end-to-end). Legacy payloads: HEAD-binary-generated payloads decode 5/5 in current engines (fireflies/fairCopies default empty, slips 0, solvedCount 13→2 books). Migration: REAL pre-progression store (HEAD build, no milestoneMask column) upgraded in place — retro-credit exact (masks 3/48/1792/2048/16384, wallet 500+9×75=1175), idempotent under plain relaunch AND guaranteed flag-cleared re-run (cfprefsd-safe method = simctl shutdown→edit plist→boot; live-sim file edits are NOT safe). Depth-0 identity quantitative (min-over-90s-burst strips): zombie max 3/255 exact, blueprints 0.18%, luau 0.68%, stacks 3.85%/deck 0.92%, cipher 4.78% — all residuals attributed to non-periodic layers (clouds/waves/palms/sparks); palette bands ≤6/255; picker fresh slot-matched exact vs v7; lounge fresh clean (WALK-IN, no sprite leaks). Pacing DATA (offline rig on real engines, n=300/game + on-sim spot checks within IQR): Stacks greedy-bot median 137, 44%≥150, 1%≥400 (bot=weak floor; humans higher — shape plausible); Zombie random-bot 99%≥t5, 81%≥t7, 1%≥t9, 0%≥t11 (bottom rungs near-free, top rungs properly rare); Luau median 1180, 98.7%≥700 with ~600 theoretical floor from 20 guaranteed-legal swaps — the WHOLE ladder completes every finished run for any player (policy-independent lower bound), so INFERNO+ENCORE ≈ every run and 3 mints shower on first run: dim 5 = 7, ladder-shape miss reported, NOT retuned per item-17 scope. Build: clean rebuild green; 3 warnings, all present at HEAD (verified by clean HEAD build — earlier "zero warnings" claims were incremental-build artifacts); 0 NEW warnings; 14 #Preview blocks compile. Remaining unknowns: TestFlight-artifact upgrade (Carson device), human pacing medians, device playtest, veterans' tutorial-inflated Stacks bests (pre-existing; retro may over-credit ≤3 bits/+225 for affected saves). |
