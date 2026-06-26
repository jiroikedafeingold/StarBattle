import SwiftUI

/// The Help tab: the rules, a handful of solving tactics with worked examples, a
/// button to replay the tutorial, and credits.
struct HelpView: View {
    @State private var showTutorial = false
    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.cherry.rawValue

    private var piece: PieceStyle { PieceStyle(rawValue: pieceRaw) ?? .cherry }

    var body: some View {
        NavigationStack {
            List {
                Section("How to play") {
                    ruleRow("2️⃣",
                            "Every row, column and coloured region holds exactly two \(piece.plural).") {
                        inlineDiagram(RuleDiagrams.twoPerLine(piece: piece, cell: 26),
                                      ok: true, label: "Two per line")
                        inlineDiagram(RuleDiagrams.region(piece: piece, cell: 26),
                                      label: "Two per region")
                    }
                    ruleRow("🚫",
                            "Two \(piece.plural) may never touch — not even diagonally.") {
                        inlineDiagram(RuleDiagrams.neverTouch(piece: piece, cell: 26),
                                      label: "Blocks neighbours")
                        inlineDiagram(RuleDiagrams.touchBad(piece: piece, cell: 26),
                                      ok: false, label: "Not even diagonally")
                    }
                    rule("👆",
                         "Tap a square to cycle it: empty → a dot → a \(piece.noun) → empty.")
                    rule("✏️",
                         "Drag across a row or column to lay a line of dots quickly.")
                    rule("🏆",
                         "Solve it when all \(piece.plural) are placed legally — the board celebrates!")
                }

                Section("Tips & tactics") {
                    tip("📝",
                        "Mark, don't guess",
                        "Put a dot in every square you’ve ruled out. Placing a \(piece.noun) dots its eight neighbours for you automatically.")
                    tip("🎯",
                        "Start where it’s tight",
                        "Look for a row, column or region whose \(piece.plural) can only fit one way — small or cramped regions are a great first move.")
                    tip("🔢",
                        "Count the gaps",
                        "If a line still needs two \(piece.plural) and has exactly two open squares, both must be \(piece.plural). If a line already has its two, every other square is empty.")
                    tip("💡",
                        "Ask for a hint",
                        "Hint places the next square that logic forces and explains why — a good way to learn a new tactic.")
                    tip("🧪",
                        "Test an idea safely",
                        "In Mark mode, pencil in a candidate \(piece.noun) and its dots. If it leads to a dead end, clear it; if it holds up, tap “Do it” to commit it.")
                }

                Section("Using Mark mode") {
                    VStack(alignment: .leading, spacing: 12) {
                        markParagraph("🖍️",
                            "Mark mode is for trying out a path. Tap the **Mark** button and the board turns into a scratch pad: tap a square once for a guess-dot, again for a guess-\(piece.noun) — exactly like the real board, but nothing is committed yet.")
                        markParagraph("🧭",
                            "Pick a square you’re unsure about and guess a \(piece.noun) there. Then follow the consequences — place the dots and \(piece.plural) that guess forces. If it all holds together, tap **Do it** to make the guesses real.")
                        markParagraph("❌",
                            "If the path leads to a contradiction, then your first guess was wrong — so that square is actually a **dot**. Either way you’ve learned something, and often you can read off several more squares from there.")
                        markParagraph("📍",
                            "When you back out of a path (Undo) or tap **Erase**, the square where you started stays **outlined for a few seconds** — by then you should know whether it’s a \(piece.noun) or a dot, so mark it for real.")
                    }
                    .padding(.vertical, 2)
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
                        Text("Cherry Battle is a cherry-themed take on **Star Battle**, the classic logic puzzle invented by **Hans Eendebak**. All credit for the original puzzle design goes to him.")
                        Text("Made with 🍒 & SwiftUI.")
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

    private func rule(_ emoji: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Text(emoji).font(.title3)
        }
    }

    /// A rule with one or more example diagrams shown directly beneath it.
    @ViewBuilder
    private func ruleRow<Diagrams: View>(_ symbol: String, _ text: String,
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
    private func inlineDiagram(_ board: MiniBoard, ok: Bool? = nil, label: String) -> some View {
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

    private func tip(_ emoji: String, _ title: String, _ body: String) -> some View {
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
