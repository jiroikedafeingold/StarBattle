import SwiftUI

/// The app's root: a Play / Stats / Help / Settings tab bar, the app-wide light/dark
/// appearance, a first-launch onboarding cover, and saving the game when the app is
/// backgrounded.
struct ContentView: View {
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false

    @State private var model = GameViewModel()
    @State private var showOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearance) ?? .system
    }

    var body: some View {
        TabView {
            GameView(model: model)
                .tabItem { Label("Play", systemImage: "gamecontroller") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            HelpView()
                .tabItem { Label("Help", systemImage: "questionmark.circle") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView()
        }
        .task {
            // Show the tutorial once, on the first launch.
            if !hasSeenOnboarding { showOnboarding = true }
        }
        .onChange(of: scenePhase) { _, phase in
            // Persist the current game whenever the app leaves the foreground.
            if phase != .active { model.saveGame() }
        }
    }
}

#Preview {
    ContentView()
}
