import Foundation
#if canImport(os)
import os
#endif

/// Logical channels for app logging. Each maps to an OSLog category so logs can be
/// filtered by subsystem+category in Console.app / Instruments.
public enum LogCategory: String {
    case app
    case onboarding
    case persistence
    case map
    case performance
}

/// Provider-agnostic logging seam. The default `OSLogLogger` routes to the unified
/// logging system; a third-party logger can conform later without touching call sites.
public protocol AppLogging: AnyObject {
    func debug(_ message: String, category: LogCategory)
    func info(_ message: String, category: LogCategory)
    func error(_ message: String, category: LogCategory)
}

public final class NoopLogger: AppLogging {
    public init() {}
    public func debug(_ message: String, category: LogCategory) {}
    public func info(_ message: String, category: LogCategory) {}
    public func error(_ message: String, category: LogCategory) {}
}

/// Default logger backed by `os.Logger` (one cached `Logger` per category). Falls back
/// to `print` on platforms without `os` so the package still compiles for test hosts.
public final class OSLogLogger: AppLogging {
    private let subsystem: String
    #if canImport(os)
    private var loggers: [LogCategory: Logger] = [:]
    private let lock = NSLock()
    #endif

    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.bhdrozly.languageios") {
        self.subsystem = subsystem
    }

    #if canImport(os)
    private func logger(for category: LogCategory) -> Logger {
        lock.lock()
        defer { lock.unlock() }
        if let existing = loggers[category] { return existing }
        let created = Logger(subsystem: subsystem, category: category.rawValue)
        loggers[category] = created
        return created
    }
    #endif

    public func debug(_ message: String, category: LogCategory) {
        #if canImport(os)
        logger(for: category).debug("\(message, privacy: .public)")
        #else
        print("[\(category.rawValue)] DEBUG: \(message)")
        #endif
    }

    public func info(_ message: String, category: LogCategory) {
        #if canImport(os)
        logger(for: category).info("\(message, privacy: .public)")
        #else
        print("[\(category.rawValue)] INFO: \(message)")
        #endif
    }

    public func error(_ message: String, category: LogCategory) {
        #if canImport(os)
        logger(for: category).error("\(message, privacy: .public)")
        #else
        print("[\(category.rawValue)] ERROR: \(message)")
        #endif
    }
}
