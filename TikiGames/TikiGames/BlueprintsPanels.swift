import SwiftUI

/// Blueprints TOO MANY MISTAKES — three wrong cells, lives spend beat,
/// ALL GAMES / PLAY AGAIN. Extracted from BlueprintsView so panel work
/// stays off the board / picker / coach files.
struct BlueprintsFailedPanel: View {
    let puzzleName: String
    let spendBreakIndex: Int?
    let playSpendBreak: Bool
    var onExit: () -> Void
    var onPlayAgain: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        ZStack {
            P.ink.color.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("TOO MANY MISTAKES")
                    .font(.custom("Futura-Bold", size: 22, relativeTo: .body))
                    .tracking(3)
                    .foregroundStyle(P.coral.color)
                Text("THREE WRONG CELLS ENDED THE DRAFT")
                    .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.cream.color.opacity(0.8))
                    .multilineTextAlignment(.center)
                Text(puzzleName.uppercased())
                    .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.blossom.color)
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

/// DRAFTED seam — the non-modal replacement for the `BlueprintsDraftedPanel`
/// on every solve that has somewhere to go.
///
/// The modal covered the one thing the player just earned: the board
/// colorizing into its picture. It then asked a question whose answer was
/// always the same (NEXT BLUEPRINT), and answering it dropped them back in
/// the picker to hunt for an unsolved sheet — which is how a just-completed
/// puzzle gets reopened by mistake. This docks under the still-visible
/// board, occludes nothing, asks nothing, and loads the next unsolved
/// blueprint on its own. Same shape as Luau's night-clear seam.
///
/// Press and hold to freeze the fuse; tap to go now.
struct BlueprintsDraftedBanner: View {
    let puzzleName: String
    let nextName: String
    let completionNote: String
    let completionNoteGold: Bool
    let pointsEarned: Int?
    let deadline: Date
    let total: Double
    let holding: Bool
    var onHoldChanged: (Bool) -> Void
    var onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let fuseWidth: CGFloat = 168
    private let gold = Color(red: 0.910, green: 0.702, blue: 0.235)

    var body: some View {
        VStack(spacing: 9) {
            Text("DRAFTED!")
                .font(.custom("Futura-Bold", size: 20, relativeTo: .body))
                .tracking(3)
                .foregroundStyle(gold)
                .shadow(color: P.ink.color, radius: 0, x: 2, y: 2)
            Text(puzzleName.uppercased())
                .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.blossom.color)
            HStack(spacing: 10) {
                Text(completionNote)
                    .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(completionNoteGold ? gold : P.cream.color.opacity(0.75))
                if let pointsEarned {
                    Text("+\(pointsEarned)")
                        .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                        .tracking(1.5)
                        .foregroundStyle(gold)
                }
            }
            fuse
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        // Opaque: it docks over the scenery, and anything showing through
        // reads as a rendering fault rather than depth.
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(P.woodDark.color)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(P.ink.color, lineWidth: 2)
        )
        .shadow(color: P.ink.color.opacity(0.5), radius: 12, y: 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSkip)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onHoldChanged(true) }
                .onEnded { _ in onHoldChanged(false) }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(puzzleName) drafted. Next up, \(nextName).")
        .accessibilityHint("Double tap to continue now, or touch and hold to wait.")
    }

    /// A burning fuse rather than a spinner: it says both "something is
    /// coming" and "here is exactly how long you have". Redrawn from the
    /// deadline each frame so the drawn fuse and the timer that actually
    /// advances can never disagree after a main-thread hitch. Under Reduce
    /// Motion it still drains — this is information, not decoration.
    private var fuse: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? 0.25 : 1.0 / 30.0)) { ctx in
            let remaining = max(0, deadline.timeIntervalSince(ctx.date))
            let fraction = total > 0 ? min(1, remaining / total) : 0
            VStack(spacing: 6) {
                Text(holding ? "HOLDING" : "NEXT · \(nextName.uppercased())")
                    .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                    .tracking(2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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

/// Blueprints DRAFTED panel — pixel art, wallet lines, NEXT BLUEPRINT,
/// leaderboard bar + Vic mint toast. Still the ending for a solve with
/// nowhere to go: the last unsolved sheet in the drawer.
struct BlueprintsDraftedPanel: View {
    let puzzle: BlueprintsGame.Puzzle
    let completionNote: String
    let completionNoteGold: Bool
    let summary: RunSummary?
    let canAffordNewItem: Bool
    let mintedThisSolve: Int
    let boardRank: Int?
    var onNextBlueprint: () -> Void
    var onOpenLeaderboard: () -> Void

    var body: some View {
        let gold = Color(red: 0.910, green: 0.702, blue: 0.235)
        return ZStack {
            P.ink.color.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("DRAFTED!")
                    .font(.custom("Futura-Bold", size: 24, relativeTo: .body))
                    .tracking(3)
                    .foregroundStyle(gold)
                PixelArtView(puzzle: puzzle, colors: BlueprintColors.for(puzzle.id), animated: true)
                    .frame(width: 110, height: 110)
                Text(puzzle.name.uppercased())
                    .font(.custom("Futura-Bold", size: 16, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(P.blossom.color)
                if let summary {
                    Text(completionNote)
                        .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(completionNoteGold ? gold : P.cream.color.opacity(0.75))
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
                Button(action: onNextBlueprint) {
                    Text("NEXT BLUEPRINT")
                        .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                        .tracking(2.5)
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(P.torch.color))
                }
                .buttonStyle(SoftPressStyle())
                .padding(.top, 6)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 18).fill(P.woodDark.color))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.ink.color, lineWidth: 2))
            .overlay(alignment: .bottom) {
                if mintedThisSolve > 0 {
                    MilestoneToast(
                        message: "+\(mintedThisSolve * PlayerStore.milestoneMint) POINTS"
                    )
                    .offset(y: 56)
                }
            }
            .overlay(alignment: .top) {
                LeaderboardBar(title: LeaderboardTheme.blueprints.title, rank: boardRank) {
                    onOpenLeaderboard()
                }
                .offset(y: -58)
            }
        }
        .transition(.opacity)
    }
}
