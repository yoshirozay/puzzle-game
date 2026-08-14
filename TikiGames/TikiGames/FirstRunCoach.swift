import SwiftUI

/// First-run coach chrome — per-game skinned so each game's overlay reads as
/// native to that game's world. Same skeleton, five wardrobes.
/// - `CoachSkin` — the aesthetic contract (colors, radii, glyph, dismiss cue)
/// - `CoachCard` — bottom or top instruction card + SKIP chip
/// - `CoachPulse` — pulsing ring at target cells (1.67 Hz, phase-locked with arrow)
/// - `CoachArrow` — 5 hand-drawn SwiftUI glyphs (torch, wood, swizzle, matchbook, chalk)
///
/// Motion honors Reduce Motion. Dismissal on the required action; no "OK" button.

// MARK: — Skin

enum CoachArrowGlyph { case torch, wood, swizzle, matchbook, chalk, bamboo }

enum CoachDismissSound {
    case tick, pop
    case clear(Int)
    case win, fanfare

    @MainActor
    func play() {
        switch self {
        case .tick: TikiSound.shared.tick()
        case .pop: TikiSound.shared.pop()
        case .clear(let i): TikiSound.shared.clear(intensity: i)
        case .win: TikiSound.shared.win()
        case .fanfare: TikiSound.shared.fanfare()
        }
    }
}

enum CoachCardPosition { case top(CGFloat), bottom(CGFloat) }

struct CoachSkin {
    let cardFill: Color
    let cardStroke: Color
    let cardStrokeWidth: CGFloat
    let cardCornerRadius: CGFloat
    let cardTextColor: Color
    let cardFont: Font
    let cardTracking: CGFloat
    let pulseColor: Color
    let pulseLineWidth: CGFloat
    let arrowColor: Color
    let arrowGlyph: CoachArrowGlyph
    let skipFill: Color
    let skipTextColor: Color
    let dismissSound: CoachDismissSound
    let cardPosition: CoachCardPosition
}

extension CoachSkin {
    static let luau = CoachSkin(
        cardFill: P.plank.color,
        cardStroke: P.ember.color,
        cardStrokeWidth: 1.5,
        cardCornerRadius: 20,
        cardTextColor: P.blossom.color,
        cardFont: .custom("Futura-Bold", size: 15, relativeTo: .body),
        cardTracking: 2.5,
        pulseColor: P.coral.color,
        pulseLineWidth: 3.0,
        arrowColor: P.coral.color,
        arrowGlyph: .torch,
        skipFill: P.ink.color.opacity(0.55),
        skipTextColor: P.cream.color.opacity(0.75),
        dismissSound: .clear(1),
        cardPosition: .bottom(88)
    )

    static let stacks = CoachSkin(
        cardFill: P.cream.color,
        cardStroke: P.shadowBrown.color.opacity(0.7),
        cardStrokeWidth: 0.75,
        cardCornerRadius: 8,
        cardTextColor: P.woodDark.color,
        cardFont: .custom("Futura-Bold", size: 15, relativeTo: .body),
        cardTracking: 2.5,
        pulseColor: P.torch.color,
        pulseLineWidth: 2.5,
        arrowColor: P.woodDark.color,
        arrowGlyph: .wood,
        skipFill: P.blossom.color,
        skipTextColor: P.woodDark.color.opacity(0.75),
        dismissSound: .pop,
        cardPosition: .top(122)
    )

    static let zombie = CoachSkin(
        cardFill: P.woodDark.color,
        cardStroke: P.ink.color,
        cardStrokeWidth: 2.0,
        cardCornerRadius: 22,
        cardTextColor: P.blossom.color,
        cardFont: .custom("Futura-Bold", size: 15, relativeTo: .body),
        cardTracking: 2.5,
        pulseColor: P.torch.color,
        pulseLineWidth: 2.5,
        arrowColor: P.torch.color,
        arrowGlyph: .swizzle,
        skipFill: P.ink.color.opacity(0.6),
        skipTextColor: P.cream.color.opacity(0.75),
        dismissSound: .tick,
        // Top-positioned so the coach card doesn't crowd the drink-lore card
        // (fires at bottom for tiers 3+, which the scripted rounds now reach).
        cardPosition: .top(120)
    )

    static let cipher = CoachSkin(
        cardFill: P.cream.color,
        cardStroke: P.ink.color,
        cardStrokeWidth: 1.5,
        cardCornerRadius: 6,
        cardTextColor: P.ink.color,
        cardFont: .custom("Futura-Bold", size: 15, relativeTo: .body),
        cardTracking: 2.5,
        // Coral (deeper red-orange) beats torch on the keyboard's cream
        // tiles — the previous torch-on-cream pulse blended into the keys.
        // Thicker ring (3.5) also makes the affordance harder to miss.
        pulseColor: P.coral.color,
        pulseLineWidth: 3.5,
        arrowColor: P.coral.color,
        arrowGlyph: .matchbook,
        skipFill: P.ink.color.opacity(0.08),
        skipTextColor: P.ink.color.opacity(0.7),
        dismissSound: .tick,
        cardPosition: .top(120)
    )

    /// The Lounge's wardrobe: bar-coaster cream card, coral hairline stroke,
    /// torch pulse, a bamboo pointer that echoes the bar front's cane grammar.
    /// Nothing here is borrowed from a game skin — coaster + bamboo are the
    /// lounge's own vocabulary.
    static let lounge = CoachSkin(
        cardFill: P.cream.color,
        cardStroke: P.coral.color,
        cardStrokeWidth: 1.5,
        cardCornerRadius: 14,
        cardTextColor: P.woodDark.color,
        cardFont: .custom("Futura-Bold", size: 15, relativeTo: .body),
        cardTracking: 2.5,
        pulseColor: P.torch.color,
        pulseLineWidth: 2.5,
        arrowColor: P.woodDark.color,
        arrowGlyph: .bamboo,
        // SKIP sits over the deep lagoon plane — woodDark-on-teal was
        // invisible (round 2). Ink capsule + cream text, like the wallet chip.
        skipFill: P.ink.color.opacity(0.45),
        skipTextColor: P.cream.color.opacity(0.85),
        dismissSound: .pop,
        cardPosition: .bottom(60)
    )

    /// Navigator's wardrobe: night-sky ink card, driftwood-frame stroke,
    /// torch-lit chalk pointer. Card bottom so it doesn't crowd the sky
    /// board (WATCH THE SKY beat + status row live below).
    static let navigator = CoachSkin(
        cardFill: P.ink.color.opacity(0.92),
        cardStroke: P.driftwood.color,
        cardStrokeWidth: 2.0,
        cardCornerRadius: 20,
        cardTextColor: P.blossom.color,
        cardFont: .custom("Futura-Bold", size: 15, relativeTo: .body),
        cardTracking: 2.5,
        pulseColor: P.torch.color,
        pulseLineWidth: 3.0,
        arrowColor: P.torch.color,
        arrowGlyph: .chalk,
        skipFill: P.ink.color.opacity(0.55),
        skipTextColor: P.cream.color.opacity(0.75),
        dismissSound: .win,
        cardPosition: .bottom(120)
    )

    static let blueprints = CoachSkin(
        cardFill: P.deepLeaf.color.opacity(0.92),
        cardStroke: P.blossom.color.opacity(0.7),
        cardStrokeWidth: 1.0,
        cardCornerRadius: 4,
        cardTextColor: P.blossom.color,
        cardFont: .custom("Futura-Bold", size: 14, relativeTo: .body),
        cardTracking: 3.5,
        pulseColor: P.blossom.color,
        pulseLineWidth: 1.5,
        arrowColor: P.blossom.color.opacity(0.9),
        arrowGlyph: .chalk,
        skipFill: P.blossom.color.opacity(0.15),
        skipTextColor: P.cream.color.opacity(0.85),
        dismissSound: .tick,
        cardPosition: .top(122)
    )
}

// MARK: — Card

/// The bottom or top instruction card + top-left SKIP chip. Renders full-screen
/// so games can lay it on top without threading a size in.
struct CoachCard: View {
    let message: String
    let skin: CoachSkin
    let onSkip: () -> Void
    /// Optional tap on the card body itself — for beats whose instruction
    /// names a tappable thing (the lounge's SHOP beat opens the shop
    /// directly). nil keeps the card hit-transparent as before.
    var onTap: (() -> Void)? = nil
    /// Top inset for the SKIP chip. The default clears most games' chrome;
    /// a game whose top-left corner is occupied during the coach (Luau's
    /// SAND objective chip) passes a deeper inset so SKIP never occludes it.
    var skipTopPadding: CGFloat = 56

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(false)
                skipChip
                    .padding(.top, skipTopPadding)
                    .padding(.leading, 20)
                cardPositioned(in: geo.size)
                    .allowsHitTesting(onTap != nil)
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.94)),
            removal: .opacity.combined(with: .scale(scale: 0.9))
        ))
    }

    private func cardPositioned(in size: CGSize) -> some View {
        Group {
            switch skin.cardPosition {
            case .top(let pad):
                VStack {
                    cardBody
                        .padding(.top, pad)
                    Spacer(minLength: 0)
                }
            case .bottom(let pad):
                VStack {
                    Spacer(minLength: 0)
                    cardBody
                        .padding(.bottom, pad)
                }
            }
        }
        .padding(.horizontal, 32)
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    private var cardBody: some View {
        Text(message)
            .font(skin.cardFont)
            .tracking(skin.cardTracking)
            .foregroundStyle(skin.cardTextColor)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: skin.cardCornerRadius)
                    .fill(skin.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: skin.cardCornerRadius)
                    .stroke(skin.cardStroke, lineWidth: skin.cardStrokeWidth)
            )
            .shadow(color: P.ink.color.opacity(0.28), radius: 10, x: 0, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: skin.cardCornerRadius))
            .onTapGesture { onTap?() }
            .accessibilityAddTraits(onTap != nil ? .isButton : [])
    }

    private var skipChip: some View {
        Button(action: onSkip) {
            Text("SKIP")
                .font(.custom("Futura-Bold", size: 11, relativeTo: .caption))
                .tracking(3)
                .foregroundStyle(skin.skipTextColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule().fill(skin.skipFill)
                )
                .overlay(
                    Capsule().stroke(skin.skipTextColor.opacity(0.35), lineWidth: 0.75)
                )
                .contentShape(Rectangle().inset(by: -12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Skip tutorial")
    }
}

// MARK: — Swipe cue

/// An animated drag indicator for the "swipe anywhere" beat. Renders as a
/// swizzle stick pulled across a bar — a hand-composed SwiftUI glyph (no SF
/// Symbols) that mirrors SwizzleArrow's driftwood/torch/rum primitives, so it
/// reads native to Zombie's mid-century bar wardrobe rather than an iOS
/// system hint. A cross-shaped dashed rail plus an alternating drift axis
/// (H then V then H …) sells "drag any direction" — the atom of round 3.
struct TutorialSwipeCue: View {
    let skin: CoachSkin
    let boardWidth: CGFloat
    @State private var driftFraction: CGFloat = -0.24
    @State private var pulse = false
    /// true → drift runs left↔right along the horizontal rail. Toggles on
    /// every full drift cycle so the icon traces both cardinals over time.
    @State private var horizontalPhase = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let travel = boardWidth * 0.44
        let iconWidth: CGFloat = 78
        let iconHeight: CGFloat = 26
        return ZStack {
            // Cross-shaped guide rail: horizontal + vertical dashed capsules
            // so both axes read as "draggable path" even at rest / under
            // Reduce Motion, where the drift itself is pinned.
            Capsule()
                .stroke(
                    skin.pulseColor.opacity(0.42),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 8])
                )
                .frame(width: travel * 2 + 12, height: 6)
            Capsule()
                .stroke(
                    skin.pulseColor.opacity(0.42),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 8])
                )
                .frame(width: travel * 2 + 12, height: 6)
                .rotationEffect(.degrees(90))

            // Pulse ring behind the swizzle. Same 1.67 Hz cadence CoachPulse
            // uses on target cells, so the visual grammar stays consistent.
            Circle()
                .stroke(skin.pulseColor.opacity(pulse ? 0.15 : 0.85), lineWidth: skin.pulseLineWidth)
                .frame(width: iconWidth + 18, height: iconWidth + 18)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .offset(
                    x: horizontalPhase ? driftFraction * travel * 2 : 0,
                    y: horizontalPhase ? 0 : driftFraction * travel * 2
                )

            SwizzleDrag(shaftColor: skin.pulseColor, handleColor: P.driftwood.color, garnishColor: P.rum.color)
                .frame(width: iconWidth, height: iconHeight)
                .rotationEffect(.degrees(horizontalPhase ? 0 : 90))
                .offset(
                    x: horizontalPhase ? driftFraction * travel * 2 : 0,
                    y: horizontalPhase ? 0 : driftFraction * travel * 2
                )
        }
        // Root-level defenses: the cue is decorative overlay chrome — VoiceOver
        // should not announce it (CoachCard already reads the atom aloud) and
        // touches must fall through to the board's DragGesture.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear(perform: run)
    }

    private func run() {
        if reduceMotion {
            driftFraction = 0
            return
        }
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            pulse = true
        }
        withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
            driftFraction = 0.24
        }
        // Alternate the active axis every full drift round-trip (2.8 s) so
        // one lens sweep teaches horizontal, the next teaches vertical.
        Task { @MainActor in
            while true {
                try? await Task.sleep(for: .milliseconds(2800))
                withAnimation(.easeInOut(duration: 0.3)) { horizontalPhase.toggle() }
            }
        }
    }
}

/// A swizzle stick shape composed of the same primitives as SwizzleArrow —
/// driftwood-brown grip Circle, torch-orange Capsule shaft, rum-red garnish
/// Circle at the leading end — plus three motion streaks trailing behind so
/// it reads as "being pulled across the bar," not "resting on the bar." No
/// SF Symbols; renders inside the bar wardrobe, not the iOS onboarding
/// vocabulary.
private struct SwizzleDrag: View {
    let shaftColor: Color
    let handleColor: Color
    let garnishColor: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // Motion streaks trailing the grip.
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(shaftColor.opacity(0.55 - Double(i) * 0.15))
                        .frame(width: 12 - CGFloat(i) * 2, height: 3)
                        .offset(x: -w * 0.34 - CGFloat(i) * 10, y: 0)
                }
                // Driftwood grip end.
                Circle()
                    .fill(handleColor)
                    .frame(width: h * 0.9, height: h * 0.9)
                    .position(x: w * 0.24, y: h / 2)
                // Torch shaft.
                Capsule()
                    .fill(shaftColor)
                    .frame(width: w * 0.44, height: h * 0.60)
                    .position(x: w * 0.55, y: h / 2)
                // Rum-red garnish (with an ink hairline) at the leading tip.
                Circle()
                    .fill(garnishColor)
                    .overlay(Circle().stroke(shaftColor, lineWidth: 1.2))
                    .frame(width: h * 1.05, height: h * 1.05)
                    .position(x: w * 0.86, y: h / 2)
            }
            .shadow(color: P.ink.color.opacity(0.4), radius: 2, y: 1)
        }
    }
}

// MARK: — Ready banner

/// Post-tutorial reveal: appears when the coach dismisses on success, holds
/// briefly, then fades. The game view drives the boolean and provides the
/// per-game copy — "READY TO STACK", "READY TO CRACK", etc. — plus the skin
/// so the banner reads native to each world. Tap-anywhere accelerates the
/// exit; skipping never triggers this banner (the game hides silently).
///
/// The banner is deliberately unmissable: 34-pt tracked headline + a
/// pulseColor rule below it, both scaled in on a small spring, so the
/// end-of-tutorial moment is legible even if the player is mid-scroll or
/// looking away from the board.
struct TutorialReadyBanner: View {
    let message: String
    let skin: CoachSkin
    let onFinish: () -> Void

    @State private var shown = false
    @State private var faded = false
    @State private var finished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Rectangle()
                .fill(P.ink.color.opacity(0.55))
                .ignoresSafeArea()
                .opacity(shown && !faded ? 1 : 0)
                .allowsHitTesting(false)

            VStack(spacing: 14) {
                Text(message)
                    .font(.custom("Futura-Bold", size: 34, relativeTo: .title))
                    .tracking(4)
                    .foregroundStyle(skin.pulseColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .shadow(color: skin.pulseColor.opacity(0.45), radius: 14)
                    .accessibilityAddTraits(.isHeader)
                Capsule()
                    .fill(skin.pulseColor)
                    .frame(width: 66, height: 3)
                    .opacity(0.85)
            }
            .scaleEffect(shown ? 1 : 0.72)
            .opacity(shown && !faded ? 1 : 0)
        }
        .contentShape(Rectangle())
        .onAppear(perform: run)
        .onTapGesture { accelerate() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private func run() {
        TikiSound.shared.win()
        if reduceMotion {
            shown = true
        } else {
            withAnimation(.spring(duration: 0.5, bounce: 0.45)) { shown = true }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1400))
            guard !finished else { return }
            withAnimation(.easeOut(duration: 0.4)) { faded = true }
            try? await Task.sleep(for: .milliseconds(400))
            complete()
        }
    }

    private func accelerate() {
        guard !finished, shown else { return }
        withAnimation(.easeOut(duration: 0.25)) { faded = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            complete()
        }
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

// MARK: — Pulse

/// Per-skin pulsing ring the game places over its target cells.
/// Rate is 1.67 Hz round-trip (0.3 s half-cycle × autoreverse) per the rubric's
/// 1.5–2 Hz window. After 6 s of idle (player hasn't acted), the pulse
/// escalates by widening its opacity range and scale delta — never by shouting
/// with the card, per Vollmer's "scaffolding, not banners" rule.
/// Reduce Motion → static ring, no escalation.
struct CoachPulse: View {
    let skin: CoachSkin
    var diameter: CGFloat = 44
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    @State private var escalated = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(skin.pulseColor.opacity(animate ? (escalated ? 0.05 : 0.15) : 1.0), lineWidth: skin.pulseLineWidth)
                .frame(width: diameter, height: diameter)
                .scaleEffect(animate ? (escalated ? 1.5 : 1.35) : 1.0)
            Circle()
                .stroke(skin.pulseColor.opacity(0.85), lineWidth: skin.pulseLineWidth * 0.7)
                .frame(width: diameter, height: diameter)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                animate = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(6))
                withAnimation(.easeInOut(duration: 0.4)) { escalated = true }
            }
        }
    }
}

// MARK: — Arrow

/// Points at the target with a per-skin glyph. `direction` rotates the glyph.
/// Bob is phase-locked with the pulse (0.6 s round-trip, 1.67 Hz). After 6 s
/// of idle, the bob amplitude bumps from 6 → 10 pt — escalation lives on the
/// affordance, not the card. Reduce Motion → static.
struct CoachArrow: View {
    enum Direction { case up, down, left, right }
    let skin: CoachSkin
    var direction: Direction = .down
    var size: CGFloat = 28
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false
    @State private var escalated = false

    var body: some View {
        glyph
            .frame(width: size * 0.7, height: size)
            .rotationEffect(rotation)
            .offset(offset)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
                    bob = true
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(6))
                    withAnimation(.easeInOut(duration: 0.4)) { escalated = true }
                }
            }
    }

    @ViewBuilder private var glyph: some View {
        switch skin.arrowGlyph {
        case .torch: TorchArrow(color: skin.arrowColor, tip: skin.pulseColor)
        case .wood: WoodChevron(color: skin.arrowColor)
        case .swizzle: SwizzleArrow(color: skin.arrowColor)
        case .matchbook: MatchbookArrow(color: skin.arrowColor, tip: skin.pulseColor)
        case .chalk: ChalkLeader(color: skin.arrowColor)
        case .bamboo: BambooArrow(color: skin.arrowColor, tip: skin.pulseColor)
        }
    }

    private var rotation: Angle {
        switch direction {
        case .down: return .degrees(0)
        case .up: return .degrees(180)
        case .left: return .degrees(90)
        case .right: return .degrees(-90)
        }
    }

    private var offset: CGSize {
        guard bob else { return .zero }
        let d: CGFloat = escalated ? 10 : 6
        switch direction {
        case .up: return CGSize(width: 0, height: -d)
        case .down: return CGSize(width: 0, height: d)
        case .left: return CGSize(width: -d, height: 0)
        case .right: return CGSize(width: d, height: 0)
        }
    }
}

/// A bidirectional swap indicator: two coach arrows pointing at each other.
struct CoachSwapArrows: View {
    let skin: CoachSkin
    var size: CGFloat = 26

    var body: some View {
        HStack(spacing: 4) {
            CoachArrow(skin: skin, direction: .down, size: size)
            CoachArrow(skin: skin, direction: .up, size: size)
        }
        .allowsHitTesting(false)
    }
}

// MARK: — Per-skin arrow glyphs (SwiftUI-native, no external assets)

private struct TorchArrow: View {
    let color: Color
    let tip: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(P.driftwood.color)
                    .frame(width: w * 0.28, height: h * 0.68)
                    .position(x: w / 2, y: h * 0.36)
                Rectangle()
                    .fill(P.shadowBrown.color.opacity(0.8))
                    .frame(width: w * 0.28, height: 1)
                    .position(x: w / 2, y: h * 0.28)
                Rectangle()
                    .fill(P.shadowBrown.color.opacity(0.8))
                    .frame(width: w * 0.28, height: 1)
                    .position(x: w / 2, y: h * 0.50)
                Path { p in
                    p.move(to: CGPoint(x: w * 0.15, y: h * 0.70))
                    p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.70))
                    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.98))
                    p.closeSubpath()
                }
                .fill(color)
                .shadow(color: tip.opacity(0.5), radius: 4, y: 1)
            }
        }
    }
}

private struct WoodChevron: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                p.move(to: CGPoint(x: w * 0.1, y: h * 0.45))
                p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.85))
                p.addLine(to: CGPoint(x: w * 0.9, y: h * 0.45))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
            .shadow(color: P.ink.color.opacity(0.22), radius: 1, y: 1)
        }
    }
}

private struct SwizzleArrow: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Circle()
                    .fill(P.driftwood.color)
                    .frame(width: w * 0.30, height: w * 0.30)
                    .position(x: w / 2, y: h * 0.10)
                Capsule()
                    .fill(color)
                    .frame(width: w * 0.18, height: h * 0.60)
                    .position(x: w / 2, y: h * 0.44)
                Circle()
                    .fill(P.rum.color)
                    .overlay(Circle().stroke(color, lineWidth: 1.2))
                    .frame(width: w * 0.44, height: w * 0.44)
                    .position(x: w / 2, y: h * 0.86)
            }
            .shadow(color: P.ink.color.opacity(0.4), radius: 2, y: 1)
        }
    }
}

private struct MatchbookArrow: View {
    let color: Color
    let tip: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Capsule()
                    .fill(P.cream.color)
                    .overlay(
                        Capsule().stroke(P.ink.color.opacity(0.35), lineWidth: 0.5)
                    )
                    .frame(width: w * 0.22, height: h * 0.66)
                    .position(x: w / 2, y: h * 0.4)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [P.blossom.color, tip, color],
                            center: .init(x: 0.4, y: 0.4),
                            startRadius: 0,
                            endRadius: w * 0.28
                        )
                    )
                    .frame(width: w * 0.55, height: w * 0.55)
                    .position(x: w / 2, y: h * 0.86)
                    .shadow(color: color.opacity(0.6), radius: 5, y: 1)
            }
        }
    }
}

/// A short bamboo cane pointer: driftwood shaft with two cream rope wraps and
/// a torch-tipped tapered leaf. Diegetic to the lounge bar (whose front is
/// bamboo lashed with the same cream cord), and specifically NOT reused from
/// any game skin — this glyph belongs to the lounge.
private struct BambooArrow: View {
    let color: Color
    let tip: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: w * 0.34, height: h * 0.60)
                    .position(x: w / 2, y: h * 0.35)
                ForEach([0.18, 0.52], id: \.self) { fraction in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(P.cream.color.opacity(0.9))
                        .frame(width: w * 0.44, height: 2.5)
                        .position(x: w / 2, y: h * fraction * 0.9)
                }
                Path { p in
                    p.move(to: CGPoint(x: w * 0.14, y: h * 0.66))
                    p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.66))
                    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.98))
                    p.closeSubpath()
                }
                .fill(tip)
                .shadow(color: tip.opacity(0.5), radius: 4, y: 1)
            }
        }
    }
}

private struct ChalkLeader: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                if reduceMotion {
                    dashedLine(w: w, h: h, phase: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                        let phase = -Double(timeline.date.timeIntervalSince1970 * 12).truncatingRemainder(dividingBy: 7)
                        dashedLine(w: w, h: h, phase: CGFloat(phase))
                    }
                }
                Path { p in
                    p.move(to: CGPoint(x: w * 0.25, y: h * 0.70))
                    p.addLine(to: CGPoint(x: w * 0.5, y: h * 0.95))
                    p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.70))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
                Circle()
                    .fill(color)
                    .frame(width: 3.5, height: 3.5)
                    .position(x: w / 2, y: 4)
            }
        }
    }

    private func dashedLine(w: CGFloat, h: CGFloat, phase: CGFloat) -> some View {
        Path { p in
            p.move(to: CGPoint(x: w / 2, y: 4))
            p.addLine(to: CGPoint(x: w / 2, y: h * 0.86))
        }
        .stroke(
            color,
            style: StrokeStyle(lineWidth: 1.0, lineCap: .butt, dash: [3.5, 3.0], dashPhase: phase)
        )
    }
}
