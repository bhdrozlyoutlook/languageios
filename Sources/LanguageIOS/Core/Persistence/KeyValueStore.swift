import Foundation

/// Minimal abstraction over a binary key-value store. Lets repositories stay agnostic
/// of `UserDefaults` so a file/Keychain/remote-backed store can replace it later, and
/// so tests can use an in-memory implementation.
public protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    func removeObject(forKey key: String)
}

public final class UserDefaultsKeyValueStore: KeyValueStore {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    public func set(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    public func removeObject(forKey key: String) {
        defaults.removeObject(forKey: key)
    }
}

public final class InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func data(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[key]
    }

    public func set(_ data: Data?, forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = data
    }

    public func removeObject(forKey key: String) {
        lock.lock()
        defer { lock.unlock() }
        storage[key] = nil
    }
}
