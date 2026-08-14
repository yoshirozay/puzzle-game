import SwiftUI

/// Deep-night volcanic cove backdrop (Blueprints — nonogram). The darkest and
/// calmest of the five scenes: a giant cream moon over still water, star
/// clusters joined into little pixel-pictures (a nod to nonogram reveals),
/// and a volcano breathing embers on the right. All motion derives from one
/// TimelineView clock; the sky breathes on a 90-second moon-glow cycle.
/// Shared components live in TikiScenery.swift.
struct BlueprintsBackgroundView: View {
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
                BlueprintsScene(
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

private struct BlueprintsScene: View {
    let t: Double
    let size: CGSize
    let depth: Double
    let tier: Int        // persistent mark: 1 + solved/3 constellation ladder (0 = legacy caller: the shipped four)
    let beat: Int        // cumulative first-solve counter
    let beatAt: Double   // wall-clock moment of the latest solve

    /// 0 = brighter twilight-night, 1 = deepest night. Slow 90 s moon-glow
    /// breath; fill depth lifts the floor (full swing at depth 0 — the
    /// shipped scene exactly).
    var breath: Double {
        let wave = (1 - cos(t * 2 * .pi / 90)) / 2
        return depth * 0.7 + wave * (1 - depth * 0.7)
    }

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var horizonY: CGFloat { h * 0.64 }
    var ledgeTopY: CGFloat { h * 0.84 }
    var moonX: CGFloat { w * 0.30 }
    var moonY: CGFloat { h * 0.22 }

    var body: some View {
        ZStack {
            sky
            stars
            constellations
            shootingStar
            moon
            ocean
            headland
            volcano
            smoke
            ledge
            lantern
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
        let deep: Double = 0.13 * breath
        return ZStack {
            band(0, h * 0.16, P.twilight.lerp(P.ink, 0.67 + deep).color)
            band(h * 0.16, h * 0.32, P.twilight.lerp(P.ink, 0.59 + deep).color)
            band(h * 0.32, h * 0.48, P.twilight.lerp(P.ink, 0.51 + deep).color)
            band(h * 0.48, horizonY, P.twilight.lerp(P.deepLeaf, 0.30).lerp(P.ink, 0.44 + deep).color)
        }
    }

    /// Dense twinkling field confined above the board zone. The whole field
    /// drifts a few points on a glacial 240 s sine — the sky slowly turning.
    private var stars: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let drift: Double = 10 * sin(t * 2 * .pi / 240)
            for i in 0..<30 {
                let fi: Double = Double(i)
                let hx: Double = (sin(fi * 127.1 + 1.3) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                let hy: Double = (sin(fi * 311.7 + 4.7) * 26951.2917).truncatingRemainder(dividingBy: 1).magnitude
                let x: Double = hx * width + drift
                let y: Double = hy * height
                let twinkle: Double = 0.52 + 0.48 * sin(t * (1.1 + hx * 1.7) + fi * 2.3)
                let r: Double = i % 6 == 0 ? 2.8 : 1.7
                let alpha: Double = twinkle * 0.9
                let rect = CGRect(x: x, y: y, width: r, height: r)
                ctx.fill(Path(ellipseIn: rect), with: .color(P.cream.color.opacity(alpha)))
            }
        }
        .frame(width: w, height: h * 0.44)
        .position(x: w / 2, y: h * 0.22)
    }

    /// Star groups joined by faint cream lines into tiny geometric pictures —
    /// a square, an L, an S, a T — like nonogram puzzles solved in the sky.
    /// Each cluster brightens and dims on its own slow ~70 s phase.
    /// The collection: every three drafts permanently hangs the next picture
    /// (tier carries 1 + solved/3; ten authored groups = the 30-sheet drawer).
    /// tier 0 = legacy caller (bare previews): the shipped four exactly.
    private var constellations: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let drift: Double = 10 * sin(t * 2 * .pi / 240)
            let unit: Double = width * 0.030
            let clusters: [(Double, Double, Double, [(Double, Double)])] = [
                (0.44, 0.15, 0.0, [(0, 0), (1, 0), (1, 1), (0, 1), (0, 0)]),
                (0.90, 0.16, 2.1, [(0, 0), (0, 1), (0, 2), (1, 2)]),
                (0.07, 0.44, 4.2, [(0, 1), (1, 1), (1, 0), (2, 0)]),
                (0.49, 0.40, 1.3, [(0, 0), (2, 0), (1, 0), (1, 1)]),
                (0.14, 0.13, 3.1, [(0, 0), (1, 0), (2, 0), (3, 0)]),
                (0.66, 0.10, 5.4, [(0, 0), (1, 0), (1, 1), (2, 1)]),
                (0.30, 0.05, 1.9, [(1, 0), (1, 1), (1, 2), (0, 2)]),
                (0.55, 0.25, 4.4, [(0, 2), (0, 1), (1, 1), (1, 0), (2, 0)]),
                (0.76, 0.30, 0.8, [(0, 0), (0, 1), (1, 1), (2, 1), (2, 0)]),
                (0.68, 0.44, 2.6, [(1, 0), (2, 1), (1, 2), (0, 1), (1, 0)]),
            ]
            let hung: Int = tier == 0 ? 4 : min(clusters.count, tier - 1)
            for c in clusters.prefix(hung) {
                let ox: Double = c.0 * width + drift
                let oy: Double = c.1 * height
                let slow: Double = 0.70 + 0.30 * sin(t * 2 * .pi / 70 + c.2)
                var line = Path()
                for (j, g) in c.3.enumerated() {
                    let px: Double = ox + g.0 * unit
                    let py: Double = oy + g.1 * unit
                    if j == 0 { line.move(to: CGPoint(x: px, y: py)) }
                    else { line.addLine(to: CGPoint(x: px, y: py)) }
                }
                ctx.stroke(line, with: .color(P.cream.color.opacity(0.15 * slow)), lineWidth: 1)
                for (j, g) in c.3.enumerated() {
                    let fj: Double = Double(j)
                    let px: Double = ox + g.0 * unit
                    let py: Double = oy + g.1 * unit
                    let glow: Double = 0.55 + 0.30 * sin(t * 1.4 + c.2 + fj * 1.9)
                    let rect = CGRect(x: px - 1.7, y: py - 1.7, width: 3.4, height: 3.4)
                    ctx.fill(Path(ellipseIn: rect), with: .color(P.cream.color.opacity(glow * slow)))
                }
            }
        }
        .frame(width: w, height: horizonY)
        .position(x: w / 2, y: horizonY / 2)
    }

    /// Every 12 s a brief cream streak crosses part of the upper sky. Start
    /// point and heading are hashed from the cycle index, so each pass takes
    /// a different line — no randomness APIs, fully deterministic. A solve
    /// beat fires one grander streak of the same species, keyed off beatAt.
    private var shootingStar: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            func streak(_ u: Double, _ h1: Double, _ h2: Double, len: Double, gain: Double, head: Color) {
                let startX: Double = width * (0.14 + 0.62 * h1)
                let startY: Double = height * (0.10 + 0.42 * h2)
                let steep: Double = 0.34 + 0.22 * h1
                let side: Double = h2 < 0.5 ? 1.0 : -1.0
                let dirX: Double = side * cos(steep)
                let dirY: Double = sin(steep)
                let headX: Double = startX + dirX * len * u
                let headY: Double = startY + dirY * len * u
                let fade: Double = sin(.pi * u)
                let tail: Double = len * 0.34 * fade
                for s in 0..<3 {
                    let fs: Double = Double(s)
                    let aX: Double = headX - dirX * tail * fs / 3
                    let aY: Double = headY - dirY * tail * fs / 3
                    let bX: Double = headX - dirX * tail * (fs + 1) / 3
                    let bY: Double = headY - dirY * tail * (fs + 1) / 3
                    var seg = Path()
                    seg.move(to: CGPoint(x: aX, y: aY))
                    seg.addLine(to: CGPoint(x: bX, y: bY))
                    let alpha: Double = min(1, fade * (0.75 - 0.22 * fs) * gain)
                    let lw: Double = (2.2 - 0.5 * fs) * (0.5 + 0.5 * gain)
                    ctx.stroke(seg, with: .color(P.cream.color.opacity(alpha)), style: StrokeStyle(lineWidth: lw, lineCap: .round))
                }
                let r: Double = 2 * (0.5 + 0.5 * gain)
                let headRect = CGRect(x: headX - r, y: headY - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: headRect), with: .color(head.opacity(fade)))
            }
            let cycle: Double = 12
            let idx: Double = (t / cycle).rounded(.down)
            let phase: Double = (t - idx * cycle) / cycle
            if phase < 0.09 {
                let h1: Double = (sin(idx * 91.7 + 2.1) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                let h2: Double = (sin(idx * 47.3 + 5.9) * 26951.2917).truncatingRemainder(dividingBy: 1).magnitude
                streak(phase / 0.09, h1, h2, len: width * 0.26, gain: 1, head: P.blossom.color)
            }
            // The solve star: longer, brighter, gold-headed — one per draft.
            let age: Double = t - beatAt
            if beatAt > 0, age >= 0, age < 1.8 {
                let fb: Double = Double(beat)
                let h1: Double = (sin(fb * 73.9 + 3.7) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude
                let h2: Double = (sin(fb * 29.5 + 1.4) * 26951.2917).truncatingRemainder(dividingBy: 1).magnitude
                streak(age / 1.8, h1, h2, len: width * 0.44, gain: 1.45, head: P.torch.color)
            }
        }
        .frame(width: w, height: h * 0.42)
        .position(x: w / 2, y: h * 0.21)
    }

    /// Giant moon upper-left: cream disc, three flat crater spots, and two
    /// halo rings that pulse in opposition to the sky breath — brightest when
    /// the night is deepest. Fill depth swells the glow directly — the quiet
    /// "almost there" as the reveal approaches (zero at depth 0).
    private var moon: some View {
        let r: CGFloat = w * 0.14
        let pulse: Double = 1 + 0.012 * sin(t * 0.35)
        let counter: Double = 1 - breath
        let haloScale: CGFloat = CGFloat(pulse * (1 + 0.03 * counter + 0.06 * depth))
        let disc: Color = P.cream.mix(P.blossom, 0.45)
        let crater: Color = P.cream.lerp(P.torch, 0.28).color
        let ringOuter: Double = (0.10 + 0.06 * depth) * (0.80 + 0.35 * counter)
        let ringInner: Double = (0.16 + 0.08 * depth) * (0.80 + 0.35 * counter)
        return ZStack {
            Circle()
                .fill(disc.opacity(ringOuter))
                .frame(width: r * 2.6, height: r * 2.6)
                .scaleEffect(haloScale)
            Circle()
                .fill(disc.opacity(ringInner))
                .frame(width: r * 2.15, height: r * 2.15)
                .scaleEffect(haloScale)
            Circle()
                .fill(disc)
                .frame(width: r * 2, height: r * 2)
            Circle()
                .fill(crater)
                .frame(width: r * 0.50, height: r * 0.50)
                .offset(x: -r * 0.34, y: -r * 0.18)
            Circle()
                .fill(crater)
                .frame(width: r * 0.30, height: r * 0.30)
                .offset(x: r * 0.30, y: r * 0.30)
            Circle()
                .fill(crater)
                .frame(width: r * 0.20, height: r * 0.20)
                .offset(x: r * 0.10, y: -r * 0.44)
        }
        .position(x: moonX, y: moonY)
    }

    // MARK: water

    private var ocean: some View {
        ZStack {
            band(horizonY, h, P.deepLeaf.lerp(P.ink, 0.48 + 0.12 * breath).color)
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let oceanH: Double = Double(sz.height)
                for row in 0..<4 {
                    let fr: Double = Double(row)
                    let y: Double = oceanH * (0.22 + 0.19 * fr)
                    let amp: Double = 1.6 + 0.6 * fr
                    let speed: Double = 0.5 + 0.13 * fr
                    var path = Path()
                    var first = true
                    var x: Double = 0
                    while x <= width {
                        let angle: Double = x / 95 * 2 * .pi + t * speed + fr * 1.7
                        let yy: Double = y + amp * sin(angle)
                        let point = CGPoint(x: x, y: yy)
                        if first { path.move(to: point); first = false }
                        else { path.addLine(to: point) }
                        x += 6
                    }
                    ctx.stroke(path, with: .color(P.cream.color.opacity(0.10)), lineWidth: 1.3)
                }
                let glintX: Double = width * 0.30
                for row in 0..<6 {
                    let fr: Double = Double(row)
                    let gy: Double = oceanH * 0.10 + fr * oceanH * 0.13
                    let shimmer: Double = 0.5 + 0.5 * sin(t * 1.8 + fr * 1.5)
                    let sway: Double = 9 * sin(t * 0.7 + fr * 2.1)
                    let gw: Double = 26 - fr * 2.5 + 6 * sin(t * 0.5 + fr)
                    let gx: Double = glintX - gw / 2 + sway
                    let rect = CGRect(x: gx, y: gy, width: gw, height: 2.6)
                    let alpha: Double = shimmer * 0.42 * (1 - fr / 9)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.3), with: .color(P.cream.color.opacity(alpha)))
                }
            }
            .frame(width: w, height: ledgeTopY - horizonY)
            .position(x: w / 2, y: (horizonY + ledgeTopY) / 2)
        }
    }

    // MARK: land

    /// Low angular islet closing the cove on the left, one tiny palm on top.
    private var headland: some View {
        let fill: Color = P.deepLeaf.lerp(P.ink, 0.66).color
        return ZStack(alignment: .bottom) {
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let height: Double = Double(sz.height)
                var p = Path()
                p.move(to: CGPoint(x: 0, y: height))
                p.addLine(to: CGPoint(x: 0, y: height * 0.35))
                p.addLine(to: CGPoint(x: width * 0.22, y: height * 0.18))
                p.addLine(to: CGPoint(x: width * 0.46, y: height * 0.44))
                p.addLine(to: CGPoint(x: width * 0.70, y: height * 0.30))
                p.addLine(to: CGPoint(x: width, y: height))
                p.closeSubpath()
                ctx.fill(p, with: .color(fill))
            }
            TinyPalm()
                .stroke(fill, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 22, height: 26)
                .offset(x: -w * 0.045, y: -h * 0.036)
        }
        .frame(width: w * 0.16, height: h * 0.045)
        .position(x: w * 0.08, y: horizonY - h * 0.0225)
    }

    /// The cove's guardian: an angular cone with a notched crater. Inside the
    /// notch an ember glow breathes on an 8 s cycle, rim-lighting the crater
    /// edges, while a few sparks climb and die.
    private var volcano: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            func poly(_ pts: [(Double, Double)]) -> Path {
                var p = Path()
                p.move(to: CGPoint(x: pts[0].0 * width, y: pts[0].1 * height))
                for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0 * width, y: q.1 * height)) }
                p.closeSubpath()
                return p
            }
            let ridge: Color = P.twilight.lerp(P.ink, 0.76).color
            ctx.fill(
                poly([(0.0, 1.0), (0.10, 0.72), (0.30, 0.58), (0.52, 0.70),
                      (0.66, 0.62), (0.86, 0.78), (1.0, 0.74), (1.0, 1.0)]),
                with: .color(ridge)
            )
            let cone: Color = P.woodDark.lerp(P.ink, 0.42 + 0.14 * breath).color
            ctx.fill(
                poly([(0.06, 1.0), (0.22, 0.62), (0.34, 0.44), (0.50, 0.16),
                      (0.58, 0.10), (0.62, 0.22), (0.66, 0.20), (0.70, 0.06),
                      (0.78, 0.30), (0.88, 0.56), (0.97, 0.82), (1.0, 1.0)]),
                with: .color(cone)
            )
            let ember: Double = 0.5 + 0.5 * sin(t * 2 * .pi / 8)
            let cx: Double = width * 0.64
            let cy: Double = height * 0.215
            let outerR: Double = width * 0.070 * (1 + 0.18 * ember)
            let outerRect = CGRect(x: cx - outerR, y: cy - outerR, width: outerR * 2, height: outerR * 2)
            ctx.fill(Path(ellipseIn: outerRect), with: .color(P.coral.color.opacity(0.06 + 0.10 * ember)))
            let coreR: Double = width * 0.020 * (1 + 0.12 * ember)
            let coreColor: Color = P.coral.lerp(P.ember, 0.30).color
            let coreRect = CGRect(x: cx - coreR, y: cy - coreR, width: coreR * 2, height: coreR * 2)
            ctx.fill(Path(ellipseIn: coreRect), with: .color(coreColor.opacity(0.70 + 0.30 * ember)))
            for i in 0..<3 {
                let fi: Double = Double(i)
                let sparkCycle: Double = 5.0 + fi * 1.3
                let ph: Double = (t / sparkCycle + fi * 0.37).truncatingRemainder(dividingBy: 1)
                let sparkX: Double = cx + (fi - 1) * width * 0.02 + 10 * sin(t * 0.8 + fi * 2.4)
                let sparkY: Double = cy - ph * height * 0.24
                let alpha: Double = (1 - ph) * 0.7 * ember
                let rect = CGRect(x: sparkX - 1.5, y: sparkY - 1.5, width: 3, height: 3)
                ctx.fill(Path(ellipseIn: rect), with: .color(P.torch.color.opacity(alpha)))
            }
        }
        .frame(width: w * 0.50, height: h * 0.36)
        .position(x: w * 0.79, y: horizonY - h * 0.18)
    }

    /// Thin smoke strands rising from the crater. They sway on a medium
    /// beat and the whole column leans with a glacial 180 s wind.
    private var smoke: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let lean: Double = width * 0.16 * sin(t * 2 * .pi / 180)
            let tint: Color = P.twilight.lerp(P.cream, 0.42).color
            for strand in 0..<2 {
                let fs0: Double = Double(strand)
                var xx: Double = width * 0.5 + fs0 * 3
                var yy: Double = height
                var p = Path()
                p.move(to: CGPoint(x: xx, y: yy))
                for s in 0..<4 {
                    let fs: Double = Double(s)
                    let frac: Double = (fs + 1) / 4
                    let ny: Double = height * (1 - frac)
                    let sway: Double = width * 0.05 * sin(t * 0.32 + fs * 1.8 + fs0 * 2.2)
                    let nx: Double = width * 0.5 + lean * frac + sway * frac
                    let cxx: Double = (xx + nx) / 2 + width * 0.04 * sin(t * 0.45 + fs * 2.6 + fs0)
                    let cyy: Double = (yy + ny) / 2
                    p.addQuadCurve(to: CGPoint(x: nx, y: ny), control: CGPoint(x: cxx, y: cyy))
                    xx = nx
                    yy = ny
                }
                let lw: Double = strand == 0 ? 4.5 : 2.5
                let alpha: Double = strand == 0 ? 0.11 : 0.08
                ctx.stroke(p, with: .color(tint.opacity(alpha)), style: StrokeStyle(lineWidth: lw, lineCap: .round))
            }
        }
        .frame(width: w * 0.26, height: h * 0.24)
        .position(x: w * 0.86, y: h * 0.228)
    }

    // MARK: foreground

    /// Rocky ledge: an ink polygon with an angular, irregular top edge. A
    /// pinnacle rises at the far left (the cat's lookout) and a lower outcrop
    /// on the right carries the lantern. Lighter boulders step the values.
    private var ledge: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let top: Double = 0.54
            func yy(_ f: Double) -> Double { (f - top) / 0.46 * height }
            let outline: [(Double, Double)] = [
                (0.0, 1.0), (0.0, 0.63), (0.035, 0.578), (0.105, 0.562),
                (0.135, 0.67), (0.16, 0.79), (0.19, 0.845),
                (0.28, 0.836), (0.31, 0.812), (0.37, 0.818), (0.40, 0.845),
                (0.52, 0.840), (0.62, 0.850), (0.70, 0.828), (0.76, 0.846),
                (0.86, 0.843), (0.90, 0.72), (0.955, 0.695), (1.0, 0.735),
                (1.0, 1.0),
            ]
            var p = Path()
            p.move(to: CGPoint(x: outline[0].0 * width, y: yy(outline[0].1)))
            for q in outline.dropFirst() {
                p.addLine(to: CGPoint(x: q.0 * width, y: yy(q.1)))
            }
            p.closeSubpath()
            ctx.fill(p, with: .color(P.ink.color))
            let boulder: Color = P.ink.lerp(P.woodDark, 0.35).color
            let stones: [[(Double, Double)]] = [
                [(0.46, 0.905), (0.50, 0.862), (0.555, 0.868), (0.575, 0.905)],
                [(0.66, 0.93), (0.70, 0.882), (0.77, 0.888), (0.80, 0.93)],
                [(0.22, 0.92), (0.255, 0.878), (0.30, 0.885), (0.315, 0.92)],
            ]
            for s in stones {
                var b = Path()
                b.move(to: CGPoint(x: s[0].0 * width, y: yy(s[0].1)))
                for q in s.dropFirst() { b.addLine(to: CGPoint(x: q.0 * width, y: yy(q.1))) }
                b.closeSubpath()
                ctx.fill(b, with: .color(boulder))
            }
        }
        .frame(width: w, height: h * 0.46)
        .position(x: w / 2, y: h * 0.77)
    }

    /// A little hut-shaped tiki lantern left burning on the right outcrop —
    /// somebody was here not long ago. The window flickers like a torch.
    /// The drafting lamp: its pool warms and widens with fill depth.
    private var lantern: some View {
        let flick: Double = 0.72 + 0.16 * sin(t * 11) + 0.08 * sin(t * 29 + 1.7) + 0.04 * sin(t * 47 + 0.6)
        return ZStack {
            Circle()
                .fill(P.torch.color.opacity((0.13 + 0.09 * depth) * flick))
                .frame(width: w * 0.115 * (1 + 0.22 * depth), height: w * 0.115 * (1 + 0.22 * depth))
            Canvas { ctx, sz in
                let sxu: Double = Double(sz.width) / 100
                let syu: Double = Double(sz.height) / 120
                func poly(_ pts: [(Double, Double)]) -> Path {
                    var p = Path()
                    p.move(to: CGPoint(x: pts[0].0 * sxu, y: pts[0].1 * syu))
                    for q in pts.dropFirst() { p.addLine(to: CGPoint(x: q.0 * sxu, y: q.1 * syu)) }
                    p.closeSubpath()
                    return p
                }
                ctx.fill(poly([(50, 0), (96, 42), (4, 42)]), with: .color(P.woodDark.lerp(P.driftwood, 0.25).color))
                ctx.fill(poly([(22, 42), (78, 42), (72, 104), (28, 104)]), with: .color(P.woodDark.color))
                ctx.fill(
                    Path(CGRect(x: 38 * sxu, y: 56 * syu, width: 24 * sxu, height: 34 * syu)),
                    with: .color(P.torch.color.opacity(flick))
                )
                ctx.fill(
                    Path(CGRect(x: 44 * sxu, y: 64 * syu, width: 12 * sxu, height: 18 * syu)),
                    with: .color(P.blossom.color.opacity(flick * 0.9))
                )
                ctx.fill(
                    Path(CGRect(x: 18 * sxu, y: 104 * syu, width: 64 * sxu, height: 8 * syu)),
                    with: .color(P.ink.color)
                )
            }
            .frame(width: w * 0.052, height: h * 0.048)
        }
        .position(x: w * 0.925, y: h * 0.684)
    }

    /// The suspicious cat, out on the pinnacle, transfixed by the moon.
    private var cat: some View {
        CatView(t: t)
            .frame(width: w * 0.105, height: h * 0.072)
            .position(x: w * 0.070, y: h * 0.526)
    }
}

#Preview {
    BlueprintsBackgroundView()
}
