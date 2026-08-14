import SwiftUI

/// A game's leaderboard wardrobe: its scene, its trophy shapes, its voice.
/// LeaderboardView renders the shared skeleton; everything a player would
/// call "the <game>'s board" lives here. MainActor because the stored
/// closures build views — themes are UI config, only ever touched from UI.
@MainActor
struct LeaderboardTheme {
    let game: TikiGame
    let title: String
    let subtitle: String
    let loadingLine: String
    let emptyTitle: String
    let emptyLine: String
    let signedOutLine: String
    let joinLine: String
    let footerSuffix: String
    let backdrop: () -> AnyView
    /// (slot, width, height) → trophy art; slot 0 = champion, 1 = second,
    /// 2 = third. Sized by the caller, stroked in ink like everything else.
    let podiumArt: (Int, CGFloat, CGFloat) -> AnyView
    let tierColor: (Int) -> Color

    static func theme(for game: TikiGame) -> LeaderboardTheme? {
        guard GameCenter.leaderboardID(for: game) != nil else { return nil }
        switch game {
        case .tikiStacks: return .totem
        case .zombie: return .topShelf
        case .luau: return .luau
        case .cabanaCipher: return .cipher
        case .blueprints: return .blueprints
        case .navigator: return .navigator
        }
    }
}

// MARK: - The six wardrobes

extension LeaderboardTheme {
    /// Totem: carved heads on the night lagoon, scores wearing the game's
    /// own depth ladder (DUSK / NIGHTFALL / MOONRISE / GLOW TIDE).
    static let totem = LeaderboardTheme(
        game: .tikiStacks,
        title: "LEADERBOARD",
        subtitle: "TOTEM · ALL TIME",
        loadingLine: "LOADING LEADERBOARD…",
        emptyTitle: "NO STACKERS YET",
        emptyLine: "BE THE FIRST ON THE LEADERBOARD",
        signedOutLine: "SIGN IN TO GAME CENTER\nTO SEE THE WORLD'S STACKS",
        joinLine: "STACK A RUN TO JOIN THE LEADERBOARD",
        footerSuffix: "MORE ON THE LEADERBOARD",
        backdrop: { AnyView(TikiBackgroundView(phase: ProgressPhase(stage: 3, depth: 1))) },
        podiumArt: { slot, w, h in
            let faces: [RGB] = [P.coral, P.driftwood, P.plank]
            return AnyView(TotemHeadArt(face: faces[slot], w: w, h: h))
        },
        tierColor: { score in
            let t = TikiStacksGame.depthThresholds
            if score >= t[3] { return P.bioGlow.color }
            if score >= t[2] { return P.torch.color }
            if score >= t[1] { return P.lagoonTeal.lerp(P.blossom, 0.45).color }
            return P.sunsetMid.color
        }
    )

    /// Top Shelf: the best pours racked as bottles on the back-bar shelf.
    static let topShelf = LeaderboardTheme(
        game: .zombie,
        title: "LEADERBOARD",
        subtitle: "TOP SHELF · ALL TIME",
        loadingLine: "LOADING LEADERBOARD…",
        emptyTitle: "NO POURS YET",
        emptyLine: "BE THE FIRST ON THE LEADERBOARD",
        signedOutLine: "SIGN IN TO GAME CENTER\nTO SEE THE WORLD'S POURS",
        joinLine: "MIX A RUN TO JOIN THE LEADERBOARD",
        footerSuffix: "MORE ON THE LEADERBOARD",
        backdrop: { AnyView(ZombieBackgroundView(phase: ProgressPhase(stage: 3, depth: 1))) },
        podiumArt: { slot, w, h in
            let bodies: [RGB] = [P.coral, P.olive, P.driftwood]
            return AnyView(BottleArt(body: bodies[slot], w: w, h: h))
        },
        tierColor: { _ in P.torch.color }
    )

    /// Luau: the brightest parties strung up as party lanterns.
    static let luau = LeaderboardTheme(
        game: .luau,
        title: "LEADERBOARD",
        subtitle: "LUAU · ALL TIME",
        loadingLine: "LOADING LEADERBOARD…",
        emptyTitle: "NO LANTERNS LIT",
        emptyLine: "BE THE FIRST ON THE LEADERBOARD",
        signedOutLine: "SIGN IN TO GAME CENTER\nTO SEE THE WORLD'S PARTIES",
        joinLine: "CLEAR A NIGHT TO JOIN THE LEADERBOARD",
        footerSuffix: "MORE ON THE LEADERBOARD",
        backdrop: { AnyView(LuauBackgroundView(phase: ProgressPhase(stage: 3, depth: 1))) },
        podiumArt: { slot, w, h in
            let glows: [RGB] = [P.torch, P.coral, P.olive]
            return AnyView(LanternArt(glow: glows[slot], w: w, h: h))
        },
        tierColor: { _ in P.coral.color }
    )

    /// Cabana Cipher: solved ciphers pinned up as matchbooks on the wall.
    static let cipher = LeaderboardTheme(
        game: .cabanaCipher,
        title: "LEADERBOARD",
        subtitle: "CABANA CIPHER · ALL TIME",
        loadingLine: "LOADING LEADERBOARD…",
        emptyTitle: "NO MATCHES STRUCK",
        emptyLine: "BE THE FIRST ON THE LEADERBOARD",
        signedOutLine: "SIGN IN TO GAME CENTER\nTO SEE THE WORLD'S CIPHERS",
        joinLine: "SOLVE A PHRASE TO JOIN THE LEADERBOARD",
        footerSuffix: "MORE ON THE LEADERBOARD",
        backdrop: { AnyView(CipherBackgroundView(phase: ProgressPhase(stage: 3, depth: 1))) },
        podiumArt: { slot, w, h in
            let covers: [RGB] = [P.coral, P.lagoon, P.rum]
            return AnyView(MatchbookArt(cover: covers[slot], w: w, h: h))
        },
        tierColor: { _ in P.sunsetMid.color }
    )

    /// Blueprints: the finest drafts pinned to the drafting wall.
    static let blueprints = LeaderboardTheme(
        game: .blueprints,
        title: "LEADERBOARD",
        subtitle: "BLUEPRINTS · ALL TIME",
        loadingLine: "LOADING LEADERBOARD…",
        emptyTitle: "NO DRAFTS PINNED",
        emptyLine: "BE THE FIRST ON THE LEADERBOARD",
        signedOutLine: "SIGN IN TO GAME CENTER\nTO SEE THE WORLD'S DRAFTS",
        joinLine: "DRAFT A PUZZLE TO JOIN THE LEADERBOARD",
        footerSuffix: "MORE ON THE LEADERBOARD",
        backdrop: { AnyView(BlueprintsBackgroundView(phase: ProgressPhase(stage: 3, depth: 1))) },
        podiumArt: { slot, w, h in
            let sheets: [RGB] = [P.lagoonTeal, P.lagoon, P.deepLeaf]
            return AnyView(DraftSheetArt(sheet: sheets[slot], w: w, h: h))
        },
        tierColor: { _ in P.lagoonTeal.lerp(P.blossom, 0.45).color }
    )

    /// Navigator: the longest voyages etched into the star chart.
    /// Scores here are TOTAL PASSAGES in one run, not points.
    static let navigator = LeaderboardTheme(
        game: .navigator,
        title: "LEADERBOARD",
        subtitle: "NAVIGATOR · PASSAGES",
        loadingLine: "LOADING LEADERBOARD…",
        emptyTitle: "NO VOYAGES CHARTED",
        emptyLine: "BE THE FIRST ON THE LEADERBOARD",
        signedOutLine: "SIGN IN TO GAME CENTER\nTO SEE THE WORLD'S VOYAGES",
        joinLine: "SAIL A VOYAGE TO JOIN THE LEADERBOARD",
        footerSuffix: "MORE ON THE LEADERBOARD",
        backdrop: { AnyView(NavigatorBackgroundView(phase: ProgressPhase(stage: 3, depth: 1))) },
        podiumArt: { slot, w, h in
            let cores: [RGB] = [P.blossom, P.bioGlow, P.torch]
            return AnyView(StarArt(core: cores[slot], w: w, h: h))
        },
        tierColor: { _ in P.bioGlow.color }
    )
}

// MARK: - Podium art (flat shapes, chunky ink — the house grammar)

/// Totem: the carved head from the original Totem Pole board.
private struct TotemHeadArt: View {
    let face: RGB
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(face.color)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.ink.color, lineWidth: 2.5))
            VStack(spacing: h * 0.14) {
                HStack(spacing: w * 0.18) {
                    Capsule().fill(P.ink.color).frame(width: w * 0.17, height: h * 0.17)
                    Capsule().fill(P.ink.color).frame(width: w * 0.17, height: h * 0.17)
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(P.ink.color)
                    .frame(width: w * 0.5, height: h * 0.11)
            }
        }
    }
}

/// Top Shelf: a back-bar bottle — cap, neck, labeled body.
private struct BottleArt: View {
    let body_: RGB
    let w: CGFloat
    let h: CGFloat

    init(body: RGB, w: CGFloat, h: CGFloat) {
        self.body_ = body
        self.w = w
        self.h = h
    }

    var body: some View {
        VStack(spacing: -1) {
            RoundedRectangle(cornerRadius: 3)
                .fill(P.torch.color)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(P.ink.color, lineWidth: 2))
                .frame(width: w * 0.32, height: h * 0.09)
            Rectangle()
                .fill(body_.color)
                .overlay(Rectangle().stroke(P.ink.color, lineWidth: 2))
                .frame(width: w * 0.26, height: h * 0.2)
            RoundedRectangle(cornerRadius: 10)
                .fill(body_.color)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(P.ink.color, lineWidth: 2.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(P.cream.color)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(P.ink.color, lineWidth: 1.5))
                        .frame(width: w * 0.62, height: h * 0.2)
                )
                .frame(width: w * 0.78, height: h * 0.71)
        }
        .frame(width: w, height: h, alignment: .bottom)
    }
}

/// Luau: a hanging party lantern, lit from within.
private struct LanternArt: View {
    let glow: RGB
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        VStack(spacing: 2) {
            Rectangle().fill(P.ink.color).frame(width: 2, height: h * 0.1)
            RoundedRectangle(cornerRadius: 3)
                .fill(P.driftwood.color)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(P.ink.color, lineWidth: 2))
                .frame(width: w * 0.42, height: h * 0.08)
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.3)
                    .fill(glow.color)
                    .overlay(RoundedRectangle(cornerRadius: w * 0.3).stroke(P.ink.color, lineWidth: 2.5))
                Circle()
                    .fill(P.blossom.color.opacity(0.9))
                    .frame(width: w * 0.4, height: w * 0.4)
            }
            .frame(width: w * 0.86, height: h * 0.6)
            RoundedRectangle(cornerRadius: 3)
                .fill(P.driftwood.color)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(P.ink.color, lineWidth: 2))
                .frame(width: w * 0.42, height: h * 0.08)
            Rectangle().fill(P.torch.color).frame(width: 3, height: h * 0.09)
        }
        .frame(width: w, height: h, alignment: .bottom)
    }
}

/// Cabana Cipher: a matchbook, flap up, striker along the base.
private struct MatchbookArt: View {
    let cover: RGB
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        VStack(spacing: -2) {
            RoundedRectangle(cornerRadius: 6)
                .fill(cover.lerp(P.ink, 0.25).color)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(P.ink.color, lineWidth: 2))
                .frame(width: w * 0.8, height: h * 0.24)
            RoundedRectangle(cornerRadius: 8)
                .fill(cover.color)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(P.ink.color, lineWidth: 2.5))
                .overlay(
                    Circle()
                        .fill(P.blossom.color)
                        .overlay(Circle().stroke(P.ink.color, lineWidth: 1.5))
                        .frame(width: w * 0.26, height: w * 0.26)
                )
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(P.cream.color)
                        .overlay(Rectangle().stroke(P.ink.color, lineWidth: 1.5))
                        .frame(width: w * 0.66, height: h * 0.08)
                        .padding(.bottom, h * 0.05)
                }
                .frame(width: w * 0.86, height: h * 0.72)
        }
        .frame(width: w, height: h, alignment: .bottom)
    }
}

/// Blueprints: a drafted sheet pinned to the wall, grid showing.
private struct DraftSheetArt: View {
    let sheet: RGB
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(sheet.color)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(P.ink.color, lineWidth: 2.5))
            VStack(spacing: h * 0.18) {
                Rectangle().fill(P.blossom.color.opacity(0.3)).frame(height: 1.5)
                Rectangle().fill(P.blossom.color.opacity(0.3)).frame(height: 1.5)
                Rectangle().fill(P.blossom.color.opacity(0.3)).frame(height: 1.5)
            }
            .padding(.horizontal, w * 0.12)
            HStack(spacing: w * 0.2) {
                Rectangle().fill(P.blossom.color.opacity(0.3)).frame(width: 1.5)
                Rectangle().fill(P.blossom.color.opacity(0.3)).frame(width: 1.5)
            }
            .padding(.vertical, h * 0.12)
            Circle()
                .fill(P.coral.color)
                .overlay(Circle().stroke(P.ink.color, lineWidth: 2))
                .frame(width: 12, height: 12)
                .offset(y: -h * 0.5)
        }
        .frame(width: w, height: h * 0.92)
    }
}

/// Navigator: a charted star — glow ring, core, four rays.
private struct StarArt: View {
    let core: RGB
    let w: CGFloat
    let h: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(P.bioGlow.color.opacity(0.18))
                .frame(width: w * 0.95, height: w * 0.95)
            Circle()
                .stroke(P.bioGlow.color.opacity(0.6), lineWidth: 2)
                .frame(width: w * 0.66, height: w * 0.66)
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(P.bioGlow.color)
                    .frame(width: 3.5, height: w * 0.24)
                    .offset(y: -w * 0.42)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
            Circle()
                .fill(core.color)
                .overlay(Circle().stroke(P.ink.color, lineWidth: 2.5))
                .frame(width: w * 0.34, height: w * 0.34)
        }
        .frame(width: w, height: h)
    }
}
