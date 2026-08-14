import SwiftUI

/// Shared hearts row for the lives pool — picker chip, in-game HUD, defeat
/// panels, and the out-of-lives sheet. One component so the pool never
/// reads as a different system in different places.
///
/// Modes:
/// - **HUD** (count only): quiet chrome during play; last-life breathe when
///   count == 1; quiet pulse on spend; refill pop when a heart fills.
/// - **Chip / panel**: optional live countdown (caller supplies seconds);
///   larger break beat on defeat when `playBreak` is armed once.
struct LivesHearts: View {
    enum Size {
        case chip   // picker / quiet HUD
        case panel  // defeat + out-of-lives
    }

    let count: Int
    var size: Size = .chip
    var filledColor: Color = P.coral.color
    var emptyColor: Color = P.cream.color.opacity(0.35)
    /// When non-nil and the pool is below cap, show "NEXT LIFE IN m:ss"
    /// (or just m:ss under the chip). HUD never passes this.
    var secondsToNext: Int? = nil
    /// Chip stacks the countdown under the hearts so the capsule stays narrow.
    var stackCountdown: Bool = false
    /// Label prefix for the countdown line. Empty → bare m:ss (chip).
    var countdownPrefix: String = "NEXT LIFE IN "
    /// Index of the heart that just drained (equals `count` after a spend).
    /// Combined with `playBreak` for a one-shot break beat.
    var breakIndex: Int? = nil
    /// Parent arms this true once per defeat, then clears after ~0.6s so
    /// panel re-renders / leaderboard toggles never replay the beat.
    var playBreak: Bool = false
    /// HUD: pulse once when count drops (parent can leave default true).
    var pulseOnDecrement: Bool = true
    /// Pop a heart that just filled from a refill (chip + HUD).
    var popOnRefill: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastCount: Int?
    @State private var breakProgress: CGFloat = 0   // 0 idle/full → 1 drained
    @State private var breaking = false
    @State private var lastLifeBreathe = false
    @State private var hudPulse = false
    @State private var refillPopIndex: Int?

    private var heartFont: CGFloat {
        switch size {
        case .chip: return 11
        case .panel: return 22
        }
    }

    private var countdownFont: CGFloat {
        switch size {
        case .chip: return 10
        case .panel: return 14
        }
    }

    var body: some View {
        let hearts = HStack(spacing: size == .panel ? 6 : 2) {
            ForEach(0..<PlayerStore.livesCap, id: \.self) { i in
                heartGlyph(at: i)
            }
        }

        Group {
            if stackCountdown, let secs = secondsToNext, count < PlayerStore.livesCap {
                VStack(spacing: 2) {
                    hearts
                    Text(Self.formatCountdown(secs))
                        .font(.custom("Futura-Bold", size: countdownFont, relativeTo: .body))
                        .tracking(1)
                        .foregroundStyle(P.cream.color.opacity(0.75))
                        .monospacedDigit()
                }
            } else {
                VStack(spacing: size == .panel ? 8 : 0) {
                    hearts
                    if let secs = secondsToNext, count < PlayerStore.livesCap, !stackCountdown {
                        Text("\(countdownPrefix)\(Self.formatCountdown(secs))")
                            .font(.custom("Futura-Bold", size: countdownFont, relativeTo: .body))
                            .tracking(2)
                            .foregroundStyle(P.torch.color)
                            .monospacedDigit()
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .onAppear {
            lastCount = count
            syncLastLifeBreathe()
            startBreakIfNeeded()
        }
        .onChange(of: playBreak) { _, on in
            if on { startBreakIfNeeded() }
        }
        .onChange(of: count) { old, new in
            handleCountChange(from: old, to: new)
            lastCount = new
            syncLastLifeBreathe()
        }
        .onChange(of: reduceMotion) { _, _ in syncLastLifeBreathe() }
    }

    @ViewBuilder
    private func heartGlyph(at i: Int) -> some View {
        let filled = i < count
        let isBreaking = playBreak && breakIndex == i && (breaking || breakProgress > 0)
        let showFilled = filled || (isBreaking && breakProgress < 1)
        let isLastLife = count == 1 && i == 0

        Image(systemName: showFilled ? "heart.fill" : "heart")
            .font(.system(size: heartFont, weight: .bold))
            .foregroundStyle(showFilled ? filledColor : emptyColor)
            .scaleEffect(scale(for: i, isLastLife: isLastLife, isBreaking: isBreaking))
            .opacity(isBreaking ? max(0.25, 1 - breakProgress * 0.75) : 1)
            .offset(y: isBreaking && !reduceMotion ? breakProgress * 6 : 0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: hudPulse)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: refillPopIndex)
    }

    private func scale(for i: Int, isLastLife: Bool, isBreaking: Bool) -> CGFloat {
        if isBreaking, !reduceMotion {
            return 1.0 + 0.25 * (1 - breakProgress) // swell then settle
        }
        if refillPopIndex == i, !reduceMotion { return 1.28 }
        if hudPulse, i == count, !reduceMotion { return 1.12 } // quiet pulse on the new empty edge
        if isLastLife, !reduceMotion { return lastLifeBreathe ? 1.14 : 1.0 }
        if isLastLife, reduceMotion { return 1.1 } // steady emphasized frame
        return 1.0
    }

    private func startBreakIfNeeded() {
        guard playBreak, let idx = breakIndex, idx >= 0, idx < PlayerStore.livesCap else { return }
        if reduceMotion {
            breakProgress = 1
            breaking = false
            return
        }
        guard !breaking, breakProgress < 1 else { return }
        breaking = true
        breakProgress = 0
        withAnimation(.easeIn(duration: 0.45)) { breakProgress = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            breaking = false
        }
    }

    private func handleCountChange(from old: Int?, to new: Int) {
        guard let old else { return }
        if new > old, popOnRefill, !reduceMotion {
            // Pop each newly filled heart (usually one).
            for i in old..<new {
                refillPopIndex = i
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                withAnimation(.spring(duration: 0.28, bounce: 0.35)) { refillPopIndex = nil }
            }
        } else if new < old, pulseOnDecrement, !reduceMotion, !playBreak {
            // Quiet HUD pulse — defeat panels own the break drama via playBreak.
            hudPulse = true
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.easeOut(duration: 0.2)) { hudPulse = false }
            }
        }
    }

    private func syncLastLifeBreathe() {
        guard count == 1, !reduceMotion else {
            lastLifeBreathe = false
            return
        }
        // Slow house-clock breathe — only while the last life is on the rail.
        if !lastLifeBreathe {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                lastLifeBreathe = true
            }
        }
    }

    private var accessibilityLabel: String {
        if let secs = secondsToNext, count < PlayerStore.livesCap {
            return "\(count) of \(PlayerStore.livesCap) lives, next in \(Self.formatCountdown(secs))"
        }
        if count == 1 {
            return "1 of \(PlayerStore.livesCap) lives — last life"
        }
        return "\(count) of \(PlayerStore.livesCap) lives"
    }

    /// m:ss — shared by chip, sheet, and empty-pool defeat panels.
    static func formatCountdown(_ seconds: Int) -> String {
        let s = max(0, seconds)
        let m = s / 60
        let r = s % 60
        return "\(m):\(String(format: "%02d", r))"
    }
}

#Preview("HUD last life") {
    ZStack {
        P.woodDark.color.ignoresSafeArea()
        LivesHearts(count: 1, size: .chip)
    }
}

#Preview("Panel spend") {
    ZStack {
        P.ink.color.ignoresSafeArea()
        LivesHearts(count: 2, size: .panel, secondsToNext: nil,
                    breakIndex: 2, playBreak: true)
    }
}
