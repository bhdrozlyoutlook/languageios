import Foundation

/// One-time migration from the legacy single-blob `AppStore` state
/// (`PersistenceSchema.legacyAppStateKey`) to the versioned v2 stores. Lossless:
/// existing users keep their target language and per-language progress; new full-profile
/// fields simply start `nil`. The legacy blob is left in place as a rollback safety net.
public final class StoreMigrator {
    private let store: KeyValueStore
    private let logger: AppLogging

    public init(store: KeyValueStore, logger: AppLogging) {
        self.store = store
        self.logger = logger
    }

    /// Mirrors the old `AppStore.PersistedState` shape for decoding only.
    private struct LegacyAppState: Codable {
        var hasCompletedOnboarding: Bool
        var targetLanguageRaw: String?
        var progress: [String: LearningProgress]
    }

    public func migrateIfNeeded() {
        // Already migrated if any v2 store exists.
        if store.data(forKey: PersistenceSchema.settingsKey) != nil
            || store.data(forKey: PersistenceSchema.progressKey) != nil
            || store.data(forKey: PersistenceSchema.profileKey) != nil {
            return
        }

        guard let data = store.data(forKey: PersistenceSchema.legacyAppStateKey) else {
            return // Fresh install — nothing to migrate.
        }
        guard let legacy = try? JSONDecoder().decode(LegacyAppState.self, from: data) else {
            logger.error("legacy app-state decode failed during migration", category: .persistence)
            return
        }

        let encoder = JSONEncoder()
        let settings = SettingsBlob(
            hasCompletedOnboarding: legacy.hasCompletedOnboarding,
            lastTargetLanguageRaw: legacy.targetLanguageRaw
        )
        if let encoded = try? encoder.encode(Versioned(payload: settings)) {
            store.set(encoded, forKey: PersistenceSchema.settingsKey)
        }
        if let encoded = try? encoder.encode(Versioned(payload: legacy.progress)) {
            store.set(encoded, forKey: PersistenceSchema.progressKey)
        }
        let profile = UserProfile(targetLanguage: legacy.targetLanguageRaw.flatMap(TargetLanguage.init(rawValue:)))
        if let encoded = try? encoder.encode(Versioned(payload: profile)) {
            store.set(encoded, forKey: PersistenceSchema.profileKey)
        }

        logger.info("migrated legacy app-state v1 → v2 (onboarded=\(legacy.hasCompletedOnboarding))", category: .persistence)
    }
}
