import SwiftUI

/// Zombie — the merge game, played over the bar-interior scene. Swipes mix
/// drinks up the eleven-tier ladder toward THE ZOMBIE. Board persists via
/// SwiftData (GameSaveState) so a killed app resumes mid-run.
///
/// One number runs the whole game: `boardValue`, the face value of the tiles
/// on the grid. It is what the HUD shows, what the board ranks, what the best
/// records and what the wallet is paid on. The cumulative merge score
/// (`game.score`) survives as internal state — undo snapshots and the save
/// payload carry it — but nothing surfaces it any more. It used to, and it
/// needed a divisor: classic 2048 scores run ~10x hotter than the rest of the
/// bundle, which is roughly the (top tier − 1) ratio between the two numbers.
struct ZombieView: View {
    @Environment(PlayerStore.self) private var store
    var onExitRequested: () -> Void = { }
    @State private var game = ZombieGame()
    @State private var howToOpen = false
    @State private var seenHowTo = true
    @State private var autoplayStarted = false
    /// First-run coach — three scripted rounds ending at tier 4 (value 16).
    @State private var coachActive = false
    @State private var tutorialRound: Int = 0
    /// Fires after a successful tutorial dismiss so the transition from
    /// coach → real play is unmistakable (SKIP dismisses silently).
    @State private var readyBannerActive = false
    /// True during the ~720 ms window between a merge landing and the next
    /// round being seeded — pulses hide during this window so torch-gold
    /// rings don't float over the empty starting cells while the merged
    /// tile sits at the bottom.
    @State private var roundTransitioning: Bool = false
    /// Refusal nudge: the board leans into a rejected swipe and springs back.
    @State private var nudge: CGSize = .zero
    /// Gold wash for the THE ZOMBIE moment.
    @State private var zombieFlash = false
    /// First-mix drink lore card, keyed so late hides can't kill a newer card.
    @State private var loreCard: (tier: Int, title: String, line: String)?
    @State private var loreBeat = 0
    /// Depth-milestone bookkeeping: bits already checked this run, and mints
    /// that were new this run (drives the game-over toast).
    @State private var checkedBits: Set<Int> = []
    @State private var mintedThisRun = 0
    /// Leaderboard overlay + the payoff bar's rank teaser.
    @State private var leaderboardOpen = false
    @State private var boardStandings: GameCenter.Standings?
    /// Depth Charge: targeting mode with a movable 2×2 reticle (anchor =
    /// top-left cell), plus the one-time ON THE HOUSE comp toast fired at
    /// the first dangerous fill. The chip breathes the whole time it's
    /// owned — Carson's device note: big, pulsing, can't-miss.
    @State private var bombTargeting = false
    @State private var bombAnchor: (col: Int, row: Int) = (1, 1)
    @State private var bombCompActive = false
    /// Shared out-of-lives sheet — MIX AGAIN at 0 lives.
    @State private var outOfLivesOpen = false
    @State private var spendBreakIndex: Int? = nil
    @State private var playSpendBreak = false
    @State private var livesEducationActive = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let slideHaptic = UIImpactFeedbackGenerator(style: .light)
    private let mergeHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let zombieHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let successHaptic = UINotificationFeedbackGenerator()

    /// One line of house copy per drink, shown the first time each tier is
    /// mixed. Tier 11 is handled by the THE ZOMBIE banner, not a card.
    private static let drinkLore: [Int: (name: String, line: String)] = [
        3: ("LIME DAIQUIRI", "SHAKEN BY SOMEONE WHO CARES"),
        4: ("MAI TAI", "VIC MEASURES WITH HIS HEART"),
        5: ("PIÑA COLADA", "A CLOUD YOU CAN DRINK"),
        6: ("BLUE HAWAII", "THE OCEAN, BOTTLED AT DUSK"),
        7: ("FOG CUTTER", "YOU'LL FIND YOUR WAY BACK. EVENTUALLY."),
        8: ("SCORPION BOWL", "SHARED BY FOUR, REGRETTED BY ALL"),
        9: ("NAVY GROG", "THREE RUMS AND A STERN LOOK"),
        10: ("FLAMING VOLCANO", "THE PARTY'S LAST WARNING"),
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ZombieBackgroundView(phase: scenePhase)
                    .accessibilityHidden(true)
                board(geo.size)
                ZombieChrome(
                    game: game,
                    coachActive: coachActive,
                    bombTargeting: $bombTargeting,
                    bombAnchor: $bombAnchor,
                    onHowTo: { howToOpen = true },
                    onPersist: persist
                )
                Color(red: 0.910, green: 0.702, blue: 0.235)
                    .ignoresSafeArea()
                    .opacity(zombieFlash ? 0.5 : 0)
                    .allowsHitTesting(false)
                if let loreCard, !game.isOver {
                    loreCardView(loreCard, geo.size)
                }
                if bombCompActive {
                    // The drink-lore band below the board — the top band
                    // collides with either the chrome stack or the board edge
                    // somewhere across the SE/tall-phone height range.
                    MilestoneToast(message: "FREE DEPTH CHARGE · CLEARS 2×2", fontSize: 13)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, geo.size.height * 0.84)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
                if game.zombieReached && !game.zombieCelebrated {
                    ZombieWinBanner(size: geo.size) {
                        game.zombieCelebrated = true
                    }
                }
                if game.isOver {
                    ZombieGameOverPanel(
                        score: game.boardValue,
                        highestTier: highestTier,
                        summary: game.lastRunSummary,
                        canAffordNewItem: store.canAffordNewItem,
                        mintedThisRun: mintedThisRun,
                        boardRank: boardStandings?.local?.rank,
                        spendBreakIndex: spendBreakIndex,
                        playSpendBreak: playSpendBreak,
                        onExit: onExitRequested,
                        onMixAgain: {
                            if store.isOutOfLives(for: .zombie) {
                                withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
                                return
                            }
                            mixAgainAfterGate()
                        },
                        onOpenLeaderboard: {
                            withAnimation(.spring(duration: 0.3, bounce: 0.25)) {
                                leaderboardOpen = true
                            }
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
                            mixAgainAfterGate()
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
                if leaderboardOpen {
                    LeaderboardView(theme: .topShelf) {
                        withAnimation(.easeOut(duration: 0.25)) { leaderboardOpen = false }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(90)
                }
                if coachActive, !game.isOver {
                    CoachCard(
                        message: coachMessage,
                        skin: .zombie,
                        onSkip: { dismissCoach(withSuccess: false) },
                        // Clears the global back chevron AND Top Shelf's own
                        // left column (SCORE chip, then UNDO). On the default
                        // 56 the SKIP capsule landed on both — a mis-tap away
                        // from leaving the game entirely.
                        skipTopPadding: 180
                    )
                }
                if readyBannerActive {
                    TutorialReadyBanner(message: "READY TO MIX", skin: .zombie) {
                        readyBannerActive = false
                    }
                }
                if howToOpen {
                    HowToPlayPanel(title: "HOW TO MIX", rules: [
                        HowToRule(symbol: "hand.draw.fill", text: "Swipe to slide every drink on the bar."),
                        HowToRule(image: .zombieTile(1), text: "Matching drinks merge into one stronger drink."),
                        HowToRule(image: .zombieTile(10), text: "Each merge scores. Stronger merges score more."),
                        HowToRule(image: .zombieTile(11), text: "Mix all the way up to THE ZOMBIE."),
                        HowToRule(symbol: "arrow.uturn.backward", text: "One UNDO per run takes back your last swipe."),
                        HowToRule(symbol: "bell.fill", text: "When the bar fills and no drinks can merge, that's last call — the run ends."),
                        HowToRule(symbol: "burst.fill", text: "The DEPTH CHARGE clears a 2×2 of drinks. Vic comps your first."),
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
        .onAppear { Analytics.entered("topshelf") }
        .onChange(of: coachActive) { _, active in
            // The FTUE is its own progression family — the one
            // place a tutorial SHOULD be counted (D-6).
            if active { Analytics.progression(.start, "coach", "zombie") }
        }
        .onDisappear {
            Analytics.exited("topshelf", runInProgress: game.isOver ? nil : .zombie)
        }
        // Mid-run mirror. Watching boardValue rather than score also fixes
        // what the old wiring missed: a Depth Charge changes the board
        // without merging, so it moved the ranked number while leaving the
        // merge score — and this observer — untouched.
        .onChange(of: game.boardValue) { _, value in
            GameCenter.shared.submitLive(score: value, for: .zombie)
        }
        .onChange(of: game.isOver) { _, over in
            guard over else { return }
            boardStandings = nil
            Task { boardStandings = try? await GameCenter.shared.loadStandings(for: .zombie) }
        }
        .onChange(of: game.inDanger) { _, danger in
            guard danger else { return }
            offerBombCompIfNeeded()
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

    // MARK: lifecycle

    private func start() {
        guard game.tiles.isEmpty else { return }
        game.configureBest(store.bestScore(for: .zombie))
        let payload = game.restore(from: store.loadState(for: .zombie))
        // A restored board already counted its start — see TikiStacksView.
        if game.score == 0, !game.isOver {
            Analytics.runStarted(.zombie, level: "run", tutorial: coachActive)
        }
        seenHowTo = payload?.seenHowTo ?? false
        if !seenHowTo, !store.onboardingSkipped(for: .zombie) {
            // First run: three scripted rounds that walk tier 1 → 2 → 3 → 4
            // (value 2 → 4 → 8 → 16). Even if the player quit mid-tutorial we
            // always restart from round 0 — a partial-tutorial resume would be
            // fragile.
            tutorialRound = 0
            game.seedTutorialBoard(round: 0)
            coachActive = true
        }
        persist()
        #if DEBUG
        // Dev hook: SIMCTL_CHILD_TIKI_ZOMBIE_TUTORIAL=<0..3> jumps to a
        // specific scripted round for screenshot verification.
        if let raw = ProcessInfo.processInfo.environment["TIKI_ZOMBIE_TUTORIAL"],
           let r = Int(raw), (0..<ZombieGame.tutorialRoundCount).contains(r) {
            tutorialRound = r
            coachActive = true
            game.seedTutorialBoard(round: r)
        }
        // Staging hook (SIMCTL_CHILD_TIKI_ZOMBIE_BOARD=<tier>): seeds a board
        // whose highest tile is that tier so every wall state can be staged.
        if let raw = ProcessInfo.processInfo.environment["TIKI_ZOMBIE_BOARD"],
           let tier = Int(raw) {
            game.debugSeedBoard(maxTier: tier)
            seenHowTo = true
            coachActive = false
            persist()
        }
        // Staging hook (SIMCTL_CHILD_TIKI_ZOMBIE_DANGER): "1" seeds the
        // 14-tile danger board (on a fresh profile the comp toast + chip
        // fire on appear); "2" additionally scripts the flow — open
        // targeting, then drop on (1,1) — for screenshot verification.
        if let raw = ProcessInfo.processInfo.environment["TIKI_ZOMBIE_DANGER"],
           let mode = Int(raw), mode >= 1 {
            game.debugSeedDangerBoard()
            // Rewind the one-time comp so the staged run always replays the
            // ON THE HOUSE beat, even on a profile that already got it.
            store.debugResetZombieComp()
            seenHowTo = true
            coachActive = false
            persist()
            if mode >= 2 {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(1600))
                    withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                        bombTargeting = true
                        bombAnchor = (1, 1)
                    }
                    try? await Task.sleep(for: .milliseconds(1400))
                    dropBomb()
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
        // once the observable game has invalidated the view (gotcha #3), and
        // checkMilestones bookkeeps the toast in checkedBits/mintedThisRun.
        // A board RESTORED into danger never fires the onChange (no
        // transition), so the comp check runs here too.
        Task { @MainActor in
            checkMilestones()
            if game.inDanger { offerBombCompIfNeeded() }
        }
    }

    /// Records depth-state milestones the first time the board's highest tier
    /// reaches 5/7/9/11 in a run (bits 4–7). `recordMilestone` mints +75
    /// exactly once, ever; `checkedBits` keeps re-checks cheap within the run.
    private func checkMilestones() {
        for (i, tier) in [5, 7, 9, 11].enumerated()
        where highestTier >= tier && !checkedBits.contains(4 + i) {
            checkedBits.insert(4 + i)
            if store.recordMilestone(game: .zombie, bit: 4 + i) {
                mintedThisRun += 1
            }
        }
    }

    private func persist() {
        store.saveState(for: .zombie, payload: game.payload(seenHowTo: seenHowTo))
    }

    private func markHowToSeen() {
        seenHowTo = true
        persist()
    }

    private func dismissCoach(withSuccess: Bool) {
        Analytics.progression(withSuccess ? .complete : .fail, "coach", "zombie")
        guard coachActive else { return }
        withAnimation(.easeOut(duration: 0.3)) { coachActive = false }
        // Tutorial ends — real play resumes with spawn re-enabled. The final
        // merged tile stays on the board as a gift.
        game.endTutorial()
        if withSuccess {
            CoachSkin.zombie.dismissSound.play()
            readyBannerActive = true
        } else {
            store.setOnboardingSkipped(true, for: .zombie)
        }
        seenHowTo = true
        persist()
    }

    /// Escalating copy across the ladder — three merge beats, then a fourth
    /// swipe-teach beat so the player knows they can drag anywhere on the
    /// board to keep playing. Round 3 mirrors R0's "DOUBLE THE MUGS" cadence
    /// (verb + THE + bar noun) so the bartender voice carries through instead
    /// of dropping into instruction-manual mode with "SWIPE TO ...".
    private var coachMessage: String {
        switch tutorialRound {
        case 0: return "DOUBLE THE MUGS"
        case 1: return "DOUBLE AGAIN"
        case 2: return "ONCE MORE!"
        default: return "SLIDE THE MUGS"
        }
    }

    /// Called after a scripted merge lands. Advance to the next round after
    /// a beat so the merge animation and any drink-lore card have time to
    /// read; dismiss cleanly on the final round.
    private func handleTutorialMerge() {
        let next = tutorialRound + 1
        if next >= ZombieGame.tutorialRoundCount {
            dismissCoach(withSuccess: true)
            return
        }
        // Hide pulses during the interim — the seeded starting cells are
        // empty while the merged tile sits at the bottom of the column.
        roundTransitioning = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(720))
            tutorialRound = next
            withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                game.seedTutorialBoard(round: next)
            }
            roundTransitioning = false
            persist()
        }
    }

    private func swipe(_ direction: ZombieGame.Direction) {
        guard !game.isOver, !howToOpen, !bombTargeting else { return }
        var moved = false
        withAnimation(.spring(duration: 0.22, bounce: 0.18)) {
            moved = game.slide(direction)
        }
        guard moved else {
            let v: CGSize
            switch direction {
            case .up: v = CGSize(width: 0, height: -6)
            case .down: v = CGSize(width: 0, height: 6)
            case .left: v = CGSize(width: -6, height: 0)
            case .right: v = CGSize(width: 6, height: 0)
            }
            withAnimation(.spring(duration: 0.1, bounce: 0.5)) { nudge = v }
            withAnimation(.spring(duration: 0.2, bounce: 0.4).delay(0.1)) { nudge = .zero }
            return
        }
        slideHaptic.impactOccurred()
        TikiSound.shared.tick()
        if let tier = game.lastMergedTier {
            mergeHaptic.impactOccurred()
            TikiSound.shared.clear(intensity: (tier + 1) / 2)
            if tier == ZombieGame.zombieTier { celebrateZombie() }
            showLoreIfFirstMix(tier)
            announceDoublesIfNeeded()
            if coachActive {
                if tutorialRound == ZombieGame.tutorialSwipeTeachRound {
                    dismissCoach(withSuccess: true)
                } else {
                    handleTutorialMerge()
                }
            }
        } else if coachActive {
            // The swipe-teach round dismisses on ANY successful slide — merge
            // or not — since the atom is the swipe gesture itself. Earlier
            // rounds reseed so the pulsed pair stays pointable.
            if tutorialRound == ZombieGame.tutorialSwipeTeachRound {
                dismissCoach(withSuccess: true)
            } else {
                game.seedTutorialBoard(round: tutorialRound)
            }
        }
        persist()
        checkMilestones()
        if game.isOver { finishRun() }
    }

    /// THE ZOMBIE gets the full stack: gold wash + heavy double-thump +
    /// success haptic under the banner's spring entrance.
    private func celebrateZombie() {
        zombieFlash = true
        withAnimation(.easeOut(duration: 1.0).delay(0.08)) { zombieFlash = false }
        TikiSound.shared.fanfare()
        zombieHaptic.impactOccurred()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(130))
            zombieHaptic.impactOccurred(intensity: 1.0)
            try? await Task.sleep(for: .milliseconds(150))
            successHaptic.notificationOccurred(.success)
        }
    }

    private func showLoreIfFirstMix(_ tier: Int) {
        guard tier >= 3, !game.loreSeen.contains(tier),
              let lore = Self.drinkLore[tier] else {
            // The banner is tier 11's card; never show both.
            if tier == ZombieGame.zombieTier { game.loreSeen.insert(tier) }
            return
        }
        game.loreSeen.insert(tier)
        showCard(tier: tier, title: "FIRST MIX — \(lore.name)", line: lore.line)
    }

    /// Doubles After Midnight: the first time a tier-8+ drink hits the board
    /// this run, Vic announces the house rule — after any first-mix card has
    /// had its beat. Resumed past-midnight runs stay quiet (game flag).
    private func announceDoublesIfNeeded() {
        guard game.doublesLive, !game.doublesAnnounced else { return }
        game.doublesAnnounced = true
        let wait = loreCard == nil ? 350 : 2950
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(wait))
            guard !game.isOver else { return }
            showCard(tier: 2, title: "AFTER MIDNIGHT", line: "VIC POURS DOUBLES AFTER MIDNIGHT")
        }
    }

    private func showCard(tier: Int, title: String, line: String) {
        loreBeat += 1
        let beat = loreBeat
        withAnimation(.spring(duration: 0.35, bounce: 0.4)) {
            loreCard = (tier, title, line)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(2600))
            guard loreBeat == beat else { return }
            withAnimation(.easeOut(duration: 0.3)) { loreCard = nil }
        }
    }

    private func loreCardView(_ lore: (tier: Int, title: String, line: String), _ size: CGSize) -> some View {
        HStack(spacing: 12) {
            Image.zombieTile(lore.tier)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(lore.title)
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(Color(red: 0.910, green: 0.702, blue: 0.235))
                Text(lore.line)
                    .font(.custom("Futura-Medium", size: 11, relativeTo: .body))
                    .tracking(1)
                    .foregroundStyle(P.cream.color)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: min(size.width * 0.86, 380))
        .background(RoundedRectangle(cornerRadius: 14).fill(P.woodDark.color.opacity(0.94)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.ink.color, lineWidth: 2))
        .position(x: size.width / 2, y: size.height * 0.875)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
    }

    private func finishRun() {
        TikiSound.shared.gameOver()
        // Board-full is a real defeat; the coach's scripted merges never
        // end a run (tutorialActive), so they leave the pool alone.
        if store.spendLifeForDefeat(
            game: .zombie,
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
        // Face value at the kill screen is the run, full stop — best, rank,
        // wallet and analytics all read it. No `earnScore` divisor any more:
        // that existed to cool the merge score by the ~10x it ran hot, and
        // boardValue is already on the bundle's scale.
        game.lastRunSummary = store.recordRun(
            game: .zombie, score: game.boardValue, boardValue: game.boardValue
        )
        // Endless: board-full is the only ending, so `won` is always false.
        Analytics.runEnded(.zombie, level: "run", won: false, score: game.boardValue,
                           tutorial: game.tutorialActive || coachActive)
        persist()
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
        guard !store.livesExplained, !coachActive, !bombCompActive else { return }
        store.livesExplained = true
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { livesEducationActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(4200))
            withAnimation(.easeOut(duration: 0.4)) { livesEducationActive = false }
        }
    }

    private func mixAgainAfterGate() {
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            game.newGame()
            Analytics.runStarted(.zombie, level: "run", tutorial: coachActive)
            checkedBits = []
            mintedThisRun = 0
            spendBreakIndex = nil
            playSpendBreak = false
            persist()
        }
    }

    #if DEBUG
    /// Dev hook (TIKI_AUTOPLAY=1): random-weighted swipes until game over,
    /// for screenshot verification runs. TIKI_AUTOPLAY_MS overrides the
    /// move cadence (default 120) — slower runs read better on film.
    private func autoplay() async {
        let moves: [ZombieGame.Direction] = [.down, .left, .down, .right, .left, .down]
        let interval = ProcessInfo.processInfo.environment["TIKI_AUTOPLAY_MS"]
            .flatMap(Int.init) ?? 120
        while !game.isOver {
            try? await Task.sleep(for: .milliseconds(interval))
            swipe(moves.randomElement() ?? .down)
        }
        print("[autoplay] zombie over score=\(game.score) maxTier=\(game.tiles.map(\.tier).max() ?? 0)")
    }
    #endif

    // MARK: board

    private func board(_ size: CGSize) -> some View {
        let side: CGFloat = min(size.width * 0.92, size.height * 0.44)
        let gap: CGFloat = side * 0.025
        let cell: CGFloat = (side - gap * 5) / 4
        let originX: CGFloat = (size.width - side) / 2
        // The wall zone between the scene's shelf (~0.33h) and counter (0.78h).
        let originY: CGFloat = size.height * 0.545 - side / 2

        func center(_ col: Int, _ row: Int) -> CGPoint {
            CGPoint(
                x: originX + gap + cell / 2 + CGFloat(col) * (cell + gap),
                y: originY + gap + cell / 2 + CGFloat(row) * (cell + gap)
            )
        }

        /// Center-on-finger aiming (tap or drag): the 2×2 rides with the
        /// touch, anchor clamped onto the board, so the touched cell always
        /// sits inside the square.
        func aim(_ location: CGPoint, fast: Bool) {
            let colF = (location.x - originX) / side * 4
            let rowF = (location.y - originY) / side * 4
            let c = min(max(Int((colF - 1).rounded()), 0), 2)
            let r = min(max(Int((rowF - 1).rounded()), 0), 2)
            guard c != bombAnchor.col || r != bombAnchor.row else { return }
            withAnimation(.spring(duration: fast ? 0.15 : 0.25, bounce: fast ? 0.15 : 0.3)) {
                bombAnchor = (c, r)
            }
        }

        return ZStack {
            RoundedRectangle(cornerRadius: side * 0.045)
                .fill(P.woodDark.color)
                .frame(width: side, height: side)
                .position(x: size.width / 2, y: originY + side / 2)
                .overlay(
                    RoundedRectangle(cornerRadius: side * 0.045)
                        .stroke(P.ink.color, lineWidth: 2)
                        .frame(width: side, height: side)
                        .position(x: size.width / 2, y: originY + side / 2)
                )
            ForEach(0..<16, id: \.self) { i in
                RoundedRectangle(cornerRadius: cell * 0.16)
                    .fill(P.shadowBrown.color.opacity(0.55))
                    .frame(width: cell, height: cell)
                    .position(center(i % 4, i / 4))
            }
            ForEach(game.tiles) { tile in
                ZombieTileView(
                    tile: tile,
                    cell: cell,
                    pulsed: game.justMerged.contains(tile.id)
                )
                .position(center(tile.col, tile.row))
                .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
            if let tier = game.lastMergedTier, tier >= 6 {
                ForEach(game.tiles.filter { game.justMerged.contains($0.id) }) { tile in
                    ZombieBurst()
                        .frame(width: cell * 1.2, height: cell * 1.2)
                        .position(center(tile.col, tile.row))
                        .id("\(game.gainBeat)-\(tile.id)")
                        .allowsHitTesting(false)
                }
            }
            if game.lastGain > 0 {
                GainPopup(text: "+\(game.lastGain)", big: game.lastGain >= 128)
                    .position(x: size.width / 2, y: originY - 14)
                    .id(game.gainBeat)
            }
            if !game.lastBombedCells.isEmpty {
                ForEach(Array(game.lastBombedCells.enumerated()), id: \.offset) { i, c in
                    ZombieBurst()
                        .frame(width: cell * 1.3, height: cell * 1.3)
                        .position(center(c.col, c.row))
                        .id("bomb-\(game.bombBeat)-\(i)")
                        .allowsHitTesting(false)
                }
            }
            if coachActive, !game.isOver, !roundTransitioning {
                let positions = ZombieGame.tutorialTilePositions(round: tutorialRound)
                if positions.count >= 2 {
                    let a = positions[0]
                    let b = positions[1]
                    CoachPulse(skin: .zombie, diameter: cell * 1.08)
                        .position(center(a.col, a.row))
                    CoachPulse(skin: .zombie, diameter: cell * 1.08)
                        .position(center(b.col, b.row))
                    // Down-arrow BETWEEN the two stacked same-tier tiles —
                    // pulse/arrow/card read as one visual sentence.
                    CoachArrow(skin: .zombie, direction: .down, size: 20)
                        .position(x: center(a.col, a.row).x, y: (center(a.col, a.row).y + center(b.col, b.row).y) / 2)
                }
                if tutorialRound == ZombieGame.tutorialSwipeTeachRound {
                    // The atom of the final beat is the drag itself, so the
                    // cue rides at board center and sweeps left↔right — a
                    // one-glance answer to "what do I do now?" once the
                    // scripted merges are behind us.
                    TutorialSwipeCue(skin: .zombie, boardWidth: side)
                        .position(x: size.width / 2, y: originY + side / 2)
                        .allowsHitTesting(false)
                }
            }
            if bombTargeting {
                // Scrim knocks the board back so the reticle owns the eye;
                // taps pass through it to the aiming gesture below.
                RoundedRectangle(cornerRadius: side * 0.045)
                    .fill(P.ink.color.opacity(0.42))
                    .frame(width: side, height: side)
                    .position(x: size.width / 2, y: originY + side / 2)
                    .allowsHitTesting(false)
                let a = center(bombAnchor.col, bombAnchor.row)
                let b = center(bombAnchor.col + 1, bombAnchor.row + 1)
                let reticleSide = cell * 2 + gap
                RoundedRectangle(cornerRadius: cell * 0.2)
                    .fill(P.torch.color.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: cell * 0.2).stroke(P.torch.color, lineWidth: 3))
                    .frame(width: reticleSide, height: reticleSide)
                    .position(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                    .shadow(color: P.torch.color.opacity(0.8), radius: 10)
                    .allowsHitTesting(false)
                Text("TAP TO AIM — CLEARS 2×2")
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.torch.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(P.ink.color.opacity(0.7)))
                    .position(x: size.width / 2, y: originY - 16)
                    .allowsHitTesting(false)
                Button(action: dropBomb) {
                    Text("DROP IT")
                        .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                        .tracking(2.5)
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(P.torch.color.opacity(bombTargetCount == 0 ? 0.4 : 1)))
                }
                .buttonStyle(SoftPressStyle())
                .disabled(bombTargetCount == 0)
                .position(x: size.width / 2, y: originY + side + 34)
            }
        }
        .offset(nudge)
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .local) { location in
            guard bombTargeting,
                  location.x >= originX, location.x <= originX + side,
                  location.y >= originY, location.y <= originY + side else { return }
            aim(location, fast: false)
        }
        .gesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    // Targeting: the square is draggable, not just tappable —
                    // it tracks the finger live.
                    guard bombTargeting else { return }
                    aim(value.location, fast: true)
                }
                .onEnded { value in
                    if bombTargeting {
                        aim(value.location, fast: true)
                        return
                    }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy) {
                        swipe(dx > 0 ? .right : .left)
                    } else {
                        swipe(dy > 0 ? .down : .up)
                    }
                }
        )
    }

    /// Tiles under the reticle right now — DROP IT disables on an empty
    /// target so the charge can't be wasted on air.
    private var bombTargetCount: Int {
        game.tiles.filter {
            (bombAnchor.col...bombAnchor.col + 1).contains($0.col)
                && (bombAnchor.row...bombAnchor.row + 1).contains($0.row)
        }.count
    }

    private func dropBomb() {
        guard bombTargeting, store.zombieBombs > 0 else { return }
        var cleared = 0
        withAnimation(.spring(duration: 0.32, bounce: 0.22)) {
            cleared = game.detonate(col: bombAnchor.col, row: bombAnchor.row)
        }
        guard cleared > 0 else { return }
        _ = store.spendZombieBomb()
        zombieHaptic.impactOccurred()
        TikiSound.shared.clear(intensity: 4)
        withAnimation(.spring(duration: 0.3, bounce: 0.25)) { bombTargeting = false }
        persist()
    }

    /// The one-time comp: the first time any run hits the danger zone, Vic
    /// slides one Depth Charge down the bar — chip pops in, toast says so.
    private func offerBombCompIfNeeded() {
        guard !store.zombieBombGranted, !coachActive else { return }
        var granted = false
        withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
            granted = store.grantZombieBombIfNeeded()
        }
        guard granted else { return }
        mergeHaptic.impactOccurred()
        TikiSound.shared.tick()
        withAnimation(.spring(duration: 0.35, bounce: 0.4)) { bombCompActive = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(3200))
            withAnimation(.easeOut(duration: 0.3)) { bombCompActive = false }
        }
    }

    private var highestTier: Int {
        game.tiles.map(\.tier).max() ?? 1
    }

    /// Bar-wall ladder: DUSK BLINDS tier 5 / NIGHT NEON 7 / VOLCANO WATCH 9 / THE ZOMBIE 11.
    /// tier = shelf stock, 1 + deepest drink ever mixed (lifetime, via loreSeen).
    private var scenePhase: ProgressPhase {
        ProgressPhase(
            stage: [5, 7, 9, 11].filter { highestTier >= $0 }.count,
            depth: min(1, max(0, Double(highestTier - 3) / 8)),
            tier: min(12, 1 + (game.loreSeen.max() ?? 0)),
            beat: game.gainBeat
        )
    }
}

/// Burst star for big merges (tier 6+): the Tiki Stacks clear-spectacle
/// pattern, fired at the merged tile's cell.
private struct ZombieBurst: View {
    @State private var shown = false
    @State private var faded = false

    var body: some View {
        Image.fxBurst
            .resizable()
            .scaledToFit()
            .scaleEffect(shown ? (faded ? 1.3 : 1) : 0.1)
            .opacity(faded ? 0 : (shown ? 1 : 0))
            .rotationEffect(.degrees(shown ? 18 : -20))
            .onAppear {
                withAnimation(.spring(duration: 0.28, bounce: 0.4)) { shown = true }
                withAnimation(.easeOut(duration: 0.4).delay(0.3)) { faded = true }
            }
    }
}

/// Floating "+N" that rises off the board on every scoring swipe — the
/// Tiki Stacks popup pattern, gold and drop-shadowed, bigger for big merges.
private struct GainPopup: View {
    let text: String
    let big: Bool
    @State private var risen = false

    var body: some View {
        ZStack {
            Text(text)
                .offset(x: 2, y: 2)
                .foregroundStyle(P.ink.color.opacity(0.9))
            Text(text)
                .foregroundStyle(Color(red: 0.910, green: 0.702, blue: 0.235))
        }
        .font(.custom("Futura-Bold", size: big ? 30 : 22))
        .tracking(1)
        .scaleEffect(risen ? (big ? 1.15 : 1.0) : 0.5)
        .offset(y: risen ? -44 : 0)
        .opacity(risen ? 0 : 1)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { risen = true }
        }
        .allowsHitTesting(false)
    }
}

/// One drink tile: catalog art + a small value chip, with a merge pulse.
private struct ZombieTileView: View {
    let tile: ZombieGame.Tile
    let cell: CGFloat
    let pulsed: Bool
    @State private var pulse = false

    var body: some View {
        Image.zombieTile(tile.tier)
            .resizable()
            .scaledToFit()
            .frame(width: cell, height: cell)
            .overlay(alignment: .bottom) {
                Text("\(1 << tile.tier)")
                    .font(.custom("Futura-Bold", size: cell * 0.16))
                    .foregroundStyle(P.blossom.color)
                    .padding(.horizontal, cell * 0.09)
                    .padding(.vertical, cell * 0.025)
                    .background(Capsule().fill(P.ink.color.opacity(0.7)))
                    .offset(y: cell * 0.045)
            }
            .scaleEffect(pulse ? 1.14 : 1.0)
            .onChange(of: pulsed) { _, newValue in
                guard newValue else { return }
                withAnimation(.spring(duration: 0.16, bounce: 0.5)) { pulse = true }
                withAnimation(.spring(duration: 0.22, bounce: 0.3).delay(0.16)) { pulse = false }
            }
    }
}

#Preview {
    ZombieView()
        .environment(PlayerStore(inMemory: true))
}
