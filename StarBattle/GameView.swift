import SwiftUI

/// The full game screen: title, timer, board, controls and a win banner.
struct GameView: View {
    @State private var model = GameViewModel()
    @State private var showNewConfirm = false
    @State private var showClearConfirm = false

    var body: some View {
        GeometryReader { geo in
            // Size the board to the full available width so it fills the screen in
            // both normal and Highlight mode. The layout scrolls only if a smaller
            // device can't fit everything at once.
            let side = min(geo.size.width, 560) - 32
            ScrollView {
                VStack(spacing: 16) {
                    header

                    board(side: side)

                    if model.isHighlightMode {
                        highlightBar
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    controls

                    legend
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .overlay {
            if model.isSolved {
                celebration
            }
        }
        .animation(.spring(duration: 0.5), value: model.isSolved)
        .animation(.spring(duration: 0.35), value: model.isHighlightMode)
        .confirmationDialog("Start a new puzzle?", isPresented: $showNewConfirm,
                            titleVisibility: .visible) {
            Button("New Puzzle", role: .destructive) { Task { await model.newGame() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current progress will be lost.")
        }
        .confirmationDialog("Clear the board?", isPresented: $showClearConfirm,
                            titleVisibility: .visible) {
            Button("Clear", role: .destructive) { model.clearBoard() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all your marks and guesses.")
        }
        .sensoryFeedback(trigger: model.tapPulse) { _, _ in
            model.lastActionPlacedStar ? .impact(weight: .medium, intensity: 0.9)
                                       : .impact(weight: .light, intensity: 0.6)
        }
        .sensoryFeedback(trigger: model.isSolved) { wasSolved, isSolved in
            (isSolved && !wasSolved) ? .success : nil
        }
        // A rolling burst of heavy impacts while the win celebration plays.
        .sensoryFeedback(trigger: model.celebrationPulse) { _, _ in
            .impact(weight: .heavy, intensity: 1.0)
        }
        .sensoryFeedback(trigger: model.checkPulse) { _, _ in
            model.lastCheckHadErrors ? .error : .success
        }
        .task {
            // A simple one-second timer that runs while a puzzle is in progress.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !model.isSolved && !model.isGenerating {
                    model.elapsedSeconds += 1
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("Cherry Battle")
                .font(.largeTitle.bold())
            Text("Place 2 cherries in every row, column and region")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label(timeString, systemImage: "clock")
                .font(.title3.monospacedDigit())
                .padding(.top, 2)
        }
    }

    // MARK: - Board

    private func board(side: CGFloat) -> some View {
        ZStack {
            BoardView(
                puzzle: model.puzzle,
                marks: model.marks,
                highlights: model.highlights,
                wrongStars: model.wrongStars,
                onTap: { row, col in model.tap(row: row, col: col) },
                onDragBegin: { model.beginDrag() },
                onDragPaint: { start, end in model.dragPaint(from: start, to: end) },
                onDragEnd: { model.endDrag() }
            )
            .frame(width: side, height: side)
            .opacity(model.isGenerating ? 0.15 : 1)

            if model.isGenerating {
                ProgressView("Creating a new board…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .frame(width: side, height: side)
    }

    // MARK: - Celebration

    private var celebration: some View {
        ZStack {
            CelebrationView()
            solvedBanner
        }
    }

    private var solvedBanner: some View {
        VStack(spacing: 8) {
            Text("🎉 Solved! 🎉")
                .font(.largeTitle.bold())
            Text("Time: \(timeString)")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button {
                Task { await model.newGame() }
            } label: {
                Label("New Puzzle", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 6)
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 12)
        .transition(.scale(scale: 0.6).combined(with: .opacity))
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    showNewConfirm = true
                } label: {
                    Label("New", systemImage: "sparkles").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    model.undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!model.canUndo)
            }

            HStack(spacing: 10) {
                Button {
                    showClearConfirm = true
                } label: {
                    Label("Clear", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    model.check()
                } label: {
                    Label("Check", systemImage: "checkmark.seal").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            highlightToggle
        }
        .disabled(model.isGenerating || model.isRealizing)
    }

    @ViewBuilder private var highlightToggle: some View {
        let label = Label(model.isHighlightMode ? "Exit Highlight Mode" : "Highlight Mode",
                          systemImage: "highlighter")
            .frame(maxWidth: .infinity)
        if model.isHighlightMode {
            Button { model.toggleHighlightMode() } label: { label }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
        } else {
            Button { model.toggleHighlightMode() } label: { label }
                .buttonStyle(.bordered)
                .tint(.purple)
        }
    }

    // MARK: - Highlight mode bar (under the board)

    private var highlightBar: some View {
        HStack(spacing: 14) {
            swatch(.guessStar, fill: .white)
            swatch(.guessEmpty, fill: Color(white: 0.55))

            Spacer()

            Button {
                Task { await model.realizeGuesses() }
            } label: {
                Label("Realize", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(!model.hasHighlights || model.isRealizing)
        }
        .padding(.horizontal, 4)
    }

    private func swatch(_ kind: CellHighlight, fill: Color) -> some View {
        let selected = model.selectedHighlight == kind
        return Button {
            model.selectHighlight(kind)
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(fill)
                .frame(width: 46, height: 46)
                .overlay(GuessGlyph(highlight: kind, cellSize: 46))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(selected ? Color.purple : Color.secondary.opacity(0.5),
                                      lineWidth: selected ? 3 : 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(model.isRealizing)
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Tap a cell to cycle: empty → • dot → 🍒 cherry → empty", systemImage: "hand.tap")
            Label("Cherries may never touch — not even diagonally", systemImage: "exclamationmark.triangle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private var timeString: String {
        let minutes = model.elapsedSeconds / 60
        let seconds = model.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    GameView()
}
