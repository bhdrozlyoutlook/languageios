import SwiftUI

/// Palette for the learning-path map. Reuses `OnboardingTheme` ink/paper/accents so
/// the map feels like the same product as onboarding, and adds sea + land tones.
enum MapTheme {
    // Sea background gradient.
    static let seaTop = Color(red: 0.66, green: 0.86, blue: 0.92)
    static let seaBottom = Color(red: 0.36, green: 0.66, blue: 0.80)
    static let seaFoam = Color(red: 0.82, green: 0.93, blue: 0.96)

    // Landmasses.
    static let landActive = Color(red: 0.92, green: 0.84, blue: 0.58)
    static let landActiveEdge = Color(red: 0.74, green: 0.62, blue: 0.36)
    static let landCompleted = Color(red: 0.62, green: 0.80, blue: 0.52)
    static let landCompletedEdge = Color(red: 0.40, green: 0.62, blue: 0.34)
    static let landLocked = Color(red: 0.68, green: 0.74, blue: 0.76)
    static let landLockedEdge = Color(red: 0.52, green: 0.58, blue: 0.60)

    // The winding trail between stops.
    static let trailDim = Color.white.opacity(0.45)
    static let trailDone = Color.white.opacity(0.95)

    // Shared accents from onboarding.
    static let ink = OnboardingTheme.ink
    static let paper = OnboardingTheme.paper
    static let teal = OnboardingTheme.teal
    static let coral = OnboardingTheme.coral
}
