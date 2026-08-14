import SwiftUI

// Shared scenery kit for all five game backgrounds.
// Flat fills only — no gradients, shadows, or blur. All motion is driven by a
// single TimelineView clock per scene. Canvas math uses explicit Double types
// to keep the Swift type-checker fast.

// MARK: - Palette

struct RGB {
    let r: Double, g: Double, b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    var color: Color { Color(red: r, green: g, blue: b) }
    func lerp(_ o: RGB, _ u: Double) -> RGB {
        RGB(r + (o.r - r) * u, g + (o.g - g) * u, b + (o.b - b) * u)
    }
    func mix(_ o: RGB, _ u: Double) -> Color { lerp(o, u).color }
}

/// Three-keyframe blend that never passes through desaturated gray:
/// day → mid for u in 0...0.5, mid → night for u in 0.5...1.
func mix3(_ day: RGB, _ mid: RGB, _ night: RGB, _ u: Double) -> Color {
    if u < 0.5 { return day.mix(mid, u * 2) }
    return mid.mix(night, (u - 0.5) * 2)
}

/// RGB variant of mix3 for scenes that keep blending past the night keyframe
/// (depth-state palettes). Same math; the caller finishes with `.color`.
func mix3RGB(_ day: RGB, _ mid: RGB, _ night: RGB, _ u: Double) -> RGB {
    if u < 0.5 { return day.lerp(mid, u * 2) }
    return mid.lerp(night, (u - 0.5) * 2)
}

enum P {
    static let blossom = RGB(1.000, 0.965, 0.894)       // FFF6E4
    static let cream = RGB(0.949, 0.894, 0.757)         // F2E4C1
    static let torch = RGB(0.910, 0.706, 0.314)         // E8B450
    static let sunsetMid = RGB(0.933, 0.541, 0.329)     // EE8A54
    static let coral = RGB(0.910, 0.420, 0.290)         // E86B4A
    static let clay = RGB(0.773, 0.353, 0.235)          // C55A3C
    static let rum = RGB(0.545, 0.228, 0.180)           // 8B3A2E
    static let ember = RGB(0.290, 0.106, 0.047)         // 4A1B0C
    static let lagoon = RGB(0.102, 0.353, 0.420)        // 1A5A6B
    static let lagoonTeal = RGB(0.165, 0.420, 0.486)    // 2A6B7C — lighter water step
    static let deepLeaf = RGB(0.071, 0.243, 0.286)      // 123E49
    static let palmLeaf = RGB(0.102, 0.290, 0.337)      // 1A4A56
    static let driftwood = RGB(0.420, 0.290, 0.180)     // 6B4A2E
    static let plank = RGB(0.349, 0.224, 0.122)         // 59391F
    static let shadowBrown = RGB(0.290, 0.180, 0.102)   // 4A2E1A
    static let woodDark = RGB(0.231, 0.157, 0.094)      // 3B2818
    static let ink = RGB(0.106, 0.086, 0.075)           // 1B1613
    static let twilight = RGB(0.169, 0.165, 0.337)      // 2B2A56
    static let olive = RGB(0.478, 0.545, 0.180)         // 7A8B2E — retro plant green
    static let bioGlow = RGB(0.329, 0.910, 0.855)       // 54E8DA — glow-tide cyan
}

// MARK: - Clouds

struct CloudPuff: View {
    let width: CGFloat
    var body: some View {
        FluffyCloudShape()
            .frame(width: width, height: width * 0.40)
    }
}

/// Flat-bottomed cumulus: a rounded base with puffy lobes rising off it.
/// Single path so the flat fill stays seamless at partial opacity.
struct FluffyCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        let baseH = h * 0.38
        p.addRoundedRect(
            in: CGRect(x: 0, y: h - baseH, width: w, height: baseH),
            cornerSize: CGSize(width: baseH / 2, height: baseH / 2)
        )
        let puffs: [(Double, Double, Double)] = [
            (0.22, 0.55, 0.30),
            (0.44, 0.42, 0.42),
            (0.67, 0.52, 0.34),
            (0.85, 0.68, 0.22),
        ]
        for q in puffs {
            let r = h * q.2
            let cx = w * q.0
            let cy = h * q.1
            p.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }
        return p
    }
}

// MARK: - Water and horizon props

struct IslandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.4)
        )
        p.closeSubpath()
        return p
    }
}

struct TinyPalm: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h))
        p.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.25), control: CGPoint(x: w * 0.42, y: h * 0.6))
        let crown = CGPoint(x: w * 0.58, y: h * 0.25)
        for tip in [CGPoint(x: 0, y: h * 0.30), CGPoint(x: w * 0.25, y: 0),
                    CGPoint(x: w * 0.9, y: 0), CGPoint(x: w, y: h * 0.35)] {
            p.move(to: crown)
            p.addQuadCurve(to: tip, control: CGPoint(x: (crown.x + tip.x) / 2, y: min(crown.y, tip.y) - h * 0.12))
        }
        return p
    }
}

struct BoatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0, y: h * 0.78))
        p.addLine(to: CGPoint(x: w, y: h * 0.78))
        p.addLine(to: CGPoint(x: w * 0.82, y: h))
        p.addLine(to: CGPoint(x: w * 0.18, y: h))
        p.closeSubpath()
        p.move(to: CGPoint(x: w * 0.52, y: h * 0.70))
        p.addLine(to: CGPoint(x: w * 0.52, y: 0))
        p.addLine(to: CGPoint(x: w * 0.14, y: h * 0.70))
        p.closeSubpath()
        return p
    }
}

// MARK: - Palm

/// Curved-trunk palm with drooping fronds, drawn in a 200x300 design box.
/// Plant it behind a foreground band; sways gently around its base.
struct PalmView: View {
    let t: Double
    let dusk: Double
    let phase: Double

    var body: some View {
        Canvas { ctx, sz in
            let sx: Double = Double(sz.width) / 200
            let sy: Double = Double(sz.height) / 300
            func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }

            let leaf: Color = P.palmLeaf.mix(P.deepLeaf, dusk)
            let wood: Color = P.shadowBrown.mix(P.woodDark, dusk)

            var trunk = Path()
            trunk.move(to: pt(45, 300))
            trunk.addCurve(to: pt(148, 70), control1: pt(66, 220), control2: pt(102, 140))
            ctx.stroke(trunk, with: .color(wood), style: StrokeStyle(lineWidth: 9 * sx, lineCap: .round))

            let fronds: [((Double, Double), (Double, Double), (Double, Double))] = [
                ((100, 22), (58, 34), (110, 58)),
                ((140, 0), (168, 10), (156, 48)),
                ((188, 28), (200, 58), (172, 62)),
                ((202, 78), (196, 112), (172, 80)),
                ((92, 72), (72, 108), (116, 84)),
                ((152, 98), (136, 124), (142, 90)),
            ]
            let crown = pt(148, 70)
            for f in fronds {
                var leafPath = Path()
                leafPath.move(to: crown)
                leafPath.addQuadCurve(to: pt(f.1.0, f.1.1), control: pt(f.0.0, f.0.1))
                leafPath.addQuadCurve(to: crown, control: pt(f.2.0, f.2.1))
                leafPath.closeSubpath()
                ctx.fill(leafPath, with: .color(leaf))
                var rib = Path()
                rib.move(to: crown)
                let midX: Double = (f.0.0 + f.2.0) / 2
                let midY: Double = (f.0.1 + f.2.1) / 2
                rib.addQuadCurve(to: pt(f.1.0, f.1.1), control: pt(midX, midY))
                ctx.stroke(rib, with: .color(wood.opacity(0.45)), lineWidth: 1.6 * sx)
            }
            for c in [(142.0, 78.0), (154.0, 84.0)] {
                let r: Double = 6 * sx
                ctx.fill(
                    Path(ellipseIn: CGRect(x: c.0 * sx - r, y: c.1 * sy - r, width: r * 2, height: r * 2)),
                    with: .color(wood)
                )
            }
        }
        .rotationEffect(.degrees(sin(t * 0.45 + phase) * 1.4), anchor: .bottom)
    }
}

// MARK: - Fire

/// Bamboo torch with layered flickering flame. `boost` swells the flame for
/// depth-state flares (0 = the shipped torch exactly).
struct TorchView: View {
    let t: Double
    let dusk: Double
    let phase: Double
    var boost: Double = 0

    var body: some View {
        let flicker: Double = 1 + 0.10 * sin(t * 9 + phase) + 0.06 * sin(t * 23 + phase * 1.7)
        let lean: Double = 4 * sin(t * 7 + phase) + 2 * sin(t * 17 + phase)
        return VStack(spacing: 0) {
            ZStack {
                FlameShape()
                    .fill(P.coral.color)
                    .frame(width: 26, height: 44)
                FlameShape()
                    .fill(P.torch.color)
                    .frame(width: 14, height: 26)
                    .offset(y: 9)
            }
            .scaleEffect(x: 1 + 0.30 * boost, y: flicker * (1 + 0.55 * boost), anchor: .bottom)
            .rotationEffect(.degrees(lean), anchor: .bottom)

            Rectangle()
                .fill(P.woodDark.color)
                .frame(width: 14, height: 10)
            Rectangle()
                .fill(P.shadowBrown.mix(P.woodDark, dusk))
                .frame(width: 7)
                .frame(maxHeight: .infinity)
        }
    }
}

struct FlameShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: h))
        p.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.42), control: CGPoint(x: 0, y: h * 0.78))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0), control: CGPoint(x: w * 0.34, y: h * 0.14))
        p.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.42), control: CGPoint(x: w * 0.66, y: h * 0.14))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h), control: CGPoint(x: w, y: h * 0.78))
        p.closeSubpath()
        return p
    }
}

// MARK: - Props

/// Tiki mug with a straw — someone left their drink out.
struct MugView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                MugShape()
                    .fill(P.torch.color)
                    .frame(width: w, height: h)
                Circle()
                    .fill(P.woodDark.color)
                    .frame(width: w * 0.11)
                    .position(x: w * 0.36, y: h * 0.42)
                Circle()
                    .fill(P.woodDark.color)
                    .frame(width: w * 0.11)
                    .position(x: w * 0.64, y: h * 0.42)
                Rectangle()
                    .fill(P.woodDark.color)
                    .frame(width: w * 0.40, height: h * 0.055)
                    .position(x: w * 0.5, y: h * 0.66)
                Rectangle()
                    .fill(P.coral.color)
                    .frame(width: w * 0.07, height: h * 0.5)
                    .rotationEffect(.degrees(24))
                    .position(x: w * 0.76, y: h * 0.04)
            }
        }
    }
}

struct MugShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.08, y: 0))
        p.addLine(to: CGPoint(x: w * 0.92, y: 0))
        p.addLine(to: CGPoint(x: w * 0.84, y: h))
        p.addLine(to: CGPoint(x: w * 0.16, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - The suspicious cat (cameos in every scene)

/// Sits watching, tail swishing, blinking occasionally.
struct CatView: View {
    let t: Double

    var body: some View {
        let blinkPhase = t.truncatingRemainder(dividingBy: 6.5)
        let blink: CGFloat = blinkPhase < 0.18 ? 0.12 : 1.0
        let tailSwish = sin(t * 0.8) * 14

        return GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                TailShape()
                    .stroke(P.ink.color, style: StrokeStyle(lineWidth: w * 0.075, lineCap: .round))
                    .frame(width: w * 0.36, height: h * 0.62)
                    .rotationEffect(.degrees(tailSwish), anchor: .bottomTrailing)
                    .position(x: w * 0.16, y: h * 0.62)
                BodyShape()
                    .fill(P.ink.color)
                    .frame(width: w * 0.62, height: h * 0.60)
                    .position(x: w * 0.52, y: h * 0.70)
                Circle()
                    .fill(P.ink.color)
                    .frame(width: w * 0.42, height: w * 0.42)
                    .position(x: w * 0.66, y: h * 0.30)
                EarShape()
                    .fill(P.ink.color)
                    .frame(width: w * 0.42, height: h * 0.28)
                    .position(x: w * 0.66, y: h * 0.12)
                ForEach(0..<2, id: \.self) { i in
                    Ellipse()
                        .fill(P.torch.color)
                        .frame(width: w * 0.115, height: w * 0.085)
                        .scaleEffect(x: 1, y: blink)
                        .position(x: w * (i == 0 ? 0.585 : 0.735), y: h * 0.29)
                }
            }
        }
    }
}

struct TailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY),
            control: CGPoint(x: rect.minX - rect.width * 0.4, y: rect.maxY * 0.8)
        )
        return p
    }
}

struct BodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.minY + rect.height * 0.25))
        p.addLine(to: CGPoint(x: rect.maxX * 0.85, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

struct EarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.22, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.maxY * 0.85))
        p.closeSubpath()
        p.move(to: CGPoint(x: rect.maxX - rect.width * 0.42, y: rect.maxY * 0.85))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.22, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.08, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
