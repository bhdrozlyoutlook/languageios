import Foundation
#if canImport(MetricKit) && os(iOS)
import MetricKit

/// Subscribes to MetricKit: logs performance metric payloads and forwards crash/hang
/// diagnostics to the `CrashReporter`. iOS-only; the system delivers payloads in the
/// background (≈ once per day), so this is observability, not a live crash pipeline.
public final class MetricKitReporter: NSObject, MXMetricManagerSubscriber {
    private let logger: AppLogging
    private let crashReporter: CrashReporter

    /// Keeps subscribers alive for the app's lifetime.
    private static var retained: [MetricKitReporter] = []

    @discardableResult
    public static func start(logger: AppLogging, crashReporter: CrashReporter) -> MetricKitReporter {
        let reporter = MetricKitReporter(logger: logger, crashReporter: crashReporter)
        MXMetricManager.shared.add(reporter)
        retained.append(reporter)
        return reporter
    }

    private init(logger: AppLogging, crashReporter: CrashReporter) {
        self.logger = logger
        self.crashReporter = crashReporter
    }

    public func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            if let json = String(data: payload.jsonRepresentation(), encoding: .utf8) {
                logger.info("MetricKit metrics: \(json)", category: .performance)
            }
        }
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let descriptions = payloads.compactMap { String(data: $0.jsonRepresentation(), encoding: .utf8) }
        crashReporter.ingest(diagnostics: descriptions)
    }
}
#endif
