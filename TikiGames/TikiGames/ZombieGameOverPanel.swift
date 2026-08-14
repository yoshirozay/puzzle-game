import SwiftUI

/// Top Shelf LAST CALL panel — lose reason, spend-beat hearts, wallet lines,
/// ALL GAMES / MIX AGAIN. Extracted from ZombieView so panel work stays
/// off the board/chrome files.
struct ZombieGameOverPanel: View {
    let score: Int
    let highestTier: Int
    let summary: RunSummary?
    let canAffordNewItem: Bool
    let mintedThisRun: Int
    let boardRank: Int?
    let spendBreakIndex: Int?
    let playSpendBreak: Bool
    var onExit: () -> Void
    var onMixAgain: () -> Void
    var onOpenLeaderboard: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        let gold = Color(red: 0.910, green: 0.702, blue: 0.235)
        let cream = Color(red: 0.957, green: 0.914, blue: 0.831)
        let isNewBest = summary?.isNewBest ?? false
        return ZStack {
            P.ink.color.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text(isNewBest ? "NEW BEST!" : "LAST CALL")
                    .font(.custom("Futura-Bold", size: 24, relativeTo: .body))
                    .tracking(3)
                    .foregroundStyle(isNewBest ? gold : cream)
                // The lose reason, always stated — a first run headlines
                // NEW BEST!, so this line alone says the run ended, and why.
                Text("BAR FULL — NO MERGES LEFT")
                    .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(cream.opacity(0.8))
                // Nothing was spent if Top Shelf is not charging yet.
                if store.livesActive(for: .zombie) {
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
                Image.zombieTile(min(highestTier, 11))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                Text("\(score)")
                    .font(.custom("Futura-Bold", size: 40, relativeTo: .body))
                    .foregroundStyle(cream)
                if let summary {
                    Text("BEST \(summary.best)")
                        .font(.custom("Futura-Medium", size: 14, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(cream.opacity(0.75))
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
                            .foregroundStyle(cream.opacity(0.7))
                    }
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
                    Button(action: onMixAgain) {
                        Text("MIX AGAIN")
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
            .padding(30)
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
                LeaderboardBar(title: LeaderboardTheme.topShelf.title, rank: boardRank) {
                    onOpenLeaderboard()
                }
                .offset(y: -58)
            }
        }
        .transition(.opacity)
    }
}

/// Mid-run THE ZOMBIE celebration — kept with the panel family so win/lose
/// chrome lives together.
struct ZombieWinBanner: View {
    let size: CGSize
    var onContinue: () -> Void

    var body: some View {
        let gold = Color(red: 0.910, green: 0.702, blue: 0.235)
        return VStack(spacing: 12) {
            Image.zombieTile(11)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
            Text("THE ZOMBIE!")
                .font(.custom("Futura-Bold", size: 26, relativeTo: .body))
                .tracking(3)
                .foregroundStyle(gold)
            Text("KEEP MIXING FOR THE HIGH SCORE")
                .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(P.blossom.color)
            Button(action: onContinue) {
                Text("CONTINUE")
                    .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.ink.color)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(P.torch.color))
            }
            .buttonStyle(SoftPressStyle())
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 18).fill(P.ink.color.opacity(0.88)))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(gold, lineWidth: 2))
        .position(x: size.width / 2, y: size.height * 0.42)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }
}
