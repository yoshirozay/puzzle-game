import SwiftUI

/// Animated tiki lagoon backdrop (Tiki Stacks). All motion is driven by one
/// TimelineView clock; the palette breathes between golden hour and dusk on a
/// 90-second cycle. Shared components live in TikiScenery.swift.
struct TikiBackgroundView: View {
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
                TikiScene(
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

private struct TikiScene: View {
    let t: Double
    let size: CGSize
    let depth: Double
    let stage: Double    // eased 0...4 position on the lagoon's depth-state ladder
    let tier: Int        // persistent mark: ≥ 1 hangs the earned deck lantern strand
    let beat: Int        // cumulative line-clear counter
    let beatAt: Double   // wall-clock moment of the latest beat

    /// 0 = golden hour, 1 = dusk. Slow 90 s breath; run depth lifts the
    /// breath's floor (full swing at depth 0 — the shipped scene exactly).
    var dusk: Double {
        let breath = (1 - cos(t * 2 * .pi / 90)) / 2
        return depth * 0.7 + breath * (1 - depth * 0.7)
    }

    /// 0→1 across the arrival of stage s: DUSK 1, NIGHTFALL 2, MOONRISE 3,
    /// GLOW TIDE 4. All zero at stage 0 — the shipped scene exactly.
    func ramp(_ s: Int) -> Double { min(1, max(0, stage - Double(s - 1))) }

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var horizonY: CGFloat { h * 0.60 }
    var deckTopY: CGFloat { h * 0.82 }

    var body: some View {
        ZStack {
            sky
            stars
            clouds
            sun
            moon
            island
            ocean
            boat
            palms
            deck
            tiki
            torches
            deckStrand
            mug
            cat
            fireflies
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
        // NIGHTFALL banding: each band keeps a quarter of its dusk-breath
        // movement under the twilight/ink blend so the 90 s breath stays alive.
        let night: Double = 0.75 * ramp(2)
        func banded(_ day: RGB, _ mid: RGB, _ dark: RGB, _ target: RGB) -> Color {
            mix3RGB(day, mid, dark, dusk).lerp(target, night).color
        }
        return ZStack {
            band(0, h * 0.20, banded(P.blossom.lerp(P.coral, 0.25), P.coral, P.twilight, P.ink.lerp(P.twilight, 0.40)))
            band(h * 0.20, h * 0.34, banded(P.torch, P.sunsetMid, P.rum, P.twilight.lerp(P.ink, 0.35)))
            band(h * 0.34, h * 0.47, banded(P.sunsetMid, P.coral, P.ember, P.twilight.lerp(P.ink, 0.12)))
            band(h * 0.47, horizonY, banded(P.coral, P.clay, P.clay, P.twilight.lerp(P.ember, 0.30)))
        }
    }

    private var stars: some View {
        Canvas { ctx, sz in
            let night: Double = ramp(2)
            let reveal: Double = max((dusk - 0.4) / 0.6, night)
            guard reveal > 0 else { return }
            let count: Int = 18 + Int((22 * night).rounded())
            for i in 0..<count {
                let fi: Double = Double(i)
                let px: Double = (sin(fi * 127.1) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                let py: Double = (sin(fi * 311.7) * 26951.2917).truncatingRemainder(dividingBy: 1).magnitude
                let twinkle: Double = 0.55 + 0.45 * sin(t * (1.2 + px) + fi * 2.3)
                let alpha: Double = reveal * twinkle * (i < 18 ? 1 : night)
                let r: Double = i % 5 == 0 ? 3.0 : 1.9
                let sx: Double = px * Double(sz.width)
                let sy: Double = py * Double(sz.height)
                let rect = CGRect(x: sx, y: sy, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(P.blossom.color.opacity(alpha)))
            }
        }
        .frame(width: w, height: h * 0.19)
        .position(x: w / 2, y: h * 0.095)
    }

    private var sun: some View {
        let sunX: CGFloat = w * 0.40
        // DUSK settles the disc onto the horizon; NIGHTFALL sends it under
        // (the opaque ocean band clips it) and fades the halo.
        // DUSK's extra sink outruns the breath's 0.05 h swing, so a half-set
        // sun always reads as stage 1, never as a deep-breath golden hour.
        let sink: CGFloat = CGFloat(dusk) * h * 0.05
            + CGFloat(ramp(1)) * h * 0.085
            + CGFloat(ramp(2)) * h * 0.15
        let sunY: CGFloat = horizonY - h * 0.085 + sink
        let r: CGFloat = w * 0.16
        let pulse: Double = 1 + 0.015 * sin(t * 0.35)
        let disc: Color = P.blossom.mix(P.torch, dusk)
        return ZStack {
            Circle()
                .fill(disc.opacity(0.25))
                .frame(width: r * 3.0, height: r * 3.0)
                .scaleEffect(pulse)
            Circle()
                .fill(disc.opacity(0.35))
                .frame(width: r * 2.4, height: r * 2.4)
                .scaleEffect(pulse)
            Circle()
                .fill(disc)
                .frame(width: r * 2, height: r * 2)
        }
        .position(x: sunX, y: sunY)
        .opacity(1 - ramp(2))
    }

    /// MOONRISE: the moon climbs out of the lagoon exactly where the sun set
    /// (drawn before the ocean band, so the waterline occludes the rise).
    @ViewBuilder
    private var moon: some View {
        let rise: Double = ramp(3)
        if rise > 0 {
            let r: CGFloat = w * 0.085
            let startY: CGFloat = horizonY + r * 1.6
            let endY: CGFloat = horizonY - h * 0.085
            let disc: RGB = P.blossom.lerp(P.twilight, 0.08)
            let crater: Color = disc.mix(P.twilight, 0.30)
            ZStack {
                Circle()
                    .fill(disc.color.opacity(0.14))
                    .frame(width: r * 3.2, height: r * 3.2)
                Circle()
                    .fill(disc.color.opacity(0.20))
                    .frame(width: r * 2.5, height: r * 2.5)
                Circle()
                    .fill(disc.color)
                    .frame(width: r * 2, height: r * 2)
                Circle()
                    .fill(crater)
                    .frame(width: r * 0.42, height: r * 0.42)
                    .offset(x: -r * 0.40, y: -r * 0.22)
                Circle()
                    .fill(crater)
                    .frame(width: r * 0.26, height: r * 0.26)
                    .offset(x: r * 0.34, y: r * 0.38)
            }
            .position(x: w * 0.40, y: startY + (endY - startY) * CGFloat(rise))
            .opacity(min(1, rise * 1.5))
        }
    }

    private var clouds: some View {
        let tint: Color = P.blossom.mix(P.clay, dusk * 0.55)
        return ForEach(0..<3, id: \.self) { i in
            let fi = Double(i)
            let speed: Double = [5.5, 8.0, 11.0][i]
            let cw: CGFloat = [150, 100, 120][i]
            let cy: CGFloat = [h * 0.065, h * 0.15, h * 0.26][i]
            let span = Double(w + cw * 2)
            let x = CGFloat((t * speed + fi * 520).truncatingRemainder(dividingBy: span)) - cw
            CloudPuff(width: cw)
                .foregroundStyle(tint.opacity(0.92))
                .position(x: x, y: cy)
        }
    }

    private var island: some View {
        ZStack(alignment: .bottom) {
            IslandShape()
                .fill(P.deepLeaf.mix(P.ink, dusk * 0.6))
            TinyPalm()
                .stroke(P.deepLeaf.mix(P.ink, dusk * 0.6), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 26, height: 30)
                .offset(x: -10, y: -22)
        }
        .frame(width: w * 0.36, height: h * 0.030)
        .position(x: w * 0.84, y: horizonY - h * 0.015)
    }

    /// Distant catamaran drifting across the horizon — the scene's slowest layer.
    /// From DUSK on, its stern lantern is lit.
    private var boat: some View {
        let span: Double = Double(w) + 60
        let drift: Double = (t * 3.2).truncatingRemainder(dividingBy: span) - 30
        let bob: Double = 1.6 * sin(t * 0.9)
        let lit: Double = ramp(1)
        return ZStack {
            BoatShape()
                .fill(P.ink.mix(P.twilight, dusk * 0.4))
            if lit > 0 {
                Circle()
                    .fill(P.torch.color.opacity(0.30 * lit))
                    .frame(width: 10, height: 10)
                    .offset(x: 9, y: 4)
                Circle()
                    .fill(P.torch.color.opacity(lit * (0.75 + 0.25 * sin(t * 2.3))))
                    .frame(width: 4, height: 4)
                    .offset(x: 9, y: 4)
            }
        }
        .frame(width: 34, height: 26)
        .position(x: CGFloat(drift), y: horizonY - 11 + CGFloat(bob))
    }

    /// Someone left their drink on the deck. The cat has opinions.
    private var mug: some View {
        MugView()
            .frame(width: w * 0.055, height: h * 0.042)
            .position(x: w * 0.79, y: deckTopY + h * 0.055)
    }

    // MARK: water

    private var ocean: some View {
        let night: Double = ramp(2)
        let glade: Double = ramp(3)
        let tide: Double = ramp(4)
        return ZStack {
            band(horizonY, deckTopY, P.lagoon.lerp(P.deepLeaf, dusk).mix(P.ink, 0.35 * night))
            Canvas { ctx, sz in
                let width: Double = sz.width
                let oceanH: Double = sz.height
                for row in 0..<4 {
                    let fr: Double = Double(row)
                    let y: Double = oceanH * (0.20 + 0.20 * fr)
                    let amp: Double = 2.0 + 0.7 * fr
                    let speed: Double = 0.55 + 0.14 * fr
                    var path = Path()
                    var first = true
                    var x: Double = 0
                    while x <= width {
                        let angle: Double = x / 85 * 2 * .pi + t * speed + fr * 1.7
                        let yy: Double = y + amp * sin(angle)
                        let point = CGPoint(x: x, y: yy)
                        if first { path.move(to: point); first = false }
                        else { path.addLine(to: point) }
                        x += 6
                    }
                    // GLOW TIDE recolors the wavelets bioluminescent cyan.
                    let waveTint: RGB = P.cream.lerp(P.bioGlow, tide)
                    let surge: Double = tide * (0.16 + 0.10 * sin(t * 1.5 + fr * 2.1))
                    ctx.stroke(
                        path,
                        with: .color(waveTint.color.opacity(0.20 + surge)),
                        lineWidth: 1.6 + 0.8 * tide
                    )
                }
                // GLOW TIDE: extra cyan wavelets shimmering between the rows.
                if tide > 0 {
                    for row in 0..<3 {
                        let fr: Double = Double(row)
                        let y: Double = oceanH * (0.30 + 0.20 * fr)
                        var path = Path()
                        var first = true
                        var x: Double = 0
                        while x <= width {
                            let angle: Double = x / 60 * 2 * .pi + t * (0.8 + 0.2 * fr) + fr * 2.8
                            let yy: Double = y + (1.4 + 0.5 * fr) * sin(angle)
                            let point = CGPoint(x: x, y: yy)
                            if first { path.move(to: point); first = false }
                            else { path.addLine(to: point) }
                            x += 6
                        }
                        let shimmer: Double = 0.5 + 0.5 * sin(t * 2.2 + fr * 2.6)
                        ctx.stroke(
                            path,
                            with: .color(P.bioGlow.color.opacity(tide * (0.20 + 0.28 * shimmer))),
                            lineWidth: 2.0
                        )
                    }
                }
                // Sun-glint rows fade out with the sun and return as a silver
                // moonglade under the risen moon.
                let sunX: Double = width * 0.40
                let silver: RGB = P.blossom.lerp(P.twilight, 0.18)
                let glint: RGB = P.blossom.lerp(P.torch, 0.5).lerp(silver, glade)
                let source: Double = min(1, (1 - night) + glade)
                for row in 0..<7 {
                    let fr: Double = Double(row)
                    let gy: Double = 8 + fr * 10
                    let shimmer: Double = 0.5 + 0.5 * sin(t * 1.9 + fr * 1.35)
                    let wobble: Double = 8 * sin(t * 0.7 + fr)
                    let gw: Double = 42 - fr * 3 + wobble
                    let sway: Double = 10 * sin(t * 0.4 + fr * 2.2)
                    let gx: Double = sunX - gw / 2 + sway
                    let rect = CGRect(x: gx, y: gy, width: gw, height: 3.4)
                    let alpha: Double = shimmer * 0.9 * (1 - fr / 8) * source
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.6), with: .color(glint.color.opacity(alpha)))
                }
                // GLOW TIDE: a line clear sends a bioluminescent ripple
                // across the lagoon (keyed off the cumulative clear beat).
                let age: Double = t - beatAt
                if tide > 0.6, beatAt > 0, age >= 0, age < 2.4 {
                    let u: Double = age / 2.4
                    let hb: Double = (sin(Double(beat) * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                    let cx: Double = width * (0.18 + 0.64 * hb)
                    let cy: Double = oceanH * 0.82
                    for ring in 0..<3 {
                        let fring: Double = Double(ring)
                        let rr: Double = (12 + 110 * u) * (1 + 0.35 * fring)
                        let alpha: Double = (1 - u) * (1 - u) * (0.55 - 0.13 * fring) * tide
                        let rect = CGRect(x: cx - rr, y: cy - rr * 0.30, width: rr * 2, height: rr * 0.60)
                        ctx.stroke(
                            Path(ellipseIn: rect),
                            with: .color(P.bioGlow.color.opacity(alpha)),
                            lineWidth: 2.4 - 0.5 * fring
                        )
                    }
                }
            }
            .frame(width: w, height: deckTopY - horizonY)
            .position(x: w / 2, y: (horizonY + deckTopY) / 2)
        }
    }

    // MARK: foreground

    private var deck: some View {
        ZStack {
            Rectangle()
                .fill(P.ink.color)
                .frame(width: w, height: 5)
                .position(x: w / 2, y: deckTopY + 2.5)
            band(deckTopY + 5, h, P.driftwood.lerp(P.shadowBrown, dusk).mix(P.woodDark, 0.35 * ramp(2)))
            Canvas { ctx, sz in
                let plankW: Double = Double(sz.width) / 10
                for i in 0..<10 where i % 2 == 1 {
                    let rect = CGRect(x: plankW * Double(i), y: 0, width: plankW, height: Double(sz.height))
                    ctx.fill(Path(rect), with: .color(P.ink.color.opacity(0.06)))
                }
                let plank: Color = P.plank.mix(P.woodDark, dusk)
                for i in 1..<10 {
                    let x: Double = Double(sz.width) * Double(i) / 10
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: Double(sz.height)))
                    ctx.stroke(path, with: .color(plank), lineWidth: 1.5)
                }
            }
            .frame(width: w, height: h - deckTopY - 5)
            .position(x: w / 2, y: (deckTopY + 5 + h) / 2)
        }
    }

    private var palms: some View {
        ZStack {
            PalmView(t: t, dusk: dusk, phase: 0)
                .frame(width: w * 0.55, height: h * 0.60)
                .position(x: w * 0.16, y: h * 0.55)
            PalmView(t: t, dusk: dusk, phase: 2.4)
                .frame(width: w * 0.48, height: h * 0.52)
                .scaleEffect(x: -1, y: 1)
                .position(x: w * 0.87, y: h * 0.60)
        }
    }

    private var torches: some View {
        // Deck torches flare at DUSK.
        let flareBoost: Double = 0.6 * ramp(1)
        return ZStack {
            TorchView(t: t, dusk: dusk, phase: 0, boost: flareBoost)
                .frame(width: 30, height: h * 0.13)
                .position(x: w * 0.27, y: deckTopY - h * 0.050)
            TorchView(t: t, dusk: dusk, phase: 3.1, boost: flareBoost)
                .frame(width: 30, height: h * 0.13)
                .position(x: w * 0.73, y: deckTopY - h * 0.044)
        }
    }

    /// GLOW TIDE's permanent mark (tier ≥ 1): a lantern strand slung between
    /// the deck torches, adapted from the Luau strand — the deck remembers
    /// you've seen night.
    @ViewBuilder
    private var deckStrand: some View {
        if tier >= 1 {
            let x0: CGFloat = w * 0.27
            let x1: CGFloat = w * 0.73
            let yTop: CGFloat = deckTopY - h * 0.026
            let sag: CGFloat = h * 0.026
            Canvas { ctx, _ in
                var path = Path()
                path.move(to: CGPoint(x: x0, y: yTop))
                path.addQuadCurve(
                    to: CGPoint(x: x1, y: yTop),
                    control: CGPoint(x: (x0 + x1) / 2, y: yTop + sag * 2)
                )
                ctx.stroke(path, with: .color(P.cream.color.opacity(0.35)), lineWidth: 1.5)
            }
            .allowsHitTesting(false)
            ForEach(0..<3, id: \.self) { i in
                let u: CGFloat = [0.30, 0.50, 0.70][i]
                let mu: CGFloat = 1 - u
                let hx: CGFloat = mu * mu * x0 + 2 * u * mu * (x0 + x1) / 2 + u * u * x1
                let hy: CGFloat = yTop + 2 * u * mu * sag * 2
                let tint: RGB = [P.coral, P.torch, P.cream][i]
                let lh: CGFloat = w * 0.055
                DeckLantern(tint: tint, t: t, phase: Double(i) * 1.4)
                    .frame(width: w * 0.034, height: lh)
                    .rotationEffect(.degrees(5.5 * sin(t * 0.7 + Double(i) * 1.15)), anchor: .top)
                    .position(x: hx, y: hy + lh / 2)
            }
        }
    }

    private var tiki: some View {
        TikiHeadView(t: t, dusk: dusk)
            .frame(width: w * 0.17, height: h * 0.145)
            .position(x: w * 0.14, y: h * 0.975 - h * 0.0725)
    }

    private var cat: some View {
        CatView(t: t)
            .frame(width: w * 0.14, height: h * 0.095)
            .position(x: w * 0.68, y: deckTopY + h * 0.068)
    }

    private var fireflies: some View {
        Canvas { ctx, sz in
            // Group 0 always flies (the shipped six); group 1 joins at
            // NIGHTFALL (+4); group 2 doubles the swarm at GLOW TIDE.
            let night: Double = ramp(2)
            let tide: Double = ramp(4)
            let seeds: [(Double, Double, Int)] = [
                (0.10, 0.80, 0), (0.20, 0.87, 0), (0.16, 0.76, 0),
                (0.82, 0.84, 0), (0.88, 0.78, 0), (0.58, 0.905, 0),
                (0.32, 0.83, 1), (0.46, 0.78, 1), (0.72, 0.90, 1), (0.06, 0.90, 1),
                (0.26, 0.92, 2), (0.38, 0.88, 2), (0.52, 0.84, 2), (0.64, 0.80, 2),
                (0.78, 0.93, 2), (0.90, 0.87, 2), (0.12, 0.86, 2), (0.42, 0.94, 2),
                (0.60, 0.955, 2), (0.94, 0.92, 2),
            ]
            for (i, seed) in seeds.enumerated() {
                let gate: Double = seed.2 == 0 ? 1 : (seed.2 == 1 ? night : tide)
                guard gate > 0 else { continue }
                let fi: Double = Double(i)
                let x: Double = seed.0 * Double(sz.width) + 20 * sin(t * 0.31 + fi * 2.1)
                let y: Double = seed.1 * Double(sz.height) + 14 * sin(t * 0.23 + fi * 1.3)
                let glow: Double = 0.5 + 0.5 * sin(t * 0.9 + fi * 1.9)
                let alpha: Double = (0.20 + 0.60 * glow) * (0.35 + 0.65 * dusk) * gate
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: 5, height: 5)),
                    with: .color(P.torch.color.opacity(alpha))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// Mini paper lantern for the earned deck strand — the Luau lantern's drawing
/// scaled down to a deck prop.
private struct DeckLantern: View {
    let tint: RGB
    let t: Double
    let phase: Double

    var body: some View {
        GeometryReader { geo in
            let lw = geo.size.width
            let lh = geo.size.height
            let glow: Color = tint.lerp(P.blossom, 0.45).color
            ZStack {
                Circle()
                    .fill(glow.opacity(0.13 + 0.04 * sin(t * 1.1 + phase)))
                    .frame(width: lw * 2.4, height: lw * 2.4)
                    .position(x: lw / 2, y: lh * 0.62)
                Rectangle()
                    .fill(P.cream.color.opacity(0.5))
                    .frame(width: 1.2, height: lh * 0.30)
                    .position(x: lw / 2, y: lh * 0.15)
                RoundedRectangle(cornerRadius: lw * 0.28)
                    .fill(tint.color)
                    .frame(width: lw * 0.80, height: lh * 0.56)
                    .position(x: lw / 2, y: lh * 0.60)
                Rectangle()
                    .fill(P.woodDark.color)
                    .frame(width: lw * 0.36, height: lh * 0.05)
                    .position(x: lw / 2, y: lh * 0.30)
                Rectangle()
                    .fill(P.woodDark.color)
                    .frame(width: lw * 0.36, height: lh * 0.05)
                    .position(x: lw / 2, y: lh * 0.90)
            }
        }
    }
}

/// Carved tiki head with brows, glowing eyes, nose, and toothy mouth,
/// drawn in a 100x140 design box.
struct TikiHeadView: View {
    let t: Double
    let dusk: Double

    var body: some View {
        let eyeGlow: Double = 0.40 + 0.60 * dusk * (0.6 + 0.4 * sin(t * 1.1))
        return Canvas { ctx, sz in
            let sx: Double = Double(sz.width) / 100
            let sy: Double = Double(sz.height) / 140
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
                CGRect(x: x * sx, y: y * sy, width: w * sx, height: h * sy)
            }
            func poly(_ pts: [(Double, Double)]) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: pts[0].0 * sx, y: pts[0].1 * sy))
                for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0 * sx, y: q.1 * sy)) }
                p.closeSubpath()
                return p
            }

            ctx.fill(Path(roundedRect: rect(4, 0, 92, 140), cornerRadius: 6 * sx), with: .color(P.woodDark.color))
            ctx.fill(Path(roundedRect: rect(4, 0, 92, 18), cornerRadius: 6 * sx), with: .color(P.ink.color.opacity(0.45)))
            ctx.fill(poly([(12, 28), (46, 28), (29, 44)]), with: .color(P.torch.color))
            ctx.fill(poly([(54, 28), (88, 28), (71, 44)]), with: .color(P.torch.color))
            ctx.fill(Path(rect(16, 50, 26, 16)), with: .color(P.torch.color.opacity(eyeGlow)))
            ctx.fill(Path(rect(58, 50, 26, 16)), with: .color(P.torch.color.opacity(eyeGlow)))
            ctx.fill(Path(rect(24, 54, 8, 8)), with: .color(P.ink.color))
            ctx.fill(Path(rect(66, 54, 8, 8)), with: .color(P.ink.color))
            ctx.fill(poly([(50, 66), (64, 96), (36, 96)]), with: .color(P.ink.color))
            ctx.fill(Path(rect(14, 104, 72, 18)), with: .color(P.ink.color))
            for i in 0..<4 {
                ctx.fill(Path(rect(18 + Double(i) * 16, 106, 10, 7)), with: .color(P.cream.color))
            }
            for i in 0..<3 {
                ctx.fill(Path(rect(26 + Double(i) * 16, 113, 10, 7)), with: .color(P.cream.color))
            }
            for y in [128.0, 134.0] {
                var g = Path()
                g.move(to: CGPoint(x: 8 * sx, y: y * sy))
                g.addLine(to: CGPoint(x: 92 * sx, y: y * sy))
                ctx.stroke(g, with: .color(P.ink.color), lineWidth: 2)
            }
        }
    }
}

#Preview {
    TikiBackgroundView()
}
