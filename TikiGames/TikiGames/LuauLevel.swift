import Foundation

/// A single hand-authored or LevelForge-generated Luau level. The engine
/// (`LuauGame`) treats the 7x7 board as a canvas: `mask` marks which cells
/// are playable, `jelly` marks which of those must be cleared to win, and
/// `moves` is bot-solved for the normal difficulty band. `movesHard` is
/// stored for a future mastery lap (no UI in v1). `seed` seeds the level's
/// spawn stream so a run is reproducible; retries salt it further.
struct LuauLevel: Codable, Identifiable, Equatable {
    let id: Int
    /// 49-bit playable-cell mask, row-major (bit `r*7+c`).
    let mask: UInt64
    /// 49 entries, row-major — jelly layers at each cell (0 for masked cells
    /// and for playable cells with no jelly).
    let jelly: [UInt8]
    let colors: Int          // 4...6
    var moves: Int
    var movesHard: Int
    let seed: UInt64
    let archetype: String
    /// Row-major cell indices that start holding cargo — the Ingredients win
    /// condition. Nil for every level that predates it, which is all 200 today.
    ///
    /// `var` and OPTIONAL, both deliberately and both verified rather than
    /// assumed. A `let` with a default is omitted from the synthesized
    /// memberwise init entirely, so it could never be set; a non-optional
    /// `var x: [Int] = []` compiles at the 200 existing call sites but breaks
    /// Codable decoding of saved level JSON that lacks the key. Only
    /// `var x: [Int]?` costs zero edits at both.
    var ingredients: [Int]?
    /// Non-nil marks this a LESSON, not a night: a scripted demonstration of one
    /// mechanic, dropped into the campaign where that mechanic first matters.
    /// The string is what it teaches, for the coach line and for tests.
    ///
    /// A lesson does not count as a night — night numbers are computed over
    /// non-lesson levels only, so inserting one never renumbers the campaign in
    /// the player's head — and a lesson cannot be failed.
    var teaches: String?

    static let size = 7
    static let cellCount = size * size

    var ingredientCells: [Int] { ingredients ?? [] }
    var ingredientTotal: Int { ingredientCells.count }
    var isLesson: Bool { teaches != nil }

    /// True when this column reaches the board's bottom row, which is the only
    /// place cargo can leave. A masked column that stops on a ledge is a dead
    /// end by design — that is what makes the mask shape the puzzle.
    func drains(col: Int) -> Bool { playableRows(col: col).last == Self.size - 1 }

    /// Copy with a different move budget, preserving every other field.
    ///
    /// Exists so nothing re-lists the fields by hand. Two callers used to build
    /// a fresh `LuauLevel(id:mask:jelly:...)` field by field — the evaluator
    /// when staging a budget, and the campaign builder when emitting the level
    /// that actually ships. Any field added to this struct with a default would
    /// simply be dropped by both, silently and without a compile error, and the
    /// campaign one writes the shipped value.
    /// Copy carrying cargo. Used by the campaign's retrofit overlay — see
    /// `LuauLevels.cargoNights` for why the overlay exists at all.
    func with(ingredients cells: [Int]) -> LuauLevel {
        var copy = self
        copy.ingredients = cells
        return copy
    }

    func with(moves newMoves: Int, movesHard newMovesHard: Int? = nil) -> LuauLevel {
        var copy = self
        copy.moves = newMoves
        copy.movesHard = newMovesHard ?? movesHard
        return copy
    }

    var playableCount: Int { mask.nonzeroBitCount }

    var jellyTotal: Int { jelly.reduce(0) { $0 + Int($1) } }

    func isPlayable(col: Int, row: Int) -> Bool {
        guard (0..<Self.size).contains(col), (0..<Self.size).contains(row) else { return false }
        return (mask >> (row * Self.size + col)) & 1 == 1
    }

    func jellyAt(col: Int, row: Int) -> Int {
        guard (0..<Self.size).contains(col), (0..<Self.size).contains(row) else { return 0 }
        return Int(jelly[row * Self.size + col])
    }

    /// Playable rows in the given column, top-to-bottom. Empty if the
    /// column is fully masked. Gravity iterates this list per-column.
    func playableRows(col: Int) -> [Int] {
        (0..<Self.size).filter { isPlayable(col: col, row: $0) }
    }

    /// v1 mask invariant: each column's playable cells form a single
    /// contiguous vertical run. Split columns are forbidden (cells below a
    /// mid-column hole could never refill without diagonal fill).
    var isColumnConvex: Bool {
        for c in 0..<Self.size {
            var seenStart = false
            var seenEnd = false
            for r in 0..<Self.size {
                let playable = isPlayable(col: c, row: r)
                if playable {
                    if seenEnd { return false }
                    seenStart = true
                } else if seenStart {
                    seenEnd = true
                }
            }
        }
        return true
    }

    /// Parse a 7-line ASCII grid into (mask, jelly). Legend:
    /// `#` playable, no jelly · `o` playable, jelly ×1 · `@` playable,
    /// jelly ×2 · `.` masked. Precondition-fails on malformed input — this
    /// is meant for compile-time constants in generated code.
    static func parse(_ ascii: [String]) -> (mask: UInt64, jelly: [UInt8]) {
        precondition(ascii.count == size, "parse: expected \(size) rows, got \(ascii.count)")
        var m: UInt64 = 0
        var j = [UInt8](repeating: 0, count: cellCount)
        for (r, line) in ascii.enumerated() {
            let chars = Array(line)
            precondition(chars.count == size, "parse: row \(r) length \(chars.count) != \(size)")
            for c in 0..<size {
                let bit: UInt64 = (1 as UInt64) << (r * size + c)
                switch chars[c] {
                case "#": m |= bit
                case "o": m |= bit; j[r * size + c] = 1
                case "@": m |= bit; j[r * size + c] = 2
                case ".": break
                default:
                    preconditionFailure("parse: row \(r) col \(c): illegal char '\(chars[c])'")
                }
            }
        }
        return (m, j)
    }
}
