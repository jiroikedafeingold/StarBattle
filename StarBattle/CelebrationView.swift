import SwiftUI

/// A full-screen burst of falling confetti — the player's chosen piece, dots and ribbons
/// in festive colours — used to celebrate a solved puzzle.
struct CelebrationView: View {
    private let pieces: [ConfettiPiece]

    init(piece: PieceStyle = .star) {
        pieces = ConfettiPiece.make(count: 120, emoji: piece.emoji)
    }

    var body: some View {
        GeometryReader { geo in
            // Drive the fall directly from elapsed time so it can't be swallowed by
            // an ancestor animation transaction (which previously snapped every piece
            // off-screen so the confetti was never seen). TimelineView re-renders each
            // frame, advancing every piece down its own continuous loop.
            TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let h = geo.size.height
                let w = geo.size.width
                ZStack {
                    ForEach(pieces) { piece in
                        // Normalised fall progress 0…1, offset so pieces don't fall in sync.
                        let progress = (t / piece.duration + piece.phase)
                            .truncatingRemainder(dividingBy: 1)
                        piece.shape
                            .position(x: piece.x * w,
                                      y: -0.15 * h + progress * 1.30 * h)
                            .rotationEffect(.degrees(piece.spin * progress))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

#Preview {
    ZStack {
        Color(white: 0.9)
        CelebrationView()
    }
}

/// One piece of confetti with its own random look and trajectory.
private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat          // horizontal position, 0...1 of the width
    let size: CGFloat
    let color: Color
    let spin: Double        // total degrees turned over one fall
    let duration: Double    // seconds for one top-to-bottom fall
    let phase: Double       // 0…1 starting offset so pieces don't fall in lockstep
    let kind: Kind
    let emoji: String       // the chosen piece's glyph, for `.piece` confetti

    enum Kind { case piece, circle, ribbon }

    @ViewBuilder var shape: some View {
        switch kind {
        case .piece:
            Text(emoji)
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

    static func make(count: Int, emoji: String) -> [ConfettiPiece] {
        let colors: [Color] = [
            .red, .orange, .yellow, .green, .mint, .blue, .purple, .pink,
            Color(red: 1.0, green: 0.84, blue: 0.0)
        ]
        let kinds: [Kind] = [.piece, .piece, .circle, .ribbon]
        return (0..<count).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 9...20),
                color: colors.randomElement()!,
                spin: Double.random(in: 240...1200) * (Bool.random() ? 1 : -1),
                duration: Double.random(in: 2.2...4.6),
                phase: Double.random(in: 0...1),
                kind: kinds.randomElement()!,
                emoji: emoji
            )
        }
    }
}
