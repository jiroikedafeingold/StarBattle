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

    // MARK: Win finale
    /// The solved cherries, in the order they detonate.
    @State private var explosionStars: [GridPosition] = []
    /// How many cherries have burst so far; drives the board's hidden stars and the
    /// burst overlay.
    @State private var explodedCount = 0
    /// Set true once the explosions finish (or immediately if the win celebration is
    /// off / the puzzle loaded already solved), revealing the "Play again" banner.
    @State private var showBanner = false
    /// The running explosion sequence, cancelled if the player starts a new puzzle.
    @State private var finaleTask: Task<Void, Never>?

    /// True for ~1s after the secret near-solve fires, so the tap that lands when the
    /// finger lifts is swallowed rather than opening the hint dialog.
    @State private var secretSolveFired = false

    /// A brief rule reminder shown when switching into or out of Beginner, where the
    /// pieces-per-line count changes. Auto-dismisses after a couple of seconds.
    @State private var ruleToast: LocalizedStringKey?
    @State private var ruleToastTask: Task<Void, Never>?
    /// Bumped to give the Exit-Mark-Mode button a press haptic.
    @State private var exitPressTick = 0
    /// True for ~1s after a deep Check (long-press) fires, so the release tap doesn't
    /// re-run the normal Check.
    @State private var deepCheckFired = false

    /// A difficulty change waiting on confirmation (because it would abandon a game in
    /// progress), plus the flag that presents the confirmation dialog.
    @State private var pendingDifficultyRaw = ""
    @State private var showSwitchConfirm = false

    init(model: GameViewModel? = nil) {
        _model = State(initialValue: model ?? GameViewModel())
    }

    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.star.rawValue
    @AppStorage(SettingsKey.hideTimer) private var hideTimer = false
    @AppStorage(SettingsKey.difficulty) private var difficultyRaw = Difficulty.easy.rawValue
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.winCelebration) private var winCelebration = true

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    /// The purchase / entitlement service, used to gate new puzzles behind the daily
    /// free limit (lifted by Full Access).
    @Environment(PurchaseManager.self) private var store
    /// Presents the Full Access paywall when a free player is out of daily puzzles.
    @State private var showPaywall = false

    private var pieceStyle: PieceStyle { PieceStyle(rawValue: pieceRaw) ?? .cherry }
    private var difficulty: Difficulty { Difficulty(rawValue: difficultyRaw) ?? .easy }

    /// True only on a full-screen iPad. iPhones are always compact in at least one
    /// axis, and an iPad in a narrow multitasking slot goes compact too — in both of
    /// those the tab bar sits at the bottom. When both axes are regular the tab bar
    /// floats across the top, so the Play content needs room to clear it.
    private var isPadLayout: Bool { hSize == .regular && vSize == .regular }

    var body: some View {
        // Split across three helpers so no single expression is too large for the
        // compiler to type-check (Release archiving is stricter than a debug build).
        withFeedback(withDialogs(mainLayout))
    }

    private var mainLayout: some View {
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
            if showBanner {
                celebration
            }
        }
        .overlay(alignment: .top) {
            if let ruleToast {
                Text(ruleToast)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
                    .shadow(radius: 10, y: 4)
                    .padding(.top, isPadLayout ? 56 : 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(duration: 0.5), value: showBanner)
        .animation(.spring(duration: 0.35), value: model.isHighlightMode)
    }

    /// Attaches the confirmation dialogs, the streak alert and the paywall sheet.
    private func withDialogs<Content: View>(_ content: Content) -> some View {
        content
        .confirmationDialog("Start a new puzzle?", isPresented: $showNewConfirm,
                            titleVisibility: .visible) {
            Button("New Puzzle", role: .destructive) {
                if !store.isUnlocked { FreePuzzleLimiter.recordPuzzle(in: difficulty) }
                Task { await model.newGame() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current progress will be lost.")
        }
        .confirmationDialog("Switch difficulty?", isPresented: $showSwitchConfirm,
                            titleVisibility: .visible) {
            Button("Switch & Start New", role: .destructive) {
                difficultyRaw = pendingDifficultyRaw
            }
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    /// Attaches the haptic feedback, win-finale reactions and the game timer.
    private func withFeedback<Content: View>(_ content: Content) -> some View {
        content
        .sensoryFeedback(trigger: model.tapPulse) { _, _ in
            guard haptics else { return nil }
            return model.lastActionPlacedStar ? .impact(weight: .heavy, intensity: 1.0)
                                              : .impact(weight: .medium, intensity: 0.8)
        }
        .sensoryFeedback(trigger: model.isSolved) { wasSolved, isSolved in
            (haptics && isSolved && !wasSolved) ? .success : nil
        }
        // On a fresh solve, detonate the cherries one by one, then show the banner.
        .onChange(of: model.celebrationPulse) { _, _ in
            startWinFinale()
        }
        // Tearing down the win (new puzzle, clear) cancels the finale and hides the banner.
        .onChange(of: model.isSolved) { _, solved in
            if !solved { resetWinFinale() }
        }
        // A puzzle that loads already solved skips the explosions and shows the banner.
        .onAppear {
            if model.isSolved && !showBanner && finaleTask == nil { showBanner = true }
        }
        // A clear tap every time Check is pressed; a clean board also gets a success
        // chime. A wrong cherry adds the strong, longer buzz below.
        .sensoryFeedback(trigger: model.checkPulse) { _, _ in
            guard haptics else { return nil }
            return model.lastCheckHadErrors ? .impact(weight: .heavy, intensity: 1.0) : .success
        }
        // A strong, repeated buzz when Check reveals a wrong cherry.
        .sensoryFeedback(trigger: model.wrongPulse) { _, _ in
            haptics ? .impact(weight: .heavy, intensity: 1.0) : nil
        }
        .sensoryFeedback(trigger: model.hintPulse) { _, _ in
            haptics ? .impact(weight: .heavy) : nil
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
            Group {
                if model.puzzle.starsPerUnit == 1 {
                    Text("Place 1 \(pieceStyle.noun) in every row, column and region")
                } else {
                    Text("Place 2 \(pieceStyle.plural) in every row, column and region")
                }
            }
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
        // The picker shows `difficultyRaw` but routes a tap through `requestDifficulty`,
        // which asks before abandoning a game in progress. If the player cancels, the
        // segment snaps back because the binding's value never changed.
        Picker("Difficulty", selection: Binding(get: { difficultyRaw },
                                                set: { requestDifficulty($0) })) {
            ForEach(Difficulty.allCases) { level in
                Text(level.shortLabel).tag(level.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 360)
        .disabled(model.isGenerating || model.isRealizing)
        .onChange(of: difficultyRaw) { oldValue, newValue in
            let old = Difficulty(rawValue: oldValue) ?? .easy
            let new = Difficulty(rawValue: newValue) ?? .easy
            // Switching commits a new puzzle in the target mode — count it against the
            // free daily allowance (a no-op for Beginner or with Full Access).
            if !store.isUnlocked { FreePuzzleLimiter.recordPuzzle(in: new) }
            model.setDifficulty(new)
            // Remind the player of the rule only when the piece-per-line count actually
            // changes (i.e. crossing into or out of Beginner).
            if old.starsPerUnit != new.starsPerUnit {
                showRuleToast(stars: new.starsPerUnit)
            }
        }
    }

    /// Handles a difficulty-picker tap: shows the paywall if the target mode's free
    /// puzzle is used up, otherwise applies it immediately on a fresh board or asks first
    /// when a game is in progress. Committing the change (here or from the dialog) updates
    /// `difficultyRaw`, whose `onChange` starts the new game.
    private func requestDifficulty(_ raw: String) {
        guard raw != difficultyRaw else { return }
        let target = Difficulty(rawValue: raw) ?? .easy
        guard canStartNewPuzzle(in: target) else { showPaywall = true; return }
        if model.hasProgress {
            pendingDifficultyRaw = raw
            showSwitchConfirm = true
        } else {
            difficultyRaw = raw
        }
    }

    // MARK: - Free-tier gate

    /// Whether the player may start a new puzzle in `difficulty` right now — always true
    /// with Full Access or in Beginner, otherwise limited to one per day per mode.
    private func canStartNewPuzzle(in difficulty: Difficulty) -> Bool {
        store.isUnlocked || FreePuzzleLimiter.hasFreePuzzle(in: difficulty)
    }

    /// Starts a new puzzle at the current difficulty, or shows the paywall if the daily
    /// free allowance for this mode is spent. Used by the New button and the win banner.
    private func requestNewPuzzle() {
        guard canStartNewPuzzle(in: difficulty) else { showPaywall = true; return }
        if !store.isUnlocked { FreePuzzleLimiter.recordPuzzle(in: difficulty) }
        Task { await model.newGame() }
    }

    // MARK: - Board

    private func board(side: CGFloat) -> some View {
        ZStack {
            BoardView(
                puzzle: model.puzzle,
                marks: model.marks,
                highlights: model.highlights,
                wrongStars: model.wrongStars,
                wrongDots: model.wrongDots,
                pieceStyle: pieceStyle,
                hintCell: model.hintFocus,
                ghostCell: model.guessGhost,
                ghostPulse: model.ghostPulse,
                hiddenStars: hiddenStars,
                onTap: { row, col in model.tap(row: row, col: col) },
                onDragBegin: { model.beginDrag() },
                onDragPaint: { start, end in model.dragPaint(from: start, to: end) },
                onDragEnd: { model.endDrag() }
            )
            .frame(width: side, height: side)
            .opacity(model.isGenerating ? 0.12 : 1)

            // Each solved cherry bursts in turn, drawn exactly over its grid cell.
            if winCelebration && model.isSolved {
                CherryExplosionLayer(stars: explosionStars, explodedCount: explodedCount,
                                     size: model.puzzle.size, side: side,
                                     pieceStyle: pieceStyle)
            }

            if model.isGenerating {
                GeneratingView(stage: model.generationStage, attempt: model.generationAttempt)
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

    /// The cherries that have already burst — drawn as empty cells while the overlay
    /// plays their explosion.
    private var hiddenStars: Set<GridPosition> {
        Set(explosionStars.prefix(explodedCount))
    }

    /// Bursts the solved cherries one at a time (top-to-bottom, left-to-right), each
    /// with a crisp haptic pop that crescendos, then a final confetti sweep and the
    /// "Play again" banner. If the win celebration is off, the banner shows at once.
    private func startWinFinale() {
        finaleTask?.cancel()
        guard winCelebration else {
            explosionStars = []
            explodedCount = 0
            showBanner = true
            return
        }
        // Burst the pieces in a random order rather than reading-order, so the finale
        // feels like scattered fireworks instead of a sweep.
        let order = model.starPositions.shuffled()
        explosionStars = order
        explodedCount = 0
        showBanner = false
        finaleTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.35))
            let count = order.count
            for i in 0..<count {
                if Task.isCancelled { return }
                explodedCount = i + 1
                if haptics {
                    let ramp = count > 1 ? Double(i) / Double(count - 1) : 1
                    celebrationHaptics.playPop(strength: Float(0.8 + 0.2 * ramp))
                }
                try? await Task.sleep(for: .seconds(0.12))
            }
            if Task.isCancelled { return }
            if haptics { celebrationHaptics.play() }   // a swelling confetti sweep to finish
            try? await Task.sleep(for: .seconds(0.35))
            if Task.isCancelled { return }
            showBanner = true
        }
    }

    /// The hidden long-press payoff: fill in all but one cherry, give a solid buzz,
    /// and arm the tap-swallowing flag (self-clearing in case the tap never lands).
    private func secretNearSolve() {
        guard model.canHint else { return }
        model.revealAllButOne()
        if haptics { celebrationHaptics.play() }
        secretSolveFired = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            secretSolveFired = false
        }
    }

    /// Flashes a small "N {piece} per row, column and region" reminder, auto-dismissing.
    private func showRuleToast(stars: Int) {
        let toast: LocalizedStringKey = stars == 1
            ? "1 \(pieceStyle.noun) per row, column and region"
            : "2 \(pieceStyle.plural) per row, column and region"
        withAnimation(.spring(duration: 0.3)) { ruleToast = toast }
        ruleToastTask?.cancel()
        ruleToastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeOut(duration: 0.3)) { ruleToast = nil }
        }
    }

    /// The long-press payoff on Check: also flag dots placed on squares that actually
    /// need a cherry. Arms the tap-swallowing flag (self-clearing if the tap never lands).
    private func deepCheck() {
        model.checkDeep()
        deepCheckFired = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            deepCheckFired = false
        }
    }

    /// Cancels any running finale and clears its state (called when the win ends).
    private func resetWinFinale() {
        finaleTask?.cancel()
        finaleTask = nil
        explodedCount = 0
        explosionStars = []
        showBanner = false
    }

    private var celebration: some View {
        ZStack {
            if winCelebration {
                CelebrationView(piece: pieceStyle)
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
                requestNewPuzzle()
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
                ToolButton(title: "New",
                           systemImage: canStartNewPuzzle(in: difficulty) ? "sparkles" : "lock.fill",
                           style: .prominent) {
                    if canStartNewPuzzle(in: difficulty) { showNewConfirm = true }
                    else { showPaywall = true }
                }
                ToolButton(title: "Hint", systemImage: "lightbulb",
                           isEnabled: model.canHint,
                           onLongPress: secretNearSolve) {
                    // A long press just fired the secret near-solve; swallow the tap
                    // that lands on release so the hint dialog doesn't also appear.
                    if secretSolveFired { secretSolveFired = false; return }
                    showHintConfirm = true
                }
                ToolButton(title: "Check", systemImage: "checkmark.seal",
                           onLongPress: deepCheck, longPressSeconds: 3) {
                    // Swallow the tap that lands when the finger lifts after a long press.
                    if deepCheckFired { deepCheckFired = false; return }
                    model.check()
                }
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
            exitPressTick &+= 1
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
        .sensoryFeedback(trigger: exitPressTick) { _, _ in
            haptics ? .impact(weight: .light, intensity: 0.7) : nil
        }
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

/// The game title: "STAR BATTLE+" in all caps to echo the star key-art — a golden
/// "STAR", a royal-blue "BATTLE" and a golden "+". Each word is filled with a top-lit
/// metallic gradient and carries a crisp bottom edge plus a soft drop shadow, so it reads
/// with real depth and definition rather than flat lettering.
struct GameTitle: View {
    private static let gold = LinearGradient(
        colors: [Color(hex: 0xFFE7A0), Color(hex: 0xF2B01E), Color(hex: 0xC6820A)],
        startPoint: .top, endPoint: .bottom)
    private static let blue = LinearGradient(
        colors: [Color(hex: 0x7AA6F7), Color(hex: 0x2E6BE5), Color(hex: 0x1B47B0)],
        startPoint: .top, endPoint: .bottom)

    var body: some View {
        HStack(spacing: 0) {
            word("STAR ", Self.gold)
            word("BATTLE", Self.blue)
            word("+", Self.gold)
        }
        .font(.system(size: 34, weight: .heavy, design: .rounded))
        .tracking(1)
        .minimumScaleFactor(0.7)
        .lineLimit(1)
        // A tight dark edge just below reads as an emboss; the softer shadow adds depth.
        .shadow(color: .black.opacity(0.55), radius: 0.5, x: 0, y: 1)
        .shadow(color: .black.opacity(0.38), radius: 5, x: 0, y: 3)
        .accessibilityElement()
        .accessibilityLabel("Star Battle+")
        .accessibilityAddTraits(.isHeader)
    }

    private func word(_ s: String, _ fill: LinearGradient) -> some View {
        Text(verbatim: s).foregroundStyle(fill)
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
    /// An optional action triggered by a long press of `longPressSeconds`. Used for the
    /// deep Check (5s) and the secret near-solve on Hint (10s); nil for other buttons.
    var onLongPress: (() -> Void)? = nil
    var longPressSeconds: Double = 10
    let action: () -> Void

    /// Times the secret hold: started when the finger lands and cancelled the instant
    /// it lifts, so the action only fires after a full, uninterrupted 10s press.
    @State private var holdTask: Task<Void, Never>?

    @AppStorage(SettingsKey.haptics) private var haptics = true
    /// Bumped on every tap so the button gives a light "pressed" haptic.
    @State private var pressTick = 0

    var body: some View {
        let button = Button {
            pressTick &+= 1
            action()
        } label: {
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
        // A light tap so every control confirms the press (gated by the Haptics setting).
        .sensoryFeedback(trigger: pressTick) { _, _ in
            haptics ? .impact(weight: .light, intensity: 0.7) : nil
        }

        // A LongPressGesture loses arbitration to the Button on a plain style, so the
        // hold is timed manually: a zero-distance drag reports finger-down/up while the
        // Button's own tap keeps working. Only attached when a secret action exists.
        if let onLongPress, isEnabled {
            button.simultaneousGesture(holdGesture(onLongPress))
        } else {
            button
        }
    }

    private func holdGesture(_ perform: @escaping () -> Void) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                // Schedule once per press; the task is left in place (not nilled) after
                // it fires so further onChanged ticks during the same hold can't re-arm it.
                guard holdTask == nil else { return }
                holdTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(longPressSeconds))
                    guard !Task.isCancelled else { return }
                    perform()
                }
            }
            .onEnded { _ in
                holdTask?.cancel()
                holdTask = nil
            }
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
    return GameView(model: model).environment(PurchaseManager())
}

#Preview("Mark mode") {
    let model = GameViewModel()
    let cells = model.puzzle.solution.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
    for p in cells.prefix(8) {
        model.tap(row: p.row, col: p.col)
        model.tap(row: p.row, col: p.col)
    }
    model.toggleHighlightMode()
    return GameView(model: model).environment(PurchaseManager())
}
