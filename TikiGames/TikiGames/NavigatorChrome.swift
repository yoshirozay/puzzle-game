import SwiftUI

/// Navigator HUD — how-to + lives top-trailing, passage/stars/mistakes/peek
/// status row at the bottom. Extracted from NavigatorView so chrome edits
/// don't fight board / end-panel / coach work in the same file.
struct NavigatorChrome: View {
    let game: NavigatorGame
    let showTopChrome: Bool
    let peekAvailable: Bool
    var onHowTo: () -> Void
    var onPeek: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        if showTopChrome {
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    // Leading is the back button's home — lives sit trailing
                    // under / beside how-to so the two never stack.
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        HowToPlayButton(action: onHowTo)
                        // Snapshot + 30s tick — mid-run refills reach the HUD
                        // (the `lives` mirror only moves at mutation points).
                        TimelineView(.periodic(from: .now, by: 30)) { ctx in
                            LivesHearts(count: store.livesSnapshot(now: ctx.date).count, size: .chip)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(P.ink.color.opacity(0.55)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 64)
                Spacer()
            }
        }
        VStack {
            Spacer()
            statusRow
                .padding(.bottom, 46)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            if let lvl = game.level {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PASSAGE \(lvl.id)")
                        .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                        .tracking(1.5)
                        .foregroundStyle(P.blossom.color)
                    Text(game.loopSubtitle(lvl))
                        .font(.custom("Futura-Medium", size: 9, relativeTo: .body))
                        .tracking(1.2)
                        .foregroundStyle(P.cream.color.opacity(0.75))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(P.ink.color.opacity(0.55)))
                .accessibilityElement(children: .combine)

                HStack(spacing: 5) {
                    StarShape()
                        .fill(P.blossom.color)
                        .frame(width: 13, height: 13)
                    Text("\(game.starsFound)/\(game.starsTotal)")
                        .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                        .foregroundStyle(P.blossom.color)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Capsule().fill(P.ink.color.opacity(0.55)))
                .accessibilityLabel("\(game.starsFound) of \(game.starsTotal) stars charted")

                HStack(spacing: 5) {
                    ForEach(0..<max(lvl.mistakes, 1), id: \.self) { i in
                        Circle()
                            .fill(i < game.mistakesLeft ? P.cream.color.opacity(0.85) : P.coral.color)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 13)
                .background(Capsule().fill(P.ink.color.opacity(0.55)))
                .accessibilityLabel("\(game.mistakesLeft) mistakes left")

                Button(action: onPeek) {
                    HStack(spacing: 5) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("PEEK ×\(game.peeksLeft)")
                            .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                            .tracking(1)
                    }
                    .foregroundStyle(peekAvailable ? P.ink.color : P.cream.color.opacity(0.45))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(peekAvailable ? P.torch.color : P.ink.color.opacity(0.45)))
                }
                .buttonStyle(.plain)
                .disabled(!peekAvailable)
                .accessibilityLabel("Peek, \(game.peeksLeft) left")
            }
        }
    }

}

extension NavigatorGame {
    /// Subtitle under PASSAGE N — the family name on loop 1, LOOP N on
    /// later loops so the "faster ball" state is obvious at a glance.
    /// Shared by the chrome row and the end panel so the two can't drift.
    func loopSubtitle(_ lvl: NavigatorLevel) -> String {
        if loopNumber > 1 {
            return "LOOP \(loopNumber)"
        }
        return lvl.family.uppercased()
    }
}
