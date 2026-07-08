import Foundation

/// A named Star Battle solving technique, surfaced with a hint so the player can learn
/// *why* a move works — not just where. `lookFor` is a one-line nudge (shown before the
/// square is revealed); `info` is the fuller description shown in the tap-through popup.
nonisolated struct HintTechnique: Equatable {
    let name: String
    let lookFor: String
    let info: String
}

/// The result of asking for a hint.
struct Hint {
    enum Outcome {
        case place      // a cell is logically forced — place it
        case mistake    // the player has a piece that isn't in the solution
        case stuck      // no certain move from the current position
        case solved     // the board is already complete
    }

    let outcome: Outcome
    /// The cell to act on (only for `.place`).
    let position: GridPosition?
    /// Whether `.place` means "put a cherry here" (true) or "this square is empty" (false).
    let placesStar: Bool
    /// A human-readable explanation shown to the player.
    let message: String
    /// The named technique this move uses, when it comes from one (nil for a mistake,
    /// a solved board, or a last-resort reveal).
    var technique: HintTechnique? = nil
}

/// Works out the next logically-forced move from the current board, with an
/// explanation. It seeds a constraint model from the player's *confirmed cherries*
/// only (their dots are treated as notes, so a stray note never produces a wrong
/// hint), then replays sound Star Battle deductions one step at a time and returns
/// the first determination the player hasn't already made.
///
/// The techniques mirror the ones the generator's `LogicBoard` uses to decide a
/// puzzle is solvable without guessing, so a hint exists whenever the puzzle does
/// not require a guess.
enum HintEngine {

    /// `item` / `items` are the singular / plural names of the current piece (e.g.
    /// "star" / "stars"), so explanations match the icon the player has chosen.
    static func nextHint(puzzle: Puzzle, marks: [[CellMark]],
                         item: String = "cherry", items: String = "cherries") -> Hint {
        let engine = Engine(puzzle: puzzle, item: item, items: items)
        return engine.nextHint(marks: marks)
    }

    private final class Engine {
        let n: Int
        let quota: Int
        let solution: Set<GridPosition>
        let rows: [[Int]]
        let cols: [[Int]]
        let regions: [[Int]]
        let units: [[Int]]
        /// Piece name, singular and plural, plus a capitalised plural for sentence starts.
        let item: String
        let items: String
        var itemsCap: String { items.prefix(1).uppercased() + items.dropFirst() }

        /// 0 = unknown, 1 = cherry, 2 = empty.
        var state: [Int8]

        /// The size of the coloured region each cell belongs to, so hints can prefer a
        /// move inside a small (more constraining, more helpful) region.
        let regionSize: [Int]

        private static let king = [(-1, -1), (-1, 0), (-1, 1), (0, -1),
                                   (0, 1), (1, -1), (1, 0), (1, 1)]

        init(puzzle: Puzzle, item: String, items: String) {
            self.item = item
            self.items = items
            n = puzzle.size
            quota = puzzle.starsPerUnit
            solution = puzzle.solution
            let regionCount = (puzzle.regions.flatMap { $0 }.max() ?? -1) + 1

            var rows = Array(repeating: [Int](), count: n)
            var cols = Array(repeating: [Int](), count: n)
            var regs = Array(repeating: [Int](), count: max(regionCount, 1))
            for r in 0..<n {
                for c in 0..<n {
                    let i = r * n + c
                    rows[r].append(i)
                    cols[c].append(i)
                    regs[puzzle.regions[r][c]].append(i)
                }
            }
            self.rows = rows
            self.cols = cols
            self.regions = regs
            self.units = rows + cols + regs
            self.state = [Int8](repeating: 0, count: n * n)

            var sizes = [Int](repeating: 0, count: n * n)
            for regCells in regs {
                for cell in regCells { sizes[cell] = regCells.count }
            }
            self.regionSize = sizes
        }

        func nextHint(marks: [[CellMark]]) -> Hint {
            // 1. Validate the player's cherries against the known solution.
            for r in 0..<n {
                for c in 0..<n where marks[r][c] == .star {
                    if !solution.contains(GridPosition(row: r, col: c)) {
                        return Hint(outcome: .mistake, position: GridPosition(row: r, col: c),
                                    placesStar: false,
                                    message: "The \(item) at row \(r + 1), column \(c + 1) isn't part of the solution. Tap Undo or remove it, then try again.")
                    }
                }
            }

            // 2. Seed only the confirmed cherries; deductions flow from those.
            for r in 0..<n {
                for c in 0..<n where marks[r][c] == .star {
                    state[r * n + c] = 1
                }
            }

            // 3. Replay sound deductions one at a time. The first determination the
            //    player hasn't already made (as a cherry or a dot) is the hint.
            while true {
                guard let step = nextDetermination() else { break }
                state[step.cell] = step.star ? 1 : 2
                let pos = GridPosition(row: step.cell / n, col: step.cell % n)
                let mark = marks[pos.row][pos.col]
                if step.star && mark != .star {
                    return Hint(outcome: .place, position: pos, placesStar: true, message: step.reason,
                                technique: step.technique)
                }
                if !step.star && mark != .dot && mark != .star {
                    return Hint(outcome: .place, position: pos, placesStar: false, message: step.reason,
                                technique: step.technique)
                }
                // Otherwise the player already knows this — keep deducing.
            }

            // 4. Nothing more is forced by pure logic. This is rare — the generator
            //    strongly favours logically-solvable boards — but as a safety net we
            //    reveal a correct cell from the known solution so the player is never
            //    left truly stuck (and never sees a discouraging "no move" message).
            let placed = state.lazy.filter { $0 == 1 }.count
            if placed >= quota * n {
                return Hint(outcome: .solved, position: nil, placesStar: false,
                            message: "Every \(item) is already placed — you're done!")
            }
            for r in 0..<n {
                for c in 0..<n where solution.contains(GridPosition(row: r, col: c)) {
                    if state[r * n + c] != 1 {
                        return Hint(outcome: .place, position: GridPosition(row: r, col: c),
                                    placesStar: true,
                                    message: "This is a tricky spot — here's \(itemArticle) \(item) from the solution to keep you moving.")
                    }
                }
            }
            return Hint(outcome: .stuck, position: nil, placesStar: false,
                        message: "There's no certain move from here.")
        }

        private struct Step { let cell: Int; let star: Bool; let reason: String; let technique: HintTechnique }

        /// "a"/"an" for the piece noun (e.g. "an alien"), and a sentence-start variant.
        private var itemArticle: String {
            let vowels: Set<Character> = ["a", "e", "i", "o"]
            return vowels.contains(item.lowercased().first ?? " ") ? "an" : "a"
        }
        private var itemArticleCap: String { itemArticle.capitalized }
        private var anItem: String { "\(itemArticle) \(item)" }

        /// The named techniques, described in terms of the player's chosen piece.
        enum TechniqueKind { case onlySpots, forcedSquare, lineComplete, noTouching, lookAhead }

        private func tech(_ kind: TechniqueKind) -> HintTechnique {
            switch kind {
            case .onlySpots:
                return HintTechnique(
                    name: "Only Spots Left",
                    lookFor: "A row, column or region has exactly as many empty squares left as \(items) it still needs.",
                    info: "When a row, column or region has just as many open squares as \(items) it still needs, every one of those squares must hold \(anItem) — there's nowhere else for them to go.")
            case .forcedSquare:
                return HintTechnique(
                    name: "Forced Square",
                    lookFor: "Try the opposite here and a row, column or region can no longer be completed.",
                    info: "Test a square by assuming the opposite. If making it empty (or making it \(anItem)) leaves some row, column or region unable to reach its count, then the other value is forced.")
            case .lineComplete:
                return HintTechnique(
                    name: "Line Complete",
                    lookFor: "A row, column or region already holds all of its \(items).",
                    info: "Once a row, column or region already contains all the \(items) it needs, every remaining square in it must be empty.")
            case .noTouching:
                return HintTechnique(
                    name: "No Touching",
                    lookFor: "\(itemsCap) can never sit next to each other — not even diagonally.",
                    info: "Two \(items) may never touch, so every one of the eight squares around \(anItem), including the diagonals, must be empty.")
            case .lookAhead:
                return HintTechnique(
                    name: "Look Ahead",
                    lookFor: "Follow the forced moves a few steps on and one option hits a dead end.",
                    info: "Assume a value for a square and play out the moves it forces. If that runs into an impossible board a few steps later, the assumption was wrong — so the other value is certain. This is the technique the hardest boards lean on.")
            }
        }

        /// Finds one new determination using sound techniques. Every move below is a
        /// sound single-cell deduction; among them we hand back the *most helpful* one —
        /// preferring placing a cherry, then a move inside the smallest region — since
        /// those advance the solve most. Deep (Hard-board) techniques are a last resort.
        private func nextDetermination() -> Step? {
            var cherryMoves: [Step] = []
            var dotMoves: [Step] = []

            // 1. Exact fit → cherry: a unit's open squares exactly equal the cherries it still needs.
            for (idx, unit) in units.enumerated() {
                let (stars, open) = tally(unit)
                let needed = quota - stars
                if needed > 0 && open.count == needed, let cell = open.first {
                    cherryMoves.append(Step(cell: cell, star: true,
                                reason: "\(unitName(idx)) still needs \(needed) \(needed == 1 ? item : items) and has exactly that many open squares left — so this square must be \(itemArticle) \(item).",
                                technique: tech(.onlySpots)))
                }
            }
            // 2. Contradiction → cherry: leaving this square empty would break a unit.
            for i in 0..<state.count where state[i] == 0 {
                if contradicts(setting: i, to: 2) {
                    let pos = GridPosition(row: i / n, col: i % n)
                    cherryMoves.append(Step(cell: i, star: true,
                                reason: "Row \(pos.row + 1), column \(pos.col + 1) has to be \(itemArticle) \(item) — leaving it empty would make a row, column or region impossible to complete.",
                                technique: tech(.forcedSquare)))
                }
            }
            // 3. Unit already satisfied → empty.
            for (idx, unit) in units.enumerated() {
                let (stars, open) = tally(unit)
                if stars == quota, let cell = open.first {
                    dotMoves.append(Step(cell: cell, star: false,
                                reason: "\(unitName(idx)) already has its \(quota) \(items), so this square can't be one.",
                                technique: tech(.lineComplete)))
                }
            }
            // 4. Touches a cherry → empty.
            for i in 0..<state.count where state[i] == 1 {
                let r = i / n, c = i % n
                for (dr, dc) in Self.king {
                    let nr = r + dr, nc = c + dc
                    guard nr >= 0, nr < n, nc >= 0, nc < n else { continue }
                    let j = nr * n + nc
                    if state[j] == 0 {
                        dotMoves.append(Step(cell: j, star: false,
                                    reason: "\(itemsCap) can never touch — this square sits next to the \(item) at row \(r + 1), column \(c + 1), so it must be empty.",
                                    technique: tech(.noTouching)))
                    }
                }
            }
            // 5. Contradiction → empty: a cherry here would break a unit.
            for i in 0..<state.count where state[i] == 0 {
                if contradicts(setting: i, to: 1) {
                    let pos = GridPosition(row: i / n, col: i % n)
                    dotMoves.append(Step(cell: i, star: false,
                                reason: "\(itemArticleCap) \(item) at row \(pos.row + 1), column \(pos.col + 1) would break a row, column or region, so this square must be empty.",
                                technique: tech(.forcedSquare)))
                }
            }

            // Most helpful first: a cherry (in the smallest region), else a dot that
            // fills in part of a small region.
            if let best = cherryMoves.min(by: { regionSize[$0.cell] < regionSize[$1.cell] }) { return best }
            if let best = dotMoves.min(by: { regionSize[$0.cell] < regionSize[$1.cell] }) { return best }

            // 6. Deep (nested) contradiction → cherry: leaving it empty leads, after a
            //    few more forced steps, to an impossible board. (Hard boards.)
            for i in 0..<state.count where state[i] == 0 {
                if contradictsDeep(setting: i, to: 2) {
                    let pos = GridPosition(row: i / n, col: i % n)
                    return Step(cell: i, star: true,
                                reason: "This one needs a deeper look: marking row \(pos.row + 1), column \(pos.col + 1) empty forces a contradiction a few steps on — so it must be \(itemArticle) \(item).",
                                technique: tech(.lookAhead))
                }
            }
            // 7. Deep (nested) contradiction → empty.
            for i in 0..<state.count where state[i] == 0 {
                if contradictsDeep(setting: i, to: 1) {
                    let pos = GridPosition(row: i / n, col: i % n)
                    return Step(cell: i, star: false,
                                reason: "This one needs a deeper look: \(itemArticle) \(item) at row \(pos.row + 1), column \(pos.col + 1) forces a contradiction a few steps on — so it must be empty.",
                                technique: tech(.lookAhead))
                }
            }
            return nil
        }

        /// Depth-2 contradiction: assume `value`, propagate, then apply the single-cell
        /// contradiction closure to the hypothetical; true if any of it breaks.
        private func contradictsDeep(setting i: Int, to value: Int8) -> Bool {
            var s = state
            s[i] = value
            if !propagate(&s) { return true }
            return !resolveSingleCell(&s)
        }

        /// Applies every forced single-cell-contradiction deduction to `s`.
        /// Returns false if the board becomes impossible.
        private func resolveSingleCell(_ s: inout [Int8]) -> Bool {
            while true {
                var progressed = false
                for j in 0..<s.count where s[j] == 0 {
                    var t1 = s; t1[j] = 1
                    if !propagate(&t1) {            // a cherry here is impossible
                        s[j] = 2
                        if !propagate(&s) { return false }
                        progressed = true; continue
                    }
                    var t2 = s; t2[j] = 2
                    if !propagate(&t2) {            // leaving it empty is impossible
                        s[j] = 1
                        if !propagate(&s) { return false }
                        progressed = true; continue
                    }
                }
                if !progressed { break }
            }
            return true
        }

        /// Cherries placed and the list of still-open cells in a unit.
        private func tally(_ unit: [Int]) -> (stars: Int, open: [Int]) {
            var stars = 0
            var open: [Int] = []
            for j in unit {
                if state[j] == 1 { stars += 1 } else if state[j] == 0 { open.append(j) }
            }
            return (stars, open)
        }

        /// Whether forcing cell `i` to `value` leads to an immediate contradiction
        /// under simple propagation (king elimination + per-unit counting).
        private func contradicts(setting i: Int, to value: Int8) -> Bool {
            var s = state
            s[i] = value
            return !propagate(&s)
        }

        /// Forced-move propagation to a fixpoint. Returns false on contradiction.
        private func propagate(_ s: inout [Int8]) -> Bool {
            var changed = true
            while changed {
                changed = false
                for i in 0..<s.count where s[i] == 1 {
                    let r = i / n, c = i % n
                    for (dr, dc) in Self.king {
                        let nr = r + dr, nc = c + dc
                        guard nr >= 0, nr < n, nc >= 0, nc < n else { continue }
                        let j = nr * n + nc
                        if s[j] == 1 { return false }      // two cherries touch
                        if s[j] == 0 { s[j] = 2; changed = true }
                    }
                }
                for unit in units {
                    var stars = 0, unknown = 0
                    for j in unit {
                        if s[j] == 1 { stars += 1 } else if s[j] == 0 { unknown += 1 }
                    }
                    if stars > quota || stars + unknown < quota { return false }
                    if unknown > 0 && stars == quota {
                        for j in unit where s[j] == 0 { s[j] = 2 }
                        changed = true
                    } else if unknown > 0 && stars + unknown == quota {
                        for j in unit where s[j] == 0 { s[j] = 1 }
                        changed = true
                    }
                }
            }
            return true
        }

        /// A friendly name for unit index `idx` (rows, then columns, then regions).
        private func unitName(_ idx: Int) -> String {
            if idx < n { return "Row \(idx + 1)" }
            if idx < 2 * n { return "Column \(idx - n + 1)" }
            return "This region"
        }
    }
}
