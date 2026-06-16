import SwiftUI

/// A short, paged introduction shown automatically on first launch and replayable
/// from the Help tab. Dismissing it marks onboarding as seen.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false

    @State private var page = 0

    private struct Slide: Identifiable {
        let id = UUID()
        /// When true, the slide shows the cherry game piece instead of `symbol`.
        var showsCherry = false
        var symbol = ""
        let tint: Color
        let title: String
        let body: String
    }

    private let slides: [Slide] = [
        Slide(showsCherry: true, tint: .red,
              title: "Welcome to Cherry Bomb",
              body: "A bite-size logic puzzle. Fill the board with cherries using pure deduction — no luck required."),
        Slide(symbol: "2.square.fill", tint: .orange,
              title: "Two per line",
              body: "Every row, every column, and every coloured region holds exactly two cherries."),
        Slide(symbol: "hand.raised.slash.fill", tint: .pink,
              title: "Never touching",
              body: "Two cherries can never touch — not horizontally, vertically, or even diagonally. Use that to rule squares out."),
        Slide(symbol: "hand.tap.fill", tint: .purple,
              title: "Mark as you go",
              body: "Tap a square to cycle it: empty → a dot (your “no cherry here” note) → a cherry → empty. Drag to lay a quick line of dots."),
        Slide(symbol: "lightbulb.fill", tint: .green,
              title: "Helpers when you need them",
              body: "Stuck? Tap Hint for the next logical step, explained. Use Mark mode to pencil in a guess and Realize it, and Undo or Redo anytime.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
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
            Group {
                if slide.showsCherry {
                    PieceView(style: .cherry, isWrong: false, size: 110)
                } else {
                    Image(systemName: slide.symbol)
                        .font(.system(size: 84, weight: .semibold))
                        .foregroundStyle(slide.tint)
                }
            }
            .frame(height: 120)
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
