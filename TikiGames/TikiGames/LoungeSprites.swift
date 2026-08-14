import SwiftUI

// MARK: - Sprite lookup

enum LoungeSprites {
    /// itemID -> catalog sprite. The string bridge the typed accessors lack.
    static func image(for itemID: String) -> Image {
        switch itemID {
        case "flamingMug": return .flamingMug
        case "umbrellaDrink": return .umbrellaDrink
        case "cornerFronds": return .cornerFronds
        case "palmPlant": return .palmPlant
        case "glassFloat": return .glassFloat
        case "tikiStatue": return .tikiStatue
        case "blowfishLamp": return .blowfishLamp
        case "recordCredenza": return .recordCredenza
        case "martiniWoman": return .martiniWoman
        case "highballMan": return .highballMan
        case "backBarShelf": return .backBarShelf
        case "sunsetWindow": return .sunsetWindow
        case "suspiciousCat": return .suspiciousCat
        case "barStools": return .barStools
        case "ceilingFan": return .ceilingFan
        case "marlin": return .marlin
        case "parrot": return .parrot
        case "neonTikiSign": return .neonTikiSign
        case "aquarium": return .aquarium
        case "grandPiano": return .piano
        case "loungeCouch": return .couch
        case "highTable": return .highTable
        case "plantBush": return .plantBush
        case "plantSnake": return .plantSnake
        case "plantTiered": return .plantTiered
        case "loungeRug": return Image.rugColorways[0]
        case "buoy": return .buoy
        case "lagoonDuck": return .lagoonDuck
        case "messageBottle": return .messageBottle
        case "dolphin": return .dolphin
        case "seaTurtle": return .seaTurtle
        case "sailboat": return .sailboat
        case "shark": return .shark
        case "orca": return .orca
        case "farIsland": return .farIsland
        case "volcano": return .volcano
        case "yacht": return .yacht
        default: return .flamingMug
        }
    }

    /// itemID -> shop thumbnail. All catalog art is asset-backed as of the
    /// lounge v2 delivery, except the code-drawn live bay window.
    @ViewBuilder
    static func thumbnail(for itemID: String) -> some View {
        if itemID == "bayWindow" {
            LiveWindowView(t: 0.9, view: .sunset)
                .aspectRatio(1.0 / 0.70, contentMode: .fit)
        } else {
            image(for: itemID).resizable().scaledToFit()
        }
    }
}

