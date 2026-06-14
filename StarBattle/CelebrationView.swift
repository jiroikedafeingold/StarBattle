import SwiftUI

/// A full-screen burst of falling confetti — cherries, dots and ribbons in festive
/// colours — used to celebrate a solved puzzle.
struct CelebrationView: View {
    @State private var animate = false
    private let pieces = ConfettiPiece.make(count: 120)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    piece.shape
                        .position(
                            x: piece.x * geo.size.width,
                            y: animate ? geo.size.height * 1.15 : -geo.size.height * 0.15
                        )
                        .rotationEffect(.degrees(animate ? piece.spin : 0))
                        .animation(
                            .easeIn(duration: piece.duration)
                                .delay(piece.delay)
                                .repeatForever(autoreverses: false),
                            value: animate
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear { animate = true }
    }
}

/// One piece of confetti with its own random look and trajectory.
private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat          // horizontal position, 0...1 of the width
    let size: CGFloat
    let color: Color
    let spin: Double
    let duration: Double
    let delay: Double
    let kind: Kind

    enum Kind { case cherry, circle, ribbon }

    @ViewBuilder var shape: some View {
        switch kind {
        case .cherry:
            Text("🍒")
                .font(.system(size: size))
        case .circle:
            Circle()
                .fill(color)
                .frame(width: size * 0.8, height: size * 0.8)
        case .ribbon:
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: size * 0.7, height: size * 1.3)
        }
    }

    static func make(count: Int) -> [ConfettiPiece] {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .mint, .blue, .purple, .pink,
            Color(red: 1.0, green: 0.84, blue: 0.0)
        ]
        let kinds: [Kind] = [.cherry, .cherry, .circle, .ribbon]
        return (0..<count).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 9...20),
                color: colors.randomElement()!,
                spin: Double.random(in: 240...1200) * (Bool.random() ? 1 : -1),
                duration: Double.random(in: 1.6...3.4),
                delay: Double.random(in: 0...1.4),
                kind: kinds.randomElement()!
            )
        }
    }
}
