import SwiftUI

/// A point-cloud tree, ported from Lionel Mora's p5.js sketch "Flowers made with
/// code #1". 15,400 points — 40 rings x 7 petals x 55 steps along each strand —
/// projected isometrically and breathing on an 8-second cycle.
///
/// EXPLORATORY. Staged as its own scene (SIMCTL_CHILD_TIKI_BG=codetree) rather
/// than dropped into the beach, so the shape can be judged on its own before
/// anyone argues about where it belongs.
///
/// The original advances `t` by PI/240 per draw at p5's 60fps, so `t` is not
/// seconds — it is an angle accumulating at PI/4 radians per second. Matching
/// that exactly is what keeps the motion at the speed it was authored for.
struct CodeTreeView: View {
    /// Points to draw. The original is 15,400 (= 385 * 40); anything less
    /// thins the canopy rather than shrinking it, since `i` walks rings last.
    var points: Int = 15_400
    /// Faithful to the sketch: near-white on near-black. The palette version is
    /// one line away — see `tint`.
    var tint: Color = Color(red: 1, green: 1, blue: 1).opacity(140.0 / 255.0)
    var background: Color = Color(red: 6.0 / 255, green: 8.0 / 255, blue: 11.0 / 255)
    /// The sketch's `22*y` term, which lifts the STRAND CENTRE. At the original
    /// 22 the thing is a flower — a radial burst with no stem. Raising it pulls
    /// the middle up into a spire and the outer rings fall away as a canopy,
    /// which is the only change needed to make the same maths read as a tree.
    var spire: Double = 22

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))
                // The sketch is authored against a 520x520 canvas centred at
                // (260, 265); scale to whatever frame we are handed so it can be
                // dropped anywhere without re-deriving the constants.
                let scale = min(size.width, size.height) / 520
                let ox = size.width / 2, oy = size.height / 2
                ctx.fill(Self.cloud(points: points, t: elapsed * .pi / 4,
                                    scale: scale, ox: ox, oy: oy, spire: spire),
                         with: .color(tint))
            }
            .drawingGroup()
        }
    }

    /// One frame of the cloud as a SINGLE path. Building 15,400 separate fill
    /// calls is what makes a port like this crawl; accumulating into one path and
    /// filling once keeps it to a single draw.
    static func cloud(points: Int, t: Double, scale: CGFloat,
                      ox: CGFloat, oy: CGFloat, spire: Double = 22) -> Path {
        var path = Path()
        let dot = max(0.7, 1.15 * scale)
        for i in 0..<points {
            let j = Double(i % 55)
            let s = Double(i / 385) / 39
            let u = Double((i / 55) % 7) / 3 - 1
            let y = j / 55
            let a = j * 2.4 + t / 10
            let l = (50 + 130 * pow(1 - y, 0.85)) * (1 + 0.05 * sin(7.7 * j))
            let b = 1 - 0.45 * (0.5 + 0.5 * sin(0.45 * t + 3 * y - 1.2 * s))
            let e = (0.3 + 1.2 * y) * (1 - 0.8 * s) * b - 0.15 * s
            let r = l * s * cos(e)
            let z = l * s * sin(e) + spire * y
                + 6 * s * sin(7 * s - 1.6 * t + 0.9 * j) + u * u * 8 * s
            let q = a + u * (9 + 24 * (1 - y)) * sin(.pi * pow(s, 0.8)) / (r + 14)
                + 0.1 * s * sin(0.9 * t + 2.3 * j + 2.5 * s)
            // Isometric drop: 0.52 flattens the ellipse, 0.86 lifts height.
            let px = ox + CGFloat((260 - 260) + r * cos(q)) * scale
            let py = oy + CGFloat(0.52 * r * sin(q) - 0.86 * z) * scale
            path.addRect(CGRect(x: px, y: py, width: dot, height: dot))
        }
        return path
    }
}

#Preview {
    CodeTreeView()
        .ignoresSafeArea()
}

/// The same sketch rendered as SOLID FRONDS instead of a point cloud.
///
/// The point version is lovely and speaks the wrong language: every other thing
/// on this beach is sparse, flat-filled and hard-edged, so 15,400 stippled dots
/// read as a screenshot from a different app. What the sketch is actually GOOD at
/// is its structure — radial strands, a spire, fronds falling away, a 45%
/// breathing swing — and none of that needs a dot cloud to survive.
///
/// So this keeps the maths and throws away the medium. Each (ring, petal) pair
/// traces one strand; that polyline is widened into a leaf and filled flat, in
/// palette, painter-sorted back to front. ~40 shapes instead of 15,400 points.
struct CodePetalTreeView: View {
    var rings: Int = 6
    var petals: Int = 7
    var spire: Double = 190
    var background: Color = P.ink.color

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))
                let scale = min(size.width, size.height) / 520
                let ox = size.width / 2, oy = size.height / 2
                for frond in Self.fronds(rings: rings, petals: petals, spire: spire,
                                         t: elapsed * .pi / 4, scale: scale, ox: ox, oy: oy) {
                    // House idiom: a flat offset shadow, no blur.
                    ctx.fill(frond.path.offsetBy(dx: 1.5 * scale, dy: 2.5 * scale),
                             with: .color(P.ink.color.opacity(0.55)))
                    ctx.fill(frond.path, with: .color(frond.fill))
                }
            }
        }
    }

    struct Frond { let path: Path; let fill: Color; let depth: Double }

    /// One frame's worth of leaves, painter-sorted so the near ones land last.
    ///
    /// A FROND IS FIXED `j`, VARYING `s` — and getting that backwards is the one
    /// way to render this sketch into nonsense. `a = j*2.4` advances 2.4 RADIANS
    /// per step, a phyllotaxis spiral, so consecutive `j` values point in
    /// completely different directions; walking `j` traces no strand at all, it
    /// scatters around the whole circle. `s` is the radial one: it grows the
    /// radius from the spine outward while `q` barely drifts, which is exactly a
    /// frond. Reading `j` as the strand produced a stack of picture frames.
    static func fronds(rings: Int, petals: Int, spire: Double, t: Double,
                       scale: CGFloat, ox: CGFloat, oy: CGFloat) -> [Frond] {
        var out: [Frond] = []
        let steps = 20
        for jj in stride(from: 0, to: 55, by: max(1, 55 / max(1, rings * 9))) {
            for pi in 0..<petals {
                let j = Double(jj)
                let u = petals == 1 ? 0 : Double(pi) / Double(petals - 1) * 2 - 1
                let y = j / 55
                var spine: [CGPoint] = []
                var depth = 0.0
                for k in 0...steps {
                    let s = 0.06 + 0.94 * Double(k) / Double(steps)
                    let a = j * 2.4 + t / 10
                    let l = (50 + 130 * pow(1 - y, 0.85)) * (1 + 0.05 * sin(7.7 * j))
                    let b = 1 - 0.45 * (0.5 + 0.5 * sin(0.45 * t + 3 * y - 1.2 * s))
                    let e = (0.3 + 1.2 * y) * (1 - 0.8 * s) * b - 0.15 * s
                    let r = l * s * cos(e)
                    let z = l * s * sin(e) + spire * y
                        + 6 * s * sin(7 * s - 1.6 * t + 0.9 * j) + u * u * 8 * s
                    let q = a + u * (9 + 24 * (1 - y)) * sin(.pi * pow(s, 0.8)) / (r + 14)
                        + 0.1 * s * sin(0.9 * t + 2.3 * j + 2.5 * s)
                    depth += 0.52 * r * sin(q)
                    spine.append(CGPoint(x: ox + CGFloat(r * cos(q)) * scale,
                                         y: oy + CGFloat(0.52 * r * sin(q) - 0.86 * z) * scale))
                }
                guard spine.count > 2 else { continue }
                out.append(Frond(path: leaf(spine, scale: scale),
                                 fill: colour(ring: 1 - y),
                                 depth: depth / Double(steps + 1)))
            }
        }
        // Painter's algorithm: the isometric drop puts the far side of the orbit
        // at a smaller y contribution, so sorting on it lays back leaves first.
        return out.sorted { $0.depth < $1.depth }
    }

    /// Widens a spine into a leaf — zero at the tip, fattest at mid-length, so it
    /// reads as a frond rather than a stroke of constant weight.
    private static func leaf(_ spine: [CGPoint], scale: CGFloat) -> Path {
        let n = spine.count
        var left: [CGPoint] = [], right: [CGPoint] = []
        for (k, p) in spine.enumerated() {
            let f = Double(k) / Double(n - 1)
            let w = CGFloat(pow(sin(.pi * f), 0.5)) * 3.4 * scale
            let prev = spine[max(0, k - 1)], next = spine[min(n - 1, k + 1)]
            let dx = next.x - prev.x, dy = next.y - prev.y
            let len = max(0.0001, sqrt(dx * dx + dy * dy))
            let nx = -dy / len * w, ny = dx / len * w
            left.append(CGPoint(x: p.x + nx, y: p.y + ny))
            right.append(CGPoint(x: p.x - nx, y: p.y - ny))
        }
        var path = Path()
        path.addLines(left + right.reversed())
        path.closeSubpath()
        return path
    }

    /// Outer rings sit further from the fire and read cooler and darker; the
    /// crown catches the torchlight. Flat steps, no gradient.
    private static func colour(ring: Double) -> Color {
        if ring > 0.82 { return P.torch.mix(P.cream, 0.25) }
        if ring > 0.60 { return P.olive.mix(P.torch, 0.30) }
        if ring > 0.38 { return P.olive.mix(P.deepLeaf, 0.25) }
        if ring > 0.18 { return P.palmLeaf.mix(P.olive, 0.30) }
        return P.deepLeaf.mix(P.ink, 0.20)
    }
}
