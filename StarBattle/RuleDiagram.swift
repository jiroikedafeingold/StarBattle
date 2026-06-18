import SwiftUI

/// One cell in a small instructional board diagram.
enum MiniCell: Equatable {
    case empty
    case dot
    case cherry
}

/// A small, self-contained board snippet used to illustrate the rules in
/// onboarding, Help, and (rendered to PNG) the website. It draws just a few cells
/// with cherries and dots so a single situation reads at a glance.
struct MiniBoard: View {
    let grid: [[MiniCell]]
    var piece: PieceStyle = .cherry
    /// Which cells are tinted as a region (defaults to none).
    var tintMask: [[Bool]]? = nil
    var tint: Color = Color(red: 0.80, green: 0.90, blue: 0.98)
    var cell: CGFloat = 34

    var body: some View {
        VStack(spacing: 0) {
            ForEach(grid.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(grid[r].indices, id: \.self) { c in
                        cellView(grid[r][c], tinted: tintMask?[r][c] ?? false)
                            .frame(width: cell, height: cell)
                            .overlay(Rectangle().strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5))
                    }
                }
            }
        }
        .background(Color.white)
        .overlay(Rectangle().strokeBorder(Color.black.opacity(0.55), lineWidth: 1.5))
    }

    @ViewBuilder private func cellView(_ kind: MiniCell, tinted: Bool) -> some View {
        ZStack {
            if tinted { tint } else { Color.white }
            switch kind {
            case .empty:
                EmptyView()
            case .dot:
                Circle().fill(Color(white: 0.4))
                    .frame(width: cell * 0.17, height: cell * 0.17)
            case .cherry:
                PieceView(style: piece, isWrong: false, size: cell * 0.78)
            }
        }
    }
}

/// A labelled example: a `MiniBoard` with an optional ✓/✗ verdict badge and caption.
struct RuleExample: View {
    let title: String
    let board: MiniBoard
    var ok: Bool? = nil
    var detail: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            board
                .overlay(alignment: .topTrailing) {
                    if let ok {
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, ok ? Color.green : Color.red)
                            .background(Circle().fill(.white).padding(3))
                            .offset(x: 10, y: -10)
                    }
                }
            Text(title).font(.subheadline.bold())
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// The canonical rule diagrams, shared by onboarding, Help and the website export.
enum RuleDiagrams {
    private static let e = MiniCell.empty
    private static let d = MiniCell.dot
    private static let x = MiniCell.cherry

    /// A cherry surrounded by dots — it blocks all eight touching squares.
    static func neverTouch(piece: PieceStyle = .cherry, cell: CGFloat = 34) -> MiniBoard {
        MiniBoard(grid: [[d, d, d], [d, x, d], [d, d, d]], piece: piece, cell: cell)
    }

    /// Two cherries in a line with a gap — the legal way to place a pair.
    static func twoPerLine(piece: PieceStyle = .cherry, cell: CGFloat = 34) -> MiniBoard {
        MiniBoard(grid: [[x, d, e, x, d]], piece: piece, cell: cell)
    }

    /// Two cherries touching at a corner — illegal.
    static func touchBad(piece: PieceStyle = .cherry, cell: CGFloat = 34) -> MiniBoard {
        MiniBoard(grid: [[x, e, e], [e, x, e], [e, e, e]], piece: piece, cell: cell)
    }

    /// A coloured region holding its two (non-touching) cherries.
    static func region(piece: PieceStyle = .cherry, cell: CGFloat = 34) -> MiniBoard {
        MiniBoard(grid: [[x, e, e], [e, e, e], [e, e, x]],
                  piece: piece,
                  tintMask: Array(repeating: Array(repeating: true, count: 3), count: 3),
                  cell: cell)
    }
}

/// A grid of the four key rule examples — reused in Help and exported for the website.
struct RuleExamplesView: View {
    var piece: PieceStyle = .cherry

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 20) {
            RuleExample(title: "Two per line",
                        board: RuleDiagrams.twoPerLine(piece: piece),
                        ok: true,
                        detail: "Each row and column gets exactly two — with a gap.")
            RuleExample(title: "Never touching",
                        board: RuleDiagrams.neverTouch(piece: piece),
                        detail: "A cherry rules out all eight neighbours.")
            RuleExample(title: "Not even diagonally",
                        board: RuleDiagrams.touchBad(piece: piece),
                        ok: false,
                        detail: "Corner-to-corner still counts as touching.")
            RuleExample(title: "Two per region",
                        board: RuleDiagrams.region(piece: piece),
                        detail: "Every coloured group holds two as well.")
        }
        .padding()
    }
}

#Preview("Examples") {
    RuleExamplesView()
        .padding()
        .background(Color.white)
}

// Web export: one image per "how to play" rule group.

#Preview("web-rule1") {
    HStack(alignment: .top, spacing: 36) {
        RuleExample(title: "Two per line",
                    board: RuleDiagrams.twoPerLine(cell: 42), ok: true)
        RuleExample(title: "Two per region",
                    board: RuleDiagrams.region(cell: 42))
    }
    .padding(36)
    .background(Color.white)
}

#Preview("web-rule2") {
    HStack(alignment: .top, spacing: 36) {
        RuleExample(title: "Blocks neighbours",
                    board: RuleDiagrams.neverTouch(cell: 42))
        RuleExample(title: "Not even diagonally",
                    board: RuleDiagrams.touchBad(cell: 42), ok: false)
    }
    .padding(36)
    .background(Color.white)
}
