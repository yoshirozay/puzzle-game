import SwiftUI

// MARK: - Room

/// The room itself: anatomy (wall, floor, rug, bar, Vic) always present;
/// catalog items render at their anchors when placed. Anchors re-compose the
/// LoungeScene hero for portrait: hanging layer on the tall wall, bar zone
/// right, floor zones left-to-center, patrons mid-floor, fronds framing.
struct LoungeRoomView: View {
    let t: Double
    let size: CGSize
    let placed: Set<String>
    let justPlaced: String?
    let zombieTrophy: Bool
    let standing: String
    let standingTier: Int
    let aquariumFish: Int
    let windowEast: String
    let windowWest: String
    let rugColorway: Int
    let positions: [String: Double]
    let depths: [String: Double]
    let cycleWindow: (Bool) -> Void
    let cycleRug: () -> Void
    let commitPlacement: (String, Double, Double) -> Void
    /// Tapping a ghost (unowned) item opens the shop at its row.
    let openShop: (String) -> Void
    /// The welcome coach's SHOP beat is live: the copy names a thing in the
    /// world ("VIC'S WELCOME MUG"), so the world answers — a pulse rides
    /// Vic's raised hand alongside the chrome ring.
    let coachWelcomeActive: Bool
    /// Move-hint demo: this item hops while the hint card shows.
    let wiggleID: String?
    /// Vic's round is mid-pour: the reward pops at his hand, captioned in
    /// place. (The caption used to be a screen-space toast 400 pt north.)
    var dailyPour: PlayerStore.NightlyReward? = nil
    /// World-clock stamp of the moment the pour began — drives Vic's tilt.
    /// Read off `t` rather than held as @State because this view is re-inited
    /// every frame by the room's TimelineView.
    var dailyPourStart: TimeInterval? = nil
    /// The message bottle was tapped — the parent shows a note from Vic.
    var bottleTapped: () -> Void = {}
    /// Tonight's round is earned and unclaimed: Vic glows behind the bar.
    var nightlyReady: Bool = false
    /// Challenges done tonight — VoiceOver reads the board from Vic.
    var nightlyDone: Int = 0
    /// Vic was tapped — the parent opens the Nightly Nine board.
    var vicTapped: () -> Void = {}
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drag placement (LOUNGE_V2_PLAN §6): long-press lifts an owned piece,
    /// drag slides it along the floor (x free, y within the depth wedge),
    /// drop commits. Transient lift state lives here; persistence in the store.
    private struct Lift: Equatable {
        var id: String
        var cx: CGFloat
        var depth: CGFloat
    }
    @State private var lift: Lift?

    /// Effective anchor cx: lifted finger > player placement > designed default.
    private func cx(_ id: String, _ def: CGFloat) -> CGFloat {
        if let lift, lift.id == id { return lift.cx }
        if let p = positions[id], p >= 0 { return CGFloat(p) }
        return def
    }

    /// Continuous floor depth (device round: "items should get slightly
    /// larger the further down the floor — smallest against the wall").
    /// Eligible pieces slide anywhere between their wall rail (depth 0)
    /// and the deepest foot line (depth 1), growing linearly to deepScale
    /// and stacking by their feet. EVERY standing floor piece is eligible
    /// (Carson's device round 2: a piano that only slides sideways reads
    /// as broken). Only the rug (floor-flat) and the corner fronds
    /// (screen-edge framing whose feet sit BELOW deepFoot — the lerp
    /// would run backwards) keep fixed y.
    static let deepFoot: CGFloat = 0.93
    static let deepScale: CGFloat = 1.16
    /// EXPERIMENT (2026-07-16, Carson: "try doubling the scale of all
    /// items… I want all the items in the lounge to be bigger"): a global
    /// multiplier on every lounge ITEM — floor pieces, rug, fronds, wall
    /// art (marlin/aquarium/back bar), parrot, counter drink, trophy —
    /// EXCLUDING windows, roof hangings (lanterns/blowfish/float/neon/
    /// fan), and fixtures (Vic, his mug, the bar, the plaque). Default
    /// anchors are still spaced for 1×, so 2× overlaps until rearranged.
    /// Tune here; 1.0 restores the shipped proportion system.
    static let itemScale: CGFloat = 2.0
    static let depthEligible: Set<String> = [
        "plantSnake", "plantBush", "plantTiered", "palmPlant",
        "suspiciousCat", "barStools", "highTable", "loungeCouch",
        "grandPiano", "recordCredenza", "tikiStatue",
        "martiniWoman", "highballMan",
    ]

    /// Effective depth (0…1): lifted finger > player placement > rail.
    private func depth(_ id: String) -> CGFloat {
        guard Self.depthEligible.contains(id) else { return 0 }
        if let lift, lift.id == id { return lift.depth }
        return CGFloat(depths[id] ?? 0)
    }

    /// Floor-piece frame honoring the piece's depth: the foot lerps from
    /// its rail to deepFoot and the piece grows toward deepScale.
    private func floorFrame(_ id: String, def: CGFloat, widthF: CGFloat, aspect: CGFloat, rail: CGFloat) -> CGRect {
        let d = depth(id)
        return frame(cx: cx(id, def),
                     width: span(widthF * Self.itemScale * (1 + (Self.deepScale - 1) * d)),
                     aspect: aspect,
                     bottom: rail + (Self.deepFoot - rail) * d)
    }

    private func liftDrag(id: String, startCx: CGFloat, halfW: CGFloat) -> some Gesture {
        // 0.2 s, down from 0.35 (device round: the hold felt sluggish).
        // Any lower and hesitant pans that start on furniture would lift
        // the piece instead of scrolling the room — a fast pan still wins
        // because finger movement cancels the press. maximumDistance 8
        // (default 10) so a touch-down dwell that's already creeping into
        // a pan cancels the lift instead of stealing it (grand retune:
        // furniture now covers most of the screen).
        LongPressGesture(minimumDuration: 0.2, maximumDistance: 8)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("loungeRoom")))
            .onChanged { value in
                switch value {
                case .first(true):
                    if lift == nil {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        lift = Lift(id: id, cx: startCx, depth: depth(id))
                    }
                case .second(true, let drag?):
                    let lo = halfW + 0.01, hi = 1 - halfW - 0.01
                    // Depth tracks the finger continuously: at the rail's
                    // foot line the piece stands against the wall; dragging
                    // down the planks walks it toward the camera (device
                    // round: the two-band snap read as "not following my
                    // finger"). Ineligible pieces ignore the vertical.
                    let newDepth: CGFloat
                    if Self.depthEligible.contains(id) {
                        let rail = railFoot(id)
                        newDepth = min(max((drag.location.y / h - rail) / (Self.deepFoot - rail), 0), 1)
                    } else {
                        newDepth = 0
                    }
                    lift = Lift(id: id, cx: min(max(drag.location.x / w, lo), hi), depth: newDepth)
                default:
                    break
                }
            }
            .onEnded { _ in
                guard let l = lift, l.id == id else { return }
                commitPlacement(id, Double(l.cx), Double(l.depth))
                lift = nil
            }
    }

    /// Designed rail foot for an eligible piece (the depth-0 line the
    /// finger mapping is anchored to).
    private func railFoot(_ id: String) -> CGFloat {
        switch id {
        case "loungeCouch", "grandPiano": return 0.80
        case "barStools": return 0.815
        case "recordCredenza": return 0.792
        case "martiniWoman", "highballMan": return 0.805
        default: return 0.795
        }
    }

    /// placedImage's movable twin: lift scale + a flat ground shadow while
    /// held, and the long-press-drag gesture. `rect` must come from the same
    /// cx(_:_:) the anchor uses so the piece tracks the finger. The hit area
    /// extends `slop` pt beyond the visible art so small pieces (parrot,
    /// cat) stay easy to grab — but only small ones: half-size padding on
    /// the big furniture blanketed the floor band in gesture surface and
    /// room pans that started there died (device pass, 2026-07-16).
    private func movableImage(_ image: Image, _ id: String, _ rect: CGRect) -> some View {
        let lifted = lift?.id == id
        // Three hit-surface tiers (grand retune): small pieces keep a
        // generous grab pad; big 2×-canon pieces give an inset back to the
        // room pan — at the new scale furniture blankets the screen, and
        // pans that started on a piece went dead (device note). Grabbing
        // the middle still lifts.
        let minDim = min(rect.width, rect.height)
        let maxDim = max(rect.width, rect.height)
        let slop: CGFloat = minDim < 60 ? 18 : (maxDim > 220 ? -10 : 6)
        return image
            .resizable()
            .scaledToFit()
            .frame(width: rect.width, height: rect.height)
            .background(alignment: .bottom) {
                if lifted {
                    Ellipse()
                        .fill(P.ink.color.opacity(0.22))
                        .frame(width: rect.width * 0.85, height: rect.width * 0.13)
                        .offset(y: rect.width * 0.05)
                }
            }
            .scaleEffect(lifted ? 1.06 : 1)
            .padding(slop)
            .contentShape(Rectangle())
            .position(x: rect.midX, y: rect.midY)
            // Move-hint demo hop — the same lift the finger gets, unprompted.
            .offset(y: wiggleID == id ? -12 : 0)
            .transition(popIn)
            .gesture(liftDrag(id: id, startCx: rect.midX / w, halfW: rect.width / (2 * w)))
    }

    /// Wall warmth: coral -> rum on the 90 s breath, like the Zombie interior.
    var breath: Double { (1 - cos(t * 2 * .pi / 90)) / 2 }
    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var floorLine: CGFloat { h * 0.78 }

    /// Lounge v2: the room is a horizontal-scroll world (LOUNGE_V2_PLAN §3).
    /// GRAND RETUNE (2026-07-16, Carson: "I like this way more… make the
    /// lounge wider, do the full re-anchor pass"): 2.2 → 4.4 screens with
    /// itemScale 2 — every anchor now carries its OLD world fraction as a
    /// literal, so the whole 2.2-screen composition doubled WITH its
    /// spacing: same room, twice the size, seen through a closer camera.
    /// `east()` survives only as the old-world conversion note: at 2.2
    /// screens east(x) was (1.2+x)/2.2 — those quotients are the literals
    /// on the east-zone anchors below.
    static let worldScreens: CGFloat = 4.4
    /// Where the roof meets the wall (fraction of h). The ceiling Canvas
    /// fills above this; the fan and every hanging cord mount to it. 0.40
    /// balances two reads: the wall stays bounded (~4.3 P with the roof cap
    /// carrying the scale) and the roof stays a band, not half the screen.
    static let ceilingLine: CGFloat = 0.40
    private func span(_ f: CGFloat) -> CGFloat { f / Self.worldScreens }

    /// Purchase auto-scroll targets (LoungeView scrolls to "scroll-<id>").
    static let scrollableIDs: [String] = [
        "sunsetWindow", "blowfishLamp", "glassFloat", "backBarShelf",
        "flamingMug", "umbrellaDrink", "tikiStatue", "palmPlant",
        "suspiciousCat", "recordCredenza", "martiniWoman", "highballMan",
        "cornerFronds", "barStools", "ceilingFan", "marlin", "parrot",
        "neonTikiSign", "aquarium", "bayWindow", "highTable", "grandPiano",
        "loungeCouch", "plantSnake", "plantBush", "plantTiered", "loungeRug",
        "buoy", "lagoonDuck", "messageBottle", "dolphin", "seaTurtle",
        "sailboat", "shark", "orca", "farIsland", "volcano", "yacht",
    ]

    var body: some View {
        ZStack {
            edgeBleed
            wall
            wallDressing
            ceiling
            lagoonLife
            dustMotes
            floorAndRug
            ghostHooks
            standingPlaque
            hangingLayer
            vic
            bar
            standingItems
            purchaseBurst
            scrollMarkers
        }
        .coordinateSpace(name: "loungeRoom")
        .animation(.spring(duration: 0.4, bounce: 0.35), value: lift?.id)
        .animation(.spring(duration: 0.4, bounce: 0.5), value: wiggleID)
    }

    /// Invisible per-item markers so the outer ScrollViewReader can bring a
    /// fresh purchase on screen before its burst fires. Markers are placed
    /// by LAYOUT (spacer-offset), never `.position` — scrollTo resolves the
    /// identified view's layout frame, and a `.position` wrapper reports
    /// the full 2.2-screen world, degrading every target to "center the
    /// room" (purchases parked at the viewport edge; zone parks only worked
    /// by coincidence).
    private var scrollMarkers: some View {
        ZStack {
            ForEach(Self.scrollableIDs, id: \.self) { id in
                marker("scroll-\(id)", x: anchorFrame(for: id)?.midX ?? 0)
            }
            // "hint" is the discovery drift's target: centering 0.65 peeks
            // the couch/marlin edge of the mid zone, then the camera
            // settles back east.
            ForEach(Array(zip(["west", "mid", "east", "hint"], [0.02, 0.5, 0.98, 0.65])), id: \.0) { zone, x in
                marker("zone-\(zone)", x: CGFloat(x) * w)
            }
        }
        .allowsHitTesting(false)
    }

    private func marker(_ id: String, x: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: max(x - 0.5, 0), height: 1)
            Color.clear.frame(width: 1, height: 1).id(id)
            Spacer(minLength: 0)
        }
        .frame(width: w, height: 1)
    }

    /// House Standing, posted where a bar would post it (§3): a small
    /// engraved plaque on the wall over the back bar. The name is the whole
    /// display — no meter anywhere.
    private var standingPlaque: some View {
        // scaleEffect, not a bigger frame: the engraving fonts are fixed
        // sizes, so scaling the view keeps plate and text in step with the
        // 2× canon (×1.5 reads right over the doubled back bar).
        HouseStandingPlaque(standing: standing)
            .frame(width: plaqueFrame.width, height: plaqueFrame.height)
            .scaleEffect(1.5)
            .position(x: plaqueFrame.midX, y: plaqueFrame.midY)
    }

    /// Celebration at the anchor: a burst star fires where the new item just
    /// landed (the Tiki Stacks juice pattern), then fades.
    @ViewBuilder
    private var purchaseBurst: some View {
        if let id = justPlaced, let anchor = anchorFrame(for: id) {
            LoungeBurst()
                .frame(width: max(anchor.width * 0.9, 54), height: max(anchor.width * 0.9, 54))
                .position(x: anchor.midX, y: anchor.midY)
                .id(id)
                .allowsHitTesting(false)
        }
    }

    private func anchorFrame(for id: String) -> CGRect? {
        // Lagoon items anchor wherever they currently float — the purchase
        // scroll and burst chase the drift.
        if let item = Self.lagoonItems.first(where: { $0.id == id }) {
            return waterFrame(item)
        }
        switch id {
        case "sunsetWindow": return windowFrame
        case "blowfishLamp": return lampFrame
        case "glassFloat": return floatFrame
        case "backBarShelf": return shelfFrame
        case "flamingMug": return mugFrame
        case "umbrellaDrink": return drinkFrame
        case "tikiStatue": return statueFrame
        case "palmPlant": return palmFrame
        case "suspiciousCat": return catFrame
        case "recordCredenza": return credenzaFrame
        case "martiniWoman": return womanFrame
        case "highballMan": return manFrame
        case "cornerFronds": return frondsFrame
        case "barStools": return stoolsFrame
        case "ceilingFan": return fanFrame
        case "marlin": return marlinFrame
        case "parrot": return parrotFrame
        case "neonTikiSign": return signFrame
        case "aquarium": return aquariumFrame
        case "bayWindow": return bayWindowFrame
        case "highTable": return highTableFrame
        case "grandPiano": return pianoFrame
        case "loungeCouch": return couchFrame
        case "plantSnake": return plantSnakeFrame
        case "plantBush": return plantBushFrame
        case "plantTiered": return plantTieredFrame
        case "loungeRug": return rugFrame
        default: return nil
        }
    }

    // MARK: anchors (fractions of W/H; aspect = sprite viewBox h/w)

    private func frame(cx: CGFloat, width: CGFloat, aspect: CGFloat, bottom: CGFloat? = nil, top: CGFloat? = nil) -> CGRect {
        let fw: CGFloat = width * w
        let fh: CGFloat = fw * aspect
        let x: CGFloat = cx * w - fw / 2
        let y: CGFloat
        if let bottom { y = bottom * h - fh } else { y = (top ?? 0) * h }
        return CGRect(x: x, y: y, width: fw, height: fh)
    }

    // Corner clearances: the back button owns the top-left ~0.16W x 0.13h,
    // the wallet/SHOP cluster owns the top-right — hanging items steer clear
    // of the EAST screenful's corners (the camera's opening frame).
    // Proportion system (2026-07 retune): the unit is one standing person,
    // P = highTableFrame.height * 103.5/114 (the toasting couple, ~85 pt on
    // a 440 pt screen). Bands: roof above `ceilingLine`; wall art hangs
    // 1.2-2.6 P above the floor line (0.78h); floor pieces stand at
    // 0.795-0.815h; the bar top (0.744h) meets a patron at the chest.
    // runProportionAudit() (DEBUG, TIKI_PROPORTION_AUDIT=1) proves these.
    private var windowFrame: CGRect { frame(cx: 0.7227, width: span(0.32), aspect: 180.0 / 238.0, top: 0.52) }
    private var lampFrame: CGRect { frame(cx: cx("blowfishLamp", 0.6205), width: span(0.075), aspect: 78.0 / 63.0, top: 0.44) }
    private var floatFrame: CGRect { frame(cx: cx("glassFloat", 0.7545), width: span(0.05), aspect: 53.0 / 38.0, top: 0.455) }
    private var shelfFrame: CGRect { frame(cx: 0.9045, width: span(0.22 * Self.itemScale), aspect: 116.0 / 216.0, top: 0.60) }
    // Vic is a fixture but scales with the canon — a 1× bartender at a 2×
    // bar read as a child (itemScale experiment). Bottom 0.755 keeps his
    // hidden-behind-the-counter fraction in range at the new counter.
    private var vicFrame: CGRect { frame(cx: 0.9227, width: span(0.10 * Self.itemScale), aspect: 150.0 / 87.0, bottom: 0.755) }
    private var drinkFrame: CGRect { frame(cx: cx("umbrellaDrink", 0.8682), width: span(0.022 * Self.itemScale), aspect: 54.0 / 32.0, bottom: 0.688) }
    private var statueFrame: CGRect { floorFrame("tikiStatue", def: 0.6273, widthF: 0.085, aspect: 259.0 / 92.0, rail: 0.795) }
    private var palmFrame: CGRect { floorFrame("palmPlant", def: 0.6818, widthF: 0.15, aspect: 258.0 / 158.0, rail: 0.795) }
    // Cat span 0.058, not 0.04: at 0.04 the 500-pt Suspicious Cat rendered
    // ~18 pt wide — an invisible black smudge on the dark floor (device
    // round). 0.058 ≈ 0.44 P tall: an actual cat you can be judged by.
    private var catFrame: CGRect { floorFrame("suspiciousCat", def: 0.7364, widthF: 0.058, aspect: 88.0 / 60.0, rail: 0.795) }
    private var credenzaFrame: CGRect { floorFrame("recordCredenza", def: 0.7727, widthF: 0.16, aspect: 114.0 / 188.0, rail: 0.792) }
    private var womanFrame: CGRect { floorFrame("martiniWoman", def: 0.8364, widthF: 0.12, aspect: 112.0 / 64.0, rail: 0.805) }
    private var manFrame: CGRect { floorFrame("highballMan", def: 0.8886, widthF: 0.105, aspect: 112.0 / 56.0, rail: 0.805) }
    private var frondsFrame: CGRect { frame(cx: cx("cornerFronds", 0.9750), width: span(0.12 * Self.itemScale), aspect: 78.0 / 64.0, bottom: 1.02) }
    // Hanging zone: fan overhead in the mid zone, marlin on the mid wall,
    // aquarium wall-mounted over the couch. Sign on the east screenful's
    // left edge; lamp and float staggered so no cords cross art below.
    // Grand-retune restack: the doubled marlin + aquarium no longer fit
    // stacked over the doubled couch (0.231h of wall for 0.243h of art) —
    // the marlin moved west over the piano, the aquarium rose and
    // recentered over the couch, and the fan slid east between them.
    private var fanFrame: CGRect { frame(cx: cx("ceilingFan", 0.42), width: span(0.18), aspect: 120.0 / 220.0, top: Self.ceilingLine) }
    private var marlinFrame: CGRect { frame(cx: cx("marlin", 0.32), width: span(0.30 * Self.itemScale), aspect: 76.0 / 200.0, top: 0.43) }
    private var signFrame: CGRect { frame(cx: cx("neonTikiSign", 0.5795), width: span(0.07), aspect: 190.0 / 64.0, top: 0.44) }
    private var aquariumFrame: CGRect { frame(cx: cx("aquarium", 0.47), width: span(0.30 * Self.itemScale), aspect: 110.0 / 220.0, top: 0.46) }
    // West-wing anchors (the east screenful starts at world 0.545). The
    // bistro table sits under the bay window; bush and tiered plant tuck
    // BEHIND the piano and couch respectively (draw order, not clearance).
    private var bayWindowFrame: CGRect { frame(cx: 0.13, width: span(0.40), aspect: 0.70, top: 0.50) }
    private var highTableFrame: CGRect { floorFrame("highTable", def: 0.155, widthF: 0.28, aspect: 114.0 / 150.0, rail: 0.795) }
    private var pianoFrame: CGRect { floorFrame("grandPiano", def: 0.30, widthF: 0.34, aspect: 150.0 / 220.0, rail: 0.80) }
    private var couchFrame: CGRect { floorFrame("loungeCouch", def: 0.475, widthF: 0.40, aspect: 110.0 / 240.0, rail: 0.80) }
    private var plantSnakeFrame: CGRect { floorFrame("plantSnake", def: 0.035, widthF: 0.11, aspect: 170.0 / 100.0, rail: 0.795) }
    // Bush default 0.41, not 0.26: at 0.26 the whole pot sat inside the
    // piano's open underside and read as a stuck render, not depth
    // (fresh-eyes round 2). At 0.41 the crown peeks over the couch's left
    // arm — the same read the tiered pot makes at its right.
    private var plantBushFrame: CGRect { floorFrame("plantBush", def: 0.41, widthF: 0.12, aspect: 150.0 / 110.0, rail: 0.795) }
    private var plantTieredFrame: CGRect { floorFrame("plantTiered", def: 0.575, widthF: 0.13, aspect: 160.0 / 130.0, rail: 0.795) }
    private var rugFrame: CGRect { frame(cx: cx("loungeRug", 0.46), width: span(0.62 * Self.itemScale), aspect: 56.0 / 300.0, bottom: 0.97) }
    private var parrotFrame: CGRect { frame(cx: 0.9682, width: span(0.062 * Self.itemScale), aspect: 110.0 / 90.0, bottom: 0.688) }
    private var stoolsFrame: CGRect { floorFrame("barStools", def: 0.9500, widthF: 0.155, aspect: 95.0 / 150.0, rail: 0.815) }
    private var plaqueFrame: CGRect { frame(cx: 0.9318, width: span(0.22), aspect: 34.0 / 116.0, top: 0.53) }

    /// The mug shares Vic's sprite origin (world -502,-100), so its frame is
    /// Vic's frame scaled by the two viewBoxes — it registers in his hand.
    private var mugFrame: CGRect {
        let v = vicFrame
        return CGRect(x: v.minX, y: v.minY, width: v.width * 30.0 / 87.0, height: v.height * 74.0 / 150.0)
    }

    /// Earned trophy anchor: THE ZOMBIE mug (100x170 design box) stands on
    /// the credenza's top slab (local y 44/114), right of the tiki figure —
    /// or on the credenza's dust mark until it's purchased.
    private var trophyFrame: CGRect {
        let c = credenzaFrame
        let fw: CGFloat = w * span(0.028 * Self.itemScale)
        let fh: CGFloat = fw * 1.7
        let bottom: CGFloat = placed.contains("recordCredenza") ? c.minY + c.height * 44 / 114 : c.maxY
        return CGRect(x: c.minX + c.width * 0.80 - fw / 2, y: bottom - fh, width: fw, height: fh)
    }

    // MARK: anatomy

    private func band(_ y0: CGFloat, _ y1: CGFloat, _ fill: Color) -> some View {
        Rectangle()
            .fill(fill)
            .frame(width: w, height: y1 - y0)
            .position(x: w / 2, y: (y0 + y1) / 2)
    }

    private var wall: some View {
        band(0, h, P.coral.mix(P.rum, breath))
    }

    /// How far the room's textures paint past each world edge. Rubber-band
    /// overscroll tops out near half a viewport; 0.2 of the 2.2-screen
    /// world (~0.44 screens) covers any realistic pull.
    private var bleedW: CGFloat { w * 0.2 }

    /// Painted continuation of the room past both world edges (device
    /// round 3 — overscroll showed band COLORS but no textures, a hard
    /// seam where wavelets/battens/planks stopped). Full-width canvas,
    /// drawn first; the real layers overpaint the middle. Textures only —
    /// features (sun, fish, lanterns) stay inside the world.
    private var edgeBleed: some View {
        Canvas { ctx, sz in
            let bleed: Double = Double(bleedW)
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let line: Double = height * Double(Self.ceilingLine)
            let beam: Double = height * 0.012
            let waterBottom: Double = line - beam
            // Water plane + wavelets, phase-matched via the world-x offset.
            ctx.fill(
                Path(CGRect(x: 0, y: 0, width: width, height: waterBottom)),
                with: .color(P.lagoon.color)
            )
            for row in 0..<4 {
                let fr: Double = Double(row)
                let y: Double = 12 + waterBottom * (0.15 + 0.22 * fr)
                let amp: Double = 2.0 + 0.7 * fr
                let speed: Double = 0.55 + 0.14 * fr
                var path = Path()
                var first = true
                var x: Double = 0
                while x <= width {
                    let angle: Double = (x - bleed) / 85 * 2 * .pi + t * speed + fr * 1.7
                    let point = CGPoint(x: x, y: y + amp * sin(angle))
                    if first { path.move(to: point); first = false } else { path.addLine(to: point) }
                    x += 6
                }
                ctx.stroke(path, with: .color(P.cream.color.opacity(0.26)), lineWidth: 1.9)
            }
            ctx.fill(
                Path(CGRect(x: 0, y: waterBottom, width: width, height: beam)),
                with: .color(P.ink.color)
            )
            // Wall slice with the same dressing: breath fill, wainscot,
            // rail, skirting, battens on the world's 1/44 grid.
            let rail: Double = height * 0.635
            let floorLine: Double = height * 0.78
            ctx.fill(
                Path(CGRect(x: 0, y: line, width: width, height: floorLine - line)),
                with: .color(P.coral.mix(P.rum, breath))
            )
            ctx.fill(
                Path(CGRect(x: 0, y: rail, width: width, height: floorLine - rail)),
                with: .color(P.rum.color.opacity(0.18))
            )
            ctx.fill(
                Path(CGRect(x: 0, y: rail - 2.5, width: width, height: 2.5)),
                with: .color(P.ink.color.opacity(0.30))
            )
            ctx.fill(
                Path(CGRect(x: 0, y: rail, width: width, height: 1.5)),
                with: .color(P.cream.color.opacity(0.22))
            )
            ctx.fill(
                Path(CGRect(x: 0, y: floorLine - height * 0.012, width: width, height: height * 0.012)),
                with: .color(P.rum.color.opacity(0.30))
            )
            for i in -9..<53 {
                let x: Double = bleed + Double(w) * Double(i) / 44.0
                guard x > -2, x < width + 2 else { continue }
                ctx.fill(
                    Path(CGRect(x: x, y: line, width: 1.2, height: rail - line)),
                    with: .color(P.ink.color.opacity(0.045))
                )
            }
            // Floor: baseboard ink, wood, plank seams on the 1/18 grid.
            ctx.fill(
                Path(CGRect(x: 0, y: floorLine, width: width, height: beam)),
                with: .color(P.ink.color)
            )
            ctx.fill(
                Path(CGRect(x: 0, y: floorLine + beam, width: width, height: height - floorLine - beam)),
                with: .color(P.driftwood.color)
            )
            for i in -4..<23 {
                let x: Double = bleed + Double(w) * Double(i) / 18.0
                guard x > -2, x < width + 2 else { continue }
                var seam = Path()
                seam.move(to: CGPoint(x: x, y: floorLine + beam))
                seam.addLine(to: CGPoint(x: x, y: height))
                ctx.stroke(seam, with: .color(P.plank.color), lineWidth: 1.5)
            }
        }
        .frame(width: w + 2 * bleedW, height: h)
        .position(x: w / 2, y: h / 2)
        .allowsHitTesting(false)
    }

    /// Mid-century bones for the big coral plane (device round 2 — "the
    /// wall is so bland"): a deeper wainscot band under a hard chair rail,
    /// a skirting step above the baseboard, and faint batten seams pacing
    /// the upper wall like the floor planks. All translucent overlays, so
    /// the wall's 90 s coral-rum breath keeps working beneath them.
    private var wallDressing: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let rail: Double = height * 0.635
            let floorLine: Double = height * 0.78
            // Wainscot: the band a real bar would panel.
            ctx.fill(
                Path(CGRect(x: 0, y: rail, width: width, height: floorLine - rail)),
                with: .color(P.rum.color.opacity(0.18))
            )
            // Chair rail: ink shadow above, cream catch-light below.
            ctx.fill(
                Path(CGRect(x: 0, y: rail - 2.5, width: width, height: 2.5)),
                with: .color(P.ink.color.opacity(0.30))
            )
            ctx.fill(
                Path(CGRect(x: 0, y: rail, width: width, height: 1.5)),
                with: .color(P.cream.color.opacity(0.22))
            )
            // Skirting: one deeper step just above the baseboard ink.
            ctx.fill(
                Path(CGRect(x: 0, y: floorLine - height * 0.012, width: width, height: height * 0.012)),
                with: .color(P.rum.color.opacity(0.30))
            )
            // Batten seams, beam to rail — rhythm, not stripes.
            for i in 1..<44 {
                let x: Double = width * Double(i) / 44.0
                ctx.fill(
                    Path(CGRect(x: x, y: height * Double(Self.ceilingLine), width: 1.2, height: rail - height * Double(Self.ceilingLine))),
                    with: .color(P.ink.color.opacity(0.045))
                )
            }
        }
        .frame(width: w, height: h)
        .position(x: w / 2, y: h / 2)
        .allowsHitTesting(false)
    }

    /// The lid (2026-07 retune, water pass): the roof is the Tiki Stacks
    /// lagoon inverted overhead — flat lagoon plane, four rows of cream
    /// wavelets animated on the same `t` clock, an ink beam as the sea
    /// line, and pendant lanterns hanging off it. The lounge sits under a
    /// glassy ceiling looking straight up at the water. Two cues sell the
    /// looking-up read (fresh-eyes 2026-07-16 — a bare plane scanned as
    /// unfinished sky): the sun as a stepped refraction disc over the
    /// opening frame, and slow flat-ink fish crossing between us and the
    /// light. Both ride `t`, so reduceMotion holds them still.
    private var ceiling: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let line: Double = height * Double(Self.ceilingLine)
            let beam: Double = height * 0.012
            let waterBottom: Double = line - beam
            // Lagoon plane. Same fill Tiki Stacks paints beneath its horizon.
            ctx.fill(
                Path(CGRect(x: 0, y: 0, width: width, height: waterBottom)),
                with: .color(P.lagoon.color)
            )
            // The sun from underneath: hard-stepped rings, no gradients —
            // parked over the east opening frame (world 0.75), swaying and
            // sinking a touch on the 90 s breath. West water stays deep.
            let breath: Double = (1 - cos(t * 2 * .pi / 90)) / 2
            let sunX: Double = width * 0.75 + 14 * sin(t * 2 * .pi / 90)
            let sunY: Double = waterBottom * (0.30 + 0.10 * breath)
            let sunR: Double = waterBottom * 0.16
            for (mul, alpha) in [(1.8, 0.07), (1.35, 0.12), (1.0, 0.28)] {
                let r: Double = sunR * mul
                ctx.fill(
                    Path(ellipseIn: CGRect(x: sunX - r, y: sunY - r, width: r * 2, height: r * 2)),
                    with: .color(P.cream.color.opacity(alpha))
                )
            }
            // Four rows of wavelets (TikiBackgroundView `ocean`, tide=0).
            for row in 0..<4 {
                let fr: Double = Double(row)
                let y: Double = 12 + waterBottom * (0.15 + 0.22 * fr)
                let amp: Double = 2.0 + 0.7 * fr
                let speed: Double = 0.55 + 0.14 * fr
                var path = Path()
                var first = true
                var x: Double = 0
                while x <= width {
                    let angle: Double = x / 85 * 2 * .pi + t * speed + fr * 1.7
                    let yy: Double = y + amp * sin(angle)
                    let point = CGPoint(x: x, y: yy)
                    if first { path.move(to: point); first = false } else { path.addLine(to: point) }
                    x += 6
                }
                ctx.stroke(path, with: .color(P.cream.color.opacity(0.26)), lineWidth: 1.9)
            }
            // Passers-by between us and the light: flat ink silhouettes on
            // slow crossings — lane, length, seconds-per-crossing, phase,
            // heading. One or two are usually somewhere over the room.
            let fishLanes: [(y: Double, len: Double, secs: Double, phase: Double, dir: Double)] = [
                (0.18, 34, 70, 0.00, 1), (0.30, 26, 95, 0.45, -1), (0.09, 22, 120, 0.80, 1),
            ]
            for f in fishLanes {
                let travel: Double = width + 2 * f.len
                let prog: Double = (t / f.secs + f.phase).truncatingRemainder(dividingBy: 1)
                let x: Double = f.dir > 0 ? prog * travel - f.len : width + f.len - prog * travel
                let y: Double = waterBottom * f.y + 3 * sin(t * 2 * .pi / 11 + f.phase * 7)
                var fish = Path()
                fish.addEllipse(in: CGRect(x: x - f.len * 0.36, y: y - f.len * 0.14,
                                           width: f.len * 0.72, height: f.len * 0.28))
                fish.move(to: CGPoint(x: x - f.dir * f.len * 0.30, y: y))
                fish.addLine(to: CGPoint(x: x - f.dir * f.len * 0.58, y: y - f.len * 0.16))
                fish.addLine(to: CGPoint(x: x - f.dir * f.len * 0.58, y: y + f.len * 0.16))
                fish.closeSubpath()
                ctx.fill(fish, with: .color(P.ink.color.opacity(0.16)))
            }
            // Ink beam — the sea line that becomes the room's ceiling.
            ctx.fill(
                Path(CGRect(x: 0, y: waterBottom, width: width, height: beam)),
                with: .color(P.ink.color)
            )
            // Caustic dapple just under the beam: the lagoon's light reaches
            // into the room, tying the frame's two halves together.
            // Deliberately subliminal — shapes you feel, not count.
            for ci in 0..<5 {
                let fc: Double = Double(ci)
                let cw: Double = width * (0.055 + 0.02 * fc.truncatingRemainder(dividingBy: 2))
                let cxp: Double = width * ((0.11 + 0.19 * fc) + 0.012 * sin(t * 2 * .pi / 34 + fc * 2.1))
                let cy: Double = line + height * (0.012 + 0.006 * fc.truncatingRemainder(dividingBy: 3))
                let ca: Double = 0.05 + 0.035 * sin(t * 2 * .pi / 21 + fc * 2.6)
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cxp - cw / 2, y: cy, width: cw, height: width * 0.011)),
                    with: .color(P.cream.color.opacity(max(ca, 0)))
                )
            }
            // Pendant lanterns on staggered cords, hanging from the beam.
            // 0.56 not 0.54: the east opening frame starts at world 0.545,
            // and a lantern astride that seam gets guillotined on open.
            let lanterns: [(Double, Double)] = [
                (0.08, 0.455), (0.24, 0.435), (0.56, 0.47), (0.92, 0.445),
            ]
            for (i, spot) in lanterns.enumerated() {
                let x: Double = width * spot.0
                let bottom: Double = height * spot.1
                let lw: Double = width * 0.016
                let lh: Double = lw * 1.15
                // Light pass: each pendant pools a little warmth on the wall
                // behind it — the room's first cast light. Slow per-lantern
                // breathing keeps it alive without reading as a blinker.
                let glowPulse: Double = 0.8 + 0.2 * sin(t * 2 * .pi / 7 + Double(i) * 1.9)
                let glowR: Double = lw * 3.4
                let bulbY: Double = bottom - lh / 2
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - glowR, y: bulbY - glowR, width: glowR * 2, height: glowR * 2)),
                    with: .radialGradient(
                        Gradient(colors: [P.torch.color.opacity(0.16 * glowPulse), .clear]),
                        center: CGPoint(x: x, y: bulbY),
                        startRadius: 0,
                        endRadius: glowR
                    )
                )
                var cord = Path()
                cord.move(to: CGPoint(x: x, y: line))
                cord.addLine(to: CGPoint(x: x, y: bottom - lh))
                ctx.stroke(cord, with: .color(P.ink.color), lineWidth: 1.5)
                ctx.fill(
                    Path(roundedRect: CGRect(x: x - lw / 2, y: bottom - lh, width: lw, height: lh), cornerRadius: lw * 0.45),
                    with: .color(i % 2 == 0 ? P.torch.color : P.cream.color)
                )
                for capY in [bottom - lh - 1.5, bottom - 2.5] {
                    ctx.fill(
                        Path(roundedRect: CGRect(x: x - lw * 0.24, y: capY, width: lw * 0.48, height: 4), cornerRadius: 2),
                        with: .color(P.ink.color)
                    )
                }
            }
        }
        .frame(width: w, height: h)
        .position(x: w / 2, y: h / 2)
        .allowsHitTesting(false)
    }

    // MARK: lagoon life

    /// A water item's staging. Unlike furniture, lagoon items are bought,
    /// not placed — they drift, bob, and stand watch on their own. lane is
    /// the center-y as a fraction of screen height (the water band runs
    /// 0…ceilingLine); all sprites share the 140×130 delivery viewBox.
    struct LagoonItem {
        enum Motion {
            case drift(period: Double, dir: CGFloat) // crosses the world, wraps
            case moored(worldX: CGFloat)             // fixed x, bobs on the swell
            case landmark(worldX: CGFloat)           // fixed scenery
        }
        let id: String
        let image: Image
        let widthF: CGFloat   // screen-width fraction
        let lane: CGFloat     // center y, fraction of h
        let motion: Motion
        let phase: Double
        let bob: CGFloat      // swell amplitude, pt
        let rock: Double      // roll amplitude, degrees
    }

    /// Surface floaters ride high, creatures swim the mid-band, landmarks
    /// park where the pan reveals them. Directions match each sprite's
    /// native facing so nothing ever renders mirrored.
    static let lagoonItems: [LagoonItem] = [
        LagoonItem(id: "buoy", image: .buoy, widthF: 0.06, lane: 0.065,
                   motion: .moored(worldX: 0.885), phase: 0.13, bob: 5, rock: 6),
        LagoonItem(id: "lagoonDuck", image: .lagoonDuck, widthF: 0.065, lane: 0.055,
                   motion: .drift(period: 150, dir: 1), phase: 0.48, bob: 3, rock: 3),
        LagoonItem(id: "messageBottle", image: .messageBottle, widthF: 0.06, lane: 0.078,
                   motion: .moored(worldX: 0.42), phase: 0.71, bob: 5, rock: 5),
        LagoonItem(id: "dolphin", image: .dolphin, widthF: 0.10, lane: 0.22,
                   motion: .drift(period: 60, dir: -1), phase: 0.05, bob: 6, rock: 0),
        LagoonItem(id: "seaTurtle", image: .seaTurtle, widthF: 0.09, lane: 0.30,
                   motion: .drift(period: 170, dir: 1), phase: 0.33, bob: 5, rock: 0),
        LagoonItem(id: "sailboat", image: .sailboat, widthF: 0.13, lane: 0.075,
                   motion: .drift(period: 110, dir: 1), phase: 0.62, bob: 2, rock: 1.6),
        LagoonItem(id: "shark", image: .shark, widthF: 0.115, lane: 0.26,
                   motion: .drift(period: 75, dir: -1), phase: 0.82, bob: 4, rock: 0),
        LagoonItem(id: "orca", image: .orca, widthF: 0.13, lane: 0.32,
                   motion: .drift(period: 95, dir: -1), phase: 0.27, bob: 5, rock: 0),
        LagoonItem(id: "farIsland", image: .farIsland, widthF: 0.20, lane: 0.16,
                   motion: .landmark(worldX: 0.10), phase: 0, bob: 0, rock: 0),
        LagoonItem(id: "volcano", image: .volcano, widthF: 0.22, lane: 0.18,
                   motion: .landmark(worldX: 0.52), phase: 0, bob: 0, rock: 0),
        LagoonItem(id: "yacht", image: .yacht, widthF: 0.25, lane: 0.085,
                   motion: .drift(period: 130, dir: 1), phase: 0.90, bob: 2, rock: 1.2),
    ]

    /// Current frame for a lagoon item: drifters wrap the whole world with
    /// a margin so they fully exit before re-entering; everyone rides a
    /// gentle swell except the landmarks.
    func waterFrame(_ item: LagoonItem) -> CGRect {
        let iw = w * span(item.widthF)
        let ih = iw * 130.0 / 140.0
        let x: CGFloat
        switch item.motion {
        case .drift(let period, let dir):
            let m = iw * 1.5
            let cycle = ((t / period) + item.phase).truncatingRemainder(dividingBy: 1)
            let run = (w + 2 * m) * CGFloat(cycle)
            x = dir > 0 ? run - m : w + m - run
        case .moored(let wx), .landmark(let wx):
            x = wx * w
        }
        let bob = item.bob * sin(t * 2 * .pi / 3.9 + item.phase * 11)
        return CGRect(x: x - iw / 2, y: item.lane * h + bob - ih / 2, width: iw, height: ih)
    }

    private var lagoonLife: some View {
        ZStack {
            ForEach(Self.lagoonItems, id: \.id) { item in
                if placed.contains(item.id) {
                    let f = waterFrame(item)
                    let roll = item.rock * sin(t * 2 * .pi / 4.3 + item.phase * 9)
                    Group {
                        if item.id == "messageBottle" {
                            // The one interactive floater: tapping it
                            // surfaces a note in Vic's voice.
                            item.image
                                .resizable()
                                .scaledToFit()
                                .frame(width: f.width, height: f.height)
                                .rotationEffect(.degrees(roll))
                                .position(x: f.midX, y: f.midY)
                                .onTapGesture(perform: bottleTapped)
                        } else {
                            item.image
                                .resizable()
                                .scaledToFit()
                                .frame(width: f.width, height: f.height)
                                .rotationEffect(.degrees(roll))
                                .position(x: f.midX, y: f.midY)
                                .allowsHitTesting(false)
                        }
                        if item.id == "volcano" {
                            // Crater glow: torch-warm, breathing — the
                            // lagoon's one light source of its own.
                            Circle()
                                .fill(P.torch.color.opacity(0.10 + 0.08 * breath))
                                .frame(width: f.width * 0.55, height: f.width * 0.55)
                                .blur(radius: f.width * 0.10)
                                .position(x: f.midX, y: f.minY + f.height * 0.22)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
        }
    }

    private var dustMotes: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let seeds: [(Double, Double)] = [
                (0.04, 0.30), (0.10, 0.62), (0.17, 0.18), (0.24, 0.50),
                (0.30, 0.28), (0.36, 0.66), (0.42, 0.40), (0.49, 0.24),
                (0.55, 0.58), (0.62, 0.34), (0.68, 0.62), (0.75, 0.20),
                (0.81, 0.52), (0.87, 0.30), (0.93, 0.64), (0.97, 0.42),
            ]
            for (i, seed) in seeds.enumerated() {
                let fi: Double = Double(i)
                let x: Double = seed.0 * width + width * 0.035 * sin(t * 2 * .pi / 190 + fi * 2.4)
                let y: Double = seed.1 * height + height * 0.16 * sin(t * 2 * .pi / 150 + fi * 1.8)
                let alpha: Double = (0.05 + 0.05 * sin(t * 2 * .pi / 165 + fi * 3.1)) * (0.5 + 0.5 * breath)
                let r: Double = i % 3 == 0 ? 2.6 : 1.8
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(P.cream.color.opacity(alpha))
                )
            }
        }
        .frame(width: w, height: h * 0.30)
        .position(x: w / 2, y: h * 0.62)
        .allowsHitTesting(false)
    }

    private var floorAndRug: some View {
        Canvas { ctx, sz in
            let width: Double = Double(sz.width)
            let height: Double = Double(sz.height)
            let fl: Double = height * 0.78
            let base: Double = height * 0.012
            // Baseboard shadow line, then the plank floor.
            ctx.fill(Path(CGRect(x: 0, y: fl, width: width, height: base)), with: .color(P.ink.color))
            ctx.fill(
                Path(CGRect(x: 0, y: fl + base, width: width, height: height - fl - base)),
                with: .color(P.driftwood.color)
            )
            for i in 1..<18 {
                let x: Double = width * Double(i) / 18.0
                var seam = Path()
                seam.move(to: CGPoint(x: x, y: fl + base))
                seam.addLine(to: CGPoint(x: x, y: height))
                ctx.stroke(seam, with: .color(P.plank.color), lineWidth: 1.5)
            }
            // (The hero's east rug trapezoid lived here until 2026-07-16 —
            // Carson cut it; the plank floor carries the bar zone, and THE
            // RUG catalog item is the one true rug.)
            // Light pass: owned windows spill their sunset onto the planks —
            // a wedge of low-sun warmth, skewed east and drawn before the
            // ghosts and furniture so everything stands in it.
            for (owned, f) in [(placed.contains("sunsetWindow"), windowFrame),
                               (placed.contains("bayWindow"), bayWindowFrame)] where owned {
                let inset: Double = Double(f.width) * 0.10
                let spread: Double = Double(f.width) * 0.16
                let sx0: Double = Double(f.minX) + inset
                let sx1: Double = Double(f.maxX) - inset
                let yTop: Double = fl + base
                let yBot: Double = min(height, yTop + height * 0.115)
                var spill = Path()
                spill.move(to: CGPoint(x: sx0, y: yTop))
                spill.addLine(to: CGPoint(x: sx1, y: yTop))
                spill.addLine(to: CGPoint(x: sx1 + spread * 1.8, y: yBot))
                spill.addLine(to: CGPoint(x: sx0 + spread * 0.6, y: yBot))
                spill.closeSubpath()
                ctx.fill(spill, with: .linearGradient(
                    Gradient(colors: [P.torch.color.opacity(0.10), P.torch.color.opacity(0.02)]),
                    startPoint: CGPoint(x: sx0, y: yTop),
                    endPoint: CGPoint(x: sx0, y: yBot)
                ))
            }
        }
        .frame(width: w, height: h)
        .position(x: w / 2, y: h / 2)
    }

    /// Empty-state invitation: clean patches and nails on the wall where the
    /// hanging pieces belong, and dust shadows on the floor where furniture
    /// will sit — the room says what it wants to become.
    private var ghostHooks: some View {
        let hooks: [(String, CGRect)] = [
            ("sunsetWindow", windowFrame),
            ("blowfishLamp", lampFrame),
            ("glassFloat", floatFrame),
            ("backBarShelf", shelfFrame),
            ("marlin", marlinFrame),
            ("aquarium", aquariumFrame),
            ("bayWindow", bayWindowFrame),
        ]
        // Floor set includes the west statement trio (piano/couch/table):
        // their silhouettes are what tells a new player the room keeps
        // going past the opening frame.
        let marks: [(String, CGRect)] = [
            ("tikiStatue", statueFrame),
            ("palmPlant", palmFrame),
            ("recordCredenza", credenzaFrame),
            ("barStools", stoolsFrame),
            ("grandPiano", pianoFrame),
            ("loungeCouch", couchFrame),
            ("highTable", highTableFrame),
        ]
        // Ghosts render the actual art, desaturated and faint — a wishbook
        // of what could hang here, not an anonymous patch. ONE grammar for
        // wall and floor (round 2: the pale hook cards read as wall stains
        // while the darker floor silhouettes read as furniture you already
        // own — the card is gone and the alphas meet in the middle: wall
        // art up to 0.26, floor art down to 0.12). Tapping one opens the
        // shop at its row (taps never claim moving touches, so room pans
        // over ghosts still win).
        return ZStack {
            ForEach(hooks.filter { !placed.contains($0.0) }, id: \.0) { hook in
                ZStack {
                    LoungeSprites.thumbnail(for: hook.0)
                        .saturation(0)
                        .opacity(0.26)
                    Circle()
                        .fill(P.ink.color.opacity(0.5))
                        .frame(width: 4, height: 4)
                        .position(x: hook.1.width / 2, y: 3)
                }
                .frame(width: hook.1.width, height: hook.1.height)
                .contentShape(Rectangle())
                .onTapGesture { openShop(hook.0) }
                .position(x: hook.1.midX, y: hook.1.midY)
            }
            // No ground ellipses under the silhouettes — on device the
            // scattered ink ovals read as random floor stains (round 2);
            // the ghost art grounds itself.
            ForEach(marks.filter { !placed.contains($0.0) }, id: \.0) { mark in
                LoungeSprites.thumbnail(for: mark.0)
                    .saturation(0)
                    .opacity(0.12)
                    .frame(width: mark.1.width, height: mark.1.height)
                    .contentShape(Rectangle())
                    .onTapGesture { openShop(mark.0) }
                    .position(x: mark.1.midX, y: mark.1.midY)
            }
        }
    }

    // MARK: hanging layer

    private var hangingLayer: some View {
        ZStack {
            if placed.contains("ceilingFan") {
                placedImage(.ceilingFan, fanFrame)
                placedImage(Image.ceilingFanBlades[Int(t / 0.18) % 3], fanFrame)
            }
            if placed.contains("marlin") {
                movableImage(.marlin, "marlin", marlinFrame)
            }
            if placed.contains("neonTikiSign") {
                // Light pass: a soft coral halo on the wall behind the neon —
                // the sign finally lights the corner it names. Slow breath
                // with a once-in-a-while hiccup (the >0.985 sin window opens
                // for ~half a second every ~47 s).
                let haloDip: Double = sin(t * 2 * .pi / 47) > 0.985 ? 0.4 : 1.0
                RadialGradient(
                    colors: [P.coral.color.opacity(0.30), P.coral.color.opacity(0.10), .clear],
                    center: .center, startRadius: 0, endRadius: signFrame.height * 0.85
                )
                .frame(width: signFrame.height * 1.9, height: signFrame.height * 1.9)
                .position(x: signFrame.midX, y: signFrame.midY)
                .opacity((0.8 + 0.2 * sin(t * 2 * .pi / 13)) * haloDip)
                .allowsHitTesting(false)
                movableImage(.neonTikiSign, "neonTikiSign", signFrame)
                placedImage(.neonTikiSignGlow, signFrame)
                    .opacity(max(0.35, 0.7 + 0.3 * (0.6 * sin(t * 8.1) + 0.4 * sin(t * 33 + 2))))
                    .allowsHitTesting(false)
            }
            if placed.contains("aquarium") {
                movableImage(.aquarium, "aquarium", aquariumFrame)
                ForEach(0..<min(aquariumFish, Image.aquariumFish.count), id: \.self) { i in
                    placedImage(Image.aquariumFish[i], aquariumFrame)
                        .allowsHitTesting(false)
                }
            }
            if placed.contains("sunsetWindow") {
                // Lounge v2: the east window is LIVE — a palette scene on the
                // 90 s breath. Tap cycles earned views (LiveWindowView).
                LiveWindowView(t: t, view: WindowViewKind(rawValue: windowEast) ?? .sunset)
                    .frame(width: windowFrame.width, height: windowFrame.height)
                    .position(x: windowFrame.midX, y: windowFrame.midY)
                    .transition(popIn)
                    .onTapGesture { cycleWindow(true) }
            }
            if placed.contains("bayWindow") {
                LiveWindowView(t: t, view: WindowViewKind(rawValue: windowWest) ?? .sunset)
                    .frame(width: bayWindowFrame.width, height: bayWindowFrame.height)
                    .position(x: bayWindowFrame.midX, y: bayWindowFrame.midY)
                    .transition(popIn)
                    .onTapGesture { cycleWindow(false) }
            }
            if placed.contains("blowfishLamp") {
                HangingSprite(image: .blowfishLamp, frame: lampFrame, cordTop: h * Self.ceilingLine, sway: 2.5 * sin(t * 2 * .pi / 9))
                    .transition(popIn)
                    .gesture(liftDrag(id: "blowfishLamp", startCx: lampFrame.midX / w, halfW: lampFrame.width / (2 * w)))
            }
            if placed.contains("glassFloat") {
                HangingSprite(image: .glassFloat, frame: floatFrame, cordTop: h * Self.ceilingLine, sway: 1.6 * sin(t * 2 * .pi / 13 + 1.2))
                    .transition(popIn)
                    .gesture(liftDrag(id: "glassFloat", startCx: floatFrame.midX / w, halfW: floatFrame.width / (2 * w)))
            }
            if placed.contains("backBarShelf") {
                placedImage(.backBarShelf, shelfFrame)
            }
            if placed.contains("parrot") {
                placedImage(.parrot, parrotFrame)
            }
        }
    }

    // MARK: bar zone

    private var vic: some View {
        // Vic breathes: a slow, tiny bob so the empty room still feels tended.
        let bob: CGFloat = 3.0 * sin(t * 2 * .pi / 4.6)
        return ZStack {
            if nightlyReady {
                vicGlow(bob: bob)
            }
            Image.bartenderVic
                .resizable()
                .scaledToFit()
                .frame(width: vicFrame.width, height: vicFrame.height)
                // He tips into the pour. Anchored at the bottom, where his
                // planted side disappears behind the bar, so the lean reads
                // as a handoff rather than the whole man sliding.
                .rotationEffect(.degrees(pourTilt), anchor: .bottom)
                .position(x: vicFrame.midX, y: vicFrame.midY + bob)
            if nightlyReady {
                // The glow alone measured ~1.9:1 against a coral wall — real
                // but not a summons, and the room's only other cue was the
                // SHOP pill's red dot. The picker card's own banner, set down
                // on the counter in front of him like a chit.
                //
                LoungePourBanner()
                    .position(x: vicFrame.midX, y: pourBannerY + bob)
                    .allowsHitTesting(false)
            }
            if placed.contains("flamingMug") {
                placedImage(.flamingMug, mugFrame, offsetY: bob)
                mugFlicker(bob: bob)
            }
            if coachWelcomeActive {
                // The welcome coach's SHOP beat: the copy names the mug, so
                // Vic's tap answers with the shop's FREE row and a pulse
                // sits on his raised hand — the world answers the card.
                Color.clear
                    .frame(width: vicFrame.width * 1.2, height: vicFrame.height)
                    .contentShape(Rectangle())
                    .onTapGesture { openShop("flamingMug") }
                    .position(x: vicFrame.midX, y: vicFrame.midY + bob)
                CoachPulse(skin: .lounge, diameter: mugFrame.width * 3.0)
                    .position(x: mugFrame.midX, y: mugFrame.midY + bob)
                    .allowsHitTesting(false)
            } else {
                // Any other time — mug claimed or not — Vic answers a tap
                // with tonight's board. (v1 gated this on the mug being
                // placed; a save that staged past the FTUE never claimed
                // the gift, so Vic kept opening the shop — device round.)
                Color.clear
                    .frame(width: vicFrame.width * 1.2, height: vicFrame.height)
                    .contentShape(Rectangle())
                    .onTapGesture { vicTapped() }
                    .position(x: vicFrame.midX, y: vicFrame.midY + bob)
                    .accessibilityLabel("Daily goals")
                    .accessibilityValue(nightlyReady
                        ? "Reward ready. Tap Vic to claim."
                        : "\(nightlyDone) of 9 done")
                    .accessibilityAddTraits(.isButton)
            }
            if let reward = dailyPour {
                DailyPourFloat(
                    reward: reward,
                    art: vicFrame.width * 0.68,
                    // Up into the band the banner just left, not down onto the
                    // counter: the bar zone paints over anything below it.
                    captionOffsetY: pourBannerY - vicHandPoint.y
                )
                .position(x: vicHandPoint.x, y: vicHandPoint.y + bob)
                .allowsHitTesting(false)
            }
        }
    }

    /// Vic's raised hand, in the sprite's own design box (bartender-vic.svg,
    /// 87x150): the forearm runs `M542 172 L524 190` then `L516 170`, so the
    /// hand lands at (14, 70).
    ///
    /// The pour used to anchor to `mugFrame` — which is the FLAMING MUG shop
    /// slot, not the hand, and whose `minY` is the top of Vic's whole sprite
    /// box. The reward launched from 70 design units above his fingers and
    /// drifted out over the WALK-IN sign.
    private var vicHandPoint: CGPoint {
        let v = vicFrame
        return CGPoint(x: v.minX + v.width * 14.0 / 87.0,
                       y: v.minY + v.height * 70.0 / 150.0)
    }

    /// The banner's only home: the band of clear wall between the house
    /// plaque's lower edge (drawn at 1.5x) and the top of Vic's hair, which
    /// begins 18.5/150 into his sprite box. ~47 pt on a 402x874 screen.
    ///
    /// Not the counter in front of him, which reads as the obvious spot — the
    /// bar zone paints AFTER Vic (his lower body is meant to be hidden by it),
    /// so anything hung at counter height is covered by the counter.
    private var pourBannerY: CGFloat {
        let plaqueBottom = plaqueFrame.midY + plaqueFrame.height * 1.5 / 2
        let hairTop = vicFrame.minY + vicFrame.height * 18.5 / 150
        return (plaqueBottom + hairTop) / 2
    }

    /// Degrees of lean during the pour: out over 0.30 s, held, back over 0.40.
    /// Smoothstepped so the reversal has no corner in it.
    private var pourTilt: Double {
        guard !reduceMotion, let start = dailyPourStart else { return 0 }
        let e = t - start
        let peak = 5.0
        func smooth(_ x: Double) -> Double {
            let c = min(max(x, 0), 1)
            return c * c * (3 - 2 * c)
        }
        switch e {
        case ..<0: return 0
        case ..<0.30: return peak * smooth(e / 0.30)
        case ..<0.90: return peak
        case ..<1.30: return peak * (1 - smooth((e - 0.90) / 0.40))
        default: return 0
        }
    }

    /// Vic's pour: the reward pops at his hand on a ring of light, names
    /// itself on the counter right below, holds long enough to be read, then
    /// lifts away together.
    ///
    /// v1 drew an ~18 pt sprite that was fully opaque for about a quarter
    /// second — smaller than the 18 pt the `catFrame` note already calls "an
    /// invisible black smudge" — and put its caption at the top of the
    /// screen. Art is 3.7x the area now and the words travel with it.
    ///
    /// @State survives the 30 fps TimelineView re-inits because the view's
    /// tree position is stable while dailyPour holds.
    private struct DailyPourFloat: View {
        let reward: PlayerStore.NightlyReward
        let art: CGFloat
        /// Signed distance from the glyph to the caption's slot on the wall.
        let captionOffsetY: CGFloat
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var popped = false
        @State private var burst = false
        @State private var captioned = false
        @State private var leaving = false

        private let gold = Color(red: 0.910, green: 0.702, blue: 0.235)

        var body: some View {
            ZStack {
                // The handoff's flash — one ring off his hand, gone in half
                // a second. Reduce Motion never scales it.
                Circle()
                    .stroke(gold.opacity(burst ? 0 : 0.85), lineWidth: art * 0.075)
                    .frame(width: art, height: art)
                    .scaleEffect(reduceMotion ? 1.2 : (burst ? 1.8 : 0.35))
                NightlyRewardGlyph(reward: reward)
                    .frame(width: art, height: art)
                    .shadow(color: P.torch.color.opacity(0.8), radius: art * 0.20)
                    .shadow(color: P.ink.color.opacity(0.45), radius: art * 0.06, y: 2)
                    .scaleEffect(popped ? 1 : 0.3)
                    .opacity(popped ? 1 : 0)
            }
            .frame(width: art, height: art)
            // Overlay, not a stacked VStack: the caption must not shift the
            // glyph off Vic's hand.
            .overlay(alignment: .center) {
                caption
                    .offset(y: captionOffsetY + (captioned ? 0 : 8))
                    .opacity(captioned ? 1 : 0)
            }
            .offset(y: leaving ? -art * 0.28 : 0)
            .opacity(leaving ? 0 : 1)
            .onAppear(perform: run)
        }

        /// One line, in the banner's own shape — it takes over the banner's
        /// slot on the wall, which is only ~47 pt tall.
        private var caption: some View {
            Text(reward.pourCaption)
                .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                .tracking(1.4)
                .foregroundStyle(gold)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 10).fill(P.ink.color.opacity(0.88)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(gold.opacity(0.55), lineWidth: 1.5))
            .accessibilityHidden(true)   // the parent posts the announcement
        }

        private func run() {
            guard !reduceMotion else {
                popped = true
                captioned = true
                withAnimation(.easeIn(duration: 0.4).delay(2.0)) { leaving = true }
                return
            }
            withAnimation(.spring(duration: 0.38, bounce: 0.45)) { popped = true }
            withAnimation(.easeOut(duration: 0.55)) { burst = true }
            withAnimation(.easeOut(duration: 0.28).delay(0.30)) { captioned = true }
            // Held ~1.6 s at full strength before it leaves. The old beat
            // began fading at 0.6 s and was gone by the time you looked.
            withAnimation(.easeIn(duration: 0.65).delay(1.95)) { leaving = true }
        }
    }

    /// The pour's herald: tonight's round is earned, so a warm backlight
    /// breathes behind Vic — the room itself says "see the man". Runs on
    /// the world clock (30 fps); Reduce Motion pauses that clock, so the
    /// glow pins to a steady mid-breath instead of freezing mid-swing.
    private func vicGlow(bob: CGFloat) -> some View {
        let breathe = CGFloat(reduceMotion ? 0.5 : 0.5 + 0.5 * sin(t * 2 * .pi / 2.6))
        let gold = Color(red: 0.910, green: 0.702, blue: 0.235)
        let v = vicFrame
        let w = v.width * (1.58 + 0.12 * breathe)
        let h = v.height * (1.14 + 0.07 * breathe)
        return Ellipse()
            .fill(RadialGradient(
                // Gold on a coral wall is hue-adjacent: the all-gold falloff
                // measured a ~1.9:1 peak lift and read as a warm smudge. A
                // blossom core carries the luminance the hue cannot.
                gradient: Gradient(stops: [
                    .init(color: P.blossom.color.opacity(0.40 + 0.20 * breathe), location: 0),
                    .init(color: gold.opacity(0.36 + 0.18 * breathe), location: 0.40),
                    .init(color: gold.opacity(0), location: 1),
                ]),
                center: .center,
                startRadius: 0,
                endRadius: w * 0.52
            ))
            .frame(width: w, height: h)
            // Centered on the visible man, not the sprite: his lower body
            // sits behind the bar, so the sprite's midY reads low.
            .position(x: v.midX, y: v.midY - v.height * 0.13 + bob)
            .allowsHitTesting(false)
    }

    /// Fast-frequency shimmer over the mug's baked flame — the candle trick
    /// from the Zombie scene, riding Vic's bob so it stays in his hand.
    private func mugFlicker(bob: CGFloat) -> some View {
        let flick: Double = 1 + 0.16 * sin(t * 8.3) + 0.09 * sin(t * 57 + 1.7)
        let lean: Double = 3 * sin(t * 6.1) + 1.5 * sin(t * 15)
        let m = mugFrame
        return FlameShape()
            .fill(P.torch.mix(P.coral, 0.35).opacity(0.55))
            .frame(width: m.width * 0.5, height: m.height * 0.26)
            .scaleEffect(x: 1, y: CGFloat(flick), anchor: .bottom)
            .rotationEffect(.degrees(lean), anchor: .bottom)
            .position(x: m.midX, y: m.minY + m.height * 0.32 + bob)
            .allowsHitTesting(false)
    }

    private var bar: some View {
        ZStack {
            Canvas { ctx, sz in
                let width: Double = Double(sz.width)
                let height: Double = Double(sz.height)
                let x0: Double = width * 0.8091   // east(0.58) at the old 2.2 world
                // Counter top at 0.690h: chest height on the 2×-canon patron
                // standing at the bar's foot (0.805h) — grand retune.
                let top: Double = height * 0.690
                let slabH: Double = height * 0.016
                let frontBottom: Double = height * 0.80
                let bambooMid = RGB(0.549, 0.384, 0.224)
                let bambooDeep = RGB(0.478, 0.333, 0.188)
                // Ink top slab (slight left overhang like the hero).
                let overhang: Double = width * Double(span(0.024))
                ctx.fill(
                    Path(CGRect(x: x0 - overhang, y: top, width: width - x0 + overhang, height: slabH)),
                    with: .color(P.ink.color)
                )
                // Bamboo front: a fence of poles — deep seam and a light
                // catch per pole, staggered joint lines (the read that says
                // bamboo), two dim twine lashings riding over the poles.
                // Round 2: 50/50 slats + bright full-width bands read as
                // tartan, not cane.
                let frontH: Double = frontBottom - top - slabH
                ctx.fill(
                    Path(CGRect(x: x0, y: top + slabH, width: width - x0, height: frontH)),
                    with: .color(bambooMid.color)
                )
                let bambooLight = RGB(0.624, 0.455, 0.278)
                let poleCount: Int = 14
                let poleW: Double = (width - x0) / Double(poleCount)
                for i in 0..<poleCount {
                    let sx: Double = x0 + poleW * Double(i)
                    ctx.fill(
                        Path(CGRect(x: sx, y: top + slabH, width: poleW * 0.16, height: frontH)),
                        with: .color(bambooDeep.color)
                    )
                    ctx.fill(
                        Path(CGRect(x: sx + poleW * 0.16, y: top + slabH, width: poleW * 0.18, height: frontH)),
                        with: .color(bambooLight.color)
                    )
                    // Joints stagger on a 3-pole cycle so no horizontal band forms.
                    for k in 0..<2 {
                        let jy: Double = top + slabH + frontH * (0.16 + 0.40 * Double(k) + 0.10 * Double(i % 3))
                        ctx.fill(
                            Path(CGRect(x: sx + poleW * 0.16, y: jy, width: poleW * 0.84, height: 2.4)),
                            with: .color(bambooDeep.color.opacity(0.75))
                        )
                    }
                }
                // Counter overhang shadow: the slab reads as a surface the
                // patrons stand in front of, not a stripe crossing them.
                ctx.fill(
                    Path(CGRect(x: x0, y: top + slabH, width: width - x0, height: height * 0.012)),
                    with: .color(P.ink.color.opacity(0.22))
                )
                // Twine lashings: tight dim pairs, not bright bands.
                let rope: Color = P.cream.mix(P.torch, 0.55).opacity(0.38)
                for yf in [0.30, 0.68] {
                    let y: Double = top + slabH + frontH * yf
                    for off in [-2.4, 2.4] {
                        var lash = Path()
                        lash.move(to: CGPoint(x: x0, y: y + off))
                        lash.addLine(to: CGPoint(x: width, y: y + off))
                        ctx.stroke(lash, with: .color(rope), lineWidth: 1.6)
                    }
                }
            }
            .frame(width: w, height: h)
            .position(x: w / 2, y: h / 2)
            if placed.contains("umbrellaDrink") {
                placedImage(.umbrellaDrink, drinkFrame)
            }
        }
        // Nothing here is interactive, and the Canvas frame spans the WHOLE
        // room — an opaque-to-touch full-frame layer above the ghosts ate
        // every ghost/window tap on device (round 2 finding).
        .allowsHitTesting(false)
    }

    // MARK: floor zone

    private var standingItems: some View {
        ZStack {
            // The rug is floor-flat: always the deepest floor layer no
            // matter where anything stands. Tapping cycles the free
            // colorway (expression, not economy).
            if placed.contains("loungeRug") {
                movableImage(Image.rugColorways[min(max(rugColorway, 0), 3)], "loungeRug", rugFrame)
                    .onTapGesture(perform: cycleRug)
                    .zIndex(-1)
            }
            // Continuous depth: floor pieces stack by their FEET — the
            // lower on the planks (closer to the camera), the later they
            // draw. Rail pieces tie at their designed feet, so the
            // curated declaration order below is the rail composition
            // (bush tucked behind the couch's left arm, the tiered pot
            // behind its right, crowns peeking over — depth, not
            // collision).
            if placed.contains("plantSnake") {
                movableImage(.plantSnake, "plantSnake", plantSnakeFrame)
                    .zIndex(Double(plantSnakeFrame.maxY))
            }
            if placed.contains("plantBush") {
                movableImage(.plantBush, "plantBush", plantBushFrame)
                    .zIndex(Double(plantBushFrame.maxY))
            }
            if placed.contains("plantTiered") {
                movableImage(.plantTiered, "plantTiered", plantTieredFrame)
                    .zIndex(Double(plantTieredFrame.maxY))
            }
            if placed.contains("grandPiano") {
                movableImage(.piano, "grandPiano", pianoFrame)
                    .zIndex(Double(pianoFrame.maxY))
            }
            if placed.contains("loungeCouch") {
                // The Davenport seats its couple once the house knows you:
                // occupied at REGULAR standing. Earned, never sold.
                movableImage(standingTier >= 1 ? .couchCouple : .couch, "loungeCouch", couchFrame)
                    .zIndex(Double(couchFrame.maxY))
            }
            if placed.contains("highTable") {
                // The tall table's toasting couple arrives at ISLANDER. The
                // couple sprite is an overlay sharing the table's viewBox
                // (couch-couple, by contrast, ships as one composition).
                Group {
                    movableImage(.highTable, "highTable", highTableFrame)
                    if standingTier >= 2 {
                        placedImage(.highTableCouple, highTableFrame)
                            .allowsHitTesting(false)
                    }
                }
                .zIndex(Double(highTableFrame.maxY))
            }
            if placed.contains("tikiStatue") {
                movableImage(.tikiStatue, "tikiStatue", statueFrame)
                    .zIndex(Double(statueFrame.maxY))
            }
            if placed.contains("palmPlant") {
                movableImage(.palmPlant, "palmPlant", palmFrame)
                    .zIndex(Double(palmFrame.maxY))
            }
            if placed.contains("suspiciousCat") {
                movableImage(.suspiciousCat, "suspiciousCat", catFrame)
                    .zIndex(Double(catFrame.maxY))
            }
            if placed.contains("recordCredenza") {
                Group {
                    movableImage(.recordCredenza, "recordCredenza", credenzaFrame)
                    spinningDisc
                        .allowsHitTesting(false)
                }
                .zIndex(Double(credenzaFrame.maxY))
            }
            if zombieTrophy {
                // Rides the credenza (frame derives from credenzaFrame).
                Group {
                    placedImage(.zombieTrophyMug, trophyFrame)
                        .allowsHitTesting(false)
                    placedImage(.zombieTrophyMugGlow, trophyFrame)
                        .opacity(0.35 + 0.65 * breath)
                        .allowsHitTesting(false)
                }
                .zIndex(Double(credenzaFrame.maxY))
            }
            if placed.contains("barStools") {
                movableImage(.barStools, "barStools", stoolsFrame)
                    .zIndex(Double(stoolsFrame.maxY))
            }
            if placed.contains("martiniWoman") {
                movableImage(.martiniWoman, "martiniWoman", womanFrame)
                    .zIndex(Double(womanFrame.maxY))
            }
            if placed.contains("highballMan") {
                movableImage(.highballMan, "highballMan", manFrame)
                    .zIndex(Double(manFrame.maxY))
            }
            // Fronds are the nearest layer of all — screen-edge foliage
            // framing the room — above anything on the floor.
            if placed.contains("cornerFronds") {
                movableImage(.cornerFronds, "cornerFronds", frondsFrame)
                    .zIndex(100_000)
            }
        }
    }

    /// The credenza's platter as a separate layer, spinning at a stylized 33 rpm.
    /// Offsets come from the disc's world rect within the credenza's.
    private var spinningDisc: some View {
        let c = credenzaFrame
        let dw: CGFloat = c.width * 22.0 / 188.0
        let dx: CGFloat = c.minX + c.width * 25.0 / 188.0 + dw / 2
        let dy: CGFloat = c.minY + c.height * 17.0 / 114.0 + dw / 2
        return Image.recordDisc
            .resizable()
            .scaledToFit()
            .frame(width: dw, height: dw)
            .rotationEffect(.degrees(t.truncatingRemainder(dividingBy: 3) * 120))
            .position(x: dx, y: dy)
    }

    // MARK: helpers

    private var popIn: AnyTransition {
        .scale(scale: 0.1).combined(with: .opacity)
    }

    private func placedImage(_ image: Image, _ rect: CGRect, offsetY: CGFloat = 0) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY + offsetY)
            .transition(popIn)
    }

    /// placedImage's twin for the vector economy-pass sprites.
    private func placedSprite<V: View>(_ sprite: V, _ rect: CGRect) -> some View {
        sprite
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .transition(popIn)
    }
}

/// One burst star: springs in at the fresh purchase's anchor, then fades.
/// Local animation state only — nothing here is session state.
struct LoungeBurst: View {
    @State private var shown = false
    @State private var faded = false

    var body: some View {
        Image.fxBurst
            .resizable()
            .scaledToFit()
            .scaleEffect(shown ? (faded ? 1.25 : 1) : 0.05)
            .opacity(faded ? 0 : (shown ? 1 : 0))
            .rotationEffect(.degrees(shown ? 18 : -20))
            .onAppear {
                withAnimation(.spring(duration: 0.32, bounce: 0.4)) { shown = true }
                withAnimation(.easeOut(duration: 0.45).delay(0.55)) { faded = true }
            }
    }
}

/// A ceiling-hung sprite: ink cord from the rafter line (`cordTop`) to the
/// item, the whole assembly swaying gently around its ceiling pivot.
struct HangingSprite: View {
    let image: Image
    let frame: CGRect
    let cordTop: CGFloat
    let sway: Double

    var body: some View {
        let drop = max(frame.maxY - cordTop, frame.height)
        ZStack(alignment: .top) {
            // The cord stops just inside the art's top edge — the sprites
            // carry their own cord stub down to the fixture, so a full-drop
            // cord skewers the piece and pokes out beneath it (round 2 zoom).
            Rectangle()
                .fill(P.ink.color)
                .frame(width: 1.5, height: max(drop - frame.height * 0.86, 0))
            image
                .resizable()
                .scaledToFit()
                .frame(width: frame.width, height: frame.height)
                .frame(height: drop, alignment: .bottom)
        }
        .frame(width: frame.width, height: drop, alignment: .top)
        .rotationEffect(.degrees(sway), anchor: .top)
        .position(x: frame.midX, y: frame.maxY - drop / 2)
    }
}

#if DEBUG
// MARK: - Proportion audit

extension LoungeRoomView {
    /// Executable proof of the room's proportion system (the lounge's answer
    /// to the games' ROTTEST-style hooks): re-derives every anchor at a
    /// reference size and checks the invariants of the 2026-07 retune —
    /// wall height, the counter-at-the-chest band, window sills, hanging
    /// heights, one standing band, head canon, and default-anchor clearance.
    /// Prints one line per invariant and a final tally.
    static func runProportionAudit() {
        // The room view takes the WORLD size (worldScreens x one screen).
        let size = CGSize(width: 440 * Self.worldScreens, height: 956)
        let room = LoungeRoomView(
            t: 0, size: size, placed: [], justPlaced: nil, zombieTrophy: false,
            standing: "WALK-IN", standingTier: 0, aquariumFish: 0,
            windowEast: "sunset", windowWest: "sunset", rugColorway: 0,
            positions: [:], depths: [:],
            cycleWindow: { _ in }, cycleRug: {}, commitPlacement: { _, _, _ in },
            openShop: { _ in },
            coachWelcomeActive: false,
            wiggleID: nil
        )
        // A second room with every eligible piece at full depth — the
        // continuous-depth frames are checked against this instance.
        let downRoom = LoungeRoomView(
            t: 0, size: size, placed: [], justPlaced: nil, zombieTrophy: false,
            standing: "WALK-IN", standingTier: 0, aquariumFish: 0,
            windowEast: "sunset", windowWest: "sunset", rugColorway: 0,
            positions: [:],
            depths: Dictionary(uniqueKeysWithValues: Self.depthEligible.map { ($0, 1.0) }),
            cycleWindow: { _ in }, cycleRug: {}, commitPlacement: { _, _, _ in },
            openShop: { _ in },
            coachWelcomeActive: false,
            wiggleID: nil
        )
        // And a third at half depth — the lerp itself is the invariant.
        let midRoom = LoungeRoomView(
            t: 0, size: size, placed: [], justPlaced: nil, zombieTrophy: false,
            standing: "WALK-IN", standingTier: 0, aquariumFish: 0,
            windowEast: "sunset", windowWest: "sunset", rugColorway: 0,
            positions: [:],
            depths: Dictionary(uniqueKeysWithValues: Self.depthEligible.map { ($0, 0.5) }),
            cycleWindow: { _ in }, cycleRug: {}, commitPlacement: { _, _, _ in },
            openShop: { _ in },
            coachWelcomeActive: false,
            wiggleID: nil
        )
        let h = size.height
        let floor = 0.78 * h
        // 0.690, not 0.744: the grand retune dropped the counter to chest
        // height on the 2×-canon patron (keep in step with `bar`'s Canvas).
        let barTop = 0.690 * h
        // One person P: the toasting couple's figure fills 103.5/114 of the
        // high-table composition (high-table-couple.svg).
        let P = room.highTableFrame.height * 103.5 / 114.0
        var passes = 0
        var fails = 0
        func check(_ name: String, _ value: CGFloat, _ lo: CGFloat, _ hi: CGFloat) {
            let ok = value >= lo && value <= hi
            if ok { passes += 1 } else { fails += 1 }
            let v = String(format: "%.2f", value)
            print("[proportion] \(ok ? "PASS" : "FAIL") \(name) = \(v) (want \(lo)-\(hi))")
        }
        // Grand-retune canon: the room is COZY now — ~2.1 P of wall. Below
        // 1.8 P the hanging layer would crush; above 3.2 P the old empty-
        // wall read returns and the 2× furniture goes back to miniature.
        check("wall height (P)", (floor - Self.ceilingLine * h) / P, 1.8, 3.2)
        check("counter above patron feet (P)", (0.805 * h - barTop) / P, 0.55, 0.75)
        let womanHead = room.womanFrame.minY + room.womanFrame.height * 4.0 / 112.0
        check("counter below woman head (P)", (barTop - womanHead) / P, 0.2, 0.6)
        let vicHead = room.vicFrame.minY + room.vicFrame.height * 18.5 / 150.0
        check("vic head above woman head (P)", (womanHead - vicHead) / P, 0.0, 0.5)
        check("vic hidden behind bar (fraction)", (room.vicFrame.maxY - barTop) / room.vicFrame.height, 0.15, 0.45)
        // Picture line: tops sit near the ceiling so the wall doesn't
        // read as a void above the décor.
        let ceilY = Self.ceilingLine * h
        // Windows and roof hangings stayed 1× in the retune (Carson's
        // exclusion), so their P-relative ranges are the old canon halved.
        for (name, f) in [("east window", room.windowFrame), ("bay window", room.bayWindowFrame)] {
            check("\(name) height (P)", f.height / P, 0.5, 1.0)
            check("\(name) sill above floor (P)", (floor - f.maxY) / P, 0.3, 2.0)
            check("\(name) top below ceiling (P)", (f.minY - ceilY) / P, 0.25, 1.0)
        }
        for (name, f) in [("lamp", room.lampFrame), ("float", room.floatFrame),
                          ("sign", room.signFrame), ("marlin", room.marlinFrame)] {
            check("\(name) bottom above floor (P)", (floor - f.maxY) / P, 1.0, 1.9)
            check("\(name) top below ceiling (P)", (f.minY - ceilY) / P, 0.1, 1.0)
        }
        check("fan mounts at ceiling (h)", room.fanFrame.minY / h - Self.ceilingLine, -0.005, 0.005)
        check("aquarium bottom above floor (P)", (floor - room.aquariumFrame.maxY) / P, 0.7, 1.4)
        check("aquarium top below ceiling (P)", (room.aquariumFrame.minY - ceilY) / P, 0.2, 0.8)
        check("aquarium clears couch (pt)", room.couchFrame.minY - room.aquariumFrame.maxY, 10, 10_000)
        let seatTop = room.stoolsFrame.minY + room.stoolsFrame.height * 1.5 / 95.0
        check("stool seat below counter (P)", (seatTop - barTop) / P, 0.15, 0.45)
        let floorPieces: [(String, CGRect)] = [
            ("statue", room.statueFrame), ("palm", room.palmFrame), ("cat", room.catFrame),
            ("credenza", room.credenzaFrame), ("table", room.highTableFrame),
            ("piano", room.pianoFrame), ("couch", room.couchFrame),
            ("snake", room.plantSnakeFrame), ("bush", room.plantBushFrame),
            ("tiered", room.plantTieredFrame), ("woman", room.womanFrame),
            ("man", room.manFrame), ("stools", room.stoolsFrame),
        ]
        for (name, f) in floorPieces {
            check("\(name) on the standing band (h)", f.maxY / h, 0.78, 0.82)
        }
        // Continuous depth: every eligible piece at depth 1 stands on the
        // deep foot line grown to deepScale; at depth 0.5 its foot and
        // width sit halfway between the rail and full-depth values (the
        // lerp is the invariant); skyline pieces ignore depth entirely.
        let downTriples: [(String, CGRect, CGRect, CGRect)] = [
            ("palm", downRoom.palmFrame, midRoom.palmFrame, room.palmFrame),
            ("cat", downRoom.catFrame, midRoom.catFrame, room.catFrame),
            ("stools", downRoom.stoolsFrame, midRoom.stoolsFrame, room.stoolsFrame),
            ("table", downRoom.highTableFrame, midRoom.highTableFrame, room.highTableFrame),
            ("couch", downRoom.couchFrame, midRoom.couchFrame, room.couchFrame),
            ("snake", downRoom.plantSnakeFrame, midRoom.plantSnakeFrame, room.plantSnakeFrame),
            ("bush", downRoom.plantBushFrame, midRoom.plantBushFrame, room.plantBushFrame),
            ("tiered", downRoom.plantTieredFrame, midRoom.plantTieredFrame, room.plantTieredFrame),
            ("piano", downRoom.pianoFrame, midRoom.pianoFrame, room.pianoFrame),
            ("credenza", downRoom.credenzaFrame, midRoom.credenzaFrame, room.credenzaFrame),
            ("statue", downRoom.statueFrame, midRoom.statueFrame, room.statueFrame),
            ("woman", downRoom.womanFrame, midRoom.womanFrame, room.womanFrame),
            ("man", downRoom.manFrame, midRoom.manFrame, room.manFrame),
        ]
        for (name, d, m, u) in downTriples {
            check("\(name) full-depth foot (h)", d.maxY / h, 0.925, 0.935)
            check("\(name) full-depth scale", d.width / u.width, 1.155, 1.165)
            check("\(name) half-depth foot lerps (frac)", (m.maxY - u.maxY) / max(d.maxY - u.maxY, 0.001), 0.48, 0.52)
        }
        // The two fixed-y floor layers really are fixed: the rug is the
        // ground itself, the fronds are screen-edge framing.
        check("rug ignores depth (pt)", abs(downRoom.rugFrame.maxY - room.rugFrame.maxY), 0, 0.001)
        check("fronds ignore depth (pt)", abs(downRoom.frondsFrame.maxY - room.frondsFrame.maxY), 0, 0.001)
        // Lagoon items live inside the water band: fully above the roof
        // beam (t = 0 reference swell).
        for item in Self.lagoonItems {
            check("\(item.id) in the water band (h)", room.waterFrame(item).maxY / h, 0.0, Self.ceilingLine - 0.01)
        }
        // Head canon: every figure's head renders at the couple's head size.
        let coupleHead = room.highTableFrame.width * 18.0 / 150.0
        check("woman head vs canon", room.womanFrame.width * 18.0 / 64.0 / coupleHead, 0.9, 1.1)
        check("man head vs canon", room.manFrame.width * 18.0 / 56.0 / coupleHead, 0.9, 1.1)
        // Default anchors keep clear of each other; the two designed depth
        // tucks (and the cat brushing the credenza) are whitelisted. Round 2
        // moved the bush's tuck from the piano's underside (read as a stuck
        // render) to the couch's left arm, mirroring the tiered pot's right.
        let allowed: Set<String> = ["bush|couch", "couch|tiered", "cat|credenza"]
        var overlaps = 0
        for i in 0..<floorPieces.count {
            for j in (i + 1)..<floorPieces.count {
                let key = [floorPieces[i].0, floorPieces[j].0].sorted().joined(separator: "|")
                if allowed.contains(key) { continue }
                if floorPieces[i].1.insetBy(dx: 1, dy: 1).intersects(floorPieces[j].1.insetBy(dx: 1, dy: 1)) {
                    overlaps += 1
                    print("[proportion] FAIL overlap \(key)")
                }
            }
        }
        if overlaps == 0 {
            passes += 1
            print("[proportion] PASS no unplanned floor overlaps")
        } else {
            fails += overlaps
        }
        print("[proportion] AUDIT \(passes)/\(passes + fails) PASS")
    }
}
#endif

