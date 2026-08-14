import SwiftUI

/// Cabana Cipher — hangman-style letter guessing at the poolside. Tap any
/// keyboard letter: if it is in the phrase it fills every position at once
/// (tiles are display-only), if not it strikes out on the keyboard and costs
/// a mistake. A category strip above the board hints the genre. Progress
/// persists in SwiftData; each cracked phrase pays the wallet.
struct CipherView: View {
    var onExitRequested: () -> Void = { }
    @Environment(PlayerStore.self) private var store
    @State private var game = CipherGame()
    @State private var howToOpen = false
    @State private var seenHowTo = true
    @State private var shake: CGFloat = 0
    /// The CRACKED panel waits for the winning cascade to land before it
    /// pours in — set on a delay from finishIfComplete, cleared on advance.
    @State private var crackedShown = false
    /// The delayed presentation task — cancelled on view exit so the win
    /// fanfare can never fire over the lounge.
    @State private var crackedTask: Task<Void, Never>?
    /// Defeat beat: the answer lands on the board first, THEN the panel.
    /// `defeatRevealed` is DISPLAY-ONLY — writing the answer into the
    /// engine's solvedLetters would persist it and hand out completion
    /// credit on the next restore.
    @State private var defeatRevealed = false
    /// How many tiles the defeat sweep has turned over, in phrase order.
    /// The reveal is driven by THIS counter rather than per-tile animation
    /// delays: a tile's symbol→letter swap replaces its content subtree, so
    /// SwiftUI staggers only the rotation and the letters all land in one
    /// frame (measured). Ticking state gives a real progressive sweep.
    @State private var revealProgress = 0
    @State private var failedShown = false
    @State private var failedTask: Task<Void, Never>?
    @State private var autoplayStarted = false
    @State private var started = false
    /// First-run coach — two scripted beats: tap a sure-hit letter (watch it
    /// cascade into every tile it owns), then the HINT affordance.
    /// `tutorialBeat` tracks which beat is live.
    @State private var coachActive = false
    @State private var tutorialBeat: Int = 0
    static let tutorialBeatCount = 2
    /// Show clock for the win flourish — set the moment the phrase completes,
    /// cleared on advance/retry. Every wave hop, glint, and spark star in
    /// CipherWinFX schedules off this one anchor (the Luau FX lesson: a
    /// main-thread hitch must shift the whole show together, never apart).
    /// Stays nil on a restored-complete board — no replayed fanfare.
    @State private var winWaveStart: Date?
    /// Fires after a successful tutorial dismiss so the transition from
    /// coach → real play is unmistakable (SKIP dismisses silently).
    @State private var readyBannerActive = false
    /// Beat-0 spotlight: until the very first taught tap lands, everything
    /// but the target dims and the target breathes — the opening move is
    /// unmissable. The dim lifts with the first lock (the payoff flips in
    /// full color); later beats keep ring + breathe only. Reduce Motion
    /// keeps the dim, skips the breathe.
    @State private var coachBreathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The heavy dim applies only while beat 0 waits for its tap.
    private var spotlightDimActive: Bool {
        coachActive && tutorialBeat == 0
    }
    /// Matchbook spine bookkeeping for the CRACKED panel: name of the book
    /// this solve completed (banner + the +100) and milestone mints that
    /// were new this solve (shared toast). Both reset on advance.
    @State private var bookCompleted: String?
    @State private var mintedThisSolve = 0
    /// Leaderboard overlay + the payoff bar's rank teaser.
    @State private var leaderboardOpen = false
    @State private var boardStandings: GameCenter.Standings?
    /// The LAST CALL matchbook-wall ceremony at each full-wall wrap.
    @State private var lastCallActive = false
    /// Shared lives — defeat spend beat, education toast, out-of-lives gate.
    @State private var outOfLivesOpen = false
    @State private var spendBreakIndex: Int? = nil
    @State private var playSpendBreak = false
    @State private var livesEducationActive = false
    /// Guards a single spend + VO per cold phrase.
    @State private var defeatHandled = false
    /// Streak story for the panels: whether this solve beat the best run
    /// (needs the pre-recordRun best, so it's captured at solve time), and
    /// the run a defeat ended (captured before breakStreak zeroes it).
    @State private var newBestStreak = false
    @State private var endedStreak = 0

    private let lockHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let mistakeHaptic = UINotificationFeedbackGenerator()

    // MARK: reveal timing
    // One source of truth for the tile flip: the defeat beat derives its
    // panel delay from these, so the animation and the wait can never drift
    // apart the way two hand-tuned numbers do.
    private static let tileFlip = 0.4
    /// A win cascades fast — it's a victory lap over letters you already know.
    /// Reads CipherWinTiming so the golden wave (which chases this front at
    /// the same rate) can never drift off the cascade.
    private static let winStagger = CipherWinTiming.stagger
    /// A defeat sweeps SLOWER: this is the first time you're seeing the
    /// answer, and it has to read as its own beat, not a flicker.
    private static let defeatStagger = 0.06
    /// Beat to sit on the finished answer before the panel covers it.
    private static let defeatHold = 0.7

    /// How long the defeat reveal runs, end to end, for `count` letters.
    private static func defeatRevealDuration(letters count: Int) -> Double {
        Double(max(0, count - 1)) * defeatStagger + tileFlip
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CipherBackgroundView(phase: scenePhase)
                    .accessibilityHidden(true)
                content(geo.size)
                // Presented DELAYED so the hero cascade finishes in the clear
                // (panel R1: the final flip used to play under the scrim).
                // Hidden while the LAST CALL wall pours — the ceremony owns
                // the screen and the panel would bleed through its scrim.
                if crackedShown, !lastCallActive {
                    CipherCrackedPanel(
                        phrase: game.phrase,
                        isCleanSolve: game.isCleanSolve,
                        mistakes: game.mistakes,
                        hints: game.hints,
                        summary: game.lastRunSummary,
                        canAffordNewItem: store.canAffordNewItem,
                        bookCompleted: bookCompleted,
                        mintedThisSolve: mintedThisSolve,
                        boardRank: boardStandings?.local?.rank,
                        streak: store.record(for: .cabanaCipher).streak,
                        bestStreak: store.record(for: .cabanaCipher).bestStreak,
                        isNewBestStreak: newBestStreak,
                        onNextPhrase: { advanceTapped() },
                        onOpenLeaderboard: {
                            withAnimation(.spring(duration: 0.3, bounce: 0.25)) { leaderboardOpen = true }
                        }
                    )
                }
                if failedShown {
                    CipherFailedPanel(
                        phrase: game.phrase,
                        endedStreak: endedStreak,
                        bestStreak: store.record(for: .cabanaCipher).bestStreak,
                        spendBreakIndex: spendBreakIndex,
                        playSpendBreak: playSpendBreak,
                        onExit: onExitRequested,
                        onPlayAgain: {
                            if store.isOutOfLives(for: .cabanaCipher) {
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
                            withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = false }
                        },
                        onLifeLandedPlay: {
                            withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = false }
                            if game.isFailed {
                                retryAfterGate()
                            } else {
                                // NEXT PHRASE was gated — continue the pour/advance path.
                                if (game.phraseIndex + 1).isMultiple(of: CipherGame.phrases.count) {
                                    var instant = Transaction()
                                    instant.disablesAnimations = true
                                    withTransaction(instant) { crackedShown = false }
                                    withAnimation(.easeInOut(duration: 0.4)) { lastCallActive = true }
                                } else {
                                    advancePhrase()
                                }
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
                if leaderboardOpen {
                    LeaderboardView(theme: .cipher) {
                        withAnimation(.easeOut(duration: 0.25)) { leaderboardOpen = false }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(90)
                }
                if lastCallActive {
                    CipherLastCallCeremony {
                        advancePhrase()
                        withAnimation(.easeOut(duration: 0.35)) { lastCallActive = false }
                    }
                }
                if coachActive, !game.isComplete, !game.isFailed {
                    CoachCard(
                        message: coachMessage,
                        skin: .cipher,
                        onSkip: { dismissCoach(withSuccess: false) },
                        // Below BOTH the shell's back chevron (bottom ~114pt)
                        // and the cipher coach card (.top(122), ~52pt tall) —
                        // 118 landed the chip underneath the card itself.
                        skipTopPadding: 190
                    )
                }
                if readyBannerActive {
                    TutorialReadyBanner(message: "READY TO CRACK", skin: .cipher) {
                        readyBannerActive = false
                    }
                }
                if howToOpen {
                    HowToPlayPanel(title: "HOW TO CRACK", rules: [
                        HowToRule(symbol: "hand.tap.fill", text: "A famous saying hides behind the symbols. Tap any letter you think is in it — a hit fills every spot at once."),
                        HowToRule(symbol: "textformat.abc", text: "Same symbol, same letter. The category strip tells you what kind of saying it is."),
                        HowToRule(symbol: "xmark.circle.fill", text: "A letter that is not in the phrase strikes out and costs a miss — five misses ends the phrase. HINT reveals a letter: it trims your score, never costs a miss."),
                        HowToRule(symbol: "mustache.fill", text: "Every phrase opens with its busiest letter poured free. Vic adds one free tip a day."),
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
        .onAppear { Analytics.entered("cipher") }
        .onChange(of: coachActive) { _, active in
            // The FTUE is its own progression family — the one
            // place a tutorial SHOULD be counted (D-6).
            if active { Analytics.progression(.start, "coach", "cabanaCipher") }
        }
        .onChange(of: game.phraseIndex, initial: true) { _, idx in
            Analytics.runStarted(.cabanaCipher, level: Analytics.phrase(idx), tutorial: coachActive)
        }
        .onDisappear {
            Analytics.exited("cipher",
                             runInProgress: (game.isComplete || game.isFailed) ? nil : .cabanaCipher)
        }
        .onDisappear {
            crackedTask?.cancel()
            failedTask?.cancel()
        }
        .onAppear { if coachActive { startCoachBreathe() } }
        .onChange(of: coachActive) { _, on in
            game.setCoachShield(on)
            if on {
                startCoachBreathe()
            } else {
                withAnimation(.easeOut(duration: 0.3)) { coachBreathe = false }
            }
        }
        .onChange(of: game.isComplete) { _, over in
            guard over else { return }
            boardStandings = nil
            Task { boardStandings = try? await GameCenter.shared.loadStandings(for: .cabanaCipher) }
        }
        .onChange(of: game.isFailed) { _, failed in
            guard failed else {
                defeatHandled = false
                return
            }
            handleDefeat()
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

    /// Golden hour arrives as the phrase completes — solving IS the sunset.
    /// tier = completed matchbooks (solvedCount / 6, capped at 16): the
    /// pennant string across the far deck, permanent because solvedCount is.
    private var scenePhase: ProgressPhase {
        let unique = game.uniqueCipherLetters.count
        return ProgressPhase(
            depth: unique == 0 ? 0 : Double(game.solvedLetters.count) / Double(unique),
            // The pennant string maxes at 16 (CipherBackgroundView caps the
            // same way) — cap here too so the double cap is documented.
            tier: min(16, game.solvedCount / 6),
            beat: game.lockBeat
        )
    }

    // MARK: lifecycle

    private func start() {
        guard !started else { return }
        started = true
        let payload = game.restore(from: store.loadState(for: .cabanaCipher))
        seenHowTo = payload?.seenHowTo ?? false
        // Crafted fully-solved saves can restore complete — mirror that in
        // the panel flag so the board is never complete-but-panel-less.
        crackedShown = game.isComplete
        // One-shot migration re-teach: a pre-hangman save decodes with
        // misses == nil and seenHowTo == true — that player learned the DEAD
        // cursor model, so the rebuilt rules open the how-to once. The next
        // persist writes misses (even []), so this never re-fires.
        if let payload, payload.seenHowTo, payload.misses == nil {
            howToOpen = true
        }
        if !seenHowTo, !store.onboardingSkipped(for: .cabanaCipher) {
            // Pin the tutorial phrase to index 0 ("THE EARLY BIRD GETS
            // THE WORM") so the coach's sure-hit target is stable even if a
            // killed-app resume restored a later phrase mid-arc. The house
            // pour is the only pre-reveal the coach needs.
            if game.phraseIndex != 0 || (payload?.assignments.isEmpty ?? true) {
                game.begin(index: 0)
            }
            coachActive = true
            game.setCoachShield(true)
            tutorialBeat = 0
        }
        // Kill-and-relaunch mid-defeat: re-arm the panel (answer already
        // shown, no reveal animation to replay) without double-spending.
        if game.isFailed {
            defeatHandled = true
            defeatRevealed = true
            revealProgress = game.phrase.filter { $0 != " " }.count // already shown
            failedShown = true
        }
        persist()
        #if DEBUG
        // Dev hook: TIKI_CIPHER_TUTORIAL_AUTOPLAY=1 walks the 2 scripted
        // beats so we can capture each state without a real tap driver.
        if ProcessInfo.processInfo.environment["TIKI_CIPHER_TUTORIAL_AUTOPLAY"] == "1" {
            Task { @MainActor in
                while coachActive {
                    try? await Task.sleep(for: .milliseconds(1400))
                    if !coachActive { break }
                    if tutorialBeat == 1 {
                        useHint(charged: true)
                    } else {
                        guard let plain = coachTargetPlain else { break }
                        tryGuess(plain)
                    }
                }
            }
        }
        // Staging hook (SIMCTL_CHILD_TIKI_CIPHER_SOLVED=<n>): n phrases
        // already solved, fresh board at phrase n, no coach — pennants,
        // book banners, and LAST CALL all stage on demand.
        if let raw = ProcessInfo.processInfo.environment["TIKI_CIPHER_SOLVED"], let n = Int(raw), n >= 0 {
            game.debugSeedSolved(n)
            seenHowTo = true
            coachActive = false
            game.setCoachShield(false)
            persist()
        }
        // Staging: TIKI_CIPHER_MISTAKES=<n> on the live board.
        if let raw = ProcessInfo.processInfo.environment["TIKI_CIPHER_MISTAKES"],
           let n = Int(raw) {
            game.debugStageMistakes(n)
            if game.isFailed { handleDefeat() }
            persist()
        }
        if ProcessInfo.processInfo.environment["TIKI_AUTOPLAY"] == "1", !autoplayStarted {
            autoplayStarted = true
            howToOpen = false
            coachActive = false
            game.setCoachShield(false)
            seenHowTo = true
            Task { await autoplay() }
        }
        #endif
    }

    private func persist() {
        store.saveState(for: .cabanaCipher, payload: game.payload(seenHowTo: seenHowTo))
    }

    private func markHowToSeen() {
        seenHowTo = true
        persist()
    }

    /// One shared breathe phase drives whichever element the coach is
    /// pointing at (key, tile, or HINT). Guarded so the two onAppear paths
    /// can't stack a second repeatForever on top of the first.
    private func startCoachBreathe() {
        guard coachActive, !reduceMotion, !coachBreathe else { return }
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
            coachBreathe = true
        }
    }

    /// `playSound: false` graduates silently — the solve path fires win()
    /// with the CRACKED panel a beat later, and two stingers inside one
    /// second read as a glitch (panel R3).
    private func dismissCoach(withSuccess: Bool, playSound: Bool = true) {
        Analytics.progression(withSuccess ? .complete : .fail, "coach", "cabanaCipher")
        guard coachActive else { return }
        // Wipe scripted-board residue BEFORE the shield drops: stray taps
        // during the teach accrue real misses under the shield, and letting
        // them ride would detonate an instant defeat — and a life spend —
        // the moment the shield clears (panel R1 critic).
        game.clearCoachResidue()
        withAnimation(.easeOut(duration: 0.3)) { coachActive = false }
        game.setCoachShield(false)
        if withSuccess {
            if playSound { CoachSkin.cipher.dismissSound.play() }
            readyBannerActive = true
        } else {
            store.setOnboardingSkipped(true, for: .cabanaCipher)
        }
        seenHowTo = true
        persist()
    }

    /// The sure-hit keyboard letter the coach pulses on beat 0 — the most
    /// frequent still-hidden letter, so the payoff cascade is maximal.
    private var coachTargetPlain: Character? {
        guard coachActive, tutorialBeat == 0 else { return nil }
        return game.coachTargetPlain
    }

    /// The cipher symbol the target letter hides behind — its tiles pulse in
    /// sympathy with the key so the fill destination is visible before the tap.
    private var coachTargetCipher: Character? {
        guard let plain = coachTargetPlain else { return nil }
        return game.mapping[plain]
    }

    /// The HINT button gets a pulse on beat 1 — the affordance IS the atom
    /// for that beat, so the keyboard pulse stands down.
    private var coachHintPulseActive: Bool {
        coachActive && tutorialBeat == 1
    }

    /// Card copy: one diegetic verb per beat. ≤ 6 words per beat (rubric §3).
    /// "CRACK" is the game's own vocabulary — the HowToPlay panel calls the
    /// full puzzle a "crack" and the completion overlay says CRACKED.
    private var coachMessage: String {
        tutorialBeat == 0 ? "TAP THE GLOWING LETTER" : "STUCK? TAP HINT"
    }

    private func useHint(charged: Bool) {
        Analytics.design("feature:cipher:hint:\(charged ? "charged" : "free")")
        guard !game.isComplete, !game.isFailed, !howToOpen else { return }
        // Beat 1's atom is the HINT affordance — tutorial hints ride free so
        // the player doesn't pay a mistake tax for following the coach's cue.
        let effectiveCharged = coachActive && tutorialBeat == 1 ? false : charged
        withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
            game.hint(charged: effectiveCharged)
        }
        lockHaptic.impactOccurred()
        if coachActive, tutorialBeat == 1 {
            advanceTutorial()
        }
        finishIfComplete()
        persist()
    }

    /// Beat 0 (taught tap) → Beat 1 (hint) → dismiss. Card copy and pulse
    /// targets are recomputed from `tutorialBeat` on each read.
    private func advanceTutorial() {
        let next = tutorialBeat + 1
        if next >= Self.tutorialBeatCount {
            dismissCoach(withSuccess: true)
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { tutorialBeat = next }
        }
    }

    private func tryGuess(_ plain: Character) {
        guard !game.isComplete, !game.isFailed, !howToOpen else { return }
        let before = game.mistakes
        // Animated so tile flips and the CRACKED! overlay's transition run.
        let locked = withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
            game.guess(plain)
        }
        if locked {
            lockHaptic.impactOccurred()
            // The completing guess cedes its clear() to win() at panel-land —
            // two celebration sounds in one frame read as a glitch.
            if !game.isComplete {
                TikiSound.shared.clear(intensity: game.solvedLetters.count / 4 + 1)
            }
        } else if game.mistakes > before {
            mistakeHaptic.notificationOccurred(.error)
            TikiSound.shared.mistake()
            if !reduceMotion {
                withAnimation(.spring(duration: 0.08, bounce: 0.6)) { shake = 7 }
                withAnimation(.spring(duration: 0.2, bounce: 0.4).delay(0.08)) { shake = 0 }
            }
        }
        // Only advance on a REAL success; a wrong guess must not trigger the
        // `withSuccess: false` path, which would flip the bundle-wide skip flag.
        // Beat 0 → beat 1 (hint) → dismiss. Beat 1 advances via useHint.
        if locked, coachActive, tutorialBeat == 0 { advanceTutorial() }
        if game.isFailed { handleDefeat() }
        finishIfComplete()
        persist()
    }

    /// Defeat spends a life and arms the panel beat — never recordRun
    /// (a round is a cracked phrase, not a cold one).
    private func handleDefeat() {
        // Defeat records the attempt too — without this Cipher would show a
        // 100% win rate, which is exactly the §3.2 bug this replaces.
        if !defeatHandled {
            Analytics.runEnded(.cabanaCipher, level: Analytics.phrase(game.phraseIndex),
                               won: false, score: game.completionScore,
                               tutorial: coachActive)
        }
        guard game.isFailed, !defeatHandled else { return }
        defeatHandled = true
        // The run of phrases ends here — defeats never reach recordRun
        // (lives canon), so the streak is broken explicitly. The panel
        // mourns the run by name, so grab it before it zeroes.
        endedStreak = store.record(for: .cabanaCipher).streak
        store.breakStreak(for: .cabanaCipher)
        // The answer lands FIRST: a player who just lost has earned the
        // right to see what they were chasing before the panel covers the
        // board. Display-only — the engine keeps its unsolved state.
        defeatRevealed = true
        let letters = game.phrase.filter { $0 != " " }.count
        failedTask?.cancel()
        failedTask = Task { @MainActor in
            if reduceMotion {
                // No sweep under Reduce Motion — the answer simply appears.
                revealProgress = letters
                try? await Task.sleep(for: .seconds(0.6))
            } else {
                // The sweep itself: one tile per tick, left to right, so the
                // answer arrives as a readable beat instead of a flash.
                for i in 1...max(1, letters) {
                    guard !Task.isCancelled else { return }
                    withAnimation(.spring(duration: Self.tileFlip, bounce: 0.3)) {
                        revealProgress = i
                    }
                    try? await Task.sleep(for: .seconds(Self.defeatStagger))
                }
                // Hold on the finished answer before the panel covers it.
                try? await Task.sleep(for: .seconds(Self.defeatHold))
            }
            guard !Task.isCancelled, game.isFailed else { return }
            // The death sting lands HERE, not on the killing miss — that
            // frame already fired the miss sound, and two stingers in one
            // frame read as a glitch (same finding as the win path).
            TikiSound.shared.gameOver()
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) { failedShown = true }
            // Lives messaging rides WITH the panel so it can't fight the
            // reveal for attention.
            offerLivesEducationIfNeeded()
        }
        if store.spendLifeForDefeat(game: .cabanaCipher, duringTutorial: coachActive) {
            armSpendBreak(after: store.lives)
            AccessibilityNotification.Announcement(
                "Life spent — \(store.lives) of \(PlayerStore.livesCap) left"
            ).post()
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
        guard !store.livesExplained, !coachActive, !readyBannerActive else { return }
        store.livesExplained = true
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { livesEducationActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(4200))
            withAnimation(.easeOut(duration: 0.4)) { livesEducationActive = false }
        }
    }

    /// A FRESH phrase after a defeat — the lost phrase is spent, and its
    /// answer was just shown, so re-serving it would be a non-puzzle.
    private func retryAfterGate() {
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            game.advance()
            crackedShown = false
            winWaveStart = nil
            defeatRevealed = false
            revealProgress = 0
            failedShown = false
            defeatHandled = false
            spendBreakIndex = nil
            playSpendBreak = false
            persist()
        }
    }

    private func finishIfComplete() {
        guard game.isComplete, game.lastRunSummary == nil else { return }
        // Solving the tutorial phrase graduates the player — without this, a
        // confident player who never taps HINT carries the coach shield into
        // phrase 2+ forever (no defeats possible, MISSES 6/5) — panel R2.
        if coachActive {
            dismissCoach(withSuccess: true, playSound: false)
            readyBannerActive = false   // the CRACKED panel owns this moment
        }
        // Economy lands immediately (the panel reads lastRunSummary); the
        // panel itself — and the win fanfare — wait for the whole show: the
        // cascade's flips, then the golden wave + spark stars chasing them
        // (CipherWinFX). panelDelay is the single source of truth so the
        // panel can never land on top of a still-running wave, and win()
        // still lands WITH the panel, not under it.
        winWaveStart = Date()
        let letters = game.phrase.filter { $0 != " " }.count
        let delay = CipherWinTiming.panelDelay(letters: letters, reduceMotion: reduceMotion)
        crackedTask?.cancel()
        crackedTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            // Cancellation covers view exit — the fanfare must never play
            // over the lounge after a quick back-out (panel R2 nit).
            guard !Task.isCancelled, game.isComplete else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) { crackedShown = true }
            TikiSound.shared.win()
            mistakeHaptic.notificationOccurred(.success)
        }
        // Matchbook spine: phrases advance linearly, so completed books =
        // solvedCount / 6. Book bonuses and mints land before recordRun so
        // the panel's WALLET line shows the full take. Round two re-strikes
        // no books — the wall is finite at matchbooks.count.
        let books = game.solvedCount / 6
        if game.solvedCount.isMultiple(of: 6), books <= CipherGame.matchbooks.count {
            bookCompleted = game.currentMatchbook.book.name
            store.grant(points: 100, source: "milestone", sourceID: "cipher:book")
        }
        for (i, count) in [1, 4, 8, 16].enumerated() where books >= count {
            if store.recordMilestone(game: .cabanaCipher, bit: 14 + i) { mintedThisSolve += 1 }
        }
        // Looped phrases (301+) pay a quarter — the Blueprints replay rate.
        // Ships in the same build as the +100 book bonuses, never before.
        let looped = game.phraseIndex >= CipherGame.phrases.count
        // recordRun folds this solve into bestStreak, after which a tie and
        // a beat are indistinguishable — so the "beat it" verdict needs the
        // best captured first.
        let prevBestStreak = store.record(for: .cabanaCipher).bestStreak
        game.lastRunSummary = store.recordRun(
            game: .cabanaCipher, score: game.completionScore,
            earnScore: looped ? max(10, game.completionScore / 4) : nil
        )
        newBestStreak = store.record(for: .cabanaCipher).streak > prevBestStreak
        Analytics.runEnded(.cabanaCipher, level: Analytics.phrase(game.phraseIndex),
                           won: true, score: game.completionScore,
                           tutorial: coachActive)
    }

    /// NEXT PHRASE: at each full-wall wrap the LAST CALL ceremony pours
    /// first; otherwise straight to the next phrase.
    private func advanceTapped() {
        // Post-solve is never at zero (defeats never solve), but gate
        // defensively if the pool drained elsewhere mid-session.
        if store.isOutOfLives(for: .cabanaCipher) {
            withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
            return
        }
        if (game.phraseIndex + 1).isMultiple(of: CipherGame.phrases.count) {
            // The panel leaves WITHOUT a fade so its gold text can't bleed
            // through the ceremony scrim during the crossfade (panel R1).
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { crackedShown = false }
            withAnimation(.easeInOut(duration: 0.4)) { lastCallActive = true }
        } else {
            advancePhrase()
        }
    }

    private func advancePhrase() {
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            game.advance()
            crackedShown = false
            winWaveStart = nil
            bookCompleted = nil
            mintedThisSolve = 0
            defeatHandled = false
            newBestStreak = false
            persist()
        }
    }

    /// Local calendar day key for Vic's free daily tip.
    private var todayKey: String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private var freeTipAvailable: Bool {
        game.lastFreeHintDay != todayKey
    }

    #if DEBUG
    /// Dev hook (TIKI_AUTOPLAY=1): cracks the current phrase with one miss
    /// and one hint along the way. TIKI_CIPHER_CLEAN=1 solves clean;
    /// TIKI_CIPHER_HOLD=<k> stops with k letters left (golden-hour staging);
    /// TIKI_CIPHER_ADVANCE=1 taps NEXT after the solve (LAST CALL staging).
    private func autoplay() async {
        let env = ProcessInfo.processInfo.environment
        let clean = env["TIKI_CIPHER_CLEAN"] == "1"
        let hold = Int(env["TIKI_CIPHER_HOLD"] ?? "") ?? 0
        try? await Task.sleep(for: .milliseconds(600))
        var usedWrong = clean
        var usedHint = clean
        while !game.isComplete, !game.isFailed {
            let unsolved = game.uniqueCipherLetters.filter { game.plainFor(cipherLetter: $0) == nil }
            if hold > 0, unsolved.count <= hold { return }
            try? await Task.sleep(for: .milliseconds(160))
            if !usedHint, game.hints == 0, game.uniqueCipherLetters.count > 6 {
                usedHint = true
                game.hint()
                persist()
                continue
            }
            if !usedWrong {
                usedWrong = true
                // A deliberate miss: any letter absent from the phrase.
                if let wrong = "QZXJVK".first(where: { !game.phrase.contains($0) && !game.misses.contains($0) }) {
                    tryGuess(wrong)
                }
                continue
            }
            guard let plain = game.coachTargetPlain else { break }
            tryGuess(plain)
        }
        if env["TIKI_CIPHER_ADVANCE"] == "1", game.isComplete {
            try? await Task.sleep(for: .milliseconds(2500))
            advanceTapped()
        }
    }
    #endif

    // MARK: layout

    private func content(_ size: CGSize) -> some View {
        let oneLeft = game.mistakes == CipherGame.mistakeCap - 1
        return VStack(spacing: 0) {
            HStack(alignment: .top) {
                // Leading inset clears the shell's 44pt back chevron (right
                // edge x=64) for BOTH header lines in every state — panel R1
                // measured the circle occluding "HOUSE" in all seven shots.
                VStack(alignment: .leading, spacing: 2) {
                    Text("CABANA CIPHER")
                        .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.blossom.color)
                    Text("\(game.currentMatchbook.book.name) · No. \(game.currentMatchbook.number) · MISSES \(game.mistakes)/\(CipherGame.mistakeCap)")
                        .font(.custom("Futura-Medium", size: 10, relativeTo: .body))
                        .tracking(1.5)
                        // One line always — the chevron inset narrowed the
                        // column, and long book names would wrap the misses
                        // counter onto its own row.
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(
                            oneLeft ? P.coral.color
                            : game.mistakes == 0 ? P.ink.color.opacity(0.7) : P.clay.color
                        )
                }
                .padding(.leading, 52)
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 30)) { ctx in
                        LivesHearts(count: store.livesSnapshot(now: ctx.date).count, size: .chip)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(P.ink.color.opacity(0.55)))
                    if !coachActive {
                        HowToPlayButton { Analytics.design("feature:cipher:howto"); howToOpen = true }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)

            Spacer()
            // Category strike-strip: the WoF-style genre hint. Sits with the
            // board, not the chrome — it is solving information.
            Text(game.currentCategory.rawValue)
                .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                .tracking(3)
                .foregroundStyle(P.ink.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Capsule().fill(P.cream.color))
                .overlay(Capsule().stroke(P.torch.color, lineWidth: 1.5))
                .padding(.bottom, 14)
                .animation(nil, value: game.phraseIndex)
            phraseTiles(size)
                .offset(x: shake)
            Spacer()

            // The board closes visibly while the hero cascade plays — live-
            // looking keys during the panel delay swallowed taps silently.
            VStack(spacing: 12) {
                keyboard(size)
                HStack(spacing: 10) {
                    Button {
                        useHint(charged: true)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("HINT")
                                .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                                .tracking(2)
                        }
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(P.cream.color))
                        .overlay(Capsule().stroke(P.ink.color.opacity(0.3), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    // Receded during the beat-0 spotlight; beat 1 points at
                    // it with ring + breathe on a full-color board.
                    .opacity(spotlightDimActive ? 0.35 : 1)
                    .scaleEffect(coachHintPulseActive && coachBreathe ? 1.1 : 1)
                    .overlay {
                        if coachHintPulseActive {
                            ZStack {
                                CoachPulse(skin: .cipher, diameter: 78)
                                CoachArrow(skin: .cipher, direction: .down, size: 22)
                                    .offset(y: -46)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    if freeTipAvailable {
                        Button {
                            // The day-stamp must sit BEHIND every condition
                            // useHint itself checks — otherwise a tap in the
                            // post-solve window (or on the coach's scripted
                            // board) burns the once-a-day freebie for a hint
                            // that never lands (panel R3).
                            guard !coachActive, !game.isComplete,
                                  !game.isFailed, !howToOpen else { return }
                            withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
                                game.lastFreeHintDay = todayKey
                            }
                            useHint(charged: false)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "mustache.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text("VIC'S TIP · FREE")
                                    .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                                    .tracking(2)
                            }
                            .foregroundStyle(P.ink.color)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(P.torch.color))
                        }
                        .buttonStyle(.plain)
                        // Recedes for the WHOLE coach, not just beat 0: the
                        // tip is guarded off during the teach, so it must
                        // look inert instead of swallowing taps at full gold.
                        .opacity(coachActive || spotlightDimActive ? 0.35 : 1)
                        .allowsHitTesting(!coachActive)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
            }
            .padding(.bottom, 40)
            // The board visibly closes while the terminal beat plays — on
            // the win cascade AND the defeat reveal — because full-bright
            // keys during a panel delay swallow taps silently (panel R2).
            .opacity(game.isComplete || game.isFailed ? 0.35 : 1)
            .animation(.easeOut(duration: 0.3), value: game.isComplete)
            .animation(.easeOut(duration: 0.3), value: game.isFailed)
        }
    }

    private func phraseTiles(_ size: CGSize) -> some View {
        let words = game.cipherText.split(separator: " ").map(String.init)
        let tile: CGFloat = size.width * 0.062
        // Greedy word wrap by tile budget per line, carrying each word's
        // phrase-order offset so locked letters cascade left-to-right.
        let budget = Int((size.width * 0.9) / (tile + 3))
        var lines: [[(word: String, start: Int)]] = [[]]
        var used = 0
        var offset = 0
        for word in words {
            let need = word.count + (lines[lines.count - 1].isEmpty ? 0 : 1)
            if used + need > budget, !lines[lines.count - 1].isEmpty {
                lines.append([(word, offset)])
                used = word.count
            } else {
                lines[lines.count - 1].append((word, offset))
                used += need
            }
            offset += word.count
        }
        return VStack(spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                // Word gap lives BETWEEN groups (outer spacing), not as a
                // trailing pad — a trailing pad biased centered rows ~4pt
                // left of true center (panel R1 measurement).
                HStack(spacing: 11) {
                    ForEach(Array(line.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 3) {
                            ForEach(Array(entry.word.enumerated()), id: \.offset) { i, ch in
                                letterTile(ch, side: tile, order: entry.start + i)
                            }
                        }
                    }
                }
            }
        }
        // Spark stars ride the golden wave over the phrase block. Keyed on
        // the show clock so each solve mounts a fresh, fully-scheduled layer.
        .overlay {
            if let winWaveStart {
                CipherWinSparkles(
                    start: winWaveStart,
                    letters: game.phrase.filter { $0 != " " }.count,
                    seed: game.phraseIndex,
                    reduceMotion: reduceMotion
                )
            }
        }
    }

    /// Unrevealed cipher tiles show a distinct symbol per A–Z instead of the
    /// cipher letter itself — otherwise players read the substitute letter
    /// as the "real" letter. Same cipher letter → same symbol across the
    /// phrase, so the propagation atom still reads visually.
    private static let cipherSymbols: [Character: String] = [
        "A": "●", "B": "○", "C": "■", "D": "□",
        "E": "▲", "F": "△", "G": "▼", "H": "▽",
        "I": "◆", "J": "◇", "K": "★", "L": "☆",
        "M": "♠", "N": "♣", "O": "♥", "P": "♦",
        "Q": "⬢", "R": "⬡", "S": "◉", "T": "◎",
        "U": "▶", "V": "◀", "W": "✚", "X": "✦",
        "Y": "✧", "Z": "✱",
    ]

    /// Display-only tile — all input lives on the keyboard now. Unrevealed
    /// tiles show the cipher symbol; a hit flips every tile of that letter
    /// in phrase order (the hangman cascade).
    private func letterTile(_ cipher: Character, side: CGFloat, order: Int) -> some View {
        let solved = game.plainFor(cipherLetter: cipher)
        // On defeat the board shows the answer — display-only, toned apart
        // from earned letters, and swept in phrase order by revealProgress.
        let sweptIn = defeatRevealed && order < revealProgress
        let plain = solved ?? (sweptIn ? game.reverse[cipher] : nil)
        let toldNotEarned = solved == nil && plain != nil
        let isCoachTarget = cipher == coachTargetCipher && plain == nil
        return Group {
            if let plain {
                Text(String(plain))
                    .font(.custom("Futura-Bold", size: side * 0.52))
            } else {
                // System font — Futura-Bold lacks glyphs for the geometric
                // Unicode block, so a chunk of the symbol set fell back to
                // ".notdef" boxes. System font has full coverage.
                Text(Self.cipherSymbols[cipher] ?? String(cipher))
                    .font(.system(size: side * 0.58, weight: .bold))
            }
        }
            .foregroundStyle(
                toldNotEarned ? P.clay.color
                : plain != nil ? P.ink.color
                : P.blossom.color
            )
            .frame(width: side, height: side * 1.15)
            .background(
                RoundedRectangle(cornerRadius: side * 0.18)
                    .fill(
                        toldNotEarned ? P.cream.color.opacity(0.55)
                        : plain != nil ? P.cream.color
                        : P.lagoon.color
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: side * 0.18)
                    .stroke(P.ink.color.opacity(0.25), lineWidth: 1)
            )
            .overlay {
                // Destination tiles glow STATICALLY — the pulsing ring lives
                // only on the keyboard key, so exactly one thing on screen
                // says "tap me" (tiles are display-only and a pulse would
                // teach a dead tap on the teaching beat itself).
                if isCoachTarget {
                    RoundedRectangle(cornerRadius: side * 0.18)
                        .stroke(P.torch.color, lineWidth: 2.5)
                }
            }
            // Beat-0 spotlight: the target letter's tiles stay lit so the
            // fill destination is visible before the tap lands.
            .opacity(spotlightDimActive && cipher != coachTargetCipher ? 0.4 : 1)
            // Locking flips the tile over, cascading across the phrase in
            // order. Reduce Motion swaps the 3D flip + stagger for a plain
            // cross-fade, per the house accessibility idiom.
            .rotation3DEffect(.degrees(!reduceMotion && plain != nil ? 360 : 0), axis: (x: 0, y: 1, z: 0))
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .spring(duration: Self.tileFlip, bounce: 0.3)
                        // Defeat tiles get no delay — revealProgress already
                        // paces that sweep; only the win cascade staggers here.
                        .delay(toldNotEarned ? 0 : Double(order) * Self.winStagger),
                value: plain != nil
            )
            // The win flourish: a golden wave chases the final cascade across
            // the phrase — hop + glint per tile, in the same phrase order.
            .modifier(CipherTileWinWave(
                start: winWaveStart, order: order, side: side,
                reduceMotion: reduceMotion
            ))
    }

    private func keyboard(_ size: CGSize) -> some View {
        let rows = ["ABCDEFGHI", "JKLMNOPQR", "STUVWXYZ"]
        let key: CGFloat = size.width * 0.094
        return VStack(spacing: 5) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, ch in
                        keyTile(ch, side: key)
                    }
                }
            }
        }
    }

    private func keyTile(_ ch: Character, side: CGFloat) -> some View {
        let used = game.usedPlainLetters.contains(ch)
        let missed = game.misses.contains(ch)
        let isCoachTarget = coachActive && tutorialBeat == 0 && ch == coachTargetPlain
        return Button {
            tryGuess(ch)
        } label: {
            Text(String(ch))
                .font(.custom("Futura-Bold", size: side * 0.44))
                .foregroundStyle(
                    missed ? P.coral.color
                    : used ? P.ink.color.opacity(0.3)
                    : P.ink.color
                )
                .frame(width: side, height: side * 1.15)
                .background(
                    // OPAQUE base under every state — translucent fills let
                    // the drifting buoy ring and tower legs wash out the
                    // burn/ghost states in the keyboard band (panel R2,
                    // pixel-measured 1.2:1 glyph contrast on props).
                    ZStack {
                        RoundedRectangle(cornerRadius: side * 0.2)
                            .fill(P.cream.color)
                        if missed {
                            RoundedRectangle(cornerRadius: side * 0.2)
                                .fill(P.coral.color.opacity(0.35))
                        } else if used {
                            RoundedRectangle(cornerRadius: side * 0.2)
                                .fill(P.ink.color.opacity(0.12))
                        }
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: side * 0.2)
                        .stroke(missed ? P.coral.color.opacity(0.8) : P.ink.color.opacity(missed || used ? 0.15 : 0.25),
                                lineWidth: missed ? 1.5 : 1)
                )
                .overlay {
                    // The burn mark: a dedicated strike bar at full weight —
                    // .strikethrough at key size measured ~1.7pt of low-
                    // contrast teal, invisible at arm's length (panel R1).
                    if missed {
                        Rectangle()
                            .fill(P.coral.color)
                            .frame(width: side * 0.7, height: 2.5)
                            .rotationEffect(.degrees(-8))
                    }
                }
                // Beat-0 spotlight dims via opacity; the dead states above
                // recede via premixed opaque fills, never transparency.
                .opacity(spotlightDimActive ? (isCoachTarget ? 1 : 0.35) : 1)
                .overlay {
                    if isCoachTarget {
                        CoachPulse(skin: .cipher, diameter: side * 1.25)
                    }
                }
                .overlay(alignment: .top) {
                    if isCoachTarget {
                        CoachArrow(skin: .cipher, direction: .down, size: 18)
                            .offset(y: -side * 0.55)
                    }
                }
        }
        .buttonStyle(.plain)
        .scaleEffect(isCoachTarget && coachBreathe ? 1.12 : 1)
        .animation(.spring(duration: 0.25, bounce: 0.4), value: missed)
        .accessibilityValue(missed ? "struck out" : used ? "already revealed" : "")
        .disabled(used || missed)
    }

}

#Preview {
    CipherView()
        .environment(PlayerStore(inMemory: true))
}
