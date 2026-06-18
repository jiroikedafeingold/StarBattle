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

    var best: Int? { times.min() }
    var average: Int? {
        guard !times.isEmpty else { return nil }
        return Int((Double(times.reduce(0, +)) / Double(times.count)).rounded())
    }
}

/// Reads and updates the persisted `Stats`.
enum StatsStore {
    private static let key = "stats.v1"

    static func load() -> Stats {
        guard let data = UserDefaults.standard.data(forKey: key),
              let stats = try? JSONDecoder().decode(Stats.self, from: data) else { return Stats() }
        return stats
    }

    static func save(_ stats: Stats) {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func recordStarted() {
        var stats = load()
        stats.started += 1
        save(stats)
    }

    static func recordSolved(seconds: Int) {
        var stats = load()
        stats.solved += 1
        stats.times.append(seconds)
        save(stats)
    }

    static func reset() {
        save(Stats())
    }
}
