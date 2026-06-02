import XCTest
@testable import LanguageIOS

final class EntitlementTests: XCTestCase {

    private func cal() -> Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal().date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    // MARK: Consume / refund

    func testConsumeSpendsFreeQuotaBeforeTokens() {
        let c = cal(); let now = date(2026, 1, 5) // Monday
        var s = EntitlementState(tier: .premium, period: .weekly, tokenBalance: 2)
        for _ in 0..<10 {
            XCTAssertEqual(s.consumeAnalysis(now: now, calendar: c), .freeQuota)
        }
        XCTAssertEqual(s.consumeAnalysis(now: now, calendar: c), .token) // 11th -> token
        XCTAssertEqual(s.tokenBalance, 1)
        XCTAssertEqual(s.consumeAnalysis(now: now, calendar: c), .token)
        XCTAssertEqual(s.tokenBalance, 0)
        XCTAssertNil(s.consumeAnalysis(now: now, calendar: c)) // exhausted
    }

    func testFreemiumConsumesTokenOrNilWithoutSpendingMissingQuota() {
        let c = cal(); let now = date(2026, 1, 5)
        var withToken = EntitlementState(tier: .freemium, tokenBalance: 1)
        XCTAssertEqual(withToken.consumeAnalysis(now: now, calendar: c), .token)
        XCTAssertNil(withToken.consumeAnalysis(now: now, calendar: c))

        var empty = EntitlementState(tier: .freemium)
        XCTAssertNil(empty.consumeAnalysis(now: now, calendar: c))
        XCTAssertEqual(empty.freeAnalysesUsed, 0) // nothing spent
        XCTAssertEqual(empty.tokenBalance, 0)
    }

    func testRefundRestoresChargedUnit() {
        let c = cal(); let now = date(2026, 1, 5)
        var s = EntitlementState(tier: .premium, tokenBalance: 1)
        let free = s.consumeAnalysis(now: now, calendar: c)!
        XCTAssertEqual(free, .freeQuota)
        s.refundAnalysis(free)
        XCTAssertEqual(s.freeAnalysesRemaining(now: now, calendar: c), 10)

        // Spend the 10 free, then a token; refunding the token credits it back.
        for _ in 0..<10 { _ = s.consumeAnalysis(now: now, calendar: c) }
        let token = s.consumeAnalysis(now: now, calendar: c)!
        XCTAssertEqual(token, .token)
        XCTAssertEqual(s.tokenBalance, 0)
        s.refundAnalysis(token)
        XCTAssertEqual(s.tokenBalance, 1)
    }

    func testFreeRefundClampsAtZero() {
        var s = EntitlementState(tier: .premium)
        s.refundAnalysis(.freeQuota) // nothing spent yet
        XCTAssertEqual(s.freeAnalysesUsed, 0)
    }

    // MARK: Period rollover

    func testWeeklyRolloverRestoresFreeQuotaButKeepsTokens() {
        let c = cal()
        var s = EntitlementState(tier: .premium, period: .weekly, freeAnalysesUsed: 10, tokenBalance: 3)
        s.periodAnchor = s.periodStart(containing: date(2026, 1, 5), calendar: c) // week of Jan 5
        XCTAssertEqual(s.freeAnalysesRemaining(now: date(2026, 1, 5), calendar: c), 0)
        XCTAssertEqual(s.freeAnalysesRemaining(now: date(2026, 1, 12), calendar: c), 10) // next week
        XCTAssertEqual(s.tokenBalance, 3)
    }

    func testMonthlyRolloverUsesCalendarMonthNotThirtyDays() {
        let c = cal()
        var s = EntitlementState(tier: .premium, period: .monthly, freeAnalysesUsed: 10)
        s.periodAnchor = date(2026, 1, 31)
        XCTAssertTrue(s.needsReset(now: date(2026, 2, 1), calendar: c))   // Jan 31 -> Feb 1 rolls
        s.periodAnchor = date(2026, 2, 1)
        XCTAssertFalse(s.needsReset(now: date(2026, 2, 28), calendar: c)) // same calendar month
    }

    func testISOWeekYearBoundaryIsSamePeriod() {
        let c = cal()
        var s = EntitlementState(tier: .premium, period: .weekly)
        s.periodAnchor = date(2025, 12, 30) // Tue, ISO week 1 of 2026
        XCTAssertFalse(s.needsReset(now: date(2026, 1, 1), calendar: c)) // Thu, same ISO week
    }

    func testPureReadsDoNotMutateAcrossRollover() {
        let c = cal()
        var s = EntitlementState(tier: .premium, period: .weekly, freeAnalysesUsed: 10)
        s.periodAnchor = s.periodStart(containing: date(2026, 1, 5), calendar: c)
        let snapshot = s
        _ = s.freeAnalysesRemaining(now: date(2026, 1, 19), calendar: c)
        _ = s.canStartAnalysis(now: date(2026, 1, 19), calendar: c)
        XCTAssertEqual(s, snapshot) // reads never commit the reset
    }

    func testResetIfNeededIsIdempotentWithinPeriod() {
        let c = cal()
        var s = EntitlementState(tier: .premium, period: .weekly, freeAnalysesUsed: 5)
        s.periodAnchor = s.periodStart(containing: date(2026, 1, 5), calendar: c)
        s.resetIfNeeded(now: date(2026, 1, 7), calendar: c)
        let once = s
        s.resetIfNeeded(now: date(2026, 1, 7), calendar: c)
        XCTAssertEqual(s, once)
    }

    func testLazyAnchorReportsFullQuotaThenBindsOnConsume() {
        let c = cal(); let now = date(2026, 1, 5)
        var s = EntitlementState(tier: .premium) // anchor nil
        XCTAssertNil(s.periodAnchor)
        XCTAssertEqual(s.freeAnalysesRemaining(now: now, calendar: c), 10)
        XCTAssertEqual(s.consumeAnalysis(now: now, calendar: c), .freeQuota)
        XCTAssertNotNil(s.periodAnchor)
    }

    func testTokensCarryOverAcrossMultipleRollovers() {
        let c = cal()
        var s = EntitlementState(tier: .premium, period: .weekly, tokenBalance: 5)
        s.periodAnchor = s.periodStart(containing: date(2026, 1, 5), calendar: c)
        _ = s.consumeAnalysis(now: date(2026, 1, 5), calendar: c)
        _ = s.freeAnalysesRemaining(now: date(2026, 2, 2), calendar: c) // 4 weeks later
        _ = s.consumeAnalysis(now: date(2026, 3, 2), calendar: c)
        XCTAssertEqual(s.tokenBalance, 5) // only free quota was spent
    }

    func testSetTierStartsFreshPeriodAndKeepsTokens() {
        let c = cal(); let now = date(2026, 1, 5)
        var s = EntitlementState(tier: .freemium, tokenBalance: 3)
        s.setTier(.premium, period: .weekly, now: now, calendar: c)
        XCTAssertEqual(s.freeAnalysesRemaining(now: now, calendar: c), 10)
        XCTAssertEqual(s.tokenBalance, 3)
        s.setTier(.freemium, period: .weekly, now: now, calendar: c)
        XCTAssertEqual(s.freeQuota, 0)
        XCTAssertEqual(s.tokenBalance, 3) // downgrade keeps tokens
    }

    // MARK: Codable back-compat

    func testDecodesPartialJSONToDefaults() throws {
        let premium = try JSONDecoder().decode(EntitlementState.self, from: Data(#"{"tier":"premium"}"#.utf8))
        XCTAssertEqual(premium.tier, .premium)
        XCTAssertEqual(premium.period, .weekly)
        XCTAssertEqual(premium.tokenBalance, 0)
        XCTAssertEqual(premium.freeQuota, 10)

        let empty = try JSONDecoder().decode(EntitlementState.self, from: Data("{}".utf8))
        XCTAssertEqual(empty, EntitlementState())
    }

    // MARK: Repository

    func testRepositoryRoundTripAndClear() throws {
        let store = InMemoryKeyValueStore()
        let repo = UserDefaultsEntitlementRepository(store: store, logger: NoopLogger())
        try repo.save(EntitlementState(tier: .premium, freeAnalysesUsed: 4, tokenBalance: 7))

        XCTAssertEqual(repo.load().tier, .premium)
        XCTAssertEqual(repo.load().tokenBalance, 7)

        // Survives a fresh repository over the same store.
        let reopened = UserDefaultsEntitlementRepository(store: store, logger: NoopLogger())
        XCTAssertEqual(reopened.load().freeAnalysesUsed, 4)

        try repo.clear()
        XCTAssertEqual(repo.load(), EntitlementState())
    }

    // MARK: Purchase catalog

    func testPurchaseProductIDRoundTrips() {
        for product in PurchaseProduct.all {
            XCTAssertEqual(PurchaseProduct(productID: product.productID), product)
        }
        XCTAssertEqual(PurchaseProduct.all.count, 4)
        XCTAssertEqual(PurchaseProduct.tokens(.fifty).productID, "com.bhdrozly.languageios.tokens.50")
        XCTAssertEqual(PurchaseProduct.premium(.weekly).productID, "com.bhdrozly.languageios.premium.weekly")
        XCTAssertNil(PurchaseProduct(productID: "com.other.app.premium.weekly"))
    }

    func testLedgerDecodesPartialJSON() throws {
        let ledger = try JSONDecoder().decode(LocalPurchaseLedger.self, from: Data("{}".utf8))
        XCTAssertNil(ledger.subscriptionExpires)
        XCTAssertEqual(ledger.lastTransactionSeq, 0)
    }

    // MARK: LocalPurchaseService

    func testLocalPurchasePremiumSetsExpiryAndStatus() async {
        let svc = LocalPurchaseService(store: InMemoryKeyValueStore(), logger: NoopLogger(), calendar: cal())
        let now = date(2026, 1, 5)
        let outcome = await svc.purchasePremium(period: .weekly, now: now)
        guard case .success(let grants) = outcome, case .premium(let period, let expires)? = grants.first?.kind else {
            return XCTFail("expected premium grant")
        }
        XCTAssertEqual(period, .weekly)
        XCTAssertEqual(expires, cal().date(byAdding: .day, value: 7, to: now))
        let active = await svc.subscriptionStatus(now: now)
        XCTAssertEqual(active?.period, .weekly)
        let expired = await svc.subscriptionStatus(now: date(2026, 1, 20))
        XCTAssertNil(expired) // past expiry
    }

    func testLocalPurchaseMonthlyExpiryIsCalendarMonth() async {
        let svc = LocalPurchaseService(store: InMemoryKeyValueStore(), logger: NoopLogger(), calendar: cal())
        let now = date(2026, 1, 31)
        let outcome = await svc.purchasePremium(period: .monthly, now: now)
        guard case .success(let grants) = outcome, case .premium(_, let expires)? = grants.first?.kind else {
            return XCTFail("expected premium grant")
        }
        XCTAssertEqual(expires, cal().date(byAdding: .month, value: 1, to: now)) // Feb 28, not +30d
    }

    func testLocalBuyTokensGrantsCountAndDistinctIDs() async {
        let svc = LocalPurchaseService(store: InMemoryKeyValueStore(), logger: NoopLogger(), calendar: cal())
        let now = date(2026, 1, 5)
        let o1 = await svc.buyTokens(pack: .ten, now: now)
        let o2 = await svc.buyTokens(pack: .fifty, now: now)
        guard case .success(let g1) = o1, case .tokens(let n1)? = g1.first?.kind,
              case .success(let g2) = o2, case .tokens(let n2)? = g2.first?.kind else {
            return XCTFail("expected token grants")
        }
        XCTAssertEqual(n1, 10)
        XCTAssertEqual(n2, 50)
        XCTAssertNotEqual(g1.first?.transactionID, g2.first?.transactionID)
    }

    func testLocalRestoreReturnsActiveSubThenEmptyAfterExpiry() async {
        let store = InMemoryKeyValueStore()
        let now = date(2026, 1, 5)
        _ = await LocalPurchaseService(store: store, logger: NoopLogger(), calendar: cal())
            .purchasePremium(period: .monthly, now: now)

        let reopened = LocalPurchaseService(store: store, logger: NoopLogger(), calendar: cal())
        guard case .success(let grants) = await reopened.restore(now: now) else { return XCTFail() }
        XCTAssertEqual(grants.count, 1) // active sub restored across reload

        guard case .success(let none) = await reopened.restore(now: date(2026, 3, 1)) else { return XCTFail() }
        XCTAssertTrue(none.isEmpty) // expired -> nothing to restore
    }

    // MARK: AppStore integration

    private func premiumStore(_ store: InMemoryKeyValueStore, now: Date) async -> AppStore {
        let purchases = LocalPurchaseService(store: store, logger: NoopLogger(), calendar: cal())
        let app = AppStore(environment: makeTestEnvironment(store: store, purchaseService: purchases))
        await app.purchasePremium(.weekly, now: now)
        return app
    }

    func testAppStorePurchasePremiumFlipsTierAndQuota() async {
        let now = date(2026, 1, 7)
        let app = await premiumStore(InMemoryKeyValueStore(), now: now)
        XCTAssertTrue(app.isPremium)
        XCTAssertEqual(app.photoQuotaLimit, 10)
        XCTAssertEqual(app.photoQuotaRemaining(now: now), 10)
    }

    func testAppStoreConsumePersistsAndRefundRestores() async {
        let now = date(2026, 1, 7)
        let store = InMemoryKeyValueStore()
        let app = await premiumStore(store, now: now)

        let charge = app.consumePhotoQuota(now: now)
        XCTAssertEqual(charge, .freeQuota)
        XCTAssertEqual(app.photoQuotaRemaining(now: now), 9)

        // Survives a fresh AppStore over the same store.
        let reopened = AppStore(environment: makeTestEnvironment(store: store))
        XCTAssertEqual(reopened.photoQuotaRemaining(now: now), 9)
        XCTAssertTrue(reopened.isPremium)

        app.refundPhotoQuota(charge!)
        XCTAssertEqual(app.photoQuotaRemaining(now: now), 10)
    }

    func testAppStoreFreemiumCannotCaptureUntilTokensBought() async {
        let now = date(2026, 1, 7)
        let store = InMemoryKeyValueStore()
        let purchases = LocalPurchaseService(store: store, logger: NoopLogger(), calendar: cal())
        let app = AppStore(environment: makeTestEnvironment(store: store, purchaseService: purchases))

        XCTAssertFalse(app.isPremium)
        XCTAssertFalse(app.canCapturePhoto(now: now)) // freemium, 0 quota, 0 tokens
        XCTAssertNil(app.consumePhotoQuota(now: now))

        await app.buyTokens(.ten, now: now)
        XCTAssertEqual(app.tokenBalance, 10)
        XCTAssertTrue(app.canCapturePhoto(now: now))
        XCTAssertEqual(app.consumePhotoQuota(now: now), .token)
        XCTAssertEqual(app.tokenBalance, 9)

        // Tokens carry over across reload (no premium needed).
        let reopened = AppStore(environment: makeTestEnvironment(store: store))
        XCTAssertEqual(reopened.tokenBalance, 9)
    }

    func testAppStoreResetAllClearsEntitlement() async {
        let now = date(2026, 1, 7)
        let store = InMemoryKeyValueStore()
        let app = await premiumStore(store, now: now)
        await app.buyTokens(.ten, now: now)
        app.resetAll()
        XCTAssertFalse(app.isPremium)
        XCTAssertEqual(app.tokenBalance, 0)
        XCTAssertEqual(AppStore(environment: makeTestEnvironment(store: store)).tokenBalance, 0)
    }
}
