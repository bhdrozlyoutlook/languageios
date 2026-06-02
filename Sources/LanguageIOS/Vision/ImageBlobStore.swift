import Foundation

/// Stores binary image blobs keyed by id. Cutout PNGs can grow unbounded as the user
/// captures words, so they live on disk (not in `UserDefaults`); tests use the in-memory
/// variant. Kept separate from `KeyValueStore` so the metadata store stays small.
public protocol ImageBlobStore: AnyObject {
    func write(_ data: Data, forID id: String)
    func read(forID id: String) -> Data?
    func delete(forID id: String)
    func deleteAll()
}

public final class FileImageBlobStore: ImageBlobStore {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// Default location: Application Support/CapturedObjects.
    public convenience init?(fileManager: FileManager = .default) {
        guard let base = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) else { return nil }
        self.init(directory: base.appendingPathComponent("CapturedObjects", isDirectory: true), fileManager: fileManager)
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("png")
    }

    public func write(_ data: Data, forID id: String) {
        try? data.write(to: url(for: id), options: .atomic)
    }

    public func read(forID id: String) -> Data? {
        try? Data(contentsOf: url(for: id))
    }

    public func delete(forID id: String) {
        try? fileManager.removeItem(at: url(for: id))
    }

    public func deleteAll() {
        guard let contents = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return
        }
        for url in contents { try? fileManager.removeItem(at: url) }
    }
}

public final class InMemoryImageBlobStore: ImageBlobStore {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func write(_ data: Data, forID id: String) {
        lock.lock(); defer { lock.unlock() }
        storage[id] = data
    }

    public func read(forID id: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        return storage[id]
    }

    public func delete(forID id: String) {
        lock.lock(); defer { lock.unlock() }
        storage[id] = nil
    }

    public func deleteAll() {
        lock.lock(); defer { lock.unlock() }
        storage.removeAll()
    }
}
