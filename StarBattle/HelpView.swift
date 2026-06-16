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
                    rule("2.square.fill",
                         "Every row, column and coloured region holds exactly two \(piece.plural).")
                    rule("hand.raised.slash.fill",
                         "Two \(piece.plural) may never touch — not even diagonally.")
                    rule("hand.tap.fill",
                         "Tap a square to cycle it: empty → a dot → a \(piece.noun) → empty.")
                    rule("hand.draw.fill",
                         "Drag across a row or column to lay a line of dots quickly.")
                    rule("trophy.fill",
                         "Solve it when all \(piece.plural) are placed legally — the board celebrates!")
                }

                Section("Tips & tactics") {
                    tip("square.dashed",
                        "Mark, don't guess",
                        "Put a dot in every square you’ve ruled out. Placing a \(piece.noun) dots its eight neighbours for you automatically.")
                    tip("arrow.down.right.and.arrow.up.left",
                        "Start where it’s tight",
                        "Look for a row, column or region whose \(piece.plural) can only fit one way — small or cramped regions are a great first move.")
                    tip("equal.square",
                        "Count the gaps",
                        "If a line still needs two \(piece.plural) and has exactly two open squares, both must be \(piece.plural). If a line already has its two, every other square is empty.")
                    tip("lightbulb.fill",
                        "Ask for a hint",
                        "Hint places the next square that logic forces and explains why — a good way to learn a new tactic.")
                    tip("highlighter",
                        "Test an idea safely",
                        "In Mark mode, pencil in a candidate \(piece.noun) and its dots. If it leads to a dead end, clear it; if it holds up, tap Realize to commit it.")
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

    private func rule(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(.red)
        }
    }

    private func tip(_ symbol: String, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.purple)
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
