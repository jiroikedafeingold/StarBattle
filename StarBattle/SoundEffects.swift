import AVFoundation
import Foundation

/// Plays the game's short sound effects, each preloaded once. Respects the "Sound effects"
/// setting (default on) and the device mute switch (an ambient audio session, which also
/// mixes politely with any music already playing). The sounds are simple synthesized tones
/// bundled as `.wav` files (`place`, `dot`, `bad`, `doit`, `celebrate`) — drop in custom
/// recordings with the same names to replace them.
final class SoundEffects {
    static let shared = SoundEffects()

    enum Effect: String, CaseIterable {
        case place       // a symbol placed on the board
        case dot         // a dot placed or dragged
        case bad         // a wrong placement / rule conflict
        case doit        // "Do it" — committing Mark-mode guesses
        case celebrate   // the win celebration
    }

    private var players: [Effect: AVAudioPlayer] = [:]
    private var sessionConfigured = false
    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    private init() {
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav"),
                  let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            players[effect] = player
        }
    }

    /// Plays `effect` unless sound is disabled (or we're rendering a SwiftUI preview).
    func play(_ effect: Effect) {
        guard !isPreview, SettingsKey.boolDefaultingTrue(SettingsKey.sound) else { return }
        guard let player = players[effect] else { return }
        configureSessionIfNeeded()
        player.currentTime = 0
        player.play()
    }

    private func configureSessionIfNeeded() {
        guard !sessionConfigured else { return }
        sessionConfigured = true
        // `.ambient`: honours the silent switch and mixes with other audio — the polite
        // default for incidental game sound effects.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
