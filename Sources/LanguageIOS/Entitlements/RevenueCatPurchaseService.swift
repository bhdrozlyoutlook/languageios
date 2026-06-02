import Foundation
#if canImport(RevenueCat)
import RevenueCat

/// RevenueCat-backed `PurchaseService`. Compiles and activates only once the RevenueCat SPM
/// package is added AND `REVENUECAT_API_KEY` is set (see `AppEnvironment.makePurchaseService`).
/// Until then `canImport(RevenueCat)` is false and the app keeps using `LocalPurchaseService`.
///
/// Setup:
///   1. Add the package: Xcode ▸ File ▸ Add Packages ▸ https://github.com/RevenueCat/purchases-ios
///      (product: RevenueCat). Or add it to `project.yml` `packages:` + the app target deps.
///   2. App Store Connect: create the products with our IDs (`PurchaseProduct.all`):
///      premium.weekly / premium.monthly (auto-renewable subs), tokens.* (consumables).
///   3. RevenueCat dashboard: connect the app, import the products, build an Offering with
///      those packages, and create an Entitlement identified `premium`. Copy the public SDK
///      key into `Secrets.plist` under `REVENUECAT_API_KEY`.
///
/// Token balances are consumables, so RevenueCat just confirms the purchase — the running
/// balance stays in `EntitlementState.tokenBalance` (carry-over) as today.
public final class RevenueCatPurchaseService: PurchaseService {
    /// RevenueCat Entitlement identifier that represents an active premium subscription.
    private static let premiumEntitlement = "premium"

    private let calendar: Calendar

    public init(apiKey: String, calendar: Calendar = .current) {
        self.calendar = calendar
        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: apiKey)
        }
    }

    public func products() async -> [PurchaseProductInfo] {
        guard let packages = try? await Purchases.shared.offerings().current?.availablePackages else { return [] }
        return packages.compactMap { package in
            guard let product = PurchaseProduct(productID: package.storeProduct.productIdentifier) else { return nil }
            return PurchaseProductInfo(
                product: product,
                displayName: PurchaseProductInfo.defaultDisplayName(product),
                displayPrice: package.storeProduct.localizedPriceString // real, localized price
            )
        }
    }

    public func purchasePremium(period: RenewalPeriod, now: Date) async -> PurchaseOutcome {
        await purchase(productID: PurchaseProduct.premium(period).productID)
    }

    public func buyTokens(pack: TokenPack, now: Date) async -> PurchaseOutcome {
        await purchase(productID: PurchaseProduct.tokens(pack).productID)
    }

    public func restore(now: Date) async -> PurchaseOutcome {
        guard let info = try? await Purchases.shared.restorePurchases() else { return .failed(.network) }
        if let grant = premiumGrant(from: info, transactionID: "restore") { return .success([grant]) }
        return .success([]) // consumables (tokens) are not restorable
    }

    public func subscriptionStatus(now: Date) async -> SubscriptionStatus? {
        guard let info = try? await Purchases.shared.customerInfo() else { return nil }
        return subscriptionStatus(from: info)
    }

    // MARK: Helpers

    private func purchase(productID: String) async -> PurchaseOutcome {
        guard let package = await package(forProductID: productID) else {
            return .failed(.productUnavailable)
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return .userCancelled }
            let transactionID = result.transaction?.transactionIdentifier ?? productID
            if let grant = grant(forProductID: productID, customerInfo: result.customerInfo, transactionID: transactionID) {
                return .success([grant])
            }
            return .success([])
        } catch {
            return .failed(.unknown)
        }
    }

    private func package(forProductID id: String) async -> Package? {
        guard let packages = try? await Purchases.shared.offerings().current?.availablePackages else { return nil }
        return packages.first { $0.storeProduct.productIdentifier == id }
    }

    private func grant(forProductID id: String, customerInfo: CustomerInfo, transactionID: String) -> PurchaseGrant? {
        guard let product = PurchaseProduct(productID: id) else { return nil }
        switch product {
        case .premium:
            return premiumGrant(from: customerInfo, transactionID: transactionID)
        case .tokens(let pack):
            return PurchaseGrant(kind: .tokens(pack.tokenCount), transactionID: transactionID)
        }
    }

    private func premiumGrant(from info: CustomerInfo, transactionID: String) -> PurchaseGrant? {
        guard let status = subscriptionStatus(from: info) else { return nil }
        return PurchaseGrant(kind: .premium(status.period, expires: status.expires), transactionID: transactionID)
    }

    private func subscriptionStatus(from info: CustomerInfo) -> SubscriptionStatus? {
        guard let entitlement = info.entitlements[Self.premiumEntitlement], entitlement.isActive else { return nil }
        let expires = entitlement.expirationDate
            ?? calendar.date(byAdding: .month, value: 1, to: Date())
            ?? Date()
        let period: RenewalPeriod = {
            if case .premium(let p)? = PurchaseProduct(productID: entitlement.productIdentifier) { return p }
            return .monthly
        }()
        return SubscriptionStatus(period: period, expires: expires)
    }
}
#endif
