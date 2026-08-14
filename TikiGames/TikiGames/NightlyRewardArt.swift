import SwiftUI

// MARK: - Tonight's pour, drawn

/// The three faces of tonight's pour. Drawn once here so the board's prize
/// plaque and the world-space float can never disagree about what the player
/// is playing for — and so the payoff is a picture, not the word "reward".
///
/// Art only: callers own the frame and any backing.
struct NightlyRewardGlyph: View {
    let reward: PlayerStore.NightlyReward

    var body: some View {
        switch reward {
        case .item(.luau):
            Image.luauSpecialCat
                .resizable()
                .scaledToFit()
        case .item:
            DepthChargeGlyph()
        case .points(let amount):
            PointsCoinGlyph(amount: amount)
        }
    }
}

/// THE TOP SHELF's depth charge, drawn: a fused round charge with a lit
/// fuse. The game's own chip still wears an SF `burst.fill`.
///
/// A banded canister was tried first and read as a birthday cake at 38 pt —
/// squat body, fat candle-stub neck, blunt flame. The silhouette that
/// survives the squint is the round one, and the torch rim is load-bearing:
/// an ink body sits on a dark slate plaque and a dark coral wall alike, so
/// the glyph has to carry its own edge.
struct DepthChargeGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let r = s * 0.32
            let cx = geo.size.width / 2
            let cy = geo.size.height - r - s * 0.07
            let fuseTip = CGPoint(x: cx + r * 1.22, y: cy - r * 1.55)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: cx + r * 0.42, y: cy - r * 0.82))
                    p.addQuadCurve(to: fuseTip,
                                   control: CGPoint(x: cx + r * 1.34, y: cy - r * 0.86))
                }
                .stroke(P.driftwood.color,
                        style: StrokeStyle(lineWidth: max(1.5, s * 0.07), lineCap: .round))
                Circle()
                    .fill(P.ink.color)
                    .overlay(Circle().stroke(P.torch.color, lineWidth: max(1.5, s * 0.055)))
                    .frame(width: r * 2, height: r * 2)
                    .position(x: cx, y: cy)
                // Specular — the one mark that says "round" at 20 px.
                Ellipse()
                    .fill(P.cream.color.opacity(0.45))
                    .frame(width: r * 0.60, height: r * 0.40)
                    .rotationEffect(.degrees(-32))
                    .position(x: cx - r * 0.36, y: cy - r * 0.40)
                FlameGlyph()
                    .fill(LinearGradient(
                        colors: [P.blossom.color, P.torch.color, P.coral.color],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: s * 0.20, height: s * 0.28)
                    .position(x: fuseTip.x, y: fuseTip.y - s * 0.12)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

/// The wallet pour, with its number on it. The old float drew a bare gold
/// disc and left the amount to a caption 400 pt away.
struct PointsCoinGlyph: View {
    let amount: Int
    private let gold = Color(red: 0.910, green: 0.702, blue: 0.235)

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(gold)
                    .overlay(Circle().stroke(P.ink.color, lineWidth: max(1.5, d * 0.075)))
                    .overlay(
                        Circle()
                            .stroke(P.blossom.color.opacity(0.55), lineWidth: max(1, d * 0.035))
                            .padding(d * 0.14)
                    )
                Text("+\(amount)")
                    .font(.custom("Futura-Bold", size: d * 0.34))
                    .tracking(0.5)
                    .foregroundStyle(P.ink.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, d * 0.18)
            }
            .frame(width: d, height: d)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

// MARK: - House voice

extension PlayerStore.NightlyReward {
    /// What it is — the headline of both the plaque and the pour caption.
    var pourName: String {
        switch self {
        case .item(.zombie): return "DEPTH CHARGE"
        case .item: return "LOUNGE CAT"
        case .points(let n): return "+\(n) POINTS"
        }
    }

    /// The pour caption, one line. It hangs in the band of wall the REWARD
    /// READY banner just vacated — ~47 pt tall — so it gets one line and no
    /// more. Where the comp actually lands is the announcement's job.
    var pourCaption: String { "ON THE HOUSE — \(pourName)" }

    /// VoiceOver reads sentences, not signage.
    var pourAnnouncement: String {
        switch self {
        case .item(.zombie): return "On the house — a Depth Charge for the Top Shelf"
        case .item: return "On the house — a Lounge Cat for the Luau"
        case .points(let n): return "On the house — \(n) points for the wallet"
        }
    }
}

// MARK: - Drawn tick

/// The board's check mark, drawn rather than borrowed from SF Symbols —
/// every other mark in this app is a `Path`, and the board was the one
/// surface still speaking iOS.
struct BoardTick: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.20, y: h * 0.52))
        p.addLine(to: CGPoint(x: w * 0.42, y: h * 0.74))
        p.addLine(to: CGPoint(x: w * 0.80, y: h * 0.26))
        return p
    }
}

#Preview {
    ZStack {
        P.woodDark.color.ignoresSafeArea()
        HStack(spacing: 24) {
            NightlyRewardGlyph(reward: .item(.luau)).frame(width: 64, height: 64)
            NightlyRewardGlyph(reward: .item(.zombie)).frame(width: 64, height: 64)
            NightlyRewardGlyph(reward: .points(50)).frame(width: 64, height: 64)
            BoardTick()
                .stroke(P.torch.color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .frame(width: 30, height: 30)
        }
    }
}
