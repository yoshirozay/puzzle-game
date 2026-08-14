import Foundation
import Testing
@testable import Tiki_Lounge

// Rail display order (TikiGame.pickerOrder) and cold-launch resume
// (ContentView.resumeTarget).
//
// Both shipped together in the "open into play, lead with Luau" change.
// Neither touches PlayerStore, so these suites need no defaults snapshot —
// pickerOrder is a compile-time constant and resumeTarget is pure.

@MainActor
final class PickerOrderTests {

    // The rail order is deliberately NOT TikiGame.allCases. This is the
    // guard that a seventh game added to the enum can't silently fail to
    // appear on the rail — the single most likely way to break this.
    // guards: pickerOrder is a complete, duplicate-free cover of allCases
    @Test func pickerOrderCoversEveryGameExactlyOnce() {
        #expect(Set(TikiGame.pickerOrder) == Set(TikiGame.allCases),
                "every game must appear on the rail")
        #expect(TikiGame.pickerOrder.count == TikiGame.allCases.count,
                "a game must not appear on the rail twice")
    }

    // guards: lounge, then the banner, then Luau — the picker still OPENS
    // on Luau (PickerSlot.home)
    @Test func loungeAndBannerLeadTheRailLuauLeadsTheGames() {
        #expect(TikiGame.pickerOrder.first == .luau)
        #expect(PickerSlot.all.first == .lounge,
                "the lounge hangs at position 0")
        #expect(PickerSlot.all.count > 2 && PickerSlot.all[1] == .leaderboards,
                "the leaderboard banner is next")
        #expect(PickerSlot.all[2] == .game(.luau),
                "Luau is the first game card")
        #expect(PickerSlot.home == .game(.luau),
                "cold start lands on the first game, not the lounge")
    }

    // guards: the lounge is back on the rail
    @Test func loungeIsOnTheRail() {
        #expect(PickerSlot.all.contains(.lounge))
    }

    // PickerSlot.all[0..2] are read at property-initializer time by
    // GamePickerView.cardDrop, and all[0] gates the rail's opacity — a
    // short rail would trap or render invisible.
    // guards: the rail is lounge + banner + the shipping roster
    @Test func railIsLoungeBannerPlusRoster() {
        #expect(PickerSlot.all.count == TikiGame.allCases.count + 2)
        #expect(PickerSlot.all.count >= 3, "cardDrop seeds all[0..2]")
        #expect(PickerSlot.all.filter { $0 == .leaderboards }.count == 1,
                "exactly one banner")
        #expect(PickerSlot.all.filter { $0 == .lounge }.count == 1,
                "exactly one lounge")
    }

    // guards: the shipping roster is all six games
    @Test func rosterIsAllSixGames() {
        #expect(Set(TikiGame.allCases) == Set([
            .tikiStacks, .luau, .zombie, .cabanaCipher, .blueprints, .navigator
        ]))
    }

    // The nightly distinct-games mask persists ITS order separately and must
    // stay independent of anything cosmetic.
    // guards: reordering the rail never implies reordering the enum
    @Test func railOrderIsIndependentOfEnumOrder() {
        #expect(TikiGame.pickerOrder != TikiGame.allCases,
                "if these ever match, the decoupling is no longer being exercised")
        #expect(TikiGame.allCases.first == .tikiStacks,
                "allCases order is load-bearing elsewhere — it must not drift")
    }
}

@MainActor
final class ColdLaunchResumeTests {

    // The v2 product decision, reversing "open into play": a fresh install
    // lands on the home rail and picks a game. Only returning players resume.
    // guards: no recorded last game opens the picker, not Luau
    @Test func freshInstallOpensThePicker() {
        #expect(ContentView.resumeTarget(lastGameRaw: nil) == nil)
    }

    // guards: the happy path — a returning player lands on their last game
    @Test func returningPlayerResumesIntoLastGame() {
        for game in TikiGame.allCases {
            #expect(ContentView.resumeTarget(lastGameRaw: game.rawValue) == game,
                    "\(game.rawValue) must round-trip through the resume key")
        }
    }

    // The key holds a rawValue string, so a renamed or retired case would
    // otherwise resume into the wrong game (or none).
    // guards: an unrecognized persisted rawValue degrades to the picker
    @Test func unknownPersistedGameOpensThePicker() {
        #expect(ContentView.resumeTarget(lastGameRaw: "honu") == nil,
                "a retired game id must fall back, not resume")
        #expect(ContentView.resumeTarget(lastGameRaw: "") == nil)
    }


    // Every rawValue the resume key can hold must round-trip, or a player
    // gets silently relocated to Luau on their next launch.
    // guards: rawValues are the stable identity the resume key depends on
    @Test func everyGameRawValueIsRecognized() {
        for game in TikiGame.allCases {
            #expect(TikiGame(rawValue: game.rawValue) == game)
        }
    }
}
