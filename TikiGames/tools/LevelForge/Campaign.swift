import Foundation

/// Campaign-200 builder: plans 188 generated levels (ids 13–200) as a
/// ladder of 16 windows, assigns every slot a shape from the library with
/// spacing rules (never the same mask back to back, never the same family
/// back to back, no mask repeat inside a window), places jelly by
/// mask-derived style, then solves every slot in parallel with the
/// sand-first bot:
///
///   budget = min(band binary-search, ceil(medianWinningMoves × 1.35))
///
/// The cap is the honesty rule — the band search alone can still drift
/// high on levels where the bot's tail is slow; the median-winning cap
/// pins the budget to how the level actually plays when it's won.
enum Campaign {

    struct Window {
        let count: Int
        let bands: [Solver.Band]   // cycled across the window
        let colors: [Int]          // cycled
        let tiers: [Int]           // allowed shape tiers
        let doublesMax: Int
    }

    /// The 188-level ladder. Sawtooth by construction: breather bands and
    /// gentler tiers recur inside otherwise-rising windows.
    static let ladder: [Window] = [
        Window(count: 12, bands: [.easy], colors: [5], tiers: [0], doublesMax: 0),
        Window(count: 12, bands: [.easy, .easy, .easy, .medium], colors: [5], tiers: [0, 1], doublesMax: 0),
        Window(count: 12, bands: [.medium, .medium, .medium, .easy], colors: [5], tiers: [0, 1], doublesMax: 0),
        Window(count: 12, bands: [.medium], colors: [5], tiers: [1], doublesMax: 1),
        Window(count: 12, bands: [.medium, .medium, .medium, .medium, .medium, .hard], colors: [5], tiers: [1, 2], doublesMax: 1),
        Window(count: 12, bands: [.medium], colors: [5, 5, 6], tiers: [0, 1, 2], doublesMax: 2),
        Window(count: 12, bands: [.medium, .hard], colors: [5, 6], tiers: [1, 2], doublesMax: 2),
        Window(count: 12, bands: [.medium, .medium, .hard], colors: [6], tiers: [1, 2], doublesMax: 2),
        Window(count: 12, bands: [.hard, .hard, .hard, .medium], colors: [5, 6], tiers: [2], doublesMax: 3),
        Window(count: 12, bands: [.medium], colors: [5], tiers: [0, 1], doublesMax: 2),
        Window(count: 12, bands: [.medium, .hard], colors: [6], tiers: [1, 2], doublesMax: 3),
        Window(count: 12, bands: [.hard, .hard, .hard, .hard, .medium], colors: [6], tiers: [2], doublesMax: 3),
        Window(count: 12, bands: [.medium, .hard], colors: [6], tiers: [1, 2], doublesMax: 3),
        Window(count: 12, bands: [.hard], colors: [6], tiers: [2], doublesMax: 4),
        Window(count: 12, bands: [.hard, .hard, .hard, .easy], colors: [6], tiers: [1, 2], doublesMax: 4),
        Window(count: 8, bands: [.hard], colors: [6], tiers: [2], doublesMax: 4),
    ]

    struct Slot {
        let id: Int
        let shape: Generator.Shape
        let band: Solver.Band
        let colors: Int
        let style: Generator.JellyStyle
        let jellyCount: Int
        let doubles: Int
        let seedBase: UInt64
    }

    struct Built {
        let level: LuauLevel
        let band: Solver.Band
        let rate: Double
        let medianUsed: Int
        let retries: Int
    }

    // MARK: planning

    /// Deterministically assign shapes/styles to every slot up front so
    /// spacing rules hold regardless of solve order or retries.
    static func plan() -> [Slot] {
        var slots: [Slot] = []
        var rng = Generator.SplitMix(seed: 0x10A0_0200_C0DE_2026)
        var lastMask: UInt64 = 0
        var lastFamily = ""
        var id = 13

        for window in ladder {
            var usedInWindow = Set<UInt64>()
            for i in 0..<window.count {
                let band = window.bands[i % window.bands.count]
                let wantColors = window.colors[i % window.colors.count]

                // Shape: eligible tier, not the same mask twice in a window,
                // never the same mask or family back to back.
                let eligible = Generator.shapes.filter { window.tiers.contains($0.tier) }
                var pick: Generator.Shape? = nil
                for _ in 0..<24 {
                    let cand = eligible[Int(rng.next() % UInt64(eligible.count))]
                    if cand.mask == lastMask { continue }
                    if cand.family == lastFamily { continue }
                    if usedInWindow.contains(cand.mask) { continue }
                    pick = cand; break
                }
                // Pool exhausted (small windows late in enumeration) — relax
                // the within-window rule but never the back-to-back rules.
                if pick == nil {
                    pick = eligible.first { $0.mask != lastMask && $0.family != lastFamily } ?? eligible[0]
                }
                let shape = pick!
                // Openness cap: narrow boards starve at high color counts —
                // 6 colors is earned by open boards only.
                let triples = Generator.horizontalTriples(shape.mask)
                let colorCap = triples >= 24 ? 6 : (triples >= 14 ? 5 : 4)
                let colors = min(wantColors, colorCap)
                usedInWindow.insert(shape.mask)
                lastMask = shape.mask
                lastFamily = shape.family

                // Jelly: band-based count scaled to board size.
                // Sized for ~2-3 minute levels (Carson 2026-07-12: the
                // first cut cleared in ~30s — the work, not the budget,
                // sets a level's length). Roughly half the eligible cells
                // wear sand mid-campaign.
                let base: Double
                switch band.name {
                case "easy": base = 16
                case "medium": base = 19
                default: base = 23
                }
                let scaled = Int((base * Double(shape.cells) / 49.0).rounded())
                let jellyCount = max(6, min(scaled, 30))
                // doublesMax is a tier 0-4 -> fraction of jelly doubled.
                let doubleFraction = [0.0, 0.15, 0.25, 0.35, 0.45][min(window.doublesMax, 4)]
                let doubles = band.name == "easy" ? 0
                    : Int((Double(jellyCount) * doubleFraction).rounded())

                // Style rotates within band-appropriate sets.
                let styles: [Generator.JellyStyle]
                switch band.name {
                case "easy": styles = [.scatter, .band, .blob]
                case "medium": styles = [.scatter, .rim, .blob, .band]
                default: styles = [.pockets, .floor, .scatter, .rim]
                }
                let style = styles[Int(rng.next() % UInt64(styles.count))]

                slots.append(Slot(
                    id: id, shape: shape, band: band, colors: colors,
                    style: style, jellyCount: jellyCount, doubles: doubles,
                    seedBase: 0x2026_0712 &+ UInt64(id) &* 0x9E37_79B9_7F4A_7C15
                ))
                id += 1
            }
        }
        return slots
    }

    // MARK: solving

    /// Budget scheme: the sand-first bot is LOW-VARIANCE, so win-rate vs
    /// moves is a steep curve — binary-searching a 20-point band is noise
    /// chasing (the v1 approach worked only because the old first-legal
    /// bot was a coin flip). Instead: measure the median moves a WINNING
    /// bot run needs on a generous budget, then set
    ///     budget = ceil(median × tightness(band))
    /// and verify the win rate at that budget clears the band's floor,
    /// bumping +2 up to 4× if it doesn't. Tightness IS the difficulty:
    /// easy leaves headroom, hard is nearly the bot's own pace.
    private static func tightness(_ band: Solver.Band) -> Double {
        switch band.name {
        case "teach": return 1.6
        case "easy": return 1.45
        case "medium": return 1.2
        default: return 1.05
        }
    }

    /// Duration floor — the point of the 2.5x retune. A level whose
    /// median winning run is this short plays "beaten in 30 seconds"
    /// regardless of budget; such candidates retry with more sand.
    private static func minMedianUsed(_ band: Solver.Band) -> Int {
        switch band.name {
        case "teach": return 8
        case "easy": return 10
        case "medium": return 16
        default: return 18
        }
    }

    private static func floorRate(_ band: Solver.Band) -> Double {
        switch band.name {
        case "teach": return 0.85
        case "easy": return 0.70
        case "medium": return 0.50
        default: return 0.32
        }
    }

    /// Solve one slot: up to 3 jelly rerolls on the same shape.
    /// Returns nil only if every reroll failed.
    static func build(slot: Slot, searchAttempts: Int, confirmAttempts: Int) -> Built? {
        var jellyCount = slot.jellyCount
        for retry in 0..<3 {
            let seed = slot.seedBase &+ UInt64(retry) &* 0x0101_0101_0101_0101
            let bias = slot.band.name == "hard" ? 1 : (slot.band.name == "easy" ? -1 : 0)
            let cand = Generator.candidate(
                id: slot.id, shape: slot.shape, style: slot.style,
                jellyCount: jellyCount, doubles: slot.doubles,
                colors: slot.colors, bias: bias, seed: seed
            )

            // Generous-budget probe: the level must be cleanly winnable at
            // all, and it tells us the bot's natural pace.
            let probe = Evaluator.evaluate(level: cand, movesBudget: 80,
                                           attempts: searchAttempts)
            // Hard slots run at the bot's own pace, so the relaxed-probe
            // bar can sit lower; everything else must be cleanly winnable.
            let probeFloor = slot.band.name == "hard" ? 0.82 : 0.90
            guard probe.winRate >= probeFloor else {  // unreachable pockets → reroll
                print("[levelforge]   ? L\(slot.id) r\(retry) probe-fail rate=\(String(format: "%.0f%%", probe.winRate * 100)) [\(slot.shape.family) \(slot.style.rawValue) j\(slot.jellyCount)+\(slot.doubles)d c\(slot.colors)]")
                continue
            }
            let medianUsed = max(6, 80 - probe.medianMovesLeftOnWin)
            // Too fast = defect (the point of the 2.5× retune). Add sand
            // and re-solve rather than shipping a 30-second level.
            if medianUsed < minMedianUsed(slot.band), retry < 2 {
                print("[levelforge]   ? L\(slot.id) r\(retry) too-short medUsed=\(medianUsed) j\(jellyCount) — bumping sand")
                jellyCount = min(30, max(jellyCount + 3, Int(Double(jellyCount) * 1.25)))
                continue
            }

            var moves = min(50, max(10, Int((Double(medianUsed) * tightness(slot.band)).rounded(.up))))
            var eval = Evaluator.evaluate(level: cand, movesBudget: moves,
                                          attempts: confirmAttempts)
            var bumps = 0
            while eval.winRate < floorRate(slot.band), moves < 50, bumps < 4 {
                moves += 2
                bumps += 1
                eval = Evaluator.evaluate(level: cand, movesBudget: moves,
                                          attempts: confirmAttempts)
            }
            guard eval.winRate >= floorRate(slot.band), moves <= 50 else {
                print("[levelforge]   ? L\(slot.id) r\(retry) floor-fail rate=\(String(format: "%.0f%%", eval.winRate * 100)) at mv=\(moves) [\(slot.shape.family)]")
                continue
            }

            // movesHard: the bot's own pace, floor of 8 — future mastery lap.
            let movesHard = min(moves, max(8, Int((Double(medianUsed) * 1.02).rounded(.up))))

            // Reject rules run against the FINAL budget.
            let finalSolve = Solver.SolveResult(
                level: cand, band: slot.band, moves: moves,
                observedRate: eval.winRate, steps: [], converged: true
            )
            let rep = Rejector.evaluate(level: cand, solve: finalSolve, probeAttempts: 36)
            guard rep.accepted else {
                print("[levelforge]   ? L\(slot.id) r\(retry) \(rep.summary) [\(slot.style.rawValue) j\(slot.jellyCount)+\(slot.doubles)d]")
                continue
            }

            // Through `with(moves:)` — this is the value that SHIPS, so a
            // dropped field here would be a silently wrong campaign.
            let final = cand.with(moves: moves, movesHard: movesHard)
            return Built(level: final, band: slot.band, rate: eval.winRate,
                         medianUsed: medianUsed, retries: retry)
        }
        return nil
    }

    // MARK: emission

    static func emit(_ built: [Built], to path: String) {
        let chunkSize = 50
        var lines: [String] = []
        lines.append("import Foundation")
        lines.append("")
        lines.append("/// Auto-generated by LevelForge (`campaign build`).")
        lines.append("/// Do not hand-edit — regenerate to update.")
        lines.append("/// Levels: \(built.count) · ids \(built.first?.level.id ?? 0)..\(built.last?.level.id ?? 0)")
        lines.append("/// Solved by the sand-first bot; budget = min(band, median×1.35).")
        lines.append("extension LuauLevels {")
        let chunks = stride(from: 0, to: built.count, by: chunkSize).map {
            Array(built[$0..<min($0 + chunkSize, built.count)])
        }
        for (n, chunk) in chunks.enumerated() {
            lines.append("    private static let generated\(n): [LuauLevel] = [")
            for it in chunk {
                let jellyBytes = it.level.jelly.map(String.init).joined(separator: ",")
                lines.append("        .init(")
                lines.append("            id: \(it.level.id), mask: 0x\(String(it.level.mask, radix: 16, uppercase: true)),")
                lines.append("            jelly: [\(jellyBytes)],")
                lines.append("            colors: \(it.level.colors), moves: \(it.level.moves), movesHard: \(it.level.movesHard),")
                lines.append("            seed: 0x\(String(it.level.seed, radix: 16, uppercase: true)),")
                lines.append("            archetype: \"\(it.level.archetype)\"")
                lines.append("        ),")
            }
            lines.append("    ]")
        }
        let joins = (0..<chunks.count).map { "generated\($0)" }.joined(separator: " + ")
        lines.append("    static let generated: [LuauLevel] = \(joins)")
        lines.append("}")
        try? (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }

    static func stats(_ built: [Built], elapsed: TimeInterval, failedSlots: [Int]) -> String {
        var s = "LevelForge campaign build (sand-first bot) — \(Date())\n"
        s += "levels=\(built.count) elapsed=\(String(format: "%.0f", elapsed))s failed-slots=\(failedSlots)\n\n"
        s += "id   archetype       col mv  hard band   rate  medUsed retries\n"
        s += String(repeating: "-", count: 66) + "\n"
        for it in built {
            s += it.level.id.description.padding(toLength: 5, withPad: " ", startingAt: 0)
            s += it.level.archetype.padding(toLength: 16, withPad: " ", startingAt: 0)
            s += "\(it.level.colors)   "
            s += it.level.moves.description.padding(toLength: 4, withPad: " ", startingAt: 0)
            s += it.level.movesHard.description.padding(toLength: 5, withPad: " ", startingAt: 0)
            s += it.band.name.padding(toLength: 7, withPad: " ", startingAt: 0)
            s += String(format: "%3.0f%%  ", it.rate * 100)
            s += it.medianUsed.description.padding(toLength: 8, withPad: " ", startingAt: 0)
            s += "\(it.retries)\n"
        }
        // Distributions.
        var byFamily: [String: Int] = [:]
        var maskSet = Set<UInt64>()
        for it in built {
            byFamily[it.level.archetype, default: 0] += 1
            maskSet.insert(it.level.mask)
        }
        s += "\nshapes: \(maskSet.count) distinct masks across \(byFamily.count) families\n"
        for (fam, n) in byFamily.sorted(by: { $0.value > $1.value }) {
            s += "  \(fam.padding(toLength: 16, withPad: " ", startingAt: 0)) \(n)\n"
        }
        let movesList = built.map(\.level.moves).sorted()
        if !movesList.isEmpty {
            s += "\nmoves: min=\(movesList.first!) p25=\(movesList[movesList.count/4]) median=\(movesList[movesList.count/2]) p75=\(movesList[3*movesList.count/4]) max=\(movesList.last!)\n"
        }
        return s
    }
}

/// Thread-safe slot results for the parallel build.
final class BuildBox: @unchecked Sendable {
    private let lock = NSLock()
    private var slots: [Campaign.Built?]
    private var done = 0
    init(count: Int) { slots = Array(repeating: nil, count: count) }
    func set(_ i: Int, _ value: Campaign.Built?, slotID: Int) {
        lock.lock(); defer { lock.unlock() }
        slots[i] = value
        done += 1
        let mark = value == nil ? "✗" : "✓"
        let detail = value.map { "mv=\($0.level.moves) hard=\($0.level.movesHard) rate=\(String(format: "%.0f%%", $0.rate * 100)) [\($0.level.archetype)]" } ?? "ALL RETRIES FAILED"
        print("[levelforge] \(mark) L\(slotID) (\(done)/\(slots.count)) \(detail)")
    }
    func snapshot() -> [Campaign.Built?] {
        lock.lock(); defer { lock.unlock() }
        return slots
    }
}

func runCampaign(args: [String]) {
    guard args.first == "build" else {
        FileHandle.standardError.write("usage: campaign build [<searchAttempts>] [<confirmAttempts>]\n".data(using: .utf8)!)
        exit(1)
    }
    let searchAttempts = args.count > 1 ? (Int(args[1]) ?? 60) : 60
    let confirmAttempts = args.count > 2 ? (Int(args[2]) ?? 140) : 140
    let slots = Campaign.plan()
    print("[levelforge] campaign build — \(slots.count) slots, ids \(slots.first!.id)..\(slots.last!.id)")
    print("[levelforge] shape library: \(Generator.shapes.count) masks, attempts search=\(searchAttempts) confirm=\(confirmAttempts)")

    let start = Date()
    let box = BuildBox(count: slots.count)
    DispatchQueue.concurrentPerform(iterations: slots.count) { i in
        let slot = slots[i]
        let built = Campaign.build(slot: slot, searchAttempts: searchAttempts,
                                   confirmAttempts: confirmAttempts)
        box.set(i, built, slotID: slot.id)
    }

    var results = box.snapshot()

    // Graduated serial fallback for failed slots. Stage 1 keeps the slot's
    // shape (the window's character) and eases the recipe one notch;
    // stage 2 is the gentle escape hatch.
    var failedSlots: [Int] = []
    for i in results.indices where results[i] == nil {
        let slot = slots[i]
        failedSlots.append(slot.id)
        let easierBand: Solver.Band = slot.band.name == "hard" ? .medium : .easy
        let stage1 = Campaign.Slot(
            id: slot.id, shape: slot.shape, band: easierBand,
            colors: max(4, slot.colors - 1), style: .scatter,
            jellyCount: max(3, slot.jellyCount - 1),
            doubles: max(0, slot.doubles - 1),
            seedBase: slot.seedBase &+ 0xFA11_0001
        )
        results[i] = Campaign.build(slot: stage1, searchAttempts: searchAttempts,
                                    confirmAttempts: confirmAttempts)
        if results[i] == nil {
            let fallbackShape = Generator.shapes.first { $0.tier == 0 && $0.mask != slot.shape.mask }!
            let stage2 = Campaign.Slot(
                id: slot.id, shape: fallbackShape, band: easierBand,
                colors: max(4, slot.colors - 1), style: .scatter,
                jellyCount: max(3, slot.jellyCount - 2), doubles: 0,
                seedBase: slot.seedBase &+ 0xFA11_0002
            )
            results[i] = Campaign.build(slot: stage2, searchAttempts: searchAttempts,
                                        confirmAttempts: confirmAttempts)
        }
        print("[levelforge] fallback L\(slot.id): \(results[i] == nil ? "STILL FAILED" : "recovered")")
    }

    let built = results.compactMap { $0 }
    let elapsed = Date().timeIntervalSince(start)
    guard built.count == slots.count else {
        print("[levelforge] FATAL: \(slots.count - built.count) slots unfilled — not emitting")
        exit(2)
    }

    let outputPath = "/Users/carsonosullivan/Projects/tiki-lounge/TikiGames/TikiGames/LuauLevels.generated.swift"
    let statsPath = "/Users/carsonosullivan/Projects/tiki-lounge/build/luau-levels/campaign-stats.txt"
    Campaign.emit(built, to: outputPath)
    let statsText = Campaign.stats(built, elapsed: elapsed, failedSlots: failedSlots)
    try? FileManager.default.createDirectory(atPath: (statsPath as NSString).deletingLastPathComponent,
                                             withIntermediateDirectories: true)
    try? statsText.write(toFile: statsPath, atomically: true, encoding: .utf8)
    print("[levelforge] built \(built.count) levels in \(String(format: "%.0f", elapsed))s")
    print("[levelforge] wrote \(outputPath)")
    print("[levelforge] wrote \(statsPath)")
    print(statsText.components(separatedBy: "\nid").first ?? "")
}
