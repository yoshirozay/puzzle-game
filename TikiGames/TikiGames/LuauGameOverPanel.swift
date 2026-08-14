import SwiftUI

/// LESSON — the line that names what a teaching level is demonstrating.
///
/// Docked under the board and deliberately NOT scrimmed. `TutorialReadyBanner`
/// exists and would have been less work, but it dims the whole screen for 1.4s
/// and then leaves: a lesson has to be readable WHILE you look at the thing it
/// describes, or the sentence and the board never connect.
///
/// Stays until the player taps it away or clears the sand, because there is no
/// time limit on understanding something.
struct LuauLessonBanner: View {
    let teaches: String
    var onDismiss: () -> Void

    private var copy: (title: String, body: String) {
        switch teaches {
        case "packedSand":
            // Names the ring, not the shade: packed sand renders PALER than
            // single sand (a heavier film over the piece), so "darker" —
            // the obvious word — describes the opposite of what's drawn.
            return ("PACKED SAND",
                    "Sand with a second ring inside is packed twice. One match clears the top layer, and it takes another to dig out the rest.")
        case "corners":
            // Names the SHAPE, not the special, because the shape is the part
            // players cannot see coming — the reward explains itself once it
            // is sitting on the board.
            return ("THE SUNBURST",
                    "Bend five of a colour into an L or a T — a row and a column meeting at one piece. The corner becomes a sunburst that blasts everything around it when you match it.")
        case "ingredients":
            // Says what the coconut CAN'T do first, because that is the part
            // that surprises people. The old copy ended on "you can also slide
            // it left or right", which promised free steering the game no
            // longer has: a coconut swaps like any other piece, and a swap that
            // matches nothing springs straight back.
            return ("THE COCONUT",
                    "It doesn't match with anything. Clear the pieces under it and it drops — get it to the bottom row to float it away. You can swap it in any direction, but only if the swap makes a match somewhere.")
        default:
            return ("SOMETHING NEW", "Have a look around.")
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(copy.title)
                .font(.custom("Futura-Bold", size: 17, relativeTo: .body))
                .tracking(3)
                .foregroundStyle(P.torch.color)
                .shadow(color: P.ink.color, radius: 0, x: 2, y: 2)
            Text(copy.body)
                .font(.custom("Futura-Medium", size: 13, relativeTo: .body))
                .tracking(0.5)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(P.cream.color.opacity(0.9))
            Text("TAP TO DISMISS")
                .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.cream.color.opacity(0.5))
                .padding(.top, 2)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(P.ink.color).offset(x: 2, y: 3)
                RoundedRectangle(cornerRadius: 18).fill(P.woodDark.color)
                RoundedRectangle(cornerRadius: 18).strokeBorder(P.torch.color.opacity(0.55), lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture { onDismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(copy.title). \(copy.body)")
        .accessibilityAddTraits(.isButton)
    }
}

/// NIGHT CLEAR — the non-modal replacement for the win half of
/// `LuauSunrisePanel`. A cleared night used to raise a modal card over a
/// hit-testable scrim that killed the board and asked a binary question
/// (LEVELS or NEXT NIGHT) whose answer was obvious, which is what broke flow
/// between levels. This docks *under* the still-visible board, occludes
/// nothing, asks nothing, and advances on its own — the board takes the bow.
///
/// Press and hold to freeze the fuse; tap to go now.
struct LuauNightClearBanner: View {
    let levelId: Int
    let movesLeft: Int
    let spareBonus: Int
    let pointsEarned: Int?
    let nightStreak: Int
    let deadline: Date
    let total: Double
    let holding: Bool
    var onHoldChanged: (Bool) -> Void
    var onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var streakFlare = false

    private let fuseWidth: CGFloat = 168

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text("NIGHT \(levelId) CLEAR")
                    .font(.custom("Futura-Bold", size: 20, relativeTo: .body))
                    .tracking(3)
                    .foregroundStyle(P.torch.color)
                    .shadow(color: P.ink.color, radius: 0, x: 2, y: 2)
                if nightStreak >= 2 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("\(nightStreak)")
                            .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                    }
                    .foregroundStyle(P.torch.color)
                    .scaleEffect(streakFlare ? 1.18 : 1)
                }
            }
            if spareBonus > 0 {
                Text("\(movesLeft) \(movesLeft == 1 ? "MOVE" : "MOVES") SPARE · +\(spareBonus)")
                    .font(.custom("Futura-Medium", size: 13, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.cream.color.opacity(0.85))
            }
            if let pointsEarned {
                Text("+\(pointsEarned) POINTS")
                    .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.torch.color)
            }
            fuse
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
        .background {
            ZStack {
                // Flat offset plate — the piece-plate shadow geometry used
                // across this game. No blur; the art is hard-edged.
                RoundedRectangle(cornerRadius: 18).fill(P.ink.color)
                    .offset(x: 2, y: 3)
                RoundedRectangle(cornerRadius: 18).fill(P.woodDark.color)
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(P.torch.color.opacity(0.55), lineWidth: 2)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 18))
        .onTapGesture { onSkip() }
        .onLongPressGesture(minimumDuration: 0.01, maximumDistance: 40, pressing: { pressing in
            onHoldChanged(pressing)
        }, perform: {})
        .onAppear {
            guard !reduceMotion, nightStreak >= 2 else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.spring(duration: 0.35, bounce: 0.45)) { streakFlare = true }
                try? await Task.sleep(for: .milliseconds(320))
                withAnimation(.spring(duration: 0.3, bounce: 0.25)) { streakFlare = false }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Night \(levelId) clear. Next night starting.")
        .accessibilityHint("Double tap to continue now, or touch and hold to wait.")
    }

    /// A burning fuse rather than a spinner: it says both "something is coming"
    /// and "here is exactly how long you have". Redrawn from the deadline each
    /// frame so the drawn fuse and the fire that actually advances can never
    /// disagree after a main-thread hitch. Under Reduce Motion it still drains
    /// — this is information, not decoration — just in coarse steps.
    private var fuse: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? 0.25 : 1.0 / 30.0)) { ctx in
            let remaining = max(0, deadline.timeIntervalSince(ctx.date))
            let fraction = total > 0 ? min(1, remaining / total) : 0
            VStack(spacing: 7) {
                Text(holding ? "HOLDING" : "NEXT NIGHT")
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(holding ? P.blossom.color : P.cream.color.opacity(0.7))
                ZStack(alignment: .leading) {
                    Capsule().fill(P.cream.color.opacity(0.18))
                        .frame(width: fuseWidth, height: 4)
                    Capsule().fill(P.torch.color)
                        .frame(width: fuseWidth * fraction, height: 4)
                    if !reduceMotion, fraction > 0.001 {
                        Circle().fill(P.blossom.color)
                            .frame(width: 7, height: 7)
                            .offset(x: fuseWidth * fraction - 3.5)
                    }
                }
                .frame(width: fuseWidth, height: 7)
            }
        }
    }
}

/// Luau SUNRISE / NIGHT CLEAR / OUT OF MOVES panel — wallet lines, lives
/// spend beat, ALL GAMES exit + forward action. Extracted from LuauView so
/// panel work stays off the board / chrome / coach files.
struct LuauSunrisePanel: View {
    let score: Int
    let isNewBest: Bool
    let isLevelMode: Bool
    let didWinLevel: Bool
    let levelId: Int?
    let movesLeft: Int
    let lastSpareBonus: Int
    let jellyRemaining: Int
    let summary: RunSummary?
    let canAffordNewItem: Bool
    let mintedThisRun: Int
    let boardRank: Int?
    let hasNextNight: Bool
    let spendBreakIndex: Int?
    let playSpendBreak: Bool
    var onExit: () -> Void
    var onNextNight: () -> Void
    var onRetry: () -> Void
    var onOpenLeaderboard: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        let gold = Color(red: 0.910, green: 0.702, blue: 0.235)
        let inLevel = isLevelMode
        let levelWon = inLevel && didWinLevel
        let levelLost = inLevel && !didWinLevel

        return ZStack {
            P.ink.color.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                // Headline: level-clear, level-fail, or the endless SUNRISE.
                if levelWon, let levelId {
                    Text("NIGHT \(levelId) CLEAR")
                        .font(.custom("Futura-Bold", size: 22, relativeTo: .body))
                        .tracking(3)
                        .foregroundStyle(gold)
                } else if levelLost {
                    Text("OUT OF MOVES")
                        .font(.custom("Futura-Bold", size: 22, relativeTo: .body))
                        .tracking(3)
                        .foregroundStyle(P.coral.color)
                } else {
                    Text(isNewBest ? "NEW BEST!" : "SUNRISE")
                        .font(.custom("Futura-Bold", size: 24, relativeTo: .body))
                        .tracking(3)
                        .foregroundStyle(isNewBest ? gold : P.blossom.color)
                }
                Image.luauSpecialCat
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                if !levelLost {
                    Text("\(score)")
                        .font(.custom("Futura-Bold", size: 40, relativeTo: .body))
                        .foregroundStyle(P.blossom.color)
                }
                if levelWon, lastSpareBonus > 0 {
                    Text("\(movesLeft) \(movesLeft == 1 ? "MOVE" : "MOVES") TO SPARE · +\(lastSpareBonus)")
                        .font(.custom("Futura-Medium", size: 13, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(gold)
                }
                if levelLost {
                    Text("\(jellyRemaining) SAND LEFT")
                        .font(.custom("Futura-Medium", size: 13, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.cream.color.opacity(0.75))
                    // Spend beat only on lost nights — wins show nothing new.
                    livesSpendHearts
                } else if !inLevel {
                    // Endless sunrise is also a defeat.
                    livesSpendHearts
                }
                if !levelLost, let summary {
                    Text("BEST \(summary.best)")
                        .font(.custom("Futura-Medium", size: 14, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.cream.color.opacity(0.75))
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
                // Buttons: the route home on the left (every game's terminal
                // panel offers ALL GAMES — Luau used to be the one exception),
                // the forward action (next night / retry / one more night) on
                // the right.
                HStack(spacing: 10) {
                    Button(action: onExit) {
                        Text("ALL GAMES")
                            .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                            .tracking(2)
                            .foregroundStyle(P.blossom.color)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 11)
                            .background(Capsule().stroke(P.blossom.color.opacity(0.7), lineWidth: 1.5))
                    }
                    .buttonStyle(SoftPressStyle())
                    if levelWon, hasNextNight {
                        Button(action: onNextNight) {
                            Text("NEXT NIGHT")
                                .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                                .tracking(2)
                                .foregroundStyle(P.ink.color)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 11)
                                .background(Capsule().fill(P.torch.color))
                        }
                        .buttonStyle(SoftPressStyle())
                    } else if levelLost {
                        Button(action: onRetry) {
                            Text("RETRY")
                                .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                                .tracking(2)
                                .foregroundStyle(P.ink.color)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 11)
                                .background(Capsule().fill(P.torch.color))
                        }
                        .buttonStyle(SoftPressStyle())
                    } else if !inLevel {
                        Button(action: onRetry) {
                            Text("ONE MORE NIGHT")
                                .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                                .tracking(2)
                                .foregroundStyle(P.ink.color)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 11)
                                .background(Capsule().fill(P.torch.color))
                        }
                        .buttonStyle(SoftPressStyle())
                    }
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 18).fill(P.woodDark.color))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.ink.color, lineWidth: 2))
            .overlay(alignment: .bottom) {
                if mintedThisRun > 0 {
                    MilestoneToast(
                        message: "+\(mintedThisRun * PlayerStore.milestoneMint) POINTS"
                    )
                    .offset(y: 56)
                }
            }
            .overlay(alignment: .top) {
                LeaderboardBar(title: LeaderboardTheme.luau.title, rank: boardRank) {
                    onOpenLeaderboard()
                }
                .offset(y: -58)
            }
        }
        .transition(.opacity)
    }

    @ViewBuilder
    private var livesSpendHearts: some View {
        // Nothing was spent if Luau is not charging yet — no hearts to show.
        if store.livesActive(for: .luau) {
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
            }
        }
    }
}
