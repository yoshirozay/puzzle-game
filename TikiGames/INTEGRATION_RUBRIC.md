# Lounge ↔ games integration — rubric

Grading scale per dimension: 0–10. **A+ bar: average ≥ 9.3 with no dimension below 8.**
Screenshot both directions of the loop on the simulator and grade honestly.

The reference pattern (Playrix hub flow): the decorated space is the hub; a single
prominent PLAY launches the earner; every run ends by handing the player back with
their new buying power made visible; commerce lives in a top corner; guidance comes
from the environment (badges), never popups; conventions stay consistent across
screens.

| # | Dimension | What 10/10 looks like |
|---|---|---|
| 1 | Loop closure | Every seam of earn → spend → earn is one tap: lounge PLAY → Tiki Stacks; back from a lounge-launched game returns to the lounge; Home reaches both in one tap. No dead ends. |
| 2 | Affordance hierarchy | PLAY is the lounge's unmistakable primary action (bottom-center, biggest chrome). SHOP is secondary, clustered with the wallet top-right. Nothing fights the room art. |
| 3 | Environmental guidance | Badges — not popups — pull the player: coral dot on Home's lounge row, on the SHOP button, at the moment something becomes affordable. Badges disappear when there's nothing to buy. |
| 4 | Game-over handoff | The payoff moment shows +earned, the wallet total, and — when true — "new item affordable in the lounge" in the established gold. The player never has to do mental math. |
| 5 | Empty-wallet guidance | A broke player in the shop is told exactly where points come from ("earn points playing Tiki Stacks"); a completionist gets a wink instead. No unexplained dead ends. |
| 6 | Style fidelity | All new chrome is flat mid-century: Futura, palette tokens, capsule pills, no materials. The gold that means "points" stays the same gold everywhere. |
| 7 | Convention consistency | Back button always top-left; wallet chip always top-right; badges always coral-dot-with-ink-ring; the same capsule language on every button. Dev shortcuts route through real navigation. |
| 8 | Craft | Provenance state on the right owner, store logic centralized (`canAffordNewItem` on PlayerStore), no duplicated affordability math, builds clean, no regressions in either screen. |

## Iteration log

| Iter | 1 Loop | 2 Hierarchy | 3 Guidance | 4 Handoff | 5 Empty | 6 Style | 7 Convention | 8 Craft | Avg | Grade |
|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 9 | 9.5 | 9 | 8 | 7 | 9 | 8.5 | 9 | 8.6 | A- |
| v2 | 9 | 9.5 | 9 | 8.5 | 7.5 | 9.5 | 9.5 | 9 | 8.9 | A- |
| v3 | 9 | 9.5 | 9 | 8.5 | 9.5 | 9.5 | 9.5 | 9.5 | 9.25 | A |
| v4 | 9 | 9.5 | 9.5 | 9.5 | 9.5 | 9.5 | 9.5 | 9 | 9.38 | **A+** |

v1 notes (SHOP to top-right cluster with wallet, PLAY bottom-center, provenance
back, badges, game-over lines, dev route through HomeView): live user save (6/13
items, 10 pts) confirmed badges correctly absent when broke — but the back button
skewered the hanging blowfish lamp, and the shop's "earn points" footer sat below
the fold where a broke player would never see it.

v2 notes (hanging anchors respect the back-button corner; lamp/window tops align):
collision gone; footer still buried.

v3 notes (guidance moved into the shop header — gold "EARN POINTS PLAYING TIKI
STACKS" under the title when broke; "THE ROOM IS COMPLETE. THE CAT APPROVES."
at 13/13): above the fold, verified on the live 10-pt save.

v4 notes (game-over verified on a throwaway simulator via TIKI_AUTOPLAY — two
real runs): first run exposed WALLET buried under PLAY AGAIN; second confirmed
the fix as one combined gold line "WALLET N · NEW ITEM IN THE LOUNGE" (wood
"WALLET N" when nothing affordable). **A+ bar met — loop goal achieved.**

v5 notes (design change by Carson, superseding the lounge-PLAY pattern): Home
became the hub — sparse lagoon hero with a big PLAY capsule that opens a 2-wide
game-picker grid (thumbnail tiles, SOON tags) and a THE LOUNGE capsule with the
affordability badge. The lounge's PLAY button and the `gameFromLounge`
provenance state were removed; back always returns to Home. All three screens
screenshot-verified. Dimension 1's "back from a lounge-launched game returns to
the lounge" no longer applies — games are only entered through the grid.
