# STACKS PLACEMENT-FORGIVENESS RUBRIC

Grades Block Blast-style magnetic placement in Tiki Stacks: the ghost (and
drop) snap to the nearest legal origin within a tolerance instead of
requiring exact cell alignment. **Target: A = avg ≥ 9.0 AND no dimension
< 8.** Evidence: executable scenario tests + regression runs; the mid-drag
ghost itself has no headless path (device feel is Carson's).

Reference class: Block Blast / Woodoku drop forgiveness (near-miss drops
land; edge drags pull in; precise drops never reroute).

## Dimensions

1. **Snap correctness** — executable scenarios prove: exact-legal unchanged,
   one-cell miss snaps to the nearest legal neighbor, all-blocked within
   radius yields nil, edge overhang clamps in within radius, far-off-board
   (over the tray) never ghosts.
2. **Precision preserved** — a legal exact placement always wins (distance
   0); forgiveness only engages when the rounded origin is illegal.
3. **Calibration** — radius ~1.25 cells: catches one-cell misses and lean-in
   diagonals, never teleports (diagonal-at-rest 1.41 excluded); deterministic
   tie-breaking.
4. **Regression safety** — tutorial + autoplay + bot paths untouched (they
   call canPlace/place directly); build green, no new warnings; ghost render
   path unchanged (only the origin computation moved).
5. **Cost** — ≤ 9 extra canPlace probes per drag frame (each ≤ 9 cell reads);
   no allocation in the hot path.
6. **Device feel** — snapping magnetism under a thumb (gated: Carson).

## Iteration log

| version | 1 Correct | 2 Precision | 3 Calib | 4 Regress | 5 Cost | 6 Feel | avg | grade | delta diagnosis |
|---------|-----------|-------------|---------|-----------|--------|--------|-----|-------|-----------------|
| v1 (snappedOrigin + forgiving ghost) | 9.5 | 10 | 9 | 9.5 | 10 | 8 | 9.33 | **A** | TIKI_STACKS_SNAPTEST 6/6 scenarios 0 failures on the real model (exact-legal keeps its cell, one-cell miss snaps — including a distance tie resolved deterministically, all-blocked-within-radius nil, 1×4 edge overhang clamps in at d=1.0, far overhang d=2.4 nil, over-tray d=2.5 nil); precision preservation is structural (a legal rounded origin is strictly nearest except at exact .5 ambiguity); tutorial autoplay re-passed 4/4 → 0/0/0 on the final binary; autoplay/bot/place paths untouched (they never used ghostOrigin); cost ≤ 9 canPlace probes per drag frame. Feel 8 (gated): the 1.25-cell radius is genre-reasoned but a thumb hasn't confirmed the magnetism — Carson's device pass, alongside rotation. |
