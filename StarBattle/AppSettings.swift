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

    /// The SF Symbol used for every style except the custom-drawn cherry.
    /// (`cherry` is rendered by `CherryView`, so this is unused for it.)
    var symbolName: String {
        switch self {
        case .cherry:  return "circle.fill"   // unused — cherry uses CherryView
        case .star:    return "star.fill"
        case .queen:   return "crown.fill"
        case .diamond: return "suit.diamond.fill"
        case .heart:   return "suit.heart.fill"
        case .dog:     return "dog.fill"
        case .cat:     return "cat.fill"
        case .bunny:   return "hare.fill"
        case .turtle:  return "tortoise.fill"
        case .bird:    return "bird.fill"
        case .fish:    return "fish.fill"
        case .ladybug: return "ladybug.fill"
        }
    }

    /// A symbol guaranteed to exist on iOS 17, used when `symbolName` isn't available
    /// on the running OS (e.g. `dog.fill`/`cat.fill` are newer). Resolved at runtime.
    var fallbackSymbol: String {
        switch self {
        case .dog, .cat: return "pawprint.fill"
        case .bird:      return "leaf.fill"
        case .fish:      return "drop.fill"
        case .ladybug:   return "ant.fill"
        default:         return symbolName
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
