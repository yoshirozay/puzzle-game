import SwiftUI

/// Blueprints — nonograms over the volcanic cove. A drawer of tiki pixel-art
/// blueprints: pencil-fill cells by the run clues, and a finished draft
/// colorizes into its picture. Progress (solved drafts + the in-progress
/// grid) persists in SwiftData; each completed draft pays the wallet.
struct BlueprintsView: View {
    var onExitRequested: () -> Void = { }
    @Environment(PlayerStore.self) private var store
    @State private var game = BlueprintsGame()
    @State private var howToOpen = false
    @State private var seenHowTo = true
    /// One-shot just-in-time teach: the first real wrong fill explains
    /// itself ("marked for you") instead of relying on panel text.
    @State private var mistakeHintShown = false
    @State private var mistakeToastActive = false
    @State private var shake: CGFloat = 0
    @State private var autoplayStarted = false
    /// First-run coach — seventeen scripted beats walking the deduction
    /// ladder (rubric v3): READ a full-line clue (row 2's 5), fill a run
    /// (row 0's 3), EARN marks (a finished clue proves its leftovers
    /// empty), CASH them on col 1's stacked `3 1`, then GENERALIZE on
    /// row 3's `1 1 1` — the three-number clue played out, not read
    /// about. The game's mode auto-flips per beat so the target is
    /// always inputtable with a single tap on the pulsed cell, and the
    /// clue label each phase reasons about is spotlit alongside the card.
    @State private var coachActive = false
    @State private var tutorialBeat: Int = 0
    /// Whether the player has pressed the coached MARK button — the tool
    /// switch is itself a taught step (rubric v5): the first cross phase
    /// waits on a solo pulsed MARK at the bottom instead of auto-flipping,
    /// and the full toggle stays visible (auto-selecting) afterwards.
    @State private var markIntroduced = false
    /// Fires after a successful tutorial dismiss so the transition from
    /// coach → real play is unmistakable (SKIP dismisses silently).
    @State private var readyBannerActive = false
    /// Depth-milestone bookkeeping: mints newly paid on this solve (toast).
    @State private var mintedThisSolve = 0
    /// Leaderboard overlay + the payoff bar's rank teaser.
    @State private var leaderboardOpen = false
    @State private var boardStandings: GameCenter.Standings?
    /// Shared lives — defeat spend beat, education toast, out-of-lives gate.
    @State private var outOfLivesOpen = false
    @State private var spendBreakIndex: Int? = nil
    @State private var playSpendBreak = false
    @State private var livesEducationActive = false
    /// Guards a single spend + VO per ruined sketch.
    @State private var defeatHandled = false
    /// Puzzle the picker wanted to open while the sheet is up.
    @State private var blockedPuzzle: BlueprintsGame.Puzzle?
    /// Auto-advance seam: the fuse that carries a finished sketch to the
    /// next unsolved blueprint without a trip through the picker.
    @State private var seamDeadline: Date?
    @State private var seamTotal: Double = 2.6
    @State private var seamHeld = false
    @State private var seamRunID = 0

    private let fillHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mistakeHaptic = UINotificationFeedbackGenerator()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                BlueprintsBackgroundView(phase: scenePhase)
                    .accessibilityHidden(true)
                if let puzzle = game.puzzle {
                    boardScreen(puzzle, size: geo.size)
                } else {
                    picker(geo.size)
                }
                if game.isComplete, let puzzle = game.puzzle, !draftedSeam {
                    BlueprintsDraftedPanel(
                        puzzle: puzzle,
                        completionNote: completionNote,
                        completionNoteGold: completionNoteGold,
                        summary: game.lastRunSummary,
                        canAffordNewItem: store.canAffordNewItem,
                        mintedThisSolve: mintedThisSolve,
                        boardRank: boardStandings?.local?.rank,
                        onNextBlueprint: {
                            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                                game.closePuzzle()
                                persist()
                            }
                        },
                        onOpenLeaderboard: {
                            withAnimation(.spring(duration: 0.3, bounce: 0.25)) { leaderboardOpen = true }
                        }
                    )
                }
                if game.isFailed, let puzzle = game.puzzle {
                    BlueprintsFailedPanel(
                        puzzleName: puzzle.name,
                        spendBreakIndex: spendBreakIndex,
                        playSpendBreak: playSpendBreak,
                        onExit: onExitRequested,
                        onPlayAgain: {
                            if store.isOutOfLives(for: .blueprints) {
                                withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
                                return
                            }
                            retryAfterGate()
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
                            withAnimation(.easeOut(duration: 0.2)) {
                                outOfLivesOpen = false
                                blockedPuzzle = nil
                            }
                        },
                        onLifeLandedPlay: {
                            withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = false }
                            if game.isFailed {
                                retryAfterGate()
                            } else if let p = blockedPuzzle {
                                blockedPuzzle = nil
                                game.begin(p)
                                persist()
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
                if leaderboardOpen {
                    LeaderboardView(theme: .blueprints) {
                        withAnimation(.easeOut(duration: 0.25)) { leaderboardOpen = false }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(90)
                }
                if coachActive, let p = game.puzzle,
                   p.id == BlueprintsGame.puzzles[BlueprintsGame.tutorialPuzzleIndex].id,
                   !game.isComplete, !game.isFailed {
                    CoachCard(
                        message: coachMessage,
                        skin: .blueprints,
                        onSkip: { dismissCoach(withSuccess: false) }
                    )
                }
                if readyBannerActive {
                    TutorialReadyBanner(message: "READY TO DRAFT", skin: .blueprints) {
                        readyBannerActive = false
                    }
                }
                if howToOpen {
                    HowToPlayPanel(title: "HOW TO DRAFT", rules: [
                        HowToRule(symbol: "number.square", text: "Each number is a run of filled cells, in order — 1 2 1 means a single, a gap, a pair, a gap, a single."),
                        HowToRule(symbol: "paintbrush.fill", text: "BRUSH paints cells you are sure of. Wrong fills cost a mistake and mark themselves — three ruins the sketch."),
                        HowToRule(symbol: "xmark.square", text: "MARK flags cells that must stay empty. Finish the picture to colorize the blueprint."),
                    ]) {
                        howToOpen = false
                        // Mid-coach the panel is reference, not completion —
                        // dismissCoach owns seenHowTo, so a kill right after
                        // peeking at the rules still resumes the script.
                        if !coachActive { markHowToSeen() }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0.25), value: howToOpen)
        }
        .ignoresSafeArea()
        .onAppear(perform: start)
        .onAppear { Analytics.entered("blueprints") }
        .onChange(of: coachActive) { _, active in
            // The FTUE is its own progression family — the one
            // place a tutorial SHOULD be counted (D-6).
            if active { Analytics.progression(.start, "coach", "blueprints") }
        }
        .onChange(of: game.puzzle?.id, initial: true) { _, id in
            guard let id, let i = BlueprintsGame.puzzles.firstIndex(where: { $0.id == id }) else { return }
            Analytics.runStarted(.blueprints, level: Analytics.sketch(i + 1), tutorial: coachActive)
        }
        .onDisappear {
            Analytics.exited("blueprints",
                             runInProgress: (game.isComplete || game.isFailed) ? nil : .blueprints)
        }
        .onChange(of: game.isComplete) { _, over in
            guard over else {
                seamDeadline = nil
                seamHeld = false
                return
            }
            boardStandings = nil
            Task { boardStandings = try? await GameCenter.shared.loadStandings(for: .blueprints) }
        }
        .task(id: seamRunID) {
            guard seamDeadline != nil else { return }
            await runSeam()
        }
        .onChange(of: game.isFailed) { _, failed in
            guard failed else {
                defeatHandled = false
                return
            }
            handleDefeat()
        }
        .onChange(of: coachActive) { _, on in
            game.setCoachShield(on)
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

    /// Moon-glow depth = the drafted fraction of the open puzzle's true cells.
    /// tier = the constellation ladder (1 + solved/3): every three drafts
    /// permanently hangs a picture in the sky (0 stays the legacy-caller
    /// sentinel). beat = first solves — each one fires the shooting star.
    private var scenePhase: ProgressPhase {
        var phase = ProgressPhase(
            tier: 1 + game.solvedIDs.count / 3,
            beat: game.solvedIDs.count
        )
        guard let p = game.puzzle, game.grid.count == p.size else { return phase }
        var total = 0
        var filled = 0
        for r in 0..<p.size {
            for c in 0..<p.size where p.truth(r, c) {
                total += 1
                if game.grid[r][c] == .filled { filled += 1 }
            }
        }
        if total > 0 { phase.depth = Double(filled) / Double(total) }
        return phase
    }

    // MARK: lifecycle

    private func start() {
        guard !autoplayStarted, game.puzzle == nil, game.solvedIDs.isEmpty else { return }
        let payload = game.restore(from: store.loadState(for: .blueprints))
        seenHowTo = payload?.seenHowTo ?? false
        mistakeHintShown = payload?.mistakeHint ?? false
        if !seenHowTo, !store.onboardingSkipped(for: .blueprints) {
            // First run: skip the picker, launch straight into the 5x5 Tiki
            // Mug warm-up. The coach enters at the first unsatisfied beat
            // (fresh grid → beat 0; a killed-app resume mid-script re-enters
            // where it left off instead of replaying or stranding) and
            // auto-flips mode per beat so the pulsed cell is always
            // inputtable.
            let mug = BlueprintsGame.puzzles[BlueprintsGame.tutorialPuzzleIndex]
            if game.puzzle == nil {
                game.begin(mug)
            }
            if game.puzzle?.id == mug.id {
                tutorialBeat = firstPendingBeat(from: 0)
                // Past both intro crosses (beats 8-9) → the tool was taught;
                // a resume inside them re-asks for the MARK press.
                markIntroduced = tutorialBeat > 9
                if tutorialBeat < BlueprintsGame.tutorialBeatCount {
                    let mode = BlueprintsGame.tutorialBeats[tutorialBeat].mode
                    if mode == .fill || markIntroduced {
                        game.mode = mode
                    }
                    coachActive = true
                    game.setCoachShield(true)
                } else {
                    // Every beat already satisfied (script finished, app died
                    // before the dismiss) — don't replay a done lesson.
                    seenHowTo = true
                }
            }
        }
        // Kill-and-relaunch mid-defeat: re-arm the panel without double-spending.
        if game.isFailed { defeatHandled = true }
        persist()
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        // Staging hook (SIMCTL_CHILD_TIKI_BLUEPRINTS_SOLVED=<n>): n sheets
        // already drafted, no coach — constellations and milestone
        // thresholds stage on demand.
        if let raw = env["TIKI_BLUEPRINTS_SOLVED"], let n = Int(raw), n >= 0 {
            game.debugSeedSolved(n)
            seenHowTo = true
            coachActive = false
            game.setCoachShield(false)
            persist()
        }
        // Dev hook (TIKI_PUZZLE=<id>): opens a specific blueprint directly.
        if let id = env["TIKI_PUZZLE"],
           let p = BlueprintsGame.puzzles.first(where: { $0.id == id }) {
            howToOpen = false
            seenHowTo = true
            game.begin(p)
        }
        // Staging: TIKI_BLUEPRINTS_MISTAKES=<n> on the live board.
        if let raw = env["TIKI_BLUEPRINTS_MISTAKES"], let n = Int(raw) {
            game.debugStageMistakes(n)
            if game.isFailed { handleDefeat() }
            persist()
        }
        if ProcessInfo.processInfo.environment["TIKI_AUTOPLAY"] == "1" {
            autoplayStarted = true
            howToOpen = false
            coachActive = false
            game.setCoachShield(false)
            seenHowTo = true
            Task { await autoplay() }
        }
        if ProcessInfo.processInfo.environment["TIKI_BLUEPRINTS_TUTORIAL_AUTOPLAY"] == "1" {
            Task { @MainActor in
                while coachActive {
                    try? await Task.sleep(for: .milliseconds(1400))
                    if !coachActive { break }
                    // The MARK intro parks the cells — press the button.
                    if awaitingMarkIntro {
                        withAnimation(.easeInOut(duration: 0.25)) { introduceMark() }
                        continue
                    }
                    guard let t = coachTargetCell else { break }
                    withAnimation(.spring(duration: 0.18, bounce: 0.4)) { tapCell(t.row, t.col) }
                }
            }
        }
        #endif
    }

    private func persist() {
        store.saveState(for: .blueprints, payload: game.payload(seenHowTo: seenHowTo, mistakeHint: mistakeHintShown))
    }

    private func markHowToSeen() {
        seenHowTo = true
        persist()
    }

    /// Phase card copy — the beat's clue value + reason clause. v1 capped
    /// cards at 4 words; that cap is retired for Blueprints (rubric v2
    /// dim 3): a logic game's card must state the why, not just the verb.
    private var coachMessage: String {
        guard tutorialBeat < BlueprintsGame.tutorialBeatCount else { return "" }
        if awaitingMarkIntro { return "THE 3 IS DONE — HIT MARK BELOW" }
        return BlueprintsGame.tutorialBeats[tutorialBeat].message
    }

    /// The script is parked on its first cross beat waiting for the player
    /// to press the solo MARK button — cells aren't the target yet.
    private var awaitingMarkIntro: Bool {
        coachActive && !markIntroduced
            && tutorialBeat < BlueprintsGame.tutorialBeatCount
            && BlueprintsGame.tutorialBeats[tutorialBeat].mode == .cross
    }

    /// Cell the coach highlights on this beat. nil while the MARK intro
    /// waits — the pulsed button owns the act-here role then.
    private var coachTargetCell: (row: Int, col: Int)? {
        guard coachActive, !awaitingMarkIntro,
              tutorialBeat < BlueprintsGame.tutorialBeatCount else { return nil }
        let beat = BlueprintsGame.tutorialBeats[tutorialBeat]
        return (beat.row, beat.col)
    }

    /// Clue label the current phase reasons about — spotlit in the clue
    /// rails while the coach is up (rubric v2 dim 5).
    private var coachClue: BlueprintsGame.ClueRef? {
        guard coachActive, tutorialBeat < BlueprintsGame.tutorialBeatCount,
              let p = game.puzzle,
              p.id == BlueprintsGame.puzzles[BlueprintsGame.tutorialPuzzleIndex].id,
              !game.isComplete else { return nil }
        return BlueprintsGame.tutorialBeats[tutorialBeat].clue
    }

    /// Whether a beat's target already holds the state the beat asks for.
    private func beatSatisfied(_ beat: BlueprintsGame.TutorialBeat) -> Bool {
        let want: BlueprintsGame.Cell = beat.mode == .fill ? .filled : .crossed
        return beat.row < game.grid.count && beat.col < game.grid[beat.row].count
            && game.grid[beat.row][beat.col] == want
    }

    /// First beat at or after `i` whose target isn't already in the state
    /// the beat asks for. Drag-ahead paint, stray auto-corrected mistakes,
    /// and killed-app resumes all leave committed cells behind — the
    /// script flows around them instead of stranding on an untappable
    /// target (rubric v2 dims 2 and 9).
    private func firstPendingBeat(from i: Int) -> Int {
        var b = i
        while b < BlueprintsGame.tutorialBeatCount,
              beatSatisfied(BlueprintsGame.tutorialBeats[b]) {
            b += 1
        }
        return b
    }

    /// The current phase's OTHER pending targets — every beat sharing the
    /// live card's message whose cell isn't committed yet, minus the
    /// primary target itself. Quiet rings on these make the run's whole
    /// shape legible at once ("5" = five circled squares) while the
    /// primary pulse still says where to act now (rubric v4 dim 7).
    private var coachPhaseCells: [(id: Int, row: Int, col: Int)] {
        guard coachActive, tutorialBeat < BlueprintsGame.tutorialBeatCount else { return [] }
        let beats = BlueprintsGame.tutorialBeats
        let message = beats[tutorialBeat].message
        return beats.enumerated().compactMap { i, beat in
            // While the MARK intro waits, the current cell rings too — the
            // pulsed button is the act-here target, and the rings preview
            // everything "cross off the rest" means.
            guard i != tutorialBeat || awaitingMarkIntro,
                  beat.message == message, !beatSatisfied(beat) else { return nil }
            return (id: i, row: beat.row, col: beat.col)
        }
    }

    /// Called after a successful scripted tap. Flow to the next pending
    /// beat (auto-flipping the game's mode to that beat's tool) or
    /// dismiss on the last.
    private func advanceTutorial() {
        let next = firstPendingBeat(from: tutorialBeat + 1)
        if next >= BlueprintsGame.tutorialBeatCount {
            dismissCoach(withSuccess: true)
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                tutorialBeat = next
                let mode = BlueprintsGame.tutorialBeats[next].mode
                // The first cross phase doesn't auto-flip: the player earns
                // it by pressing the coached MARK button (rubric v5).
                if mode == .fill || markIntroduced {
                    game.mode = mode
                }
            }
        }
    }

    /// The solo MARK press: switch tools, then resync in case stray taps
    /// already committed the waiting cross cells while the intro was up
    /// (a wrong fill auto-crosses, satisfying the beat behind the park).
    private func introduceMark() {
        fillHaptic.impactOccurred()
        TikiSound.shared.tick()
        markIntroduced = true
        game.mode = .cross
        let resync = firstPendingBeat(from: tutorialBeat)
        if resync >= BlueprintsGame.tutorialBeatCount {
            dismissCoach(withSuccess: true)
        } else if resync != tutorialBeat {
            withAnimation(.easeInOut(duration: 0.25)) {
                tutorialBeat = resync
                game.mode = BlueprintsGame.tutorialBeats[resync].mode
            }
        }
        persist()
    }

    private func dismissCoach(withSuccess: Bool) {
        Analytics.progression(withSuccess ? .complete : .fail, "coach", "blueprints")
        guard coachActive else { return }
        withAnimation(.easeOut(duration: 0.3)) { coachActive = false }
        game.setCoachShield(false)
        if withSuccess {
            CoachSkin.blueprints.dismissSound.play()
            readyBannerActive = true
        } else {
            store.setOnboardingSkipped(true, for: .blueprints)
        }
        seenHowTo = true
        persist()
    }

    private func tapCell(_ r: Int, _ c: Int) {
        let hadMistakes = game.mistakes
        guard game.tap(r, c) else { return }
        // Advance the scripted ladder only on the coach's own target — a
        // stray tap elsewhere shouldn't consume a beat. Off-target taps
        // still commit as normal play (the game state updates fine).
        if coachActive, let target = coachTargetCell, target.row == r, target.col == c,
           game.mistakes == hadMistakes {
            advanceTutorial()
        }
        if game.mistakes > hadMistakes {
            mistakeHaptic.notificationOccurred(.error)
            TikiSound.shared.mistake()
            withAnimation(.spring(duration: 0.08, bounce: 0.6)) { shake = 7 }
            withAnimation(.spring(duration: 0.2, bounce: 0.4).delay(0.08)) { shake = 0 }
            // First-ever wrong fill explains the safety net once, right as
            // it fires — the default rules taught by play, not panel text.
            if !mistakeHintShown {
                mistakeHintShown = true
                withAnimation(.spring(duration: 0.3, bounce: 0.3)) { mistakeToastActive = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(2800))
                    withAnimation(.easeOut(duration: 0.4)) { mistakeToastActive = false }
                }
            }
        } else {
            fillHaptic.impactOccurred()
            TikiSound.shared.pop()
        }
        if game.isFailed {
            handleDefeat()
        } else if game.isComplete {
            if coachActive {
                // The player solved the mug out from under the script —
                // that is graduation, not skipping. Retire the coach
                // silently (the DRAFTED overlay owns this moment; the
                // READY banner would fight it) and never replay the
                // lesson. Without this the armed coach outlives the
                // puzzle: stale beats ghost onto the next board and the
                // mode toggle stays hidden everywhere.
                withAnimation(.easeOut(duration: 0.3)) { coachActive = false }
                game.setCoachShield(false)
                seenHowTo = true
            }
            TikiSound.shared.win()
            mistakeHaptic.notificationOccurred(.success)
            // Depth milestones at 5/15/30 drafted (bits 11–13), plus the
            // full-drawer mint at 60 (bit 22). The first three thresholds are
            // left exactly where they were when the drawer held 30 sheets —
            // rescaling them would move the goalposts under players already
            // part-way — so the expansion adds a rung rather than shifting
            // the ladder. Mints land before recordRun so the payoff line
            // shows the full take; `recordMilestone` pays +75 exactly once,
            // ever. The @State write is deferred one hop: a tap resumed
            // inside the TimelineView's render window would have it dropped
            // as a mid-update mutation.
            var minted = 0
            for (i, count) in [5, 15, 30].enumerated() where game.solvedIDs.count >= count {
                if store.recordMilestone(game: .blueprints, bit: 11 + i) { minted += 1 }
            }
            if game.solvedIDs.count >= BlueprintsGame.puzzles.count,
               store.recordMilestone(game: .blueprints, bit: 22) { minted += 1 }
            let mintedNow = minted
            Task { @MainActor in mintedThisSolve = mintedNow }
            let score = game.completionScore
            // Replays pay a quarter — first solves are where the wallet lives.
            game.lastRunSummary = store.recordRun(
                game: .blueprints,
                score: score,
                earnScore: game.completedFirstSolve ? nil : max(10, score / 4)
            )
            if let p = game.puzzle,
               let i = BlueprintsGame.puzzles.firstIndex(where: { $0.id == p.id }) {
                Analytics.runEnded(.blueprints, level: Analytics.sketch(i + 1),
                                   won: true, score: score, tutorial: coachActive)
            }
            // Armed after the payout so `draftedSeam` (which requires
            // lastRunSummary) is already true when the banner mounts.
            // checkComplete has already recorded this id as solved, so the
            // lookup can never hand back the sheet just finished.
            if let id = game.puzzle?.id, game.nextUnsolved(after: id) != nil { armSeam() }
        }
        persist()
    }

    /// Defeat spends a life and arms the panel beat — never recordRun
    /// (a round is a solved sketch, not a ruined one).
    private func handleDefeat() {
        // Blueprints' recordRun is solve-only by design ("a round is a solved
        // sketch, not a ruined one"), so the defeat attempt is recorded here
        // or it is never recorded at all (§3.2).
        if !defeatHandled, let p = game.puzzle,
           let i = BlueprintsGame.puzzles.firstIndex(where: { $0.id == p.id }) {
            Analytics.runEnded(.blueprints, level: Analytics.sketch(i + 1),
                               won: false, score: game.completionScore,
                               tutorial: coachActive)
        }
        guard game.isFailed, !defeatHandled else { return }
        defeatHandled = true
        TikiSound.shared.gameOver()
        if store.spendLifeForDefeat(game: .blueprints, duringTutorial: coachActive) {
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
        guard !store.livesExplained, !coachActive, !mistakeToastActive, !readyBannerActive
        else { return }
        store.livesExplained = true
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { livesEducationActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(4200))
            withAnimation(.easeOut(duration: 0.4)) { livesEducationActive = false }
        }
    }

    /// A drafted sketch that has been paid out and has somewhere to go — the
    /// banner's mount condition and the modal's suppression condition, so the
    /// two can never both be on screen. Requiring `lastRunSummary` makes
    /// "banner visible" structural proof that the payout already landed;
    /// requiring a next sheet means the final blueprint still gets the modal
    /// send-off (with its leaderboard bar) rather than a fuse to nowhere.
    private var draftedSeam: Bool {
        guard game.isComplete, let p = game.puzzle else { return false }
        return game.lastRunSummary != nil && game.nextUnsolved(after: p.id) != nil
    }

    /// Arms the seam. Called once when a sketch is drafted.
    @MainActor
    private func armSeam() {
        // Long enough to watch the picture colorize; VoiceOver needs longer
        // still to speak the banner before the board turns over.
        let total: Double = UIAccessibility.isVoiceOverRunning ? 5.0 : 2.6
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

    /// Opens the next unsolved blueprint. Idempotent — clearing the deadline
    /// first means a tap racing the fuse can only advance once.
    @MainActor
    private func advanceSeam() {
        guard seamDeadline != nil, let p = game.puzzle,
              let next = game.nextUnsolved(after: p.id) else { return }
        seamDeadline = nil
        seamHeld = false
        // Out of lives mid-seam: land in the picker rather than silently
        // opening a board the player cannot start.
        guard !store.isOutOfLives(for: .blueprints) else {
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                game.closePuzzle()
                persist()
            }
            return
        }
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            game.begin(next)
            defeatHandled = false
            mintedThisSolve = 0
            persist()
        }
    }

    /// Same puzzle, clean board — mistakes back to zero.
    private func retryAfterGate() {
        guard let p = game.puzzle else { return }
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            game.begin(p)
            defeatHandled = false
            spendBreakIndex = nil
            playSpendBreak = false
            persist()
        }
    }

    #if DEBUG
    /// Dev hook (TIKI_AUTOPLAY=1): drafts the first unsolved blueprint with
    /// a couple of deliberate mistakes, for verification runs.
    /// TIKI_BLUEPRINTS_CLEAN=1 makes no mistakes; TIKI_BLUEPRINTS_HOLD=<k>
    /// stops with k true cells unfilled (fill-fraction warmth staging).
    private func autoplay() async {
        try? await Task.sleep(for: .milliseconds(600))
        let env = ProcessInfo.processInfo.environment
        guard let target = game.puzzle
            ?? BlueprintsGame.puzzles.first(where: { !game.solvedIDs.contains($0.id) }) else { return }
        if game.puzzle == nil {
            game.begin(target)
        }
        persist()
        var wrongBudget = env["TIKI_BLUEPRINTS_CLEAN"] == "1" ? 0 : 2
        let hold = Int(env["TIKI_BLUEPRINTS_HOLD"] ?? "") ?? 0
        var toFill = 0
        for r in 0..<target.size {
            for c in 0..<target.size where target.truth(r, c) { toFill += 1 }
        }
        for r in 0..<target.size {
            for c in 0..<target.size {
                try? await Task.sleep(for: .milliseconds(70))
                if !target.truth(r, c), wrongBudget > 0, (r + c) % 5 == 2 {
                    wrongBudget -= 1
                    tapCell(r, c)
                } else if target.truth(r, c) {
                    if toFill <= hold { return }
                    toFill -= 1
                    tapCell(r, c)
                }
            }
        }
    }
    #endif

    // MARK: picker

    private func picker(_ size: CGSize) -> some View {
        VStack(spacing: 0) {
            Text("BLUEPRINTS")
                .font(.custom("Futura-Bold", size: 24, relativeTo: .body))
                .tracking(4)
                .foregroundStyle(P.blossom.color)
                .padding(.top, 74)
            Text("\(game.solvedIDs.count) OF \(BlueprintsGame.puzzles.count) DRAFTED")
                .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.cream.color.opacity(0.8))
                .padding(.top, 4)
            // The seam took the per-solve LeaderboardBar off screen (it now
            // rides only the final completion panel), so the drawer carries
            // the entry point instead of losing it.
            LeaderboardBar(title: LeaderboardTheme.blueprints.title, rank: boardStandings?.local?.rank) {
                withAnimation(.spring(duration: 0.3, bounce: 0.25)) { leaderboardOpen = true }
            }
            .padding(.top, 12)
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(BlueprintsGame.puzzles) { puzzle in
                        puzzleCard(puzzle)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 40)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !coachActive {
                HowToPlayButton { Analytics.design("feature:blueprints:howto"); howToOpen = true }
                    .padding(.trailing, 20)
                    .padding(.top, 64)
            }
        }
        .task {
            // The drawer's own rank teaser — the board screen loads this on
            // completion, but the picker can be the first thing seen.
            guard boardStandings == nil else { return }
            boardStandings = try? await GameCenter.shared.loadStandings(for: .blueprints)
        }
    }

    private func puzzleCard(_ puzzle: BlueprintsGame.Puzzle) -> some View {
        let solved = game.solvedIDs.contains(puzzle.id)
        return Button {
            if store.isOutOfLives(for: .blueprints) {
                blockedPuzzle = puzzle
                withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
                return
            }
            game.begin(puzzle)
            defeatHandled = false
            persist()
        } label: {
            VStack(spacing: 8) {
                if solved {
                    PixelArtView(puzzle: puzzle, colors: BlueprintColors.for(puzzle.id))
                        .frame(width: 74, height: 74)
                } else {
                    Text("?")
                        .font(.custom("Futura-Bold", size: 34, relativeTo: .body))
                        .foregroundStyle(P.blossom.color.opacity(0.55))
                        .frame(width: 74, height: 74)
                }
                Text(solved ? puzzle.name.uppercased() : "\(puzzle.size)×\(puzzle.size)")
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(solved ? P.torch.color : P.cream.color.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(P.deepLeaf.color.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(solved ? P.torch.color.opacity(0.6) : P.blossom.color.opacity(0.25), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: board

    private func boardScreen(_ puzzle: BlueprintsGame.Puzzle, size: CGSize) -> some View {
        let n = puzzle.size
        let m = BlueprintsBoardMetrics(
            size: n,
            screen: size,
            widestClue: BlueprintsBoardMetrics.widestClue(for: puzzle)
        )
        let cell = m.cell
        let clueW = m.clueW
        let clueH = m.clueH
        let clueFont = m.clueFont
        let sideMargin = BlueprintsBoardMetrics.sideMargin

        let oneLeft = game.mistakes == BlueprintsGame.mistakeCap - 1
        return VStack(spacing: 0) {
            HStack {
                Button {
                    game.closePuzzle()
                    coachActive = false
                    game.setCoachShield(false)
                    defeatHandled = false
                    persist()
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(P.blossom.color)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(P.ink.color.opacity(0.55)))
                }
                .buttonStyle(.plain)
                // Sits beside ContentView's global back chevron, not under
                // it. Both were landing within 3pt of each other in the same
                // corner, and the chevron is drawn later in the ZStack, so it
                // swallowed every tap and the drawer was unreachable from a
                // board. They do different things — chevron leaves the game,
                // this opens the drawer — so both need to be hittable.
                .padding(.leading, 48)
                .accessibilityLabel("All blueprints")
                Spacer()
                VStack(spacing: 2) {
                    Text(puzzle.name.uppercased())
                        .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.blossom.color)
                    Text("MISTAKES \(game.mistakes)/\(BlueprintsGame.mistakeCap)")
                        .font(.custom("Futura-Medium", size: 10, relativeTo: .body))
                        .tracking(1.5)
                        .foregroundStyle(
                            oneLeft ? P.coral.color
                            : game.mistakes == 0 ? P.cream.color.opacity(0.7) : P.coral.color.opacity(0.85)
                        )
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 30)) { ctx in
                        LivesHearts(count: store.livesSnapshot(now: ctx.date).count, size: .chip)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(P.ink.color.opacity(0.55)))
                    // Reachable even mid-coach (rubric v2 dim 7 inverts v1's
                    // hidden-help rule): a confused first-runner must be able
                    // to open the full rules; the script resumes untouched
                    // when the panel closes.
                    HowToPlayButton { Analytics.design("feature:blueprints:howto"); howToOpen = true }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)

            Spacer()

            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    Color.clear.frame(width: clueW, height: clueH)
                    ForEach(0..<n, id: \.self) { r in
                        let lit = coachClue == .row(r)
                        Text(game.rowClues(r).map(String.init).joined(separator: " "))
                            .font(.custom("Futura-Bold", size: clueFont))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(lit ? P.torch.color : P.blossom.color)
                            .opacity(game.rowSatisfied(r) && !lit ? 0.32 : 1)
                            .frame(width: clueW, height: cell, alignment: .trailing)
                            .padding(.trailing, 4)
                            .modifier(ClueSpotlight(active: lit))
                    }
                }
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(0..<n, id: \.self) { c in
                            let lit = coachClue == .col(c)
                            // Stacked digits breathe (≥ 8% of cell height,
                            // rubric v2 dim 6) so a `1 2 1` column reads as
                            // three runs, never as "121".
                            VStack(spacing: max(2, cell * 0.1)) {
                                ForEach(Array(game.colClues(c).enumerated()), id: \.offset) { _, clue in
                                    Text("\(clue)")
                                        .font(.custom("Futura-Bold", size: clueFont))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .foregroundStyle(lit ? P.torch.color : P.blossom.color)
                                }
                            }
                            .opacity(game.colSatisfied(c) && !lit ? 0.32 : 1)
                            .frame(width: cell, height: clueH, alignment: .bottom)
                            .modifier(ClueSpotlight(active: lit))
                        }
                    }
                    grid(puzzle, cell: cell)
                        .offset(x: shake)
                }
            }
            // Small boards keep the old asymmetric trailing inset; only the
            // responsive tiers claim the extra width.
            .padding(.trailing, m.isLegacy ? BlueprintsBoardMetrics.legacyTrailingPad : 0)
            .padding(.horizontal, m.isLegacy ? 0 : sideMargin)

            Spacer()
            if draftedSeam, let deadline = seamDeadline,
               let next = game.nextUnsolved(after: puzzle.id) {
                // Takes the tool toggle's slot — the tools are dead once the
                // picture is finished. Laid out in flow rather than floated
                // over the board, so it can never cover the reveal the
                // player just earned.
                BlueprintsDraftedBanner(
                    puzzleName: puzzle.name,
                    nextName: next.name,
                    completionNote: completionNote,
                    completionNoteGold: completionNoteGold,
                    pointsEarned: game.lastRunSummary?.pointsEarned,
                    deadline: deadline,
                    total: seamTotal,
                    holding: seamHeld,
                    onHoldChanged: { held in
                        guard held != seamHeld else { return }
                        seamHeld = held
                        if held { fillHaptic.impactOccurred() }
                    },
                    onSkip: { advanceSeam() }
                )
                .padding(.bottom, 30)
                .transition(.offset(y: 26).combined(with: .opacity))
            } else if game.isComplete {
                Color.clear.frame(height: 1)
            } else if !coachActive || markIntroduced {
                // Visible mid-coach once MARK is taught: the auto-selection
                // animating between BRUSH and MARK keeps the tool concept
                // on screen for the rest of the script (rubric v5).
                modeToggle
                    .padding(.bottom, 44)
                    .transition(.opacity)
            } else if awaitingMarkIntro {
                soloMarkIntro
                    .padding(.bottom, 44)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if mistakeToastActive {
                Text("WRONG CELL — MARKED FOR YOU")
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.cream.color)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(P.coral.color.opacity(0.92)))
                    .padding(.bottom, 108)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .allowsHitTesting(false)
            }
        }
    }

    @State private var lastPainted: (r: Int, c: Int)? = nil
    /// A drag acts only on cells in the state its first cell had — so a
    /// draft-mode stroke that doubles back can't erase what it just painted.
    @State private var dragIntent: BlueprintsGame.Cell? = nil

    private func grid(_ puzzle: BlueprintsGame.Puzzle, cell: CGFloat) -> some View {
        let n = puzzle.size
        let colors = BlueprintColors.for(puzzle.id)
        return VStack(spacing: 0) {
            ForEach(0..<n, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<n, id: \.self) { c in
                        cellView(puzzle, r: r, c: c, side: cell, colors: colors)
                    }
                }
            }
        }
        // While drafting, the cool deepLeaf slate. On completion the board
        // becomes the mat the finished picture is pinned to — otherwise the
        // colorize payoff lands dark-on-dark for every woody subject.
        .background((game.isComplete ? BlueprintColors.mat(for: puzzle.id).color : P.deepLeaf.color.opacity(0.9)))
        // Classic nonogram 5-block separators for larger boards.
        .overlay(
            Path { path in
                for i in stride(from: 5, to: n, by: 5) {
                    let offset = CGFloat(i) * cell
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset, y: cell * CGFloat(n)))
                    path.move(to: CGPoint(x: 0, y: offset))
                    path.addLine(to: CGPoint(x: cell * CGFloat(n), y: offset))
                }
            }
            .stroke(P.blossom.color.opacity(0.75), lineWidth: 1.5)
        )
        .overlay(Rectangle().stroke(P.blossom.color.opacity(0.7), lineWidth: 2))
        .overlay(alignment: .topLeading) {
            if coachActive,
               puzzle.id == BlueprintsGame.puzzles[BlueprintsGame.tutorialPuzzleIndex].id,
               !game.isComplete {
                // Quiet rings on the phase's remaining cells — the run's
                // full shape reads at a glance; each vanishes as its cell
                // commits. During the MARK-intro park these are the only
                // cell chrome (the pulsed button owns act-here), so they
                // render independent of the target (rubric v5 dim 7).
                ForEach(coachPhaseCells, id: \.id) { c in
                    CoachGroupRing(diameter: cell * 0.8)
                        .position(x: (CGFloat(c.col) + 0.5) * cell, y: (CGFloat(c.row) + 0.5) * cell)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                if let target = coachTargetCell {
                    CoachPulse(skin: .blueprints, diameter: cell * 1.05)
                        .position(x: (CGFloat(target.col) + 0.5) * cell, y: (CGFloat(target.row) + 0.5) * cell)
                        .allowsHitTesting(false)
                    CoachArrow(skin: .blueprints, direction: .down, size: 26)
                        .position(x: (CGFloat(target.col) + 0.5) * cell, y: (CGFloat(target.row) + 0.5) * cell - cell * 0.95)
                        .allowsHitTesting(false)
                }
            }
        }
        // Drag paints a run of cells in the active mode; a tap is a 0-length drag.
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let fx = value.location.x / cell
                    let fy = value.location.y / cell
                    // Reject points off the board BEFORE truncation:
                    // Int(-0.4) is 0, so a drag exiting the left/top edge
                    // used to keep phantom-painting row/col 0 from up to a
                    // full cell outside the grid.
                    guard fx >= 0, fy >= 0 else { return }
                    let c = Int(fx)
                    let r = Int(fy)
                    guard r < n, c < n else { return }
                    if let last = lastPainted, last.r == r, last.c == c { return }
                    // After the first cell, a NEW cell only paints once the
                    // touch reaches its inner 70% — boundary grazes and
                    // release-overshoot stop adding cells you never meant
                    // to hit. First touch keeps full-cell hit area so taps
                    // stay forgiving at cell edges.
                    if lastPainted != nil {
                        guard abs(fx - (CGFloat(c) + 0.5)) <= 0.35,
                              abs(fy - (CGFloat(r) + 0.5)) <= 0.35 else { return }
                    }
                    lastPainted = (r, c)
                    let state: BlueprintsGame.Cell =
                        (r < game.grid.count && c < game.grid[r].count) ? game.grid[r][c] : .empty
                    if dragIntent == nil { dragIntent = state }
                    guard state == dragIntent else { return }
                    withAnimation(.spring(duration: 0.18, bounce: 0.4)) { tapCell(r, c) }
                }
                .onEnded { _ in
                    lastPainted = nil
                    dragIntent = nil
                }
        )
    }

    @ViewBuilder
    private func cellView(_ puzzle: BlueprintsGame.Puzzle, r: Int, c: Int, side: CGFloat, colors: (RGB, RGB)) -> some View {
        // Bounds-guarded: a ForEach child can receive a final update while the
        // board is being torn down or swapped for a different-sized puzzle.
        let state: BlueprintsGame.Cell =
            (r < game.grid.count && c < game.grid[r].count) ? game.grid[r][c] : .empty
        ZStack {
            Rectangle()
                .fill(P.deepLeaf.color.opacity(0.01))
                .overlay(Rectangle().stroke(P.blossom.color.opacity(0.22), lineWidth: 0.7))
            if state == .filled {
                Rectangle()
                    .fill(game.isComplete
                          ? (puzzle.isAccent(r, c) ? colors.1 : colors.0).color
                          : P.cream.color)
                    .padding(game.isComplete ? 0 : side * 0.08)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            } else if state == .crossed {
                Image(systemName: "xmark")
                    .font(.system(size: side * 0.4, weight: .bold))
                    .foregroundStyle(P.coral.color.opacity(0.85))
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
        .frame(width: side, height: side)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            modeButton("BRUSH", symbol: "paintbrush.fill", mode: .fill)
            modeButton("MARK", symbol: "xmark", mode: .cross)
                .simultaneousGesture(TapGesture().onEnded {
                    Analytics.design("feature:blueprints:mark")
                })
        }
        .background(Capsule().fill(P.ink.color.opacity(0.55)))
    }

    /// The MARK tool's debut: a lone coached button where the toggle
    /// normally sits. The card says "HIT MARK BELOW"; pressing it flips
    /// the mode, unparks the cross beats, and graduates the bottom bar
    /// to the full toggle (rubric v5 dim 7).
    private var soloMarkIntro: some View {
        Button(action: introduceMark) {
            HStack(spacing: 7) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                Text("MARK")
                    .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                    .tracking(1.5)
            }
            .foregroundStyle(P.blossom.color)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Capsule().fill(P.ink.color.opacity(0.55)))
            .overlay(CoachCapsulePulse())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark tool")
        .accessibilityHint("Switches to marking empty cells")
    }

    private func modeButton(_ label: String, symbol: String, mode: BlueprintsGame.Mode) -> some View {
        let selected = game.mode == mode
        return Button {
            game.mode = mode
            fillHaptic.impactOccurred()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                Text(label)
                    .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                    .tracking(1.5)
            }
            .foregroundStyle(selected ? P.ink.color : P.blossom.color)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Capsule().fill(selected ? P.torch.color : .clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: completion

    private var completionNote: String {
        if !game.completedFirstSolve { return "REDRAFT — REDUCED POINTS" }
        return game.mistakes == 0 ? "PERFECT DRAFT" : "MISTAKES \(game.mistakes)"
    }

    private var completionNoteGold: Bool {
        game.completedFirstSolve && game.mistakes == 0
    }
}

/// Capsule twin of the shared CoachPulse (which is circle-only and lives
/// in the Luau session's file) for pulsing the solo MARK button — same
/// 1.67 Hz cadence and blossom skin; Reduce Motion pins it static.
private struct CoachCapsulePulse: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        Capsule()
            .stroke(P.blossom.color.opacity(animate ? 0.15 : 1.0), lineWidth: 1.5)
            .scaleEffect(animate ? 1.16 : 1.0)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
    }
}

/// Quiet steady ring on a remaining cell of the coach's current phase —
/// visually subordinate to CoachPulse (smaller, hairline, no animation)
/// so the primary act-here signal stays unambiguous while the run's
/// whole shape stays visible (rubric v4 dim 7). Static by construction,
/// so Reduce Motion needs no branch.
private struct CoachGroupRing: View {
    var diameter: CGFloat

    var body: some View {
        Circle()
            .stroke(P.blossom.color.opacity(0.5), lineWidth: 1.2)
            .frame(width: diameter, height: diameter)
    }
}

/// Torch-lit emphasis on the clue label the coach's current phase reasons
/// about — the number itself joins the visual sentence of card + arrow +
/// cell pulse (rubric v2 dim 5). Pulse cadence matches CoachPulse (0.3 s
/// half-cycle, ~1.67 Hz); Reduce Motion pins a static highlight.
private struct ClueSpotlight: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? (reduceMotion || !pulse ? 1.12 : 1.22) : 1)
            .shadow(color: P.torch.color.opacity(active ? 0.7 : 0), radius: active ? 5 : 0)
            .onChange(of: active) { _, on in setPulse(on) }
            .onAppear { setPulse(active) }
    }

    private func setPulse(_ on: Bool) {
        if on, !reduceMotion {
            pulse = false
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { pulse = false }
        }
    }
}

/// Colorized mini-render of a puzzle bitmap (picker cards + completion).
/// With `animated`, cells ink in as a diagonal wave — the reveal moment.
///
/// Sits on its own backing mat (`BlueprintColors.mat`) with a cell of quiet
/// margin, so the silhouette reads against a known backdrop instead of
/// whatever card happens to be behind it — the drafting sheet a finished
/// blueprint gets pinned to.
struct PixelArtView: View {
    let puzzle: BlueprintsGame.Puzzle
    let colors: (RGB, RGB)
    var animated = false
    var mat: RGB? = nil
    @State private var revealed = false

    var body: some View {
        GeometryReader { geo in
            let n = puzzle.size
            // One cell of margin all round, so edge-touching art never bleeds
            // into the mat's own border.
            let side = geo.size.width / CGFloat(n + 2)
            let inset = side
            ForEach(0..<n, id: \.self) { r in
                ForEach(0..<n, id: \.self) { c in
                    if puzzle.truth(r, c) {
                        Rectangle()
                            .fill((puzzle.isAccent(r, c) ? colors.1 : colors.0).color)
                            .frame(width: side, height: side)
                            .position(
                                x: inset + side * (CGFloat(c) + 0.5),
                                y: inset + side * (CGFloat(r) + 0.5)
                            )
                            .scaleEffect(animated && !revealed ? 0.01 : 1)
                            .animation(
                                animated
                                    ? .spring(duration: 0.3, bounce: 0.45)
                                        .delay(Double(r + c) * 0.75 / Double(n))
                                    : nil,
                                value: revealed
                            )
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill((mat ?? BlueprintColors.mat(for: puzzle.id)).color)
        )
        .onAppear { if animated { revealed = true } }
    }
}

/// Board geometry for one puzzle on one screen.
///
/// The cell used to be a flat `0.72 * width / n`, which pinned the board to
/// the same box at every size and let the cells shrink instead: 56pt at 5x5
/// but 28pt at 10x10 — under the 44pt tap target, with 10.7pt clue digits —
/// while roughly 300pt of vertical space sat unused. Here the cell is taken
/// from whichever budget actually binds, and the clue rail is measured in
/// cells rather than as a slice of the screen, which is what lets the grid
/// grow on the big boards.
///
/// Pure and screen-parameterised so the sizing can be asserted in tests
/// rather than eyeballed in a screenshot.
struct BlueprintsBoardMetrics {
    /// Deepest column stack the content gate allows is 4 runs; at 0.38-cell
    /// digits with 0.1-cell air that needs ~2.34 cells to clear the grid.
    static let bandCells: CGFloat = 2.4
    static let sideMargin: CGFloat = 6
    /// Air between the row clue and the grid's left edge.
    static let railPadding: CGFloat = 4
    /// Header block and the tool toggle, with their padding.
    static let chromeHeight: CGFloat = 236
    /// Clue digits stop shrinking with the board; the labels carry
    /// `minimumScaleFactor` so a rare long clue still fits its rail.
    static let minClueFont: CGFloat = 12.5

    /// Smallest board that takes the budget-derived geometry. Below this the
    /// original fixed-box rule is kept verbatim: those tiers already read
    /// well (5x5 lands at ~57pt cells), and widening them only bought a
    /// point or two while changing a layout Carson liked. The responsive
    /// rule exists to rescue the dense tiers, so it applies only there.
    static let responsiveFloor = 9

    /// The pre-existing rule: the board occupied a fixed 72% of the width at
    /// every size, with a 17%-of-width clue rail.
    static let legacyBoardFraction: CGFloat = 0.72
    static let legacyRailFraction: CGFloat = 0.17
    /// The old layout's only horizontal inset, on the trailing edge.
    static let legacyTrailingPad: CGFloat = 12

    let size: Int
    let screen: CGSize
    /// The widest row-clue string this puzzle can show, e.g. "1 1 1 1 1".
    /// The rail is sized from this text's real drawn width — an estimated
    /// em-multiple was wrong by 8pt and put Sunset's clues on the screen edge.
    let widestClue: String

    var isLegacy: Bool { size < Self.responsiveFloor }

    /// Cell, rail and font are mutually dependent on the big boards (font
    /// floors, rail follows the drawn text, cell is what's left). Two passes
    /// settle it: the first prices the rail from a trial cell, the second
    /// spends the real remainder. Small boards skip all of it and use the
    /// original proportions.
    private var solved: (cell: CGFloat, rail: CGFloat, font: CGFloat) {
        let n = CGFloat(size)
        guard !isLegacy else {
            let c = screen.width * Self.legacyBoardFraction / n
            return (c, screen.width * Self.legacyRailFraction, c * 0.38)
        }
        let heightCell = (screen.height - Self.chromeHeight) / (n + Self.bandCells)
        let usable = screen.width - Self.sideMargin * 2

        func pass(_ trialCell: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
            let font = max(Self.minClueFont, trialCell * 0.38)
            let rail = Self.railWidth(widestClue, font: font)
            let byWidth = (usable - rail) / n
            return (max(1, min(byWidth, heightCell)), rail, font)
        }

        // Trial: the width budget ignoring the rail, which always overshoots,
        // so the first rail price is an upper bound and the second is stable.
        let (c1, _, _) = pass(usable / n)
        let (c2, rail, font) = pass(c1)
        return (c2, rail, font)
    }

    var cell: CGFloat { solved.cell }
    var clueW: CGFloat { solved.rail }
    var clueH: CGFloat { cell * Self.bandCells }
    var clueFont: CGFloat { solved.font }

    /// Drawn width of a clue string plus its air, in the real board font.
    static func railWidth(_ clue: String, font size: CGFloat) -> CGFloat {
        let f = UIFont(name: "Futura-Bold", size: size)
            ?? .systemFont(ofSize: size, weight: .bold)
        return (clue as NSString).size(withAttributes: [.font: f]).width + railPadding * 2
    }

    /// The widest row clue a puzzle can display.
    static func widestClue(for puzzle: BlueprintsGame.Puzzle) -> String {
        (0..<puzzle.size)
            .map { r in
                BlueprintsGame.clues(for: (0..<puzzle.size).map { puzzle.truth(r, $0) })
                    .map(String.init).joined(separator: " ")
            }
            .max(by: { $0.count < $1.count }) ?? "0"
    }
}

/// Per-blueprint reveal palettes (primary, accent) — mode-stable P colors.
///
/// Returns `RGB` rather than `Color` so `mat(for:)` can measure luminance:
/// the drawer holds both very dark subjects (a woodDark totem) and very
/// light ones (a cream moon), and each needs the opposite backing.
enum BlueprintColors {
    static func `for`(_ id: String) -> (RGB, RGB) {
        switch id {
        case "mug": return (P.driftwood, P.torch)
        case "hibiscus": return (P.coral, P.torch)
        case "anchor": return (P.ink, P.torch)
        case "pineapple": return (P.torch, P.palmLeaf)
        case "umbrella": return (P.coral, P.blossom)
        case "limewedge": return (P.olive, P.torch)
        case "beachball": return (P.coral, P.blossom)
        case "sun": return (P.torch, P.coral)
        case "tikibowl": return (P.clay, P.torch)
        case "bongo": return (P.driftwood, P.cream)
        case "coupe": return (P.lagoon, P.blossom)
        case "parasol": return (P.coral, P.cream)
        case "rumbottle": return (P.palmLeaf, P.torch)
        case "beachshack": return (P.driftwood, P.torch)
        case "jellyfish": return (P.blossom, P.coral)
        case "goblet": return (P.clay, P.cream)
        case "cocopalm": return (P.palmLeaf, P.driftwood)
        case "sanddollar": return (P.cream, P.clay)
        case "barrel": return (P.woodDark, P.torch)
        case "bamboo": return (P.olive, P.cream)
        case "tikiflame": return (P.coral, P.torch)
        case "coralfan": return (P.clay, P.blossom)
        case "firepit": return (P.torch, P.ink)
        case "mask": return (P.clay, P.torch)
        case "palm": return (P.palmLeaf, P.driftwood)
        case "cat": return (P.ink, P.torch)
        case "martini": return (P.blossom, P.coral)
        case "float": return (P.lagoon, P.driftwood)
        case "ukulele": return (P.driftwood, P.woodDark)
        case "crab": return (P.coral, P.ink)
        case "idol": return (P.clay, P.coral)
        case "vinyl": return (P.ink, P.coral)
        case "outrigger": return (P.driftwood, P.lagoon)
        case "lantern": return (P.coral, P.torch)
        case "shell": return (P.blossom, P.cream)
        case "moonrise": return (P.cream, P.torch)
        case "skull": return (P.cream, P.ink)
        case "grasshut": return (P.driftwood, P.torch)
        case "manta": return (P.lagoon, P.cream)
        case "lighthouse": return (P.blossom, P.coral)
        case "marlin": return (P.lagoon, P.torch)
        case "hula": return (P.olive, P.torch)
        case "longboard": return (P.cream, P.coral)
        case "seacave": return (P.woodDark, P.cream)
        case "gecko": return (P.olive, P.torch)
        case "conch": return (P.blossom, P.clay)
        case "crossedoars": return (P.driftwood, P.cream)
        case "moonjelly": return (P.blossom, P.lagoon)
        case "driftlog": return (P.woodDark, P.torch)
        case "volcano": return (P.woodDark, P.coral)
        case "torch": return (P.driftwood, P.torch)
        case "blowfish": return (P.torch, P.ink)
        case "turtle": return (P.palmLeaf, P.driftwood)
        case "kraken": return (P.clay, P.cream)
        case "sunset": return (P.lagoon, P.torch)
        case "castaway": return (P.lagoon, P.driftwood)
        case "compass": return (P.driftwood, P.coral)
        case "island": return (P.palmLeaf, P.driftwood)
        case "totem": return (P.woodDark, P.torch)
        case "starfish": return (P.coral, P.torch)
        default: return (P.cream, P.torch)
        }
    }

    /// The two backing sheets a finished blueprint can be pinned to.
    static let lightMat = P.blossom
    static let darkMat = P.ink

    /// Backing sheet for a drafted blueprint, *derived* from its own palette
    /// rather than authored per puzzle: whichever mat its primary reads
    /// louder against wins. Without this the art was drawn straight onto the
    /// DRAFTED card (`P.woodDark`) and the picker card (`P.deepLeaf`), where
    /// a woodDark totem scored 1.00:1 — literally invisible — and 23 of the
    /// 30 sheets sat under 3:1. Deriving it means new puzzles are covered
    /// the moment their palette lands, with nothing extra to author.
    static func mat(for id: String) -> RGB {
        let primary = `for`(id).0
        return contrast(primary, lightMat) >= contrast(primary, darkMat) ? lightMat : darkMat
    }

    /// WCAG relative luminance.
    static func luminance(_ c: RGB) -> Double {
        func channel(_ v: Double) -> Double {
            v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    /// WCAG contrast ratio, 1.0 (identical) ... 21.0 (black on white).
    static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

#Preview {
    BlueprintsView()
        .environment(PlayerStore(inMemory: true))
}
