import SwiftUI

/// The Settings tab: appearance, the piece icon, and whether the timer is shown.
/// Everything is backed by `@AppStorage`, so changes apply live across the app.
struct SettingsView: View {
    @AppStorage(SettingsKey.appearance) private var appearance = AppearanceMode.system.rawValue
    @AppStorage(SettingsKey.pieceStyle) private var pieceRaw = PieceStyle.cherry.rawValue
    @AppStorage(SettingsKey.hideTimer) private var hideTimer = false

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Timer") {
                    Toggle("Hide the timer", isOn: $hideTimer)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
