import SwiftUI

/// One player, the whole lounge: avatar, display name, and their standing
/// on every board — rank, score in that game's tier tint, and the date the
/// best was set. Presented over a board from a row or podium tap, in the
/// HowToPlayPanel idiom (ink dim, tap outside to dismiss).
struct PlayerCardView: View {
    let entry: GameCenter.Entry
    let onDismiss: () -> Void
    @State private var phase: Phase = .loading

    enum Phase {
        case loading
        case failed
        case loaded(GameCenter.PlayerCard)
    }

    var body: some View {
        ZStack {
            P.ink.color.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            panel
        }
        .task { await load() }
    }

    private var panel: some View {
        VStack(spacing: 12) {
            avatar
            Text(entry.name.uppercased())
                .font(.custom("Futura-Bold", size: 16, relativeTo: .body))
                .tracking(2)
                .foregroundStyle(P.blossom.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            switch phase {
            case .loading:
                PulseDots()
                    .frame(height: 30)
                Text("LOADING RANKS…")
                    .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.cream.color.opacity(0.8))
                    .padding(.bottom, 8)
            case .failed:
                Text("COULDN'T LOAD")
                    .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.cream.color.opacity(0.8))
                Button {
                    Task { await load() }
                } label: {
                    Text("TRY AGAIN")
                        .font(.custom("Futura-Bold", size: 12, relativeTo: .body))
                        .tracking(2.5)
                        .foregroundStyle(P.ink.color)
                        .padding(.horizontal, 20)
                        .frame(height: 38)
                        .background(Capsule().fill(P.torch.color))
                }
                .buttonStyle(SoftPressStyle())
                .padding(.bottom, 6)
            case .loaded(let card):
                Text("ON \(card.standings.count) OF \(TikiGame.allCases.count) BOARDS")
                    .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                    .tracking(2)
                    .foregroundStyle(P.torch.color)
                VStack(spacing: 7) {
                    ForEach(TikiGame.allCases) { game in
                        row(game, card.standings[game])
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .frame(maxWidth: 330)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(P.woodDark.color)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(P.ink.color, lineWidth: 2.5))
        )
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var avatar: some View {
        ZStack {
            Circle().fill(P.plank.color)
            if case .loaded(let card) = phase, let photo = card.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(String(entry.name.prefix(2)).uppercased())
                    .font(.custom("Futura-Bold", size: 24, relativeTo: .body))
                    .tracking(1)
                    .foregroundStyle(P.blossom.color)
            }
        }
        .frame(width: 76, height: 76)
        .clipShape(Circle())
        .overlay(Circle().stroke(P.ink.color, lineWidth: 2.5))
        .accessibilityHidden(true)
    }

    private func row(_ game: TikiGame, _ standing: GameCenter.BoardStanding?) -> some View {
        HStack(spacing: 10) {
            game.icon
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(game.displayName.uppercased())
                .font(.custom("Futura-Bold", size: 11, relativeTo: .body))
                .tracking(1.5)
                .foregroundStyle(P.cream.color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            if let standing {
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Nº \(standing.rank)")
                            .font(.custom("Futura-Bold", size: 10, relativeTo: .body))
                            .tracking(1)
                            .foregroundStyle(P.torch.color)
                        Text(standing.score.formatted(.number.grouping(.automatic)))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(LeaderboardTheme.theme(for: game)?.tierColor(standing.score) ?? P.blossom.color)
                    }
                    if let date = standing.date {
                        Text(Self.dateLine(date))
                            .font(.custom("Futura-Bold", size: 9, relativeTo: .body))
                            .tracking(1)
                            .foregroundStyle(P.cream.color.opacity(0.55))
                    }
                }
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(P.cream.color.opacity(0.35))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(P.plank.color)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(P.ink.color, lineWidth: 1.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(standing.map {
            "\(game.displayName): rank \($0.rank), \($0.score)\($0.date.map { d in ", set \(Self.dateLine(d))" } ?? "")"
        } ?? "\(game.displayName): not charted")
    }

    /// "JUL 12", or "JUL 12 '25" once the year no longer matches.
    private static func dateLine(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = Calendar.current.isDate(date, equalTo: .now, toGranularity: .year)
            ? "MMM d" : "MMM d ''yy"
        return fmt.string(from: date).uppercased()
    }

    private func load() async {
        phase = .loading
        do {
            phase = .loaded(try await GameCenter.shared.loadPlayerCard(for: entry))
        } catch {
            phase = .failed
        }
    }
}
