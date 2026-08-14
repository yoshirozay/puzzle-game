import SwiftUI

/// Animated tiki bar interior (Zombie — the 2048 merge game). The only indoor
/// scene: a flat coral wall breathes toward rum on a 90-second cycle while the
/// blowfish lamp and candle glow strengthen to match. On the counter sits THE
/// ZOMBIE, quietly smoking; a tipped bottle on the shelf says who poured it,
/// and the cat has opinions. All motion derives from one TimelineView clock.
/// Shared components live in TikiScenery.swift.
struct ZombieBackgroundView: View {
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
                ZombieScene(
                    t: t, size: geo.size,
                    depth: reduceMotion ? phase.depth : dial.eased(at: t),
                    stage: reduceMotion ? Double(phase.stage) : stageDial.eased(at: t),
                    tier: phase.tier,
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

private struct ZombieScene: View {
    let t: Double
    let size: CGSize
    let depth: Double
    let stage: Double    // eased 0...4 position on the bar's depth-state ladder
    let tier: Int        // persistent mark: shelf bottles (0 = legacy full lineup)
    let beatAt: Double   // wall-clock moment of the latest merge beat

    /// Wall warmth: 0 = coral / soft light, 1 = rum / deep light. 90 s breath;
    /// run depth lifts the floor (full swing at depth 0 — the shipped scene exactly).
    var breath: Double {
        let wave = (1 - cos(t * 2 * .pi / 90)) / 2
        return depth * 0.7 + wave * (1 - depth * 0.7)
    }
    /// Lamp and candle light strengthen as the wall deepens.
    var glow: Double { 0.35 + 0.65 * breath }

    /// 0→1 across the arrival of stage s: DUSK BLINDS 1, NIGHT NEON 2,
    /// VOLCANO WATCH 3, THE ZOMBIE 4. All zero at stage 0 — the shipped scene.
    func ramp(_ s: Int) -> Double { min(1, max(0, stage - Double(s - 1))) }

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var shelfZoneH: CGFloat { h * 0.18 }
    var counterY: CGFloat { h * 0.78 }
    var slabH: CGFloat { h * 0.022 }

    var body: some View {
        ZStack {
            wall
            duskBlinds
            glowPool
            dustMotes
            hibiscusPrint
            starburstClock
            eruption
            shelf
            lamp
            counter
            zombieMug
            smoke
            emberFlecks
            candle
            cat
        }
    }

    private func band(_ y0: CGFloat, _ y1: CGFloat, _ fill: Color) -> some View {
        Rectangle()
            .fill(fill)
            .frame(width: w, height: y1 - y0)
            .position(x: w / 2, y: (y0 + y1) / 2)
    }

    // MARK: wall

    /// One flat plane fills the screen — this IS the calm board zone.
    /// NIGHT NEON locks it toward rum, VOLCANO WATCH adds a slow 7 s pulse,
    /// THE ZOMBIE settles it toward ember. The lock target keeps breathing so
    /// the 90 s cycle survives every state; stage 0 is the shipped blend.
    private var wall: some View {
        let pulse: Double = ramp(3) * 0.14 * (0.5 + 0.5 * sin(t * 2 * .pi / 7))
        let lock: Double = min(0.72, 0.42 * ramp(2) + 0.16 * ramp(4) + pulse)
        let night: RGB = P.rum.lerp(P.ember, 0.20 + 0.45 * breath)
        return band(0, h, P.coral.lerp(P.rum, breath).lerp(night, lock).color)
    }

    /// DUSK BLINDS: low sun rakes slatted light across the wall. The bands
    /// creep on the 90 s breath; NIGHT NEON swallows them.
    @ViewBuilder
    private var duskBlinds: some View {
        let rake: Double = ramp(1) * (1 - ramp(2))
        if rake > 0 {
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let height: Double = Double(sz.height)
                let pitch: Double = height / 8
                let slat: Double = pitch * 0.42
                let lean: Double = width * 0.14
                let drift: Double = pitch * 0.30 * sin(t * 2 * .pi / 90)
                let tint: Color = P.torch.mix(P.cream, 0.45)
                for i in 0..<9 {
                    let y0: Double = pitch * Double(i) - lean + drift
                    var bandPath = Path()
                    bandPath.move(to: CGPoint(x: 0, y: y0 + lean))
                    bandPath.addLine(to: CGPoint(x: width, y: y0))
                    bandPath.addLine(to: CGPoint(x: width, y: y0 + slat))
                    bandPath.addLine(to: CGPoint(x: 0, y: y0 + slat + lean))
                    bandPath.closeSubpath()
                    ctx.fill(bandPath, with: .color(tint.opacity((0.13 + 0.06 * breath) * rake)))
                }
            }
            .frame(width: w, height: h * 0.62)
            .position(x: w / 2, y: h * 0.16 + h * 0.31)
            .allowsHitTesting(false)
        }
    }

    /// NIGHT NEON: the blowfish lamp's pool of light widens across the wall.
    /// VOLCANO WATCH tints the pool volcanic.
    @ViewBuilder
    private var glowPool: some View {
        let neon: Double = ramp(2)
        if neon > 0 {
            let pulse: Double = 0.5 + 0.5 * sin(t * 1.3)
            let base: CGFloat = w * CGFloat(0.24 + 0.18 * neon)
            let tint: RGB = P.torch.lerp(P.cream, 0.55).lerp(P.coral, 0.65 * ramp(3))
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    let fi = CGFloat(i)
                    Ellipse()
                        .fill(
                            tint.color
                                .opacity((0.11 - 0.03 * Double(i)) * neon * (0.75 + 0.25 * pulse) * glow * (1 + 0.5 * ramp(3)))
                        )
                        .frame(width: base * (1 + fi * 0.5), height: base * (0.80 + fi * 0.42))
                }
            }
            .position(x: w * 0.62, y: h * 0.264)
            .allowsHitTesting(false)
        }
    }

    /// THE ZOMBIE: eruption glow — the win moment made environmental. The
    /// back bar becomes a furnace: stepped gold light climbs from the shelf
    /// line while play continues. Merge beats surge it.
    @ViewBuilder
    private var eruption: some View {
        let erupt: Double = ramp(4)
        if erupt > 0 {
            let age: Double = t - beatAt
            let surge: Double = (beatAt > 0 && age >= 0 && age < 1.2) ? (1 - age / 1.2) * 0.5 : 0
            let throb: Double = 0.80 + 0.20 * sin(t * 2 * .pi / 5)
            let gold: Color = P.torch.mix(P.cream, 0.30)
            ZStack {
                // Room-wide heat wash — the whole bar lit by eruption light.
                band(0, h, gold.opacity(0.06 * erupt * throb))
                // Furnace bands rising off the back bar.
                ForEach(0..<4, id: \.self) { i in
                    let fi = CGFloat(i)
                    Ellipse()
                        .fill(gold.opacity((0.17 - 0.035 * Double(i)) * erupt * throb * (1 + surge)))
                        .frame(
                            width: w * (0.55 + 0.35 * fi) * (1 + 0.08 * CGFloat(surge)),
                            height: h * (0.10 + 0.055 * fi)
                        )
                        .position(x: w * 0.5, y: h * 0.155)
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// Barely-there dust drifting through the lamplight — the glacial layer.
    /// NIGHT NEON stretches the motes into slow smoke wisps.
    private var dustMotes: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let wisp: Double = ramp(2)
            let seeds: [(Double, Double)] = [
                (0.08, 0.30), (0.22, 0.62), (0.37, 0.18), (0.52, 0.50),
                (0.66, 0.28), (0.80, 0.66), (0.93, 0.40),
            ]
            for (i, seed) in seeds.enumerated() {
                let fi: Double = Double(i)
                let x: Double = seed.0 * width + width * 0.035 * sin(t * 2 * .pi / 190 + fi * 2.4)
                let y: Double = seed.1 * height + height * 0.16 * sin(t * 2 * .pi / 150 + fi * 1.8)
                let alpha: Double = (0.05 + 0.05 * sin(t * 2 * .pi / 165 + fi * 3.1))
                    * (0.5 + 0.5 * breath) * (1 + 1.2 * wisp)
                let r: Double = i % 3 == 0 ? 2.6 : 1.8
                let rw: Double = r * (1 - 0.25 * wisp)
                let rh: Double = r * (1 + 4.5 * wisp)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y - (rh - r) / 2, width: rw, height: rh)),
                    with: .color(P.cream.color.opacity(alpha))
                )
            }
        }
        .frame(width: w, height: h * 0.24)
        .position(x: w / 2, y: h * 0.31)
        .allowsHitTesting(false)
    }

    /// Framed hibiscus print on the left wall — the bar's one attempt at decor.
    private var hibiscusPrint: some View {
        let fw: CGFloat = w * 0.14
        let fh: CGFloat = h * 0.10
        return ZStack {
            RoundedRectangle(cornerRadius: fw * 0.06)
                .fill(P.woodDark.color)
                .frame(width: fw, height: fh)
            RoundedRectangle(cornerRadius: fw * 0.03)
                .fill(P.cream.color)
                .frame(width: fw * 0.82, height: fh * 0.80)
            ForEach(0..<5, id: \.self) { i in
                Ellipse()
                    .fill(P.clay.color)
                    .frame(width: fw * 0.20, height: fw * 0.34)
                    .offset(y: -fw * 0.17)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle()
                .fill(P.torch.color)
                .frame(width: fw * 0.14, height: fw * 0.14)
        }
        .position(x: w * 0.075, y: h * 0.40)
    }

    /// Mid-century starburst wall clock keeping honest time — its hands are
    /// driven by the real clock, so the minute hand is the glacial layer.
    private var starburstClock: some View {
        let cw: CGFloat = w * 0.115
        let minuteAngle: Double = (t / 60).truncatingRemainder(dividingBy: 60) * 6
        let hourAngle: Double = (t / 3600).truncatingRemainder(dividingBy: 12) * 30
        return ZStack {
            ForEach(0..<8, id: \.self) { i in
                Capsule()
                    .fill(P.torch.color)
                    .frame(width: cw * 0.045, height: cw * 0.42)
                    .offset(y: -cw * 0.29)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Circle()
                .fill(P.woodDark.color)
                .frame(width: cw * 0.34, height: cw * 0.34)
            Circle()
                .fill(P.cream.color)
                .frame(width: cw * 0.26, height: cw * 0.26)
            Rectangle()
                .fill(P.ink.color)
                .frame(width: cw * 0.018, height: cw * 0.09)
                .offset(y: -cw * 0.045)
                .rotationEffect(.degrees(hourAngle))
            Rectangle()
                .fill(P.ink.color)
                .frame(width: cw * 0.014, height: cw * 0.12)
                .offset(y: -cw * 0.06)
                .rotationEffect(.degrees(minuteAngle))
            Circle()
                .fill(P.ink.color)
                .frame(width: cw * 0.03, height: cw * 0.03)
        }
        .position(x: w * 0.86, y: h * 0.315)
    }

    // MARK: top shelf

    /// Back-bar shelf with the bottle collection. One bottle lies tipped by a
    /// gap in the lineup — the rum that went into the Zombie.
    private var shelf: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let boardY: Double = height * 0.70
            let boardH: Double = height * 0.17
            let wood: Color = P.plank.mix(P.woodDark, 0.35 + 0.35 * breath)
            ctx.fill(Path(CGRect(x: 0, y: boardY, width: width, height: boardH)), with: .color(wood))
            ctx.fill(
                Path(CGRect(x: 0, y: boardY, width: width, height: height * 0.03)),
                with: .color(P.ink.color.opacity(0.35))
            )
            ctx.fill(
                Path(CGRect(x: 0, y: boardY + boardH - height * 0.02, width: width, height: height * 0.02)),
                with: .color(P.ink.color.opacity(0.5))
            )
            for bx in [0.10, 0.50, 0.90] {
                let cx: Double = width * bx
                var bracket = Path()
                bracket.move(to: CGPoint(x: cx - width * 0.018, y: boardY + boardH))
                bracket.addLine(to: CGPoint(x: cx + width * 0.018, y: boardY + boardH))
                bracket.addLine(to: CGPoint(x: cx, y: boardY + boardH + height * 0.15))
                bracket.closeSubpath()
                ctx.fill(bracket, with: .color(P.woodDark.color))
            }
            // Bottles: (centerX, width, height fraction, tint index, tapered).
            let tints: [Color] = [P.lagoon.color, P.clay.color, P.torch.color, P.cream.color]
            let specs: [(Double, Double, Double, Int, Bool)] = [
                (0.055, 0.040, 0.88, 0, false),
                (0.115, 0.028, 0.60, 2, true),
                (0.175, 0.048, 0.95, 1, true),
                (0.235, 0.026, 0.52, 3, false),
                (0.310, 0.042, 0.78, 0, true),
                (0.395, 0.034, 0.90, 2, false),
                (0.470, 0.046, 0.58, 3, true),
                (0.540, 0.030, 0.82, 1, false),
                (0.755, 0.044, 0.92, 0, true),
                (0.820, 0.028, 0.56, 2, false),
                (0.880, 0.040, 0.74, 3, false),
                (0.945, 0.048, 0.86, 1, true),
            ]
            // Persistent mark: the back bar stocks 1 + (deepest drink ever
            // mixed) of its authored lineup — the full dozen at THE ZOMBIE.
            // tier 0 = legacy caller (bare previews): today's full shelf.
            let stocked: Int = tier == 0 ? specs.count : min(specs.count, tier)
            for s in specs.prefix(stocked) {
                let bw: Double = width * s.1
                let bh: Double = boardY * s.2 * 0.80
                let cx: Double = width * s.0
                let x0: Double = cx - bw / 2
                let y0: Double = boardY - bh
                let tint: Color = tints[s.3]
                if s.4 {
                    var bottle = Path()
                    bottle.move(to: CGPoint(x: x0, y: boardY))
                    bottle.addLine(to: CGPoint(x: x0 + bw, y: boardY))
                    bottle.addLine(to: CGPoint(x: x0 + bw * 0.80, y: y0 + bh * 0.30))
                    bottle.addLine(to: CGPoint(x: x0 + bw * 0.20, y: y0 + bh * 0.30))
                    bottle.closeSubpath()
                    ctx.fill(bottle, with: .color(tint))
                } else {
                    let bodyRect = CGRect(x: x0, y: y0 + bh * 0.28, width: bw, height: bh * 0.72)
                    ctx.fill(Path(bodyRect), with: .color(tint))
                }
                let neckW: Double = bw * 0.34
                let neckRect = CGRect(x: cx - neckW / 2, y: y0, width: neckW, height: bh * 0.32)
                ctx.fill(Path(neckRect), with: .color(tint))
            }
            // The tipped bottle beside the gap in the lineup.
            let tipY: Double = boardY - height * 0.055
            let tipRect = CGRect(x: width * 0.615, y: tipY, width: width * 0.058, height: height * 0.055)
            ctx.fill(Path(roundedRect: tipRect, cornerRadius: height * 0.018), with: .color(P.clay.color))
            let tipNeck = CGRect(x: width * 0.585, y: boardY - height * 0.038, width: width * 0.032, height: height * 0.022)
            ctx.fill(Path(tipNeck), with: .color(P.clay.color))
        }
        .frame(width: w, height: shelfZoneH)
        .position(x: w / 2, y: shelfZoneH / 2)
    }

    /// Blowfish lamp hanging under the shelf, swaying on its cord.
    private var lamp: some View {
        let sway: Double = 3 * sin(t * 2 * .pi / 9)
        let pulse: Double = 0.5 + 0.5 * sin(t * 1.3)
        let haloAlpha: Double = (0.10 + 0.14 * pulse) * glow
        let lampW: CGFloat = w * 0.26
        let lampH: CGFloat = h * 0.26
        return Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let cx: Double = width / 2
            let fishR: Double = width * 0.20
            let fishY: Double = height * 0.42
            let cordW: Double = width * 0.014
            let cordRect = CGRect(x: cx - cordW / 2, y: 0, width: cordW, height: fishY - fishR * 0.7)
            ctx.fill(Path(cordRect), with: .color(P.ink.color))
            let haloR: Double = fishR * 1.85
            let haloRect = CGRect(x: cx - haloR, y: fishY - haloR, width: haloR * 2, height: haloR * 2)
            ctx.fill(Path(ellipseIn: haloRect), with: .color(P.torch.mix(P.cream, 0.55).opacity(haloAlpha)))
            for i in 0..<9 {
                let ang: Double = Double(i) / 9 * 2 * .pi + 0.32
                let tipR: Double = fishR * 1.40
                let a1: Double = ang - 0.17
                let a2: Double = ang + 0.17
                var spike = Path()
                spike.move(to: CGPoint(x: cx + cos(a1) * fishR * 0.92, y: fishY + sin(a1) * fishR * 0.92))
                spike.addLine(to: CGPoint(x: cx + cos(a2) * fishR * 0.92, y: fishY + sin(a2) * fishR * 0.92))
                spike.addLine(to: CGPoint(x: cx + cos(ang) * tipR, y: fishY + sin(ang) * tipR))
                spike.closeSubpath()
                ctx.fill(spike, with: .color(P.torch.color))
            }
            let bodyRect = CGRect(x: cx - fishR, y: fishY - fishR, width: fishR * 2, height: fishR * 2)
            ctx.fill(Path(ellipseIn: bodyRect), with: .color(P.torch.mix(P.cream, 0.20 * glow)))
            let eyeR: Double = fishR * 0.26
            let ex: Double = cx - fishR * 0.36
            let ey: Double = fishY - fishR * 0.26
            let eyeRect = CGRect(x: ex - eyeR, y: ey - eyeR, width: eyeR * 2, height: eyeR * 2)
            ctx.fill(Path(ellipseIn: eyeRect), with: .color(P.cream.color))
            let pupilR: Double = eyeR * 0.45
            let px: Double = ex - eyeR * 0.30
            let pupilRect = CGRect(x: px - pupilR, y: ey - pupilR, width: pupilR * 2, height: pupilR * 2)
            ctx.fill(Path(ellipseIn: pupilRect), with: .color(P.ink.color))
            let lipW: Double = fishR * 0.34
            let lipH: Double = fishR * 0.16
            let lx: Double = cx - fishR * 0.96
            let ly: Double = fishY + fishR * 0.16
            let upperLip = CGRect(x: lx - lipW / 2, y: ly - lipH - 1, width: lipW, height: lipH)
            let lowerLip = CGRect(x: lx - lipW / 2, y: ly + 1, width: lipW, height: lipH)
            ctx.fill(Path(ellipseIn: upperLip), with: .color(P.clay.color))
            ctx.fill(Path(ellipseIn: lowerLip), with: .color(P.clay.color))
        }
        .frame(width: lampW, height: lampH)
        .rotationEffect(.degrees(sway), anchor: .top)
        .position(x: w * 0.62, y: h * 0.155 + lampH / 2)
    }

    // MARK: counter

    /// Bamboo bar counter: ink top slab, alternating warm slats, two lashings.
    private var counter: some View {
        ZStack {
            band(counterY, counterY + slabH, P.ink.color)
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let height: Double = Double(sz.height)
                let slatCount: Int = 13
                let slatW: Double = width / Double(slatCount)
                for i in 0..<slatCount {
                    let fi: Double = Double(i)
                    let base: RGB = i % 2 == 0 ? P.driftwood : P.plank
                    let tone: Color = base.mix(P.shadowBrown, 0.25 + 0.35 * breath)
                    ctx.fill(
                        Path(CGRect(x: slatW * fi, y: 0, width: slatW, height: height)),
                        with: .color(tone)
                    )
                }
                for i in 1..<slatCount {
                    let x: Double = slatW * Double(i)
                    var seam = Path()
                    seam.move(to: CGPoint(x: x, y: 0))
                    seam.addLine(to: CGPoint(x: x, y: height))
                    ctx.stroke(seam, with: .color(P.woodDark.color), lineWidth: 2)
                }
                let rope: Color = P.cream.mix(P.torch, 0.55)
                for yf in [0.26, 0.68] {
                    let y: Double = height * yf
                    for off in [-2.2, 2.2] {
                        var lash = Path()
                        lash.move(to: CGPoint(x: 0, y: y + off))
                        lash.addLine(to: CGPoint(x: width, y: y + off))
                        ctx.stroke(lash, with: .color(rope.opacity(0.65)), lineWidth: 1.8)
                    }
                }
            }
            .frame(width: w, height: h - counterY - slabH)
            .position(x: w / 2, y: (counterY + slabH + h) / 2)
        }
    }

    // MARK: the Zombie still life

    private var zombieMug: some View {
        // THE ZOMBIE: the mug's eyes blaze under eruption light.
        ZombieMugView(t: t, glow: min(1, glow + 0.6 * ramp(4)))
            .frame(width: w * 0.098, height: h * 0.17)
            .position(x: w * 0.16, y: counterY + h * 0.012 - h * 0.085)
    }

    /// Smoke curling off THE ZOMBIE — quad-curve strands rippling upward,
    /// thinning and fading as they rise. VOLCANO WATCH triples the plume.
    private var smoke: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let segs: Int = 4
            let watch: Double = ramp(3)
            // (phase, x offset, 0 = always / 1 = VOLCANO WATCH extras)
            let strands: [(Double, Double, Double)] = [
                (0.0, -1.0, 0), (2.1, 0.0, 0), (4.4, 1.0, 0),
                (1.2, -1.7, 1), (3.3, 1.7, 1), (5.6, -0.5, 1),
                (0.7, 0.5, 1), (2.9, -2.3, 1), (5.0, 2.3, 1),
            ]
            for s in strands {
                let gate: Double = s.2 == 0 ? 1 : watch
                guard gate > 0 else { continue }
                let phase: Double = s.0
                let baseX: Double = width * 0.5 + s.1 * width * 0.11
                let fade: Double = 0.55 + 0.45 * sin(t * 0.30 + phase * 1.7)
                var prevX: Double = baseX
                var prevY: Double = height
                for j in 0..<segs {
                    let fj: Double = Double(j)
                    let y1: Double = height - height * (fj + 1) / Double(segs)
                    let amp: Double = width * (0.05 + 0.11 * (fj + 1) / Double(segs))
                    let x1: Double = baseX + amp * sin((fj + 1) * 1.6 + phase - t * 0.60)
                    let midAmp: Double = amp * 0.85
                    let ctrlX: Double = (prevX + x1) / 2 + midAmp * sin((fj + 0.5) * 1.6 + phase - t * 0.60 + 1.3)
                    let ctrlY: Double = (prevY + y1) / 2
                    var strand = Path()
                    strand.move(to: CGPoint(x: prevX, y: prevY))
                    strand.addQuadCurve(to: CGPoint(x: x1, y: y1), control: CGPoint(x: ctrlX, y: ctrlY))
                    let alpha: Double = (0.32 - 0.07 * fj) * fade * (0.45 + 0.55 * glow) * gate
                    let lw: Double = 3.2 - 0.6 * fj
                    ctx.stroke(
                        strand,
                        with: .color(P.cream.color.opacity(alpha)),
                        style: StrokeStyle(lineWidth: lw, lineCap: .round)
                    )
                    prevX = x1
                    prevY = y1
                }
            }
        }
        .frame(width: w * 0.09, height: h * 0.27)
        .position(x: w * 0.16, y: h * 0.497)
        .allowsHitTesting(false)
    }

    /// VOLCANO WATCH: ember flecks drift up through the room; THE ZOMBIE
    /// doubles the swarm. Merge beats flare it. A gold rim lights the counter
    /// slab under eruption light.
    @ViewBuilder
    private var emberFlecks: some View {
        let watch: Double = ramp(3)
        if watch > 0 {
            let erupt: Double = ramp(4)
            let age: Double = t - beatAt
            let flare: Double = (beatAt > 0 && age >= 0 && age < 0.9) ? (1 - age / 0.9) : 0
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let height: Double = Double(sz.height)
                let seeds: [Double] = [
                    0.04, 0.10, 0.17, 0.26, 0.34, 0.43, 0.52, 0.60, 0.69, 0.78, 0.87, 0.95,
                    0.07, 0.22, 0.39, 0.56, 0.73, 0.91,
                ]
                for (i, sx) in seeds.enumerated() {
                    let gate: Double = i < 12 ? watch : erupt
                    guard gate > 0 else { continue }
                    let fi: Double = Double(i)
                    let cycle: Double = 9 + 4 * fi.truncatingRemainder(dividingBy: 3)
                    let u: Double = ((t + fi * 3.7) / cycle).truncatingRemainder(dividingBy: 1)
                    let y: Double = height * (1 - u)
                    let x: Double = sx * width + width * 0.02 * sin(t * 1.1 + fi * 2.2)
                    let a: Double = gate * sin(u * .pi)
                        * (0.55 + 0.35 * (0.5 + 0.5 * sin(t * 3 + fi))) * (1 + 0.8 * flare)
                    let r: Double = (i % 3 == 0 ? 6.0 : 4.2) * (1 + 0.5 * flare)
                    let tint: RGB = i % 3 == 0 ? P.coral : P.torch
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r * 1.7)),
                        with: .color(tint.color.opacity(min(0.9, a)))
                    )
                }
            }
            .frame(width: w, height: h * 0.62)
            .position(x: w / 2, y: h * 0.45)
            .allowsHitTesting(false)
            if erupt > 0 {
                Rectangle()
                    .fill(P.torch.mix(P.cream, 0.35).opacity(0.45 * erupt * (0.8 + 0.2 * sin(t * 2 * .pi / 5))))
                    .frame(width: w, height: slabH * 0.4)
                    .position(x: w / 2, y: counterY + slabH * 0.2)
                    .allowsHitTesting(false)
            }
        }
    }

    /// Small candle beside the Zombie — the fast and flicker layers.
    /// DUSK BLINDS brightens it: bigger halo, taller flame.
    private var candle: some View {
        let brighten: Double = ramp(1)
        let flick: Double = (1 + 0.14 * sin(t * 8.3) + 0.08 * sin(t * 57 + 1.7)) * (1 + 0.28 * brighten)
        let lean: Double = 4 * sin(t * 6.1) + 2 * sin(t * 15)
        let haloPulse: Double = 0.5 + 0.5 * sin(t * 8.3 + 0.6) + 0.15 * sin(t * 57)
        let haloAlpha: Double = (0.07 + 0.09 * haloPulse) * glow * (1 + 1.3 * brighten)
        let cx: CGFloat = w * 0.24
        let waxTop: CGFloat = h * 0.770
        return ZStack {
            Circle()
                .fill(P.torch.mix(P.cream, 0.5).opacity(haloAlpha))
                .frame(width: h * 0.028 * (1 + 0.7 * CGFloat(brighten)), height: h * 0.028 * (1 + 0.7 * CGFloat(brighten)))
                .position(x: cx, y: h * 0.768)
            Rectangle()
                .fill(P.cream.color)
                .frame(width: w * 0.030, height: h * 0.014)
                .position(x: cx, y: h * 0.777)
            Rectangle()
                .fill(P.torch.color)
                .frame(width: w * 0.036, height: h * 0.004)
                .position(x: cx, y: waxTop)
            ZStack {
                FlameShape()
                    .fill(P.coral.color)
                    .frame(width: w * 0.022, height: h * 0.015)
                FlameShape()
                    .fill(P.torch.color)
                    .frame(width: w * 0.012, height: h * 0.009)
                    .offset(y: h * 0.003)
            }
            .scaleEffect(x: 1, y: CGFloat(flick), anchor: .bottom)
            .rotationEffect(.degrees(lean), anchor: .bottom)
            .position(x: cx, y: waxTop - h * 0.0075)
        }
    }

    /// The suspicious cat, up on the counter, side-eyeing the smoking drink.
    private var cat: some View {
        CatView(t: t)
            .frame(width: w * 0.14, height: h * 0.095)
            .scaleEffect(x: -1, y: 1)
            .position(x: w * 0.925, y: counterY + h * 0.015 - h * 0.0475)
    }
}

/// THE ZOMBIE — a tall carved tiki vessel, drawn in a 100x170 design box.
/// Its eyes catch the lamplight as the room deepens. Internal: the lounge
/// reuses it as the earned trophy on the credenza (never sold).
struct ZombieMugView: View {
    let t: Double
    let glow: Double

    var body: some View {
        let eyeGlow: Double = 0.15 + 0.55 * glow * (0.75 + 0.25 * sin(t * 1.1 + 0.8))
        return Canvas { ctx, sz in
            let sx: Double = Double(sz.width) / 100
            let sy: Double = Double(sz.height) / 170
            func rect(_ x: Double, _ y: Double, _ rw: Double, _ rh: Double) -> CGRect {
                CGRect(x: x * sx, y: y * sy, width: rw * sx, height: rh * sy)
            }
            func poly(_ pts: [(Double, Double)]) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: pts[0].0 * sx, y: pts[0].1 * sy))
                for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0 * sx, y: q.1 * sy)) }
                p.closeSubpath()
                return p
            }

            ctx.fill(poly([(12, 6), (88, 6), (77, 170), (23, 170)]), with: .color(P.clay.mix(P.rum, 0.30)))
            ctx.fill(poly([(12, 6), (88, 6), (87, 20), (13, 20)]), with: .color(P.ember.color))
            ctx.fill(poly([(20, 40), (46, 34), (47, 42), (21, 48)]), with: .color(P.ember.color))
            ctx.fill(poly([(54, 34), (80, 40), (79, 48), (53, 42)]), with: .color(P.ember.color))
            ctx.fill(poly([(24, 52), (45, 50), (45, 66), (24, 68)]), with: .color(P.ink.color))
            ctx.fill(poly([(55, 50), (76, 52), (76, 68), (55, 66)]), with: .color(P.ink.color))
            ctx.fill(Path(rect(30, 55, 9, 8)), with: .color(P.torch.color.opacity(eyeGlow)))
            ctx.fill(Path(rect(61, 55, 9, 8)), with: .color(P.torch.color.opacity(eyeGlow)))
            ctx.fill(poly([(50, 74), (58, 92), (42, 92)]), with: .color(P.ember.color))
            ctx.fill(Path(rect(25, 102, 50, 18)), with: .color(P.ink.color))
            for i in 0..<3 {
                ctx.fill(Path(rect(29 + Double(i) * 15, 104, 9, 6)), with: .color(P.cream.color))
            }
            for i in 0..<2 {
                ctx.fill(Path(rect(36 + Double(i) * 15, 113, 9, 6)), with: .color(P.cream.color))
            }
            for gy in [136.0, 146.0] {
                var groove = Path()
                groove.move(to: CGPoint(x: 26 * sx, y: gy * sy))
                groove.addLine(to: CGPoint(x: 74 * sx, y: gy * sy))
                ctx.stroke(groove, with: .color(P.ember.color), lineWidth: 2.5 * sy)
            }
            ctx.fill(poly([(24.5, 156), (75.5, 156), (74.5, 170), (25.5, 170)]), with: .color(P.ember.color))
        }
    }
}

#Preview {
    ZombieBackgroundView()
}
