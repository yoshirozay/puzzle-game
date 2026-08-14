import SwiftUI

// MARK: - Banner crest (the card's face)

/// The leaderboard banner's media-window scene — the rail's only non-game
/// card. A torch-lit trophy over the night sky, pennants strung across the
/// top, and the three games' crests racked on a podium below: the picker
/// card as a shop window for "the boards".
///
/// Same duty as LoungeTorchCrest on the old lounge card: designed art, no
/// AVPlayer, inherently Reduce Motion / Low Power safe (the only motion is
/// a slow shimmer + star twinkle, both stilled under Reduce Motion).
struct LeaderboardBannerCrest: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
                let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    // Night sky — ink into twilight, like the boards' own hour.
                    LinearGradient(
                        colors: [P.ink.color, P.twilight.lerp(P.ink, 0.35).color],
                        startPoint: .top, endPoint: .bottom
                    )
                    stars(w: w, h: h, t: t)
                    pennants(w: w, h: h)
                    trophyGlow(w: w, h: h)
                    trophy(w: w, h: h, t: t)
                    shelf(w: w, h: h)
                    podium(w: w, h: h)
                }
            }
        }
    }

    // MARK: sky

    /// Fixed star field (hashed positions, no RNG at render) with a slow
    /// per-star twinkle.
    private func stars(w: CGFloat, h: CGFloat, t: Double) -> some View {
        Canvas { ctx, _ in
            let pts: [(Double, Double, Double)] = [
                (0.12, 0.06, 1.6), (0.30, 0.11, 1.1), (0.52, 0.05, 1.4),
                (0.71, 0.09, 1.1), (0.88, 0.14, 1.6), (0.20, 0.19, 1.1),
                (0.62, 0.17, 1.2), (0.80, 0.23, 1.0), (0.09, 0.27, 1.2),
                (0.41, 0.24, 1.5), (0.93, 0.31, 1.1), (0.26, 0.33, 1.0),
            ]
            for (i, p) in pts.enumerated() {
                let tw = 0.55 + 0.45 * sin(t * 0.8 + Double(i) * 1.7)
                let r = p.2
                ctx.fill(
                    Path(ellipseIn: CGRect(x: p.0 * w - r, y: p.1 * h - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(P.cream.color.opacity(0.30 + 0.45 * tw))
                )
            }
        }
    }

    /// A sagging string of pennants across the sky — the house "earned"
    /// motif (Cipher hangs one per matchbook; here they dress the boards).
    private func pennants(w: CGFloat, h: CGFloat) -> some View {
        Canvas { ctx, _ in
            let y0 = h * 0.055, sag = h * 0.045
            func hang(_ u: Double) -> CGPoint {
                CGPoint(x: u * w, y: y0 + sag * sin(.pi * u))
            }
            var string = Path()
            string.move(to: hang(0))
            for u in stride(from: 0.05, through: 1.0, by: 0.05) {
                string.addLine(to: hang(u))
            }
            ctx.stroke(string, with: .color(P.cream.color.opacity(0.55)), lineWidth: 1.5)
            let colors: [RGB] = [P.coral, P.torch, P.cream, P.lagoonTeal, P.torch, P.coral]
            for (i, u) in [0.10, 0.26, 0.42, 0.58, 0.74, 0.90].enumerated() {
                let a = hang(u - 0.045), b = hang(u + 0.045)
                let tip = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + h * 0.052)
                var tri = Path()
                tri.move(to: a); tri.addLine(to: b); tri.addLine(to: tip); tri.closeSubpath()
                ctx.fill(tri, with: .color(colors[i].color))
                ctx.stroke(tri, with: .color(P.ink.color), lineWidth: 1)
            }
        }
    }

    // MARK: trophy

    private func trophyGlow(w: CGFloat, h: CGFloat) -> some View {
        RadialGradient(
            colors: [P.torch.color.opacity(0.30), .clear],
            center: .center, startRadius: 2, endRadius: w * 0.42
        )
        .frame(width: w * 0.9, height: w * 0.9)
        .position(x: w / 2, y: h * 0.335)
    }

    /// Canvas-drawn cup — torch gold, ink stroked, with a slow specular
    /// sweep so the gold reads as metal rather than paint. Path builders
    /// live in `TrophyPaths` — one big Canvas closure chokes the type
    /// checker.
    private func trophy(w: CGFloat, h: CGFloat, t: Double) -> some View {
        let g = TrophyPaths(cx: w / 2, cy: h * 0.335, cw: w * 0.34)
        return Canvas { ctx, _ in
            for side in [CGFloat(-1), 1] {
                let handle = g.handle(side: side)
                ctx.stroke(handle, with: .color(P.ink.color),
                           style: StrokeStyle(lineWidth: g.cw * 0.10 + 3))
                ctx.stroke(handle, with: .color(P.torch.color), lineWidth: g.cw * 0.10)
            }
            for p in [g.cup, g.stem, g.base] {
                ctx.fill(p, with: .color(P.torch.color))
                ctx.stroke(p, with: .color(P.ink.color), lineWidth: 2)
            }
            ctx.fill(g.star, with: .color(P.ember.color.opacity(0.85)))
            ctx.clip(to: g.cup)
            ctx.fill(g.sweepBand(t: t), with: .color(P.blossom.color.opacity(0.35)))
        }
    }

    /// The trophy's geometry, precomputed as Paths so the Canvas closure
    /// stays trivially type-checkable.
    private struct TrophyPaths {
        let cx: CGFloat
        let cy: CGFloat
        let cw: CGFloat

        /// Bowl: wide lip narrowing into a waist.
        var cup: Path {
            var p = Path()
            p.move(to: CGPoint(x: cx - cw / 2, y: cy - cw * 0.42))
            p.addLine(to: CGPoint(x: cx + cw / 2, y: cy - cw * 0.42))
            p.addCurve(
                to: CGPoint(x: cx + cw * 0.10, y: cy + cw * 0.34),
                control1: CGPoint(x: cx + cw / 2, y: cy + cw * 0.10),
                control2: CGPoint(x: cx + cw * 0.30, y: cy + cw * 0.30)
            )
            p.addLine(to: CGPoint(x: cx - cw * 0.10, y: cy + cw * 0.34))
            p.addCurve(
                to: CGPoint(x: cx - cw / 2, y: cy - cw * 0.42),
                control1: CGPoint(x: cx - cw * 0.30, y: cy + cw * 0.30),
                control2: CGPoint(x: cx - cw / 2, y: cy + cw * 0.10)
            )
            p.closeSubpath()
            return p
        }

        func handle(side: CGFloat) -> Path {
            var p = Path()
            p.addArc(
                center: CGPoint(x: cx + side * (cw / 2 + cw * 0.13), y: cy - cw * 0.16),
                radius: cw * 0.20,
                startAngle: .degrees(side > 0 ? -70 : 250),
                endAngle: .degrees(side > 0 ? 110 : 70),
                clockwise: side < 0
            )
            return p
        }

        var stem: Path {
            Path(CGRect(x: cx - cw * 0.05, y: cy + cw * 0.34,
                        width: cw * 0.10, height: cw * 0.16))
        }

        var base: Path {
            Path(roundedRect: CGRect(x: cx - cw * 0.24, y: cy + cw * 0.50,
                                     width: cw * 0.48, height: cw * 0.13),
                 cornerRadius: 3)
        }

        /// Engraved five-point star on the bowl.
        var star: Path {
            let sr = cw * 0.10
            var p = Path()
            for i in 0..<5 {
                let a = Double(i) * 4 * .pi / 5 - .pi / 2
                let pt = CGPoint(x: cx + cos(a) * sr, y: cy - cw * 0.05 + sin(a) * sr)
                if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            p.closeSubpath()
            return p
        }

        /// The specular band gliding across the bowl.
        func sweepBand(t: Double) -> Path {
            let sweep = (t * 0.22).truncatingRemainder(dividingBy: 1)
            let sx = cx - cw / 2 + CGFloat(sweep) * cw
            var p = Path()
            p.move(to: CGPoint(x: sx - cw * 0.06, y: cy - cw * 0.42))
            p.addLine(to: CGPoint(x: sx + cw * 0.06, y: cy - cw * 0.42))
            p.addLine(to: CGPoint(x: sx - cw * 0.02, y: cy + cw * 0.30))
            p.addLine(to: CGPoint(x: sx - cw * 0.14, y: cy + cw * 0.30))
            p.closeSubpath()
            return p
        }
    }

    private func shelf(w: CGFloat, h: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(P.driftwood.color)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(P.ink.color, lineWidth: 1.5))
            .frame(width: w * 0.62, height: 7)
            .position(x: w / 2, y: h * 0.475)
    }

    // MARK: podium

    /// Three podium blocks carrying the three games' crests — Luau on the
    /// tall center step, flanked by Totem and Top Shelf. "The boards" as
    /// one picture.
    private func podium(w: CGFloat, h: CGFloat) -> some View {
        let blockW = w * 0.26
        let baseY = h * 0.88
        let heights: [CGFloat] = [h * 0.135, h * 0.20, h * 0.105]
        let xs: [CGFloat] = [w * 0.24, w * 0.50, w * 0.76]
        let icons: [Image] = [.tikiStacksIcon, .luauIcon, .zombieIcon]
        let ranks = ["2", "1", "3"]
        return ZStack {
            ForEach(0..<3, id: \.self) { i in
                let bh = heights[i]
                RoundedRectangle(cornerRadius: 6)
                    .fill(P.plank.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(P.ink.color, lineWidth: 2)
                    )
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(P.driftwood.color)
                            .frame(height: 5)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .padding(.horizontal, 2)
                            .padding(.top, 2)
                    }
                    .overlay {
                        Text(ranks[i])
                            .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                            .foregroundStyle(P.cream.color.opacity(0.55))
                    }
                    .frame(width: blockW, height: bh)
                    .position(x: xs[i], y: baseY - bh / 2)
                icons[i]
                    .resizable()
                    .scaledToFit()
                    .frame(width: blockW * 0.78)
                    .position(x: xs[i], y: baseY - bh - blockW * 0.28)
            }
        }
    }
}

// MARK: - Boards chooser (full-screen overlay)

/// The banner's landing: pick which game's board to open. Each row is a
/// window into that board's own world — the LeaderboardTheme backdrop,
/// miniature — with the game's crest and your ranked number on it. House
/// panel idiom throughout (ink dim, plank chrome, Futura caps).
struct LeaderboardPickerPanel: View {
    @Environment(PlayerStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onPick: (TikiGame) -> Void
    let onDismiss: () -> Void

    @State private var entered = false
    /// Local player's rank per board, filled async as standings land.
    /// Missing key = still loading, not ranked, or signed out — the row
    /// falls back to the trophy mark.
    @State private var ranks: [TikiGame: Int] = [:]

    /// The board's own metric, named in its own voice.
    private static func metricLabel(_ g: TikiGame) -> String {
        switch g {
        case .luau: return "ALL NIGHTS"
        case .zombie: return "BEST BAR"
        default: return "BEST SCORE"
        }
    }

    /// How far down each theme's 700pt scene the row's window sits — each
    /// backdrop keeps its signature band in frame (Luau's lantern glow,
    /// Totem's lagoon, Top Shelf's racked bottles), not its empty sky.
    private static func sceneWindowOffset(_ g: TikiGame) -> CGFloat {
        switch g {
        case .luau: return -210
        case .tikiStacks: return -240
        default: return 0
        }
    }

    var body: some View {
        ZStack {
            P.ink.color.opacity(0.60)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            VStack(spacing: 16) {
                VStack(spacing: 5) {
                    Text("LEADERBOARDS")
                        .font(.custom("Futura-Bold", size: 22, relativeTo: .title2))
                        .tracking(3)
                        .foregroundStyle(P.blossom.color)
                    Text("PICK A BOARD")
                        .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.cream.color.opacity(0.75))
                }
                .padding(.top, 26)

                VStack(spacing: 12) {
                    ForEach(TikiGame.pickerOrder) { game in
                        boardRow(game)
                    }
                }
                .padding(.horizontal, 18)

                Button(action: onDismiss) {
                    Text("BACK")
                        .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                        .tracking(3)
                        .foregroundStyle(P.cream.color)
                        .padding(.horizontal, 34)
                        .frame(height: 44)
                        .background(Capsule().fill(P.shadowBrown.color))
                        .overlay(Capsule().stroke(P.ink.color, lineWidth: 2))
                }
                .buttonStyle(SoftPressStyle())
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: 400)
            .background {
                RoundedRectangle(cornerRadius: 28)
                    .fill(P.plank.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 23)
                            .stroke(P.woodDark.color, lineWidth: 2)
                            .padding(6)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(P.ink.color, lineWidth: 2.5))
            }
            .padding(.horizontal, 20)
            .scaleEffect(entered ? 1 : 0.92)
            .opacity(entered ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.8)) {
                entered = true
            }
            loadRanks()
        }
    }

    /// One standings round per board (60s-cached in GameCenter), each
    /// filling its row's chip as it lands. Signed-out or failed loads
    /// leave the trophy fallback in place — the chooser never blocks on
    /// the network.
    private func loadRanks() {
        guard GameCenter.shared.isAuthenticated else { return }
        for game in TikiGame.pickerOrder {
            Task { @MainActor in
                guard let standings = try? await GameCenter.shared.loadStandings(for: game),
                      let mine = standings.local else { return }
                withAnimation(.easeOut(duration: 0.2)) { ranks[game] = mine.rank }
            }
        }
    }

    /// One board's door: its world in a letterboxed window, crest + name +
    /// your number riding a legibility scrim.
    @ViewBuilder
    private func boardRow(_ game: TikiGame) -> some View {
        if let theme = LeaderboardTheme.theme(for: game) {
            Button {
                onPick(game)
            } label: {
                ZStack(alignment: .leading) {
                    // The theme's full scene rendered at phone logical size,
                    // scaled into the row — a miniature of the real board's
                    // backdrop, not a recolor.
                    GeometryReader { geo in
                        theme.backdrop()
                            .frame(width: 390, height: 700)
                            .offset(y: Self.sceneWindowOffset(game))
                            .scaleEffect(geo.size.width / 390, anchor: .top)
                            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                            .allowsHitTesting(false)
                    }
                    .clipped()
                    LinearGradient(
                        colors: [P.ink.color.opacity(0.72), P.ink.color.opacity(0.18), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                    HStack(spacing: 12) {
                        game.icon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(game.displayName.uppercased())
                                .font(.custom("Futura-Bold", size: 16, relativeTo: .body))
                                .tracking(2)
                                .foregroundStyle(P.blossom.color)
                            let score = store.leaderboardScore(for: game)
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(Self.metricLabel(game))
                                    .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                                    .tracking(2)
                                    .foregroundStyle(P.torch.color)
                                Text(score > 0 ? score.formatted(.number.grouping(.automatic)) : "—")
                                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                                    .foregroundStyle(P.cream.color)
                            }
                        }
                        Spacer()
                        // Your rank on this board, once standings land.
                        // Until then (or signed out / never charted) the
                        // trophy mark holds the corner.
                        if let rank = ranks[game] {
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("#")
                                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                                    .foregroundStyle(P.torch.color)
                                Text("\(rank)")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(P.blossom.color)
                            }
                            .padding(.horizontal, 11)
                            .frame(height: 30)
                            .background(Capsule().fill(P.ink.color.opacity(0.55)))
                            .overlay(Capsule().stroke(P.cream.color.opacity(0.35), lineWidth: 1.5))
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                        } else {
                            ZStack {
                                Circle()
                                    .fill(P.ink.color.opacity(0.55))
                                    .overlay(Circle().stroke(P.cream.color.opacity(0.35), lineWidth: 1.5))
                                Image.iconTrophy.resizable().scaledToFit().frame(height: 15)
                            }
                            .frame(width: 30, height: 30)
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .frame(height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(P.ink.color, lineWidth: 2.5))
                .contentShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel(
                ranks[game].map { "\(game.displayName) leaderboard, you are ranked number \($0)" }
                    ?? "\(game.displayName) leaderboard"
            )
        }
    }
}

#Preview("Banner crest") {
    LeaderboardBannerCrest()
        .frame(width: 300, height: 615)
        .clipShape(RoundedRectangle(cornerRadius: 14))
}

#Preview("Boards chooser") {
    LeaderboardPickerPanel(onPick: { _ in }, onDismiss: {})
        .environment(PlayerStore(inMemory: true))
}
