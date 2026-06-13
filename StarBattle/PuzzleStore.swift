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

    init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("StarBattle", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("puzzles.json")

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([Puzzle].self, from: data) {
            saved = decoded
        } else {
            saved = []
        }
    }

    /// A puzzle to show at launch: a previously saved one if any exist, otherwise a
    /// built-in starter.
    func launchPuzzle() -> Puzzle {
        saved.randomElement() ?? Puzzle.starters.randomElement() ?? Puzzle.placeholder()
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
