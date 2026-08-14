import SwiftUI
import AVFoundation

/// The Sign Rail (PICKER_SPEC.md): five carved wooden bar signs hang from a
/// continuous bamboo rail across a dark plank wall, each with a routed
/// window playing a live muted gameplay loop. Slide the signs along the
/// rail; tap one and its window expands into the running game. Replaces the
/// old 2x3 grid overlay. Chrome uses the mode-stable P palette; flat fills
/// only — no gradients, no blurs, no soft shadows.
struct GamePickerView: View {
    let onLaunch: (PickerSlot) -> Void
    let onClose: () -> Void
    /// Slot the rail opens on. Cold start is the first GAME (the leaderboard
    /// banner at position 0 is a reveal, not a landing); after a game exit
    /// ContentView passes the slot that launched so the home rail resumes
    /// where the player left off. Applied POST-appear in enter() — the
    /// scrollPosition binding ignores initial state (see the hook comment).
    var initialFocus: PickerSlot = PickerSlot.home

    @Environment(PlayerStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    // Spec §12: at accessibility type sizes the plate and footer bands grow
    // (capped) and the window absorbs the difference.
    @ScaledMetric(relativeTo: .body) private var plateBand: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var footerBand: CGFloat = 64

    @State private var players = PreviewPlayers()
    /// The rail starts on the Lounge card (position 0). Games sit at 1..6.
    /// A deeper `initialFocus` is applied post-appear — seeding it as
    /// initial state moves nothing (scrollPosition only reacts to a change).
    @State private var focused: PickerSlot? = PickerSlot.all[0]
    /// Continuous page position, derived from the rail's scroll offset.
    /// Every position is a game, in TikiGame.pickerOrder.
    @State private var progress: Double = 0
    /// False only while an `initialFocus` past the first card settles —
    /// conceals the pre-jump frame so a return fades in already on the game.
    @State private var railRevealed = false
    @State private var bests: [TikiGame: Int] = [:]
    @State private var savedGames: Set<TikiGame> = []
    /// Item 11: each card's wood takes the palette of the deepest state ever
    /// reached — the picker as a quiet trophy row. Absent = exactly today.
    @State private var depthTints: [TikiGame: RGB] = [:]
    @State private var windowFrames: [TikiGame: CGRect] = [:]
    @State private var fullRect: CGRect = .zero

    // Entry choreography (PICKER_SPEC §7): pre-entry values, animated on
    // appear; Reduce Motion snaps straight to rest.
    @State private var chromeIn = false
    @State private var railSlide: CGFloat = -20
    @State private var carouselShift: CGFloat = 0.5 // unit of card width
    // Seeds the cards visible at rest around the home slot — the banner's
    // edge, the first game, and the second game's edge — so all three drop
    // in on appear.
    @State private var cardDrop: [PickerSlot: CGFloat] =
        Dictionary(uniqueKeysWithValues: PickerSlot.all.prefix(3).map { ($0, -40) })
    @State private var interactive = false

    @State private var kick: [PickerSlot: Double] = [:]
    @State private var pressScale: [PickerSlot: CGFloat] = [:]
    @State private var nudge: CGFloat = 0
    @State private var didSwipe = UserDefaults.standard.bool(forKey: "pickerDidSwipe")
    @State private var launchState: GamePickerLaunchState?
    @State private var chromeVisible = true
    /// Trophy-chip destination: which game's leaderboard overlay is open.
    @State private var leaderboardGame: TikiGame?
    /// The banner card's landing — the boards chooser overlay. A picked
    /// board opens `leaderboardGame` ON TOP of it, so dismissing a board
    /// steps back to the chooser, not the rail.
    @State private var boardsOpen = false
    /// Shared out-of-lives sheet — presented when a defeat-capable game is
    /// launched at 0 lives (picker gate).
    /// Staging hook (SIMCTL_CHILD_TIKI_OUT_OF_LIVES=1): opens the OUT OF LIVES
    /// sheet on appear. That sheet is only reachable by TAPPING a game card while
    /// the pool is empty, and simctl cannot tap — so it was the one panel in the
    /// app that could never be screenshot-verified. DEBUG-only, so it cannot ship.
    #if DEBUG
    @State private var outOfLivesOpen = ProcessInfo.processInfo.environment["TIKI_OUT_OF_LIVES"] == "1"
    #else
    @State private var outOfLivesOpen = false
    #endif

    /// Game that was blocked by the gate — the sheet's PLAY CTA launches it
    /// when a life lands.
    @State private var blockedLaunch: TikiGame?

    /// Extract the current focused game (nil when the lounge is focused).
    private var focusedGame: TikiGame? { focused?.game }

    private let settleHaptic = UIImpactFeedbackGenerator(style: .light)
    private let pressHaptic = UIImpactFeedbackGenerator(style: .medium)


    var body: some View {
        GeometryReader { geo in
            let m = Metrics(
                w: geo.size.width,
                containerH: geo.size.height,
                safeBottom: geo.safeAreaInsets.bottom,
                plateH: max(58, min(plateBand, 74)),
                footerH: max(64, min(footerBand, 76))
            )
            ZStack(alignment: .top) {
                wall
                    .opacity(chromeVisible ? 1 : 0)
                rail(m)
                    .opacity(chromeVisible ? 1 : 0)
                carousel(m)
                    .opacity(launchState == nil || chromeVisible ? 1 : 0)
                GamePickerTopBar(progress: progress)
                    .opacity(chromeIn && chromeVisible ? 1 : 0)
                indicatorStrip(m)
                    .opacity(chromeIn && chromeVisible ? 1 : 0)
                if let state = launchState, let player = players.existing(for: .game(state.game)) {
                    GamePickerLaunchOverlay(state: state, player: player)
                }
                if boardsOpen {
                    LeaderboardPickerPanel(
                        onPick: { g in
                            withAnimation(.easeOut(duration: 0.25)) { leaderboardGame = g }
                        },
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.22)) { boardsOpen = false }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(9)
                }
                if let g = leaderboardGame, let boardTheme = LeaderboardTheme.theme(for: g) {
                    LeaderboardView(theme: boardTheme) {
                        withAnimation(.easeOut(duration: 0.25)) { leaderboardGame = nil }
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }
                if outOfLivesOpen {
                    OutOfLivesSheet(
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                outOfLivesOpen = false
                                blockedLaunch = nil
                            }
                        },
                        onLifeLandedPlay: {
                            let game = blockedLaunch
                            withAnimation(.easeOut(duration: 0.2)) {
                                outOfLivesOpen = false
                                blockedLaunch = nil
                            }
                            if let game { launchGameAfterGate(game) }
                        }
                    )
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(20)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: leaderboardGame)
            .animation(.easeInOut(duration: 0.22), value: boardsOpen)
            .animation(.easeInOut(duration: 0.2), value: outOfLivesOpen)
        }
        // Bounded Dynamic Type: the plate/footer bands scale (capped) and
        // the window absorbs it; past AX1 the plate lockup and the top bar
        // can no longer hold their single lines, so chrome growth stops
        // there (verified: CABANA CIPHER ellipsizes at AX2).
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .allowsHitTesting(interactive && launchState == nil)
        .onAppear(perform: enter)
        .onAppear { Analytics.design("nav:picker:open") }
        .onDisappear { players.teardownAll() }
        .onChange(of: focused) { _, newValue in settle(on: newValue) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if !reduceMotion, launchState == nil { players.focus(focused) }
            } else {
                players.pauseAll()
            }
        }
        // Mid-session flips tear players down to posters immediately.
        .onChange(of: reduceMotion) { _, rm in
            if rm { players.teardownAll() } else { players.focus(focused) }
        }
        .onReceive(
            NotificationCenter.default
                .publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
                .receive(on: DispatchQueue.main)
        ) { _ in powerStateShifted() }
        .onReceive(
            NotificationCenter.default
                .publisher(for: ProcessInfo.thermalStateDidChangeNotification)
                .receive(on: DispatchQueue.main)
        ) { _ in powerStateShifted() }
        .onPreferenceChange(WindowFramesKey.self) { frames in
            // Quantize to a 4pt grid: the idle sway wiggles the global
            // frames ~30x/s, and un-throttled writes would re-evaluate the
            // whole body each tick. ±2pt on the expansion seed is invisible.
            for (game, rect) in frames {
                let q = CGRect(
                    x: (rect.origin.x / 4).rounded() * 4,
                    y: (rect.origin.y / 4).rounded() * 4,
                    width: (rect.width / 4).rounded() * 4,
                    height: (rect.height / 4).rounded() * 4
                )
                if windowFrames[game] != q { windowFrames[game] = q }
            }
        }
        .onPreferenceChange(FullRectKey.self) { fullRect = $0 ?? .zero }
    }

    // MARK: - Wall and rail

    /// Plank wall with vertical seams that whisper toward the incoming
    /// game's accent as the rail scrolls (finger-driven, kept under RM).
    /// Fill is the spec's named fallback — woodDark pulled toward ink so
    /// the plank boards separate from the wall without lightening them.
    private var wall: some View {
        let seam = seamColor
        return ZStack {
            P.woodDark.lerp(P.ink, 0.35).color
            Canvas { ctx, size in
                var x: CGFloat = 32
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: 0, width: 1.5, height: size.height)), with: .color(seam))
                    x += 64
                }
            }
            GeometryReader { g in
                Color.clear.preference(key: FullRectKey.self, value: g.frame(in: .global))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var seamColor: Color {
        // Position 0 is the leaderboard banner (torch gold); 1..N are the
        // games in rail order.
        let accents: [RGB] = PickerSlot.all.map(\.pickerAccent)
        let i = min(Int(progress), accents.count - 1)
        let f = progress - Double(i)
        let blended = accents[i].lerp(accents[min(i + 1, accents.count - 1)], f)
        return P.ink.lerp(blended, 0.40).color.opacity(0.25)
    }

    /// Bamboo rail running off both screen edges — "more down the bar".
    private func rail(_ m: Metrics) -> some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 5)
                .fill(P.driftwood.color)
            Rectangle()
                .fill(P.ink.color)
                .frame(height: 2)
            HStack(spacing: 53) {
                ForEach(0..<9, id: \.self) { _ in
                    Rectangle()
                        .fill(P.shadowBrown.color)
                        .frame(width: 3, height: 10)
                }
            }
        }
        .frame(width: m.w + 40, height: 10)
        .position(x: m.w / 2, y: m.railTop + 5)
        .offset(y: railSlide)
        .opacity(chromeIn ? 1 : 0)
        .accessibilityHidden(true)
    }

    // MARK: - Carousel

    private func carousel(_ m: Metrics) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: m.spacing) {
                // id: \.self so the ForEach's per-item identifier is the
                // PickerSlot value itself — that's what .scrollPosition(id:
                // $focused) binds against (Binding<PickerSlot?>). Without
                // this, ForEach uses PickerSlot.Identifiable.id (String),
                // scrollPosition can't correlate, and both directions of the
                // binding break: user swipes don't update `focused` in sync,
                // and programmatic assignments to `focused` don't scroll —
                // which manifests as the picker's game preview videos never
                // autoplaying when settle() calls players.focus(game).
                ForEach(PickerSlot.all, id: \.self) { slot in
                    signCard(slot, m)
                        .frame(width: m.cardW, height: m.cardH)
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            content
                                // Anchor the shrink to the neighbor's inner
                                // (on-screen) edge so the peek keeps its full
                                // stripe + poster slice; the anchor flips only
                                // at phase 0 where scale is 1.
                                .scaleEffect(
                                    reduceMotion ? 1 : 1 - 0.08 * abs(phase.value),
                                    anchor: UnitPoint(x: phase.value > 0 ? 0 : 1, y: 0)
                                )
                                .opacity(1 - 0.15 * abs(phase.value))
                                // sin(π·phase): zero at rest AND at full peek,
                                // so signs hang straight when settled but sway
                                // through the drag.
                                .rotationEffect(
                                    .degrees(reduceMotion ? 0 : -sin(.pi * phase.value) * 2.5),
                                    anchor: .top
                                )
                        }
                }
            }
            .scrollTargetLayout()
            .background {
                GeometryReader { g in
                    Color.clear.preference(
                        key: RailMinXKey.self,
                        value: g.frame(in: .named("railScroll")).minX
                    )
                }
            }
        }
        .coordinateSpace(name: "railScroll")
        .contentMargins(.horizontal, m.margin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $focused)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: m.cardH)
        .offset(x: carouselShift * m.cardW + nudge, y: m.railTop + 10)
        // Concealed while a deeper return position settles — the player must
        // never glimpse the first card before the post-appear jump lands.
        .opacity(initialFocus == PickerSlot.all[0] || railRevealed ? 1 : 0)
        .onPreferenceChange(RailMinXKey.self) { minX in
            guard let minX else { return }
            progress = min(CGFloat(PickerSlot.all.count - 1), max(0, (m.margin - minX) / (m.cardW + m.spacing)))
        }
    }

    // MARK: - One hanging sign

    private func signCard(_ slot: PickerSlot, _ m: Metrics) -> some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: swayPaused(slot))) { timeline in
            cardBody(slot, m)
                .rotationEffect(
                    .degrees(swayAngle(timeline.date, slot) + (kick[slot] ?? 0)),
                    anchor: .top
                )
        }
        .scaleEffect(pressScale[slot] ?? 1)
        .offset(y: cardDrop[slot] ?? 0)
        .contentShape(Rectangle())
        .onTapGesture { cardTapped(slot) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(slot))
        .accessibilityHint(slot == .lounge
            ? "Double tap to enter the lounge. Swipe up or down with one finger for games."
            : "Double tap to play. Swipe up or down with one finger for more games.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAdjustableAction { direction in
            guard let index = PickerSlot.all.firstIndex(of: slot) else { return }
            let last = PickerSlot.all.count - 1
            let next = direction == .increment ? min(index + 1, last) : max(index - 1, 0)
            guard next != index else {
                AccessibilityNotification.Announcement(
                    direction == .increment ? "Last destination" : "First destination"
                ).post()
                return
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                focused = PickerSlot.all[next]
            }
        }
    }

    private func swayPaused(_ slot: PickerSlot) -> Bool {
        reduceMotion || focused != slot || launchState != nil
    }

    private func swayAngle(_ date: Date, _ slot: PickerSlot) -> Double {
        guard focused == slot, !reduceMotion else { return 0 }
        return 0.6 * sin(date.timeIntervalSinceReferenceDate * (2 * .pi / 5))
    }

    private func cardBody(_ slot: PickerSlot, _ m: Metrics) -> some View {
        VStack(spacing: 0) {
            straps(m)
            board(slot, m)
        }
    }

    /// Two rope straps from the rail down to the board, ending in knots.
    private func straps(_ m: Metrics) -> some View {
        ZStack {
            ForEach([0.22, 0.78], id: \.self) { fraction in
                let x = m.cardW * fraction
                Rectangle()
                    .fill(P.cream.color.opacity(0.85))
                    .frame(width: 3.5, height: 26)
                    .position(x: x, y: 13)
                Circle()
                    .fill(P.cream.color)
                    .overlay(Circle().stroke(P.ink.color, lineWidth: 1))
                    .frame(width: 6, height: 6)
                    .position(x: x, y: 24)
            }
        }
        .frame(width: m.cardW, height: 26)
    }

    private func board(_ slot: PickerSlot, _ m: Metrics) -> some View {
        // Picker cards render in their designed wood palette. (The
        // deepest-ever depth-state tint from the economy pass was retired
        // 2026-07-10 — Carson: "Tiki Stacks always highlighted blue".)
        return VStack(spacing: 0) {
            namePlate(slot, m)
            accentStripe(slot, m)
            mediaWindow(slot, m)
            footer(slot, m)
        }
        .frame(width: m.cardW, height: m.boardH)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(P.plank.color)
                .overlay(
                    RoundedRectangle(cornerRadius: 19)
                        .stroke(P.woodDark.color, lineWidth: 2)
                        .padding(6)
                )
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(P.ink.color, lineWidth: 2.5))
        }
        .overlay(alignment: .topTrailing) {
            if let g = slot.game, savedGames.contains(g) {
                Circle()
                    .fill(P.coral.color)
                    .overlay(Circle().stroke(P.ink.color, lineWidth: 1.5))
                    .frame(width: 13, height: 13)
                    .padding([.top, .trailing], 11.5)
            }
        }
    }

    private func namePlate(_ slot: PickerSlot, _ m: Metrics) -> some View {
        // Text is centered on the plate; the icon sits beside it (leading).
        // Without the phantom spacer, the HStack centers as a UNIT — which
        // pushes short titles ("LUAU", "ZOMBIE") right of plate center. The
        // phantom balances the icon's leading weight so the text is what's
        // centered, not the whole lockup.
        HStack(spacing: 10) {
            slotIcon(slot)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(slot.displayName.uppercased())
                .font(.custom("Futura-Bold", size: 19, relativeTo: .body))
                .tracking(2.5)
                .foregroundStyle(P.blossom.color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Color.clear
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .frame(height: m.plateH)
    }

    @ViewBuilder
    private func slotIcon(_ slot: PickerSlot) -> some View {
        switch slot {
        case .lounge:
            // A hand-drawn torch flame in a rounded plate — sits in the same
            // 34pt slot the game icons occupy.
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(P.ember.color)
                FlameGlyph()
                    .fill(
                        LinearGradient(
                            colors: [P.torch.color, P.coral.color, P.rum.color],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .padding(6)
            }
        case .leaderboards:
            // Gold trophy on an ember plate — same 34pt slot as game icons,
            // same plate treatment as the lounge torch.
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(P.ember.color)
                Image.iconTrophy
                    .resizable()
                    .scaledToFit()
                    .padding(7)
            }
        case .game(let g):
            g.icon
                .resizable()
                .scaledToFit()
        }
    }

    private func accentStripe(_ slot: PickerSlot, _ m: Metrics) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(slot.pickerAccent.color)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(P.ink.color, lineWidth: 1))
            .frame(width: m.windowW, height: 4)
    }

    /// Routed mat + the media window. For games the frame is published in
    /// global coordinates so the launch overlay can expand from it.
    @ViewBuilder
    private func mediaWindow(_ slot: PickerSlot, _ m: Metrics) -> some View {
        switch slot {
        case .lounge:
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(P.woodDark.color)
                    .frame(width: m.windowW + 12, height: m.windowH + 12)
                // The breathing torch crest IS the lounge card's face — the
                // pan-clip experiment is retired (crest already covers the
                // Reduce Motion / Low Power duty by design).
                LoungeTorchCrest()
                .frame(width: m.windowW, height: m.windowH)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.ink.color, lineWidth: 2.5))
                .overlay(alignment: .top) {
                    // Tonight's pour is earned and unclaimed — the card
                    // says so before you ever enter the room (Vic's glow
                    // takes the handoff inside).
                    if nightlyReady {
                        LoungePourBanner()
                            .padding(.top, 12)
                    }
                }
            }
        case .leaderboards:
            // Designed crest, no AVPlayer — same duty as the lounge card's
            // torch (Reduce Motion / Low Power safe by construction).
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(P.woodDark.color)
                    .frame(width: m.windowW + 12, height: m.windowH + 12)
                LeaderboardBannerCrest()
                    .frame(width: m.windowW, height: m.windowH)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.ink.color, lineWidth: 2.5))
            }
        case .game(let game):
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(P.woodDark.color)
                    .frame(width: m.windowW + 12, height: m.windowH + 12)
                GamePreviewView(
                    slot: .game(game),
                    player: playerIfNear(.game(game)),
                    playing: focused == .game(game) && launchState == nil
                )
                .frame(width: m.windowW, height: m.windowH)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(P.ink.color, lineWidth: 2.5))
                .background {
                    GeometryReader { g in
                        Color.clear.preference(
                            key: WindowFramesKey.self,
                            value: [game: g.frame(in: .global)]
                        )
                    }
                }
            }
        }
    }

    /// Player policy: only focused ± 1 get a live player (PICKER_SPEC §8).
    /// Read-only — players.focus() (settle path) owns creation/teardown,
    /// so no state mutates during view rendering. Slot indices include the
    /// lounge (position 0), so the neighboring game gets a player when the
    /// lounge is focused.
    private func playerIfNear(_ slot: PickerSlot) -> AVPlayer? {
        guard !reduceMotion, let focused,
              let f = PickerSlot.all.firstIndex(of: focused),
              let s = PickerSlot.all.firstIndex(of: slot),
              abs(f - s) <= 1 else { return nil }
        return players.existing(for: slot)
    }

    private func footer(_ slot: PickerSlot, _ m: Metrics) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(slot.pickerGenre)
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.cream.color.opacity(0.80))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                secondFooterLine(slot)
            }
            Spacer(minLength: 10)
            launchCapsule(slot)
        }
        .padding(.horizontal, 18)
        .frame(maxHeight: .infinity)
    }

    /// Local count of boards this player is on — a game joins its board
    /// with its first scoring run. Local truth only; the async Game Center
    /// standings never gate the picker.
    private var boardsJoined: Int {
        TikiGame.pickerOrder.filter { store.leaderboardScore(for: $0) > 0 }.count
    }

    @ViewBuilder
    private func secondFooterLine(_ slot: PickerSlot) -> some View {
        switch slot {
        case .leaderboards:
            Text("ON \(boardsJoined) OF \(TikiGame.pickerOrder.count) BOARDS")
                .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.torch.color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        case .lounge:
            let placed = store.placedItemIDs.count
            let total = store.loungeItems.count
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(placed >= total && total > 0 ? "ALL PLACED" : "\(placed) OF \(total) ITEMS")
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.torch.color)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        case .game(let g):
            HStack(alignment: .center, spacing: 10) {
                if let best = bests[g], best > 0 {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("BEST")
                            .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                            .tracking(2)
                            .foregroundStyle(P.torch.color)
                        Text(best.formatted(.number.grouping(.automatic)))
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(P.blossom.color)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                if GameCenter.leaderboardID(for: g) != nil {
                    ranksChip(g)
                }
            }
        }
    }

    /// Trophy door to a game's leaderboard — only games with a Game Center
    /// board get one. Visually 28 pt so the footer band keeps its height;
    /// the inset contentShape stretches the tap target to ~44 pt.
    private func ranksChip(_ g: TikiGame) -> some View {
        Button {
            leaderboardGame = g
        } label: {
            ZStack {
                Circle()
                    .fill(P.shadowBrown.color)
                    .overlay(Circle().stroke(P.ink.color, lineWidth: 1.5))
                Image.iconTrophy.resizable().scaledToFit().frame(height: 14)
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle().inset(by: -8))
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("\(g.displayName) leaderboard")
    }

    /// A deliberate miniature of the home PLAY button; RESUME swaps to
    /// coral/ember (ember-on-coral passes contrast where blossom fails).
    /// The Lounge card gets an ENTER capsule that never becomes RESUME.
    private func launchCapsule(_ slot: PickerSlot) -> some View {
        let label: String
        let resuming: Bool
        switch slot {
        case .lounge:
            label = "ENTER"
            resuming = false
        case .leaderboards:
            label = "VIEW"
            resuming = false
        case .game(let g):
            resuming = savedGames.contains(g)
            label = resuming ? "RESUME" : "PLAY"
        }
        return Text(label)
            .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
            .tracking(3)
            .foregroundStyle(resuming ? P.ember.color : P.ink.color)
            .padding(.horizontal, 24)
            .frame(height: 44)
            .background(Capsule().fill(resuming ? P.coral.color : P.torch.color))
            .overlay(Capsule().stroke(P.ink.color.opacity(0.25), lineWidth: 1.5))
    }

    // MARK: - Indicator strip

    /// Miniature signs, one per game in its accent color, on an exact
    /// 44 pt center pitch — each a real jump target. The active sign is
    /// bigger and "hangs heavier" (dropped 1.5 pt).
    private func indicatorStrip(_ m: Metrics) -> some View {
        // Strip is "which game" — one pip per game. The leaderboard banner
        // holds position 0, so the pip index is the scroll position minus
        // one, and the strip fades to 0.55 while the banner is focused
        // ("not on a game right now").
        let count = TikiGame.allCases.count
        let raw = min(count, max(0, Int(progress.rounded())))
        let active = max(0, min(count - 1, raw - 1))
        return HStack(spacing: 0) {
            ForEach(Array(TikiGame.pickerOrder.enumerated()), id: \.element) { index, game in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        focused = .game(game)
                    }
                } label: {
                    let hot = index == active && raw > 0
                    RoundedRectangle(cornerRadius: hot ? 3 : 2.5)
                        .fill(game.pickerAccent.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: hot ? 3 : 2.5)
                                .stroke(P.ink.color, lineWidth: hot ? 1.5 : 1)
                        )
                        .frame(
                            width: hot ? 18 : 13,
                            height: hot ? 13 : 9
                        )
                        .offset(y: hot ? 1.5 : 0)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .opacity(raw == 0 ? 0.55 : 1)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: raw)
        .position(x: m.w / 2, y: m.stripCenterY)
        .accessibilityHidden(true)
    }

    // MARK: - Entry, settle, nudge

    private func enter() {
        store.refreshNightlyMirrors()   // day may have rolled while idle
        bests = Dictionary(uniqueKeysWithValues: TikiGame.allCases.map { ($0, store.bestScore(for: $0)) })
        savedGames = Set(TikiGame.allCases.filter { store.loadState(for: $0) != nil })
        depthTints = Dictionary(uniqueKeysWithValues: TikiGame.allCases.compactMap { g in
            store.deepestMilestone(for: g).map { (g, g.depthAccents[min($0, g.depthAccents.count - 1)]) }
        })
        // Reduce Motion shows posters only — never spin up video decode.
        if !reduceMotion { players.focus(focused) }

        if reduceMotion {
            chromeIn = true
            railSlide = 0
            carouselShift = 0
            cardDrop = [:]
            interactive = true
            return
        }
        withAnimation(.easeOut(duration: 0.25)) {
            chromeIn = true
            railSlide = 0
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.10)) {
            carouselShift = 0
        }
        for slot in PickerSlot.all.prefix(3) { kick[slot] = -2.5 }
        // Cold start jumps to the home slot behind the reveal curtain
        // (rail concealed until ~0.43s) — hold the card drops until the
        // fade-in is underway so they land on a visible rail. An entry
        // opening at position 0 (never in practice) keeps the original
        // 0.15s choreography.
        let dropBase = initialFocus == PickerSlot.all[0] ? 0.15 : 0.34
        for (i, slot) in PickerSlot.all.prefix(3).enumerated() {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(dropBase + 0.06 * Double(i))) {
                cardDrop[slot] = 0
                kick[slot] = 0
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            interactive = true
            try? await Task.sleep(for: .seconds(1.2))
            firstRunNudge()
        }
        // Return-to-rail: land on the slot the player launched from.
        // Assigned post-appear (not as initial state) for the same reason
        // as the TIKI_PICKER_PAGE hook below — the scrollPosition binding
        // only reacts to a change in the bound value.
        if initialFocus != PickerSlot.all[0], focused != initialFocus {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { focused = initialFocus }
                withAnimation(.easeOut(duration: 0.18)) { railRevealed = true }
            }
        }
        #if DEBUG
        // Dev hook: SIMCTL_CHILD_TIKI_PICKER_LAUNCH=1 taps the focused card
        // after the entry settles, for capturing the expansion transition.
        if ProcessInfo.processInfo.environment["TIKI_PICKER_LAUNCH"] == "1" {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.5))
                cardTapped(focused ?? .game(.tikiStacks))
            }
        }
        // Dev hook: SIMCTL_CHILD_TIKI_PICKER_PAGE=<0-N> jumps to that page.
        // Assigned here (not as initial state) because programmatic
        // scrollPosition only reacts to a change in the bound value. Fires
        // AFTER the cold-start home jump (250ms) and guards against the
        // jump's landing slot, not the pre-jump focus — page 0 (the banner)
        // used to self-disarm because `focused` still sat at position 0
        // when this armed.
        if let raw = ProcessInfo.processInfo.environment["TIKI_PICKER_PAGE"],
           let index = Int(raw), PickerSlot.all.indices.contains(index),
           PickerSlot.all[index] != initialFocus {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(550))
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { focused = PickerSlot.all[index] }
            }
        }
        #endif
    }

    /// Low Power / thermal shifts degrade to posters and recover to video —
    /// but never mid-expansion, where a teardown would cut the overlay.
    private func powerStateShifted() {
        guard launchState == nil else { return }
        if players.disabled {
            players.teardownAll()
        } else if !reduceMotion {
            players.focus(focused)
        }
    }

    /// Once ever: if the user hasn't swiped 1.7 s in, the rail leans left
    /// and springs back — "there's more down here".
    private func firstRunNudge() {
        // progress guard: never yank the rail while a first drag is in flight.
        guard !didSwipe, launchState == nil, !reduceMotion, progress < 0.02 else { return }
        TikiSound.shared.knock()
        withAnimation(.easeInOut(duration: 0.45)) { nudge = -36 }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.45)) { nudge = 0 }
    }

    private func settle(on slot: PickerSlot?) {
        guard let slot, let index = PickerSlot.all.firstIndex(of: slot) else { return }
        if !didSwipe {
            didSwipe = true
            UserDefaults.standard.set(true, forKey: "pickerDidSwipe")
            // If most players never swipe, two of three games are effectively
            // hidden and D-1's breadth problem has a NAVIGATION cause rather
            // than an interest one — a completely different fix.
            Analytics.design("picker:swipe")
        }
        if !reduceMotion { players.focus(slot) }
        guard interactive else { return }
        settleHaptic.impactOccurred()
        // railTick.step animates within the game count; the banner at
        // position 0 clamps to the first step.
        TikiSound.shared.railTick(step: max(0, index - 1))
        if !reduceMotion {
            kick[slot] = 1.2
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
                kick[slot] = 0
            }
        }
        switch slot {
        case .lounge:
            AccessibilityNotification.Announcement("The Lounge, your home room").post()
        case .leaderboards:
            AccessibilityNotification.Announcement("Leaderboards, high scores for every game").post()
        case .game(let g):
            // The banner holds position 0, so a game's rail index IS its
            // game number.
            AccessibilityNotification.Announcement("\(g.displayName), game \(index) of \(TikiGame.allCases.count)").post()
        }
    }

    // MARK: - Launch

    private func cardTapped(_ slot: PickerSlot) {
        guard launchState == nil else { return }
        // Peek taps used to require a second tap to launch. Snap-focus in the
        // same gesture, then continue straight to launch; the extra settle
        // delay below lets the window recenter before the expansion seeds.
        let wasFocused = (slot == focused)
        if !wasFocused {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { focused = slot }
        }
        pressHaptic.impactOccurred()
        TikiSound.shared.knock()
        // Lounge fast path — no AVPlayer, no expandWindow. The launch overlay
        // pipeline stays game-only.
        if case .lounge = slot {
            withAnimation(.easeInOut(duration: 0.06)) { pressScale[.lounge] = 0.96 }
            withAnimation(.easeInOut(duration: 0.06).delay(0.06)) { pressScale[.lounge] = 1.0 }
            onLaunch(.lounge)
            onClose()
            return
        }
        // Banner fast path — the boards chooser is an overlay of this
        // screen, not a route; the launch pipeline stays game-only.
        if case .leaderboards = slot {
            withAnimation(.easeInOut(duration: 0.06)) { pressScale[.leaderboards] = 0.96 }
            withAnimation(.easeInOut(duration: 0.06).delay(0.06)) { pressScale[.leaderboards] = 1.0 }
            Analytics.design("feature:boards:open")
            withAnimation(.easeOut(duration: 0.22)) { boardsOpen = true }
            return
        }
        guard case .game(let game) = slot else { return }
        // Shared lives gate: every game spends on defeat; at 0 lives the
        // out-of-lives sheet opens instead of launching.
        if store.isOutOfLives(for: game) {
            blockedLaunch = game
            withAnimation(.easeOut(duration: 0.2)) { outOfLivesOpen = true }
            return
        }
        launchGameAfterGate(game, wasFocused: wasFocused)
    }

    /// Continues a launch after the lives gate has cleared (or never applied).
    private func launchGameAfterGate(_ game: TikiGame, wasFocused: Bool = true) {
        // Reduce Motion — and any state without a live player (Low Power,
        // thermal) — takes the plain 0.3s crossfade instead of the expansion.
        if reduceMotion || players.existing(for: .game(game)) == nil {
            onLaunch(.game(game))
            onClose()
            return
        }
        withAnimation(.easeInOut(duration: 0.06)) { pressScale[.game(game)] = 0.96 }
        withAnimation(.easeInOut(duration: 0.06).delay(0.06)) { pressScale[.game(game)] = 1.0 }
        let settleDelay: Double = wasFocused ? 0.12 : 0.35
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(settleDelay))
            expandWindow(from: game)
        }
    }

    /// The signature exit: the exact window you were watching expands into
    /// the running game, which is already loading beneath the picker.
    private func expandWindow(from game: TikiGame) {
        guard let start = windowFrames[game], fullRect.width > 0 else {
            #if DEBUG
            print("[picker] expansion fallback: window=\(windowFrames[game].map(String.init(describing:)) ?? "nil") full=\(fullRect)")
            #endif
            onLaunch(.game(game))
            onClose()
            return
        }
        #if DEBUG
        print("[picker] expanding from \(start) to \(fullRect)")
        #endif
        launchState = GamePickerLaunchState(game: game, rect: start, radius: 14, opacity: 1)
        onLaunch(.game(game))
        withAnimation(.easeOut(duration: 0.25)) { chromeVisible = false }
        withAnimation(.easeInOut(duration: 0.40)) {
            launchState?.rect = fullRect
            launchState?.radius = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.40))
            withAnimation(.easeOut(duration: 0.20)) { launchState?.opacity = 0 }
            try? await Task.sleep(for: .seconds(0.20))
            players.teardownAll()
            onClose()
        }
    }

    // MARK: - Accessibility

    /// Tonight's pour is earned and unclaimed — the picker card wears the
    /// gold banner and VoiceOver says why.
    private var nightlyReady: Bool {
        store.nightlyCompleted >= PlayerStore.nightlyGoal && !store.nightlyRewardClaimed
    }

    private func accessibilityLabel(_ slot: PickerSlot) -> String {
        switch slot {
        case .leaderboards:
            var parts = ["Leaderboards.", "High scores for every game."]
            parts.append("You are on \(boardsJoined) of \(TikiGame.pickerOrder.count) boards.")
            parts.append("Double tap to view.")
            return parts.joined(separator: " ")
        case .lounge:
            let placed = store.placedItemIDs.count
            let total = store.loungeItems.count
            var parts: [String] = ["The Lounge, your home room."]
            if nightlyReady {
                parts.append("A daily reward is ready. Tap Vic to claim it.")
            }
            if placed == 0 {
                parts.append("No items placed yet.")
            } else if placed >= total, total > 0 {
                parts.append("All items placed.")
            } else {
                parts.append("\(placed) of \(total) items placed.")
            }
            return parts.joined(separator: " ")
        case .game(let game):
            let index = (TikiGame.pickerOrder.firstIndex(of: game) ?? 0) + 1
            var parts: [String] = []
            if savedGames.contains(game) { parts.append("Game in progress.") }
            parts.append("\(game.displayName).")
            parts.append("\(game.pickerGenreSpoken).")
            if let best = bests[game], best > 0 {
                parts.append("Best score \(best).")
            } else {
                parts.append("No score yet.")
            }
            parts.append("Game \(index) of \(TikiGame.allCases.count).")
            return parts.joined(separator: " ")
        }
    }
}

#Preview {
    GamePickerView(onLaunch: { _ in }, onClose: {}, initialFocus: .lounge)
        .environment(PlayerStore(inMemory: true))
}

