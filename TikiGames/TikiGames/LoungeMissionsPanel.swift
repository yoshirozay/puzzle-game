import SwiftUI

/// THE NIGHTLY NINE board card — challenge ticks, tonight's prize, CLAIM
/// REWARD, dismiss. Extracted from LoungeView so missions work stays off
/// room / shop / chrome.
///
/// Built as bar furniture, not a system dialog: a woodDark tab board with
/// hardware at the corners, a slate field, and chalk ticks drawn as `Path`s.
/// Colour has one job each — chalk marks progress, cream carries text, and
/// gold is spent on exactly one object, the claim.
struct LoungeMissionsPanel: View {
    let size: CGSize
    let nightlyReady: Bool
    var onClaimAndPour: () -> Void
    var onDismiss: () -> Void

    @Environment(PlayerStore.self) private var store

    private let gold = Color(red: 0.910, green: 0.702, blue: 0.235)
    private var slate: Color { P.ink.lerp(P.plank, 0.18).color }

    var body: some View {
        ZStack {
            P.ink.color.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            board
                .frame(width: min(size.width * 0.9, 370))
                .position(x: size.width / 2, y: size.height * 0.48)
        }
    }

    private var board: some View {
        VStack(spacing: 0) {
            header
            list
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(slate))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(P.ink.color.opacity(0.8), lineWidth: 1.5)
                )
                .padding(.top, 12)
            prizePlaque
                .padding(.top, 12)
            actions
                .padding(.top, 12)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(P.woodDark.color)
                .overlay(
                    // Bevel: the same lit-top / shadowed-bottom edge the
                    // hanging signs on the picker rail wear.
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            LinearGradient(
                                colors: [P.driftwood.color.opacity(0.75), P.ink.color.opacity(0.5)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                )
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.ink.color, lineWidth: 2.5))
        .overlay(alignment: .top) { hardware }
    }

    /// Two brass screws at the top corners — the board is mounted, not floating.
    private var hardware: some View {
        HStack {
            screw
            Spacer()
            screw
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
    }

    private var screw: some View {
        Circle()
            .fill(P.driftwood.color)
            .overlay(Circle().stroke(P.ink.color.opacity(0.7), lineWidth: 1))
            .overlay(
                Rectangle()
                    .fill(P.ink.color.opacity(0.55))
                    .frame(width: 5, height: 1.4)
            )
            .frame(width: 8, height: 8)
    }

    // MARK: header + meter

    private var header: some View {
        VStack(spacing: 6) {
            Text("THE NIGHTLY NINE")
                .font(.custom("Futura-Bold", size: 17, relativeTo: .body))
                .tracking(2.5)
                .foregroundStyle(P.cream.color)
            // No per-row prize: any four of the nine pay the same single
            // pour. Say so at the top of the list, and again on the plaque —
            // the meter used to live up here, nine rows away from the thing
            // it unlocks.
            Text("NINE GOALS · ANY FOUR PAY THE SAME POUR")
                .font(.custom("Futura-Medium", size: 10, relativeTo: .body))
                .tracking(1.1)
                .foregroundStyle(P.cream.color.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The Nightly Nine. Nine goals; any four pay the same single pour.")
    }

    // MARK: the nine

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(PlayerStore.nightlyChallenges) { c in
                let p = store.nightlyProgress[c.id] ?? 0
                let done = p >= c.target
                HStack(spacing: 9) {
                    chit(done: done)
                    marker(for: c)
                    Text(c.title)
                        .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                        .tracking(0.8)
                        .foregroundStyle(P.cream.color.opacity(done ? 1 : 0.80))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 6)
                    Text(done ? "DONE" : "\(min(p, c.target))/\(c.target)")
                        .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                        .tracking(1)
                        // 0.50 measured 4.39:1 on this field — under AA for
                        // 10 pt. 0.68 clears it with room to spare.
                        .foregroundStyle(P.cream.color.opacity(done ? 0.92 : 0.68))
                }
                .padding(.vertical, 5)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(game(for: c).map { "\(c.title). \($0.displayName)." } ?? c.title)
                .accessibilityValue(done ? "Done" : "\(min(p, c.target)) of \(c.target)")
            }
        }
    }

    /// Where a row sends you. The board is a routing list before it is a
    /// scoreboard, so each game row wears that game's own picker icon and the
    /// three house-wide rows wear a torch — "anywhere in the lounge".
    private func game(for c: PlayerStore.NightlyChallenge) -> TikiGame? {
        switch c.kind {
        case .runScore(let g, _), .gameRuns(let g, _): return g
        case .luauWin: return .luau
        case .anyRuns, .distinctGames, .pointsEarned: return nil
        }
    }

    @ViewBuilder
    private func marker(for c: PlayerStore.NightlyChallenge) -> some View {
        if let g = game(for: c) {
            g.icon
                .resizable()
                .scaledToFit()
                .frame(width: 19, height: 19)
        } else {
            // The lounge's own torch, lit the way the picker crest lights it.
            // A flat one-colour fill read as a gold leaf and competed with the
            // six real icons instead of saying "anywhere in the house".
            FlameGlyph()
                .fill(LinearGradient(
                    colors: [P.blossom.color, P.torch.color, P.coral.color, P.rum.color],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 12, height: 16)
                .frame(width: 19, height: 19)
        }
    }

    /// Chalk tick in a slate chit. Unchecked sits at 0.48, not 0.30 — the old
    /// empty circle measured 2.40:1, under the 3:1 floor for a UI mark.
    private func chit(done: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(P.cream.color.opacity(done ? 0 : 0.48), lineWidth: 1.5)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(done ? P.blossom.color.opacity(0.16) : .clear)
            )
            .overlay {
                if done {
                    BoardTick()
                        .stroke(P.blossom.color,
                                style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                        .padding(1)
                }
            }
            .frame(width: 17, height: 17)
    }

    // MARK: tonight's prize

    /// What the board is actually for — one prize for any four rows, never a
    /// prize per row. It carries the meter itself so the rule is legible in a
    /// single object, and it is cut from driftwood rather than the list's
    /// slate: sharing the field's material made it read as a tenth row, i.e.
    /// as the reward for EARN 60 POINTS.
    private var prizePlaque: some View {
        let reward = store.previewNightlyReward()
        let done = min(store.nightlyCompleted, PlayerStore.nightlyGoal)
        return HStack(spacing: 12) {
            NightlyRewardGlyph(reward: reward)
                .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    // Outlined track, filled progress. A bare unlit pip
                    // measured 1.11:1 against the mat — the empty slots have
                    // to be drawn, or the meter only exists once it's full.
                    HStack(spacing: 4) {
                        ForEach(0..<PlayerStore.nightlyGoal, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(i < done ? P.blossom.color : P.ink.color.opacity(0.45))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2.5)
                                        .stroke(P.cream.color.opacity(i < done ? 0 : 0.55),
                                                lineWidth: 1)
                                )
                                .frame(width: 13, height: 6)
                        }
                    }
                    Text(nightlyReady ? "POURED AND WAITING" : "ANY \(PlayerStore.nightlyGoal) ABOVE")
                        .font(.custom("Futura-Medium", size: 9, relativeTo: .body))
                        .tracking(1.3)
                        // 0.75 measured 3.60:1 on driftwood — under AA for 9 pt.
                        .foregroundStyle(P.cream.color.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Text(reward.pourName)
                    .font(.custom("Futura-Bold", size: 14, relativeTo: .body))
                    .tracking(1.4)
                    .foregroundStyle(P.cream.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        // Driftwood, and RAISED — lit top edge, shadowed bottom. The list
        // field is recessed (darker than the board, inset stroke). Recessed
        // vs raised is the separation that survives; shadowBrown alone
        // measured 1.10:1 against the field, i.e. the same material.
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(P.driftwood.color)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [P.cream.color.opacity(0.35), P.ink.color.opacity(0.45)],
                                startPoint: .top, endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: P.ink.color.opacity(0.5), radius: 3, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(gold.opacity(nightlyReady ? 0.8 : 0), lineWidth: 2)
        )
        .opacity(nightlyReady ? 1 : 0.78)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(nightlyReady
            ? "Poured and waiting: \(reward.pourAnnouncement)"
            : "One pour for any \(PlayerStore.nightlyGoal) goals above, \(done) done so far: \(reward.pourAnnouncement)")
    }

    // MARK: actions

    private var actions: some View {
        VStack(spacing: 8) {
            if nightlyReady {
                // The earned moment is the player's to take — and the only
                // filled gold object on the board, so it cannot be confused
                // with a status label.
                Button(action: onClaimAndPour) {
                    Text("CLAIM REWARD")
                        .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                        .tracking(2)
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(gold))
                }
                .buttonStyle(SoftPressStyle())
            } else {
                Text(store.nightlyRewardClaimed
                     ? "POURED — SEE YOU TOMORROW"
                     : "\(PlayerStore.nightlyGoal - store.nightlyCompleted) MORE TO GO")
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.cream.color.opacity(0.75))
                    .padding(.vertical, 10)
            }
            // Quiet dismiss: CLAIM REWARD owns the filled capsule when it's
            // up, and the scrim already closes the card anyway.
            Button(action: onDismiss) {
                Text("BACK TO THE ROOM")
                    .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.cream.color.opacity(0.85))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().stroke(P.cream.color.opacity(0.35), lineWidth: 1.5))
            }
            .buttonStyle(SoftPressStyle())
        }
    }
}
