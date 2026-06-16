import SwiftUI

/// The Play screen: title, optional timer, board, the action row and (in Highlight
/// mode) the guess bar. The layout is fixed — it never scrolls — sizing the board to
/// whatever space is left after the chrome so everything fits on one screen.
struct GameView: View {
    @State private var model = GameViewModel()
    @State private var showNewConfirm = false
    @State private var showClearConfirm = false

    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.cherry.rawValue
    @AppStorage(SettingsKey.hideTimer) private var hideTimer = false

    private var pieceStyle: PieceStyle { PieceStyle(rawValue: pieceRaw) ?? .cherry }

    var body: some View {
        GeometryReader { geo in
            // Reserve room for the chrome so the square board fits without scrolling.
            let chrome: CGFloat = 150 + (model.isHighlightMode ? 70 : 0)
            let side = max(140, min(geo.size.width - 32, geo.size.height - chrome, 620))

            VStack(spacing: 14) {
                Spacer(minLength: 0)

                header

                Spacer(minLength: 0)

                board(side: side)

                if model.isHighlightMode {
                    highlightBar
                        .frame(width: side)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                controls

                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .sensoryFeedback(trigger: model.hintPulse) { _, _ in .impact(weight: .medium) }
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
        VStack(spacing: 2) {
            Text("Cherry Battle")
                .font(.title.bold())
            Text("Place 2 \(pieceStyle.plural) in every row, column and region")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !hideTimer {
                Label(timeString, systemImage: "clock")
                    .font(.headline.monospacedDigit())
                    .padding(.top, 2)
            }
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
                pieceStyle: pieceStyle,
                hintCell: model.hintFocus,
                onTap: { row, col in model.tap(row: row, col: col) },
                onDragBegin: { model.beginDrag() },
                onDragPaint: { start, end in model.dragPaint(from: start, to: end) },
                onDragEnd: { model.endDrag() }
            )
            .frame(width: side, height: side)
            .opacity(model.isGenerating ? 0.12 : 1)

            if model.isGenerating {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Creating a new board…")
                        .font(.headline)
                }
                .padding(28)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
            }
        }
        .frame(width: side, height: side)
        .overlay(alignment: hintAlignment) {
            if let message = model.hintMessage {
                HintBubble(text: message) { model.dismissHint() }
                    .frame(maxWidth: side - 16)
                    .padding(6)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .task(id: model.hintPulse) {
                        // Auto-dismiss after 10s. (Tapping the board also dismisses it,
                        // since any move clears the hint.) Re-armed per hint via the id.
                        try? await Task.sleep(for: .seconds(10))
                        model.dismissHint()
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: model.hintMessage)
    }

    /// Keep the explanation away from the highlighted square: anchor it to whichever
    /// edge of the board the square is *not* near.
    private var hintAlignment: Alignment {
        guard let focus = model.hintFocus else { return .top }
        return focus.row < model.puzzle.size / 2 ? .bottom : .top
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
        HStack(spacing: 6) {
            ToolButton(title: "New", systemImage: "sparkles", style: .prominent) {
                showNewConfirm = true
            }
            ToolButton(title: "Undo", systemImage: "arrow.uturn.backward",
                       isEnabled: model.canUndo) { model.undo() }
            ToolButton(title: "Redo", systemImage: "arrow.uturn.forward",
                       isEnabled: model.canRedo) { model.redo() }
            ToolButton(title: "Hint", systemImage: "lightbulb",
                       isEnabled: model.canHint) {
                model.hint(item: pieceStyle.noun, items: pieceStyle.plural)
            }
            ToolButton(title: "Check", systemImage: "checkmark.seal") { model.check() }
            ToolButton(title: "Clear", systemImage: "trash") { showClearConfirm = true }
            ToolButton(title: "Mark", systemImage: "highlighter", tint: .purple,
                       style: model.isHighlightMode ? .active : .normal) {
                model.toggleHighlightMode()
            }
        }
        .disabled(model.isGenerating || model.isRealizing)
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
                .overlay(GuessGlyph(highlight: kind, pieceStyle: pieceStyle, cellSize: 46))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(selected ? Color.purple : Color.secondary.opacity(0.5),
                                      lineWidth: selected ? 3 : 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(model.isRealizing)
    }

    // MARK: - Helpers

    private var timeString: String {
        let minutes = model.elapsedSeconds / 60
        let seconds = model.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// The hint explanation, shown beside (never over) the highlighted square. Tapping
/// it — or the close button — dismisses it.
private struct HintBubble: View {
    let text: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(.blue)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(radius: 6)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture(perform: onDismiss)
    }
}

/// A compact action button: an icon above a small caption, sized to share a row
/// equally with its siblings.
private struct ToolButton: View {
    enum Style { case normal, prominent, active }

    let title: String
    let systemImage: String
    var tint: Color = .accentColor
    var style: Style = .normal
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
    }

    private var foreground: Color {
        switch style {
        case .normal:   return tint
        case .prominent, .active: return .white
        }
    }

    private var background: Color {
        switch style {
        case .normal:    return tint.opacity(0.14)
        case .prominent: return .accentColor
        case .active:    return tint
        }
    }
}

#Preview {
    GameView()
}
