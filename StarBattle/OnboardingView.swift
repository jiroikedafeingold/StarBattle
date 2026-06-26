import SwiftUI

/// A short, paged introduction shown automatically on first launch and replayable
/// from the Help tab. Dismissing it marks onboarding as seen.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false
    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.cherry.rawValue

    @State private var page = 0

    private var piece: PieceStyle { PieceStyle(rawValue: pieceRaw) ?? .cherry }

    /// What a slide shows above its text.
    private enum Art {
        case piece
        case symbol(String)
        case neverTouch
        case twoPerLine
    }

    private struct Slide: Identifiable {
        let id = UUID()
        var art: Art
        let tint: Color
        let title: String
        let body: String
    }

    private var slides: [Slide] {
        [
            Slide(art: .piece, tint: .red,
                  title: "Welcome to Cherry Battle",
                  body: "A bite-size logic puzzle. Fill the board with \(piece.plural) using pure deduction — no luck required."),
            Slide(art: .twoPerLine, tint: .orange,
                  title: "Two per line",
                  body: "Every row, every column, and every coloured region holds exactly two \(piece.plural)."),
            Slide(art: .neverTouch, tint: .pink,
                  title: "Never touching",
                  body: "Two \(piece.plural) can never touch — not horizontally, vertically, or even diagonally. Each one rules out all eight neighbours."),
            Slide(art: .symbol("hand.tap.fill"), tint: .purple,
                  title: "Mark as you go",
                  body: "Tap a square to cycle it: empty → a dot (your “no \(piece.noun) here” note) → a \(piece.noun) → empty. Drag to lay a quick line of dots."),
            Slide(art: .symbol("lightbulb.fill"), tint: .green,
                  title: "Helpers when you need them",
                  body: "Stuck? Tap Hint for the next logical step, explained. Use Mark mode to pencil in a guess and tap “Do it” to commit, and Undo or Redo anytime.")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                // Key on the stable page index, not slide.id: `slides` is recomputed on
                // every render (it reads the current piece), so its UUIDs change each
                // time. Keying on those churning ids made SwiftUI rebuild the pager
                // mid-swipe, so a drag would move partway and then snap to the next page.
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    slideView(slide).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(action: advance) {
                Text(page == slides.count - 1 ? "Start playing" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .overlay(alignment: .topTrailing) {
            Button("Skip") { finish() }
                .padding()
        }
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: 24) {
            art(for: slide)
                .frame(height: 150)
                .padding(.bottom, 4)
            Text(slide.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(slide.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }

    @ViewBuilder private func art(for slide: Slide) -> some View {
        switch slide.art {
        case .piece:
            PieceView(style: piece, isWrong: false, size: 110)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 84, weight: .semibold))
                .foregroundStyle(slide.tint)
        case .neverTouch:
            RuleDiagrams.neverTouch(piece: piece, cell: 46)
        case .twoPerLine:
            RuleDiagrams.twoPerLine(piece: piece, cell: 46)
        }
    }

    private func advance() {
        if page < slides.count - 1 {
            withAnimation { page += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        hasSeenOnboarding = true
        dismiss()
    }
}

#Preview {
    OnboardingView()
}
