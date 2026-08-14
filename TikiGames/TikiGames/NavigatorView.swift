import SwiftUI

/// Navigator — memory-flash run over the open-ocean night scene. The chart
/// glows (peek), the clouds close, and the player taps the stars back from
/// memory. Input is untimed; budget is 3 mistakes per passage; running out
/// ends the RUN and drops the player back to Passage 1 (2048-shaped, no
/// free retries — see NavigatorGame's run model doc for the full policy).
struct NavigatorView: View {
    /// Called when the player wants to leave to the bundle picker. Set by
    /// ContentView so this view can intercept back-taps with the "pause
    /// voyage?" confirmation before routing home. Defaults to no-op for
    /// previews.
    var onExitRequested: () -> Void = { }

    @Environment(PlayerStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var game = NavigatorGame()

    @State private var started = false
    @State private var seenHowTo = true
    @State private var howToOpen = false
    @State private var coachActive = false
    @State private var readyBannerActive = false
    @State private var repeekActive = false
    @State private var watchTheSky = false
    /// Leaderboard overlay + the payoff bar's rank teaser.
    @State private var leaderboardOpen = false
    @State private var boardStandings: GameCenter.Standings?
    @State private var waveGap = false
    @State private var pendingPeek = false
    @State private var showPauseDialog = false
    /// Set true when the back-button flow applies the penalty. Guards
    /// `leave()` from double-applying it if `.onDisappear` fires afterward.
    @State private var hasHandledExit = false
    @State private var decoyLit: Set<Int> = []
    @State private var passageSummary: RunSummary?
    @State private var newBestFlash = false
    @State private var peekTask: Task<Void, Never>?
    @State private var decoyTask: Task<Void, Never>?
    @State private var autoplayTask: Task<Void, Never>?
    /// Passage-won celebration: the constellation traces itself star-to-star
    /// on the open board first; the panel is held back until this flips.
    @State private var showWonPanel = false
    @State private var constellationTrace: CGFloat = 0
    @State private var winPanelTask: Task<Void, Never>?
    /// Shared out-of-lives sheet — TRY AGAIN / START RUN at 0 lives.
    @State private var outOfLivesOpen = false
    @State private var spendBreakIndex: Int? = nil
    @State private var playSpendBreak = false
    @State private var livesEducationActive = false

    private let starHaptic = UIImpactFeedbackGenerator(style: .light)
    private let missHaptic = UINotificationFeedbackGenerator()
    private let winHaptic = UINotificationFeedbackGenerator()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                NavigatorBackgroundView(phase: scenePhase)
                    .accessibilityHidden(true)
                // Run-start screen shows only when NO run is in flight —
                // gating on `level == nil` (not phase==idle), because
                // advanceAfterWin briefly leaves phase in .idle while the
                // next passage's runPeek is queued (850ms watch-the-sky).
                if game.level == nil {
                    runStartScreen
                        .padding(.top, 64)
                        .background(P.ink.color.opacity(0.96))
                        .transition(.opacity)
                        .zIndex(50)
                } else {
                    NavigatorChrome(
                        game: game,
                        showTopChrome: showTopChrome,
                        peekAvailable: peekAvailable,
                        onHowTo: { howToOpen = true },
                        onPeek: { doPeek() }
                    )
                    board(geo.size)
                }
                // runOver panels immediately; passageWon holds the panel back
                // (scheduleWonPanel) so the constellation trace gets its beat.
                if game.phase == .runOver || (game.phase == .passageWon && showWonPanel) {
                    switch game.phase {
                    case .passageWon:
                        NavigatorPassageWonPanel(
                            loopComplete: game.justCompletedLoop,
                            passageId: game.level?.id ?? 0,
                            loopSubtitle: game.level.map { game.loopSubtitle($0) },
                            levelScore: game.levelScore,
                            isPerfect: game.isPerfect,
                            passageSummary: passageSummary,
                            newBestFlash: newBestFlash,
                            nextLoopNumber: game.loopNumber + 1,
                            onContinue: continueRun
                        )
                    case .runOver:
                        NavigatorRunOverPanel(
                            totalPassages: game.totalPassages,
                            reachedPassage: game.level?.id ?? 0,
                            resumePassage: game.resumePassage,
                            loopNumber: game.loopNumber,
                            newBestFlash: newBestFlash,
                            boardRank: boardStandings?.local?.rank,
                            spendBreakIndex: spendBreakIndex,
                            playSpendBreak: playSpendBreak,
                            onExit: requestExit,
                            onTryAgain: startRun,
                            onOpenLeaderboard: {
                                withAnimation(.spring(duration: 0.3, bounce: 0.25)) { leaderboardOpen = true }
                            }
                        )
                    default:
                        EmptyView()
                    }
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
                            startRunAfterGate()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
                if leaderboardOpen {
                    LeaderboardView(theme: .navigator) {
                        withAnimation(.easeOut(duration: 0.25)) { leaderboardOpen = false }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(90)
                }
                // The coach's SKIP chip owns the top-left corner during the
                // tutorial — the two would stack at the same spot.
                if showTopChrome, !coachActive {
                    backButton
                        .zIndex(80)
                }
                if coachActive {
                    CoachCard(
                        message: coachMessage,
                        skin: .navigator,
                        onSkip: { dismissCoach(withSuccess: false) }
                    )
                    .zIndex(85)
                }
                if readyBannerActive {
                    TutorialReadyBanner(message: "READY TO SAIL", skin: .navigator) {
                        dismissReadyBanner()
                    }
                    .zIndex(95)
                }
                if howToOpen {
                    HowToPlayPanel(title: "HOW TO NAVIGATE", rules: [
                        HowToRule(image: .navigatorStar, text: "The star chart glows, then the clouds roll in. Memorize it."),
                        HowToRule(image: .navigatorCell, text: "Tap every cell where a star shone. Order doesn't matter."),
                        HowToRule(image: .navigatorCloud, text: "Three misses on a passage end the whole run — the clouds close in and you're back to Passage 1."),
                        HowToRule(image: .navigatorDecoy, text: "PEEK parts the clouds once. Back out to play another game if you like — you'll lose a step of progress on return."),
                    ]) {
                        dismissHowTo()
                    }
                    .zIndex(90)
                }
            }
        }
        .ignoresSafeArea()
        .confirmationDialog(
            "Pause voyage?",
            isPresented: $showPauseDialog,
            titleVisibility: .visible
        ) {
            Button("Pause and Exit", role: .destructive) {
                Analytics.design("feature:navigator:pauseexit")
                performExit(penalize: true)
            }
            Button("Continue Voyage", role: .cancel) { }
        } message: {
            Text("Leaving mid-passage drops you back one passage on return.")
        }
        .onAppear(perform: start)
        .onAppear { Analytics.entered("navigator") }
        .onChange(of: coachActive) { _, active in
            // The FTUE is its own progression family — the one
            // place a tutorial SHOULD be counted (D-6).
            if active { Analytics.progression(.start, "coach", "navigator") }
        }
        .onChange(of: game.phase) { _, phase in
            // `.peek(0)` is the first wave of a NEW passage; later peeks are
            // further waves of the same one.
            guard phase == .peek(0) else { return }
            Analytics.runStarted(.navigator, level: Analytics.passage(game.totalPassages),
                                 tutorial: coachActive)
        }
        .onDisappear {
            // `.idle` and `.runOver` are both "no voyage in flight".
            let live = game.phase != .idle && game.phase != .runOver
            Analytics.exited("navigator", runInProgress: live ? .navigator : nil)
        }
        .onChange(of: game.phase) { _, p in
            if p == .passageWon {
                // Live chart update each passage — a long voyage ranks in
                // real time, not only at the fall.
                GameCenter.shared.submitLive(score: game.totalPassages, for: .navigator)
            }
            guard p == .runOver else { return }
            // The chart ranks total passages per run — submitted here, not
            // through the per-passage recordRun mirror.
            GameCenter.shared.submit(score: game.totalPassages, for: .navigator)
            boardStandings = nil
            Task { boardStandings = try? await GameCenter.shared.loadStandings(for: .navigator) }
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
        .onDisappear(perform: leave)
    }

    // MARK: back button + exit flow

    private var backButton: some View {
        VStack {
            HStack {
                Button(action: requestExit) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(P.blossom.color)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(P.ink.color.opacity(0.55)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to picker")
                Spacer()
            }
            Spacer()
        }
        .padding(.leading, 20)
        // The scene ignores the safe area, so 8 pt here buried the button
        // under the status bar / Dynamic Island. 64 matches the how-to
        // button's row in chrome().
        .padding(.top, 64)
    }

    /// User tapped back. Coach mode → skip the tutorial (no penalty, no
    /// pause dialog — tutorial isn't a real run). Mid-passage → show
    /// confirmation with the penalty warning. Otherwise (idle run-start,
    /// run-over summary, celebration between passages) → exit cleanly.
    private func requestExit() {
        if coachActive {
            dismissCoach(withSuccess: false)
            performExit(penalize: false)
            return
        }
        if game.isMidPassage {
            showPauseDialog = true
        } else {
            performExit(penalize: false)
        }
    }

    private func performExit(penalize: Bool) {
        hasHandledExit = true
        if penalize {
            game.backOutOfRun()
            persist()
        }
        onExitRequested()
    }

    // MARK: scene signal

    /// In-run passage number drives the scene's depth (headland recedes,
    /// landfall island rises). Resets on every fresh run — the voyage is
    /// this run, not the persistent high-water mark.
    private var scenePhase: ProgressPhase {
        let currentID = game.level?.id ?? 0
        let thresholds = [8, 20, 46] // end-of-band cliffs (Band 1, 2, 4)
        let stage = thresholds.filter { currentID >= $0 }.count
        return ProgressPhase(
            stage: stage,
            depth: game.starsTotal > 0 ? Double(game.starsFound) / Double(game.starsTotal) : 0,
            tier: 0,
            beat: game.chartBeat
        )
    }

    // MARK: run-start screen

    private var runStartScreen: some View {
        VStack(spacing: 24) {
            Text("NAVIGATOR")
                .font(.custom("Futura-Bold", size: 30, relativeTo: .largeTitle))
                .tracking(5)
                .foregroundStyle(P.blossom.color)
                .padding(.top, 8)
            Text("MEMORY VOYAGE")
                .font(.custom("Futura-Medium", size: 12, relativeTo: .body))
                .tracking(3)
                .foregroundStyle(P.cream.color.opacity(0.8))

            Spacer().frame(height: 20)

            VStack(spacing: 10) {
                metricLine(label: "BEST PASSAGES", value: game.bestTotalPassages > 0 ? "\(game.bestTotalPassages)" : "—")
                metricLine(label: "LIFETIME STARS", value: "\(game.lifetimeStars)")
                metricLine(label: "RUNS", value: "\(game.runNumber)")
            }

            Spacer().frame(height: 24)

            Button(action: startRun) {
                Text("START RUN")
                    .font(.custom("Futura-Bold", size: 17, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(P.ink.color)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(P.torch.color))
            }
            .buttonStyle(SoftPressStyle())

            Button {
                howToOpen = true
            } label: {
                Text("HOW TO PLAY")
                    .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                    .tracking(1.8)
                    .foregroundStyle(P.blossom.color)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().stroke(P.blossom.color.opacity(0.55), lineWidth: 1.4))
            }
            .buttonStyle(SoftPressStyle())

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func metricLine(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                .tracking(1.8)
                .foregroundStyle(P.cream.color.opacity(0.7))
            Spacer()
            Text(value)
                .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(P.blossom.color)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .frame(maxWidth: 260)
        .background(Capsule().fill(P.ink.color.opacity(0.55)))
    }

    // MARK: chrome helpers

    /// Staging override for preview-video captures: env-var value in DEBUG
    /// builds when set, the live fallback otherwise. Knobs read through
    /// this: TIKI_NAVIGATOR_SKY_MS (watch-the-sky beat), _PEEK_MS (exposure
    /// per wave), _TAP_MS (autoplay tap cadence), _WIN_MS (autoplay dwell
    /// on win/run-over panels). Release builds always get the fallback.
    private func stagedMs(_ key: String, _ fallback: Int) -> Int {
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment[key], let ms = Int(raw) {
            return ms
        }
        #endif
        return fallback
    }

    /// Hide the back button + how-to button during preview-video captures
    /// so the frame is pure gameplay. Only takes effect in DEBUG builds
    /// with TIKI_NAVIGATOR_HIDE_CHROME=1 set.
    private var showTopChrome: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["TIKI_NAVIGATOR_HIDE_CHROME"] == "1" {
            return false
        }
        #endif
        return true
    }

    private var peekAvailable: Bool {
        game.phase == .input && game.peeksLeft > 0 && !repeekActive
    }

    /// Coach copy: verb by phase. "watch" during peek/pre-peek beat,
    /// "chart" during input. Two words each — pulses aren't needed since
    /// the whole board is the affordance.
    private var coachMessage: String {
        switch game.phase {
        case .input: return "TAP EVERY LIT CELL"
        default: return "WATCH THE STARS"
        }
    }

    // MARK: board

    @ViewBuilder
    private func board(_ size: CGSize) -> some View {
        let side = min(size.width - 48, 380)
        let gap: CGFloat = game.grid > 5 ? 6 : 8
        let cell = (side - gap * CGFloat(game.grid - 1)) / CGFloat(game.grid)
        VStack {
            Spacer()
            ZStack {
                VStack(spacing: gap) {
                    ForEach(0..<game.grid, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<game.grid, id: \.self) { col in
                                cellView(index: row * game.grid + col, size: cell)
                            }
                        }
                    }
                }
                if game.phase == .passageWon {
                    constellationLines(side: side, gap: gap, cell: cell)
                        .allowsHitTesting(false)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(P.ink.color.opacity(0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(P.driftwood.color.opacity(0.8), lineWidth: 3)
                    )
            )
            .overlay(alignment: .top) {
                peekBanner
                    .offset(y: -46)
            }
            Spacer()
            Spacer().frame(height: 90)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var peekBanner: some View {
        if watchTheSky {
            Text("WATCH THE SKY")
                .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                .tracking(2.5)
                .foregroundStyle(P.blossom.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(P.ink.color.opacity(0.7)))
                .transition(.opacity)
        } else if case .peek(let w) = game.phase, game.waveGroups.count > 1 {
            Text("WAVE \(w + 1) OF \(game.waveGroups.count)")
                .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.torch.color)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(P.ink.color.opacity(0.7)))
                .transition(.opacity)
        }
    }

    private enum CellState {
        case dark, lit, charted, cloud, missed, decoy
    }

    private func cellState(_ index: Int) -> CellState {
        switch game.phase {
        case .peek:
            if waveGap { return .dark }
            if game.litCells.contains(index) { return .lit }
            if decoyLit.contains(index) { return .decoy }
            return .dark
        case .input:
            if repeekActive && game.remainingStars.contains(index) { return .lit }
            if game.found.contains(index) { return .charted }
            if game.wrong.contains(index) { return .cloud }
            return .dark
        case .passageWon:
            if game.found.contains(index) { return .charted }
            return .dark
        case .runOver:
            if game.found.contains(index) { return .charted }
            if game.wrong.contains(index) { return .cloud }
            if game.remainingStars.contains(index) { return .missed }
            return .dark
        case .idle:
            return .dark
        }
    }

    @ViewBuilder
    private func cellView(index: Int, size: CGFloat) -> some View {
        let state = cellState(index)
        Button {
            handleTap(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.17)
                    .fill(P.deepLeaf.color)
                    .offset(y: size * 0.045)
                RoundedRectangle(cornerRadius: size * 0.17)
                    .fill(P.palmLeaf.color)
                switch state {
                case .dark:
                    EmptyView()
                case .lit, .charted:
                    Circle()
                        .fill(P.blossom.color.opacity(0.2))
                        .frame(width: size * 0.72, height: size * 0.72)
                    Circle()
                        .fill(P.blossom.color.opacity(0.45))
                        .frame(width: size * 0.46, height: size * 0.46)
                    StarShape()
                        .fill(P.blossom.color)
                        .frame(width: size * 0.56, height: size * 0.56)
                case .missed:
                    StarShape()
                        .stroke(P.torch.color.opacity(0.85), lineWidth: 1.6)
                        .frame(width: size * 0.52, height: size * 0.52)
                case .cloud:
                    Image.navigatorCloud
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.98, height: size * 0.98)
                case .decoy:
                    Image.navigatorDecoy
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.98, height: size * 0.98)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(state == .charted ? 1.0 : (state == .lit ? 1.03 : 1.0))
            // The charting pop is a within-passage beat, so it must never be
            // armed across a passage change. Cell identity is (row, column) —
            // a cell view survives into the next passage — and this modifier
            // sits below `.frame`, so it animates the cell's SIZE too. At a
            // band boundary (`cell` shrinks: passages 4, 7, 21, 37 and the
            // 60→1 loop) the cells whose `state == .charted` flips true→false
            // are exactly the passage just cleared: its whole constellation
            // would spring to the new size while every other tile snapped,
            // ghosting the old answer onto the fresh board as blank tiles that
            // visibly breathe. `.idle` is precisely the between-passages
            // phase, so leaving the animation nil there lets the resize snap.
            .animation(game.phase == .idle ? nil : .spring(duration: 0.30, bounce: 0.45),
                       value: state == .charted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sky row \(index / game.grid + 1) column \(index % game.grid + 1)")
        .accessibilityValue(accessibilityValue(for: state))
    }

    private func accessibilityValue(for state: CellState) -> String {
        switch state {
        case .dark: return "dark"
        case .lit: return "glowing star"
        case .charted: return "charted"
        case .cloud: return "cloud"
        case .missed: return "missed star"
        case .decoy: return "shooting star"
        }
    }

    private func constellationLines(side: CGFloat, gap: CGFloat, cell: CGFloat) -> some View {
        ConstellationTraceShape(pattern: game.pattern, grid: game.grid, gap: gap, cell: cell)
            .trim(from: 0, to: constellationTrace)
            .stroke(P.cream.color.opacity(0.55), lineWidth: 1.6)
            .frame(width: side, height: side)
            .onAppear {
                // Inserted at trim 0 (handleTap resets it on every win), then
                // traced star-to-star. Reduce Motion shows the finished lines.
                if reduceMotion {
                    constellationTrace = 1
                } else {
                    withAnimation(.easeInOut(duration: 0.7)) { constellationTrace = 1 }
                }
            }
    }

    // MARK: flow

    private func start() {
        guard !started else { return }
        started = true
        game.configureBest(store.bestScore(for: .navigator))
        let payload = game.restore(from: store.loadState(for: .navigator))
        seenHowTo = payload?.seenHowTo ?? false
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["TIKI_NAVIGATOR_LEVEL"],
           let id = Int(raw), let lvl = NavigatorLevels.level(id: id) {
            game.newLevel(lvl, attempt: 1)
        }
        // TIKI_NAVIGATOR_SKIP_COACH=1 marks the tutorial as seen for
        // preview-video captures — autoplay lands straight on run-start
        // and shows pure gameplay, no coach chrome.
        if ProcessInfo.processInfo.environment["TIKI_NAVIGATOR_SKIP_COACH"] == "1" {
            seenHowTo = true
        }
        #endif
        // First-run coach: no in-flight save AND player hasn't seen the
        // how-to AND they haven't opted out of tutorials bundle-wide →
        // seed the tutorial board and enter coach mode.
        if game.level == nil && !seenHowTo && !store.onboardingSkipped(for: .navigator) {
            coachActive = true
            game.seedTutorialBoard()
            persist()
            runPeek()
            startAutoplayIfNeeded()
            return
        }
        // Otherwise, resume any mid-flight passage (same star roll) or
        // sit on the run-start screen until the player taps START RUN.
        if game.level != nil {
            runPeek()
        }
        persist()
        startAutoplayIfNeeded()
    }

    /// View is being removed. Cancel live tasks. The back-button flow is
    /// the primary path for applying the penalty — `hasHandledExit` guards
    /// against double-applying it here. This branch only fires if the view
    /// unmounts through some path other than our button (edge case safety
    /// net; not expected in normal use).
    private func leave() {
        peekTask?.cancel()
        decoyTask?.cancel()
        autoplayTask?.cancel()
        winPanelTask?.cancel()
        if !hasHandledExit && game.isMidPassage {
            game.backOutOfRun()
            persist()
        }
    }

    /// Starts a fresh run from Passage 1.
    private func startRun() {
        if store.isOutOfLives(for: .navigator) {
            withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
            return
        }
        startRunAfterGate()
    }

    private func startRunAfterGate() {
        passageSummary = nil
        newBestFlash = false
        winPanelTask?.cancel()
        showWonPanel = false
        spendBreakIndex = nil
        playSpendBreak = false
        game.startNewRun()
        persist()
        runPeek()
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
        guard !store.livesExplained, !coachActive else { return }
        store.livesExplained = true
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { livesEducationActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(4200))
            withAnimation(.easeOut(duration: 0.4)) { livesEducationActive = false }
        }
    }

    /// Holds the won panel back so the constellation gets its moment — the
    /// trace draws (~0.7s), breathes, then the panel scales in over it.
    /// The phase guard covers exits during the hold; Reduce Motion skips
    /// the trace, so the hold shortens to a beat.
    private func scheduleWonPanel() {
        winPanelTask?.cancel()
        winPanelTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(stagedMs("TIKI_NAVIGATOR_PANEL_MS", reduceMotion ? 350 : 900)))
            guard !Task.isCancelled, game.phase == .passageWon else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) { showWonPanel = true }
        }
    }

    /// Auto-continues to the next passage after the player dismisses the
    /// passage-won panel.
    private func continueRun() {
        passageSummary = nil
        newBestFlash = false
        winPanelTask?.cancel()
        showWonPanel = false
        game.advanceAfterWin()
        persist()
        if game.phase == .runOver { return }
        runPeek()
    }

    private func dismissHowTo() {
        howToOpen = false
        markHowToSeen()
        if pendingPeek {
            pendingPeek = false
            runPeek()
        }
    }

    /// End the first-run coach. Success (player completed tutorial P1) →
    /// dismiss cue + ready banner. Skip → clear the tutorial state and
    /// route to the run-start screen. Either way, seenHowTo flips true so
    /// the coach doesn't refire.
    private func dismissCoach(withSuccess: Bool) {
        Analytics.progression(withSuccess ? .complete : .fail, "coach", "navigator")
        guard coachActive else { return }
        withAnimation(.easeOut(duration: 0.3)) { coachActive = false }
        seenHowTo = true
        if withSuccess {
            CoachSkin.navigator.dismissSound.play()
            readyBannerActive = true
        } else {
            game.abandonLevel()
        }
        persist()
    }

    private func dismissReadyBanner() {
        readyBannerActive = false
        // Clear the tutorial passage so the body lands on run-start,
        // where the player taps START RUN to begin their real run 1.
        game.abandonLevel()
        persist()
    }

    /// The view-owned peek clock: an anticipation beat first (WATCH THE
    /// SKY — nothing races the run-start fade, the how-to, or cold-start
    /// jank), then waves show for `peekMs` each with a dark beat between
    /// strokes, decoys flash inside the first wave, and the clouds close.
    private func runPeek() {
        guard game.level != nil else { return }
        guard !howToOpen else {
            pendingPeek = true
            return
        }
        peekTask?.cancel()
        decoyTask?.cancel()
        decoyLit = []
        waveGap = false
        withAnimation(.easeInOut(duration: 0.2)) { watchTheSky = true }
        peekTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(stagedMs("TIKI_NAVIGATOR_SKY_MS", 850)))
            guard !Task.isCancelled, let lvl = game.level else { return }
            withAnimation(.easeInOut(duration: 0.2)) { watchTheSky = false }
            game.beginPeek()
            TikiSound.shared.tick()
            scheduleDecoys(lvl)
            while case .peek = game.phase {
                try? await Task.sleep(for: .milliseconds(stagedMs("TIKI_NAVIGATOR_PEEK_MS", game.currentPeekMs)))
                guard !Task.isCancelled else { return }
                if case .peek(let w) = game.phase, w + 1 < game.waveGroups.count {
                    waveGap = true
                    try? await Task.sleep(for: .milliseconds(380))
                    waveGap = false
                    guard !Task.isCancelled else { return }
                }
                if !game.advanceWave() {
                    persist()
                    break
                }
                TikiSound.shared.tick()
            }
        }
    }

    private func scheduleDecoys(_ lvl: NavigatorLevel) {
        guard !game.decoyCells.isEmpty else { return }
        let cells: [Int] = game.decoyCells
        let peekMs: Double = Double(game.currentPeekMs)
        decoyTask = Task { @MainActor in
            let n: Double = Double(cells.count)
            var elapsed: Int = 0
            for (i, cell) in cells.enumerated() {
                let fraction: Double = 0.20 + 0.55 * Double(i) / max(1.0, n)
                let at: Int = Int(peekMs * fraction)
                let wait: Int = max(0, at - elapsed)
                try? await Task.sleep(for: .milliseconds(wait))
                elapsed = at
                guard !Task.isCancelled, case .peek = game.phase else { return }
                decoyLit.insert(cell)
                TikiSound.shared.tick()
                try? await Task.sleep(for: .milliseconds(550))
                elapsed += 550
                decoyLit.remove(cell)
            }
        }
    }

    private func doPeek() {
        guard !repeekActive, game.usePeek() else { return }
        guard let lvl = game.level else { return }
        repeekActive = true
        TikiSound.shared.tick()
        persist()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(Double(game.currentPeekMs) * 0.6)))
            repeekActive = false
        }
    }

    private func handleTap(_ index: Int) {
        guard !repeekActive else { return }
        let priorBest = game.bestPassage
        let result = game.tap(index)
        switch result {
        case .star:
            starHaptic.impactOccurred()
            TikiSound.shared.pop()
            persist()
        case .miss:
            missHaptic.notificationOccurred(.warning)
            TikiSound.shared.mistake()
            persist()
        case .passageWon:
            winHaptic.notificationOccurred(.success)
            TikiSound.shared.win()
            constellationTrace = 0
            if coachActive {
                // Tutorial completion — engine already skipped stat
                // updates. Hold the celebration briefly, then hand off
                // to the ready banner and the real run flow.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(900))
                    dismissCoach(withSuccess: true)
                }
            } else {
                // Passage scores feed the wallet through the shared divisor
                // (PlayerStore.navigatorEarnScore) — the price ladder is
                // calibrated to it, so it lives there, tested, not inline.
                passageSummary = store.recordRun(
                    game: .navigator, score: game.levelScore,
                    earnScore: PlayerStore.navigatorEarnScore(game.levelScore))
                Analytics.runEnded(.navigator, level: Analytics.passage(game.totalPassages),
                                   won: true, score: game.levelScore,
                                   tutorial: coachActive)
                newBestFlash = game.bestPassage > priorBest
                scheduleWonPanel()
            }
            persist()
        case .runOver:
            missHaptic.notificationOccurred(.error)
            TikiSound.shared.gameOver()
            // True voyage end — not the per-passage recordRun at
            // passageWon. Coach boards leave the lives pool alone.
            // The voyage end never reaches recordRun (only passage-wins do),
            // so the losing attempt is recorded here or nowhere (§3.2).
            Analytics.runEnded(.navigator, level: Analytics.passage(game.totalPassages),
                               won: false, score: game.levelScore, tutorial: coachActive)
            if store.spendLifeForDefeat(game: .navigator, duringTutorial: coachActive) {
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
            // On run-over, best-passage was updated at the last win — flag
            // the summary if THIS run set a new best.
            newBestFlash = game.bestPassage > priorBest
            persist()
        case .duplicate, .ignored:
            break
        }
    }

    private func persist() {
        store.saveState(for: .navigator, payload: game.payload(seenHowTo: seenHowTo))
    }

    private func markHowToSeen() {
        seenHowTo = true
        persist()
    }

    // MARK: autoplay (capture + verification bot — perfect recall)

    private func startAutoplayIfNeeded() {
        #if DEBUG
        guard ProcessInfo.processInfo.environment["TIKI_AUTOPLAY"] == "1" else { return }
        autoplayTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(stagedMs("TIKI_NAVIGATOR_TAP_MS", 400)))
                if howToOpen {
                    dismissHowTo()
                }
                if readyBannerActive {
                    dismissReadyBanner()
                    continue
                }
                switch game.phase {
                case .idle:
                    // level==nil → truly no run in flight, kick off a new
                    // one. level!=nil → transient loading state between
                    // newLevel and beginPeek; leave it alone so runPeek
                    // finishes its 850ms watch-the-sky beat.
                    if game.level == nil { startRun() }
                case .input:
                    if ProcessInfo.processInfo.environment["TIKI_NAVIGATOR_LOSE"] == "1" {
                        let bad = (0..<game.cellCount).first {
                            !game.pattern.contains($0) && !game.wrong.contains($0) && !game.found.contains($0)
                        }
                        if !repeekActive, let cell = bad { handleTap(cell) }
                    } else if !repeekActive, let target = game.remainingStars.sorted().first {
                        handleTap(target)
                    }
                case .passageWon:
                    try? await Task.sleep(for: .milliseconds(stagedMs("TIKI_NAVIGATOR_WIN_MS", 900)))
                    continueRun()
                case .runOver:
                    try? await Task.sleep(for: .milliseconds(stagedMs("TIKI_NAVIGATOR_WIN_MS", 900)))
                    startRun()
                case .peek:
                    break
                }
            }
        }
        #endif
    }
}

// MARK: - Constellation trace

/// Connect-the-stars path through the pattern's cell centers, in pattern
/// order — `.trim` animates it drawing star-to-star on passage win.
private struct ConstellationTraceShape: Shape {
    let pattern: [Int]
    let grid: Int
    let gap: CGFloat
    let cell: CGFloat

    func path(in rect: CGRect) -> Path {
        guard pattern.count > 1 else { return Path() }
        func center(_ index: Int) -> CGPoint {
            let row = index / grid, col = index % grid
            return CGPoint(
                x: CGFloat(col) * (cell + gap) + cell / 2,
                y: CGFloat(row) * (cell + gap) + cell / 2
            )
        }
        var p = Path()
        p.move(to: center(pattern[0]))
        for cellIndex in pattern.dropFirst() {
            p.addLine(to: center(cellIndex))
        }
        return p
    }
}

// MARK: - Star shape

/// Four-point star matching the Stage 2 sprite geometry.
struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w * 0.605, y: h * 0.395))
        p.addLine(to: CGPoint(x: w, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.605, y: h * 0.605))
        p.addLine(to: CGPoint(x: w * 0.5, y: h))
        p.addLine(to: CGPoint(x: w * 0.395, y: h * 0.605))
        p.addLine(to: CGPoint(x: 0, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.395, y: h * 0.395))
        p.closeSubpath()
        return p
    }
}

#Preview {
    NavigatorView()
        .environment(PlayerStore(inMemory: true))
}
