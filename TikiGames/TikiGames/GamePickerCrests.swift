import SwiftUI

// MARK: - Lounge crest + flame glyph

/// The gold banner the lounge card wears while tonight's pour is earned and
/// unclaimed: a breathing capsule over the crest, same 30 fps self-clocked
/// pattern as the crest below it. Reduce Motion holds a steady mid-breath.
struct LoungePourBanner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let gold = Color(red: 0.910, green: 0.702, blue: 0.235)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breathe = reduceMotion ? 0.5 : 0.5 + 0.5 * sin(t * 2 * .pi / 2.6)
            Text("REWARD READY")
                .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                .tracking(1.8)
                .foregroundStyle(P.ink.color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(gold))
                .overlay(Capsule().stroke(P.ink.color, lineWidth: 1.5))
                .shadow(color: gold.opacity(0.30 + 0.35 * breathe), radius: CGFloat(5 + 4 * breathe))
                .scaleEffect(CGFloat(1 + 0.035 * breathe))
        }
        .accessibilityHidden(true)   // the card's label speaks for it
    }
}

/// A miniature torch against a coral wall — SwiftUI-native, no assets. Sits
/// in the picker's media window slot to announce the lounge without borrowing
/// the game-preview grammar (video, poster). Cheap enough to breathe alongside
/// up to five `AVPlayer` neighbors.
struct LoungeTorchCrest: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Wall — coral warmed toward rum on breath.
                if reduceMotion {
                    P.coral.lerp(P.rum, 0.5).color
                } else {
                    TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let breath = (1 - cos(t * 2 * .pi / 90)) / 2
                        P.coral.lerp(P.rum, breath).color
                    }
                }
                // Two mirrored fronds framing the crest.
                CornerFrondSprite()
                    .frame(width: w * 0.35, height: h * 0.7)
                    .rotationEffect(.degrees(-14))
                    .position(x: w * 0.18, y: h * 0.58)
                CornerFrondSprite()
                    .frame(width: w * 0.35, height: h * 0.7)
                    .scaleEffect(x: -1, y: 1)
                    .rotationEffect(.degrees(14))
                    .position(x: w * 0.82, y: h * 0.58)
                // Torch — driftwood shaft plus a live flame.
                Torch(width: w * 0.14, height: h * 0.90)
                    .position(x: w / 2, y: h * 0.55)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Tall driftwood shaft with three ink bindings and a flame + halo above.
struct Torch: View {
    let width: CGFloat
    let height: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shaftW = width
        let shaftH = height * 0.55
        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(P.driftwood.color)
                .frame(width: shaftW, height: shaftH)
                .offset(y: (height - shaftH) / 2)
            ForEach([0.2, 0.5, 0.8], id: \.self) { fraction in
                Rectangle()
                    .fill(P.ink.color.opacity(0.65))
                    .frame(width: shaftW, height: 2)
                    .offset(y: (height - shaftH) / 2 - shaftH / 2 + shaftH * fraction)
            }
            flame
        }
    }

    @ViewBuilder
    private var flame: some View {
        let flameW = width * 2.4
        let flameH = height * 0.42
        let y = height * 0.03
        if reduceMotion {
            FlameGlyph()
                .fill(flameFill)
                .frame(width: flameW, height: flameH)
                .offset(y: y)
                .shadow(color: P.torch.color.opacity(0.55), radius: 8, y: 2)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: false)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let scale = 1 + 0.10 * sin(t * 8.3) + 0.05 * sin(t * 15.7)
                let lean = 2 * sin(t * 6.1) + 1.2 * sin(t * 15)
                FlameGlyph()
                    .fill(flameFill)
                    .frame(width: flameW, height: flameH)
                    .scaleEffect(x: 1, y: scale, anchor: .bottom)
                    .rotationEffect(.degrees(lean), anchor: .bottom)
                    .offset(y: y)
                    .shadow(color: P.torch.color.opacity(0.55), radius: 8, y: 2)
            }
        }
    }

    private var flameFill: LinearGradient {
        LinearGradient(
            colors: [P.blossom.color, P.torch.color, P.coral.color, P.rum.color],
            startPoint: .top, endPoint: .bottom
        )
    }
}

/// Teardrop-shaped flame path scaled to a 1×1 unit box.
struct FlameGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addCurve(
            to: CGPoint(x: w, y: h * 0.7),
            control1: CGPoint(x: w * 0.85, y: h * 0.2),
            control2: CGPoint(x: w * 0.95, y: h * 0.45)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w, y: h * 0.9),
            control2: CGPoint(x: w * 0.75, y: h)
        )
        p.addCurve(
            to: CGPoint(x: 0, y: h * 0.7),
            control1: CGPoint(x: w * 0.25, y: h),
            control2: CGPoint(x: 0, y: h * 0.9)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: w * 0.05, y: h * 0.45),
            control2: CGPoint(x: w * 0.15, y: h * 0.2)
        )
        p.closeSubpath()
        return p
    }
}

/// A tiny frond silhouette — three stroked veins on a deep leaf base.
/// Used at both bottom corners of the crest to frame the torch.
struct CornerFrondSprite: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.15, y: 0),
                        control: CGPoint(x: w * 0.1, y: h * 0.55)
                    )
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.5, y: h),
                        control: CGPoint(x: w * 0.85, y: h * 0.5)
                    )
                }
                .fill(P.deepLeaf.color)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.5, y: h))
                    p.addQuadCurve(
                        to: CGPoint(x: w * 0.2, y: h * 0.05),
                        control: CGPoint(x: w * 0.2, y: h * 0.55)
                    )
                }
                .stroke(P.palmLeaf.color, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            }
        }
    }
}

