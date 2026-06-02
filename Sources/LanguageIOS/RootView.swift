import SwiftUI

/// App root and composition point. Owns the persistent `AppStore` (built from the
/// injected `AppEnvironment`), publishes the environment into the SwiftUI tree, decides
/// onboarding vs. learning-path home, and surfaces persistence errors.
public struct RootView: View {
    @State private var store: AppStore
    @State private var showSplash = true
    private let environment: AppEnvironment

    /// Defaults to `.preview()` so `#Preview` and tests can use `RootView()`.
    public init(environment: AppEnvironment = .preview()) {
        self.environment = environment
        _store = State(initialValue: AppStore(environment: environment))
    }

    public var body: some View {
        ZStack {
            content
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            // Branded splash that masks first-frame setup, then fades to content.
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
        }
        .environment(\.appEnvironment, environment)
        .onAppear { environment.crashReporter.recordBreadcrumb("app launched", category: .app) }
        .alert(
            "Hata",
            isPresented: Binding(
                get: { store.lastError != nil },
                set: { if !$0 { store.clearError() } }
            ),
            presenting: store.lastError
        ) { _ in
            Button("Tamam", role: .cancel) { store.clearError() }
        } message: { error in
            Text(error.userMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.hasCompletedOnboarding, let language = store.targetLanguage {
            LearningPathView(language: language, store: store)
                .transition(.opacity)
        } else {
            OnboardingView { profile in
                withAnimation(.easeInOut(duration: 0.35)) {
                    store.completeOnboarding(with: profile)
                }
            }
            .transition(.opacity)
        }
    }
}

#Preview {
    RootView()
}
