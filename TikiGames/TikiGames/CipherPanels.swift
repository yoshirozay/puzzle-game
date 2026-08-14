import SwiftUI

/// The run-of-wins story the end-game panels tell. Cipher's leaderboard
/// ranks phrases solved IN A ROW, but nothing on screen ever said so —
/// the panels are where the player learns the chase and feels the count
/// grow. Pure copy rules, kept off the views so they're testable:
/// streak 1 seeds the goal, 2+ celebrates the row, a defeat names the
/// run it just ended — and silence otherwise (crafted saves restore
/// complete with a zeroed streak; a 0/1-win defeat has no run to mourn).
struct CipherStreakStory: Equatable {
    let streak: Int
    let title: String
    let detail: String
    let isNewBest: Bool

    static func rowTitle(_ n: Int) -> String { "\(n) IN A ROW" }

    /// CRACKED panel block. `isNewBest` is ignored at streak 1 — the
    /// first win always teaches the chase instead of celebrating it.
    static func cracked(streak: Int, best: Int, isNewBest: Bool) -> CipherStreakStory? {
        guard streak >= 1 else { return nil }
        if streak == 1 {
            return .init(streak: 1, title: "STREAK STARTED",
                         detail: "CRACK THE NEXT FOR 2 IN A ROW", isNewBest: false)
        }
        return .init(streak: streak, title: rowTitle(streak),
                     detail: isNewBest ? "YOUR BEST YET" : "BEST \(best)",
                     isNewBest: isNewBest)
    }

    /// OUT OF MISSES one-liner: the run that just died, with the best as
    /// the number to chase back.
    static func failed(endedStreak: Int, best: Int) -> String? {
        guard endedStreak >= 2 else { return nil }
        return "\(rowTitle(endedStreak)) ENDS · BEST \(best)"
    }

    /// Color ladder — the stamp runs hotter as the run grows. Thresholds are
    /// the milestones players actually quote ("5 in a row", "10 in a row").
    /// blaze is white-hot blossom — the flame CORE color, physically hotter
    /// than orange — and glow-tide cyan appears nowhere else in the panels,
    /// so 20+ reads genuinely rare. (Coral is skipped: it's Cipher's danger
    /// color, and the stamp is a celebration.)
    enum Heat { case matchGold, sunset, blaze, glowTide }
    var heat: Heat {
        switch streak {
        case ..<5: return .matchGold
        case ..<10: return .sunset
        case ..<20: return .blaze
        default: return .glowTide
        }
    }
}

/// Cabana Cipher OUT OF MISSES — five misses, lives spend beat,
/// ALL GAMES / PLAY AGAIN. Extracted from CipherView so panel work stays
/// off the board / keyboard / coach files.
struct CipherFailedPanel: View {
    /// The answer the player was chasing. The board reveals it first, but
    /// the panel covers the tiles — so it lives here too, where it stays
    /// readable while they decide what to do next.
    let phrase: String
    /// The streak this defeat ended, captured BEFORE breakStreak zeroed it
    /// (0 after a kill-and-relaunch restore, which correctly hides the line).
    let endedStreak: Int
    let bestStreak: Int
    let spendBreakIndex: Int?
    let playSpendBreak: Bool
    var onExit: () -> Void
    var onPlayAgain: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        ZStack {
            P.ink.color.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("OUT OF MISSES")
                    .font(.custom("Futura-Bold", size: 22, relativeTo: .body))
                    .tracking(3)
                    .foregroundStyle(P.coral.color)
                Text("THE PHRASE WAS")
                    .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.cream.color.opacity(0.7))
                Text("“\(phrase)”")
                    .font(.custom("Futura-Medium", size: 15, relativeTo: .body))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(P.blossom.color)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
                if let line = CipherStreakStory.failed(endedStreak: endedStreak, best: bestStreak) {
                    Text(line)
                        .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                        .tracking(1.6)
                        .foregroundStyle(P.cream.color.opacity(0.7))
                }
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let snap = store.livesSnapshot(now: ctx.date)
                    LivesHearts(
                        count: snap.count,
                        size: .panel,
                        secondsToNext: snap.count == 0 ? snap.secondsToNext : nil,
                        breakIndex: spendBreakIndex,
                        playBreak: playSpendBreak,
                        pulseOnDecrement: false
                    )
                    .accessibilityLabel("Lives remaining: \(snap.count) of \(PlayerStore.livesCap)")
                }
                HStack(spacing: 10) {
                    Button(action: onExit) {
                        Text("ALL GAMES")
                            .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                            .tracking(2)
                            .foregroundStyle(P.blossom.color)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Capsule().stroke(P.blossom.color.opacity(0.7), lineWidth: 1.5))
                    }
                    .buttonStyle(SoftPressStyle())
                    Button(action: onPlayAgain) {
                        Text("PLAY AGAIN")
                            .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                            .tracking(2.5)
                            .foregroundStyle(P.ink.color)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(P.torch.color))
                    }
                    .buttonStyle(SoftPressStyle())
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 18).fill(P.woodDark.color))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.ink.color, lineWidth: 2))
        }
        .transition(.opacity)
    }
}

/// Cabana Cipher CRACKED panel — phrase, clean-strike / mistakes, wallet,
/// NEXT PHRASE, matchbook + leaderboard overlays.
struct CipherCrackedPanel: View {
    let phrase: String
    let isCleanSolve: Bool
    let mistakes: Int
    let hints: Int
    let summary: RunSummary?
    let canAffordNewItem: Bool
    let bookCompleted: String?
    let mintedThisSolve: Int
    let boardRank: Int?
    /// Post-recordRun streak values — read live from the store by the view,
    /// so a kill-and-relaunch restore (which loses `summary`) keeps them.
    let streak: Int
    let bestStreak: Int
    let isNewBestStreak: Bool
    var onNextPhrase: () -> Void
    var onOpenLeaderboard: () -> Void

    var body: some View {
        let gold = Color(red: 0.910, green: 0.702, blue: 0.235)
        return ZStack {
            P.ink.color.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("CRACKED!")
                    .font(.custom("Futura-Bold", size: 24, relativeTo: .body))
                    .tracking(3)
                    .foregroundStyle(gold)
                Text("“\(phrase)”")
                    .font(.custom("Futura-Medium", size: 15, relativeTo: .body))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(P.blossom.color)
                    .fixedSize(horizontal: false, vertical: true)
                if let summary {
                    if isCleanSolve {
                        MatchStrikeView()
                        // Unnumbered by design: the +15 lands in score
                        // units, and score is invisible on this panel — a
                        // number here read as a broken payout (panel R2).
                        Text("CLEAN STRIKE")
                            .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                            .tracking(2)
                            .foregroundStyle(gold)
                    } else {
                        Text("MISSES \(mistakes) · HINTS \(hints)")
                        // (CLEAN STRIKE renders unnumbered above — its +15
                        // lands in score units the panel never displays, so
                        // a number here read as a broken payout; panel R2.)
                            .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                            .tracking(2)
                            .foregroundStyle(P.cream.color.opacity(0.75))
                    }
                    Text("+\(summary.pointsEarned) POINTS")
                        .font(.custom("Futura-Bold", size: 16, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(gold)
                    if canAffordNewItem {
                        Text("POINTS \(summary.totalPoints) · NEW ITEM")
                            .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                            .tracking(1.2)
                            .foregroundStyle(gold)
                    } else {
                        Text("POINTS \(summary.totalPoints)")
                            .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                            .tracking(2)
                            .foregroundStyle(P.cream.color.opacity(0.7))
                    }
                }
                Button(action: onNextPhrase) {
                    Text("NEXT PHRASE")
                        .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                        .tracking(2.5)
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(P.torch.color))
                }
                .buttonStyle(SoftPressStyle())
                .padding(.top, 6)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 18).fill(P.woodDark.color))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.ink.color, lineWidth: 2))
            .overlay(alignment: .top) {
                if let name = bookCompleted {
                    MilestoneToast(message: "MATCHBOOK COMPLETE — \(name) +100")
                        .offset(y: -56)
                } else {
                    LeaderboardBar(title: LeaderboardTheme.cipher.title, rank: boardRank) {
                        onOpenLeaderboard()
                    }
                    .offset(y: -58)
                }
            }
            .overlay(alignment: .bottom) {
                // The streak owns the band below the card (Carson: outside
                // the card, unmissable) — the mint toast stacks beneath it.
                // The guide pins the stack's TOP just under the card edge so
                // any combination of chips self-heights.
                VStack(spacing: 8) {
                    if let story = CipherStreakStory.cracked(
                        streak: streak, best: bestStreak, isNewBest: isNewBestStreak
                    ) {
                        CipherStreakStamp(story: story)
                    }
                    if mintedThisSolve > 0 {
                        // Defers past the slam + roll when the stamp is on
                        // stage — the streak owns the first motion down here.
                        MilestoneToast(
                            message: "+\(mintedThisSolve * PlayerStore.milestoneMint) POINTS",
                            delay: streak >= 2 ? 1.95 : 0.35
                        )
                    }
                }
                .alignmentGuide(.bottom) { $0[VerticalAlignment.top] - 14 }
            }
            .padding(.horizontal, 34)
        }
        .transition(.opacity)
    }
}

/// The final NEXT PHRASE of the wall pours the ceremony: full matchbook
/// wall, then Vic calls the second round. Kept with the panel family so
/// CipherView stays board / keyboard / coach focused.
struct CipherLastCallCeremony: View {
    var onPourSecondRound: () -> Void

    var body: some View {
        let gold = Color(red: 0.910, green: 0.702, blue: 0.235)
        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)
        return ZStack {
            // Fully opaque — the ceremony owns the screen, and gold panel
            // text read through anything less during the crossfade.
            P.ink.color.ignoresSafeArea()
            VStack(spacing: 14) {
                Text("LAST CALL")
                    .font(.custom("Futura-Bold", size: 30, relativeTo: .body))
                    .tracking(5)
                    .foregroundStyle(gold)
                Text("FIFTY MATCHBOOKS · EVERY COVER STRUCK")
                    .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                    .tracking(1.6)
                    .foregroundStyle(P.cream.color.opacity(0.75))
                // Fifty covers outgrow the screen — the wall scrolls, capped
                // so Vic's call and the CTA stay on screen below it.
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(Array(CipherGame.matchbooks.enumerated()), id: \.element.id) { i, book in
                            MatchbookCover(name: book.name, index: i)
                        }
                    }
                }
                .frame(maxHeight: 340)
                // Bottom fade signals the wall scrolls — fifty covers hide
                // below the fold with no other affordance.
                .mask(
                    LinearGradient(
                        stops: [.init(color: .black, location: 0),
                                .init(color: .black, location: 0.88),
                                .init(color: .black.opacity(0.05), location: 1)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                Text("“LAST CALL... SECOND ROUND, HOUSE SHUFFLE.”")
                    .font(.custom("Futura-Medium", size: 13, relativeTo: .body))
                    .tracking(1.2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(P.blossom.color)
                Text("— VIC")
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(P.cream.color.opacity(0.6))
                Button(action: onPourSecondRound) {
                    Text("NEXT MATCHBOOK")
                        .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(P.torch.color))
                }
                .buttonStyle(SoftPressStyle())
                .padding(.top, 6)
            }
            .padding(.horizontal, 12)
        }
        .transition(.opacity)
    }
}

/// One struck matchbook cover on the LAST CALL wall — cream book, ink
/// striker band, clay scratch, spent match at rest. Covers pop in one by one.
private struct MatchbookCover: View {
    let name: String
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Sixteen cover paintings across fifty books. Books 1–16 keep their
    /// PAINTED pairing (the cat cover belongs to THE CAT, the ukulele to THE
    /// BAND) — a blanket shuffle scrambled that and read as mis-assigned art.
    /// Books 17+ recycle the paintings through a deterministic per-block
    /// shuffle so repeats never form the diagonal twin pattern a plain
    /// (index % 16) cycle produced on the 5-column grid.
    private static func art(for index: Int) -> Int {
        let block = index / 16
        guard block > 0 else { return index + 1 }   // painted pairing, books 1–16
        var order = Array(1...16)
        var seed = UInt64(block &* 2654435761 &+ 54481)
        for i in (1..<order.count).reversed() {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let j = Int((seed >> 33) % UInt64(i + 1))
            order.swapAt(i, j)
        }
        return order[index % 16]
    }

    var body: some View {
        // Lounge v2 delivery: illustrated cover art (motif in the lower 2/3,
        // striker baked in); the title stays code-rendered over the upper 1/3.
        Image.matchbookCover(Self.art(for: index))
            .resizable()
            .aspectRatio(96 / 128, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(alignment: .top) {
                Text(name)
                    .font(.custom("Futura-Bold", size: 9, relativeTo: .body))
                    .tracking(0.5)
                    .foregroundStyle(P.ink.color)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5) // THE PHILOSOPHY SHELF fits untruncated
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)
                    .padding(.top, 6)
                    .padding(.horizontal, 4)
            }
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(P.ink.color.opacity(0.35), lineWidth: 1))
        .scaleEffect(shown ? 1 : (reduceMotion ? 1 : 0.6))
        .opacity(shown ? 1 : 0)
        .onAppear {
            // Reduce Motion: covers fade in together, no pop, no stagger.
            let anim: Animation = reduceMotion
                ? .easeOut(duration: 0.25)
                : .spring(duration: 0.4, bounce: 0.35).delay(0.15 + Double(index) * 0.05)
            withAnimation(anim) { shown = true }
        }
    }
}

/// The streak stamp — slams into the band BELOW the CRACKED card so the
/// run can't be missed in the panel's text pile. Choreography: cocked
/// oversized above the glass → one decisive slam (ring shockwave + heavy
/// haptic on the landing frame) → the count odometer-rolls N−1 → N →
/// best-line chip pops under it → the whole thing settles into a calm
/// resting chip that stays for the NEXT PHRASE decision. First wins skip
/// the slam: a quiet STREAK STARTED pop that teaches the chase instead.
private struct CipherStreakStamp: View {
    let story: CipherStreakStory

    private enum Phase { case cocked, held, rest }
    @State private var phase: Phase = .cocked
    /// Opacity is deliberately NOT driven by the slam spring: a stamp must
    /// be visible mass while it falls (v1 filmed as a fade — no impact).
    @State private var visible = false
    @State private var rolled: Int
    @State private var ringProgress: CGFloat = 0
    /// One-beat stroke flash on the landing frame — the ink outline goes
    /// run-colored for ~0.2s with the ring + thud, so the impact reads
    /// crisply even at low frame rates.
    @State private var strokeFlash = false
    @State private var detailShown = false
    @State private var flameFlicker = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let gold = Color(red: 0.910, green: 0.702, blue: 0.235)

    init(story: CipherStreakStory) {
        self.story = story
        _rolled = State(initialValue: max(story.streak - 1, 1))
    }

    private var slams: Bool { story.streak >= 2 }

    private var heatColor: Color {
        switch story.heat {
        case .matchGold: gold
        case .sunset: P.sunsetMid.color
        case .blaze: P.blossom.color
        case .glowTide: P.bioGlow.color
        }
    }

    private var scale: CGFloat {
        switch phase {
        case .cocked: slams ? 1.9 : 0.8
        case .held: 1.30
        case .rest: 1.0
        }
    }

    /// The stamp is the brightest thing below the card while the show runs —
    /// a run-colored glow that cools as it settles into the resting chip.
    private var glowOpacity: Double {
        switch phase {
        case .cocked: 0
        case .held: 0.55
        case .rest: 0.28
        }
    }

    private var rotation: Double {
        guard slams else { return 0 }
        switch phase {
        case .cocked: return -5
        case .held: return -2
        case .rest: return 0
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // The stamp proper: LeaderboardBar's capsule chrome, run-colored.
            HStack(spacing: 8) {
                flame
                if slams {
                    Text(CipherStreakStory.rowTitle(rolled))
                        .font(.custom("Futura-Bold", size: 20, relativeTo: .body))
                        .tracking(2.5)
                        .foregroundStyle(heatColor)
                        .contentTransition(.numericText(value: Double(rolled)))
                        .lineLimit(1)
                        .fixedSize()
                } else {
                    Text(story.title)
                        .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                        .tracking(2.5)
                        .foregroundStyle(heatColor)
                        .lineLimit(1)
                        .fixedSize()
                }
                // Twin flames flank the blaze tiers — 10+ burns at both ends.
                if story.streak >= 10 { flame }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .background(Capsule().fill(P.plank.color))
            .overlay(Capsule().stroke(strokeFlash ? heatColor : P.ink.color, lineWidth: 2.5))
            // Shockwave: the capsule's own outline, thrown outward on the
            // landing frame.
            .background {
                if slams {
                    Capsule()
                        .stroke(heatColor.opacity(Double(1 - ringProgress) * 0.85),
                                lineWidth: 4)
                        .scaleEffect(x: 1 + ringProgress * 0.35,
                                     y: 1 + ringProgress * 0.9)
                }
            }
            .shadow(color: heatColor.opacity(glowOpacity), radius: 16)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            if detailShown {
                Text(story.detail)
                    .font(.custom("Futura-Bold", size: 10.5, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(story.isNewBest ? heatColor : P.cream.color.opacity(0.8))
                    .lineLimit(1)
                    // The overlay inherits the CARD's width proposal, which
                    // truncated the teach line — size to the text instead
                    // (longest line ≈ 270pt, comfortably inside any phone).
                    .fixedSize()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(P.ink.color.opacity(0.55)))
                    .transition(reduceMotion
                                ? .opacity
                                : .opacity.combined(with: .scale(scale: 0.6)))
            }
        }
        .opacity(visible ? 1 : 0)
        .accessibilityElement(children: .combine)
        .task { await choreograph() }
    }

    /// One beat at a time — slam, shockwave+haptic, roll, best line, settle.
    /// Runs in .task so a fast NEXT PHRASE cancels the tail cleanly.
    @MainActor
    private func choreograph() async {
        if reduceMotion {
            // Settled state only: no slam, no roll, no repeat flicker.
            phase = .rest
            visible = true
            rolled = story.streak
            withAnimation(.easeOut(duration: 0.28).delay(0.2)) { detailShown = true }
            return
        }
        guard slams else {
            // First win: a soft pop, no theatrics — the chase is the lesson.
            try? await Task.sleep(for: .seconds(0.35))
            withAnimation(.easeOut(duration: 0.12)) { visible = true }
            withAnimation(.spring(duration: 0.45, bounce: 0.4)) { phase = .rest }
            withAnimation(.spring(duration: 0.4, bounce: 0.3).delay(0.25)) { detailShown = true }
            return
        }
        // Let the card's own landing finish so the slam owns its moment.
        try? await Task.sleep(for: .seconds(0.45))
        // Mass first, then the fall: near-instant opacity, springy scale
        // with one decisive overshoot (v1's spring-driven fade read limp).
        withAnimation(.linear(duration: 0.08)) { visible = true }
        withAnimation(.spring(duration: 0.3, bounce: 0.36)) { phase = .held }
        try? await Task.sleep(for: .seconds(0.12))
        // Landing frame: shockwave + stroke flash + thud together.
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.easeOut(duration: 0.5)) { ringProgress = 1 }
        strokeFlash = true
        withAnimation(.easeOut(duration: 0.22).delay(0.06)) { strokeFlash = false }
        try? await Task.sleep(for: .seconds(0.38))
        // The run GREW — roll the odometer up to today's number.
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { rolled = story.streak }
        try? await Task.sleep(for: .seconds(0.45))
        withAnimation(.spring(duration: 0.4, bounce: 0.45)) { detailShown = true }
        try? await Task.sleep(for: .seconds(1.0))
        // The show ends: settle into the resting chip.
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) { phase = .rest }
        try? await Task.sleep(for: .seconds(0.25))
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            flameFlicker = true
        }
    }

    /// A teardrop flame in the CLEAN STRIKE colors. MatchStrikeView's
    /// circle-flame reads fine on a match head, but standalone at this
    /// size it read as a bullet point — the silhouette does the work here.
    private var flame: some View {
        ZStack {
            StreakFlameShape()
                .fill((story.heat == .matchGold ? gold : heatColor).opacity(0.95))
                .frame(width: 13, height: 18)
            StreakFlameShape()
                .fill(story.heat == .blaze ? gold : P.blossom.color)
                .frame(width: 6, height: 8.5)
                .offset(y: 3.5)
        }
        // Breathes upward from its base, the way a real flame sways.
        .scaleEffect(flameFlicker ? 1.1 : 0.94, anchor: .bottom)
    }
}

/// Symmetric teardrop: pointed tip, flared sides, round base.
private struct StreakFlameShape: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: r.minX + w * 0.5, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.minX + w, y: r.minY + h * 0.65),
                       control: CGPoint(x: r.minX + w * 0.95, y: r.minY + h * 0.25))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.5, y: r.minY + h),
                       control: CGPoint(x: r.minX + w, y: r.minY + h))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.65),
                       control: CGPoint(x: r.minX, y: r.minY + h))
        p.addQuadCurve(to: CGPoint(x: r.minX + w * 0.5, y: r.minY),
                       control: CGPoint(x: r.minX + w * 0.05, y: r.minY + h * 0.25))
        return p
    }
}

/// One-shot CLEAN STRIKE beat on the CRACKED panel: a match drags across
/// its scratch line and flares alight.
private struct MatchStrikeView: View {
    @State private var struck = false
    @State private var flicker = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let gold = Color(red: 0.910, green: 0.702, blue: 0.235)

    var body: some View {
        ZStack {
            Capsule()
                .fill(P.ink.color.opacity(0.5))
                .frame(width: 56, height: 3)
                .scaleEffect(x: struck ? 1 : 0.12, y: 1, anchor: .leading)
                .offset(x: -8, y: 14)
            ZStack {
                Capsule()
                    .fill(P.cream.color)
                    .frame(width: 30, height: 4.5)
                Circle()
                    .fill(P.coral.color)
                    .frame(width: 8, height: 8)
                    .offset(x: 15)
                ZStack {
                    Circle()
                        .fill(gold.opacity(0.9))
                        .frame(width: 16, height: 16)
                    Circle()
                        .fill(P.blossom.color)
                        .frame(width: 7, height: 7)
                        .offset(y: 1.5)
                }
                .scaleEffect(struck ? (flicker ? 1.12 : 0.92) : 0.05)
                .opacity(struck ? 1 : 0)
                .offset(x: 19, y: -7)
            }
            .rotationEffect(.degrees(struck ? -10 : 8))
            .offset(x: struck ? 16 : -24, y: struck ? -2 : 8)
        }
        .frame(width: 96, height: 40)
        .onAppear {
            // Reduce Motion: the match lands already struck, flame steady —
            // no drag animation and no repeatForever flicker.
            if reduceMotion {
                struck = true
                return
            }
            withAnimation(.spring(duration: 0.5, bounce: 0.2).delay(0.3)) { struck = true }
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true).delay(0.85)) {
                flicker = true
            }
        }
    }
}
