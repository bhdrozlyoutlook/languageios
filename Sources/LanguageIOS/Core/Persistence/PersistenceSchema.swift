import Foundation

/// Storage keys and schema version for persisted state. Each v2 store is self-describing
/// via the `Versioned` wrapper so future migrations can branch on `schemaVersion`.
public enum PersistenceSchema {
    public static let profileKey = "language-ios.profile.v2"
    public static let progressKey = "language-ios.progress.v2"
    public static let settingsKey = "language-ios.settings.v2"
    public static let gamificationKey = "language-ios.gamification.v2"
    public static let crashBreadcrumbsKey = "language-ios.crash-breadcrumbs.v1"
    public static let capturedObjectsKey = "language-ios.captured-objects.v1"

    /// The single JSON blob written by the pre-repository `AppStore`. Source for migration.
    public static let legacyAppStateKey = "language-ios.app-state.v1"

    public static let currentVersion = 2
}

/// A versioned, self-describing persistence envelope.
public struct Versioned<Payload: Codable>: Codable {
    public var schemaVersion: Int
    public var payload: Payload

    public init(schemaVersion: Int = PersistenceSchema.currentVersion, payload: Payload) {
        self.schemaVersion = schemaVersion
        self.payload = payload
    }
}
