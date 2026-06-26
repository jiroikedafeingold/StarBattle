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
nonisolated enum Difficulty: String, CaseIterable, Identifiable {
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
/// app icon); the rest are simple tintable alternatives.
enum PieceStyle: String, CaseIterable, Identifiable {
    case cherry, star, heart, diamond, queen
    case dog, cat, bunny, turtle, bird, fish, ladybug

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
        case .diamond: return "diamond"
        case .heart:   return "heart"
        case .dog:     return "dog"
        case .cat:     return "cat"
        case .bunny:   return "bunny"
        case .turtle:  return "turtle"
        case .bird:    return "bird"
        case .fish:    return "fish"
        case .ladybug: return "ladybug"
        }
    }

    /// The lowercase plural noun (e.g. "two stars per row").
    var plural: String {
        switch self {
        case .cherry:  return "cherries"
        case .star:    return "stars"
        case .queen:   return "queens"
        case .diamond: return "diamonds"
        case .heart:   return "hearts"
        case .dog:     return "dogs"
        case .cat:     return "cats"
        case .bunny:   return "bunnies"
        case .turtle:  return "turtles"
        case .bird:    return "birds"
        case .fish:    return "fish"
        case .ladybug: return "ladybugs"
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
        case .diamond: return "💎"
        case .heart:   return "❤️"
        case .dog:     return "🐶"
        case .cat:     return "🐱"
        case .bunny:   return "🐰"
        case .turtle:  return "🐢"
        case .bird:    return "🐦"
        case .fish:    return "🐠"
        case .ladybug: return "🐞"
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
        case .diamond: return Color(red: 0.90, green: 0.16, blue: 0.30)
        case .heart:   return Color(red: 0.90, green: 0.16, blue: 0.30)
        case .dog:     return Color(red: 0.60, green: 0.41, blue: 0.22)
        case .cat:     return Color(red: 0.96, green: 0.52, blue: 0.12)
        case .bunny:   return Color(red: 0.91, green: 0.45, blue: 0.62)
        case .turtle:  return Color(red: 0.20, green: 0.62, blue: 0.34)
        case .bird:    return Color(red: 0.20, green: 0.55, blue: 0.90)
        case .fish:    return Color(red: 0.10, green: 0.62, blue: 0.66)
        case .ladybug: return Color(red: 0.85, green: 0.13, blue: 0.16)
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
