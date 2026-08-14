# PROGRESSION RESEARCH — Making Long Play Feel Rewarding

*2026-07-09. Research phase for the level-progression initiative. Sources: deep-research
sweep (22 sources fetched, 102 claims extracted, 25 adversarially verified 3-vote, 23
confirmed) + full codebase audit. Next phase: PROGRESSION_PLAN.md (design proposal).*

---

## 1. The problem, measured

**Playing Tiki Games for a long time changes almost nothing the player can see.**
The audit found exactly three progression gaps:

### Gap A — In-run: backgrounds are 100% decoupled from gameplay
All five `*BackgroundView.swift` scenes (and `TikiScenery.swift`) receive only a
wall-clock `t` from `TimelineView` plus screen size. None receive game state. The
90-second day/dusk "breath" happens whether you're at 0 points or 10,000. The only
progress-reactive visual in the entire app is the lounge room filling with furniture.

### Gap B — Per-game: nothing persists but `bestScore`, nothing ramps
| Game | Board | Advances | Ramp | End shape |
|---|---|---|---|---|
| Tiki Stacks | fixed 8×8 | score only | none (turn-based) | endless until no placement |
| Zombie | fixed 4×4 | score + tier (win at tier 11, play continues) | none — spawn always 90/10 tier-1/2 | endless until no move |
| Blueprints | 5×5→10×10 | solved count | easy→hard ordering | **finite: 30 puzzles, then dry** |
| Cipher | — | solvedCount | none | 96 phrases, **silently loops forever** |
| Luau | fixed 7×7 | score only | none | fixed 20-move runs |

No game unlocks anything, grows, or gets harder as the player improves. Best score
gates nothing.

### Gap C — Meta: the economy has a hard ceiling
Lounge catalog = 13 items, 50–500 pts, ≈2,830 pts of real spend (Flaming Mug is the
free FTUE gift). Earn rates: Stacks score/10, Zombie score/100, Luau score/30, Cipher
completionScore/10, Blueprints first-solve/10 then ¼ on replay. After the 13th item:
"THE ROOM IS COMPLETE" and **points become inert** — no sink, no prestige, nothing
left to want.

---

## 2. What the research found (verified)

### Theme 1 — Make depth visible through the environment itself
- **Alto's Odyssey uses in-run palette shift as the game's only time signal** — night/day,
  weather, and biome features cycle within a single run; no HUD counter. Achievements
  reward *witnessing* a full cycle or a sunrise. (3-0 verified; MacStories + corroboration)
- **Snowman layered slow-cycle ambient details** (lunar cycles, wildlife, weather
  surprises) explicitly to build "a sense of something much larger than yourself, that
  you want to keep returning to" — environmental discovery as the session-to-session
  hook in a $4.99 no-IAP game. (3-0; Game Developer IGF interview, primary)
- **Environmental change must be coupled to mechanical change.** Each Alto biome carries
  its own mechanics (wallriding, grind rails, tornados); the team designed each area
  "to feel distinct to play, instead of being a purely visual change." (3-0; Red Bull)

### Theme 2 — Earned aesthetics: the reward IS the play
- **Tetris Effect's founding premise**: the flow state that emerges as play deepens
  *creates the music* — audio built from the game's own sound effects synced to each
  player action. The audiovisual payoff is produced by the player, not layered on.
  (3-0; Mizuguchi interview, primary)
- **Downwell** (unverified by the panel but well-documented): depth reached converts to
  unlockable 4-color palettes — cosmetic color swaps as visible proof of how deep
  you've gone, in a premium no-IAP game.

### Theme 3 — The psychology: competence feedback, not reward schedules
- **Competence need satisfaction predicts voluntary re-engagement** (β=.41 free-choice
  return play; SDT/PENS, peer-reviewed primary). Persistence flows from *felt
  competence*, not compulsion mechanics.
- **Immersion is predicted by need satisfaction, not graphics fidelity** — cosmetic and
  environmental rewards deepen engagement when tied to demonstrated competence, not
  when applied as free polish. (3-0; Przybylski/Rigby/Ryan 2010)
- **The concrete mechanisms**: (a) skill-graded challenge, (b) granular, timely positive
  feedback. PENS's four features: easy controls, clear/consistent feedback, choice of
  goals and strategies, social play. (3-0, primary)
- **GameFlow (Sweetser & Wyeth 2005)**: progress must be continuously visible; challenge
  should rise with skill (else apathy); and "the effort invested in a game should equal
  the rewards of success" — the academic basis for earned reveals. (3-0, primary)

### Theme 4 — The decoration meta is proven, and premium economies work
- **31% of top-grossing US iOS match-3 games carry a building/decoration meta**;
  Gardenscapes is the trendsetter. The decoration layer, not the puzzle, carries
  long-term retention. (3-0; GameRefinery market data)
- **Alto's premium coin economy**: run-collected coins feed a Workshop where flagship
  items are *deliberately expensive* (wingsuit 7,500 coins, ~16,750 total) and function
  as multi-session savings goals that **expand the possibility space** (combos, escapes,
  records) — not cosmetic-only. (3-0; two sources)

### Theme 5 — Ethical lines for a premium game
- **CHI 2022 dark-patterns research**: a mechanic isn't dark by nature — darkness lives
  in pricing, timing, and pairing. Daily rewards and milestones are fine if they never
  punish absence. Gambling-style mechanics are the unanimous exception. (3-0, primary)
- **Unpacking** ($19.99, no scores, no fail states; 1M+ sales, 2 BAFTAs): premium puzzle
  engagement sustained through **contemplation, discovery, expression**. The
  "expression" pillar maps directly onto the lounge. (3-0; GDC talk writeup)
- **Emotion-first design** (2-1, weakest finding): Snowman fixed the target feeling
  before mechanics. For us: the lounge's feeling is *warm, unhurried,
  vacation-at-dusk* — audit every unlock against it.

### Refuted — do not cite
- "Alto's stated core goal was flow" (1-2) and "battle passes deliver a healthy earning
  cadence" (0-3) both failed adversarial verification.

---

## 3. Design principles distilled (the checklist for PROGRESSION_PLAN)

1. **Depth must be readable at a glance, diegetically.** Tie palette/sky/lighting state
   to score depth or run length — the background should *be* the progress bar.
2. **Never ship a purely visual change.** Each new zone/state should carry a small rule
   twist (new tile type, new piece, new obstacle) — Alto's biome rule.
3. **The reward is produced by play, not popped up after it.** Escalate audio/particle
   response to streaks and depth (Tetris Effect rule). We already have per-game SFX and
   juice; wire intensity to depth.
4. **Cosmetics must be earned to mean anything** (SDT). Unlockable scene states/palettes
   gated on demonstrated competence (best-depth, tier reached, puzzles drafted) — not
   given free, not sold.
5. **Effort ∝ reward, visible always** (GameFlow). Milestones should land at honest
   intervals; long droughts and instant showers both break it.
6. **Expensive flagship goals are good** (Alto's wingsuit). The economy ceiling isn't
   fixed by cheaper items but by *bigger wants* — 2,000–5,000-pt items that expand what
   you can do (unlock a game variant, a lounge wing, a scene state).
7. **Discovery is a return hook.** Slow-cycle ambient surprises (rare wildlife, a comet,
   a luau on the beach at milestone N) that only long-session or returning players see.
8. **Nothing that punishes absence.** No decay, no streak loss, no timers. Milestones,
   daily *bonuses* (never penalties), and earned reveals are all ethically clean.
9. **Expression over optimization** (Unpacking). Lounge placement choice (LOUNGE_PLAN
   step 5's toggles) is progression too — more ways to arrange = more reasons to earn.

## 4. Where each principle bites, per game

- **Tiki Stacks / Zombie / Luau (endless score-chasers)**: prime candidates for
  **in-run environmental depth** (principle 1) — e.g. lagoon dusk→night→bioluminescence
  as score climbs; Zombie's coral wall reacting to highest tier on board; Luau bonfire
  growing with cascade streaks. Plus **persistent unlockable scene states** at best-score
  milestones (principle 4).
- **Zombie** already has tiers + lore cards — the natural spine for named milestone
  reveals (tier art on the wall behind the board?).
- **Blueprints (finite 30)**: needs content *or* a prestige mode; the drafted-blueprint
  collection is itself a gallery — display drafted pictures in the lounge?
- **Cipher (loops silently)**: matchbook completion (16 books × 6) is an unclaimed
  milestone structure; the loop-at-96 needs acknowledging or extending.
- **Lounge (economy ceiling)**: flagship 2,000+ pt items (aquarium! marlin!) as
  savings goals; possibly scene-state purchases (window views, time-of-day for the
  room) — items Carson already owes art for slot straight in.

## 5. Open questions the research couldn't settle

1. **Milestone granularity/naming** for endless score-chasers went unverified (nothing
   survived on Mini Metro city unlocks, Spire ascension tiers) — theory-grounded only.
2. **Does the decoration meta transfer to premium?** Proven in F2P; Alto's functional
   workshop is the nearest premium proof. We're partly the experiment.
3. **Pacing**: how often should palettes/zones shift per run? No tuning guidance found —
   needs playtest + rubric iteration.
4. **Shared wallet effects**: does cross-game earning strengthen (goal choice = autonomy)
   or dilute per-game competence feedback? Watch for it in playtests.

## 6. Caveats on the evidence

Alto claims rest largely on secondary press of primary interviews; SDT/PENS data is
correlational (single-session, novices) — "predicts," not "causes"; the 31% decoration
stat is from an F2P-dominated chart (March 2020); GameFlow was validated by expert
review of two RTS games; Unpacking is finite, so it proves premium-without-pressure,
not endless retention.

---

*Key files for the plan phase: `PlayerStore.swift` (economy, catalog, records),
`Tiki/Zombie/Blueprints/Cipher/LuauBackgroundView.swift` (all currently clock-only),
the five `*Game.swift` engines, `LoungeView.swift` (meta-room).*
