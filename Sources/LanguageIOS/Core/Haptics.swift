import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Thin wrapper over haptic feedback. No-ops on platforms without UIKit so the package
/// still compiles for the macOS test host.
public enum Haptics {
    public static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    public static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }

    public static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}
