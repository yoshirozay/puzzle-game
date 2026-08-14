import SwiftUI

/// Navigator passage-won and run-over panels. Extracted from NavigatorView
/// so end-panel work stays off board / chrome / flow files.
struct NavigatorPassageWonPanel: View {
    let loopComplete: Bool
    let passageId: Int
    let loopSubtitle: String?
    let levelScore: Int
    let isPerfect: Bool
    let passageSummary: RunSummary?
    let newBestFlash: Bool
    let nextLoopNumber: Int
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(loopComplete ? "LANDFALL" : "PASSAGE \(passageId) CHARTED")
                .font(.custom("Futura-Bold", size: 18, relativeTo: .title2))
                .tracking(2)
                .foregroundStyle(P.torch.color)
                .multilineTextAlignment(.center)
            if loopComplete {
                Text("CHART REDRAWN")
                    .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(P.cream.color.opacity(0.85))
            } else if let loopSubtitle {
                Text(loopSubtitle)
                    .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.cream.color.opacity(0.85))
            }
            Text("SCORE \(levelScore)\(isPerfect ? " · PERFECT" : "")")
                .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                .tracking(1.2)
                .foregroundStyle(P.blossom.color)
            if let summary = passageSummary {
                Text("+\(summary.pointsEarned) · \(summary.totalPoints) POINTS")
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(1.2)
                    .foregroundStyle(P.torch.color)
            }
            if newBestFlash {
                Text("NEW BEST")
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.coral.color)
            }
            Button(action: onContinue) {
                Text(loopComplete ? "BEGIN LOOP \(nextLoopNumber)" : "SAIL ON")
                    .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.ink.color)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(P.torch.color))
            }
            .buttonStyle(SoftPressStyle())
            .padding(.top, 6)
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(P.ink.color.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.driftwood.color, lineWidth: 2))
        )
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .zIndex(60)
    }
}

/// Navigator run-over — clouds close in, lives spend beat, ALL GAMES / TRY AGAIN.
struct NavigatorRunOverPanel: View {
    let totalPassages: Int
    let reachedPassage: Int
    let resumePassage: Int
    let loopNumber: Int
    let newBestFlash: Bool
    let boardRank: Int?
    let spendBreakIndex: Int?
    let playSpendBreak: Bool
    var onExit: () -> Void
    var onTryAgain: () -> Void
    var onOpenLeaderboard: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        VStack(spacing: 12) {
            Text("THE CLOUDS CLOSE IN")
                .font(.custom("Futura-Bold", size: 20, relativeTo: .title2))
                .tracking(2.5)
                .foregroundStyle(P.blossom.color)
                .multilineTextAlignment(.center)
            Text("\(totalPassages) PASSAGES CLEARED")
                .font(.custom("Futura-Medium", size: 13, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(P.cream.color.opacity(0.85))
            Text(loopNumber > 1
                ? "FELL AT PASSAGE \(reachedPassage) · LOOP \(loopNumber)"
                : "FELL AT PASSAGE \(reachedPassage)")
                .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(P.blossom.color)
            // Where TRY AGAIN will drop them. Silent rewinds read as a bug —
            // the player needs to see that they kept most of their ground.
            if resumePassage < reachedPassage {
                Text("THE TIDE CARRIES YOU BACK TO PASSAGE \(resumePassage)")
                    .font(.custom("Futura-Medium", size: 11, relativeTo: .caption))
                    .tracking(1.2)
                    .foregroundStyle(P.cream.color.opacity(0.7))
                    .multilineTextAlignment(.center)
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
            }
            if newBestFlash {
                Text("NEW BEST")
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(P.coral.color)
                    .padding(.top, 2)
            }
            // Lounge handoff — the same wallet line the other five games end
            // on. Passages bank their points one by one during the run, so
            // this panel is the only place a voyage's total gets spoken.
            Text(store.canAffordNewItem
                ? "POINTS \(store.points) · NEW ITEM"
                : "POINTS \(store.points)")
                .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(store.canAffordNewItem ? P.torch.color : P.cream.color.opacity(0.8))
            HStack(spacing: 10) {
                Button(action: onExit) {
                    Text("ALL GAMES")
                        .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.blossom.color)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Capsule().stroke(P.blossom.color.opacity(0.7), lineWidth: 1.5))
                }
                .buttonStyle(SoftPressStyle())
                Button(action: onTryAgain) {
                    Text("TRY AGAIN")
                        .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(P.torch.color))
                }
                .buttonStyle(SoftPressStyle())
            }
            .padding(.top, 6)
        }
        .padding(26)
        .frame(maxWidth: 340)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(P.ink.color.opacity(0.92))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.driftwood.color, lineWidth: 2))
        )
        .overlay(alignment: .top) {
            LeaderboardBar(title: LeaderboardTheme.navigator.title, rank: boardRank) {
                onOpenLeaderboard()
            }
            .offset(y: -58)
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
        .zIndex(60)
    }
}
