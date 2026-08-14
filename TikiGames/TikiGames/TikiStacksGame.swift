import SwiftUI
import Observation

// MARK: - Assets

enum BlockColor: Int, CaseIterable, Codable {
    case coral, teal, gold, orange, avocado, chartreuse

    var image: Image {
        switch self {
        case .coral: return Image("BlockCellCoral")
        case .teal: return Image("BlockCellTeal")
        case .gold: return Image("BlockCellGold")
        case .orange: return Image("BlockCellOrange")
        case .avocado: return Image("BlockCellAvocado")
        case .chartreuse: return Image("BlockCellChartreuse")
        }
    }
}

extension Image {
    static let blockCellEmpty = Image("BlockCellEmpty")
    static let boardFrame = Image("BoardFrame")
    static let uiTray = Image("UITray")
    static let uiScoreboard = Image("UIScoreboard")
    static let uiPanel = Image("UIPanel")
    static let uiButton = Image("UIButton")
    static let fxBurst = Image("FXBurst")
    static let maskHappy = Image("MaskHappy")
    static let maskSurprised = Image("MaskSurprised")
    static let maskSleepy = Image("MaskSleepy")
    static let maskGrumpy = Image("MaskGrumpy")
    static let iconTrophy = Image("IconTrophy")
    static let iconCrown = Image("IconCrown")
}

// MARK: - Model

struct GridPos: Hashable, Codable {
    let row: Int
    let col: Int
}

/// tier 0 = point callout at the clear; 1-2 = combo banner; 3+ = milestone.
struct ScorePopup: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let row: Double
    let col: Double
    let tier: Int
}

struct Piece: Identifiable, Equatable, Codable {
    let id: UUID
    let cells: [GridPos]
    let color: BlockColor

    var rows: Int { cells.map(\.row).max()! + 1 }
    var cols: Int { cells.map(\.col).max()! + 1 }
}

enum PieceLibrary {
    static let shapes: [[(Int, Int)]] = [
        // dots and lines
        [(0, 0)],
        [(0, 0), (0, 1)], [(0, 0), (1, 0)],
        [(0, 0), (0, 1), (0, 2)], [(0, 0), (1, 0), (2, 0)],
        [(0, 0), (0, 1), (0, 2), (0, 3)], [(0, 0), (1, 0), (2, 0), (3, 0)],
        [(0, 0), (0, 1), (0, 2), (0, 3), (0, 4)], [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0)],
        // squares and rectangles
        [(0, 0), (0, 1), (1, 0), (1, 1)],
        [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)],
        [(0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (2, 1)],
        [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)],
        // small corners
        [(0, 0), (1, 0), (1, 1)], [(0, 1), (1, 0), (1, 1)],
        [(0, 0), (0, 1), (1, 0)], [(0, 0), (0, 1), (1, 1)],
        // big L
        [(0, 0), (1, 0), (2, 0), (2, 1)], [(0, 1), (1, 1), (2, 0), (2, 1)],
        [(0, 0), (0, 1), (1, 0), (2, 0)], [(0, 0), (0, 1), (1, 1), (2, 1)],
        // T
        [(0, 0), (0, 1), (0, 2), (1, 1)], [(0, 1), (1, 0), (1, 1), (1, 2)],
        // S / Z
        [(0, 1), (0, 2), (1, 0), (1, 1)], [(0, 0), (0, 1), (1, 1), (1, 2)],
    ]

    static func piece(shapeIndex: Int) -> Piece {
        let shape = shapes[shapeIndex]
        let color = BlockColor.allCases.randomElement()!
        return Piece(id: UUID(), cells: shape.map { GridPos(row: $0.0, col: $0.1) }, color: color)
    }
}

@Observable
@MainActor
final class TikiStacksGame {
    static let size = 8
    static let cleanSweepBonus = 120
    /// Moonlit Sweep: the clean-sweep bonus doubles from NIGHTFALL on.
    static let moonlitSweepBonus = 240
    /// A line clear containing a firefly cell pays this on top.
    static let fireflyBonus = 25
    /// The lagoon's depth-state ladder: DUSK / NIGHTFALL / MOONRISE / GLOW TIDE.
    static let depthThresholds = [150, 400, 800, 1500]

    var grid: [[BlockColor?]]
    var tray: [Piece?]
    var score = 0
    var best: Int
    var streak = 0
    var lastClearCount = 0
    var isGameOver = false
    /// 0–4 index into the depth-state ladder for the current score.
    var stage: Int { Self.depthThresholds.filter { score >= $0 }.count }
    /// Cumulative line-clear counter — the scene's one-shot flourish beat.
    private(set) var clearBeat = 0
    /// Firefly Piece (NIGHTFALL+): tray pieces dealt glowing, and the board
    /// cells they filled. Clearing a line through a firefly cell pays +25.
    private(set) var glowingPieceIDs: Set<UUID> = []
    private(set) var fireflyCells: Set<GridPos> = []
    /// Cells that just cleared — the view draws a brief burst on these.
    var clearFlash: [GridPos] = []
    /// Floating score/combo callouts; each removes itself after its moment.
    var popups: [ScorePopup] = []
    /// Centroid of the last clear — bursts cascade outward from here.
    var clearCentroid: GridPos = GridPos(row: 0, col: 0)
    private var startingBest: Int = 0
    private var celebratedBest = false

    /// Called once when a run ends, with the final score. The owning view
    /// routes this into PlayerStore — the game itself never touches storage.
    var onGameOver: ((Int) -> Void)?
    /// Persistence outcome for the finished run, set by the owning view's
    /// onGameOver hook. Lives here (not view @State) so the game-over panel
    /// always observes it regardless of view identity.
    var lastRunSummary: RunSummary?

    /// Shuffled-bag piece source: every pass deals each library shape exactly
    /// once, so droughts of rescuer pieces can't run longer than one bag.
    private var bag: [Int] = []
    private var bagDealt = 0
    private var glowSlots: Set<Int> = []

    /// Firefly pieces per bag: 1 from NIGHTFALL, 2 at GLOW TIDE.
    private var fireflyPerBag: Int { stage >= 4 ? 2 : stage >= 2 ? 1 : 0 }

    private func nextPiece() -> Piece {
        if bag.isEmpty {
            bag = Array(PieceLibrary.shapes.indices).shuffled()
            bagDealt = 0
            glowSlots = Set((0..<bag.count).shuffled().prefix(fireflyPerBag))
        }
        let piece = PieceLibrary.piece(shapeIndex: bag.removeFirst())
        if glowSlots.contains(bagDealt) { glowingPieceIDs.insert(piece.id) }
        bagDealt += 1
        return piece
    }

    init() {
        grid = Array(repeating: Array(repeating: nil, count: Self.size), count: Self.size)
        best = 0
        startingBest = 0
        tray = []
        tray = (0..<3).map { _ in nextPiece() }
    }

    /// Seeds the persisted best before play begins.
    func configureBest(_ persisted: Int) {
        best = max(best, persisted)
        startingBest = best
    }

    /// True when this run's score beats the best it started with.
    var isNewBest: Bool { score > 0 && score > startingBest }
    var previousBest: Int { startingBest }

    var fillRatio: Double {
        let filled = grid.flatMap { $0 }.compactMap { $0 }.count
        return Double(filled) / Double(Self.size * Self.size)
    }

    enum Mood { case happy, surprised, grumpy, sleepy }
    var mood: Mood {
        if isGameOver { return .sleepy }
        if lastClearCount >= 2 { return .surprised }
        if fillRatio > 0.6 { return .grumpy }
        return .happy
    }

    func canPlace(_ piece: Piece, at origin: GridPos) -> Bool {
        for c in piece.cells {
            let r = origin.row + c.row
            let k = origin.col + c.col
            guard r >= 0, r < Self.size, k >= 0, k < Self.size, grid[r][k] == nil else { return false }
        }
        return true
    }

    func hasAnyPlacement(_ piece: Piece) -> Bool {
        guard piece.rows <= Self.size, piece.cols <= Self.size else { return false }
        for r in 0...(Self.size - piece.rows) {
            for k in 0...(Self.size - piece.cols) {
                if canPlace(piece, at: GridPos(row: r, col: k)) { return true }
            }
        }
        return false
    }

    /// Placement forgiveness (Block Blast-style): a near-miss drop still
    /// lands. Snap candidates beyond this distance (in cell units, measured
    /// from the piece's ideal fractional top-left) never engage — one-cell
    /// misses and lean-in diagonals are caught, resting diagonals (1.41) and
    /// anything further never teleport.
    static let snapRadius = 1.25

    /// The nearest legal origin within `snapRadius` of the ideal fractional
    /// top-left, or nil. A legal exact (rounded) placement sits at the
    /// minimum distance by construction, so precision is never rerouted;
    /// board-edge overhang clamps in and competes by the same distance rule.
    func snappedOrigin(for piece: Piece, idealRow: Double, idealCol: Double) -> GridPos? {
        let rr = Int(idealRow.rounded())
        let rk = Int(idealCol.rounded())
        var best: GridPos?
        var bestDist = Double.infinity
        for dr in -1...1 {
            for dk in -1...1 {
                let r = min(max(rr + dr, 0), Self.size - piece.rows)
                let k = min(max(rk + dk, 0), Self.size - piece.cols)
                let dRow = Double(r) - idealRow
                let dCol = Double(k) - idealCol
                let dist = (dRow * dRow + dCol * dCol).squareRoot()
                guard dist <= Self.snapRadius, dist < bestDist,
                      canPlace(piece, at: GridPos(row: r, col: k)) else { continue }
                best = GridPos(row: r, col: k)
                bestDist = dist
            }
        }
        return best
    }

    @discardableResult
    func place(slot: Int, at origin: GridPos) -> Bool {
        guard !isGameOver,
              tray.indices.contains(slot), let piece = tray[slot], canPlace(piece, at: origin) else {
            return false
        }
        for c in piece.cells {
            grid[origin.row + c.row][origin.col + c.col] = piece.color
        }
        if glowingPieceIDs.remove(piece.id) != nil {
            for c in piece.cells {
                fireflyCells.insert(GridPos(row: origin.row + c.row, col: origin.col + c.col))
            }
        }
        score += piece.cells.count
        tray[slot] = nil
        clearLines()
        // Tutorial owns the tray until it hands off — skip auto-refill so the
        // view can drop a new dot (or reset the round) without a random flash.
        if tray.allSatisfy({ $0 == nil }), !tutorialActive {
            tray = (0..<3).map { _ in nextPiece() }
        }
        updateBestIfNeeded()
        checkGameOver()
        return true
    }

    private func clearLines() {
        var fullRows: [Int] = []
        var fullCols: [Int] = []
        for r in 0..<Self.size where (0..<Self.size).allSatisfy({ grid[r][$0] != nil }) {
            fullRows.append(r)
        }
        for k in 0..<Self.size where (0..<Self.size).allSatisfy({ grid[$0][k] != nil }) {
            fullCols.append(k)
        }
        let lines = fullRows.count + fullCols.count
        lastClearCount = lines
        guard lines > 0 else {
            streak = 0
            return
        }
        var cells: Set<GridPos> = []
        for r in fullRows {
            for k in 0..<Self.size { cells.insert(GridPos(row: r, col: k)) }
        }
        for k in fullCols {
            for r in 0..<Self.size { cells.insert(GridPos(row: r, col: k)) }
        }
        for p in cells { grid[p.row][p.col] = nil }
        streak += 1
        clearBeat += 1
        let points = lines * 10 * streak
        score += points
        clearFlash = Array(cells)
        // popups: points at the clear's centroid, combo banner when escalating
        let midRow = Double(cells.map(\.row).reduce(0, +)) / Double(cells.count)
        let midCol = Double(cells.map(\.col).reduce(0, +)) / Double(cells.count)
        clearCentroid = GridPos(row: Int(midRow.rounded()), col: Int(midCol.rounded()))
        spawnPopup(ScorePopup(text: "+\(points)", row: midRow, col: midCol, tier: 0))
        // Firefly Piece: a clear through a glowing cell pays its bonus.
        if !fireflyCells.isDisjoint(with: cells) {
            fireflyCells.subtract(cells)
            score += Self.fireflyBonus
            spawnPopup(ScorePopup(text: "FIREFLY +\(Self.fireflyBonus)", row: midRow + 1.4, col: midCol, tier: 0))
        }
        if streak >= 2 {
            spawnPopup(ScorePopup(text: "COMBO x\(streak)", row: -1, col: -1, tier: min(streak - 1, 2)))
        }
        // Emptying the whole board is the genre's rarest event — celebrate it.
        // From NIGHTFALL on it is a Moonlit Sweep and pays double. Scripted
        // tutorial rounds always wipe the grid, so they never qualify (the
        // view already skips the fanfare for the same reason).
        if !tutorialActive, grid.allSatisfy({ $0.allSatisfy { $0 == nil } }) {
            let moonlit = stage >= 2
            let bonus = moonlit ? Self.moonlitSweepBonus : Self.cleanSweepBonus
            score += bonus
            spawnPopup(ScorePopup(
                text: moonlit ? "MOONLIT SWEEP! +\(bonus)" : "CLEAN SWEEP! +\(bonus)",
                row: -1, col: -1, tier: 3
            ))
        }
        if !celebratedBest, startingBest > 0, score > startingBest {
            celebratedBest = true
            spawnPopup(ScorePopup(text: "NEW BEST!", row: -1, col: -1, tier: 3))
        }
        clearFlashGeneration += 1
        let generation = clearFlashGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 750_000_000)
            // A newer clear owns the flash now — don't truncate its burst.
            guard let self, self.clearFlashGeneration == generation else { return }
            self.clearFlash = []
        }
    }

    private var clearFlashGeneration = 0

    private func spawnPopup(_ popup: ScorePopup) {
        popups.append(popup)
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self?.popups.removeAll { $0.id == popup.id }
        }
    }

    private func updateBestIfNeeded() {
        // Scripted-tutorial placements must not pollute the displayed best.
        if !tutorialActive, score > best {
            best = score
        }
    }

    private func checkGameOver() {
        let remaining = tray.compactMap { $0 }
        guard !remaining.isEmpty else { return }
        if remaining.allSatisfy({ !hasAnyPlacement($0) }) {
            isGameOver = true
            // The death beat's headline — states the lose reason over the
            // board during the pause before the panel covers it.
            spawnPopup(ScorePopup(text: "NO ROOM LEFT", row: -1, col: -1, tier: 3))
            onGameOver?(score)
        }
    }

    func restart() {
        grid = Array(repeating: Array(repeating: nil, count: Self.size), count: Self.size)
        glowingPieceIDs = []
        fireflyCells = []
        glowSlots = []       // a restart re-earns NIGHTFALL before glow returns
        score = 0
        tray = (0..<3).map { _ in nextPiece() }
        streak = 0
        lastClearCount = 0
        isGameOver = false
        clearFlash = []
        popups = []
        lastRunSummary = nil
        startingBest = best
        celebratedBest = false
    }

    /// First-run seed: four sequential rounds that escalate from a single-line
    /// clear to a four-lines-in-one-drop payoff. Each round hand-authors the
    /// pre-filled cells + the tray shape + the drop origin so that the optimal
    /// placement clears N lines simultaneously (N = 1, 2, 3, 4). Round 2's
    /// two-line clear intersects a row and a column so the player also learns
    /// both axes clear — no modal ever names either concept.
    struct TutorialRound {
        let boardFills: [(row: Int, col: Int)]
        let trayShapeIndex: Int
        let dropOrigin: (row: Int, col: Int)
    }

    /// The four scripted rounds. `boardFills` are computed once at load and
    /// shape indices reference `PieceLibrary.shapes`:
    ///   0 = 1x1 dot, 2 = vertical 2, 6 = vertical 4.
    static let tutorialRounds: [TutorialRound] = {
        let last = size - 1
        // Round 1 (1-line row clear) — row 4 filled cols 0..6, drop 1x1 at (4,7).
        let r1 = (0..<last).map { (row: 4, col: $0) }
        // Round 2 (row + column intersect = 2 lines) — row 4 cols 0..6 filled,
        // col 7 rows 0..3 + 5..7 filled; drop 1x1 at (4,7) fills the last gap
        // of BOTH row 4 AND column 7.
        let r2 = (0..<last).map { (row: 4, col: $0) }
            + (0..<size).filter { $0 != 4 }.map { (row: $0, col: last) }
        // Round 3 (3 lines) — rows 3 and 4 filled cols 0..6, col 7 filled at
        // rows 0,1,2,5,6,7 (empty only at 3 and 4). Drop vertical 2-piece at
        // (3,7) → fills (3,7) and (4,7). Both rows complete; col 7 also.
        let r3 = (0..<last).flatMap { c -> [(row: Int, col: Int)] in
            [(row: 3, col: c), (row: 4, col: c)]
        } + [0, 1, 2, 5, 6, 7].map { (row: $0, col: last) }
        // Round 4 (4-line row clear) — rows 2..5 filled cols 0..6. Drop
        // vertical 4-piece at (2,7) → fills (2,7)..(5,7). All four rows clear.
        let r4 = (0..<last).flatMap { c -> [(row: Int, col: Int)] in
            [2, 3, 4, 5].map { (row: $0, col: c) }
        }
        return [
            TutorialRound(boardFills: r1, trayShapeIndex: 0, dropOrigin: (4, last)),
            TutorialRound(boardFills: r2, trayShapeIndex: 0, dropOrigin: (4, last)),
            TutorialRound(boardFills: r3, trayShapeIndex: 2, dropOrigin: (3, last)),
            TutorialRound(boardFills: r4, trayShapeIndex: 6, dropOrigin: (2, last)),
        ]
    }()
    static var tutorialRoundCount: Int { tutorialRounds.count }

    static func tutorialTarget(round: Int) -> (row: Int, col: Int) {
        let r = max(0, min(round, tutorialRounds.count - 1))
        return tutorialRounds[r].dropOrigin
    }

    /// True while the scripted tutorial owns the tray — suppresses the
    /// standard 3-piece auto-refill in `place()` so the view can drop the
    /// next scripted piece without a flash of random shapes.
    var tutorialActive: Bool = false

    private func tutorialPiece(shapeIndex: Int) -> Piece {
        let shape = PieceLibrary.shapes[shapeIndex]
        return Piece(
            id: UUID(),
            cells: shape.map { GridPos(row: $0.0, col: $0.1) },
            color: .coral
        )
    }

    func seedTutorialBoard(round: Int) {
        let r = max(0, min(round, Self.tutorialRounds.count - 1))
        let spec = Self.tutorialRounds[r]
        grid = Array(repeating: Array(repeating: nil, count: Self.size), count: Self.size)
        for cell in spec.boardFills {
            grid[cell.row][cell.col] = .gold
        }
        tray = [tutorialPiece(shapeIndex: spec.trayShapeIndex), nil, nil]
        tutorialActive = true
        // Every round starts from zero (mirrors Luau's per-round reset):
        // scripted rounds must never accumulate score across reseeds, or the
        // coach outruns DUSK (150) and mints milestones from scripted play.
        score = 0
        streak = 0
        if r == 0 {
            lastClearCount = 0
            isGameOver = false
            clearFlash = []
            popups = []
        }
    }

    /// View calls this the moment a round's clear resolves — refresh the tray
    /// with the NEXT round's piece so it never flashes empty during the
    /// clear-burst window (the round-advance seed follows ~520 ms later).
    func refillTutorialTray(for round: Int) {
        let r = max(0, min(round, Self.tutorialRounds.count - 1))
        tray = [tutorialPiece(shapeIndex: Self.tutorialRounds[r].trayShapeIndex), nil, nil]
    }

    /// View calls this once the whole tutorial ends so the player gets three
    /// real pieces to start actual play. Score resets with the tray — the
    /// last scripted round's points never leak into the real run's depth,
    /// milestones, or best.
    func endTutorialAndRefill() {
        tutorialActive = false
        score = 0
        streak = 0
        tray = (0..<3).map { _ in nextPiece() }
    }

    #if DEBUG
    /// Staging support (TIKI_STACKS_SCORE): redeal the tray from a fresh bag
    /// so stage-gated firefly deals match the seeded score immediately.
    func debugRedealTray() {
        bag = []
        glowingPieceIDs = []
        tray = (0..<3).map { _ in nextPiece() }
    }

    /// Executable proof for placement forgiveness (TIKI_STACKS_SNAPTEST=1):
    /// scenario assertions against the real snappedOrigin on staged boards.
    static func debugValidateSnapping() {
        let g = TikiStacksGame()
        let dot = Piece(id: UUID(), cells: [GridPos(row: 0, col: 0)], color: .teal)
        let line4 = Piece(id: UUID(), cells: (0..<4).map { GridPos(row: 0, col: $0) }, color: .teal)
        var failures = 0
        func expect(_ name: String, _ got: GridPos?, _ want: GridPos?) {
            if got != want {
                failures += 1
                print("[snaptest] FAIL \(name): got \(String(describing: got)) want \(String(describing: want))")
            }
        }
        // Exact legal placement is untouched.
        expect("exact", g.snappedOrigin(for: dot, idealRow: 3.0, idealCol: 3.0), GridPos(row: 3, col: 3))
        // One-cell miss: rounded target occupied, nearest legal neighbor wins.
        g.grid[3][3] = .coral
        expect("miss", g.snappedOrigin(for: dot, idealRow: 3.1, idealCol: 2.9), GridPos(row: 3, col: 2))
        // Everything within radius blocked: no ghost (resting diagonals stay out).
        g.grid[3][2] = .coral; g.grid[3][4] = .coral
        g.grid[2][3] = .coral; g.grid[4][3] = .coral
        expect("blocked", g.snappedOrigin(for: dot, idealRow: 3.0, idealCol: 3.0), nil)
        // Edge overhang within radius clamps in; a full drag past it does not.
        expect("edge", g.snappedOrigin(for: line4, idealRow: 0.0, idealCol: 5.0), GridPos(row: 0, col: 4))
        expect("far-edge", g.snappedOrigin(for: line4, idealRow: 0.0, idealCol: 6.4), nil)
        // Over the tray (well below the board): never ghosts.
        expect("tray", g.snappedOrigin(for: dot, idealRow: 9.5, idealCol: 3.0), nil)
        print("[snaptest] failures=\(failures) \(failures == 0 ? "ALL OK" : "BROKEN")")
    }

    /// Greedy-bot score distributions (TIKI_STACKS_BOT=<n>) — the measured
    /// basis for the depth-threshold (150/400/800/1500) conversation.
    static func debugBotBatch(runs: Int) {
        var scores: [Int] = []
        for _ in 0..<runs {
            let g = TikiStacksGame()
            var moves = 0
            while !g.isGameOver, moves < 4000 {
                var placed = false
                for slot in 0..<3 where !placed {
                    guard let piece = g.tray[slot] else { continue }
                    outer: for r in 0..<size {
                        for k in 0..<size where g.canPlace(piece, at: GridPos(row: r, col: k)) {
                            g.place(slot: slot, at: GridPos(row: r, col: k))
                            placed = true
                            break outer
                        }
                    }
                }
                if !placed { break }
                moves += 1
            }
            scores.append(g.score)
        }
        let s = scores.sorted()
        let mid = s[s.count / 2]
        print("[bot] n=\(s.count) min=\(s.first ?? 0) p25=\(s[s.count / 4]) median=\(mid) p75=\(s[(3 * s.count) / 4]) max=\(s.last ?? 0)")
    }

    /// Staging support (TIKI_STACKS_SWEEP): fills the board except (4,7) and
    /// deals a single dot, so the TIKI_AUTOPLAY driver's next placement is
    /// forced onto the gap and clears every line at once — the only reliable
    /// way to observe a clean sweep on demand.
    func debugSeedSweepBoard() {
        for r in 0..<Self.size {
            for k in 0..<Self.size {
                grid[r][k] = BlockColor.allCases[(r + k) % BlockColor.allCases.count]
            }
        }
        grid[4][7] = nil
        glowingPieceIDs = []
        fireflyCells = []
        tray = [PieceLibrary.piece(shapeIndex: 0), nil, nil]
    }
    #endif

    // MARK: persistence (SwiftData payload via PlayerStore.saveState)

    struct SavePayload: Codable {
        var seenHowTo: Bool
        var score: Int
        var streak: Int
        var board: [[BlockColor?]]?
        var tray: [Piece?]?
        // Firefly state — optionals so pre-progression payloads still decode.
        var fireflies: [GridPos]?
        var glowingTray: [UUID]?
        /// One-shot lose-rule tip shown at the first dangerous fill —
        /// optional so pre-tip payloads still decode.
        var seenDangerTip: Bool?
    }

    func payload(seenHowTo: Bool, seenDangerTip: Bool = false) -> String {
        let live = !isGameOver
        let state = SavePayload(
            seenHowTo: seenHowTo,
            score: score,
            streak: streak,
            board: live ? grid : nil,
            tray: live ? tray : nil,
            fireflies: live ? Array(fireflyCells) : nil,
            glowingTray: live ? tray.compactMap { $0?.id }.filter(glowingPieceIDs.contains) : nil,
            seenDangerTip: seenDangerTip
        )
        guard let data = try? JSONEncoder().encode(state) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Restores a live board+tray from a payload; on any validation failure
    /// the fresh-game state from init stands. Returns the decoded payload so
    /// the view can read seenHowTo.
    @discardableResult
    func restore(from json: String?) -> SavePayload? {
        guard let json, let data = json.data(using: .utf8),
              let state = try? JSONDecoder().decode(SavePayload.self, from: data) else {
            return nil
        }
        if let board = state.board, let savedTray = state.tray,
           board.count == Self.size, board.allSatisfy({ $0.count == Self.size }),
           savedTray.count == 3,
           !savedTray.compactMap({ $0 }).isEmpty,
           savedTray.compactMap({ $0 }).allSatisfy({
               !$0.cells.isEmpty && $0.rows <= Self.size && $0.cols <= Self.size
           }) {
            grid = board
            tray = savedTray
            // Tampered saves near Int.max would trap the next `score +=` /
            // `streak += 1` in a relaunch loop; clamp far above any value a
            // real run can reach.
            score = min(max(0, state.score), 99_999_999)
            streak = min(max(0, state.streak), 9_999)
            fireflyCells = Set(state.fireflies ?? [])
            glowingPieceIDs = Set(state.glowingTray ?? [])
        }
        return state
    }
}
