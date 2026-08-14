import SwiftUI

/// Cabana Cipher's win flourish — the moment the last letter lands, a golden
/// wave chases the flip front across the phrase: each tile hops with a gold
/// glint in phrase order while spark stars pop up around the board. The
/// CRACKED panel waits for the wave (CipherWinTiming.panelDelay is the single
/// source of truth, same contract as the defeat reveal's timing block).
///
/// House rules honoured: self-clocking components on a shared show clock
/// (`fxSleep`, the Luau FX pattern — a main-thread hitch shifts the whole
/// show together), flat P-palette fills, deterministic sparkle placement
/// (captures must repro), Reduce Motion swaps motion for a soft in-place glow.

enum CipherWinTiming {
    /// The wave front trails each tile's flip by this much, so the hop lands
    /// on the flip's heel — continuous motion, not a second show.
    static let waveLead = 0.42
    /// Per-tile sweep rate. CipherView's flip stagger reads THIS value, so
    /// the wave and the cascade can never drift apart.
    static let stagger = 0.025
    /// One tile's hop + glint, start to settle.
    static let hopSpan = 0.55
    /// When the CRACKED panel may land: last hop settles, sparkle tail dies.
    static func panelDelay(letters: Int, reduceMotion: Bool) -> Double {
        reduceMotion
            ? 0.6
            : min(2.2, waveLead + Double(max(0, letters - 1)) * stagger + hopSpan + 0.2)
    }
}

/// Per-tile wave beat: a hop with a gold glint, fired `waveLead + order ·
/// stagger` after the winning guess. `start == nil` is the resting state —
/// flipping it back (next phrase) resets the tile instantly, and `.task(id:)`
/// cancels mid-show on view exit.
struct CipherTileWinWave: ViewModifier {
    let start: Date?
    let order: Int
    let side: CGFloat
    let reduceMotion: Bool
    @State private var lift = false
    @State private var glow = false

    func body(content: Content) -> some View {
        content
            .overlay {
                // The glint: a flat torch-gold wash over the whole tile,
                // letter included — light passing across, not a new layer.
                RoundedRectangle(cornerRadius: side * 0.18)
                    .fill(P.torch.color)
                    .opacity(glow ? 0.45 : 0)
                    .allowsHitTesting(false)
            }
            .offset(y: lift ? -side * 0.28 : 0)
            .task(id: start) {
                guard let start else {
                    lift = false
                    glow = false
                    return
                }
                if reduceMotion {
                    // One soft simultaneous glow — no hop, no stagger.
                    await fxSleep(until: start, plus: 0.05)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeIn(duration: 0.2)) { glow = true }
                    try? await Task.sleep(for: .seconds(0.3))
                    withAnimation(.easeOut(duration: 0.35)) { glow = false }
                    return
                }
                await fxSleep(until: start,
                              plus: CipherWinTiming.waveLead + Double(order) * CipherWinTiming.stagger)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.26, bounce: 0.55)) { lift = true }
                withAnimation(.easeIn(duration: 0.12)) { glow = true }
                try? await Task.sleep(for: .seconds(0.14))
                guard !Task.isCancelled else { return }
                withAnimation(.spring(duration: 0.38, bounce: 0.34)) { lift = false }
                withAnimation(.easeOut(duration: 0.4)) { glow = false }
            }
    }
}

/// Classic four-point twinkle — pinched-waist star, the ✦ the cipher key
/// already uses as a symbol, now in the flesh.
struct SparkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let waist = r * 0.18
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y),
                       control: CGPoint(x: c.x + waist, y: c.y - waist))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r),
                       control: CGPoint(x: c.x + waist, y: c.y + waist))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y),
                       control: CGPoint(x: c.x - waist, y: c.y + waist))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r),
                       control: CGPoint(x: c.x - waist, y: c.y - waist))
        p.closeSubpath()
        return p
    }
}

/// Spark stars scattered over the phrase block, popping in sweep order with
/// the wave. Mounted as an overlay on the tile container; positions are
/// fractions of that container, hashed deterministically per (phrase, spark)
/// so a given solve always throws the same stars.
struct CipherWinSparkles: View {
    let start: Date
    let letters: Int
    let seed: Int
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geo in
            // Reduce Motion: the glow beat carries the win alone — popping
            // stars are exactly the transient motion the setting opts out of.
            if !reduceMotion {
                ForEach(0..<count, id: \.self) { i in
                    let fx = h(i, 1)
                    WinSparkle(
                        start: start,
                        at: CGPoint(x: (0.02 + 0.96 * fx) * geo.size.width,
                                    y: (-0.3 + 1.5 * h(i, 2)) * geo.size.height),
                        delay: CipherWinTiming.waveLead
                            + fx * Double(letters) * CipherWinTiming.stagger
                            + h(i, 5) * 0.12,
                        size: 8 + h(i, 3) * 9,
                        tint: tint(h(i, 4))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Enough stars to read as a shower without carpeting short phrases.
    private var count: Int { min(16, max(10, letters * 2 / 3)) }

    /// Mostly gold, some cream-white, the odd coral — the torch-flame mix.
    private func tint(_ f: Double) -> Color {
        f < 0.18 ? P.coral.color : (f < 0.5 ? P.blossom.color : P.torch.color)
    }

    /// Deterministic per (phrase, sparkle, channel) — no RNG, captures repro.
    private func h(_ i: Int, _ salt: Int) -> Double {
        abs((sin(Double(seed &* 97 &+ i &* 127 &+ salt &* 311)) * 43758.5453)
            .truncatingRemainder(dividingBy: 1))
    }
}

/// One spark: pops in with a twist, holds a beat, then shrinks, drifts up,
/// and dies. Invisible until its scheduled moment (the CellBurst contract).
private struct WinSparkle: View {
    let start: Date
    let at: CGPoint
    let delay: Double
    let size: CGFloat
    let tint: Color
    @State private var armed = false
    @State private var shown = false
    @State private var gone = false

    var body: some View {
        SparkShape()
            .fill(tint)
            .frame(width: size, height: size)
            .scaleEffect(!shown ? 0.15 : (gone ? 0.3 : 1))
            .rotationEffect(.degrees(!shown ? -50 : (gone ? 25 : 8)))
            .opacity(!armed ? 0 : (gone ? 0 : 0.95))
            .position(x: at.x, y: at.y - (gone ? size * 0.9 : 0))
            .task {
                await fxSleep(until: start, plus: delay)
                guard !Task.isCancelled else { return }
                armed = true
                withAnimation(.spring(duration: 0.2, bounce: 0.4)) { shown = true }
                try? await Task.sleep(for: .seconds(0.24))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.32)) { gone = true }
            }
    }
}
