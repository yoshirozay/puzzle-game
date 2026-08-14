# THE SHOP — Overhaul plan (categories + price normalization)

Companion to SHOP_RUBRIC.md. Carson's brief (2026-07-31): categorize the one
giant list, normalize old-vs-new prices, tie prices to what games actually pay,
reward play, maximize engagement.

## 1. Measured earn model (from game code, 2026-08-01 analysis)

Wallet faucet: `recordRun` pays `max(1, (earnScore ?? score) / 10)`.
Milestone mints 75 each. Nightly pour 50/day at 4-of-9. Cipher matchbook +100.

Per-run wallet points (casual / median / skilled), minutes/run, evidence in
the 2026-08-01 workflow analysis:

| Game | casual | median | skilled | min/run | pts/min (c/m/s) | notes |
|------|-------:|-------:|--------:|--------:|------------------|-------|
| Totem | 18 | 35 | 150 | 2–5.5 | 9 / 12 / 27 | every run-end spends a life |
| Top Shelf | 20 | 50 | 250 | 4.5–13 | 4.5 / 6 / 19 | earnScore already /10 (≈score/100) |
| Luau | 60 | 66 | 106 | 2.5–4.5 | ~20–25 flat | defeats pay too (~85–95%); earnScore /3 |
| Blueprints | 9 | 24 | 40 | 4–5 | 4–6 | FINITE: ~840 first-solve + 225 mints, then 2–10/replay |
| Cipher | 4+bk | 7+bk | 9+bk | 1.5–4 | 5 / 9.5 / 17 | +100/book ≈ +16.7/crack; finite 96 phrases, second lap ~1.5/min |
| Navigator | 320 | 450 | 1100 | 3–7 | **100–160 sustained** | RAW per-passage scores, no divisor, no cap, loops forever |

Milestone mints wired: 18 bits × 75 = 1,350 lifetime (Navigator's 4 reserved
bits 22–26 are NOT wired — zero mints today; Stage 6 work parked elsewhere).

Reference player-days (mixed play, post-normalization below):
- casual day (~10–15 min): ~120–180 pts
- engaged-median day (~25–35 min): ~350 pts + 50 nightly pour
- week 1 adds ~600–900 in front-loaded milestone mints
- skilled hour: ~1,200–1,800 pts

## 2. The Navigator outlier (faucet fix, one line)

Navigator submits raw per-passage `levelScore` (200–785 per 10–25 s passage)
into an economy where every other hot game has a tuned divisor (Top Shelf /10,
Luau /3). Median-run wallet 450 vs 24–66 elsewhere: ~10× per minute. No price
ladder can serve both rates — pricing to Navigator starves the other five
games; pricing to the field lets Navigator buy the room in an evening.

Fix (house precedent, same shape as Top Shelf's): pass
`earnScore: game.levelScore / 5` at the NavigatorView recordRun call.
Post-fix: ~4–15 wallet/passage → ~64 / 90 / 220 per run ≈ 21–31 pts/min —
still the bundle's best earner, no longer economy-breaking. Displayed score,
bestScore, leaderboards, nightly missions unchanged.

## 3. Sink target

Old catalog totalled 42,830 (eras: original avg 675, west 1,031, lagoon
1,977) — roughly four months of engaged play, with purchases stalling for
days at a time. Target: **total ≈ 17,000–19,000**.

Shipped: **17,800 catalog / 17,750 real spend** after the gift. Verified on
device — a staged 30,000 wallet with TIKI_BUY=all ends at 12,250.

Completion math (rates from §1; mints 1,350 and matchbooks 1,600 are
one-time and front-loaded into the first ~3 weeks):

- engaged-median: 17,750 = 400/day × D + 2,950 → **D ≈ 37 days (5.3 weeks)**
- casual (~150/day): D ≈ 99 days — casual players furnish steadily rather
  than complete, which is the intended shape.

## 4. Final design (Concept 3 "Spatial Curator" + panel grafts, 2026-08-01)

Three concepts (engagement-max 15,350 / collector 19,540 / spatial curator
18,480) were scored by a 4-persona judge panel: curator won 8.23 vs 7.29 /
6.64 — only ladder whose ledger reconciles against the earn model, plus
recitable category membership. Grafts folded in: SHALLOW/DEEP sub-bands in
the water aisle (from collector), honest NEXT UP savings badge (from
engagement-max), Navigator fix as a ship-order gate, test re-derivation.

Six sections, panel order (membership rule: where it lives in the room);
prices ascend within section; every category leads with a cheap doorway and
ends with its aspiration cap:

| BEHIND THE BAR | A LITTLE GREENERY | THE REGULARS | WALLS AND RAFTERS | TAKE THE FLOOR | OUT ON THE WATER |
|---|---|---|---|---|---|
| flamingMug 50 (gift) | cornerFronds 90 | suspiciousCat 180 | glassFloat 100 | tikiStatue 220 | buoy 120 |
| umbrellaDrink 80 | plantBush 120 | parrot 280 | blowfishLamp 160 | loungeRug 320 | lagoonDuck 160 |
| barStools 140 | plantSnake 160 | martiniWoman 400 | ceilingFan 250 | highTable 500 | messageBottle 220 |
| recordCredenza 220 | plantTiered 220 | highballMan 400 | sunsetWindow 400 | loungeCouch 800 | dolphin 300 |
| backBarShelf 360 | palmPlant 300 | | bayWindow 550 | grandPiano 1250 | seaTurtle 400 |
| neonTikiSign 600 (gated) | | | marlin 750 | | sailboat 550 |
| | | | aquarium 1100 | | shark 700 · orca 950 |
| | | | | | farIsland 1200 · volcano 1400 · yacht 1800 |

Sums: 1,450 + 890 + 1,260 + 3,310 + 3,090 + 7,800 = **17,800**
(real spend 17,750 after the gift). Patron twins tied at 400 by design.
OUT ON THE WATER renders two sub-bands: THE SHALLOW END (buoy→seaTurtle,
"IF IT FITS IN A ROCK POOL") / THE DEEP END (sailboat→yacht, "IF IT COULD
CAPSIZE THE DUCK").

Ladder measurements: global max adjacent step **1.6×**. Within-section steps are inside the 1.15–1.6× band everywhere except two
declared exceptions: BEHIND THE BAR runs high (below), and THE REGULARS
carries a deliberate **1.00× step** — the patron twins tie at 400 because
they are the same piece in two poses.

### Declared exception (D2 step band, BEHIND THE BAR)

The bar aisle is 50/80/140/220/360/600: steps 1.60, **1.75**, 1.57, **1.64**,
**1.67** — three above the 1.6 ceiling. This is arithmetic, not sloppiness:
the aisle spans 12× across six rungs, and ln(12)/ln(1.6) = 5.29, so five
steps cannot all sit at ≤1.6×.

Adding a seventh rung is necessary but **not sufficient**, and it is worth
being exact about that: inserting the parrot at 280 gives 1.60/1.75/1.57/
1.27/1.29/1.67 (two still high) and the cat at 180 gives 1.60/1.75/1.29/
1.22/1.64/1.67 (three still high). A seventh rung only works alongside a
full aisle reprice — 12^(1/6) = 1.51 is feasible, e.g. 50/80/125/200/300/
400/600 — and the only insertion candidates would strip THE REGULARS below
its four-item floor. Not worth trading the aisle's best idea for a decimal.
The prior 3.1× cliff (80→250) is gone; what remains is an even, slightly
wide ladder whose violating steps all sit at the cheap end, where rungs are
minutes apart at any earn rate.

### Cross-aisle pricing axis

Within an aisle, price rises with visual prominence. **Across** aisles the
axis is deliberately different, and this is the rule the numbers follow:

1. **Living things carry a premium.** The cat (180) → parrot (280) → patrons
   (400) sit above comparable fixtures. Company is worth more than furniture.
2. **Behind the bar is the on-ramp.** It is the opening camera frame, so its
   rungs are priced to be bought early and often — which is why bar stools
   (140) undercut a snake plant (160) and The Back Bar (360) undercuts a
   patron (400). A player furnishing the frame they already stare at is the
   fastest route to a room that looks lived-in.
3. **The lagoon prices on spectacle, not size** — a landmark volcano (1400)
   over a whole yacht's worth of small drifters.

NEXT UP badge: the first unowned row in panel order priced above the wallet
shows an honest progress readout ("N TO GO" + fill bar) from live wallet
state — no timers, no artificial scarcity. The locked Sign is excluded (its
cost is play) and so is the unclaimed welcome mug (it is free). The header
carries a tappable **"N WITHIN REACH ›"** chip that scrolls to the first
affordable row, so what the SHOP badge promises is never below the fold.

### Declared exception (D3 dead-zone clause)

At engaged-median 400/day the last three buys exceed the rubric's 3-day
bound when taken cheapest-first from a zero bank: piano 3.1 days, volcano
3.5, yacht 4.5. This is intrinsic to a finite 38-item catalog — near the end
there are simply fewer rungs left — and flattening it would cost the
aspirational peak the room is built around. Mitigation is the NEXT UP
progress bar on exactly those saves. Everything before day ~27 stays inside
1–3 days.

## 5. Constraints (implementation)

- Welcome gift (flamingMug) stays price-50/free-once; Sign stays play-gated.
- syncLoungeCatalog upsert retunes unpurchased rows only — veterans keep
  owned items; big price drops give existing testers a windfall (accepted,
  pre-App-Store).
- Tests to update: PlayerStoreAdversarialTests `lockedSignRefusesPurchaseAndBadge`
  (2200 literal ×2), `ownedUnplacedItemIsNotNewlyAffordable` (730/580/150
  ladder + "next: 200"), 38-row counts stay.
- Shop panel keeps: ghost-tap scroll-to-row, TIKI_SHOP_SCROLL, coach pulse on
  the mug row, VIC TIDIES UP footer.
- Another session owns uncommitted Luau edits — stage shop files only.
- The earn model in §1 is per-run and ignores the shared lives pool (cap 5,
  +1/30 min). Lives bound how many DEFEATS a session can absorb, so the
  casual figures above are an upper bound on defeat-heavy play; Navigator
  banks per passage and only spends a life at voyage end, so it remains the
  most lives-efficient earner even after the /5 divisor.

## 6. Known follow-ups (out of scope here)

- **No terminal sink.** At engaged-median rates the room is complete around
  day 37 and the wallet keeps filling with nothing to spend it on. The judge
  panel's largest single deduction. Options: consumables (extra Depth
  Charges / Lounge Cats for points), repeatable spends (rug and window
  colorways as purchases rather than free taps), a second room, or seasonal
  restock. Needs a product decision before an economy one.
- **Chip vs BUY visual weight.** The gold WITHIN REACH capsule is currently
  as loud as the gold BUY capsules — a navigation shortcut competing with
  the purchase action. Worth a look on device; an outline capsule would
  demote it if it reads wrong in the hand.

- Marketing collateral (`website/assets/shots/02-lounge.png` and its
  shots-web / previews twins, plus the staged App Store set) shows a
  160,100-point wallet — 9× the whole retuned catalog. Reshoot before the
  next store submission.
- Existing TestFlight installs keep owned items but see prices drop on
  unpurchased rows (upsert semantics), so testers get a one-time windfall.
  Accepted pre-App-Store.
