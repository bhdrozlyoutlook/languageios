import Foundation

/// Stores the global gamification state (XP, streak, stars, hearts).
public protocol GamificationRepository: AnyObject {
    func load() -> GamificationState
    func save(_ state: GamificationState) throws
    func clear() throws
}

public final class UserDefaultsGamificationRepository: GamificationRepository {
    private let store: KeyValueStore
    private let logger: AppLogging

    public init(store: KeyValueStore, logger: AppLogging) {
        self.store = store
        self.logger = logger
    }

    public func load() -> GamificationState {
        guard let data = store.data(forKey: PersistenceSchema.gamificationKey) else {
            return GamificationState()
        }
        do {
            return try JSONDecoder().decode(Versioned<GamificationState>.self, from: data).payload
        } catch {
            logger.error("gamification decode failed: \(error)", category: .persistence)
            return GamificationState()
        }
    }

    public func save(_ state: GamificationState) throws {
        do {
            let data = try JSONEncoder().encode(Versioned(payload: state))
            store.set(data, forKey: PersistenceSchema.gamificationKey)
        } catch {
            logger.error("gamification encode failed: \(error)", category: .persistence)
            throw AppError.persistenceWrite(key: PersistenceSchema.gamificationKey)
        }
    }

    public func clear() throws {
        store.removeObject(forKey: PersistenceSchema.gamificationKey)
    }
}
