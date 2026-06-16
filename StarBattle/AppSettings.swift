import SwiftUI

/// User-facing preferences, persisted with `@AppStorage`. These keys are read
/// directly by the views that need them (the board, the timer, the root color
/// scheme) so there is no separate settings object to thread through.
enum SettingsKey {
    static let pieceStyle = "pieceStyle"
    static let appearance = "appearance"
    static let hideTimer = "hideTimer"
    static let hasSeenOnboarding = "hasSeenOnboarding"
}

/// The glyph the player places on the board. The cherry is the default (and the
/// app icon); the rest are simple tintable alternatives.
enum PieceStyle: String, CaseIterable, Identifiable {
    case cherry, star, queen, diamond, heart

    var id: String { rawValue }

    /// Short name shown in Settings.
    var label: String {
        switch self {
        case .cherry: return "Cherry"
        case .star:   return "Star"
        case .queen:  return "Queen"
        case .diamond: return "Diamond"
        case .heart:  return "Heart"
        }
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
