import SwiftUI
import UIKit

/// A monochrome star silhouette used as the Play tab icon. Rendered once from a Canvas
/// drawing into a template image so the tab bar tints it like an SF Symbol.
@MainActor
enum PlayTabIcon {
    static let image: Image = {
        let renderer = ImageRenderer(content: MonoStar().frame(width: 30, height: 30))
        renderer.scale = 3
        if let ui = renderer.uiImage?.withRenderingMode(.alwaysTemplate) {
            return Image(uiImage: ui)
        }
        return Image(systemName: "star.fill")
    }()
}

/// A filled five-pointed star drawn as a flat black silhouette.
private struct MonoStar: View {
    var body: some View {
        Canvas { ctx, sz in
            let s = min(sz.width, sz.height)
            let c = CGPoint(x: s / 2, y: s * 0.53)
            let R = s * 0.47, r = R * 0.42
            var path = Path()
            let step = Double.pi / 5
            var angle = -Double.pi / 2
            for i in 0..<10 {
                let rad = i.isMultiple(of: 2) ? R : r
                let pt = CGPoint(x: c.x + CGFloat(cos(angle)) * rad,
                                 y: c.y + CGFloat(sin(angle)) * rad)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                angle += step
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(.black))
        }
    }
}
