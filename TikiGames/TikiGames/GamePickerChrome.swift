import SwiftUI
import AVFoundation

/// Picker top bar — lives chip, PICK A GAME title, HOME / Nº k OF N counter.
/// Extracted from GamePickerView so chrome edits don't fight carousel work.
struct GamePickerTopBar: View {
    let progress: Double

    var body: some View {
        HStack {
            LivesChip()
            Spacer()
            counter
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .overlay {
            Text("PICK A GAME")
                .font(.custom("Futura-Bold", size: 16, relativeTo: .body))
                .tracking(3)
                .foregroundStyle(P.blossom.color)
        }
        // The bar is decorative chrome (counter is VO-hidden; cards carry
        // the accessible text). Past xLarge the tracked caps collide with
        // the counter, and minimumScaleFactor is unreliable under tracking.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
    }

    private var counter: some View {
        // Position 0 is the leaderboard banner (THE BOARDS); 1..N are the
        // games (Nº k OF N).
        let count = TikiGame.allCases.count
        // "· BOARDS ·" over anything longer: the counter is right-aligned
        // against the centered PICK A GAME title and a wide label collides
        // with it (measured: "· THE BOARDS ·" overlapped the E).
        let raw = min(count, max(0, Int(progress.rounded())))
        let label = raw == 0 ? "· BOARDS ·" : "Nº \(raw) OF \(count)"
        return Text(label)
            .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
            .tracking(2)
            .foregroundStyle(P.cream.color.opacity(0.70))
            .contentTransition(.opacity)
            .animation(.snappy(duration: 0.25), value: label)
            .accessibilityHidden(true)
    }
}

/// Expanding window overlay during game launch — seeds from the card window
/// and fills the screen. Extracted from GamePickerView.
struct GamePickerLaunchOverlay: View {
    let state: GamePickerLaunchState
    let player: AVPlayer

    var body: some View {
        GeometryReader { g in
            let origin = g.frame(in: .global).origin
            // Same top-aligned fill math as the card window, so the
            // overlay seeds pixel-identical to the window it replaces
            // and converges to full-bleed at screen size.
            let fillW = max(state.rect.width, state.rect.height * TikiGame.previewAspect)
            ZStack(alignment: .top) {
                // Poster underlay: a tap that lands before the player's
                // layer is ready still expands footage, never a hole.
                if let poster = PickerSlot.game(state.game).previewPoster {
                    poster
                        .resizable()
                        .frame(width: fillW, height: fillW / TikiGame.previewAspect)
                }
                PlayerLayerHost(player: player)
                    .frame(width: fillW, height: fillW / TikiGame.previewAspect)
            }
            .frame(width: state.rect.width, height: state.rect.height, alignment: .top)
            .clipShape(RoundedRectangle(cornerRadius: state.radius))
            .position(
                x: state.rect.midX - origin.x,
                y: state.rect.midY - origin.y
            )
            .opacity(state.opacity)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Launch overlay state — window rect + corner radius + fade.
struct GamePickerLaunchState {
    let game: TikiGame
    var rect: CGRect
    var radius: CGFloat
    var opacity: Double
}
