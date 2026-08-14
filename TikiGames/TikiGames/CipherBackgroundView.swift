import SwiftUI

/// Palm Springs poolside backdrop (Cabana Cipher) — the only full-daylight
/// scene. A bright afternoon breathes toward golden hour and back on a
/// 90-second cycle. All motion derives from one TimelineView clock; shared
/// palette and components live in TikiScenery.swift.
struct CipherBackgroundView: View {
    var phase: ProgressPhase = ProgressPhase()   // default = today's behavior exactly
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dial = DepthDial()
    @State private var beatAt: TimeInterval = 0
    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                // Under reduceMotion the paused clock freezes eased() at its
                // launch value (depth 0) — render the true depth statically.
                CipherScene(
                    t: t, size: geo.size,
                    depth: reduceMotion ? phase.depth : dial.eased(at: t),
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
        .onChange(of: phase.beat) { _, _ in
            beatAt = Date().timeIntervalSinceReferenceDate
        }
    }
}

private struct CipherScene: View {
    let t: Double
    let size: CGSize
    let depth: Double
    let tier: Int        // persistent mark: pennants, one per completed matchbook
    let beat: Int        // cumulative letter-lock counter
    let beatAt: Double   // wall-clock moment of the latest lock

    /// 0 = bright afternoon, 1 = golden hour. Slow 90 s breath; solve depth
    /// lifts the floor (full swing at depth 0 — the shipped scene exactly).
    var golden: Double {
        let breath = (1 - cos(t * 2 * .pi / 90)) / 2
        return depth * 0.7 + breath * (1 - depth * 0.7)
    }

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var poolTopY: CGFloat { h * 0.50 }
    var poolBottomY: CGFloat { h * 0.86 }
    var deckTopY: CGFloat { h * 0.885 }

    /// The water breathes from afternoon lagoon toward evening deepLeaf.
    var poolColor: Color { P.lagoon.mix(P.deepLeaf, golden * 0.5) }

    var body: some View {
        ZStack {
            sky
            sun
            bird
            mountains
            farDeck
            if tier > 0 {
                pennants
            }
            farPalms
            palm
            pool
            divingBoard
            poolLadder
            ring
            deck
            wetFootprints
            cocktail
            cabana
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
        ZStack {
            band(0, h * 0.14, P.blossom.lerp(P.coral, 0.20).mix(P.sunsetMid, golden * 0.30 + depth * 0.14))
            band(h * 0.14, h * 0.26, P.blossom.lerp(P.torch, 0.55).mix(P.sunsetMid, golden * 0.45 + depth * 0.18))
            band(h * 0.26, h * 0.40, P.torch.mix(P.sunsetMid, golden * 0.65 + depth * 0.22))
        }
    }

    /// Golden-hour peak rides `depth` (not the breath) so a near-complete
    /// solve sinks the sun toward the ridge — depth 0 stays the shipped sun.
    private var sun: some View {
        let sunX: CGFloat = w * 0.64
        let sunY: CGFloat = h * 0.105 + CGFloat(golden) * h * 0.035 + CGFloat(depth) * h * 0.055
        let r: CGFloat = w * 0.115
        let pulse: Double = 1 + 0.014 * sin(t * 0.32)
        let disc: Color = P.blossom.lerp(P.torch, 0.30 + golden * 0.5).mix(P.sunsetMid, depth * 0.45)
        return ZStack {
            Circle()
                .fill(disc.opacity(0.20))
                .frame(width: r * 2.9, height: r * 2.9)
                .scaleEffect(CGFloat(pulse))
            Circle()
                .fill(disc.opacity(0.30))
                .frame(width: r * 2.3, height: r * 2.3)
                .scaleEffect(CGFloat(pulse))
            Circle()
                .fill(disc)
                .frame(width: r * 2, height: r * 2)
        }
        .position(x: sunX, y: sunY)
    }

    /// A lone chevron bird crosses the sky every 20 s, wings beating fast.
    private var bird: some View {
        let progress: Double = (t / 20).truncatingRemainder(dividingBy: 1)
        let bx: CGFloat = CGFloat(progress) * (w + 60) - 30
        let by: CGFloat = h * 0.155 - CGFloat(sin(progress * .pi)) * h * 0.035
        let flap: Double = sin(t * 9)
        return Canvas { ctx, sz in
            let cw: Double = Double(sz.width)
            let ch: Double = Double(sz.height)
            let midX: Double = cw / 2
            let midY: Double = ch * 0.62
            let tipY: Double = midY - ch * 0.45 * flap
            var v = Path()
            v.move(to: CGPoint(x: midX - cw * 0.46, y: tipY))
            v.addQuadCurve(to: CGPoint(x: midX, y: midY), control: CGPoint(x: midX - cw * 0.18, y: midY))
            v.addQuadCurve(to: CGPoint(x: midX + cw * 0.46, y: tipY), control: CGPoint(x: midX + cw * 0.18, y: midY))
            ctx.stroke(v, with: .color(P.ink.color.opacity(0.85)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
        .frame(width: 26, height: 14)
        .position(x: bx, y: by)
    }

    // MARK: midground

    /// Two overlapping San Jacinto-style ridge lines behind everything.
    private var mountains: some View {
        let back: Color = P.clay.lerp(P.torch, 0.45).mix(P.sunsetMid, golden * 0.35)
        let front: Color = P.driftwood.lerp(P.clay, 0.50).mix(P.rum, golden * 0.35)
        return Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            func ridge(_ pts: [(Double, Double)]) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: pts[0].0 * width, y: pts[0].1 * height))
                for q in pts.dropFirst() {
                    p.addLine(to: CGPoint(x: q.0 * width, y: q.1 * height))
                }
                p.addLine(to: CGPoint(x: width, y: height))
                p.addLine(to: CGPoint(x: 0, y: height))
                p.closeSubpath()
                return p
            }
            let backPts: [(Double, Double)] = [
                (0.00, 0.40), (0.10, 0.08), (0.20, 0.30), (0.33, 0.02),
                (0.46, 0.34), (0.58, 0.10), (0.72, 0.42), (0.86, 0.16), (1.00, 0.36),
            ]
            let frontPts: [(Double, Double)] = [
                (0.00, 0.75), (0.12, 0.46), (0.25, 0.68), (0.40, 0.34),
                (0.53, 0.64), (0.68, 0.40), (0.82, 0.72), (1.00, 0.50),
            ]
            ctx.fill(ridge(backPts), with: .color(back))
            ctx.fill(ridge(frontPts), with: .color(front))
        }
        .frame(width: w, height: h * 0.18)
        .position(x: w / 2, y: h * 0.31)
    }

    /// Pale far-side deck plus the cream coping line along the pool's top edge.
    private var farDeck: some View {
        ZStack {
            band(h * 0.40, h * 0.488, P.cream.lerp(P.torch, 0.30).mix(P.sunsetMid, golden * 0.25))
            band(h * 0.488, poolTopY, P.blossom.lerp(P.cream, 0.35).mix(P.torch, golden * 0.20))
        }
    }

    /// Earned pennant string across the far deck — one triangle per
    /// completed matchbook (16 caps the wall), permanent once hung.
    private var pennants: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let endY: Double = height * 0.10
            let sagY: Double = height * 0.52
            func hang(_ u: Double) -> CGPoint {
                let mu: Double = 1 - u
                let y: Double = mu * mu * endY + 2 * u * mu * sagY + u * u * endY
                return CGPoint(x: u * width, y: y)
            }
            var string = Path()
            string.move(to: hang(0))
            for k in 1...32 { string.addLine(to: hang(Double(k) / 32)) }
            ctx.stroke(string, with: .color(P.ink.color.opacity(0.38)), lineWidth: 1.3)
            let tints: [RGB] = [P.coral, P.lagoon, P.torch, P.palmLeaf, P.clay, P.sunsetMid]
            for i in 0..<min(16, tier) {
                let fi: Double = Double(i)
                let p: CGPoint = hang((fi + 0.5) / 16)
                let fw: Double = width * 0.027
                let fh: Double = height * 0.58
                let sway: Double = 1.6 * sin(t * 0.6 + fi * 1.3)
                var tri = Path()
                tri.move(to: CGPoint(x: p.x - fw / 2, y: p.y + 0.5))
                tri.addLine(to: CGPoint(x: p.x + fw / 2, y: p.y + 0.5))
                tri.addLine(to: CGPoint(x: p.x + sway, y: p.y + fh))
                tri.closeSubpath()
                ctx.fill(tri, with: .color(tints[i % 6].mix(P.sunsetMid, golden * 0.15)))
            }
        }
        .frame(width: w, height: h * 0.045)
        .position(x: w / 2, y: h * 0.4255)
    }

    private var farPalms: some View {
        let tint: Color = P.palmLeaf.mix(P.deepLeaf, 0.3 + golden * 0.3)
        return ZStack {
            TinyPalm()
                .stroke(tint, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .frame(width: w * 0.085, height: h * 0.045)
                .position(x: w * 0.075, y: h * 0.4655)
            TinyPalm()
                .stroke(tint, style: StrokeStyle(lineWidth: 2.0, lineCap: .round))
                .frame(width: w * 0.065, height: h * 0.034)
                .position(x: w * 0.128, y: h * 0.471)
        }
    }

    /// Big palm leaning in from the top-left corner, swaying on its own beat.
    private var palm: some View {
        PalmView(t: t, dusk: golden * 0.4, phase: 1.2)
            .frame(width: w * 0.30, height: h * 0.30)
            .position(x: w * 0.055, y: h * 0.35)
    }

    // MARK: pool

    private var pool: some View {
        ZStack {
            band(poolTopY, poolBottomY, poolColor)
            poolCanvas
        }
    }

    private var poolCanvas: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let poolH: Double = Double(sz.height)

            // Caustic shimmer: rows of short wavy cream dashes, dimmed through
            // the middle rows so the board zone stays calm.
            for row in 0..<7 {
                let fr: Double = Double(row)
                let y: Double = poolH * (0.09 + 0.13 * fr)
                let centerDim: Double = (row >= 2 && row <= 4) ? 0.6 : 1.0
                let breathe: Double = 0.75 + 0.25 * sin(t * 0.8 + fr * 2.3)
                let alpha: Double = 0.14 * centerDim * breathe
                let phaseDrift: Double = 14 * sin(t * 0.55 + fr * 1.9)
                var x: Double = -60 + phaseDrift + fr * 17
                while x < width + 30 {
                    let segLen: Double = 26 + 8 * sin(fr * 3.7 + x * 0.05)
                    let wobble: Double = 2.2 * sin(x * 0.16 + t * 0.9 + fr)
                    let y0: Double = y + wobble
                    var dash = Path()
                    dash.move(to: CGPoint(x: x, y: y0))
                    dash.addQuadCurve(
                        to: CGPoint(x: x + segLen, y: y0),
                        control: CGPoint(x: x + segLen / 2, y: y0 - 3.5)
                    )
                    ctx.stroke(dash, with: .color(P.cream.color.opacity(alpha)), lineWidth: 1.7)
                    x += segLen + 34
                }
            }

            // Sun sparkles hugging the pool's left and right edges — a fast
            // twinkle with a high-frequency glint riding on top.
            let seeds: [(Double, Double)] = [
                (0.045, 0.16), (0.090, 0.42), (0.050, 0.68), (0.115, 0.88),
                (0.930, 0.20), (0.955, 0.50), (0.900, 0.74), (0.965, 0.90),
            ]
            for (i, seed) in seeds.enumerated() {
                let fi: Double = Double(i)
                let twinkle: Double = 0.5 + 0.5 * sin(t * 6 + fi * 2.7)
                let flick: Double = 0.5 + 0.5 * sin(t * 48 + fi * 5.1)
                let alpha: Double = (0.10 + 0.45 * twinkle) * (0.55 + 0.45 * flick)
                let r: Double = i % 3 == 0 ? 2.6 : 1.8
                let px: Double = seed.0 * width
                let py: Double = seed.1 * poolH
                let rect = CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(P.blossom.color.opacity(alpha)))
            }

            // Lock flourish: each locked letter drops one ripple somewhere
            // in the open water (position hashed off the cumulative beat).
            let age: Double = t - beatAt
            if beatAt > 0, age >= 0, age < 1.4 {
                let u: Double = age / 1.4
                let hb: Double = (sin(Double(beat) * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                let hb2: Double = (hb * 7.31).truncatingRemainder(dividingBy: 1)
                let cx: Double = width * (0.22 + 0.56 * hb)
                let cy: Double = poolH * (0.28 + 0.44 * hb2)
                let rw: Double = 10 + 44 * u
                let alpha: Double = 0.45 * (1 - u)
                let rect = CGRect(x: cx - rw / 2, y: cy - rw * 0.15, width: rw, height: rw * 0.30)
                ctx.stroke(Path(ellipseIn: rect), with: .color(P.blossom.color.opacity(alpha)), lineWidth: 1.8)
            }

            // Rings spreading under the diving board tip — someone just dove
            // in, but the pool is empty.
            for k in 0..<2 {
                let fk: Double = Double(k)
                let phase: Double = ((t + fk * 4) / 8).truncatingRemainder(dividingBy: 1)
                let rw: Double = 8 + 40 * phase
                let rh: Double = rw * 0.30
                let alpha: Double = 0.28 * (1 - phase)
                let cx: Double = width * 0.095
                let cy: Double = poolH * 0.10
                let rect = CGRect(x: cx - rw / 2, y: cy - rh / 2, width: rw, height: rh)
                ctx.stroke(Path(ellipseIn: rect), with: .color(P.cream.color.opacity(alpha)), lineWidth: 1.5)
            }
        }
        .frame(width: w, height: poolBottomY - poolTopY)
        .position(x: w / 2, y: (poolTopY + poolBottomY) / 2)
    }

    private var divingBoard: some View {
        let boardY: CGFloat = h * 0.507
        let boardLen: CGFloat = w * 0.135
        let boardTh: CGFloat = h * 0.013
        return ZStack {
            Rectangle()
                .fill(P.woodDark.color)
                .frame(width: w * 0.020, height: h * 0.055)
                .position(x: w * 0.045, y: h * 0.535)
            Rectangle()
                .fill(P.blossom.lerp(P.cream, 0.4).mix(P.torch, golden * 0.15))
                .frame(width: boardLen, height: boardTh)
                .position(x: boardLen / 2, y: boardY)
            Rectangle()
                .fill(P.ink.color.opacity(0.30))
                .frame(width: boardLen, height: 2)
                .position(x: boardLen / 2, y: boardY + boardTh / 2 + 1)
        }
    }

    /// Coral inflatable donut drifting the length of the pool — the scene's
    /// glacial layer (~175 s per crossing) — with a gentle bob and rock.
    private var ring: some View {
        let ringD: CGFloat = w * 0.10
        let span: Double = Double(w) + Double(ringD) * 2
        let drift: Double = (t * span / 175).truncatingRemainder(dividingBy: span)
        let rx: CGFloat = CGFloat(drift) - ringD
        let ry: CGFloat = h * 0.805 + CGFloat(2.6 * sin(t * 0.5))
        return ZStack {
            Circle()
                .fill(P.coral.mix(P.clay, golden * 0.25))
                .frame(width: ringD, height: ringD)
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(P.blossom.color.opacity(0.9))
                    .frame(width: ringD * 0.10, height: ringD * 0.24)
                    .offset(y: -ringD * 0.365)
                    .rotationEffect(.degrees(Double(i) * 90 + 45))
            }
            Circle()
                .fill(poolColor)
                .frame(width: ringD * 0.46, height: ringD * 0.46)
        }
        .rotationEffect(.degrees(4 * sin(t * 0.23)))
        .position(x: rx, y: ry)
    }

    // MARK: foreground

    private var deck: some View {
        ZStack {
            Rectangle()
                .fill(P.ink.color.opacity(0.35))
                .frame(width: w, height: 2)
                .position(x: w / 2, y: poolBottomY + 1)
            band(poolBottomY + 2, deckTopY, P.blossom.lerp(P.cream, 0.45).mix(P.torch, golden * 0.18))
            band(deckTopY, h, P.cream.mix(P.torch, 0.10 + golden * 0.16))
            speckles
        }
    }

    /// Static terrazzo chips — deterministic hash scatter, never animated.
    private var speckles: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let chips: [Color] = [
                P.clay.color.opacity(0.32),
                P.lagoon.color.opacity(0.28),
                P.driftwood.color.opacity(0.30),
                P.torch.color.opacity(0.38),
            ]
            for i in 0..<64 {
                let fi: Double = Double(i)
                let px: Double = (sin(fi * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                let py: Double = (sin(fi * 78.2330) * 96321.5687).truncatingRemainder(dividingBy: 1).magnitude
                let rr: Double = (sin(fi * 39.4250) * 14375.3400).truncatingRemainder(dividingBy: 1).magnitude
                let r: Double = 1.2 + 1.6 * rr
                let rect = CGRect(x: px * width, y: py * height, width: r * 2, height: r * 1.4)
                ctx.fill(Path(ellipseIn: rect), with: .color(chips[i % 4]))
            }
        }
        .frame(width: w, height: h - deckTopY)
        .position(x: w / 2, y: (deckTopY + h) / 2)
    }

    /// Chrome pool ladder at the left edge, descending into the water.
    private var poolLadder: some View {
        let railW: CGFloat = w * 0.008
        let railTop: CGFloat = h * 0.488
        let railBottom: CGFloat = h * 0.60
        let rail: Color = P.blossom.lerp(P.cream, 0.4).color
        return ZStack {
            Capsule()
                .fill(rail)
                .frame(width: railW, height: railBottom - railTop)
                .position(x: w * 0.055, y: (railTop + railBottom) / 2)
            Capsule()
                .fill(rail)
                .frame(width: railW, height: railBottom - railTop)
                .position(x: w * 0.088, y: (railTop + railBottom) / 2)
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(rail)
                    .frame(width: w * 0.033, height: railW)
                    .position(x: w * 0.0715, y: h * (0.525 + 0.026 * CGFloat(i)))
            }
        }
    }

    /// Wet footprints from the pool edge toward the cabana — whoever made the
    /// ripples under the diving board dried off here. The cat took their chair.
    private var wetFootprints: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let tint: Color = P.lagoon.color.opacity(0.22)
            let steps: [(Double, Double, Double)] = [
                (0.46, 0.18, -14), (0.51, 0.30, -10),
                (0.56, 0.22, -6), (0.62, 0.35, -2),
                (0.68, 0.28, 4), (0.74, 0.42, 8),
            ]
            for s in steps {
                let fx: Double = s.0 * width
                let fy: Double = s.1 * height
                let fw: Double = width * 0.016
                let fh: Double = fw * 2.1
                var foot = Path(ellipseIn: CGRect(x: -fw / 2, y: -fh / 2, width: fw, height: fh))
                let rot = CGAffineTransform(translationX: fx, y: fy)
                    .rotated(by: s.2 * .pi / 180)
                foot = foot.applying(rot)
                ctx.fill(foot, with: .color(tint))
            }
        }
        .frame(width: w, height: h - deckTopY)
        .position(x: w / 2, y: (deckTopY + h) / 2)
        .allowsHitTesting(false)
    }

    /// Someone's yellow cocktail sweats near the pool edge. The cat is unbothered.
    private var cocktail: some View {
        let gw: CGFloat = w * 0.045
        let gh: CGFloat = h * 0.050
        return ZStack {
            Ellipse()
                .fill(P.ink.color.opacity(0.10))
                .frame(width: gw * 1.5, height: gh * 0.18)
                .offset(y: gh * 0.52)
            Rectangle()
                .fill(P.coral.color)
                .frame(width: gw * 0.10, height: gh * 0.95)
                .rotationEffect(.degrees(20))
                .offset(x: gw * 0.22, y: -gh * 0.60)
            MugShape()
                .fill(P.torch.mix(P.sunsetMid, golden * 0.2))
                .frame(width: gw, height: gh)
            Rectangle()
                .fill(P.blossom.color.opacity(0.45))
                .frame(width: gw * 0.13, height: gh * 0.66)
                .offset(x: -gw * 0.20)
        }
        .position(x: w * 0.185, y: h * 0.942)
    }

    // MARK: cabana

    private var cabana: some View {
        ZStack {
            cabanaShade
            cabanaPoles
            butterflyChair
            cat
            canopy
            curtain
        }
    }

    private var cabanaShade: some View {
        Canvas { ctx, sz in
            let cw: Double = Double(sz.width)
            let ch: Double = Double(sz.height)
            var p = Path()
            p.move(to: CGPoint(x: cw * 0.22, y: 0))
            p.addLine(to: CGPoint(x: cw, y: 0))
            p.addLine(to: CGPoint(x: cw * 0.78, y: ch))
            p.addLine(to: CGPoint(x: 0, y: ch))
            p.closeSubpath()
            ctx.fill(p, with: .color(P.ink.color.opacity(0.10)))
        }
        .frame(width: w * 0.20, height: h * 0.07)
        .position(x: w * 0.865, y: h * 0.935)
    }

    private var cabanaPoles: some View {
        let poleTop: CGFloat = h * 0.615
        let poleBottom: CGFloat = h * 0.955
        let poleW: CGFloat = max(w * 0.008, 3)
        return ZStack {
            Rectangle()
                .fill(P.woodDark.color)
                .frame(width: poleW, height: poleBottom - poleTop)
                .position(x: w * 0.808, y: (poleTop + poleBottom) / 2)
            Rectangle()
                .fill(P.woodDark.color)
                .frame(width: poleW, height: poleBottom - poleTop)
                .position(x: w * 0.938, y: (poleTop + poleBottom) / 2)
        }
    }

    /// Slanted cream-and-coral striped awning with a zigzag valance.
    private var canopy: some View {
        let coralStripe: Color = P.coral.mix(P.clay, golden * 0.30)
        let creamStripe: Color = P.cream.mix(P.torch, golden * 0.20)
        return Canvas { ctx, sz in
            let cw: Double = Double(sz.width)
            let ch: Double = Double(sz.height)
            var awning = Path()
            awning.move(to: CGPoint(x: 0, y: ch * 0.30))
            awning.addLine(to: CGPoint(x: cw, y: 0))
            awning.addLine(to: CGPoint(x: cw, y: ch * 0.68))
            let teeth: Int = 6
            let toothW: Double = cw / Double(teeth)
            for i in stride(from: teeth - 1, through: 0, by: -1) {
                let fi: Double = Double(i)
                let xRight: Double = toothW * (fi + 1)
                let xMid: Double = toothW * (fi + 0.5)
                let xLeft: Double = toothW * fi
                awning.addLine(to: CGPoint(x: xRight, y: ch * 0.68))
                awning.addLine(to: CGPoint(x: xMid, y: ch))
                awning.addLine(to: CGPoint(x: xLeft, y: ch * 0.68))
            }
            awning.closeSubpath()
            ctx.clip(to: awning)
            let stripes: Int = 6
            let sw: Double = cw / Double(stripes)
            for i in 0..<stripes {
                let fi: Double = Double(i)
                let c: Color = i % 2 == 0 ? creamStripe : coralStripe
                let rect = CGRect(x: sw * fi, y: 0, width: sw, height: ch)
                ctx.fill(Path(rect), with: .color(c))
            }
        }
        .frame(width: w * 0.19, height: h * 0.09)
        .position(x: w * 0.8825, y: h * 0.615)
    }

    /// Sheer cabana curtain swaying on a lazy 16 s rhythm.
    private var curtain: some View {
        let sway: Double = 2.2 * sin(t * 0.38) + 0.7 * sin(t * 0.90)
        return Rectangle()
            .fill(P.cream.lerp(P.torch, 0.25).mix(P.sunsetMid, golden * 0.20))
            .frame(width: w * 0.024, height: h * 0.22)
            .rotationEffect(.degrees(sway), anchor: .top)
            .position(x: w * 0.812, y: h * 0.765)
    }

    private var butterflyChair: some View {
        Canvas { ctx, sz in
            let cw: Double = Double(sz.width)
            let ch: Double = Double(sz.height)
            var sling = Path()
            sling.move(to: CGPoint(x: cw * 0.04, y: 0))
            sling.addLine(to: CGPoint(x: cw * 0.22, y: ch * 0.10))
            sling.addQuadCurve(
                to: CGPoint(x: cw * 0.78, y: ch * 0.10),
                control: CGPoint(x: cw * 0.50, y: ch * 0.72)
            )
            sling.addLine(to: CGPoint(x: cw * 0.96, y: 0))
            sling.addLine(to: CGPoint(x: cw * 0.99, y: ch * 0.08))
            sling.addQuadCurve(
                to: CGPoint(x: cw * 0.50, y: ch * 0.68),
                control: CGPoint(x: cw * 0.84, y: ch * 0.54)
            )
            sling.addQuadCurve(
                to: CGPoint(x: cw * 0.01, y: ch * 0.08),
                control: CGPoint(x: cw * 0.16, y: ch * 0.54)
            )
            sling.closeSubpath()
            // Canvas, not ink. The cat is solid P.ink but for its eyes, so an
            // ink sling gave it nothing to sit against — the two silhouettes
            // merged into one unreadable shape. Cipher hid this behind the
            // translucent letter-tile layer washing over the cabana; Luau has
            // no such wash in that corner and it read as a blob.
            ctx.fill(sling, with: .color(P.coral.mix(P.cream, 0.18)))
            var legs = Path()
            legs.move(to: CGPoint(x: cw * 0.18, y: ch * 0.44))
            legs.addLine(to: CGPoint(x: cw * 0.80, y: ch))
            legs.move(to: CGPoint(x: cw * 0.82, y: ch * 0.44))
            legs.addLine(to: CGPoint(x: cw * 0.20, y: ch))
            ctx.stroke(legs, with: .color(P.ink.color), style: StrokeStyle(lineWidth: cw * 0.05, lineCap: .round))
        }
        .frame(width: w * 0.085, height: h * 0.062)
        .position(x: w * 0.888, y: h * 0.90)
    }

    /// The suspicious cat has claimed the only chair, deep in the cabana shade.
    private var cat: some View {
        CatView(t: t)
            .frame(width: w * 0.062, height: h * 0.046)
            .scaleEffect(x: -1, y: 1)
            .position(x: w * 0.888, y: h * 0.872)
    }
}

#Preview {
    CipherBackgroundView()
}
