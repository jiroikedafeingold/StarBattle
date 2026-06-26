import SwiftUI

/// User-facing preferences, persisted with `@AppStorage`. These keys are read
/// directly by the views that need them (the board, the timer, the root color
/// scheme) so there is no separate settings object to thread through.
enum SettingsKey {
    static let pieceStyle = "pieceStyle"
    static let appearance = "appearance"
    static let hideTimer = "hideTimer"
    static let hasSeenOnboarding = "hasSeenOnboarding"
    static let difficulty = "difficulty"
    static let cleanWins = "cleanWins"
    static let difficultyPromptShown = "difficultyPromptShown"
    /// Whether placing a piece automatically dots its eight neighbours. Default on.
    static let autoDot = "autoDot"
    /// Whether dragging across the board paints a line of dots. Default on.
    static let swipeDots = "swipeDots"
    /// Whether haptic feedback fires on taps, checks and wins. Default on.
    static let haptics = "haptics"
    /// Whether the falling-confetti animation plays on a win. Default on.
    static let winCelebration = "winCelebration"

    /// Reads a Bool that should default to `true` when the user hasn't set it yet.
    static func boolDefaultingTrue(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }
}

/// Puzzle difficulty, graded by the *peak* technique a solve forces and how often —
/// not the aggregate step count. Bands are defined in
/// `PuzzleGenerator.band(forProfile:)`. `nonisolated` so the off-main generator
/// can use it.
nonisolated enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case easy, medium, hard

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// The next harder level, if any (used by the "step up" prompt).
    var harder: Difficulty? {
        switch self {
        case .easy: return .medium
        case .medium: return .hard
        case .hard: return nil
        }
    }
}

/// The glyph the player places on the board. The cherry is the default (and the
/// app icon); the rest are bright emoji alternatives — a few classics plus some
/// deliberately quirky picks for fun.
enum PieceStyle: String, CaseIterable, Identifiable {
    case cherry, star, queen, dog, cat, bunny
    case poop, alien, ghost, robot, unicorn, dino

    var id: String { rawValue }

    /// Short name shown in Settings.
    var label: String { noun.capitalized }

    /// The lowercase singular noun for this piece, used in instructional text and
    /// hints (e.g. "place a star here").
    var noun: String {
        switch self {
        case .cherry:  return "cherry"
        case .star:    return "star"
        case .queen:   return "queen"
        case .dog:     return "dog"
        case .cat:     return "cat"
        case .bunny:   return "bunny"
        case .poop:    return "poop"
        case .alien:   return "alien"
        case .ghost:   return "ghost"
        case .robot:   return "robot"
        case .unicorn: return "unicorn"
        case .dino:    return "dino"
        }
    }

    /// The lowercase plural noun (e.g. "two stars per row").
    var plural: String {
        switch self {
        case .cherry:  return "cherries"
        case .star:    return "stars"
        case .queen:   return "queens"
        case .dog:     return "dogs"
        case .cat:     return "cats"
        case .bunny:   return "bunnies"
        case .poop:    return "poops"
        case .alien:   return "aliens"
        case .ghost:   return "ghosts"
        case .robot:   return "robots"
        case .unicorn: return "unicorns"
        case .dino:    return "dinos"
        }
    }

    /// The plural noun with a capitalised first letter, for the start of a sentence.
    var pluralCapitalized: String {
        plural.prefix(1).uppercased() + plural.dropFirst()
    }

    /// The colour emoji drawn for every style except the custom-drawn cherry, so the
    /// pieces read as bright, recognisable objects rather than flat monochrome symbols.
    /// (`cherry` is rendered by `CherryView`, so its value here is unused.)
    var emoji: String {
        switch self {
        case .cherry:  return "🍒"   // unused — cherry uses CherryView
        case .star:    return "⭐️"
        case .queen:   return "👑"
        case .dog:     return "🐶"
        case .cat:     return "🐱"
        case .bunny:   return "🐰"
        case .poop:    return "💩"
        case .alien:   return "👽"
        case .ghost:   return "👻"
        case .robot:   return "🤖"
        case .unicorn: return "🦄"
        case .dino:    return "🦖"
        }
    }

    /// The piece's signature colour — the tint of its symbol, or a ripe red for the
    /// custom-drawn cherry. Used both for the placed glyph and for its win-explosion
    /// confetti, so the burst always matches whatever piece the player chose.
    var color: Color {
        switch self {
        case .cherry:  return Color(red: 0.86, green: 0.12, blue: 0.18)
        case .star:    return Color(red: 0.98, green: 0.74, blue: 0.10)
        case .queen:   return Color(red: 0.62, green: 0.22, blue: 0.78)
        case .dog:     return Color(red: 0.60, green: 0.41, blue: 0.22)
        case .cat:     return Color(red: 0.96, green: 0.52, blue: 0.12)
        case .bunny:   return Color(red: 0.91, green: 0.45, blue: 0.62)
        case .poop:    return Color(red: 0.55, green: 0.36, blue: 0.20)   // brown
        case .alien:   return Color(red: 0.42, green: 0.78, blue: 0.52)   // little green
        case .ghost:   return Color(red: 0.82, green: 0.82, blue: 0.92)   // pale spectral
        case .robot:   return Color(red: 0.55, green: 0.60, blue: 0.66)   // steel
        case .unicorn: return Color(red: 0.93, green: 0.55, blue: 0.80)   // magic pink
        case .dino:    return Color(red: 0.33, green: 0.62, blue: 0.30)   // green
        }
    }

}

/// How the app picks its light/dark appearance.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// The scheme to force, or `nil` to follow the system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
