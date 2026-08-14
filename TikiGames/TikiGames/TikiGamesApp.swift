import SwiftUI

@main
@MainActor
struct TikiGamesApp: App {
    @State private var store = PlayerStore()

    // Analytics deliberately does NOT boot here. Initialising during launch
    // races GA's own foreground handler, which ends the just-started session
    // and opens a second one — measured on 3/3 launches, doubling session
    // counts and halving average session length. It boots on the first
    // `.active` scenePhase in ContentView instead (ANALYTICS_PLAN §3.1).

    var body: some Scene {
        WindowGroup {
            // The landing is resolved here, where the store already exists,
            // so ContentView can seed its route before first render.
            ContentView(launchTarget: ContentView.launchTarget(store: store))
                .environment(store)
                .onAppear {
                    TikiSound.shared.warmUp()
                    // Before the Game Center gate below reads any best.
                    store.migrateTopShelfBestToBoardValue()
                    // Game Center stays silent for brand-new installs (the
                    // FTUE owns the first minutes); returning players
                    // authenticate at launch so parked scores land. A new
                    // player's first run end triggers it instead.
                    if TikiGame.allCases.contains(where: { store.bestScore(for: $0) > 0 }) {
                        GameCenter.shared.authenticate()
                        GameCenter.shared.backfillBests(from: store)
                    }
                }
        }
    }
}
