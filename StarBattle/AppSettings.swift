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
}

/// Puzzle difficulty, graded by how much step-by-step logic a solve needs (the
/// count of single-cell contradiction deductions). Bands are defined in
/// `PuzzleGenerator.band(forComplexity:)`. `nonisolated` so the off-main generator
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
    case cherry, star, queen, diamond, heart

    var id: String { rawValue }

    /// Short name shown in Settings.
    var label: String { noun.capitalized }

    /// The lowercase singular noun for this piece, used in instructional text and
    /// hints (e.g. "place a star here").
    var noun: String {
        switch self {
        case .cherry: return "cherry"
        case .star:   return "star"
        case .queen:  return "queen"
        case .diamond: return "diamond"
        case .heart:  return "heart"
        }
    }

    /// The lowercase plural noun (e.g. "two stars per row").
    var plural: String {
        switch self {
        case .cherry: return "cherries"
        case .star:   return "stars"
        case .queen:  return "queens"
        case .diamond: return "diamonds"
        case .heart:  return "hearts"
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
