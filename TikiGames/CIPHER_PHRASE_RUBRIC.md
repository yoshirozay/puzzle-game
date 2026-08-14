# Cabana Cipher — "A phrase" Rubric (v1, LOCKED 2026-07-31)

Purpose: binary gate for the 300-phrase catalog. A phrase is either an **A** (ships)
or it is dropped. No A+ tier (Carson's call). Applies to every current and future
phrase, including replacements.

Why the bar is recognition-first: the game is hangman-style with a 5-miss defeat
that costs a **life**. An unrecognizable phrase converts directly into unfair life
loss — obscurity is a monetization bug, not just a taste issue.

Reference class: **aired Wheel of Fortune puzzles** (near-universal recognizability),
classic newsstand cryptogram collections, and all-caps crossword-grid conventions
for punctuation.

## Mechanical gate (auto-checked by script, not judged)

A–Z + spaces only · ≤46 chars · ≥2 words · no duplicate phrase in the catalog.

## Dimensions — each scored 0 / 1 / 2; ★ = ship-blocker floor

### 1. ★ RECOGNITION (floor: must be 2)
- **2** — The average US adult has HEARD this exact saying many times. Test: with
  ~half the letters revealed plus the category label, most players could shout the
  rest. ("JACK OF ALL ___" → yes.)
- **1** — Known, but meaningfully skewed by generation, region, or subculture
  (Gen-Z slang, UK-isms, business jargon, dated references).
- **0** — Invented, poster-quote, or niche. Understandable is NOT known.

### 2. ★ CANONICAL WORDING (floor: ≥1)
- **2** — Exactly how the saying is most commonly said/printed (within the A–Z
  charset). NEVER-recasts score 2 only when that form itself circulates widely
  ("NEVER JUDGE A BOOK BY ITS COVER").
- **1** — A minority-but-real printed variant ("WHERE THERE IS A WILL THERE IS A
  WAY" in older proverb form).
- **0** — Stiff de-contraction nobody says ("THAT IS THE WAY THE COOKIE CRUMBLES"),
  awkward truncation of a longer canonical form, or an invented variant of a real
  saying ("SAIL INTO THE SUNSET").

### 3. ★ CLEAN RENDER (floor: ≥1)
- **2** — The all-caps, punctuation-free form reads exactly right.
- **1** — A dropped possessive apostrophe that still reads naturally as caps
  ("SAILORS DELIGHT", "BEGINNERS LUCK").
- **0** — Reads as a plural error or non-word ("SHEEPS CLOTHING", "LIONS SHARE"),
  or a compound spaced/joined incorrectly ("SHIP SHAPE" for SHIPSHAPE).

### 4. ★ STANDALONE PAYOFF (floor: ≥1)
- **2** — A complete idiomatic saying; the reveal lands with "of course!"
- **1** — An idiomatic term or compound with real standing on its own
  ("POKER FACE", "COUCH POTATO", "WILD CARD").
- **0** — Sentence fragment, generic verb phrase ("SPRING INTO ACTION"),
  announcer/marketing filler, or mere vocabulary.

### 5. FAIR PLAY (floor: ≥1)
- **2** — Fair board: no proper-noun dependence beyond household usage
  ("HAIL MARY" ok), family-friendly, not degenerate (≥8 letters or instantly
  known when shorter).
- **1** — Minor concern (very short but famous; mildly cheesy).
- **0** — Needs specific trivia, potentially offensive, or degenerate board.

## The A bar

**A = RECOGNITION 2 AND every other ★ floor met AND total ≥ 8/10.**
Any ★ floor missed = drop, regardless of total.

## Category clause (Carson's rule)

If a category cannot field 30 A phrases within 3 replacement rounds, the category
is not A-generating: shrink it and promote/introduce a category that is.

## Grading protocol

3-judge differentiated panel (WoF puzzle editor · split-age player advocate ·
copy editor), each grading all 300 independently against this file. Drop = ≥2
judges fail it, or 1 judge alleges a ★=0 violation that an adversarial verifier
(told to REFUTE, default isReal=false) confirms. Replacements are graded by the
same panel protocol before entering the catalog. Verdicts are cached — unchanged
phrases are never regraded.

## Iteration log

| round | catalog | fails found | dropped | replacements added | result |
|-------|---------|-------------|---------|--------------------|--------|
| 1 | v2 (300) | judges raw 19/23/14 → 16 majority fails + 16 disputed; adversarial verifier CONFIRMED 1 (STEP OUT OF YOUR COMFORT ZONE), REFUTED 15 (retained) | 17 | — | 283/300 A |
| 2 | v3 (300) | 53-candidate replacement pool panel-graded: 1 majority fail (BACK TO THE SALT MINES), 5 single-judge fails set aside conservatively → 47 clean | 0 | 17 (incl. 1 in-place swap in book 16) | **300/300 A — bar met, loop closed** |

Round-1 drops: A WOLF IN SHEEPS CLOTHING · THE LIONS SHARE · SHIP SHAPE ·
IT IS RAINING CATS AND DOGS · THAT IS THE WAY THE COOKIE CRUMBLES ·
CALM SEAS NEVER MADE A SKILLED SAILOR · SAIL INTO THE SUNSET · LIFE IS A BEACH ·
A DROP IN THE OCEAN · EVERY JOURNEY BEGINS WITH A SINGLE STEP · TEMPEST IN A
TEAPOT · BOLT FROM THE BLUE · SPRING INTO ACTION · THE CROWD GOES WILD ·
MAIN CHARACTER ENERGY · RISE AND GRIND · STEP OUT OF YOUR COMFORT ZONE

Category clause outcome: no category shrunk. SEA & SHORE took the worst round-1
damage (5 drops) and refilled entirely from clean candidates (TEST THE WATERS,
WATER UNDER THE BRIDGE, TAKE THE PLUNGE, UP THE CREEK WITHOUT A PADDLE,
GET YOUR FEET WET) — it is an A-generating category.
