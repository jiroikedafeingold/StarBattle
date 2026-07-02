import SwiftUI

/// The app's root: a Play / Stats / Help / Settings tab bar, the app-wide light/dark
/// appearance, a first-launch onboarding cover, and saving the game when the app is
/// backgrounded.
struct ContentView: View {
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.dark.rawValue
    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false

    @State private var model = GameViewModel()
    /// The in-app purchase / entitlement service, shared with every screen (Play gates
    /// new puzzles on it; Settings buys and restores it).
    @State private var store = PurchaseManager()
    @State private var showOnboarding = false
    @Environment(\.scenePhase) private var scenePhase

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearance) ?? .dark
    }

    var body: some View {
        TabView {
            GameView(model: model)
                .tabItem { Label { Text("Play") } icon: { CherryTabIcon.image } }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar") }

            HelpView()
                .tabItem { Label("Help", systemImage: "questionmark.circle") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .environment(store)
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
