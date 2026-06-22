import SwiftUI
import UIKit

/// A monochrome cherry silhouette used as the Play tab icon. Rendered once from a
/// Canvas drawing into a template image so the tab bar tints it like an SF Symbol.
@MainActor
enum CherryTabIcon {
    static let image: Image = {
        let renderer = ImageRenderer(content: MonoCherry().frame(width: 30, height: 30))
        renderer.scale = 3
        if let ui = renderer.uiImage?.withRenderingMode(.alwaysTemplate) {
            return Image(uiImage: ui)
        }
        return Image(systemName: "gamecontroller")
    }()
}

/// Two cherries drawn as a flat black silhouette (stems, leaf, fruit).
private struct MonoCherry: View {
    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height)
            let left = CGPoint(x: 0.33 * s, y: 0.70 * s)
            let right = CGPoint(x: 0.67 * s, y: 0.74 * s)
            let rL = 0.235 * s, rR = 0.215 * s
            let join = CGPoint(x: 0.60 * s, y: 0.15 * s)

            // Stems.
            var stems = Path()
            stems.move(to: join)
            stems.addQuadCurve(to: CGPoint(x: left.x, y: left.y - rL * 0.8),
                               control: CGPoint(x: 0.40 * s, y: 0.32 * s))
            stems.move(to: join)
            stems.addQuadCurve(to: CGPoint(x: right.x, y: right.y - rR * 0.8),
                               control: CGPoint(x: 0.66 * s, y: 0.38 * s))
            ctx.stroke(stems, with: .color(.black),
                       style: StrokeStyle(lineWidth: max(1.5, 0.06 * s), lineCap: .round))

            // Leaf.
            var leaf = Path()
            leaf.move(to: join)
            leaf.addQuadCurve(to: CGPoint(x: 0.82 * s, y: 0.10 * s),
                              control: CGPoint(x: 0.66 * s, y: -0.02 * s))
            leaf.addQuadCurve(to: join, control: CGPoint(x: 0.78 * s, y: 0.24 * s))
            leaf.closeSubpath()
            ctx.fill(leaf, with: .color(.black))

            // Fruit.
            for (c, r) in [(left, rL), (right, rR)] {
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                         with: .color(.black))
            }
        }
    }
}
