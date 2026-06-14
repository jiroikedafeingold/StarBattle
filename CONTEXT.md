# Cherry Battle — Project Context

A SwiftUI logic-puzzle game (a "Star Battle" variant, re-themed to cherries) for
iPhone and iPad. The player places **two cherries in every row, column and region**
of a 10×10 grid, where no two cherries may touch — not even diagonally.

> **Naming note:** the product is presented to users as **Cherry Battle**
> (`INFOPLIST_KEY_CFBundleDisplayName = "Cherry Battle"`), and all on-screen text
> and artwork use cherries. The **Xcode project, target, scheme, source folder and
> many internal identifiers are still named `StarBattle` / `star`** (e.g.
> `CellMark.star`, `Puzzle.starsPerUnit`, `wrongStars`, `guessStar`). These were
> kept to avoid risky project-file surgery and a sweeping rename; they are invisible
> to users. A future pass could rename them for consistency.

## Stack & conventions
- SwiftUI only, async/await (no Combine, no UIKit). Min iOS 17.
- MVVM: one `@Observable` view model, views stay thin. `GameViewModel` is
  `@MainActor` and does **not** import SwiftUI types into its logic.
- Xcode project uses a **PBXFileSystemSynchronizedRootGroup** — files added to the
  `StarBattle/` folder on disk are auto-included in the target. (This is why a
  stray `Assets 2.xcassets` once appeared; do **not** create catalogs via the MCP
  `XcodeWrite`, which conflicts with the synchronized group — write files to disk.)

## File map (`StarBattle/StarBattle/`)
- `StarBattleApp.swift` — `@main` app entry → `ContentView`.
- `ContentView.swift` — hosts `GameView`.
- `GameView.swift` — the whole game screen: header, board, controls, highlight bar,
  legend, win celebration, confirmation dialogs, and all haptics
  (`.sensoryFeedback`). Board is sized to the **full screen width** in both normal
  and Highlight mode via a `GeometryReader` (`side = min(width,560) - 32`) and a
  `ScrollView` so smaller devices can scroll if needed.
- `GameViewModel.swift` — live game state: `marks` (`[[CellMark]]`), `highlights`
  (Highlight/guess layer), undo `history`, auto-dot ref-counting, win detection,
  prefetch queue. Key bits:
  - **Auto-dots:** placing a cherry dots its 8 neighbours (ref-counted so shared
    neighbours and hand-placed dots survive correctly). Mirrored for the guess layer.
  - **Highlight mode:** paint "will be a cherry" (white/pale-yellow) or "not a
    cherry" (grey) guesses, then `realizeGuesses()` commits them one-by-one.
  - **Prefetch:** `topUpPrefetch()` keeps `prefetchDepth` (2) puzzles generating off
    the main actor via `Task.detached`, so "New" is usually instant. On-demand
    generation shows the "Creating a new board…" overlay.
  - **Celebration haptics:** on first solve, `playCelebrationHaptics()` bumps
    `celebrationPulse` 9× (~110 ms apart); the view fires a `.heavy` impact each bump
    for a strong rolling rumble, plus a `.success`.
- `BoardView.swift` — renders the grid (region tints, thin grid, thick region
  borders via `Canvas`), the marks, and the guess layer. **`CherryView`** draws the
  glossy pair-of-cherries mark in a `Canvas` (radial-gradient spheres, stems, leaf,
  specular highlight); `CherryPalette.ripe` (red) for normal, `.wrong` (blue) for
  cherries flagged by Check. Contains two `#Preview`s: index 0 **"Icon"** (a fully
  solved, edge-to-edge, text-free board used to render the app icon) and index 1
  "Board" (sample marks).
- `Models.swift` — `GridPosition`, `CellMark` (`.empty/.star/.dot`),
  `CellHighlight` (`.none/.guessStar/.guessEmpty`), `Puzzle`.
- `PuzzleGenerator.swift` — generates puzzles. `generate()` runs on a detached
  task. `buildPuzzle()` creates a random solution, grows regions, kills alternate
  solutions to guarantee uniqueness, and **prefers logically-solvable (no-guessing)
  puzzles** via an incremental deduction solver (`logicallySolvable`), falling back
  to a guaranteed-unique puzzle if none is found in the attempt budget.
- `PuzzleStore.swift` — on-disk pool of generated puzzles for launch-screen variety.
- `StarterPuzzles.swift` — bundled starter puzzles (`Puzzle.starters`) for instant
  first launch (and used by the Icon preview).
- `CelebrationView.swift` — falling-confetti win animation (🍒 cherries, dots,
  ribbons).
- `Assets.xcassets/AppIcon.appiconset/AppIcon.png` — 1024² app icon, a solved cherry
  board. **Regenerated** by rendering the "Icon" preview (index 0 in
  `BoardView.swift`), centered-square cropping with `sips -c W W`, and resizing to
  1024. `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.

## Webpage
- `docs/index.html` (+ `docs/icon.png`, `docs/board.png`) — a self-contained landing
  page, GitHub-Pages-ready from `/docs` on `main`.

## Regenerating the app icon
1. Edit the "Icon" `#Preview` in `BoardView.swift` if needed (it places every
   `solution` cherry on `Puzzle.starters.first`).
2. `RenderPreview` `BoardView.swift` index 0 → snapshot PNG.
3. `W=$(sips -g pixelWidth SNAP)`, `sips -c $W $W SNAP --out crop.png`,
   `sips -z 1024 1024 crop.png --out AppIcon.png`, copy into the appiconset.
4. Build; verify `AppIcon60x60@2x.png` + `Assets.car` appear in the built `.app`.
   On device, delete the app first to clear the home-screen icon cache.

## Build / verify
- Scheme `StarBattle`, destinations iPhone 17 Pro / iPad Pro 13" (M4).
- Generation is correct-by-construction (unique fallback). The **logically-solvable
  hit-rate has not been measured** at runtime yet — a good follow-up.

## Known follow-ups
- Measure & tune the logically-solvable pass rate vs. unique fallback.
- Optionally complete the internal `star → cherry` identifier rename and rename the
  Xcode target/scheme/bundle (project-file surgery; do carefully).
