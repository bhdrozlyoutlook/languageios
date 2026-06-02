import Foundation

/// Stores the local entitlement state (tier, period usage, token balance). Backed today by
/// `UserDefaults` via `KeyValueStore`; a synced/remote store can replace it later.
public protocol EntitlementRepository: AnyObject {
    func load() -> EntitlementState
    func save(_ state: EntitlementState) throws
    func clear() throws
}

public final class UserDefaultsEntitlementRepository: EntitlementRepository {
    private let store: KeyValueStore
    private let logger: AppLogging

    public init(store: KeyValueStore, logger: AppLogging) {
        self.store = store
        self.logger = logger
    }

    public func load() -> EntitlementState {
        guard let data = store.data(forKey: PersistenceSchema.entitlementKey) else {
            return EntitlementState()
        }
        do {
            return try JSONDecoder().decode(Versioned<EntitlementState>.self, from: data).payload
        } catch {
            logger.error("entitlement decode failed: \(error)", category: .persistence)
            return EntitlementState()
        }
    }

    public func save(_ state: EntitlementState) throws {
        do {
            let data = try JSONEncoder().encode(Versioned(payload: state))
            store.set(data, forKey: PersistenceSchema.entitlementKey)
        } catch {
            logger.error("entitlement encode failed: \(error)", category: .persistence)
            throw AppError.persistenceWrite(key: PersistenceSchema.entitlementKey)
        }
    }

    public func clear() throws {
        store.removeObject(forKey: PersistenceSchema.entitlementKey)
    }
}
