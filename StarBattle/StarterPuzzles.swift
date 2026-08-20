import Foundation

extension Puzzle {
    /// Hand-baked, verified-unique 10×10 / 2-star boards. They're shown instantly at
    /// launch (and used as a last-resort fallback) so the player never waits for the
    /// generator to warm up. Each string is one grid row; every character is that
    /// cell's region id (ids are single digits 0…9).
    private nonisolated static let starterLayouts: [[String]] = [
        // Two of the original hand-baked layouts graded *expert* on the solver's own
        // difficulty profile, which made a brand-new player's very first board a 1-in-3
        // chance of being the hardest thing the app can produce. They were replaced (here
        // and below) with verified easy-band boards.
        [
            "0010022233",
            "4010022335",
            "4010222355",
            "4010003335",
            "0010000055",
            "0000607666",
            "0800607776",
            "6860606666",
            "6866606999",
            "6666666669",
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
            "0000111112",
            "0330001122",
            "0333000022",
            "0000004442",
            "0000000044",
            "0550660000",
            "5555650777",
            "5585655555",
            "5585555955",
            "5585599955",
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
        // Harvested 2026-08-20 with the app's own generator, so a new player isn't one of
        // only six possible first boards. Each was checked to have exactly one solution,
        // to grade in the **easy** band (the default level a new player lands on), to use
        // all 10 regions with none swallowing more than 40% of the grid, and to be distinct
        // from every other layout here under rotation and reflection.
        [
            "0000000000",
            "0110000002",
            "3310044402",
            "3313033332",
            "3333333333",
            "3335333363",
            "7755338363",
            "7555338366",
            "7799338866",
            "7999938866",
        ],
        [
            "0111122333",
            "0000223333",
            "0044422222",
            "0022222555",
            "6002222575",
            "6000222275",
            "6000222275",
            "0008222272",
            "0008292222",
            "0008899922",
        ],
        [
            "0001122223",
            "0001224423",
            "0001224423",
            "0522224423",
            "0526622222",
            "0522666662",
            "0002777766",
            "0082222996",
            "0082222999",
            "0082222999",
        ],
        [
            "0000112223",
            "0400155323",
            "6440135323",
            "6644135333",
            "6614133337",
            "1611183337",
            "1111183137",
            "1191883133",
            "1191113133",
            "9991111111",
        ],
        [
            "0000000011",
            "0002220011",
            "3300000001",
            "3000004005",
            "3000064655",
            "6000764665",
            "6080766665",
            "6680766966",
            "6686666966",
            "6666666966",
        ],
        [
            "0111222222",
            "0001324225",
            "0333324225",
            "0000024255",
            "6660222222",
            "0000072822",
            "0000078822",
            "0000072822",
            "9990002222",
            "0000022222",
        ],
        [
            "0011111022",
            "3000000002",
            "3333040002",
            "5000040222",
            "5555040005",
            "5000000065",
            "5500777065",
            "5555555065",
            "5588855555",
            "5555555999",
        ],
        [
            "0011111222",
            "0031111142",
            "0331115444",
            "3331115444",
            "1111115444",
            "6666614444",
            "6661114777",
            "8888194444",
            "8811194444",
            "8811194444",
        ],
        [
            "0111223333",
            "0111224444",
            "0102222454",
            "0002224454",
            "0022222455",
            "2666624444",
            "2222227774",
            "2288824444",
            "2222222444",
            "2229994444",
        ],
        [
            "0000000001",
            "2220000001",
            "0000000001",
            "3300000444",
            "3005554444",
            "3444444464",
            "4477744464",
            "4474448464",
            "4999448444",
            "4999888444",
        ],
        [
            "0000112223",
            "0001122223",
            "4400222223",
            "4400255522",
            "0440222022",
            "0000000022",
            "6077700022",
            "6070008022",
            "6000008882",
            "6999922222",
        ],
        [
            "0000111122",
            "0111113122",
            "1111113112",
            "4441113111",
            "4551666651",
            "5571115655",
            "5571185559",
            "5771185999",
            "5551585555",
            "5555555555",
        ],
        [
            "0001122233",
            "0111122133",
            "1111122113",
            "1111111113",
            "4411155511",
            "4416154411",
            "7416444811",
            "7446444888",
            "7744449888",
            "4444449999",
        ],
        [
            "0012222222",
            "0012333222",
            "0012222224",
            "0002225524",
            "0002225224",
            "0600025224",
            "0666022274",
            "0000082274",
            "0999082777",
            "0900088877",
        ],
        [
            "0000001111",
            "0000000010",
            "0000222000",
            "3330400000",
            "4300400555",
            "4666400575",
            "4444480777",
            "4444484447",
            "9444484444",
            "9994444444",
        ],
        [
            "0111211111",
            "0131211143",
            "0131211143",
            "1131115143",
            "1131315343",
            "1133355333",
            "1663333337",
            "1633388837",
            "1633333887",
            "1339999877",
        ],
        [
            "0111111111",
            "0001211311",
            "2222211314",
            "2111111314",
            "2222211114",
            "2255216111",
            "7725216281",
            "7725226281",
            "7722222288",
            "2229992222",
        ],
        [
            "0011222222",
            "0111112211",
            "0033311111",
            "0000111445",
            "0000061415",
            "0000061415",
            "0007061111",
            "0807111191",
            "0807111191",
            "0800011191",
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
        // Harvested 2026-08-20 with the app's own generator (see the note above): each has
        // exactly one solution, uses all 5 regions with none over 8 cells, and is distinct
        // from the rest under rotation and reflection.
        ["00011", "22011", "23114", "23114", "33444"],
        ["01222", "01222", "00003", "44433", "44444"],
        ["01122", "31112", "33122", "33122", "33344"],
        ["00011", "00111", "00112", "03122", "33444"],
        ["00112", "03122", "03124", "03334", "33344"],
        ["00011", "02211", "33111", "33444", "34444"],
        ["00112", "00022", "30424", "30444", "33444"],
        ["00111", "00001", "20301", "43333", "44443"],
        ["01111", "00111", "20031", "22433", "24433"],
        ["00111", "00001", "02222", "33324", "33333"],
        ["01122", "00112", "03322", "03224", "03324"],
        ["00112", "00012", "00222", "34224", "34444"],
        ["00001", "00211", "00341", "33344", "34444"],
        ["01222", "01112", "00222", "00333", "44333"],
        ["00111", "00021", "33222", "32242", "33344"],
        ["01111", "00211", "22221", "32244", "33244"],
        ["00001", "00001", "22331", "22341", "22244"],
        ["00011", "00021", "30221", "33331", "33344"],
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
