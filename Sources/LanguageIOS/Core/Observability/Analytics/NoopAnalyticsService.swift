import Foundation

/// Discards all events. Used in previews and tests that don't assert analytics.
public final class NoopAnalyticsService: AnalyticsService {
    public init() {}
    public func track(_ event: AnalyticsEvent) {}
    public func identify(userId: String?) {}
    public func setUserProperty(_ value: String?, for key: String) {}
}
