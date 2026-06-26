import SwiftUI

/// The app icon artwork: a zoomed-in crop of a Cherry Battle board showing one small,
/// irregular region (seven cells) with its two cherries already correctly placed — far
/// enough apart that they never touch. Rendered from the `#Preview` below and exported
/// into `AppIcon.appiconset` (see the app-icon regeneration notes).
///
/// Not used at runtime; it exists purely so the icon can be re-rendered from code, like
/// the rest of the board art.
struct AppIconArt: View {
    /// A 5×5 crop. Region 0 (the focus) is a seven-cell blob in cherry red, centred in
    /// the icon; the surrounding cells are accent regions, so it reads as a slice of a
    /// larger board. The extra ring of cells keeps the cherries clear of the edges.
    private let regions = [
        [1, 1, 1, 1, 1],
        [3, 0, 0, 1, 1],
        [3, 0, 0, 0, 2],
        [3, 3, 0, 0, 2],
        [3, 3, 2, 2, 2]
    ]
    /// The two cherries of region 0 — diagonally apart (so they don't touch) and inset
    /// from every edge.
    private let cherries = [GridPosition(row: 1, col: 1), GridPosition(row: 3, col: 3)]

    private var cols: Int { regions[0].count }
    private var rows: Int { regions.count }

    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let cell = s / CGFloat(cols)

            ZStack(alignment: .topLeading) {
                // Region tints.
                ForEach(0..<(rows * cols), id: \.self) { i in
                    let r = i / cols, c = i % cols
                    Rectangle()
                        .fill(Self.tint(regions[r][c]))
                        .frame(width: cell, height: cell)
                        .position(x: cell * CGFloat(c) + cell / 2,
                                  y: cell * CGFloat(r) + cell / 2)
                }

                // Thin grid lines and thick region borders.
                IconBorders(regions: regions, cell: cell)

                // A gentle top-down sheen for a little depth.
                LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.06)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(width: s, height: s)
                    .blendMode(.softLight)

                // The two correctly-placed cherries.
                ForEach(Array(cherries.enumerated()), id: \.offset) { _, p in
                    CherryView(isWrong: false, size: cell * 0.82)
                        .position(x: cell * CGFloat(p.col) + cell / 2,
                                  y: cell * CGFloat(p.row) + cell / 2)
                }
            }
            .frame(width: s, height: s)
            .background(Color(red: 0.98, green: 0.96, blue: 0.94))
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// Soft, muted tints close to the in-game board, so the icon reads as a real board
    /// crop rather than a loud graphic.
    private static func tint(_ id: Int) -> Color {
        switch id {
        case 0:  return Color(red: 0.97, green: 0.78, blue: 0.78)   // cherry red (focus)
        case 1:  return Color(red: 0.99, green: 0.92, blue: 0.77)   // amber
        case 2:  return Color(red: 0.83, green: 0.93, blue: 0.79)   // green
        default: return Color(red: 0.80, green: 0.88, blue: 0.97)   // blue
        }
    }
}

/// Thin grid lines everywhere, with heavy ink wherever two regions meet — the same
/// language as the in-game board, so the icon reads as a genuine board crop.
private struct IconBorders: View {
    let regions: [[Int]]
    let cell: CGFloat

    private let ink = Color(red: 0.13, green: 0.14, blue: 0.17)
    private let gridLine = Color.black.opacity(0.12)

    var body: some View {
        Canvas { context, _ in
            let rows = regions.count, cols = regions[0].count
            let w = cell * CGFloat(cols), h = cell * CGFloat(rows)

            var grid = Path()
            for c in 0...cols {
                let x = CGFloat(c) * cell
                grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: h))
            }
            for r in 0...rows {
                let y = CGFloat(r) * cell
                grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: w, y: y))
            }
            context.stroke(grid, with: .color(gridLine), lineWidth: max(0.5, cell * 0.012))

            var thick = Path()
            for r in 0..<rows {
                for c in 0..<cols {
                    let reg = regions[r][c]
                    let x = CGFloat(c) * cell, y = CGFloat(r) * cell
                    if c == 0 || regions[r][c - 1] != reg {
                        thick.move(to: CGPoint(x: x, y: y)); thick.addLine(to: CGPoint(x: x, y: y + cell))
                    }
                    if c == cols - 1 || regions[r][c + 1] != reg {
                        thick.move(to: CGPoint(x: x + cell, y: y)); thick.addLine(to: CGPoint(x: x + cell, y: y + cell))
                    }
                    if r == 0 || regions[r - 1][c] != reg {
                        thick.move(to: CGPoint(x: x, y: y)); thick.addLine(to: CGPoint(x: x + cell, y: y))
                    }
                    if r == rows - 1 || regions[r + 1][c] != reg {
                        thick.move(to: CGPoint(x: x, y: y + cell)); thick.addLine(to: CGPoint(x: x + cell, y: y + cell))
                    }
                }
            }
            context.stroke(thick, with: .color(ink),
                           style: StrokeStyle(lineWidth: cell * 0.07, lineJoin: .round))
        }
    }
}

#Preview {
    AppIconArt()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
}
