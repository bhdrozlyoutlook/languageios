import Foundation

/// Persists the user's captured-word collection: metadata via `KeyValueStore`, cutout
/// images via `ImageBlobStore`. Newest-first ordering is the storage invariant so the
/// collection screen can render groups without re-sorting.
public protocol CaptureRepository: AnyObject {
    func all() -> [CapturedObject]
    func add(_ object: CapturedObject, image: Data?)
    func image(forID id: String) -> Data?
    func remove(id: String)
    func clear()
}

public final class DefaultCaptureRepository: CaptureRepository {
    private let store: KeyValueStore
    private let blobs: ImageBlobStore
    private let logger: AppLogging?

    public init(store: KeyValueStore, blobs: ImageBlobStore, logger: AppLogging? = nil) {
        self.store = store
        self.blobs = blobs
        self.logger = logger
    }

    public func all() -> [CapturedObject] {
        guard let data = store.data(forKey: PersistenceSchema.capturedObjectsKey) else { return [] }
        do {
            return try JSONDecoder().decode(Versioned<[CapturedObject]>.self, from: data).payload
        } catch {
            logger?.error("captured objects decode failed: \(error)", category: .persistence)
            return []
        }
    }

    public func add(_ object: CapturedObject, image: Data?) {
        if let image { blobs.write(image, forID: object.id) }
        var items = all().filter { $0.id != object.id }
        items.insert(object, at: 0) // newest first
        persist(items)
    }

    public func image(forID id: String) -> Data? {
        blobs.read(forID: id)
    }

    public func remove(id: String) {
        blobs.delete(forID: id)
        persist(all().filter { $0.id != id })
    }

    public func clear() {
        blobs.deleteAll()
        store.removeObject(forKey: PersistenceSchema.capturedObjectsKey)
    }

    private func persist(_ items: [CapturedObject]) {
        do {
            let data = try JSONEncoder().encode(Versioned(schemaVersion: 1, payload: items))
            store.set(data, forKey: PersistenceSchema.capturedObjectsKey)
        } catch {
            logger?.error("captured objects encode failed: \(error)", category: .persistence)
        }
    }
}
