import SwiftUI

/// Luau HUD — SAND/SCORE + Lounge Cat on the left, MOVES center, BEST +
/// lives + how-to on the right. Extracted from LuauView so chrome edits
/// don't fight board / coach / sunrise work in the same file.
struct LuauChrome: View {
    let game: LuauGame
    let coachActive: Bool
    let resolving: Bool
    @Binding var catTargeting: Bool
    @Binding var catTarget: (col: Int, row: Int)
    var onHowTo: () -> Void
    var onDismissCatComp: () -> Void

    @Environment(PlayerStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sandChipPop = false
    @State private var movesChipPop = false
    @State private var streakPop = false
    @State private var catChipBreathe = false

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                // In level mode the objective is the story: SAND replaces
                // SCORE as the primary chip so "clear the sand" reads at
                // a glance. Score still accumulates for the wallet handoff.
                VStack(alignment: .leading, spacing: 10) {
                    if game.isLevelMode {
                        // The counter tick IS the objective feedback — bounce the
                        // chip on every pop so eyes find it. Reseeds (count going
                        // up between coach rounds) stay silent.
                        chip("SAND", value: game.jellyRemaining)
                            .scaleEffect(sandChipPop ? 1.18 : 1)
                            .onChange(of: game.jellyRemaining) { old, new in
                                guard new < old else { return }
                                withAnimation(.spring(duration: 0.18, bounce: 0.45)) { sandChipPop = true }
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(200))
                                    withAnimation(.spring(duration: 0.32, bounce: 0.3)) { sandChipPop = false }
                                }
                            }
                    } else {
                        chip("SCORE", value: game.score)
                    }
                    // Permanent inventory slot (Carson: the player should
                    // always see how many they have left) — dim ×0 when
                    // empty, gold and breathing when a cat is in the basket.
                    if !coachActive {
                        catButton
                    }
                    // The one thing that survives the seam between nights, so
                    // it has to be visible or it isn't carrying anything. Held
                    // back until 2 — a "streak" of one night is just a win, and
                    // showing it every time would clutter the row for nothing.
                    if !coachActive, game.nightStreak >= 2 {
                        streakBadge
                    }
                }
                Spacer()
                VStack(spacing: 6) {
                    Text("MOVES")
                        .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.cream.color.opacity(0.75))
                    Text("\(game.movesLeft)")
                        .font(.custom("Futura-Bold", size: 24, relativeTo: .body))
                        .foregroundStyle(game.movesLeft <= 3 ? P.coral.color : P.blossom.color)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(Capsule().fill(P.ink.color.opacity(0.55)))
                .overlay(
                    // Last-moves tension: the chip itself signals, not just a tint.
                    Capsule().stroke(
                        P.coral.color.opacity(game.movesLeft <= 3 && !game.isOver ? 0.9 : 0),
                        lineWidth: 2
                    )
                )
                .scaleEffect(game.movesLeft <= 3 && !game.isOver ? 1.12 : 1)
                .animation(.spring(duration: 0.35, bounce: 0.5), value: game.movesLeft <= 3)
                // Spending a move is the one cost the player pays every turn,
                // and nothing used to mark it — a whiff looked exactly like an
                // illegal drag. Same pop idiom as the SAND chip above.
                .scaleEffect(movesChipPop ? 1.15 : 1)
                .onChange(of: game.movesLeft) { old, new in
                    guard new < old else { return }
                    withAnimation(.spring(duration: 0.18, bounce: 0.45)) { movesChipPop = true }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(180))
                        withAnimation(.spring(duration: 0.3, bounce: 0.3)) { movesChipPop = false }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 10) {
                    chip("BEST", value: max(game.best, game.score))
                    // Hidden until Luau starts charging this player — showing
                    // hearts a defeat will not spend advertises a limit that
                    // is not being applied.
                    // Snapshot + 30s tick — mid-run refills reach the HUD
                    // (the `lives` mirror only moves at mutation points).
                    if store.livesActive(for: .luau) {
                        TimelineView(.periodic(from: .now, by: 30)) { ctx in
                            LivesHearts(count: store.livesSnapshot(now: ctx.date).count, size: .chip)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(P.ink.color.opacity(0.55)))
                    }
                    if !coachActive {
                        HowToPlayButton(action: onHowTo)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 64)
            Spacer()
        }
    }

    /// Nights cleared back-to-back. Torch-lit because the streak is the fire
    /// you're keeping alight; it pops on each increment using the same idiom as
    /// the SAND and MOVES chips, and enters on a spring scale like the cat chip
    /// so a new badge doesn't just blink into existence.
    private var streakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .bold))
            Text("\(game.nightStreak)")
                .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                .tracking(1.5)
        }
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(P.torch.color)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(P.ink.color.opacity(0.7)))
        .overlay(Capsule().stroke(P.torch.color.opacity(0.45), lineWidth: 1.5))
        .scaleEffect(streakPop ? 1.16 : 1)
        .transition(.scale(scale: 0.3).combined(with: .opacity))
        .onChange(of: game.nightStreak) { old, new in
            guard new > old else { return }
            withAnimation(.spring(duration: 0.2, bounce: 0.5)) { streakPop = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                withAnimation(.spring(duration: 0.34, bounce: 0.3)) { streakPop = false }
            }
        }
        .accessibilityLabel("Night streak \(game.nightStreak)")
    }

    private var catButton: some View {
        let stocked = store.luauCats > 0 && !game.isOver
        return Button {
            guard stocked, !resolving else { return }
            onDismissCatComp()
            withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                catTargeting.toggle()
                catTarget = (3, 3)
            }
        } label: {
            // Compact form — cat face + count only. Luau's chrome row runs
            // three columns (SAND/MOVES/BEST), so the full name wraps; the
            // sprite carries the identity, the toast/how-to carry the name.
            HStack(spacing: 6) {
                Image.luauSpecialCat
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .opacity(stocked ? 1 : 0.4)
                Text(catTargeting ? "CANCEL" : "×\(store.luauCats)")
                    .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                    .tracking(1.5)
            }
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(stocked ? P.torch.color : P.cream.color.opacity(0.35))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(P.ink.color.opacity(stocked ? 0.7 : 0.45)))
            .overlay(Capsule().stroke(P.torch.color.opacity(stocked ? (catChipBreathe ? 0.9 : 0.35) : 0), lineWidth: 2))
            .shadow(color: P.torch.color.opacity(catChipBreathe ? 0.8 : 0), radius: catChipBreathe ? 12 : 5)
        }
        .buttonStyle(.plain)
        .disabled(!stocked)
        .scaleEffect(catChipBreathe ? 1.1 : 1.0)
        .transition(.scale(scale: 0.3).combined(with: .opacity))
        .onAppear(perform: syncCatBreathe)
        .onChange(of: store.luauCats) { syncCatBreathe() }
        .onChange(of: game.isOver) { syncCatBreathe() }
        .onDisappear { catChipBreathe = false }
    }

    /// Breathe only while a cat is in the basket and the night is live — an
    /// empty slot pulsing would promise a tap that does nothing. Cipher
    /// breathe idiom: guarded start, easeOut stop, Reduce Motion static.
    private func syncCatBreathe() {
        let shouldBreathe = !reduceMotion && store.luauCats > 0 && !game.isOver
        if shouldBreathe, !catChipBreathe {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                catChipBreathe = true
            }
        } else if !shouldBreathe, catChipBreathe {
            withAnimation(.easeOut(duration: 0.3)) { catChipBreathe = false }
        }
    }

    private func chip(_ label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.cream.color.opacity(0.75))
            Text("\(value)")
                .font(.custom("Futura-Bold", size: 19, relativeTo: .body))
                .foregroundStyle(P.blossom.color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(P.ink.color.opacity(0.55)))
    }
}
