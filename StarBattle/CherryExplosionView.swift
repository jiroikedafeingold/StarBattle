import SwiftUI

/// The win finale's first act: each piece on the solved board bursts in sequence.
///
/// This layer is sized to exactly overlay the board, so a burst can be drawn at the
/// real grid position of every solved piece. The parent reveals pieces one at a time
/// by raising `explodedCount`; each newly revealed `BurstView` plays its short
/// pop-and-scatter animation once, on appear, then leaves a faint stain behind. The
/// board itself hides the underlying piece as each one bursts, so the glyph appears to
/// detonate and vanish. The scatter and stain take the chosen piece's colour, so the
/// effect matches whatever the player plays with — cherry, star, ladybug, and so on.
struct CherryExplosionLayer: View {
    /// The solved pieces, in the order they should detonate.
    let stars: [GridPosition]
    /// How many pieces have burst so far (drives which `BurstView`s exist).
    let explodedCount: Int
    /// The grid dimension (cells per side), so we can place bursts by row/col.
    let size: Int
    /// The board's pixel side length; one cell is `side / size`.
    let side: CGFloat
    /// The piece the player chose — its colour tints every burst.
    let pieceStyle: PieceStyle

    private var cell: CGFloat { side / CGFloat(size) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<min(explodedCount, stars.count), id: \.self) { i in
                let pos = stars[i]
                BurstView(cell: cell, tint: pieceStyle.color)
                    .position(x: cell * CGFloat(pos.col) + cell / 2,
                              y: cell * CGFloat(pos.row) + cell / 2)
            }
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
    }
}

/// One piece's explosion: a white flash ring snapping outward plus a scatter of bits
/// flung radially in the piece's colours, all fading as they fly — then a soft stain
/// and a few specks that linger on the square. Runs once when it appears.
private struct BurstView: View {
    let cell: CGFloat

    @State private var go = false
    private let bits: [Bit]
    private let specks: [Speck]

    init(cell: CGFloat, tint: Color) {
        self.cell = cell
        let gold = Color(red: 0.99, green: 0.80, blue: 0.20)
        // Weighted toward the piece's own colour, with white sparks and a gold accent.
        let palette: [Color] = [tint, tint, tint, .white, gold]
        // A dozen bits flung at roughly even angles, each jittered so the scatter
        // never looks mechanical.
        self.bits = (0..<12).map { i in
            let base = Double(i) / 12 * 2 * .pi
            return Bit(
                angle: base + Double.random(in: -0.26...0.26),
                distance: Double.random(in: 0.45...1.05),
                size: CGFloat.random(in: 0.12...0.26),
                color: palette.randomElement() ?? tint)
        }
        // A handful of leftover specks that stay scattered near the centre.
        self.specks = (0..<5).map { _ in
            Speck(
                dx: CGFloat.random(in: -0.22...0.22),
                dy: CGFloat.random(in: -0.20...0.24),
                size: CGFloat.random(in: 0.06...0.12),
                color: tint)
        }
    }

    var body: some View {
        ZStack {
            residue
            burst
        }
    }

    /// The momentary blast: a flash ring and the flung, fading bits.
    private var burst: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: cell * 0.05)
                .frame(width: cell * (go ? 1.4 : 0.15),
                       height: cell * (go ? 1.4 : 0.15))
                .opacity(go ? 0 : 0.95)

            ForEach(bits.indices, id: \.self) { idx in
                let b = bits[idx]
                Circle()
                    .fill(b.color)
                    .frame(width: cell * b.size, height: cell * b.size)
                    .offset(x: go ? CGFloat(cos(b.angle)) * cell * CGFloat(b.distance) : 0,
                            y: go ? CGFloat(sin(b.angle)) * cell * CGFloat(b.distance) : 0)
                    .scaleEffect(go ? 0.35 : 1)
                    .opacity(go ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { go = true }
        }
    }

    /// What's left after the blast: a soft tinted smudge and a few specks that linger.
    private var residue: some View {
        ZStack {
            Circle()
                .fill(tintStain)
                .frame(width: cell * 0.5, height: cell * 0.5)
                .blur(radius: cell * 0.07)
                .opacity(go ? 0.22 : 0)

            ForEach(specks.indices, id: \.self) { idx in
                let s = specks[idx]
                Circle()
                    .fill(s.color)
                    .frame(width: cell * s.size, height: cell * s.size)
                    .offset(x: cell * s.dx, y: cell * s.dy)
                    .opacity(go ? 0.4 : 0)
            }
        }
        .animation(.easeOut(duration: 0.4), value: go)
    }

    /// The stain reuses the first speck's tint (every speck shares the piece colour).
    private var tintStain: Color { specks.first?.color ?? .gray }

    /// One scattered fragment's trajectory and look.
    private struct Bit {
        let angle: Double       // radians from cell centre
        let distance: Double    // travel, in cell-widths
        let size: CGFloat       // diameter, as a fraction of a cell
        let color: Color
    }

    /// One leftover speck that lingers on the square.
    private struct Speck {
        let dx: CGFloat         // offset from centre, in cell-widths
        let dy: CGFloat
        let size: CGFloat       // diameter, as a fraction of a cell
        let color: Color
    }
}

#Preview {
    ZStack {
        Color(white: 0.9)
        CherryExplosionLayer(
            stars: [GridPosition(row: 0, col: 0), GridPosition(row: 1, col: 2),
                    GridPosition(row: 2, col: 1)],
            explodedCount: 3, size: 4, side: 320, pieceStyle: .cherry)
    }
    .frame(width: 320, height: 320)
}
