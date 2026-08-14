import SwiftUI

/// Root of the app. The game picker IS the home screen; taps route to the
/// lounge (position 0) or one of the six games via `Destination`. The old
/// HomeView has been retired — its state migrated here.
struct ContentView: View {
    @Environment(PlayerStore.self) private var store
    /// Root-mounted so the restock notifier still arms when a game is
    /// open (GamePickerView unmounts on route switch).
    @Environment(\.scenePhase) private var scenePhase

    /// Set in `init` from the resolved launch target — see below.
    @State private var route: Destination
    /// One-shot exit hint after the welcome mug is claimed — see onChange
    /// below. Only ever true on the lounge route.
    @State private var exitHintActive = false
    /// Analytics boots on the first `.active`, never in `App.init()` —
    /// initialising during launch races GA's foreground handler and opens
    /// two sessions per launch (ANALYTICS_PLAN §3.1).
    @State private var analyticsStarted = false
    /// One `lives:zero:sessionend` per foreground session, not per background.
    @State private var zeroSessionLogged = false
    /// Last picker rail position — when the player backs out of a game (or
    /// the lounge), the home rail reopens on that slot instead of always
    /// snapping to The Lounge. Seeded from the resumed game so backing out
    /// of a cold-launch resume lands on that game's card, not the lounge.
    @State private var pickerFocus: PickerSlot

    // MARK: - Cold-launch resume

    /// The last game the player opened, persisted so a cold launch drops
    /// straight onto its board instead of the menu. The lounge deliberately
    /// never writes it — "open into play" means a game, not the meta room.
    private static let lastGameKey = "tikiLastGame"

    /// Which game the app belongs in on a cold launch — pure, so it stays
    /// testable. The last game the player opened, or **Luau** when there
    /// isn't one: a fresh install opens into the deepest game in the
    /// bundle rather than a menu. Never nil — the picker is a place you
    /// navigate to, not the place you land.
    /// The game to resume into, or nil to open the picker. v2 trim: a fresh
    /// install no longer drops straight into Luau — new players land on the
    /// home rail and choose. Only returning players resume, and only into a
    /// game still on the roster (a stored `cabanaCipher` must not reopen a
    /// hidden game).
    static func resumeTarget(lastGameRaw: String?) -> TikiGame? {
        guard let raw = lastGameRaw, let game = TikiGame(rawValue: raw),
              TikiGame.allCases.contains(game) else { return nil }
        return game
    }

    /// The resolved landing, or nil to open the picker instead. Nil when the
    /// lives pool is empty — resuming onto a live board would otherwise skip
    /// the picker's out-of-lives gate, and defeats at zero lives are free
    /// (`spendLife` no-ops), which would make the wall trivially bypassable.
    /// Also nil under tests and previews, where a resumed route would
    /// silently hide the picker.
    @MainActor
    static func launchTarget(store: PlayerStore) -> TikiGame? {
        let env = ProcessInfo.processInfo.environment
        guard env["XCTestConfigurationFilePath"] == nil,
              env["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
        else { return nil }
        guard let game = resumeTarget(lastGameRaw: UserDefaults.standard.string(forKey: lastGameKey))
        else { return nil }
        return store.isOutOfLives(for: game) ? nil : game
    }

    /// `launchTarget` is resolved by the App (which owns the store) and
    /// handed in, so the landing is decided before first render — no picker
    /// frame flashes ahead of the resumed board.
    init(launchTarget: TikiGame? = nil) {
        _route = State(initialValue: launchTarget.map(Destination.game) ?? .picker)
        _pickerFocus = State(initialValue: launchTarget.map(PickerSlot.game) ?? PickerSlot.home)
    }

    var body: some View {
        Group {
            // Dev shortcuts: launch directly into any scene with
            // SIMCTL_CHILD_TIKI_BG=<name>. Bypasses the picker.
            switch ProcessInfo.processInfo.environment["TIKI_BG"] {
            case "luau": LuauView()
            case "zombie": ZombieView()
            case "cipher": CipherView()
            case "blueprints": BlueprintsView()
            case "lagoon": TikiBackgroundView()
            case "navigator": NavigatorView()
            case "navigatorbg": NavigatorBackgroundView()   // bare scene, for background staging
            case "codetree":
                // Exploratory bare scene. TIKI_TREE_SPIRE lifts the centre into
                // a trunk; TIKI_TREE_TINT=torch wears the game's palette.
                if ProcessInfo.processInfo.environment["TIKI_TREE_STYLE"] == "petals" {
                    CodePetalTreeView(
                        rings: Int(ProcessInfo.processInfo.environment["TIKI_TREE_RINGS"] ?? "") ?? 6,
                        spire: Double(ProcessInfo.processInfo.environment["TIKI_TREE_SPIRE"] ?? "") ?? 190
                    ).ignoresSafeArea()
                } else {
                    CodeTreeView(
                        tint: ProcessInfo.processInfo.environment["TIKI_TREE_TINT"] == "torch"
                            ? P.torch.color.opacity(0.55) : Color.white.opacity(140.0 / 255.0),
                        spire: Double(ProcessInfo.processInfo.environment["TIKI_TREE_SPIRE"] ?? "") ?? 22
                    ).ignoresSafeArea()
                }
            case "stacks": TikiStacksView()
            case "lounge": LoungeView()
            default: main
            }
        }
        .onAppear(perform: applyDebugHooks)
        // Dimensions go stale otherwise. A player who launches with a full
        // pool, empties it, and quits would carry `lives_healthy` on every
        // event of that session — including `lives:zero:sessionend`, which
        // is the exact opposite of what D-4 asks. Re-stamp on every change.
        .onChange(of: store.lives) { _, _ in refreshDimensionsIfStarted() }
        .onChange(of: route) { _, _ in refreshDimensionsIfStarted() }
        // Restock local notification — schedule on background, clear on
        // active. Lives only change while running (in-app spends; refill
        // is roll-on-read wall clock), so background-time schedule is exact.
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                let untilFull = store.secondsUntilFull()
                Task { await LivesRestockNotifier.shared.syncOnBackground(secondsUntilFull: untilFull) }
                // Sessions that end empty are the lives economy's headline
                // number (ANALYTICS_PLAN D-4). Latched: backgrounding five
                // times at zero is one session ending at zero, not five.
                if store.lives == 0, !zeroSessionLogged {
                    zeroSessionLogged = true
                    Analytics.design("lives:zero:sessionend")
                }
            case .active:
                LivesRestockNotifier.shared.syncOnActive()
                startAnalyticsIfNeeded()
                zeroSessionLogged = false
            default:
                break
            }
        }
    }

    /// Boots the SDK once, then stamps the three sticky dimensions. Order
    /// matters: GA validates dimension values against the lists registered
    /// inside `start()`, so nothing may be set before it.
    private func startAnalyticsIfNeeded() {
        guard !analyticsStarted else { return }
        analyticsStarted = true
        Analytics.start()
        AppHealth.shared.start()
        refreshDimensions()
        stampSessionState()
    }

    /// Re-stamps the three sticky splits from current state. Cheap, and the
    /// only way `custom_01`/`custom_03` mean anything: both are time-varying,
    /// and a launch-only stamp describes the player as they were when the app
    /// opened rather than when the event fired.
    private func refreshDimensions() {
        Analytics.setDimensions(
            breadth: store.analyticsBreadth,
            entry: store.analyticsEntry,
            livesPressure: store.analyticsLivesTier
        )
    }

    private func refreshDimensionsIfStarted() {
        guard analyticsStarted else { return }
        refreshDimensions()
    }

    /// Once-per-session state that only makes sense as a rate over sessions.
    private func stampSessionState() {
        // Three states, not two: auth is deferred for brand-new installs
        // (TikiGamesApp gates it on having a best score), so a player who
        // never finishes a run is never even asked. Reporting only ok/fail
        // would drop them and inflate the enabled rate (§5.6.2).
        let gc: String
        if GameCenter.shared.isAuthenticated {
            gc = "on"
        } else if TikiGame.allCases.contains(where: { store.bestScore(for: $0) > 0 }) {
            gc = "off"
        } else {
            gc = "unattempted"
        }
        Analytics.design("gc:state:\(gc)")

        // If Reduce Motion adoption is material, the animation budget is
        // being spent on players who never see it (D-18).
        if UIAccessibility.isReduceMotionEnabled { Analytics.design("a11y:reducemotion") }
        if UIAccessibility.isVoiceOverRunning { Analytics.design("a11y:voiceover") }
    }

    @ViewBuilder
    private var main: some View {
        ZStack {
            switch route {
            case .picker:
                GamePickerView(
                    onLaunch: { slot in
                        pickerFocus = slot
                        // The picker runs its own expansion for games; slam
                        // the parent state without animation so the two
                        // transitions don't ghost through each other.
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) {
                            route = destination(for: slot)
                        }
                        if case .game(let g) = route {
                            // custom_02 records the first game the player
                            // CHOOSES. It deliberately does not fire on the
                            // cold-launch route: `resumeTarget` hands every
                            // fresh install Luau, so capturing that would
                            // tag ~100% of installs `first_luau` and make
                            // D-3 ("which game should be the front door?")
                            // answer itself. Nil until a real choice is made.
                            store.noteFirstGame(g)
                            Analytics.gameStarted(g)
                            // Remembered for the next cold launch.
                            UserDefaults.standard.set(g.rawValue, forKey: Self.lastGameKey)
                        }
                    },
                    onClose: {},
                    initialFocus: pickerFocus
                )
                .transition(.opacity)
            case .lounge:
                LoungeView()
                    .transition(.opacity)
                backButton
                    .transition(.opacity)
            case .game(let game):
                gameView(for: game)
                    .transition(.opacity)
                // Navigator draws its own back button so it can intercept
                // the tap with a "pause voyage?" confirmation (back-out
                // during a run costs one passage per the anti-abuse rule).
                if game != .navigator {
                    backButton
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.30), value: routeID)
        // Claiming the welcome mug ends the lounge FTUE with the expand
        // toast ("play the games…") — this pulse shows the door it means.
        // Rides the same 3000 ms beat as the toast, lingers 2 s past it.
        .onChange(of: store.placedItemIDs) { old, new in
            guard route == .lounge,
                  new.contains(PlayerStore.welcomeGiftItemID),
                  !old.contains(PlayerStore.welcomeGiftItemID) else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(3000))
                guard route == .lounge else { return }
                withAnimation(.spring(duration: 0.45, bounce: 0.3)) { exitHintActive = true }
                try? await Task.sleep(for: .milliseconds(5200))
                withAnimation(.easeOut(duration: 0.5)) { exitHintActive = false }
            }
        }
    }

    private var routeID: String {
        switch route {
        case .picker: return "picker"
        case .lounge: return "lounge"
        case .game(let g): return "game.\(g.rawValue)"
        }
    }

    private func destination(for slot: PickerSlot) -> Destination {
        switch slot {
        case .lounge: return .lounge
        // The banner never launches — its chooser is an overlay inside the
        // picker (cardTapped intercepts before onLaunch). Exhaustiveness
        // only; routing it back to the picker is the safe no-op.
        case .leaderboards: return .picker
        case .game(let g): return .game(g)
        }
    }

    @ViewBuilder
    private func gameView(for game: TikiGame) -> some View {
        switch game {
        case .tikiStacks: TikiStacksView(onExitRequested: { route = .picker })
        case .luau: LuauView(onExitRequested: { route = .picker })
        case .zombie: ZombieView(onExitRequested: { route = .picker })
        case .cabanaCipher: CipherView(onExitRequested: { route = .picker })
        case .blueprints: BlueprintsView(onExitRequested: { route = .picker })
        case .navigator: NavigatorView(onExitRequested: { route = .picker })
        }
    }

    private var backButton: some View {
        VStack {
            HStack {
                Button {
                    route = .picker
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(P.blossom.color)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(P.ink.color.opacity(0.55)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to picker")
                .overlay {
                    if exitHintActive {
                        CoachPulse(skin: .lounge, diameter: 66)
                            .allowsHitTesting(false)
                    }
                }
                Spacer()
            }
            Spacer()
        }
        .padding(.leading, 20)
        .padding(.top, 8)
    }

    /// Dev hooks: SIMCTL_CHILD_TIKI_POINTS=<n> grants points;
    /// SIMCTL_CHILD_TIKI_BUY=all|id,id purchases through the real flow.
    private func applyDebugHooks() {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        if let raw = env["TIKI_POINTS"], let n = Int(raw) {
            store.debugGrant(points: n)
        }
        if let buy = env["TIKI_BUY"] {
            let ids = buy == "all"
                ? store.loungeItems.map(\.itemID)
                : buy.split(separator: ",").map(String.init)
            for id in ids { store.purchase(id) }
        }
        // SIMCTL_CHILD_TIKI_DEPTH=<id>:<0..1>,... pulls floor pieces down
        // the floor through the real placement path (continuous-depth
        // screenshots).
        if let raw = env["TIKI_DEPTH"] {
            for pair in raw.split(separator: ",") {
                let parts = pair.split(separator: ":")
                if parts.count == 2, let depth = Double(parts[1]) {
                    store.setItemDepth(String(parts[0]), depth: depth)
                }
            }
        }
        // SIMCTL_CHILD_TIKI_BEST=<game rawValue>:<score> seeds a best score.
        if let raw = env["TIKI_BEST"] {
            let parts = raw.split(separator: ":")
            if parts.count == 2, let game = TikiGame(rawValue: String(parts[0])),
               let score = Int(parts[1]) {
                store.debugSetBest(game: game, score: score)
            }
        }
        // SIMCTL_CHILD_TIKI_STREAK=<game rawValue>:<n>[:<best>] stages a
        // live win streak, optionally under a higher standing best
        // (panel N-IN-A-ROW protocols).
        if let raw = env["TIKI_STREAK"] {
            let parts = raw.split(separator: ":")
            if parts.count >= 2, let game = TikiGame(rawValue: String(parts[0])),
               let n = Int(parts[1]) {
                store.debugSetStreak(game: game, streak: n,
                                     best: parts.count >= 3 ? Int(parts[2]) : nil)
            }
        }
        // SIMCTL_CHILD_TIKI_OPEN=<game rawValue> routes straight into a
        // game view on launch — entry is picker-first and simctl can't tap,
        // so full-screen game states had no headless path.
        if let raw = env["TIKI_OPEN"], let game = TikiGame(rawValue: raw) {
            pickerFocus = .game(game)
            route = .game(game)
        }
        // SIMCTL_CHILD_TIKI_LUAU_SELFTEST=1 runs the Stage A engine
        // verification and prints PASS/FAIL/SUMMARY lines to stdout.
        // Read via `xcrun simctl launch --console`.
        if env["TIKI_LUAU_SELFTEST"] == "1" {
            LuauSelfTest.run()
        }
        #endif
    }
}

/// Where the app can route to at the root.
enum Destination: Hashable {
    case picker
    case lounge
    case game(TikiGame)
}

#Preview {
    ContentView()
        .environment(PlayerStore(inMemory: true))
}
