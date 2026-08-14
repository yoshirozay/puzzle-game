import SwiftUI

/// Night beach bonfire party backdrop (Luau match-3). All motion is driven by
/// one TimelineView clock; the palette breathes on a 90-second "bonfire flare"
/// cycle — the low sky and sand warm with ember tint at flare peak, then cool
/// back to indigo and ink. Shared components live in TikiScenery.swift.
struct LuauBackgroundView: View {
    var phase: ProgressPhase = ProgressPhase()   // default = today's behavior exactly
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dial = DepthDial()
    @State private var stageDial = DepthDial()
    @State private var beatAt: TimeInterval = 0
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                // Under reduceMotion the paused clock freezes eased() at its
                // launch value (depth 0) — render the true depth statically.
                LuauScene(
                    t: t, size: geo.size,
                    depth: reduceMotion ? phase.depth : dial.eased(at: t),
                    stage: reduceMotion ? Double(phase.stage) : stageDial.eased(at: t),
                    tier: phase.tier,
                    swell: phase.swell,
                    beat: phase.beat,
                    beatAt: beatAt
                )
            }
        }
        .ignoresSafeArea()
        .onChange(of: phase.depth, initial: true) { _, newDepth in
            dial.set(newDepth, at: Date().timeIntervalSinceReferenceDate)
        }
        .onChange(of: phase.stage, initial: true) { _, newStage in
            stageDial.set(Double(newStage), at: Date().timeIntervalSinceReferenceDate)
        }
        .onChange(of: phase.beat) { _, _ in
            beatAt = Date().timeIntervalSinceReferenceDate
        }
    }
}

private struct LuauScene: View {
    let t: Double
    let size: CGSize
    let depth: Double
    let stage: Double    // eased 0...3 position on the bonfire's depth-state ladder
    let tier: Int        // persistent mark: lantern strand size (0 = legacy six)
    let swell: Double    // 0...1 within-run headroom above INFERNO (see ProgressPhase)
    let beat: Int        // cumulative cascade-≥3 counter
    let beatAt: Double   // wall-clock moment of the latest cascade beat

    /// 0 = cool indigo night, 1 = bonfire flare peak. Slow 90 s breath; run
    /// depth lifts the floor (full swing at depth 0 — the shipped scene exactly).
    var flare: Double {
        let breath = (1 - cos(t * 2 * .pi / 90)) / 2
        return depth * 0.7 + breath * (1 - depth * 0.7)
    }

    /// 0→1 across the arrival of stage s: FLAME 1, BLAZE 2, INFERNO 3.
    /// All zero at stage 0 — the shipped scene exactly.
    func ramp(_ s: Int) -> Double { min(1, max(0, stage - Double(s - 1))) }

    /// The bonfire only grows within a run: FLAME feeds it, INFERNO makes it
    /// dominate. The 90 s breath keeps supplying the flicker underneath.
    var fireScale: Double { 1 + 0.30 * ramp(1) + 0.12 * ramp(2) + 0.42 * ramp(3) }

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var horizonY: CGFloat { h * 0.62 }
    var sandTopY: CGFloat { h * 0.80 }
    var fireX: CGFloat { w * 0.30 }
    var fireBaseY: CGFloat { h * 0.885 }

    var body: some View {
        ZStack {
            sky
            stars
            ocean
            palms
            sand
            turtle
            poles
            strand
            lanterns
            dancers(front: false)
            fireGlow
            logs
            flames
            embers
            dancers(front: true)
            mug
            cat
        }
    }

    // MARK: sky

    private func band(_ y0: CGFloat, _ y1: CGFloat, _ fill: Color) -> some View {
        Rectangle()
            .fill(fill)
            .frame(width: w, height: y1 - y0)
            .position(x: w / 2, y: (y0 + y1) / 2)
    }

    private var sky: some View {
        // INFERNO tints the whole sky ember; b3/b4 keep their flare term so
        // the 90 s breath stays alive under the tint. Zero at stage < 3.
        let inf: Double = ramp(3)
        let b1: Color = P.ink.lerp(P.twilight, 0.20).lerp(P.ember, 0.38 * inf).color
        let b2: Color = P.ink.lerp(P.twilight, 0.45).lerp(P.ember, 0.34 * inf).color
        let b3: Color = P.ink.lerp(P.twilight, 0.40).lerp(P.rum, 0.30 * inf).mix(P.rum, 0.08 + 0.14 * flare)
        let b4: Color = P.twilight.lerp(P.ink, 0.38).lerp(P.rum, 0.34 * inf).mix(P.rum, 0.24 + 0.30 * flare)
        return ZStack {
            band(0, h * 0.17, b1)
            band(h * 0.17, h * 0.33, b2)
            band(h * 0.33, h * 0.48, b3)
            band(h * 0.48, horizonY, b4)
        }
    }

    /// Always-on star field down to the horizon. The whole field drifts west
    /// on a glacial ~240 s wrap; stars over the future board zone are dimmed.
    private var stars: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let drift: Double = t / 240
            // INFERNO: the ember-lit smoke haze washes a third of the stars out.
            let haze: Double = 1 - 0.30 * ramp(3)
            for i in 0..<26 {
                let fi: Double = Double(i)
                let hx: Double = (sin(fi * 127.1 + 1.3) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                let hy: Double = (sin(fi * 311.7 + 4.7) * 26951.2917).truncatingRemainder(dividingBy: 1).magnitude
                let px: Double = (hx + drift).truncatingRemainder(dividingBy: 1)
                let py: Double = hy * 0.97
                let inBoard: Bool = px > 0.15 && px < 0.85 && py > 0.72
                let calm: Double = inBoard ? 0.30 : 1.0
                let twinkle: Double = 0.55 + 0.45 * sin(t * (1.1 + hx * 1.6) + fi * 2.3)
                let alpha: Double = (0.35 + 0.55 * twinkle) * calm * haze
                let r: Double = i % 6 == 0 ? 2.8 : 1.8
                let x: Double = px * width
                let y: Double = py * height
                let rect = CGRect(x: x, y: y, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(P.blossom.color.opacity(alpha)))
            }
        }
        .frame(width: w, height: horizonY)
        .position(x: w / 2, y: horizonY / 2)
    }

    // MARK: water

    private var ocean: some View {
        ZStack {
            band(horizonY, sandTopY, P.deepLeaf.mix(P.ink, 0.48))
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let oceanH: Double = Double(sz.height)
                for row in 0..<4 {
                    let fr: Double = Double(row)
                    let y: Double = oceanH * (0.24 + 0.21 * fr)
                    let amp: Double = 1.4 + 0.6 * fr
                    let speed: Double = 0.42 + 0.13 * fr
                    let alpha: Double = row < 3 ? 0.08 : 0.16
                    var path = Path()
                    var first = true
                    var x: Double = 0
                    while x <= width {
                        let angle: Double = x / 95 * 2 * .pi + t * speed + fr * 1.9
                        let yy: Double = y + amp * sin(angle)
                        let point = CGPoint(x: x, y: yy)
                        if first { path.move(to: point); first = false }
                        else { path.addLine(to: point) }
                        x += 6
                    }
                    ctx.stroke(path, with: .color(P.cream.color.opacity(alpha)), lineWidth: 1.4)
                }
                // Bonfire reflection: warm shimmering dashes at the waterline,
                // kept below the board zone. INFERNO widens and brightens the
                // lane — the dominating fire owns the water too.
                let fx: Double = width * 0.30
                let inf: Double = ramp(3)
                for row in 0..<4 {
                    let fr: Double = Double(row)
                    let gy: Double = oceanH * (0.80 + 0.055 * fr)
                    let shimmer: Double = 0.5 + 0.5 * sin(t * 1.8 + fr * 1.5)
                    let wobble: Double = 5 * sin(t * 0.6 + fr * 2.0)
                    let gw: Double = (34 - fr * 4 + wobble) * (1 + 0.5 * inf)
                    let sway: Double = 6 * sin(t * 0.35 + fr * 2.4)
                    let gx: Double = fx - gw / 2 + sway
                    let alpha: Double = (0.22 + 0.20 * flare + 0.18 * inf) * shimmer
                    let rect = CGRect(x: gx, y: gy, width: gw, height: 2.6)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.3), with: .color(P.torch.color.opacity(alpha)))
                }
            }
            .frame(width: w, height: sandTopY - horizonY)
            .position(x: w / 2, y: (horizonY + sandTopY) / 2)
        }
    }

    // MARK: midground

    private var palms: some View {
        ZStack {
            PalmView(t: t, dusk: 0.95, phase: 0.6)
                .frame(width: w * 0.50, height: h * 0.55)
                .position(x: w * 0.08, y: h * 0.575)
            PalmView(t: t, dusk: 0.95, phase: 2.9)
                .frame(width: w * 0.46, height: h * 0.50)
                .scaleEffect(x: -1, y: 1)
                .position(x: w * 0.92, y: h * 0.615)
        }
    }

    private var sand: some View {
        let sandRGB: RGB = P.driftwood.lerp(P.cream, 0.32)
        let warmed: Color = sandRGB.mix(P.clay, 0.06 + 0.16 * flare)
        return ZStack {
            band(sandTopY, h, warmed)
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let height: Double = Double(sz.height)
                let seeds: [(Double, Double, Double)] = [
                    (0.09, 0.30, 3.4), (0.56, 0.22, 2.6), (0.66, 0.58, 3.8),
                    (0.13, 0.78, 2.8), (0.47, 0.86, 3.2), (0.90, 0.40, 2.6),
                    (0.77, 0.83, 3.6), (0.35, 0.65, 2.4),
                ]
                for (i, s) in seeds.enumerated() {
                    let x: Double = s.0 * width
                    let y: Double = s.1 * height
                    let r: Double = s.2
                    let shade: Color = i % 3 == 0
                        ? P.blossom.color.opacity(0.55)
                        : P.shadowBrown.color.opacity(0.45)
                    let rect = CGRect(x: x, y: y, width: r * 1.5, height: r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(shade))
                }
                // Footprints wandering from the party toward the dark water.
                for i in 0..<6 {
                    let fi: Double = Double(i)
                    let side: Double = i % 2 == 0 ? -1.0 : 1.0
                    let x: Double = width * (0.545 + fi * 0.062)
                    let y: Double = height * (0.42 - fi * 0.052) + side * 5.0
                    let rect = CGRect(x: x, y: y, width: 4.4, height: 7.5)
                    ctx.fill(Path(ellipseIn: rect), with: .color(P.shadowBrown.color.opacity(0.5)))
                }
            }
            .frame(width: w, height: h - sandTopY)
            .position(x: w / 2, y: (sandTopY + h) / 2)
        }
    }

    // MARK: string lights

    private var poles: some View {
        ZStack {
            bambooPole(x: w * 0.035)
            bambooPole(x: w * 0.965)
        }
    }

    private func bambooPole(x: CGFloat) -> some View {
        let topY: CGFloat = h * 0.095
        let bottomY: CGFloat = h * 0.96
        let poleH: CGFloat = bottomY - topY
        return ZStack {
            Rectangle()
                .fill(P.driftwood.mix(P.woodDark, 0.35))
                .frame(width: w * 0.014, height: poleH)
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(P.woodDark.color)
                    .frame(width: w * 0.014, height: 3)
                    .offset(y: poleH * (CGFloat(i) * 0.22 - 0.33))
            }
        }
        .position(x: x, y: (topY + bottomY) / 2)
    }

    private var strand: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            var path = Path()
            path.move(to: CGPoint(x: width * 0.035, y: height * 0.42))
            path.addQuadCurve(
                to: CGPoint(x: width * 0.965, y: height * 0.42),
                control: CGPoint(x: width * 0.5, y: height * 1.14)
            )
            ctx.stroke(path, with: .color(P.cream.color.opacity(0.30)), lineWidth: 1.5)
        }
        .frame(width: w, height: h * 0.25)
        .position(x: w / 2, y: h * 0.125)
    }

    /// Point on the strand's quadratic curve at parameter u.
    private func strandPoint(_ u: CGFloat) -> CGPoint {
        let mu: CGFloat = 1 - u
        let x: CGFloat = mu * mu * (w * 0.035) + 2 * u * mu * (w * 0.5) + u * u * (w * 0.965)
        let y: CGFloat = mu * mu * (h * 0.105) + 2 * u * mu * (h * 0.285) + u * u * (h * 0.105)
        return CGPoint(x: x, y: y)
    }

    private var lanterns: some View {
        // Persistent mark: the strand hangs your best run's lanterns —
        // 3 + bestScore/150, capped at 9 (the tier field carries the count).
        // tier 0 = legacy caller (bare previews): today's six exactly.
        // FLAME brightens every paper shade.
        let count: Int = tier == 0 ? 6 : min(9, max(1, tier))
        let tints: [RGB] = [P.coral, P.torch, P.cream]
        let brighten: Double = ramp(1)
        return ZStack {
            ForEach(0..<count, id: \.self) { i in
                let u: CGFloat = count == 1 ? 0.5 : 0.15 + 0.70 * CGFloat(i) / CGFloat(count - 1)
                let hang: CGPoint = strandPoint(u)
                let fi: Double = Double(i)
                let swing: Double = 6.5 * sin(t * 0.68 + fi * 1.15) + 2.0 * sin(t * 1.31 + fi * 2.4)
                let lw: CGFloat = w * 0.052
                let lh: CGFloat = w * 0.085
                LanternView(tint: tints[i % 3], flare: flare, boost: brighten)
                    .frame(width: lw, height: lh)
                    .rotationEffect(.degrees(swing), anchor: .top)
                    .position(x: hang.x, y: hang.y + lh / 2)
            }
        }
    }

    // MARK: bonfire

    private var fireGlow: some View {
        let pulse: Double = 1 + 0.05 * sin(t * 8.7) + 0.03 * sin(t * 21.3) + 0.02 * sin(t * 57)
        let breadth: Double = 0.85 + 0.30 * flare
        let gw: CGFloat = w * 0.34 * CGFloat(pulse * breadth) * CGFloat(0.66 + 0.34 * fireScale)
        let inf: Double = ramp(3)
        let tint: Color = P.torch.mix(P.coral, 0.35)
        return ZStack {
            Ellipse()
                .fill(tint.opacity(0.10 + 0.04 * inf))
                .frame(width: gw * 1.5, height: gw * 0.52)
            Ellipse()
                .fill(tint.opacity(0.16 + 0.06 * inf))
                .frame(width: gw, height: gw * 0.36)
        }
        .position(x: fireX, y: fireBaseY + h * 0.006)
    }

    private var logs: some View {
        ZStack {
            log(w * 0.155, 3, 0, h * 0.008, P.woodDark.color)
            log(w * 0.135, 24, -w * 0.028, 0, P.plank.mix(P.woodDark, 0.40))
            log(w * 0.135, -22, w * 0.028, 0, P.shadowBrown.mix(P.woodDark, 0.35))
        }
    }

    private func log(_ lw: CGFloat, _ angle: Double, _ dx: CGFloat, _ dy: CGFloat, _ fill: Color) -> some View {
        RoundedRectangle(cornerRadius: lw * 0.07)
            .fill(fill)
            .frame(width: lw, height: lw * 0.15)
            .rotationEffect(.degrees(angle))
            .position(x: fireX + dx, y: fireBaseY + dy)
    }

    private var flames: some View {
        let flick: Double = 1 + 0.13 * sin(t * 8.5) + 0.07 * sin(t * 21) + 0.04 * sin(t * 57)
        let flick2: Double = 1 + 0.11 * sin(t * 9.4 + 1.9) + 0.08 * sin(t * 24 + 0.7) + 0.04 * sin(t * 61 + 2.4)
        let lean: Double = 4.5 * sin(t * 6.3) + 2.2 * sin(t * 15.2)
        let lean2: Double = 3.5 * sin(t * 7.1 + 2.2) + 1.8 * sin(t * 17.5 + 1.1)
        let baseY: CGFloat = fireBaseY - h * 0.006
        // Every flame frame's bottom sits at baseY, so folding fireScale into
        // the bottom-anchored scale grows the whole fire in place.
        let fs: CGFloat = CGFloat(fireScale)
        return ZStack {
            FlameShape()
                .fill(P.coral.color)
                .frame(width: w * 0.115, height: h * 0.10)
                .scaleEffect(x: fs, y: CGFloat(flick) * fs, anchor: .bottom)
                .rotationEffect(.degrees(lean), anchor: .bottom)
                .position(x: fireX, y: baseY - h * 0.05)
            FlameShape()
                .fill(P.torch.color)
                .frame(width: w * 0.066, height: h * 0.062)
                .scaleEffect(x: fs, y: CGFloat(flick2) * fs, anchor: .bottom)
                .rotationEffect(.degrees(lean2), anchor: .bottom)
                .position(x: fireX, y: baseY - h * 0.031)
            FlameShape()
                .fill(P.cream.mix(P.blossom, 0.5))
                .frame(width: w * 0.030, height: h * 0.030)
                .scaleEffect(x: fs, y: CGFloat(flick) * fs, anchor: .bottom)
                .rotationEffect(.degrees(lean2), anchor: .bottom)
                .position(x: fireX, y: baseY - h * 0.015)
        }
    }

    /// Embers rise, drift, and fade on deterministic looping phases; each is
    /// fully faded before it could reach the board zone. The base nine are the
    /// shipped layer exactly (the frame grew for headroom; their pixels did
    /// not move). FLAME adds four higher risers, INFERNO stacks a fast tight
    /// sparks column, and each cascade beat pops a one-shot ember burst.
    private var embers: some View {
        let hp: Double = Double(h)
        let flame: Double = ramp(1)
        let inferno: Double = ramp(3)
        return Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            for i in 0..<20 {
                let fi: Double = Double(i)
                let gate: Double = i < 9 ? 1 : (i < 13 ? flame : inferno)
                guard gate > 0 else { continue }
                let column: Bool = i >= 13
                let period: Double = column
                    ? 1.7 + 0.4 * fi.truncatingRemainder(dividingBy: 3)
                    : 2.6 + 0.5 * fi.truncatingRemainder(dividingBy: 3)
                let raw: Double = t / period + fi * 0.37
                let u: Double = raw.truncatingRemainder(dividingBy: 1)
                let swayAmp: Double = column ? 4 : 8 + 3 * fi.truncatingRemainder(dividingBy: 2)
                let sway: Double = swayAmp * sin(t * 1.7 + fi * 2.1)
                let dx: Double = i < 9 ? (fi - 4) * 3.5 : (column ? (fi - 16) * 2.5 : (fi - 11) * 7.0)
                let x: Double = width * 0.5 + dx + sway * u
                let rise: Double = i < 9 ? hp * 0.145 : (column ? hp * 0.165 : hp * 0.19)
                let y: Double = height - rise * u * 0.94
                let fade: Double = (1 - u) * (1 - u)
                let glow: Double = 0.6 + 0.4 * sin(t * 11 + fi * 3.3)
                let alpha: Double = fade * glow * 0.9 * gate
                let r: Double = (column ? 3.6 : 3.2) - 2.0 * u
                let tint: Color = i % 2 == 0 ? P.torch.color : P.coral.color
                let rect = CGRect(x: x, y: y, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(tint.opacity(alpha)))
            }
            // Cascade beat: a cascade ≥ 3 visibly feeds the fire — fourteen
            // sparks fountain from the crown and gutter out inside 1.4 s.
            let age: Double = t - beatAt
            if beatAt > 0, age >= 0, age < 1.4 {
                func hash(_ n: Double) -> Double {
                    (sin(n) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                }
                let u: Double = age / 1.4
                let pop: Double = 1 - (1 - u) * (1 - u)
                for j in 0..<14 {
                    let fj: Double = Double(j)
                    let h1: Double = hash(fj * 12.9898 + Double(beat) * 78.233)
                    let h2: Double = hash(fj * 39.3467 + Double(beat) * 11.135)
                    let ang: Double = -.pi / 2 + (h1 - 0.5) * 2.2
                    let dist: Double = hp * (0.02 + 0.085 * h2) * pop
                    let x: Double = width * 0.5 + cos(ang) * dist
                    let y: Double = height - hp * 0.075 + sin(ang) * dist + hp * 0.03 * u * u
                    let alpha: Double = (1 - u) * (1 - u) * (0.60 + 0.35 * h2)
                    let r: Double = 3.6 - 2.4 * u
                    let tint: Color = j % 3 == 0
                        ? P.cream.mix(P.blossom, 0.5)
                        : (j % 3 == 1 ? P.torch.color : P.coral.color)
                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(tint.opacity(alpha)))
                }
            }
        }
        .frame(width: w * 0.44, height: h * 0.30)
        .position(x: fireX, y: h * 0.7275)
        .allowsHitTesting(false)
    }

    // MARK: turtle

    /// Honu, hauled up to the waterline. The same sprite the lounge sells as a
    /// lagoon item — no mechanical connection to the lounge, it is just the
    /// turtle this game already owns — the last of the night's arrivals, once
    /// the run has pushed past the top of the fire's own ladder.
    ///
    /// Sits high on the wet sand at the ocean edge (`sandTopY` is the waterline)
    /// and clear of the cat at 0.435w/0.905h. The sprite is drawn for daylight,
    /// so it is multiplied down into the beach's night value range and then lets
    /// `flare` lift it, the same way everything else on this sand breathes.
    @ViewBuilder
    private var turtle: some View {
        // Last to arrive, and only on a genuinely good night: `swell` starts
        // above INFERNO, so Honu is the reward for a run that keeps going after
        // the fire has already maxed out.
        let earned: Double = swell
        if earned > 0 {
            // Swims the shallows left to right over 78 s, entering and leaving
            // fully off-screen so the wrap is never seen — which also means she
            // always faces her direction of travel and never needs to flip.
            // Sitting still she was a sticker; the old 0.0035 bob was ~3 points
            // of travel, invisible.
            let cycle: Double = (t / 78).truncatingRemainder(dividingBy: 1)
            let swimX: Double = -0.14 + 1.28 * cycle
            let bob: Double = sin(t * 0.9) * 0.004
            let pitch: Double = sin(t * 0.9 + 1.1) * 3.5
            Image.seaTurtle
                .resizable()
                .scaledToFit()
                // Sized to read: at 0.115w it was a green pebble. It wants to be
                // at least the cat's 0.13w, and it is a wide silhouette, so 0.19.
                .frame(width: w * 0.19)
                // Multiplied only lightly — at 0.50 the shell went khaki and
                // vanished into brown sand. Keeping more of its own green is
                // what separates it from the beach.
                .colorMultiply(P.driftwood.lerp(P.cream, 0.72 + 0.10 * flare).color)
                .opacity(0.94 * earned)
                // Swims in the shallows, just ABOVE the sand line. Two spots on
                // the sand failed first: 0.47w sat under the INFERNO flame, and
                // 0.20w landed inside the dancers' orbit — they ring the fire
                // from ~0.14w to ~0.42w and they circle, so any fixed spot in
                // there is overlapped sooner or later. The water also gives the
                // shell contrast the brown sand never did.
                .rotationEffect(.degrees(pitch))
                .position(x: w * swimX, y: h * (0.773 + bob))
                .allowsHitTesting(false)
        }
    }

    // MARK: dancers

    /// BLAZE: hula dancer silhouettes circle the bonfire on a slow ellipse.
    /// The far arc renders behind the fire, the near arc in front, so the
    /// orbit reads as depth. Visual only — flat ink figures against firelight.
    @ViewBuilder
    private func dancers(front: Bool) -> some View {
        let blaze: Double = ramp(2)
        if blaze > 0 {
            let hp: Double = Double(h)
            let wp: Double = Double(w)
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                for i in 0..<3 {
                    let fi: Double = Double(i)
                    let theta: Double = t * 0.26 + fi * (2 * .pi / 3)
                    let s: Double = sin(theta)
                    guard (s >= 0) == front else { continue }
                    let k: Double = 0.82 + 0.14 * (s + 1)
                    let bodyH: Double = hp * 0.056 * k
                    let bob: Double = 1.6 * sin(t * 2.3 + fi * 2.6)
                    let x: Double = width / 2 + cos(theta) * wp * 0.16
                    let footY: Double = hp * 0.106 + s * hp * 0.020 + bob
                    let swing: Double = sin(t * 1.9 + fi * 2.1)
                    let ink: Color = P.ink.color.opacity((front ? 0.92 : 0.72) * blaze)

                    var skirt = Path()
                    skirt.move(to: CGPoint(x: x - bodyH * 0.075, y: footY - bodyH * 0.46))
                    skirt.addLine(to: CGPoint(x: x + bodyH * 0.075, y: footY - bodyH * 0.46))
                    skirt.addLine(to: CGPoint(x: x + bodyH * 0.21 + bodyH * 0.03 * swing, y: footY))
                    skirt.addLine(to: CGPoint(x: x - bodyH * 0.21 + bodyH * 0.03 * swing, y: footY))
                    skirt.closeSubpath()
                    ctx.fill(skirt, with: .color(ink))
                    var torso = Path()
                    torso.move(to: CGPoint(x: x - bodyH * 0.105, y: footY - bodyH * 0.72))
                    torso.addLine(to: CGPoint(x: x + bodyH * 0.105, y: footY - bodyH * 0.72))
                    torso.addLine(to: CGPoint(x: x + bodyH * 0.07, y: footY - bodyH * 0.44))
                    torso.addLine(to: CGPoint(x: x - bodyH * 0.07, y: footY - bodyH * 0.44))
                    torso.closeSubpath()
                    ctx.fill(torso, with: .color(ink))
                    let hr: Double = bodyH * 0.11
                    let hx: Double = x + bodyH * 0.05 * swing
                    let head = CGRect(x: hx - hr, y: footY - bodyH * 0.98, width: hr * 2, height: hr * 2)
                    ctx.fill(Path(ellipseIn: head), with: .color(ink))
                    for side in [-1.0, 1.0] {
                        let lift: Double = side * swing > 0 ? 0.34 : 0.16
                        var arm = Path()
                        arm.move(to: CGPoint(x: x + side * bodyH * 0.09, y: footY - bodyH * 0.68))
                        arm.addQuadCurve(
                            to: CGPoint(
                                x: x + side * bodyH * (0.28 + 0.05 * swing),
                                y: footY - bodyH * (0.78 + lift + 0.05 * swing * side)
                            ),
                            control: CGPoint(x: x + side * bodyH * 0.30, y: footY - bodyH * 0.66)
                        )
                        ctx.stroke(arm, with: .color(ink), style: StrokeStyle(lineWidth: bodyH * 0.055, lineCap: .round))
                    }
                }
            }
            .frame(width: w * 0.46, height: h * 0.14)
            .position(x: fireX, y: fireBaseY - h * 0.036)
            .allowsHitTesting(false)
        }
    }

    // MARK: props


    /// Someone left their drink in the sand. The cat is not telling whose.
    private var mug: some View {
        MugView()
            .frame(width: w * 0.048, height: h * 0.038)
            .position(x: w * 0.525, y: h * 0.922)
    }

    private var cat: some View {
        CatView(t: t)
            .frame(width: w * 0.13, height: h * 0.088)
            .scaleEffect(x: -1, y: 1)
            .position(x: w * 0.435, y: h * 0.905)
    }
}

/// Paper lantern with a flat glow disc, hung from its frame top so it can
/// swing around the strand point. Drawn proportionally in its frame.
private struct LanternView: View {
    let tint: RGB
    let flare: Double
    /// FLAME's lantern brightening — 0 = the shipped lantern exactly.
    var boost: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let glow: Color = tint.lerp(P.blossom, 0.45).color
            ZStack {
                Circle()
                    .fill(glow.opacity(0.10 + 0.05 * flare + 0.10 * boost))
                    .frame(width: w * (2.6 + 0.55 * boost), height: w * (2.6 + 0.55 * boost))
                    .position(x: w / 2, y: h * 0.62)
                Rectangle()
                    .fill(P.cream.color.opacity(0.5))
                    .frame(width: 1.5, height: h * 0.36)
                    .position(x: w / 2, y: h * 0.18)
                RoundedRectangle(cornerRadius: w * 0.28)
                    .fill(tint.lerp(P.blossom, 0.18 * boost).color)
                    .frame(width: w * 0.78, height: h * 0.55)
                    .position(x: w / 2, y: h * 0.62)
                Rectangle()
                    .fill(P.ink.color.opacity(0.15))
                    .frame(width: w * 0.78, height: 1.5)
                    .position(x: w / 2, y: h * 0.53)
                Rectangle()
                    .fill(P.ink.color.opacity(0.15))
                    .frame(width: w * 0.78, height: 1.5)
                    .position(x: w / 2, y: h * 0.71)
                Rectangle()
                    .fill(P.woodDark.color)
                    .frame(width: w * 0.34, height: h * 0.06)
                    .position(x: w / 2, y: h * 0.325)
                Rectangle()
                    .fill(P.woodDark.color)
                    .frame(width: w * 0.34, height: h * 0.06)
                    .position(x: w / 2, y: h * 0.915)
            }
        }
    }
}


#Preview {
    LuauBackgroundView()
}
