# Cipher Streak Stamp — Quality Rubric

Scope: the CRACKED-panel streak moment after the 2026-08-02 rework — a stamp
that slams in BELOW the card (Carson: "outside the card, underneath… really
nice animation, the user shouldn't miss it… slam… maybe different colours
depending on how high the streak").

Reference class: Clash Royale victory/trophy stamps, Balatro score slams,
Candy Crush clear banners (impact + transience), Duolingo streak flame
(escalating milestone color), house components (MilestoneToast, LeaderboardBar,
CRACKED card, Luau fuse banner). Platform: Apple HIG motion — Reduce Motion
must remove scaling/repeat effects, no flashing.

Pass bar: **average ≥ 9.3 AND no dimension below 8.** Locked before scoring.

## Dimensions (0–10)

1. **Unmissability** — 10/10: within ~1.5s of the panel landing, the streak is
   the highest-salience element on screen — clear of the card's text pile, in
   its own band below the card, arriving with motion large enough that a player
   staring at the keyboard row still catches it. Evidence: frame extraction.
2. **Impact feel** — 10/10: arrival reads as a physical stamp: first visible
   pixel → settled in ≤ 0.4s, one decisive overshoot (no wobble tail), an
   impact accent (ring/flash) synchronized with the landing frame ±1 frame,
   haptic fired at the same moment (code-verified; sim can't play haptics).
3. **Escalation & reward scaling** — 10/10: higher streaks read categorically
   hotter — tier color ladder + flame count step; the N−1→N odometer roll
   sells growth; YOUR BEST YET gets its own later beat; a 20+ streak looks
   rare (glow-tide cyan exists nowhere else in the panels).
4. **Legibility & contrast** — 10/10: every tier's headline measures ≥ 4.5:1
   against its plaque fill in-situ (screenshot-sampled); rest-state headline
   ≥ ~17pt effective; stamp fits phone-width at "12 IN A ROW ENDS"-class
   lengths and never collides with the card or screen bottom (SE class).
5. **House cohesion** — 10/10: plaque geometry (corner radius, ink stroke
   weight), Futura caps + tracking, and spring parameters are indistinguishable
   from existing house chrome; all colors from `P` palette (+ the panel gold);
   no alien easing curves.
6. **Choreography discipline** — 10/10: beats land in sequence — panel →
   slam → roll → best-pop → settle-to-chip — each ≥ 0.25s apart, nothing
   fights the golden-wave tail or the mint toast (stacking handled); full
   celebration ≤ 3.5s; NEXT PHRASE never blocked.
7. **Motion accessibility & restraint** — 10/10: Reduce Motion lands the
   settled chip with zero slam/roll/repeatForever; no >3Hz flashing; rest
   state is calm enough to sit under a thumb-hover indefinitely (flicker
   ≤ ~±10% scale, slow).

## Iteration log

| version | 1 | 2 | 3 | 4 | 5 | 6 | 7 | avg | grade | delta diagnosis |
|---|---|---|---|---|---|---|---|---|---|---|
| v1 | 7.5 | 7 | 8 | 8.5 | 9 | 8.5 | 9 | 8.21 | B | 20fps film: slam arrives as a FADE (opacity rides the spring) so no mass lands; ring 1–2 frames late, no overshoot; plank-on-teal blends; mint toast moves first and steals the eye; roll + settle + stacking all verified clean |
| v2 | 9 | 9 | 9.5 | 9 | 9 | 9.5 | 9 | 9.14 | A− | opacity split from spring = opaque mass falls (f31); ring ±1 frame; tier glow owns the lower half; toast deferred to 1.95s (filmed); ladder gold→sunset→white-hot+twins→cyan measured; contrast 5.1/8.7/5.9, sunset 4.1 vs 3.0 large-text; SE fit incl. longest teach line; overshoot still subtle, RM path unfilmed |
| v3 | 9.5 | 9.5 | 9.5 | 9 | 9 | 9.5 | 9.5 | 9.36 | A | landing stroke-flash (ink→tier→ink 0.22s) + bounce 0.36: impact reads in a single 30fps frame, first-pixel→settled ≈100ms; RM filmed static (0.0 diff/1s, settled chip, count final). PASS — remaining points are device-only (haptic feel, ProMotion) and handed to Carson |
