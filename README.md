# Tiki Lounge

Six puzzles. One lounge.

A free offline puzzle bundle for iPhone and iPad. You play, you earn points, you decorate Vic's bar. The room grows with you. No account. No forced daily login. Open it on a plane.

This repo is the public snapshot: the [landing page](https://tiki-lounge.vercel.app/) and the story. The iOS app source is not here.

[Play the site](https://tiki-lounge.vercel.app/) · [App Store](https://apps.apple.com/search?term=Tiki%20Lounge%20Offline%20Games) · iPhone · iPad · Offline · Free

<p align="center">
  <img src="assets/brand/app-icon.png" width="120" alt="Tiki Lounge icon">
</p>

<p align="center">
  <img src="assets/shots-web/02-lounge.jpg" width="160" alt="The lounge">
  <img src="assets/shots-web/04-luau.jpg" width="160" alt="Luau">
  <img src="assets/shots-web/03-stacks.jpg" width="160" alt="Totem">
  <img src="assets/shots-web/05-zombie.jpg" width="160" alt="Top Shelf">
</p>
<p align="center">
  <img src="assets/shots-web/06-cipher.jpg" width="160" alt="Cabana Cipher">
  <img src="assets/shots-web/07-blueprints.jpg" width="160" alt="Blueprints">
  <img src="assets/shots-web/08-navigator.jpg" width="160" alt="Navigator">
</p>

## The games

The home screen is a hanging-sign rail. Swipe. Lounge and leaderboards sit to the left of Luau. Cold start lands on Luau.

**Luau** is match-3. Swap pieces to match three or more. Specials clear big chunks of the board. This is the deep one: a 200-level campaign. The first card a new player meets.

**Totem** is a block puzzle. Drop blocks. Clear full lines. The lagoon behind the board deepens the further you go.

**Top Shelf** is merge, 2048-style. Swipe matching cocktails together and climb the shelf.

**Cabana Cipher** is a letter puzzle. Decode a phrase one letter at a time. Vic will hint if you get stuck.

**Blueprints** is a picture grid. The numbers tell you which cells to shade. Fill it right and the picture shows up.

**Navigator** is memory. Watch the star pattern, then tap it back. Win and the constellation draws itself.

## The lounge

The lounge is the room you come home to. Winning any game pays points into one wallet. Spend them in Vic's shop and the pieces drop into the room. Drag them around. The night settles in as you go.

Vic is the bartender. He is always there. He runs the shop and the Nightly Nine.

The shop is the room, priced. A flaming mug in his hand. Fronds in the corners. The back bar. A sunset that never quite sets. A suspicious cat. Each row has Vic's line under it ("THE HOUSE POUR, ON FIRE"). Buy something and it pops into place with a spring.

**The Nightly Nine.** Nine small goals each day, spread across the games. Finish any four and Vic pours a reward: fifty points, or a shop item you do not own yet.

## Lives

Five hearts. One pool for every game. Lose a round, lose a heart. One heart comes back every 30 minutes, on the wall clock, even if the app is closed.

When you are empty, the out-of-lives sheet sits on the board with a live countdown. A life landing while it is open flips the sheet so you can play immediately. The tutorial does not spend a heart.

There is no buy-back. Ads and gold bars on that sheet are "coming soon" on purpose. You wait, or you come back later.

## Leaderboards

One board per game, on its own hanging sign. Game Center underneath, a themed screen on top. Each game has its own wardrobe: Totem's carved heads on the night lagoon, Top Shelf's bottles on the back bar, Luau's match-3 world, and so on.

The skeleton is the same on every board. Header, podium for the top three, plank slats for the rest, a pinned YOU bar at the bottom. Tap a row and that player's card opens. Scores queue offline and submit when you are back on the network.

You can play the whole app without signing in. The boards just wait.

## Custom assets

Everything on screen is original flat-vector illustration. Mid-century, hard geometric shadows, no gradients. Sunset coral, lagoon teal, bamboo cream, driftwood, torchlight. Night shifts to twilight indigo and midnight lagoon.

The site uses the same hanging signs as the home screen, and a web port of Totem's lagoon behind the rail.

## The story

I wanted an offline puzzle app that felt like a place, not a folder of clones. The "Offline Games" listings on the store are thirty generic boards. This is six games and a bartender.

I built the iOS app, the lounge, and the site.

## What's in here

```
TikiGames/   the iPhone app (team ID, bundle ID, and Game Center board IDs stripped)
index.html   the landing page (also at https://tiki-lounge.vercel.app/)
```

Open the site with:

```bash
python3 -m http.server 8765
```

Then go to [http://localhost:8765](http://localhost:8765).

The iOS project opens in Xcode. Set your own team, bundle ID, and App Store Connect leaderboard IDs before you run it on a device. GameAnalytics keys go in a local `TikiGames/Secrets.xcconfig` that is not in this repo.

The Android port and the App Store submission kit are not here.

## Status

On the App Store as **Tiki Lounge: Offline Games**. The lounge and all six games are on the rail.

## License

All rights reserved. The app is the product. Ask before you ship a copy of it.
