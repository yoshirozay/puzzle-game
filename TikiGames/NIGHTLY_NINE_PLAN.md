# THE NIGHTLY NINE — plan & handoff

Status date: **2026-07-20** (updated after the ship-to-main session).
Owner of record: Carson. This doc is the pickup point for any fresh session.

## 1. Where things stand

- **SHIPPED TO MAIN.** Commit `195a243` = new main tip (origin/main
  `ca94a6a` → `195a243` ff; branch `luau-onboarding` pushed at the same
  tip). Exactly the five Nightly Nine files, 642 insertions. Suite
  re-verified green immediately before the commit: **401 tests / 70
  suites** (TESTING.md is current).
- Remaining dirt on the tree belongs to the concurrent analytics session
  (`Analytics.swift`, `TikiGamesApp.swift`, `project.yml`,
  `ContentView.swift`, testflight skill, `RELEASE_NOTES.md`) — do NOT
  sweep those without checking that session's state.
- **Device install DONE 2026-07-20**: Debug build of the shipped tree
  installed on the iPhone 17 (`6BB56801-…`) and launched staged with
  `{"TIKI_BG":"lounge","TIKI_NIGHTLY":"4"}` — the pour-ready board is
  waiting for Carson's feel round. Re-stage anytime with the launch
  command in §5. NOT yet on TestFlight (`/testflight` when Carson wants
  testers on it).
- **2026-07-20 later — VIC-AS-DOOR REDESIGN, UNCOMMITTED** (Carson: "Vic
  glows when a reward is available; tap Vic → daily rewards screen"; a
  spin-the-wheel idea was floated and dropped in the same exchange).
  `LoungeView.swift` + `GamePickerView.swift` (picker banner, Carson's
  follow-up ask), view layer; suite re-run green 401/70 after each.
  Chip + entry auto-claim removed, glow/pulse + tap-to-board + POUR THE
  ROUND manual claim + one-shot discovery toast added, and the lounge
  picker card wears a pulsing gold VIC'S READY TO POUR banner while the
  pour is unclaimed (details in §3). Sim-verified: glow on/off, pulse
  oscillation (video-measured), card CTA, claim beat + caption, hint on
  second visit, banner on/off + pulse. Device-installed for Carson's
  verdict — tap-on-Vic physical feel is the one thing sim can't prove.
  Ship after his verdict.

## 2. What the system is (decisions ledger — do not relitigate casually)

Daily missions, Pokémon-research-style, per Carson's pitch + agreed shaping:

- **One fixed board of nine challenges, forever.** No rotating content, no
  authoring treadmill. Progress resets each **local calendar day**.
- **Any 4 of 9** → Vic pours in the lounge (the earned evolution of the
  "ON THE HOUSE" beat). The pour **prefers refilling an empty introduced
  comp slot** (Depth Charge / Lounge Cat, cap 1 each); **falls back to +50
  wallet points** when slots are full, so a finished board always pays.
- **One pour per night. No streaks, no expiry, no notifications** — missing
  a day costs nothing. This is the "quiet generosity" principle: Carson
  rejected pressure monetization AND pressure retention; both stay out.
- **Cap 1 per comp item** — the pour is a regen, not a stockpile, so Game
  Center boards stay skill contests (decided during the Depth Charge work).
- ~~Everything free. No IAP.~~ **AMENDED 2026-07-21 (Carson's F2P pivot):**
  the app is free-to-play with a shared five-life pool — a defeat spends
  one, +1 refills per 30 minutes (the lives ship, main `5451872`).
  Out-of-lives recovery will be a rewarded ad or a gold-bar purchase;
  both are inert placeholder buttons today. The pour itself stays free
  and unmonetized, and the rest of the quiet-generosity canon (no
  streaks, no expiry, no notifications) stands.
- Roster shape: **one challenge per game + three connectors**, so "any
  four" naturally tours the bundle without mandating all six.

The board (ids are PERSISTED in saves — never rename/reorder; titles/targets
are tunable):

| id | title | kind | target |
|---|---|---|---|
| topShelf500 | CLOSE A 500 TAB ON THE TOP SHELF | runScore(.zombie) | 500 |
| totem150 | STACK 150 AT THE TOTEM | runScore(.tikiStacks) | 150 |
| luauNight | CLEAR A NIGHT AT THE LUAU | luauWin | 1 |
| navigator3 | CHART 3 PASSAGES | gameRuns(.navigator) | 3 |
| blueprintsSketch | FINISH A SKETCH | gameRuns(.blueprints) | 1 |
| cipherPhrase | CRACK A CIPHER | gameRuns(.cabanaCipher) | 1 |
| rounds3 | MAKE THE ROUNDS — 3 GAMES | distinctGames | 3 |
| busy4 | KEEP IT GOING — 4 ROUNDS | anyRuns | 4 |
| wallet60 | PAD THE WALLET — 60 POINTS | pointsEarned | 60 |

## 3. Architecture map

- **Engine — `PlayerStore.swift`, MARK "the Nightly Nine"**: challenge
  table (`nightlyChallenges`, `nightlyGoal=4`, `nightlyPointsPour=50`),
  `NightlyState` (dayStamp / progress / gamesMask / rewardClaimed) stored
  as JSON in a **`GameSaveState` row, gameID "nightlyNine"** — no schema
  migration. Day-roll happens on read (`nightlyState(now:)`).
- **Tracking is 100% inside store choke points.** `recordRun(game:score:
  earnScore:wonLevel:now:)` feeds every kind (all six games call recordRun:
  Blueprints per solved sketch, Cipher per solved phrase, Navigator per
  passage won); `grant(points:)` feeds wallet60. Games carry NO mission
  code — the only game-side line is LuauView passing
  `wonLevel: game.didWinLevel`. `nightlyTrackingEnabled` keeps init-time
  retro-credit mints out of tonight's wallet counter.
- **Mirrors** for UI: `nightlyProgress` / `nightlyCompleted` /
  `nightlyRewardClaimed`, plus `refreshNightlyMirrors(now:)` — the lounge
  calls it on entry because the day can roll while the app idles.
- **Reward**: `claimNightlyReward(now:)` — ≥4 done + unclaimed tonight →
  `.item(game)` from `dailyCompPool()` else `.points(50)`. The points path
  reloads state after `grant()` (grant writes its own nightly bump; saving
  a stale copy would clobber it).
- **Lounge UI — `LoungeView.swift` (REDESIGNED 2026-07-20, Carson's call:
  "Vic glows when a reward is available; tapping Vic opens the board")**:
  the TONIGHT chrome chip is GONE — **Vic is the board's door**. When ≥4
  done + unclaimed, `vicGlow` breathes behind him (gold radial on the
  30 fps world clock, ~2.6 s period; Reduce Motion pins a steady
  mid-breath — the paused TimelineView would otherwise freeze it
  mid-swing). Tapping Vic (once the welcome mug is claimed; before that
  his tap still belongs to the FTUE gift) opens `missionsCard`, whose
  footer becomes a gold **POUR THE ROUND** button when ready (BACK TO THE
  ROOM demoted to a quiet outline); `claimAndPour()` closes the card,
  waits 400 ms, then plays the beat (`DailyPourFloat` at Vic's hand +
  `MilestoneToast` caption). **Auto-claim on entry is REMOVED** — entry
  only refreshes mirrors; an unclaimed pour survives all night and is
  lost at day-roll (accepted: quiet generosity, there's always
  tomorrow's board). Discovery: one-shot "TAP VIC FOR TONIGHT'S NINE"
  toast (UserDefaults `tikiNightlyHintSeen`) at 3.6 s on the first
  visit where nothing else owns the moment (defers past FTUE/banner/
  other toasts to the next visit). VoiceOver: Vic's tap target is
  labeled "The Nightly Nine" with tonight's progress as its value. All
  three lounge toasts still sit at **top padding 232**.
- **Picker banner — `GamePickerView.swift` (same day, Carson's ask)**:
  while the pour is ready, the lounge card wears a pulsing gold
  "VIC'S READY TO POUR" capsule (`LoungePourBanner`, top of the crest
  window; self-clocked 30 fps TimelineView like the crest, 2.6 s
  breathe on scale + glow shadow, Reduce Motion holds mid-breath;
  a11y-hidden — the card's VoiceOver label says "Vic's ready to pour
  tonight's round" instead). `enter()` refreshes the nightly mirrors so
  a day-roll while idle can't leave a stale banner; the banner tracks
  the store mirrors reactively, so completing the 4th challenge shows
  it on return to the picker and claiming clears it. Handoff chain:
  card banner → Vic's glow → POUR THE ROUND.
- **Comps this feeds** (already ON MAIN, `96d2820`): Depth Charge
  (ZombieGame/ZombieView) and Lounge Cat (LuauGame/LuauView), their danger
  intros, permanent ×N chips, drag/tap reticles.

## 4. How to verify

- Full suite: `cd TikiGames && xcodegen generate && xcodebuild test
  -project TikiGames.xcodeproj -scheme TikiGames -destination "platform=iOS
  Simulator,name=TikiGames Sim" CODE_SIGNING_ALLOWED=NO` → expect 401/70.
- Staging hooks (env, all DEBUG; pair with `SIMCTL_CHILD_TIKI_BG=lounge`):
  - `TIKI_NIGHTLY=<n>` — fresh board with n challenges done, claim cleared,
    comp slots emptied, coach + discovery hint suppressed. `n>=4` → Vic
    glows (claim is manual now).
  - `TIKI_NIGHTLY_OPEN=1` — opens the board card (simctl can't tap Vic).
  - `TIKI_NIGHTLY_CLAIM=1` — fires the claim beat at ~1.6 s (pair with
    `TIKI_NIGHTLY=4`; simctl can't tap POUR THE ROUND).
  - Picker banner staging: the TIKI_NIGHTLY hook only runs on LOUNGE
    appear, so stage in two launches — `TIKI_BG=lounge TIKI_NIGHTLY=4`
    first (persists), then relaunch with NO env → picker shows the
    banner on the lounge card.
  - Comps: `TIKI_ZOMBIE_DANGER=1|2`, `TIKI_LUAU_CAT=1|2` (see their code).
- Sim etiquette: **check `xcrun simctl list devices` for booted sims
  first** — concurrent sessions stage on "TikiGames Sim"; use "TikiGames
  SE" (`0C4B8E38-…`) when the main sim is busy.

## 5. Next work, in order

1. ~~**Ship to main.**~~ DONE 2026-07-20 (`195a243`, see §1).
   `/testflight` still pending — run it when Carson wants testers on it
   (policy: build-number bump + release notes — see
   `.claude/skills/testflight`).
2. **Device feel round — Carson's judgment is the open item.** The build
   is installed and staged (see §1); judge on iPhone — pour beat timing,
   card readability, chip placement, whether challenge targets feel
   commute-sized. Expect verdicts to adjust copy/targets. Re-stage with:
   `xcrun devicectl device process launch --device 6BB56801-0376-504F-977A-DD1D892ED82A \
   --environment-variables '{"TIKI_BG":"lounge","TIKI_NIGHTLY":"4"}' com.example.tikilounge`.
3. **Polish backlog** (not started):
   - ~~World-space chalkboard next to Vic as the board's home~~ SUPERSEDED
     2026-07-20: Vic himself is the door (glow + tap). A chalkboard could
     still return someday as pure set dressing, but the entry problem is
     solved — don't rebuild it casually.
   - A quiet **in-game tick** when a challenge completes mid-run (games
     currently show nothing; the board only updates in the lounge). Keep it
     one toast max, house voice.
   - Card polish: per-row game icons, maybe progress bars.
4. **Roster growth — the post-launch arc.** The pour pool only spans
   zombie+luau until more games grow comp items. Sketches (each needs the
   full pattern: danger intro, cap-1 slot chip, placement/use UX, tests):
   - Navigator: a one-shot **extra-peek token** (assists-stay-free rule
     means it must also stay earnable/free forever).
   - Blueprints: **"Vic marks a cell"** (one free correct cell).
   - Totem: a **piece re-roll** (swap one tray piece).
   - Cipher: already has the free house pour opener — maybe a **second
     Vic's Tip** charge.
   When items exist, consider per-game challenge/item pairing on the board.
5. **Tuning knobs** (all constants, safe to tweak): challenge targets
   (table above), `nightlyGoal` (4), `nightlyPointsPour` (50),
   `dailyCompCap` (1), lounge beat timing (3400ms), toast band (232).

## 6. Gotchas (each cost real time — read before touching)

- Swift `switch` expressions can't be inline call arguments — assign first.
- `grant()` has **no now-injection**: tests mixing injected days with
  grant-driven asserts must anchor runs to real-today (noon).
- Init's mirror refresh uses the **real clock** — relaunch tests must
  re-call `refreshNightlyMirrors(now: <injected day>)` before asserting.
- Four cipher runs only complete TWO challenges — a genuine 4-done test
  fixture is bp + cipher + luau(won) + zombie(500) (see `playFourDone`).
- `MilestoneToast` has a built-in **0.35s entrance delay** — early
  screenshots miss it.
- Worktrees need `xcodegen generate` (the .xcodeproj is gitignored).
- `grep available` also matches "unavailable" — `grep -v unavailable` first.
- TWO+ sessions share this repo — `git status` before commits, expect
  files to move underneath you, never sweep another session's WIP silently.
- **A staged save is NOT a played save**: staging hooks set
  `loungeOnboardingSeen` without claiming the welcome mug, so Carson's
  device save has no `flamingMug` in `placedItemIDs`. v1 gated Vic's
  board tap on the mug being placed → his taps opened the SHOP (the old
  ghost grammar). Fix: routing keys on `coachWelcomeActive` only — coach
  beat → shop, any other time → board. Corollary: `TIKI_NIGHTLY_OPEN`
  calls `openMissions()` directly and NEVER exercises the real tap
  routing (simctl can't tap; AppleScript needs an Apple Events grant we
  don't have) — hit-target changes are device-round-only territory.

## 7. Related

- Memory notes (deep history): `~/.claude/projects/-Users-carsonosullivan-Projects/memory/tiki-games-project.md` and `tiki-monetization-plan.md`.
- `TESTING.md` — suite conventions (Swift Testing, `// guards:` comments).
- The comp pattern's precedents: `ZombieView` (Depth Charge) and `LuauView`
  (Lounge Cat) are the reference implementations for any new roster item.
