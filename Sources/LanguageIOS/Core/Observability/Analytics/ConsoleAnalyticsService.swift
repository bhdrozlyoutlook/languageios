import Foundation

/// Prints events through the app logger (so they appear in OSLog, not raw stdout).
/// The default analytics sink during development.
public final class ConsoleAnalyticsService: AnalyticsService {
    private let logger: AppLogging

    public init(logger: AppLogging) {
        self.logger = logger
    }

    public func track(_ event: AnalyticsEvent) {
        let suffix = event.params.isEmpty
            ? ""
            : " " + event.params.sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
        logger.info("📊 \(event.name)\(suffix)", category: .app)
    }

    public func identify(userId: String?) {
        logger.info("📊 identify userId=\(userId ?? "nil")", category: .app)
    }

    public func setUserProperty(_ value: String?, for key: String) {
        logger.info("📊 userProperty \(key)=\(value ?? "nil")", category: .app)
    }
}
