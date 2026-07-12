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
    /// Whether a normal Check also flags dots placed where a piece belongs. Default off;
    /// the deep Check (long-press) always flags them regardless.
    static let checkDots = "checkDots"

    /// Reads a Bool that should default to `true` when the user hasn't set it yet.
    static func boolDefaultingTrue(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }
}

/// The free-tier gate: without "Full Access", a player may start **one new puzzle per
/// day in each of Easy, Medium and Hard**. Beginner is always free and unlimited.
/// Resuming a saved game or the launch board never counts — only *starting a new*
/// puzzle does. Full Access (see `PurchaseManager`) lifts the limit entirely; this type
/// only tracks the free allowance and does not know about entitlements.
enum FreePuzzleLimiter {

    /// Whether this mode is subject to the daily limit. Beginner never is.
    static func isLimited(_ difficulty: Difficulty) -> Bool { difficulty != .beginner }

    /// Whether a free player may start a new puzzle in `difficulty` today.
    static func hasFreePuzzle(in difficulty: Difficulty) -> Bool {
        guard isLimited(difficulty) else { return true }
        return UserDefaults.standard.object(forKey: key(difficulty)) as? Int != todayIndex
    }

    /// Records that a free player has used today's puzzle for `difficulty`.
    static func recordPuzzle(in difficulty: Difficulty) {
        guard isLimited(difficulty) else { return }
        UserDefaults.standard.set(todayIndex, forKey: key(difficulty))
    }

    private static func key(_ difficulty: Difficulty) -> String {
        "freePuzzleDay_\(difficulty.rawValue)"
    }

    /// The current calendar day as a whole-day index in the user's local time zone, so
    /// the allowance resets at local midnight.
    private static var todayIndex: Int {
        Int(Calendar.current.startOfDay(for: Date()).timeIntervalSinceReferenceDate / 86_400)
    }
}

/// Puzzle difficulty, graded by the *peak* technique a solve forces and how often —
/// not the aggregate step count. Bands are defined in
/// `PuzzleGenerator.band(forProfile:)`. `nonisolated` so the off-main generator
/// can use it.
nonisolated enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case beginner, easy, medium, hard, expert

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    /// A compact label so all five levels fit the segmented picker on small phones.
    var shortLabel: String {
        switch self {
        case .beginner: return "Begin"
        case .easy:     return "Easy"
        case .medium:   return "Med"
        case .hard:     return "Hard"
        case .expert:   return "Exp"
        }
    }

    /// The board's side length (cells per row/column) for this level. Beginner uses a
    /// gentler 5×5 grid; everything else is the standard 10×10.
    var boardSize: Int { self == .beginner ? 5 : 10 }

    /// How many pieces go in every row, column and region. Beginner places just one;
    /// the other levels place two.
    var starsPerUnit: Int { self == .beginner ? 1 : 2 }

    /// The next harder level, if any (used by the "step up" prompt).
    var harder: Difficulty? {
        switch self {
        case .beginner: return .easy
        case .easy:     return .medium
        case .medium:   return .hard
        case .hard:     return .expert
        case .expert:   return nil
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

    /// The English indefinite article for the singular noun — "an" before a vowel
    /// sound, else "a". We treat a/e/i/o-initial nouns as vowel sounds; "u" words like
    /// "unicorn" read as "a unicorn", so they stay "a". (English-only nicety; other
    /// languages carry their own article in the translated strings.)
    var article: String {
        let vowels: Set<Character> = ["a", "e", "i", "o"]
        return vowels.contains(noun.first ?? " ") ? "an" : "a"
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
