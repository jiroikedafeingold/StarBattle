import Foundation

/// A coordinate on the puzzle grid.
struct GridPosition: Hashable, Codable {
    var row: Int
    var col: Int
}

/// What the player has placed in a cell.
enum CellMark: Equatable {
    /// Nothing placed.
    case empty
    /// A star.
    case star
    /// A "no star here" marker the player uses while deducing.
    case dot
}

/// A background "guess" colour painted in Highlight mode. It sits behind any mark
/// and is only committed to real marks when the player taps "Realize".
enum CellHighlight: Equatable {
    /// No highlight — the cell shows its normal region tint.
    case none
    /// White — the player is guessing this square WILL be a star.
    case guessStar
    /// Greyed-out — the player is guessing this square is NOT a star.
    case guessEmpty
}

/// A fully described Star Battle puzzle.
///
/// A puzzle is defined entirely by its region layout. The `solution` is kept
/// alongside it for reference, but the player never needs it — every puzzle the
/// generator produces is guaranteed to have exactly one valid solution.
struct Puzzle: Codable {
    /// Width and height of the (square) grid, e.g. 10.
    let size: Int
    /// Number of stars required in each row, column and region, e.g. 2.
    let starsPerUnit: Int
    /// The region id for every cell, indexed `[row][col]`. Ids run `0..<size`.
    let regions: [[Int]]
    /// The star positions of the unique solution.
    let solution: Set<GridPosition>

    func regionId(row: Int, col: Int) -> Int {
        regions[row][col]
    }

    /// A blank placeholder shown briefly while the first real puzzle generates.
    static func placeholder(size: Int = 10, starsPerUnit: Int = 2) -> Puzzle {
        var regions = Array(repeating: Array(repeating: 0, count: size), count: size)
        for r in 0..<size {
            for c in 0..<size {
                regions[r][c] = r
            }
        }
        return Puzzle(size: size, starsPerUnit: starsPerUnit, regions: regions, solution: [])
    }
}
