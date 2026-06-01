import Foundation

/// Stores per-language learning progress.
public protocol ProgressRepository: AnyObject {
    func progress(for language: TargetLanguage) -> LearningProgress
    func allProgress() -> [String: LearningProgress]
    func save(_ progress: LearningProgress, for language: TargetLanguage) throws
    func reset(for language: TargetLanguage) throws
    func resetAll() throws
}

public final class UserDefaultsProgressRepository: ProgressRepository {
    private let store: KeyValueStore
    private let logger: AppLogging

    public init(store: KeyValueStore, logger: AppLogging) {
        self.store = store
        self.logger = logger
    }

    public func progress(for language: TargetLanguage) -> LearningProgress {
        load()[language.rawValue] ?? LearningProgress()
    }

    public func allProgress() -> [String: LearningProgress] {
        load()
    }

    public func save(_ progress: LearningProgress, for language: TargetLanguage) throws {
        var all = load()
        all[language.rawValue] = progress
        try persist(all)
    }

    public func reset(for language: TargetLanguage) throws {
        var all = load()
        all[language.rawValue] = LearningProgress()
        try persist(all)
    }

    public func resetAll() throws {
        try persist([:])
    }

    private func load() -> [String: LearningProgress] {
        guard let data = store.data(forKey: PersistenceSchema.progressKey) else { return [:] }
        do {
            return try JSONDecoder().decode(Versioned<[String: LearningProgress]>.self, from: data).payload
        } catch {
            logger.error("progress decode failed: \(error)", category: .persistence)
            return [:]
        }
    }

    private func persist(_ all: [String: LearningProgress]) throws {
        do {
            let data = try JSONEncoder().encode(Versioned(payload: all))
            store.set(data, forKey: PersistenceSchema.progressKey)
        } catch {
            logger.error("progress encode failed: \(error)", category: .persistence)
            throw AppError.persistenceWrite(key: PersistenceSchema.progressKey)
        }
    }
}
