import Foundation

/// Generates Star Battle puzzles with a guaranteed-unique solution.
///
/// The pipeline is:
///   1. `randomSolution` — place a valid star pattern (N per row/column, no two
///      stars touching, even diagonally) using randomized backtracking.
///   2. `growRegions` — pair the stars and grow connected, irregular regions
///      outward so each region contains exactly N of the solution's stars.
///   3. `buildPuzzle` refinement loop — random region layouts almost always admit
///      several solutions, so we repeatedly solve the layout and, while an
///      alternate solution exists, nudge a region boundary to destroy it (see
///      `killAlternate`). Attacking a *random* alternate avoids cycles. This
///      converges on a layout whose only solution is the one we started with.
/// The phase a board generation is currently in, surfaced so the UI can show what's
/// happening during the (occasionally long) build rather than a bare spinner.
nonisolated enum GenerationStage: Sendable {
    case placing    // laying down a valid cherry pattern
    case shaping    // growing the coloured regions
    case checking   // forcing the layout to a single solution
    case tuning     // confirming it hits the requested difficulty
}

nonisolated enum PuzzleGenerator {

    /// Async entry point so generation runs off the main actor. `onProgress` (if given)
    /// is called from the background with the current attempt number and phase.
    static func generate(size: Int = 10, stars: Int = 2,
                         difficulty: Difficulty = .easy,
                         onProgress: (@Sendable (Int, GenerationStage) -> Void)? = nil) async -> Puzzle {
        await Task.detached(priority: .userInitiated) {
            var puzzle = buildPuzzle(size: size, stars: stars, difficulty: difficulty, onProgress: onProgress)
            puzzle.difficulty = difficulty
            return puzzle
        }.value
    }

    /// The fewest times a board must *force* the depth-2 (nested) technique before we
    /// call it Hard. Below this it's a Medium with a few spicy moments; at zero it's
    /// Easy. Lowered from 6 to 5 so Medium boards force the hard technique at most four
    /// times (a little gentler) — a small shift that barely changes how common Medium
    /// boards are, so generation stays as fast as before.
    static let hardMinTier2 = 5

    /// Medium is biased toward its gentle end *and* toward simple shapes. A board that
    /// forces the depth-2 technique at most `mediumLowTier2` times AND has at least
    /// `mediumMinSmall` small (≤6 cell) regions is taken immediately; otherwise the best
    /// of the first `mediumSampleCap` Medium boards is used — scored to favour more
    /// simple shapes (extra footholds, so usually more than one way forward) and fewer
    /// depth-2 moments — so Medium skews easy without expensive over-searching.
    static let mediumLowTier2 = 2
    static let mediumMinSmall = 4
    static let mediumSampleCap = 4

    /// An Easy board must contain at least this many "simple" regions — ones of
    /// `easySmallRegionMaxCells` cells or fewer. A small region holding two pieces is
    /// very constraining and usually cracks open by single-cell logic, so guaranteeing
    /// several of them keeps Easy boards genuinely gentle.
    static let easyMinSmallRegions = 6
    static let easySmallRegionMaxCells = 6

    /// Counts regions of `maxCells` cells or fewer in a layout.
    static func smallRegionCount(_ regions: [[Int]], size: Int,
                                 maxCells: Int = easySmallRegionMaxCells) -> Int {
        var counts: [Int: Int] = [:]
        for r in 0..<size {
            for c in 0..<size { counts[regions[r][c], default: 0] += 1 }
        }
        return counts.values.filter { $0 <= maxCells }.count
    }

    /// Grades a board by *how often it forces the hard (depth-2) technique* — the peak
    /// technique and its frequency, not the aggregate step count. This is what makes
    /// "Hard" reliably hard: Easy never needs depth-2, Medium needs it occasionally,
    /// and Hard needs it again and again.
    static func band(forProfile p: DifficultyProfile) -> Difficulty {
        if p.tier2Steps == 0 { return .easy }            // pure single-cell logic
        if p.tier2Steps >= hardMinTier2 { return .hard } // forces depth-2 repeatedly
        return .medium                                   // a few depth-2 moments
    }

    /// Computes a board's solve profile, or nil if it isn't solvable within depth-2.
    static func profile(regions: [[Int]], size: Int, stars: Int) -> DifficultyProfile? {
        LogicBoard(regions: regions, size: size, stars: stars).difficultyProfile()
    }

    // MARK: - Top level

    static func buildPuzzle(size: Int = 10, stars: Int = 2,
                            difficulty: Difficulty = .easy,
                            onProgress: (@Sendable (Int, GenerationStage) -> Void)? = nil) -> Puzzle {
        var rng = SystemRandomNumberGenerator()
        var fallback: Puzzle?         // any solvable puzzle, regardless of band
        var nonUniqueFallback: Puzzle?
        var bestMedium: Puzzle?       // best (simplest-shaped, gentlest) Medium board seen
        var bestMediumScore = Int.min
        var mediumSeen = 0

        // A converging layout settles in a few dozen refinement steps, so we cap
        // each attempt well above that and simply restart a stubborn one rather
        // than grinding on it — restarting from a fresh layout is far cheaper than
        // chasing a layout that keeps spawning new alternates.
        let refinementCap = 60

        // We return on the first solvable board whose difficulty matches the target,
        // so the average cost is just the attempts needed to hit one. The high cap
        // only bounds the rare unlucky run; on a miss we fall back to any solvable
        // board (closest difficulty we found). `HintEngine` reveals a correct cell as
        // a final backstop, so "Hint" always has a move.
        for attempt in 0..<500 {
            onProgress?(attempt, .placing)
            guard let solution = randomSolution(size: size, stars: stars, rng: &rng) else {
                continue
            }
            onProgress?(attempt, .shaping)
            var built: [[Int]]?
            // The small-region bias keeps the big 10×10 Easy board gentle. A 5×5 beginner
            // board is already trivial, and biasing it just dumps the leftovers into one
            // oversized region — so let beginner grow naturally balanced instead.
            let preferSmall = difficulty == .easy
            for _ in 0..<8 {
                if let candidate = growRegions(solution: solution, size: size, stars: stars,
                                               rng: &rng, preferSmallRegions: preferSmall) {
                    built = candidate
                    break
                }
            }
            guard var regions = built else { continue }
            var success = false

            onProgress?(attempt, .checking)
            for _ in 0..<refinementCap {
                let solutions = findSolutions(regions: regions, size: size, stars: stars, limit: 6)
                let alternates = solutions.filter { $0 != solution }
                if alternates.isEmpty {
                    success = true
                    break
                }
                var killed = false
                for alternate in alternates.shuffled(using: &rng) {
                    if killAlternate(regions: &regions, target: solution, alternate: alternate,
                                     size: size, rng: &rng) {
                        killed = true
                        break
                    }
                }
                if !killed { break } // Stuck: restart with a fresh layout.
            }

            let puzzle = Puzzle(size: size, starsPerUnit: stars, regions: regions, solution: solution)
            guard success else {
                nonUniqueFallback = puzzle
                continue
            }
            // Grade as cheaply as the target allows. For Easy only a tier-1 solve
            // matters, and it never pays the costly depth-2 grind — important because
            // Easy boards are scarce, so we test many candidates. For Medium/Hard the
            // depth-2 profile is unavoidable (it's what tells them apart), but it stays
            // cheap on the Easy candidates it skips past (those solve at tier 1). Any
            // unique board is a valid fallback, so keep the first one we see.
            onProgress?(attempt, .tuning)
            let board = LogicBoard(regions: regions, size: size, stars: stars)
            if difficulty == .beginner {
                // Beginner just needs to crack open by simple single-cell logic; the
                // small 5×5 / one-star board is gentle by construction.
                if board.tier1Solve() != nil { return puzzle }
                fallback = fallback ?? puzzle
            } else if difficulty == .easy {
                // Require a board that both solves by simple single-cell logic AND has
                // at least `easyMinSmallRegions` little regions. Keep the best near-miss
                // (a tier-1 board) as a fallback for the rare run that never qualifies.
                if board.tier1Solve() != nil {
                    if smallRegionCount(regions, size: size) >= easyMinSmallRegions {
                        return puzzle
                    }
                    fallback = fallback ?? puzzle
                } else {
                    fallback = fallback ?? puzzle
                }
            } else if let profile = board.difficultyProfile() {
                if band(forProfile: profile) == difficulty {
                    if difficulty == .medium {
                        // Prefer gentle boards (few depth-2 moments) that also have
                        // several simple shapes — small regions are extra footholds, so
                        // there's usually more than one logical way forward instead of a
                        // single forced line. Take an ideal board outright; otherwise keep
                        // the best by score and settle after a small sample, so we don't
                        // grind hunting for the very best.
                        let small = smallRegionCount(regions, size: size)
                        if profile.tier2Steps <= mediumLowTier2 && small >= mediumMinSmall {
                            return puzzle
                        }
                        let score = small * 10 - profile.tier2Steps
                        if score > bestMediumScore {
                            bestMediumScore = score
                            bestMedium = puzzle
                        }
                        mediumSeen += 1
                        if mediumSeen >= mediumSampleCap, let bm = bestMedium { return bm }
                    } else {
                        return puzzle
                    }
                } else {
                    fallback = fallback ?? puzzle
                }
            } else {
                fallback = fallback ?? puzzle            // deeper than depth-2, still playable
            }
        }
        return bestMedium ?? fallback ?? nonUniqueFallback
            ?? Puzzle.starters(for: difficulty).randomElement()
            ?? Puzzle.placeholder(size: size, starsPerUnit: stars)
    }

    // MARK: - Random valid solution

    /// Places a valid star pattern using randomized, row-by-row backtracking.
    static func randomSolution(size: Int, stars: Int,
                               rng: inout SystemRandomNumberGenerator) -> Set<GridPosition>? {
        var placement = Array(repeating: [Int](), count: size) // chosen columns per row
        var colCount = Array(repeating: 0, count: size)
        var prevCols: [Int] = []

        // All ways to choose `stars` columns in a row that are mutually
        // non-adjacent, respect the per-column cap, and don't touch the row above.
        func rowCombos() -> [[Int]] {
            var results: [[Int]] = []
            func rec(_ start: Int, _ chosen: [Int]) {
                if chosen.count == stars {
                    results.append(chosen)
                    return
                }
                for c in start..<size {
                    if let last = chosen.last, c - last < 2 { continue }   // no touching within row
                    if colCount[c] >= stars { continue }                   // column already full
                    if prevCols.contains(where: { abs($0 - c) <= 1 }) { continue } // touches row above
                    rec(c + 1, chosen + [c])
                }
            }
            rec(0, [])
            results.shuffle(using: &rng)
            return results
        }

        // Prune if any column can no longer reach its required star count.
        func feasible(afterRow row: Int) -> Bool {
            let remainingRows = size - (row + 1)
            for c in 0..<size where stars - colCount[c] > remainingRows {
                return false
            }
            return true
        }

        func solve(_ row: Int) -> Bool {
            if row == size {
                return colCount.allSatisfy { $0 == stars }
            }
            for combo in rowCombos() {
                for c in combo { colCount[c] += 1 }
                placement[row] = combo
                let savedPrev = prevCols
                prevCols = combo

                if feasible(afterRow: row) && solve(row + 1) { return true }

                prevCols = savedPrev
                for c in combo { colCount[c] -= 1 }
                placement[row] = []
            }
            return false
        }

        guard solve(0) else { return nil }

        var stars0 = Set<GridPosition>()
        for r in 0..<size {
            for c in placement[r] {
                stars0.insert(GridPosition(row: r, col: c))
            }
        }
        return stars0
    }

    // MARK: - Region growth

    private static let orthogonal = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    /// Builds `size` connected regions that tile the grid, each containing exactly
    /// `stars` of the solution's stars. Growth uses a random frontier so regions
    /// come out irregular — which both lowers the initial solution count and leaves
    /// more cells on region boundaries, where they can be moved during refinement.
    ///
    /// Each region's two stars are first joined by a carved path so the region is a
    /// single connected shape, then the leftover cells are filled in. Returns nil if
    /// a connecting path can't be routed (caller retries with a fresh pairing).
    static func growRegions(solution: Set<GridPosition>, size: Int, stars: Int,
                            rng: inout SystemRandomNumberGenerator,
                            preferSmallRegions: Bool = false) -> [[Int]]? {
        // Group the solution's stars into one region per `stars` of them. With one star
        // per region each star is its own seed; with two, pair them by nearest
        // neighbour so a region's stars start out close together.
        var groups: [[GridPosition]]
        if stars <= 1 {
            groups = solution.map { [$0] }
            groups.shuffle(using: &rng)
        } else {
            var remaining = Array(solution)
            remaining.shuffle(using: &rng)
            var pairs: [[GridPosition]] = []
            while remaining.count >= 2 {
                let a = remaining.removeLast()
                var bestIdx = 0
                var bestDist = Int.max
                for (i, b) in remaining.enumerated() {
                    let d = abs(a.row - b.row) + abs(a.col - b.col)
                    if d < bestDist {
                        bestDist = d
                        bestIdx = i
                    }
                }
                let b = remaining.remove(at: bestIdx)
                pairs.append([a, b])
            }
            groups = pairs
        }

        var region = Array(repeating: Array(repeating: -1, count: size), count: size)
        for (id, group) in groups.enumerated() {
            for cell in group { region[cell.row][cell.col] = id }
        }

        // Connect each multi-star region's stars with a path through unclaimed cells so
        // the region is connected from the outset. Single-star regions are already
        // connected. Process in random order; later regions route around carved paths.
        var order = Array(0..<groups.count)
        order.shuffle(using: &rng)
        for id in order where groups[id].count >= 2 {
            guard let path = connectingPath(region: region, from: groups[id][0],
                                            to: groups[id][1], id: id, size: size) else {
                return nil
            }
            for cell in path {
                region[cell.row][cell.col] = id
            }
        }

        // Region sizes so far (just the carved connecting paths).
        var sizeOf = [Int](repeating: 0, count: groups.count)
        var unassigned = 0
        for r in 0..<size {
            for c in 0..<size {
                let id = region[r][c]
                if id == -1 { unassigned += 1 } else { sizeOf[id] += 1 }
            }
        }

        // Easy boards aim for many small regions (3–6 cells): a region holding two
        // stars in just a few cells is very constraining and usually solves by simple
        // single-cell logic. Give the regions whose stars sit closest a small target
        // size and let the rest soak up the remaining cells, then grow toward those
        // targets — so the finished board is dominated by easy little regions.
        var target = sizeOf
        if preferSmallRegions, groups.count > 1 {
            let idsBySize = (0..<groups.count).sorted { sizeOf[$0] < sizeOf[$1] }
            // Aim for more small regions than the minimum we require, so the few that
            // drift larger during refinement still leave enough simple regions behind.
            let smallCount = min(groups.count - 1,
                                 max(easyMinSmallRegions + 2, Int(Double(groups.count) * 0.7)))
            for (rank, id) in idsBySize.enumerated() where rank < smallCount {
                target[id] = max(sizeOf[id], Int.random(in: 3...5, using: &rng))
            }
            let smallSum = idsBySize.prefix(smallCount).reduce(0) { $0 + target[$1] }
            let largeIds = Array(idsBySize.dropFirst(smallCount))
            if !largeIds.isEmpty {
                let remaining = max(0, size * size - smallSum)
                let base = remaining / largeIds.count
                var extra = remaining - base * largeIds.count
                for id in largeIds {
                    target[id] = max(sizeOf[id], base + (extra > 0 ? 1 : 0))
                    if extra > 0 { extra -= 1 }
                }
            }
        }

        while unassigned > 0 {
            // Every unassigned cell that touches at least one assigned cell, paired
            // with the regions it could join.
            var frontier: [(GridPosition, [Int])] = []
            for r in 0..<size {
                for c in 0..<size where region[r][c] == -1 {
                    var adjacent: [Int] = []
                    for (dr, dc) in orthogonal {
                        let nr = r + dr, nc = c + dc
                        if nr >= 0, nr < size, nc >= 0, nc < size, region[nr][nc] != -1 {
                            adjacent.append(region[nr][nc])
                        }
                    }
                    if !adjacent.isEmpty {
                        frontier.append((GridPosition(row: r, col: c), adjacent))
                    }
                }
            }
            guard !frontier.isEmpty else { break }

            let cell: GridPosition
            let chosen: Int
            if preferSmallRegions {
                // Feed each cell to whichever adjacent region is furthest below its
                // target, so the big regions fill first and the small ones stay small.
                // Shuffling first randomises ties, avoiding directional growth.
                frontier.shuffle(using: &rng)
                var best: (cell: GridPosition, id: Int, deficit: Int)?
                for (c, options) in frontier {
                    for id in options {
                        let deficit = target[id] - sizeOf[id]
                        if best == nil || deficit > best!.deficit {
                            best = (c, id, deficit)
                        }
                    }
                }
                guard let pick = best else { break }
                cell = pick.cell
                chosen = pick.id
            } else {
                guard let (c, options) = frontier.randomElement(using: &rng),
                      let pickId = options.randomElement(using: &rng) else { break }
                cell = c
                chosen = pickId
            }
            region[cell.row][cell.col] = chosen
            sizeOf[chosen] += 1
            unassigned -= 1
        }
        return region
    }

    /// Shortest path (BFS) from `from` to `to` travelling only through cells that
    /// are unclaimed or already belong to `id`, so the path never steals another
    /// region's cell. Returns the cells on the path, or nil if none exists.
    private static func connectingPath(region: [[Int]], from: GridPosition, to: GridPosition,
                                       id: Int, size: Int) -> [GridPosition]? {
        var visited: Set<GridPosition> = [from]
        var cameFrom: [GridPosition: GridPosition] = [:]
        var queue = [from]
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            if current == to {
                var path = [current]
                var node = current
                while let prev = cameFrom[node] {
                    path.append(prev)
                    node = prev
                }
                return path
            }
            for (dr, dc) in orthogonal {
                let n = GridPosition(row: current.row + dr, col: current.col + dc)
                guard n.row >= 0, n.row < size, n.col >= 0, n.col < size,
                      !visited.contains(n) else { continue }
                let value = region[n.row][n.col]
                if value == -1 || value == id {
                    visited.insert(n)
                    cameFrom[n] = current
                    queue.append(n)
                }
            }
        }
        return nil
    }

    // MARK: - Refinement: destroy an alternate solution

    /// Eliminates the alternate solution `alternate` by reassigning one cell that
    /// holds a star in `alternate` but not in `target` to a neighbouring region.
    ///
    /// That cell is not a star in `target`, so moving it keeps `target` valid. But
    /// it removes a star from `alternate`'s region, dropping that region below its
    /// quota and making `alternate` invalid. Connectivity of the shrinking region
    /// is preserved. Returns false if no such move is available.
    static func killAlternate(regions: inout [[Int]], target: Set<GridPosition>,
                              alternate: Set<GridPosition>, size: Int,
                              rng: inout SystemRandomNumberGenerator) -> Bool {
        var differing = Array(alternate.subtracting(target))
        differing.shuffle(using: &rng)

        for p in differing {
            let home = regions[p.row][p.col]
            var neighbourRegions: [Int] = []
            for (dr, dc) in orthogonal {
                let nr = p.row + dr, nc = p.col + dc
                if nr >= 0, nr < size, nc >= 0, nc < size, regions[nr][nc] != home {
                    neighbourRegions.append(regions[nr][nc])
                }
            }
            if neighbourRegions.isEmpty { continue }
            if regionStaysConnected(regions: regions, region: home, removing: p, size: size) {
                regions[p.row][p.col] = neighbourRegions.randomElement(using: &rng)!
                return true
            }
        }
        return false
    }

    /// True if `region` would remain a single connected component after `removed`
    /// is taken out of it.
    private static func regionStaysConnected(regions: [[Int]], region: Int,
                                             removing removed: GridPosition, size: Int) -> Bool {
        var cells: Set<GridPosition> = []
        for r in 0..<size {
            for c in 0..<size where regions[r][c] == region {
                let g = GridPosition(row: r, col: c)
                if g != removed { cells.insert(g) }
            }
        }
        guard let start = cells.first else { return false }

        var visited: Set<GridPosition> = [start]
        var stack = [start]
        while let cur = stack.popLast() {
            for (dr, dc) in orthogonal {
                let n = GridPosition(row: cur.row + dr, col: cur.col + dc)
                if cells.contains(n) && !visited.contains(n) {
                    visited.insert(n)
                    stack.append(n)
                }
            }
        }
        return visited.count == cells.count
    }

    // MARK: - Solver

    /// Finds up to `limit` valid solutions for a region layout. Used both to detect
    /// uniqueness and to retrieve alternates for refinement.
    static func findSolutions(regions: [[Int]], size: Int, stars: Int,
                              limit: Int) -> [Set<GridPosition>] {
        if stars == 2 {
            return findSolutionsTwoStar(regions: regions, size: size, limit: limit)
        }
        return findSolutionsGeneral(regions: regions, size: size, stars: stars, limit: limit)
    }

    /// Convenience wrapper returning just the number of solutions (capped at `limit`).
    static func countSolutions(regions: [[Int]], size: Int, stars: Int, limit: Int) -> Int {
        findSolutions(regions: regions, size: size, stars: stars, limit: limit).count
    }

    /// Fast, allocation-light solver specialised for the two-stars-per-unit case.
    private static func findSolutionsTwoStar(regions: [[Int]], size: Int,
                                             limit: Int) -> [Set<GridPosition>] {
        var regionCount = 0
        for row in regions {
            for id in row where id + 1 > regionCount { regionCount = id + 1 }
        }

        // regionRowsAfter[id][r] = how many rows at index >= r contain a cell of
        // region `id`. A region can gain at most one star per such row, so this
        // bounds how many more of its stars are still placeable.
        var regionRowsAfter = Array(repeating: [Int](repeating: 0, count: size + 1),
                                    count: regionCount)
        for id in 0..<regionCount {
            for r in stride(from: size - 1, through: 0, by: -1) {
                var present = false
                for c in 0..<size where regions[r][c] == id { present = true; break }
                regionRowsAfter[id][r] = regionRowsAfter[id][r + 1] + (present ? 1 : 0)
            }
        }

        var colCount = [Int](repeating: 0, count: size)
        var regionStars = [Int](repeating: 0, count: regionCount)
        var col1 = [Int](repeating: -1, count: size)
        var col2 = [Int](repeating: -1, count: size)
        var prevA = -2, prevB = -2 // previous row's two columns (-2 means "none")
        var results: [Set<GridPosition>] = []

        func touchesPrev(_ c: Int) -> Bool {
            (prevA >= 0 && abs(prevA - c) <= 1) || (prevB >= 0 && abs(prevB - c) <= 1)
        }

        // Can every column and region still reach two stars in the rows after `row`?
        func feasible(afterRow row: Int) -> Bool {
            let remainingRows = size - (row + 1)
            for c in 0..<size where 2 - colCount[c] > remainingRows { return false }
            for id in 0..<regionCount where 2 - regionStars[id] > regionRowsAfter[id][row + 1] {
                return false
            }
            return true
        }

        func solve(_ row: Int) {
            if results.count >= limit { return }
            if row == size {
                var s = Set<GridPosition>(minimumCapacity: size * 2)
                for r in 0..<size {
                    s.insert(GridPosition(row: r, col: col1[r]))
                    s.insert(GridPosition(row: r, col: col2[r]))
                }
                results.append(s)
                return
            }
            let savedA = prevA, savedB = prevB
            for c1 in 0..<(size - 1) {
                if colCount[c1] >= 2 || touchesPrev(c1) { continue }
                let r1 = regions[row][c1]
                if regionStars[r1] >= 2 { continue }
                colCount[c1] += 1; regionStars[r1] += 1
                for c2 in (c1 + 2)..<size {
                    if colCount[c2] >= 2 || touchesPrev(c2) { continue }
                    let r2 = regions[row][c2]
                    if regionStars[r2] >= 2 { continue } // already reflects c1 when r2 == r1
                    colCount[c2] += 1; regionStars[r2] += 1
                    col1[row] = c1; col2[row] = c2
                    prevA = c1; prevB = c2
                    if feasible(afterRow: row) { solve(row + 1) }
                    prevA = savedA; prevB = savedB
                    colCount[c2] -= 1; regionStars[r2] -= 1
                    if results.count >= limit {
                        colCount[c1] -= 1; regionStars[r1] -= 1
                        return
                    }
                }
                colCount[c1] -= 1; regionStars[r1] -= 1
            }
        }

        solve(0)
        return results
    }

    /// General recursive solver for any number of stars per unit.
    private static func findSolutionsGeneral(regions: [[Int]], size: Int, stars: Int,
                                             limit: Int) -> [Set<GridPosition>] {
        let regionCount = (regions.flatMap { $0 }.max() ?? -1) + 1
        var colCount = Array(repeating: 0, count: size)
        var regionStars = Array(repeating: 0, count: regionCount)
        var prevCols: [Int] = []
        var current: [GridPosition] = []
        var results: [Set<GridPosition>] = []

        func combos(row: Int) -> [[Int]] {
            var out: [[Int]] = []
            func rec(_ start: Int, _ chosen: [Int]) {
                if chosen.count == stars {
                    out.append(chosen)
                    return
                }
                for c in start..<size {
                    if let last = chosen.last, c - last < 2 { continue }
                    if colCount[c] >= stars { continue }
                    if prevCols.contains(where: { abs($0 - c) <= 1 }) { continue }
                    let reg = regions[row][c]
                    let sameRegionChosen = chosen.filter { regions[row][$0] == reg }.count
                    if regionStars[reg] + sameRegionChosen + 1 > stars { continue }
                    rec(c + 1, chosen + [c])
                }
            }
            rec(0, [])
            return out
        }

        func feasible(afterRow row: Int) -> Bool {
            let remainingRows = size - (row + 1)
            for c in 0..<size where stars - colCount[c] > remainingRows {
                return false
            }
            return true
        }

        func solve(_ row: Int) {
            if results.count >= limit { return }
            if row == size {
                results.append(Set(current))
                return
            }
            for combo in combos(row: row) {
                for c in combo {
                    colCount[c] += 1
                    regionStars[regions[row][c]] += 1
                    current.append(GridPosition(row: row, col: c))
                }
                let saved = prevCols
                prevCols = combo

                if feasible(afterRow: row) { solve(row + 1) }

                prevCols = saved
                for c in combo {
                    colCount[c] -= 1
                    regionStars[regions[row][c]] -= 1
                    current.removeLast()
                }
                if results.count >= limit { return }
            }
        }

        solve(0)
        return results
    }

}

/// A board's solve "shape": how many single-cell-contradiction steps it needs, and how
/// many times it *forces* the harder depth-2 (nested) technique. The peak technique and
/// its frequency — not the aggregate step count — are what make a board feel hard.
nonisolated struct DifficultyProfile {
    var tier1Steps = 0   // forced single-cell-contradiction deductions
    var tier2Steps = 0   // times the board forced an escalation to depth-2
    var peakTier = 0     // 0 = basic propagation, 1 = single-cell, 2 = depth-2
}

/// Fast, incremental constraint engine behind `difficultyProfile`. Cell state lives in
/// a flat array; per-unit star/blank counts are kept up to date so propagation only
/// touches the cells that change, and trial assumptions are undone via a journal
/// rather than by copying the whole grid.
private nonisolated final class LogicBoard {
    private let size: Int
    private let stars: Int
    private let regionOf: [Int]          // cell index -> region id
    private let rowCells: [[Int]]
    private let colCells: [[Int]]
    private let regionCellLists: [[Int]]

    private var state: [Int8]            // 0 = unknown, 1 = star, 2 = eliminated
    private var queue: [Int] = []
    private var journal: [(Int, Int8)] = []
    private var ok = true
    private var starTotal = 0

    private static let kingOffsets = [(-1, -1), (-1, 0), (-1, 1), (0, -1),
                                      (0, 1), (1, -1), (1, 0), (1, 1)]

    init(regions: [[Int]], size: Int, stars: Int) {
        self.size = size
        self.stars = stars
        let regionCount = (regions.flatMap { $0 }.max() ?? -1) + 1

        var regionOf = [Int](repeating: 0, count: size * size)
        var rows = Array(repeating: [Int](), count: size)
        var cols = Array(repeating: [Int](), count: size)
        var regs = Array(repeating: [Int](), count: regionCount)
        for r in 0..<size {
            for c in 0..<size {
                let i = r * size + c
                let id = regions[r][c]
                regionOf[i] = id
                rows[r].append(i)
                cols[c].append(i)
                regs[id].append(i)
            }
        }
        self.regionOf = regionOf
        self.rowCells = rows
        self.colCells = cols
        self.regionCellLists = regs
        self.state = [Int8](repeating: 0, count: size * size)
    }

    /// Cheap, tier-1-only solve: applies single-cell-contradiction logic to a fixpoint
    /// and returns the number of such steps used (0 = basic propagation alone solved
    /// it), or nil if the board stalls — i.e. needs the harder depth-2 technique (or a
    /// guess). Used as a fast pre-filter so Easy/Medium generation never pays the
    /// depth-2 cost: a board that stalls here is, by definition, not tier-1-gradable.
    func tier1Solve() -> Int? {
        propagate()
        guard ok else { return nil }

        var steps = 0
        while starTotal < stars * size {
            var progressed = false
            for i in 0..<(size * size) where state[i] == 0 {
                if trialContradicts(i, assume: 1) {
                    setEliminated(i); propagate()
                    if !ok { return nil }
                    steps += 1; progressed = true
                } else if trialContradicts(i, assume: 2) {
                    setStar(i); propagate()
                    if !ok { return nil }
                    steps += 1; progressed = true
                }
            }
            if !progressed { return nil }   // stalls → needs depth-2 or a guess
        }
        return steps
    }

    /// Solves the board the way a person would — always reaching for the cheapest
    /// technique that makes progress, and only escalating to the harder depth-2
    /// technique when nothing cheaper works, then dropping straight back down — and
    /// records a profile of that solve. Returns nil if the board needs more than
    /// depth-2 (i.e. a guess).
    ///
    /// The two tiers, cheapest first:
    ///   • Tier 1 — single-cell contradiction (`trialContradicts`): assume a star/blank
    ///     in one cell; if simple propagation breaks, the opposite is forced.
    ///   • Tier 2 — depth-2 nested contradiction (`deepTrial`): assume a value, then run
    ///     the *entire* tier-1 closure on the hypothetical; if that breaks, it's forced.
    ///
    /// `tier2Steps` — how many distinct times the board left no tier-1 move and forced
    /// the hard technique — is the signal that separates a genuinely hard board from one
    /// with a single tricky spot.
    func difficultyProfile() -> DifficultyProfile? {
        propagate()
        guard ok else { return nil }

        var profile = DifficultyProfile()
        while starTotal < stars * size {
            // Tier 1: apply every single-cell contradiction deduction available.
            var tier1Found = 0
            for i in 0..<(size * size) where state[i] == 0 {
                if trialContradicts(i, assume: 1) {        // a star here is impossible
                    setEliminated(i); propagate()
                    if !ok { return nil }
                    tier1Found += 1
                } else if trialContradicts(i, assume: 2) { // leaving it blank is impossible
                    setStar(i); propagate()
                    if !ok { return nil }
                    tier1Found += 1
                }
            }
            if tier1Found > 0 {
                profile.tier1Steps += tier1Found
                profile.peakTier = max(profile.peakTier, 1)
                continue
            }

            // No tier-1 move: escalate to a single depth-2 deduction, then loop back to
            // the cheap tier (a hard breakthrough usually reopens easy moves).
            var madeTier2 = false
            for i in 0..<(size * size) where state[i] == 0 {
                if deepTrial(i, assume: 1) {
                    setEliminated(i); propagate()
                    if !ok { return nil }
                    madeTier2 = true
                } else if deepTrial(i, assume: 2) {
                    setStar(i); propagate()
                    if !ok { return nil }
                    madeTier2 = true
                }
                if madeTier2 { break }
            }
            if madeTier2 {
                profile.tier2Steps += 1
                profile.peakTier = 2
                continue
            }

            return nil   // stuck even with depth-2 → would require a guess
        }
        return profile
    }

    /// Depth-2 trial: assume `value` at `i`, propagate, then run the full single-cell
    /// contradiction closure on the hypothetical; the assumption is impossible if any
    /// of that breaks. Rewinds all changes afterwards.
    private func deepTrial(_ i: Int, assume value: Int8) -> Bool {
        let mark = journal.count
        if value == 1 { setStar(i) } else { setEliminated(i) }
        propagate()
        if ok { depthOneClosure() }
        let bad = !ok
        rewind(to: mark)
        return bad
    }

    /// Applies every forced single-cell-contradiction deduction to the current
    /// (hypothetical) state, used inside a depth-2 trial.
    private func depthOneClosure() {
        while ok {
            var progressed = false
            for i in 0..<(size * size) where state[i] == 0 {
                if trialContradicts(i, assume: 1) {
                    setEliminated(i); propagate()
                    if !ok { return }
                    progressed = true
                } else if trialContradicts(i, assume: 2) {
                    setStar(i); propagate()
                    if !ok { return }
                    progressed = true
                }
            }
            if !progressed { break }
        }
    }

    /// Tentatively sets cell `i` to `value`, propagates, notes whether it breaks the
    /// board, then rewinds every change.
    private func trialContradicts(_ i: Int, assume value: Int8) -> Bool {
        let mark = journal.count
        if value == 1 { setStar(i) } else { setEliminated(i) }
        propagate()
        let bad = !ok
        rewind(to: mark)
        return bad
    }

    private func propagate() {
        while ok, let i = queue.popLast() {
            if state[i] == 1 {
                let r = i / size, c = i % size
                for (dr, dc) in Self.kingOffsets {
                    let nr = r + dr, nc = c + dc
                    if nr >= 0, nr < size, nc >= 0, nc < size {
                        setEliminated(nr * size + nc)
                        if !ok { return }
                    }
                }
            }
            checkUnit(rowCells[i / size])
            if !ok { return }
            checkUnit(colCells[i % size])
            if !ok { return }
            checkUnit(regionCellLists[regionOf[i]])
            if !ok { return }
        }
    }

    private func checkUnit(_ cells: [Int]) {
        var s = 0, u = 0
        for j in cells {
            if state[j] == 1 { s += 1 } else if state[j] == 0 { u += 1 }
        }
        if s > stars || s + u < stars { ok = false; return }
        if u > 0 && s == stars {
            for j in cells where state[j] == 0 { setEliminated(j); if !ok { return } }
        } else if u > 0 && s + u == stars {
            for j in cells where state[j] == 0 { setStar(j); if !ok { return } }
        }
    }

    private func setStar(_ i: Int) {
        switch state[i] {
        case 1: return
        case 2: ok = false; return
        default:
            journal.append((i, 0))
            state[i] = 1
            starTotal += 1
            queue.append(i)
        }
    }

    private func setEliminated(_ i: Int) {
        switch state[i] {
        case 2: return
        case 1: ok = false; return
        default:
            journal.append((i, 0))
            state[i] = 2
            queue.append(i)
        }
    }

    private func rewind(to mark: Int) {
        while journal.count > mark {
            let (i, old) = journal.removeLast()
            if state[i] == 1 { starTotal -= 1 }
            state[i] = old
        }
        queue.removeAll(keepingCapacity: true)
        ok = true
    }
}
