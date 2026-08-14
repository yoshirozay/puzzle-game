import SwiftUI

/// Uniform press feedback for chrome buttons that otherwise animate their
/// side effects but leave the tap itself inert (post-run retry/next/back,
/// level-picker cards, shop buys). Scales + fades on press with reduce-motion
/// falling back to opacity only.
struct SoftPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (pressed ? 0.96 : 1.0))
            .opacity(pressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.14), value: pressed)
    }
}
