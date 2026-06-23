import CoreHaptics

/// Plays a rich, ~3-second celebratory haptic when a puzzle is solved.
///
/// SwiftUI's `.sensoryFeedback` can only fire fixed, uniform taps, which read as a
/// flat string of identical thuds. Core Haptics lets us build the sensation the win
/// deserves: a long, swelling *whoosh* — like confetti sweeping past you — with dozens
/// of light, randomly-placed flecks sprinkled on top, each one a single piece of
/// confetti brushing by. Devices without a haptic engine (e.g. iPad) simply no-op, so
/// the falling-cherry confetti still plays on its own.
@MainActor
final class CelebrationHaptics {
    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    init() {
        guard supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
        // The system may stop the engine (e.g. after an interruption); restart it so
        // the next win still buzzes.
        engine?.resetHandler = { [weak self] in
            try? self?.engine?.start()
        }
    }

    /// Fires the celebration pattern once. Safe to call on any device; failures are
    /// swallowed because haptics are a non-essential flourish.
    func play() {
        guard supportsHaptics, let engine else { return }
        do {
            try engine.start()
            let player = try engine.makePlayer(with: Self.makePattern())
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are decorative — never let a failure disrupt the win.
        }
    }

    /// A long, swelling continuous rumble overlaid with many short transient flecks at
    /// random times and strengths, so the win feels like confetti brushing past.
    private static func makePattern() throws -> CHHapticPattern {
        let total = 3.0
        var events: [CHHapticEvent] = []

        // The sweep: one continuous event spanning the whole celebration. Its intensity
        // and sharpness are shaped by the parameter curves below so it swells in, then
        // rustles brighter as it fades.
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0,
            duration: total))

        // An opening pop the instant the board is solved.
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
            ],
            relativeTime: 0))

        // Individual flecks of confetti, sprinkled across the fall at random.
        for _ in 0..<28 {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity,
                                           value: Float.random(in: 0.25...0.9)),
                    CHHapticEventParameter(parameterID: .hapticSharpness,
                                           value: Float.random(in: 0.3...0.9))
                ],
                relativeTime: Double.random(in: 0.05...(total - 0.2))))
        }

        // Swell the sweep up fast, hold, then let it trail away.
        let intensityCurve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: 0.2),
                CHHapticParameterCurve.ControlPoint(relativeTime: 0.4, value: 1.0),
                CHHapticParameterCurve.ControlPoint(relativeTime: 1.6, value: 0.7),
                CHHapticParameterCurve.ControlPoint(relativeTime: total, value: 0.0)
            ],
            relativeTime: 0)

        // Start soft and rounded, brighten as it rustles away.
        let sharpnessCurve = CHHapticParameterCurve(
            parameterID: .hapticSharpnessControl,
            controlPoints: [
                CHHapticParameterCurve.ControlPoint(relativeTime: 0, value: -0.3),
                CHHapticParameterCurve.ControlPoint(relativeTime: total, value: 0.5)
            ],
            relativeTime: 0)

        return try CHHapticPattern(events: events,
                                   parameterCurves: [intensityCurve, sharpnessCurve])
    }
}
