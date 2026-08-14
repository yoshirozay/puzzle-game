# Analytics Strategy Rubric

Grading bar for `ANALYTICS_PLAN.md`. Locked before v1 was written; not editable
mid-loop. **Pass = average ≥ 9.3 AND no dimension below 8.**

Reference class: instrumentation plans for F2P mobile puzzle bundles (King's
Candy Crush lives/economy telemetry, Voodoo/Zynga hyper-casual funnel packs),
constrained to what GameAnalytics actually exposes on the **free** plan.

---

## D1 — Decision coverage

10/10: Every proposed event traces to a **named decision** with a **stated
threshold that would trigger action**. No event exists because it is "nice to
have". The plan explicitly lists decisions it will NOT be able to make and why.
5/10: Events are grouped by theme, and the reader can guess the decisions.
0/10: A list of events with no decisions attached.

## D2 — Platform fidelity (measured, not assumed)

10/10: Every one of GA's real limits is checked against the proposed taxonomy
with an **arithmetic estimate**: design 15,000 / progression 8,000 / resource
4,000 unique identifiers per day; 500 events per user per day; 3 custom
dimensions × 20 values; ≤50 currencies, ≤20 item types; custom event fields
invisible in the dashboard; funnels are **any-order** on free.
5/10: Limits are named but not applied to this taxonomy.
0/10: Design would silently null out event IDs or rely on paid-tier features.

## D3 — Funnel completeness

10/10: Names each funnel the business needs (new-player onboarding, game
adoption/breadth, lives-depletion → monetization intent, economy, daily-mission
return), and each is **buildable from the listed events** with GA's funnel tool.
Any-order distortion is addressed per funnel.
5/10: Funnels named but some steps have no corresponding event.
0/10: No funnel design.

## D4 — Native-type leverage

10/10: Progression / resource / business / error / ad types are used wherever
they fit, so GA's built-in dashboards (level funnels, economy balance, error
grouping) work without custom dashboards. Design events are the fallback, not
the default, and each design-event choice is justified.
5/10: Some native types used, some obvious fits missed.
0/10: Everything is a design event.

## D5 — Implementation specificity

10/10: Exact event ID strings, exact call sites as `file:line`, exact wrapper
signatures, and the code shape for each hook. An engineer implements it without
making a single further design decision.
5/10: Event names given, call sites vague.
0/10: Conceptual only.

## D6 — Correctness against this codebase

10/10: Every claim about existing code is **verified against the actual files**,
including the traps (recordRun's per-game defeat inconsistency; LevelForge
cherry-picks sources so Analytics calls must stay out of shared engine files;
Analytics no-ops under XCTest). No hook is proposed at a site that cannot host it.
5/10: Mostly right, one or two unverified claims.
0/10: Plan contradicts the code.

## D7 — Staging and cost

10/10: Phased so the highest-decision-value instrumentation ships first, with
the rationale stated, an explicit "fix before adding" step for known-broken
telemetry, and a rough per-phase effort estimate.
5/10: Phased arbitrarily.
0/10: One undifferentiated pile.

## D8 — Privacy, compliance, and honesty of limits

10/10: Covers ATT/IDFA posture, the privacy manifest, ASC nutrition labels, and
data retention. States plainly what this plan **cannot** answer on the free tier
and what it would cost to answer it.
5/10: Mentions privacy.
0/10: Silent on it.

---

## Iteration log

Filled in one row per round, after that round is actually graded. Newest first.

**Stopped at v3 (A, 9.63).** Stopping early and deliberately: the remaining
points are not reachable by more writing. D4's last point needs a verified use
for `progression03` that the game does not currently have; D7's needs measured
implementation time rather than estimates; D8's needs Carson's decision on the
EU consent posture. Every provisional threshold in §2 needs 30 days of real
player data to replace a guess with a baseline. A v4 would be awarding scores
without evidence, which this rubric forbids.

| version | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 | avg | grade | delta diagnosis |
|---|---|---|---|---|---|---|---|---|---|---|---|
| v9 | 10 | 10 | 10 | 10 | 10 | 9 | 9 | 9 | **9.63** | **A** | **Audit round** (Carson: "final pass, look for gaps and bugs"). Ran the check I said was needed after v8 — every spec against its actual call site, mechanically. **D6 drops 10→9**, and it should: the audit found seven real defects that had been sitting in an A-graded document. (1) **Five stale line citations** — main moved to 48ff2d5 under me and `PlayerStore` shifted by 4 lines; one more (`TikiSound.swift:39`) I broke myself with the audio change an hour earlier. All 45 citations now verified mechanically, in-range *and* by content. (2) **Tutorial runs would corrupt every difficulty number** — all six games guard `spendLifeForDefeat` with a tutorial flag, but progression events had no such guard, so coached runs on scripted boards would emit real level attempts. (3) **Progression `start` has no call site anywhere** — and the one candidate hook, `LuauGame.newGame()`, is a LevelForge cherry-picked file that cannot host an Analytics call. (4) **D-20's site is impossible** — ContentView.swift:130 knows the route, not whether a save exists. (5) `lives:zero:sessionend` unlatched, inflating the D-4 ratio on repeated backgrounding. (6) The `custom_02` swap silently breaks retention windows straddling it. (7) **The test guard is a single point of failure** — the xctest bundle sits inside the app, so `Bundle.main` resolves `GAGameKey` during tests, and only `NSClassFromString("XCTestCase")` stops 591 tests writing to production. Measured safe today (XCTest linked, zero GA lines in a full run) but incidental to a framework the suite is migrating off. D5 holds at 10 — every fault is now corrected and verified, not merely noted. |
| v8 | 10 | 10 | 10 | 10 | 10 | 10 | 9 | 9 | **9.75** | **A** | **Correction round, not a scope addition.** Carson asked to track how many players have Game Center enabled — already nominally covered by v7's D-19, but reading the auth path showed **v7's spec was wrong three ways**: (a) it modelled a binary ok/fail when there is a **third state, never-attempted**, which may be the largest bucket since `authenticate()` is deliberately deferred for new installs (TikiGamesApp.swift:25 gates on having a best score) — reporting ok/fail alone silently inflates the enabled rate; (b) it hooked auth time, but `authenticate()` guards on `handlerInstalled` and fires **once per process**, so it cannot answer an ongoing question — replaced with a per-session read of `GKLocalPlayer.local.isAuthenticated`; (c) it ignored that **GameCenter.swift:116 discards GameKit's error**, making declined / no-Apple-ID / offline indistinguishable. New §5.6.2. Scores unchanged: D6 stays 10 because the fault was caught and corrected against the source before shipping, which is the behaviour D6 measures — but this is the second consecutive round where a spec I wrote failed on first contact with the actual call path, and that pattern is worth watching. |
| v7 | 10 | 10 | 10 | 10 | 10 | 10 | 9 | 9 | **9.75** | **A** | Scope addition (Carson: "any other analytics missing for pure grassroots functionality") — and the honest note is that **my coverage method up to v6 was reactive**: each round found gaps only because Carson named a surface. v7 replaces that with an actual systematic sweep — every `UserDefaults` key, the audio system, Game Center, and every accessibility environment read across the target. Result: §5.6 + D-17…D-20 (stability, accessibility adoption, Game Center health, resume-vs-restart), plus `edu:*` coverage for the eight persisted teaching one-shots. **The biggest finding is not an event: there is no crash reporting of any kind** — GA is not a crash reporter and it is the only package in project.yml, so a crash loop is invisible today. Recommended MetricKit (Apple-native, no extra privacy surface) forwarded into GA, and moved it into Phase 0 (~2h → ~5h). Two product findings fell out of the same sweep: **`TikiSound.setEnabled` is never called from anywhere — players cannot mute the game** — and there is no settings surface at all. Scores held: the addition is executed to standard but D7/D8 remain evidence-gated and D1–D6 were already at ceiling. |
| v6 | 10 | 10 | 10 | 10 | 10 | 10 | 9 | 9 | **9.75** | **A** | Scope addition (playtime / session length, Carson) that exposed a **latent design fault in v1–v5**: GA allows exactly one numeric `value` per event, and progression's was spent on score — leaving **no channel for time at all**. Resolved by moving score back to the already-shipped `game:<game>:end` design event (preserving its live history) and freeing progression `value` for duration, which GA explicitly recommends it for. New §5.3.2 separates three questions that were being conflated: app-wide session length (**native, free, already flowing**), per-game playtime (`time:<game>`, one event per visit, sum = total / mean = avg), and per-level time-to-complete (rides existing progression events). Added `time:lounge` so that app playtime minus the sum of all `time:*` yields the **menu residual** — the slice nobody measures. **D4 rises 9→10**: the unused-lever criticism that capped it since v3 is now resolved — every native channel, including the value field, carries its highest-value payload. D7/D8 unchanged and still evidence-gated. |
| v5 | 10 | 10 | 10 | 9 | 10 | 10 | 9 | 9 | **9.63** | **A** | Scope addition, not a quality round: **feature census** (Carson, 2026-08-01) — "track what functionality is used and what isn't". v1–v4 were decision-driven; this adds a coverage-driven layer (D-16, §5.5) over every optional affordance. Governing rule: **used ÷ exposed, never a raw count** — Depth Charge and Lounge Cat already have their denominator free, since §5.2 models them as resource source/sink pairs. Sweeping every `Button` in the six game views produced two product findings independent of analytics: **How To Play exists in only 2 of 6 games**, and **Totem has no optional affordances at all**. Also corrected a premise: **Navigator has no hint system — Cipher does** (free daily "Vic's Tip" + charged), and neither was instrumented. Added §5.2.1 on reading the shop's most/least-purchased ranking, whose naive form is confounded by a 50→1800 price spread — rank within price bands, and pair the sink with `lounge:nextup` for conversion-at-the-rung. Dimension scores unchanged; same three evidence-gated items still cap D4/D7/D8. |
| v4 | 10 | 10 | 10 | 9 | 10 | 10 | 9 | 9 | **9.63** | **A** | Scope addition, not a quality round: lounge usage (Carson, 2026-08-01). v3 gave a 3,271-line meta-game two design events. Added D-13/14/15, nine lounge events, the buyer→decorator distinction (collecting vs arranging), and a `lounge:nextup:<itemID>` aspiration signal off the existing NEXT-UP computation. Two things the survey forced: **`commitPlacement` fires on every drag end** (LoungeView.swift:144), so 50+ events per rearranging session — latched to once per lounge visit, same discipline as the per-move ban; and the 4th dimension candidate had no slot, resolved by **staging `custom_02`** (write-once first-game → lounge engagement at Phase 3, prefix-namespaced so the eras can't blur). Dimension scores unchanged — the addition was executed to the same standard, and the same three evidence-gated items still cap D4/D7/D8. |
| v3 | 10 | 10 | 10 | 9 | 10 | 10 | 9 | 9 | **9.63** | **A** | Cardinality total corrected and re-verified by script (1,768); Cipher `p02` pinned to `"phrase_%03d"` of `% 300`; the sheet-impression site decided (instrument `OutOfLivesSheet.onAppear`, not its six callers); breadth un-banded to `games_1…games_6`. Two substantive additions: **§2.3 the weekly read** — eight numbers, each tied to a decision with a "this is bad" line, which is the operating layer v2 lacked — and **§8.2 a post-ship verification procedure** built on today's finding that GA's debug log misreports design-event payloads. D4 held at 9 (progression03 remains an unused lever with no verified use case); D7 at 9 (effort estimates are judgement, not measurement); D8 at 9 (the consent posture is Carson's decision, not one the plan can close). **Passes: avg ≥ 9.3, no dimension < 8.** |
| v2 | 8 | 8 | 9 | 9 | 8 | 9 | 9 | 9 | 8.63 | B+ | Fixed everything v1 was marked down for. New faults, found by re-review: **the §6.1 cardinality total is arithmetically wrong** (1,762 stated, 1,768 actual) in the very table claiming to be measured (D2); Cipher's `p02` range is off-by-one against `% 300` (D5); §8 leaves a live design decision to the reader ("consider hoisting") which D5 forbids (D5); breadth is banded at `games_4plus` for no reason when 20 dimension values are available and 6 games exist (D1); and there is **no operating layer** — nothing tells anyone which numbers to look at weekly, which is what separates a strategy from an event spec (D1). |
| v1 | 7 | 6 | 7 | 8 | 5 | 6 | 8 | 6 | 6.63 | C+ | Taxonomy and decision register are sound, but: no call sites for any NEW hook (D5); the 500-events/user/day cap is quoted then never applied, and Cipher's `phraseIndex` grows unbounded so `phrase_NNN` is a cardinality bomb (D2); LevelForge's cherry-picked sources would break if Analytics lands in shared engine files, unmentioned (D6); D-2 ("which game gets the sprint") is **not computable** — retention can only be split by the 3 custom dimensions, and none of them encodes "ever played game X" (D1); COPPA/GDPR/opt-out absent (D8). |
