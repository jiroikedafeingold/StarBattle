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
        case .star:
            StarView(isWrong: isWrong, size: size)
        default:
            EmojiPiece(style: style, isWrong: isWrong, size: size)
        }
    }
}

/// A glossy, dimensional gold star — the default piece — drawn in a Canvas so it stays
/// crisp at any size, with a top-lit metallic gradient, a dark rim for definition, and a
/// specular shine. A blue finish marks a star flagged wrong by "Check".
struct StarView: View {
    let isWrong: Bool
    let size: CGFloat

    var body: some View {
        let p = isWrong ? Self.wrong : Self.gold
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height)
            let c = CGPoint(x: s / 2, y: s * 0.53)   // nudged down — stars read top-heavy
            let R = s * 0.47, r = s * 0.198
            let verts = Self.starPoints(center: c, outer: R, inner: r, points: 5)
            let path = Self.star(from: verts)

            // Base: a raised-centre radial gradient (bright core fading to a deep rim),
            // reading as a rounded, puffed solid rather than a flat cut-out.
            ctx.fill(path, with: .radialGradient(
                Gradient(colors: [p.bright, p.mid, p.deep]),
                center: CGPoint(x: c.x - s * 0.05, y: c.y - s * 0.06),
                startRadius: s * 0.02, endRadius: R * 1.02))

            // Facet shading: treat each triangular facet (centre → two rim vertices) as a
            // slanted plane and light it by how much it faces a top-left light. Facets
            // tilted toward the light brighten; those away darken — a gem-cut 3D look.
            let light = CGVector(dx: -0.42, dy: -0.91)
            for i in 0..<verts.count {
                let a = verts[i], b = verts[(i + 1) % verts.count]
                var tri = Path()
                tri.move(to: c); tri.addLine(to: a); tri.addLine(to: b); tri.closeSubpath()
                let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
                var dx = mid.x - c.x, dy = mid.y - c.y
                let len = max(0.0001, (dx * dx + dy * dy).squareRoot())
                dx /= len; dy /= len
                let d = dx * light.dx + dy * light.dy
                if d > 0 {
                    ctx.fill(tri, with: .color(.white.opacity(0.42 * d)))
                } else {
                    ctx.fill(tri, with: .color(.black.opacity(0.36 * -d)))
                }
            }

            // Crisp ridge highlights running out along the spine of each arm.
            var ridges = Path()
            for i in stride(from: 0, to: verts.count, by: 2) {
                ridges.move(to: c); ridges.addLine(to: verts[i])
            }
            ctx.stroke(ridges, with: .color(.white.opacity(0.20)),
                       style: StrokeStyle(lineWidth: max(0.4, s * 0.013), lineCap: .round))

            // Dark rim for definition.
            ctx.stroke(path, with: .color(p.outline),
                       style: StrokeStyle(lineWidth: max(0.6, s * 0.03), lineJoin: .round))

            // A tight specular glint near the top point.
            let shine = Path(ellipseIn: CGRect(x: c.x - s * 0.10, y: c.y - s * 0.34,
                                               width: s * 0.17, height: s * 0.12))
            ctx.fill(shine, with: .color(.white.opacity(0.65)))
        }
        .frame(width: size, height: size)
        .shadow(color: p.glow.opacity(0.45), radius: size * 0.06)
        .shadow(color: .black.opacity(0.24), radius: size * 0.03, x: 0, y: size * 0.02)
    }

    /// The `points * 2` alternating outer/inner vertices of a star, first point at the top.
    private static func starPoints(center c: CGPoint, outer R: CGFloat, inner r: CGFloat, points: Int) -> [CGPoint] {
        var pts: [CGPoint] = []
        let step = Double.pi / Double(points)
        var angle = -Double.pi / 2
        for i in 0..<(points * 2) {
            let rad = i.isMultiple(of: 2) ? R : r
            pts.append(CGPoint(x: c.x + CGFloat(cos(angle)) * rad,
                               y: c.y + CGFloat(sin(angle)) * rad))
            angle += step
        }
        return pts
    }

    /// A closed star path through the given vertices.
    private static func star(from pts: [CGPoint]) -> Path {
        var path = Path()
        for (i, pt) in pts.enumerated() {
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private struct Palette { let bright, mid, deep, outline, glow: Color }
    private static let gold = Palette(
        bright:  Color(red: 1.00, green: 0.92, blue: 0.66),
        mid:     Color(red: 0.96, green: 0.70, blue: 0.12),
        deep:    Color(red: 0.72, green: 0.47, blue: 0.04),
        outline: Color(red: 0.46, green: 0.30, blue: 0.02),
        glow:    Color(red: 1.00, green: 0.80, blue: 0.20))
    private static let wrong = Palette(
        bright:  Color(red: 0.80, green: 0.88, blue: 1.00),
        mid:     Color(red: 0.24, green: 0.48, blue: 0.92),
        deep:    Color(red: 0.10, green: 0.24, blue: 0.62),
        outline: Color(red: 0.06, green: 0.14, blue: 0.42),
        glow:    Color(red: 0.35, green: 0.55, blue: 1.00))
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
            .font(.system(size: size * 0.82))
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

/// A looping, playful animation for a placed piece — a little squash, a hop, then a
/// left/right wiggle, cycling forever. Used when the "Animate pieces" setting is on.
/// Each piece is desynced by a per-cell `seed` (and small per-piece timing variance) so
/// the board feels lively rather than marching in lockstep. iOS 17+ `PhaseAnimator`.
struct QuirkyPiece<Content: View>: View {
    let seed: Int
    /// How far the piece hops up, in points (relative to the piece size).
    let hopHeight: CGFloat
    let content: Content

    init(seed: Int, hopHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self.seed = seed
        self.hopHeight = hopHeight
        self.content = content()
    }

    var body: some View {
        content.phaseAnimator(Phase.allCases) { view, phase in
            view
                .scaleEffect(x: phase.scaleX, y: phase.scaleY, anchor: .bottom)
                .rotationEffect(.degrees(phase.rotation))
                .offset(y: phase == .hop ? -hopHeight : 0)
        } animation: { phase in
            phase.animation(seed: seed)
        }
    }

    private enum Phase: CaseIterable {
        case rest, squash, hop, wiggleLeft, wiggleRight

        var scaleX: CGFloat { self == .squash ? 1.15 : (self == .hop ? 0.90 : 1) }
        var scaleY: CGFloat { self == .squash ? 0.85 : (self == .hop ? 1.12 : 1) }
        var rotation: Double { self == .wiggleLeft ? -12 : (self == .wiggleRight ? 12 : 0) }

        func animation(seed: Int) -> Animation {
            // A little per-piece variance so pieces drift out of sync over time.
            let jitter = 1 + Double(seed % 4) * 0.08
            switch self {
            case .rest:        return .easeInOut(duration: 0.55 * jitter)
            case .squash:      return .easeIn(duration: 0.16)
            case .hop:         return .spring(response: 0.34, dampingFraction: 0.48)
            case .wiggleLeft:  return .easeInOut(duration: 0.20 * jitter)
            case .wiggleRight: return .easeInOut(duration: 0.20 * jitter)
            }
        }
    }
}

/// A placed piece caught in a live rule conflict: it keeps its normal colour but jitters
/// with a quick shake inside a pulsing red ring and glow, so the pieces involved in the
/// conflict jump out — clearly different from the blue "Check" wrong finish. Used only
/// when the "show errors while playing" setting is on.
struct ConflictPiece<Content: View>: View {
    let cellSize: CGFloat
    let content: Content
    @State private var animate = false

    init(cellSize: CGFloat, @ViewBuilder content: () -> Content) {
        self.cellSize = cellSize
        self.content = content()
    }

    var body: some View {
        content
            // A quick, alarming jitter on the piece itself.
            .rotationEffect(.degrees(animate ? 5 : -5))
            .animation(.easeInOut(duration: 0.13).repeatForever(autoreverses: true), value: animate)
            // A pulsing red ring + glow framing the conflicting piece.
            .background {
                RoundedRectangle(cornerRadius: cellSize * 0.24, style: .continuous)
                    .stroke(Color.red, lineWidth: max(1.5, cellSize * 0.05))
                    .frame(width: cellSize * 0.9, height: cellSize * 0.9)
                    .scaleEffect(animate ? 1.0 : 0.88)
                    .opacity(animate ? 1.0 : 0.4)
                    .shadow(color: .red.opacity(0.85),
                            radius: animate ? cellSize * 0.09 : cellSize * 0.02)
                    .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: animate)
            }
            .onAppear { animate = true }
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
