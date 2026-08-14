import SwiftUI

/// One-line milestone toast for the game-over panels — Vic's voice, one
/// message, skinnable accent. Games hang it below their panel when a depth
/// milestone was newly minted this run ("+75 POINTS").
struct MilestoneToast: View {
    let message: String
    var accent: Color = Color(red: 0.910, green: 0.702, blue: 0.235)
    var fontSize: CGFloat = 15
    /// When the toast shares a stage with a bigger beat (the Cipher streak
    /// stamp), the caller pushes it later so it never moves first.
    var delay: Double = 0.35

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        Text(message)
            .font(.custom("Futura-Bold", size: fontSize))
            .tracking(1.5)
            .foregroundStyle(accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(P.ink.color.opacity(0.55)))
            .scaleEffect(reduceMotion ? 1 : (shown ? 1 : 0.8))
            .opacity(shown ? 1 : 0)
            .onAppear {
                let anim: Animation = reduceMotion
                    ? .easeOut(duration: 0.28).delay(delay)
                    : .spring(duration: 0.45, bounce: 0.4).delay(delay)
                withAnimation(anim) { shown = true }
            }
            .transition(reduceMotion
                        ? .opacity
                        : .opacity.combined(with: .scale(scale: 0.9)))
            .accessibilityAddTraits(.isStaticText)
    }
}

#Preview {
    ZStack {
        P.lagoon.color.ignoresSafeArea()
        MilestoneToast(message: "+75 POINTS")
    }
}
