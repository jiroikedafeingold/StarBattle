import SwiftUI

/// The app's root: a Play / Help / Settings tab bar, the app-wide light/dark
/// appearance, and a first-launch onboarding cover.
struct ContentView: View {
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.hasSeenOnboarding) private var hasSeenOnboarding = false

    @State private var showOnboarding = false

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearance) ?? .system
    }

    var body: some View {
        TabView {
            GameView()
                .tabItem { Label("Play", systemImage: "gamecontroller") }

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
    }
}

#Preview {
    ContentView()
}
