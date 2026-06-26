import SwiftUI

/// Renders the puzzle grid: region tints, thick region borders, and the player's
/// stars and dots.
///
/// A single tap cycles a cell (via `onTap`). Dragging across cells paints dots:
/// once the finger crosses into a second cell the stroke locks to whichever axis
/// it started moving along, and stays on that row/column even if the finger drifts
/// — so a quick horizontal or vertical swipe lays down a clean straight line.
struct BoardView: View {
    let puzzle: Puzzle
    let marks: [[CellMark]]
    /// Per-cell guess colours painted in Highlight mode, indexed `[row][col]`.
    let highlights: [[CellHighlight]]
    /// Stars flagged as incorrect by "Check"; drawn in red.
    let wrongStars: Set<GridPosition>
    /// The glyph used for placed marks and guess ghosts (from Settings).
    var pieceStyle: PieceStyle = .cherry
    /// The cell the current hint refers to; drawn with an attention ring.
    var hintCell: GridPosition? = nil
    /// A cell to mark with a slowly-fading "?" (where the player's guessing began).
    var ghostCell: GridPosition? = nil
    /// Bumped when a new ghost appears, so its 15s fade restarts.
    var ghostPulse: Int = 0
    /// Stars to leave undrawn — used by the win finale, where each cherry vanishes as
    /// it bursts (the burst itself is drawn by an overlay above the board).
    var hiddenStars: Set<GridPosition> = []
    let onTap: (Int, Int) -> Void
    let onDragBegin: () -> Void
    let onDragPaint: (GridPosition, GridPosition) -> Void
    let onDragEnd: () -> Void

    private enum DragAxis { case horizontal, vertical }

    @State private var dragStart: GridPosition?
    @State private var dragAxis: DragAxis?
    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let dim = min(geo.size.width, geo.size.height)
            let cell = dim / CGFloat(puzzle.size)

            ZStack {
                ForEach(0..<puzzle.size, id: \.self) { row in
                    ForEach(0..<puzzle.size, id: \.self) { col in
                        CellView(
                            mark: marks[row][col],
                            highlight: highlights[row][col],
                            regionColor: Color.regionColor(puzzle.regionId(row: row, col: col)),
                            isWrong: wrongStars.contains(GridPosition(row: row, col: col)),
                            hideStar: hiddenStars.contains(GridPosition(row: row, col: col)),
                            pieceStyle: pieceStyle,
                            cellSize: cell
                        )
                        .frame(width: cell, height: cell)
                        .position(x: cell * CGFloat(col) + cell / 2,
                                  y: cell * CGFloat(row) + cell / 2)
                    }
                }

                RegionBorders(puzzle: puzzle, cell: cell)
                    .allowsHitTesting(false)

                if let hintCell {
                    HintRing(cell: cell)
                        .position(x: cell * CGFloat(hintCell.col) + cell / 2,
                                  y: cell * CGFloat(hintCell.row) + cell / 2)
                        .allowsHitTesting(false)
                }

                if let ghostCell {
                    GhostMark(cell: cell)
                        .id(ghostPulse)   // restart the fade for each new ghost
                        .position(x: cell * CGFloat(ghostCell.col) + cell / 2,
                                  y: cell * CGFloat(ghostCell.row) + cell / 2)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: dim, height: dim)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in handleChange(value, cell: cell) }
                    .onEnded { value in handleEnd(value, cell: cell) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Gesture handling

    private func cell(at point: CGPoint, cellSize: CGFloat) -> GridPosition {
        let last = puzzle.size - 1
        let col = min(max(Int(point.x / cellSize), 0), last)
        let row = min(max(Int(point.y / cellSize), 0), last)
        return GridPosition(row: row, col: col)
    }

    private func handleChange(_ value: DragGesture.Value, cell: CGFloat) {
        let current = self.cell(at: value.location, cellSize: cell)

        guard let start = dragStart else {
            dragStart = current
            return
        }

        if !isDragging {
            // A drag only begins once the finger leaves the starting cell; until
            // then it might still be a tap.
            guard current != start else { return }
            dragAxis = abs(value.translation.width) >= abs(value.translation.height)
                ? .horizontal : .vertical
            isDragging = true
            onDragBegin()
        }
        paint(from: start, to: current)
    }

    private func handleEnd(_ value: DragGesture.Value, cell: CGFloat) {
        let start = dragStart ?? self.cell(at: value.startLocation, cellSize: cell)
        if isDragging {
            onDragEnd()
        } else {
            onTap(start.row, start.col)
        }
        dragStart = nil
        dragAxis = nil
        isDragging = false
    }

    /// Paints a straight line of dots from `start` to `current`, clamped to the
    /// locked axis so off-course drift is ignored.
    private func paint(from start: GridPosition, to current: GridPosition) {
        let end: GridPosition
        switch dragAxis {
        case .vertical:
            end = GridPosition(row: current.row, col: start.col)
        default:
            end = GridPosition(row: start.row, col: current.col)
        }
        onDragPaint(start, end)
    }
}

/// A single grid cell: a tinted background plus an optional star or dot.
private struct CellView: View {
    let mark: CellMark
    let highlight: CellHighlight
    let regionColor: Color
    let isWrong: Bool
    /// When true, a `.star` cell draws no piece (it's mid-burst in the win finale).
    var hideStar: Bool = false
    let pieceStyle: PieceStyle
    let cellSize: CGFloat

    var body: some View {
        ZStack {
            background

            // A faint preview of what the guess will become, shown only on an
            // otherwise-empty cell.
            if mark == .empty {
                GuessGlyph(highlight: highlight, pieceStyle: pieceStyle, cellSize: cellSize)
            }

            switch mark {
            case .empty:
                EmptyView()
            case .star:
                if !hideStar {
                    PieceView(style: pieceStyle, isWrong: isWrong, size: cellSize * 0.80)
                }
            case .dot:
                Circle()
                    // Fixed dark grey so the dot reads on the light board in both
                    // light and dark appearance.
                    .fill(Color(white: 0.32))
                    .frame(width: cellSize * 0.17, height: cellSize * 0.17)
            }
        }
        .contentShape(Rectangle())
    }

    /// The cell's background: its region tint, or a guess colour in Highlight mode —
    /// white for "will be a star", a grey wash for "not a star".
    @ViewBuilder private var background: some View {
        switch highlight {
        case .none:
            regionColor
        case .guessStar:
            // Pale yellow — a "this will be a star" candidate.
            Color(red: 1.0, green: 0.96, blue: 0.74)
        case .guessEmpty:
            ZStack {
                regionColor
                Color(white: 0.5).opacity(0.6)
            }
        }
    }
}

/// A faint "ghost" of the mark a guess colour will become — a translucent star for
/// a "will be a star" guess, a translucent dot for a "not a star" guess. Reused on
/// the board cells and on the colour-selector swatches.
struct GuessGlyph: View {
    let highlight: CellHighlight
    var pieceStyle: PieceStyle = .cherry
    let cellSize: CGFloat

    var body: some View {
        switch highlight {
        case .guessStar:
            // A soft, faded piece — a quiet "this will be a cherry" hint on the
            // pale-yellow cell.
            PieceView(style: pieceStyle, isWrong: false, size: cellSize * 0.80)
                .opacity(0.42)
        case .guessEmpty:
            Circle()
                .fill(Color(white: 0.28))
                .frame(width: cellSize * 0.17, height: cellSize * 0.17)
                .opacity(0.5)
        case .none:
            EmptyView()
        }
    }
}

/// A pulsing ring that draws the eye to the cell a hint refers to.
private struct HintRing: View {
    let cell: CGFloat
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: cell * 0.18)
            .strokeBorder(Color.blue, lineWidth: max(2, cell * 0.10))
            .frame(width: cell, height: cell)
            .shadow(color: .blue.opacity(0.7), radius: cell * 0.18)
            .scaleEffect(pulse ? 1.0 : 0.86)
            .opacity(pulse ? 1.0 : 0.65)
            .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

/// A slight highlight left on the square where the player's guessing began,
/// fading out over 15 seconds.
private struct GhostMark: View {
    let cell: CGFloat
    @State private var faded = false

    var body: some View {
        RoundedRectangle(cornerRadius: cell * 0.12)
            .strokeBorder(Color.purple, lineWidth: max(2, cell * 0.07))
            .frame(width: cell, height: cell)
            .opacity(faded ? 0 : 0.75)
            .onAppear {
                faded = false
                withAnimation(.linear(duration: 10)) { faded = true }
            }
    }
}

/// Draws thin grid lines, thick borders between regions, and a heavy outer frame.
private struct RegionBorders: View {
    let puzzle: Puzzle
    let cell: CGFloat

    // Fixed inks so the board reads the same on light and dark backgrounds: it is
    // a light play surface in both appearances.
    private let ink = Color(red: 0.13, green: 0.14, blue: 0.17)
    private let gridLine = Color.black.opacity(0.14)

    var body: some View {
        Canvas { context, _ in
            let n = puzzle.size
            let full = cell * CGFloat(n)

            // Thin lines for every cell boundary.
            var grid = Path()
            for i in 0...n {
                let p = CGFloat(i) * cell
                grid.move(to: CGPoint(x: p, y: 0)); grid.addLine(to: CGPoint(x: p, y: full))
                grid.move(to: CGPoint(x: 0, y: p)); grid.addLine(to: CGPoint(x: full, y: p))
            }
            context.stroke(grid, with: .color(gridLine), lineWidth: 0.5)

            // Thick lines wherever two different regions meet.
            var thick = Path()
            for r in 0..<n {
                for c in 0..<n {
                    let reg = puzzle.regions[r][c]
                    let x = CGFloat(c) * cell, y = CGFloat(r) * cell
                    if c == 0 || puzzle.regions[r][c - 1] != reg {
                        thick.move(to: CGPoint(x: x, y: y)); thick.addLine(to: CGPoint(x: x, y: y + cell))
                    }
                    if c == n - 1 || puzzle.regions[r][c + 1] != reg {
                        thick.move(to: CGPoint(x: x + cell, y: y)); thick.addLine(to: CGPoint(x: x + cell, y: y + cell))
                    }
                    if r == 0 || puzzle.regions[r - 1][c] != reg {
                        thick.move(to: CGPoint(x: x, y: y)); thick.addLine(to: CGPoint(x: x + cell, y: y))
                    }
                    if r == n - 1 || puzzle.regions[r + 1][c] != reg {
                        thick.move(to: CGPoint(x: x, y: y + cell)); thick.addLine(to: CGPoint(x: x + cell, y: y + cell))
                    }
                }
            }
            context.stroke(thick, with: .color(ink),
                           style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))

            // Heavy outer frame.
            let outer = Path(CGRect(x: 0, y: 0, width: full, height: full))
            context.stroke(outer, with: .color(ink), lineWidth: 3)
        }
    }
}

extension Color {
    /// Ten soft, distinct region tints. Each region id maps to its own colour.
    private static let regionPalette: [Color] = [
        Color(red: 0.98, green: 0.80, blue: 0.80),
        Color(red: 0.80, green: 0.90, blue: 0.98),
        Color(red: 0.85, green: 0.95, blue: 0.80),
        Color(red: 0.99, green: 0.93, blue: 0.78),
        Color(red: 0.92, green: 0.85, blue: 0.98),
        Color(red: 0.80, green: 0.96, blue: 0.94),
        Color(red: 0.99, green: 0.86, blue: 0.74),
        Color(red: 0.95, green: 0.83, blue: 0.92),
        Color(red: 0.88, green: 0.90, blue: 0.80),
        Color(red: 0.83, green: 0.87, blue: 0.95)
    ]

    static func regionColor(_ id: Int) -> Color {
        guard id >= 0 else { return Color(white: 0.95) }
        return regionPalette[id % regionPalette.count]
    }
}

#Preview("Icon") {
    // A fully solved board (every solution star placed, no dots), edge-to-edge and
    // text-free, for capturing the app icon.
    let p = Puzzle.starters.first ?? Puzzle.placeholder()
    var marks = Array(repeating: Array(repeating: CellMark.empty, count: p.size), count: p.size)
    for s in p.solution { marks[s.row][s.col] = .star }
    let highlights = Array(repeating: Array(repeating: CellHighlight.none, count: p.size), count: p.size)

    return BoardView(puzzle: p, marks: marks, highlights: highlights, wrongStars: [],
                     onTap: { _, _ in }, onDragBegin: {}, onDragPaint: { _, _ in }, onDragEnd: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
}

#Preview("Board") {
    // A static 2x5 block layout (10 regions) so both vertical and horizontal
    // region borders are visible, with a few sample marks.
    let size = 10
    var regions = Array(repeating: Array(repeating: 0, count: size), count: size)
    for r in 0..<size {
        for c in 0..<size {
            regions[r][c] = (r / 2) + (c >= 5 ? 5 : 0)
        }
    }
    let puzzle = Puzzle(size: size, starsPerUnit: 2, regions: regions, solution: [])
    var marks = Array(repeating: Array(repeating: CellMark.empty, count: size), count: size)
    marks[0][0] = .star          // gold stars
    marks[0][8] = .star
    marks[3][7] = .star          // flagged-wrong star (red)
    marks[5][5] = .dot
    marks[6][2] = .dot
    let wrong: Set<GridPosition> = [GridPosition(row: 3, col: 7)]

    var highlights = Array(repeating: Array(repeating: CellHighlight.none, count: size), count: size)
    highlights[2][2] = .guessStar   // white "will be a star" guess
    highlights[8][8] = .guessEmpty  // greyed "not a star" guess

    return BoardView(puzzle: puzzle, marks: marks, highlights: highlights, wrongStars: wrong,
                     onTap: { _, _ in }, onDragBegin: {}, onDragPaint: { _, _ in }, onDragEnd: {})
        .padding()
}
