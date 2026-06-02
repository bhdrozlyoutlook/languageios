import Foundation

/// Persisted record of local "purchases" (no real payment): the current fake subscription
/// and a monotonic transaction counter. Mirrors the gamification persistence shape.
struct LocalPurchaseLedger: Codable {
    var subscriptionPeriodRaw: String?
    var subscriptionExpires: Date?
    var lastTransactionSeq: Int

    init(subscriptionPeriodRaw: String? = nil, subscriptionExpires: Date? = nil, lastTransactionSeq: Int = 0) {
        self.subscriptionPeriodRaw = subscriptionPeriodRaw
        self.subscriptionExpires = subscriptionExpires
        self.lastTransactionSeq = lastTransactionSeq
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subscriptionPeriodRaw = try container.decodeIfPresent(String.self, forKey: .subscriptionPeriodRaw)
        subscriptionExpires = try container.decodeIfPresent(Date.self, forKey: .subscriptionExpires)
        lastTransactionSeq = try container.decodeIfPresent(Int.self, forKey: .lastTransactionSeq) ?? 0
    }
}

/// Development purchases: grants premium/tokens instantly (no payment) and persists a ledger
/// so a restored/active subscription survives relaunch. Swapped for `StoreKit2PurchaseService`
/// later via `AppEnvironment.makePurchaseService` — no call site changes.
public final class LocalPurchaseService: PurchaseService {
    private let store: KeyValueStore
    private let logger: AppLogging
    private let calendar: Calendar
    private let lock = NSLock()

    public init(store: KeyValueStore, logger: AppLogging, calendar: Calendar = .current) {
        self.store = store
        self.logger = logger
        self.calendar = calendar
    }

    public func products() async -> [PurchaseProductInfo] {
        PurchaseProductInfo.placeholderCatalog()
    }

    public func purchasePremium(period: RenewalPeriod, now: Date) async -> PurchaseOutcome {
        lock.lock(); defer { lock.unlock() }
        var ledger = loadLedger()
        let expires = expiry(for: period, from: now)
        ledger.subscriptionPeriodRaw = period.rawValue
        ledger.subscriptionExpires = expires
        ledger.lastTransactionSeq += 1
        let seq = ledger.lastTransactionSeq
        saveLedger(ledger)
        return .success([PurchaseGrant(kind: .premium(period, expires: expires), transactionID: "local-\(seq)")])
    }

    public func buyTokens(pack: TokenPack, now: Date) async -> PurchaseOutcome {
        lock.lock(); defer { lock.unlock() }
        var ledger = loadLedger()
        ledger.lastTransactionSeq += 1
        let seq = ledger.lastTransactionSeq
        saveLedger(ledger)
        return .success([PurchaseGrant(kind: .tokens(pack.tokenCount), transactionID: "local-\(seq)")])
    }

    public func restore(now: Date) async -> PurchaseOutcome {
        lock.lock(); defer { lock.unlock() }
        guard let status = status(from: loadLedger()), status.isActive(now: now) else {
            return .success([])
        }
        return .success([PurchaseGrant(
            kind: .premium(status.period, expires: status.expires),
            transactionID: "local-restore"
        )])
    }

    public func subscriptionStatus(now: Date) async -> SubscriptionStatus? {
        lock.lock(); defer { lock.unlock() }
        guard let status = status(from: loadLedger()), status.isActive(now: now) else { return nil }
        return status
    }

    // MARK: Ledger

    private func expiry(for period: RenewalPeriod, from now: Date) -> Date {
        switch period {
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 86400)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: now) ?? now.addingTimeInterval(30 * 86400)
        }
    }

    private func status(from ledger: LocalPurchaseLedger) -> SubscriptionStatus? {
        guard let raw = ledger.subscriptionPeriodRaw,
              let period = RenewalPeriod(rawValue: raw),
              let expires = ledger.subscriptionExpires else { return nil }
        return SubscriptionStatus(period: period, expires: expires)
    }

    private func loadLedger() -> LocalPurchaseLedger {
        guard let data = store.data(forKey: PersistenceSchema.purchaseLedgerKey) else {
            return LocalPurchaseLedger()
        }
        do {
            return try JSONDecoder().decode(Versioned<LocalPurchaseLedger>.self, from: data).payload
        } catch {
            logger.error("purchase ledger decode failed: \(error)", category: .persistence)
            return LocalPurchaseLedger()
        }
    }

    private func saveLedger(_ ledger: LocalPurchaseLedger) {
        do {
            let data = try JSONEncoder().encode(Versioned(payload: ledger))
            store.set(data, forKey: PersistenceSchema.purchaseLedgerKey)
        } catch {
            logger.error("purchase ledger encode failed: \(error)", category: .persistence)
        }
    }
}
