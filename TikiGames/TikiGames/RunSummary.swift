import Foundation

/// The payoff panel's data model — every game view receives one from
/// `PlayerStore.recordRun(...)` at run end. Lifted out of `PlayerStore.swift`
/// so headless tools (LevelForge) can source `LuauGame` without pulling in
/// SwiftData / SwiftUI.
struct RunSummary {
    let best: Int
    let isNewBest: Bool
    let pointsEarned: Int
    let totalPoints: Int
}
