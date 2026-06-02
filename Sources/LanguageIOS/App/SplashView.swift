import SwiftUI

/// Branded launch overlay. The OS launch screen is just the flat `LaunchBackground` color
/// (no logo) — so the first thing the user sees is blank. This view paints the same
/// background instantly (no flash) and animates a logo mark in, then `RootView` fades it
/// out into the real content, masking first-frame setup cost.
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
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(LinearGradient(
                            colors: [OnboardingTheme.teal, OnboardingTheme.teal.opacity(0.78)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 108, height: 108)
                        .shadow(color: OnboardingTheme.teal.opacity(0.35), radius: 20, y: 12)
                    Image(systemName: "character.bubble.fill")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                }
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
