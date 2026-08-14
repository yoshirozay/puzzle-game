import SwiftUI

/// Open-ocean night passage (Navigator memory-flash). A sky-dominant
/// starfield over calm swell: crescent moon high to port, an outrigger
/// canoe running before the wind with the cat curled on the prow, the
/// departure headland's torch lights sinking astern. One TimelineView
/// clock drives everything; the palette breathes on a 90-second
/// "deep night" cycle. Depth states sail the voyage: HARBOR shore
/// astern → REEF PASS foam → OPEN OCEAN star bloom → LANDFALL island
/// ahead with first-light rose on the horizon. Shared components live
/// in TikiScenery.swift.
struct NavigatorBackgroundView: View {
    var phase: ProgressPhase = ProgressPhase()   // default = today's scene exactly
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
                NavigatorScene(
                    t: t, size: geo.size,
                    depth: reduceMotion ? phase.depth : dial.eased(at: t),
                    stage: reduceMotion ? Double(phase.stage) : stageDial.eased(at: t),
                    tier: phase.tier,
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

private struct NavigatorScene: View {
    let t: Double
    let size: CGSize
    let depth: Double
    let stage: Double    // eased 0...3 position on the voyage ladder
    let tier: Int        // persistent mark: constellation figures charted (perfect clears)
    let beat: Int        // cumulative chart counter
    let beatAt: Double   // wall-clock moment of the latest chart beat

    /// 0 = overcast hush, 1 = crystal night peak. Slow 90 s breath; run
    /// depth lifts the floor (full swing at depth 0 — the shipped scene).
    var night: Double {
        let breath = (1 - cos(t * 2 * .pi / 90)) / 2
        return depth * 0.7 + breath * (1 - depth * 0.7)
    }

    /// 0→1 across the arrival of stage s: REEF PASS 1, OPEN OCEAN 2, LANDFALL 3.
    /// All zero at stage 0 — the shipped scene exactly.
    func ramp(_ s: Int) -> Double { min(1, max(0, stage - Double(s - 1))) }

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var horizonY: CGFloat { h * 0.76 }
    var moonX: CGFloat { w * 0.16 }
    var moonY: CGFloat { h * 0.115 }
    var moonR: CGFloat { w * 0.072 }
    var canoeX: CGFloat { w * (0.36 + 0.012 * sin(t * 0.09)) }
    var canoeY: CGFloat { h * 0.83 }

    var body: some View {
        ZStack {
            sky
            starField
            constellations
            shootingStar
            moon
            clouds
            sea
            islet
            landfall
            headland
            canoe
        }
    }

    // MARK: sky

    private func band(_ y0: CGFloat, _ y1: CGFloat, _ fill: Color) -> some View {
        Rectangle()
            .fill(fill)
            .frame(width: w, height: y1 - y0)
            .position(x: w / 2, y: (y0 + y1) / 2)
    }

    /// Five cool steps, darkest at the zenith. The two bands under 0.44h
    /// carry the board zone: near-identical values so the one seam inside
    /// the play band stays a whisper. LANDFALL warms only the horizon band.
    private var sky: some View {
        let rose: Double = ramp(3)
        let b1: Color = P.ink.lerp(P.twilight, 0.42).mix(P.twilight, 0.10 * night)
        let b2: Color = P.twilight.lerp(P.ink, 0.30).mix(P.twilight, 0.14 * night)
        let b3: Color = P.twilight.lerp(P.lagoon, 0.20).mix(P.twilight, 0.08 * night)
        let b4: Color = P.twilight.lerp(P.lagoon, 0.26).lerp(P.blossom, 0.040 + 0.020 * night).color
        let b5: Color = P.twilight.lerp(P.lagoon, 0.28)
            .lerp(P.blossom, 0.050 + 0.022 * night)
            .lerp(P.clay, 0.10 * rose).color
        return ZStack {
            band(0, h * 0.14, b1)
            band(h * 0.14, h * 0.29, b2)
            band(h * 0.29, h * 0.44, b3)
            band(h * 0.44, h * 0.62, b4)
            band(h * 0.62, horizonY, b5)
        }
    }

    /// The working sky: hash-scattered stars confined above the board band,
    /// density thinning toward it. Depth blooms the field — charting below
    /// lights the sky above. A few four-point sparkles carry the
    /// mid-century read.
    private var starField: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let bloom: Double = 0.55 + 0.30 * night + 0.35 * depth + 0.20 * ramp(2)
            let count: Int = 26 + Int(6 * ramp(2))
            for i in 0..<count {
                let fi: Double = Double(i)
                let hx: Double = (sin(fi * 127.1 + 1.3) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                let hy: Double = (sin(fi * 311.7 + 4.7) * 26951.2917).truncatingRemainder(dividingBy: 1).magnitude
                let px: Double = hx * width
                // Thin toward the board band: squared bias pulls stars up,
                // and nothing renders past 86% of the field — the board
                // band below stays star-free.
                let py: Double = hy * hy * height
                guard py <= height * 0.86 else { continue }
                let fade: Double = py > height * 0.72 ? 0.35 : 1.0
                let twinkle: Double = 0.55 + 0.45 * sin(t * (0.8 + hx * 1.6) + fi * 2.3)
                let alpha: Double = (0.22 + 0.55 * twinkle) * bloom * fade
                if i % 7 == 0 {
                    // Four-point sparkle: two thin crossed bars.
                    let arm: Double = 3.4 + 1.4 * twinkle
                    let across = CGRect(x: px - arm, y: py - 0.55, width: arm * 2, height: 1.1)
                    let down = CGRect(x: px - 0.55, y: py - arm, width: 1.1, height: arm * 2)
                    ctx.fill(Path(across), with: .color(P.blossom.color.opacity(alpha)))
                    ctx.fill(Path(down), with: .color(P.blossom.color.opacity(alpha)))
                } else {
                    let r: Double = i % 4 == 0 ? 2.5 : 1.6
                    let rect = CGRect(x: px, y: py, width: r, height: r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(P.blossom.color.opacity(alpha)))
                }
            }
        }
        .frame(width: w, height: h * 0.46)
        .position(x: w / 2, y: h * 0.23)
        .allowsHitTesting(false)
    }

    /// The navigator's charted figures: one faint connected constellation
    /// per tier mark, pinned to the upper corners — the earned aesthetic
    /// (perfect charts etch the sky). Zero at tier 0.
    private var constellations: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let figures: [[(Double, Double)]] = [
                [(0.70, 0.22), (0.76, 0.14), (0.84, 0.18), (0.90, 0.10)],           // the paddle
                [(0.08, 0.52), (0.14, 0.44), (0.22, 0.48), (0.18, 0.58), (0.10, 0.60)], // the sail
                [(0.55, 0.08), (0.61, 0.05), (0.67, 0.09), (0.63, 0.16)],           // the frigate bird
                [(0.34, 0.30), (0.40, 0.24), (0.47, 0.28), (0.44, 0.38)],           // the honu
            ]
            let glow: Double = 0.16 + 0.10 * night
            for f in 0..<min(tier, figures.count) {
                let fig = figures[f]
                var line = Path()
                for (i, p) in fig.enumerated() {
                    let point = CGPoint(x: p.0 * width, y: p.1 * height)
                    if i == 0 { line.move(to: point) } else { line.addLine(to: point) }
                }
                ctx.stroke(line, with: .color(P.cream.color.opacity(glow)), lineWidth: 1.0)
                for p in fig {
                    let rect = CGRect(x: p.0 * width - 1.6, y: p.1 * height - 1.6, width: 3.2, height: 3.2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(P.cream.color.opacity(glow + 0.22)))
                }
            }
        }
        .frame(width: w, height: h * 0.42)
        .position(x: w / 2, y: h * 0.21)
        .allowsHitTesting(false)
    }

    /// Every ~24 s a star falls through the top band — the sky is alive,
    /// and not every streak belongs on the chart (the decoy, foreshadowed).
    private var shootingStar: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let cycle: Double = 24
            let u: Double = (t.truncatingRemainder(dividingBy: cycle)) / 1.1
            guard u < 1 else { return }
            let n: Double = (t / cycle).rounded(.down)
            let hx: Double = (sin(n * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
            let hy: Double = (sin(n * 78.233) * 26951.2917).truncatingRemainder(dividingBy: 1).magnitude
            let x0: Double = width * (0.15 + 0.6 * hx)
            let y0: Double = height * (0.10 + 0.45 * hy)
            let dx: Double = width * 0.16
            let dy: Double = height * 0.30
            let head = CGPoint(x: x0 + dx * u, y: y0 + dy * u)
            let tailU: Double = max(0, u - 0.22)
            let tail = CGPoint(x: x0 + dx * tailU, y: y0 + dy * tailU)
            var streak = Path()
            streak.move(to: tail)
            streak.addLine(to: head)
            let alpha: Double = (1 - u) * 0.55
            ctx.stroke(streak, with: .color(P.blossom.color.opacity(alpha)), lineWidth: 1.4)
            let rect = CGRect(x: head.x - 1.5, y: head.y - 1.5, width: 3, height: 3)
            ctx.fill(Path(ellipseIn: rect), with: .color(P.blossom.color.opacity(alpha + 0.2)))
        }
        .frame(width: w, height: h * 0.44)
        .position(x: w / 2, y: h * 0.22)
        .allowsHitTesting(false)
    }

    // MARK: moon

    /// Waning crescent high to port, halo rings breathing with the night.
    /// Flat construction: a bright disc with a sky-colored bite. Depth
    /// swells the halo — the charted sky glows back.
    private var moon: some View {
        let biteFill: Color = P.ink.lerp(P.twilight, 0.42).mix(P.twilight, 0.10 * night)
        let glow: Double = 0.5 + 0.5 * night
        return ZStack {
            Circle()
                .fill(P.blossom.color.opacity(0.05 + 0.05 * glow + 0.05 * depth))
                .frame(width: moonR * 3.6, height: moonR * 3.6)
                .position(x: moonX, y: moonY)
            Circle()
                .fill(P.blossom.color.opacity(0.09 + 0.07 * glow + 0.06 * depth))
                .frame(width: moonR * 2.4, height: moonR * 2.4)
                .position(x: moonX, y: moonY)
            Circle()
                .fill(P.cream.lerp(P.blossom, 0.55).color)
                .frame(width: moonR * 2, height: moonR * 2)
                .position(x: moonX, y: moonY)
            Circle()
                .fill(biteFill)
                .frame(width: moonR * 1.72, height: moonR * 1.72)
                .position(x: moonX + moonR * 0.42, y: moonY - moonR * 0.18)
        }
    }

    /// Two night cumulus silhouettes on a glacial drift, barely lighter
    /// than the sky where the moon reaches them.
    private var clouds: some View {
        let lit: Color = P.twilight.lerp(P.blossom, 0.10 + 0.05 * night).color
        return ZStack {
            CloudPuff(width: w * 0.26)
                .foregroundStyle(lit.opacity(0.55))
                .position(
                    x: wrapX(0.68, speed: 1 / 320),
                    y: h * 0.075 + 3 * sin(t * 0.09)
                )
            CloudPuff(width: w * 0.18)
                .foregroundStyle(lit.opacity(0.42))
                .position(
                    x: wrapX(0.22, speed: 1 / 280),
                    y: h * 0.245 + 3 * sin(t * 0.12 + 2.1)
                )
        }
    }

    /// Cloud drift with a wrap that happens off-screen (no visible seam).
    private func wrapX(_ start: Double, speed: Double) -> CGFloat {
        let u: Double = (start + t * speed).truncatingRemainder(dividingBy: 1.3)
        return w * CGFloat(u * 1.3 - 0.15)
    }

    // MARK: sea

    /// Three moonlit swell bands stepping darker toward the bow of the
    /// screen, the glint lane pooling under the moon, and — from REEF
    /// PASS — a foam seam breaking mid-channel.
    private var sea: some View {
        let top: Color = P.lagoon.lerp(P.twilight, 0.45).lerp(P.blossom, 0.05 + 0.04 * night).color
        let mid: Color = P.lagoon.lerp(P.twilight, 0.58).mix(P.ink, 0.10)
        let deep: Color = P.twilight.lerp(P.ink, 0.45).mix(P.deepLeaf, 0.18)
        return ZStack {
            band(horizonY, horizonY + (h - horizonY) * 0.34, top)
            band(horizonY + (h - horizonY) * 0.34, horizonY + (h - horizonY) * 0.68, mid)
            band(horizonY + (h - horizonY) * 0.68, h, deep)
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let seaH: Double = Double(sz.height)
                // Slow swell strokes, calm and low-alpha.
                for row in 0..<4 {
                    let fr: Double = Double(row)
                    let y: Double = seaH * (0.18 + 0.21 * fr)
                    let amp: Double = 1.0 + 0.7 * fr
                    let speed: Double = 0.30 + 0.10 * fr
                    let alpha: Double = 0.06 + 0.02 * fr
                    var path = Path()
                    var first = true
                    var x: Double = 0
                    while x <= width {
                        let angle: Double = x / 120 * 2 * .pi + t * speed + fr * 2.1
                        let yy: Double = y + amp * sin(angle)
                        let point = CGPoint(x: x, y: yy)
                        if first { path.move(to: point); first = false }
                        else { path.addLine(to: point) }
                        x += 6
                    }
                    ctx.stroke(path, with: .color(P.blossom.color.opacity(alpha)), lineWidth: 1.2)
                }
                // The moon's glint lane: cool dashes pooling to port.
                let gx0: Double = width * 0.16
                for row in 0..<5 {
                    let fr: Double = Double(row)
                    let gy: Double = seaH * (0.14 + 0.16 * fr)
                    let shimmer: Double = 0.5 + 0.5 * sin(t * 1.4 + fr * 1.7)
                    let wobble: Double = 4 * sin(t * 0.45 + fr * 2.2)
                    let gw: Double = 22 - fr * 2.0 + wobble
                    let sway: Double = 5 * sin(t * 0.28 + fr * 2.6)
                    let alpha: Double = (0.18 + 0.16 * night) * shimmer
                    let rect = CGRect(x: gx0 - gw / 2 + sway, y: gy, width: gw, height: 2.2)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.1), with: .color(P.blossom.color.opacity(alpha)))
                }
                // REEF PASS: a foam seam breaking across the mid channel.
                let reef: Double = ramp(1) * (1 - 0.55 * ramp(2))
                if reef > 0.02 {
                    var foam = Path()
                    var first = true
                    var fx: Double = width * 0.55
                    while fx <= width * 1.01 {
                        let lap: Double = 2.2 * sin(fx / 60 + t * 0.5) + 1.1 * sin(fx / 19 - t * 0.3)
                        let y: Double = seaH * 0.30 + lap
                        let point = CGPoint(x: fx, y: y)
                        if first { foam.move(to: point); first = false }
                        else { foam.addLine(to: point) }
                        fx += 7
                    }
                    ctx.stroke(foam, with: .color(P.blossom.color.opacity(0.30 * reef)), lineWidth: 1.8)
                    for j in 0..<5 {
                        let fj: Double = Double(j)
                        let bx: Double = width * (0.60 + 0.09 * fj)
                        let sparkle: Double = max(0, sin(t * (0.9 + fj * 0.3) + fj * 2.4))
                        let rect = CGRect(x: bx, y: seaH * 0.30 - 3.5, width: 2.2, height: 2.2)
                        ctx.fill(Path(ellipseIn: rect), with: .color(P.blossom.color.opacity(0.5 * sparkle * reef)))
                    }
                }
                // A porpoise rolls through the channel every ~31 s — quick,
                // quiet, gone before you're sure you saw it.
                let pCycle: Double = 31
                let pu: Double = (t.truncatingRemainder(dividingBy: pCycle)) / 2.2
                if pu < 1 {
                    let hide: Color = P.ink.lerp(P.twilight, 0.25).color
                    let px: Double = width * (0.56 + 0.16 * pu)
                    let arcH: Double = 10 * sin(pu * .pi)
                    let py: Double = seaH * 0.38 - arcH
                    if arcH > 0.5 {
                        var back = Path()
                        back.move(to: CGPoint(x: px - 13, y: py + 6))
                        back.addQuadCurve(to: CGPoint(x: px + 13, y: py + 6), control: CGPoint(x: px, y: py - 8))
                        back.closeSubpath()
                        ctx.fill(back, with: .color(hide.opacity(0.9)))
                        var fin = Path()
                        fin.move(to: CGPoint(x: px - 1, y: py - 1))
                        fin.addLine(to: CGPoint(x: px + 4, y: py - 7))
                        fin.addLine(to: CGPoint(x: px + 6, y: py - 1))
                        fin.closeSubpath()
                        ctx.fill(fin, with: .color(hide.opacity(0.9)))
                    }
                    if pu > 0.35 {
                        let ru: Double = (pu - 0.35) / 0.65
                        let rw: Double = 10 + 26 * ru
                        let rect = CGRect(x: px - 20 - rw / 2, y: seaH * 0.38 + 5 - rw * 0.10, width: rw, height: rw * 0.20)
                        ctx.stroke(Path(ellipseIn: rect), with: .color(P.blossom.color.opacity(0.30 * (1 - ru))), lineWidth: 1.2)
                    }
                }
            }
            .frame(width: w, height: h - horizonY)
            .position(x: w / 2, y: (horizonY + h) / 2)
        }
    }

    // MARK: voyage geography

    /// LANDFALL: the destination rises ahead to port — an island silhouette,
    /// shore fires pricking on, a rose whisper of first light along its
    /// stretch of horizon.
    private var landfall: some View {
        let arrive: Double = ramp(3)
        return ZStack {
            if arrive > 0.02 {
                Rectangle()
                    .fill(P.clay.color.opacity(0.16 * arrive))
                    .frame(width: w * 0.40, height: 3)
                    .position(x: w * 0.20, y: horizonY - 1)
                IslandShape()
                    .fill(P.ink.lerp(P.twilight, 0.30).color.opacity(min(1, arrive * 1.4)))
                    .frame(width: w * 0.20, height: h * 0.030 * arrive)
                    .position(x: w * 0.185, y: horizonY - h * 0.013 * arrive)
                TinyPalm()
                    .stroke(P.ink.lerp(P.twilight, 0.30).color.opacity(arrive), lineWidth: 1.4)
                    .frame(width: w * 0.036, height: h * 0.028)
                    .position(x: w * 0.178, y: horizonY - h * (0.014 + 0.020 * arrive))
                Canvas { ctx, sz in
                    let width: Double = Double(sz.width)
                    for j in 0..<3 {
                        let fj: Double = Double(j)
                        let flick: Double = 0.6 + 0.4 * sin(t * (2.0 + fj) + fj * 2.1)
                        let rect = CGRect(x: width * (0.30 + 0.20 * fj), y: 3 + fj.truncatingRemainder(dividingBy: 2) * 2, width: 2.4, height: 2.4)
                        ctx.fill(Path(ellipseIn: rect), with: .color(P.torch.color.opacity(0.85 * flick * arrive)))
                    }
                }
                .frame(width: w * 0.20, height: 10)
                .position(x: w * 0.185, y: horizonY - h * 0.006)
            }
        }
        .allowsHitTesting(false)
    }

    /// A far islet resting on the horizon — small, muted, squint-readable.
    private var islet: some View {
        IslandShape()
            .fill(P.twilight.lerp(P.ink, 0.35).color.opacity(0.75))
            .frame(width: w * 0.11, height: h * 0.014)
            .position(x: w * 0.60, y: horizonY - h * 0.006)
    }

    /// The departure headland astern (starboard corner): a staircase
    /// coastal mass breaking the horizon, the harbor's torch lights on its
    /// caps. The voyage pulls it under — REEF PASS starts the sink, OPEN
    /// OCEAN takes it below the horizon for good.
    private var headland: some View {
        let sink: Double = ramp(1) * 0.40 + ramp(2) * 0.60
        let gone: Double = min(1, ramp(2) * 1.6)
        return Canvas { ctx, sz in
            guard gone < 0.98 else { return }
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let fade: Double = 1 - gone
            let drop: Double = sink * height * 0.62
            let horizon: Double = height * 0.40
            let fill: Color = P.ink.lerp(P.twilight, 0.18).color
            // Staircase silhouette stepping down from the right edge to the
            // waterline: (xEnd, capY) per step, tallest first. One closed
            // path — caps run left, risers run down, a hairline foot rides
            // just under the horizon, and the near shore runs off-frame.
            let steps: [(Double, Double)] = [(0.86, 0.25), (0.68, 0.31), (0.52, 0.37), (0.35, 0.40)]
            var mass = Path()
            mass.move(to: CGPoint(x: width, y: height * 0.42 + drop))
            mass.addLine(to: CGPoint(x: width, y: steps[0].1 * height + drop))
            var lastY: Double = steps[0].1
            for s in steps {
                mass.addLine(to: CGPoint(x: s.0 * width, y: lastY * height + drop))
                mass.addLine(to: CGPoint(x: s.0 * width, y: s.1 * height + drop))
                lastY = s.1
            }
            mass.addLine(to: CGPoint(x: steps.last!.0 * width, y: height * 0.42 + drop))
            mass.closeSubpath()
            ctx.fill(mass, with: .color(fill.opacity(fade)))
            // Moonlit cap rim along the stepped skyline.
            var rim = Path()
            rim.move(to: CGPoint(x: width, y: steps[0].1 * height + drop))
            lastY = steps[0].1
            for s in steps {
                rim.addLine(to: CGPoint(x: s.0 * width, y: lastY * height + drop))
                rim.addLine(to: CGPoint(x: s.0 * width, y: s.1 * height + drop))
                lastY = s.1
            }
            ctx.stroke(rim, with: .color(P.blossom.color.opacity(0.20 * fade)), lineWidth: 1.4)
            // Harbor torches on the high caps — home, going dark astern —
            // and their glimmer wavering on the water below the horizon.
            let torches: [(Double, Double)] = [(0.93, 0.235), (0.76, 0.295), (0.60, 0.355)]
            for (j, tor) in torches.enumerated() {
                let fj: Double = Double(j)
                let flick: Double = 0.55 + 0.45 * sin(t * (2.4 + fj * 0.7) + fj * 1.9)
                let tx: Double = tor.0 * width
                let ty: Double = tor.1 * height + drop
                let rect = CGRect(x: tx - 1.5, y: ty - 1.5, width: 3.0, height: 3.0)
                ctx.fill(Path(ellipseIn: rect), with: .color(P.torch.color.opacity(flick * fade)))
                let glowRect = CGRect(x: tx - 3.8, y: ty - 3.8, width: 7.6, height: 7.6)
                ctx.fill(Path(ellipseIn: glowRect), with: .color(P.torch.color.opacity(0.28 * flick * fade)))
                if j < 2 {
                    let sway: Double = 2 * sin(t * 0.7 + fj)
                    let gRect = CGRect(x: width * (0.82 - 0.14 * fj) + sway, y: height * (0.47 + 0.05 * fj) + drop, width: 2, height: 7)
                    ctx.fill(Path(roundedRect: gRect, cornerRadius: 1), with: .color(P.torch.color.opacity(0.16 * flick * fade)))
                }
            }
        }
        .frame(width: w * 0.34, height: h * 0.40)
        .position(x: w * 0.83, y: h * 0.80)
        .allowsHitTesting(false)
    }

    // MARK: the canoe

    /// The voyaging canoe running to port: dark hull with an outrigger
    /// float, crab-claw sail, the navigator seated at the steering paddle —
    /// and the cat curled on the foredeck, supervising the sky. A chart
    /// beat dips the paddle and stirs glow-tide sparks in the wake.
    private var canoe: some View {
        let bob: Double = 2.2 * sin(t * 0.7)
        let heel: Double = 1.3 * sin(t * 0.23) - 1.0
        return ZStack {
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let height: Double = Double(sz.height)
                let cy: Double = height * 0.62 + bob
                let ink: Color = P.ink.color
                // Wake: two diverging lines astern, glow-tide flecks inside.
                var wakeA = Path()
                wakeA.move(to: CGPoint(x: width * 0.66, y: cy + 10))
                wakeA.addQuadCurve(
                    to: CGPoint(x: width * 1.02, y: cy + 4),
                    control: CGPoint(x: width * 0.86, y: cy + 12)
                )
                ctx.stroke(wakeA, with: .color(P.blossom.color.opacity(0.20)), lineWidth: 1.4)
                var wakeB = Path()
                wakeB.move(to: CGPoint(x: width * 0.66, y: cy + 13))
                wakeB.addQuadCurve(
                    to: CGPoint(x: width * 1.02, y: cy + 22),
                    control: CGPoint(x: width * 0.86, y: cy + 18)
                )
                ctx.stroke(wakeB, with: .color(P.blossom.color.opacity(0.15)), lineWidth: 1.2)
                for j in 0..<6 {
                    let fj: Double = Double(j)
                    let u: Double = ((fj * 0.17 + t * 0.10).truncatingRemainder(dividingBy: 1))
                    let px: Double = width * (0.68 + 0.30 * u)
                    let py: Double = cy + 8 + 10 * u + 2.5 * sin(fj * 2.6)
                    let sparkle: Double = max(0, sin(t * (1.1 + fj * 0.4) + fj * 2.2))
                    let rect = CGRect(x: px, y: py, width: 2.0, height: 2.0)
                    ctx.fill(Path(ellipseIn: rect), with: .color(P.bioGlow.color.opacity(0.35 * sparkle * (1 - u))))
                }
                // Chart beat: the paddle stirs a glow-tide burst, gone in 1.4 s.
                let age: Double = t - beatAt
                if beatAt > 0, age >= 0, age < 1.4 {
                    let u: Double = age / 1.4
                    func hash(_ n: Double) -> Double {
                        (sin(n) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                    }
                    for j in 0..<7 {
                        let fj: Double = Double(j)
                        let h1: Double = hash(fj * 12.9898 + Double(beat) * 78.233)
                        let h2: Double = hash(fj * 39.3467 + Double(beat) * 11.135)
                        let ang: Double = -.pi / 2 + (h1 - 0.5) * 2.2
                        let dist: Double = (4 + 22 * h2) * (1 - (1 - u) * (1 - u))
                        let px: Double = width * 0.70 + cos(ang) * dist
                        let py: Double = cy + 10 + sin(ang) * dist + 10 * u * u
                        let r: Double = 2.4 - 1.4 * u
                        let rect = CGRect(x: px, y: py, width: r, height: r)
                        ctx.fill(Path(ellipseIn: rect), with: .color(P.bioGlow.color.opacity((1 - u) * 0.7)))
                    }
                    for ring in 0..<2 {
                        let fr: Double = Double(ring)
                        let rw: Double = (12 + 34 * u) * (1 + fr * 0.5)
                        let alpha: Double = (1 - u) * (1 - u) * (0.4 - fr * 0.14)
                        let rect = CGRect(x: width * 0.70 - rw / 2, y: cy + 10 - rw * 0.12, width: rw, height: rw * 0.24)
                        ctx.stroke(Path(ellipseIn: rect), with: .color(P.blossom.color.opacity(alpha)), lineWidth: 1.4)
                    }
                }
                // Hull: long low sheer line, bow to port.
                var hull = Path()
                hull.move(to: CGPoint(x: width * 0.06, y: cy))
                hull.addQuadCurve(
                    to: CGPoint(x: width * 0.70, y: cy),
                    control: CGPoint(x: width * 0.38, y: cy + 13)
                )
                hull.addLine(to: CGPoint(x: width * 0.665, y: cy - 5))
                hull.addLine(to: CGPoint(x: width * 0.10, y: cy - 5))
                hull.addQuadCurve(
                    to: CGPoint(x: width * 0.06, y: cy - 12),
                    control: CGPoint(x: width * 0.065, y: cy - 8)
                )
                hull.closeSubpath()
                ctx.fill(hull, with: .color(ink))
                // Outrigger float on the near side, hung on two spars.
                var floatBar = Path()
                floatBar.move(to: CGPoint(x: width * 0.16, y: cy + 16))
                floatBar.addLine(to: CGPoint(x: width * 0.44, y: cy + 16))
                ctx.stroke(floatBar, with: .color(ink), style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                for sx in [0.21, 0.38] {
                    var spar = Path()
                    spar.move(to: CGPoint(x: width * sx, y: cy - 3))
                    spar.addLine(to: CGPoint(x: width * (sx + 0.015), y: cy + 15))
                    ctx.stroke(spar, with: .color(ink), lineWidth: 2.4)
                }
                // Crab-claw sail: two spars diverge from the tack like an
                // open claw; the cloth between them ends in a deep concave
                // notch. A short prop mast holds the tack — the spars are
                // the structure.
                let mastX: Double = width * 0.30
                let tack = CGPoint(x: mastX + width * 0.006, y: cy - 9)
                let tipA = CGPoint(x: mastX + width * 0.115, y: cy - height * 0.42)
                let tipB = CGPoint(x: mastX + width * 0.185, y: cy - height * 0.055)
                let ctrlA = CGPoint(x: mastX + width * 0.020, y: cy - height * 0.26)
                let ctrlB = CGPoint(x: mastX + width * 0.090, y: cy - height * 0.10)
                var mast = Path()
                mast.move(to: CGPoint(x: mastX, y: cy - 2))
                mast.addLine(to: tack)
                ctx.stroke(mast, with: .color(ink), lineWidth: 2.6)
                var sail = Path()
                sail.move(to: tack)
                sail.addQuadCurve(to: tipA, control: ctrlA)
                sail.addQuadCurve(
                    to: tipB,
                    control: CGPoint(x: mastX + width * 0.085, y: cy - height * 0.185)
                )
                sail.addQuadCurve(to: tack, control: ctrlB)
                sail.closeSubpath()
                ctx.fill(sail, with: .color(P.deepLeaf.lerp(P.ink, 0.55).color))
                // Spars in silhouette; moonlight rides the upper one.
                var sparA = Path()
                sparA.move(to: tack)
                sparA.addQuadCurve(to: tipA, control: ctrlA)
                ctx.stroke(sparA, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                ctx.stroke(sparA, with: .color(P.blossom.color.opacity(0.42)), lineWidth: 1.1)
                var sparB = Path()
                sparB.move(to: tack)
                sparB.addQuadCurve(to: tipB, control: ctrlB)
                ctx.stroke(sparB, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                // The navigator at the stern, steering paddle trailing.
                let navX: Double = width * 0.575
                let navY: Double = cy - 8
                ctx.fill(
                    Path(ellipseIn: CGRect(x: navX - 4.5, y: navY - 15, width: 9, height: 9)),
                    with: .color(ink)
                )
                var torso = Path()
                torso.move(to: CGPoint(x: navX - 6, y: navY - 7))
                torso.addQuadCurve(
                    to: CGPoint(x: navX + 7, y: navY + 1),
                    control: CGPoint(x: navX + 2, y: navY - 8)
                )
                torso.addLine(to: CGPoint(x: navX - 6, y: navY + 1))
                torso.closeSubpath()
                ctx.fill(torso, with: .color(ink))
                let dip: Double = beatAt > 0 && t - beatAt < 1.4 ? sin(min(1, (t - beatAt) / 0.5) * .pi) : 0
                var paddle = Path()
                paddle.move(to: CGPoint(x: navX + 4, y: navY - 6))
                paddle.addLine(to: CGPoint(x: navX + 15 + 2 * dip, y: navY + 17 + 3 * dip))
                ctx.stroke(paddle, with: .color(ink), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            }
            .frame(width: w * 0.46, height: h * 0.26)
            .position(x: canoeX, y: canoeY)
            .rotationEffect(.degrees(heel), anchor: .center)
            // The cat claimed the foredeck; the sky is under supervision.
            CatView(t: t)
                .frame(width: w * 0.055, height: h * 0.036)
                .position(x: canoeX - w * 0.155, y: canoeY + h * 0.007 + CGFloat(bob))
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    NavigatorBackgroundView()
}
