import SwiftUI

/// The Play screen: title, optional timer, board, the action row and (in Highlight
/// mode) the guess bar. The layout is fixed — it never scrolls — sizing the board to
/// whatever space is left after the chrome so everything fits on one screen.
struct GameView: View {
    @State private var model: GameViewModel
    @State private var showNewConfirm = false
    @State private var showClearConfirm = false
    @State private var showHintConfirm = false
    @State private var showEraseConfirm = false
    @State private var celebrationHaptics = CelebrationHaptics()

    init(model: GameViewModel? = nil) {
        _model = State(initialValue: model ?? GameViewModel())
    }

    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.cherry.rawValue
    @AppStorage(SettingsKey.hideTimer) private var hideTimer = false
    @AppStorage(SettingsKey.difficulty) private var difficultyRaw = Difficulty.easy.rawValue
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.winCelebration) private var winCelebration = true

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    private var pieceStyle: PieceStyle { PieceStyle(rawValue: pieceRaw) ?? .cherry }
    private var difficulty: Difficulty { Difficulty(rawValue: difficultyRaw) ?? .easy }

    /// True only on a full-screen iPad. iPhones are always compact in at least one
    /// axis, and an iPad in a narrow multitasking slot goes compact too — in both of
    /// those the tab bar sits at the bottom. When both axes are regular the tab bar
    /// floats across the top, so the Play content needs room to clear it.
    private var isPadLayout: Bool { hSize == .regular && vSize == .regular }

    var body: some View {
        VStack(spacing: 10) {
            header

            // The board fills whatever space is left between the header and the
            // controls (a GeometryReader is greedy), sized to fit and centred. Because
            // the controls keep their natural height, they can never clip off-screen —
            // this is what previously happened on iPad.
            GeometryReader { geo in
                let side = max(140, min(geo.size.width, geo.size.height, 600))
                board(side: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)   // centred
            }

            // Fixed-height controls area so the board region above never changes height
            // between normal and Mark mode (keeping the board the same size).
            ZStack {
                if model.isHighlightMode {
                    markControls
                } else {
                    controls
                }
            }
            .frame(height: 150)
            // Lift the control bar off the tab bar so it sits centred in the space
            // between the board and the bottom of the screen.
            .padding(.bottom, 28)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        // Keep the header (title + difficulty options) clear of the iPad's floating
        // top tab bar, which otherwise overlaps them.
        .safeAreaPadding(.top, isPadLayout ? 44 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground().ignoresSafeArea())
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
        .confirmationDialog("Show a hint?", isPresented: $showHintConfirm,
                            titleVisibility: .visible) {
            Button("Show Hint") { model.hint(item: pieceStyle.noun, items: pieceStyle.plural) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This places the next logical move and explains why.")
        }
        .confirmationDialog("Erase all guesses?", isPresented: $showEraseConfirm,
                            titleVisibility: .visible) {
            Button("Erase", role: .destructive) { model.clearGuesses() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears every guess on the board.")
        }
        .alert("Nice streak! 🍒", isPresented: difficultyPromptPresented) {
            Button("Try \(difficulty.harder?.label ?? "Harder")") {
                if let harder = difficulty.harder { difficultyRaw = harder.rawValue }
                model.dismissDifficultyPrompt()
            }
            Button("Stay on \(difficulty.label)", role: .cancel) {
                model.dismissDifficultyPrompt()
            }
        } message: {
            Text("You've solved five puzzles with no hints or wrong cherries. Ready to step up to \(difficulty.harder?.label ?? "a harder level")?")
        }
        .sensoryFeedback(trigger: model.tapPulse) { _, _ in
            guard haptics else { return nil }
            return model.lastActionPlacedStar ? .impact(weight: .medium, intensity: 0.9)
                                              : .impact(weight: .light, intensity: 0.6)
        }
        .sensoryFeedback(trigger: model.isSolved) { wasSolved, isSolved in
            (haptics && isSolved && !wasSolved) ? .success : nil
        }
        // A long, swelling "confetti brushing past you" burst when the puzzle is solved.
        .onChange(of: model.celebrationPulse) { _, _ in
            if haptics { celebrationHaptics.play() }
        }
        // A clear tap every time Check is pressed; a clean board also gets a success
        // chime. A wrong cherry adds the strong, longer buzz below.
        .sensoryFeedback(trigger: model.checkPulse) { _, _ in
            guard haptics else { return nil }
            return model.lastCheckHadErrors ? .impact(weight: .medium, intensity: 0.9) : .success
        }
        // A strong, repeated buzz when Check reveals a wrong cherry.
        .sensoryFeedback(trigger: model.wrongPulse) { _, _ in
            haptics ? .impact(weight: .heavy, intensity: 1.0) : nil
        }
        .sensoryFeedback(trigger: model.hintPulse) { _, _ in
            haptics ? .impact(weight: .medium) : nil
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
            GameTitle()
            Text("Place 2 \(pieceStyle.plural) in every row, column and region")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !hideTimer {
                Label(timeString, systemImage: "clock")
                    .font(.headline.monospacedDigit())
                    .padding(.top, 1)
            }
            difficultyPicker
                .padding(.top, 12)
        }
    }

    private var difficultyPicker: some View {
        Picker("Difficulty", selection: $difficultyRaw) {
            ForEach(Difficulty.allCases) { level in
                Text(level.label).tag(level.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
        .disabled(model.isGenerating || model.isRealizing)
        .onChange(of: difficultyRaw) { _, newValue in
            model.setDifficulty(Difficulty(rawValue: newValue) ?? .easy)
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
                ghostCell: model.guessGhost,
                ghostPulse: model.ghostPulse,
                onTap: { row, col in model.tap(row: row, col: col) },
                onDragBegin: { model.beginDrag() },
                onDragPaint: { start, end in model.dragPaint(from: start, to: end) },
                onDragEnd: { model.endDrag() }
            )
            .frame(width: side, height: side)
            .opacity(model.isGenerating ? 0.12 : 1)

            if model.isGenerating {
                GeneratingView(stage: model.generationStage)
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
            if winCelebration {
                CelebrationView()
            }
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
                ToolButton(title: "New", systemImage: "sparkles", style: .prominent) {
                    showNewConfirm = true
                }
                ToolButton(title: "Hint", systemImage: "lightbulb",
                           isEnabled: model.canHint) { showHintConfirm = true }
                ToolButton(title: "Check", systemImage: "checkmark.seal") { model.check() }
                ToolButton(title: "Mark", systemImage: "highlighter", tint: .purple,
                           style: model.isHighlightMode ? .active : .normal) {
                    model.toggleHighlightMode()
                }
            }
            HStack(spacing: 10) {
                ToolButton(title: "Undo", systemImage: "arrow.uturn.backward",
                           isEnabled: model.canUndo) { model.undo() }
                ToolButton(title: "Redo", systemImage: "arrow.uturn.forward",
                           isEnabled: model.canRedo) { model.redo() }
                ToolButton(title: "Clear", systemImage: "trash") { showClearConfirm = true }
            }
        }
        .disabled(model.isGenerating || model.isRealizing)
    }

    /// Shown in place of the full bar while in Mark mode — the only way out.
    private var exitMarkButton: some View {
        Button {
            model.toggleHighlightMode()
        } label: {
            Label("Exit Mark Mode", systemImage: "highlighter")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
        .disabled(model.isGenerating || model.isRealizing)
    }

    // MARK: - Mark-mode controls

    /// Mark mode uses the same full-size buttons as the main screen: Undo / Redo /
    /// Erase / Do it, with the Exit button below.
    private var markControls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ToolButton(title: "Undo", systemImage: "arrow.uturn.backward",
                           isEnabled: model.canUndo) { model.undo() }
                ToolButton(title: "Redo", systemImage: "arrow.uturn.forward",
                           isEnabled: model.canRedo) { model.redo() }
                ToolButton(title: "Erase", systemImage: "eraser", tint: .red, style: .active,
                           isEnabled: model.hasHighlights) { showEraseConfirm = true }
                ToolButton(title: "Do it", systemImage: "wand.and.stars", tint: .purple,
                           style: .active, isEnabled: model.hasHighlights) {
                    Task { await model.realizeGuesses() }
                }
            }
            exitMarkButton
        }
        .disabled(model.isGenerating || model.isRealizing)
    }

    // MARK: - Helpers

    private var difficultyPromptPresented: Binding<Bool> {
        Binding(get: { model.promptDifficultyIncrease },
                set: { if !$0 { model.dismissDifficultyPrompt() } })
    }

    private var timeString: String {
        let minutes = model.elapsedSeconds / 60
        let seconds = model.elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

/// A cherry-themed, vignette-style backdrop. Dark mirrors the intro screen; light is
/// a soft blush-white version that keeps the same shape and warmth.
struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        RadialGradient(
            gradient: scheme == .dark ? Self.darkStops : Self.lightStops,
            center: UnitPoint(x: 0.5, y: 0.40),
            startRadius: 0, endRadius: 560)
    }

    private static let darkStops = Gradient(stops: [
        .init(color: Color(hex: 0x220912), location: 0.0),
        .init(color: Color(hex: 0x140609), location: 0.58),
        .init(color: Color(hex: 0x0B0405), location: 1.0)
    ])

    private static let lightStops = Gradient(stops: [
        .init(color: Color(hex: 0xFFF7F8), location: 0.0),
        .init(color: Color(hex: 0xFCE9EC), location: 0.58),
        .init(color: Color(hex: 0xF2D9DD), location: 1.0)
    ])
}

/// The game title, matching the intro screen's wordmark: "Cherry Battle" in a bold
/// rounded face with a light "Cherry" and a cherry-red "Battle".
struct GameTitle: View {
    var body: some View {
        // "Cherry" uses the primary label colour so it reads on either background
        // (near-white in dark, near-black in light); "Battle" stays cherry red.
        (Text(verbatim: "Cherry ").foregroundColor(.primary)
         + Text(verbatim: "Battle").foregroundColor(Color(hex: 0xE51937)))
            .font(.system(size: 40, weight: .bold, design: .rounded))
            .accessibilityLabel("Cherry Battle")
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
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 23, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var foreground: Color {
        // A medium, appearance-adaptive grey reads clearly in both light and dark,
        // unlike a faded tint.
        guard isEnabled else { return .secondary }
        switch style {
        case .normal:   return tint
        case .prominent, .active: return .white
        }
    }

    private var background: Color {
        guard isEnabled else { return .secondary.opacity(0.18) }
        switch style {
        case .normal:    return tint.opacity(0.14)
        case .prominent: return .accentColor
        case .active:    return tint
        }
    }
}

#Preview {
    // A partially-solved board, for App Store screenshots and layout checks.
    let model = GameViewModel()
    let cells = model.puzzle.solution.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
    for p in cells.prefix(13) {
        model.tap(row: p.row, col: p.col)   // empty -> dot
        model.tap(row: p.row, col: p.col)   // dot -> cherry (+ auto-dots)
    }
    return GameView(model: model)
}

#Preview("Mark mode") {
    let model = GameViewModel()
    let cells = model.puzzle.solution.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
    for p in cells.prefix(8) {
        model.tap(row: p.row, col: p.col)
        model.tap(row: p.row, col: p.col)
    }
    model.toggleHighlightMode()
    return GameView(model: model)
}
