import SwiftUI

/// The Stats tab: cumulative play history (games started/solved, solve rate, and
/// best / average completion time). Reloads each time it appears.
struct StatsView: View {
    @State private var stats = Stats()
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("Games solved", "\(stats.solved)", "checkmark.seal.fill", .green)
                    row("Games started", "\(stats.started)", "play.circle.fill", .blue)
                    row("Solve rate", solveRate, "percent", .orange)
                }

                Section("Times") {
                    row("Best time", timeText(stats.best), "trophy.fill", .yellow)
                    row("Average time", timeText(stats.average), "clock.fill", .purple)
                }

                Section("Helpers") {
                    row("Hints used", "\(stats.hints)", "lightbulb.fill", .blue)
                    row("Bad cherries caught", "\(stats.badGuesses)", "xmark.seal.fill", .red)
                }

                if stats.solved == 0 {
                    Section {
                        Text("Solve your first puzzle to start tracking stats.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset stats", systemImage: "trash")
                    }
                    .disabled(stats.started == 0 && stats.solved == 0)
                }
            }
            .navigationTitle("Stats")
        }
        .onAppear { stats = StatsStore.load() }
        .confirmationDialog("Reset all stats?", isPresented: $showResetConfirm,
                            titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                StatsStore.reset()
                stats = StatsStore.load()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently clears your play history.")
        }
    }

    private var solveRate: String {
        guard stats.started > 0 else { return "—" }
        let pct = Int((Double(stats.solved) / Double(stats.started) * 100).rounded())
        return "\(min(pct, 100))%"
    }

    private func timeText(_ seconds: Int?) -> String {
        guard let seconds else { return "—" }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func row(_ title: String, _ value: String, _ symbol: String, _ tint: Color) -> some View {
        HStack {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol).foregroundStyle(tint)
            }
            Spacer()
            Text(value)
                .font(.body.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    StatsStore.save(Stats(started: 14, solved: 11, times: [128, 95, 210, 84, 156, 142],
                          hints: 3, badGuesses: 5))
    return StatsView()
}
