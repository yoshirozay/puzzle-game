import SwiftUI

/// Luau — match-3 at the night bonfire. Drag a piece toward a neighbor to
/// swap; 3+ of a color clears with cascade combos, 4s make torches (line
/// clears), 5s summon the cat (color bomb). Twenty moves a night; the run
/// persists in SwiftData and every party pays the wallet at sunrise.
struct LuauView: View {
    var onExitRequested: () -> Void = { }
    @Environment(PlayerStore.self) private var store
    @State private var game = LuauGame()
    @State private var howToOpen = false
    @State private var seenHowTo = true
    @State private var resolving = false
    /// The two cells of a rejected swap: pieces there animate to each
    /// other's spot and back, so a wrong guess still reads as a swipe.
    @State private var invalidSwap: ((col: Int, row: Int), (col: Int, row: Int))?
    @State private var invalidSwapBeat = 0
    @State private var autoplayStarted = false
    @State private var started = false
    /// Banner copy while a special x special combo's resolution runs.
    @State private var comboLabel: String?
    @State private var shuffleToast = false
    /// First-run coach — five scripted rounds, sand-first: pop a blob's top
    /// row → pop the survivors → torch-in-sand → cat-in-sand → cat-swap
    /// wiping sand across the board. Every beat pops sand; the specials are
    /// taught as better ways to pop it. Advances on each successful swap.
    @State private var coachActive = false
    @State private var tutorialRound: Int = 0
    /// True during the ~900 ms window between a scripted swap resolving and
    /// the next round being seeded — the coach's pulse hides so it doesn't
    /// float over a mid-collapse board.
    @State private var roundTransitioning = false
    /// A teaching level's line is dismissed per level id, not once globally:
    /// lessons are replayable from the campaign, and a player who comes back
    /// to one is usually coming back for exactly the thing it explains.
    @State private var lessonDismissedFor: Int?
    /// Fires after a successful tutorial dismiss so the transition from
    /// coach → real play is unmistakable (SKIP dismisses silently).
    @State private var readyBannerActive = false
    /// Depth-milestone bookkeeping: bits already checked this run, mints that
    /// were new this run (drives the game-over toast), and the lifetime best
    /// that sizes the lantern strand (updates only between runs).
    @State private var checkedBits: Set<Int> = []
    @State private var mintedThisRun = 0
    /// Leaderboard overlay + the payoff bar's rank teaser.
    @State private var leaderboardOpen = false
    @State private var boardStandings: GameCenter.Standings?
    @State private var strandBest = 0
    /// ENCORE bookkeeping: last engine beat seen + the toast's visibility.
    @State private var lastEncoreBeat = 0
    @State private var encoreToast = false
    /// Level-picker overlay — the campaign entry point. True whenever no
    /// level run is in progress; picking a numbered night dismisses it.
    /// The campaign IS the game — endless has no player entry point.
    @State private var pickerOpen = false
    /// Special-activation FX: mounted show events, pieces blanked mid-show
    /// (by id, so they stay invisible through their removal transition),
    /// and the combo shake phase. See LuauSpecialFX.swift for the contract.
    @State private var fxEvents: [FXEvent] = []
    @State private var hiddenFXPieceIDs: Set<UUID> = []
    /// Plain-match pops (the feedback floor) and the beat that remounts them.
    @State private var plainPops: [(col: Int, row: Int, kind: Int)] = []
    @State private var plainPopBeat = 0
    /// The seam between nights: when the auto-advance fires, how long its fuse
    /// was, and whether the player is holding it open. Nil deadline = no seam
    /// running, which is also the banner's mount condition.
    @State private var seamDeadline: Date?
    @State private var seamTotal: Double = 1.2
    @State private var seamHeld = false
    /// Stable identity for the fuse task. The deadline itself shifts while the
    /// player holds, so it can't be the task id or the loop would restart.
    @State private var seamRunID = 0
    /// Idle hint: the two cells of a legal swap, shown after a few seconds of
    /// no input so a stuck player is never stuck for long. `idleBeat` restarts
    /// the clock — every interaction bumps it, which both cancels the pending
    /// task and clears any hint already on screen.
    @State private var hintPair: ((col: Int, row: Int), (col: Int, row: Int))?
    @State private var idleBeat = 0
    @State private var fxShakePhase: CGFloat = 0
    @State private var fxShakeTravel: CGFloat = 0
    /// Lounge Cat: placement targeting with a single-cell reticle, plus the
    /// one-time ON THE HOUSE comp toast at the first low-moves danger. The
    /// chip breathes the whole time it's owned — big, pulsing, can't-miss
    /// (Carson's Depth Charge device note, mirrored here).
    @State private var catTargeting = false
    @State private var catTarget: (col: Int, row: Int) = (3, 3)
    @State private var catCompActive = false
    /// Shared out-of-lives sheet — RETRY / next-run at 0 lives.
    @State private var outOfLivesOpen = false
    @State private var spendBreakIndex: Int? = nil
    @State private var playSpendBreak = false
    @State private var livesEducationActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let swapHaptic = UIImpactFeedbackGenerator(style: .light)
    private let clearHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let warnHaptic = UINotificationFeedbackGenerator()
    private let mistakeHaptic = UINotificationFeedbackGenerator()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // v2: Luau plays against Cabana Cipher's world. Same
                // ProgressPhase contract, so Luau's live signals still drive
                // it — note the fields mean different things over here:
                // `tier` hangs pennants rather than sizing the lantern
                // strand, and `depth` drives the golden-hour warmth instead
                // of the bonfire ladder (`stage`/`swell` go unread).
                CipherBackgroundView(phase: scenePhase)
                    .accessibilityHidden(true)
                LuauChrome(
                    game: game,
                    coachActive: coachActive,
                    resolving: resolving,
                    catTargeting: $catTargeting,
                    catTarget: $catTarget,
                    onHowTo: { howToOpen = true },
                    onDismissCatComp: {
                        withAnimation(.easeOut(duration: 0.2)) { catCompActive = false }
                    }
                )
                board(geo.size)
                if pickerOpen {
                    LuauLevelPicker(
                        completedLevels: stagedCompletedLevels ?? game.completedLevels,
                        onLevelSelected: { level in
                            if store.isOutOfLives(for: .luau) {
                                withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
                                return
                            }
                            seamDeadline = nil
                            seamHeld = false
                            game.newLevel(level, attempt: 1)
                            persist()
                            withAnimation(.easeInOut(duration: 0.25)) { pickerOpen = false }
                        }
                    )
                    .padding(.top, 64)   // clear the notch + status bar row
                    .background(P.ink.color.opacity(0.96))
                    .transition(.opacity)
                    .zIndex(50)
                }
                // Defeat-only now. A cleared night gets the non-modal banner
                // docked under the board instead: no scrim, no question, no
                // stop. A defeat still earns a modal, because there the player
                // genuinely has a decision to make (retry, leave, or wait on
                // lives) and stopping is the right feeling.
                if game.isOver, !wonNightSeam {
                    LuauSunrisePanel(
                        score: game.score,
                        isNewBest: game.lastRunSummary?.isNewBest ?? false,
                        isLevelMode: game.isLevelMode,
                        didWinLevel: game.didWinLevel,
                        levelId: game.currentLevel.map { LuauLevels.nightNumber(of: $0.id) ?? $0.id },
                        movesLeft: game.movesLeft,
                        lastSpareBonus: game.lastSpareBonus,
                        jellyRemaining: game.jellyRemaining,
                        summary: game.lastRunSummary,
                        canAffordNewItem: store.canAffordNewItem,
                        mintedThisRun: mintedThisRun,
                        boardRank: boardStandings?.local?.rank,
                        hasNextNight: nextNight != nil,
                        spendBreakIndex: spendBreakIndex,
                        playSpendBreak: playSpendBreak,
                        onExit: { onExitRequested() },
                        onNextNight: {
                            if store.isOutOfLives(for: .luau) {
                                withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
                                return
                            }
                            if let next = nextNight {
                                withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                                    startNight(next)
                                }
                            }
                        },
                        onRetry: {
                            if store.isOutOfLives(for: .luau) {
                                withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
                                return
                            }
                            retryAfterGate()
                        },
                        onOpenLeaderboard: {
                            withAnimation(.spring(duration: 0.3, bounce: 0.25)) { leaderboardOpen = true }
                        }
                    )
                }
                if livesEducationActive {
                    MilestoneToast(
                        message: "USED A LIFE · 5 HEARTS · +1 EVERY 30 MIN",
                        fontSize: 12
                    )
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, geo.size.height * 0.18)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    .zIndex(95)
                }
                if outOfLivesOpen {
                    OutOfLivesSheet(
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = false }
                        },
                        onLifeLandedPlay: {
                            withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = false }
                            retryAfterGate()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
                if leaderboardOpen {
                    LeaderboardView(theme: .luau) {
                        withAnimation(.easeOut(duration: 0.25)) { leaderboardOpen = false }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(60)
                }
                if coachActive, !game.isOver {
                    // Deep skip inset: the top-left corner belongs to the
                    // SAND objective chip during the coach.
                    CoachCard(
                        message: coachMessage,
                        skin: .luau,
                        onSkip: { dismissCoach(withSuccess: false) },
                        skipTopPadding: 126
                    )
                }
                if readyBannerActive {
                    TutorialReadyBanner(message: "READY TO PARTY", skin: .luau) {
                        readyBannerActive = false
                    }
                }
                if howToOpen {
                    HowToPlayPanel(title: "HOW TO PARTY", rules: [
                        HowToRule(symbol: "hand.draw.fill", text: "Drag a piece toward a neighbor to swap. The swap must line up 3 of a color."),
                        HowToRule(image: .luauSpecialTorch, text: "Line up 4 to earn a torch — it clears its whole lane when matched."),
                        HowToRule(image: .luauSpecialBomb, text: "Bend 5 into an L or T to forge the sunburst — it blasts everything around it when matched."),
                        HowToRule(image: .luauSpecialCat, text: "Line up 5 to summon the cat. Swap it with any piece to clear that color everywhere."),
                        HowToRule(symbol: "flame.fill", text: "Swap two specials into each other for a mega blast."),
                        HowToRule(symbol: "moon.stars.fill", text: "Clear all the sand before your moves run out. Cascades chain for combo multipliers."),
                        HowToRule(symbol: "pawprint.fill", text: "Vic comps one LOUNGE CAT — place it on any tile when the night runs short."),
                    ]) {
                        howToOpen = false
                        markHowToSeen()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0.25), value: howToOpen)
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onAppear { Analytics.entered("luau") }
        .onChange(of: coachActive) { _, active in
            // The FTUE is its own progression family — the one
            // place a tutorial SHOULD be counted (D-6).
            if active { Analytics.progression(.start, "coach", "luau") }
        }
        .onChange(of: game.currentLevel?.id, initial: true) { _, id in
            guard let id else { return }
            Analytics.runStarted(.luau, level: Analytics.night(id),
                                 tutorial: game.tutorialActive || coachActive)
        }
        .onDisappear {
            Analytics.exited("luau", runInProgress: game.isOver ? nil : .luau)
        }
        .task(id: idleBeat) {
            // Candy Crush shows you a move when you stall. Ten seconds leaves
            // room to actually read the board — five interrupted people who
            // were still thinking — while keeping genuinely stuck from
            // becoming bored.
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, boardAwaitsInput else { return }
            if let pair = game.findLegalSwap() {
                withAnimation(.easeIn(duration: 0.35)) { hintPair = pair }
            }
        }
        .task(id: seamRunID) {
            guard seamDeadline != nil else { return }
            await runSeam()
        }
        .onChange(of: game.score) { checkMilestones() }
        .onChange(of: game.isOver) { _, over in
            guard over else { return }
            boardStandings = nil
            Task { boardStandings = try? await GameCenter.shared.loadStandings(for: .luau) }
        }
        .onChange(of: game.inDanger) { _, danger in
            guard danger else { return }
            offerCatCompIfNeeded()
        }
        .onAppear {
            #if DEBUG
            // Staging: TIKI_LB=1 opens the board; TIKI_LB_MOCK stages data.
            if ProcessInfo.processInfo.environment["TIKI_LB"] == "1" {
                GameCenter.shared.authenticate()
                coachActive = false
                howToOpen = false
                seenHowTo = true
                leaderboardOpen = true
            }
            #endif
        }
    }

    /// Bonfire ladder: FLAME 150 / BLAZE 400 / INFERNO 700.
    /// tier = lantern strand size, 3 + bestScore/150 capped at 9 (lifetime);
    /// beat = the engine's cascade-≥3 counter, an ember burst per bump.
    private var scenePhase: ProgressPhase {
        ProgressPhase(
            stage: LuauGame.depthThresholds.filter { game.score >= $0 }.count,
            depth: min(1, Double(game.score) / Double(LuauGame.depthThresholds[2])),
            tier: min(9, 3 + strandBest / 150),
            beat: game.cascadeBeat,
            // The party assembles as the night builds and leaves with it. The
            // named ladder stops at 700 (INFERNO) but nights routinely score
            // past 2,000, so this carries the scene the rest of the way up.
            swell: min(1, max(0, Double(game.score - 1400) / 400))
        )
    }

    /// Staging hook (SIMCTL_CHILD_TIKI_LUAU_DONE=<n>): present the picker
    /// as if nights 1…n are complete — scroll-to-frontier screenshots.
    /// Visual only; the engine's real progress is untouched.
    private var stagedCompletedLevels: [Int]? {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["TIKI_LUAU_DONE"],
           let n = Int(raw), n >= 1 {
            return Array(1...n)
        }
        #endif
        return nil
    }

    // MARK: lifecycle

    private func start() {
        guard !started else { return }
        started = true
        game.configureBest(store.bestScore(for: .luau))
        let payload = game.restore(from: store.loadState(for: .luau))
        seenHowTo = payload?.seenHowTo ?? false
        if !seenHowTo, !store.onboardingSkipped(for: .luau) {
            // First run: always restart the scripted rounds from 0 — a partial
            // mid-tutorial resume would be fragile against schema tweaks.
            // The coach plays on Night 1's live board: sand overlay and SAND
            // chip visible from first paint, scripted matches pop real jelly.
            tutorialRound = 0
            if let first = LuauLevels.all.first {
                game.newLevel(first, attempt: 1)
            }
            game.seedTutorialBoard(round: 0)
            coachActive = true
        } else {
            // No coach — resume the live mid-level run if the restore
            // returned one, else open the frontier night's BOARD. Entry
            // lands on play, never on a menu; PICK A NIGHT now only opens
            // itself when the campaign is exhausted (the game-over panel's
            // LEVELS button became the ALL GAMES exit — every game's
            // terminal panel routes home). Legacy mid-endless saves are
            // retired (the campaign is the game now), so they fall through
            // to the frontier like everyone else.
            let midLevel = game.isLevelMode && !game.isOver
            if !midLevel {
                if let level = frontierNight {
                    game.newLevel(level, attempt: 1)
                } else {
                    pickerOpen = true
                }
            }
        }
        persist()
        #if DEBUG
        // Dev hook: SIMCTL_CHILD_TIKI_LUAU_TUTORIAL=<0..5> jumps the coach
        // straight to that scripted round for screenshot verification.
        if let raw = ProcessInfo.processInfo.environment["TIKI_LUAU_TUTORIAL"],
           let r = Int(raw), (0..<LuauGame.tutorialRoundCount).contains(r) {
            tutorialRound = r
            coachActive = true
            // The frontier picker would otherwise open over the staged
            // coach (sibling hooks close it too).
            pickerOpen = false
            if !game.isLevelMode, let first = LuauLevels.all.first {
                game.newLevel(first, attempt: 1)
            }
            game.seedTutorialBoard(round: r)
        }
        // Dev hook: TIKI_LUAU_TUTORIAL_AUTOPLAY=1 fires the scripted swap
        // every 1.6 s so the ladder plays itself out end-to-end for capture.
        if ProcessInfo.processInfo.environment["TIKI_LUAU_TUTORIAL_AUTOPLAY"] == "1" {
            Task { @MainActor in
                while coachActive {
                    try? await Task.sleep(for: .milliseconds(1600))
                    if !coachActive { break }
                    let round = tutorialRound
                    let sandBefore = game.jellyRemaining
                    trySwap(LuauGame.tutorialSwapA, LuauGame.tutorialSwapB)
                    // Sample sand after the clear resolves but before the
                    // 900 ms round reseed — the pop is the datum. Caveat: the
                    // cat-swap round's FX show runs ~1 s BEFORE the engine
                    // swap, so its line prints pre-wipe (8->8); the wipe's
                    // 8->0 is pinned by tutorialCatWipePopsScatteredSand.
                    try? await Task.sleep(for: .milliseconds(500))
                    print("[coach] luau round=\(round) score=\(game.score) moves=\(game.movesLeft) sand=\(sandBefore)->\(game.jellyRemaining) encoreBeat=\(game.encoreBeat)")
                }
                try? await Task.sleep(for: .seconds(3))
                print("[coach] luau done night=\(game.currentLevel?.id ?? -1) sand=\(game.jellyRemaining) score=\(game.score) moves=\(game.movesLeft) completed=\(game.completedLevels) encoreBeat=\(game.encoreBeat) mask=\(store.record(for: .luau).milestoneMask) wallet=\(store.points)")
            }
        }
        // Staging hook (SIMCTL_CHILD_TIKI_LUAU_SCORE=<n>): fresh board with a
        // seeded score — and no coach — so every bonfire state stages on demand.
        if let raw = ProcessInfo.processInfo.environment["TIKI_LUAU_SCORE"], let n = Int(raw) {
            game.debugSeedScore(n)
            seenHowTo = true
            coachActive = false
            pickerOpen = false
            persist()
        }
        // Staging hook (SIMCTL_CHILD_TIKI_LUAU_LEVEL=<id>): launch straight
        // into a campaign level, skipping the coach and any endless
        // resume. Ignored if the level id is unknown.
        if let raw = ProcessInfo.processInfo.environment["TIKI_LUAU_LEVEL"], let id = Int(raw) {
            if game.debugSeedLevel(id: id) {
                seenHowTo = true
                coachActive = false
                pickerOpen = false
                persist()
            }
        }
        // Staging hook (SIMCTL_CHILD_TIKI_LUAU_DEFEAT=1): the live night
        // straight to OUT OF MOVES with the full real defeat side (sound,
        // spend, summary) — the panel stages on demand. Combine with
        // TIKI_LUAU_LEVEL to pick the night.
        if ProcessInfo.processInfo.environment["TIKI_LUAU_DEFEAT"] == "1" {
            seenHowTo = true
            coachActive = false
            pickerOpen = false
            game.debugStageDefeat()
            if game.isOver { finalizeRunEnd() }
            persist()
        }
        // Staging hook (SIMCTL_CHILD_TIKI_LUAU_SPECIALS=1): plant the three
        // specials on the current board — deterministic art capture.
        if ProcessInfo.processInfo.environment["TIKI_LUAU_SPECIALS"] == "1" {
            game.debugPlantSpecials()
        }
        // Staging hook (SIMCTL_CHILD_TIKI_LUAU_FIRE=<scenario>): stage the
        // board and fire one special activation — deterministic FX capture.
        // Scenarios: torch, cat, cross, storm, cataclysm. Pair with
        // TIKI_LUAU_SCORE=0 for a fresh full board.
        if let scenario = ProcessInfo.processInfo.environment["TIKI_LUAU_FIRE"] {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(4000))
                if let swap = game.debugStageFire(scenario) {
                    print("[fire] staged \(scenario) swap=\(swap.0)->\(swap.1)")
                    try? await Task.sleep(for: .milliseconds(400))
                    trySwap(swap.0, swap.1)
                    print("[fire] swap dispatched")
                } else {
                    print("[fire] UNKNOWN scenario \(scenario)")
                }
            }
        }
        // Staging hook (SIMCTL_CHILD_TIKI_LUAU_NEXT=1): once a level is
        // won, fire the win panel's NEXT NIGHT after a beat — simctl can't
        // synthesize the tap (same rationale as TIKI_BUY_LATE).
        if ProcessInfo.processInfo.environment["TIKI_LUAU_NEXT"] == "1" {
            Task { @MainActor in
                while !(game.isOver && game.didWinLevel) {
                    try? await Task.sleep(for: .milliseconds(300))
                }
                try? await Task.sleep(for: .milliseconds(2000))
                guard let next = nextNight else {
                    print("[luau-next] campaign complete — no next night")
                    return
                }
                withAnimation(.spring(duration: 0.35, bounce: 0.3)) { startNight(next) }
                try? await Task.sleep(for: .milliseconds(1200))
                print("[luau-next] night=\(game.currentLevel?.id ?? -1) moves=\(game.movesLeft) sand=\(game.jellyRemaining)")
            }
        }
        // Staging hook (SIMCTL_CHILD_TIKI_LUAU_PICKER=1): open the level
        // picker directly, skipping any coach / mid-run resume.
        if ProcessInfo.processInfo.environment["TIKI_LUAU_PICKER"] == "1" {
            game.newGame()
            coachActive = false
            seenHowTo = true
            pickerOpen = true
            persist()
        }
        // Staging hook (SIMCTL_CHILD_TIKI_LUAU_CAT): "1" stages Night 1 at
        // 3 moves with sand left — on a fresh profile the Lounge Cat comp
        // fires on appear; "2" additionally scripts the flow — open
        // targeting, then place at board center — for screenshot runs.
        if let raw = ProcessInfo.processInfo.environment["TIKI_LUAU_CAT"],
           let mode = Int(raw), mode >= 1 {
            if game.debugSeedLevel(id: 1) {
                game.testSetMovesLeft(3)
                // Rewind the one-time comp so the staged run always replays
                // the ON THE HOUSE beat, even on an already-comped profile.
                store.debugResetLuauCatComp()
                seenHowTo = true
                coachActive = false
                pickerOpen = false
                persist()
                if mode >= 2 {
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(1800))
                        withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                            catTargeting = true
                            catTarget = (3, 3)
                        }
                        try? await Task.sleep(for: .milliseconds(1400))
                        placeCompCat()
                    }
                }
            }
        }
        if ProcessInfo.processInfo.environment["TIKI_AUTOPLAY"] == "1", !autoplayStarted {
            autoplayStarted = true
            howToOpen = false
            coachActive = false
            seenHowTo = true
            Task { await autoplay() }
        }
        #endif
        // Deferred a turn: @State writes from onAppear are silently dropped
        // once the observable game has invalidated the view, and the strand
        // reads strandBest on the next phase recompute anyway. A board
        // RESTORED into danger never fires the onChange, so the cat comp
        // check runs here too.
        Task { @MainActor in
            strandBest = store.bestScore(for: .luau)
            checkMilestones()
            if game.inDanger { offerCatCompIfNeeded() }
        }
    }

    /// Records depth-state milestones the first time the score crosses
    /// 150/400/700 in a run (bits 8–10). `recordMilestone` mints +75 exactly
    /// once, ever; `checkedBits` keeps re-checks cheap within the run.
    private func checkMilestones() {
        // Scripted boards never mint: the coach's cat-wipe round alone scores
        // 180 (> FLAME's 150). Real play restarts from zero at dismissCoach.
        guard !coachActive else { return }
        for (i, threshold) in LuauGame.depthThresholds.enumerated()
        where game.score >= threshold && !checkedBits.contains(8 + i) {
            checkedBits.insert(8 + i)
            if store.recordMilestone(game: .luau, bit: 8 + i) {
                mintedThisRun += 1
            }
        }
    }

    /// Runs one special-activation show: mounts the FX layer, shakes on
    /// combos, then walks the stagger and blanks each doomed piece (by id)
    /// at the exact moment its burst covers it. Returns when the show is
    /// over; the caller then lets the engine clear + collapse for real.
    @MainActor
    private func playFires(_ fires: [LuauGame.SpecialFire], comboShake: Bool = false) async {
        guard !fires.isEmpty else { return }
        // Previous fire's exit transitions are long done (≥320ms between
        // steps) — safe to reset. Never clear these right after a mutation:
        // exiting piece views re-evaluate the opacity modifier and would
        // flash back as doubled ghosts (judge round 1, D8).
        hiddenFXPieceIDs = []
        let showStart = Date()
        fxEvents = fires.map { FXEvent(fire: $0, start: showStart) }
        clearHaptic.impactOccurred()
        if !reduceMotion {
            let isBig = fires.contains { $0.kind == .cataclysm }
            // `comboShake` comes from the swap path, which knows the combo
            // directly — a DOUBLE BLAST's fires are all plain .bomb kinds, so
            // kind inference alone left the biggest new blast shakeless.
            let isCombo = isBig || comboShake || fires.contains {
                $0.kind == .torchCross || $0.kind == .torchStorm
                    || $0.kind == .shockwave || $0.kind == .eruption
            }
            if isCombo {
                fxShakeTravel = isBig ? 5 : 3
                withAnimation(.linear(duration: 0.32)) { fxShakePhase += 3 }
            }
        }
        // Quantize hides into 24ms buckets: one set-union per bucket
        // instead of one @State mutation per piece — 49 individual inserts
        // starved the burst tasks on the cataclysm (judge round 2 lag).
        var buckets: [Int: [UUID]] = [:]
        for fire in fires {
            for c in fire.cells {
                let d = FXTiming.hideDelay(cell: c, fire: fire)
                buckets[Int(d / 0.024), default: []].append(c.id)
            }
        }
        for key in buckets.keys.sorted() {
            let at = Double(key) * 0.024
            let elapsed = Date().timeIntervalSince(showStart)
            if at > elapsed {
                try? await Task.sleep(for: .seconds(at - elapsed))
            }
            hiddenFXPieceIDs.formUnion(buckets[key] ?? [])
        }
        // Return as soon as the last piece is covered (+ a short beat) —
        // the burst tails finish over the collapsing board. Overlap, not
        // dead air (judge round 1, D5).
        let mutateAt = FXTiming.mutateDelay(fires)
        let elapsed = Date().timeIntervalSince(showStart)
        if mutateAt > elapsed {
            try? await Task.sleep(for: .seconds(mutateAt - elapsed))
        }
    }

    /// The level after the one just played, in campaign order — nil at the
    /// end of the campaign (and in endless mode).
    private var nextNight: LuauLevel? {
        guard let current = game.currentLevel else { return nil }
        return LuauLevels.next(after: current.id)
    }

    /// The furthest-progressed night: one past the highest cleared, the
    /// same frontier the night grid highlights. Clamps to the last authored
    /// night once the campaign is finished (that board replays), and is nil
    /// only if the level table were empty — in which case `start()` falls
    /// back to the grid rather than inventing a board.
    private var frontierNight: LuauLevel? {
        return LuauLevels.frontierLevel(completed: game.completedLevels)
    }

    /// Start-a-level path for the win panel's NEXT NIGHT — same per-run
    /// resets RETRY does.
    private func startNight(_ level: LuauLevel) {
        seamDeadline = nil
        seamHeld = false
        game.newLevel(level, attempt: 1)
        checkedBits = []
        mintedThisRun = 0
        persist()
    }

    private func persist() {
        store.saveState(for: .luau, payload: game.payload(seenHowTo: seenHowTo))
    }

    private func markHowToSeen() {
        seenHowTo = true
        persist()
    }

    /// One diegetic verb per round — the objective leads, the specials
    /// follow as better ways to pop sand.
    /// Copy stays ≤ 4 words — pulses/arrows carry the "where", card carries
    /// the "what verb".
    private var coachMessage: String {
        switch tutorialRound {
        case 0: return "POP THE SAND"
        case 1: return "POP THE REST"
        case 2: return "MATCH A SQUARE"
        case 3: return "MAKE A TORCH"
        case 4: return "SUMMON THE CAT"
        default: return "SWAP THE CAT"
        }
    }

    /// Called after a scripted swap lands. Advances the round only after the
    /// whole show settles — a fixed timer can't size these: the torch
    /// round's collapse chains multiple combos and can fire the specials it
    /// just minted, so 900 ms from the swap was wiping the board mid-show
    /// (device report). After settle, hold a beat — longer on the spawn
    /// rounds so the freshly minted torch/cat gets a moment to be admired —
    /// and if the player fires the new special during the hold, wait out
    /// that show too before reseeding.
    private func handleTutorialSwap() {
        // One advance per round: the board turns interactive between settle
        // and reseed, and a second successful swap in that window must not
        // schedule a second reseed.
        guard !roundTransitioning else { return }
        roundTransitioning = true
        // Post-settle beats, kept tight (device feedback: transitions
        // dragged) — the variable-length show has already fully played out
        // by the settle wait; this is only the "read the result" pause.
        let spawnRounds: Set<Int> = [3, 4]  // MAKE A TORCH / SUMMON THE CAT
        let isFinal = tutorialRound + 1 >= LuauGame.tutorialRoundCount
        let linger: Duration = .milliseconds(
            spawnRounds.contains(tutorialRound) ? 750 : (isFinal ? 600 : 300))
        let next = tutorialRound + 1
        Task { @MainActor in
            // Grace tick: the plain-swap path calls this BEFORE it launches
            // runResolution, so give the resolve a beat to raise `resolving`
            // — otherwise the linger runs concurrently with the clear and
            // the settled board gets almost no reading time.
            try? await Task.sleep(for: .milliseconds(150))
            repeat {
                while resolving { try? await Task.sleep(for: .milliseconds(50)) }
                try? await Task.sleep(for: linger)
            } while resolving
            if isFinal {
                dismissCoach(withSuccess: true)
                return
            }
            tutorialRound = next
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                game.seedTutorialBoard(round: next)
            }
            roundTransitioning = false
            persist()
        }
    }

    private func dismissCoach(withSuccess: Bool) {
        Analytics.progression(withSuccess ? .complete : .fail, "coach", "luau")
        guard coachActive else { return }
        withAnimation(.easeOut(duration: 0.3)) { coachActive = false }
        // The final-round advance guard set this; a staged coach re-entry
        // (TIKI_LUAU_TUTORIAL) must not inherit hidden pulses.
        roundTransitioning = false
        // Tutorial ends — real play starts fresh, never on the scripted
        // board (its post-tutorial refill cascade once minted hundreds of
        // unearned points, polluting milestones, depth, and best-score).
        game.endTutorial()
        if withSuccess, let first = LuauLevels.all.first {
            // Straight into Night 1 — the campaign is the game.
            game.newLevel(first, attempt: 1)
            checkedBits = []
            mintedThisRun = 0
            CoachSkin.luau.dismissSound.play()
            readyBannerActive = true
        } else {
            game.newGame()
            pickerOpen = true
            store.setOnboardingSkipped(true, for: .luau)
        }
        seenHowTo = true
        persist()
    }

    // MARK: interaction

    private func trySwap(_ a: (col: Int, row: Int), _ b: (col: Int, row: Int)) {
        guard !resolving, !game.isOver, !howToOpen, !catTargeting else { return }

        // Special-detonating swap (cat swap / special×special): the show
        // plays over the LIVE board first — streaks and zaps must reach
        // pieces that still exist — then the engine clears and collapses.
        let swapFires = game.previewSwapFires(a, b)
        if !swapFires.isEmpty {
            resolving = true
            swapHaptic.impactOccurred()
            TikiSound.shared.tick()
            // The banner keys on the COMBO, not on the fires: fire kinds are
            // the SHOW (an eruption's zaps, a blast's ring), and switching on
            // them here left every bomb combo mislabeled or silent — the
            // review panel found all three new banner strings dead because
            // this path never reads `lastCombo`. The engine knows which combo
            // the swap is; ask it.
            let combo = game.previewCombo(a, b)
            switch combo {
            case .some(.cataclysm):
                comboLabel = "CATACLYSM!"
                warnHaptic.notificationOccurred(.success)
                TikiSound.shared.fanfare()
            case .some(let c):
                comboLabel = Self.bannerText(for: c)
                warnHaptic.notificationOccurred(.success)
                TikiSound.shared.clear(intensity: 4)
            case .none:
                // A cat swap — a special show, but no combo.
                TikiSound.shared.clear(intensity: 3)
            }
            Task { @MainActor in
                await playFires(swapFires, comboShake: combo != nil)
                withAnimation(.spring(duration: 0.3, bounce: 0.22)) {
                    _ = game.attemptSwap(a, b)
                }
                // fxEvents/hiddenFXPieceIDs stay put: bursts self-fade over
                // the collapse, and clearing hidden ids now would resurrect
                // exiting pieces mid-transition (doubled ghosts).
                lowMovesCue()
                if coachActive { handleTutorialSwap() }
                await runResolution()
            }
            return
        }

        let comboBefore = game.comboBeat
        nudgeIdle()
        let movesBefore = game.movesLeft
        var committed = false
        withAnimation(.spring(duration: 0.2, bounce: 0.25)) {
            committed = game.attemptSwap(a, b)
        }
        guard committed else {
            // Feedback sorts on LEGALITY, not cost. A whiff — those two can
            // swap, there is just no match here — gets a light registered tap;
            // a rejection — you cannot swap those at all — gets the .error
            // buzz. Branching on spentMove used to mean the same thing, but it
            // stopped discriminating the day whiffs became free, and once the
            // coconut whiffed like any other piece the buzz was scolding a
            // legal, everyday gesture. `spentMove` still guards the close-out
            // below, so if the economy ever changes again this path still ends
            // a run correctly.
            let spentMove = game.movesLeft != movesBefore
            if game.isLegalPairing(a, b) {
                swapHaptic.impactOccurred()
                TikiSound.shared.knock()
            } else {
                mistakeHaptic.notificationOccurred(.error)
                TikiSound.shared.mistake()
            }
            invalidSwapBeat += 1
            let beat = invalidSwapBeat
            withAnimation(.spring(duration: 0.16, bounce: 0.3)) {
                invalidSwap = (a, b)
            }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                guard beat == invalidSwapBeat else { return }
                withAnimation(.spring(duration: 0.22, bounce: 0.35)) {
                    invalidSwap = nil
                }
            }
            // Mirror the committed path's low-moves cue, save the spent move,
            // and — since no resolution will ever run — close out a run the
            // whiff just ended.
            if spentMove {
                lowMovesCue()
                persist()
                if game.isOver, game.lastRunSummary == nil { finalizeRunEnd() }
            }
            return
        }
        if game.comboBeat != comboBefore {
            comboLabel = comboBannerText
            warnHaptic.notificationOccurred(.success)
            if game.lastCombo == .cataclysm {
                TikiSound.shared.fanfare()
            } else {
                TikiSound.shared.clear(intensity: 4)
            }
        }
        lowMovesCue()
        swapHaptic.impactOccurred()
        TikiSound.shared.tick()
        if coachActive { handleTutorialSwap() }
        Task { await runResolution() }
    }

    /// One banner table for both paths: the preview path (which knows the
    /// combo before the swap commits, via `previewCombo`) and the fallback
    /// `comboBeat` path read the same strings.
    static func bannerText(for combo: LuauGame.ComboKind) -> String {
        switch combo {
        case .torchCross: return "FIRE CROSS!"
        case .torchStorm: return "TORCH STORM!"
        case .cataclysm: return "CATACLYSM!"
        case .blast: return "DOUBLE BLAST!"
        case .shockwave: return "SHOCKWAVE!"
        case .eruption: return "ERUPTION!"
        }
    }

    private var comboBannerText: String {
        game.lastCombo.map(Self.bannerText(for:)) ?? ""
    }

    // MARK: lounge cat

    /// The reticle's cell right now — SET IT DOWN disables on masked cells
    /// and existing specials so the comp can't be wasted.
    private var catTargetValid: Bool {
        guard let p = game.piece(at: catTarget.col, catTarget.row) else { return false }
        return p.special == .none
    }

    private func placeCompCat() {
        guard catTargeting, store.luauCats > 0, !resolving else { return }
        var placed = false
        withAnimation(.spring(duration: 0.32, bounce: 0.35)) {
            placed = game.placeCat(col: catTarget.col, row: catTarget.row)
        }
        guard placed else { return }
        _ = store.spendLuauCat()
        clearHaptic.impactOccurred()
        TikiSound.shared.clear(intensity: 2)
        withAnimation(.spring(duration: 0.3, bounce: 0.25)) { catTargeting = false }
        persist()
    }

    /// The one-time comp: the first time a night hits the low-moves danger
    /// zone, Vic sends the Lounge Cat over — chip pops in, toast says so.
    private func offerCatCompIfNeeded() {
        guard !store.luauCatGranted, !coachActive else { return }
        var granted = false
        withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
            granted = store.grantLuauCatIfNeeded()
        }
        guard granted else { return }
        clearHaptic.impactOccurred()
        TikiSound.shared.tick()
        withAnimation(.spring(duration: 0.35, bounce: 0.4)) { catCompActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(3200))
            withAnimation(.easeOut(duration: 0.3)) { catCompActive = false }
        }
    }

    @MainActor
    private func runResolution() async {
        resolving = true
        let shuffleBefore = game.shuffleBeat
        try? await Task.sleep(for: .milliseconds(140))
        while true {
            // Triggered torches show BEFORE the step mutates the board —
            // the streak has to cross pieces that still exist. Plain
            // steps skip straight through (preview is a cheap scan).
            let stepFires = game.previewStepFires()
            if !stepFires.isEmpty {
                TikiSound.shared.clear(intensity: max(3, game.lastCascade))
                await playFires(stepFires)
            }
            var cleared = false
            withAnimation(.spring(duration: 0.3, bounce: 0.22)) {
                cleared = game.resolveStep()
            }
            // Pay out the instant the run ends, not 660ms later at the end of
            // the settle. The panel mounts on `isOver` immediately and its
            // buttons are live, so a fast tap on NEXT NIGHT used to clear
            // isOver before the post-settle check below ever ran — skipping
            // recordRun entirely: no wallet points, no Game Center submit, no
            // run recorded, and no sign to the player that anything was lost.
            // Checked here rather than inside `if cleared` because
            // evaluateEndCondition also latches on a step that clears nothing.
            // `lastRunSummary` is the idempotency guard: recordRun always
            // returns one, and newLevel nils it, so a fresh run re-arms itself.
            if game.isOver, game.lastRunSummary == nil {
                finalizeRunEnd()
                // Arm the handover in the same breath as the payout, so the
                // banner can require a summary and still appear immediately.
                if wonNightSeam { armSeam() }
            }
            if cleared {
                // The ladder needs a floor, not just a ceiling. A plain first
                // round is the commonest thing that happens in the game: it pops
                // softly (pop() + a light tap + a kind-tinted ring), and only
                // cascades climb into clear()'s pentatonic and the medium impact.
                // Specials rounds keep their own show and skip the plain ring.
                let plainRound = stepFires.isEmpty
                if plainRound {
                    plainPops = game.lastPlainPops
                    plainPopBeat += 1
                }
                if game.lastCascade <= 1, plainRound {
                    swapHaptic.impactOccurred()
                    TikiSound.shared.pop()
                } else {
                    clearHaptic.impactOccurred()
                    TikiSound.shared.clear(intensity: game.lastCascade)
                }
                try? await Task.sleep(for: .milliseconds(320))
            } else {
                break
            }
        }
        // Board settled — exit transitions done; retire the FX state.
        try? await Task.sleep(for: .milliseconds(340))
        fxEvents = []
        hiddenFXPieceIDs = []
        plainPops = []
        persist()
        // Normally already paid out the moment isOver latched; this remains as
        // a backstop for any path that ends a run without a resolve step.
        if game.isOver, game.lastRunSummary == nil {
            finalizeRunEnd()
        }
        // Banner exits through its transition, not an abrupt un-render.
        withAnimation(.easeOut(duration: 0.25)) {
            resolving = false
            comboLabel = nil
        }
        // Board has settled and is the player's again — restart the idle clock
        // from here rather than from their last touch, or the hint would fire
        // mid-cascade on a long resolve.
        nudgeIdle()
        // ENCORE lands once the board settles: the +2 is already on the
        // moves chip, the banner says why. Engine-guarded against the coach.
        if game.encoreBeat != lastEncoreBeat {
            lastEncoreBeat = game.encoreBeat
            TikiSound.shared.fanfare()
            warnHaptic.notificationOccurred(.success)
            withAnimation(.spring(duration: 0.35, bounce: 0.35)) { encoreToast = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(2200))
                withAnimation(.easeOut(duration: 0.3)) { encoreToast = false }
            }
        }
        if game.shuffleBeat != shuffleBefore, !game.isOver {
            // The board rearranging untouched is the most disorienting thing that
            // can happen mid-run; it used to be announced by a text toast only.
            warnHaptic.notificationOccurred(.warning)
            TikiSound.shared.railTick(step: 0)
            withAnimation(.spring(duration: 0.3, bounce: 0.3)) { shuffleToast = true }
            try? await Task.sleep(for: .milliseconds(1400))
            withAnimation(.easeOut(duration: 0.3)) { shuffleToast = false }
        }
    }

    /// A cleared campaign night that has been paid out and has somewhere to go
    /// — the banner's mount condition and the modal's suppression condition, so
    /// the two can never both be on screen. Requiring `lastRunSummary` makes
    /// "banner visible" structural proof that the payout already landed.
    private var wonNightSeam: Bool {
        game.isOver && game.isLevelMode && game.didWinLevel
            && game.lastRunSummary != nil && nextNight != nil
    }

    /// Arms the seam. Called once when a night is cleared.
    @MainActor
    private func armSeam() {
        // VoiceOver needs time to speak the banner before the board turns over.
        let total: Double = UIAccessibility.isVoiceOverRunning ? 3.6 : 1.2
        seamTotal = total
        seamHeld = false
        seamDeadline = Date().addingTimeInterval(total)
        seamRunID += 1
    }

    /// Runs the fuse. Holding pushes the deadline out rather than pausing a
    /// clock, so the drawn fuse and this loop read from the same source.
    @MainActor
    private func runSeam() async {
        while let d = seamDeadline, !Task.isCancelled {
            if seamHeld {
                seamDeadline = d.addingTimeInterval(0.08)
                try? await Task.sleep(for: .milliseconds(80))
                continue
            }
            if d.timeIntervalSinceNow <= 0 { break }
            try? await Task.sleep(for: .milliseconds(40))
        }
        guard !Task.isCancelled, seamDeadline != nil else { return }
        advanceSeam()
    }

    /// Hands over to the next night. Idempotent — clearing the deadline first
    /// means a tap racing the fuse can only advance once.
    @MainActor
    /// The lesson key to name on screen, or nil when there is nothing to say.
    /// Suppressed under the first-run coach (which is already talking) and
    /// under the night-clear seam (which has the board's attention).
    private var lessonTeaches: String? {
        guard !coachActive, !wonNightSeam,
              let level = game.currentLevel, let teaches = level.teaches,
              lessonDismissedFor != level.id
        else { return nil }
        return teaches
    }

    private func advanceSeam() {
        guard seamDeadline != nil, let next = nextNight else { return }
        seamDeadline = nil
        seamHeld = false
        // Out of lives between the win and the handover: fall back to the sheet
        // rather than silently refusing to advance.
        if store.isOutOfLives(for: .luau) {
            withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
            return
        }
        TikiSound.shared.tick()
        swapHaptic.impactOccurred()
        withAnimation(.spring(duration: 0.44, bounce: 0.28)) {
            startNight(next)
        }
    }

    /// Any interaction restarts the idle clock and pulls the hint. Called from
    /// every path that means "the player is doing something".
    @MainActor
    private func nudgeIdle() {
        if hintPair != nil { withAnimation(.easeOut(duration: 0.2)) { hintPair = nil } }
        idleBeat &+= 1
    }

    /// True only when the board is genuinely waiting on the player: no
    /// resolution running, no panel or sheet over it, and not during the coach,
    /// which already has its own pointer and must not be doubled up on.
    private var boardAwaitsInput: Bool {
        !resolving && !game.isOver && !howToOpen && !pickerOpen
            && !outOfLivesOpen && !leaderboardOpen && !coachActive && !catTargeting
    }

    /// Low-moves cue — escalates instead of firing once. A single buzz at
    /// exactly 3 was easy to miss and said nothing about how close the wall
    /// was; 5 and 3 warn, 1 is the last-move alarm.
    @MainActor
    private func lowMovesCue() {
        switch game.movesLeft {
        case 5, 3: warnHaptic.notificationOccurred(.warning)
        case 1: warnHaptic.notificationOccurred(.error)
        default: break
        }
    }

    /// Run-end bookkeeping, shared by the two paths that can latch isOver:
    /// the settle after a committed swap (runResolution) and a WHIFF that
    /// spends the final move (trySwap's uncommitted branch — no resolution
    /// ever runs there, so it must pay the piper itself).
    @MainActor
    private func finalizeRunEnd() {
        // A cleared night is the loudest moment in the run, not the quietest:
        // it used to fall through to gameOver() and no haptic at all, so a
        // win and a defeat were indistinguishable to the ear and the hand.
        if game.didWinLevel {
            TikiSound.shared.win()
            warnHaptic.notificationOccurred(.success)
        } else {
            TikiSound.shared.gameOver()
            warnHaptic.notificationOccurred(.error)
        }
        // LOST nights (and endless sunrise) spend a life; won nights
        // are free. The coach never ends a run (tutorialActive).
        if !game.didWinLevel,
           store.spendLifeForDefeat(
               game: .luau,
               duringTutorial: game.tutorialActive || coachActive
           ) {
            armSpendBreak(after: store.lives)
            AccessibilityNotification.Announcement(
                "Life spent — \(store.lives) of \(PlayerStore.livesCap) left"
            ).post()
            offerLivesEducationIfNeeded()
            // Last life just went: ask once, after the panel lands.
            Task {
                await LivesRestockNotifier.shared.offerAuthorizationAfterDefeat(
                    lives: store.lives, duringTutorial: coachActive
                )
            }
        }
        game.lastRunSummary = store.recordRun(
            game: .luau, score: game.score, earnScore: game.score / 3,
            wonLevel: game.didWinLevel
        )
        // Campaign depth backs the lives activation gate, and it lives in
        // Luau's save state where the store cannot see it. Report it here.
        store.noteLuauLevelsCleared(game.completedLevels.count)
        Analytics.runEnded(.luau, level: Analytics.night(game.currentLevel?.id ?? 0),
                           won: game.didWinLevel, score: game.score,
                           tutorial: game.tutorialActive || coachActive)
        // The strand only grows between runs — sunrise hangs new lights.
        strandBest = max(strandBest, game.score)
        persist()
    }

    #if DEBUG
    /// Dev hook (TIKI_AUTOPLAY=1): greedy legal swaps until the run ends.
    /// Uses `LuauBot.pickMove` so screenshots and LevelForge stats can
    /// never disagree on the move choice.
    private func autoplay() async {
        try? await Task.sleep(for: .milliseconds(600))
        while !game.isOver {
            try? await Task.sleep(for: .milliseconds(200))
            guard !resolving else { continue }
            guard let move = LuauBot.pickMove(for: game) else { continue }
            trySwap(move.0, move.1)
        }
        // Let the final resolution settle before reporting the run.
        try? await Task.sleep(for: .seconds(3))
        print("[autoplay] luau over score=\(game.score)")
    }
    #endif

    // MARK: board

    private func board(_ size: CGSize) -> some View {
        let n = LuauGame.size
        let side: CGFloat = min(size.width * 0.94, size.height * 0.5)
        let gap: CGFloat = side * 0.012
        let cell: CGFloat = (side - gap * CGFloat(n + 1)) / CGFloat(n)
        let originX: CGFloat = (size.width - side) / 2
        let originY: CGFloat = size.height * 0.50 - side / 2

        func center(_ col: Int, _ row: Int) -> CGPoint {
            CGPoint(
                x: originX + gap + cell / 2 + CGFloat(col) * (cell + gap),
                y: originY + gap + cell / 2 + CGFloat(row) * (cell + gap)
            )
        }

        /// The reticle rides with the touch — tap or drag — clamped onto
        /// the board.
        func aimCat(_ location: CGPoint, fast: Bool) {
            guard catTargeting else { return }
            let col = min(max(Int((location.x - originX) / side * CGFloat(n)), 0), n - 1)
            let row = min(max(Int((location.y - originY) / side * CGFloat(n)), 0), n - 1)
            guard col != catTarget.col || row != catTarget.row else { return }
            withAnimation(.spring(duration: fast ? 0.12 : 0.25, bounce: fast ? 0.15 : 0.3)) {
                catTarget = (col, row)
            }
        }

        /// A rejected swap's two pieces swap on-screen positions, then spring
        /// back once `invalidSwap` clears — the feedback that the guess was wrong.
        func rejectOffset(_ col: Int, _ row: Int) -> CGSize {
            guard let invalidSwap else { return .zero }
            let (a, b) = invalidSwap
            if col == a.col, row == a.row {
                return CGSize(width: CGFloat(b.col - a.col) * (cell + gap), height: CGFloat(b.row - a.row) * (cell + gap))
            }
            if col == b.col, row == b.row {
                return CGSize(width: CGFloat(a.col - b.col) * (cell + gap), height: CGFloat(a.row - b.row) * (cell + gap))
            }
            return .zero
        }

        return ZStack {
            RoundedRectangle(cornerRadius: side * 0.035)
                .fill(P.ink.color.opacity(0.45))
                .frame(width: side + gap * 2, height: side + gap * 2)
                .position(x: size.width / 2, y: originY + side / 2)
            ForEach(game.pieces) { piece in
                // Beat-1 spotlight: while the very first card is up, pieces
                // outside the sand dim slightly so "inside the jelly" reads
                // spatially before the copy is even parsed. Dies with beat 1.
                let dimmed = coachActive && tutorialRound == 0 && !roundTransitioning
                    && game.isLevelMode
                    && game.jelly[piece.row * LuauGame.size + piece.col] == 0
                LuauPieceView(piece: piece, cell: cell)
                    .opacity(hiddenFXPieceIDs.contains(piece.id) ? 0 : (dimmed ? 0.65 : 1))
                    .position(center(piece.col, piece.row))
                    .offset(rejectOffset(piece.col, piece.row))
                    // Refills drop in opaque from a cell above (judge
                    // round 2: opacity-only insertion read as translucent
                    // doubles mid-fall). Removal keeps the pop-out read.
                    .transition(.asymmetric(
                        insertion: .offset(y: -52).combined(with: .opacity),
                        removal: .scale(scale: 0.2).combined(with: .opacity)
                    ))
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onEnded { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                let target: (Int, Int) = abs(dx) > abs(dy)
                                    ? (piece.col + (dx > 0 ? 1 : -1), piece.row)
                                    : (piece.col, piece.row + (dy > 0 ? 1 : -1))
                                guard (0..<n).contains(target.0), (0..<n).contains(target.1) else { return }
                                trySwap((piece.col, piece.row), (target.0, target.1))
                            }
                    )
                    // Targeting: pieces go touch-transparent so the board's
                    // aim gestures (tap + drag) receive everything — a piece's
                    // own swap drag would otherwise claim and eat the drag.
                    .allowsHitTesting(!catTargeting)
            }
            // Sand overlay: jellied cells wear a translucent sand film ON TOP
            // of the piece art — the pieces are opaque full-bleed tiles, so
            // anything drawn under them can never read. Hit testing stays off
            // so drags land on the piece below.
            if game.isLevelMode {
                ForEach(0..<LuauGame.size * LuauGame.size, id: \.self) { i in
                    let layers = Int(game.jelly[i])
                    if layers > 0 {
                        LuauSandOverlay(cell: cell, layers: layers,
                                        emphasized: coachActive || game.currentLevel?.isLesson == true)
                            .position(center(i % LuauGame.size, i / LuauGame.size))
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 1.25).combined(with: .opacity))
                    }
                }
            }
            // Docked 24pt under the board, top-aligned so its own height never
            // shifts where it sits. Deliberately inside the board layer, not
            // the outer ZStack: it belongs to the board it is congratulating.
            if wonNightSeam, let deadline = seamDeadline, let level = game.currentLevel {
                VStack(spacing: 0) {
                    Spacer().frame(height: originY + side + 24)
                    LuauNightClearBanner(
                        levelId: LuauLevels.nightNumber(of: level.id) ?? level.id,
                        movesLeft: game.movesLeft,
                        spareBonus: game.lastSpareBonus,
                        pointsEarned: game.lastRunSummary?.pointsEarned,
                        nightStreak: game.nightStreak,
                        deadline: deadline,
                        total: seamTotal,
                        holding: seamHeld,
                        onHoldChanged: { held in
                            guard held != seamHeld else { return }
                            seamHeld = held
                            if held { swapHaptic.impactOccurred() }
                        },
                        onSkip: { advanceSeam() }
                    )
                    Spacer(minLength: 0)
                }
                .frame(width: size.width, height: size.height)
                .transition(.offset(y: 26).combined(with: .opacity))
                .zIndex(40)
            }
            // Same dock as the night-clear seam, and for the same reason: it
            // belongs to the board it is describing. Unscrimmed on purpose —
            // the player has to be able to look at the sand while reading it.
            if let teaches = lessonTeaches {
                VStack(spacing: 0) {
                    Spacer().frame(height: originY + side + 24)
                    LuauLessonBanner(teaches: teaches) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            lessonDismissedFor = game.currentLevel?.id
                        }
                    }
                    .padding(.horizontal, 18)
                    Spacer(minLength: 0)
                }
                .frame(width: size.width, height: size.height)
                .transition(.offset(y: 26).combined(with: .opacity))
                .zIndex(39)
            }
            // Idle hint: a slow breathing ring on the two cells of a legal swap.
            // Deliberately calm — it is a nudge, not an alarm, and it sits UNDER
            // the pops so a clear always reads over the top of it.
            if let hint = hintPair {
                ForEach([hint.0, hint.1].indices, id: \.self) { i in
                    let c = i == 0 ? hint.0 : hint.1
                    LuauHintRing(cell: cell, reduceMotion: reduceMotion)
                        .position(center(c.col, c.row))
                        .allowsHitTesting(false)
                }
                .transition(.opacity)
            }
            // The floor: a soft kind-tinted ring per plain match. Keyed on the
            // beat so each resolve round mounts a fresh set that self-fades.
            LuauPlainPopLayer(pops: plainPops, cell: cell,
                              center: { center($0, $1) }, reduceMotion: reduceMotion)
                .id(plainPopBeat)
            // Special-activation shows: streaks, zaps, bursts, shockwaves.
            LuauFXLayer(events: fxEvents, cell: cell, gap: gap,
                        center: { center($0, $1) }, reduceMotion: reduceMotion)
            if let comboLabel, resolving {
                specialBanner(comboLabel)
                    .position(x: size.width / 2, y: originY - 26)
            } else if game.lastCascade >= 2, resolving {
                comboBanner
                    .position(x: size.width / 2, y: originY - 26)
                    .id(game.clearBeat)
            }
            if scoreGain > 0 {
                GainPopupLuau(text: "+\(scoreGain)")
                    .position(x: size.width / 2, y: originY + side + 22)
                    .id(game.clearBeat)
            }
            if encoreToast {
                Text("ENCORE — THE BAND PLAYS ON +2")
                    .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(Color(red: 0.910, green: 0.702, blue: 0.235))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(P.ink.color.opacity(0.75)))
                    .position(x: size.width / 2, y: originY - 26)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            if shuffleToast {
                Text("NO MOVES LEFT — RESHUFFLED")
                    .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.cream.color)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(P.ink.color.opacity(0.75)))
                    .position(x: size.width / 2, y: originY + side / 2)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            if coachActive, !roundTransitioning, !game.isOver {
                let a = LuauGame.tutorialSwapA
                let b = LuauGame.tutorialSwapB
                CoachPulse(skin: .luau, diameter: cell * 1.08)
                    .position(center(a.col, a.row))
                CoachPulse(skin: .luau, diameter: cell * 1.08)
                    .position(center(b.col, b.row))
                CoachSwapArrows(skin: .luau, size: 22)
                    .position(x: center(a.col, a.row).x, y: (center(a.col, a.row).y + center(b.col, b.row).y) / 2)
            }
            if catCompActive {
                Text("ON THE HOUSE — ONE LOUNGE CAT")
                    .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(Color(red: 0.910, green: 0.702, blue: 0.235))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(P.ink.color.opacity(0.75)))
                    .position(x: size.width / 2, y: originY + side + 56)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
            if catTargeting {
                // Scrim knocks the party back so the reticle owns the eye;
                // taps pass through it to the aiming gesture below.
                RoundedRectangle(cornerRadius: side * 0.035)
                    .fill(P.ink.color.opacity(0.42))
                    .frame(width: side + gap * 2, height: side + gap * 2)
                    .position(x: size.width / 2, y: originY + side / 2)
                    .allowsHitTesting(false)
                let valid = catTargetValid
                RoundedRectangle(cornerRadius: cell * 0.2)
                    .fill(P.torch.color.opacity(valid ? 0.18 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: cell * 0.2)
                            .stroke(valid ? P.torch.color : P.cream.color.opacity(0.4), lineWidth: 3)
                    )
                    .frame(width: cell * 1.12, height: cell * 1.12)
                    .position(center(catTarget.col, catTarget.row))
                    .shadow(color: P.torch.color.opacity(valid ? 0.8 : 0), radius: 10)
                    .allowsHitTesting(false)
                Text("TAP A TILE TO PLACE THE CAT")
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.torch.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(P.ink.color.opacity(0.7)))
                    .position(x: size.width / 2, y: originY - 26)
                    .allowsHitTesting(false)
                Button(action: placeCompCat) {
                    Text("SET IT DOWN")
                        .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                        .tracking(2.5)
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(P.torch.color.opacity(valid ? 1 : 0.4)))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(!valid)
                .position(x: size.width / 2, y: originY + side + 56)
            }
        }
        .modifier(FXShake(travel: fxShakeTravel, shakes: fxShakePhase))
        .onTapGesture(coordinateSpace: .local) { location in
            guard catTargeting,
                  location.x >= originX, location.x <= originX + side,
                  location.y >= originY, location.y <= originY + side else { return }
            aimCat(location, fast: false)
        }
        // The reticle is draggable too, not just tappable — it tracks the
        // finger live. The mask keeps this gesture fully OFF outside
        // targeting so it can never contend with the pieces' swap drags.
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in aimCat(value.location, fast: true) }
                .onEnded { value in aimCat(value.location, fast: true) },
            including: catTargeting ? .all : .subviews
        )
    }

    private func specialBanner(_ text: String) -> some View {
        Text(text)
            .font(.custom("Futura-Bold", size: 26, relativeTo: .body))
            .tracking(3)
            .foregroundStyle(P.coral.color)
            .shadow(color: P.ink.color, radius: 0, x: 2, y: 2)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
    }

    private var scoreGain: Int {
        game.lastGain
    }

    private var comboBanner: some View {
        let tier = game.lastCascade
        let color: Color = tier >= 4 ? P.coral.color
            : (tier == 3 ? Color(red: 0.910, green: 0.702, blue: 0.235) : P.cream.color)
        return Text("COMBO ×\(tier)")
            .font(.custom("Futura-Bold", size: 20 + CGFloat(min(tier, 5)) * 2))
            .tracking(2)
            .foregroundStyle(color)
            .shadow(color: P.ink.color, radius: 0, x: 2, y: 2)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
    }

    private func armSpendBreak(after: Int) {
        spendBreakIndex = after
        playSpendBreak = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            playSpendBreak = false
        }
    }

    private func offerLivesEducationIfNeeded() {
        guard !store.livesExplained, !coachActive, !catCompActive, !encoreToast else { return }
        store.livesExplained = true
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { livesEducationActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(4200))
            withAnimation(.easeOut(duration: 0.4)) { livesEducationActive = false }
        }
    }

    /// RETRY path after the lives gate clears (sheet PLAY or direct tap).
    private func retryAfterGate() {
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            if game.isLevelMode {
                game.retryLevel()
            } else {
                game.newGame()
            }
            checkedBits = []
            mintedThisRun = 0
            spendBreakIndex = nil
            playSpendBreak = false
            persist()
        }
    }

}

/// One board piece: catalog art, with specials rendered at full plate size.
/// Specials also get a pulsing glow + ring — their dark plate art alone
/// reads too close to the board's own ink background to register as
/// "important" at a glance.
private struct LuauPieceView: View {
    let piece: LuauGame.Piece
    let cell: CGFloat
    @State private var pulse = false

    var body: some View {
        ZStack {
            if let glow = specialGlow {
                Circle()
                    .fill(RadialGradient(colors: [glow.opacity(0.9), glow.opacity(0)], center: .center, startRadius: 0, endRadius: cell * 0.62))
                    .frame(width: cell * (pulse ? 1.34 : 1.05), height: cell * (pulse ? 1.34 : 1.05))
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            ZStack {
                if isCargo {
                    cargoGlyph
                } else {
                if wearsKindPlate {
                    torchPlate
                }
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: cell, height: cell)
                    // The torch glyph's beam runs horizontally; a .lineV
                    // torch clears its column, so its glyph stands upright.
                    .rotationEffect(.degrees(piece.special == .lineV ? 90 : 0))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cell * 0.167)
                    .strokeBorder(specialGlow ?? .clear, lineWidth: specialGlow == nil ? 0 : 2.5)
                    .opacity(pulse ? 1 : 0.55)
            )
            .scaleEffect(specialGlow != nil && pulse ? 1.05 : 1.0)
        }
        .onAppear {
            guard specialGlow != nil else { return }
            withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    /// CARGO — the coconut. Deliberately the only thing on the board that is
    /// not a rounded square: every matchable piece sits on a plate, so a bare
    /// round husk reads as "this one is not like the others" before any copy
    /// explains why. Drawn in code rather than shipped as an asset because it
    /// is one shape and it has to sit at the same 96-unit geometry as the
    /// piece SVGs to line up with them.
    private var isCargo: Bool { LuauGame.isIngredient(piece) }

    private static let husk = Color(red: 0.427, green: 0.278, blue: 0.169)
    private static let huskLit = Color(red: 0.573, green: 0.392, blue: 0.243)
    private static let huskDark = Color(red: 0.235, green: 0.149, blue: 0.090)

    private var cargoGlyph: some View {
        let unit = cell / 96
        let d = unit * 72
        return ZStack {
            // Sits ON the board rather than in it — the shadow is what sells
            // the weight, and weight is the whole reason it falls.
            Circle().fill(P.ink.color.opacity(0.5))
                .frame(width: d, height: d)
                .offset(y: unit * 5)
            Circle()
                .fill(RadialGradient(
                    colors: [Self.huskLit, Self.husk],
                    center: .init(x: 0.36, y: 0.30),
                    startRadius: 0, endRadius: d * 0.72))
                .frame(width: d, height: d)
            Circle().strokeBorder(Self.huskDark, lineWidth: unit * 4)
                .frame(width: d, height: d)
            // The three eyes, the one detail that makes a brown circle a
            // coconut and not a rock.
            ForEach(Array([(-0.13, -0.05), (0.13, -0.05), (0.0, 0.14)].enumerated()), id: \.offset) { _, e in
                Circle().fill(Self.huskDark)
                    .frame(width: unit * 11, height: unit * 11)
                    .offset(x: d * e.0, y: d * e.1)
            }
        }
        .frame(width: cell, height: cell)
    }

    /// Specials whose glyph asset is PLATE-LESS and which therefore need the
    /// kind plate drawn behind them. The cat is excluded on purpose: its kind is
    /// -1, it matches nothing, and it has no colour to advertise. The bomb is
    /// IN on purpose: it is matchable by colour exactly like a torch, and its
    /// first life shipped without the plate — no colour to match by, and Carson
    /// reported the mechanic itself as broken.
    private var wearsKindPlate: Bool {
        piece.special == .lineH || piece.special == .lineV || piece.special == .bomb
    }

    /// Code-drawn plate in the torch's match color — the torch glyph asset
    /// is plate-less (one asset, six colors). Geometry mirrors the piece
    /// SVGs: 88×84 plate + 4-unit drop shadow inside a 96 box.
    private var torchPlate: some View {
        let unit = cell / 96
        let kind = max(0, min(piece.kind, Self.plateColors.count - 1))
        let colors = Self.plateColors[kind]
        return ZStack {
            RoundedRectangle(cornerRadius: unit * 16)
                .fill(colors.shadow)
                .frame(width: unit * 88, height: unit * 84)
                .offset(y: unit * 2)
            RoundedRectangle(cornerRadius: unit * 16)
                .fill(colors.plate)
                .frame(width: unit * 88, height: unit * 84)
                .offset(y: -unit * 2)
        }
    }

    /// Plate/shadow pairs by kind — mirrors the plate rects in the piece
    /// SVGs (LuauAssets/*.svg) so the composited torch matches its
    /// siblings exactly.
    private static let plateColors: [(plate: Color, shadow: Color)] = [
        (Color(red: 0.910, green: 0.420, blue: 0.290), Color(red: 0.651, green: 0.282, blue: 0.188)),  // hibiscus E86B4A/A64830
        (Color(red: 0.910, green: 0.706, blue: 0.314), Color(red: 0.773, green: 0.353, blue: 0.235)),  // mask E8B450/C55A3C
        (Color(red: 0.949, green: 0.894, blue: 0.757), Color(red: 0.773, green: 0.353, blue: 0.235)),  // mug F2E4C1/C55A3C
        (Color(red: 0.102, green: 0.353, blue: 0.420), Color(red: 0.071, green: 0.243, blue: 0.286)),  // float 1A5A6B/123E49
        (Color(red: 0.478, green: 0.545, blue: 0.180), Color(red: 0.290, green: 0.180, blue: 0.102)),  // frond 7A8B2E/4A2E1A
        (Color(red: 0.169, green: 0.165, blue: 0.337), Color(red: 0.106, green: 0.086, blue: 0.075)),  // flame 2B2A56/1B1613
    ]

    private var image: Image {
        switch piece.special {
        case .cat: return .luauSpecialCat
        case .lineH, .lineV: return .luauSpecialTorch
        case .bomb: return .luauSpecialBomb
        case .none: return Image.luauPieces[max(0, min(piece.kind, Image.luauPieces.count - 1))]
        }
    }

    /// nil for ordinary pieces — no glow, no ring, no pulse. Cream for the
    /// bomb because it is the open slot: gold is the torch's, twilight the
    /// cat's, and coral vanishes against the coral (hibiscus) plate — measured
    /// during the art panel, where the composited ring simply disappeared.
    private var specialGlow: Color? {
        switch piece.special {
        case .cat: return P.twilight.color
        case .lineH, .lineV: return P.torch.color
        case .bomb: return P.cream.color
        case .none: return nil
        }
    }
}

/// Translucent sand film over a jellied cell — the objective marker.
/// A warm sand wash + fixed grain speckles + torch rim; two layers read
/// deeper (darker film, heavier rim, denser grain) and the first match
/// The idle-hint ring: breathes on the two cells of a legal swap once the
/// player has stalled. Blossom rather than torch so it never reads as sand or
/// as a special — this is the game pointing, not the board changing.
///
/// Under Reduce Motion it holds steady instead of breathing. It still appears:
/// it is information for a stuck player, not decoration.
private struct LuauHintRing: View {
    let cell: CGFloat
    let reduceMotion: Bool
    @State private var breathe = false

    var body: some View {
        RoundedRectangle(cornerRadius: cell * 0.167)
            .strokeBorder(P.blossom.color.opacity(breathe ? 0.95 : 0.45), lineWidth: 3)
            .frame(width: cell * 0.94, height: cell * 0.94)
            .scaleEffect(breathe ? 1.04 : 0.98)
            .onAppear {
                guard !reduceMotion else { breathe = true; return }
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    breathe = true
                }
            }
    }
}

/// visibly thins the sand. Deliberately between P.cream and P.torch so
/// the film says "sand", not "disabled".
private struct LuauSandOverlay: View {
    let cell: CGFloat
    let layers: Int
    /// Coach-time emphasis: the film breathes so a new player can't miss
    /// which cells are sand. Slower than the coach's swap pulse (its 0.6 s
    /// round trip stays the loudest, actionable signal) and stops when the
    /// coach dismisses — real play keeps the calm static film. The overlay
    /// view persists across rounds (stable ForEach identity), so the stop
    /// must run on the flag change, not view teardown. Reduce Motion →
    /// static.
    var emphasized: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathe = false

    private let sand = Color(red: 0.925, green: 0.812, blue: 0.576)
    private let grain = Color(red: 0.545, green: 0.420, blue: 0.247)

    /// Fixed grain pattern (unit offsets from cell center) — deterministic
    /// so the board never shimmers on re-render.
    private static let grains: [CGPoint] = [
        CGPoint(x: -0.26, y: -0.24), CGPoint(x: 0.10, y: -0.30),
        CGPoint(x: 0.30, y: -0.06), CGPoint(x: -0.32, y: 0.06),
        CGPoint(x: -0.10, y: 0.16), CGPoint(x: 0.22, y: 0.27),
    ]
    private static let deepGrains: [CGPoint] = [
        CGPoint(x: -0.05, y: -0.10), CGPoint(x: 0.33, y: -0.30),
        CGPoint(x: -0.30, y: 0.31), CGPoint(x: 0.05, y: 0.33),
    ]

    var body: some View {
        let r = cell * 0.167
        ZStack {
            RoundedRectangle(cornerRadius: r)
                .fill(sand.opacity(filmOpacity))
            ForEach(Array(activeGrains.enumerated()), id: \.offset) { _, p in
                Circle()
                    .fill(grain.opacity(layers >= 2 ? 0.55 : 0.40))
                    .frame(width: cell * 0.075, height: cell * 0.075)
                    .offset(x: p.x * cell, y: p.y * cell)
            }
            RoundedRectangle(cornerRadius: r)
                .strokeBorder(P.torch.color.opacity(breathe ? 1.0 : 0.95), lineWidth: layers >= 2 ? 4 : 2.5)
            // DOUBLE SAND IS A DIFFERENT SHAPE, not a darker one. Every other
            // difference between one layer and two is quantitative — film 0.62
            // vs 0.42, ten grains vs six, a 4pt rim vs 2.5 — so it can only be
            // perceived by comparing two cells side by side, and a level made
            // entirely of double sand gives you nothing to compare against. The
            // result reads as a bug: you clear the cell, sand stays, and nothing
            // says why. A second inset crust is readable from one cell alone,
            // and its disappearance is what makes the 2 -> 1 pop legible.
            if layers >= 2 {
                RoundedRectangle(cornerRadius: r * 0.72)
                    .strokeBorder(P.torch.color.opacity(0.85), lineWidth: 2.5)
                    .padding(cell * 0.17)
            }
        }
        .frame(width: cell, height: cell)
        .onAppear { if emphasized { startBreathing() } }
        .onChange(of: emphasized) { _, on in
            if on {
                startBreathing()
            } else {
                withAnimation(.easeOut(duration: 0.3)) { breathe = false }
            }
        }
    }

    /// Film breathes between its resting opacity and a brighter crest.
    /// Layer depth keeps its meaning: a 2-layer film stays darker than a
    /// 1-layer film at every phase of the breath.
    private var filmOpacity: Double {
        let base: Double = layers >= 2 ? 0.62 : 0.42
        return breathe ? min(base + 0.20, 0.82) : base
    }

    private func startBreathing() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
            breathe = true
        }
    }

    private var activeGrains: [CGPoint] {
        layers >= 2 ? Self.grains + Self.deepGrains : Self.grains
    }
}

/// Floating "+N" under the board on every clear round.
private struct GainPopupLuau: View {
    let text: String
    @State private var risen = false

    var body: some View {
        ZStack {
            Text(text)
                .offset(x: 2, y: 2)
                .foregroundStyle(P.ink.color.opacity(0.9))
            Text(text)
                .foregroundStyle(Color(red: 0.910, green: 0.702, blue: 0.235))
        }
        .font(.custom("Futura-Bold", size: 24, relativeTo: .body))
        .tracking(1)
        .scaleEffect(risen ? 1.05 : 0.5)
        .offset(y: risen ? 30 : 0)
        .opacity(risen ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { risen = true }
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    LuauView()
        .environment(PlayerStore(inMemory: true))
}
