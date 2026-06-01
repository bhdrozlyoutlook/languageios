import Foundation

/// Fans every call out to multiple analytics services. The plug point for adding
/// third-party providers later: append their adapter to this list in `AppEnvironment`.
public final class MultiplexAnalyticsService: AnalyticsService {
    private let children: [AnalyticsService]

    public init(_ children: [AnalyticsService]) {
        self.children = children
    }

    public func track(_ event: AnalyticsEvent) {
        children.forEach { $0.track(event) }
    }

    public func identify(userId: String?) {
        children.forEach { $0.identify(userId: userId) }
    }

    public func setUserProperty(_ value: String?, for key: String) {
        children.forEach { $0.setUserProperty(value, for: key) }
    }
}
