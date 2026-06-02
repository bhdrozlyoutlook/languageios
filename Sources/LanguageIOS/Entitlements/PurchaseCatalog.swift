import Foundation

/// A purchasable token pack. 1 token = 1 extra Gemini object analysis.
public enum TokenPack: String, CaseIterable, Sendable {
    case ten
    case fifty
    case hundred
    case twoFifty
    case fiveHundred

    public var tokenCount: Int {
        switch self {
        case .ten: 10
        case .fifty: 50
        case .hundred: 100
        case .twoFifty: 250
        case .fiveHundred: 500
        }
    }

    public var idSuffix: String { String(tokenCount) }
}

/// The in-app purchase catalog. Product IDs are the frozen contract App Store Connect must
/// match when real StoreKit ships.
public enum PurchaseProduct: Equatable, Sendable {
    case premium(RenewalPeriod)
    case tokens(TokenPack)

    private static let prefix = "com.bhdrozly.languageios."

    public var productID: String {
        switch self {
        case .premium(let period): return "\(Self.prefix)premium.\(period.rawValue)"
        case .tokens(let pack): return "\(Self.prefix)tokens.\(pack.idSuffix)"
        }
    }

    public init?(productID: String) {
        guard productID.hasPrefix(Self.prefix) else { return nil }
        let suffix = String(productID.dropFirst(Self.prefix.count))
        for period in RenewalPeriod.allCases where suffix == "premium.\(period.rawValue)" {
            self = .premium(period)
            return
        }
        for pack in TokenPack.allCases where suffix == "tokens.\(pack.idSuffix)" {
            self = .tokens(pack)
            return
        }
        return nil
    }

    public static var all: [PurchaseProduct] {
        RenewalPeriod.allCases.map { .premium($0) } + TokenPack.allCases.map { .tokens($0) }
    }
}

/// Display model for the paywall. `displayPrice` is a local placeholder until real StoreKit
/// supplies `Product.displayPrice`.
public struct PurchaseProductInfo: Identifiable, Equatable, Sendable {
    public let product: PurchaseProduct
    public let displayName: String
    public let displayPrice: String

    public var id: String { product.productID }

    public init(product: PurchaseProduct, displayName: String, displayPrice: String) {
        self.product = product
        self.displayName = displayName
        self.displayPrice = displayPrice
    }

    /// Placeholder catalog used by the local/noop services (display-only prices).
    public static func placeholderCatalog() -> [PurchaseProductInfo] {
        PurchaseProduct.all.map { product in
            PurchaseProductInfo(
                product: product,
                displayName: defaultDisplayName(product),
                displayPrice: defaultDisplayPrice(product)
            )
        }
    }

    static func defaultDisplayName(_ product: PurchaseProduct) -> String {
        switch product {
        case .premium(.weekly): String(localized: "Premium (Haftalık)")
        case .premium(.monthly): String(localized: "Premium (Aylık)")
        case .tokens(let pack): String(localized: "\(pack.tokenCount) Jeton")
        }
    }

    static func defaultDisplayPrice(_ product: PurchaseProduct) -> String {
        switch product {
        case .premium(.weekly): "₺49,99"
        case .premium(.monthly): "₺149,99"
        case .tokens(let pack):
            switch pack {
            case .ten: "₺29,99"
            case .fifty: "₺99,99"
            case .hundred: "₺179,99"
            case .twoFifty: "₺399,99"
            case .fiveHundred: "₺699,99"
            }
        }
    }
}
