# Android Port Plan — Tiki Lounge

**Status:** Phases 0–7 scaffold complete (playable six-game Android twin; Lounge/Nightly shell; local leaderboards; not pixel-parity)  
**Stack:** Kotlin · Jetpack Compose · native Android only  
**Source of truth for product:** iOS app in `TikiGames/` (~28k LOC Swift, 6 games + Lounge)  
**Companion docs:** `ONBOARDING_RUBRIC.md`, `PROGRESSION_PLAN.md`, `PICKER_SPEC.md`, `GAME_FEEL_RUBRIC.md`, per-game `*_ONBOARDING_RUBRIC.md`

---

## 1. Intent

Build an **Android twin** of Tiki Lounge — same rules, art, economy, and diegetic first-run coaches — not a line-for-line SwiftUI translation and not a shared multiplatform UI.

| Decision | Choice | Why |
|----------|--------|-----|
| UI | Jetpack Compose | Closest mental model to SwiftUI; fine for board games + canvas scenery |
| Language | Kotlin | Native engines + Android ecosystem |
| Game engine | None (Compose + pure logic) | iOS is already non-SpriteKit; no Unity/Godot |
| Code sharing day one | None | iOS stays Swift; rewrite pure rules in Kotlin |
| Code sharing later (optional) | KMP for *engines only* | Only after 2+ games prove stable APIs |
| First public cut | 3 games + shared economy | Full Lounge is phase 2 |
| Onboarding | Port coach *system* + scripts with each game | Not a post-hoc FTUE project |

**Success (long-term):** A Play Store build a player would recognize as Tiki Lounge — picker, lives/points, six puzzles, leaderboards, Nightly Nine, Lounge — with first-run coaches that pass the same bar as `ONBOARDING_RUBRIC.md`.

**Success (first shippable):** Three games, full coach + how-to, lives, points, game over, one leaderboard path, no Lounge furniture required.

---

## 2. What we are porting (inventory)

### 2.1 Product surface (iOS today)

| Area | iOS home | Notes for Android |
|------|----------|-------------------|
| Six games | `*Game.swift` + `*View.swift` | Engines → pure Kotlin; views → Compose |
| Game picker | `GamePickerView` | House chrome; signs/previews later |
| Lives / points / milestones | `PlayerStore` | Domain layer + DataStore |
| Nightly Nine | `PlayerStore` + `LoungeView` | After core economy |
| Lounge | `LoungeView` (~2.8k) | Phase 2 destination |
| First-run coach | `FirstRunCoach` + per-view scripts | Shared Compose coach + script data |
| How to play | `HowToPlay` | Cheap shared panel |
| Leaderboards | Game Center + themed boards | Play Games Services; title **LEADERBOARD** |
| Notifications | Lives restock | WorkManager / alarms |
| Analytics | GameAnalytics | Android SDK |
| Sound / haptics | `TikiSound`, soft-press | Wrappers; feel pass per game |
| Art | `Assets.xcassets` + `assets/` SVGs | Reuse; no re-author |

### 2.2 Scale (order of magnitude)

- ~53 Swift sources, ~28k LOC app code  
- Heaviest UI: Lounge, Luau, picker, per-game views (1–1.6k each)  
- Background canvases: ~500–700 LOC × 6  
- Engines: hundreds of LOC each; Luau largest + generated levels  

This is a **multi-month product**, not a weekend convert.

### 2.3 Non-goals (explicit)

- Sharing SwiftUI/Compose UI  
- Day-one KMP  
- Pixel-perfect lagoon canvas before input feels right  
- Account wall, ads, or difficulty picker before first action  
- Rebuilding iOS “to prepare for Android” first  

---

## 3. Principles

1. **Seams over files** — Copy iOS architecture (pure engine / chrome / platform), not file structure.  
2. **Engines have zero UI types** — No Compose `Color`/`Modifier` in rules. Assets live in UI.  
3. **Economy is the product** — A game without lives/points is a demo; ship hooks early.  
4. **Onboarding is a platform** — Shared coach chrome; per-game seeds + success predicates.  
5. **Literal labels where discovery matters** — Primary board chrome says **LEADERBOARD** (iOS already); keep house voice in empty/join copy and art.  
6. **Feel is a scheduled pass** — “Feature complete” ≠ ship; budget time against iOS reference clips.  
7. **iOS is the oracle** — Fixtures, seeds, screen recordings, rubrics; not pair-programming every file.  
8. **Phase gates are hard** — No Lounge until three games are playable with coaches.  

---

## 4. Architecture

### 4.1 Module map

```text
tiki-lounge-android/   (new repo or /android under monorepo — pick one; prefer monorepo folder later)
  :app                 Application, nav host, DI
  :core:theme          Palette, type, SoftPress, panels (house design system)
  :core:domain         Games enum, run summary, lives/points math interfaces
  :core:data           DataStore/Room, prefs, pending leaderboard queue
  :core:onboarding     CoachSkin, CoachOverlay, CoachController, flags
  :platform            Play Games, notifications, analytics, sound, haptics
  :feature:picker      Game list / home
  :feature:totem       Engine + UI + tutorial script
  :feature:luau
  :feature:topshelf    (Zombie)
  :feature:cipher
  :feature:blueprints
  :feature:navigator
  :feature:lounge      Phase 2
```

Start thinner if solo (`:app` + `:core` + one game package); grow modules when friction appears. Do **not** start with six feature modules and empty shells.

### 4.2 Engine contract (every game)

```text
Engine (pure Kotlin)
  state: BoardState
  intents: place / swap / merge / guess / fill / …
  events: cleared, scored, gameOver, tutorialSucceeded
  seedTutorial(beat) / isTutorial: Boolean
  scoring + win/lose pure functions

UI (Compose)
  collect state → draw board + HUD
  map gestures → intents
  coach overlay reads targets from TutorialScript + state
```

### 4.3 Economy contract

Port the **rules** of `PlayerStore`, not the file:

- Life spend on real defeat (not during tutorial)  
- Restock windows / notifier hooks  
- Points from runs, milestones  
- Nightly Nine progress (phase 2 with Lounge)  
- Per-game “seen how-to / coach complete” + global `onboardingSkipped`  

Persist with **DataStore** first; Room only if structured history demands it.

### 4.4 Platform mapping

| iOS | Android |
|-----|---------|
| Game Center leaderboards | Play Games Services (v2) |
| Local notifications | WorkManager + notification channels; exact alarms if restock timing requires |
| GameAnalytics | GameAnalytics Android SDK |
| UserDefaults / files | DataStore |
| StoreKit (if/when) | Play Billing (later) |
| Haptics | `HapticFeedback` / vibrator behind interface |
| AVFoundation ticks | SoundPool / ExoPlayer stubs → full SFX pass |

All behind `:platform` interfaces so features never import Play Services directly.

### 4.5 Design system (first real code)

Before any full game UI:

- Color tokens from `assets/palette` / house `P.*`  
- Type: Futura-equivalent (licensed font or close geometric sans)  
- Soft-press button style  
- Wood/cream panels (How to play, game over)  
- Leaderboard bar + sheet skeleton (title **LEADERBOARD**)  

Games compose on top of this; they do not invent chrome.

---

## 5. Onboarding plan (first-class)

### 5.1 Model (match iOS)

| Layer | Role |
|-------|------|
| **First-run coach** | Live board + card + pulse + arrow; dismiss on correct action; SKIP always |
| **How to play** | Optional `?` panel; static rules; anytime |

**Policy (non-negotiable):**

- ≤ ~5s from first paint to first legal input (no welcome modal)  
- Fixed **seeded** first board; ≥ high first-gesture success  
- ≤ ~6–8 words; diegetic verb  
- One core atom on first fire (progressive disclosure for later beats)  
- Tutorial does **not** spend lives, mint leaderboard scores, or corrupt Nightly progress  
- SKIP marks seen / can set global skip; silent dismiss  
- Respect reduced motion  

Rubric: `ONBOARDING_RUBRIC.md` and per-game onboarding rubrics — Android targets the same pass bar.

### 5.2 Implementation shape

```text
:core:onboarding
  CoachSkin (per game wardrobe)
  CoachCard + SKIP
  CoachPulse + CoachArrow
  CoachController(activeBeat, onSkip, onSuccess)

per game
  TutorialScript: List<Beat>
  Beat(message, highlights, arrow, succeedWhen)
  engine.seedTutorial(beatIndex)
```

Scripts as **data + predicates**, not Compose spaghetti. Unit-test: from seed, only the intended move advances the beat.

### 5.3 Rollout with games

| Game wave | Coach scope |
|-----------|-------------|
| Totem first | Single-atom coach + How to play + global skip flags |
| Luau second | Multi-beat coach (proves controller + board ownership) |
| Game 3 | One more script (Cipher or Blueprints recommended) |
| Remaining games | Scripts only; no new FTUE framework |
| Meta | Lives explained **just-in-time** (first empty / first restock), not pre-game lecture |

### 5.4 Analytics (from first coach)

- `coach_start` / `coach_step` / `coach_complete` / `coach_skip` (game id, beat)  
- Time to first successful action  
- Drop-off by beat (especially Luau)  

---

## 6. Phased roadmap

### Phase 0 — Skeleton (≈ 1 week solo)

**Deliverables**

- Android project, Compose BOM, package structure  
- Theme tokens + SoftPress + empty nav: Home → placeholder game → Game over → Home  
- Domain stubs: lives, points, `onboardingSkipped`, per-game seen flags  
- Analytics + sound interfaces (no-ops OK)  
- CI: unit test task green  

**Exit:** Installable APK; navigate shell on a physical device.

---

### Phase 1 — Totem vertical slice (≈ 2–3 weeks)

**Deliverables**

- Totem engine in pure Kotlin + golden tests (score / clear / game over fixtures from iOS)  
- Board UI + gestures + game over  
- Life spend on real defeat; points on run  
- Full first-run coach (seed + pulse + arrow + SKIP)  
- How to play panel  
- Placeholder or simplified background (full canvas later)  

**Exit:** New install → open Totem → coach → complete tutorial → real run → game over → lives/points updated. Side-by-side feel notes vs iOS (written list).

---

### Phase 2 — Luau + multi-beat coach (≈ 2–3 weeks)

**Deliverables**

- Luau engine + level data port (export generated levels to neutral JSON/codegen; keep seeds)  
- Campaign/endless minimum viable path matching iOS entry for first night  
- Multi-beat coach script  
- Same economy hooks; tutorial shields progression  
- Feel pass: swap, cascade timing constants in `Feel.kt`  

**Exit:** Coach multi-step complete/skip; Night 1 completable; tests for match rules and tutorial predicates.

---

### Phase 3 — Third game + shared chrome polish (≈ 2 weeks)

**Pick one:** Cipher or Blueprints (strong puzzle identity, coach ladder already designed on iOS).

**Deliverables**

- Engine + UI + coach + how-to  
- Shared game-over / leaderboard **bar** chrome (literal LEADERBOARD)  
- Picker shows three games as first-class; others “coming” or hidden  

**Exit:** Three-game internal beta; picker feels like Tiki Lounge lite.

---

### Phase 4 — Platform services (≈ 1–2 weeks)

**Deliverables**

- Play Games auth + submit/load one board, then all shipped games  
- Leaderboard screen (themed podium art can lag; structure first)  
- Lives restock notifications  
- GameAnalytics events (session, run end, coach funnel)  

**Exit:** Rank visible on device with a test account; restock notify fires in staging.

---

### Phase 5 — Remaining games (≈ 3–5 weeks)

Order suggestion:

1. Top Shelf (Zombie) — if not already game 3  
2. The other of Cipher/Blueprints  
3. Navigator last (voyage + passages leaderboard semantics)  

Each game ticket includes: engine tests, UI, coach script, how-to copy, economy hooks, feel checklist.

**Exit:** Six games playable with coaches; still no full Lounge required.

---

### Phase 6 — Meta & Lounge (≈ 3–5 weeks)

**Deliverables**

- Nightly Nine  
- Lounge v2 surface (furniture, Vic, claims) — port behavior from `LOUNGE_V2_PLAN` / iOS  
- Post-tutorial reveals (lives explained, milestone toasts)  
- Picker polish (signs, previews if assets allow)  
- Full background canvas pass (batch)  
- Accessibility / reduced motion audit  

**Exit:** Feature parity target for Play closed test.

---

### Phase 7 — Ship prep

- Store listing, screenshots, data safety, content rating  
- Play Billing only if monetization exists (iOS is free-to-play; keep free)  
- Crash/ANR budget, API level matrix (minSdk: modern, match “iOS 17” spirit → API 26+ or 29+ as chosen)  
- Open testing → production  

---

## 7. Game order & rationale

| Order | Game | Why here |
|-------|------|----------|
| 1 | **Totem** | Clear grid, house identity, single-atom coach |
| 2 | **Luau** | Purest engine; multi-beat coach stress-test; level data pipeline |
| 3 | **Cipher or Blueprints** | Deep puzzle; coach ladder without voyage complexity |
| 4–5 | Remaining grid/puzzle | Pattern established |
| 6 | **Navigator** | Special leaderboard metric (passages); coach + voyage UX |
| Last | **Lounge + Nightly** | Destination content; depends on stable economy |

---

## 8. Testing strategy

| Layer | What |
|-------|------|
| Engine unit tests | Rules, scores, seeds, tutorial predicates — every PR |
| Golden fixtures | Port critical iOS self-test cases (Luau especially) |
| Coach tests | Beat N + only intended action advances |
| UI | Manual + device matrix; screenshot tests for chrome tokens only at first |
| Feel | Per-game checklist from `GAME_FEEL_RUBRIC.md`; 30s iOS reference clips |
| DoD per game | See §9 |

Staging hooks (like iOS `TIKI_*` / simctl): debug menu — reset coach, force seed, mock leaderboard.

---

## 9. Definition of done (per game)

1. Completes a full run on physical device  
2. First install shows coach; success and SKIP both leave a clean real run  
3. Tutorial never spends lives or submits leaderboard scores  
4. Real defeat spends a life; points update as on iOS for that path  
5. How to play opens/closes without breaking state  
6. Fixed-seed / fixture tests match iOS scoring for listed scenarios  
7. Gesture feel signed off against iOS reference (written deltas resolved or accepted)  
8. Analytics events fire for run end + coach funnel  

---

## 10. Risk register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Scope (Lounge + 6 games + meta) | Endless WIP | Hard gates; first ship = 3 games |
| Luau / match feel never “snaps” | Soft product | Gesture lab before full UI; `Feel.kt` constants |
| Coach leaks into progression | Economy bugs, angry players | Domain-level `duringTutorial`; tests |
| Play Games auth friction | Leaderboards late | Offline-first ranks stub; wire PGS in Phase 4 |
| Canvas scenery time sink | Delays playable | Placeholders until Phase 6 batch |
| Solo bandwidth | Slip | One owner; iOS as oracle; no dual KMP tax early |
| Rule drift from iOS | Dual products | Golden tests; fixture export from iOS when unsure |

---

## 11. Team & working mode

- **One Android owner** end-to-end preferred for Phase 0–3  
- **iOS / design** supplies: rubrics, seeds, recordings, copy sheet (plain-English labels already on main)  
- **PR size:** one vertical slice or one coach script at a time  
- **No** “rewrite iOS PlayerStore for sharing” track unless dual maintenance is committed for 12+ months  

---

## 12. Repo & tooling recommendations

| Topic | Recommendation |
|-------|----------------|
| Location | New `android/` at monorepo root **or** `tiki-lounge-android` repo; monorepo eases asset reuse |
| Assets | Share `assets/` SVGs; pipeline to Android vector/drawable as needed |
| Levels | Export Luau levels to versioned JSON consumed by both (optional later); Android can vend from copied data first |
| Min SDK | API 29+ unless a hard reason to go lower |
| Language | Kotlin official; Compose BOM pinned |
| DI | Manual or lightweight (e.g. Metro/Koin) — avoid heavy ceremony early |

---

## 13. Effort sketch (solo, focused)

| Phase | Calendar (rough) |
|-------|------------------|
| 0 Skeleton | ~1 week |
| 1 Totem + coach | ~2–3 weeks |
| 2 Luau + multi-beat | ~2–3 weeks |
| 3 Third game + chrome | ~2 weeks |
| 4 Platform services | ~1–2 weeks |
| 5 Games 4–6 | ~3–5 weeks |
| 6 Lounge + meta | ~3–5 weeks |
| 7 Ship prep | ~1–2 weeks |

**First internal playable (3 games):** ~2–3 months focused.  
**Parity-class closed test:** ~4–6 months focused.  
Part-time stretches these roughly 1.5–2×.

---

## 14. First two weeks (concrete backlog)

### Week 1

1. Create Android project + modules skeleton  
2. Port palette + type + SoftPress + panel primitives  
3. Nav: Picker (stub) → Totem (empty board) → GameOver (stub)  
4. `PlayerStore`-shaped domain: lives, points, coach flags + DataStore  
5. `CoachOverlay` composable with fake beat (hardcoded targets)  

### Week 2

1. Totem engine + unit tests  
2. Totem board render + place/rotate input  
3. Wire life spend + score on game over  
4. Real Totem tutorial seed + success predicate + SKIP  
5. Device install; capture feel delta list vs iOS Totem  

---

## 15. Open decisions

| # | Decision | Status |
|---|----------|--------|
| 1 | Monorepo `android/` vs separate repo | **Resolved:** monorepo `android/` |
| 2 | Min SDK / target SDK | **Resolved:** min 29, target/compile 35 |
| 3 | Package name | **Resolved:** `com.example.tikilounge` |
| 4 | Play Games project in Play Console | Open (Phase 4) |
| 5 | First public track | Open |
| 6 | Font licensing (Futura-class) | Open — system sans for now |

---

## 16. Summary

Port Tiki Lounge to Android by **reimplementing pure game rules in Kotlin**, **rebuilding UI in Compose** on a **shared house design system**, and treating **first-run coaching as a reusable platform** delivered with each game — not after. Ship **Totem → Luau → third game** with full economy and coach policy, then platform services, then remaining games, then Lounge/Nightly. Optimize for **feel and FTUE quality** over early visual parity or cross-platform code sharing.

When this plan is accepted, Phase 0 ticket 1 is: create the Android project and design-system module.
