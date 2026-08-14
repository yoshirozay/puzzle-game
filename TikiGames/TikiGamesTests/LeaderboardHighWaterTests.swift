import Foundation
import Testing
@testable import Tiki_Lounge

/// The high-water cache drops any submission it believes the server already
/// has — locally, before any network call, with no error anywhere. Two ways
/// that assumption breaks, both of which shipped:
///
/// 1. A board changes WHICH stat it ranks. Top Shelf moved from the
///    cumulative merge score (grows all run) to the board's face value
///    (a merge conserves it; 16 tiles bound it). Every player who scored
///    under the old rule held a high-water no new score could reach, so
///    their board went permanently quiet.
/// 2. The board's data is deleted or reset server-side, leaving the cache
///    describing scores that no longer exist.
///
/// Neither fails loudly. These tests pin the guards that make them recover.
@MainActor
@Suite("Leaderboard high-water survives a re-ranked board")
struct LeaderboardHighWaterTests {

    @Test("Only the re-ranked board carries a bumped metric version")
    func onlyRerankedBoardIsBumped() {
        #expect(GameCenter.rankedMetricVersion(.zombie) == 2)
        for game in TikiGame.allCases where game != .zombie {
            #expect(GameCenter.rankedMetricVersion(game) == 1,
                    "\(game.rawValue) has not been re-ranked — it should stay at v1")
        }
    }

    @Test("Bumping the version yields a different key")
    func versionPartitionsTheKey() {
        let v1 = GameCenter.highWaterKey(.zombie, version: 1, playerID: "P")
        let v2 = GameCenter.highWaterKey(.zombie, version: 2, playerID: "P")
        #expect(v1 != v2)
    }

    @Test("An old-scale high-water is invisible under the new version")
    func oldScaleValueDoesNotLeakForward() {
        // The actual failure, reproduced against real UserDefaults: a large
        // cumulative score stored under v1 must not be what a v2 board-value
        // submission is compared against.
        let player = "test-\(UUID().uuidString)"
        let oldKey = GameCenter.highWaterKey(.zombie, version: 1, playerID: player)
        let newKey = GameCenter.highWaterKey(.zombie, version: 2, playerID: player)
        defer {
            UserDefaults.standard.set(0, forKey: oldKey)
            UserDefaults.standard.set(0, forKey: newKey)
        }

        UserDefaults.standard.set(2_440, forKey: oldKey)   // old cumulative scale

        let newHighWater = UserDefaults.standard.integer(forKey: newKey)
        #expect(newHighWater == 0, "the new scale must start from zero, not 2440")

        // A realistic board value now submits instead of being discarded.
        let boardValue = 420
        #expect(boardValue > newHighWater)
        // ...and would have been dropped had the key not been partitioned.
        #expect(boardValue <= UserDefaults.standard.integer(forKey: oldKey))
    }

    @Test("Bumping the epoch re-keys every board at once")
    func epochResetsAllBoards() {
        // A metric bump rescues one board. A server-side wipe hits all six,
        // so the epoch has to partition every game, not just the re-ranked one.
        for game in TikiGame.allCases {
            let before = GameCenter.highWaterKey(game, version: 1, playerID: "P", epoch: 1)
            let after = GameCenter.highWaterKey(game, version: 1, playerID: "P", epoch: 2)
            #expect(before != after, "\(game.rawValue) did not re-key on the epoch bump")
        }
    }

    @Test("An epoch bump hides pre-wipe high-waters for every game")
    func epochInvalidatesStaleValues() {
        let player = "test-\(UUID().uuidString)"
        for game in TikiGame.allCases {
            let old = GameCenter.highWaterKey(game, version: 1, playerID: player, epoch: 1)
            let new = GameCenter.highWaterKey(game, version: 1, playerID: player, epoch: 2)
            defer { UserDefaults.standard.set(0, forKey: old) }
            UserDefaults.standard.set(9_999, forKey: old)
            #expect(UserDefaults.standard.integer(forKey: new) == 0,
                    "\(game.rawValue) still sees its pre-wipe high-water")
        }
    }

    @Test("The shipped epoch reflects the 2026-08-01 wipe")
    func shippedEpochIsCurrent() {
        #expect(GameCenter.currentBoardEpoch == 2)
    }

    @Test("Keys stay partitioned per game and per player")
    func keysArePartitioned() {
        let perGame = TikiGame.allCases.map {
            GameCenter.highWaterKey($0, version: 1, playerID: "P")
        }
        #expect(Set(perGame).count == TikiGame.allCases.count)

        let a = GameCenter.highWaterKey(.zombie, version: 2, playerID: "playerA")
        let b = GameCenter.highWaterKey(.zombie, version: 2, playerID: "playerB")
        #expect(a != b, "switching Game Center account must not inherit a high-water")
    }
}
