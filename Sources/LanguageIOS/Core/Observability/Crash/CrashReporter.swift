import Foundation

/// Provider-agnostic crash/diagnostics seam. Default impl persists a breadcrumb ring
/// buffer and logs MetricKit crash diagnostics on the next launch. A real SDK
/// (Sentry/Crashlytics) conforms to this later for live crash capture.
public protocol CrashReporter: AnyObject {
    func recordBreadcrumb(_ message: String, category: LogCategory)
    func setUserId(_ id: String?)
    func ingest(diagnostics: [String])
}

public final class NoopCrashReporter: CrashReporter {
    public init() {}
    public func recordBreadcrumb(_ message: String, category: LogCategory) {}
    public func setUserId(_ id: String?) {}
    public func ingest(diagnostics: [String]) {}
}

/// Persists a rolling breadcrumb trail to the key-value store and logs any crash
/// diagnostics handed to it (by `MetricKitReporter` on iOS).
public final class BreadcrumbCrashReporter: CrashReporter {
    private let store: KeyValueStore
    private let logger: AppLogging
    private let maxBreadcrumbs = 50
    private let lock = NSLock()

    public init(store: KeyValueStore, logger: AppLogging) {
        self.store = store
        self.logger = logger
        let previous = loadBreadcrumbs()
        if !previous.isEmpty {
            logger.info("loaded \(previous.count) breadcrumb(s) from previous session", category: .app)
        }
    }

    public func recordBreadcrumb(_ message: String, category: LogCategory) {
        lock.lock()
        defer { lock.unlock() }
        var crumbs = loadBreadcrumbs()
        crumbs.append("[\(category.rawValue)] \(message)")
        if crumbs.count > maxBreadcrumbs {
            crumbs.removeFirst(crumbs.count - maxBreadcrumbs)
        }
        if let data = try? JSONEncoder().encode(crumbs) {
            store.set(data, forKey: PersistenceSchema.crashBreadcrumbsKey)
        }
    }

    public func setUserId(_ id: String?) {
        logger.debug("crash userId=\(id ?? "nil")", category: .app)
    }

    public func ingest(diagnostics: [String]) {
        guard !diagnostics.isEmpty else { return }
        for diagnostic in diagnostics {
            logger.error("crash diagnostic: \(diagnostic)", category: .app)
        }
    }

    private func loadBreadcrumbs() -> [String] {
        guard let data = store.data(forKey: PersistenceSchema.crashBreadcrumbsKey),
              let crumbs = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return crumbs
    }
}
