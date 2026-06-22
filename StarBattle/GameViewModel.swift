import Foundation
import Observation
import SwiftUI

/// Holds the live game state: the current puzzle, the player's marks, and the
/// derived information the UI needs (errors, win state, timer).
@MainActor
@Observable
final class GameViewModel {

    private(set) var puzzle: Puzzle
    /// The player's mark for every cell, indexed `[row][col]`.
    var marks: [[CellMark]]

    /// How many placed stars are currently auto-dotting each cell. A cell can be
    /// auto-dotted by more than one neighbouring star, so we keep a count rather
    /// than a flag: the auto dot is only removed once the last star next to it is
    /// gone. Dots the player placed by hand are never tracked here, so they
    /// survive when a neighbouring star is removed.
    private var autoDotCount: [GridPosition: Int] = [:]

    private(set) var isGenerating = false
    private(set) var isSolved = false
    var elapsedSeconds = 0

    /// Stars flagged by the last "Check" as not belonging to the solution. Cleared
    /// as soon as the player changes the board.
    private(set) var wrongStars: Set<GridPosition> = []
    /// Bumped each time "Check" runs, so the view can fire a pass/fail haptic.
    private(set) var checkPulse = 0
    /// Whether the most recent check found any incorrect stars.
    private(set) var lastCheckHadErrors = false
    /// Bumped several times in quick succession when "Check" finds a wrong cherry, so
    /// the view can play a strong, buzzing "that's wrong" rumble.
    private(set) var wrongPulse = 0

    /// Bumped on every action; the view watches it to fire a tap haptic.
    private(set) var tapPulse = 0
    /// Whether the most recent action placed a star (used to pick a stronger haptic).
    private(set) var lastActionPlacedStar = false

    /// Bumped repeatedly when a puzzle is solved so the view can play a strong,
    /// rolling burst of haptics during the celebration.
    private(set) var celebrationPulse = 0

    // MARK: Highlight (guessing) mode

    /// Per-cell background "guess" colours, indexed `[row][col]`.
    private(set) var highlights: [[CellHighlight]]
    /// Whether the board is in Highlight (guessing) mode.
    private(set) var isHighlightMode = false
    /// True while "Realize" is animating guesses into real marks.
    private(set) var isRealizing = false
    /// Whether any cell currently carries a highlight.
    var hasHighlights: Bool { highlights.contains { row in row.contains { $0 != .none } } }

    /// The cell of the very first guess in the current Mark-mode exploration. Used to
    /// drop a fading "?" there if the player backs all the way out of their guesses.
    private var firstGuessCell: GridPosition?
    /// The cell currently showing the fading "?" reminder (or nil). The view fades it
    /// out over ~15s; `ghostPulse` changes so the fade restarts on each new ghost.
    private(set) var guessGhost: GridPosition?
    private(set) var ghostPulse = 0
    private var ghostToken = 0

    /// Mirrors `autoDotCount` for the highlight layer: how many "will be a star"
    /// guesses are auto-dotting each cell with a grey guess. Lets a white guess
    /// place grey guess-dots around itself, and remove only those when it's removed.
    private var highlightAutoDotCount: [GridPosition: Int] = [:]

    /// Full board snapshots captured before each action, for Undo.
    private var history: [Snapshot] = []
    /// States popped by Undo, so they can be reapplied with Redo. Cleared whenever
    /// a fresh action is taken.
    private var redoStack: [Snapshot] = []
    private let historyLimit = 200
    var canUndo: Bool { !history.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// The explanation for the most recent Hint, shown to the player. Setting it to
    /// nil dismisses the message.
    var hintMessage: String?
    /// The cell the current hint refers to, so the board can highlight it and the
    /// explanation can be positioned beside it. Nil when a hint has no single cell.
    private(set) var hintFocus: GridPosition?
    /// Bumped each time a hint is given, so the view can fire a haptic.
    private(set) var hintPulse = 0
    /// Whether a hint can be requested right now.
    var canHint: Bool { !isGenerating && !isSolved && !isRealizing && !isHighlightMode }

    private struct Snapshot {
        let marks: [[CellMark]]
        let autoDotCount: [GridPosition: Int]
        let highlights: [[CellHighlight]]
        let highlightAutoDotCount: [GridPosition: Int]
    }

    /// On-disk pool of previously generated puzzles, for launch-screen variety.
    private let store = PuzzleStore()

    /// Puzzles generated ahead of time so "New Puzzle" is instant even on rapid
    /// taps. Kept topped up to `prefetchDepth`.
    private var prefetchQueue: [Task<Puzzle, Never>] = []
    private let prefetchDepth = 2
    /// The most recently scheduled generation. Each new build waits on it before
    /// starting, so the (CPU-heavy) builds run one-at-a-time instead of all at once
    /// — two concurrent builds used to starve the main thread and make the board
    /// feel unresponsive right after launch.
    private var prefetchTail: Task<Puzzle, Never>?

    /// True inside SwiftUI previews — used to skip background work and persistence.
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    /// The difficulty new puzzles are generated at (persisted; defaults to Easy).
    private(set) var difficulty: Difficulty

    // Per-game "clean win" tracking: a win counts as clean only if the player used
    // no hint and never placed a wrong cherry.
    private var hintUsedThisGame = false
    private var badPlacementThisGame = false
    /// Set true when the player has earned enough clean wins to be offered a step up
    /// in difficulty; the view shows a one-time prompt and clears it.
    var promptDifficultyIncrease = false

    init() {
        let storedDifficulty = UserDefaults.standard.string(forKey: SettingsKey.difficulty)
            .flatMap(Difficulty.init(rawValue:)) ?? .easy
        difficulty = storedDifficulty

        // Restore the game the player left off in, if one was saved. Otherwise show a
        // real, playable board immediately (drawn from the saved pool so it varies)
        // while the generator warms up in the background.
        if !isPreview, let saved = GameStateStore.load() {
            puzzle = saved.puzzle
            marks = saved.marks
            highlights = saved.highlights
            autoDotCount = saved.autoDotCount
            highlightAutoDotCount = saved.highlightAutoDotCount
            elapsedSeconds = saved.elapsedSeconds
            isHighlightMode = saved.isHighlightMode
            isSolved = saved.isSolved
        } else {
            let launch = store.launchPuzzle()
            puzzle = launch
            marks = Self.emptyMarks(size: launch.size)
            highlights = Self.emptyHighlights(size: launch.size)
            if !isPreview { StatsStore.recordStarted() }
        }
        isGenerating = false

        // Don't spin up background generation inside SwiftUI previews. Defer it a
        // beat so the first frame and the first taps stay smooth on launch.
        if !isPreview {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                self?.topUpPrefetch()
            }
        }
    }

    /// Saves the current game so it can be restored after the app is quit.
    func saveGame() {
        guard !isPreview else { return }
        GameStateStore.save(SavedGame(
            puzzle: puzzle, marks: marks, highlights: highlights,
            autoDotCount: autoDotCount, highlightAutoDotCount: highlightAutoDotCount,
            elapsedSeconds: elapsedSeconds, isHighlightMode: isHighlightMode, isSolved: isSolved))
    }

    // MARK: - Lifecycle

    /// Installs a fresh puzzle, handing back one prepared in the background. Falls
    /// back to on-demand generation only if the queue hasn't caught up yet.
    func newGame() async {
        isGenerating = true
        isSolved = false
        elapsedSeconds = 0

        // Keep the "Creating a new board…" indicator on screen long enough to read,
        // even when a prefetched puzzle is ready instantly.
        let start = ContinuousClock.now
        let fresh: Puzzle
        if !prefetchQueue.isEmpty {
            fresh = await prefetchQueue.removeFirst().value
        } else {
            fresh = await PuzzleGenerator.generate(difficulty: difficulty)
        }
        let minimumShown = Duration.milliseconds(450)
        let elapsed = start.duration(to: ContinuousClock.now)
        if elapsed < minimumShown {
            try? await Task.sleep(for: minimumShown - elapsed)
        }

        puzzle = fresh
        marks = Self.emptyMarks(size: fresh.size)
        highlights = Self.emptyHighlights(size: fresh.size)
        autoDotCount.removeAll()
        highlightAutoDotCount.removeAll()
        history.removeAll()
        redoStack.removeAll()
        clearCheck()
        dismissHint()
        firstGuessCell = nil
        guessGhost = nil
        isHighlightMode = false
        isGenerating = false
        hintUsedThisGame = false
        badPlacementThisGame = false

        if !isPreview { StatsStore.recordStarted() }
        saveGame()
        topUpPrefetch()
    }

    /// Dismisses the one-time "step up the difficulty" prompt so it never shows again.
    func dismissDifficultyPrompt() {
        promptDifficultyIncrease = false
        UserDefaults.standard.set(true, forKey: SettingsKey.difficultyPromptShown)
    }

    /// Switches the difficulty of future puzzles, discards any prefetched (wrong
    /// difficulty) boards, and starts a fresh game at the new level.
    func setDifficulty(_ new: Difficulty) {
        guard new != difficulty else { return }
        difficulty = new
        UserDefaults.standard.set(new.rawValue, forKey: SettingsKey.difficulty)
        prefetchQueue.removeAll()
        prefetchTail = nil
        Task { await newGame() }
    }

    /// Keeps the background generation queue filled to `prefetchDepth`. The tasks
    /// run concurrently off the main actor, so several puzzles prepare in parallel.
    /// Each finished puzzle is also saved to the on-disk pool for launch variety.
    private func topUpPrefetch() {
        while prefetchQueue.count < prefetchDepth {
            // Chain each build onto the previous one so they run sequentially at low
            // priority rather than competing for the CPU all at once.
            let previous = prefetchTail
            let level = difficulty
            let task = Task.detached(priority: .background) { () -> Puzzle in
                _ = await previous?.value
                return PuzzleGenerator.buildPuzzle(difficulty: level)
            }
            prefetchTail = task
            prefetchQueue.append(task)
            Task { [weak self] in
                let puzzle = await task.value
                self?.store.add(puzzle)
            }
        }
    }

    /// Removes every mark and guess highlight from the board (undoable).
    func clearBoard() {
        let hasMarks = marks.contains { row in row.contains { $0 != .empty } }
        guard hasMarks || hasHighlights else { return }
        pushHistory()
        marks = Self.emptyMarks(size: puzzle.size)
        highlights = Self.emptyHighlights(size: puzzle.size)
        autoDotCount.removeAll()
        highlightAutoDotCount.removeAll()
        clearCheck()
        firstGuessCell = nil
        guessGhost = nil
        isSolved = false
    }

    // MARK: - Interaction

    /// Cycles a cell: empty → dot → star → empty.
    ///
    /// A first tap leaves a dot — the player's note that a star can't go here.
    /// A second tap promotes it to a star and automatically dots the eight
    /// surrounding cells (where a star is now impossible). A third tap clears the
    /// star and removes only those auto-placed dots, leaving any dots the player
    /// had already placed by hand untouched.
    func tap(row: Int, col: Int) {
        guard !isGenerating, !isSolved, !isRealizing else { return }

        // In Highlight mode a tap cycles the *guess* layer exactly like the real
        // board cycles marks: empty → guess-dot → guess-cherry → empty.
        if isHighlightMode {
            pushHistory()
            let pos = GridPosition(row: row, col: col)
            switch highlights[row][col] {
            case .none:
                if firstGuessCell == nil { firstGuessCell = pos }
                highlights[row][col] = .guessEmpty
                lastActionPlacedStar = false
            case .guessEmpty:
                highlightAutoDotCount[pos] = nil      // this cell becomes a cherry guess
                highlights[row][col] = .guessStar
                addGuessAutoDots(around: pos)
                lastActionPlacedStar = true
            case .guessStar:
                removeGuessAutoDots(around: pos)
                highlights[row][col] = .none
                lastActionPlacedStar = false
            }
            tapPulse &+= 1
            noteHighlightsCleared()
            return
        }

        pushHistory()
        clearCheck()
        let pos = GridPosition(row: row, col: col)

        // Out of Mark mode, tapping a left-over guess clears it first, so a real
        // mark can replace it on the same tap.
        if highlights[row][col] != .none {
            if highlights[row][col] == .guessStar { removeGuessAutoDots(around: pos) }
            highlights[row][col] = .none
            highlightAutoDotCount[pos] = nil
        }

        switch marks[row][col] {
        case .empty:
            marks[row][col] = .dot
            lastActionPlacedStar = false
        case .dot:
            marks[row][col] = .star
            addAutoDots(around: pos)
            lastActionPlacedStar = true
            if !puzzle.solution.contains(pos) { badPlacementThisGame = true }
        case .star:
            removeAutoDots(around: pos)
            marks[row][col] = .empty
            lastActionPlacedStar = false
        }
        tapPulse &+= 1
        evaluateWin()
    }

    /// Reverts the most recent action, restoring the exact board that preceded it.
    /// The state being undone is kept so it can be reapplied with Redo.
    func undo() {
        guard !isGenerating, !isRealizing, let snapshot = history.popLast() else { return }
        redoStack.append(currentSnapshot())
        restore(snapshot)
    }

    /// Reapplies the most recently undone action.
    func redo() {
        guard !isGenerating, !isRealizing, let snapshot = redoStack.popLast() else { return }
        history.append(currentSnapshot())
        restore(snapshot)
    }

    /// Restores a captured board, refreshing derived state.
    private func restore(_ snapshot: Snapshot) {
        marks = snapshot.marks
        autoDotCount = snapshot.autoDotCount
        highlights = snapshot.highlights
        highlightAutoDotCount = snapshot.highlightAutoDotCount
        clearCheck()
        dismissHint()
        lastActionPlacedStar = false
        tapPulse &+= 1
        noteHighlightsCleared()
        evaluateWin()
    }

    /// If the player has just emptied every guess while in Mark mode, drop a fading
    /// "?" on the cell where their guessing began.
    private func noteHighlightsCleared() {
        guard isHighlightMode, firstGuessCell != nil, !hasHighlights else { return }
        triggerGuessGhost()
    }

    private func triggerGuessGhost() {
        guard let cell = firstGuessCell else { return }
        firstGuessCell = nil
        guessGhost = cell
        ghostPulse &+= 1
        ghostToken &+= 1
        let token = ghostToken
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            if ghostToken == token { guessGhost = nil }
        }
    }

    /// Clears every guess highlight (leaving real marks), and — like backing out of
    /// them — drops the fading "?" on the first guessed cell.
    func clearGuesses() {
        guard isHighlightMode, hasHighlights, !isRealizing else { return }
        pushHistory()
        highlights = Self.emptyHighlights(size: puzzle.size)
        highlightAutoDotCount.removeAll()
        tapPulse &+= 1
        noteHighlightsCleared()
    }

    private func currentSnapshot() -> Snapshot {
        Snapshot(marks: marks, autoDotCount: autoDotCount,
                 highlights: highlights, highlightAutoDotCount: highlightAutoDotCount)
    }

    /// Records the current board so the next action can be undone. Taking a fresh
    /// action invalidates any redo history.
    private func pushHistory() {
        history.append(currentSnapshot())
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
        redoStack.removeAll()
        dismissHint()
    }

    // MARK: - Drag-to-mark

    /// Board state captured when a drag begins, so each move recomputes the stroke
    /// from scratch (letting the line grow and shrink as the finger moves).
    private var dragBase: [[CellMark]]?
    private var dragBaseHighlights: [[CellHighlight]]?
    private var dragLength = 0

    /// Starts a drag stroke: snapshots the board once for Undo and for recomputation.
    func beginDrag() {
        guard !isGenerating, !isSolved, !isRealizing else { return }
        pushHistory()
        dragLength = 0
        if isHighlightMode {
            dragBaseHighlights = highlights
        } else {
            clearCheck()
            dragBase = marks
        }
    }

    /// Paints a straight line of dots between `start` and `end` (which share a row or
    /// column), leaving stars untouched and rebuilding the stroke from the pre-drag
    /// board each call so dragging back over the line erases it again. In Highlight
    /// mode it paints guess-dots on the guess layer; otherwise real dots — the two
    /// modes behave identically.
    func dragPaint(from start: GridPosition, to end: GridPosition) {
        let cells = Self.lineCells(from: start, to: end)
        if isHighlightMode {
            guard let base = dragBaseHighlights else { return }
            var updated = base
            for cell in cells where updated[cell.row][cell.col] != .guessStar {
                if firstGuessCell == nil { firstGuessCell = cell }
                updated[cell.row][cell.col] = .guessEmpty
            }
            highlights = updated
        } else {
            guard let base = dragBase else { return }
            var updated = base
            for cell in cells where updated[cell.row][cell.col] != .star {
                updated[cell.row][cell.col] = .dot
            }
            marks = updated
        }
        if cells.count != dragLength {
            dragLength = cells.count
            lastActionPlacedStar = false
            tapPulse &+= 1 // a light tick as the stroke crosses each new cell
        }
    }

    /// Ends a drag stroke.
    func endDrag() {
        dragBase = nil
        dragBaseHighlights = nil
        dragLength = 0
        noteHighlightsCleared()
        evaluateWin()
    }

    /// The cells on the straight line between two points that share a row or column.
    private static func lineCells(from a: GridPosition, to b: GridPosition) -> [GridPosition] {
        if a.row == b.row {
            let lo = min(a.col, b.col), hi = max(a.col, b.col)
            return (lo...hi).map { GridPosition(row: a.row, col: $0) }
        } else {
            let lo = min(a.row, b.row), hi = max(a.row, b.row)
            return (lo...hi).map { GridPosition(row: $0, col: a.col) }
        }
    }

    /// The eight cells touching `pos`, clipped to the board.
    private func neighbors(of pos: GridPosition) -> [GridPosition] {
        var result: [GridPosition] = []
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let r = pos.row + dr, c = pos.col + dc
                if r >= 0, r < puzzle.size, c >= 0, c < puzzle.size {
                    result.append(GridPosition(row: r, col: c))
                }
            }
        }
        return result
    }

    /// Marks the empty neighbours of a newly placed star as auto dots and records
    /// that this star is responsible for them.
    private func addAutoDots(around pos: GridPosition) {
        for n in neighbors(of: pos) {
            let mark = marks[n.row][n.col]
            // Never overwrite a star.
            if mark == .star { continue }
            let count = autoDotCount[n, default: 0]
            // A dot with no count is one the player placed by hand: leave it
            // (and don't start tracking it) so it survives this star's removal.
            if mark == .dot && count == 0 { continue }
            marks[n.row][n.col] = .dot
            autoDotCount[n] = count + 1
        }
    }

    /// Reverses `addAutoDots`: decrements the count for each neighbour and clears
    /// the dot once no remaining star is auto-dotting it. Hand-placed dots have no
    /// count, so they are left alone.
    private func removeAutoDots(around pos: GridPosition) {
        for n in neighbors(of: pos) {
            guard let count = autoDotCount[n] else { continue }
            if count <= 1 {
                autoDotCount[n] = nil
                if marks[n.row][n.col] == .dot {
                    marks[n.row][n.col] = .empty
                }
            } else {
                autoDotCount[n] = count - 1
            }
        }
    }

    // MARK: - Guess painting (Highlight mode)

    /// Grey-dots the neighbours of a white guess, ref-counted so hand-placed grey
    /// guesses survive and shared neighbours stay until the last white guess goes.
    private func addGuessAutoDots(around pos: GridPosition) {
        for n in neighbors(of: pos) {
            let h = highlights[n.row][n.col]
            if h == .guessStar { continue }                  // never overwrite a star guess
            let count = highlightAutoDotCount[n, default: 0]
            if h == .guessEmpty && count == 0 { continue }   // hand-placed grey: leave it
            highlights[n.row][n.col] = .guessEmpty
            highlightAutoDotCount[n] = count + 1
        }
    }

    /// Reverses `addGuessAutoDots`.
    private func removeGuessAutoDots(around pos: GridPosition) {
        for n in neighbors(of: pos) {
            guard let count = highlightAutoDotCount[n] else { continue }
            if count <= 1 {
                highlightAutoDotCount[n] = nil
                if highlights[n.row][n.col] == .guessEmpty { highlights[n.row][n.col] = .none }
            } else {
                highlightAutoDotCount[n] = count - 1
            }
        }
    }

    // MARK: - Derived state

    /// Every star the player has placed.
    var starPositions: [GridPosition] {
        var result: [GridPosition] = []
        for r in 0..<puzzle.size {
            for c in 0..<puzzle.size where marks[r][c] == .star {
                result.append(GridPosition(row: r, col: c))
            }
        }
        return result
    }

    /// Flags every placed star that isn't part of the puzzle's (unique) solution.
    /// The highlight stays until the player next changes the board.
    func check() {
        guard !isGenerating, !puzzle.solution.isEmpty else { return }
        let wrong = starPositions.filter { !puzzle.solution.contains($0) }
        wrongStars = Set(wrong)
        lastCheckHadErrors = !wrong.isEmpty
        checkPulse &+= 1
        if lastCheckHadErrors {
            playWrongHaptics()
            badPlacementThisGame = true
            if !isPreview { StatsStore.recordBadGuesses(wrong.count) }
        }
    }

    /// A short, strong buzz of heavy impacts to signal a wrong placement.
    private func playWrongHaptics() {
        Task { @MainActor in
            for _ in 0..<5 {
                wrongPulse &+= 1
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    /// Drops any "Check" highlight; called whenever the board changes.
    private func clearCheck() {
        if !wrongStars.isEmpty { wrongStars.removeAll() }
    }

    // MARK: - Hint

    /// Works out the next logically-forced move, places it on the board, and stores
    /// an explanation in `hintMessage` for the view to show. If the player has an
    /// incorrect cherry, or the position needs a guess, nothing is placed and the
    /// message says so.
    func hint(item: String = "cherry", items: String = "cherries") {
        guard canHint else { return }
        hintUsedThisGame = true
        if !isPreview { StatsStore.recordHint() }
        let result = HintEngine.nextHint(puzzle: puzzle, marks: marks, item: item, items: items)

        if result.outcome == .place, let pos = result.position {
            pushHistory()
            clearCheck()
            if result.placesStar {
                if marks[pos.row][pos.col] != .star {
                    autoDotCount[pos] = nil          // this cell is becoming a cherry
                    marks[pos.row][pos.col] = .star
                    addAutoDots(around: pos)
                }
                lastActionPlacedStar = true
            } else {
                marks[pos.row][pos.col] = .dot
                lastActionPlacedStar = false
            }
            tapPulse &+= 1
            evaluateWin()
        }

        // Highlight the relevant square (the placed cell, or the offending one for a
        // mistake) so the explanation can sit beside it.
        hintFocus = result.position
        hintMessage = result.message
        hintPulse &+= 1
    }

    /// Dismisses the current hint highlight and explanation.
    func dismissHint() {
        hintMessage = nil
        hintFocus = nil
    }

    // MARK: - Highlight (guessing) mode

    /// Enters or leaves Highlight mode. Leaving keeps the painted guesses on the
    /// board — it only changes what tapping does.
    func toggleHighlightMode() {
        guard !isRealizing else { return }
        dismissHint()
        firstGuessCell = nil          // each Mark session tracks its own first guess
        isHighlightMode.toggle()
    }

    /// Commits the painted guesses to real marks, one at a time with a short delay
    /// so the board fills in gradually, clearing each guess colour as it goes.
    /// White guesses become stars, grey guesses become dots. Undoable as one step.
    func realizeGuesses() async {
        guard !isGenerating, !isRealizing else { return }
        let guesses = guessedCells()
        guard !guesses.isEmpty else { return }

        pushHistory()
        clearCheck()
        isRealizing = true
        for (pos, guess) in guesses {
            withAnimation(.easeOut(duration: 0.18)) {
                switch guess {
                case .guessStar:
                    marks[pos.row][pos.col] = .star
                    // Play it out for real: dot the neighbours where appropriate.
                    addAutoDots(around: pos)
                    if !puzzle.solution.contains(pos) { badPlacementThisGame = true }
                case .guessEmpty:
                    marks[pos.row][pos.col] = .dot
                case .none:
                    break
                }
                highlights[pos.row][pos.col] = .none
            }
            tapPulse &+= 1
            try? await Task.sleep(for: .milliseconds(150))
        }
        highlightAutoDotCount.removeAll()
        firstGuessCell = nil          // guesses committed — start a fresh session
        isRealizing = false
        evaluateWin()
    }

    /// Cells carrying a guess highlight, in reading order, paired with the guess.
    private func guessedCells() -> [(GridPosition, CellHighlight)] {
        var result: [(GridPosition, CellHighlight)] = []
        for r in 0..<puzzle.size {
            for c in 0..<puzzle.size where highlights[r][c] != .none {
                result.append((GridPosition(row: r, col: c), highlights[r][c]))
            }
        }
        return result
    }

    // MARK: - Win detection

    private func evaluateWin() {
        let wasSolved = isSolved
        isSolved = isValidSolution()
        if isSolved && !wasSolved {
            playCelebrationHaptics()
            if !isPreview {
                StatsStore.recordSolved(seconds: elapsedSeconds)
                recordCleanWinIfEarned()
                saveGame()
            }
        }
    }

    /// A win with no hint and no wrong cherry is a "clean win". After five of them,
    /// offer to step the difficulty up — once.
    private func recordCleanWinIfEarned() {
        guard !hintUsedThisGame, !badPlacementThisGame else { return }
        let defaults = UserDefaults.standard
        let wins = defaults.integer(forKey: SettingsKey.cleanWins) + 1
        defaults.set(wins, forKey: SettingsKey.cleanWins)

        let alreadyPrompted = defaults.bool(forKey: SettingsKey.difficultyPromptShown)
        if wins >= 5, !alreadyPrompted, difficulty.harder != nil {
            promptDifficultyIncrease = true
        }
    }

    /// Fires a short, strong sequence of heavy impacts to accompany the win.
    private func playCelebrationHaptics() {
        Task { @MainActor in
            for _ in 0..<9 {
                celebrationPulse &+= 1
                try? await Task.sleep(for: .milliseconds(110))
            }
        }
    }

    /// True when the board satisfies every Star Battle rule.
    private func isValidSolution() -> Bool {
        let stars = starPositions
        let target = puzzle.starsPerUnit
        guard stars.count == puzzle.size * target else { return false }

        var rowCount = Array(repeating: 0, count: puzzle.size)
        var colCount = Array(repeating: 0, count: puzzle.size)
        var regionCount = Array(repeating: 0, count: puzzle.size)
        for s in stars {
            rowCount[s.row] += 1
            colCount[s.col] += 1
            regionCount[puzzle.regionId(row: s.row, col: s.col)] += 1
        }
        guard rowCount.allSatisfy({ $0 == target }),
              colCount.allSatisfy({ $0 == target }),
              regionCount.allSatisfy({ $0 == target }) else { return false }

        for a in stars {
            for b in stars where a != b {
                if abs(a.row - b.row) <= 1 && abs(a.col - b.col) <= 1 {
                    return false
                }
            }
        }
        return true
    }

    // MARK: - Helpers

    private static func emptyMarks(size: Int) -> [[CellMark]] {
        Array(repeating: Array(repeating: .empty, count: size), count: size)
    }

    private static func emptyHighlights(size: Int) -> [[CellHighlight]] {
        Array(repeating: Array(repeating: .none, count: size), count: size)
    }
}
