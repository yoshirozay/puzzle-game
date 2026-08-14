import Foundation

/// Game → scene progress signal. Games compute it from their @Observable
/// engines; the background scenes render it. Equatable so views cheaply
/// detect changes. The default value is exactly today's scene.
struct ProgressPhase: Equatable {
    var stage: Int = 0        // index into the game's named depth-state ladder
    var depth: Double = 0     // 0...1 continuous ladder position
    var tier: Int = 0         // persistent cross-run mark (bottles, lanterns, pennants)
    var beat: Int = 0         // increments on clear/merge/solve — one-shot flourishes
    /// Continuous WITHIN-RUN headroom above the named `stage` ladder, 0...1.
    /// A scene whose ladder tops out early (Luau's does: INFERNO lands at 700
    /// while a median winning night scores 2,170) has nowhere left to grow for
    /// most of a run. This is that missing top end, kept separate from
    /// `depthThresholds` so it cannot disturb the milestone payouts those
    /// thresholds also drive. Resets with the run, like `stage` and `depth`.
    var swell: Double = 0
}

/// Frame-exact easing inside TimelineView scenes (Canvas fills can't take
/// implicit animation, so we smoothstep against the clock the scenes already
/// have). Under reduceMotion the TimelineView pauses, `t` freezes, and
/// `eased(at:)` simply holds — no special casing.
struct DepthDial {
    private(set) var target: Double = 0
    private var previous: Double = 0
    private var changedAt: TimeInterval = 0

    mutating func set(_ v: Double, at t: TimeInterval) {
        guard abs(v - target) > 0.001 else { return }
        previous = eased(at: t)
        target = v
        changedAt = t
    }

    func eased(at t: TimeInterval, duration: Double = 4) -> Double {
        let x = min(1, max(0, (t - changedAt) / duration))
        return previous + (target - previous) * x * x * (3 - 2 * x)
    }
}
