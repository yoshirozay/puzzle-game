import SwiftUI
import StoreKit

/// The Lounge — the app's meta-game room. A mid-century tiki bar interior that
/// starts nearly empty (Vic behind the bar, breathing coral wall) and fills
/// with life as catalog items are purchased. Anchors re-compose the 680x440
/// LoungeScene hero illustration for portrait; purchased items render on
/// `isPlaced` and pop in with a spring. Single TimelineView clock, flat fills
/// only, shared palette P.* from TikiScenery.
struct LoungeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @Environment(PlayerStore.self) private var store
    @State private var model = LoungeModel()
    /// The lounge's first-run coach state, or nil when dismissed / never fired.
    /// `.shop` teaches the SHOP tap; `.buy` teaches the welcome BUY tap. Both
    /// beats are the same atom ("acquire an item"), broken across the shop's
    /// two-tap flow. Silent dismissal on success (rubric §7).
    @State private var coachStep: LoungeCoachStep? = nil
    /// Runs the first-appear gate exactly once per view instance so re-entries
    /// from the picker don't retrigger the coach mid-session.
    @State private var didStartCoach = false
    /// Fires after a successful coach dismiss so "welcome home" reads even
    /// through Vic's burst and the closing shop panel (SKIP dismisses silently).
    @State private var readyBannerActive = false
    /// One-shot "hold to move" hint after the first real purchase (§6.5).
    @State private var moveHintActive = false
    /// Item id currently doing the move-hint demo hop (nil between hops).
    @State private var moveHintWiggle: String? = nil
    /// One-shot toast the first time patrons are visibly seated on player
    /// furniture (couch at standing tier ≥1, tall table at ≥2) — the
    /// LOUNGE_V2_PLAN Stage F "regulars found the good seats" beat.
    @State private var regularsToastActive = false
    @State private var expandToastActive = false
    /// Vic's round: the reward he poured this visit (Nightly Nine payoff) —
    /// drives the world-space beat at his hand, caption and all.
    @State private var dailyReward: PlayerStore.NightlyReward? = nil
    /// World-clock stamp of that pour, so Vic's tilt can be derived from `t`
    /// instead of held as state inside a view the room re-inits every frame.
    @State private var dailyRewardStart: TimeInterval? = nil
    /// THE NIGHTLY NINE board card (opened by tapping Vic).
    @State private var missionsOpen = false
    /// One `lounge:decorate:move` per visit, not per drag end (§5.3.1).
    /// Also covers the window and rug cycles — the question D-14 asks is
    /// "does this player arrange at all", not how many times.
    @State private var decorated = false
    /// One-shot "tap Vic" discovery toast — the board has no chrome entry,
    /// so the room has to say once where it lives.
    @State private var nightlyHintActive = false
    /// The message bottle's current note (nil = no card). Notes rotate in
    /// order so a curious tapper eventually reads them all.
    @State private var bottleNote: String? = nil
    private static let bottleNotes = [
        "WISH YOU WERE HERE — NOBODY",
        "THE DOOR'S ALWAYS OPEN",
        "SEND MORE ICE",
        "S.O.S. — SOMEBODY ORDER SOMETHING",
        "IT'S FIVE O'CLOCK DOWN HERE",
        "P.S. THE CAT SAW EVERYTHING",
    ]
    private static let bottleNoteKey = "tikiBottleNoteIndex"

    /// Bottle tap: surface the next note for a few seconds. Stays out of
    /// the way while the coach or move hint is talking.
    private func showBottleNote() {
        Analytics.design("lounge:bottle")
        guard coachStep == nil, !moveHintActive else { return }
        let i = UserDefaults.standard.integer(forKey: Self.bottleNoteKey)
        UserDefaults.standard.set(i + 1, forKey: Self.bottleNoteKey)
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
            bottleNote = Self.bottleNotes[i % Self.bottleNotes.count]
        }
        Task {
            try? await Task.sleep(for: .seconds(3.5))
            withAnimation(.easeOut(duration: 0.4)) { bottleNote = nil }
        }
    }
    @State private var tidyConfirm = false
    /// When a ghost item is tapped, the shop opens scrolled to its row.
    @State private var shopScrollTarget: String? = nil
    // ".v2": the v1 hint fired once on the first-ever purchase and was gone
    // in 6 s — live saves consumed it and the drag affordance stayed secret
    // (device round 2026-07-16). Bumping the key re-teaches everyone once,
    // now with a demo hop and a room-entry fallback for furnished rooms.
    private static let moveHintKey = "tikiMoveHintSeen.v2"
    private static let regularsToastKey = "tikiRegularsToastSeen"
    private static let nightlyHintKey = "tikiNightlyHintSeen"

    /// Pieces the hold-to-move gesture actually works on — everything but
    /// the fixed fixtures (gift mug, counter drink, shelf, windows, parrot,
    /// fan). The move hint keys off this set.
    private static let movableIDs: Set<String> = [
        "cornerFronds", "palmPlant", "glassFloat", "tikiStatue",
        "blowfishLamp", "recordCredenza", "martiniWoman", "highballMan",
        "suspiciousCat", "barStools", "marlin", "neonTikiSign", "aquarium",
        "plantBush", "plantSnake", "plantTiered", "loungeRug", "highTable",
        "grandPiano", "loungeCouch",
    ]
    private let buyHaptic = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        let placed = store.placedItemIDs
        // Earned trophy, never sold: THE ZOMBIE mug lands on the credenza once
        // Zombie milestone bit 7 (board tier 11) is ever recorded.
        let zombieTrophy = store.record(for: .zombie).milestoneMask & (1 << 7) != 0
        let standing = store.houseStanding
        let fishCount = store.aquariumFish
        GeometryReader { geo in
            // Lounge v2 (LOUNGE_V2_PLAN §3): the room is a 2.2-screen world in
            // a horizontal pan; the camera opens on the bar at the east end.
            // Chrome, shop, and coach stay screen-fixed (FTUE targets them).
            let worldSize = CGSize(width: geo.size.width * LoungeRoomView.worldScreens, height: geo.size.height)
            ZStack {
                // Room-matched bands behind the scroll: horizontal
                // overscroll stretches into more room, never a foreign
                // color flash (device round 2 — a flat rum bed read as a
                // background leak at the rubber-band edges).
                VStack(spacing: 0) {
                    P.lagoon.color.frame(height: geo.size.height * 0.388)
                    P.ink.color.frame(height: geo.size.height * 0.012)
                    P.coral.color
                    P.ink.color.frame(height: geo.size.height * 0.012)
                    P.driftwood.color.frame(height: geo.size.height * 0.208)
                }
                .ignoresSafeArea()
                ScrollViewReader { scroll in
                    ScrollView(.horizontal, showsIndicators: false) {
                        // 30 fps cap on the ambient clock (grand retune): the
                        // room's full-world Canvases doubled in raster area,
                        // and redrawing 6+ world-wide layers at the display's
                        // 120 Hz starved the main thread — pans stuttered and
                        // touches registered late on device. Breath, sway,
                        // and flicker read identically at 30; the native
                        // scroll keeps its full frame rate.
                        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                            LoungeRoomView(
                                t: context.date.timeIntervalSinceReferenceDate,
                                size: worldSize,
                                placed: placed,
                                justPlaced: model.justPlaced,
                                zombieTrophy: zombieTrophy,
                                standing: standing,
                                standingTier: store.houseStandingTier,
                                aquariumFish: fishCount,
                                windowEast: store.windowViewEast,
                                windowWest: store.windowViewWest,
                                rugColorway: store.rugColorway,
                                positions: store.itemPositions,
                                depths: store.itemDepths,
                                cycleWindow: cycleWindow(east:),
                                cycleRug: cycleRug,
                                commitPlacement: { id, cx, depth in
                                    // Latched: commitPlacement fires on EVERY
                                    // drag end, and a rearranging session is
                                    // 50+ of them (§5.3.1).
                                    if !decorated {
                                        decorated = true
                                        Analytics.design("lounge:decorate:move")
                                    }
                                    withAnimation(.spring(duration: 0.4, bounce: 0.35)) {
                                        store.setItemPosition(id, cx: cx)
                                        store.setItemDepth(id, depth: depth)
                                    }
                                    if moveHintActive {
                                        withAnimation(.easeOut(duration: 0.3)) { moveHintActive = false }
                                    }
                                },
                                openShop: openShopScrolled,
                                coachWelcomeActive: coachStep == .shop,
                                wiggleID: moveHintWiggle,
                                dailyPour: dailyReward,
                                dailyPourStart: dailyRewardStart,
                                bottleTapped: showBottleNote,
                                nightlyReady: nightlyReady,
                                nightlyDone: store.nightlyCompleted,
                                vicTapped: openMissions
                            )
                        }
                        .frame(width: worldSize.width, height: worldSize.height)
                        .animation(.spring(duration: 0.55, bounce: 0.5), value: placed)
                    }
                    .defaultScrollAnchor(.trailing)
                    .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                    // A fresh purchase west of the camera scrolls into view
                    // before its burst fires — the room shows what you bought.
                    .onChange(of: model.justPlaced) { _, id in
                        guard let id else { return }
                        withAnimation(.easeInOut(duration: 0.45)) {
                            scroll.scrollTo("scroll-\(id)", anchor: .center)
                        }
                    }
                    .onAppear {
                        var cameraStaged = false
                        #if DEBUG
                        // Staging hooks: SIMCTL_CHILD_TIKI_LOUNGE_ZONE=west|mid
                        // parks the camera; SIMCTL_CHILD_TIKI_BUY_LATE=<id>
                        // purchases 2 s after appear so the live purchase path
                        // (auto-scroll + burst) can be screenshot-verified.
                        let env = ProcessInfo.processInfo.environment
                        cameraStaged = env["TIKI_LOUNGE_ZONE"] != nil
                        if let zone = env["TIKI_LOUNGE_ZONE"] {
                            // After initial layout — defaultScrollAnchor
                            // re-asserts trailing on the first pass and races
                            // an immediate scrollTo.
                            Task {
                                try? await Task.sleep(for: .milliseconds(400))
                                // .center for all zones: the 1x1 markers sit
                                // at 0.02/0.5/0.98, so west clamps to the wall
                                // — same framing the old .leading produced.
                                scroll.scrollTo("zone-\(zone)", anchor: .center)
                            }
                        }
                        if let id = env["TIKI_BUY_LATE"] {
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                // Mirror buy(_:) so the live purchase path
                                // (justPlaced -> auto-scroll + burst) runs.
                                if store.purchase(id) { model.justPlaced = id }
                            }
                        }
                        // SIMCTL_CHILD_TIKI_LOUNGE_PAN=<seconds-per-leg>
                        // glides the camera east -> west -> east for preview
                        // capture: 1400 ms settle/poster hold, linear sweep
                        // west, 600 ms turnaround dwell, linear sweep home —
                        // ending where it started so the loop seam is clean.
                        if let secs = env["TIKI_LOUNGE_PAN"].flatMap(Double.init) {
                            cameraStaged = true
                            Task {
                                try? await Task.sleep(for: .milliseconds(1400))
                                withAnimation(.linear(duration: secs)) {
                                    scroll.scrollTo("zone-west", anchor: .center)
                                }
                                try? await Task.sleep(for: .seconds(secs) + .milliseconds(600))
                                withAnimation(.linear(duration: secs)) {
                                    scroll.scrollTo("zone-east", anchor: .center)
                                }
                            }
                        }
                        // SIMCTL_CHILD_TIKI_GHOST_TAP=<id> mirrors tapping
                        // that ghost 1 s after appear (simctl can't tap).
                        if let id = env["TIKI_GHOST_TAP"] {
                            Task {
                                try? await Task.sleep(for: .seconds(1))
                                openShopScrolled(to: id)
                            }
                        }
                        // SIMCTL_CHILD_TIKI_WINDOW=east:<view>,west:<view> and
                        // SIMCTL_CHILD_TIKI_RUG=<0-3> stage expression prefs.
                        if let raw = env["TIKI_WINDOW"] {
                            for pair in raw.split(separator: ",") {
                                let parts = pair.split(separator: ":")
                                if parts.count == 2 {
                                    store.setWindowView(String(parts[1]), east: parts[0] == "east")
                                }
                            }
                        }
                        if let raw = env["TIKI_RUG"], let i = Int(raw) {
                            store.setRugColorway(i)
                        }
                        // SIMCTL_CHILD_TIKI_PLACE=<id>:<cx>,... stages drag
                        // placements; SIMCTL_CHILD_TIKI_TIDY=1 resets them.
                        if let raw = env["TIKI_PLACE"] {
                            for pair in raw.split(separator: ",") {
                                let parts = pair.split(separator: ":")
                                if parts.count == 2, let cx = Double(parts[1]) {
                                    store.setItemPosition(String(parts[0]), cx: cx)
                                }
                            }
                        }
                        if env["TIKI_TIDY"] == "1" {
                            store.resetPlacements()
                        }
                        // SIMCTL_CHILD_TIKI_PROPORTION_AUDIT=1 prints the
                        // room's proportion proof (see runProportionAudit).
                        if env["TIKI_PROPORTION_AUDIT"] == "1" {
                            LoungeRoomView.runProportionAudit()
                        }
                        // Staging: SIMCTL_CHILD_TIKI_NIGHTLY=<n> stamps a
                        // fresh board with n challenges done (4+ lights Vic's
                        // glow), clears tonight's claim, empties comp slots,
                        // and suppresses the coach + discovery toast.
                        if let raw = env["TIKI_NIGHTLY"], let n = Int(raw) {
                            store.debugStageNightly(done: n)
                            store.loungeOnboardingSeen = true
                            coachStep = nil
                            UserDefaults.standard.set(true, forKey: Self.nightlyHintKey)
                        }
                        // Staging: SIMCTL_CHILD_TIKI_NIGHTLY_OPEN=1 opens the
                        // board card after a beat (simctl can't tap Vic).
                        if env["TIKI_NIGHTLY_OPEN"] == "1" {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(900))
                                openMissions()
                            }
                        }
                        // Staging: SIMCTL_CHILD_TIKI_NIGHTLY_CLAIM=1 fires the
                        // claim beat (pair with TIKI_NIGHTLY=4 — simctl can't
                        // tap POUR THE ROUND). For the rating ask: also set
                        // TIKI_RATING_POURS=2 so this claim is the third.
                        if env["TIKI_NIGHTLY_CLAIM"] == "1" {
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(1600))
                                claimAndPour()
                            }
                        }
                        #endif
                        // One-time discovery beat (LOUNGE_V2_PLAN §3.4): once
                        // the west wing has something to show, the camera
                        // drifts toward it and settles back — the room itself
                        // says "there's more this way". No tutorial card.
                        // Skipped while the coach or shop owns the moment,
                        // under reduceMotion, and when staging parks the
                        // camera (screenshots stay reproducible).
                        if !cameraStaged, !reduceMotion,
                           !store.loungePanHintShown, westHasContent {
                            Task {
                                try? await Task.sleep(for: .milliseconds(900))
                                guard coachStep == nil, !model.shopOpen else { return }
                                store.loungePanHintShown = true
                                #if DEBUG
                                print("[lounge] discovery drift fired")
                                #endif
                                withAnimation(.easeInOut(duration: 0.9)) {
                                    scroll.scrollTo("zone-hint", anchor: .center)
                                }
                                try? await Task.sleep(for: .milliseconds(1500))
                                withAnimation(.easeInOut(duration: 0.7)) {
                                    scroll.scrollTo("zone-east", anchor: .center)
                                }
                            }
                        }
                        // Patrons may have arrived while the player was off
                        // earning standing — give the room a beat to settle,
                        // then let Vic note it once. 2600 ms lands AFTER the
                        // move-hint room-entry fallback (1500 ms) so the
                        // moveHintActive guard can defer to the next visit
                        // instead of stacking two messages.
                        Task {
                            try? await Task.sleep(for: .milliseconds(2600))
                            maybeShowRegularsToast()
                        }
                    }
                }
                LoungeChrome(
                    coachOnShop: coachStep == .shop,
                    canAffordNewItem: store.canAffordNewItem,
                    onOpenShop: {
                        withAnimation(.spring(duration: 0.35, bounce: 0.3)) { model.shopOpen = true }
                    }
                )
                if model.shopOpen {
                    LoungeShopPanel(
                        size: geo.size,
                        coachOnBuy: coachStep == .buy,
                        shopScrollTarget: shopScrollTarget,
                        tidyConfirm: $tidyConfirm,
                        onClose: {
                            withAnimation(.spring(duration: 0.35, bounce: 0.3)) { model.shopOpen = false }
                        },
                        onBuy: { buy($0) }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                }
                if let step = coachStep {
                    CoachCard(
                        message: coachMessage(for: step),
                        skin: .lounge,
                        onSkip: { dismissCoach(withSuccess: false) },
                        // The SHOP beat's card names the mug — tapping the
                        // card is as good as tapping SHOP.
                        onTap: step == .shop
                            ? { openShopScrolled(to: PlayerStore.welcomeGiftItemID) }
                            : nil
                    )
                }
                if readyBannerActive {
                    TutorialReadyBanner(message: "WELCOME HOME", skin: .lounge) {
                        readyBannerActive = false
                    }
                }
                if regularsToastActive {
                    // 232 cleared the points + SHOP + TONIGHT column when
                    // there were three capsules; the TONIGHT chip is gone
                    // (Vic is the board's door now) but the band stays —
                    // verified against staged screenshots.
                    MilestoneToast(message: "THE REGULARS FOUND THE GOOD SEATS", fontSize: 13)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 232)
                        .allowsHitTesting(false)
                }
                if nightlyHintActive {
                    MilestoneToast(message: "DAILY GOALS · TAP VIC", fontSize: 13)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 232)
                        .allowsHitTesting(false)
                }
                if expandToastActive {
                    MilestoneToast(message: "PLAY THE GAMES TO EXPAND YOUR LOUNGE", fontSize: 13)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .padding(.top, 232)
                        .allowsHitTesting(false)
                }
                if missionsOpen {
                    LoungeMissionsPanel(
                        size: geo.size,
                        nightlyReady: nightlyReady,
                        onClaimAndPour: claimAndPour,
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.25)) { missionsOpen = false }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(40)
                }
                if moveHintActive {
                    CoachCard(
                        message: "HOLD TO MOVE ANY PIECE — DRAG DOWN TO PULL IT CLOSER",
                        skin: .lounge,
                        onSkip: { withAnimation(.easeOut(duration: 0.3)) { moveHintActive = false } }
                    )
                }
                if let note = bottleNote {
                    CoachCard(
                        message: note,
                        skin: .lounge,
                        onSkip: { withAnimation(.easeOut(duration: 0.3)) { bottleNote = nil } }
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear(perform: startCoachIfNeeded)
        .onChange(of: coachStep) { was, now in
            // Fires once, when the lounge coach actually appears.
            if was == nil, now != nil { Analytics.progression(.start, "coach", "lounge") }
        }
        .onAppear {
            Analytics.design("lounge:open")

            Analytics.entered("lounge")
            decorated = false
        }
        // App playtime minus the sum of every `time:*` is the menu residual —
        // the slice nobody measures (ANALYTICS_PLAN §5.3.2).
        .onDisappear { Analytics.exited("lounge") }
        // Room-entry fallback for the move hint: a furnished room whose
        // owner has never seen the (v2) hint gets it once here — the buy()
        // path only reaches players who are about to make their FIRST
        // purchase, which live saves are long past (device round).
        .task {
            try? await Task.sleep(for: .milliseconds(1500))
            guard !UserDefaults.standard.bool(forKey: Self.moveHintKey),
                  coachStep == nil, !model.shopOpen,
                  !store.placedItemIDs.intersection(Self.movableIDs).isEmpty
            else { return }
            UserDefaults.standard.set(true, forKey: Self.moveHintKey)
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { moveHintActive = true }
            await wiggleDemo()
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.4)) { moveHintActive = false }
        }
        // Vic's round is claimed by hand now: with four of the Nightly Nine
        // done and unclaimed he glows behind the bar, and POUR THE ROUND on
        // his board card plays the beat. Entry only refreshes the mirrors
        // (the day may have rolled while the app idled) and — once ever —
        // points at him. 3600 ms lands after the entry beats (move hint
        // 1500, regulars 2600); anything still talking defers the hint to
        // the next visit rather than stacking.
        .task {
            store.refreshNightlyMirrors()
            try? await Task.sleep(for: .milliseconds(3600))
            guard !Task.isCancelled,
                  !UserDefaults.standard.bool(forKey: Self.nightlyHintKey),
                  coachStep == nil, !readyBannerActive, !model.shopOpen,
                  !missionsOpen, !regularsToastActive, !expandToastActive,
                  !moveHintActive, dailyReward == nil
            else { return }
            UserDefaults.standard.set(true, forKey: Self.nightlyHintKey)
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { nightlyHintActive = true }
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.5)) { nightlyHintActive = false }
        }
        #if DEBUG
        // SIMCTL_CHILD_TIKI_FTUE_AUTO=1 drives the welcome flow's two taps
        // (simctl can't tap): the coach card's onTap, then the mug's BUY
        // through the real buy() path — banner and expand-toast included.
        .task {
            guard ProcessInfo.processInfo.environment["TIKI_FTUE_AUTO"] == "1" else { return }
            try? await Task.sleep(for: .milliseconds(1500))
            if coachStep == .shop { openShopScrolled(to: PlayerStore.welcomeGiftItemID) }
            try? await Task.sleep(for: .milliseconds(1500))
            if coachStep == .buy,
               let mug = store.loungeItems.first(where: { $0.itemID == PlayerStore.welcomeGiftItemID }) {
                buy(mug)
            }
        }
        #endif
        // Opening the shop clears beat 1 — advance to teaching BUY.
        .onChange(of: model.shopOpen) { _, open in
            if open, coachStep == .shop {
                withAnimation(.easeInOut(duration: 0.25)) { coachStep = .buy }
            }
            // A ghost-tap target is one entry deep — closing forgets it.
            if !open { shopScrollTarget = nil }
        }
        // Placing the welcome mug (whether coached or discovered post-skip)
        // retracts the coach silently with a positive audio cue.
        .onChange(of: store.placedItemIDs) { _, ids in
            if ids.contains(PlayerStore.welcomeGiftItemID), coachStep != nil {
                dismissCoach(withSuccess: true)
            }
        }
    }

    /// Tap an owned window to cycle its live view through the EARNED set
    /// (sunset always; beach/volcano/glow tide unlock at top depth states).
    private func cycleWindow(east: Bool) {
        Analytics.design("lounge:decorate:window")
        decorated = true
        let unlocked = WindowViewKind.unlocked(mask: store.combinedMilestoneMask)
        guard unlocked.count > 1 else { return }
        let current = WindowViewKind(rawValue: east ? store.windowViewEast : store.windowViewWest) ?? .sunset
        let idx = unlocked.firstIndex(of: current) ?? 0
        store.setWindowView(unlocked[(idx + 1) % unlocked.count].rawValue, east: east)
    }

    /// Tap the owned rug to cycle its colorway — free, unlimited, expression.
    private func cycleRug() {
        Analytics.design("lounge:decorate:rug")
        decorated = true
        store.setRugColorway((store.rugColorway + 1) % 4)
    }

    /// Ghost tap (and TIKI_GHOST_TAP staging): open the shop at an item's
    /// row. During the welcome coach the shop opens unscrolled — the BUY
    /// beat targets the Flaming Mug row at the top and must stay on screen.
    private func openShopScrolled(to id: String) {
        Analytics.design("lounge:shop:open")
        // What the player is saving for but cannot yet afford — the
        // aspiration signal that separates "priced too high" from
        // "invisible in the layout" (ANALYTICS_PLAN §5.2.1).
        if let next = store.nextUnaffordableItemID {
            Analytics.design("lounge:nextup:\(next)")
        }
        if coachStep == nil { shopScrollTarget = id }
        withAnimation(.spring(duration: 0.35, bounce: 0.3)) { model.shopOpen = true }
    }

    /// Items whose designed anchors sit west of the opening frame; owning
    /// any of them (or dragging anything west) gives panning a payoff.
    private static let westWingIDs: Set<String> = [
        "bayWindow", "highTable", "grandPiano", "loungeCouch", "loungeRug",
        "plantSnake", "plantBush", "plantTiered", "marlin", "aquarium",
        "ceilingFan",
    ]
    private var westHasContent: Bool {
        !Self.westWingIDs.isDisjoint(with: store.placedItemIDs)
            || store.itemPositions.values.contains { $0 >= 0 && $0 < 0.5 }
    }

    private func coachMessage(for step: LoungeCoachStep) -> String {
        switch step {
        case .shop: return "GRAB VIC'S WELCOME MUG"
        case .buy: return "ON THE HOUSE"
        }
    }

    private func startCoachIfNeeded() {
        guard !didStartCoach else { return }
        didStartCoach = true
        guard !store.loungeOnboardingSeen else { return }
        // If we arrive with the shop already up (dev hook or an unusual
        // re-entry), skip the SHOP beat — the target moved.
        coachStep = model.shopOpen ? .buy : .shop
    }

    private func dismissCoach(withSuccess: Bool) {
        Analytics.progression(withSuccess ? .complete : .fail, "coach", "lounge")
        guard coachStep != nil else { return }
        withAnimation(.easeOut(duration: 0.3)) { coachStep = nil }
        if withSuccess {
            CoachSkin.lounge.dismissSound.play()
            readyBannerActive = true
        }
        // SKIP used to be a bundle-global clear (rubric §8), silencing every
        // other game's coach too. That is per-game now; the lounge's own
        // seen-flag below is all this needs.
        store.loungeOnboardingSeen = true
    }

    // MARK: chrome helpers

    /// Vic's pour is earned and unclaimed tonight — he glows in the room
    /// and his board card grows the POUR THE ROUND button.
    private var nightlyReady: Bool {
        store.nightlyCompleted >= PlayerStore.nightlyGoal && !store.nightlyRewardClaimed
    }

    /// THE NIGHTLY NINE entry: Vic himself. His tap (and the staging hook)
    /// land here.
    private func openMissions() {
        Analytics.design("lounge:missions:open")
        guard coachStep == nil else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.25)) { missionsOpen = true }
    }

    /// Vic's pour, by hand: let the card clear, claim tonight's round, then
    /// play the handoff — haptic + tick, the reward at his hand, the caption.
    /// After the reward card settles, the only App Store rating ask in the
    /// app may fire (pure due-read; mark stamps regardless of display).
    private func claimAndPour() {
        guard nightlyReady else { return }
        withAnimation(.easeOut(duration: 0.25)) { missionsOpen = false }
        Task { @MainActor in
            // Claim AFTER the card is gone. Granting first re-rendered the
            // board mid-fade: the comp slot it just filled drops out of the
            // pool, so the prize plaque flipped to tomorrow's pour on the way
            // out.
            try? await Task.sleep(for: .milliseconds(400))
            guard let reward = store.claimNightlyReward() else { return }
            buyHaptic.impactOccurred()
            TikiSound.shared.tick()
            dailyRewardStart = Date.timeIntervalSinceReferenceDate
            withAnimation(.spring(duration: 0.4, bounce: 0.35)) { dailyReward = reward }
            AccessibilityNotification.Announcement(reward.pourAnnouncement).post()
            // 2.8 s, not 3.6: the beat itself now runs ~2.6 s (pop, hold,
            // lift) instead of fading out from 0.6 s onward.
            try? await Task.sleep(for: .milliseconds(2800))
            withAnimation(.easeOut(duration: 0.4)) { dailyReward = nil }
            dailyRewardStart = nil
            // One short beat after the card's easeOut — never over the pour.
            try? await Task.sleep(for: .milliseconds(500))
            if store.isRatingAskDue() {
                requestReview()
                store.markRatingAsk()
                Analytics.design("rating:ask")
            }
        }
    }

    /// One-shot: patrons seat themselves on player furniture once house
    /// standing allows (couch occupied at tier ≥1, tall table at ≥2). The
    /// first time that composition is actually on screen, Vic points it out.
    /// Checked on lounge entry and after buying either seat.
    private func maybeShowRegularsToast() {
        guard !UserDefaults.standard.bool(forKey: Self.regularsToastKey),
              coachStep == nil, !model.shopOpen, !moveHintActive else { return }
        let seated = (store.houseStandingTier >= 1 && store.placedItemIDs.contains("loungeCouch"))
            || (store.houseStandingTier >= 2 && store.placedItemIDs.contains("highTable"))
        guard seated else { return }
        UserDefaults.standard.set(true, forKey: Self.regularsToastKey)
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) { regularsToastActive = true }
        AccessibilityNotification.Announcement("The regulars found the good seats").post()
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            withAnimation(.easeOut(duration: 0.5)) { regularsToastActive = false }
        }
    }

    private func buy(_ item: LoungeItem) {
        guard store.purchase(item.itemID) else { return }
        buyHaptic.impactOccurred()
        model.justPlaced = item.itemID
        withAnimation(.spring(duration: 0.4, bounce: 0.3)) { model.shopOpen = false }
        // One-time move hint after the first MOVABLE purchase — the drag
        // affordance is invisible until someone says "hold", and firing on
        // a fixed piece (umbrella drink, windows…) would teach a gesture
        // the player can't yet perform on anything (device round). The
        // card demos itself: the piece just bought hops twice while it
        // reads.
        if Self.movableIDs.contains(item.itemID),
           !UserDefaults.standard.bool(forKey: Self.moveHintKey), coachStep == nil {
            UserDefaults.standard.set(true, forKey: Self.moveHintKey)
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { moveHintActive = true }
            Task {
                await wiggleDemo()
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeOut(duration: 0.4)) { moveHintActive = false }
            }
        }
        // Buying a seat at sufficient standing seats the patrons instantly —
        // fire the regulars toast once the shop's close animation settles.
        if item.itemID == "loungeCouch" || item.itemID == "highTable" {
            Task {
                try? await Task.sleep(for: .milliseconds(900))
                maybeShowRegularsToast()
            }
        }
        // The mug is the FTUE's whole arc — once it's claimed, point at the
        // economy. 3000 ms lands after the WELCOME HOME banner (1400 hold +
        // 400 fade + entry) on the coached path; purchase is once-ever, so
        // the toast needs no one-shot key.
        if item.itemID == PlayerStore.welcomeGiftItemID {
            Task {
                try? await Task.sleep(for: .milliseconds(3000))
                withAnimation(.spring(duration: 0.45, bounce: 0.3)) { expandToastActive = true }
                AccessibilityNotification.Announcement("Play the games to expand your lounge").post()
                try? await Task.sleep(for: .seconds(3.2))
                withAnimation(.easeOut(duration: 0.5)) { expandToastActive = false }
            }
        }
    }

    /// Two little hops on one owned floor piece — the move hint's
    /// demonstration. Prefers the piece just bought; a furnished room
    /// (re-armed hint) hops its statement piece instead.
    private func wiggleDemo() async {
        let order = ["loungeCouch", "grandPiano", "recordCredenza", "highTable",
                     "tikiStatue", "palmPlant", "barStools", "plantSnake",
                     "plantBush", "plantTiered", "suspiciousCat", "loungeRug"]
        guard let id = model.justPlaced
            ?? order.first(where: { store.placedItemIDs.contains($0) })
        else { return }
        for _ in 0..<2 {
            withAnimation(.spring(duration: 0.4, bounce: 0.55)) { moveHintWiggle = id }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(duration: 0.4, bounce: 0.4)) { moveHintWiggle = nil }
            try? await Task.sleep(for: .milliseconds(450))
        }
    }
}

/// Two beats of the lounge's first-run coach: point at SHOP, then at the
/// welcome BUY. The rubric's "one atom" is the compound act of acquiring an
/// item — expressed as two taps because the shop is the atom's grammar.
enum LoungeCoachStep: Equatable {
    case shop
    case buy
}

/// Transient lounge UI state. Lives on an @Observable model, not view @State,
/// so writes from button closures survive view identity changes (gotcha #3).
@Observable
private final class LoungeModel {
    var shopOpen: Bool
    var justPlaced: String?

    init() {
        #if DEBUG
        // Dev hook: SIMCTL_CHILD_TIKI_SHOP=1 opens the shop on launch.
        shopOpen = ProcessInfo.processInfo.environment["TIKI_SHOP"] == "1"
        #else
        shopOpen = false
        #endif
    }
}

#Preview {
    LoungeView()
        .environment(PlayerStore(inMemory: true))
}
