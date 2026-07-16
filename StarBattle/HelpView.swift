import SwiftUI

/// The Help tab: the rules, a handful of solving tactics with worked examples, a
/// button to replay the tutorial, and credits.
struct HelpView: View {
    @State private var showTutorial = false
    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.star.rawValue
    @AppStorage(SettingsKey.difficulty) private var difficultyRaw = Difficulty.easy.rawValue

    private var piece: PieceStyle { PieceStyle(rawValue: pieceRaw) ?? .star }
    /// One in Beginner, two otherwise — so the rules and tactics teach the right count.
    private var stars: Int { (Difficulty(rawValue: difficultyRaw) ?? .easy).starsPerUnit }

    var body: some View {
        NavigationStack {
            List {
                Section("How to play") {
                    if stars == 1 {
                        ruleRow("1️⃣",
                                "Every row, column and coloured region holds exactly one \(piece.noun).") {
                            inlineDiagram(RuleDiagrams.onePerLine(piece: piece, cell: 26),
                                          ok: true, label: "One per line")
                            inlineDiagram(RuleDiagrams.oneRegion(piece: piece, cell: 26),
                                          label: "One per region")
                        }
                    } else {
                        ruleRow("2️⃣",
                                "Every row, column and coloured region holds exactly two \(piece.plural).") {
                            inlineDiagram(RuleDiagrams.twoPerLine(piece: piece, cell: 26),
                                          ok: true, label: "Two per line")
                            inlineDiagram(RuleDiagrams.region(piece: piece, cell: 26),
                                          label: "Two per region")
                        }
                    }
                    ruleRow("🚫",
                            "Two \(piece.plural) may never touch — not even diagonally.") {
                        inlineDiagram(RuleDiagrams.neverTouch(piece: piece, cell: 26),
                                      label: "Blocks neighbours")
                        inlineDiagram(RuleDiagrams.touchBad(piece: piece, cell: 26),
                                      ok: false, label: "Not even diagonally")
                    }
                    rule("👆",
                         "Tap a square to cycle it: empty → a dot → \(piece.article) \(piece.noun) → empty.")
                    rule("✏️",
                         "Drag across a row or column to lay a line of dots quickly.")
                    rule("🏆",
                         "Solve it when all \(piece.plural) are placed legally — the board celebrates!")
                }

                Section("How to solve") {
                    tip("📝",
                        "Mark what you rule out",
                        "Put a dot in every square that can’t hold \(piece.article) \(piece.noun). Placing \(piece.article) \(piece.noun) dots its eight neighbours for you automatically, so the board fills with clues.")
                    tip("🎯",
                        "Start where it’s tight",
                        "Look for a row, column or region whose \(piece.plural) can only fit one way — small or cramped regions are the easiest first moves.")
                    if stars == 1 {
                        tip("🔢",
                            "Count the gaps",
                            "If a line still needs its \(piece.noun) and has just one open square, that square is it. Once a line has its \(piece.noun), every other square is a dot.")
                    } else {
                        tip("🔢",
                            "Count the gaps",
                            "If a line still needs two \(piece.plural) and has exactly two open squares, both must be \(piece.plural). Once a line has its two, every other square is a dot.")
                    }
                    tip("🧠",
                        "Imagine, then follow the logic",
                        "The heart of the puzzle: pick a tricky square and imagine \(piece.article) \(piece.noun) there. Follow what it forces — neighbours become dots, and those dots force the next \(piece.plural). If the chain hits a contradiction, that square must be a dot instead; if it all fits, you’ve found real moves. Mark mode (below) lets you try this safely.")
                    tip("💡",
                        "Ask for a hint",
                        "Stuck? Hint places the next square logic forces and explains why — a good way to learn a new tactic.")
                }

                Section("Mark mode: try a “what if”") {
                    VStack(alignment: .leading, spacing: 12) {
                        markParagraph("🖍️",
                            "Mark mode is where you play out that “what if” without commitment. Tap **Mark** and the board becomes a scratch pad: tap a square once for a guess-dot, again for a guess-\(piece.noun) — just like the real board, but nothing sticks yet.")
                        markParagraph("🧭",
                            "Guess \(piece.article) \(piece.noun) in the square you’re unsure about, then follow the consequences — pencil in the dots and \(piece.plural) it forces. If everything holds together, tap **Do it** to make the guesses real.")
                        markParagraph("❌",
                            "If the path leads to a contradiction, your guess was wrong — so that square is really a **dot**. Either way you’ve learned something, and you can usually read off several more squares from there.")
                        markParagraph("📍",
                            "When you back out of a path (Undo) or tap **Erase**, the square where you started stays **outlined for a few seconds** — by then you know whether it’s \(piece.article) \(piece.noun) or a dot, so mark it for real.")
                    }
                    .padding(.vertical, 2)
                }

                Section("Check your work") {
                    tip("✅",
                        "Check for mistakes",
                        "Tap Check to flag any \(piece.plural) that don’t belong in the solution, drawn in red.")
                    tip("🔎",
                        "Deep-check your dots",
                        "Press and hold Check for a deeper look that also flags, in red, any dot you put on a square that actually needs \(piece.article) \(piece.noun).")
                }

                Section {
                    Button {
                        showTutorial = true
                    } label: {
                        Label("Replay the tutorial", systemImage: "play.circle")
                    }
                }

                Section("Credits") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Star Battle Nova is a friendly take on **Star Battle**, the classic logic puzzle invented by **Hans Eendebak**. All credit for the original puzzle design goes to him.")
                        Text("Made with ⭐️ & SwiftUI.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Help")
        }
        .sheet(isPresented: $showTutorial) {
            OnboardingView()
        }
    }

    private func markParagraph(_ emoji: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.title2)
                .frame(width: 28)
            Text(text)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func rule(_ emoji: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
        } icon: {
            Text(emoji).font(.title3)
        }
    }

    /// A rule with one or more example diagrams shown directly beneath it.
    @ViewBuilder
    private func ruleRow<Diagrams: View>(_ symbol: String, _ text: LocalizedStringKey,
                                         @ViewBuilder diagrams: () -> Diagrams) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            rule(symbol, text)
            HStack(alignment: .top, spacing: 22) {
                diagrams()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
    }

    /// A compact labelled diagram with an optional ✓/✗ badge, for use under a rule.
    private func inlineDiagram(_ board: MiniBoard, ok: Bool? = nil, label: LocalizedStringKey) -> some View {
        VStack(spacing: 6) {
            board
                .overlay(alignment: .topTrailing) {
                    if let ok {
                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.white, ok ? Color.green : Color.red)
                            .background(Circle().fill(.white).padding(2))
                            .offset(x: 7, y: -7)
                    }
                }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func tip(_ emoji: String, _ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji)
                .font(.title2)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(body).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HelpView()
}
