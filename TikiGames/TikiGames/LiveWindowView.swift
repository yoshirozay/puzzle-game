import SwiftUI

/// Lounge v2 live windows (LOUNGE_V2_PLAN §4): code-drawn architectural
/// windows whose views are flat palette scenes breathing on the room's 90 s
/// clock — depth instead of framed pictures. Views beyond `sunset` are earned
/// by top depth-state milestones and cycled by tapping the owned window;
/// nothing is sold. Compositions mirror the reference SVGs in
/// assets/sprites-v2/window-*.svg.
enum WindowViewKind: String, CaseIterable {
    case sunset, beach, volcanoNight, glowTide

    /// Global milestone bit that unlocks each earned view (nil = always).
    var unlockBit: Int? {
        switch self {
        case .sunset: return nil
        case .beach: return 10        // Luau INFERNO
        case .volcanoNight: return 7  // Zombie THE ZOMBIE
        case .glowTide: return 3      // Stacks GLOW TIDE
        }
    }

    static func unlocked(mask: Int) -> [WindowViewKind] {
        allCases.filter { $0.unlockBit.map { mask & (1 << $0) != 0 } ?? true }
    }
}

struct LiveWindowView: View {
    let t: Double
    let view: WindowViewKind

    private var breath: Double { (1 - cos(t * 2 * .pi / 90)) / 2 }

    var body: some View {
        Canvas { ctx, sz in
            let w: Double = Double(sz.width)
            let h: Double = Double(sz.height)
            // Wood frame, then the scene fills the inner pane.
            ctx.fill(
                Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: w * 0.03),
                with: .color(P.woodDark.color)
            )
            let inset: Double = w * 0.045
            let pane = CGRect(x: inset, y: inset, width: w - inset * 2, height: h - inset * 2)
            scene(&ctx, pane)
            // Mullions over the scene: one vertical, one horizontal.
            ctx.fill(
                Path(CGRect(x: pane.midX - w * 0.014, y: pane.minY, width: w * 0.028, height: pane.height)),
                with: .color(P.woodDark.color)
            )
            ctx.fill(
                Path(CGRect(x: pane.minX, y: pane.minY + pane.height * 0.44, width: pane.width, height: h * 0.028)),
                with: .color(P.woodDark.color)
            )
        }
    }

    private func band(_ ctx: inout GraphicsContext, _ pane: CGRect, _ y0: Double, _ y1: Double, _ color: Color) {
        ctx.fill(
            Path(CGRect(x: pane.minX, y: pane.minY + pane.height * y0,
                        width: pane.width, height: pane.height * (y1 - y0))),
            with: .color(color)
        )
    }

    private func disc(_ ctx: inout GraphicsContext, _ pane: CGRect, cx: Double, cy: Double, r: Double, _ color: Color) {
        let rr = pane.width * r
        ctx.fill(
            Path(ellipseIn: CGRect(x: pane.minX + pane.width * cx - rr, y: pane.minY + pane.height * cy - rr,
                                   width: rr * 2, height: rr * 2)),
            with: .color(color)
        )
    }

    private func glint(_ ctx: inout GraphicsContext, _ pane: CGRect, cx: Double, cy: Double, len: Double, _ color: Color, alpha: Double) {
        ctx.fill(
            Path(roundedRect: CGRect(x: pane.minX + pane.width * cx, y: pane.minY + pane.height * cy,
                                     width: pane.width * len, height: max(2, pane.height * 0.018)),
                 cornerRadius: 2),
            with: .color(color.opacity(alpha))
        )
    }

    private func scene(_ ctx: inout GraphicsContext, _ pane: CGRect) {
        let sink: Double = 0.03 * breath
        switch view {
        case .sunset:
            band(&ctx, pane, 0.00, 0.30, P.blossom.color)
            band(&ctx, pane, 0.30, 0.52, P.torch.color)
            band(&ctx, pane, 0.52, 0.68, P.sunsetMid.mix(P.coral, 0.3 * breath))
            band(&ctx, pane, 0.68, 0.78, P.coral.color)
            band(&ctx, pane, 0.78, 1.00, P.lagoon.color)
            disc(&ctx, pane, cx: 0.40, cy: 0.36 + sink, r: 0.14, P.blossom.color)
            glint(&ctx, pane, cx: 0.34, cy: 0.85, len: 0.14, P.cream.color, alpha: 0.8)
            glint(&ctx, pane, cx: 0.40, cy: 0.90, len: 0.10, P.cream.color, alpha: 0.5 + 0.3 * breath)
        case .beach:
            band(&ctx, pane, 0.00, 0.52, P.blossom.color)
            band(&ctx, pane, 0.20, 0.52, P.cream.mix(P.torch, 0.25))
            band(&ctx, pane, 0.52, 0.74, P.lagoon.color)
            band(&ctx, pane, 0.74, 1.00, P.cream.color)
            disc(&ctx, pane, cx: 0.30, cy: 0.24 + sink, r: 0.12, P.torch.color)
            glint(&ctx, pane, cx: 0.42, cy: 0.60, len: 0.12, P.blossom.color, alpha: 0.7)
            // Palm silhouette off the east mullion.
            var trunk = Path()
            trunk.move(to: CGPoint(x: pane.minX + pane.width * 0.80, y: pane.minY + pane.height * 0.98))
            trunk.addQuadCurve(
                to: CGPoint(x: pane.minX + pane.width * 0.70, y: pane.minY + pane.height * 0.28),
                control: CGPoint(x: pane.minX + pane.width * 0.82, y: pane.minY + pane.height * 0.55)
            )
            ctx.stroke(trunk, with: .color(P.ink.color), style: StrokeStyle(lineWidth: pane.width * 0.03, lineCap: .round))
            for (dx, dy) in [(-0.16, -0.04), (-0.10, -0.12), (0.04, -0.13), (0.12, -0.05)] {
                var frond = Path()
                frond.move(to: CGPoint(x: pane.minX + pane.width * 0.70, y: pane.minY + pane.height * 0.28))
                frond.addQuadCurve(
                    to: CGPoint(x: pane.minX + pane.width * (0.70 + dx * 1.6), y: pane.minY + pane.height * (0.28 + dy + 0.10)),
                    control: CGPoint(x: pane.minX + pane.width * (0.70 + dx), y: pane.minY + pane.height * (0.28 + dy))
                )
                ctx.stroke(frond, with: .color(P.ink.color), style: StrokeStyle(lineWidth: pane.width * 0.022, lineCap: .round))
            }
        case .volcanoNight:
            band(&ctx, pane, 0.00, 0.80, P.twilight.color)
            band(&ctx, pane, 0.80, 1.00, P.deepLeaf.color)
            for (sx, sy) in [(0.14, 0.14), (0.30, 0.30), (0.86, 0.16), (0.72, 0.08)] {
                disc(&ctx, pane, cx: sx, cy: sy + 0.01 * breath, r: 0.012, P.blossom.color)
            }
            disc(&ctx, pane, cx: 0.78, cy: 0.20 + sink * 0.5, r: 0.06, P.blossom.color)
            var cone = Path()
            cone.move(to: CGPoint(x: pane.minX + pane.width * 0.12, y: pane.minY + pane.height * 0.82))
            cone.addLine(to: CGPoint(x: pane.minX + pane.width * 0.46, y: pane.minY + pane.height * 0.26))
            cone.addLine(to: CGPoint(x: pane.minX + pane.width * 0.58, y: pane.minY + pane.height * 0.26))
            cone.addLine(to: CGPoint(x: pane.minX + pane.width * 0.92, y: pane.minY + pane.height * 0.82))
            cone.closeSubpath()
            ctx.fill(cone, with: .color(P.rum.color))
            var lava = Path()
            lava.move(to: CGPoint(x: pane.minX + pane.width * 0.475, y: pane.minY + pane.height * 0.26))
            lava.addLine(to: CGPoint(x: pane.minX + pane.width * 0.565, y: pane.minY + pane.height * 0.26))
            lava.addLine(to: CGPoint(x: pane.minX + pane.width * 0.535, y: pane.minY + pane.height * (0.52 + 0.03 * breath)))
            lava.addLine(to: CGPoint(x: pane.minX + pane.width * 0.505, y: pane.minY + pane.height * (0.52 + 0.03 * breath)))
            lava.closeSubpath()
            ctx.fill(lava, with: .color(P.coral.color))
            disc(&ctx, pane, cx: 0.52, cy: 0.25, r: 0.05, P.coral.color.opacity(0.55 + 0.35 * breath))
        case .glowTide:
            band(&ctx, pane, 0.00, 0.62, P.palmLeaf.color)
            band(&ctx, pane, 0.62, 0.76, P.deepLeaf.color)
            band(&ctx, pane, 0.76, 1.00, P.lagoon.mix(P.deepLeaf, 0.4))
            disc(&ctx, pane, cx: 0.70, cy: 0.22 + sink * 0.6, r: 0.09, P.blossom.color)
            disc(&ctx, pane, cx: 0.735, cy: 0.205 + sink * 0.6, r: 0.065, P.palmLeaf.color)
            for (gx, gy, gl) in [(0.12, 0.82, 0.16), (0.34, 0.88, 0.11), (0.58, 0.84, 0.14), (0.78, 0.92, 0.10)] {
                glint(&ctx, pane, cx: gx, cy: gy + 0.012 * breath, len: gl, P.bioGlow.color, alpha: 0.55 + 0.35 * breath)
            }
        }
    }
}