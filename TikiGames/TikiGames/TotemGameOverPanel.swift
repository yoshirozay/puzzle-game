import SwiftUI

/// Totem GAME OVER panel — panel art, lives spend beat, ALL GAMES / PLAY
/// AGAIN. Extracted from TikiStacksView so panel work stays off board/tray.
struct TotemGameOverPanel: View {
    let W: CGFloat
    let score: Int
    let best: Int
    let previousBest: Int
    let isNewBest: Bool
    let summary: RunSummary?
    let canAffordNewItem: Bool
    let mintedThisRun: Int
    let boardRank: Int?
    let spendBreakIndex: Int?
    let playSpendBreak: Bool
    var onExit: () -> Void
    var onPlayAgain: () -> Void
    var onOpenLeaderboard: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        let cream = Color(red: 0.957, green: 0.914, blue: 0.831)
        let wood = Color(red: 0.231, green: 0.141, blue: 0.090)
        return ZStack {
            P.ink.color.opacity(0.55).ignoresSafeArea()
            Image.uiPanel
                .resizable()
                .frame(width: W * 0.86, height: W * 0.86 * 360 / 400)
                .overlay(
                    GeometryReader { g in
                        let gold = Color(red: 0.910, green: 0.702, blue: 0.235)
                        Text(isNewBest ? "NEW BEST!" : "GAME OVER")
                            .font(.custom("Futura-Bold", size: g.size.height * 0.085))
                            .tracking(3)
                            .foregroundStyle(isNewBest ? gold : cream)
                            .position(x: g.size.width * 0.5, y: g.size.height * 0.095)
                        // The lose reason, always stated — a first run's
                        // headline is NEW BEST!, so this line alone tells a
                        // new player the run actually ended, and why.
                        Text("NO PIECE FIT THE BOARD")
                            .font(.custom("Futura-Medium", size: g.size.height * 0.042))
                            .tracking(1.5)
                            .foregroundStyle(wood.opacity(0.7))
                            .position(x: g.size.width * 0.5, y: g.size.height * 0.175)
                        // Spend beat: one-shot drain on the heart that left.
                        // Nothing was spent if Totem is not charging yet.
                        if store.livesActive(for: .tikiStacks) {
                            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                let snap = store.livesSnapshot(now: ctx.date)
                                LivesHearts(
                                    count: snap.count,
                                    size: .panel,
                                    filledColor: Color(red: 0.78, green: 0.28, blue: 0.28),
                                    emptyColor: wood.opacity(0.28),
                                    secondsToNext: snap.count == 0 ? snap.secondsToNext : nil,
                                    breakIndex: spendBreakIndex,
                                    playBreak: playSpendBreak,
                                    pulseOnDecrement: false
                                )
                            }
                            .position(x: g.size.width * 0.5, y: g.size.height * 0.255)
                        }
                        Group {
                            if isNewBest {
                                Image.iconCrown.resizable().scaledToFit()
                            } else {
                                Image.iconTrophy.resizable().scaledToFit()
                            }
                        }
                        .frame(height: g.size.height * 0.11)
                        .position(x: g.size.width * 0.5, y: g.size.height * 0.355)
                        Text("\(score)")
                            .font(.custom("Futura-Bold", size: g.size.height * 0.14))
                            .foregroundStyle(wood)
                            .position(x: g.size.width * 0.5, y: g.size.height * 0.48)
                        Text(isNewBest ? "PREVIOUS BEST \(previousBest)" : "BEST \(best)")
                            .font(.custom("Futura-Medium", size: g.size.height * 0.062))
                            .tracking(2)
                            .foregroundStyle(wood.opacity(0.75))
                            .position(x: g.size.width * 0.5, y: g.size.height * 0.575)
                        if let summary {
                            Text("+\(summary.pointsEarned) POINTS")
                                .font(.custom("Futura-Bold", size: g.size.height * 0.058))
                                .tracking(2)
                                .foregroundStyle(gold)
                                .position(x: g.size.width * 0.5, y: g.size.height * 0.655)
                            if canAffordNewItem {
                                Text("POINTS \(summary.totalPoints) · NEW ITEM")
                                    .font(.custom("Futura-Bold", size: g.size.height * 0.038))
                                    .tracking(1.2)
                                    .foregroundStyle(gold)
                                    .position(x: g.size.width * 0.5, y: g.size.height * 0.892)
                            } else {
                                Text("POINTS \(summary.totalPoints)")
                                    .font(.custom("Futura-Medium", size: g.size.height * 0.044))
                                    .tracking(2)
                                    .foregroundStyle(wood.opacity(0.7))
                                    .position(x: g.size.width * 0.5, y: g.size.height * 0.892)
                            }
                        }
                        HStack(spacing: 10) {
                            Button(action: onExit) {
                                Text("ALL GAMES")
                                    .font(.custom("Futura-Bold", size: g.size.height * 0.045))
                                    .tracking(2)
                                    .foregroundStyle(wood)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Capsule().stroke(wood.opacity(0.55), lineWidth: 1.5))
                            }
                            .buttonStyle(SoftPressStyle())
                            Button(action: onPlayAgain) {
                                Image.uiButton
                                    .resizable()
                                    .frame(width: g.size.width * 0.44, height: g.size.width * 0.44 * 96 / 320)
                                    .overlay(
                                        Text("PLAY AGAIN")
                                            .font(.custom("Futura-Bold", size: g.size.height * 0.049))
                                            .tracking(2.5)
                                            .foregroundStyle(cream)
                                            .offset(y: -3)
                                    )
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                        .position(x: g.size.width * 0.5, y: g.size.height * 0.78)
                    }
                )
                .overlay(alignment: .bottom) {
                    if mintedThisRun > 0 {
                        MilestoneToast(
                            message: "+\(mintedThisRun * PlayerStore.milestoneMint) POINTS"
                        )
                        .offset(y: 56)
                    }
                }
                .overlay(alignment: .top) {
                    LeaderboardBar(title: LeaderboardTheme.totem.title, rank: boardRank) {
                        onOpenLeaderboard()
                    }
                    .offset(y: -58)
                }
        }
    }
}
