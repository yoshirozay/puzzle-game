# Testing

The `TikiGamesTests` target is an adversarial unit-test suite for every
pure-logic engine in the app. It was built to attack the engines — hostile
save payloads, boundary values, illegal state-machine calls, resource
exhaustion — not just to confirm the happy path. Building it surfaced and
fixed 36 real engine bugs (commit `d29f9bd`); every one of those fixes keeps
its test as a permanent regression guard.

**Current state: 456 tests, all passing, 0 skipped.** Engine-file coverage
runs 82–99%.

## Running the suite

```sh
cd TikiGames
xcodegen generate            # required after adding/removing test files
xcodebuild test \
  -project TikiGames.xcodeproj \
  -scheme TikiGames \
  -destination "platform=iOS Simulator,name=TikiGames Sim" \
  CODE_SIGNING_ALLOWED=NO
```

Notes:

- Tests are **hosted by the app** and run on the simulator. The app module
  imports as `@testable import Tiki_Lounge` (the product rename makes the
  module `Tiki_Lounge`, not `TikiGames`).
- `project.yml` sets `TEST_HOST` explicitly — XcodeGen would otherwise
  derive it from the target name (`TikiGames.app`) and fail against the
  renamed `Tiki Lounge.app`. Don't remove it.
- One suite at a time: add
  `-only-testing:TikiGamesTests/<SuiteName>` (e.g.
  `-only-testing:TikiGamesTests/SaveStateTests`).
- Coverage: add `-resultBundlePath build/TestResults.xcresult`, then
  `xcrun xccov view --report build/TestResults.xcresult`.
  (The scheme already sets `gatherCoverageData`.)

## What's covered

| File | Tests | Attacks |
|---|---|---|
| `LuauGameAdversarialTests` | 55 | Match-3 engine: swap/resolve state machine, cascade arithmetic, specials, restore sanitization (coordinates, duplicates, score/move clamps, level-save hijack), shuffle behavior, sand-first tutorial contract (scripted per-round jelly, blob-arc continuity, per-beat pop coverage incl. cat-wipe, win-gate, tutorial payloads persist no live run), Lounge Cat placement (gift semantics, special/mask/tutorial/dead-run refusals, real cat-swap integration, save round-trip, DANGER thresholds) |
| `LuauLevelsAdversarialTests` | 50 | All 200 shipped campaign levels (structural integrity sweep), masked-board gravity, bot never stalls / scores lanes correctly, save round-trips, encore latch |
| `NavigatorAdversarialTests` | 55 | Phase guards (peek/advance/back-out exploits), passage banding and salts, tutorial isolation, hostile restore (the negative-`attempt` crash loop) |
| `PlayerStoreAdversarialTests` | 89 | Milestone bit minting (smart-shift), currency, retro-credit thresholds, shop ownership vs placement, NaN position/depth, SwiftData save-state round-trips, legacy migration, Depth Charge + Lounge Cat consumables (once-ever comps, spend floors, relaunch persistence, no cross-wiring), the Nightly Nine (stable roster ids, per-kind tracking through recordRun/grant, local-day roll, 4-of-9 reward with item-then-points pour, one claim per night, relaunch persistence, init-mint isolation, pour-counter bump + relaunch), shared lives pool (refill math, remainder carry, cap clamp, spend floor, full→timer, backwards clock, relaunch, all-six defeat spend + gate, first-spend education one-shot, countdown format, spend event counter, secondsUntilFull, restock-notify plan/apply/background/active), App Store rating ask (due-read truth table, mark flip, constants) |
| `TikiStacksAdversarialTests` | 53 | Totems engine: snap/stack state, streak/combo sequencing, restore overflow clamps, task/popup lifecycle across restarts |
| `BlueprintsAdversarialTests` | 43 | Nonogram clue algebra, puzzle-table integrity, tutorial-script proofs (marks forced when they fire, single-line-solvable runway, card/geometry gates), completion semantics (single ruleset — DRAFT mode removed 2026-07-19), out-of-bounds taps, resume soft-locks, mistake-cap defeat (3rd wrong fill fails once, coach shield, retry reset, relaunch, restore-at-cap, no recordRun on defeat) |
| `CipherAdversarialTests` | 49 | Golden cipher-text pins, house-pour opening reveal (one free most-connected letter per fresh board, never double-served, tutorial T replaces it), always-live cursor (first unsolved tile pre-selected on every board/restore, clears only at completion), hostile restore (negative/huge indices, duplicate keys), unicode input, score clamps, mistake-cap defeat (5th wrong letter fails once, coach shield, retry reset, relaunch, restore-at-cap) |
| `ZombieAdversarialTests` | 47 | Top Shelf engine: merge/slide invariants under random soak, undo, tutorial-mode leaks, restore validation and animation-state hygiene, Depth Charge detonation (surgical 2×2, anchor clamps, dead-run/tutorial/empty-target refusals, undo-snapshot kill, DANGER thresholds) |

## Conventions — read before adding tests

- **Swift Testing**, not XCTest: `@Test`, `#expect`, `#require`,
  parameterized `@Test(arguments:)`.
- Every test carries a one-line `// guards: <invariant>` comment stating
  the behavior it protects. If you can't phrase the invariant, the test
  probably isn't earning its place.
- Tests that pinned a fixed bug are tagged `// REGRESSION(<slug>)` with a
  short account of the original bug. Never delete or weaken these.
- Suites touching `@MainActor` app types (`PlayerStore`, the game engines
  via views) are `@MainActor`. Engine classes are `@Observable`; a fresh
  instance per test is a complete reset for the pure engines.
- **Isolation is non-negotiable.** Anything touching `UserDefaults` or
  SwiftData must snapshot/restore around each test (see `DefaultsSnapshot`
  in `PlayerStoreAdversarialTests`). Multi-launch scenarios use
  `PlayerStore(url:)` with a per-test temp file — never the app's real
  `default.store` (an early revision corrupted it mid-suite).
- **Determinism.** No sleeps, no timing races. Random engine behavior is
  tested via invariants that hold for every outcome over bounded
  iterations, or via the engines' seeded `#if DEBUG` test hooks.
- **No death tests.** Swift Testing can't catch `preconditionFailure` on
  iOS, so a probe that would trap must first be fixed in the product
  (guard/clamp/reject), then the test asserts the graceful path. That is
  how all the former trap bugs are pinned.

## Known storage caveat

The SQLite-backed SwiftData store truncates saved TEXT at an embedded NUL
byte. This is pinned as *graceful degradation, not a bug*
(`nulBytePayloadDegradesGracefully`): legitimate payloads are game-encoded
JSON and can never contain NUL. Don't "fix" the round-trip test to demand
byte-exact NUL preservation.

## Fast iteration without the simulator

The engines are pure Swift, so a scratch SwiftPM package (library target
named `Tiki_Lounge` containing copies of the engine sources + your test
file, `swiftLanguageMode(.v6)`, debug config so `#if DEBUG` hooks compile)
runs a module's suite in under a second with `swift test` on macOS. Copy
results back and re-verify on the simulator before committing — macOS
CoreData/SQLite behavior differs in corners (see the NUL caveat), and one
past test passed on macOS while failing on-sim.
