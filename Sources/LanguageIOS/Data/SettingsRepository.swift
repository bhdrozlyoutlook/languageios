import Foundation

/// Lightweight app settings: whether onboarding is done and the last chosen language.
public protocol SettingsRepository: AnyObject {
    var hasCompletedOnboarding: Bool { get }
    func setOnboardingCompleted(_ value: Bool) throws

    var lastTargetLanguage: TargetLanguage? { get }
    func setLastTargetLanguage(_ language: TargetLanguage?) throws
}

struct SettingsBlob: Codable, Equatable {
    var hasCompletedOnboarding: Bool
    var lastTargetLanguageRaw: String?

    init(hasCompletedOnboarding: Bool = false, lastTargetLanguageRaw: String? = nil) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.lastTargetLanguageRaw = lastTargetLanguageRaw
    }
}

public final class UserDefaultsSettingsRepository: SettingsRepository {
    private let store: KeyValueStore
    private let logger: AppLogging

    public init(store: KeyValueStore, logger: AppLogging) {
        self.store = store
        self.logger = logger
    }

    public var hasCompletedOnboarding: Bool {
        load().hasCompletedOnboarding
    }

    public func setOnboardingCompleted(_ value: Bool) throws {
        var blob = load()
        blob.hasCompletedOnboarding = value
        try persist(blob)
    }

    public var lastTargetLanguage: TargetLanguage? {
        load().lastTargetLanguageRaw.flatMap(TargetLanguage.init(rawValue:))
    }

    public func setLastTargetLanguage(_ language: TargetLanguage?) throws {
        var blob = load()
        blob.lastTargetLanguageRaw = language?.rawValue
        try persist(blob)
    }

    private func load() -> SettingsBlob {
        guard let data = store.data(forKey: PersistenceSchema.settingsKey) else { return SettingsBlob() }
        do {
            return try JSONDecoder().decode(Versioned<SettingsBlob>.self, from: data).payload
        } catch {
            logger.error("settings decode failed: \(error)", category: .persistence)
            return SettingsBlob()
        }
    }

    private func persist(_ blob: SettingsBlob) throws {
        do {
            let data = try JSONEncoder().encode(Versioned(payload: blob))
            store.set(data, forKey: PersistenceSchema.settingsKey)
        } catch {
            logger.error("settings encode failed: \(error)", category: .persistence)
            throw AppError.persistenceWrite(key: PersistenceSchema.settingsKey)
        }
    }
}
