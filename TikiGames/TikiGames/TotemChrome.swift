import SwiftUI

/// Totem scoreboard header — score/best art, lives under the board, mood
/// mask, how-to. Extracted from TikiStacksView so chrome edits don't fight
/// board / tray / game-over work in the same file.
struct TotemChrome: View {
    let game: TikiStacksGame
    let coachActive: Bool
    let maskPulse: CGFloat
    let W: CGFloat
    var onHowTo: () -> Void

    @Environment(PlayerStore.self) private var store

    var body: some View {
        // The row's rigid width (scoreboard + mask + how-to + paddings) fills
        // a 402 pt screen — anything added beside them overflows, and an
        // over-wide header re-anchors the root ZStack top-leading, shoving
        // the centered board off the right edge. The hearts therefore stack
        // UNDER the scoreboard (like Luau/Top Shelf tuck them under BEST),
        // and spacing/trailing stay trimmed so the how-to row fits 402 pt
        // exactly (12-pt gaps + the Spacer's default minimum overflowed by
        // ~19 pt, listing the whole screen right — measured, not assumed).
        // .top alignment + compensating paddings keep mask and how-to at the
        // heights they had when .center aligned them against the scoreboard.
        let scoreboardH = W * 0.44 * 150 / 360
        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .trailing, spacing: 6) {
                Image.uiScoreboard
                    .resizable()
                    .frame(width: W * 0.44, height: scoreboardH)
                    .overlay(
                        GeometryReader { g in
                            // score inside the cream window (window rect 28,26,212,86 of 360x150)
                            Text("\(game.score)")
                                .font(.custom("Futura-Bold", size: g.size.height * 0.40))
                                .foregroundStyle(Color(red: 0.231, green: 0.141, blue: 0.090))
                                .minimumScaleFactor(0.4)
                                .lineLimit(1)
                                .frame(width: g.size.width * 0.52)
                                .position(x: g.size.width * 0.372, y: g.size.height * 0.46)
                            // best under the crown badge (badge rect 256,26,76,86; crown at y 40-73)
                            Text("\(game.best)")
                                .font(.custom("Futura-Bold", size: g.size.height * 0.15))
                                .foregroundStyle(Color(red: 0.910, green: 0.702, blue: 0.235))
                                .minimumScaleFactor(0.5)
                                .lineLimit(1)
                                .frame(width: g.size.width * 0.20)
                                .position(x: g.size.width * 0.817, y: g.size.height * 0.613)
                        }
                    )
                // Quiet lives HUD — count only; last-life breathe is inside
                // LivesHearts. Snapshot + 30s tick:
                // the `lives` mirror only moves at mutation points, so a pure
                // wall-clock refill needs the periodic re-read to reach the HUD
                // (spends still land instantly via the profile-model read).
                // Hidden until Totem starts charging this player — showing
                // hearts a defeat will not spend advertises a limit that is
                // not being applied.
                if store.livesActive(for: .tikiStacks) {
                    TimelineView(.periodic(from: .now, by: 30)) { ctx in
                        LivesHearts(count: store.livesSnapshot(now: ctx.date).count,
                                    size: .chip, pulseOnDecrement: true)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(P.ink.color.opacity(0.45)))
                }
            }
            Spacer(minLength: 0)
            maskView
                .frame(width: W * 0.15, height: W * 0.15)
                .padding(.top, (scoreboardH - W * 0.15) / 2)
            if !coachActive {
                HowToPlayButton(action: onHowTo)
                    .padding(.top, (scoreboardH - 44) / 2)
            }
        }
        .padding(.leading, 72)
        .padding(.trailing, 20)
    }

    private var maskView: some View {
        Group {
            switch game.mood {
            case .happy: Image.maskHappy.resizable().scaledToFit()
            case .surprised: Image.maskSurprised.resizable().scaledToFit()
            case .grumpy: Image.maskGrumpy.resizable().scaledToFit()
            case .sleepy: Image.maskSleepy.resizable().scaledToFit()
            }
        }
        .id(game.mood)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(duration: 0.35), value: game.mood)
        .scaleEffect(maskPulse)
    }
}
