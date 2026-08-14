# THE DAILY — plan & handoff

Status date: **2026-07-24**. Owner of record: Carson.
Status: **NOT STARTED.** This doc is the spec; nothing is built.

Successor concept to the Nightly Nine, which stays exactly as it is — the two
systems are complementary and §3 spells out how they interact.

## 1. The problem this solves

Three verified gaps, all pointing at the same hole:

- **Nothing in the app makes tonight different from last night.** The Nightly
  Nine is a chore list ("play 3 games"), not content. The only daily-cadence
  mechanic anywhere in the bundle is Cipher's once-per-calendar-day free Vic's
  Tip (`lastFreeHintDay`).
- **The leaderboards measure noise.** `GameCenter.swift` is 385 lines of real
  work — six boards, offline queue, high-water dedupe, throttled mid-run live
  push, cross-game player card, a teaser in every game-over panel. Every one of
  those boards ranks players against **different randomly-generated boards**.
  The stadium is built; no shared match is being played in it.
- **Lives have no price.** Lives are the monetization strategy, but waiting 30
  minutes currently costs the player nothing — tomorrow's lounge is identical to
  tonight's, nothing expires. "Watch an ad" competes with "come back later," and
  later always wins. **A daily is the first thing in the app that expires.**

## 2. Design thesis

**The daily is a seed, not a game.** No new engines, no new art, no seventh
game. Each existing game gains one extra entry point where the RNG derives from
the date instead of the clock, and one run is recorded as the official score.

Free play is untouched everywhere: unlimited attempts, life-gated on defeat,
exactly as it ships today. The daily is purely additive.

## 3. Decisions ledger — do not relitigate casually

Settled in the 2026-07-24 product session. Each of these has a reason attached;
overturn one only with a better reason, not a fresh preference.

| # | Decision | Why |
|---|---|---|
| D1 | **The daily never costs a life.** | It is the funnel's front door. Gating it means gating your own session starts. |
| D2 | **One scored attempt. Retries are never purchasable.** | The moment a second attempt is buyable, the nightly board becomes a spending board and the share card means nothing. Sell lives for free play; keep the contest clean. |
| D3 | **Completing the daily pays +1 life** (capped; falls back to points at cap, reusing the pour's fallback shape). | Hands the player currency at peak engagement, right before they roll into life-gated free play. |
| D4 | **At 0 lives the daily is still open.** | Fixes a live bug — see D11. |
| D5 | **Every game eventually has a daily; exactly one is *featured* per night.** | Resolves the real tension: a rotating single daily breaks habits for players who dislike tonight's game; six simultaneous dailies is a second chore list. All available, one headlined. |
| D6 | **Default state shows ONE thing to do.** The other dailies are discoverable, not demanded. | This is what keeps D5 from becoming a chore list. |
| D7 | **v1 ships Cipher + Navigator only.** Architecture supports six. | Ten-stage pipeline per surface; validate that anyone returns for one before building four more. |
| D8 | **The daily window is a fixed GLOBAL window, not local midnight.** | Recurring Game Center leaderboards use a global occurrence boundary. Seeding from local date while submitting to a global board means Auckland and LA solve *different puzzles* on the *same leaderboard*. Broken contest. The Nightly Nine keeps its local-day roll, separately. |
| D9 | **The daily is more forgiving *inside* the attempt than free play.** | Wordle gives six guesses precisely because you get one shot at the day. Blowing the night in 90 seconds reads as punishing, not special — and a cheated player churns instead of converting. |
| D10 | **No staggered per-game windows.** One global window, everyone on the same night. | Staggering costs the shared-moment property that makes dailies work, to solve a load-balancing problem we don't have. |
| D11 | **Fix the Nightly Nine lives deadlock regardless of what else ships.** | All nine challenges require playing a game (`PlayerStore.swift:713`); `isOutOfLives` hard-gates every launch (`GamePickerView.swift:815`). At 0 lives tonight's board is frozen and the pour expires at day-roll with no recourse. Retention hook currently sits behind the monetization wall. |
| D12 | **No second picker screen.** Daily state lives on the existing picker cards. | Reuses the proven `LoungePourBanner` pattern; avoids two near-identical navigation surfaces. |
| D13 | **No countdown during gameplay.** | A ticking clock contradicts the unhurried house tone and puts time pressure on games that deliberately have none. Picker and game-over only. |

## 4. Scope — v1

**In:**

1. Global day-window primitive + date-derived seeding.
2. Daily Cipher and daily Navigator (seed, one-attempt persistence, forgiveness tuning).
3. Two recurring Game Center leaderboards; per-occurrence dedupe fix.
4. The picker pill (`TONIGHT'S BOARD — OPEN` → `LAST CALL — 47 MIN` → result).
5. Lit-sign treatment on tonight's featured card.
6. Share card.
7. +1 life on completion.
8. The D11 deadlock fix.

**Out (v1.x or later):** Live Activity, dailies for the other four games, friends
leaderboard scoping, achievements, past-occurrence archive screen.

## 5. Architecture map

**Day window — new, tiny.** One source of truth:

```
dayIndex = floor((now - dailyEpoch) / 86_400)   // UTC, fixed launch epoch
```

`dailyEpoch` is a single constant, chosen to align with the recurring
leaderboard's configured occurrence start in App Store Connect. Everything —
seed, one-attempt roll, pill countdown — reads this one value. Nothing reads
`Calendar.isDate(inSameDayAs:)`; that stays the Nightly Nine's mechanism (D8).

**Seeding — both engines already have what's needed.**

- **Navigator**: `NavRandom` (SplitMix64) at `NavigatorGame.swift:464` is already
  deterministic and attempt-salted. Feed it `dayIndex` instead of the attempt
  salt and fix the level sequence. Procedurally infinite — no content ceiling.
- **Cipher**: `begin(index:)` sets `phraseIndex` and calls `buildMapping()`,
  which derives the substitution from the index (`CipherGame.swift:226`). Daily
  = `begin(index: dayIndex % 96)` **with `buildMapping` seeded from `dayIndex`
  rather than `phraseIndex`**, so day 97 re-uses phrase 1 as a genuinely fresh
  cipher. See §8 risk 1 — this is the content-ceiling mitigation, not a cure.

**Persistence — zero schema change.** Reuse the Nightly Nine's pattern: a
`GameSaveState` row keyed by a reserved `gameID` (`nightlyRowID` precedent at
`PlayerStore.swift:757`), JSON payload, roll-on-read.

```
gameID: "daily.cabanaCipher" / "daily.navigator"
payload: { dayIndex, attempted: Bool, score: Int?, completed: Bool }
```

Separate rows from free play, so `saveState(for:)`/`loadState(for:)` on the game
itself are untouched and a daily in progress can never clobber a campaign save.
**Backgrounding mid-daily resumes, never forfeits** — a phone call must not cost
someone their night.

**Leaderboards — recurring, not one-per-day.** Game Center recurring leaderboards
reset on a configured schedule with no gaps (5-minute minimum, 30-day maximum
recurrence). One leaderboard per game set to daily recurrence — **2 new boards in
v1, 6 eventually**, not 365/year. The 500-board cap is a non-issue.

`GameCenter.leaderboardID(for:)` (`GameCenter.swift:18`) becomes a two-axis
lookup: `(game, .allTime | .daily)`.

**⚠ The high-water bug — must fix, not optional.** `pushPending` keeps a
per-player *lifetime* high-water and drops anything that can't beat it, with the
reasoning *"Game Center keeps best-ever and would ignore them anyway."* That is
true for classic boards and **false for recurring ones**, which keep the best
score *within the current occurrence*. Left as-is, any night where a player
scores below their all-time best is silently dropped locally and they never
appear on tonight's board. Someone who had one great night last month becomes
permanently invisible. **Key the high-water per occurrence.**

Submission otherwise unchanged — the class-method `submitScore` routes to
whichever occurrence is active. The existing offline queue carries over, and the
mid-run live push gets *better* here: watching tonight's board fill in real time
is genuinely exciting in a way an all-time board never is.

**Scoring.**

- Navigator: passages charted (already the board's metric).
- Cipher: `completionScore` — rewards fewer mistakes and hints. **No timer**
  (tone; see D13).

## 6. UX spec

**The pill** — picker and game-over only (D13). Three states:

| State | Copy | When |
|---|---|---|
| Open | `TONIGHT'S BOARD — OPEN` | daily unplayed, > ~2h left |
| Last call | `LAST CALL — 47 MIN` (live countdown) | daily unplayed, final stretch |
| Done | `PASSAGE 14 · #340 · LAST CALL 3:20` | daily played |

A 24-hour countdown is wallpaper for 23 of its 24 hours. Urgency concentrates in
the last stretch, and "Last Call" is literally a bar term. Once played, the pill
becomes a **trophy, not a to-do**.

**Card treatment.** Tonight's featured game's hanging sign is **lit**; the others
are dark. No text, instantly readable, and the theme does the work. Reuse
`LoungePourBanner`'s pulse machinery (30 fps self-clocked TimelineView, Reduce
Motion holds mid-breath). Tapping the pill snaps the existing rail to tonight's
card — it does not open a new surface (D12).

**Share card.** Spoiler-free glyph row + Vic's one-line verdict, on a matchbook
or coaster. This is the app's only organic acquisition loop and currently there
is **not a single `ShareLink` anywhere in the codebase**. Offered at the daily's
result beat, never nagged.

## 7. Open questions — need Carson's call

1. **Featured rotation order.** Fixed weekday map ("Tuesday is Cipher night") or
   Vic picks? Fixed is more habit-forming and more legible; irrelevant until
   there are more than two dailies.
2. **Cipher's daily mistake budget.** Free play is 5. Daily should be looser
   (D9) — 7? Or unlimited-with-score-penalty, which guarantees everyone finishes
   and turns the board into a cleanliness tiebreak. Leaning unlimited-with-
   penalty: more generous, more on-doctrine, still a real contest.
3. **Navigator's daily mistake budget.** Recommend keeping 3 — the whole-run
   stakes *are* the contest in a one-shot format. (This is the flaw-becomes-
   feature case: the same harshness that should be softened in free play is
   correct here.)
4. **Does the daily credit the Nightly Nine?** Recommend yes, via the normal
   `recordRun` path — it's one of nine, not a trivialization. Note defeats
   already never `recordRun`, so a failed daily credits nothing.
5. **First-run exposure.** Does a brand-new player see the daily during FTUE, or
   only after the lounge welcome-mug beat? Leaning after — one appointment at a
   time.

## 8. Risks

1. **Cipher hits a content wall at day 97.** 96 phrases; day-seeded mappings keep
   repeats fresh as *puzzles* but the plaintext repeats. Navigator is
   procedurally infinite and has no such wall — which is a real argument for
   Navigator being the flagship daily and Cipher the supporting one. Mitigation
   is content (more phrases), not code.
2. **D3's life payout could undercut the economy** if the daily becomes a
   reliable life faucet. Bounded at +1/day and only on completion; watch whether
   players stop running dry at all. Pure tuning constant.
3. **The global window will confuse someone.** A player at 11pm local may see the
   board roll at an unintuitive hour. Accepted — the alternative (D8) is a
   broken contest. Copy should say when it rolls, not assume midnight.
4. **Two "daily" systems is a naming hazard.** The Nightly Nine and the Daily
   both roll nightly, on *different* schedules (D8). They need clearly distinct
   names and visual treatments in-app or players will conflate them. Worth
   deciding the house names before building UI.
5. **A daily global board is still demoralizing** — nobody outside the top few
   hundred feels anything. Friends scoping is what makes this spread ("I beat my
   brother at Cipher night") and it's out of v1 scope. Consider pulling it in.

## 9. How to verify

Per house method — every claim from a captured frame, staged via env hooks.

Proposed hooks (DEBUG, matching `TIKI_NIGHTLY_*` conventions):

- `TIKI_DAILY_DAY=<n>` — force a `dayIndex`, so a seed is reproducible and the
  day-roll is testable without waiting.
- `TIKI_DAILY_STATE=open|lastcall|done` — stage each pill state.
- `TIKI_DAILY_PLAYED=1` — mark tonight's attempt spent.

Test coverage (Swift Testing, `// guards:` comments per `TESTING.md`):

- Same `dayIndex` → identical board, both games. Different `dayIndex` → different.
- One-attempt enforcement survives force-quit mid-run.
- Backgrounding mid-daily resumes rather than forfeits.
- The daily never decrements lives, including on defeat.
- At 0 lives the daily still launches (D4) **and** the Nightly Nine deadlock is
  gone (D11).
- Per-occurrence high-water: a score below lifetime best still submits.
- Day-roll while the app idles clears the pill and re-arms the attempt.

## 10. Related

- `NIGHTLY_NINE_PLAN.md` — the complementary system; its decisions ledger (§2)
  still stands. The quiet-generosity doctrine (nothing punishes absence) is
  compatible with everything here: a daily is a **pull**, not a push.
- `NEW_GAME_BLUEPRINT.md` — not applicable; the daily adds no games (§2).
- `GameCenter.swift` — the existing board plumbing this activates.
- `PROGRESSION_PLAN.md` §4's economy ceiling figures are **stale** (that doc
  predates the west wing and Lagoon catalog rows; real ceiling is now low-40,000s
  points, not 12,780). Do not plan against its numbers.
