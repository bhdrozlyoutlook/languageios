import Foundation

/// A purchasable token pack. 1 token = 1 extra Gemini object analysis. Data-driven so the
/// ladder can be any list of counts without a wall of enum cases.
public struct TokenPack: Equatable, Hashable, Sendable {
    public let tokenCount: Int

    public init(_ tokenCount: Int) {
        self.tokenCount = tokenCount
    }

    public var idSuffix: String { String(tokenCount) }

    /// The offered ladder: 10, then every 25 up to 1000.
    public static let all: [TokenPack] = ([10] + Array(stride(from: 25, through: 1000, by: 25))).map(TokenPack.init)

    // Convenience for tests.
    public static let ten = TokenPack(10)
    public static let fifty = TokenPack(50)
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
        for pack in TokenPack.all where suffix == "tokens.\(pack.idSuffix)" {
            self = .tokens(pack)
            return
        }
        return nil
    }

    public static var all: [PurchaseProduct] {
        RenewalPeriod.allCases.map { .premium($0) } + TokenPack.all.map { .tokens($0) }
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
        // Placeholder flat rate (~₺3/token) until real App Store prices are set.
        case .tokens(let pack): "₺\(pack.tokenCount * 3 - 1),99"
        }
    }
}
