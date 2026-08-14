import SwiftUI

/// Small picker-chrome chip: shared hearts row + stacked countdown while
/// below cap. Each tick reads a pure `livesSnapshot` — view bodies never
/// write store state.
struct LivesChip: View {
    @Environment(PlayerStore.self) private var store

    var body: some View {
        // A player no game charges yet has no pool to read — showing a full
        // row of hearts would advertise a limit that is not being applied.
        // The chip appears the first time any game activates.
        if store.livesActiveAnywhere {
            chip
        }
    }

    private var chip: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let snap = store.livesSnapshot(now: context.date)
            LivesHearts(
                count: snap.count,
                size: .chip,
                secondsToNext: snap.secondsToNext,
                stackCountdown: true,
                countdownPrefix: ""
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(P.ink.color.opacity(0.55)))
        }
    }
}

#Preview {
    ZStack {
        P.woodDark.color.ignoresSafeArea()
        LivesChip()
            .environment(PlayerStore(inMemory: true))
    }
}
