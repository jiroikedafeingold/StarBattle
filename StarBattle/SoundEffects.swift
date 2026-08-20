import AVFoundation
import Foundation

/// Plays the game's short sound effects, each preloaded once. Respects the "Sound effects"
/// setting (default on) and the device mute switch (an ambient audio session, which also
/// mixes politely with any music already playing). The sounds are simple synthesized tones
/// bundled as `.wav` files (`place`, `dot`, `bad`, `doit`, `celebrate`) — drop in custom
/// recordings with the same names to replace them.
///
/// **Everything touching AVFoundation runs on `queue`, never the main thread.** The project
/// defaults to `MainActor` isolation, so an unannotated type here would seek and start its
/// players on the main thread — which visibly stuttered taps and swipes on the board, since
/// starting a player (and the one-off audio-session setup) blocks for milliseconds. Callers
/// only enqueue and return.
///
/// Each effect also keeps a small ring of players, so rapid repeats — a dot per cell during
/// a swipe, or the win finale's bursts — overlap instead of fighting over a single player.
/// Restarting one mid-playback forces an expensive seek.
nonisolated final class SoundEffects: @unchecked Sendable {
    static let shared = SoundEffects()

    enum Effect: String, CaseIterable {
        case place       // a symbol placed on the board
        case dot         // a dot placed or dragged
        case bad         // a wrong placement / rule conflict
        case doit        // "Do it" — committing Mark-mode guesses
        case celebrate   // the win celebration
        case explode     // a piece bursting during the win finale
    }

    /// How many players each effect keeps, so quick repeats can overlap rather than
    /// restarting one another.
    private static let voicesPerEffect = 4

    /// Serialises every AVFoundation call off the main thread. `.userInitiated` because a
    /// sound that lands late feels worse than one that costs a little CPU.
    private let queue = DispatchQueue(label: "com.jirofeingold.CherryBomb.sound",
                                      qos: .userInitiated)

    /// The player rings and the next voice to use. Touched **only** on `queue` — that
    /// serialisation is what makes the `@unchecked Sendable` above sound.
    private var players: [Effect: [AVAudioPlayer]] = [:]
    private var nextVoice: [Effect: Int] = [:]

    private let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    private init() {
        guard !isPreview else { return }
        // Configure the session and preload up front, off the main thread. Doing this
        // lazily on the first sound put a one-off hitch exactly where it's most noticeable
        // — the player's first tap on the board.
        queue.async { [self] in
            configureSession()
            loadPlayers()
        }
    }

    /// Plays `effect` at `volume` (0...1, full volume by default) unless sound is disabled
    /// (or we're rendering a SwiftUI preview). Returns immediately; the work happens on
    /// `queue`.
    func play(_ effect: Effect, volume: Float = 1) {
        guard !isPreview else { return }
        queue.async { [self] in
            guard SettingsKey.boolDefaultingTrue(SettingsKey.sound),
                  let player = voice(for: effect) else { return }
            player.volume = volume
            // A finished player sits at the end of the file, so it needs rewinding; skip
            // the seek when it's already at the start.
            if player.currentTime != 0 { player.currentTime = 0 }
            player.play()
        }
    }

    /// An idle player for `effect` where one is free, otherwise the next in rotation.
    /// Must be called on `queue`.
    private func voice(for effect: Effect) -> AVAudioPlayer? {
        guard let ring = players[effect], !ring.isEmpty else { return nil }
        if let idle = ring.first(where: { !$0.isPlaying }) { return idle }
        let index = (nextVoice[effect] ?? 0) % ring.count
        nextVoice[effect] = index + 1
        return ring[index]
    }

    /// Must be called on `queue`.
    private func loadPlayers() {
        for effect in Effect.allCases {
            guard let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "wav")
            else { continue }
            let ring = (0..<Self.voicesPerEffect).compactMap { _ -> AVAudioPlayer? in
                guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
                player.prepareToPlay()
                return player
            }
            if !ring.isEmpty { players[effect] = ring }
        }
    }

    /// Must be called on `queue`.
    private func configureSession() {
        // `.ambient`: honours the silent switch and mixes with other audio — the polite
        // default for incidental game sound effects.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}
