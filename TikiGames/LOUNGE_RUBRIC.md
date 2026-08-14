# The Lounge — meta-progression feature rubric

Grading scale per dimension: 0–10. **A+ bar: average ≥ 9.3 with no dimension below 8.**
Each iteration gets screenshotted on the simulator — in BOTH the empty state (fresh
install) and the full state (`TIKI_POINTS` + `TIKI_BUY=all`) — and graded honestly.
Improvements target the lowest dimensions first.

Grounded in how the best decorate-your-space metas work (Playrix's Gardenscapes/
Homescapes renovation loop, Zynga's Ville self-expression farms, Animal Crossing's
Happy Home Academy): the loop must earn → spend → *see the space change* → want more.

| # | Dimension | What 10/10 looks like |
|---|---|---|
| 1 | Empty-state invitation | A fresh lounge reads as *potential*, not brokenness. Vic is present and the room is alive (breathing wall, ambient motion) even with zero purchases. Visible hints of what could fill the space (hooks/clean patches on the wall). The shop affordance is obvious and beckons when something is affordable. |
| 2 | First-purchase runway | The cheapest item is reachable in the first session. The full catalog — including the 500-point cat — is visible and priced from day one, so aspiration starts immediately. Buy/can't-afford/owned states are legible at a glance. |
| 3 | Purchase moment | Buying is a celebration: haptic, the shop gets out of the way, and the item pops into its spot with a spring. The FlamingMug lands in Vic's raised hand. You always *see* the room change — never a purchase that alters nothing. |
| 4 | Progression legibility | Points balance visible on Home, in the lounge, and in the shop. Room completeness (n/13) tracked. The price ladder communicates a journey: early wins (50–120), mid-game furniture (150–350), endgame flex (the cat, 500). |
| 5 | Style fidelity | Flat fills, hard geometric shadows, mid-century tiki. Purchased sprites render at hero-faithful anchors; the finished room earns its place beside the six A+ scene backgrounds. Shop chrome is flat mid-century (Futura, palette colors, no material effects). |
| 6 | Composition and zones | The 680×440 hero re-composed for portrait with intentional zones: hanging layer (lamp, float, window, shelf), bar zone with Vic, floor zones (statue/palm corner, credenza wall, patrons mid-floor, fronds framing the corner). Reads at a squint at every fill level from 0 to 13 items. |
| 7 | Ambient life | Single TimelineView clock. Wall breathes on the 90 s cycle; lamp sways; record spins once owned; dust drifts. More purchases = more motion, so the room literally comes alive as it fills. Nothing mechanical, no loop seams. |
| 8 | Performance and craft | Transform/opacity-only animation, proportional to screen size, explicit Double math in Canvas closures, renders on `isPlaced`, no view-@State written from escaping closures, SwiftData fetched in body (never cached in @State). Builds clean, 60 fps class performance. |

## Iteration log

| Iter | 1 Empty | 2 Runway | 3 Moment | 4 Progress | 5 Style | 6 Comp | 7 Life | 8 Craft | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 6 | 8 | 3 | 8.5 | 7.5 | 5.5 | 8 | 6 | 6.6 | C+ |
| v2 | 7.5 | 8.5 | 8.5 | 9 | 9 | 7.5 | 8.5 | 9 | 8.4 | A- |
| v3 | 8 | 9.5 | 9 | 9.5 | 9 | 9 | 9 | 9 | 9.0 | A |
| v5 | 9 | 9.5 | 9 | 9.5 | 9.5 | 9 | 9 | 9.5 | 9.25 | A |
| v6 | 9 | 9.5 | 9.5 | 9.5 | 9.5 | 9 | 9.5 | 9.5 | 9.38 | **A+** |

v1 notes: room anatomy + anchors landed first try (mug registered in Vic's hand),
but purchases made after first render never appeared — `loungeItems` is a computed
fetch, not observable state; the points chip masked the staleness. Vic tiny against
a fortress-tall bar; patrons buried the credenza; lashings read as plank bands.

v2 notes (placedItemIDs observable mirror on PlayerStore — same pattern as the
points mirror — plus full recompose): live updates fixed and proven by same-launch
TIKI_BUY=all populating the room. Remaining: glass float hidden behind the Dynamic
Island, lamp crowding the status bar, thin fronds.

v3 notes (island-safe hanging anchors, bigger fronds, stronger ghost patches, Vic
bob): buy-state ladder verified at 130 pts — five BUY enabled, rest dimmed,
affordable badge on SHOP. Empty floor still gave no hint of what belongs there.

v4→v5 notes (floor dust shadows where statue/palm/credenza will sit): v4's marks
straddled the baseboard and read as wall smudges; v5 dropped them fully onto the
wood. Empty room now reads as a promise in every zone.

v6 notes (burst star fires at the purchased item's anchor — the Tiki Stacks juice
pattern — and a FlameShape shimmer rides the mug's baked flame, synced to Vic's
bob): the two 9s that were holding the average under the bar (purchase moment,
ambient life) both cleared. **A+ bar met — loop goal achieved.**

Verification hooks (all DEBUG-only): `SIMCTL_CHILD_TIKI_BG=lounge` routes straight
to the room; `TIKI_POINTS=<n>` grants wallet points; `TIKI_BUY=all|id,id` purchases
through the real `purchase()` path; `TIKI_SHOP=1` opens the shop on launch. Wipe
state with `simctl uninstall`.

Polish backlog for a future pass (not blockers): live purchase-tap animation was
verified by mechanism (same-launch room updates + the proven BurstView pattern),
not by a mid-animation screenshot — worth one manual tap-through on device; cat
could get a blink; patrons could sip (step-5 idle round); window position could
breathe with a dusk phase someday.

## Research notes (what the reference games do)

- **Playrix (Gardenscapes/Homescapes)**: decoration is the retention spine for
  expressionist players; puzzle currency buys renovation; every purchase produces a
  visible before/after change and a character reaction. Lesson: never let a purchase
  fail to visibly change the room.
- **Zynga Villes (FarmVille/CastleVille)**: start with a small plot and visible
  locked potential; self-expression drives long-term play; unlock pacing runs
  early-fast → late-aspirational. Lesson: show the whole catalog early; make the
  first buy quick and the last buy a flex.
- **Animal Crossing**: empty rooms are framed as an invitation (Nook hands you the
  first furniture immediately); the Happy Home Academy grades the room weekly and
  rewards rank-ups. Lesson: grade/track completeness, and make the empty state warm,
  not barren.
- **Empty-state UX**: an empty screen must say why it is empty and invite the next
  action; hide systems not needed in the first 15 minutes; tease future features
  without unlocking them.

Sources: [Homescapes meta analysis](https://phoena.substack.com/p/game-digest-4-homescapes-my-home) ·
[GameRefinery on player motivations](https://www.gamerefinery.com/episode-6-player-motivations-rovio-fundamentally-games/) ·
[House-decoration systems in mobile games](https://asoworld.com/blog/game-market-trends-how-publishers-use-house-decoration-system-in-mobile-games-to-attract-more-users/) ·
[Playrix lessons](https://www.uxreviewer.com/home/2019/3/9/part-2-are-casual-games-maturing-lessons-from-playrix) ·
[CastleVille design interview](https://www.gamedeveloper.com/business/interview-zynga-goes-massively-multiplayer-with-i-castleville-i-) ·
[Onboarding best practices](https://www.gamerefinery.com/keep-your-players-coming-back-introducing-onboarding-best-practices-part-2/) ·
[ACNH Happy Home Academy](https://nookipedia.com/wiki/Designing)
