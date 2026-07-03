import SwiftUI
import StoreKit

/// The Settings tab: appearance, the piece icon, and whether the timer is shown.
/// Everything is backed by `@AppStorage`, so changes apply live across the app.
struct SettingsView: View {
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.dark.rawValue
    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.cherry.rawValue
    @AppStorage(SettingsKey.hideTimer) private var hideTimer = false
    @AppStorage(SettingsKey.autoDot) private var autoDot = true
    @AppStorage(SettingsKey.swipeDots) private var swipeDots = true
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.winCelebration) private var winCelebration = true

    @Environment(PurchaseManager.self) private var store
    @State private var showPaywall = false
    /// Timestamps of recent taps on the poop piece, for the secret unlock gesture.
    @State private var poopTaps: [Date] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Full Access") {
                    if store.hasFullAccess {
                        Label {
                            Text("Full Access unlocked")
                        } icon: {
                            Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                        }
                        Text("Thanks for your support — enjoy unlimited puzzles in every mode!")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Unlock Full Access", systemImage: "infinity")
                                Spacer()
                                if let product = store.product {
                                    Text(product.displayPrice).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Button("Restore Purchase") {
                            Task { await store.restore() }
                        }
                        .disabled(store.isPurchasing || store.isRestoring)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.label).tag(mode.rawValue)
                        }
                    }
                }

                Section("Game piece") {
                    ForEach(PieceStyle.allCases) { style in
                        Button {
                            pieceRaw = style.rawValue
                            if style == .poop { registerSecretTap() }
                        } label: {
                            HStack(spacing: 14) {
                                PieceView(style: style, isWrong: false, size: 30)
                                    .frame(width: 36, height: 36)
                                Text(style.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if pieceRaw == style.rawValue {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }

                Section("Assists") {
                    Toggle("Place dots around pieces", isOn: $autoDot)
                    Toggle("Swipe to draw dots", isOn: $swipeDots)
                }

                Section("Feedback") {
                    Toggle("Haptics", isOn: $haptics)
                    Toggle("Win celebration", isOn: $winCelebration)
                }

                Section("Timer") {
                    Toggle("Hide the timer", isOn: $hideTimer)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    /// Secret comp unlock: three quick taps on the poop piece silently unlock the boards
    /// (equivalent to the purchase) and remember it across launches. No visible feedback —
    /// tapping the row still just selects the poop piece as usual.
    private func registerSecretTap() {
        let now = Date()
        poopTaps = (poopTaps + [now]).filter { now.timeIntervalSince($0) < 1.2 }
        if poopTaps.count >= 3 {
            poopTaps.removeAll()
            store.unlockSecretly()
        }
    }
}

#Preview {
    SettingsView()
        .environment(PurchaseManager())
}
