import Foundation

/// A snapshot of the in-progress game, saved so it survives the app being quit.
struct SavedGame: Codable {
    var puzzle: Puzzle
    var marks: [[CellMark]]
    var highlights: [[CellHighlight]]
    var autoDotCount: [GridPosition: Int]
    var highlightAutoDotCount: [GridPosition: Int]
    var elapsedSeconds: Int
    var isHighlightMode: Bool
    var isSolved: Bool
}

/// Persists the current game to `UserDefaults` so it can be restored on next launch.
enum GameStateStore {
    private static let key = "savedGame.v1"

    static func save(_ game: SavedGame) {
        if let data = try? JSONEncoder().encode(game) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> SavedGame? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SavedGame.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Cumulative play statistics, persisted across launches.
struct Stats: Codable {
    var started = 0
    var solved = 0
    /// Completion times (seconds) of solved puzzles.
    var times: [Int] = []
    /// Total hints used.
    var hints = 0
    /// Total times Check flagged a wrong cherry (a "bad guess" caught).
    var badGuesses = 0

    var best: Int? { times.min() }
    var average: Int? {
        guard !times.isEmpty else { return nil }
        return Int((Double(times.reduce(0, +)) / Double(times.count)).rounded())
    }
}

/// Per-difficulty statistics, keyed by `Difficulty.rawValue`.
struct AllStats: Codable {
    var buckets: [String: Stats] = [:]

    subscript(_ d: Difficulty) -> Stats {
        get { buckets[d.rawValue] ?? Stats() }
        set { buckets[d.rawValue] = newValue }
    }
}

/// Reads and updates the persisted per-difficulty `Stats`.
enum StatsStore {
    private static let key = "stats.v2"

    static func loadAll() -> AllStats {
        guard let data = UserDefaults.standard.data(forKey: key),
              let all = try? JSONDecoder().decode(AllStats.self, from: data) else { return AllStats() }
        return all
    }

    static func saveAll(_ all: AllStats) {
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load(_ difficulty: Difficulty) -> Stats { loadAll()[difficulty] }

    static func recordStarted(_ difficulty: Difficulty) {
        var all = loadAll(); all[difficulty].started += 1; saveAll(all)
    }

    static func recordSolved(_ difficulty: Difficulty, seconds: Int) {
        var all = loadAll(); all[difficulty].solved += 1; all[difficulty].times.append(seconds); saveAll(all)
    }

    static func recordHint(_ difficulty: Difficulty) {
        var all = loadAll(); all[difficulty].hints += 1; saveAll(all)
    }

    static func recordBadGuesses(_ difficulty: Difficulty, _ count: Int) {
        guard count > 0 else { return }
        var all = loadAll(); all[difficulty].badGuesses += count; saveAll(all)
    }

    static func reset() {
        saveAll(AllStats())
    }
}
