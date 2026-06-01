import Foundation

/// Stores the full user profile. Backed today by `UserDefaults`; a remote/synced
/// implementation can replace it later without changing call sites.
public protocol ProfileRepository: AnyObject {
    func loadProfile() -> UserProfile?
    func save(_ profile: UserProfile) throws
    func clear() throws
}

public final class UserDefaultsProfileRepository: ProfileRepository {
    private let store: KeyValueStore
    private let logger: AppLogging

    public init(store: KeyValueStore, logger: AppLogging) {
        self.store = store
        self.logger = logger
    }

    public func loadProfile() -> UserProfile? {
        guard let data = store.data(forKey: PersistenceSchema.profileKey) else { return nil }
        do {
            return try JSONDecoder().decode(Versioned<UserProfile>.self, from: data).payload
        } catch {
            logger.error("profile decode failed: \(error)", category: .persistence)
            return nil
        }
    }

    public func save(_ profile: UserProfile) throws {
        do {
            let data = try JSONEncoder().encode(Versioned(payload: profile))
            store.set(data, forKey: PersistenceSchema.profileKey)
        } catch {
            logger.error("profile encode failed: \(error)", category: .persistence)
            throw AppError.persistenceWrite(key: PersistenceSchema.profileKey)
        }
    }

    public func clear() throws {
        store.removeObject(forKey: PersistenceSchema.profileKey)
    }
}
