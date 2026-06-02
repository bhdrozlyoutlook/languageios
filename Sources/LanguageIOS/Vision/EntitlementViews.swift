import SwiftUI

/// Single source of truth for whether photo-word capture is allowed right now. The UI keys
/// off this, never the tier alone (a freemium user holding tokens is `.allowed`).
enum CaptureAccess: Equatable {
    case allowed(remaining: Int, isPremium: Bool, tokens: Int)
    case freemiumLocked
    case premiumExhausted(tokens: Int)

    static func of(_ store: AppStore, now: Date = Date()) -> CaptureAccess {
        if store.canCapturePhoto(now: now) {
            return .allowed(
                remaining: store.photoQuotaRemaining(now: now),
                isPremium: store.isPremium,
                tokens: store.tokenBalance
            )
        }
        return store.isPremium ? .premiumExhausted(tokens: store.tokenBalance) : .freemiumLocked
    }
}

/// The capture-screen top counter: "Premium: 7/10 hak kaldı" / "Freemium: 0 hak" / "N jeton".
struct CaptureCounterPill: View {
    let access: CaptureAccess
    let limit: Int

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(.black.opacity(0.42)))
    }

    private var text: String {
        switch access {
        case .allowed(let remaining, let isPremium, let tokens):
            if isPremium {
                return String(localized: "Premium: \(remaining)/\(limit) hak kaldı")
            }
            if remaining > 0 {
                return String(localized: "Freemium: \(remaining) hak")
            }
            return String(localized: "\(tokens) jeton")
        case .freemiumLocked:
            return String(localized: "Freemium: 0 hak")
        case .premiumExhausted:
            return String(localized: "Bu dönem bitti")
        }
    }
}

/// One sheet hosting the whole paywall flow (gate → plans/tokens), navigating internally so
/// we never swap a presented `.sheet(item:)` mid-flight.
struct EntitlementFlowView: View {
    let store: AppStore
    var onClose: () -> Void

    enum Screen: Equatable, Hashable, Identifiable {
        case freemiumGate, premiumExhausted, paywallPremium, paywallTokens
        var id: Self { self }
    }

    @State private var screen: Screen
    @State private var isWorking = false

    init(store: AppStore, start: Screen, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
        self._screen = State(initialValue: start)
    }

    var body: some View {
        ZStack {
            OnboardingTheme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView {
                    content
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                        .padding(.bottom, 30)
                }
            }
            if isWorking {
                Color.black.opacity(0.12).ignoresSafeArea()
                ProgressView().controlSize(.large)
            }
        }
    }

    private var header: some View {
        HStack {
            if screen == .paywallPremium || screen == .paywallTokens {
                Button { screen = backTarget } label: {
                    Image(systemName: "chevron.left").font(.headline.bold())
                        .foregroundStyle(OnboardingTheme.ink.opacity(0.6)).frame(width: 34, height: 34)
                }
                .accessibilityLabel("Geri")
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.headline.bold())
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.6)).frame(width: 34, height: 34)
            }
            .accessibilityLabel("Kapat")
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    private var backTarget: Screen { store.isPremium ? .premiumExhausted : .freemiumGate }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .freemiumGate: freemiumGate
        case .premiumExhausted: premiumExhausted
        case .paywallPremium: paywall(title: String(localized: "Premium ol"), products: store.premiumPlans())
        case .paywallTokens: paywall(title: String(localized: "Jeton al"), products: store.tokenPackages())
        }
    }

    // MARK: Screens

    private var freemiumGate: some View {
        VStack(spacing: 18) {
            hero(symbol: "camera.viewfinder")
            Text("Fotoğrafla öğrenme Premium'da")
                .font(.title2.bold()).multilineTextAlignment(.center)
                .foregroundStyle(OnboardingTheme.ink)
            Text("Premium'da her dönem 10 ücretsiz fotoğraf analizi. Ya da jeton al, hak bitince kullan.")
                .font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
            primaryButton("Premium ol") { screen = .paywallPremium }
            secondaryButton("Jeton al") { screen = .paywallTokens }
        }
        .padding(.top, 18)
    }

    private var premiumExhausted: some View {
        VStack(spacing: 16) {
            hero(symbol: "hourglass")
            Text("Bu \(store.currentPeriodWord()) hakların bitti")
                .font(.title2.bold()).multilineTextAlignment(.center)
                .foregroundStyle(OnboardingTheme.ink)
            Text("Yeni ücretsiz hakların önümüzdeki dönem yenilenecek. Beklemek istemezsen jeton al.")
                .font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
            ForEach(store.tokenPackages()) { info in
                productRow(info) { Task { await purchase(info.product) } }
            }
        }
        .padding(.top, 18)
    }

    private func paywall(title: String, products: [PurchaseProductInfo]) -> some View {
        VStack(spacing: 14) {
            Text(title)
                .font(.title2.bold()).foregroundStyle(OnboardingTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(products) { info in
                productRow(info) { Task { await purchase(info.product) } }
            }
            Text("Şu an deneme: gerçek ödeme yok")
                .font(.caption).foregroundStyle(OnboardingTheme.ink.opacity(0.4))
                .padding(.top, 6)
        }
        .padding(.top, 10)
    }

    // MARK: Pieces

    private func hero(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 46, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 96, height: 96)
            .background(Circle().fill(OnboardingTheme.teal))
            .shadow(color: OnboardingTheme.teal.opacity(0.3), radius: 16, y: 8)
    }

    private func productRow(_ info: PurchaseProductInfo, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(info.displayName).font(.headline).foregroundStyle(OnboardingTheme.ink)
                Spacer()
                Text(info.displayPrice).font(.subheadline.bold()).foregroundStyle(OnboardingTheme.teal)
                Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(OnboardingTheme.ink.opacity(0.3))
            }
            .padding(.horizontal, 18)
            .frame(height: 60)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.paper))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline.bold()).foregroundStyle(.white)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.teal))
        }
        .disabled(isWorking)
    }

    private func secondaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline.bold()).foregroundStyle(OnboardingTheme.ink)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.paper))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1))
        }
        .disabled(isWorking)
    }

    private func purchase(_ product: PurchaseProduct) async {
        isWorking = true
        switch product {
        case .premium(let period): await store.purchasePremium(period)
        case .tokens(let pack): await store.buyTokens(pack)
        }
        isWorking = false
        onClose()
    }
}
