import Testing
import Foundation
@testable import Tiki_Lounge

// Adversarial tests for CipherGame (Cabana Cipher hangman engine).
//
// CipherGame is a plain @Observable final class with no actor isolation, no
// storage, no time, and no unseeded randomness — every test below drives a
// fresh instance synchronously. @MainActor is applied to suites defensively
// (harmless today, keeps compiling if the app ever adopts MainActor default
// isolation). No UserDefaults/SwiftData/singleton state is touched anywhere.
//
// HANGMAN PIVOT (2026-07-31): guess() is target-free — a plain letter that
// appears in the phrase locks every tile it owns; a letter absent from the
// phrase is a mistake AND enters `misses` (struck out on the keyboard, then
// inert). The cursor (`selected`), firstUnsolved, and seedTutorialReveal are
// gone. The catalog is 50 books x 6 = 300 famous sayings with a parallel
// 10-category table. Golden pins below were re-derived for the new catalog
// with an independent LCG replica and one board hand-decoded as a check.
//
// Tests marked REGRESSION pin fixes for real bugs found by earlier sweeps
// (2026-07-17): hostile-save traps/inflation in restore() and the
// negative-index matchbook seam. They must stay.
//
// HOUSE POUR: every board with no locked letters opens with its
// most-connected letter revealed free. Expectations reference
// houseSeed(index:) wherever a board's initial state matters.

// MARK: - Shared helpers

/// Encodes a SavePayload exactly the way the app persists it. Defaults to a
/// HANGMAN-ERA save (misses key present but empty) — pass `misses: nil`
/// explicitly to simulate a pre-hangman save, which restore() treats as a
/// migration and whose counters it drops.
private func saveJSON(
    index: Int,
    solvedCount: Int = 0,
    assignments: [String: String] = [:],
    mistakes: Int = 0,
    hints: Int = 0,
    seenHowTo: Bool = false,
    lastFreeHintDay: String? = nil,
    misses: [String]? = []
) -> String {
    let payload = CipherGame.SavePayload(
        seenHowTo: seenHowTo,
        phraseIndex: index,
        solvedCount: solvedCount,
        assignments: assignments,
        mistakes: mistakes,
        hints: hints,
        lastFreeHintDay: lastFreeHintDay,
        misses: misses
    )
    let data = try! JSONEncoder().encode(payload)
    return String(data: data, encoding: .utf8)!
}

private func decodePayload(_ json: String) throws -> CipherGame.SavePayload {
    try JSONDecoder().decode(CipherGame.SavePayload.self, from: Data(json.utf8))
}

/// The house pour a fresh board serves at `index` — read off a probe
/// instance, so expectations track the engine's own deterministic choice.
private func houseSeed(index: Int) -> [Character: Character] {
    let probe = CipherGame()
    probe.begin(index: index)
    return probe.solvedLetters
}

extension CipherGame {
    /// Unique cipher letters in board (phrase) order.
    fileprivate var boardOrder: [Character] {
        var seen = Set<Character>()
        var out: [Character] = []
        for ch in cipherText where ch != " " {
            if seen.insert(ch).inserted { out.append(ch) }
        }
        return out
    }

    /// Occurrence counts of unsolved cipher letters (mirrors the engine's rule
    /// via an explicitly ordered computation — no Dictionary-order dependence).
    fileprivate var unsolvedCounts: [Character: Int] {
        var counts: [Character: Int] = [:]
        for ch in cipherText where ch != " " && solvedLetters[ch] == nil {
            counts[ch, default: 0] += 1
        }
        return counts
    }

    fileprivate func solveByGuessing() {
        for c in boardOrder where solvedLetters[c] == nil {
            guess(reverse[c]!)
        }
    }

    fileprivate func solveByFreeHints(maxRounds: Int = 40) {
        var rounds = 0
        while !isComplete && rounds < maxRounds {
            hint(charged: false)
            rounds += 1
        }
    }

    /// A plain A–Z letter absent from the phrase and not yet struck — the
    /// hangman "wrong guess". Phrases never use all 26 letters, and the cap
    /// (5) is far below the absent count on any real phrase.
    fileprivate func missingPlain() -> Character {
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ".first {
            !phrase.contains($0) && !misses.contains($0)
        }!
    }
}

/// begin(0)'s exact board. The header comment in CipherGame.swift promises a
/// SwiftData-restored run re-derives the same board, so this string is a
/// shipped compatibility contract: any drift in the LCG constants, alphabet
/// order, shuffle direction, or the twin-repair pass silently corrupts every
/// in-flight save. Derived independently (python replica incl. repair) and
/// hand-decoded: THE→XUN, EARLY→NQTWO, BIRD→ZCTH.
private let goldenCipher0 = "XUN NQTWO ZCTH MNXA XUN KITE"
private let goldenCipher42 = "WFIQDPM SWA WFIQDPM SIYYWM" // ANOTHER DAY ANOTHER DOLLAR
/// Same plaintext as phrase 0, different board — pins that buildMapping seeds
/// from the RAW index across the 300-phrase wrap, not the wrapped one.
private let goldenCipher300 = "KMF FGUIP SZUA QFKC KMF XNUO"

// MARK: - Mapping & determinism

@MainActor
@Suite("Cipher mapping & determinism")
struct CipherMappingTests {

    // guards: 26-letter bijection, space structure, and no-fixed-point re-roll contract across two full catalog wraps
    @Test func mappingBijectionAndBoardStructureSweep() {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var violations: [String] = []
        for n in 0..<600 {
            let game = CipherGame()
            game.begin(index: n)
            if game.mapping.count != 26 { violations.append("[\(n)] mapping.count \(game.mapping.count)") }
            if game.reverse.count != 26 { violations.append("[\(n)] reverse.count \(game.reverse.count)") }
            for c in alphabet where game.mapping[c].flatMap({ game.reverse[$0] }) != c {
                violations.append("[\(n)] round-trip broken at \(c)")
            }
            let plain = Array(game.phrase)
            let cipher = Array(game.cipherText)
            if plain.count != cipher.count {
                violations.append("[\(n)] length \(cipher.count) != \(plain.count)")
                continue
            }
            for i in plain.indices {
                if (plain[i] == " ") != (cipher[i] == " ") { violations.append("[\(n)] space mismatch @\(i)") }
                if plain[i] != " " && plain[i] == cipher[i] { violations.append("[\(n)] fixed point \(plain[i])") }
            }
        }
        #expect(violations.isEmpty, "\(violations.joined(separator: "; "))")
    }

    // guards: same index ⇒ identical board across instances (SwiftData restore re-derivation contract)
    @Test(arguments: [0, 42, 299, 300, 599])
    func deterministicAcrossInstances(index: Int) {
        let a = CipherGame()
        let b = CipherGame()
        a.begin(index: index)
        b.begin(index: index)
        #expect(a.mapping == b.mapping)
        #expect(a.cipherText == b.cipherText)
    }

    // guards: cross-process/cross-version board stability — a silent LCG/shuffle change would corrupt every in-flight save; the index-300 pin also catches seeding from the wrapped index instead of the raw one
    @Test func goldenCipherTextPins() {
        let game = CipherGame()
        game.begin(index: 0)
        #expect(game.cipherText == goldenCipher0)
        game.begin(index: 42)
        #expect(game.cipherText == goldenCipher42)
        game.begin(index: 300)
        #expect(game.cipherText == goldenCipher300)
    }

    // guards: catalog shape the engine assumes — 50 books x 6 = 300, A-Z+space only (non-A-Z chars would leak plaintext via `mapping[$0] ?? $0`), >= 2 unique letters (the house pour must never complete a board on its own), <= 46 chars (tile layout), no duplicates, and the 10x30 category table stays parallel
    @Test func phraseCatalogShape() {
        #expect(CipherGame.matchbooks.count == 50)
        #expect(CipherGame.phrases.count == 300)
        #expect(CipherGame.categories.count == CipherGame.phrases.count)
        var violations: [String] = []
        for book in CipherGame.matchbooks {
            if book.phrases.count != 6 { violations.append("\(book.id): \(book.phrases.count) phrases") }
            for phrase in book.phrases {
                if phrase.contains(where: { $0 != " " && !("A"..."Z").contains($0) }) {
                    violations.append("\(book.id): non-A-Z char in \(phrase)")
                }
                if Set(phrase.filter { $0 != " " }).count < 2 {
                    violations.append("\(book.id): single-letter phrase \(phrase)")
                }
                if phrase.count > 46 {
                    violations.append("\(book.id): \(phrase.count) chars in \(phrase)")
                }
            }
        }
        if Set(CipherGame.phrases).count != CipherGame.phrases.count {
            violations.append("duplicate phrases in catalog")
        }
        var perCategory: [CipherGame.CipherCategory: Int] = [:]
        for c in CipherGame.categories { perCategory[c, default: 0] += 1 }
        if perCategory.count != 10 || perCategory.values.contains(where: { $0 != 30 }) {
            violations.append("category balance broken: \(perCategory)")
        }
        #expect(violations.isEmpty, "\(violations.joined(separator: "; "))")
    }

    // guards: the tutorial board contract — phrase 0 is the FTUE board, so its
    // identity (and the THE-heavy shape the coach copy leans on) is pinned
    @Test func tutorialPhrasePinned() {
        #expect(CipherGame.phrases[0] == "THE EARLY BIRD GETS THE WORM")
        #expect(CipherGame.phrases[0].filter { $0 == "T" }.count == 3)
        #expect(CipherGame.categories[0] == .oldWisdom)
    }

    // guards: the twin-repair pass — a board never shows both members of a
    // filled/hollow symbol pair (● vs ○ …) unless the phrase has 17+ distinct
    // letters, where one collision is pigeonhole-unavoidable (10 pairs + 6
    // singletons = 16 twin-free seats); even then exactly one pair remains.
    // Measured over two catalog wraps: 592/600 boards at zero, 8 at one.
    @Test func confusableTwinPairsRepairedToFloor() {
        var violations: [String] = []
        for n in 0..<600 {
            let game = CipherGame()
            game.begin(index: n)
            let used = Set(game.phrase.filter { $0 != " " }.compactMap { game.mapping[$0] })
            let pairs = CipherGame.confusableCipherPairs.filter {
                used.contains($0.0) && used.contains($0.1)
            }.count
            let distinct = Set(game.phrase.filter { $0 != " " }).count
            if distinct <= 16 && pairs != 0 {
                violations.append("[\(n)] \(pairs) pairs at \(distinct) distinct")
            }
            if pairs > 1 { violations.append("[\(n)] \(pairs) pairs — above the floor") }
        }
        #expect(violations.isEmpty, "\(violations.joined(separator: "; "))")
    }
}

// MARK: - Guess mechanics (hangman)

@MainActor
@Suite("Cipher guess mechanics")
struct CipherGuessTests {

    // guards: a correct guess locks EVERY tile of that letter at once (target-free), bumps lockBeat exactly once (house pour already spent beat 1), and leaves mistakes/misses alone
    @Test func hitFillsEveryPosition() {
        let game = CipherGame()
        game.begin(index: 0)
        // A plain letter with multiple occurrences that the pour didn't take.
        let plain = "THE EARLY BIRD GETS THE WORM"
            .filter { $0 != " " && !game.usedPlainLetters.contains($0) }
            .first { p in game.phrase.filter { $0 == p }.count >= 2 }!
        let cipher = game.mapping[plain]!
        let occurrences = game.cipherText.filter { $0 == cipher }.count
        #expect(occurrences >= 2)
        #expect(game.guess(plain))
        #expect(game.solvedLetters[cipher] == plain) // one entry fills all tiles
        #expect(game.lockBeat == 2)
        #expect(game.mistakes == 0)
        #expect(game.misses.isEmpty)
    }

    // guards: a miss counts exactly one mistake + one mistakeBeat, enters `misses`, and locks nothing beyond the house pour
    @Test func missCountsAndStrikesOut() {
        let game = CipherGame()
        game.begin(index: 0)
        let before = game.solvedLetters
        let wrong = game.missingPlain()
        #expect(!game.guess(wrong))
        #expect(game.mistakes == 1)
        #expect(game.mistakeBeat == 1)
        #expect(game.misses == [wrong])
        #expect(game.solvedLetters == before)
    }

    // guards: guard ordering — re-guessing a solved letter, re-guessing a struck letter, and post-completion guesses are all inert (no mistake, no beat, no misses growth)
    @Test func repeatAndPostCompletionGuessesAreInert() {
        let game = CipherGame()
        game.begin(index: 0)

        // (a) re-guess the poured letter — already solved, free
        let poured = game.solvedLetters.values.first!
        #expect(!game.guess(poured))
        #expect(game.mistakes == 0)

        // (b) a miss strikes out; the SAME letter again is inert
        let wrong = game.missingPlain()
        #expect(!game.guess(wrong))
        #expect(game.mistakes == 1)
        #expect(!game.guess(wrong))
        #expect(game.mistakes == 1)
        #expect(game.mistakeBeat == 1)
        #expect(game.misses.count == 1)

        // (c) post-completion guesses are total no-ops
        game.solveByGuessing()
        #expect(game.isComplete)
        #expect(!game.guess(game.missingPlain()))
        #expect(game.mistakes == 1)
        #expect(game.solvedCount == 1)
    }

    // guards: engine is case- and script-sensitive — space, emoji, Cyrillic Te, and the LOWERCASE of a correct letter each cost a real mistake and strike out (documents the view-owns-the-A-Z-keyboard trust boundary; space IS in the phrase but mapping only covers A-Z, so it falls to the miss path)
    @Test func nonLetterGuessesCostMistakes() {
        let game = CipherGame()
        game.begin(index: 0)
        let before = game.solvedLetters
        let junk: [Character] = [" ", "🌺", "Т", "e"] // "Т" is Cyrillic Te U+0422; phrase 0 contains E
        for (i, ch) in junk.enumerated() {
            #expect(!game.guess(ch))
            #expect(game.mistakes == i + 1)
            #expect(game.misses.contains(ch))
        }
        #expect(game.solvedLetters == before)
    }

    // guards: completion flips exactly on the final letter — solvedCount increments exactly once, and lockBeat totals pour + one per remaining unique letter
    @Test func completionOnLastGuess() {
        let game = CipherGame()
        game.begin(index: 0)
        let remaining = game.boardOrder.filter { game.solvedLetters[$0] == nil }
        for (i, c) in remaining.enumerated() {
            #expect(!game.isComplete)
            #expect(game.guess(game.reverse[c]!))
            if i < remaining.count - 1 { #expect(!game.isComplete) }
        }
        #expect(game.isComplete)
        #expect(game.solvedCount == 1)
        #expect(game.lockBeat == remaining.count + 1) // + the house pour
    }
}

// MARK: - Hints

@MainActor
@Suite("Cipher hints")
struct CipherHintTests {

    // guards: hint reveals the most-frequent unsolved letter, frequency ties break to the alphabetically-first cipher letter, identically across instances (no Dictionary-iteration-order dependence), and charged:false stays free
    @Test func hintTargetsMostConnectedDeterministically() {
        let probe = CipherGame()
        probe.begin(index: 0)
        let counts = probe.unsolvedCounts
        let maxCount = counts.values.max()!
        let tied = counts.filter { $0.value == maxCount }.keys.sorted()
        #expect(tied.count >= 2)   // phrase 0 exercises the tie (T/U/X at 3 post-pour)
        let expected = tied.first!
        #expect(expected == "T")   // golden pin of the inverted max-comparator's choice
        for _ in 0..<50 {
            let game = CipherGame()
            game.begin(index: 0)
            game.hint(charged: false)
            #expect(game.solvedLetters.count == 2) // house pour + hinted letter
            #expect(game.solvedLetters[expected] == game.reverse[expected])
            #expect(game.hints == 0)
        }
    }

    // guards: charged hint bumps hints exactly once and reveals exactly one letter
    @Test func chargedHintCostsOne() {
        let game = CipherGame()
        game.begin(index: 0)
        game.hint(charged: true)
        #expect(game.hints == 1)
        #expect(game.solvedLetters.count == 2)
        #expect(game.lockBeat == 2)
    }

    // guards: hint conservation — each effective hint reveals exactly one letter, a hint-only solve takes exactly (unique - pour) calls, and post-completion hints are total no-ops (no hints/lockBeat/solvedCount drift)
    @Test func hintOnlySolveThenHammering() {
        let game = CipherGame()
        game.begin(index: 0)
        let n = game.uniqueCipherLetters.count
        let poured = game.solvedLetters.count // 1: the house pour
        for i in 0..<(n - poured) {
            #expect(!game.isComplete)
            game.hint(charged: true)
            #expect(game.solvedLetters.count == poured + i + 1)
        }
        #expect(game.isComplete)
        #expect(game.hints == n - poured)
        #expect(game.lockBeat == n) // pour + every hint
        #expect(game.solvedCount == 1)
        for _ in 0..<5 { game.hint(charged: true) }
        #expect(game.hints == n - poured)
        #expect(game.lockBeat == n)
        #expect(game.solvedCount == 1)
    }

    // guards: Vic's free daily tip (charged: false) never voids CLEAN STRIKE — hints stays 0, isCleanSolve holds, +15 bonus intact
    @Test func freeHintsPreserveCleanStrike() {
        let game = CipherGame()
        game.begin(index: 0)
        game.solveByFreeHints()
        #expect(game.isComplete)
        #expect(game.hints == 0)
        #expect(game.mistakes == 0)
        #expect(game.isCleanSolve)
        #expect(game.completionScore == 23 * 3 + 15) // phrase 0 has 23 letters
    }
}

// MARK: - House pour

@MainActor
@Suite("Cipher house pour")
struct CipherHousePourTests {

    // guards: every fresh board opens with exactly ONE truthful reveal — the most-connected letter — free of charge (hints/mistakes/misses 0, CLEAN STRIKE intact)
    @Test(arguments: [0, 7, 42, 299, 300, 599])
    func freshBoardsOpenWithBusiestLetterFree(index: Int) {
        let game = CipherGame()
        game.begin(index: index)
        #expect(game.solvedLetters.count == 1)
        let (cipher, plain) = game.solvedLetters.first!
        #expect(game.reverse[cipher] == plain) // truthful reveal
        let pouredCount = game.cipherText.filter { $0 == cipher }.count
        let maxUnsolved = game.unsolvedCounts.values.max() ?? 0
        #expect(pouredCount >= maxUnsolved)    // most-connected letter won
        #expect(game.hints == 0)
        #expect(game.mistakes == 0)
        #expect(game.misses.isEmpty)
        #expect(game.isCleanSolve)             // pour never voids CLEAN STRIKE
        #expect(game.lockBeat == 1)
    }

    // guards: cross-version pour stability on board 0 — cipher N -> plain E (E is the busiest letter of THE EARLY BIRD GETS THE WORM at 4 occurrences)
    @Test func housePourGoldenPinBoardZero() {
        let game = CipherGame()
        game.begin(index: 0)
        #expect(game.solvedLetters == ["N": "E"])
    }

    // guards: the pour never double-serves — a mid-phrase restore keeps exactly the saved letters, while a pre-pour cold save (zero assignments mid-phrase, no mistakes) gets poured on restore with its counters intact
    @Test func restoreNeverDoubleServesThePour() {
        let origin = CipherGame()
        origin.begin(index: 5)
        let c = origin.boardOrder.first { origin.solvedLetters[$0] == nil }!
        #expect(origin.guess(origin.reverse[c]!))
        let copy = CipherGame()
        copy.restore(from: origin.payload(seenHowTo: true))
        #expect(copy.solvedLetters == origin.solvedLetters) // pour + guess, not a third letter

        let legacy = CipherGame()
        legacy.restore(from: saveJSON(index: 5, hints: 1))
        #expect(legacy.solvedLetters == houseSeed(index: 5))
        #expect(legacy.hints == 1)
    }
}

// MARK: - Misses & strikeout

@MainActor
@Suite("Cipher misses & strikeout")
struct CipherMissesTests {

    // guards: misses round-trip the payload exactly — a relaunched board shows the same struck keys and the same mistake count
    @Test func missesSurviveRelaunchMidRound() {
        let origin = CipherGame()
        origin.begin(index: 2)
        let w1 = origin.missingPlain()
        #expect(!origin.guess(w1))
        let w2 = origin.missingPlain()
        #expect(!origin.guess(w2))
        #expect(origin.mistakes == 2)

        let copy = CipherGame()
        #expect(copy.restore(from: origin.payload(seenHowTo: true)) != nil)
        #expect(copy.phraseIndex == 2)
        #expect(copy.mistakes == 2)
        #expect(copy.misses == [w1, w2])
        #expect(!copy.isFailed)
        // Struck letters stay inert after the relaunch.
        #expect(!copy.guess(w1))
        #expect(copy.mistakes == 2)
    }

    // guards: a pre-hangman payload (no misses key) decodes AND drops its counters — those mistakes were accrued under the dead cursor rules and have no struck keys to show for them, so the board would read MISSES 2/5 over a clean keyboard
    @Test func preHangmanPayloadDecodesWithCountersDropped() {
        let scratch = CipherGame()
        scratch.begin(index: 3)
        let good = scratch.boardOrder[0]
        let game = CipherGame()
        let returned = game.restore(from: saveJSON(
            index: 3,
            assignments: [String(good): String(scratch.reverse[good]!)],
            mistakes: 2, hints: 1,
            misses: nil        // pre-hangman: the key never existed
        ))
        #expect(returned != nil)
        #expect(game.misses.isEmpty)
        #expect(game.mistakes == 0)
        #expect(game.hints == 0)
        #expect(game.solvedLetters[good] == scratch.reverse[good]!) // board progress kept
        #expect(game.isCleanSolve)                                  // and a clean run is still reachable

        // A hangman-era save (misses key present, even empty) keeps its counters.
        let modern = CipherGame()
        modern.restore(from: saveJSON(
            index: 3,
            assignments: [String(good): String(scratch.reverse[good]!)],
            mistakes: 2, hints: 1, misses: []
        ))
        #expect(modern.mistakes == 2)
        #expect(modern.hints == 1)
    }

    // guards: misses hygiene mirrors assignments — multi-char and empty entries drop, single-Character entries (even junk) restore
    @Test func junkMissesEntriesAreFiltered() {
        let game = CipherGame()
        game.restore(from: saveJSON(index: 0, misses: ["", "AB", "Q", "🌴"]))
        #expect(game.misses == ["Q", "🌴"])
    }

    // guards: CONTENT DRIFT — a save whose assignments ALL contradict the derived mapping (written against different catalog content) keeps the wall position but zeroes mistakes/hints/misses and serves a fresh pour; inherited penalties against a phrase the player never saw would be unfair
    @Test func contentDriftServesCleanBoard() {
        let scratch = CipherGame()
        scratch.begin(index: 4)
        let k = scratch.boardOrder[0]
        let notAnswer = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".first { $0 != scratch.reverse[k]! }!
        let game = CipherGame()
        let returned = game.restore(from: saveJSON(
            index: 4,
            assignments: [String(k): String(notAnswer)], // plausible but contradicting
            mistakes: 4, hints: 2, misses: ["Q", "Z"]
        ))
        #expect(returned != nil)
        #expect(game.phraseIndex == 4)                       // wall position kept
        #expect(game.solvedLetters == houseSeed(index: 4))   // fresh pour
        #expect(game.mistakes == 0)
        #expect(game.hints == 0)
        #expect(game.misses.isEmpty)
        #expect(!game.isFailed)
    }

    // guards: drift does NOT fire when any assignment survives — a normal save with one stale pair keeps its counters
    @Test func partialSurvivalKeepsCounters() {
        let scratch = CipherGame()
        scratch.begin(index: 6)
        let good = scratch.boardOrder[0]
        let bad = scratch.boardOrder[1]
        let notAnswer = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".first {
            $0 != scratch.reverse[bad]! && $0 != scratch.reverse[good]!
        }!
        let game = CipherGame()
        game.restore(from: saveJSON(
            index: 6,
            assignments: [
                String(good): String(scratch.reverse[good]!),
                String(bad): String(notAnswer),
            ],
            mistakes: 3, misses: ["Q"]
        ))
        #expect(game.solvedLetters == [good: scratch.reverse[good]!])
        #expect(game.mistakes == 3)
        #expect(game.misses == ["Q"])
    }
}

// MARK: - Scoring

@MainActor
@Suite("Cipher scoring")
struct CipherScoreTests {

    // guards: exact score law on phrase 0 (23 letters, base 69) — floor clamps at exactly 20, +15 clean bonus applies AFTER max() and only when mistakes == 0 && hints == 0
    @Test(arguments: [
        (0, 0, 84), // 69 clean, +15 rides on top
        (1, 0, 59), // one mistake voids the bonus
        (0, 1, 54), // one charged hint voids the bonus
        (1, 2, 29), // 69 - 10 - 30
        (1, 1, 44), // 69 - 10 - 15, both costs, no clamp
        (2, 3, 20), // 69 - 20 - 45 = 4 -> clamps to 20
        (0, 5, 20), // 69 - 75 = -6 -> clamps to 20
        (7, 1, 20), // 69 - 70 - 15 = -16 -> clamps to 20
    ])
    func scoreLaw(_ testCase: (mistakes: Int, hints: Int, expected: Int)) {
        let game = CipherGame()
        #expect(CipherGame.phrases[0].filter { $0 != " " }.count == 23)
        game.begin(index: 0, restoring: nil, mistakes: testCase.mistakes, hints: testCase.hints)
        #expect(game.completionScore == testCase.expected)
    }
}

// MARK: - Persistence

@MainActor
@Suite("Cipher persistence")
struct CipherPersistenceTests {

    // guards: mid-phrase payload -> restore reproduces phraseIndex, solvedLetters, mistakes, hints, misses, lastFreeHintDay, and the exact board; the returned SavePayload carries seenHowTo through
    @Test func midPhraseRoundTrip() {
        let origin = CipherGame()
        origin.begin(index: 7)
        let order = origin.boardOrder.filter { origin.solvedLetters[$0] == nil }
        for c in order.prefix(3) {
            #expect(origin.guess(origin.reverse[c]!))
        }
        for _ in 0..<2 { #expect(!origin.guess(origin.missingPlain())) }
        origin.hint(charged: true)
        origin.lastFreeHintDay = "2026-07-17"
        let json = origin.payload(seenHowTo: true)

        let copy = CipherGame()
        let returned = copy.restore(from: json)
        #expect(returned?.seenHowTo == true)
        #expect(copy.phraseIndex == 7)
        #expect(copy.solvedLetters == origin.solvedLetters)
        #expect(copy.solvedLetters.count == 5) // pour + 3 guesses + 1 hint
        #expect(copy.mistakes == 2)
        #expect(copy.misses == origin.misses)
        #expect(copy.hints == 1)
        #expect(copy.lastFreeHintDay == "2026-07-17")
        #expect(copy.cipherText == origin.cipherText)
        #expect(copy.solvedCount == 0)
        #expect(!copy.isComplete)
    }

    // guards: a completed phrase persists as the NEXT index, fresh (empty assignments/misses, zeroed mistakes/hints) — restoring never re-serves a phrase whose answers the player just saw, and the next board pours on restore
    @Test func completedPhraseSavesAsNextIndexFresh() throws {
        let game = CipherGame()
        game.begin(index: 0)
        #expect(!game.guess(game.missingPlain())) // dirty the counters
        game.hint(charged: true)
        game.lastFreeHintDay = "2026-07-16"
        game.solveByGuessing()
        #expect(game.isComplete)

        let json = game.payload(seenHowTo: false)
        let decoded = try decodePayload(json)
        #expect(decoded.phraseIndex == 1)
        #expect(decoded.assignments.isEmpty)
        #expect(decoded.mistakes == 0)
        #expect(decoded.hints == 0)
        #expect(decoded.misses?.isEmpty == true)
        #expect(decoded.solvedCount == 1)
        #expect(decoded.seenHowTo == false)
        #expect(decoded.lastFreeHintDay == "2026-07-16")

        let copy = CipherGame()
        copy.restore(from: json)
        #expect(copy.phraseIndex == 1)
        #expect(copy.solvedLetters == houseSeed(index: 1)) // fresh board, fresh pour
        #expect(copy.misses.isEmpty)
        #expect(!copy.isComplete)
        #expect(copy.solvedCount == 1)
    }

    // guards: every decode failure (nil, empty, garbage, wrong shape, missing keys) returns nil and falls back to a clean begin(0) even from a dirty mid-game state
    @Test(arguments: [nil, "", "not json", "{}", "[]", "{\"phraseIndex\":3}"] as [String?])
    func decodeFailureFallsBackToFreshPhraseZero(_ raw: String?) {
        let game = CipherGame()
        game.begin(index: 3)
        let c = game.boardOrder.first { game.solvedLetters[$0] == nil }!
        #expect(game.guess(game.reverse[c]!))
        #expect(!game.guess(game.missingPlain()))

        let returned = game.restore(from: raw)
        #expect(returned == nil)
        #expect(game.phraseIndex == 0)
        #expect(game.solvedLetters == houseSeed(index: 0)) // clean board 0, poured
        #expect(game.mistakes == 0)
        #expect(game.hints == 0)
        #expect(game.misses.isEmpty)
        #expect(!game.isComplete)
        #expect(game.cipherText == goldenCipher0)
    }

    // guards: restore hygiene — pairs contradicting the derived cipher, empty keys/values, lowercase, and non-A-Z keys are all silently dropped while consistent pairs and counters survive (one surviving pair means NO content-drift reset)
    @Test func restoreDropsContradictingAndDegenerateAssignments() {
        let scratch = CipherGame()
        scratch.begin(index: 0)
        let good = scratch.boardOrder[0]
        let goodPlain = scratch.reverse[good]!
        let bad = scratch.boardOrder[1]
        let badAnswer = scratch.reverse[bad]!
        let wrongPlain = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".first { $0 != badAnswer && $0 != goodPlain }!

        var assignments: [String: String] = [
            String(good): String(goodPlain),   // consistent -> survives
            String(bad): String(wrongPlain),   // contradicts derived cipher -> dropped
            "": "A",                           // empty key -> dropped (k.first == nil)
            "Q": "",                           // empty value -> dropped (v.first == nil)
            "é": "A",                          // accented key -> dropped by reverse filter
            "Т": "B",                          // Cyrillic Te -> dropped
            "👾": "C",                         // emoji -> dropped
        ]
        assignments[String(good).lowercased()] = String(goodPlain).lowercased() // lowercase -> dropped

        let game = CipherGame()
        let returned = game.restore(from: saveJSON(index: 0, assignments: assignments, mistakes: 1, hints: 2))
        #expect(returned != nil)
        #expect(game.solvedLetters == [good: goodPlain])
        #expect(game.mistakes == 1)
        #expect(game.hints == 2)
        #expect(!game.isComplete)
    }

    // guards: PINNED current behavior — restoring a hand-crafted fully-solved payload flips isComplete during begin and bumps solvedCount one past the restored value, then persists index+1 fresh. Legit payloads never contain complete assignments (see completedPhraseSavesAsNextIndexFresh); pinning this so any change is deliberate.
    @Test func craftedCompleteSaveDoubleCountPinned() throws {
        let scratch = CipherGame()
        scratch.begin(index: 3)
        var full: [String: String] = [:]
        for c in scratch.boardOrder { full[String(c)] = String(scratch.reverse[c]!) }

        let game = CipherGame()
        game.restore(from: saveJSON(index: 3, solvedCount: 7, assignments: full))
        #expect(game.isComplete)
        #expect(game.solvedCount == 8) // restored 7 + checkComplete's increment

        let decoded = try decodePayload(game.payload(seenHowTo: false))
        #expect(decoded.phraseIndex == 4)
        #expect(decoded.assignments.isEmpty)
        #expect(decoded.solvedCount == 8)
    }

    // guards: a bloated hostile save (5000 junk CJK pairs) decodes, filters to just the consistent pair, and completes in bounded time
    @Test func bloatedSaveFilteredInBoundedTime() {
        let scratch = CipherGame()
        scratch.begin(index: 5)
        let good = scratch.boardOrder[0]
        let goodPlain = scratch.reverse[good]!

        // Distinct first Characters (distinct CJK scalars) sidestep the
        // Dictionary(uniqueKeysWithValues:) trap covered separately below.
        var assignments: [String: String] = [String(good): String(goodPlain)]
        for i in 0..<5000 { assignments[String(UnicodeScalar(UInt32(0x4E00 + i))!)] = "A" }

        let game = CipherGame()
        let returned = game.restore(from: saveJSON(index: 5, assignments: assignments))
        #expect(returned != nil)
        #expect(game.phraseIndex == 5)
        #expect(game.solvedLetters == [good: goodPlain])
        #expect(!game.isComplete)
    }
}

// MARK: - Boundaries

@MainActor
@Suite("Cipher boundaries")
struct CipherBoundaryTests {

    // guards: matchbook(forPhraseAt:) at every book seam and across the 300-phrase wrap — number is 1-based and book.phrases[number-1] agrees with the flat catalog
    @Test(arguments: [
        (0, "house", 1),
        (5, "house", 6),
        (6, "regulars", 1),
        (95, "philosophy", 6),
        (96, "outrigger", 1),
        (299, "closingtime", 6),
        (300, "house", 1),
        (305, "house", 6),
        (306, "regulars", 1),
        (599, "closingtime", 6),
    ])
    func matchbookSeams(_ testCase: (index: Int, bookID: String, number: Int)) {
        let result = CipherGame.matchbook(forPhraseAt: testCase.index)
        #expect(result.book.id == testCase.bookID)
        #expect(result.number == testCase.number)
        #expect(result.book.phrases[result.number - 1] == CipherGame.phrases[testCase.index % CipherGame.phrases.count])
    }

    // REGRESSION(negative-matchbook-number): Swift's % preserves sign, so a
    // negative index used to slip past the first book's `i < 6` check and
    // yield number 0 (for -1) or -6 (for -7) — outside 1...6. Fixed by the
    // non-negative modulo fold in matchbook(forPhraseAt:).
    // guards: matchbook number is always 1-based for ANY input index
    @Test(arguments: [-1, -7])
    func matchbookNegativeIndexStaysOneBased(_ index: Int) {
        let result = CipherGame.matchbook(forPhraseAt: index)
        #expect((1...6).contains(result.number))
    }

    // guards: the raw index grows past the catalog while content wraps mod 300 — phrase, currentMatchbook, currentCategory, and the flat list stay in agreement
    @Test func wrapAroundBoardsServeWrappedContent() {
        let game = CipherGame()
        game.begin(index: 300)
        #expect(game.phraseIndex == 300)
        #expect(game.phrase == CipherGame.phrases[0])
        #expect(game.currentMatchbook.book.id == "house")
        #expect(game.currentMatchbook.number == 1)
        #expect(game.currentCategory == CipherGame.categories[0])

        game.begin(index: 599)
        #expect(game.phrase == CipherGame.phrases[299])
        #expect(game.currentMatchbook.book.id == "closingtime")
        #expect(game.currentMatchbook.number == 6)
        #expect(game.currentCategory == CipherGame.categories[299])
    }

    // guards: a restored phraseIndex of Int.max survives (restore sanitizes out-of-range indices to a fresh board) and stays self-consistent — phrase agrees with phraseIndex and the mapping is intact
    @Test func intMaxRestoredIndexSurvives() {
        let game = CipherGame()
        let returned = game.restore(from: saveJSON(index: Int.max))
        #expect(returned != nil)
        #expect(game.mapping.count == 26)
        #expect(game.phrase == CipherGame.phrases[game.phraseIndex % CipherGame.phrases.count])
        #expect(CipherGame.phrases.contains(game.phrase))
    }

    // guards: a never-begun instance is inert — cipherText leaks the plaintext of phrase 0 (empty mapping passthrough, PINNED), guesses and hints are free no-ops except that a pre-begin guess of an absent letter still misses (mapping empty, phrase 0 lookup), and payload encodes a fresh index 0
    @Test func preBeginStateIsInert() throws {
        let game = CipherGame()
        #expect(game.cipherText == CipherGame.phrases[0]) // plaintext leak — pinned
        // A letter IN phrase 0 with an empty mapping: contains passes but
        // mapping[plain] is nil, so it falls to the miss path — pinned.
        #expect(!game.guess("E"))
        #expect(game.mistakes == 1)
        game.hint(charged: true)
        #expect(game.hints == 0) // reveal guard bails before charging pre-begin
        #expect(game.solvedLetters.isEmpty)
        let decoded = try decodePayload(game.payload(seenHowTo: false))
        #expect(decoded.phraseIndex == 0)
        #expect(decoded.assignments.isEmpty)
    }
}

// MARK: - Lifecycle & endurance

@MainActor
@Suite("Cipher lifecycle & endurance")
struct CipherLifecycleTests {

    // guards: begin() resets per-phrase state (mistakes/hints/misses/isComplete/lastRunSummary) but PRESERVES solvedCount, lastFreeHintDay, and the never-reset mistakeBeat/lockBeat monotone beat counters (lockBeat drives the background's pulse; mistakeBeat is engine bookkeeping)
    @Test func beginResetsPerPhraseButPreservesLifetimeState() {
        let game = CipherGame()
        game.begin(index: 24)
        game.solveByFreeHints()
        #expect(game.solvedCount == 1)
        let lockAfterSolve = game.lockBeat

        game.begin(index: 0)
        #expect(game.lockBeat == lockAfterSolve + 1) // beats survive begin; +1 house pour
        #expect(!game.guess(game.missingPlain()))
        let c0 = game.boardOrder.first { game.solvedLetters[$0] == nil }!
        #expect(game.guess(game.reverse[c0]!))
        game.lastRunSummary = RunSummary(best: 1, isNewBest: false, pointsEarned: 2, totalPoints: 3)
        game.lastFreeHintDay = "2026-07-15"

        game.begin(index: 1)
        #expect(game.phraseIndex == 1)
        #expect(game.mistakes == 0)
        #expect(game.hints == 0)
        #expect(game.misses.isEmpty)
        #expect(game.solvedLetters == houseSeed(index: 1))
        #expect(!game.isComplete)
        #expect(game.lastRunSummary == nil)
        #expect(game.mistakeBeat == 1)               // NOT reset
        #expect(game.lockBeat == lockAfterSolve + 3) // NOT reset: +pour, +guess, +pour
        #expect(game.solvedCount == 1)               // preserved
        #expect(game.lastFreeHintDay == "2026-07-15") // preserved
    }

    // guards: advance() mid-phrase is a skip — no solve credit, counters and misses reset, beats retained
    @Test func advanceMidPhraseIsSkip() {
        let game = CipherGame()
        game.begin(index: 3) // lockBeat 1: house pour
        let c0 = game.boardOrder.first { game.solvedLetters[$0] == nil }!
        #expect(game.guess(game.reverse[c0]!)) // lockBeat 2
        for _ in 0..<2 { #expect(!game.guess(game.missingPlain())) } // mistakeBeat 2
        game.hint(charged: true) // lockBeat 3
        game.lastRunSummary = RunSummary(best: 0, isNewBest: false, pointsEarned: 0, totalPoints: 0)

        game.advance()
        #expect(game.phraseIndex == 4)
        #expect(game.mistakes == 0)
        #expect(game.hints == 0)
        #expect(game.misses.isEmpty)
        #expect(game.solvedLetters == houseSeed(index: 4))
        #expect(!game.isComplete)
        #expect(game.solvedCount == 0)       // skips earn no credit
        #expect(game.lastRunSummary == nil)
        #expect(game.lockBeat == 4)          // retained; +1 pour on board 4
        #expect(game.mistakeBeat == 2)       // retained
    }

    // guards: under the coach shield, a full sweep of every absent letter accrues one mistake each with no fail; a REPEAT sweep is fully inert (strikeout idempotence at scale), and the board stays completable with the score floored
    @Test func absentLetterSweepUnderShieldIsIdempotent() {
        let game = CipherGame()
        game.begin(index: 0)
        game.setCoachShield(true) // live cap would stop at 5
        let absent = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".filter { !game.phrase.contains($0) }
        #expect(absent.count == 11) // 26 - 15 unique letters of phrase 0
        for ch in absent { #expect(!game.guess(ch)) }
        #expect(game.mistakes == absent.count)
        #expect(game.misses.count == absent.count)
        for ch in absent { #expect(!game.guess(ch)) } // second sweep: inert
        #expect(game.mistakes == absent.count)
        #expect(game.mistakeBeat == absent.count)
        #expect(!game.isFailed, "coach shield never trips the cap")
        #expect(game.solvedLetters == houseSeed(index: 0)) // nothing new locked
        #expect(game.completionScore == 20) // 78 - 110 floors
        game.solveByGuessing()
        #expect(game.isComplete)
        #expect(game.solvedCount == 1)
        #expect(game.completionScore == 20) // still floored, not clean
    }

    // guards: 10k advances rebuild (not accumulate) state — raw index grows, content wraps, the final board is a healthy bijection and still completable
    @Test func tenThousandAdvancesStayHealthy() {
        let game = CipherGame()
        for _ in 0..<10_000 { game.advance() }
        #expect(game.phraseIndex == 10_000)
        #expect(game.phrase == CipherGame.phrases[10_000 % CipherGame.phrases.count])
        #expect(game.solvedLetters == houseSeed(index: 10_000))
        #expect(game.mapping.count == 26)
        #expect(Set(game.mapping.values).count == 26)
        game.solveByFreeHints()
        #expect(game.isComplete)
        #expect(game.solvedCount == 1)
    }
}

// MARK: - Coach target

@MainActor
@Suite("Cipher coach target")
struct CipherCoachTargetTests {

    // guards: coachTargetPlain is always a sure hit — present in the phrase, not yet solved — and advances as letters lock; nil exactly when the board completes
    @Test func coachTargetIsAlwaysASureHit() {
        let game = CipherGame()
        game.begin(index: 0)
        while !game.isComplete {
            let target = game.coachTargetPlain
            #expect(target != nil)
            #expect(target.map { game.phrase.contains($0) } == true)
            #expect(target.map { game.usedPlainLetters.contains($0) } == false)
            #expect(game.guess(target!))
        }
        #expect(game.coachTargetPlain == nil)
        #expect(game.mistakes == 0) // sure hits never missed
    }
}

// MARK: - Hostile saves (regression tests for the 2026-07-17 sweep fixes)

@MainActor
@Suite("Cipher hostile saves")
struct CipherHostileSaveTests {

    // REGRESSION(negative-stats-restore): restore() used to accept negative
    // mistakes/hints unclamped; they INFLATED completionScore without bound.
    // Fixed by the min/max clamp in restore().
    // guards: restored negative counters clamp to exactly 0 (not abs()) and the score stays within the honest ceiling
    @Test func restoreClampsNegativeMistakesAndHints() {
        let game = CipherGame()
        let returned = game.restore(from: saveJSON(index: 0, mistakes: -5, hints: -3))
        #expect(returned != nil)
        #expect(game.mistakes == 0)
        #expect(game.hints == 0)
        #expect(game.completionScore <= 26 * 3 + 15)
    }

    // REGRESSION(negative/huge-index-trap): buildMapping's seed cast used to
    // trap for negative products, and restore() passed the decoded index
    // through unclamped — one corrupt save string crashed the app at
    // launch-restore. Fixed by restore() sanitizing out-of-range indices.
    // guards: hostile phraseIndex in a save never traps — restore clamps or falls back
    @Test(arguments: [-1, 4_000_000_000])
    func restoreHostilePhraseIndexIsGraceful(_ index: Int) {
        let game = CipherGame()
        game.restore(from: saveJSON(index: index))
        #expect(game.phraseIndex >= 0)
        #expect(game.mapping.count == 26)
    }

    // REGRESSION(dup-first-char-trap): restore()'s Dictionary(uniqueKeysWithValues:)
    // used to trap when two distinct JSON keys shared a first Character.
    // Fixed by requiring single-Character pairs and uniquing defensively.
    // guards: duplicate-first-Character assignment keys are dropped, not fatal
    @Test func restoreDuplicateFirstCharacterKeysIsGraceful() {
        let game = CipherGame()
        let returned = game.restore(from: saveJSON(index: 0, assignments: ["AB": "X", "AC": "Y"]))
        #expect(returned != nil)
        #expect(game.mapping.count == 26)
        #expect(game.solvedLetters == houseSeed(index: 0)) // junk never locks; only the pour shows
    }

    // REGRESSION(score-overflow-trap): completionScore's `mistakes * 10` used
    // to overflow-trap for restored mistakes > Int.max / 10. Fixed by
    // restore() capping counters at 100_000.
    // guards: completionScore never traps on extreme restored counters
    @Test func completionScoreSurvivesExtremeRestoredMistakes() {
        let game = CipherGame()
        game.restore(from: saveJSON(index: 0, mistakes: Int.max, hints: Int.max))
        #expect(game.completionScore >= 20)
    }

    // guards: solvedCount is clamped on restore like the other counters — a
    // save carrying Int.max used to overflow-trap on checkComplete's next
    // increment (panel R1, promoted from the engineer's dropped queue)
    @Test func restoreClampsHostileSolvedCount() {
        let game = CipherGame()
        game.restore(from: saveJSON(index: 0, solvedCount: Int.max))
        #expect(game.solvedCount <= 1_000_000)
        game.solveByFreeHints()      // checkComplete increments without trapping
        #expect(game.isComplete)
        let negative = CipherGame()
        negative.restore(from: saveJSON(index: 0, solvedCount: -7))
        #expect(negative.solvedCount == 0)
    }

    // REGRESSION(intmax-advance-trap): a hostile save at Int.max used to reach
    // play and the first advance() trapped on the non-wrapping `+ 1`. Fixed
    // by restore() sanitizing out-of-range indices.
    // guards: advance() from a hostile restored index never traps
    @Test func advanceAtIntMaxDoesNotTrap() {
        let game = CipherGame()
        game.restore(from: saveJSON(index: Int.max))
        game.advance()
        #expect(game.phraseIndex >= 0)
        #expect(game.mapping.count == 26)
    }
}

// MARK: - Mistake cap + lives economy

@MainActor
struct CipherMistakeCapTests {
    // guards: the (cap−1)th miss does not fail; the (cap)th fails exactly once and freezes the board — further guesses (including correct ones) refuse
    @Test func capFailsExactlyOnTheNthMiss() {
        let game = CipherGame()
        game.begin(index: 0)
        for i in 1..<CipherGame.mistakeCap {
            #expect(!game.guess(game.missingPlain()))
            #expect(game.mistakes == i)
            #expect(!game.isFailed, "miss \(i) must not end the phrase")
        }
        #expect(!game.guess(game.missingPlain()))
        #expect(game.mistakes == CipherGame.mistakeCap)
        #expect(game.isFailed)
        // Frozen — further guesses refuse.
        #expect(!game.guess(game.missingPlain()))
        #expect(game.mistakes == CipherGame.mistakeCap)
        let unsolved = game.boardOrder.first { game.solvedLetters[$0] == nil }!
        #expect(!game.guess(game.reverse[unsolved]!))
        #expect(!game.isComplete)
    }

    // guards: coach shield never fails the board even past the cap
    @Test func coachShieldNeverFails() {
        let game = CipherGame()
        game.begin(index: 0)
        game.setCoachShield(true)
        for _ in 0..<(CipherGame.mistakeCap + 2) {
            #expect(!game.guess(game.missingPlain()))
        }
        #expect(game.mistakes == CipherGame.mistakeCap + 2)
        #expect(!game.isFailed)
    }

    // guards: clearCoachResidue wipes scripted-board counters so shielded
    // misses can NEVER detonate into a defeat (and a life spend) when the
    // shield drops — the exact sequence the coach dismiss runs
    @Test func coachResidueClearedBeforeShieldDrop() {
        let game = CipherGame()
        game.begin(index: 0)
        game.setCoachShield(true)
        for _ in 0..<(CipherGame.mistakeCap + 1) {
            #expect(!game.guess(game.missingPlain()))
        }
        game.hint(charged: true)
        game.clearCoachResidue()
        game.setCoachShield(false)   // would have armed isFailed pre-fix
        #expect(game.mistakes == 0)
        #expect(game.hints == 0)
        #expect(game.misses.isEmpty)
        #expect(!game.isFailed)
        #expect(game.isCleanSolve)   // CLEAN STRIKE still reachable post-coach
        game.solveByGuessing()
        #expect(game.isComplete)
    }

    // guards: PLAY AGAIN after a defeat serves a FRESH phrase — the lost
    // phrase's answer was just revealed on the board, so re-serving it would
    // be a non-puzzle. The view drives this with advance(); this pins the
    // engine contract it relies on (new index, clean board, no solve credit).
    @Test func advanceFromDefeatServesFreshPlayablePhrase() {
        let game = CipherGame()
        game.begin(index: 11)
        for _ in 0..<CipherGame.mistakeCap {
            #expect(!game.guess(game.missingPlain()))
        }
        #expect(game.isFailed)
        let lost = game.phrase

        game.advance()
        #expect(game.phraseIndex == 12)
        #expect(game.phrase != lost)
        #expect(!game.isFailed)
        #expect(game.mistakes == 0)
        #expect(game.misses.isEmpty)
        #expect(game.solvedLetters == houseSeed(index: 12)) // fresh pour
        #expect(game.solvedCount == 0)                      // a defeat earns no credit
        game.solveByGuessing()
        #expect(game.isComplete)                            // and it is playable
    }

    // guards: reset-on-retry (begin same index) starts at zero mistakes with a clean keyboard and clears isFailed
    @Test func retrySamePhraseResetsMistakes() {
        let game = CipherGame()
        game.begin(index: 3)
        for _ in 0..<CipherGame.mistakeCap {
            #expect(!game.guess(game.missingPlain()))
        }
        #expect(game.isFailed)
        game.begin(index: 3)
        #expect(game.phraseIndex == 3)
        #expect(game.mistakes == 0)
        #expect(game.misses.isEmpty)
        #expect(!game.isFailed)
        #expect(game.solvedLetters == houseSeed(index: 3), "house pour on a fresh retry")
    }

    // guards: restoring at the cap re-arms isFailed so force-quit cannot launder a cold phrase
    @Test func restoreAtCapRearmsFailure() {
        let origin = CipherGame()
        origin.begin(index: 0)
        for _ in 0..<CipherGame.mistakeCap {
            #expect(!origin.guess(origin.missingPlain()))
        }
        #expect(origin.isFailed)
        let json = origin.payload(seenHowTo: false)
        let copy = CipherGame()
        #expect(copy.restore(from: json) != nil)
        #expect(copy.mistakes == CipherGame.mistakeCap)
        #expect(copy.misses == origin.misses)
        #expect(copy.isFailed)
        #expect(!copy.isComplete)
    }
}

// MARK: - Streak story

@Suite("Cipher streak story")
struct CipherStreakStoryTests {

    // guards: the CRACKED badge is silent exactly when no run exists —
    // crafted saves restore complete with a zeroed streak and must not
    // show a "0 IN A ROW".
    @Test func crackedHidesWithoutARun() {
        #expect(CipherStreakStory.cracked(streak: 0, best: 7, isNewBest: false) == nil)
        #expect(CipherStreakStory.cracked(streak: -3, best: 7, isNewBest: false) == nil)
    }

    // guards: the first win teaches the chase ("get X in a row") instead
    // of celebrating a 1 — even when 1 technically beats a 0 best, the
    // isNewBest flag must not turn solve one into YOUR BEST YET.
    @Test func firstWinSeedsTheChase() {
        for flag in [true, false] {
            let story = CipherStreakStory.cracked(streak: 1, best: 1, isNewBest: flag)
            #expect(story?.title == "STREAK STARTED")
            #expect(story?.detail == "CRACK THE NEXT FOR 2 IN A ROW")
            #expect(story?.isNewBest == false)
        }
    }

    // guards: from 2 up the row is the headline and the standing best is
    // the context — the number the leaderboard actually ranks.
    @Test func rowCountsWithBestContext() {
        let story = CipherStreakStory.cracked(streak: 5, best: 8, isNewBest: false)
        #expect(story?.title == "5 IN A ROW")
        #expect(story?.detail == "BEST 8")
        #expect(story?.streak == 5)
    }

    // guards: beating the best swaps the quiet context for the celebration
    // line; a mere TIE (streak == best, isNewBest false) keeps BEST — the
    // view captures the pre-recordRun best precisely so ties never lie.
    @Test func newBestCelebratesAndTiesDoNot() {
        let beat = CipherStreakStory.cracked(streak: 9, best: 9, isNewBest: true)
        #expect(beat?.detail == "YOUR BEST YET")
        #expect(beat?.isNewBest == true)
        let tie = CipherStreakStory.cracked(streak: 9, best: 9, isNewBest: false)
        #expect(tie?.detail == "BEST 9")
    }

    // guards: a defeat line appears only when a real run (2+) died. Losing
    // the first phrase of a run — or right after a defeat — mourns nothing.
    @Test func failedLineNeedsARealRun() {
        #expect(CipherStreakStory.failed(endedStreak: 0, best: 8) == nil)
        #expect(CipherStreakStory.failed(endedStreak: 1, best: 8) == nil)
        #expect(CipherStreakStory.failed(endedStreak: 2, best: 8) == "2 IN A ROW ENDS · BEST 8")
    }

    // guards: the defeat line names the run AND the target to chase back;
    // ending your best-ever run reads coherently (5 ends, best 5).
    @Test func failedNamesRunAndTarget() {
        #expect(CipherStreakStory.failed(endedStreak: 5, best: 12) == "5 IN A ROW ENDS · BEST 12")
        #expect(CipherStreakStory.failed(endedStreak: 5, best: 5) == "5 IN A ROW ENDS · BEST 5")
    }
}

// MARK: - Streak heat ladder

@Suite("Cipher streak heat")
struct CipherStreakHeatTests {

    // guards: the stamp's color ladder steps exactly at the quotable
    // milestones — 5, 10, 20 — with no gaps or overlaps at the seams.
    @Test func heatThresholds() {
        func heat(_ n: Int) -> CipherStreakStory.Heat? {
            CipherStreakStory.cracked(streak: n, best: n, isNewBest: false)?.heat
        }
        #expect(heat(1) == .matchGold)
        #expect(heat(2) == .matchGold)
        #expect(heat(4) == .matchGold)
        #expect(heat(5) == .sunset)
        #expect(heat(9) == .sunset)
        #expect(heat(10) == .blaze)
        #expect(heat(19) == .blaze)
        #expect(heat(20) == .glowTide)
        #expect(heat(120) == .glowTide)
    }
}
