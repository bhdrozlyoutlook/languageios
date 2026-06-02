import Foundation

/// A granted purchase, applied to `EntitlementState` by the app layer (so the recognizer
/// and UI never touch StoreKit types).
public struct PurchaseGrant: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case premium(RenewalPeriod, expires: Date)
        case tokens(Int)
    }

    public let kind: Kind
    public let transactionID: String

    public init(kind: Kind, transactionID: String) {
        self.kind = kind
        self.transactionID = transactionID
    }
}

public enum PurchaseError: Error, Equatable, Sendable {
    case productUnavailable
    case notAllowed
    case verificationFailed
    case network
    case unknown
}

/// Result of a purchase/restore. `userCancelled` and `pending` (Ask-to-Buy) are first-class
/// so they never accidentally grant anything.
public enum PurchaseOutcome: Equatable, Sendable {
    case success([PurchaseGrant])
    case userCancelled
    case pending
    case failed(PurchaseError)
}

public struct SubscriptionStatus: Equatable, Sendable {
    public let period: RenewalPeriod
    public let expires: Date

    public init(period: RenewalPeriod, expires: Date) {
        self.period = period
        self.expires = expires
    }

    public func isActive(now: Date) -> Bool { now < expires }
}

/// Provider-agnostic purchases seam. `LocalPurchaseService` (grants instantly, no payment)
/// drives development now; a `StoreKit2PurchaseService` adapter plugs in later behind the
/// same protocol without touching any call site.
public protocol PurchaseService: AnyObject {
    func products() async -> [PurchaseProductInfo]
    func purchasePremium(period: RenewalPeriod, now: Date) async -> PurchaseOutcome
    func buyTokens(pack: TokenPack, now: Date) async -> PurchaseOutcome
    func restore(now: Date) async -> PurchaseOutcome
    func subscriptionStatus(now: Date) async -> SubscriptionStatus?
}

public extension PurchaseService {
    func purchasePremium(period: RenewalPeriod) async -> PurchaseOutcome {
        await purchasePremium(period: period, now: Date())
    }
    func buyTokens(pack: TokenPack) async -> PurchaseOutcome {
        await buyTokens(pack: pack, now: Date())
    }
    func restore() async -> PurchaseOutcome { await restore(now: Date()) }
    func subscriptionStatus() async -> SubscriptionStatus? { await subscriptionStatus(now: Date()) }
}

/// No-op service for previews/tests that don't assert purchase side effects.
public final class NoopPurchaseService: PurchaseService {
    public init() {}
    public func products() async -> [PurchaseProductInfo] { PurchaseProductInfo.placeholderCatalog() }
    public func purchasePremium(period: RenewalPeriod, now: Date) async -> PurchaseOutcome { .success([]) }
    public func buyTokens(pack: TokenPack, now: Date) async -> PurchaseOutcome { .success([]) }
    public func restore(now: Date) async -> PurchaseOutcome { .success([]) }
    public func subscriptionStatus(now: Date) async -> SubscriptionStatus? { nil }
}
