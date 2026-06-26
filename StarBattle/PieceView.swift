import SwiftUI

/// The mark the player places on the board, drawn according to the chosen
/// `PieceStyle`. The cherry is a custom Canvas drawing; the other styles are
/// tintable SF Symbols. `isWrong` switches to a clearly different blue finish so
/// stars flagged by "Check" stand out.
struct PieceView: View {
    let style: PieceStyle
    let isWrong: Bool
    let size: CGFloat

    var body: some View {
        switch style {
        case .cherry:
            CherryView(isWrong: isWrong, size: size)
        default:
            EmojiPiece(style: style, isWrong: isWrong, size: size)
        }
    }
}

/// A bright colour-emoji piece (star, heart, dog, ladybug…) with a soft drop shadow
/// so it sits on the board with the same weight as the cherry. When flagged wrong by
/// "Check" it's drained of colour and ringed in red, an unmistakable "this one's off".
private struct EmojiPiece: View {
    let style: PieceStyle
    let isWrong: Bool
    let size: CGFloat

    var body: some View {
        Text(style.emoji)
            .font(.system(size: size * 0.74))
            .saturation(isWrong ? 0 : 1)
            .opacity(isWrong ? 0.75 : 1)
            .shadow(color: .black.opacity(0.22), radius: size * 0.035, x: 0, y: size * 0.02)
            .overlay {
                if isWrong {
                    Circle()
                        .stroke(Color.red, lineWidth: max(1.5, size * 0.06))
                        .frame(width: size * 0.94, height: size * 0.94)
                }
            }
            .frame(width: size, height: size)
    }
}

/// Colours describing one cherry finish.
private struct CherryPalette {
    let bright, mid, deep, outline, glow, stem, leaf: Color

    /// A ripe red cherry — the normal placed mark.
    static let ripe = CherryPalette(
        bright: Color(red: 1.0, green: 0.52, blue: 0.52),
        mid: Color(red: 0.86, green: 0.12, blue: 0.18),
        deep: Color(red: 0.52, green: 0.02, blue: 0.07),
        outline: Color(red: 0.36, green: 0.01, blue: 0.05),
        glow: Color(red: 0.95, green: 0.18, blue: 0.24),
        stem: Color(red: 0.40, green: 0.26, blue: 0.12),
        leaf: Color(red: 0.30, green: 0.62, blue: 0.22))

    /// A clearly different blue finish for cherries flagged wrong by "Check".
    static let wrong = CherryPalette(
        bright: Color(red: 0.74, green: 0.86, blue: 1.0),
        mid: Color(red: 0.24, green: 0.46, blue: 0.92),
        deep: Color(red: 0.06, green: 0.16, blue: 0.52),
        outline: Color(red: 0.03, green: 0.09, blue: 0.34),
        glow: Color(red: 0.30, green: 0.52, blue: 1.0),
        stem: Color(red: 0.30, green: 0.30, blue: 0.34),
        leaf: Color(red: 0.34, green: 0.52, blue: 0.40))
}

/// A glossy pair of cherries — the traditional two fruit joined by stems to a small
/// leaf. Drawn in a Canvas so it stays crisp at any cell size.
struct CherryView: View {
    let isWrong: Bool
    let size: CGFloat

    var body: some View {
        let p = isWrong ? CherryPalette.wrong : CherryPalette.ripe

        Canvas { ctx, sz in
            let s = min(sz.width, sz.height)

            // Cherry geometry, as fractions of the box.
            let left = CGPoint(x: 0.33 * s, y: 0.70 * s)
            let right = CGPoint(x: 0.67 * s, y: 0.76 * s)
            let rL = 0.225 * s
            let rR = 0.205 * s
            let join = CGPoint(x: 0.58 * s, y: 0.14 * s)

            // Stems (drawn behind the fruit).
            var stems = Path()
            stems.move(to: join)
            stems.addQuadCurve(to: CGPoint(x: left.x, y: left.y - rL * 0.7),
                               control: CGPoint(x: 0.40 * s, y: 0.30 * s))
            stems.move(to: join)
            stems.addQuadCurve(to: CGPoint(x: right.x, y: right.y - rR * 0.7),
                               control: CGPoint(x: 0.66 * s, y: 0.36 * s))
            ctx.stroke(stems, with: .color(p.stem),
                       style: StrokeStyle(lineWidth: max(1, 0.045 * s), lineCap: .round))

            // A small leaf near the join.
            var leaf = Path()
            leaf.move(to: join)
            leaf.addQuadCurve(to: CGPoint(x: 0.78 * s, y: 0.10 * s),
                              control: CGPoint(x: 0.64 * s, y: 0.01 * s))
            leaf.addQuadCurve(to: join,
                              control: CGPoint(x: 0.74 * s, y: 0.24 * s))
            leaf.closeSubpath()
            ctx.fill(leaf, with: .color(p.leaf))

            // The two cherries: each a radial-gradient sphere with a rim and a shine.
            for (c, r) in [(left, rL), (right, rR)] {
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [p.bright, p.mid, p.deep]),
                        center: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.40),
                        startRadius: r * 0.05, endRadius: r * 1.15))
                ctx.stroke(Path(ellipseIn: rect), with: .color(p.outline),
                           lineWidth: max(0.5, 0.03 * s))
                // Specular highlight near the upper-left.
                let hr = CGRect(x: c.x - r * 0.55, y: c.y - r * 0.62,
                                width: r * 0.50, height: r * 0.34)
                ctx.fill(Path(ellipseIn: hr), with: .color(.white.opacity(0.8)))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: p.glow.opacity(0.45), radius: size * 0.06, x: 0, y: 0)
        .shadow(color: .black.opacity(0.20), radius: size * 0.03, x: 0, y: size * 0.02)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(PieceStyle.allCases) { style in
            PieceView(style: style, isWrong: false, size: 56)
        }
    }
    .padding()
}
