import SwiftUI

// MARK: - Picker slot (banner + games)

/// A destination on the sign rail. `.leaderboards` hangs at position 0 —
/// one swipe left of the first game — as the boards' front door; `.game`
/// wraps the shipping games. Keeping this separate from `TikiGame` avoids
/// polluting the game-typed pipelines (previews, bests, save-state, launch
/// expansion).
enum PickerSlot: Hashable, Identifiable {
    case lounge
    case leaderboards
    case game(TikiGame)

    var id: String {
        switch self {
        case .lounge: return "lounge"
        case .leaderboards: return "leaderboards"
        case .game(let g): return g.rawValue
        }
    }

    /// The rail: the lounge, the leaderboard banner, then the games. The
    /// picker still OPENS on the first game (`home`) — lounge and boards
    /// are a swipe back, not a landing.
    static let all: [PickerSlot] = [.lounge, .leaderboards] + TikiGame.pickerOrder.map(PickerSlot.game)

    /// Cold-start slot: the first game, not the banner. Everything that
    /// used to assume "position 0 is where the rail opens" reads this.
    static let home: PickerSlot = .game(TikiGame.pickerOrder[0])

    var game: TikiGame? {
        if case .game(let g) = self { return g } else { return nil }
    }

    var pickerAccent: RGB {
        switch self {
        case .lounge, .leaderboards: return P.torch
        case .game(let g): return g.pickerAccent
        }
    }

    var displayName: String {
        switch self {
        case .lounge: return "The Lounge"
        case .leaderboards: return "Leaderboards"
        case .game(let g): return g.displayName
        }
    }

    var pickerGenre: String {
        switch self {
        case .lounge: return "HOME"
        case .leaderboards: return "HIGH SCORES"
        case .game(let g): return g.pickerGenre
        }
    }

    var pickerGenreSpoken: String {
        switch self {
        case .lounge: return "Your home room"
        case .leaderboards: return "The leaderboards"
        case .game(let g): return g.pickerGenreSpoken
        }
    }
}

// MARK: - Picker presentation of TikiGame

extension TikiGame {
    /// Rail display order. Its own array rather than `allCases` — same
    /// reason `PlayerStore.nightlyGameOrder` is its own: a semantic order
    /// should never ride on the enum's declaration order, which other
    /// code may depend on. Luau leads because it is the deepest game in
    /// the bundle (a 200-level authored campaign) and therefore the
    /// strongest first card a new player meets.
    ///
    /// Anything positional on the rail — seam blend, indicator pips,
    /// VoiceOver "game N of 6" — must read this, not `allCases`.
    /// Rail display order. Must stay a cover of `allCases`. Luau still leads.
    static let pickerOrder: [TikiGame] = [
        .luau, .tikiStacks, .zombie, .cabanaCipher, .blueprints, .navigator,
    ]

    /// Accent stripe + indicator color (PICKER_SPEC §5): echoes each game's
    /// footage; torch is reserved for "gold" (PLAY fill, BEST label).
    /// The two dark accents take the spec's named fallback (25% toward
    /// blossom) so they read on plank and the darkened wall at mini-sign
    /// size; hue still carries the identity.
    var pickerAccent: RGB {
        switch self {
        case .tikiStacks: return P.coral
        case .luau: return P.lagoon.lerp(P.blossom, 0.25)
        case .zombie: return P.sunsetMid
        case .cabanaCipher: return P.cream
        case .blueprints: return P.twilight.lerp(P.blossom, 0.25)
        case .navigator: return P.bioGlow   // glow-tide cyan; bright, reads on plank unaided
        }
    }

    var pickerGenre: String {
        switch self {
        case .tikiStacks: return "BLOCK PUZZLE"
        case .luau: return "MATCH-3"
        case .zombie: return "MERGE 2048"
        case .cabanaCipher: return "LETTER PUZZLE"
        case .blueprints: return "PICTURE GRID"
        case .navigator: return "MEMORY"
        }
    }

    var pickerGenreSpoken: String {
        switch self {
        case .tikiStacks: return "Block puzzle"
        case .luau: return "Match three"
        case .zombie: return "Merge twenty forty-eight"
        case .cabanaCipher: return "Letter puzzle"
        case .blueprints: return "Picture grid"
        case .navigator: return "Memory"
        }
    }

    /// Item 11 tint ladder: one accent per named depth state, indexed by the
    /// deepest milestone ever recorded (bit table at
    /// `PlayerStore.recordMilestone`), echoing each scene's own palette.
    var depthAccents: [RGB] {
        switch self {
        case .tikiStacks:  // DUSK / NIGHTFALL / MOONRISE / GLOW TIDE
            return [P.sunsetMid, P.twilight, P.blossom.lerp(P.twilight, 0.18), P.bioGlow]
        case .zombie:      // DUSK BLINDS / NIGHT NEON / VOLCANO WATCH / THE ZOMBIE
            return [P.sunsetMid, P.rum, P.coral.lerp(P.rum, 0.5), P.torch]
        case .luau:        // FLAME / BLAZE / INFERNO
            return [P.torch, P.coral, P.rum.lerp(P.coral, 0.3)]
        case .blueprints:  // 5 / 15 / 30 drafts hung in the sky
            return [P.twilight, P.twilight.lerp(P.blossom, 0.35), P.cream.lerp(P.torch, 0.28)]
        case .cabanaCipher:  // matchbooks 1 / 4 / 8 / 16 — deepening golden hour
            return [P.cream.lerp(P.torch, 0.5), P.torch, P.torch.lerp(P.sunsetMid, 0.65), P.sunsetMid]
        case .navigator:  // REEF PASS / OPEN OCEAN / LANDFALL / first perfect chart — the deepening voyage
            return [P.lagoonTeal, P.lagoon.lerp(P.blossom, 0.35), P.bioGlow, P.blossom]
        }
    }
}

