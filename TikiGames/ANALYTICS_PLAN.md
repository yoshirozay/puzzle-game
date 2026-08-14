# Tiki Lounge — Analytics Strategy

Graded against `ANALYTICS_RUBRIC.md`. Current version: **v11**.

Target: GameAnalytics **free** plan. Nothing here needs PipelineIQ ($499/mo),
SegmentIQ Pro, or AnalyticsIQ Pro ($49/mo).

---

## 1. What the free plan actually gives us

Verified against GA's docs, not assumed:

| Capability | Free? | Consequence |
|---|---|---|
| AnalyticsIQ dashboards, retention, cohorts | ✅ | DAU/MAU/D1/D7/D30 come free from `Analytics.start()` alone |
| Funnels (design + resource + progression steps) | ✅ | Our funnels are buildable |
| **Strict-order** funnels | ❌ SegmentIQ Pro | Free funnels are **any-order** — quantified per funnel in §7 |
| A/B testing + remote config | ✅ | Usable for difficulty/economy tests later |
| 3 custom dimensions × 20 values, sticky | ✅ | Our only cross-cutting segmentation (§4) |
| **Custom event fields** | ❌ dashboard-invisible | *"Custom event fields are not displayed in the AnalyticsIQ web-tool."* **Banned from this design.** All dimensionality lives in the event ID or a custom dimension |
| Metrics API / MCP server | ❌ PipelineIQ | Dashboard only, no programmatic querying |
| Raw export / per-user data | ❌ PipelineIQ | No SQL, no per-user paths |

**Hard limits.** Daily unique identifiers: design **15,000**, progression
**8,000**, resource **4,000**. Breaching them does not drop events — GA sets the
event ID to `null`, silently corrupting every metric derived from it. Plus a cap
of **500 events per active user per day**. Both are budgeted in §6.

## 2. Decision register

Every event in §5 traces to a row here. Thresholds marked *(provisional)* have no
industry anchor for a six-game bundle — set the real number from our own first
30 days, then hold it.

| # | Decision | Metric | Action threshold |
|---|---|---|---|
| D-1 | Is the six-game bundle a strength or a dilution? | Share of active players tagged `games_1` vs `games_2+` (custom_01) | >60% still `games_1` at D7 → bundle isn't being discovered; fix cross-game surfacing *(provisional)* |
| D-2 | Which game gets the next dev sprint? | Per-game unique starters and completion depth from progression events; retention split by **first game** | Lowest adoption **and** shallowest depth = rework candidate. See §2.1 — the obvious version of this metric is not computable on free |
| D-3 | Which game should be the front door? | D7 retention split by `custom_02` (first game) | Feature the highest-retaining entry point in the picker |
| D-4 | Is the lives economy tuned right? | Share of sessions ending at 0 lives; D7 retention of `lives_zeroed` vs `lives_healthy` (custom_03) | If zeroed players retain **worse**, the wall is costing more than it earns — loosen cap or refill *(provisional)* |
| D-5 | Ads, IAP, or neither? | WATCH-AD taps (grants a refill — upper bound) vs GOLD-BAR taps (grants nothing — lower bound), over sheet impressions | Read as a range, not a point (§2.2). Gold-bar above 8% is real IAP intent; both below 3% → monetize elsewhere *(provisional)* |
| D-6 | Is the FTUE working, per game? | `coach` progression start → complete rate, per game | <70% completion → that coach is too long or unclear |
| D-7 | Do the Nightly Nine drive return visits? | D1 return of players who hit the 4-goal vs those who didn't | <5pp lift → the daily loop isn't earning its complexity |
| D-8 | Is the lounge meta-game pulling its weight? | Share of players who ever fire a `points/decor` sink | <20% ever purchase → the wallet loop is invisible |
| D-9 | Where is each game too hard? | Per-level fail rate (Luau nights, Blueprints sketches, Cipher phrases, Navigator passages) | Any level >70% fail over ≥50 attempts is a wall |
| D-10 | **Is difficulty compounding with the lives cost?** | Fail rate of a level × share of those fails that empty the pool | A level that is both a wall *and* the common last-life killer is a churn trap — retune it before any other |
| D-11 | Is the restock notification worth keeping? | Opt-in rate; notification-open → session rate | <15% opt-in or <10% open → cut it |
| D-12 | Are we silently losing player data? | `error` event volume from failed SwiftData saves | Any sustained non-zero rate is a P0 — players are losing progress |
| D-13 | **Does the lounge earn its build cost?** | D7 retention of `lounge_buyer`/`lounge_decorator` vs `lounge_visitor`/`lounge_never` (custom_02, Phase 3+) | No retention lift from engaging with it → the lounge is decoration on the product, not a retention loop; stop investing |
| D-14 | **Is the room an expression toy, or just a shop?** | Share of buyers who also move an item / change a window / change the rug | <30% of buyers ever decorate → players want the *collection*, not the room; spend on more items, not more room features |
| D-15 | Is the shop's price ladder right? | `lounge:nextup:<itemID>` distribution vs actual purchase distribution | An item that is frequently "next up" and rarely bought is priced past the wall — retune it or add an earn path |
| D-16 | **Which features are dead weight?** | For every optional affordance: used ÷ *exposed* (§5.5) | <5% of exposed players ever use a feature → cut it or surface it better. Every feature carries maintenance cost forever; unused ones are pure liability |
| D-17 | **Is the app stable?** | Crash-free session rate; hang rate; launch time | **Currently unanswerable — there is no crash reporting of any kind (§5.6).** Any crash-free rate below ~99.5% is a stop-everything |
| D-18 | Are we building animation nobody sees? | Share of sessions with Reduce Motion on; VoiceOver on; Dynamic Type above default | >10% on Reduce Motion → every motion-heavy beat needs a static equivalent, and the animation budget is over-weighted |
| D-19 | **How many players actually have Game Center on?** | Share of *sessions* in each of three states — on / off / never-attempted (§5.6.2); plus parked-submission queue depth | GC on for <50% of sessions → leaderboards and the whole competitive layer serve a minority; weight future investment accordingly |
| D-20 | Do players resume or restart? | RESUME taken ÷ picker entries with a live save | Low resume → the save/restore loop isn't earning its complexity, or players don't trust it |

### 2.1 The metric D-2 *cannot* have

The natural metric is "D7 retention of players who ever played game X". **That is
not computable on the free plan.** Retention can only be split by the three
custom dimensions, and "ever played X" would need six more. What we get instead:

- **Adoption and depth per game** — free, from progression events (unique users
  starting `luau:*`, and how far they get).
- **Retention by entry point** — via `custom_02`.

Together those are enough to rank games for investment. They are not the same as
per-game retention, and the plan does not pretend otherwise.

### 2.2 What the WATCH AN AD row actually measures

**The refill is a shipped feature, not a leftover** (Carson, 2026-08-01). It
grants lives on tap. Do not remove it — an earlier draft of this plan
recommended exactly that, and it was wrong.

That changes how D-5 reads, and the change is worth stating precisely rather
than treating the number as spoiled:

- The tap means **"I want my lives back now"**, not "I would watch an ad for
  them". No ad plays, so nothing about ad tolerance is being measured.
- It is still the **strongest refill-demand signal available**, and it is the
  correct denominator the day a real rewarded ad ships: the drop between taps
  now and taps once an ad is attached *is* the cost of the ad, measured.
- Because the reward is free, the number is an **upper bound** on ad demand.
  `lives:empty:goldbar` — which grants nothing — is the lower bound. The truth
  sits between them, and having both bounds is more useful than having one
  clean-but-unbuilt fake door.

Read the pair, not either alone. A large gap between watchad and goldbar taps
says players want the lives badly but not at any price; a small gap says the
refill itself is what they're indifferent to.

### 2.3 The weekly read — what to actually look at

Instrumentation nobody reads is waste. This is the standing Monday review: twelve
numbers, each tied to a decision, each with a stated "this is bad" line. Build
these as one custom dashboard in AnalyticsIQ; everything below is free-tier.

| # | Number | Source | Bad looks like |
|---|---|---|---|
| 1 | D1 / D7 retention | Native retention view | D1 <35% or D7 <12% for a casual puzzle bundle |
| 2 | Breadth mix — share of active players at `games_1` | `custom_01` split | Rising, or >60% at D7 → D-1 is failing |
| 3 | Sessions ending at 0 lives | `lives:zero:sessionend` ÷ sessions | >25%, or trending up week over week |
| 4 | D7 retention: `lives_zeroed` vs `lives_healthy` | `custom_03` split on retention | Zeroed retaining **worse** → the wall is costing more than it earns (D-4) |
| 5 | Monetization intent | `lives:empty:watchad` and `:goldbar` ÷ `lives:empty:sheet` | Both <3% → no demand at this surface (D-5) |
| 6 | Worst level in each game | Progression fail rate, sorted desc | Any level >70% fail over ≥50 attempts (D-9) |
| 7 | Coach completion, per game | `coach` progression complete ÷ start | Any game <70% (D-6) |
| 8 | Save-failure rate | `error` event volume | Any sustained non-zero value is a P0 (D-12) |
| 12 | Crash-free session rate | MetricKit → `error` events (§5.6) | Below 99.5% is a stop-everything. **Zero visibility today** (D-17) |
| 11 | Where the time goes | `time:<game>` sum per game; app playtime minus the sum of all `time:*` | One game taking >50% of total playtime means the other five are decoration. A large menu residual means navigation is eating the session |
| 10 | Feature census — used ÷ exposed, per affordance | `feature:*` and the `depthCharge`/`loungeCat` resource pairs | Anything under 5% is a cut candidate (D-16). Review monthly, not weekly — it moves slowly |
| 9 | Lounge reach and depth | `lounge:open` unique users ÷ actives; then buyers ÷ visitors; then decorators ÷ buyers | <30% ever open it → the lounge is invisible from the picker. <30% of buyers ever decorate → it's a shop, not a room (D-13, D-14) |

Rows 1–5, 9 and 11 are the health of the *product thesis*; 6–8 and 12 the health of the
*build*; row 10 is the standing dead-weight audit. If only one thing gets looked at, make it row 4 — it is the single
number that says whether the lives economy is helping or quietly killing the game.

## 3. Fix before adding

Two defects make current data untrustworthy. Neither is new instrumentation.

**3.1 Double session start.** `Analytics.start()` runs in `TikiGamesApp.init()`
([TikiGamesApp.swift:8](TikiGames/TikiGamesApp.swift)), before launch completes.
GA's foreground handler arrives mid-init and opens a second session — measured on
3/3 launches. Sessions double; average session length halves. Move `start()` to
the first `.active` scenePhase in [ContentView.swift:100](TikiGames/ContentView.swift),
which already observes `scenePhase`.

**3.2 `runEnded` means something different in every game.** It fires from
`recordRun` ([PlayerStore.swift:425](TikiGames/PlayerStore.swift)), whose defeat
coverage is inconsistent — verified by reading all six:

| Game | Defeat calls `recordRun`? | Evidence |
|---|---|---|
| Top Shelf (`zombie`) | ✅ | ZombieView.swift:528 after the defeat branch |
| Totem (`tikiStacks`) | ✅ | TikiStacksView.swift:312 inside `onGameOver` |
| Luau | ✅ (carries `wonLevel`) | LuauView.swift:1110 on both paths |
| Blueprints | ❌ | BlueprintsView.swift:534 is solve-only; :521 comments *"never recordRun"* |
| Cipher | ❌ | CipherView.swift:613 is solve-only |
| Navigator | ❌ | :848 is per-passage-won; voyage end at `.runOver` records nothing |

Blueprints and Cipher would show a 100% win rate, and cross-game round counts are
not comparable. **Fix: stop instrumenting inside `recordRun`.** Call an explicit
outcome from each game's own end-of-run site (§8).

**3.3 The test guard is a single point of failure.** `Analytics.enabled` blocks
test runs with `NSClassFromString("XCTestCase") == nil`. That is currently the
**only** thing standing between the suite and production data: the test bundle
lives at `Tiki Lounge.app/PlugIns/TikiGamesTests.xctest`, so `Bundle.main` during
tests is the *app*, which means `GAGameKey` resolves and is non-empty. If that one
check ever stops matching, 591 tests calling `recordRun` start firing real events
into the live GA account.

Measured today: safe. The test bundle links `XCTest.framework` *and*
`Testing.framework` (verified with `otool -L`), so the class resolves, and a full
suite run emitted **zero** GA log lines. But the protection is incidental to a
framework the project is already migrating away from — the suite is Swift Testing.

Fix: stop sniffing frameworks. Set an explicit env var on the test target in
`project.yml` and check that instead (or in addition). Deterministic, and it
cannot silently lapse.

## 4. The three custom dimensions

Three sticky slots, 20 values each, attached to every event. The only
cross-cutting segmentation the free plan has, so the allocation is the single
highest-leverage decision in this document.

| Slot | Meaning | Values | Why it wins a slot |
|---|---|---|---|
| `custom_01` | Breadth cohort | `games_1` … `games_6` (6 of the 20 allowed values — no banding, since the 4-vs-6 distinction is exactly what D-1 asks about) | The headline question (D-1), and lets every metric split by how much of the bundle a player uses |
| `custom_02` | **Staged.** Phase 1–2: first game played (write-once). From Phase 3: lounge engagement | `first_totem` … `first_navigator` (6), then `lounge_never`, `lounge_visitor`, `lounge_buyer`, `lounge_decorator` (4) | Two one-slot questions, run in sequence — see §4.1 |
| `custom_03` | Lives pressure | `lives_healthy`, `lives_pinched`, `lives_zeroed` | The monetization thesis (D-4/D-5): does hitting the wall help or kill retention |

**Rejected: tenure band.** GA's native cohort and date-range tooling already
covers new-vs-established well enough to not spend a scarce slot on it.

**Migration:** when IAP ships, `custom_03` becomes payer tier — the highest-value
split at that point. Lives pressure is then read from funnels instead.

### 4.1 Why `custom_02` is staged, not split

Four questions want a slot and there are three. Breadth and lives pressure are
ongoing health metrics and keep theirs permanently. The other two are different
in kind:

- **First game played** answers a *one-time* question — which front door to
  feature (D-3). Once answered, the dimension has no further job. But it is
  **write-once and unreconstructable**: if it isn't captured from day 1, the
  answer is gone forever without raw export.
- **Lounge engagement** answers an *ongoing* question — does the lounge earn its
  3,271 lines (D-13). It can be captured at any time.

So: run first-game first, retire it once D-3 is decided (~60 days of installs),
then reassign the slot. The two eras stay legible in the same dimension because
the value sets are **prefix-namespaced** — `first_*` versus `lounge_*` — so a
dashboard filter can never silently mix them.

**The swap breaks any retention window that straddles it.** On swap day, a
player carrying `first_luau` is overwritten with `lounge_visitor`. Their historical
events keep the old value, but every event after does not — so a D7 or D30
retention curve spanning the swap date will show the `first_*` cohorts appearing
to evaporate. Two rules: finish and *write down* the D-3 answer before swapping,
and never read a retention window that crosses the swap date.

The tier is assigned at launch from persisted state, highest reached wins:

| Value | Condition |
|---|---|
| `lounge_never` | never opened the lounge |
| `lounge_visitor` | opened it, no purchase |
| `lounge_buyer` | ≥1 `LoungeItem.purchasedAt` |
| `lounge_decorator` | ≥1 item moved, or a window/rug ever changed |

`buyer` → `decorator` is the interesting boundary: it separates *collecting* from
*arranging*, which is the difference between a shop and a lounge.

### 4.3 Two ways these dimensions lie if you let them

Both were live in build 16 and are fixed; both are easy to reintroduce.

**A dimension the app decides is not a measurement.** `custom_02` originally
stamped on the route into a game. But `ContentView.resumeTarget` sends every
fresh install to Luau, so it recorded the app's default and reported
`first_luau` for essentially every player — making D-3 answer itself. It now
fires only from the picker's launch closure, where a player actually chooses,
and stays **nil** until they do. Nil is the correct value for a player who has
not yet made a choice; a confident wrong value is worse than a missing one.

**A once-per-launch stamp describes the wrong moment.** `custom_01` and
`custom_03` both vary during a session. Stamped only at launch, a player who
opened with a full pool, emptied it and quit carried `lives_healthy` on every
event of that session — including `lives:zero:sessionend`, the exact inverse
of what D-4 measures, and biased systematically healthy because the pool
refills while the app is closed. They re-stamp on every change to lives or
route. Only `custom_02` is write-once, and only because it must be.

### 4.2 Sticky ≠ cohort — read these correctly

Custom dimensions carry **the value at the moment the event fired**, not the
value at install. A player who is `games_1` on day 0 and `games_3` on day 5 has
day-0 events tagged `games_1` and day-5 events tagged `games_3`.

Consequence:

- `custom_02` is **write-once in Phase 1–2** (first game), making it the only
  dimension that supports a true "cohort of players who started with X"
  retention read. **After the Phase 3 swap it becomes time-varying** (lounge
  engagement, which only ever ratchets upward), so from that point it reads like
  the other two — activity by players currently in state X. D-3 must therefore
  be *decided* before the swap, not after.
- `custom_01` and `custom_03` vary over time. Read them as *"activity by players
  currently in state X"*, never as install cohorts. Stating "D7 retention of
  `games_1` players" without that caveat is a misread.

Set order matters: custom dimensions must be set **after** `GameAnalytics.initialize`,
so they are configured alongside the relocated `start()` call, not in `App.init()`.

## 5. Event taxonomy

### 5.1 Progression events — the level funnels

`progression01 : progression02`, status start/complete/fail, numeric `value`. GA
derives attempts, completion and fail rates automatically; Progression Funnels
add Complete/Start and Fail/Complete ratios.

| Game | p01 | p02 | Statuses | value |
|---|---|---|---|---|
| Luau | `luau` | `night_001`…`night_200` | start / complete / fail | **duration (s)** |
| Blueprints | `blueprints` | `sketch_01`…`sketch_30` | start / complete / fail | **duration (s)** |
| Cipher | `cipher` | `phrase_000`…`phrase_299`, formatted `"phrase_%03d"` from **`phraseIndex % 300`** | start / complete / fail | **duration (s)** |
| Navigator | `navigator` | `passage_001`…`passage_050`, then `passage_050plus` | start / complete / fail | **duration (s)** |
| Totem | `totem` | `run` | start / fail | **duration (s)** |
| Top Shelf | `topshelf` | `run` | start / fail | **duration (s)** |
| FTUE | `coach` | game rawValue + `lounge` (7) | start / complete / fail | — |

**Tutorial runs must NOT emit game progression.** All six games already pass a
tutorial flag into `spendLifeForDefeat` so coached defeats don't cost a life
(e.g. ZombieView.swift:512 `duringTutorial: game.tutorialActive || coachActive`).
Progression events need the **same guard** — a coach run happens on a scripted
board, and letting it emit `luau:night_001 fail` would corrupt every D-9
difficulty number with attempts that were never real. The `coach` progression
family (p01 = `coach`) is the exception: that one *is* the tutorial.

**Progression `start` has no call site yet.** There is no uniform "a run begins
here" hook — only `LuauGame.newGame()` (LuauGame.swift:299) resembles one, and
**that file is cherry-picked by LevelForge (§8.1), so it cannot host an Analytics
call.** Each game needs its start hook identified in its *view* during Phase 2.
This is per-game work that the ~6h estimate must cover, not a single choke point.

**Why `value` carries duration, not score.** GA allows exactly **one** numeric
value per event, and score already has a home: the shipped `game:<game>:end`
design event (§5.3), which has been live and verified since 2026-08-01 and whose
history is worth preserving. That frees progression's value for time — which GA
explicitly recommends it for (*"use the value field for any dynamic data — e.g.
time"*) and which has no other channel. The payoff is per-level duration:
*"Night 137 takes 4.2 minutes on average"* is a difficulty signal that fail rate
alone cannot give.

**Two indices must be bounded or they become cardinality bombs:**

- **Cipher.** `phraseIndex` grows without limit — `begin(index: phraseIndex + 1)`
  at CipherGame.swift:776, and the save-state guard admits values up to 1,000,000
  (:857). Only *display* wraps via `% Self.phrases.count` (:563). Naming a
  progression step off the raw index would mint a new ID forever. Use
  `phraseIndex % 300`.
- **Navigator.** `totalPassages` (NavigatorGame.swift:54) accumulates across
  loops of the level list. Band at 50.

Totem and Top Shelf are endless and never `complete`; their fail-value
distribution is the signal.

### 5.2 Resource events — the economies

Currencies: `points`, `lives`, `depthCharge`, `loungeCat` (4 of 50 allowed).
Item types: `run`, `nightly`, `milestone`, `welcome`, `decor`, `defeat`,
`refill`, `comp` (8 of 20 allowed).

| Flow | Currency | itemType | itemId | Fires at |
|---|---|---|---|---|
| source | `points` | `run` | game rawValue | run payout — **once per voyage for Navigator**, not per passage (§6) |
| source | `points` | `nightly` | challenge id (9) | Nightly pour |
| source | `points` | `milestone` | bit index (~20) | milestone mint |
| source | `points` | `welcome` | item id | welcome gift |
| sink | `points` | `decor` | shop itemID (38) | `purchase()` PlayerStore.swift:1133 |
| sink | `lives` | `defeat` | game rawValue | `spendLife` PlayerStore.swift:633 |
| source | `lives` | `refill` | `timer` | pool refill |
| source/sink | `depthCharge` / `loungeCat` | `comp` | game rawValue | grant / spend |

This is what makes GA's economy dashboard work — currency in/out balance, source
vs sink, and the lives pool as a first-class currency rather than a design event.

### 5.2.1 Reading the shop distribution — most and least bought

The `points`/`decor` sink carries the shop `itemID`, so all 38 items rank
directly in GA's economy dashboard with no extra instrumentation. **But the raw
ranking is confounded by price** and must not be read at face value.

The catalog spans 50 → 1800 points. Cheap items will always top a raw purchase
count, and the Yacht will always sit at the bottom — that tells you nothing about
whether the Yacht is a good item. Two honest reads instead:

1. **Rank within price bands.** Compare the Flaming Mug (50) against the Glass
   Float (100), not against the Volcano (1400). An item that underperforms its
   *neighbours* is the real signal — same money, less appeal.
2. **Conversion at the rung.** Pair the sink with `lounge:nextup:<itemID>`, which
   fires with whatever item the player is currently saving for. Roughly:

   ```
   rung conversion ≈ bought / (bought + was-next-up-but-never-bought)
   ```

   An item that is frequently the thing players are saving for, and rarely the
   thing they end up buying, is either priced past a wall or not desirable enough
   to finish the climb. That is the actionable end of D-15.

Least-bought is the more interesting tail: an item nobody ever saves *toward* is
invisible in the shop's layout; an item they save toward and abandon is a pricing
or desirability problem. The two need different fixes, and `nextup` is what
separates them.

### 5.3 Design events — everything without a native type

| Event ID | Fires | Serves |
|---|---|---|
| `game:<game>:end` | run ended — **already shipped**, `value` = score | score history; outcome comes from progression status |
| `time:<game>` | leaving a game view, `value` = seconds | **total playtime + avg time per visit** (§5.3.2) |
| `time:lounge` | leaving the lounge, `value` = seconds | where the session actually goes |
| `nav:picker:open` | picker shown | funnel base |
| `nav:leaderboard:open` | board shown | — |
| `lounge:open` | lounge shown | D-8, D-13 |
| `lounge:shop:open` | shop panel shown | D-8, D-15 |
| `lounge:nextup:<itemID>` | shop opened, tagged with the item the player is saving for (38 ids) | **D-15** |
| `lounge:missions:open` | Vic tapped → missions panel | D-7 |
| `lounge:decorate:move` | an item was repositioned — **once per lounge visit**, not per drag (§5.3.1) | **D-14** |
| `lounge:decorate:window` | window view cycled | D-14 |
| `lounge:decorate:rug` | rug colorway cycled | D-14 |
| `lounge:bottle` | message-in-a-bottle tapped | D-14 |
| `lounge:signunlock` | the Sign becomes buyable — all six games played | completionist milestone |
| `lives:empty:sheet` | out-of-lives sheet shown | D-5 denominator |
| `lives:empty:watchad` | WATCH-AD tapped | **D-5** |
| `lives:empty:goldbar` | GOLD-BAR tapped | **D-5** |
| `lives:empty:dismiss` | sheet dismissed | D-5 |
| `lives:zero:sessionend` | app backgrounded at 0 lives — **latched once per session** (a player who backgrounds five times at zero must count once, or the D-4 ratio inflates) | D-4 |
| `notif:restock:optin` / `:deny` | opt-in row result | D-11 |
| `notif:restock:open` | launched from the notification | D-11 |
| `nightly:done:<id>` | challenge completed (9 ids) | D-7 |
| `nightly:goal` | 4-of-9 reached | D-7 |
| `nightly:pour` | pour claimed | D-7 |
| `rating:ask` | `requestReview` called | — |
| `run:quit:<game>` | run abandoned mid-play | D-2 |

### 5.3.2 The time model — playtime and session length

Three questions, three different answers, only one of which needs new work.

| Question | How | Cost |
|---|---|---|
| **App-wide** average session length, average playtime, session count | **Native GA metric** — *"session length is the amount of seconds spent focused on a game"*. Already flowing from `Analytics.start()` | free, zero code |
| **Per-game** total playtime and average time-per-visit | `time:<game>` design event, `value` = seconds spent in that game's view, fired once on exit | 1 event per game visit |
| **Per-level** time-to-complete | Progression `value` (§5.1) | free — rides events that already fire |

`time:<game>` is what answers "total play time across the six games": **sum** the
value for the total, **mean** it for average time per visit. GA exposes both — the
SDK header states a value-carrying event *"will result in sum & mean values being
available"*.

Add `time:lounge` on the same shape. That completes the picture, because
app-wide playtime **minus** the sum of all `time:*` events is time spent in the
picker and menus — which is the one slice nobody ever measures and which,
if it is large, means navigation is eating the session.

**Fire it on the same hook as `run:quit`** — the game view's `.onDisappear`,
which does not fire on backgrounding. That is correct here: time spent with the
app backgrounded is not play time, and excluding it is the honest read.

**Caveat to check when data lands.** Sum/mean aggregation is documented for
design-event values (confirmed in the SDK header). Progression-value aggregation
is documented as suitable for time but its exact dashboard treatment is not
spelled out — verify per-level duration renders as expected before relying on it
for D-9, and fall back to `time:<game>` if not.

### 5.3.1 The drag handler is a volume trap

`commitPlacement` ([LoungeView.swift:144](TikiGames/LoungeView.swift)) fires on
**every drag end**. A player rearranging the room can commit 50+ placements in
one sitting, which against the 500-events-per-user-per-day cap is the same class
of mistake as per-move telemetry in a match-3.

`lounge:decorate:move` therefore fires **at most once per lounge visit** — a
latch reset on lounge entry. That fully answers D-14 ("do they arrange at all"),
which is the decision. *How much* they rearrange is a PipelineIQ question, not a
design event.

### 5.4 Error events

`PlayerStore` writes through `try? context.save()` in ~15 places, swallowing
every failure. If SwiftData saves start failing, players lose progress and we
currently have **no way to know**. Wrap the save path and emit a GA error event
(severity `error`, message `save:<callsite>`) on failure. Serves D-12.

### 5.5 The feature census — what's used, what's dead weight

Everything above is *decision*-driven. This section is *coverage*-driven: a
standing inventory of every optional affordance in the app, so dead features can
be found and cut. Serves D-16.

**The rule that makes a census meaningful: every feature needs a denominator.**
"50 Depth Charges dropped" is unreadable. "12% of players who *held* a Depth
Charge ever dropped one" is a decision. So each feature is measured as
**used ÷ exposed**, never as a raw count.

Some features already have their denominator for free. Depth Charge and Lounge
Cat are modelled as resource currencies in §5.2 — the grant is a `source` and the
use is a `sink`, so the pair is already the exposure ratio. Nothing to add.

The genuinely uninstrumented surface, verified by sweeping every `Button` and tap
handler in the six game views:

| Feature | Event | Exposure denominator | Site |
|---|---|---|---|
| Cipher hint — Vic's Tip (free, once daily) | `feature:cipher:hint:free` | phrases started | CipherView.swift:799 `useHint(charged: false)` |
| Cipher hint — charged | `feature:cipher:hint:charged` | phrases started | CipherView.swift `useHint(charged: true)` → CipherGame.swift:717 |
| Blueprints MARK mode | `feature:blueprints:mark` | sketches started | BlueprintsView.swift:1097 `modeButton("MARK", …)` |
| Navigator Pause-and-Exit | `feature:navigator:pauseexit` | voyages started | NavigatorView.swift:187 |
| How To Play | `feature:<game>:howto` | game entries | BlueprintsView.swift:739, :859; CipherView.swift:738 |
| Leaderboard opened | `feature:<game>:leaderboard` | game entries | GamePickerView.swift:112, ZombieView.swift:158, BlueprintsView.swift, +others |
| Lounge affordances | `lounge:decorate:*`, `lounge:bottle` | lounge visits | §5.3 — already specified |

**Two findings the sweep produced, independent of analytics:**

1. **How To Play exists in only 2 of 6 games** (Blueprints, Cipher). The other
   four have no help affordance at all. That is a product inconsistency worth a
   decision regardless of what the numbers say.
2. **Totem has no optional features whatsoever** — pure board, no abilities, no
   help, no modes. Nothing to censused there, which is itself the answer to "what
   functionality is going unused in Totem": there isn't any to use.

**Volume note.** Hint events are the only census event with per-round
multiplicity (a player can take several hints per phrase). At a realistic ≤2 per
phrase they fit inside the §6.2 headroom. Every other census event is once per
session or once per entry. If hint volume ever becomes a concern, latch it to
first-use-per-phrase — the D-16 question is "do they use hints at all", not "how
many".

### 5.6 Grassroots coverage — the unglamorous layer

Everything above measures the *product*. This measures the *app*. Found by
sweeping `UserDefaults` keys, the audio system, Game Center, and accessibility
environment reads across the whole target.

**The largest gap in this document is not an event — it is that there is no
crash reporting at all.** The only package in `project.yml` is GameAnalytics,
and GA is an analytics SDK, not a crash reporter. Today a crash loop affecting
10% of players would be completely invisible until the reviews arrived.

Recommended fix: **MetricKit** (`MXMetricManager`, Apple-native, no third-party
SDK, no extra privacy surface — which matters given §10's posture). It delivers
crash diagnostics, hang rate, and launch time once daily on-device. Since there
is no backend, forward the summary values into GA as error/design events on
receipt. That keeps one vendor and one dashboard.

| Signal | Event | Site | Decision |
|---|---|---|---|
| Crash / hang / launch time | forwarded from MetricKit into `error` + `perf:launch` (value = ms) | `MXMetricManagerSubscriber` at app init | **D-17** |
| Reduce Motion on | `a11y:reducemotion` once per session | any existing `@Environment(\.accessibilityReduceMotion)` read | **D-18** |
| VoiceOver on | `a11y:voiceover` once per session | `UIAccessibility.isVoiceOverRunning` at launch | D-18 |
| Dynamic Type above default | `a11y:dynamictype` once per session | GamePickerView.swift:146 already caps at `accessibility1` — are players hitting the cap? | D-18 |
| Game Center state | `gc:state:on` / `:off` / `:unattempted` — **once per session** (§5.6.2) | session start, reading `GKLocalPlayer.local.isAuthenticated` | **D-19** |
| Why GC is off | `gc:auth:fail:<reason>` | GameCenter.swift:116 — **the error is currently discarded** (§5.6.2) | D-19 |
| Leaderboard submit parked offline | `gc:submit:parked` | GameCenter.swift `resubmitPending()` path | D-19 |
| Resume vs fresh start | `run:resume:<game>` vs `run:new:<game>` | **NOT ContentView.swift:130** — that closure only knows the route, not whether a save exists (verified). Hook each game view where it loads save state, or the picker where it decides to show RESUME | **D-20** |
| Education one-shots ever reached | `edu:<flag>` | the persisted flags: `livesExplained`, `moveHint`, `panHint`, `nightlyHint`, `regularsToast`, `loungeSeen`, `pickerDidSwipe`, `bottleNote` | FTUE coverage — a teaching beat nobody reaches is a beat that isn't teaching |

`pickerDidSwipe` deserves singling out: it records whether a player ever
discovered the picker swipes. If that flag stays false for most players, five of
the six games are effectively hidden, and D-1's breadth problem has a **navigation**
cause rather than an interest one — a completely different fix.

### 5.6.2 Game Center state — why the obvious spec is wrong

"How many players have Game Center on" looks like an auth success rate. It isn't,
for three reasons found by reading the auth path.

**1. There is a third state, and it may be the biggest one.** `authenticate()` is
deliberately deferred for new players — TikiGamesApp.swift:25 only calls it if the
player already has a best score, because *"Game Center stays silent for brand-new
installs (the FTUE owns the first minutes)"*. A player who never finishes a run
and never opens a leaderboard **never attempts auth at all**. Reporting only
ok/fail silently drops them and inflates the enabled rate. The states are
**on / off / never-attempted**, and the third is a product signal in its own
right: it counts players who never got far enough to be asked.

**2. Auth is once per process, but the question is per session.** `authenticate()`
guards on `handlerInstalled` (GameCenter.swift:115) and installs GameKit's handler
exactly once; the other seven call sites are no-ops after the first. So an
auth-time event fires once and tells you nothing about ongoing state — a player
signed in on Monday may be signed out on Friday. Read
`GKLocalPlayer.local.isAuthenticated` **once per session at session start**
instead. It is a live property and needs no handler. That yields *"share of
sessions with GC on"*, which is the actual question and can be trended.

**3. The failure reason is currently thrown away.** GameCenter.swift:116 is
`{ [weak self] viewController, _ in` — the second parameter is GameKit's error and
it is discarded. Declined-by-player, no-Apple-ID, and offline are three different
problems with three different responses, and today they are indistinguishable.
Capturing that error is a one-line change and turns D-19 from a number into a
diagnosis.

**Not spending a custom dimension on this.** *"Do GC-enabled players retain
better?"* is a fair question and leaderboards are a retention feature, but all
three slots are allocated (§4) and this does not outrank any of them. It is the
leading candidate for `custom_03` when lives-pressure retires — noted, not free.

### 5.6.1 Two product findings from the same sweep

Neither is an analytics gap, both were surfaced by looking for one:

1. **Players cannot mute the game.** `TikiSound.setEnabled(_:)`
   (TikiSound.swift:52) is defined and **never called from anywhere** — not one
   call site in the app or the test suite, and there is no mute affordance in any
   view. The persisted `tikiSoundOn` key exists and can only ever read its
   default of `true`. For a game played in public, that is a real gap, and it
   also means "what share play muted" is currently unanswerable *because it is
   not possible*.
2. **There is no settings surface at all.** No settings screen, no options panel.
   That is a defensible choice for a game this size, but it is a choice — and it
   is where a mute toggle, an analytics opt-out (§10), and a restore-purchases
   row would all eventually have to live.

## 6. Volume budgets — both limits, computed

### 6.1 Daily unique identifiers

| Type | Worst case | Limit | Headroom |
|---|---|---|---|
| Progression | 200×3 + 30×3 + 300×3 + 51×3 + 2×2 + 7×3 = 600+90+900+153+4+21 = **1,768** | 8,000 | 4.5× |
| Resource | 6 + 9 + 20 + 1 + 38 + 6 + 1 + 8 = **89** | 4,000 | 45× |
| Design | ≈ 40 core + 38 `lounge:nextup:<itemID>` + 8 lounge + ≈20 `feature:*` + 13 time/end + ≈20 grassroots = **≈ 138** | 15,000 | 109× |

Worst case assumes every Luau night and all 300 Cipher phrases are touched by
someone on the same day.

### 6.2 Events per user per day — the limit that actually binds

Per round: progression start (1) + progression complete|fail (1) + lives sink
(0–1) + points source (1) = **3–4 events**.

Navigator is the outlier: it records **per passage**, not per voyage. A heavy
player charting 100 passages in a day would emit 300 events from Navigator alone;
add 40 rounds elsewhere (160) plus ~20 navigation/nightly events and the total is
**~480 of the 500 cap** — close enough that a slightly heavier tail breaches it,
and breaching nulls event IDs silently.

**Mitigations, both adopted:**

1. Navigator emits progression per passage (needed for the D-9 difficulty curve)
   but **one aggregated `points` source event per voyage**, not per passage. That
   cuts 3N to 2N+1 — the same 100-passage day drops to **381** events (201 + 160
   + 20), restoring ~24% headroom against the cap.
2. **Standing rule: no per-move, per-tap, per-swap, or per-tick events, ever.**
   A single Luau run is dozens of swaps; instrumenting at that grain would blow
   the cap in one session. If someone needs move-level data later, that is a
   PipelineIQ conversation, not a design event.

## 7. Funnels, and what any-order costs each one

Free-tier funnels count a player as converted on a step regardless of whether
they did the earlier steps first. That distorts a funnel only where a later step
is reachable without the earlier one.

| # | Funnel | Steps | Any-order distortion |
|---|---|---|---|
| 1 | New-player onboarding | `nav:picker:open` → `coach` start → `coach` complete → first progression complete | **Real.** A player who skips the coach and completes a level still counts on step 4. Read step 2→3 (coach start→complete) as the reliable pair; treat 3→4 as directional only |
| 2 | Game adoption / breadth | 1st distinct game start → 2nd → 3rd | **None.** Steps are counts of distinct games; order is irrelevant by construction |
| 3 | Lives → monetization intent | `lives` defeat sink → `lives:empty:sheet` → `watchad` \| `goldbar` | **None.** The buttons exist only inside the sheet, so step 3 is unreachable without step 2 |
| 4 | Economy → lounge | `points` source → `lounge:open` → `lounge:shop:open` → `points/decor` sink → `lounge:decorate:move` | **Minimal.** Each step is physically implied by the next — you cannot buy without the shop, or arrange without owning. The step that matters is **sink → decorate**: that ratio is D-14, collecting versus arranging |
| 5 | Daily return | `nightly:done` → `nightly:goal` → `nightly:pour` | **None.** Goal requires 4 completions; pour requires goal |

Only funnel 1 needs a caveat when read. The rest are monotonic by construction,
so any-order and strict-order agree.

**Activation.** The single most important derived number for a new install is
*time to first completed round* — the moment the app has delivered its promise.
Read it off funnel 1 as the step-1 → step-4 conversion within the first session,
split by `custom_02` (first game). A front door where fewer than half of new
players finish one round is the wrong front door, whatever its retention says.

## 8. Implementation map

Wrapper additions to `Analytics.swift` (all no-op under the existing `enabled`
guard, so tests and previews stay silent):

```swift
enum RunOutcome: String { case win, loss, quit }

static func progression(_ status: GAProgressionStatus,
                        p01: String, p02: String, value: Int?)
static func resource(_ flow: GAResourceFlowType, currency: String,
                     amount: Int, itemType: String, itemId: String)
static func design(_ eventId: String, value: Int? = nil)
static func error(_ message: String)
static func setDimensions(breadth: String, firstGame: String, livesPressure: String)
```

Verified call sites. **Every one is in an app-target file** — see §8.1.

| Hook | File:line | Note |
|---|---|---|
| relocate `start()` + set dimensions | TikiGamesApp.swift:8 → ContentView.swift:100 | scenePhase `.active`, once |
| session end at zero lives | ContentView.swift:100 | scenePhase `.background` |
| game start | ContentView.swift:130 | existing `Analytics.gameStarted` site |
| Totem run end | TikiStacksView.swift:307–312 | `onGameOver`; defeat + record already adjacent |
| Top Shelf run end | ZombieView.swift:512–528 | defeat branch + record |
| Luau night end | LuauView.swift:1094–1110 | `game.didWinLevel` gives the outcome directly |
| Blueprints solve / defeat | BlueprintsView.swift:534 / :547 | two separate sites — defeat is `handleDefeat()` |
| Cipher solve / defeat | CipherView.swift:613 / :524 | two separate sites |
| Navigator passage / voyage end | NavigatorView.swift:848 / :860 | passage-won vs `.runOver` |
| lives sink | PlayerStore.swift:633 (`spendLife`) | single choke point for all six games |
| points source | PlayerStore.swift:478 (`grant`) | single choke point |
| points sink | PlayerStore.swift:1133 (`purchase`) | |
| lounge opened | `LoungeView` body `.onAppear` | also resets the decorate latch (§5.3.1) |
| shop opened + `nextup` | LoungeView.swift:511 `openShopScrolled(to:)` | the "NEXT UP" item is already computed at LoungeShopPanel.swift:282 — reuse it, don't recompute |
| missions opened | LoungeView.swift:568 `openMissions()` | Vic tap routes here |
| window cycled | LoungeView.swift:495 `cycleWindow(east:)` | |
| rug cycled | LoungeView.swift:504 `cycleRug()` | |
| item moved | LoungeView.swift:144 `commitPlacement` closure | **latched** — one event per visit |
| bottle tapped | LoungeView.swift:58 `showBottleNote()` | |
| `time:<game>` + `run:quit` | each game view `.onDisappear` | one hook, two events — start the clock on `.onAppear` |
| `time:lounge` | LoungeView `.onDisappear` | pairs with the lounge-open hook |
| Cipher hint (free / charged) | CipherView.swift:799 and the charged button; both route to `useHint(charged:)` | instrument `useHint`, one site, pass the flag through |
| Blueprints MARK mode | BlueprintsView.swift:1097 `modeButton("MARK", …)` | latch once per sketch |
| Navigator pause-and-exit | NavigatorView.swift:187 | |
| How To Play | BlueprintsView.swift:739, :859; CipherView.swift:738 | only 2 of 6 games have one — see §5.5 |
| Leaderboard opened | GamePickerView.swift:112, ZombieView.swift:158, BlueprintsView.swift, +others | tag with the game whose board it is |
| out-of-lives sheet shown | **`OutOfLivesSheet.onAppear`** — one site | *Decided:* six call sites set `outOfLivesOpen = true` (GamePickerView.swift:828, ZombieView.swift:121, NavigatorView.swift, +3). Instrument the sheet itself, not its six callers — one hook, and it cannot drift out of sync when a seventh caller appears |
| WATCH-AD / GOLD-BAR / dismiss | OutOfLivesSheet.swift:95 / :111 / :129 | |
| notification opt-in | OutOfLivesSheet.swift:233, LivesRestockNotifier.swift:96 | |
| rating ask | LoungeView.swift:590–592 | |
| coach start / complete / skip | LuauView.swift:342, :366 (`coachActive = true`), `dismissCoach(withSuccess:)` | same shape in all six games + lounge |

**Run-quit detection** (`run:quit:<game>`): fire from each game view's
`.onDisappear` when a run is live and no end-of-run event has fired. Guard
against false positives — `.onDisappear` does **not** fire on backgrounding, so
this measures genuine "left the game", which is what D-2 wants.

### 8.1 The LevelForge trap

The macOS `LevelForge` tool target cherry-picks these files from the iOS target
(project.yml:73–79): `LuauGame.swift`, `LuauLevel.swift`, `LuauLevels.swift`,
`LuauLevels.hand.swift`, `LuauLevels.generated.swift`, `LuauBot.swift`,
`RunSummary.swift`.

**No `Analytics` call may live in any of them** — GameAnalytics is an iOS-only
dependency and the tool build will break. Every site in the table above is in a
view or in `PlayerStore.swift`, none of which LevelForge compiles. Keep it that way.

### 8.2 Verifying instrumentation after it ships

Each phase must be proven on-device before it counts as done. **The SDK's debug
log is not sufficient evidence** — this was established the hard way: GA carries
two design-event format strings (`{eventId:%@}` and `{eventId:%@, value:%@}`) and
logs the *no-value* one even when a value is attached. A log-only check would
have concluded the run score was being dropped when it was arriving fine.

The procedure that actually proves it:

1. **Fire the event.** Drive a run headlessly with `TIKI_AUTOPLAY=1`. Terminate
   the app first — `simctl launch` on a *running* app silently ignores
   `SIMCTL_CHILD_*` env.
   ```
   xcrun simctl terminate <udid> com.example.tikilounge
   SIMCTL_CHILD_TIKI_AUTOPLAY=1 xcrun simctl launch <udid> com.example.tikilounge
   ```
2. **Confirm it was queued** — `xcrun simctl spawn <udid> log show --last 3m
   --style compact | grep "GA/Analytics"`.
3. **Read the real payload** from the pre-flush queue. GA flushes every ~8s and
   deletes on success, so poll:
   ```
   sqlite3 <appDataContainer>/Library/gameAnalytics.sqlite "select event from ga_events;"
   ```
   This is the only free-tier way to see exactly what leaves the device —
   `value`, `custom_01..03`, and all.
4. **Confirm the server accepted it** — look for `Event queue: N events sent`,
   not merely `Sending N events`.

## 9. Phasing

| Phase | Contents | Effort | Why this order |
|---|---|---|---|
| **0** | Fix double session start; move `runEnded` out of `recordRun` with explicit outcome; **harden the test guard (§3.3)**; **add MetricKit crash/hang/launch reporting (§5.6)** | ~6h | Current numbers are wrong; adding more compounds the error |
| **1** | 3 custom dimensions; lives resource events; out-of-lives design events; **`time:<game>` / `time:lounge`** | ~5h | The monetization thesis — D-1, D-4, D-5, the largest-consequence decisions |
| **2** | Progression events for all six games + coaches | ~6h | D-6, D-9, D-10; unlocks GA's built-in level funnels |
| **3** | Points economy resource events; **all lounge events (§5.3) + the decorate latch**; swap `custom_02` to lounge engagement | ~5h | D-8, D-13, D-14, D-15 — answers "is anyone actually using the lounge", and whether its 3,271 lines earn their keep |
| **4** | Nightly, notification, rating design events; error events; **the §5.5 feature census** | ~5h | D-7, D-11, D-12, D-16 |

## 10. Privacy and compliance

- **No ATT prompt.** GA is IDFV-only; the SDK logs *"trackingAuthorizationStatus
  is not 'authorized', so can't get IDFA"* and `ios_idfa` is empty in the raw
  payload (both verified on device logs). `NSPrivacyTracking` stays `false`.
- **Privacy manifest.** The GA xcframework ships its own `PrivacyInfo.xcprivacy`;
  the app's own manifest does not need to declare GA's collection.
- **ASC nutrition labels** must be updated at the next submission: Identifiers →
  Device ID, and Usage Data → Product Interaction — both *not linked to identity*,
  *not used for tracking*.
- **Age rating / COPPA.** If Tiki Lounge is ever rated for children or listed in
  Kids Category, GA must be put in COPPA-compliant mode (it exposes a
  child-directed configuration) — otherwise device-identifier collection is not
  permissible. Decide the age rating before the next submission and set the flag
  to match.
- **GDPR/consent.** GA collects a device identifier, which in the EU generally
  requires a lawful basis. GA supports per-user opt-out; the low-friction posture
  for a game this size is a single "Share anonymous usage data" toggle in
  settings, defaulting on outside the EU. **This is a decision for Carson, not a
  default I should pick.**
- **Retention.** Free-tier dashboard history is limited (12-month history is a
  PipelineIQ feature). Anything needing long historical comparison must be
  screenshotted at the time or re-derived.

## 11. Appendix — building the weekly-read dashboard

§2.3 lists the numbers. This is how to assemble them as one custom dashboard.
GA's custom widgets use the same query model as the Explore tool: pick a
**metric**, optionally **filter** to an event id, optionally **split** by a
custom dimension. Exact UI labels may differ slightly from the names below.

Create one dashboard, `Tiki — Weekly Read`, with these widgets in this order.
Rows 1–2 and 6–8 come from predefined dashboards and are duplicated here only
so the whole read is on one screen.

| # | Widget | Metric | Filter | Split by | Reads as |
|---|---|---|---|---|---|
| 1 | Retention | Retention D1 / D7 | — | — | D1 <35% or D7 <12% is trouble |
| 2 | Breadth mix | Users | — | `custom_01` | Share sitting at `games_1` (D-1) |
| 3 | Sessions ending empty | Event count | `lives:zero:sessionend` | — | Divide by Sessions from widget 1 (D-4) |
| 4 | **Lives wall vs retention** | Retention D7 | — | `custom_03` | `lives_zeroed` vs `lives_healthy`. **The single most important number here** (D-4) |
| 5 | Monetization intent | Event count | `lives:empty:sheet`, `:watchad`, `:goldbar` | — | Tap ÷ impression (D-5) |
| 6 | Worst levels | Progression fail rate | — | progression01 | Sort desc; >70% over ≥50 attempts is a wall (D-9) |
| 7 | Coach completion | Progression complete ÷ start | `coach` | progression02 | Any game <70% (D-6) |
| 8 | Errors | Event count | category = error | — | Any sustained non-zero is a P0 (D-12, D-17) |
| 9 | Lounge funnel | Event count | `lounge:open`, `lounge:shop:open`, `lounge:decorate:move` | — | Reach → spend → arrange (D-13, D-14) |
| 10 | Feature census | Event count | `feature:*` | — | Under 5% of exposure is a cut candidate (D-16) |
| 11 | Where the time goes | **Sum** of value | `time:*` | — | Per-surface totals; app playtime minus this sum is the menu residual (§5.3.2) |
| 12 | Game Center reach | Event count | `gc:state:on|off|unattempted` | — | Three states, not two (§5.6.2) |

**Widget 11 is the one to sanity-check first.** It depends on GA exposing
*sum* and *mean* aggregation for design-event values. The SDK header states a
value-carrying event "will result in sum & mean values being available", but
that has not been confirmed in the AnalyticsIQ UI. If sum is unavailable,
per-game playtime has to come from the progression durations instead.

**Do not build this against an empty account.** Every widget needs data behind
it to confirm it renders what it claims, and today the only traffic is from
simulator verification runs. Build it after the first real build has been live
for a day.

## 12. What this plan cannot answer

- **Per-user questions.** No raw export → no "what did churned players do last?"
- **Per-game retention** for players who merely *touched* a game (§2.1).
- **Anything via custom event fields** — dashboard-invisible on free.
- **Strictly-ordered funnels** — any-order only (§7).
- **Revenue** — no business events until there is something to buy.
- **Move-level difficulty** — deliberately out of budget (§6.2).
