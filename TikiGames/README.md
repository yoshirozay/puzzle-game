# TikiGames (iOS)

Source of truth for **Tiki Lounge** product behavior. Xcode project generated from
`project.yml` via [xcodegen](https://github.com/yonaskolb/XcodeGen).

## Quick start

```bash
brew install xcodegen   # once
cd TikiGames
xcodegen generate
open TikiGames.xcodeproj
```

Bundle id: `com.example.tikilounge`. Signing team must be set for device builds.

Leaderboard IDs in `TikiGames/GameCenter.swift` are placeholders (`YOUR_LEADERBOARD_*`). Put your App Store Connect IDs there. GameAnalytics keys go in a gitignored `Secrets.xcconfig` — see `Config.xcconfig`.

## Layout

```
TikiGames/
  project.yml              XcodeGen source of truth
  TikiGames/               App sources + Assets.xcassets
  TikiGamesTests/          Adversarial engine tests
  tools/                   LevelForge, grok-delegate helpers
  *_PLAN.md / *_RUBRIC.md  Product quality bars
  ANDROID_PORT_PLAN.md     Android twin inventory
  RELEASE_NOTES.md         TestFlight notes
  TESTING.md               How we test
```

## Architecture (sketch)

| Layer | Examples |
|-------|----------|
| Engines (pure) | `*Game.swift` — no SwiftUI types |
| Views | `*View.swift` — boards, coaches, chrome |
| Economy | `PlayerStore` — lives, points, comps, mid-run |
| Feel | `TikiSound`, SoftPress, scenery canvases |
| Meta | Lounge, Nightly Nine, picker rail |

## Key docs

See monorepo [DOCUMENTATION.md](../DOCUMENTATION.md) for the full map.

| Doc | Use |
|-----|-----|
| `ONBOARDING_RUBRIC.md` | First-run coach bar |
| `GAME_FEEL_RUBRIC.md` | Motion / haptics |
| `PICKER_SPEC.md` | Home rail |
| `PROGRESSION_PLAN.md` | Economy |
| `NEW_GAME_BLUEPRINT.md` | Adding a game |
| `ANDROID_PORT_PLAN.md` | What Android must twin |

## Tests

```bash
# Prefer Xcode Test navigator, or:
xcodebuild test -scheme TikiGames -destination 'platform=iOS Simulator,name=iPhone 16'
```

Adversarial suites live in `TikiGamesTests/*AdversarialTests.swift`.

## Android twin

Compose port: `../android/`. Architecture: `../android/ARCHITECTURE.md`.
Agents: `../AGENTS.md`.
