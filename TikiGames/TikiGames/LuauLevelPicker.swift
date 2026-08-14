import SwiftUI

/// The Luau campaign entry surface. Presents a numbered grid of levels
/// (states: locked / next / done). Modeled after
/// `BlueprintsView.puzzleCard` grid so the pattern reads as house style.
/// The campaign IS the game — the historic endless mode has no player
/// entry point anymore (engine keeps it for staging hooks + legacy saves).
///
/// A level is "next" if it's `completedLevels.max() + 1` (or 1 for a fresh
/// player). Everything past "next" is locked. This is the campaign spine —
/// no timers, no lives, free retry via the in-level panel.
struct LuauLevelPicker: View {
    let completedLevels: [Int]
    let onLevelSelected: (LuauLevel) -> Void

    /// Initial scroll target: the frontier night, centered. Seeded in init
    /// so the scroll view opens there before first render — the previous
    /// scrollTo-on-appear raced LazyVGrid layout and often lost, leaving
    /// the player at night 1.
    @State private var scrolledID: Int?

    init(completedLevels: [Int], onLevelSelected: @escaping (LuauLevel) -> Void) {
        self.completedLevels = completedLevels
        self.onLevelSelected = onLevelSelected
        let frontierIdx = LuauLevels.frontierIndex(completed: completedLevels)
        // An early frontier already reads at the top of the grid — only
        // jump once it would sit below the fold.
        _scrolledID = State(initialValue: frontierIdx > 5
            ? LuauLevels.frontierLevel(completed: completedLevels)?.id
            : nil)
    }

    /// Positional frontier — see LuauLevels.playIndex for why this is not id
    /// arithmetic any more.
    private var frontierIndex: Int {
        LuauLevels.frontierIndex(completed: completedLevels)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("LUAU")
                .font(.custom("Futura-Bold", size: 26, relativeTo: .largeTitle))
                .tracking(4)
                .foregroundStyle(P.blossom.color)
                .padding(.top, 8)
            Text("PICK A NIGHT")
                .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.cream.color.opacity(0.8))
                .padding(.top, 4)
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                    ],
                    spacing: 12
                ) {
                    ForEach(LuauLevels.all) { level in
                        levelCard(level)
                            .id(level.id)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollPosition(id: $scrolledID, anchor: .center)
        }
    }

    // MARK: cards

    private func levelCard(_ level: LuauLevel) -> some View {
        let done = completedLevels.contains(level.id)
        let locked = (LuauLevels.playIndex(of: level.id) ?? Int.max) > frontierIndex
        return Button {
            guard !locked else { return }
            onLevelSelected(level)
        } label: {
            VStack(spacing: 4) {
                // A LESSON IS NOT A NIGHT — it wears a torch instead of a number,
                // and the numbers either side of it stay 4 and 5. The number is
                // computed over non-lesson levels rather than read off `id`, so
                // dropping a lesson in never renumbers the campaign.
                Text(done || level.isLesson ? "" : "\(LuauLevels.nightNumber(of: level.id) ?? level.id)")
                    .font(.custom("Futura-Bold", size: 26, relativeTo: .body))
                    .foregroundStyle(locked ? P.cream.color.opacity(0.35) : P.blossom.color)
                    .frame(height: 40)
                    .overlay {
                        if done {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(P.torch.color)
                        } else if level.isLesson {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(locked ? P.cream.color.opacity(0.35) : P.torch.color)
                        }
                    }
                Text(level.archetype.uppercased())
                    .font(.custom("Futura-Bold", size: 8, relativeTo: .body))
                    .tracking(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundStyle(P.cream.color.opacity(locked ? 0.3 : 0.75))
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14).fill(P.deepLeaf.color.opacity(locked ? 0.35 : 0.85)))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(cardBorderColor(done: done, locked: locked),
                        lineWidth: 1.5))
        }
        .buttonStyle(SoftPressStyle())
        .disabled(locked)
        .accessibilityLabel(accessibilityLabel(level: level, done: done, locked: locked))
    }

    private func cardBorderColor(done: Bool, locked: Bool) -> Color {
        if locked { return P.cream.color.opacity(0.12) }
        if done { return P.torch.color.opacity(0.6) }
        return P.blossom.color.opacity(0.25)
    }

    private func accessibilityLabel(level: LuauLevel, done: Bool, locked: Bool) -> String {
        let state = locked ? "locked" : (done ? "completed" : "available")
        return "Level \(level.id), \(level.archetype), \(state)"
    }
}
