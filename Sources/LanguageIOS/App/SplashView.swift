import SwiftUI

/// The app's logo mark drawn in SwiftUI (matches AppIcon / LaunchLogo): a teal tile with a
/// cream "Aa" speech bubble and a coral accent dot. Vector, so it stays crisp at any size.
struct AppGlyph: View {
    var size: CGFloat = 112

    private let teal = OnboardingTheme.teal
    private let tealDeep = Color(red: 0.30, green: 0.62, blue: 0.62)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                .fill(LinearGradient(colors: [tealDeep, teal], startPoint: .top, endPoint: .bottom))

            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                .fill(OnboardingTheme.background)
                .frame(width: size * 0.62, height: size * 0.46)
                .overlay(
                    Text("Aa")
                        .font(.system(size: size * 0.26, weight: .black, design: .rounded))
                        .foregroundStyle(OnboardingTheme.ink)
                )
                .offset(y: -size * 0.03)

            Circle()
                .fill(OnboardingTheme.coral)
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(x: size * 0.2, y: size * 0.17)
        }
        .frame(width: size, height: size)
    }
}

/// Branded launch overlay. The OS launch screen now shows `LaunchLogo` over the flat
/// `LaunchBackground`; this view paints the same background + glyph instantly (no flash),
/// animates it in, then `RootView` fades it out into the real content.
struct SplashView: View {
    @State private var appear = false

    private var appName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "LanguageIOS"
    }

    var body: some View {
        ZStack {
            OnboardingTheme.background.ignoresSafeArea()
            VStack(spacing: 22) {
                AppGlyph(size: 116)
                    .shadow(color: OnboardingTheme.teal.opacity(0.32), radius: 22, y: 12)
                    .scaleEffect(appear ? 1 : 0.72)
                    .opacity(appear ? 1 : 0)

                Text(appName)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(OnboardingTheme.ink)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { appear = true }
        }
    }
}
