import SwiftUI

/// Top Shelf HUD — score / undo / Depth Charge on the left, best + lives +
/// how-to on the right. Extracted from ZombieView so chrome edits don't
/// fight board / coach / game-over work in the same file.
struct ZombieChrome: View {
    let game: ZombieGame
    let coachActive: Bool
    @Binding var bombTargeting: Bool
    @Binding var bombAnchor: (col: Int, row: Int)
    var onHowTo: () -> Void
    var onPersist: () -> Void

    @Environment(PlayerStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bombChipBreathe = false

    private let slideHaptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    scoreChip("SCORE", value: game.boardValue)
                    undoButton
                    // Permanent inventory slot (Carson: the player should
                    // always see how many they have left) — dim ×0 when
                    // empty, gold and breathing when a charge is stocked.
                    if !coachActive {
                        bombButton
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    scoreChip("BEST", value: max(game.best, game.boardValue))
                    // Hidden until Top Shelf starts charging this player —
                    // showing hearts a defeat will not spend advertises a
                    // limit that is not being applied.
                    // Snapshot + 30s tick — mid-run refills reach the HUD
                    // (the `lives` mirror only moves at mutation points).
                    if store.livesActive(for: .zombie) {
                        TimelineView(.periodic(from: .now, by: 30)) { ctx in
                            LivesHearts(count: store.livesSnapshot(now: ctx.date).count, size: .chip)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(P.ink.color.opacity(0.55)))
                    }
                    if !coachActive {
                        HowToPlayButton(action: onHowTo)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
            Spacer()
        }
    }

    private var undoButton: some View {
        Button {
            guard game.canUndo else { return }
            withAnimation(.spring(duration: 0.25, bounce: 0.2)) { _ = game.undo() }
            slideHaptic.impactOccurred()
            onPersist()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .bold))
                Text("UNDO")
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(1.5)
            }
            .foregroundStyle(game.canUndo ? P.blossom.color : P.cream.color.opacity(0.3))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(P.ink.color.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .disabled(!game.canUndo)
    }

    private var bombButton: some View {
        let stocked = store.zombieBombs > 0 && !game.isOver
        return Button {
            guard stocked else { return }
            withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                bombTargeting.toggle()
                bombAnchor = (1, 1)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "burst.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(bombTargeting ? "CANCEL" : "DEPTH CHARGE")
                    .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                    .tracking(1.8)
                if !bombTargeting {
                    Text("×\(store.zombieBombs)")
                        .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                        .foregroundStyle(stocked ? P.blossom.color : P.cream.color.opacity(0.35))
                }
            }
            .foregroundStyle(stocked ? P.torch.color : P.cream.color.opacity(0.35))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Capsule().fill(P.ink.color.opacity(stocked ? 0.7 : 0.45)))
            .overlay(Capsule().stroke(P.torch.color.opacity(stocked ? (bombChipBreathe ? 0.9 : 0.35) : 0), lineWidth: 2))
            .shadow(color: P.torch.color.opacity(bombChipBreathe ? 0.8 : 0), radius: bombChipBreathe ? 12 : 5)
        }
        .buttonStyle(.plain)
        .disabled(!stocked)
        .scaleEffect(bombChipBreathe ? 1.1 : 1.0)
        .transition(.scale(scale: 0.3).combined(with: .opacity))
        .onAppear(perform: syncBombBreathe)
        .onChange(of: store.zombieBombs) { syncBombBreathe() }
        .onChange(of: game.isOver) { syncBombBreathe() }
        .onDisappear { bombChipBreathe = false }
    }

    /// Breathe only while a charge is stocked and the run is live — an
    /// empty slot pulsing would promise a tap that does nothing. Cipher
    /// breathe idiom: guarded start, easeOut stop, Reduce Motion static.
    private func syncBombBreathe() {
        let shouldBreathe = !reduceMotion && store.zombieBombs > 0 && !game.isOver
        if shouldBreathe, !bombChipBreathe {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                bombChipBreathe = true
            }
        } else if !shouldBreathe, bombChipBreathe {
            withAnimation(.easeOut(duration: 0.3)) { bombChipBreathe = false }
        }
    }

    private func scoreChip(_ label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.cream.color.opacity(0.75))
            Text("\(value)")
                .font(.custom("Futura-Bold", size: 19, relativeTo: .body))
                .foregroundStyle(P.blossom.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Capsule().fill(P.ink.color.opacity(0.55)))
    }
}
