import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Tiki_Lounge

// Adversarial tests for PlayerStore (the app's single @MainActor SwiftData
// persistence gateway) and DepthDial (ProgressPhase.swift).
//
// Isolation strategy:
//  - PlayerStore is @MainActor @Observable, so every store-touching suite is
//    a @MainActor final class. Test bodies are synchronous, so they cannot
//    interleave with other MainActor tests mid-body.
//  - EVERY PlayerStore init touches real UserDefaults.standard (writes
//    tikiProgressionRetroCredit=true, consumes tikiStacksBest) even with
//    inMemory: true. Each suite snapshots the six keys in init and restores
//    them in deinit; each body additionally re-wipes to a fresh-install
//    baseline via freshStore() so no cross-test state can leak in.
//  - Multi-launch scenarios (retro-credit over persisted payloads, catalog
//    resync, mirror rehydration) use the PlayerStore(url:) seam with a
//    per-test temp file — NEVER the app's real default.store (an earlier
//    revision stashed/restored default.store and corrupted it: CoreData
//    disk I/O errors mid-suite).
//
// REGRESSION tests (formerly SUSPECTED-BUG; each exposed a real product bug,
// now fixed — these pin the fix permanently). Slugs:
//  - milestone-bit-overshift       (bit >= 64 / < 0 minted forever; now rejected)
//  - depth-nan-clamp               (NaN survived min(max(d,0),1); now rejected)
//  - position-session-reload-divergence (cx now NaN-rejected + clamped to 0...1)
//  - canafford-ownership-not-placement  (canAffordNewItem now tests ownership)
//
// Untestable-by-design (would kill the test process or need a missing seam):
// integer-overflow traps in recordRun/grant, duplicate-LoungeItem
// fatalError in init mirrors, forced context.save() failures, and TIKI_MASK
// env fuzzing (ProcessInfo env is fixed at launch). See manifest notes.

// MARK: - UserDefaults snapshot/restore

/// The UserDefaults.standard keys PlayerStore touches. All hold Bool or
/// Int; both round-trip through integer(forKey:) (bool true <-> 1).
private let playerStoreDefaultsKeys = [
    "tikiOnboardingSkipped", "tikiLoungeOnboardingSeen",
    "tikiLoungeWelcomeGiftClaimed", "tikiLoungePanHintShown",
    "tikiProgressionRetroCredit", "tikiStacksBest",
    "tikiLivesExplained", "tikiTopShelfBestIsBoardValue",
] + TikiGame.allCases.map { "tikiOnboardingSkipped.\($0.rawValue)" }

private struct DefaultsSnapshot: Sendable {
    private let saved: [String: Int]

    init() {
        var s: [String: Int] = [:]
        for key in playerStoreDefaultsKeys
        where UserDefaults.standard.object(forKey: key) != nil {
            s[key] = UserDefaults.standard.integer(forKey: key)
        }
        saved = s
    }

    /// Fresh-install baseline: every key reads zero / false.
    ///
    /// `removeObject` alone is not enough. It only drops the value from the
    /// application domain, so a value shadowed from a lower-priority domain
    /// reappears on the next read — on the simulator `tikiLivesExplained`
    /// comes back as 1 immediately after the remove, which silently broke
    /// `livesEducationFlagIsOneShot`. Writing the baseline pins it.
    static func wipeAll() {
        for key in playerStoreDefaultsKeys {
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults.standard.set(0, forKey: key)
        }
    }

    func restore() {
        for key in playerStoreDefaultsKeys {
            // Same shadowing caveat as wipeAll: a key that was absent is
            // restored as an explicit zero, not removed, or the shadowed
            // value leaks into whichever suite runs next.
            UserDefaults.standard.set(saved[key] ?? 0, forKey: key)
        }
    }
}

// MARK: - Shared fixtures

/// Builds a deterministic store: wipes the six defaults keys, optionally
/// pre-stages the retro-credit / welcome-gift flags, then constructs an
/// isolated in-memory container.
@MainActor
private func freshStore(retroDone: Bool = false, giftClaimed: Bool = false) -> PlayerStore {
    DefaultsSnapshot.wipeAll()
    if retroDone {
        UserDefaults.standard.set(true, forKey: "tikiProgressionRetroCredit")
    }
    if giftClaimed {
        UserDefaults.standard.set(true, forKey: "tikiLoungeWelcomeGiftClaimed")
    }
    return PlayerStore(inMemory: true)
}

@MainActor
private func rowCount<T: PersistentModel>(_ type: T.Type, in store: PlayerStore) -> Int {
    (try? store.container.mainContext.fetchCount(FetchDescriptor<T>())) ?? -1
}

/// Every valid (game, bit) pair in canonical order — 22 total. Bits 18–21
/// (Honu) are reserved and absent.
// v2 trim: `combinedMilestoneMask` ORs across `TikiGame.allCases`, so a bit
// parked on a cut game is invisible to standing and the aquarium. What these
// suites actually exercise is the mask arithmetic, and
// `crossRangeBitLandsInRecordButNeverInDeepest` already pins that any game
// may hold any bit — so the cut games' indices are re-homed onto shipping
// records here. The ladder stays 22 bits deep and the thresholds stay
// honestly exercised.
//
// ⚠ These are FIXTURE assignments, not the shipping layout. In the product,
// the three shipping games own only bits 0–10, so the real reachable ceiling
// is 11 milestones: "NAME ON THE DOOR" (15) is unreachable and the aquarium
// stocks 4 of 5 species. Both live only in the Lounge, which Phase 1 cuts.
private let orderedValidBits: [(TikiGame, Int)] = [
    (.tikiStacks, 0), (.tikiStacks, 1), (.tikiStacks, 2), (.tikiStacks, 3),
    (.zombie, 4), (.zombie, 5), (.zombie, 6), (.zombie, 7),
    (.luau, 8), (.luau, 9), (.luau, 10),
    (.tikiStacks, 11), (.tikiStacks, 12), (.tikiStacks, 13),
    (.zombie, 14), (.zombie, 15), (.zombie, 16), (.zombie, 17),
    (.luau, 22), (.luau, 23), (.luau, 24), (.luau, 25),
]

/// The five top-depth bits that stock the aquarium. Re-homed onto shipping
/// games for the same reason as `orderedValidBits`.
private let topDepthBits: [(TikiGame, Int)] = [
    (.tikiStacks, 3), (.zombie, 7), (.luau, 10), (.tikiStacks, 13), (.zombie, 17),
]

// MARK: - Milestone bit attacks

@MainActor
final class MilestoneBitAttackTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    // REGRESSION(milestone-bit-overshift): Swift's smart shift makes
    // `1 << 64 == 0` and `1 << -1 == 0`, so the "already set" guard
    // (mask & 0 == 0) passed on EVERY call — recordMilestone returned true
    // and minted 75 points each time: an infinite currency faucet. Fixed by
    // rejecting bits outside 0..<Int.bitWidth.
    // guards: out-of-width bits never mint, on the first call or any after
    @Test(arguments: [64, -1])
    func overshiftBitMustNotMintTwice(_ bit: Int) {
        let store = freshStore()
        #expect(store.recordMilestone(game: .tikiStacks, bit: bit) == false,
                "out-of-width bit must be rejected outright")
        #expect(store.points == 0, "rejected bit must not mint")
        let second = store.recordMilestone(game: .tikiStacks, bit: bit)
        #expect(second == false, "same (game, bit) twice must report already-earned")
        #expect(store.points == 0, "second identical milestone must not mint")
        #expect(store.combinedMilestoneMask == 0, "no phantom bits recorded")
    }

    // guards: bit 63 (Int's sign bit) stays idempotent, but pins that the mask goes negative and out-of-range bits inflate standing counts
    @Test func signBit63IsIdempotentButCountsTowardStanding() {
        let store = freshStore()
        #expect(store.recordMilestone(game: .zombie, bit: 63))
        #expect(store.points == 75)
        #expect(store.recordMilestone(game: .zombie, bit: 63) == false)
        #expect(store.points == 75, "second call must not mint")
        #expect(store.combinedMilestoneMask == Int.min, "bit 63 makes the mask negative")
        // nonzeroBitCount still counts the out-of-range bit (1 bit -> WALK-IN).
        #expect(store.houseStanding == "WALK-IN")
        #expect(store.houseStandingTier == 0)
        for (game, bit) in orderedValidBits.prefix(4) {
            #expect(store.recordMilestone(game: game, bit: bit))
        }
        #expect(store.houseStanding == "REGULAR", "bit 63 counts as the fifth bit toward standing")
        #expect(store.houseStandingTier == 1)
    }

    // guards: deepestMilestone reads only its game's canonical range; a cross-range write corrupts the combined mask but never the ladder
    @Test func crossRangeBitLandsInRecordButNeverInDeepest() {
        let store = freshStore()
        // Bit 5 is zombie's index, written into the STACKS record.
        #expect(store.recordMilestone(game: .tikiStacks, bit: 5))
        #expect(store.combinedMilestoneMask == 1 << 5, "combined mask now claims zombie's bit")
        #expect(store.deepestMilestone(for: .tikiStacks) == nil, "bit 5 is outside stacks' 0..<4")
        #expect(store.deepestMilestone(for: .zombie) == nil, "zombie's own record is untouched")
    }

    // guards: deepestMilestone returns the 0-based index of the highest set in-range bit even with all lower rungs empty
    @Test func deepestMilestoneTopOfRangeWithGaps() {
        let store = freshStore()
        #expect(store.recordMilestone(game: .cabanaCipher, bit: 17))
        #expect(store.deepestMilestone(for: .cabanaCipher) == 3)
    }

    // guards: faucet separation — recordRun never sets milestone bits, no matter the score
    @Test func recordRunNeverMintsMilestones() {
        let store = freshStore()
        store.recordRun(game: .tikiStacks, score: 1500)
        #expect(store.deepestMilestone(for: .tikiStacks) == nil)
        #expect(store.combinedMilestoneMask == 0)
    }

    // guards: Luau's board ranks CAREER TOTAL while every other game ranks
    // its best run. A Luau run is one level (score resets each level) and
    // levels grant 13-50 moves, so best-run ranked which level you drew.
    // A big single level must NOT outrank a larger career.
    @Test func luauLeaderboardRanksCareerTotalNotBestRun() {
        let store = freshStore()
        for s in [400, 900, 300] { store.recordRun(game: .luau, score: s) }
        #expect(store.bestScore(for: .luau) == 900)          // best level, local stat
        #expect(store.leaderboardScore(for: .luau) == 1600)  // career total, ranked

        // Every other game still ranks its best run.
        for s in [400, 900, 300] { store.recordRun(game: .tikiStacks, score: s) }
        #expect(store.leaderboardScore(for: .tikiStacks) == 900)
        #expect(store.leaderboardScore(for: .tikiStacks) == store.bestScore(for: .tikiStacks))
    }

    // guards: Cipher's board ranks phrases-in-a-row, not score. Its
    // per-phrase score is dominated by phrase LENGTH (drawn, not earned),
    // so a long sloppy phrase used to outrank a short perfect one.
    @Test func cipherLeaderboardRanksStreakNotScore() {
        let store = freshStore()
        // Three phrases in a row, wildly different scores.
        for s in [36, 126, 40] { store.recordRun(game: .cabanaCipher, score: s) }
        #expect(store.leaderboardScore(for: .cabanaCipher) == 3)
        #expect(store.bestScore(for: .cabanaCipher) == 126) // score still tracked locally

        // A defeat ends the run; the BEST run survives it.
        store.breakStreak(for: .cabanaCipher)
        #expect(store.leaderboardScore(for: .cabanaCipher) == 3)
        store.recordRun(game: .cabanaCipher, score: 999)
        #expect(store.leaderboardScore(for: .cabanaCipher) == 3, "a fresh run starts at 1, not 4")

        // ...and is only beaten by a genuinely longer run.
        for _ in 0..<3 { store.recordRun(game: .cabanaCipher, score: 50) }
        #expect(store.leaderboardScore(for: .cabanaCipher) == 4)
    }

    // guards: Top Shelf's board ranks the END-OF-RUN board face value, not
    // the cumulative merge score — and keeps the BEST such board, so a later
    // weak run can't lower a standing rank
    @Test func zombieLeaderboardRanksBoardValue() {
        let store = freshStore()
        store.recordRun(game: .zombie, score: 20_480, boardValue: 4_096)
        #expect(store.leaderboardScore(for: .zombie) == 4_096)
        #expect(store.bestScore(for: .zombie) == 20_480) // run score still tracked

        store.recordRun(game: .zombie, score: 30_000, boardValue: 1_200)
        #expect(store.leaderboardScore(for: .zombie) == 4_096, "a bigger merge score must not raise the board rank")
        store.recordRun(game: .zombie, score: 100, boardValue: 6_000)
        #expect(store.leaderboardScore(for: .zombie) == 6_000)
    }

    // guards: the merge-scale best banked before Top Shelf switched to face
    // value is realigned exactly once, and never re-fires over a later best
    @Test func topShelfBestMigratesToBoardValueOnce() {
        let store = freshStore()
        store.recordRun(game: .zombie, score: 20_480, boardValue: 4_096)
        #expect(store.bestScore(for: .zombie) == 20_480, "pre-migration: the old merge scale")

        store.migrateTopShelfBestToBoardValue()
        #expect(store.bestScore(for: .zombie) == 4_096, "BEST must drop to a number the new metric can beat")

        // Second call must be a no-op. Banked so the two stats diverge —
        // a re-fire would visibly drag bestScore back down to 4_096.
        store.recordRun(game: .zombie, score: 9_000, boardValue: 1_000)
        #expect(store.leaderboardScore(for: .zombie) == 4_096, "pin: the weak board didn't raise bestBoardValue")
        store.migrateTopShelfBestToBoardValue()
        #expect(store.bestScore(for: .zombie) == 9_000, "migration re-fired and ate a real best")
    }

    // guards: a player with nothing banked is untouched by the migration
    @Test func topShelfMigrationIsInertForNewPlayers() {
        let store = freshStore()
        store.migrateTopShelfBestToBoardValue()
        #expect(store.bestScore(for: .zombie) == 0)
    }

    // guards: boardValue is opt-in — games that never pass it are unaffected
    @Test func boardValueIsOptOutForOtherGames() {
        let store = freshStore()
        store.recordRun(game: .blueprints, score: 400)
        #expect(store.leaderboardScore(for: .blueprints) == 400)
    }

    // guards: breakStreak is scoped to its own game — one game's defeat
    // must never zero another's run
    @Test func breakStreakDoesNotLeakAcrossGames() {
        let store = freshStore()
        for _ in 0..<3 { store.recordRun(game: .cabanaCipher, score: 50) }
        for _ in 0..<2 { store.recordRun(game: .blueprints, score: 400) }
        store.breakStreak(for: .cabanaCipher)
        store.recordRun(game: .blueprints, score: 400)
        #expect(store.leaderboardScore(for: .blueprints) == 400) // still ranks best run
        store.recordRun(game: .cabanaCipher, score: 50)
        #expect(store.leaderboardScore(for: .cabanaCipher) == 3) // best run intact
    }

    // guards: the career total only ever grows, so the board can't be
    // gamed by a lucky level and can't tie the way a bounded best-run does
    @Test func luauLeaderboardScoreIsMonotonic() {
        let store = freshStore()
        var last = 0
        for s in [120, 5, 900, 1, 40] {
            store.recordRun(game: .luau, score: s)
            let now = store.leaderboardScore(for: .luau)
            #expect(now >= last)
            last = now
        }
        #expect(last == 1066)
    }
}

// MARK: - Standing tiers and aquarium

@MainActor
final class StandingAndAquariumTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    // guards: houseStanding/houseStandingTier flip at exactly 5, 10, 15 set bits, and every milestone minted exactly 75
    @Test(arguments: [
        (count: 4, name: "WALK-IN", tier: 0),
        (count: 5, name: "REGULAR", tier: 1),
        (count: 9, name: "REGULAR", tier: 1),
        (count: 10, name: "ISLANDER", tier: 2),
        (count: 14, name: "ISLANDER", tier: 2),
        (count: 15, name: "NAME ON THE DOOR", tier: 3),
    ])
    func houseStandingThresholds(_ c: (count: Int, name: String, tier: Int)) {
        let store = freshStore()
        for (game, bit) in orderedValidBits.prefix(c.count) {
            #expect(store.recordMilestone(game: game, bit: bit))
        }
        #expect(store.combinedMilestoneMask.nonzeroBitCount == c.count)
        #expect(store.houseStanding == c.name)
        #expect(store.houseStandingTier == c.tier)
        #expect(store.points == c.count * 75, "wallet conservation: 75 per new bit")
    }

    // guards: aquariumFish stays within 1...5; pins that the cap engages at FOUR
    // top milestones, so the fifth game's top achievement stocks nothing.
    // Verdict on the analyst's suspected off-by-one: matches the doc comment
    // ("stocks another species, to 5" — the v2 art ships five species), so the
    // invisible fifth species is the intended art cap, pinned here.
    @Test func aquariumFishBaseAndCap() {
        let store = freshStore()
        #expect(store.aquariumFish == 1, "ships with one fish")
        for (i, (game, bit)) in topDepthBits.enumerated() {
            store.recordMilestone(game: game, bit: bit)
            #expect(store.aquariumFish == min(5, i + 2))
        }
        #expect(store.aquariumFish == 5, "all five top bits still cap at 5")
    }
}

// MARK: - Run economy

@MainActor
final class RunEconomyTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    // guards: earn rate is max(1, score/10) — floor of 1 below 20, division boundary at 20
    @Test(arguments: [
        (score: 0, earned: 1), (score: 9, earned: 1), (score: 10, earned: 1),
        (score: 19, earned: 1), (score: 20, earned: 2),
    ])
    func earnRateFloorAndDivision(_ c: (score: Int, earned: Int)) {
        let store = freshStore()
        let summary = store.recordRun(game: .luau, score: c.score)
        #expect(summary.pointsEarned == c.earned)
        #expect(store.points == c.earned)
    }

    // guards: earnScore drives the wallet only; score alone drives best/totals
    @Test func earnScoreSplitsWalletFromBest() {
        let store = freshStore()
        let summary = store.recordRun(game: .zombie, score: 1000, earnScore: 5)
        #expect(summary.pointsEarned == 1, "max(1, 5/10) == 1")
        #expect(summary.best == 1000)
        #expect(summary.isNewBest)
        #expect(store.points == 1)
        #expect(store.bestScore(for: .zombie) == 1000)
    }

    // guards: PINS the negative-score path — the floor still pays 1 while
    // totalScore silently decreases and best/isNewBest hold. No game passes a
    // negative score today; this documents the unguarded arithmetic so a
    // refactor that changes it is noticed.
    @Test func negativeScoreRunStillPaysFloor() {
        let store = freshStore()
        let summary = store.recordRun(game: .zombie, score: -500)
        #expect(summary.pointsEarned == 1)
        #expect(summary.isNewBest == false)
        #expect(store.points == 1)
        let rec = store.record(for: .zombie)
        #expect(rec.bestScore == 0)
        #expect(rec.totalScore == -500)
        #expect(rec.gamesPlayed == 1)
    }

    // guards: bestScore is monotone non-decreasing and isNewBest is true iff score STRICTLY beats the prior best
    @Test func bestScoreMonotoneAndStrictNewBest() {
        let store = freshStore()
        #expect(store.recordRun(game: .luau, score: 100).isNewBest)
        #expect(store.recordRun(game: .luau, score: 100).isNewBest == false, "equal is not a new best")
        #expect(store.recordRun(game: .luau, score: 99).isNewBest == false)
        #expect(store.bestScore(for: .luau) == 100)
        #expect(store.recordRun(game: .luau, score: 101).isNewBest)
        #expect(store.bestScore(for: .luau) == 101)
    }

    // guards: accounting stays exactly linear over many runs with a single GameRecord row (no unbounded model growth)
    @Test func manyRunsKeepInvariantsLinear() {
        let store = freshStore(retroDone: true)  // retro skipped -> no pre-made records
        for _ in 0..<2_000 {
            store.recordRun(game: .navigator, score: 10)
        }
        let rec = store.record(for: .navigator)
        #expect(rec.gamesPlayed == 2_000)
        #expect(rec.totalScore == 20_000)
        #expect(store.points == 2_000, "1 point per 10-score run")
        #expect(rowCount(GameRecord.self, in: store) == 1)
    }
}

// MARK: - Wallet and purchase

@MainActor
final class WalletAndPurchaseTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    // guards: purchase succeeds at exact balance and refuses one short, mutating nothing on refusal
    @Test(arguments: [
        (balance: 80, succeeds: true, endPoints: 0),
        (balance: 79, succeeds: false, endPoints: 79),
    ])
    func exactBalancePurchaseBoundary(_ c: (balance: Int, succeeds: Bool, endPoints: Int)) {
        let store = freshStore(giftClaimed: true)
        store.grant(points: c.balance)
        #expect(store.purchase("umbrellaDrink") == c.succeeds)
        #expect(store.points == c.endPoints)
        #expect(store.placedItemIDs.contains("umbrellaDrink") == c.succeeds)
    }

    // guards: unknown/empty/hostile item IDs are total no-ops on every id-keyed API — no wallet change, no rows, no mirror entries
    @Test(arguments: ["", "deadbeef", String(repeating: "🔥", count: 10_000)])
    func hostileItemIDsNoOp(_ id: String) {
        let store = freshStore(giftClaimed: true)
        store.grant(points: 500)
        #expect(store.purchase(id) == false)
        #expect(store.points == 500)
        store.setItemPosition(id, cx: 0.5)
        store.setItemDepth(id, depth: 0.5)
        #expect(store.itemPositions.isEmpty)
        #expect(store.itemDepths.isEmpty)
        #expect(store.placedItemIDs.isEmpty)
        #expect(rowCount(LoungeItem.self, in: store) == 38, "no phantom rows created")
    }

    // guards: the welcome gift is free exactly once regardless of balance, flips the claim flag in the same call, and lights the SHOP badge while unclaimed
    @Test(arguments: [0, 1000])
    func welcomeGiftFreeExactlyOnce(_ balance: Int) {
        let store = freshStore()
        if balance > 0 { store.grant(points: balance) }
        #expect(store.canAffordNewItem, "unclaimed gift lights the SHOP badge at any balance")
        #expect(store.purchase(PlayerStore.welcomeGiftItemID))
        #expect(store.points == balance, "the gift is on the house")
        #expect(store.welcomeGiftClaimed)
        #expect(store.placedItemIDs.contains(PlayerStore.welcomeGiftItemID))
        #expect(store.purchase(PlayerStore.welcomeGiftItemID) == false, "only once")
        #expect(store.points == balance)
    }

    // guards: PINS the cross-store desync hole — a leaked/restored claim flag
    // with a fresh SwiftData store permanently locks a new player out of the
    // free gift, and the fresh-install SHOP badge goes dark at 0 points.
    @Test func leakedGiftFlagLocksOutFreshPlayer() {
        let store = freshStore(giftClaimed: true)
        #expect(store.points == 0)
        #expect(store.purchase(PlayerStore.welcomeGiftItemID) == false,
                "claim flag true + fresh store: the bypass never fires and 0 < 50")
        #expect(store.canAffordNewItem == false)
    }

    // guards: PINS that grant() has no floor — a negative grant drives the
    // wallet negative, purchases then refuse, and recordRun still drips 1/run.
    // No production caller grants negatives; documented so refactors notice.
    @Test func negativeGrantHasNoFloor() {
        let store = freshStore(giftClaimed: true)
        store.grant(points: -10_000)
        #expect(store.points == -10_000)
        #expect(store.purchase("umbrellaDrink") == false)
        #expect(store.points == -10_000)
        store.recordRun(game: .luau, score: 0)
        #expect(store.points == -9_999)
    }

    // guards: the Sign gate — locked sign refuses purchase at any balance, is excluded from canAffordNewItem, and navigator progress must NOT count toward the launch-five gate
    @Test func lockedSignRefusesPurchaseAndBadge() {
        let store = freshStore(giftClaimed: true)
        let total = store.loungeItems.map(\.price).reduce(0, +)
        store.grant(points: total)
        // Own everything except the sign (cheapest-first order keeps it affordable).
        for item in store.loungeItems where item.itemID != PlayerStore.signItemID {
            #expect(store.purchase(item.itemID))
        }
        #expect(store.points == 600, "exactly the sign's price remains")
        #expect(store.signUnlocked == false)
        #expect(store.purchase(PlayerStore.signItemID) == false)
        #expect(store.points == 600, "refused purchase must not spend")
        #expect(store.canAffordNewItem == false, "the locked sign is not an affordable new item")

        // Navigator is NOT one of the launch five — its milestone must not unlock.
        store.recordMilestone(game: .navigator, bit: 22)
        #expect(store.signUnlocked == false)
        #expect(store.purchase(PlayerStore.signItemID) == false)

        // First rung in each launch-five game unlocks the gate.
        for (game, bit): (TikiGame, Int) in
            [(.tikiStacks, 0), (.zombie, 4), (.luau, 8), (.blueprints, 11), (.cabanaCipher, 14)] {
            store.recordMilestone(game: game, bit: bit)
        }
        #expect(store.signUnlocked)
        #expect(store.canAffordNewItem, "unlocked sign becomes the affordable new item")
        #expect(store.purchase(PlayerStore.signItemID))
        #expect(store.points == 600 + 6 * 75 - 600, "wallet conservation through the whole flow")
    }
}

// MARK: - Save state

@MainActor
final class SaveStateTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    // guards: the payload is content-agnostic — invalid JSON, control bytes, bidi overrides, and big emoji strings round-trip byte-exact; clearState is idempotent
    @Test(arguments: [
        "",
        "not{json\u{1F} \u{202E}reversed",
        String(repeating: "👩‍👩‍👧‍👦🦑", count: 50_000),
    ])
    func payloadContentAgnosticRoundTrip(_ payload: String) {
        let store = freshStore(retroDone: true)
        store.saveState(for: .zombie, payload: payload)
        #expect(store.loadState(for: .zombie) == payload, "byte-exact round-trip")
        store.clearState(for: .zombie)
        #expect(store.loadState(for: .zombie) == nil)
        store.clearState(for: .zombie)  // idempotent on absent
        #expect(store.loadState(for: .zombie) == nil)
    }

    // guards: an embedded NUL byte never crashes or corrupts the store. Byte-exact
    // NUL preservation is NOT part of the contract — the SQLite-backed store
    // truncates TEXT at NUL, and every legitimate payload is game-encoded JSON,
    // which cannot contain NUL. Pin graceful degradation, not round-trip.
    @Test func nulBytePayloadDegradesGracefully() {
        let store = freshStore(retroDone: true)
        let payload = "not{json\0trailing"
        store.saveState(for: .zombie, payload: payload)
        let loaded = store.loadState(for: .zombie)
        #expect(loaded == payload || loaded == "not{json",
                "either byte-exact or NUL-truncated prefix — never garbage")
        store.clearState(for: .zombie)
        #expect(store.loadState(for: .zombie) == nil)
    }

    // guards: saveState upserts — exactly one GameSaveState row per game, last write wins, other games untouched
    @Test func upsertReplacesSingleRow() {
        let store = freshStore(retroDone: true)
        store.saveState(for: .luau, payload: String(repeating: "x", count: 1_000_000))
        store.saveState(for: .luau, payload: "tiny")
        #expect(store.loadState(for: .luau) == "tiny")
        #expect(rowCount(GameSaveState.self, in: store) == 1)
        #expect(store.loadState(for: .zombie) == nil, "per-game isolation")
    }
}

// MARK: - Placement and depth

@MainActor
final class PlacementAndDepthTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    // guards: setItemDepth clamps to 0...1 and depth 0 (or a clamp to 0) removes the entry; the smallest positive double survives
    @Test(arguments: [
        (input: 1.5, stored: 1.0 as Double?),
        (input: -0.3, stored: nil as Double?),
        (input: 0.0, stored: nil as Double?),
        (input: Double.leastNonzeroMagnitude, stored: Double.leastNonzeroMagnitude as Double?),
    ])
    func depthClampEdges(_ c: (input: Double, stored: Double?)) {
        let store = freshStore(retroDone: true)
        store.setItemDepth("tikiStatue", depth: 0.5)  // pre-existing entry proves removal
        store.setItemDepth("tikiStatue", depth: c.input)
        #expect(store.itemDepths["tikiStatue"] == c.stored)
        let model = store.loungeItems.first { $0.itemID == "tikiStatue" }
        #expect(model?.posDepth == (c.stored ?? 0))
    }

    // REGRESSION(depth-nan-clamp): min(max(.nan, 0), 1) evaluates to NaN in
    // Swift (comparison-order dependent), `d == 0` is false for NaN, so NaN
    // persisted into posDepth and the itemDepths mirror and flowed straight
    // into layout math. Fixed: a NaN depth is rejected as a no-op (the prior
    // placement survives — a poisoned drag must not teleport the piece).
    // guards: every stored depth is a real number within 0...1
    @Test func nanDepthMustBeRejectedOrClamped() {
        let store = freshStore(retroDone: true)
        store.setItemDepth("tikiStatue", depth: 0.5)
        store.setItemDepth("tikiStatue", depth: .nan)
        if let mirrored = store.itemDepths["tikiStatue"] {
            #expect(mirrored >= 0 && mirrored <= 1, "mirror must never hold NaN/out-of-range")
        }
        #expect(store.itemDepths["tikiStatue"] == 0.5, "NaN is a no-op; prior depth survives")
        let model = store.loungeItems.first { $0.itemID == "tikiStatue" }
        let stored = model?.posDepth ?? 0
        #expect(stored >= 0 && stored <= 1, "persisted posDepth must never hold NaN")
        #expect(model?.posDepth == 0.5)
    }

    // guards: resetPlacements restores every default (posX == -1, posDepth == 0, both mirrors empty) while ownership is untouched
    @Test func resetPlacementsRestoresDefaultsKeepsOwnership() {
        let store = freshStore(giftClaimed: true)
        store.grant(points: 300)
        #expect(store.purchase("umbrellaDrink"))
        #expect(store.purchase("tikiStatue"))
        store.setItemPosition("umbrellaDrink", cx: 0.25)
        store.setItemDepth("umbrellaDrink", depth: 0.4)
        store.setItemPosition("tikiStatue", cx: 0.75)
        store.setItemDepth("tikiStatue", depth: 0.9)
        store.resetPlacements()
        #expect(store.itemPositions.isEmpty)
        #expect(store.itemDepths.isEmpty)
        #expect(store.loungeItems.allSatisfy { $0.posX == -1 && $0.posDepth == 0 })
        #expect(store.placedItemIDs == ["umbrellaDrink", "tikiStatue"], "ownership/placement flags survive")
        #expect(store.loungeItems.filter { $0.purchasedAt != nil }.count == 2)
    }

    // guards: PINS that expression prefs accept hostile values verbatim (no validation) and mirror them exactly — consumer index-safety is a different module's contract
    @Test func expressionPrefsStoreHostileValuesVerbatim() {
        let store = freshStore(retroDone: true)
        let hostile = String(repeating: "👩‍👩‍👧‍👦\u{202E}", count: 1_000)
        store.setWindowView(hostile, east: true)
        #expect(store.windowViewEast == hostile)
        #expect(store.windowViewWest == "sunset")
        store.setWindowView("verbatim-west", east: false)
        #expect(store.windowViewWest == "verbatim-west")
        #expect(store.windowViewEast == hostile, "west write must not touch the east mirror")
        store.setRugColorway(-1)
        #expect(store.rugColorway == -1)
        store.setRugColorway(Int.max)
        #expect(store.rugColorway == Int.max)
    }
}

// MARK: - Read side effects and the unenforced singleton

@MainActor
final class ReadSideEffectTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    // guards: PINS that "read-only" getters mutate the database — one houseStanding read inserts a GameRecord row per shipping game
    @Test func houseStandingReadInsertsEveryGameRecord() {
        let store = freshStore(retroDone: true)
        #expect(rowCount(GameRecord.self, in: store) == 0)
        _ = store.houseStanding
        #expect(rowCount(GameRecord.self, in: store) == TikiGame.allCases.count)
    }

    // guards: PROVES the PlayerProfile singleton is unenforced — a second row
    // inserts without error and wallet binding becomes fetch-order dependent.
    // Asserts only what holds for ALL outcomes.
    @Test func duplicateProfileRowsAreInsertableAndAmbiguous() {
        let store = freshStore(retroDone: true)
        let rogue = PlayerProfile(points: 999)
        store.container.mainContext.insert(rogue)
        try? store.container.mainContext.save()
        #expect(rowCount(PlayerProfile.self, in: store) == 2, "no unique constraint stops the duplicate")
        store.grant(points: 1)
        #expect(store.points == 1 || store.points == 1000,
                "wallet bound to whichever row the fetch returned first")
    }
}

// MARK: - Init one-shots (legacy best + retro credit, in-memory reachable)

@MainActor
final class InitOneShotTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    // guards: legacy tikiStacksBest migrates into the record AND the same init's retro pass credits all four stacks bits (+300); the key is consumed
    @Test func legacyBestMigratesAndRetroCreditsInOneInit() {
        DefaultsSnapshot.wipeAll()
        UserDefaults.standard.set(1500, forKey: "tikiStacksBest")
        let store = PlayerStore(inMemory: true)
        #expect(store.bestScore(for: .tikiStacks) == 1500)
        #expect(store.deepestMilestone(for: .tikiStacks) == 3)
        #expect(store.points == 4 * 75)
        #expect(UserDefaults.standard.object(forKey: "tikiStacksBest") == nil, "one-shot key consumed")
        #expect(UserDefaults.standard.bool(forKey: "tikiProgressionRetroCredit"))
    }

    // guards: retro-credit stacks threshold boundary at exactly 150
    @Test(arguments: [(legacy: 149, deepest: nil as Int?, points: 0),
                      (legacy: 150, deepest: 0 as Int?, points: 75)])
    func legacyBestRetroThresholdBoundary(_ c: (legacy: Int, deepest: Int?, points: Int)) {
        DefaultsSnapshot.wipeAll()
        UserDefaults.standard.set(c.legacy, forKey: "tikiStacksBest")
        let store = PlayerStore(inMemory: true)
        #expect(store.bestScore(for: .tikiStacks) == c.legacy)
        #expect(store.deepestMilestone(for: .tikiStacks) == c.deepest)
        #expect(store.points == c.points)
    }

    // guards: PINS that a non-positive legacy value skips migration but ALSO skips cleanup — the key stays behind forever (only > 0 removes it)
    @Test func nonPositiveLegacyKeyRemains() {
        DefaultsSnapshot.wipeAll()
        UserDefaults.standard.set(-5, forKey: "tikiStacksBest")
        let store = PlayerStore(inMemory: true)
        #expect(store.bestScore(for: .tikiStacks) == 0)
        #expect(UserDefaults.standard.integer(forKey: "tikiStacksBest") == -5, "key never cleaned up")
    }

    // guards: PINS the retro-credit flag-leak hazard — a pre-set flag with veteran data present credits nothing (this is why tests must restore UserDefaults)
    @Test func preSetRetroFlagSkipsVeteranCredit() {
        DefaultsSnapshot.wipeAll()
        UserDefaults.standard.set(true, forKey: "tikiProgressionRetroCredit")
        UserDefaults.standard.set(1500, forKey: "tikiStacksBest")
        let store = PlayerStore(inMemory: true)
        #expect(store.bestScore(for: .tikiStacks) == 1500, "migration still runs")
        #expect(store.deepestMilestone(for: .tikiStacks) == nil, "retro pass skipped entirely")
        #expect(store.points == 0)
    }
}

// MARK: - Persistent relaunch scenarios

/// Multi-launch scenarios go through the PlayerStore(url:) seam with a
/// per-test temp file. NEVER open the app's real default.store from tests:
/// an earlier revision stashed/restored it around each test and corrupted
/// it under the app host's live container (CoreData disk I/O errors).
@MainActor
private func freshPersistentStore(url: URL) -> PlayerStore {
    DefaultsSnapshot.wipeAll()
    return PlayerStore(url: url)
}

@Suite(.serialized)
@MainActor
final class PersistentRelaunchTests {
    private let snapshot = DefaultsSnapshot()
    /// Unique per test-case instance — each body gets its own isolated store.
    private let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlayerStoreAdversarial-\(UUID().uuidString).store")

    deinit {
        for suffix in ["", "-shm", "-wal"] {  // SQLite sidecars too
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
        snapshot.restore()
    }

    // guards: retro-credit derives milestones from persisted records/payloads at max thresholds — loreSeen 11, luau best 700, 30 blueprints, 96 solved ciphers (16 books) pay every derivable bit exactly once
    @Test func retroCreditFromPayloadsAtMaxThresholds() {
        let store1 = freshPersistentStore(url: storeURL)
        store1.saveState(for: .zombie,
            payload: #"{"seenHowTo":true,"score":0,"loreSeen":[11]}"#)
        let solved = (1...30).map { "\"p\($0)\"" }.joined(separator: ",")
        store1.saveState(for: .blueprints,
            payload: "{\"seenHowTo\":true,\"solved\":[\(solved)]}")
        store1.saveState(for: .cabanaCipher,
            payload: #"{"seenHowTo":true,"phraseIndex":96,"solvedCount":96,"assignments":{},"mistakes":0,"hints":0}"#)
        store1.debugSetBest(game: .luau, score: 700)
        UserDefaults.standard.removeObject(forKey: "tikiProgressionRetroCredit")
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.deepestMilestone(for: .zombie) == 3)
        #expect(store2.deepestMilestone(for: .luau) == 2)
        #expect(store2.deepestMilestone(for: .blueprints) == 2)
        #expect(store2.deepestMilestone(for: .cabanaCipher) == 3)
        #expect(store2.points == (4 + 3 + 4 + 3) * 75)
        #expect(UserDefaults.standard.bool(forKey: "tikiProgressionRetroCredit"))
    }

    // guards: retro-credit thresholds are exact — one-below values (loreSeen 10, luau best 699, 29 blueprints, solvedCount 95 -> 15 books) each stop one rung short
    @Test func retroCreditJustBelowThresholds() {
        let store1 = freshPersistentStore(url: storeURL)
        store1.saveState(for: .zombie,
            payload: #"{"seenHowTo":true,"score":0,"loreSeen":[10]}"#)
        let solved = (1...29).map { "\"p\($0)\"" }.joined(separator: ",")
        store1.saveState(for: .blueprints,
            payload: "{\"seenHowTo\":true,\"solved\":[\(solved)]}")
        store1.saveState(for: .cabanaCipher,
            payload: #"{"seenHowTo":true,"phraseIndex":95,"solvedCount":95,"assignments":{},"mistakes":0,"hints":0}"#)
        store1.debugSetBest(game: .luau, score: 699)
        UserDefaults.standard.removeObject(forKey: "tikiProgressionRetroCredit")
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.deepestMilestone(for: .zombie) == 2)
        #expect(store2.deepestMilestone(for: .luau) == 1)
        #expect(store2.deepestMilestone(for: .blueprints) == 1)
        #expect(store2.deepestMilestone(for: .cabanaCipher) == 2)
        #expect(store2.points == (3 + 2 + 3 + 2) * 75)
    }

    // guards: retro-credit survives hostile persisted payloads — garbage JSON, missing fields, and negative counts credit nothing, never crash, and still set the one-shot flag
    @Test func retroCreditHostilePayloadsCreditNothing() {
        let store1 = freshPersistentStore(url: storeURL)
        store1.saveState(for: .zombie, payload: "not{json\0")
        store1.saveState(for: .blueprints, payload: "{}")
        store1.saveState(for: .cabanaCipher,
            payload: #"{"seenHowTo":true,"phraseIndex":0,"solvedCount":-100,"assignments":{},"mistakes":0,"hints":0}"#)
        UserDefaults.standard.removeObject(forKey: "tikiProgressionRetroCredit")
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.combinedMilestoneMask == 0)
        #expect(store2.points == 0)
        #expect(UserDefaults.standard.bool(forKey: "tikiProgressionRetroCredit"))
    }

    // guards: the retro pass is idempotent even when the one-shot flag lies — a cleared flag re-runs it through recordMilestone's guards with zero extra mint
    @Test func retroCreditIdempotentWhenFlagCleared() {
        DefaultsSnapshot.wipeAll()
        UserDefaults.standard.set(1500, forKey: "tikiStacksBest")
        let store1 = PlayerStore(url: storeURL)
        #expect(store1.points == 300)
        UserDefaults.standard.removeObject(forKey: "tikiProgressionRetroCredit")
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.points == 300, "re-run mints nothing")
        #expect(store2.deepestMilestone(for: .tikiStacks) == 3)
    }

    // guards: every catalog row is reachable in the sectioned shop — the panel renders ONLY items named in its section map, so an id in one list and not the other would either vanish from the shop or render twice
    @Test func shopSectionsCoverCatalogExactlyOnce() {
        let store = freshStore(giftClaimed: true)
        let catalog = Set(store.loungeItems.map(\.itemID))
        let panel = LoungeShopPanel.panelOrder
        #expect(Set(panel) == catalog,
                "section map and catalog must name the same items")
        #expect(panel.count == catalog.count,
                "no item appears in two sections")
        #expect(panel.count == store.loungeItems.count,
                "the header's OF-total counts exactly what the panel renders")
    }

    // guards: prices ascend within every shop aisle — a trinket priced above the landmark it sits under is the ladder break the 2026-08 retune existed to remove
    @Test func shopSectionPricesAscend() {
        let store = freshStore(giftClaimed: true)
        let price = Dictionary(uniqueKeysWithValues: store.loungeItems.map { ($0.itemID, $0.price) })
        for section in LoungeShopPanel.sections {
            let prices = section.itemIDs.compactMap { price[$0] }
            #expect(prices == prices.sorted(),
                    "\(section.title) must read cheap doorway → aspiration cap")
        }
    }

    // guards: the ladder properties SHOP_PLAN quotes — global max adjacent step and per-aisle sums. Prices live in PlayerStore and section membership in LoungeShopPanel, so a one-sided edit silently restales the doc; this recomputes both from source.
    @Test func shopLadderPropertiesHold() {
        let store = freshStore(giftClaimed: true)
        let ladder = store.loungeItems.map(\.price).sorted()
        let maxStep = zip(ladder, ladder.dropFirst())
            .filter { $0 != $1 }
            .map { Double($1) / Double($0) }
            .max() ?? 0
        #expect(maxStep <= 1.6001, "SHOP_PLAN §4 quotes a global max adjacent step of 1.6x")

        let price = Dictionary(uniqueKeysWithValues: store.loungeItems.map { ($0.itemID, $0.price) })
        let sums = LoungeShopPanel.sections.map { section in
            section.itemIDs.compactMap { price[$0] }.reduce(0, +)
        }
        #expect(sums == [1450, 890, 1260, 3310, 3090, 7800],
                "per-aisle sums quoted in SHOP_PLAN §4")
    }

    // guards: the catalog's total sink stays inside the documented band — a reprice that silently drifts the total restales SHOP_PLAN's completion ledger, which is the whole justification for the price ladder
    @Test func catalogTotalStaysInSinkBand() {
        let store = freshStore(giftClaimed: true)
        let total = store.loungeItems.map(\.price).reduce(0, +)
        #expect(total == 17_800, "SHOP_PLAN §3/§4 quote this exact total")
        let realSpend = total - (store.loungeItems
            .first { $0.itemID == PlayerStore.welcomeGiftItemID }?.price ?? 0)
        #expect((17_000...19_000).contains(realSpend),
                "≈5.3 engaged weeks at the measured ~400 pts/day")
    }

    // guards: Navigator's wallet divisor — the whole price ladder is calibrated to it, and it used to be an untested call-site literal
    @Test func navigatorEarnScoreKeepsPassagesInLineWithTheField() {
        // A perfect 13-star passage (the campaign's richest) pays like one
        // good run elsewhere, not ten.
        #expect(PlayerStore.navigatorEarnScore(785) == 157)
        let store = freshStore(giftClaimed: true)
        let summary = store.recordRun(game: .navigator, score: 785,
                                      earnScore: PlayerStore.navigatorEarnScore(785))
        #expect(summary.pointsEarned == 15, "785 raw → 157 earn → 15 wallet")
        #expect(summary.best == 785, "the DISPLAYED score is what best tracks")
    }

    // guards: catalog resync across launches never wipes ownership/placement or duplicates rows — the 38-item catalog stays exact, the wallet persists, and expression-pref mirrors rehydrate from the profile row
    @Test func catalogResyncPreservesOwnership() {
        let store1 = freshPersistentStore(url: storeURL)
        store1.grant(points: 220)
        #expect(store1.purchase("tikiStatue"))
        store1.setWindowView("lagoon", east: false)
        store1.setRugColorway(2)
        let store2 = PlayerStore(url: storeURL)
        let statue = store2.loungeItems.first { $0.itemID == "tikiStatue" }
        #expect(statue?.purchasedAt != nil)
        #expect(statue?.isPlaced == true)
        #expect(store2.placedItemIDs.contains("tikiStatue"), "mirror rehydrates from disk")
        #expect(store2.points == 0)
        #expect(store2.loungeItems.count == 38)
        #expect(Set(store2.loungeItems.map(\.itemID)).count == 38, "no duplicate rows after double init")
        #expect(store2.windowViewWest == "lagoon", "window pref mirror rehydrates from the profile row")
        #expect(store2.windowViewEast == "sunset")
        #expect(store2.rugColorway == 2, "rug pref mirror rehydrates from the profile row")
    }

    // guards: legacy tikiStacksBest never lowers an existing record best, and the key is consumed either way
    @Test func legacyKeyConsumedButHigherRecordWins() {
        let store1 = freshPersistentStore(url: storeURL)
        store1.recordRun(game: .tikiStacks, score: 200)
        UserDefaults.standard.set(100, forKey: "tikiStacksBest")
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.bestScore(for: .tikiStacks) == 200)
        #expect(UserDefaults.standard.object(forKey: "tikiStacksBest") == nil)
    }

    // REGRESSION(position-session-reload-divergence): setItemPosition used to
    // validate nothing, so cx = -0.5 lived in the in-session mirror while
    // init's rehydration filter (posX >= 0) dropped it — the room rendered
    // differently before and after relaunch. Fixed: NaN rejected, cx clamped
    // to the 0...1 world-x domain, so session and reload always agree.
    // guards: the placement a player sees in-session (cx AND depth) is the placement after relaunch
    @Test func positionSurvivesRelaunchUnchanged() {
        let store1 = freshPersistentStore(url: storeURL)
        store1.setItemPosition("tikiStatue", cx: -0.5)
        #expect(store1.itemPositions["tikiStatue"] == 0, "out-of-domain cx clamps into 0...1")
        store1.setItemPosition("palmPlant", cx: 0.42)
        store1.setItemPosition("palmPlant", cx: .nan)
        #expect(store1.itemPositions["palmPlant"] == 0.42, "NaN is a no-op; prior position survives")
        store1.setItemDepth("palmPlant", depth: 0.6)
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.itemPositions["tikiStatue"] == store1.itemPositions["tikiStatue"],
                "session and reload views of the same placement must agree")
        #expect(store2.itemPositions["palmPlant"] == 0.42)
        #expect(store2.itemDepths["palmPlant"] == 0.6, "depth mirror rehydrates from persisted posDepth")
    }

    // REGRESSION(canafford-ownership-not-placement): canAffordNewItem used to
    // test placedItemIDs (placement) instead of purchasedAt (ownership), so an
    // owned-but-unplaced item read as an affordable NEW item — a phantom SHOP
    // badge that purchase() could never clear. Fixed: ownership decides.
    // guards: canAffordNewItem is false when every within-balance item is already owned
    @Test func ownedUnplacedItemIsNotNewlyAffordable() {
        DefaultsSnapshot.wipeAll()
        UserDefaults.standard.set(true, forKey: "tikiLoungeWelcomeGiftClaimed")
        let store1 = PlayerStore(url: storeURL)
        store1.grant(points: 850)
        // Own everything priced <= 140 (mug 50 — the gift flag is pre-claimed,
        // so it COSTS — umbrella 80, fronds 90, float 100, bush 120, buoy 120,
        // stools 140 = 700), leaving 150 — below every unowned price (next: 160).
        for id in ["flamingMug", "umbrellaDrink", "cornerFronds",
                   "glassFloat", "plantBush", "buoy", "barStools"] {
            #expect(store1.purchase(id))
        }
        #expect(store1.points == 150)
        // Un-place the owned bush directly (no public unplace API exists),
        // then force a save through a public mutator.
        store1.loungeItems.first { $0.itemID == "plantBush" }?.isPlaced = false
        store1.grant(points: 0)
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.points == 150)
        #expect(store2.canAffordNewItem == false,
                "every item within the 150 balance is owned; owned-but-unplaced is not NEW")
    }

    // guards: PINS the single-gateway assumption — a second live store over the same file keeps a stale points mirror (the double-spend hazard of two concurrent sessions)
    @Test func secondStoreMirrorGoesStale() {
        let storeA = freshPersistentStore(url: storeURL)
        let storeB = PlayerStore(url: storeURL)
        storeA.grant(points: 100)
        #expect(storeA.points == 100)
        #expect(storeB.points == 0, "B's mirror only syncs at its own init/mutations")
    }
}

// MARK: - Depth Charge consumable (Top Shelf)

@Suite(.serialized)
@MainActor
final class DepthChargeConsumableTests {
    private let snapshot = DefaultsSnapshot()
    private let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlayerStoreAdversarial-\(UUID().uuidString).store")

    deinit {
        for suffix in ["", "-shm", "-wal"] {  // SQLite sidecars too
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
        snapshot.restore()
    }

    // guards: the ON THE HOUSE comp pours exactly once, ever — a second danger moment grants nothing
    @Test func compGrantsExactlyOnce() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        #expect(store.zombieBombs == 0)
        #expect(!store.zombieBombGranted)
        #expect(store.grantZombieBombIfNeeded())
        #expect(store.zombieBombs == 1)
        #expect(store.zombieBombGranted)
        #expect(!store.grantZombieBombIfNeeded())
        #expect(store.zombieBombs == 1)
    }

    // guards: spend stops at zero — a dry shelf refuses and the count never goes negative
    @Test func spendStopsAtZero() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        #expect(!store.spendZombieBomb(), "nothing to spend before the comp")
        store.grantZombieBombIfNeeded()
        #expect(store.spendZombieBomb())
        #expect(store.zombieBombs == 0)
        #expect(!store.spendZombieBomb())
        #expect(store.zombieBombs == 0)
        #expect(store.zombieBombGranted, "granted flag survives the spend — no re-comp")
    }

    // guards: comp + spend both survive relaunch — the granted flag never resets (no second comp) and the count rehydrates into the mirrors
    @Test func bombStateSurvivesRelaunch() {
        let store1 = freshPersistentStore(url: storeURL)
        store1.grantZombieBombIfNeeded()
        do {
            let store2 = PlayerStore(url: storeURL)
            #expect(store2.zombieBombs == 1, "count mirror rehydrates from the profile row")
            #expect(store2.zombieBombGranted)
            store2.spendZombieBomb()
        }
        let store3 = PlayerStore(url: storeURL)
        #expect(store3.zombieBombs == 0)
        #expect(store3.zombieBombGranted, "a spent shelf must not re-comp on relaunch")
        #expect(!store3.grantZombieBombIfNeeded())
    }

    // guards: the Lounge Cat mirrors the Depth Charge contract — once-ever comp, spend floor at zero, relaunch persistence — and the two consumables never cross wires
    @Test func loungeCatMirrorsTheCompContract() {
        let store1 = freshPersistentStore(url: storeURL)
        #expect(!store1.spendLuauCat(), "nothing to spend before the comp")
        #expect(store1.grantLuauCatIfNeeded())
        #expect(!store1.grantLuauCatIfNeeded())
        #expect(store1.luauCats == 1)
        #expect(store1.zombieBombs == 0, "the cat comp must not fill the bomb shelf")
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.luauCats == 1, "count mirror rehydrates from the profile row")
        #expect(store2.luauCatGranted)
        #expect(store2.spendLuauCat())
        #expect(!store2.spendLuauCat())
        #expect(store2.luauCats == 0)
        let store3 = PlayerStore(url: storeURL)
        #expect(store3.luauCats == 0)
        #expect(store3.luauCatGranted, "an emptied basket must not re-comp on relaunch")
        #expect(!store3.grantLuauCatIfNeeded())
    }
}

// MARK: - The Nightly Nine (daily missions)

@Suite(.serialized)
@MainActor
final class NightlyNineTests {
    private let snapshot = DefaultsSnapshot()
    private let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlayerStoreAdversarial-\(UUID().uuidString).store")

    deinit {
        for suffix in ["", "-shm", "-wal"] {  // SQLite sidecars too
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
        snapshot.restore()
    }

    private func day(_ d: Int, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: d, hour: hour))!
    }

    private func done(_ store: PlayerStore, _ id: String) -> Bool {
        let c = PlayerStore.nightlyChallenges.first { $0.id == id }!
        return (store.nightlyProgress[id] ?? 0) >= c.target
    }

    // guards: the board is exactly nine with PERSISTED ids/targets — renames or reorders would orphan saved progress
    @Test func rosterIsNineWithStableIDs() {
        let ids = PlayerStore.nightlyChallenges.map(\.id)
        #expect(ids == ["topShelf100", "totem150", "luauNight", "navigator3",
                        "blueprintsSketch", "cipherPhrase", "rounds3", "busy4", "wallet60"])
        #expect(PlayerStore.nightlyChallenges.map(\.target) == [100, 150, 1, 3, 1, 1, 3, 4, 60])
        #expect(PlayerStore.nightlyGoal == 4)
    }

    // guards: each run feeds exactly the matching counters — score is best-of-day, wins gate Luau, per-game counts count
    @Test func runsFeedTheRightCounters() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        store.recordRun(game: .zombie, score: 99, now: day(1))
        #expect(!done(store, "topShelf100"))
        store.recordRun(game: .zombie, score: 100, now: day(1))
        #expect(done(store, "topShelf100"))
        store.recordRun(game: .zombie, score: 20, now: day(1))
        #expect(done(store, "topShelf100"), "best-of-day never regresses")
        store.recordRun(game: .luau, score: 300, now: day(1))
        #expect(!done(store, "luauNight"), "a lost night is not a cleared night")
        store.recordRun(game: .luau, score: 300, wonLevel: true, now: day(1))
        #expect(done(store, "luauNight"))
        store.recordRun(game: .navigator, score: 10, now: day(1))
        store.recordRun(game: .navigator, score: 10, now: day(1))
        #expect(!done(store, "navigator3"))
        store.recordRun(game: .navigator, score: 10, now: day(1))
        #expect(done(store, "navigator3"))
        store.recordRun(game: .blueprints, score: 40, now: day(1))
        #expect(done(store, "blueprintsSketch"))
        store.recordRun(game: .cabanaCipher, score: 40, now: day(1))
        #expect(done(store, "cipherPhrase"))
    }

    // guards: the connectors — distinct games, total rounds, and the wallet counter fed by BOTH run earnings and grant() mints
    @Test func connectorsAccumulate() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        // grant() stamps the REAL clock (no injection), so this test's runs
        // must live on the real today too — noon keeps every hour same-day.
        let today = Calendar.current.startOfDay(for: .now).addingTimeInterval(12 * 3600)
        store.recordRun(game: .zombie, score: 100, now: today)
        store.recordRun(game: .zombie, score: 100, now: today)
        #expect(store.nightlyProgress["rounds3"] == 1, "same game twice is one distinct game")
        store.recordRun(game: .luau, score: 90, now: today)
        store.recordRun(game: .blueprints, score: 40, now: today)
        #expect(done(store, "rounds3"))
        #expect(done(store, "busy4"), "four rounds anywhere")
        let runEarned = store.nightlyProgress["wallet60"] ?? 0
        #expect(runEarned == 10 + 10 + 9 + 4, "wallet counter sums recordRun earnings")
        store.grant(points: 75)
        #expect(store.nightlyProgress["wallet60"] == runEarned + 75, "grant() mints count too")
        #expect(done(store, "wallet60"))
    }

    // guards: the local-day roll — yesterday's board never leaks into tonight
    @Test func dayRollResets() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        store.recordRun(game: .blueprints, score: 40, now: day(1))
        #expect(done(store, "blueprintsSketch"))
        store.recordRun(game: .zombie, score: 100, now: day(2))
        #expect(!done(store, "blueprintsSketch"), "day rolled — sketch progress gone")
        #expect(store.nightlyProgress["busy4"] == 1, "tonight starts from this run alone")
    }

    // guards: the pour needs four, claims once per night, and prefers refilling an empty introduced slot
    @Test func rewardNeedsFourClaimsOncePrefersItems() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        store.grantZombieBombIfNeeded()
        store.spendZombieBomb()          // introduced + empty
        store.recordRun(game: .blueprints, score: 40, now: day(1))
        store.recordRun(game: .cabanaCipher, score: 40, now: day(1))
        // Under topShelf100's target: this run is here as the third distinct
        // game, and must not quietly clear Top Shelf's own goal as well.
        store.recordRun(game: .zombie, score: 20, now: day(1))
        #expect(store.nightlyCompleted == 3, "sketch + cipher + rounds3")
        #expect(store.claimNightlyReward(now: day(1)) == nil, "three is not four")
        store.recordRun(game: .cabanaCipher, score: 40, now: day(1))   // busy4 lands
        #expect(store.nightlyCompleted >= 4)
        #expect(store.claimNightlyReward(now: day(1)) == .item(.zombie))
        #expect(store.zombieBombs == 1)
        #expect(store.nightlyRewardClaimed)
        #expect(store.claimNightlyReward(now: day(1)) == nil, "one pour per night")
    }

    /// Four runs that genuinely finish four+ challenges: sketch, cipher,
    /// cleared night, 500 tab — which also lands rounds3 and busy4.
    private func playFourDone(_ store: PlayerStore, on d: Date) {
        store.recordRun(game: .blueprints, score: 40, now: d)
        store.recordRun(game: .cabanaCipher, score: 40, now: d)
        store.recordRun(game: .luau, score: 90, wonLevel: true, now: d)
        store.recordRun(game: .zombie, score: 500, now: d)
    }

    // guards: full slots fall back to wallet points — a finished board never pays nothing
    @Test func rewardFallsBackToPointsWhenSlotsFull() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        store.grantZombieBombIfNeeded()   // introduced but FULL; luau never introduced
        playFourDone(store, on: day(1))
        let before = store.points
        #expect(store.claimNightlyReward(now: day(1)) == .points(PlayerStore.nightlyPointsPour))
        #expect(store.points == before + PlayerStore.nightlyPointsPour)
        #expect(store.zombieBombs == 1, "full slot untouched")
    }

    // guards: tonight survives relaunch — progress, claim state, and the next-day reset
    @Test func tonightSurvivesRelaunch() {
        let store1 = freshPersistentStore(url: storeURL)
        store1.grantZombieBombIfNeeded()
        store1.spendZombieBomb()
        playFourDone(store1, on: day(1))
        #expect(store1.claimNightlyReward(now: day(1)) == .item(.zombie))
        let store2 = PlayerStore(url: storeURL)
        // Init refreshes mirrors against the REAL clock; re-read at the
        // injected test day before asserting.
        store2.refreshNightlyMirrors(now: day(1))
        #expect(store2.nightlyRewardClaimed, "claim state rehydrates")
        #expect(store2.claimNightlyReward(now: day(1)) == nil, "no second pour after relaunch")
        store2.recordRun(game: .cabanaCipher, score: 40, now: day(2))
        #expect(!store2.nightlyRewardClaimed, "new night, fresh claim")
        #expect(store2.nightlyProgress["cipherPhrase"] == 1)
    }

    // guards: init-time faucets (retro-credit mints) never feed tonight's wallet challenge
    @Test func initNoiseDoesNotFeedTheWallet() {
        DefaultsSnapshot.wipeAll()
        UserDefaults.standard.set(1500, forKey: "tikiStacksBest")
        let store = PlayerStore(inMemory: true)
        #expect(store.points == 300, "retro credit minted at init")
        #expect((store.nightlyProgress["wallet60"] ?? 0) == 0, "init mints are not tonight's play")
        store.grant(points: 20)
        #expect(store.nightlyProgress["wallet60"] == 20, "post-init grants count normally")
    }

    // guards: a successful claim bumps the lifetime pour counter exactly once; a nil claim bumps nothing
    @Test func claimBumpsPourCounterOnce() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        #expect(store.nightlyPoursClaimed == 0)
        #expect(store.claimNightlyReward(now: day(1)) == nil, "short of the goal")
        #expect(store.nightlyPoursClaimed == 0, "nil claim never bumps")
        store.grantZombieBombIfNeeded()
        store.spendZombieBomb()
        playFourDone(store, on: day(1))
        #expect(store.claimNightlyReward(now: day(1)) != nil)
        #expect(store.nightlyPoursClaimed == 1)
        #expect(store.claimNightlyReward(now: day(1)) == nil, "already claimed tonight")
        #expect(store.nightlyPoursClaimed == 1, "a second nil claim still bumps nothing")
        // Next night: another pour advances the counter.
        store.grantZombieBombIfNeeded()
        store.spendZombieBomb()
        playFourDone(store, on: day(2))
        #expect(store.claimNightlyReward(now: day(2)) != nil)
        #expect(store.nightlyPoursClaimed == 2)
    }

    // guards: the pour counter survives a store relaunch (profile row, not UserDefaults)
    @Test func pourCounterSurvivesRelaunch() {
        do {
            let store1 = freshPersistentStore(url: storeURL)
            store1.grantZombieBombIfNeeded()
            store1.spendZombieBomb()
            playFourDone(store1, on: day(1))
            #expect(store1.claimNightlyReward(now: day(1)) != nil)
            #expect(store1.nightlyPoursClaimed == 1)
        }
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.nightlyPoursClaimed == 1, "counter rehydrates from the profile row")
    }
}

// MARK: - App Store rating ask (Nightly pour peak)

@Suite(.serialized)
@MainActor
final class RatingAskTests {
    private let snapshot = DefaultsSnapshot()
    private let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlayerStoreAdversarial-rating-\(UUID().uuidString).store")

    deinit {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
        snapshot.restore()
    }

    private func day(_ d: Int, hour: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: d, hour: hour))!
    }

    // guards: due-read truth table — pour threshold + 120-day cooldown (the 120th day itself is due)
    @Test func dueReadTruthTable() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = day(1)

        store.debugStageRating(pours: 2, askedDaysAgo: nil, now: t0)
        #expect(!store.isRatingAskDue(now: t0), "2 pours is short of the min")

        store.debugStageRating(pours: 3, askedDaysAgo: nil, now: t0)
        #expect(store.isRatingAskDue(now: t0), "3 pours, never asked → due")

        store.debugStageRating(pours: 3, askedDaysAgo: 60, now: t0)
        #expect(!store.isRatingAskDue(now: t0), "asked 60 days ago → still cooling")

        store.debugStageRating(pours: 3, askedDaysAgo: 120, now: t0)
        #expect(store.isRatingAskDue(now: t0), "exactly 120 days → due")

        store.debugStageRating(pours: 3, askedDaysAgo: 121, now: t0)
        #expect(store.isRatingAskDue(now: t0), "121 days → due")

        store.debugStageRating(pours: 10, askedDaysAgo: 119, now: t0)
        #expect(!store.isRatingAskDue(now: t0), "119 days → still cooling even with many pours")
    }

    // guards: markRatingAsk stamps now and flips the due-read false immediately
    @Test func markFlipsDueReadFalse() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = day(1)
        store.debugStageRating(pours: 5, askedDaysAgo: nil, now: t0)
        #expect(store.isRatingAskDue(now: t0))
        store.markRatingAsk(now: t0)
        #expect(!store.isRatingAskDue(now: t0), "just asked → not due again today")
        #expect(store.isRatingAskDue(now: day(1 + PlayerStore.ratingAskCooldownDays)),
                "exactly the cooldown later → due again")
    }

    // guards: constants stay the house contract — 3 pours, 120-day re-space
    @Test func ratingConstants() {
        #expect(PlayerStore.ratingAskMinPours == 3)
        #expect(PlayerStore.ratingAskCooldownDays == 120)
    }
}

// MARK: - DepthDial (pure value type, explicit clock)

struct DepthDialTests {
    private func approx(_ a: Double, _ b: Double, tol: Double = 1e-12) -> Bool {
        abs(a - b) <= tol
    }

    // guards: the 0.001 dead-band is exclusive — a delta of exactly 0.001 is ignored, 0.0011 registers
    @Test func epsilonDeadBandBoundary() {
        var dial = DepthDial()
        dial.set(0.001, at: 0)
        #expect(dial.target == 0, "delta == epsilon is inside the dead-band")
        dial.set(0.0011, at: 0)
        #expect(dial.target == 0.0011)
        #expect(dial.eased(at: 4) == 0.0011, "registered change eases to the new target")
    }

    // guards: eased equals previous at t == changedAt, exactly target at changedAt + duration and beyond, and a clock BEHIND changedAt clamps to previous (no NaN, no negative excursion)
    @Test func easedEndpointsAndClockBehind() {
        var dial = DepthDial()
        dial.set(1, at: 10)
        #expect(dial.eased(at: 10) == 0)
        #expect(dial.eased(at: 12) == 0.5, "smoothstep midpoint is exact in binary")
        #expect(dial.eased(at: 14) == 1, "t == changedAt + duration lands exactly on target")
        #expect(dial.eased(at: 100) == 1)
        let behind = dial.eased(at: 5)
        #expect(!behind.isNaN)
        #expect(behind == 0, "clock behind changedAt clamps to previous")
    }

    // guards: DISPROVES the suspected duration-0 NaN — min(1, max(0, 0/0)) picks
    // the 0 argument (comparison-order), so duration 0 degrades to an instant
    // snap: previous at t == changedAt, target for any t > changedAt.
    @Test func zeroDurationSnapsInsteadOfNaN() {
        var dial = DepthDial()
        dial.set(1, at: 10)
        let atChange = dial.eased(at: 10, duration: 0)
        #expect(!atChange.isNaN)
        #expect(atChange == 0, "0/0 clamps to x == 0 -> previous")
        let after = dial.eased(at: 10.001, duration: 0)
        #expect(after == 1, "+inf clamps to x == 1 -> target")
    }

    // guards: NaN input to set() is rejected by the epsilon guard (NaN comparison is false), so the dial never poisons
    @Test func nanSetIsRejected() {
        var dial = DepthDial()
        dial.set(.nan, at: 0)
        #expect(dial.target == 0)
        #expect(dial.eased(at: 5) == 0)
        #expect(!dial.eased(at: 5).isNaN)
    }

    // guards: a same-value set mid-flight is a no-op (trajectory unbroken) and a retarget snapshots previous = eased(now) so the curve is continuous
    @Test func retargetContinuityAndSameValueNoOp() {
        var dial = DepthDial()
        dial.set(1, at: 0)
        dial.set(1, at: 2)  // same value: must not restart the ease
        #expect(dial.eased(at: 2) == 0.5)
        #expect(dial.eased(at: 4) == 1, "original trajectory completes on time")

        var retargeted = DepthDial()
        retargeted.set(1, at: 0)
        retargeted.set(0.2, at: 2)  // mid-flight retarget
        #expect(retargeted.eased(at: 2) == 0.5, "no jump at the retarget instant")
        #expect(approx(retargeted.eased(at: 6), 0.2), "re-eases toward the new target over 4s")
    }

    // guards: PINS the dead-band accumulation contract — relative sub-epsilon increments compare against the stale target and never register, so callers must feed absolute values
    @Test func subEpsilonRelativeCreepNeverAccumulates() {
        var dial = DepthDial()
        for _ in 0..<2_000 {
            dial.set(dial.target + 0.0009, at: 0)
        }
        #expect(dial.target == 0, "2000 sub-epsilon nudges intend 1.8 but move nothing")
    }
}

// MARK: - Shared lives pool (Candy Crush shape)

@Suite(.serialized)
@MainActor
final class SharedLivesPoolTests {
    private let snapshot = DefaultsSnapshot()
    private let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("PlayerStoreAdversarial-lives-\(UUID().uuidString).store")

    deinit {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
        }
        snapshot.restore()
    }

    private var period: TimeInterval { PlayerStore.livesRefillPeriod }
    private var cap: Int { PlayerStore.livesCap }

    /// v2: lives only engage once a game has hooked the player (see
    /// `PlayerStore.livesActivationDepth`). These suites are about the POOL
    /// mechanics, not the gate, so they stage every shipping game past its
    /// threshold first. The gate itself is covered by LivesActivationTests.
    private func activateLives(_ store: PlayerStore) {
        store.record(for: .tikiStacks).bestScore =
            PlayerStore.livesActivationDepth(for: .tikiStacks)
        store.record(for: .zombie).bestBoardValue =
            PlayerStore.livesActivationDepth(for: .zombie)
        store.noteLuauLevelsCleared(PlayerStore.livesActivationDepth(for: .luau))
    }

    // guards: a fresh install starts at the full pool with no timer running
    @Test func freshInstallStartsFull() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let snap = store.livesSnapshot()
        #expect(snap.count == cap)
        #expect(snap.secondsToNext == nil, "full pool runs no timer")
    }

    // guards: one elapsed period grants exactly one life and carries the remainder into the next anchor
    @Test func singlePeriodRefillCarriesRemainder() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Two below cap, so the grant lands with the pool still below cap and
        // the remainder has somewhere to carry to.
        store.debugStageLives(count: cap - 2, refillAnchor: t0, now: t0)
        // One full period + 5 min remainder.
        let later = t0.addingTimeInterval(period + 5 * 60)
        let snap = store.livesSnapshot(now: later)
        #expect(snap.count == cap - 1)
        #expect(snap.secondsToNext == Int(period - 5 * 60))
    }

    // guards: multi-period elapsed grants all of them and clamps hard at the cap (timer clears)
    @Test func multiPeriodRefillClampsAtCap() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        store.debugStageLives(count: 3, refillAnchor: t0, now: t0)
        // Three periods would overshoot 5 — clamp and clear the timer.
        let later = t0.addingTimeInterval(period * 3 + 10)
        let snap = store.livesSnapshot(now: later)
        #expect(snap.count == cap)
        #expect(snap.secondsToNext == nil, "full pool clears the timer")
    }

    // guards: spend floors at zero and never goes negative
    @Test func spendFloorsAtZero() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        store.debugStageLives(count: 1, refillAnchor: t0, now: t0)
        #expect(store.spendLife(now: t0))
        #expect(store.lives == 0)
        #expect(!store.spendLife(now: t0))
        #expect(store.lives == 0)
    }

    // guards: spending from a full pool starts the refill timer at `now`
    @Test func spendFromFullStartsTimer() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(store.lives == cap)
        #expect(store.livesSecondsToNext == nil)
        #expect(store.spendLife(now: t0))
        let snap = store.livesSnapshot(now: t0)
        #expect(snap.count == cap - 1)
        #expect(snap.secondsToNext == Int(period))
    }

    // guards: spend mid-timer keeps the existing remainder (does not re-anchor)
    @Test func spendMidTimerKeepsRemainder() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Below cap so a period is already running — spending from a FULL
        // pool starts a fresh one, which is a different path.
        store.debugStageLives(count: cap - 1, refillAnchor: t0, now: t0)
        let mid = t0.addingTimeInterval(10 * 60) // 10 min into the period
        #expect(store.spendLife(now: mid))
        let snap = store.livesSnapshot(now: mid)
        #expect(snap.count == cap - 2)
        #expect(snap.secondsToNext == Int(period - 10 * 60),
                "remainder carries — spend must not restart the period")
    }

    // guards: a backwards clock re-anchors without minting or destroying lives
    @Test func backwardsClockReanchorsWithoutMintOrDestroy() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        store.debugStageLives(count: 2, refillAnchor: t0, now: t0)
        let earlier = t0.addingTimeInterval(-3_600)
        let snap = store.livesSnapshot(now: earlier)
        #expect(snap.count == 2, "backwards clock must never mint or destroy")
        #expect(snap.secondsToNext == Int(period), "re-anchor starts a fresh period at now")
    }

    // guards: staged count + anchor rehydrate across a store relaunch (temp-file URL pattern)
    @Test func livesStateSurvivesRelaunch() {
        // Anchor near wall-clock so init's materialize(now: .now) doesn't
        // drain years of pending refill before the test can assert.
        let t0 = Date()
        do {
            let store1 = freshPersistentStore(url: storeURL)
            store1.debugStageLives(count: cap - 2, refillAnchor: t0, now: t0)
            #expect(store1.lives == cap - 2)
        }
        let store2 = PlayerStore(url: storeURL)
        #expect(store2.lives == cap - 2, "count mirror rehydrates from the profile row")
        let later = t0.addingTimeInterval(period + 60)
        let snap = store2.livesSnapshot(now: later)
        #expect(snap.count == cap - 1, "pending refill rolls on after relaunch")
        #expect(snap.secondsToNext == Int(period - 60))
    }

    // guards: all six games spend on real defeat; tutorials leave the pool alone
    @Test func defeatOnlySpending() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        activateLives(store)
        store.debugStageLives(count: cap, refillAnchor: nil, now: t0)

        #expect(!store.spendLifeForDefeat(game: .tikiStacks, duringTutorial: true, now: t0),
                "tutorial defeats spend nothing")
        #expect(store.lives == cap)

        // Every shipping game draws on the one shared pool.
        var expected = cap
        for g in TikiGame.allCases where expected > 0 {
            #expect(store.spendLifeForDefeat(game: g, now: t0))
            expected -= 1
            #expect(store.lives == expected)
        }
        while store.lives > 0 { #expect(store.spendLife(now: t0)) }

        #expect(!store.spendLifeForDefeat(game: .luau, now: t0), "empty pool floors")
        // A "win" path never calls spendLifeForDefeat — pool unchanged if we skip it.
        #expect(store.lives == 0)
    }

    // guards: the 0-lives gate predicate is true for every game at empty pool
    @Test func zeroLivesGatePredicate() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        activateLives(store)
        store.debugStageLives(count: 0, refillAnchor: t0, now: t0)

        for g in TikiGame.allCases {
            #expect(store.isOutOfLives(for: g, now: t0), "\(g.rawValue) gates at zero")
        }

        store.debugStageLives(count: 1, refillAnchor: t0, now: t0)
        for g in TikiGame.allCases {
            #expect(!store.isOutOfLives(for: g, now: t0), "\(g.rawValue) opens with a life")
        }
    }

    // guards: first-spend education flag starts false and sticks once set (UserDefaults, tikiOnboardingSkipped shape)
    @Test func livesEducationFlagIsOneShot() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        #expect(!store.livesExplained)
        store.livesExplained = true
        #expect(store.livesExplained)
        // Fresh in-memory store still sees the shared UserDefaults flag.
        let store2 = PlayerStore(inMemory: true)
        #expect(store2.livesExplained, "education is install-global, not per container")
        store2.livesExplained = false
        #expect(!store.livesExplained)
    }

    // guards: countdown formatter is m:ss and never negative
    @Test func countdownFormatIsStable() {
        #expect(LivesHearts.formatCountdown(0) == "0:00")
        #expect(LivesHearts.formatCountdown(59) == "0:59")
        #expect(LivesHearts.formatCountdown(60) == "1:00")
        #expect(LivesHearts.formatCountdown(1_800) == "30:00")
        #expect(LivesHearts.formatCountdown(-12) == "0:00")
    }

    // guards: the spend EVENT counter bumps once per successful spend and never on refusals
    @Test func spendCountTracksOnlyRealSpends() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        activateLives(store)
        #expect(store.livesSpendCount == 0)
        #expect(store.spendLifeForDefeat(game: .tikiStacks, now: t0))
        #expect(store.livesSpendCount == 1)
        #expect(!store.spendLifeForDefeat(game: .zombie, duringTutorial: true, now: t0))
        #expect(store.livesSpendCount == 1, "tutorial refusals never bump the counter")
        store.debugStageLives(count: 0, refillAnchor: t0, now: t0)
        #expect(!store.spendLife(now: t0))
        #expect(store.livesSpendCount == 1, "an empty-pool refusal never bumps the counter")
    }

    // guards: at cap, secondsUntilFull is nil (no restock clock)
    @Test func secondsUntilFullIsNilAtCap() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(store.secondsUntilFull(now: t0) == nil)
        store.debugStageLives(count: cap, refillAnchor: nil, now: t0)
        #expect(store.secondsUntilFull(now: t0) == nil)
    }

    // guards: cap−1 mid-period equals secondsToNext (one life remaining)
    @Test func secondsUntilFullMatchesNextWhenOneMissing() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        store.debugStageLives(count: cap - 1, refillAnchor: t0, now: t0)
        let mid = t0.addingTimeInterval(10 * 60)
        let snap = store.livesSnapshot(now: mid)
        #expect(store.secondsUntilFull(now: mid) == snap.secondsToNext)
        #expect(store.secondsUntilFull(now: mid) == Int(period - 10 * 60))
    }

    // guards: 0 lives on a fresh anchor is one full period per missing life
    @Test func secondsUntilFullEmptyFreshAnchor() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        store.debugStageLives(count: 0, refillAnchor: t0, now: t0)
        #expect(store.secondsUntilFull(now: t0) == cap * Int(period))
    }

    // guards: 0 lives partway into a period is the remainder plus a full period per remaining life
    @Test func secondsUntilFullEmptyMidPeriod() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        store.debugStageLives(count: 0, refillAnchor: t0, now: t0)
        let mid = t0.addingTimeInterval(10 * 60)
        // Remainder on the current period + a full period for each life after it.
        #expect(store.secondsUntilFull(now: mid)
                == Int(period) - 10 * 60 + (cap - 1) * Int(period))
    }

    // guards: below-cap with no anchor re-anchors to now (legacy) then counts full remaining periods
    @Test func secondsUntilFullLegacyNoAnchor() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // writeLives with nil anchor only when full — stage via profile through
        // debugStage then force a mid-count with a nil-equivalent by re-staging
        // at count 2 with anchor nil is coerced by debugStage to keep nil only at
        // cap. Simulate legacy by staging count 2 at t0 (has anchor), then
        // reading after resolve of a raw no-anchor path via spend-to-empty
        // and debugStage with anchor at t0. Cleaner: stage count 2, anchor t0
        // so resolve is stable — legacy path is resolve re-anchor; stage with
        // anchor = t0 is the post-resolve shape. Use write path: stage full,
        // spend thrice at t0 → count 2 with anchor t0 (= fresh for those two).
        store.debugStageLives(count: cap - 1, refillAnchor: nil, now: t0)
        // debugStage with nil anchor below cap writes nil; resolve re-anchors
        // to `now` on pure read → secondsUntilFull = one period per missing life.
        #expect(store.secondsUntilFull(now: t0) == Int(period),
                "missing anchor re-anchors to now; one life to fill")
    }
}

// MARK: - Onboarding skip scope

/// REGRESSION(global-skip): SKIP was one bundle-global UserDefaults flag, so
/// one tap in any game silenced the first-run coach in EVERY game. Luau leads
/// the rail, so a new player who skipped it was never taught Totem or Top
/// Shelf — caught by Carson watching a new device open Top Shelf to no
/// tutorial. Now keyed per game.
@MainActor
final class OnboardingSkipScopeTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    // guards: THE regression — skipping one game never silences another
    @Test func skipIsScopedToOneGame() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        store.setOnboardingSkipped(true, for: .luau)

        #expect(store.onboardingSkipped(for: .luau))
        for other in TikiGame.allCases where other != .luau {
            #expect(!store.onboardingSkipped(for: other),
                    "skipping Luau must not silence \(other.rawValue)")
        }
    }

    // guards: a fresh install is skipped nowhere — every game teaches itself
    @Test func freshInstallSkipsNothing() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        for g in TikiGame.allCases {
            #expect(!store.onboardingSkipped(for: g))
        }
    }

    // guards: the legacy bundle-global key LAPSES rather than migrating
    // (Carson's call) — an install carrying it gets its lessons back
    @Test func legacyGlobalFlagDoesNotSuppressAnyGame() {
        DefaultsSnapshot.wipeAll()
        UserDefaults.standard.set(true, forKey: "tikiOnboardingSkipped")
        let store = PlayerStore(inMemory: true)
        for g in TikiGame.allCases {
            #expect(!store.onboardingSkipped(for: g),
                    "the retired global key must not gate \(g.rawValue)")
        }
    }

    // guards: keys are distinct per game (a shared key would silently
    // re-create the bug)
    @Test func skipKeysAreDistinctPerGame() {
        let keys = TikiGame.allCases.map(PlayerStore.onboardingSkipKey)
        #expect(Set(keys).count == keys.count)
        #expect(!keys.contains("tikiOnboardingSkipped"),
                "must not collide with the retired global key")
    }
}

// MARK: - Lives activation gate (v2)

/// Lives are a conversion lever, so a game plays FREE until it has hooked
/// the player. These pin the gate itself: the thresholds, that a fresh
/// install is charged nothing, that the gate is per-game off a shared pool,
/// and that it can never walk backwards.
@MainActor
final class LivesActivationTests {
    private let snapshot = DefaultsSnapshot()
    deinit { snapshot.restore() }

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

    // guards: THE product decision — a brand-new player is charged nothing, anywhere
    @Test func freshInstallIsChargedNothing() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        for g in TikiGame.allCases {
            #expect(!store.livesActive(for: g), "\(g.rawValue) must start free")
            #expect(!store.spendLifeForDefeat(game: g, now: t0),
                    "\(g.rawValue) must not take a life from a new player")
        }
        #expect(store.lives == PlayerStore.livesCap, "pool untouched")
        #expect(!store.livesActiveAnywhere, "the chip stays hidden")
    }

    // guards: a new player at zero lives is never gated out of a game that has not activated
    @Test func inactiveGameNeverGatesEvenAtZeroLives() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        store.debugStageLives(count: 0, refillAnchor: t0, now: t0)
        for g in TikiGame.allCases {
            #expect(!store.isOutOfLives(for: g, now: t0),
                    "\(g.rawValue) has not hooked the player — it must stay playable")
        }
    }

    // guards: each game's threshold, exactly — one short is still free, landing on it charges
    @Test func thresholdsEngageExactlyAtDepth() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)

        let totem = PlayerStore.livesActivationDepth(for: .tikiStacks)
        store.record(for: .tikiStacks).bestScore = totem - 1
        #expect(!store.livesActive(for: .tikiStacks), "one short is still free")
        store.record(for: .tikiStacks).bestScore = totem
        #expect(store.livesActive(for: .tikiStacks))

        let shelf = PlayerStore.livesActivationDepth(for: .zombie)
        store.record(for: .zombie).bestBoardValue = shelf / 2
        #expect(!store.livesActive(for: .zombie), "a 32 board is still free")
        store.record(for: .zombie).bestBoardValue = shelf
        #expect(store.livesActive(for: .zombie))

        let nights = PlayerStore.livesActivationDepth(for: .luau)
        store.noteLuauLevelsCleared(nights - 1)
        #expect(!store.livesActive(for: .luau), "night nine is still free")
        store.noteLuauLevelsCleared(nights)
        #expect(store.livesActive(for: .luau))
    }

    // guards: the gate is PER GAME off one shared pool — being hooked on Luau
    // must not start charging a player who just opened Totem
    @Test func activationIsPerGameNotGlobal() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        store.noteLuauLevelsCleared(PlayerStore.livesActivationDepth(for: .luau))

        #expect(store.livesActive(for: .luau))
        #expect(!store.livesActive(for: .tikiStacks))
        #expect(!store.livesActive(for: .zombie))

        // Luau takes from the shared pool; Totem still takes nothing.
        let before = store.lives
        #expect(store.spendLifeForDefeat(game: .luau, now: t0))
        #expect(store.lives == before - 1)
        #expect(!store.spendLifeForDefeat(game: .tikiStacks, now: t0))
        #expect(store.lives == before - 1, "an inactive game never touches the pool")
    }

    // guards: at zero lives the player can ALWAYS still play something —
    // the whole point of holding the gate off until a game has caught them
    @Test func zeroLivesStillLeavesAnInactiveGamePlayable() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        store.noteLuauLevelsCleared(PlayerStore.livesActivationDepth(for: .luau))
        store.debugStageLives(count: 0, refillAnchor: t0, now: t0)

        #expect(store.isOutOfLives(for: .luau, now: t0), "the hooked game gates")
        #expect(!store.isOutOfLives(for: .tikiStacks, now: t0))
        #expect(!store.isOutOfLives(for: .zombie, now: t0))
    }

    // guards: activation never regresses — every backing signal is best-ever
    // or monotonic, so a bad run cannot switch lives back off
    @Test func activationNeverWalksBackwards() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        let nights = PlayerStore.livesActivationDepth(for: .luau)

        store.noteLuauLevelsCleared(nights)
        #expect(store.livesActive(for: .luau))
        // Abandoning the campaign reports a lower count — it must not stick.
        #expect(!store.noteLuauLevelsCleared(nights - 5), "lower counts are refused")
        #expect(store.luauLevelsCleared == nights)
        #expect(store.livesActive(for: .luau))
    }

    // guards: the chip appears the moment ANY game starts charging
    @Test func chipAppearsWithFirstActivation() {
        DefaultsSnapshot.wipeAll()
        let store = PlayerStore(inMemory: true)
        #expect(!store.livesActiveAnywhere)
        store.record(for: .zombie).bestBoardValue =
            PlayerStore.livesActivationDepth(for: .zombie)
        #expect(store.livesActiveAnywhere)
    }
}

// MARK: - Lives restock local notification (pure plan + apply)

/// Recording center for unit tests — no UserNotifications framework traffic.
@MainActor
private final class RecordingNotifyCenter: LivesRestockNotifier.Center {
    var status: UNAuthorizationStatus = .authorized
    var grantOnRequest = true
    var scheduled: [(id: String, seconds: TimeInterval, title: String, body: String)] = []
    var cancelled: [String] = []
    var removedDelivered: [String] = []

    var authorizationRequests = 0

    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization() async -> Bool {
        authorizationRequests += 1
        return grantOnRequest
    }
    func schedule(id: String, afterSeconds: TimeInterval, title: String, body: String) {
        scheduled.append((id, afterSeconds, title, body))
    }
    func cancelPending(id: String) { cancelled.append(id) }
    func removeDelivered(id: String) { removedDelivered.append(id) }
}

@Suite(.serialized)
@MainActor
final class LivesRestockNotifyTests {
    // guards: pure plan schedules at exactly the given interval when below cap
    @Test func planSchedulesWhenBelowCap() {
        #expect(LivesRestockNotify.plan(secondsUntilFull: 1_800) == .schedule(seconds: 1_800))
        #expect(LivesRestockNotify.plan(secondsUntilFull: 1) == .schedule(seconds: 1))
    }

    // guards: pure plan cancels at cap, nil, or non-positive intervals
    @Test func planCancelsWhenFullOrInvalid() {
        #expect(LivesRestockNotify.plan(secondsUntilFull: nil) == .cancel)
        #expect(LivesRestockNotify.plan(secondsUntilFull: 0) == .cancel)
        #expect(LivesRestockNotify.plan(secondsUntilFull: -5) == .cancel)
    }

    // guards: apply(schedule) posts once under the fixed id with house title/body
    @Test func applySchedulePostsOnce() {
        let center = RecordingNotifyCenter()
        let notifier = LivesRestockNotifier(center: center)
        notifier.apply(.schedule(seconds: 90))
        #expect(center.scheduled.count == 1)
        #expect(center.scheduled[0].id == LivesRestockNotify.identifier)
        #expect(center.scheduled[0].seconds == 90)
        #expect(center.scheduled[0].title == LivesRestockNotify.title)
        #expect(center.scheduled[0].body == LivesRestockNotify.body)
        #expect(center.cancelled.isEmpty)
    }

    // guards: a second schedule replaces under the same id (center sees two adds; never a different id)
    @Test func rescheduleReusesFixedIdentifier() {
        let center = RecordingNotifyCenter()
        let notifier = LivesRestockNotifier(center: center)
        notifier.apply(.schedule(seconds: 60))
        notifier.apply(.schedule(seconds: 120))
        #expect(center.scheduled.map(\.id) == [
            LivesRestockNotify.identifier, LivesRestockNotify.identifier
        ])
        #expect(center.scheduled.map(\.seconds) == [60, 120])
    }

    // guards: apply(cancel) cancels pending under the fixed id
    @Test func applyCancelDropsPending() {
        let center = RecordingNotifyCenter()
        let notifier = LivesRestockNotifier(center: center)
        notifier.apply(.cancel)
        #expect(center.cancelled == [LivesRestockNotify.identifier])
        #expect(center.scheduled.isEmpty)
    }

    // guards: syncOnBackground schedules when authorized + below cap; cancels when full
    @Test func backgroundSyncHonorsAuthAndCap() async {
        let center = RecordingNotifyCenter()
        center.status = .authorized
        let notifier = LivesRestockNotifier(center: center)
        await notifier.syncOnBackground(secondsUntilFull: 600)
        #expect(center.scheduled.count == 1)
        #expect(center.scheduled[0].seconds == 600)

        center.scheduled.removeAll()
        center.cancelled.removeAll()
        await notifier.syncOnBackground(secondsUntilFull: nil)
        #expect(center.scheduled.isEmpty)
        #expect(center.cancelled == [LivesRestockNotify.identifier])
    }

    // guards: syncOnBackground with denied auth cancels and never schedules
    @Test func backgroundSyncDeniedNeverSchedules() async {
        let center = RecordingNotifyCenter()
        center.status = .denied
        let notifier = LivesRestockNotifier(center: center)
        await notifier.syncOnBackground(secondsUntilFull: 900)
        #expect(center.scheduled.isEmpty)
        #expect(center.cancelled == [LivesRestockNotify.identifier])
    }

    // guards: syncOnActive clears both pending and delivered under the fixed id
    @Test func activeSyncClearsPendingAndDelivered() {
        let center = RecordingNotifyCenter()
        let notifier = LivesRestockNotifier(center: center)
        notifier.syncOnActive()
        #expect(center.cancelled == [LivesRestockNotify.identifier])
        #expect(center.removedDelivered == [LivesRestockNotify.identifier])
    }

    // MARK: defeat-time authorization prompt

    // guards: the ask fires only on the defeat that emptied the pool
    @Test func offerPromptOnlyWhenTheLastLifeGoes() {
        for lives in 1...PlayerStore.livesCap {
            #expect(!LivesRestockNotify.shouldOfferAuthorization(
                lives: lives, status: .notDetermined, duringTutorial: false),
                "\(lives) lives left is not a lock-out")
        }
        #expect(LivesRestockNotify.shouldOfferAuthorization(
            lives: 0, status: .notDetermined, duringTutorial: false))
    }

    // guards: a settled status never re-asks — iOS spends the dialog once
    @Test func offerPromptNeverReAsksOnceDecided() {
        for status: UNAuthorizationStatus in [.authorized, .denied, .provisional, .ephemeral] {
            #expect(!LivesRestockNotify.shouldOfferAuthorization(
                lives: 0, status: status, duringTutorial: false),
                "\(status.rawValue) is already decided")
        }
    }

    // guards: tutorial defeats cost nothing, so they never spend the prompt
    @Test func offerPromptSkipsTutorialDefeats() {
        #expect(!LivesRestockNotify.shouldOfferAuthorization(
            lives: 0, status: .notDetermined, duringTutorial: true))
    }

    // guards: the empty-pool defeat actually reaches the system prompt
    @Test func defeatAtZeroRequestsAuthorization() async {
        let center = RecordingNotifyCenter()
        center.status = .notDetermined
        let notifier = LivesRestockNotifier(center: center)
        await notifier.offerAuthorizationAfterDefeat(
            lives: 0, duringTutorial: false, delay: 0)
        #expect(center.authorizationRequests == 1)
    }

    // guards: a defeat with lives to spare, a decided status, and a tutorial
    // defeat all stay silent through the real entry point
    @Test func defeatOtherwiseNeverPrompts() async {
        let center = RecordingNotifyCenter()
        center.status = .notDetermined
        let notifier = LivesRestockNotifier(center: center)
        await notifier.offerAuthorizationAfterDefeat(
            lives: 2, duringTutorial: false, delay: 0)
        await notifier.offerAuthorizationAfterDefeat(
            lives: 0, duringTutorial: true, delay: 0)
        center.status = .denied
        await notifier.offerAuthorizationAfterDefeat(
            lives: 0, duringTutorial: false, delay: 0)
        #expect(center.authorizationRequests == 0)
    }

    // guards: the prompt beat is the designed 2s
    @Test func promptDelayIsTwoSeconds() {
        #expect(LivesRestockNotify.authorizationPromptDelay == 2)
    }
}
