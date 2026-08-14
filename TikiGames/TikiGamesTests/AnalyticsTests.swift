import Testing
@testable import Tiki_Lounge

/// The analytics layer had zero coverage in a 591-test suite. These tests
/// cover the parts where a silent failure destroys data rather than crashing:
/// the progression labels that keep event ids bounded, and the dimension
/// values that GA validates against a registered vocabulary.
///
/// Breaching GA's daily unique-identifier ceiling does NOT drop events — it
/// sets the event id to `null`, which quietly corrupts every metric derived
/// from it. A regression here is invisible until the dashboard is wrong.
@MainActor
@Suite("Analytics labels stay bounded")
struct AnalyticsLabelTests {

    @Test("Cipher phrase labels wrap at the catalog size")
    func phraseWraps() {
        #expect(Analytics.phrase(0) == "phrase_000")
        #expect(Analytics.phrase(299) == "phrase_299")
        // `phraseIndex` grows without limit — only the DISPLAY wraps in
        // CipherGame. Without the modulo this mints a new id forever.
        #expect(Analytics.phrase(300) == "phrase_000")
        #expect(Analytics.phrase(1_234) == Analytics.phrase(1_234 % 300))
    }

    @Test("Cipher labels can never exceed the catalog's cardinality")
    func phraseCardinalityIsBounded() {
        // The save-state guard admits indices up to 1,000,000.
        let ids = Set((0..<5_000).map { Analytics.phrase($0) })
        #expect(ids.count == 300)
    }

    @Test("Navigator passages band above the cap")
    func passageBands() {
        #expect(Analytics.passage(0) == "passage_000")
        #expect(Analytics.passage(49) == "passage_049")
        #expect(Analytics.passage(50) == "passage_050plus")
        // `totalPassages` accumulates across loops of the level list.
        #expect(Analytics.passage(9_999) == "passage_050plus")
    }

    @Test("Navigator labels are bounded regardless of depth")
    func passageCardinalityIsBounded() {
        let ids = Set((0..<10_000).map { Analytics.passage($0) })
        #expect(ids.count == 51)
    }

    @Test("Night and sketch labels are zero-padded and stable")
    func fixedWidthLabels() {
        #expect(Analytics.night(1) == "night_001")
        #expect(Analytics.night(200) == "night_200")
        #expect(Analytics.sketch(1) == "sketch_01")
        #expect(Analytics.sketch(30) == "sketch_30")
    }

    @Test("Every label fits GA's 32-character segment limit")
    func segmentsFitTheSDKLimit() {
        var labels: [String] = []
        labels += (0..<300).map { Analytics.phrase($0) }
        labels += (0..<60).map { Analytics.passage($0) }
        labels += (1...200).map { Analytics.night($0) }
        labels += (1...60).map { Analytics.sketch($0) }
        labels += TikiGame.allCases.map(\.progressionID)
        for label in labels {
            #expect(label.count <= 32, "segment too long: \(label)")
            #expect(!label.contains(":"), "segment cannot contain ':' — \(label)")
        }
    }

    @Test("Progression IDs are distinct across the six games")
    func progressionIDsAreDistinct() {
        let ids = TikiGame.allCases.map(\.progressionID)
        #expect(Set(ids).count == TikiGame.allCases.count)
    }
}

@MainActor
@Suite("Analytics dimensions match their registered vocabulary")
struct AnalyticsDimensionTests {

    /// GA rejects any dimension value not registered before `initialize`.
    /// A value the store can produce but the SDK never declared is silently
    /// dropped, so these two sets must agree.
    private static let breadthVocabulary = Set((1...6).map { "games_\($0)" })
    private static let livesVocabulary: Set<String> = [
        "lives_healthy", "lives_pinched", "lives_zeroed",
    ]

    @Test("Breadth floors at one game and never exceeds the bundle")
    func breadthIsInVocabulary() {
        let store = PlayerStore(inMemory: true)
        // A brand-new player has played nothing.
        #expect(Self.breadthVocabulary.contains(store.analyticsBreadth))
        #expect(store.analyticsBreadth == "games_1")
    }

    @Test("Breadth tracks distinct games actually played")
    func breadthCountsDistinctGames() {
        let store = PlayerStore(inMemory: true)
        store.recordRun(game: .luau, score: 10)
        #expect(store.analyticsBreadth == "games_1")
        store.recordRun(game: .zombie, score: 10)
        #expect(store.analyticsBreadth == "games_2")
        // Replaying a game already counted must not inflate breadth.
        store.recordRun(game: .luau, score: 20)
        #expect(store.analyticsBreadth == "games_2")
    }

    @Test("Lives tier covers every pool level and stays in vocabulary")
    func livesTierIsInVocabulary() {
        let store = PlayerStore(inMemory: true)
        #expect(Self.livesVocabulary.contains(store.analyticsLivesTier))
        // A full pool is healthy; the wall is what D-4 splits on.
        #expect(store.analyticsLivesTier == "lives_healthy")
    }

    @Test("Emptying the pool moves the tier — the D-4 split depends on it")
    func livesTierTracksTheWall() {
        let store = PlayerStore(inMemory: true)
        for _ in 0..<(PlayerStore.livesCap - 2) { _ = store.spendLife() }
        #expect(store.analyticsLivesTier == "lives_pinched")
        while store.lives > 0 { _ = store.spendLife() }
        #expect(store.analyticsLivesTier == "lives_zeroed")
    }

    @Test("First game is write-once and nil until a real choice is made")
    func firstGameIsWriteOnce() {
        let store = PlayerStore(inMemory: true)
        // Nil by default: the cold-launch route deliberately does NOT stamp
        // it, because `resumeTarget` hands every fresh install Luau and that
        // would tag ~100% of players `first_luau`.
        #expect(store.analyticsEntry == nil)

        store.noteFirstGame(.navigator)
        #expect(store.analyticsEntry == "first_navigator")

        // A later choice must never overwrite the first.
        store.noteFirstGame(.luau)
        #expect(store.analyticsEntry == "first_navigator")
    }

    @Test("Every game produces an entry value the SDK declared")
    func entryValuesAreInVocabulary() {
        let declared = Set(TikiGame.allCases.map { "first_\($0.rawValue)" })
        for game in TikiGame.allCases {
            let store = PlayerStore(inMemory: true)
            store.noteFirstGame(game)
            #expect(declared.contains(store.analyticsEntry ?? ""))
        }
    }
}
