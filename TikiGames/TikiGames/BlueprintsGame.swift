import Foundation
import Observation

/// Blueprints — the nonogram engine. Pure logic: row/column run-length clues
/// derive from authored tiki pixel-art bitmaps, so every puzzle is valid by
/// construction. Fill mode paints, cross mode marks empties; painting a wrong
/// cell counts a mistake and auto-corrects to a cross (casual Picross rules).
/// A puzzle is solved when every true cell is filled. The round ends in
/// defeat at `mistakeCap` wrong fills (shared lives economy).
@Observable
final class BlueprintsGame {
    /// Wrong fills that end the sketch — the third ruins the draft.
    static let mistakeCap = 3

    enum Cell: String, Codable {
        case empty, filled, crossed
    }

    enum Mode {
        case fill, cross
    }

    struct Puzzle: Identifiable {
        let id: String
        let name: String
        /// Rows of '.', '#' (primary) and '+' (accent). Square.
        let rows: [String]
        var size: Int { rows.count }

        func truth(_ r: Int, _ c: Int) -> Bool {
            let ch = Array(rows[r])[c]
            return ch == "#" || ch == "+"
        }

        func isAccent(_ r: Int, _ c: Int) -> Bool {
            Array(rows[r])[c] == "+"
        }
    }

    /// First-run tutorial — seventeen scripted beats over the 5x5 Tiki
    /// Mug, teaching the deduction ladder rather than the tools (rubric
    /// v3): READ a full-line clue (row 2 says 5 → the whole row fills),
    /// fill a run (row 0's 3), EARN marks (the finished 3 proves its
    /// leftovers empty), CASH them on col 1's stacked `3 1` (finish the
    /// 3, cross the mandatory gap, fill the lone 1), then GENERALIZE on
    /// row 3's `1 1 1` — the three-number clue played out cell by cell,
    /// so `1 2 1`-class stacks are experienced, not left to panel text.
    /// Every fill target is true and every cross target is provably
    /// empty from the grid at the moment its beat fires — first-tap
    /// success is 100% per beat and no mark is take-on-faith (`1 1 1`
    /// on a 5-wide line is the strongest case: its single arrangement
    /// is forced by the clue alone). The script still leaves the mug
    /// unfinished: the remainder resolves with only the taught atoms.
    static let tutorialPuzzleIndex = 0

    /// Which clue label a beat reasons about — the view spotlights it.
    enum ClueRef: Equatable {
        case row(Int), col(Int)
    }

    struct TutorialBeat {
        let row: Int
        let col: Int
        let mode: Mode
        /// Phase card copy — clue value + reason clause (rubric v2 dim 3).
        let message: String
        let clue: ClueRef
    }

    static let tutorialBeats: [TutorialBeat] = {
        let readRow = "ROW SAYS 5 — DRAG ACROSS ALL FIVE"
        let runRow = "ROW SAYS 3 — FILL ITS RUN OF THREE"
        let earnMark = "THE 3 IS DONE — CROSS OFF THE REST"
        let threeSingles = "1 1 1 — THREE SINGLES, A GAP BETWEEN EACH"
        return [
            // READ: row 2 = "#####" — the clue number IS the fill count.
            TutorialBeat(row: 2, col: 0, mode: .fill, message: readRow, clue: .row(2)),
            TutorialBeat(row: 2, col: 1, mode: .fill, message: readRow, clue: .row(2)),
            TutorialBeat(row: 2, col: 2, mode: .fill, message: readRow, clue: .row(2)),
            TutorialBeat(row: 2, col: 3, mode: .fill, message: readRow, clue: .row(2)),
            TutorialBeat(row: 2, col: 4, mode: .fill, message: readRow, clue: .row(2)),
            // A run: row 0 = ".###." — three together (position pulsed,
            // count reasoned by the card).
            TutorialBeat(row: 0, col: 1, mode: .fill, message: runRow, clue: .row(0)),
            TutorialBeat(row: 0, col: 2, mode: .fill, message: runRow, clue: .row(0)),
            TutorialBeat(row: 0, col: 3, mode: .fill, message: runRow, clue: .row(0)),
            // EARN A MARK: the satisfied 3 forces the leftovers empty.
            // (0,4) first — it continues a left-to-right drag naturally.
            TutorialBeat(row: 0, col: 4, mode: .cross, message: earnMark, clue: .row(0)),
            TutorialBeat(row: 0, col: 0, mode: .cross, message: earnMark, clue: .row(0)),
            // CASH IT IN: col 1's stacked `3 1`, read top to bottom. The 3
            // must contain the already-filled (0,1) → rows 0-2, so (1,1)
            // fills; the gap below it is mandatory, so (3,1) crosses; the
            // lone 1 lands at (4,1).
            TutorialBeat(row: 1, col: 1, mode: .fill,
                         message: "COLUMN SAYS 3 THEN 1 — FINISH THE 3", clue: .col(1)),
            TutorialBeat(row: 3, col: 1, mode: .cross,
                         message: "3 THEN 1 NEED A GAP — CROSS IT", clue: .col(1)),
            TutorialBeat(row: 4, col: 1, mode: .fill,
                         message: "AND THE LONE 1 BELOW", clue: .col(1)),
            // GENERALIZE: row 3 reads `1 1 1` — three separate runs, in
            // order, a gap between each. On a 5-wide line that clue has
            // exactly one arrangement (■·■·■), so every beat is forced by
            // the clue alone. (3,1) already wears col 1's gap cross, which
            // is the point: the same cell serves both readings. Left to
            // right: single, (gap), single, gap, single.
            TutorialBeat(row: 3, col: 0, mode: .fill,
                         message: threeSingles, clue: .row(3)),
            TutorialBeat(row: 3, col: 2, mode: .fill,
                         message: threeSingles, clue: .row(3)),
            TutorialBeat(row: 3, col: 3, mode: .cross,
                         message: threeSingles, clue: .row(3)),
            TutorialBeat(row: 3, col: 4, mode: .fill,
                         message: threeSingles, clue: .row(3)),
        ]
    }()

    static var tutorialBeatCount: Int { tutorialBeats.count }

    /// The tiki blueprint drawer, ordered as a size ladder: 5x5 warm-ups
    /// through 10x10 spotlights, with no gaps between tiers. The Tiki Mug
    /// stays first — it is `tutorialPuzzleIndex`, and the 17-beat coach
    /// script is written against its exact bitmap.
    static let puzzles: [Puzzle] = [
        // MARK: 5x5
        Puzzle(id: "mug", name: "Tiki Mug", rows: [
            ".###.",
            "#+#+#",
            "#####",
            "#.#.#",
            ".###.",
        ]),
        Puzzle(id: "hibiscus", name: "Hibiscus", rows: [
            ".#.#.",
            "#####",
            ".#+#.",
            "#####",
            ".#.#.",
        ]),
        Puzzle(id: "anchor", name: "Anchor", rows: [
            "..+..",
            "..#..",
            "#.#.#",
            "#.#.#",
            ".###.",
        ]),
        Puzzle(id: "pineapple", name: "Pineapple", rows: [
            ".+.+.",
            "..+..",
            ".###.",
            "#####",
            ".###.",
        ]),
        Puzzle(id: "umbrella", name: "Drink Umbrella", rows: [
            ".###.",
            "#+#+#",
            "..#..",
            "..#..",
            "..##.",
        ]),
        Puzzle(id: "limewedge", name: "Lime Wedge", rows: [
            "..+..",
            ".###.",
            "#####",
            ".###.",
            "..+..",
        ]),
        // MARK: 6x6
        Puzzle(id: "beachball", name: "Beach Ball", rows: [
            "..##..",
            ".####.",
            "##++##",
            "##++##",
            ".####.",
            "..##..",
        ]),
        Puzzle(id: "sun", name: "The Sun", rows: [
            "#.##.#",
            ".####.",
            "##++##",
            "##++##",
            ".####.",
            "#.##.#",
        ]),
        Puzzle(id: "tikibowl", name: "Tiki Bowl", rows: [
            "######",
            "#+..+#",
            "######",
            ".####.",
            ".####.",
            "..##..",
        ]),
        Puzzle(id: "bongo", name: "Bongo Drum", rows: [
            ".####.",
            "######",
            "#.##.#",
            ".####.",
            ".####.",
            ".####.",
        ]),
        Puzzle(id: "coupe", name: "Coupe Glass", rows: [
            "######",
            ".####.",
            ".####.",
            "..##..",
            "..##..",
            ".####.",
        ]),
        Puzzle(id: "parasol", name: "Parasol", rows: [
            "..##..",
            ".####.",
            "######",
            "..##..",
            "..##..",
            "..##..",
        ]),
        Puzzle(id: "rumbottle", name: "Rum Bottle", rows: [
            "..##..",
            "..##..",
            ".####.",
            "######",
            "######",
            ".####.",
        ]),
        Puzzle(id: "beachshack", name: "Beach Shack", rows: [
            "..##..",
            ".####.",
            "######",
            "#....#",
            "#.##.#",
            "#....#",
        ]),
        // MARK: 7x7
        Puzzle(id: "jellyfish", name: "Jellyfish", rows: [
            "..###..",
            ".#####.",
            "#######",
            "#+###+#",
            ".#####.",
            ".#.#.#.",
            ".#.#.#.",
        ]),
        Puzzle(id: "goblet", name: "Tiki Goblet", rows: [
            "#######",
            "#+###+#",
            "#######",
            ".#####.",
            "..###..",
            "..###..",
            ".#####.",
        ]),
        Puzzle(id: "cocopalm", name: "Coco Palm", rows: [
            ".##.##.",
            "#######",
            "..###..",
            "...#...",
            "...#...",
            "..###..",
            ".#####.",
        ]),
        Puzzle(id: "sanddollar", name: "Sand Dollar", rows: [
            "..###..",
            ".#####.",
            "##+++##",
            "##+++##",
            "##+++##",
            ".#####.",
            "..###..",
        ]),
        Puzzle(id: "barrel", name: "Rum Barrel", rows: [
            ".#####.",
            "##...##",
            "#######",
            "#+###+#",
            "#######",
            "##...##",
            ".#####.",
        ]),
        Puzzle(id: "bamboo", name: "Bamboo", rows: [
            ".##.##.",
            ".##.##.",
            "#######",
            ".##.##.",
            ".##.##.",
            "#######",
            ".##.##.",
        ]),
        Puzzle(id: "tikiflame", name: "Tiki Flame", rows: [
            "...#...",
            "..###..",
            ".#+++#.",
            ".#####.",
            "..###..",
            "...#...",
            "..###..",
        ]),
        Puzzle(id: "coralfan", name: "Coral Fan", rows: [
            "#..#..#",
            "#.###.#",
            "#######",
            ".#####.",
            "..###..",
            "...#...",
            "...#...",
        ]),
        Puzzle(id: "firepit", name: "Fire Pit", rows: [
            "...#...",
            "..#+#..",
            ".#+++#.",
            "#######",
            "#######",
            ".#####.",
            "..###..",
        ]),
        // MARK: 8x8
        Puzzle(id: "mask", name: "Carved Mask", rows: [
            ".######.",
            "########",
            "#+#..#+#",
            "########",
            "#..##..#",
            "########",
            "#.####.#",
            ".######.",
        ]),
        Puzzle(id: "palm", name: "Lone Palm", rows: [
            ".#.##.#.",
            "########",
            ".##..##.",
            "...++...",
            "...++...",
            "..++....",
            "..++....",
            "++++++++",
        ]),
        Puzzle(id: "cat", name: "The Cat", rows: [
            "##....##",
            "###..###",
            "########",
            "#+####+#",
            "########",
            ".##..##.",
            ".######.",
            "..####..",
        ]),
        Puzzle(id: "martini", name: "Last Martini", rows: [
            "#######+",
            ".######.",
            "..####..",
            "...##...",
            "...##...",
            "...##...",
            "..####..",
            ".######.",
        ]),
        Puzzle(id: "float", name: "Glass Float", rows: [
            "..####..",
            ".######.",
            "##+##+##",
            "########",
            "##+##+##",
            ".######.",
            "..####..",
            "...++...",
        ]),
        Puzzle(id: "ukulele", name: "Ukulele", rows: [
            "...##...",
            "...##...",
            "...##...",
            "..####..",
            ".######.",
            ".##++##.",
            ".######.",
            "..####..",
        ]),
        Puzzle(id: "crab", name: "Beach Crab", rows: [
            "#.#..#.#",
            ".#....#.",
            "..####..",
            ".##++##.",
            "########",
            ".######.",
            "#..##..#",
            "#......#",
        ]),
        Puzzle(id: "idol", name: "The Idol", rows: [
            "..####..",
            ".######.",
            ".#+##+#.",
            ".######.",
            "..####..",
            "..####..",
            ".######.",
            "########",
        ]),
        Puzzle(id: "vinyl", name: "Vinyl Night", rows: [
            "..####..",
            ".######.",
            "########",
            "###++###",
            "###++###",
            "########",
            ".######.",
            "..####..",
        ]),
        Puzzle(id: "outrigger", name: "Outrigger", rows: [
            "....#...",
            "...##...",
            "..###...",
            ".####...",
            "#####...",
            "....#...",
            "########",
            ".##++##.",
        ]),
        Puzzle(id: "lantern", name: "Paper Lantern", rows: [
            "...##...",
            "..####..",
            ".######.",
            ".##++##.",
            ".##++##.",
            ".######.",
            "..####..",
            "...##...",
        ]),
        Puzzle(id: "shell", name: "Pearl Shell", rows: [
            "...##...",
            "..####..",
            ".######.",
            "###++###",
            "##.##.##",
            ".#.##.#.",
            "..####..",
            "...##...",
        ]),
        Puzzle(id: "moonrise", name: "Moonrise", rows: [
            "...####.",
            "..##..+.",
            ".##.....",
            ".##.....",
            ".##.....",
            ".##.....",
            "..##....",
            "...####.",
        ]),
        Puzzle(id: "skull", name: "Bone Dry", rows: [
            "..####..",
            ".######.",
            "##.##.##",
            ".######.",
            ".##++##.",
            ".######.",
            ".#.##.#.",
            "..####..",
        ]),
        // MARK: 9x9
        Puzzle(id: "grasshut", name: "Grass Hut", rows: [
            "....#....",
            "...###...",
            "..#####..",
            ".#######.",
            "#########",
            "#.......#",
            "#.#####.#",
            "#.#...#.#",
            "#.#####.#",
        ]),
        Puzzle(id: "manta", name: "Manta Ray", rows: [
            "..#####..",
            ".#######.",
            "#########",
            "##+###+##",
            "#########",
            ".#######.",
            "..#####..",
            "...#.#...",
            "...#.#...",
        ]),
        Puzzle(id: "lighthouse", name: "Lighthouse", rows: [
            "...###...",
            "...#+#...",
            "...###...",
            "..#####..",
            "..#####..",
            "..#####..",
            ".#######.",
            ".#######.",
            "#########",
        ]),
        Puzzle(id: "marlin", name: "Marlin", rows: [
            "........#",
            ".......##",
            "..#####.#",
            ".#######.",
            "#####+###",
            ".#######.",
            "..#####.#",
            ".......##",
            "........#",
        ]),
        Puzzle(id: "hula", name: "Hula Skirt", rows: [
            "...###...",
            "...###...",
            "..#####..",
            ".#######.",
            "#########",
            "#########",
            "#.#.#.#.#",
            "#.#.#.#.#",
            "#.#.#.#.#",
        ]),
        Puzzle(id: "longboard", name: "Longboard", rows: [
            "...###...",
            "..#####..",
            "..#+++#..",
            "..#+++#..",
            "..#+++#..",
            "..#+++#..",
            "..#+++#..",
            "..#####..",
            "...###...",
        ]),
        Puzzle(id: "seacave", name: "Sea Cave", rows: [
            "#########",
            "#########",
            "##.....##",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
            "#.......#",
        ]),
        Puzzle(id: "gecko", name: "Gecko", rows: [
            ".###.....",
            "####.....",
            ".####....",
            "..#####..",
            "...#####.",
            "....#####",
            ".....###.",
            "......##.",
            "......###",
        ]),
        Puzzle(id: "conch", name: "Conch Shell", rows: [
            "......##.",
            "....####.",
            "..######.",
            ".#######.",
            "#####+###",
            ".#######.",
            "..######.",
            "....###..",
            "......#..",
        ]),
        Puzzle(id: "crossedoars", name: "Crossed Oars", rows: [
            "###...###",
            "####.####",
            ".#######.",
            "..#####..",
            "...###...",
            "..#####..",
            ".#######.",
            "####.####",
            "###...###",
        ]),
        Puzzle(id: "moonjelly", name: "Moon Jelly", rows: [
            "...###...",
            "..#####..",
            ".#######.",
            "#########",
            "#++###++#",
            "#########",
            ".#######.",
            "..#.#.#..",
            "..#.#.#..",
        ]),
        Puzzle(id: "driftlog", name: "Drift Log", rows: [
            ".........",
            "..#####..",
            ".#######.",
            "#########",
            "##+###+##",
            "#########",
            ".#######.",
            "..#####..",
            ".........",
        ]),
        // MARK: 10x10
        Puzzle(id: "volcano", name: "The Volcano", rows: [
            "....++....",
            "...++++...",
            "....##....",
            "...####...",
            "..######..",
            "..######..",
            ".########.",
            ".########.",
            "##########",
            "##########",
        ]),
        Puzzle(id: "torch", name: "Night Torch", rows: [
            "....++....",
            "...++++...",
            "....++....",
            "...####...",
            "...####...",
            "....##....",
            "....##....",
            "....##....",
            "....##....",
            "...####...",
        ]),
        Puzzle(id: "blowfish", name: "Blowfish", rows: [
            "...####...",
            "..######..",
            ".########.",
            "##########",
            "###+######",
            "##########",
            ".########.",
            "..######..",
            "...####...",
            ".#..##..#.",
        ]),
        Puzzle(id: "turtle", name: "Sea Turtle", rows: [
            "....##....",
            "...####...",
            "#.######.#",
            "##########",
            ".########.",
            ".###++###.",
            ".########.",
            "##########",
            "#.######.#",
            "...####...",
        ]),
        Puzzle(id: "kraken", name: "The Kraken", rows: [
            "...####...",
            "..######..",
            ".########.",
            ".##+##+##.",
            ".########.",
            "..######..",
            ".#.####.#.",
            "#..#..#..#",
            "#.#....#.#",
            ".#.#..#.#.",
        ]),
        Puzzle(id: "sunset", name: "Sunset", rows: [
            "...++++...",
            "..++++++..",
            ".++++++++.",
            "##########",
            "##########",
            "#.#.#.#.#.",
            ".#.#.#.#.#",
            "#.#.#.#.#.",
            ".#.#.#.#.#",
            "##########",
        ]),
        Puzzle(id: "castaway", name: "Castaway Post", rows: [
            "....++....",
            "....##....",
            "...####...",
            "..######..",
            "..######..",
            "..##++##..",
            "..##++##..",
            "..######..",
            "..######..",
            "...####...",
        ]),
        Puzzle(id: "compass", name: "Compass Rose", rows: [
            "....##....",
            "...####...",
            "..######..",
            ".###++###.",
            "####++####",
            "####++####",
            ".###++###.",
            "..######..",
            "...####...",
            "....##....",
        ]),
        Puzzle(id: "island", name: "The Island", rows: [
            ".##..##...",
            "###++##...",
            ".##..##...",
            "...##.....",
            "...##.....",
            "...##.....",
            "..##......",
            ".########.",
            "##########",
            "##########",
        ]),
        Puzzle(id: "totem", name: "The Totem", rows: [
            ".########.",
            ".#+#..#+#.",
            ".########.",
            ".##.##.##.",
            ".########.",
            ".#+#..#+#.",
            ".########.",
            ".###..###.",
            ".########.",
            "##########",
        ]),
        Puzzle(id: "starfish", name: "Starfish", rows: [
            "....##....",
            "....##....",
            "...####...",
            "##########",
            ".###++###.",
            "..##++##..",
            "..######..",
            ".###..###.",
            "###....###",
            "##......##",
        ]),
    ]

    private(set) var puzzle: Puzzle?
    private(set) var grid: [[Cell]] = []
    private(set) var mistakes = 0
    /// Bumps on every wrong fill — keys the shake/juice.
    private(set) var mistakeBeat = 0
    /// Bumps on every correct fill — keys the pop juice.
    private(set) var fillBeat = 0
    private(set) var isComplete = false
    /// True once mistakes hit `mistakeCap` — the sketch is ruined.
    private(set) var isFailed = false
    private(set) var solvedIDs: Set<String> = []
    var mode: Mode = .fill
    /// Coach boards never trip the mistake cap — the script owns the mug.
    private(set) var coachShield = false

    /// Arms or clears the coach shield. Clearing re-evaluates the cap so
    /// mistakes accrued under the script still end the round once real play
    /// begins (rare — the script itself doesn't produce mistakes).
    func setCoachShield(_ on: Bool) {
        coachShield = on
        if !on { evaluateFailure() }
    }
    /// Whether the just-completed puzzle was this player's first solve of it
    /// (replays pay reduced wallet points).
    private(set) var completedFirstSolve = true
    var lastRunSummary: RunSummary?

    // MARK: clues

    static func clues(for line: [Bool]) -> [Int] {
        var runs: [Int] = []
        var current = 0
        for cell in line {
            if cell { current += 1 } else if current > 0 { runs.append(current); current = 0 }
        }
        if current > 0 { runs.append(current) }
        return runs.isEmpty ? [0] : runs
    }

    func rowClues(_ r: Int) -> [Int] {
        guard let p = puzzle, (0..<p.size).contains(r) else { return [] }
        return Self.clues(for: (0..<p.size).map { p.truth(r, $0) })
    }

    func colClues(_ c: Int) -> [Int] {
        guard let p = puzzle, (0..<p.size).contains(c) else { return [] }
        return Self.clues(for: (0..<p.size).map { p.truth($0, c) })
    }

    /// A line is satisfied when its filled cells' run pattern equals the
    /// clue pattern. Under sketch rules (fills are always true cells) this
    /// matches the old count check; under draft rules it is the real test.
    /// Satisfied clues dim — the classic picross breadcrumb.
    func rowSatisfied(_ r: Int) -> Bool {
        guard let p = puzzle, (0..<grid.count).contains(r) else { return false }
        return Self.clues(for: (0..<p.size).map { grid[r][$0] == .filled }) == rowClues(r)
    }

    func colSatisfied(_ c: Int) -> Bool {
        guard let p = puzzle, grid.count == p.size, (0..<p.size).contains(c) else { return false }
        return Self.clues(for: (0..<p.size).map { grid[$0][c] == .filled }) == colClues(c)
    }

    // MARK: play

    func begin(_ p: Puzzle, resuming saved: [[Cell]]? = nil, mistakes savedMistakes: Int = 0) {
        // A ragged puzzle (any row shorter than the square size) would trap
        // inside truth(); reject it at the door. The static table is square.
        guard p.rows.allSatisfy({ $0.count == p.size }) else { return }
        puzzle = p
        var resumed = false
        if let saved, saved.count == p.size, saved.allSatisfy({ $0.count == p.size }) {
            grid = saved
            mistakes = max(0, savedMistakes)
            resumed = true
        } else {
            grid = [[Cell]](repeating: [Cell](repeating: .empty, count: p.size), count: p.size)
            mistakes = 0
        }
        isComplete = false
        isFailed = false
        lastRunSummary = nil
        mode = .fill
        // A corrupted save can resume an already-solved board; organic saves
        // never persist one (payload's live gate). Without a re-check no
        // sketch tap could ever fire checkComplete again — a soft-lock.
        if resumed { checkComplete() }
        // Mid-round kill with mistakes at the cap re-arms defeat so the
        // player can't force-quit to launder a ruined sketch.
        evaluateFailure()
    }

    func closePuzzle() {
        // Deliberately leaves `grid` populated: live ForEach cells can get one
        // final observation update during teardown, and an emptied grid would
        // crash their index subscripts.
        puzzle = nil
        isComplete = false
        isFailed = false
    }

    /// Returns true when the tap changed anything.
    @discardableResult
    func tap(_ r: Int, _ c: Int) -> Bool {
        guard let p = puzzle, !isComplete, !isFailed,
              (0..<p.size).contains(r), (0..<p.size).contains(c) else { return false }
        return sketchTap(p, r, c)
    }

    private func sketchTap(_ p: Puzzle, _ r: Int, _ c: Int) -> Bool {
        // Crosses are erasable in cross mode; fills are permanent.
        if grid[r][c] == .crossed, mode == .cross {
            grid[r][c] = .empty
            return true
        }
        guard grid[r][c] == .empty else { return false }
        switch mode {
        case .fill:
            if p.truth(r, c) {
                grid[r][c] = .filled
                fillBeat += 1
                checkComplete()
            } else {
                grid[r][c] = .crossed
                mistakes += 1
                mistakeBeat += 1
                evaluateFailure()
            }
        case .cross:
            if p.truth(r, c) {
                // Crossing a true cell is also a mistake — it auto-fills.
                grid[r][c] = .filled
                mistakes += 1
                mistakeBeat += 1
                evaluateFailure()
                if !isFailed { checkComplete() }
            } else {
                grid[r][c] = .crossed
            }
        }
        return true
    }

    /// Ends the sketch at the cap unless the coach owns the board.
    private func evaluateFailure() {
        guard !coachShield, !isComplete, mistakes >= Self.mistakeCap else { return }
        isFailed = true
    }

    private func checkComplete() {
        guard let p = puzzle else { return }
        for r in 0..<p.size {
            for c in 0..<p.size where p.truth(r, c) && grid[r][c] != .filled {
                return
            }
        }
        completedFirstSolve = !solvedIDs.contains(p.id)
        isComplete = true
        solvedIDs.insert(p.id)
    }

    /// The sheet the drawer hands over after this one: the next *unsolved*
    /// blueprint in table order, wrapping once past the end. Returning the
    /// drawer to the picker after every solve meant re-picking by hand, and
    /// the picker makes it easy to reopen something already drafted — this
    /// is what the auto-advance seam follows. nil once the drawer is done,
    /// which is the signal to show the completion panel instead.
    func nextUnsolved(after id: String) -> Puzzle? {
        guard let i = Self.puzzles.firstIndex(where: { $0.id == id }) else {
            return Self.puzzles.first { !solvedIDs.contains($0.id) }
        }
        // Everything after the current sheet, then everything before it —
        // the current one is never a candidate.
        let ordered = Array(Self.puzzles[(i + 1)...]) + Array(Self.puzzles[..<i])
        return ordered.first { !solvedIDs.contains($0.id) }
    }

    /// Board area x4 minus mistake penalty, floor 20.
    var completionScore: Int {
        guard let p = puzzle else { return 0 }
        return max(20, p.size * p.size * 4 - mistakes * 10)
    }

    // MARK: persistence

    struct SavePayload: Codable {
        var seenHowTo: Bool
        var solved: [String]
        var currentID: String?
        var currentGrid: [[Cell]]?
        /// Optionals so payloads written before these fields decode.
        /// (Retired DRAFT-era keys — currentRules/preferredRules/
        /// fairCopies/currentSlips — decode-skip harmlessly as unknown.)
        var currentMistakes: Int?
        /// One-shot "wrong cells mark themselves" toast already shown.
        var mistakeHint: Bool?
    }

    func payload(seenHowTo: Bool, mistakeHint: Bool) -> String {
        // Failed sketches stay live so a kill mid-panel can't launder the
        // mistake counter — restore re-arms isFailed via evaluateFailure.
        let live = !isComplete && puzzle != nil
        let state = SavePayload(
            seenHowTo: seenHowTo,
            solved: Array(solvedIDs),
            currentID: live ? puzzle?.id : nil,
            currentGrid: live ? grid : nil,
            currentMistakes: live ? mistakes : nil,
            mistakeHint: mistakeHint
        )
        guard let data = try? JSONEncoder().encode(state) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    @discardableResult
    func restore(from json: String?) -> SavePayload? {
        guard let json, let data = json.data(using: .utf8),
              let state = try? JSONDecoder().decode(SavePayload.self, from: data) else {
            return nil
        }
        solvedIDs = Set(state.solved)
        if let id = state.currentID,
           let p = Self.puzzles.first(where: { $0.id == id }) {
            begin(
                p,
                resuming: state.currentGrid,
                mistakes: state.currentMistakes ?? 0
            )
        }
        return state
    }

    #if DEBUG
    /// Dev hook (TIKI_BLUEPRINTS_SOLVED=<n>): seeds n sheets as already
    /// drafted so constellations and milestone thresholds stage on demand.
    func debugSeedSolved(_ n: Int) {
        solvedIDs = Set(Self.puzzles.prefix(max(0, n)).map(\.id))
    }

    /// Test hook: drops one sheet back to undrafted so seam-ordering cases
    /// can be staged without solving 60 boards by hand.
    func debugUnsolve(_ id: String) {
        solvedIDs.remove(id)
    }

    /// Dev hook (TIKI_BLUEPRINTS_MISTAKES=<n>): stages the live counter so
    /// one-remaining emphasis and the defeat beat can be sim-verified.
    func debugStageMistakes(_ n: Int) {
        guard puzzle != nil, !isComplete else { return }
        mistakes = max(0, n)
        mistakeBeat += 1
        isFailed = false
        evaluateFailure()
    }
    #endif
}
