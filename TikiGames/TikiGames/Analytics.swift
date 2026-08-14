import Foundation
import GameAnalytics

/// Thin vendor wrapper around GameAnalytics. Every call site goes through
/// here so the backend can be swapped without touching game code.
///
/// Inert until credentials exist: create the game at gameanalytics.com,
/// then put its key pair in TikiGames/Secrets.xcconfig (gitignored — see
/// Config.xcconfig for the format). The pair still ships in the binary by
/// design — GA uses it to route and HMAC-sign events, not as a secret.
///
/// The taxonomy this implements — every event, its decision, and the volume
/// budgets it lives inside — is ANALYTICS_PLAN.md. Read that before adding
/// an event; the daily unique-identifier limits are real and breaching them
/// silently nulls event IDs rather than dropping them.
///
/// ⚠️ Never call from a file the LevelForge tool target compiles
/// (LuauGame/LuauLevel/LuauLevels/LuauBot/RunSummary — see project.yml).
/// GameAnalytics is iOS-only and the macOS tool build will break.
enum Analytics {

    /// Vendor-neutral mirrors of GA's enums. The SDK ships plain C enums
    /// whose Swift names keep their full prefix (`GAResourceFlowTypeSink`),
    /// and letting those leak into game code would defeat the point of this
    /// wrapper — swapping backends should not touch a single call site.
    enum Flow { case source, sink }
    enum Progress { case start, complete, fail }

    private static let gameKey = infoValue("GAGameKey")
    private static let gameSecret = infoValue("GAGameSecret")

    /// Reads a key the build injected from Config.xcconfig. Missing or
    /// blank (no Secrets.xcconfig) reads as "" and leaves us disabled.
    private static func infoValue(_ key: String) -> String {
        Bundle.main.infoDictionary?[key] as? String ?? ""
    }

    /// No credentials, test run, or SwiftUI preview → every call no-ops.
    ///
    /// The test guard matters more than it looks: the test bundle lives at
    /// `Tiki Lounge.app/PlugIns/`, so `Bundle.main` during tests is the APP
    /// and `GAGameKey` resolves non-empty. Without a working guard the suite
    /// writes to the live GA account. `TIKI_DISABLE_ANALYTICS` is set on the
    /// test action in project.yml and is the authoritative signal; the
    /// XCTestCase probe stays as a backstop for runs that bypass the scheme.
    private static var enabled: Bool {
        guard !gameKey.isEmpty else { return false }
        let env = ProcessInfo.processInfo.environment
        return env["TIKI_DISABLE_ANALYTICS"] != "1"
            && env["XCODE_RUNNING_FOR_PREVIEWS"] != "1"
            && NSClassFromString("XCTestCase") == nil
    }

    // MARK: - Vocabularies
    //
    // GA validates resource currencies, item types, and custom-dimension
    // values against lists registered BEFORE initialize. Anything not
    // declared here is rejected at the SDK boundary and never reaches the
    // dashboard, so these arrays and the call sites must stay in step.

    private static let currencies = ["points", "lives", "depthCharge", "loungeCat"]

    private static let itemTypes = [
        "run", "nightly", "milestone", "welcome", "decor", "defeat", "refill", "comp",
    ]

    /// custom_01 — breadth cohort. Six games, no banding (ANALYTICS_PLAN §4).
    private static let breadthValues = (1...6).map { "games_\($0)" }

    /// custom_02 — staged. First game played now; lounge engagement from
    /// Phase 3. Both value sets are registered so the swap needs no SDK
    /// change, and the prefixes keep the two eras legible in one dimension.
    private static let entryValues =
        TikiGame.allCases.map { "first_\($0.rawValue)" }
        + ["lounge_never", "lounge_visitor", "lounge_buyer", "lounge_decorator"]

    /// custom_03 — lives pressure.
    private static let livesValues = ["lives_healthy", "lives_pinched", "lives_zeroed"]

    // MARK: - Pre-init buffer
    //
    // `start()` runs on the first `.active` scenePhase, which lands AFTER the
    // first view's `.onAppear` and `.onChange(initial:)`. Anything emitted in
    // that window was being discarded by the SDK — measured: a coach
    // progression logged "Could not add progression event: SDK is not
    // initialized" half a second before initialize. That silently cost the
    // FTUE start (D-6) and the first run's progression start on every launch.
    //
    // Moving `start()` earlier is not an option: doing it in `App.init()` is
    // what double-counted every session. So early events queue here and
    // replay in order once the SDK is up.

    @MainActor private static var started = false
    @MainActor private static var buffered: [() -> Void] = []

    /// Runs `work` now, or queues it until `start()` has initialised the SDK.
    @MainActor
    private static func whenReady(_ work: @escaping () -> Void) {
        guard enabled else { return }
        if started {
            work()
        } else if buffered.count < 64 {
            // Bounded: a launch that never reaches `.active` must not grow
            // this without limit.
            buffered.append(work)
        }
    }

    // MARK: - Lifecycle

    /// Call once, on the first `.active` scenePhase — NOT from `App.init()`.
    /// Initialising during launch races GA's own foreground handler, which
    /// opens a second session and double-counts every session (measured 3/3
    /// launches before this moved). See ANALYTICS_PLAN §3.1.
    @MainActor
    static func start() {
        guard enabled else { return }
        #if DEBUG
        GameAnalytics.setEnabledInfoLog(true)
        #endif
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        GameAnalytics.configureBuild("\(version)(\(build))")

        // Must precede initialize.
        GameAnalytics.configureAvailableResourceCurrencies(currencies)
        GameAnalytics.configureAvailableResourceItemTypes(itemTypes)
        GameAnalytics.configureAvailableCustomDimensions01(breadthValues)
        GameAnalytics.configureAvailableCustomDimensions02(entryValues)
        GameAnalytics.configureAvailableCustomDimensions03(livesValues)

        GameAnalytics.initialize(withGameKey: gameKey, gameSecret: gameSecret)
        started = true
        let queued = buffered
        buffered = []
        for work in queued { work() }
    }

    /// Sticky player segmentation, set after `start()`. Values carry the
    /// state at event time, not at install — see ANALYTICS_PLAN §4.2 for how
    /// that constrains the reads.
    @MainActor
    static func setDimensions(breadth: String, entry: String?, livesPressure: String) {
        whenReady {
        GameAnalytics.setCustomDimension01(breadth)
        if let entry { GameAnalytics.setCustomDimension02(entry) }
        GameAnalytics.setCustomDimension03(livesPressure)
        }
    }

    // MARK: - Primitives

    /// Free-form event. `value` gets sum & mean aggregation in the dashboard.
    @MainActor
    static func design(_ eventId: String, value: Int? = nil) {
        whenReady {
        if let value {
            GameAnalytics.addDesignEvent(withEventId: eventId, value: NSNumber(value: value))
        } else {
            GameAnalytics.addDesignEvent(withEventId: eventId)
        }
        }
    }

    /// A level attempt. `value` carries **duration in seconds**, not score —
    /// score has its own home on `game:<game>:end` and GA allows only one
    /// numeric per event (ANALYTICS_PLAN §5.1).
    ///
    /// Never call for a coached/tutorial run: those play scripted boards and
    /// would corrupt every difficulty number with attempts that weren't real.
    @MainActor
    static func progression(_ status: Progress,
                            _ p01: String, _ p02: String, seconds: Int? = nil) {
        whenReady {
        let ga: GAProgressionStatus = switch status {
        case .start: GAProgressionStatusStart
        case .complete: GAProgressionStatusComplete
        case .fail: GAProgressionStatusFail
        }
        if let seconds {
            GameAnalytics.addProgressionEvent(
                with: ga,
                progression01: p01, progression02: p02, progression03: "",
                score: seconds
            )
        } else {
            GameAnalytics.addProgressionEvent(
                with: ga,
                progression01: p01, progression02: p02, progression03: ""
            )
        }
        }
    }

    /// Virtual-economy flow. `currency` and `itemType` must appear in the
    /// vocabularies above or GA drops the event.
    @MainActor
    static func resource(_ flow: Flow, currency: String,
                         amount: Int, itemType: String, itemId: String) {
        // GA rejects an empty itemId outright — measured, it silently dropped
        // every milestone mint until the caller was fixed. Fail loud in debug.
        assert(!itemId.isEmpty, "resource itemId must not be empty (\(currency)/\(itemType))")
        whenReady {
        let ga: GAResourceFlowType = switch flow {
        case .source: GAResourceFlowTypeSource
        case .sink: GAResourceFlowTypeSink
        }
        GameAnalytics.addResourceEvent(
            with: ga, currency: currency,
            amount: NSNumber(value: amount), itemType: itemType, itemId: itemId
        )
        }
    }

    /// Something went wrong that a player would feel. Kept for genuine
    /// faults — a persistent save failure means lost progress.
    @MainActor
    static func error(_ message: String) {
        whenReady {
            GameAnalytics.addErrorEvent(with: GAErrorSeverityError, message: message)
        }
    }

    // MARK: - Named events

    /// Player entered a game from the picker.
    @MainActor
    static func gameStarted(_ game: TikiGame) {
        design("game:\(game.rawValue):start")
    }

    // MARK: - Durations
    //
    // The clocks live here rather than in each view because several games
    // end their run from an escaping closure that cannot touch view @State
    // (TikiStacksView's `onGameOver` says so in as many words). One keyed
    // store, MainActor-isolated like every caller.

    @MainActor private static var clocks: [String: Date] = [:]

    @MainActor private static func clockStart(_ key: String) {
        clocks[key] = Date()
    }

    /// Elapsed whole seconds since `clockStart`, consuming the clock. Zero
    /// when it was never started — a run resumed from a save has no start.
    @MainActor private static func clockStop(_ key: String) -> Int {
        guard let began = clocks.removeValue(forKey: key) else { return 0 }
        return max(0, Int(Date().timeIntervalSince(began)))
    }

    /// A run began. `level` is the game's progression-02 label — see
    /// `ANALYTICS_PLAN` §5.1 for the per-game vocabulary and why two of them
    /// have to be bounded.
    @MainActor
    static func runStarted(_ game: TikiGame, level: String, tutorial: Bool = false) {
        clockStart("run:\(game.rawValue)")
        guard !tutorial else { return }
        progression(.start, game.progressionID, level)
    }

    /// A run ended. This is the ONLY place run outcomes are recorded — it is
    /// deliberately not wired into `PlayerStore.recordRun`, because that
    /// method's defeat coverage differs per game (three of six never call it
    /// on a loss), which made cross-game run counts incomparable and showed
    /// Blueprints and Cipher at a 100% win rate. See ANALYTICS_PLAN §3.2.
    ///
    /// Coached runs record nothing: they play scripted boards, so counting
    /// them would corrupt both the difficulty numbers and the run totals.
    @MainActor
    static func runEnded(_ game: TikiGame, level: String, won: Bool,
                         score: Int, tutorial: Bool = false) {
        let seconds = clockStop("run:\(game.rawValue)")
        guard !tutorial else { return }
        design("game:\(game.rawValue):end", value: score)
        progression(won ? .complete : .fail, game.progressionID, level, seconds: seconds)
    }

    /// Entering a surface — a game view or the lounge. Pairs with `exited`.
    @MainActor
    static func entered(_ surface: String) {
        clockStart("time:\(surface)")
    }

    /// Leaving a surface. Emits the visit duration, and — if a run was still
    /// live — records it as abandoned. Sum `time:*` for total playtime, mean
    /// it for average time per visit (§5.3.2).
    ///
    /// Hung off `.onDisappear`, which does NOT fire when the app merely
    /// backgrounds. That is the honest reading: time in someone's pocket is
    /// not play time, and backgrounding is not quitting.
    @MainActor
    static func exited(_ surface: String, runInProgress: TikiGame? = nil) {
        let seconds = clockStop("time:\(surface)")
        if seconds > 0 { design("time:\(surface)", value: seconds) }
        if let game = runInProgress {
            let runSeconds = clockStop("run:\(game.rawValue)")
            design("run:quit:\(game.rawValue)", value: runSeconds)
        }
    }
}

extension Analytics {
    /// progression-02 labels. Two of these MUST stay bounded or they mint a
    /// new event id forever and breach GA's 8,000/day progression ceiling,
    /// which silently nulls the ids rather than dropping them:
    /// Cipher's `phraseIndex` grows without limit (only its *display* wraps),
    /// and Navigator's `totalPassages` accumulates across loops.
    static func night(_ id: Int) -> String { String(format: "night_%03d", id) }
    static func sketch(_ index: Int) -> String { String(format: "sketch_%02d", index) }
    static func phrase(_ rawIndex: Int) -> String {
        String(format: "phrase_%03d", rawIndex % 300)
    }
    static func passage(_ total: Int) -> String {
        total >= 50 ? "passage_050plus" : String(format: "passage_%03d", total)
    }
}

extension TikiGame {
    /// progression-01 label. Distinct from `rawValue` so the analytics
    /// vocabulary stays readable and stable even if a case is ever renamed.
    var progressionID: String {
        switch self {
        case .tikiStacks: "totem"
        case .luau: "luau"
        case .zombie: "topshelf"
        case .cabanaCipher: "cipher"
        case .blueprints: "blueprints"
        case .navigator: "navigator"
        }
    }
}
