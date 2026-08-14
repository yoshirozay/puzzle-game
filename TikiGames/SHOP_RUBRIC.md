# THE SHOP — Overhaul rubric

Scope: the Lounge shop (LoungeShopPanel + PlayerStore catalog). Goals from Carson
(2026-07-31): categorize the one giant list, normalize old-vs-new prices, tie
prices to measured game earn rates, reward play, maximize engagement.

Reference class: Animal Crossing Nook's Cranny (categorized diegetic catalog),
Two Dots / Toon Blast progression shops (smooth price ladders, always-a-next-goal),
Cookie Clicker / AdVenture Capitalist (geometric sink curves ~1.3–1.6× steps).
Economy method: prices derive from a measured points-per-session model built
from the actual scoring code of all six games (not vibes).

Pass bar: **average ≥ 9.3 AND no dimension below 8.** Rubric locked before
first grade; the iteration log below is append-only.

## Dimensions

### 1. Category design (browsability)
10/10 = every item sits in exactly one diegetic category that matches where it
lives in the room; categories are few (4–6), each 4+ items, ordered
cheap-entry → aspirational; headers speak in Vic's voice like the rest of the
app; a new player can predict what a category holds from its name alone.

### 2. Price-ladder integrity (normalization)
10/10 = one coherent ladder: within a category prices rise monotonically with
visual prominence (no trinket priced above a landmark); adjacent steps are
smooth ratios (~1.15–1.6×, no 2.5× cliffs, no near-duplicate prices without
reason); round numbers throughout; the old-catalog vs west-wing vs lagoon
pricing eras are indistinguishable after the retune.

### 3. Earn-rate fit (time-to-item)
Scored against the measured economy model (points/session for casual, median,
skilled — built from game code in this session's analysis). 10/10 = first
non-gift purchase affordable within session 1–2; a casual player affords
something new every 1–2 days through week 2; no dead zone where a median
player goes >3 days of normal play with nothing newly affordable; the top
landmark reads aspirational but lands within ~3–5 weeks of engaged play.

### 4. Engagement pull (reward psychology)
10/10 = at every wallet state along the median trajectory there is a visible
next goal within roughly one session's earnings; near-affordable items are
discoverable (not buried); the "something's affordable" badge and the
"EARN POINTS PLAYING ANY GAME" nudge stay honest under the new prices; buying
never dead-ends the loop (next goal always visible in the panel).

### 5. Shop UI craft
10/10 = sectioned panel in the house style (Futura, P.* palette, Vic's voice,
SoftPress); per-category owned counts or equivalent orientation; ghost-tap
scroll-to-item and TIKI_SHOP_SCROLL still work; welcome-mug coach pulse still
lands on the mug row; screenshot-verified on simulator, no clipped or
misaligned rows in light of the sectioned layout.

### 6. Economy & code safety
10/10 = welcome gift still free-once; Sign still play-gated at its row with
rung copy; catalog upsert still retunes only unpurchased rows (veterans keep
owned items and never lose wallet); the 38-row invariant intentional (or
consciously changed with tests updated); all price-sensitive tests updated
and the full suite green; no other surface (game-over handoff, badges,
missions) breaks under new prices.

### 7. Sink depth (lifetime fit)
10/10 = total real spend (catalog minus gift) equals a documented target:
roughly 3–6 weeks of engaged-median play to complete the room, with the math
shown from the measured earn model (per-session points × realistic
sessions/week + milestone mints + nightly pours).

## Iteration log

| version | D1 | D2 | D3 | D4 | D5 | D6 | D7 | avg | grade | delta diagnosis |
|---------|----|----|----|----|----|----|----|-----|-------|-----------------|
| v0 (shipped shop) | 3 | 5 | 3 | 4 | 5 | 9 | 2 | 4.4 | F | one flat 38-row list; 42,830 sink ≈ 4 months engaged; Navigator faucet 10× the field unpriced-for |
| v1 (plan, panel-scored) | 8.7 | 8.5 | 7.3 | 7.5 | 8.1 | 8.9 | 8.7 | 8.2 | B+ | Concept 3 base (panel mean 8.23 of 3 concepts) + grafts: SHALLOW/DEEP sub-bands, NEXT UP badge, Navigator gate, test re-derivation |
| v2 (implemented, 4-judge panel + 18 adversarial verifiers) | 9.25 | 8.88 | 8.75 | 8.62 | 9.0 | 9.12 | 9.25 | 8.98 | A− | Built and shipped; 18 findings confirmed, 0 refuted. Weakest: near-affordable buried below the fold (D4) and a 3.1× cliff at 80→250 inside the first aisle (D2) |
| v3 (after fix round, regression-hunting panel) | 9.07 | 8.60 | 8.97 | 8.73 | 8.65 | 8.82 | 8.90 | 8.82 | B+ | Score *fell*: the panel hunted regressions and found real ones — a `uniqueKeysWithValues` crash on duplicate rows, a sub-44pt chip that read as a stat line, a jump landing on a locked row, three BEHIND THE BAR steps above the 1.6 band, and a blank screenshot that made one state unjudgeable |
| v4 (regressions fixed, final panel) | 9.15 | 8.93 | 8.70 | 8.90 | 8.72 | 8.70 | 8.78 | 8.84 | B+ | Plateau (+0.02). Judges verified the fixes landed and the ladder math reproduces exactly, then found my *exception paragraph's* arithmetic wrong (a 7th rung alone would not fix the band) and one evidence file that was the Luau board, not the shop. Both corrected here |

### Stop, and why

Stopping at **8.84** — short of the 9.3 bar — after three scored rounds moved
8.98 → 8.82 → 8.84. That is a plateau, and the residue is not iterable:

- **D7's biggest deduction is a product decision, not a defect.** Judges are
  right that the wallet goes inert once the room is complete (~day 37
  engaged) with the faucet still running. Fixing it means inventing a
  post-completion sink — consumables, re-skins, a second room. That is
  Carson's call about what the game *is*, not a tuning pass.
- **D2's remaining deduction is arithmetically unfixable** at six rungs
  (proof in SHOP_PLAN §4) without spending THE REGULARS, which every judge
  named the round's best idea.
- **D4/D5's remaining deductions are taste calls** a panel cannot settle:
  whether the gold WITHIN REACH capsule should out-shout the gold BUY
  capsules, and how loud the goal readout should be.

Further rounds would either idle below the improvement floor or start
awarding points without evidence, which this rubric forbids. The three items
above go to Carson.
