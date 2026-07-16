import SwiftUI

@main
struct StarBattleApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Shows the animated Star Battle Nova intro first; tapping Play fades it away to reveal
/// the game. (The real iOS launch screen — drawn by the system before any code runs —
/// is necessarily static, so an animated intro like this lives just inside the app.)
private struct RootView: View {
    @State private var showIntro = true
    /// Set once the player taps Play, so the auto-advance timer doesn't yank the intro
    /// away while they're acting on it.
    @State private var engaged = false

    var body: some View {
        ZStack {
            ContentView()

            if showIntro {
                CherryBattleIntroView(onPlay: { dismissIntro() })
                .transition(.opacity)
                .zIndex(1)
                .task {
                    // Advance into the game on its own once the entrance animation has
                    // played, unless the player taps Play first.
                    try? await Task.sleep(for: .seconds(3.2))
                    if !engaged { dismissIntro() }
                }
            }
        }
    }

    private func dismissIntro() {
        engaged = true
        withAnimation(.easeInOut(duration: 0.45)) { showIntro = false }
    }
}
