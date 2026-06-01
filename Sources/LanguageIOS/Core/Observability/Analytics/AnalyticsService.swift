import Foundation

/// A single analytics event. Params are `String` keyed/valued so the model stays
/// `Equatable` (assertable in tests) and portable to any provider.
public struct AnalyticsEvent: Equatable {
    public let name: String
    public let params: [String: String]

    public init(name: String, params: [String: String] = [:]) {
        self.name = name
        self.params = params
    }
}

/// Provider-agnostic analytics seam. Default implementations are console/no-op; a
/// third-party adapter (Firebase/Amplitude/…) conforms to this and is added to the
/// `MultiplexAnalyticsService` in `AppEnvironment.live` — no call-site changes.
public protocol AnalyticsService: AnyObject {
    func track(_ event: AnalyticsEvent)
    func identify(userId: String?)
    func setUserProperty(_ value: String?, for key: String)
}
