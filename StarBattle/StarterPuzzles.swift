import Foundation

extension Puzzle {
    /// Hand-baked, verified-unique 10×10 / 2-star boards. They're shown instantly at
    /// launch (and used as a last-resort fallback) so the player never waits for the
    /// generator to warm up. Each string is one grid row; every character is that
    /// cell's region id (ids are single digits 0…9).
    private nonisolated static let starterLayouts: [[String]] = [
        [
            "9000888888",
            "9000444888",
            "9000444666",
            "9005446666",
            "9905556666",
            "9335552161",
            "9322222111",
            "9339277111",
            "9999777111",
            "9999777111",
        ],
        [
            "4499116666",
            "4499116333",
            "4999916333",
            "4444996666",
            "5549999666",
            "5555999666",
            "5555088866",
            "2228087766",
            "8228088776",
            "8888887776",
        ],
        [
            "5500000666",
            "5999006666",
            "5988006666",
            "9978001166",
            "9978888116",
            "9778448116",
            "7777742233",
            "7774442233",
            "7774442333",
            "7777442233",
        ],
        [
            "8881111444",
            "8880144445",
            "6880111445",
            "6880111445",
            "6888884455",
            "2228883355",
            "2228883357",
            "2228883337",
            "2222983777",
            "2299993777",
        ],
        [
            "1199990000",
            "8111990000",
            "8189922200",
            "8888999220",
            "8899959220",
            "8895555240",
            "8795554444",
            "7799554643",
            "7799966663",
            "7766666633",
        ],
        [
            "7777779999",
            "7773999289",
            "7773995288",
            "7973995288",
            "1999955888",
            "1969995888",
            "1965555880",
            "1964440080",
            "9944440000",
            "9994440000",
        ],
    ]

    /// Hand-harvested, verified-unique 5×5 / 1-star boards for the Beginner level, so a
    /// beginner board shows instantly at launch instead of a placeholder.
    private nonisolated static let beginnerLayouts: [[String]] = [
        ["00113", "00013", "04013", "24413", "24333"],
        ["00444", "00433", "00413", "02211", "02221"],
        ["00041", "20041", "20044", "22344", "22344"],
        ["20000", "40033", "44033", "44413", "44113"],
        ["33111", "00111", "00021", "00222", "22224"],
        ["22244", "32222", "33021", "03011", "00011"],
    ]

    /// The parsed standard (10×10 / 2-star) starter puzzles, built once on first use.
    nonisolated static let starters: [Puzzle] = starterLayouts.compactMap { Puzzle(regionRows: $0, stars: 2) }

    /// The parsed Beginner (5×5 / 1-star) starter puzzles.
    nonisolated static let beginnerStarters: [Puzzle] = beginnerLayouts.compactMap { Puzzle(regionRows: $0, stars: 1) }

    /// The starter set appropriate for a difficulty: 5×5 / 1-star for Beginner, the
    /// standard 10×10 / 2-star boards otherwise.
    nonisolated static func starters(for difficulty: Difficulty) -> [Puzzle] {
        difficulty == .beginner ? beginnerStarters : starters
    }

    /// Builds a puzzle from `n` rows of `n` single-digit region ids, deriving the
    /// unique solution with the solver. Returns nil if the layout is malformed.
    nonisolated init?(regionRows: [String], stars: Int = 2) {
        let size = regionRows.count
        var regions: [[Int]] = []
        for row in regionRows {
            guard row.count == size else { return nil }
            let ids = row.compactMap { $0.wholeNumberValue }
            guard ids.count == size else { return nil }
            regions.append(ids)
        }
        let solutions = PuzzleGenerator.findSolutions(regions: regions, size: size, stars: stars, limit: 1)
        self.init(size: size, starsPerUnit: stars, regions: regions, solution: solutions.first ?? [])
    }
}
