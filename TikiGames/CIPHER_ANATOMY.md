# Cabana Cipher — Code anatomy (Cipher 2.0, hangman model)

Player-facing name: **Cabana Cipher**. Engine/id: **`cabanaCipher`** / route `"cabanaCipher"` (TIKI_OPEN value).

Regenerated 2026-08-01 for the Wheel-of-Fortune pivot on branch `cipher-wof`
(supersedes the cursor-cryptogram edition). Sources:

| File | Role |
|------|------|
| `CipherGame.swift` | Pure hangman engine: catalog, mapping + twin repair, guess/miss, scoring, persistence |
| `CipherView.swift` | Board/keyboard/coach/category strip, panel timing, debug hooks |
| `CipherPanels.swift` | CRACKED / OUT OF MISSES / LAST CALL panels, matchbook covers, match-strike beat |
| `CipherBackgroundView.swift` | Poolside scenery driven by `ProgressPhase` (unchanged by the pivot) |

Tests: `CipherAdversarialTests.swift` (goldens, twin-pair invariant, miss round-trip, drift hygiene, cap/lives, hostile saves).
Quality gates: `CIPHER_PHRASE_RUBRIC.md` (content — every phrase graded A), `CIPHER_WOF_RUBRIC.md` (experience — judge-panel iteration log).
Content source of truth: `CIPHER_PHRASES_DRAFT.md` — the catalog literal is GENERATED from it; edit the doc and regenerate, never hand-edit the Swift literal.

---

## 1. Product shape in one paragraph

**Cabana Cipher** is **hangman-style letter guessing over a substitution
cipher**. Each phrase is a famous saying (ALL-CAPS A–Z + spaces), encrypted
with a deterministic per-index cipher so SwiftData restores re-derive the same
board; unsolved tiles show **geometric symbols** (same symbol = same letter —
the pattern-hint layer WoF doesn't have). Input is one tap: **any keyboard
letter — if it's in the phrase it fills every position at once; if not it's a
MISS**, struck out on the keyboard (opaque coral burn) and inert thereafter.
**5 misses** end the phrase (**OUT OF MISSES**, one life). A **category
strike-strip** above the board (10 categories) keeps recognition fair; every
board opens with its busiest letter poured free (the **house pour**). **HINT**
reveals the most-connected unsolved letter for score; **Vic's Tip** is one
free reveal per calendar day (guarded during the coach). Content is **50
matchbooks × 6 phrases = 300**; each completed book pays **+100**; the full
wall pours **LAST CALL** (scrollable 50-cover wall, 16 cover paintings
shuffled per block) then a house-shuffle second round at quarter pay. Cracked
phrases `recordRun`; cold phrases spend a life and never `recordRun`.

---

## 2. Engine — `CipherGame.swift`

### 2.1 Types & constants

| Block | Role |
|-------|------|
| `mistakeCap` | **5** — the fifth miss goes cold |
| `Matchbook` | `id`, `name`, `phrases: [String]` (always 6) |
| `matchbooks` | **50** books; ids of books 1–16 unchanged from the 96-era (save compat); 17–50 new tiki names (outrigger…closingtime) |
| `phrases` | `matchbooks.flatMap(\.phrases)` — **300** strings |
| `CipherCategory` | 10 cases, rawValue = strike-strip label (OLD WISDOM … GAME ON) |
| `categories` | `[CipherCategory]` parallel to `phrases`; `currentCategory` computed |
| `confusableCipherPairs` | The ten filled/hollow symbol twins (A–B, C–D, … X–Y) the repair pass keeps off one board |
| `matchbook(forPhraseAt:)` | Wrap index → `(book, 1-based number)`; negative-fold guarded |

### 2.2 State

| Field | Role |
|-------|------|
| `phraseIndex` | Raw flat index (grows past 300; content wraps, mapping seeds from the RAW index) |
| `mapping` / `reverse` | plain→cipher / cipher→plain bijections |
| `solvedLetters` | cipher→plain locked assignments (one entry fills every tile of that letter) |
| `misses` | `Set<Character>` — struck keyboard letters; globally wrong, inert on re-tap |
| `mistakes` / `hints` | Counters (mistakes == misses count in normal play; junk input also counts) |
| `mistakeBeat` / `lockBeat` | Monotone beat counters (lockBeat drives the background pulse) |
| `isComplete` / `isFailed` | Terminal phrase states |
| `solvedCount` | Lifetime cracked phrases (persisted; books/pennants/milestones) |
| `coachShield` | While true, `evaluateFailure` is a no-op |
| `coachTargetPlain` | Most frequent still-hidden plain letter — the coach's sure-hit key |
| `lastFreeHintDay` / `lastRunSummary` | Vic's daily tip key; view fills summary on crack |

### 2.3 Core algorithms

```
buildMapping()
  seed = phraseIndex &* 2654435761 &+ 97 → LCG
  roll ≤64× until no phrase letter maps to itself
  REPAIR (deterministic, alphabet-order scans):
    for each confusable twin pair with BOTH members on phrase letters:
      re-seat the second member's plain letter onto an unused cipher letter
      whose own twin is also off-board; if the identity guard blocks the only
      safe target, re-seat the FIRST member instead (provably succeeds ≤16
      distinct letters; 17+ keeps exactly one pair — pigeonhole floor,
      8/600 boards, invariant-tested)
  // Mirror ANY change in the python replica before regenerating goldens.

guess(plain) → Bool                      // target-free hangman
  guard live, not already solved/missed
  if phrase.contains(plain) && mapping[plain] != nil:
    lock all positions; lockBeat++; checkComplete; true
  else:
    mistakes++; misses.insert(plain); mistakeBeat++; evaluateFailure; false
  // space/junk fall to the miss path (mapping covers A–Z only)

hint(charged:)   → reveals mostConnectedUnsolved; charged bumps hints
seedStartingReveal (house pour) → uncharged busiest-letter reveal
clearCoachResidue() → zero mistakes/hints/misses/isFailed — MUST run before
  the coach shield drops (shielded misses would detonate a defeat + life)
begin(index:restoring:mistakes:hints:misses:)
  filter restored pairs vs derived cipher; CONTENT DRIFT (assignments present
  but none survive) keeps wall position, zeroes counters, fresh pour;
  re-arms isFailed at the cap (force-quit can't launder a cold phrase)
```

### 2.4 Scoring (unchanged law, new base)

`completionScore = max(20, letters*3 − mistakes*10 − hints*15) + (clean ? 15 : 0)`
House pour and Vic's free tip never charge. CLEAN STRIKE renders **unnumbered**
on the panel (the +15 is score units; the panel's only visible currency is
wallet points — panel R2).

### 2.5 Persistence

`SavePayload`: `seenHowTo, phraseIndex, solvedCount, assignments, mistakes,
hints, lastFreeHintDay?, misses?` — `misses` optional so **pre-hangman saves
decode** (and `misses == nil` is the one-shot migration signal that opens the
how-to re-teach). Completion persists as NEXT index, fresh. Restore hygiene:
single-Character pairs, index 0..<1e6, counters clamped ≤100k, **solvedCount
clamped ≤1e6** (Int.max used to overflow-trap on the next solve).

### 2.6 DEBUG hooks

| Env | Effect |
|-----|--------|
| `TIKI_OPEN=cabanaCipher` | Route straight into the game |
| `TIKI_CIPHER_SOLVED=<n>` | solvedCount = n, board at phrase n, coach off, seenHowTo on |
| `TIKI_CIPHER_MISTAKES=<n>` | Stage the counter (no struck keys — staged ≠ real defeat visually) |
| `TIKI_AUTOPLAY=1` | Crack current phrase (one deliberate miss + one hint + sure hits) |
| `TIKI_CIPHER_CLEAN=1` | Autoplay clean (CLEAN STRIKE staging) |
| `TIKI_CIPHER_HOLD=<k>` | Stop autoplay with k letters left |
| `TIKI_CIPHER_ADVANCE=1` | Tap NEXT after the solve (LAST CALL staging via SOLVED=299) |
| `TIKI_CIPHER_TUTORIAL_AUTOPLAY=1` | Walk the 2 coach beats |
| `TIKI_LB=1` | Open leaderboard, suppress coach |

Golden contracts (regenerate via the python replica in the session notes —
derived, never pasted from failures; one board hand-decoded per regen):

| Index | Cipher text |
|-------|-------------|
| 0 | `XUN NQTWO ZCTH MNXA XUN KITE` (THE EARLY BIRD GETS THE WORM) |
| 42 | `WFIQDPM SWA WFIQDPM SIYYWM` |
| 300 | `KMF FGUIR SZUA PGKPMFC KMF XNUO` (same plaintext as 0, raw-index seed) |

House pour board 0: `["M": "E"]`. Hint tie-break pin: cipher `T` (plain R).

---

## 3. View — `CipherView.swift`

### 3.1 Board & keyboard

- Tiles are **display-only** (no gestures): unsolved = symbol on lagoon,
  solved = plain letter on cream, flip-with-stagger cascade on lock
  (`order * 0.025s`, Reduce Motion → cross-fade, no stagger).
- Category strike-strip capsule above the tiles (`currentCategory.rawValue`).
- Keyboard 3 rows (`ABCDEFGHI / JKLMNOPQR / STUVWXYZ`); **every key state has
  an OPAQUE base** (cream) so background props can never wash it: live =
  cream/ink; ghost-solved = + ink 0.12 wash, glyph ink 0.3; struck = + coral
  0.35 wash, coral glyph, 1.5pt coral border, 2.5pt rotated strike bar.
  VoiceOver values: "struck out" / "already revealed".
- Header: title + `BOOK · No. n · MISSES n/5` inset 52pt clear of the shell
  chevron, single-line with minScale 0.75. Post-solve the keyboard + hint row
  dim to 0.35 while the CRACKED delay runs (no live-looking dead taps).

### 3.2 Coach (2 beats) & FTUE

- Beat 0: card "TAP THE GLOWING LETTER"; ONLY the keyboard key pulses
  (`coachTargetPlain`); its destination tiles glow with a static torch stroke;
  spotlight dims everything else. Beat 1: "STUCK? TAP HINT" (free).
- SKIP chip at `skipTopPadding: 118 → 190` (clear of chevron AND card).
- **Graduation paths**: beat progression, SKIP, or **solving the phrase**
  (`finishIfComplete` dismisses with success; ready banner suppressed there).
  `dismissCoach` calls `game.clearCoachResidue()` BEFORE the shield drops.
- Phrase 0 pinned for FTUE (THE EARLY BIRD GETS THE WORM); house pour is
  the only pre-reveal. Pre-pivot saves (`misses == nil`) open HOW TO CRACK
  once. Vic's Tip is a no-op while the coach is live.

### 3.3 Panel timing (the hero cascade)

`finishIfComplete`: economy lands immediately (book +100 at `solvedCount%6`,
milestones bits 14–17 at 1/4/8/16 books, `recordRun` — quarter-rate `earnScore`
for looped indices ≥300); the CRACKED **presentation + win SFX + haptic** run
on `crackedTask` after `min(1.6, 0.45 + letters*0.025)`s (RM: 0.25s) so the
cascade finishes in the clear. The task is cancelled `onDisappear` (fanfare
can never play over the lounge). The completing guess skips `clear()` — win
owns the moment. `crackedShown` resets on advance/retry, and drops WITHOUT
animation when LAST CALL arms (no bleed through the ceremony scrim).

### 3.4 Panels — `CipherPanels.swift`

| Panel | Notes |
|-------|-------|
| CRACKED | Phrase quote; CLEAN STRIKE badge (unnumbered) + match-strike beat (RM: lands lit, no flicker); `MISSES n · HINTS n`; wallet lines; NEXT PHRASE |
| OUT OF MISSES | "FIVE MISSES ENDED THE PHRASE"; hearts row (a11y "Lives remaining n of 5"); ALL GAMES / PLAY AGAIN |
| LAST CALL | Fires when `(phraseIndex+1) % 300 == 0`; **opaque** ink scrim; 5-col scrollable 50-cover wall with bottom fade (scroll affordance); 16 cover paintings assigned by per-block seeded shuffle; covers pop staggered (RM: fade together) |

---

## 4. Lives & wallet (shared canon)

Crack → `recordRun(completionScore)`; looped (≥300) quarter-rate. Cold phrase →
`spendLifeForDefeat`, **no recordRun**. Book +100 capped at `matchbooks.count`.
Background pennant tier caps at 16 (both cap sites documented). ⚠ OPEN CANON
QUESTION (owner): `advanceTapped` gates post-WIN NEXT PHRASE on lives; canon
says lives spend on DEFEAT only.

---

## 5. Related docs

`CIPHER_PHRASES_DRAFT.md` (content + wall order, generated-from),
`CIPHER_PHRASE_RUBRIC.md` (content gate + iteration log),
`CIPHER_WOF_RUBRIC.md` (experience gate + iteration log),
sibling `*_ANATOMY.md` docs, `DOCUMENTATION.md` index.

*Regenerated from `cipher-wof` sources. Update alongside behavior changes.*
