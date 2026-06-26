import SwiftUI

/// The overlay shown while a new board is being generated. Generation is usually
/// instant (a board is waiting in the background) but can occasionally take many
/// seconds, so instead of a bare spinner this shows a looping animation of cherries
/// filling a little board, plus the current step of the build so it never looks stuck.
struct GeneratingView: View {
    let stage: GenerationStage?

    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.cherry.rawValue
    private var piece: PieceStyle { PieceStyle(rawValue: pieceRaw) ?? .cherry }

    var body: some View {
        VStack(spacing: 16) {
            PieceBuildAnimation(piece: piece)
                .frame(width: 132, height: 132)

            VStack(spacing: 4) {
                Text("Creating a new board…")
                    .font(.headline)
                Text(Self.stageText(stage))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: stage)
            }
            .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 8)
    }

    /// A short, friendly description of the current build phase.
    private static func stageText(_ stage: GenerationStage?) -> LocalizedStringKey {
        switch stage {
        case .placing: "Placing cherries…"
        case .shaping: "Shaping the regions…"
        case .checking: "Checking for one solution…"
        case .tuning: "Tuning the difficulty…"
        case nil: "Getting ready…"
        }
    }
}

/// A 5×5 grid of the player's chosen piece that washes in along a diagonal wave, then
/// fades and repeats — an at-a-glance echo of a board being filled in. Driven by elapsed
/// time through a `TimelineView` so it animates smoothly regardless of what the rest of
/// the UI is doing.
private struct PieceBuildAnimation: View {
    let piece: PieceStyle
    private let dimension = 5
    private let period = 2.6   // seconds for one fill-and-fade loop

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let p = (t / period).truncatingRemainder(dividingBy: 1)
            GeometryReader { geo in
                let cell = geo.size.width / CGFloat(dimension)
                ZStack(alignment: .topLeading) {
                    ForEach(0..<(dimension * dimension), id: \.self) { i in
                        let row = i / dimension, col = i % dimension
                        let amount = fill(row: row, col: col, progress: p)
                        PieceView(style: piece, isWrong: false, size: cell * 0.74)
                            .frame(width: cell, height: cell)
                            .scaleEffect(0.35 + 0.65 * amount)
                            .opacity(amount)
                            .offset(x: CGFloat(col) * cell, y: CGFloat(row) * cell)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// How "present" a cell is (0…1) at loop progress `p`: cherries pop in along a
    /// diagonal wave over the first ~75% of the loop and hold, so most of the time a
    /// nearly-full board is on screen, then they all fade out together and it repeats.
    private func fill(row: Int, col: Int, progress p: Double) -> Double {
        let order = Double(row + col) / Double((dimension - 1) * 2)   // 0…1 along the diagonal
        let threshold = order * 0.7
        let appear = smoothstep(threshold, threshold + 0.1, p)
        let fadeOut = 1 - smoothstep(0.85, 1.0, p)
        return appear * fadeOut
    }

    private func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

#Preview {
    ZStack {
        Color(white: 0.9).ignoresSafeArea()
        GeneratingView(stage: .checking)
    }
}
