import Foundation
import Testing
@testable import Tiki_Lounge

// TESTFLIGHT ONLY — REMOVE BEFORE APP STORE SUBMISSION, along with
// PlayerStore.refillLivesToCap and the OUT OF LIVES sheet's ad button action.
@MainActor
struct LivesRefillTests {

    @Test func refillFillsThePoolAndClearsTheCountdown() {
        let store = PlayerStore(inMemory: true)
        while store.spendLife() {}
        #expect(store.lives == 0)
        store.refillLivesToCap()
        #expect(store.lives == PlayerStore.livesCap)
        #expect(store.livesSnapshot().secondsToNext == nil)
    }

    @Test func refillNeverExceedsTheCap() {
        let store = PlayerStore(inMemory: true)
        for _ in 0..<3 { store.refillLivesToCap() }
        #expect(store.lives == PlayerStore.livesCap)
    }
}
