import SwiftUI
import UIKit

/// Tiki Stacks: the block puzzle, played over the animated lagoon.
/// Drag pieces from the tray onto the 8x8 board; full rows and columns clear.
struct TikiStacksView: View {
    @Environment(PlayerStore.self) private var store
    var onExitRequested: () -> Void = { }
    @State private var game = TikiStacksGame()
    @State private var dragSlot: Int?
    @State private var dragLocation: CGPoint = .zero
    /// The board's playable field, in the shared "game" coordinate space.
    @State private var boardInner: CGRect = .zero
    @State private var started = false
    @State private var autoplayStarted = false
    @State private var boardShake: CGFloat = 0
    @State private var maskPulse: CGFloat = 1
    @State private var howToOpen = false
    @State private var seenHowTo = true
    @State private var dangerGlow = false
    @State private var scoreReactArmed = false
    /// First-run coach — dismissed after four scripted line clears.
    @State private var coachActive = false
    @State private var tutorialRound: Int = 0
    /// Fires after a successful tutorial dismiss so the transition from
    /// coach → real play is unmistakable (SKIP dismisses silently).
    @State private var readyBannerActive = false
    /// Depth-milestone bookkeeping: bits already checked this run, mints that
    /// were new this run (drives the game-over toast), and whether GLOW TIDE's
    /// permanent lantern strand has ever been earned.
    @State private var checkedBits: Set<Int> = []
    @State private var mintedThisRun = 0
    @State private var lanternEarned = false
    /// The Totem Pole (Game Center leaderboard) overlay + the payoff bar's
    /// rank teaser, fetched once per game over.
    @State private var leaderboardOpen = false
    @State private var totemStandings: GameCenter.Standings?
    /// Death beat: the panel holds ~1.4 s after the run ends so the player
    /// sees WHY — the stuck tray pieces grey out and shake under the
    /// engine's NO ROOM LEFT callout — before the scrim covers the board.
    @State private var panelShown = false
    @State private var trayShake: CGFloat = 0
    /// One-shot lose-rule tip at the first dangerous fill of a real run.
    @State private var dangerTipActive = false
    @State private var seenDangerTip = true
    /// Shared out-of-lives sheet — PLAY AGAIN at 0 lives.
    @State private var outOfLivesOpen = false
    /// Defeat spend beat — armed once per death; cleared after ~0.6s so
    /// panel re-renders never replay the drain.
    @State private var spendBreakIndex: Int? = nil
    @State private var playSpendBreak = false
    /// First-ever spend education toast (one-shot via store.livesExplained).
    @State private var livesEducationActive = false
    private let placeHaptic = UIImpactFeedbackGenerator(style: .light)
    private let clearHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        GeometryReader { geo in
            let W: CGFloat = geo.size.width
            ZStack {
                TikiBackgroundView(phase: scenePhase)
                    .accessibilityHidden(true)
                VStack(spacing: 16) {
                    TotemChrome(
                        game: game,
                        coachActive: coachActive,
                        maskPulse: maskPulse,
                        W: W,
                        onHowTo: { howToOpen = true }
                    )
                    board(W)
                    trayView(W)
                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                dragOverlay
                if panelShown {
                    TotemGameOverPanel(
                        W: W,
                        score: game.score,
                        best: game.best,
                        previousBest: game.previousBest,
                        isNewBest: game.isNewBest,
                        summary: game.lastRunSummary,
                        canAffordNewItem: store.canAffordNewItem,
                        mintedThisRun: mintedThisRun,
                        boardRank: totemStandings?.local?.rank,
                        spendBreakIndex: spendBreakIndex,
                        playSpendBreak: playSpendBreak,
                        onExit: onExitRequested,
                        onPlayAgain: {
                            if store.isOutOfLives(for: .tikiStacks) {
                                withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
                                return
                            }
                            restartAfterGate()
                        },
                        onOpenLeaderboard: {
                            withAnimation(.spring(duration: 0.3, bounce: 0.25)) { leaderboardOpen = true }
                        }
                    )
                        .transition(.opacity)
                }
                if dangerTipActive {
                    MilestoneToast(message: "WHEN NO PIECE FITS, THE RUN ENDS", fontSize: 13)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, W * 0.24)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                if coachActive, !game.isGameOver {
                    CoachCard(
                        message: coachMessage,
                        skin: .stacks,
                        onSkip: { dismissCoach(withSuccess: false) },
                        // ⚠ This inset is measured from BELOW the safe area,
                        // not the screen top. Totem has the tightest slot of
                        // the three: the back chevron's tap target ends at 52
                        // and the coach card hangs at ~118, so SKIP threads
                        // between them. The default 56 left only 4pt of air
                        // under the chevron — their tap targets overlapped by
                        // 8pt, which is the mis-tap Carson hit.
                        skipTopPadding: 80
                    )
                }
                if readyBannerActive {
                    TutorialReadyBanner(message: "READY TO STACK", skin: .stacks) {
                        readyBannerActive = false
                    }
                }
                if howToOpen {
                    HowToPlayPanel(title: "HOW TO STACK", rules: [
                        HowToRule(symbol: "hand.draw.fill", text: "Drag pieces from the tray onto the board."),
                        HowToRule(image: BlockColor.coral.image, text: "Fill a whole row or column to clear it."),
                        HowToRule(symbol: "sparkles", text: "Back-to-back clears build a combo streak."),
                        HowToRule(symbol: "square.grid.3x3.fill", text: "The run ends when no tray piece fits."),
                    ]) {
                        howToOpen = false
                        markHowToSeen()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
                if livesEducationActive {
                    MilestoneToast(
                        message: "USED A LIFE · 5 HEARTS · +1 EVERY 30 MIN",
                        fontSize: 12
                    )
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, W * 0.22)
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
                            restartAfterGate()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
                if leaderboardOpen {
                    LeaderboardView(theme: .totem) {
                        withAnimation(.easeOut(duration: 0.25)) { leaderboardOpen = false }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .coordinateSpace(name: "game")
            .animation(.spring(duration: 0.3, bounce: 0.25), value: howToOpen)
            .onAppear(perform: start)
            .onAppear { Analytics.entered("totem") }
            .onChange(of: coachActive) { _, active in
                // The FTUE is its own progression family — the one
                // place a tutorial SHOULD be counted (D-6).
                if active { Analytics.progression(.start, "coach", "tikiStacks") }
            }
            .onDisappear {
                Analytics.exited("totem", runInProgress: game.isGameOver ? nil : .tikiStacks)
            }
            .onChange(of: game.score) {
                reactToScoring()
                checkMilestones()
                checkDangerTip()
                GameCenter.shared.submitLive(score: game.score, for: .tikiStacks)
            }
            .onChange(of: game.isGameOver) { _, over in
                guard over else {
                    panelShown = false
                    return
                }
                // Death beat: shake the stuck pieces now, hold the panel
                // until the NO ROOM LEFT callout has had its moment.
                trayShake = 8
                withAnimation(.spring(duration: 0.45, bounce: 0.6)) { trayShake = 0 }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1400))
                    guard game.isGameOver else { return }
                    withAnimation(.easeOut(duration: 0.35)) { panelShown = true }
                }
                totemStandings = nil
                Task { totemStandings = try? await GameCenter.shared.loadStandings(for: .tikiStacks) }
            }
            // Spend beat + education toast — armed on the spend EVENT
            // counter (onGameOver is an escaping engine hook that can't
            // mutate view @State, and the lives VALUE can revisit the same
            // number inside one spend when a pending refill materializes
            // first — a same-value change never fires onChange).
            .onChange(of: store.livesSpendCount) { _, _ in
                guard game.isGameOver else { return }
                armSpendBreak(after: store.lives)
                offerLivesEducationIfNeeded()
                // Last life just went: ask once, after the panel lands.
                Task {
                    await LivesRestockNotifier.shared.offerAuthorizationAfterDefeat(
                        lives: store.lives, duringTutorial: coachActive
                    )
                }
            }
        }
    }

    /// Lagoon depth ladder: DUSK 150 / NIGHTFALL 400 / MOONRISE 800 / GLOW TIDE 1500.
    private var scenePhase: ProgressPhase {
        ProgressPhase(
            stage: game.stage,
            depth: min(1, Double(game.score) / Double(TikiStacksGame.depthThresholds[3])),
            tier: lanternEarned ? 1 : 0,
            beat: game.clearBeat
        )
    }

    // MARK: lifecycle

    private func start() {
        guard !started else { return }
        started = true
        game.configureBest(store.bestScore(for: .tikiStacks))
        let payload = game.restore(from: store.loadState(for: .tikiStacks))
        // Only a fresh board is a new run. A restored one already had its
        // start counted on the visit that began it, and double-counting
        // would break the progression funnel's start:fail ratio.
        if game.score == 0, !game.isGameOver {
            Analytics.runStarted(.tikiStacks, level: "run", tutorial: coachActive)
        }
        seenHowTo = payload?.seenHowTo ?? false
        seenDangerTip = payload?.seenDangerTip ?? false
        lanternEarned = store.record(for: .tikiStacks).milestoneMask & (1 << 3) != 0
        #if DEBUG
        // Staging hook (SIMCTL_CHILD_TIKI_STACKS_SCORE=<n>): seeds the run's
        // score so every lagoon depth state can be screenshotted on demand.
        if let raw = ProcessInfo.processInfo.environment["TIKI_STACKS_SCORE"], let n = Int(raw) {
            game.score = n
            game.debugRedealTray()
            seenHowTo = true
        }
        // Staging hook (SIMCTL_CHILD_TIKI_STACKS_SWEEP=1): board full except
        // one cell + a single dot in the tray, so the TIKI_AUTOPLAY driver's
        // next placement forces a clean sweep (pair with TIKI_STACKS_SCORE to
        // stage a Moonlit Sweep at NIGHTFALL+).
        if ProcessInfo.processInfo.environment["TIKI_STACKS_SWEEP"] == "1" {
            game.debugSeedSweepBoard()
            seenHowTo = true
        }
        // Executable proof for placement forgiveness (TIKI_STACKS_SNAPTEST=1).
        if ProcessInfo.processInfo.environment["TIKI_STACKS_SNAPTEST"] == "1" {
            TikiStacksGame.debugValidateSnapping()
        }
        // Greedy-bot score distributions (TIKI_STACKS_BOT=<runs>) — read via
        // `simctl launch --console-pty`.
        if let raw = ProcessInfo.processInfo.environment["TIKI_STACKS_BOT"], let n = Int(raw) {
            TikiStacksGame.debugBotBatch(runs: n)
        }
        // Staging hook (TIKI_STACKS_HOWTO=1): opens the HOW TO STACK panel,
        // which has no headless path (it only opens from a button tap).
        if ProcessInfo.processInfo.environment["TIKI_STACKS_HOWTO"] == "1" {
            howToOpen = true
        }
        // Staging hook (TIKI_LB=1): opens the Totem Pole overlay; pair with
        // TIKI_LB_MOCK=1|empty|offline|unauth|big[:rank] to stage each state.
        if ProcessInfo.processInfo.environment["TIKI_LB"] == "1" {
            seenHowTo = true
            GameCenter.shared.authenticate()
            leaderboardOpen = true
        }
        // Dev hook (TIKI_STACKS_TUTORIAL_AUTOPLAY=1): drops each scripted
        // round's piece on its target through the same path the drag gesture
        // uses, so the coach plays itself out for verification (mirrors the
        // Luau/Cipher/Blueprints tutorial-autoplay hooks).
        if ProcessInfo.processInfo.environment["TIKI_STACKS_TUTORIAL_AUTOPLAY"] == "1" {
            Task { @MainActor in
                while coachActive {
                    try? await Task.sleep(for: .milliseconds(1300))
                    guard coachActive else { break }
                    let target = TikiStacksGame.tutorialTarget(round: tutorialRound)
                    let before = game.clearFlash.count
                    let round = tutorialRound
                    guard game.place(slot: 0, at: GridPos(row: target.row, col: target.col)) else {
                        continue
                    }
                    let didClear = game.clearFlash.count > before || !game.clearFlash.isEmpty
                    print("[coach] stacks round=\(round) score=\(game.score) didClear=\(didClear)")
                    handleTutorialPlacement(didClear: didClear)
                    persist()
                }
                print("[coach] stacks done score=\(game.score) mask=\(store.record(for: .tikiStacks).milestoneMask) wallet=\(store.points)")
            }
        }
        #endif
        if !seenHowTo, !store.onboardingSkipped(for: .tikiStacks) {
            // First run: four scripted near-completion layouts. Even if the
            // player quit mid-tutorial we always restart from round 0 — a
            // partial-tutorial resume is fragile and rare enough to overwrite.
            tutorialRound = 0
            game.seedTutorialBoard(round: 0)
            coachActive = true
        }
        game.onGameOver = { [weak game] score in
            TikiSound.shared.gameOver()
            // Stack death spends a life; the coach's scripted boards never
            // own a real run (tutorialActive), so they leave the pool alone.
            // UI beat (break / education toast) arms via onChange(of: store.lives)
            // — this escaping hook can't mutate view @State.
            let duringTutorial = game?.tutorialActive == true
            if store.spendLifeForDefeat(game: .tikiStacks, duringTutorial: duringTutorial) {
                AccessibilityNotification.Announcement(
                    "Life spent — \(store.lives) of \(PlayerStore.livesCap) left"
                ).post()
            }
            game?.lastRunSummary = store.recordRun(game: .tikiStacks, score: score)
            // Endless: a stack death is the only ending, so `won` is always
            // false and the score distribution is what carries the signal.
            Analytics.runEnded(.tikiStacks, level: "run", won: false,
                               score: score, tutorial: duringTutorial)
        }
        persist()
        checkMilestones()
        startAutoplayIfRequested()
        // Arm score SFX after this update cycle so restoring a saved score
        // doesn't pop on entry.
        Task { @MainActor in scoreReactArmed = true }
    }

    /// Records depth-state milestones the first time the score crosses each
    /// threshold in a run. `recordMilestone` mints +75 exactly once, ever;
    /// `checkedBits` just keeps re-checks cheap within the run.
    private func checkMilestones() {
        for (bit, threshold) in TikiStacksGame.depthThresholds.enumerated()
        where game.score >= threshold && !checkedBits.contains(bit) {
            checkedBits.insert(bit)
            if store.recordMilestone(game: .tikiStacks, bit: bit) {
                mintedThisRun += 1
                if bit == 3 { lanternEarned = true }
            }
        }
    }

    private func persist() {
        store.saveState(
            for: .tikiStacks,
            payload: game.payload(seenHowTo: seenHowTo, seenDangerTip: seenDangerTip)
        )
    }

    /// The only surface that states the lose rule BEFORE the first death:
    /// a one-shot toast the first time a real run's board runs dangerously
    /// full (same threshold as the breathing rim).
    private func checkDangerTip() {
        guard !seenDangerTip, !coachActive, !game.tutorialActive, !game.isGameOver,
              game.fillRatio >= 0.72 else { return }
        seenDangerTip = true
        persist()
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { dangerTipActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(3800))
            withAnimation(.easeOut(duration: 0.4)) { dangerTipActive = false }
        }
    }

    private func markHowToSeen() {
        seenHowTo = true
        persist()
    }

    /// Arms the panel's one-shot drain beat for heart index `after`
    /// (the first empty slot post-spend). Cleared after ~0.6s so re-renders
    /// never replay it.
    private func armSpendBreak(after: Int) {
        spendBreakIndex = after
        playSpendBreak = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            playSpendBreak = false
        }
    }

    /// One-shot education toast. Defers when the danger tip already owns
    /// the moment (flag stays false so the next defeat can try).
    private func offerLivesEducationIfNeeded() {
        guard !store.livesExplained, !coachActive, !dangerTipActive else { return }
        store.livesExplained = true
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { livesEducationActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(4200))
            withAnimation(.easeOut(duration: 0.4)) { livesEducationActive = false }
        }
    }

    private func restartAfterGate() {
        withAnimation(.spring(duration: 0.35, bounce: 0.25)) { game.restart() }
        Analytics.runStarted(.tikiStacks, level: "run", tutorial: coachActive)
        checkedBits = []
        mintedThisRun = 0
        spendBreakIndex = nil
        playSpendBreak = false
        persist()
    }

    private func dismissCoach(withSuccess: Bool) {
        Analytics.progression(withSuccess ? .complete : .fail, "coach", "tikiStacks")
        guard coachActive else { return }
        withAnimation(.easeOut(duration: 0.3)) { coachActive = false }
        // Tutorial hands the tray back to the shuffled bag so real play starts
        // with three real pieces, not a leftover coral dot.
        game.endTutorialAndRefill()
        if withSuccess {
            CoachSkin.stacks.dismissSound.play()
            readyBannerActive = true
        } else {
            store.setOnboardingSkipped(true, for: .tikiStacks)
        }
        seenHowTo = true
        persist()
    }

    /// Called after a successful `place()` while the coach is up.
    /// Cleared → advance a round (or dismiss on the final round).
    /// Missed → reset the current round so the pulsed target stays valid.
    private func handleTutorialPlacement(didClear: Bool) {
        if !didClear {
            game.seedTutorialBoard(round: tutorialRound)
            return
        }
        let next = tutorialRound + 1
        if next >= TikiStacksGame.tutorialRoundCount {
            dismissCoach(withSuccess: true)
            return
        }
        // Immediately swap in the NEXT round's piece so the tray never flashes
        // empty during the clear-burst window; reseed the board once the burst
        // has had a beat to read.
        game.refillTutorialTray(for: next)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(520))
            tutorialRound = next
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                game.seedTutorialBoard(round: next)
            }
            persist()
        }
    }

    /// Shake the board on multi-line clears; pulse the mask on any clear.
    private func reactToScoring() {
        guard scoreReactArmed else { return }
        TikiSound.shared.pop()
        guard game.lastClearCount > 0 else { return }
        TikiSound.shared.clear(intensity: game.streak)
        maskPulse = 1.28
        withAnimation(.spring(duration: 0.45, bounce: 0.55)) { maskPulse = 1 }
        if game.lastClearCount >= 2 {
            boardShake = 7
            withAnimation(.spring(duration: 0.35, bounce: 0.65)) { boardShake = 0 }
        }
    }

    /// Debug hook: TIKI_AUTOPLAY=1 greedily places pieces so the full
    /// model-to-render pipeline can be verified without touch input.
    private func startAutoplayIfRequested() {
        guard ProcessInfo.processInfo.environment["TIKI_AUTOPLAY"] == "1", !autoplayStarted else { return }
        autoplayStarted = true
        howToOpen = false
        coachActive = false
        seenHowTo = true
        Task { @MainActor in
            @MainActor func placeFirstFit(_ slot: Int) -> Bool {
                guard let piece = game.tray[slot] else { return false }
                for r in 0..<TikiStacksGame.size {
                    for k in 0..<TikiStacksGame.size {
                        let origin = GridPos(row: r, col: k)
                        if game.canPlace(piece, at: origin) {
                            game.place(slot: slot, at: origin)
                            persist()
                            return true
                        }
                    }
                }
                return false
            }
            while !game.isGameOver {
                try? await Task.sleep(nanoseconds: 500_000_000)
                var placed = false
                for slot in 0..<3 where !placed {
                    placed = placeFirstFit(slot)
                }
                if !placed { break }
            }
            print("[autoplay] stacks over score=\(game.score) stage=\(game.stage)")
        }
    }

    // MARK: board

    private func board(_ W: CGFloat) -> some View {
        let bw: CGFloat = W * 0.94
        return Image.boardFrame
            .resizable()
            .frame(width: bw, height: bw)
            .mask(BoardFrameHole().fill(style: FillStyle(eoFill: true)))
            .offset(x: boardShake)
            .overlay(
                GeometryReader { g in
                    let inner = CGRect(
                        x: g.size.width * 40 / 560,
                        y: g.size.height * 38 / 560,
                        width: g.size.width * 480 / 560,
                        height: g.size.height * 480 / 560
                    )
                    let cell: CGFloat = inner.width / CGFloat(TikiStacksGame.size)
                    ZStack(alignment: .topLeading) {
                        // translucent field drawn natively — SVG fill-opacity is
                        // ignored by Xcode's importer, so glass lives here
                        RoundedRectangle(cornerRadius: inner.width * 14 / 480)
                            .fill(Color(red: 0.918, green: 0.878, blue: 0.784).opacity(0.58))
                            .frame(width: inner.width, height: inner.height)
                            .position(x: inner.midX, y: inner.midY)
                        gridCells(inner: inner, cell: cell)
                        ghostCells(inner: inner, cell: cell)
                        flashCells(inner: inner, cell: cell)
                        popupLayer(inner: inner, cell: cell)
                        dangerRim(inner: inner)
                        coachCellPulse(inner: inner, cell: cell)
                        Color.clear
                            .onAppear { updateBoardInner(g) }
                            .onChange(of: g.size) { updateBoardInner(g) }
                    }
                }
            )
    }

    private func updateBoardInner(_ g: GeometryProxy) {
        let f = g.frame(in: .named("game"))
        boardInner = CGRect(
            x: f.minX + f.width * 40 / 560,
            y: f.minY + f.height * 38 / 560,
            width: f.width * 480 / 560,
            height: f.height * 480 / 560
        )
    }

    private func gridCells(inner: CGRect, cell: CGFloat) -> some View {
        ForEach(0..<TikiStacksGame.size, id: \.self) { r in
            ForEach(0..<TikiStacksGame.size, id: \.self) { k in
                ZStack {
                    RoundedRectangle(cornerRadius: cell * 0.09)
                        .fill(Color(red: 0.918, green: 0.878, blue: 0.784).opacity(0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: cell * 0.09)
                                .stroke(
                                    Color(red: 0.788, green: 0.718, blue: 0.561).opacity(0.68),
                                    lineWidth: 1.5
                                )
                        )
                        .frame(width: cell - 2, height: cell - 2)
                    if let color = game.grid[r][k] {
                        color.image
                            .resizable()
                            .frame(width: cell - 2, height: cell - 2)
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 1.3).combined(with: .opacity),
                                    removal: .scale(scale: 0.05).combined(with: .opacity)
                                )
                            )
                        if game.fireflyCells.contains(GridPos(row: r, col: k)) {
                            FireflyDot(size: cell * 0.26)
                        }
                    }
                }
                .position(
                    x: inner.minX + (CGFloat(k) + 0.5) * cell,
                    y: inner.minY + (CGFloat(r) + 0.5) * cell
                )
            }
        }
        .animation(.spring(duration: 0.30, bounce: 0.35), value: game.grid)
    }

    @ViewBuilder
    private func ghostCells(inner: CGRect, cell: CGFloat) -> some View {
        if let origin = ghostOrigin, let slot = dragSlot, let piece = game.tray[slot] {
            ForEach(piece.cells, id: \.self) { c in
                RoundedRectangle(cornerRadius: cell * 0.12)
                    .fill(P.blossom.color.opacity(0.40))
                    .frame(width: cell - 4, height: cell - 4)
                    .position(
                        x: inner.minX + (CGFloat(origin.col + c.col) + 0.5) * cell,
                        y: inner.minY + (CGFloat(origin.row + c.row) + 0.5) * cell
                    )
            }
        }
    }

    private func flashCells(inner: CGRect, cell: CGFloat) -> some View {
        ForEach(game.clearFlash, id: \.self) { p in
            let dr = Double(p.row - game.clearCentroid.row)
            let dc = Double(p.col - game.clearCentroid.col)
            let dist = (dr * dr + dc * dc).squareRoot()
            BurstView(delay: dist * 0.045)
                .frame(width: cell * 1.5, height: cell * 1.5)
                .position(
                    x: inner.minX + (CGFloat(p.col) + 0.5) * cell,
                    y: inner.minY + (CGFloat(p.row) + 0.5) * cell
                )
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func coachCellPulse(inner: CGRect, cell: CGFloat) -> some View {
        if coachActive, !game.isGameOver {
            let round = TikiStacksGame.tutorialRounds[
                max(0, min(tutorialRound, TikiStacksGame.tutorialRoundCount - 1))
            ]
            let origin = round.dropOrigin
            let shape = PieceLibrary.shapes[round.trayShapeIndex]

            // For multi-cell pieces, dashed torch-gold outlines telegraph the
            // landing footprint BEFORE pickup — the pulse alone marks only the
            // top-left cell and would understate a vertical 4-piece's span.
            // Hidden during drag: the game's own blossom ghost preview takes
            // over then.
            if shape.count > 1, dragSlot == nil {
                ForEach(0..<shape.count, id: \.self) { i in
                    let (dr, dc) = shape[i]
                    RoundedRectangle(cornerRadius: cell * 0.12)
                        .stroke(
                            P.torch.color.opacity(0.55),
                            style: StrokeStyle(lineWidth: 2, dash: [3.5, 2.5])
                        )
                        .frame(width: cell - 6, height: cell - 6)
                        .position(
                            x: inner.minX + (CGFloat(origin.col + dc) + 0.5) * cell,
                            y: inner.minY + (CGFloat(origin.row + dr) + 0.5) * cell
                        )
                        .allowsHitTesting(false)
                }
            }

            CoachPulse(skin: .stacks, diameter: cell * 1.1)
                .position(
                    x: inner.minX + (CGFloat(origin.col) + 0.5) * cell,
                    y: inner.minY + (CGFloat(origin.row) + 0.5) * cell
                )
            CoachArrow(skin: .stacks, direction: .down, size: 22)
                .position(
                    x: inner.minX + (CGFloat(origin.col) + 0.5) * cell,
                    y: inner.minY + (CGFloat(origin.row) + 0.5) * cell - cell * 0.9
                )
        }
    }

    /// Escalating multi-line copy — the mechanic being taught is that a single
    /// drop can clear many lines at once. Round 1 baselines the fill-a-line
    /// concept; rounds 2–4 add "AT ONCE" so the player names what's happening.
    private var coachMessage: String {
        switch tutorialRound {
        case 0: return "FILL THE LINE"
        case 1: return "TWO AT ONCE"
        case 2: return "THREE AT ONCE"
        default: return "FOUR AT ONCE!"
        }
    }

    /// Breathing coral rim when the board runs dangerously full — the
    /// about-to-lose state should be felt before it arrives.
    @ViewBuilder
    private func dangerRim(inner: CGRect) -> some View {
        if game.fillRatio >= 0.72, !game.isGameOver {
            RoundedRectangle(cornerRadius: inner.width * 14 / 480)
                .stroke(P.coral.color.opacity(dangerGlow ? 0.60 : 0.12), lineWidth: 4)
                .frame(width: inner.width, height: inner.height)
                .position(x: inner.midX, y: inner.midY)
                .allowsHitTesting(false)
                .transition(.opacity)
                .onAppear {
                    dangerGlow = false
                    withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                        dangerGlow = true
                    }
                }
        }
    }

    private func popupLayer(inner: CGRect, cell: CGFloat) -> some View {
        ForEach(game.popups) { popup in
            PopupText(text: popup.text, tier: popup.tier)
                .position(popupPosition(popup, inner: inner, cell: cell))
                .allowsHitTesting(false)
        }
    }

    private func popupPosition(_ popup: ScorePopup, inner: CGRect, cell: CGFloat) -> CGPoint {
        if popup.tier >= 3 {
            return CGPoint(x: inner.midX, y: inner.minY + inner.height * 0.36)
        }
        if popup.tier > 0 {
            return CGPoint(x: inner.midX, y: inner.minY + inner.height * 0.20)
        }
        return CGPoint(
            x: inner.minX + CGFloat(popup.col + 0.5) * cell,
            y: inner.minY + CGFloat(popup.row + 0.5) * cell
        )
    }

    /// Where the dragged piece would land. Forgiving (Block Blast-style):
    /// the model snaps to the nearest legal origin within snapRadius of the
    /// finger's ideal fractional cell, so near-misses land and edge overhang
    /// pulls in — while a legal exact drop always keeps its own cell.
    private var ghostOrigin: GridPos? {
        guard let slot = dragSlot, let piece = game.tray[slot], boardInner.width > 0 else {
            return nil
        }
        let cell: CGFloat = boardInner.width / CGFloat(TikiStacksGame.size)
        let pw: CGFloat = CGFloat(piece.cols) * cell
        let ph: CGFloat = CGFloat(piece.rows) * cell
        let center = CGPoint(x: dragLocation.x, y: dragLocation.y - 80)
        let idealCol = Double((center.x - pw / 2 - boardInner.minX) / cell)
        let idealRow = Double((center.y - ph / 2 - boardInner.minY) / cell)
        return game.snappedOrigin(for: piece, idealRow: idealRow, idealCol: idealCol)
    }

    // MARK: tray

    private func trayView(_ W: CGFloat) -> some View {
        let tw: CGFloat = W * 0.94
        let th: CGFloat = tw * 170 / 520
        let slotCenters: [CGFloat] = [94.0 / 520.0, 260.0 / 520.0, 426.0 / 520.0]
        return Image.uiTray
            .resizable()
            .frame(width: tw, height: th)
            .offset(x: trayShake)
            .overlay(
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        if let piece = game.tray[i], dragSlot != i {
                            let miniCell: CGFloat = min(tw * 0.24 / CGFloat(max(piece.cols, piece.rows)), 22)
                            PieceView(
                                piece: piece, cellSize: miniCell,
                                glowing: game.glowingPieceIDs.contains(piece.id)
                            )
                            // Death beat: the pieces that fit nowhere grey
                            // out — the visible reason the run ended.
                            .saturation(game.isGameOver ? 0.1 : 1)
                            .opacity(game.isGameOver ? 0.5 : 1)
                            .animation(.easeOut(duration: 0.4), value: game.isGameOver)
                            .position(x: tw * slotCenters[i], y: th * 79 / 170)
                            .transition(.scale(scale: 0.3).combined(with: .opacity))
                        }
                    }
                }
                .animation(.spring(duration: 0.35, bounce: 0.4), value: game.tray)
            )
            .overlay(
                // one full-width gesture surface split into thirds
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { i in
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(dragGesture(slot: i))
                    }
                }
            )
    }

    private func dragGesture(slot: Int) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("game"))
            .onChanged { value in
                guard !howToOpen, !game.isGameOver, game.tray[slot] != nil else { return }
                dragSlot = slot
                dragLocation = value.location
            }
            .onEnded { _ in
                guard dragSlot == slot else { return }
                defer { dragSlot = nil }
                guard let origin = ghostOrigin else { return }
                let cleared = game.clearFlash.count
                let placed = withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
                    game.place(slot: slot, at: origin)
                }
                if placed {
                    let didClear = game.clearFlash.count > cleared || !game.clearFlash.isEmpty
                    if didClear {
                        clearHaptic.impactOccurred()
                        // CLEAN SWEEP gets the house fanfare (skipped during
                        // tutorial rounds — every scripted round wipes the grid).
                        if !coachActive, game.grid.allSatisfy({ $0.allSatisfy { $0 == nil } }) {
                            TikiSound.shared.fanfare()
                        }
                    } else {
                        placeHaptic.impactOccurred()
                    }
                    if coachActive {
                        handleTutorialPlacement(didClear: didClear)
                    }
                    persist()
                }
            }
    }

    // MARK: drag overlay

    @ViewBuilder
    private var dragOverlay: some View {
        if let slot = dragSlot, let piece = game.tray[slot], boardInner.width > 0 {
            let cell: CGFloat = boardInner.width / CGFloat(TikiStacksGame.size)
            PieceView(piece: piece, cellSize: cell, glowing: game.glowingPieceIDs.contains(piece.id))
                .scaleEffect(1.07)
                .position(x: dragLocation.x, y: dragLocation.y - 80)
                .allowsHitTesting(false)
        }
    }

}

/// Firefly marker on a glowing cell — one bright ember of the lagoon's
/// night swarm riding the piece.
private struct FireflyDot: View {
    let size: CGFloat
    @State private var bright = false

    var body: some View {
        Circle()
            .fill(P.torch.color)
            .frame(width: size, height: size)
            .shadow(color: P.torch.color.opacity(0.9), radius: bright ? size * 0.7 : size * 0.3)
            .opacity(bright ? 1 : 0.7)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
    }
}

// MARK: - Board frame mask

/// Punches the play-field hole out of the frame artwork at render time.
/// The SVG's wood layers are full-bleed rects, and Xcode's SVG importer
/// ignores opacity attributes — so the hole has to happen in SwiftUI.
private struct BoardFrameHole: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        let inner = CGRect(
            x: rect.width * 40 / 560,
            y: rect.height * 38 / 560,
            width: rect.width * 480 / 560,
            height: rect.height * 480 / 560
        )
        let r: CGFloat = rect.width * 14 / 560
        p.addRoundedRect(in: inner, cornerSize: CGSize(width: r, height: r))
        return p
    }
}

// MARK: - Floating score callout

private struct PopupText: View {
    let text: String
    let tier: Int
    @State private var risen = false

    private var fill: Color {
        switch tier {
        case 0: return Color(red: 0.957, green: 0.914, blue: 0.831)   // cream
        case 1: return Color(red: 0.957, green: 0.914, blue: 0.831)   // combo x2
        case 2: return Color(red: 0.910, green: 0.702, blue: 0.235)   // combo x3 gold
        default: return Color(red: 0.910, green: 0.420, blue: 0.290)  // x4+/milestone coral
        }
    }

    var body: some View {
        ZStack {
            Text(text)
                .offset(x: 2, y: 2)
                .foregroundStyle(Color(red: 0.106, green: 0.086, blue: 0.075).opacity(0.9))
            Text(text)
                .foregroundStyle(fill)
        }
        .font(.custom("Futura-Bold", size: tier > 0 ? CGFloat(32 + tier * 4) : 30))
        .tracking(tier > 0 ? 2 : 0)
        .scaleEffect(risen ? (tier > 0 ? 1.18 : 1.0) : 0.5)
        .offset(y: risen ? -52 : 0)
        .opacity(risen ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) { risen = true }
        }
    }
}

/// One burst star that fires after a cascade delay, sweeping out from the
/// clear's centroid.
private struct BurstView: View {
    let delay: Double
    @State private var shown = false

    var body: some View {
        Image.fxBurst
            .resizable()
            .scaleEffect(shown ? 1 : 0.05)
            .opacity(shown ? 1 : 0)
            .rotationEffect(.degrees(shown ? 18 : -20))
            .onAppear {
                withAnimation(.spring(duration: 0.32, bounce: 0.4).delay(delay)) {
                    shown = true
                }
            }
    }
}

// MARK: - Piece rendering

struct PieceView: View {
    let piece: Piece
    let cellSize: CGFloat
    var glowing: Bool = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(piece.cells, id: \.self) { c in
                ZStack {
                    piece.color.image
                        .resizable()
                        .frame(width: cellSize - 2, height: cellSize - 2)
                    if glowing {
                        FireflyDot(size: cellSize * 0.26)
                    }
                }
                .offset(x: CGFloat(c.col) * cellSize, y: CGFloat(c.row) * cellSize)
            }
        }
        .frame(
            width: CGFloat(piece.cols) * cellSize,
            height: CGFloat(piece.rows) * cellSize,
            alignment: .topLeading
        )
    }
}

#Preview {
    TikiStacksView()
        .environment(PlayerStore(inMemory: true))
}
