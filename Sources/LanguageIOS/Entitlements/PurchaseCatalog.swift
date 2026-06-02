import Foundation

/// A purchasable token pack. 1 token = 1 extra Gemini object analysis.
public enum TokenPack: String, CaseIterable, Sendable {
    case ten
    case fifty

    public var tokenCount: Int { self == .ten ? 10 : 50 }
    public var idSuffix: String { self == .ten ? "10" : "50" }
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
        switch String(productID.dropFirst(Self.prefix.count)) {
        case "premium.weekly": self = .premium(.weekly)
        case "premium.monthly": self = .premium(.monthly)
        case "tokens.10": self = .tokens(.ten)
        case "tokens.50": self = .tokens(.fifty)
        default: return nil
        }
    }

    public static var all: [PurchaseProduct] {
        [.premium(.weekly), .premium(.monthly), .tokens(.ten), .tokens(.fifty)]
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
        case .tokens(.ten): String(localized: "10 Jeton")
        case .tokens(.fifty): String(localized: "50 Jeton")
        }
    }

    static func defaultDisplayPrice(_ product: PurchaseProduct) -> String {
        switch product {
        case .premium(.weekly): "₺49,99"
        case .premium(.monthly): "₺149,99"
        case .tokens(.ten): "₺29,99"
        case .tokens(.fifty): "₺99,99"
        }
    }
}
