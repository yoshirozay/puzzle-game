import SwiftUI

extension Image {
    static let loungeScene = Image("LoungeScene")

    static let backBarShelf = Image("BackBarShelf")
    static let bartenderVic = Image("BartenderVic")
    static let blowfishLamp = Image("BlowfishLamp")
    static let cornerFronds = Image("CornerFronds")
    static let flamingMug = Image("FlamingMug")
    static let glassFloat = Image("GlassFloat")
    static let highballMan = Image("HighballMan")
    static let martiniWoman = Image("MartiniWoman")
    static let palmPlant = Image("PalmPlant")
    static let recordCredenza = Image("RecordCredenza")
    static let recordDisc = Image("RecordDisc")
    static let sunsetWindow = Image("SunsetWindow")
    static let umbrellaDrink = Image("UmbrellaDrink")
    static let suspiciousCat = Image("SuspiciousCat")
    static let tikiStatue = Image("TikiStatue")

    // Lagoon delivery (Carson's "Water scene SVGs", 2026-07-16): shop items
    // that live in the water band above the room. Baked wavelets stripped
    // and rgba fills pre-blended to solids at import (Xcode's SVG importer
    // ignores fill alpha).
    static let buoy = Image("Buoy")
    static let lagoonDuck = Image("LagoonDuck")
    static let messageBottle = Image("MessageBottle")
    static let dolphin = Image("Dolphin")
    static let seaTurtle = Image("SeaTurtle")
    static let sailboat = Image("Sailboat")
    static let shark = Image("Shark")
    static let orca = Image("Orca")
    static let farIsland = Image("FarIsland")
    static let volcano = Image("Volcano")
    static let yacht = Image("Yacht")

    // Lounge v2 delivery (assets/sprites-v2, LOUNGE_V2_PLAN.md).
    static let barStools = Image("BarStools")
    static let ceilingFan = Image("CeilingFan")
    static let ceilingFanBlades: [Image] = [
        Image("CeilingFanBladesA"), Image("CeilingFanBladesB"), Image("CeilingFanBladesC"),
    ]
    static let marlin = Image("Marlin")
    static let parrot = Image("Parrot")
    static let neonTikiSign = Image("NeonTikiSign")
    static let neonTikiSignGlow = Image("NeonTikiSignGlow")
    static let aquarium = Image("Aquarium")
    static let aquariumFish: [Image] = [
        Image("AquariumFish1"), Image("AquariumFish2"), Image("AquariumFish3"),
        Image("AquariumFish4"), Image("AquariumFish5"),
    ]
    static let zombieTrophyMug = Image("ZombieTrophyMug")
    static let zombieTrophyMugGlow = Image("ZombieTrophyMugGlow")
    static let piano = Image("Piano")
    static let couch = Image("Couch")
    static let couchCouple = Image("CouchCouple")
    static let highTable = Image("HighTable")
    static let highTableCouple = Image("HighTableCouple")
    static let plantBush = Image("PlantBush")
    static let plantSnake = Image("PlantSnake")
    static let plantTiered = Image("PlantTiered")
    static let rugColorways: [Image] = [
        Image("Rug"), Image("RugLagoon"), Image("RugMidnight"), Image("RugRum"),
    ]
    static func matchbookCover(_ index: Int) -> Image {
        Image(String(format: "Matchbook%02d", index))
    }

    /// Luau match-3 pieces by kind index, plus the three specials.
    static let luauPieces: [Image] = [
        Image("LuauHibiscus"), Image("LuauMask"), Image("LuauMug"),
        Image("LuauFloat"), Image("LuauFrond"), Image("LuauFlame"),
    ]
    static let luauSpecialTorch = Image("LuauSpecialTorch")
    static let luauSpecialCat = Image("LuauSpecialCat")
    static let luauSpecialBomb = Image("LuauSpecialBomb")

    /// Zombie merge drink ladder, tiers 1...11 (Coconut Water -> THE ZOMBIE).
    static func zombieTile(_ tier: Int) -> Image {
        Image("ZombieTile" + String(format: "%02d", min(max(tier, 1), 11)))
    }

    /// Navigator memory-flash pieces: sky cell plate, the star (lit state —
    /// code drives idle/ignited via opacity/scale), the shooting-star decoy,
    /// and the miss cloud. How-to rows reuse the same four.
    static let navigatorCell = Image("NavigatorCell")
    static let navigatorStar = Image("NavigatorStar")
    static let navigatorDecoy = Image("NavigatorDecoy")
    static let navigatorCloud = Image("NavigatorCloud")

    static let tikiStacksIcon = Image("TikiStacksIcon")
    static let luauIcon = Image("LuauIcon")
    static let zombieIcon = Image("ZombieIcon")
    static let cabanaCipherIcon = Image("CabanaCipherIcon")
    static let blueprintsIcon = Image("BlueprintsIcon")
    static let navigatorIcon = Image("NavigatorIcon")
}

enum TikiGame: String, CaseIterable, Identifiable {
    // .honu (game #6, hex-match) was parked pre-store — sources live in
    // TikiGames/_Attic/Honu/ pending an IAP revival. See that folder's README.
    case tikiStacks, luau, zombie, cabanaCipher, blueprints, navigator

    /// Full roster. Cipher, Blueprints and Navigator were hidden for a v2
    /// trim; they are back on. Honu stays in _Attic.
    static var allCases: [TikiGame] {
        [.tikiStacks, .luau, .zombie, .cabanaCipher, .blueprints, .navigator]
    }

    var id: String { rawValue }

    /// All six games are playable.
    var isPlayable: Bool { true }

    var displayName: String {
        switch self {
        case .tikiStacks: return "Totem"
        case .luau: return "Luau"
        case .zombie: return "Top Shelf"
        case .cabanaCipher: return "Cabana Cipher"
        case .blueprints: return "Blueprints"
        case .navigator: return "Navigator"
        }
    }

    var icon: Image {
        switch self {
        case .tikiStacks: return .tikiStacksIcon
        case .luau: return .luauIcon
        case .zombie: return .zombieIcon
        case .cabanaCipher: return .cabanaCipherIcon
        case .blueprints: return .blueprintsIcon
        case .navigator: return .navigatorIcon
        }
    }
}
