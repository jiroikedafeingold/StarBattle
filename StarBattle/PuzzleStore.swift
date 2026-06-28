import Foundation

/// Persists generated puzzles to disk so the board shown at launch varies over
/// time, instead of repeating the small set of built-in starters. New puzzles are
/// produced in the background during play and added here; on launch we pick one of
/// the saved boards at random (falling back to a starter when the pool is empty).
@MainActor
final class PuzzleStore {
    private(set) var saved: [Puzzle]
    private let capacity = 30
    private let fileURL: URL
    private let prefetchURL: URL

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("StarBattle", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("puzzles.json")
        prefetchURL = dir.appendingPathComponent("prefetch.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Puzzle].self, from: data) {
            saved = decoded
        } else {
            saved = []
        }
    }

    /// Loads the persisted ready-to-play queue, keyed by difficulty. These are boards
    /// generated in a previous session but never shown, so restoring them makes the
    /// first New/switch instant after a relaunch — especially for slow Hard boards —
    /// without ever replaying a board the player has already seen.
    func loadPrefetch() -> [Difficulty: [Puzzle]] {
        guard let data = try? Data(contentsOf: prefetchURL),
              let decoded = try? JSONDecoder().decode([String: [Puzzle]].self, from: data) else {
            return [:]
        }
        var result: [Difficulty: [Puzzle]] = [:]
        for (key, puzzles) in decoded {
            if let level = Difficulty(rawValue: key) { result[level] = puzzles }
        }
        return result
    }

    /// Persists the current ready queue so it survives app restarts.
    func savePrefetch(_ queues: [Difficulty: [Puzzle]]) {
        var encodable: [String: [Puzzle]] = [:]
        for (level, puzzles) in queues where !puzzles.isEmpty {
            encodable[level.rawValue] = puzzles
        }
        guard let data = try? JSONEncoder().encode(encodable) else { return }
        try? data.write(to: prefetchURL, options: .atomic)
    }

    /// A puzzle to show at launch for the given difficulty: a previously saved board of
    /// that level if one exists, otherwise a built-in starter (or a placeholder).
    func launchPuzzle(for difficulty: Difficulty) -> Puzzle {
        if let pooled = saved.filter({ $0.difficulty == difficulty }).randomElement() {
            return pooled
        }
        return Puzzle.starters(for: difficulty).randomElement()
            ?? Puzzle.placeholder(size: difficulty.boardSize, starsPerUnit: difficulty.starsPerUnit)
    }

    /// Adds a freshly generated puzzle (skipping duplicate layouts), trims the pool
    /// to `capacity`, and writes it to disk.
    func add(_ puzzle: Puzzle) {
        guard !saved.contains(where: { $0.regions == puzzle.regions }) else { return }
        saved.append(puzzle)
        if saved.count > capacity {
            saved.removeFirst(saved.count - capacity)
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(saved) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
