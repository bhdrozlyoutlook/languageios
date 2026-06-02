# RevenueCat purchases

The app's purchase layer is provider-agnostic (`PurchaseService`). It ships with a
`LocalPurchaseService` (fake, no payment) for development. RevenueCat plugs in as a drop-in
adapter (`RevenueCatPurchaseService`) — no changes to `AppStore`, the UI, or
`EntitlementState`.

The adapter is compiled behind `#if canImport(RevenueCat)`, so the project keeps building
without the SDK. It activates automatically once **both** are true:

1. the RevenueCat SPM package is present, and
2. `REVENUECAT_API_KEY` is set in `App/Secrets.plist` (or the environment).

`AppEnvironment.makePurchaseService` then returns `RevenueCatPurchaseService`; otherwise it
falls back to `LocalPurchaseService`.

## One-time setup

1. **Add the SDK.** Xcode ▸ File ▸ Add Package Dependencies ▸
   `https://github.com/RevenueCat/purchases-ios` → add the `RevenueCat` product to the
   `LanguageIOSApp` target. (Or add it to `project.yml` under `packages:` and the target's
   `dependencies:`, then `xcodegen generate`.)

2. **App Store Connect.** Create the in-app purchases with these exact IDs
   (`PurchaseProduct.all`):
   - `com.bhdrozly.languageios.premium.weekly` — auto-renewable subscription
   - `com.bhdrozly.languageios.premium.monthly` — auto-renewable subscription
   - `com.bhdrozly.languageios.tokens.10` … `.tokens.1000` — **consumables**
   Fill in banking/tax info or purchases won't process.

3. **RevenueCat dashboard.** Add the app, import the products, build an **Offering** that
   contains the packages, and create an **Entitlement** identified exactly `premium`
   (granted by both subscription products). Copy the **public SDK key**.

4. **Key.** Put the public key in `App/Secrets.plist` under `REVENUECAT_API_KEY`.

## Notes

- **Real prices.** `products()` reads `storeProduct.localizedPriceString`, so the paywall
  shows real App Store prices — the local placeholder prices are ignored once RevenueCat is
  active.
- **Tokens are consumables.** RevenueCat confirms the purchase; the running balance stays in
  `EntitlementState.tokenBalance` (carry-over), credited via `AppStore.buyTokens`.
- **Subscription status.** `subscriptionStatus()` reads the `premium` entitlement
  (`isActive` / `expirationDate`); `AppStore.reconcileEntitlements()` downgrades on expiry at
  launch, keeping tokens.
- The adapter targets the RevenueCat v5 Swift API; adjust method names if you pin a different
  major version.
