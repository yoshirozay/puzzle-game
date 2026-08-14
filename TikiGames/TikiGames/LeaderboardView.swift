import SwiftUI

/// One leaderboard screen, six wardrobes. Every game's board shares this
/// skeleton — header, podium, plank slats, pinned YOU bar, themed
/// loading / signed-out / offline / empty states — and a LeaderboardTheme
/// supplies the game's world: backdrop scene, podium art, copy, tint.
/// Full-screen overlay in the HowToPlayPanel idiom (ink dim, wood chrome,
/// Futura caps).
struct LeaderboardView: View {
    let theme: LeaderboardTheme
    let onDismiss: () -> Void
    @State private var phase: LoadPhase = .loading
    /// A tapped row / podium head opens that player's card.
    @State private var cardEntry: GameCenter.Entry?
    /// Key-window safe insets, captured once at init — querying UIKit from
    /// inside `body` can wedge the attribute graph. Portrait-only app, so
    /// the values never change while the board is up.
    @State private var insets: UIEdgeInsets = LeaderboardView.windowInsets
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum LoadPhase {
        case loading
        case signedOut
        case failed
        case loaded(GameCenter.Standings)
    }

    var body: some View {
        boardBody
            .onAppear { Analytics.design("feature:leaderboard:open") }
    }

    private var boardBody: some View {
        ZStack {
            theme.backdrop()
                .accessibilityHidden(true)
            P.ink.color.opacity(0.35)
            VStack(spacing: 0) {
                header
                content
            }
            // Hosts disagree about ignoresSafeArea (Zombie / Cipher /
            // Blueprints / Navigator extend under the island; Totem and
            // Luau don't) — so the board claims the full screen and insets
            // itself, keeping the back chevron clear of the island and the
            // pinned bar clear of the home bar in every host.
            .padding(.top, insets.top)
            .padding(.bottom, insets.bottom)
            if let e = cardEntry {
                PlayerCardView(entry: e) {
                    withAnimation(.easeOut(duration: 0.2)) { cardEntry = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(5)
            }
        }
        .ignoresSafeArea()
        .task { await load() }
        .onChange(of: GameCenter.shared.isAuthenticated) { _, authed in
            if authed { Task { await load(force: true) } }
        }
    }

    /// The key window's safe insets, read from UIKit so they hold even
    /// inside a host view hierarchy that ignores the safe area.
    private static var windowInsets: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets ?? .zero
    }

    // MARK: - Chrome

    private var header: some View {
        ZStack {
            VStack(spacing: 3) {
                Text(theme.title)
                    .font(.custom("Futura-Bold", size: 18, relativeTo: .body))
                    .tracking(3)
                    .foregroundStyle(P.blossom.color)
                Text(theme.subtitle)
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.torch.color)
            }
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(P.blossom.color)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(P.ink.color.opacity(0.55)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close leaderboard")
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            statusPanel {
                PulseDots()
                Text(theme.loadingLine)
                    .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.cream.color)
            }
        case .signedOut:
            statusPanel {
                Image.iconTrophy.resizable().scaledToFit().frame(height: 40)
                Text("SIGN IN FOR RANKS")
                    .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(P.blossom.color)
                Text(theme.signedOutLine)
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.cream.color.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                capsuleButton("SIGN IN") { GameCenter.shared.authenticate() }
            }
        case .failed:
            statusPanel {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(P.torch.color)
                Text("COULDN'T LOAD")
                    .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(P.blossom.color)
                Text("NO CONNECTION")
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.cream.color.opacity(0.8))
                capsuleButton("TRY AGAIN") { Task { await load(force: true) } }
            }
        case .loaded(let standings) where standings.entries.isEmpty:
            statusPanel {
                Image.iconCrown.resizable().scaledToFit().frame(height: 40)
                Text(theme.emptyTitle)
                    .font(.custom("Futura-Bold", size: 15, relativeTo: .body))
                    .tracking(2.5)
                    .foregroundStyle(P.blossom.color)
                Text(theme.emptyLine)
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.cream.color.opacity(0.8))
            }
        case .loaded(let standings):
            board(standings)
        }
    }

    /// Shared wood panel for the loading / signed-out / failed / empty
    /// states, centered in the free space below the header.
    private func statusPanel(@ViewBuilder _ inner: () -> some View) -> some View {
        VStack(spacing: 16, content: inner)
            .padding(.horizontal, 28)
            .padding(.vertical, 30)
            .frame(maxWidth: 300)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(P.woodDark.color)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(P.ink.color, lineWidth: 2.5))
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 40)
    }

    private func capsuleButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.custom("Futura-Bold", size: 13, relativeTo: .body))
                .tracking(3)
                .foregroundStyle(P.ink.color)
                .padding(.horizontal, 24)
                .frame(height: 44)
                .background(Capsule().fill(P.torch.color))
                .overlay(Capsule().stroke(P.ink.color.opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: - The board

    private func board(_ standings: GameCenter.Standings) -> some View {
        let top = Array(standings.entries.prefix(3))
        let rest = Array(standings.entries.dropFirst(3))
        let localInList = standings.entries.first(where: \.isLocal)
        let hidden = standings.totalPlayers - standings.entries.count
        return VStack(spacing: 0) {
            podium(top)
                .padding(.top, 18)
                .padding(.bottom, 14)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(rest) { row($0) }
                        if hidden > 0 {
                            // The fetch window is the top 50 — give the
                            // cutoff a reason instead of a hard stop.
                            Text("…\(hidden.formatted(.number.grouping(.automatic))) \(theme.footerSuffix)")
                                .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                                .tracking(2)
                                .foregroundStyle(P.cream.color.opacity(0.7))
                                .padding(.top, 6)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                    .padding(.bottom, 12)
                }
                .mask(
                    // Slats slip under the pinned bar instead of clipping hard.
                    LinearGradient(
                        stops: [.init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .onAppear {
                    // Your slat can sit below the fold inside the fetched
                    // top 50 (no pinned bar in that case) — bring it into
                    // view once layout settles.
                    guard let local = localInList, local.rank > 3 else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        if reduceMotion {
                            proxy.scrollTo(local.id, anchor: .center)
                        } else {
                            withAnimation(.easeOut(duration: 0.45)) {
                                proxy.scrollTo(local.id, anchor: .center)
                            }
                        }
                    }
                }
            }
            if localInList == nil {
                yourStanding(standings)
                    .padding(.horizontal, 24)
                    .padding(.top, 2)
                    .padding(.bottom, 10)
            }
        }
    }

    /// The top three in the game's own trophy shapes. Slot 0 is the tall
    /// crowned champion; 1 and 2 flank it.
    private func podium(_ top: [GameCenter.Entry]) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            if top.count > 1 { podiumColumn(top[1], slot: 1, width: 78, height: 84) }
            if !top.isEmpty { podiumColumn(top[0], slot: 0, width: 92, height: 112) }
            if top.count > 2 { podiumColumn(top[2], slot: 2, width: 78, height: 72) }
        }
    }

    private func podiumColumn(_ entry: GameCenter.Entry, slot: Int, width: CGFloat, height: CGFloat) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.25)) { cardEntry = entry }
        } label: {
        VStack(spacing: 6) {
            if slot == 0 {
                Image.iconCrown.resizable().scaledToFit().frame(height: 26)
            }
            theme.podiumArt(slot, width, height)
                .frame(width: width, height: height)
            Text("Nº \(entry.rank)")
                .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(P.torch.color)
            Text(entry.name.uppercased())
                .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                .tracking(1)
                .foregroundStyle(P.blossom.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: width + 14)
            Text(entry.score.formatted(.number.grouping(.automatic)))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.tierColor(entry.score))
        }
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("Rank \(entry.rank), \(entry.name), \(entry.score)")
        .accessibilityHint("Shows player card")
    }

    private func row(_ entry: GameCenter.Entry) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.25)) { cardEntry = entry }
        } label: {
        HStack(spacing: 12) {
            Text("Nº \(entry.rank)")
                .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(entry.isLocal ? P.ember.color : P.torch.color)
                .frame(width: 48, alignment: .leading)
            Text(entry.name.uppercased())
                .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                .tracking(1)
                .foregroundStyle(entry.isLocal ? P.ink.color : P.cream.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if entry.isLocal {
                Text("YOU")
                    .font(.custom("Futura-Bold", size: 9, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.blossom.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(P.ember.color))
            }
            Spacer(minLength: 8)
            Circle()
                .fill(theme.tierColor(entry.score))
                .frame(width: 6, height: 6)
            Text(entry.score.formatted(.number.grouping(.automatic)))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(entry.isLocal ? P.ink.color : theme.tierColor(entry.score))
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(entry.isLocal ? P.torch.color : P.plank.color)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(P.ink.color, lineWidth: 2))
        )
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("Rank \(entry.rank), \(entry.name)\(entry.isLocal ? ", you" : ""), \(entry.score)")
        .accessibilityHint("Shows player card")
    }

    /// Pinned bar for a player outside the visible top: your carve on the
    /// board, or the nudge to make one.
    @ViewBuilder
    private func yourStanding(_ standings: GameCenter.Standings) -> some View {
        if let local = standings.local {
            Button {
                withAnimation(.spring(duration: 0.3, bounce: 0.25)) { cardEntry = local }
            } label: {
            HStack(spacing: 12) {
                Text("Nº \(local.rank)")
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(1.5)
                    .foregroundStyle(P.ember.color)
                    .frame(width: 48, alignment: .leading)
                Text("YOU")
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(1)
                    .foregroundStyle(P.ink.color)
                Text("OF \(standings.totalPlayers.formatted(.number.grouping(.automatic)))")
                    .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                    .tracking(1)
                    .foregroundStyle(P.ember.color.opacity(0.8))
                Spacer(minLength: 8)
                Text(local.score.formatted(.number.grouping(.automatic)))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(P.ink.color)
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(P.torch.color)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(P.ink.color, lineWidth: 2.5))
            )
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel("Your rank \(local.rank) of \(standings.totalPlayers), \(local.score)")
            .accessibilityHint("Shows your player card")
        } else {
            Text(theme.joinLine)
                .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.cream.color.opacity(0.85))
                .frame(height: 40)
        }
    }

    private func load(force: Bool = false) async {
        guard GameCenter.shared.isAuthenticated else {
            phase = .signedOut
            return
        }
        if !force, case .loaded = phase { return }
        phase = .loading
        do {
            phase = .loaded(try await GameCenter.shared.loadStandings(for: theme.game, forceRefresh: force))
            #if DEBUG
            // Staging: TIKI_LB_CARD=<rank> opens that entry's player card.
            if case .loaded(let s) = phase, cardEntry == nil,
               let raw = ProcessInfo.processInfo.environment["TIKI_LB_CARD"], let r = Int(raw) {
                cardEntry = s.entries.first { $0.rank == r } ?? s.local
            }
            #endif
        } catch {
            phase = .failed
        }
    }
}

/// Hanging plank above a game's payoff panel — the door to its board.
/// Shows the player's world rank once standings land; plain otherwise.
struct LeaderboardBar: View {
    let title: String
    let rank: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image.iconTrophy.resizable().scaledToFit().frame(height: 15)
                Text(title)
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.blossom.color)
                if let rank {
                    Text("Nº \(rank)")
                        .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                        .tracking(1.5)
                        .foregroundStyle(P.torch.color)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Capsule().fill(P.plank.color))
            .overlay(Capsule().stroke(P.ink.color, lineWidth: 2.5))
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityLabel("\(title) leaderboard")
    }
}

/// Three ember dots breathing in sequence while a board loads; holds
/// steady under Reduce Motion. Shared with PlayerCardView.
struct PulseDots: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bright = false

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(P.torch.color)
                    .frame(width: 10, height: 10)
                    .opacity(bright ? 1 : 0.35)
                    .animation(
                        reduceMotion ? nil
                            : .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(i) * 0.2),
                        value: bright
                    )
            }
        }
        .onAppear { bright = true }
        .accessibilityHidden(true)
    }
}

#Preview {
    LeaderboardView(theme: .theme(for: .tikiStacks)!, onDismiss: {})
}
