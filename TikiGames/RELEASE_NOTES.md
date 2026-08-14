# Release Notes

One entry per TestFlight build, newest first, written at upload time by the
`/testflight` skill. Bullets are concise and player-facing — what changed in
this binary, in the player's terms, never files or commit prose. Each entry
doubles as the build's **What to Test** text in App Store Connect.

Template:

```md
## <version> (<build>) — <YYYY-MM-DD>

- <2–5 high-level bullets on what changed>
```

History starts with the first build shipped after 0.1.3 (1); earlier builds
predate this file.

## 0.1.3 (26) — 2026-08-03

- Fixed: skipping one game's lesson used to silence the lessons in every
  other game too, so a game you'd never played could open with no tutorial
  at all. Each game now teaches itself regardless of what you skipped
  elsewhere — and if you skipped before, your unseen lessons are back
- The tutorial's SKIP button no longer crowds the back arrow in Totem and
  Top Shelf

## 0.1.3 (25) — 2026-08-03

- A leaderboard banner joins the picker — swipe left of Luau to find the
  boards under their pennants and gold trophy
- Tap it to pick a board: each game's world in miniature, your best on
  that board's own measure, and your live world ranking once standings
  load

## 0.1.3 (24) — 2026-08-03

- The bar slims down to three games — Luau, Totem, and Top Shelf — and now
  opens on the game picker instead of dropping you into Luau
- Lives hold off until a game has hooked you (Luau night 10, a 64 bottle in
  Top Shelf, 300 in Totem) — new players play free, and a game you haven't
  cracked stays free even at zero hearts
- The shared pool is now 3 hearts, one back every hour
- Luau relocated to the cabana pool — new backdrop and a fresh preview on
  its picker card

## 0.1.3 (23) — 2026-08-02

- New app icon: the sunset now fills the whole icon edge to edge, instead of sitting in a small framed sign on a wall — far easier to pick out on a crowded home screen

## 0.1.3 (22) — 2026-08-02

- Cabana Cipher's streak now gets its own moment: a stamp slams in under the win card, rolls up to your new count, and burns hotter as the run grows — gold, then sunset orange, then white-hot twin flames at 10 in a row, then a rare glow-tide blue at 20
- Your first win points at the goal: crack the next for 2 in a row (and the line no longer gets cut off)
- The tutorial phrase now reads THE EARLY BIRD GETS THE WORM

## 0.1.3 (21) — 2026-08-02

- Cabana Cipher's win and loss panels now tell your streak story — how many you've cracked in a row, and what a defeat just ended
- Internal: fixes to what the games report about themselves. Several things weren't being recorded at all, including the first-run tutorial and the points from milestones

## 0.1.3 (20) — 2026-08-01

- Leaderboards are back. Top Shelf had gone quiet for anyone who played before it started ranking your board's face value — your old score was on a bigger scale, so nothing new could ever beat it and your scores were being dropped before they were sent
- All six boards now re-submit your best automatically the next time you open the app, so the cleared boards fill back in without you replaying anything

## 0.1.3 (19) — 2026-08-01

- Internal changes only — corrections to how the games report what's happening under the hood. Nothing changes while you play

## 0.1.3 (18) — 2026-08-01

- Cracking a phrase in Cabana Cipher now earns a celebration: a golden wave
  sweeps the solved letters and spark stars fly before the CRACKED panel lands

## 0.1.3 (17) — 2026-08-01

- The Nightly Nine board now shows what tonight's pour actually is before you earn it, instead of just promising "a reward"
- Every goal on the board says which game it belongs to and wears that game's mark — "finish a sketch" never told you it meant Blueprints
- Vic's pour now lands in his hand at a size you can see, with the prize named right beside it; it used to drift up past the sign and fade before you looked
- The lounge says a reward is waiting before you tap anything — the old glow behind Vic was too faint to notice
- Top Shelf scores the drinks on your board rather than the merges it took to build them, so the number matches what you're looking at

## 0.1.3 (16) — 2026-08-01

- Background music is off for now while the audio gets a proper pass — sound effects are unchanged
- Under the hood: the games now report how they're actually played, plus crash and hang reporting, so we can see where they need work

## 0.1.3 (15) — 2026-08-01

- Blueprints has 30 more pictures to draft — 60 in all — and new 6×6, 7×7 and 9×9 boards fill in the old jump from small straight to large
- Finished blueprints are pinned to a backing sheet so every picture reads against it; the Totem and the Volcano used to disappear into the card
- Finishing a blueprint now carries you straight into the next one you haven't drafted, instead of sending you back to the drawer to hunt for it
- The 9×9 and 10×10 boards are drawn larger with bigger clue numbers, and the drawer button on a board opens the drawer instead of leaving the game
- Top Shelf's leaderboard ranks the board's face value, and the lounge yacht now sits at flagship scale

## 0.1.3 (14) — 2026-08-01

- Cabana Cipher's leaderboard now ranks how many phrases you solve in a row, so it rewards a long run rather than drawing a long phrase
- Luau's leaderboard now ranks your career total across every night, instead of your single best night

## 0.1.3 (13) — 2026-08-01

- Cabana Cipher plays a whole new way: tap any letter and it fills every spot it belongs in — no more picking one tile at a time
- Its phrases are now 300 famous sayings instead of made-up lounge lines, and each board tells you the category it comes from
- Wrong letters strike out on the keyboard so you can see what you have spent
- Lose a phrase and the answer sweeps in before the game-over card, then you get a fresh phrase to play

## 0.1.3 (12) — 2026-08-01

- The shop is sorted into six aisles — the bar, the plants, the regulars, the walls, the floor, and the lagoon — each with its own count of what you own
- Everything is repriced: the room now costs about a third of what it did, so items land steadily instead of stalling for days
- The shop header tells you how many items are within reach and jumps you to the first one; your nearest goal shows how far off it is
- Navigator passages pay points more in line with the other games
- Navigator now tells you where your wallet stands when a voyage ends
- Luau's sunburst bomb got its finishing effects, and a lesson before Night 8 teaches the corner trick

## 0.1.3 (11) — 2026-08-01

- Luau: bend five pieces into an L or a T to forge the sunburst — it blasts everything around it when matched
- Luau: swap the sunburst into another special for three new combos — SHOCKWAVE, DOUBLE BLAST and ERUPTION

## 0.1.3 (10) — 2026-07-31

- Luau: torches caught in a cat's colour wipe or a combo blast now fire their lanes instead of vanishing
- Luau: the coconut swaps in any direction like a normal piece, but only when the swap makes a match — free sliding is gone, and the lesson explains the new rule
- Luau: a swap that makes no match now gives a soft tap instead of the mistake buzz

## 0.1.3 (9) — 2026-07-26

- Testers: WATCH AN AD now fills your lives straight away, so nobody has to sit out a refill

## 0.1.3 (8) — 2026-07-26

- New in Luau: coconuts to float out to sea, taught just before Night 42 and turning up right through the campaign
- Matches now pass straight through a coconut instead of stopping at it

## 0.1.3 (7) — 2026-07-26

- Fixed a bug where the new coconut lesson could lock up and leave Luau unplayable
- Any save already stuck on that lesson repairs itself when you open the game
- The coconut lesson is now over in a single swipe, and the app icon is orange

## 0.1.3 (6) — 2026-07-25

- Fixed a crash that could end a night in Luau when the leaderboard loaded
- New in Luau: a coconut to float out to sea, introduced by its own lesson
- Luau reshuffles again when you run out of matches, and sliding the coconut is free
- Navigator: a cleared constellation no longer ghosts onto the next board

## 0.1.3 (5) — 2026-07-25

- Luau no longer stops to ask whether you want to keep playing, and a swap that doesn't match is free
- Luau teaches as it goes: a lesson before packed sand arrives, and a nudge when you've been staring too long
- Navigator's campaign climbs steadily instead of swinging, and losing no longer sends you back through the easy opening
- The app reopens on the board you left, and every board calls its leaderboard a leaderboard
- Art, sound and feedback polish across Totem, Cipher, Blueprints and the Luau beach

## 0.1.3 (4) — 2026-07-21

- Vic can wave you back: tap WAVE ME BACK WHEN FULL on the OUT OF LIVES
  card and you'll get a notification the moment all five lives are back on
  the bar (if you'd declined notifications, the same row now jumps straight
  to Settings)
- After Vic's third nightly pour the app asks for an App Store rating
  (TestFlight builds suppress the system sheet, so don't expect it here)

## 0.1.3 (3) — 2026-07-21

- Leaving a game brings you back to that game's card on the home rail — no
  more restarting at The Lounge every time

## 0.1.3 (2) — 2026-07-21

- The lounge is free to play now: five lives on the rail, a defeat spends
  one, and one pours back every half hour — run dry and the OUT OF LIVES
  card shows the way back (the ad and gold-bar buttons are coming-soon
  placeholders)
- Every game can now be lost: three wrong cells ruin a Blueprints sketch,
  five wrong letters put a Cipher phrase on ice, and every defeat shows
  the heart it cost
- THE NIGHTLY NINE: one board of nine daily challenges — finish any four
  and Vic glows; tap him and he pours the round
- Luau: squares of four now match, leftover moves pay out at sunrise, and
  a swap that hits nothing costs a move
- On the house: Top Shelf pours your first Depth Charge, a lounge cat
  rescues your worst Luau night, and every game over explains the loss
  and offers a way home
