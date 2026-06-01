import Foundation
#if canImport(os)
import os
#endif

/// A running performance span. Call `end()` once.
public protocol PerformanceInterval {
    func end()
}

/// Provider-agnostic performance tracing. Default impl emits `os_signpost` intervals
/// (visible in Instruments). Instrument transitions and one-time work only — never
/// per-frame hot paths.
public protocol PerformanceTracer: AnyObject {
    func beginInterval(_ name: StaticString) -> PerformanceInterval
}

public extension PerformanceTracer {
    /// Measures the duration of `work` as a single interval.
    func measure<T>(_ name: StaticString, _ work: () throws -> T) rethrows -> T {
        let interval = beginInterval(name)
        defer { interval.end() }
        return try work()
    }
}

public final class NoopPerformanceTracer: PerformanceTracer {
    public init() {}
    public func beginInterval(_ name: StaticString) -> PerformanceInterval { NoopInterval() }
    private struct NoopInterval: PerformanceInterval {
        func end() {}
    }
}

#if canImport(os)
public final class SignpostPerformanceTracer: PerformanceTracer {
    private let signposter: OSSignposter

    public init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.bhdrozly.languageios") {
        signposter = OSSignposter(subsystem: subsystem, category: "Performance")
    }

    public func beginInterval(_ name: StaticString) -> PerformanceInterval {
        let id = signposter.makeSignpostID()
        let state = signposter.beginInterval(name, id: id)
        return SignpostInterval(signposter: signposter, name: name, state: state)
    }

    private struct SignpostInterval: PerformanceInterval {
        let signposter: OSSignposter
        let name: StaticString
        let state: OSSignpostIntervalState
        func end() { signposter.endInterval(name, state) }
    }
}
#endif
