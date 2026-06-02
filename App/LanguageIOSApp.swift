import SwiftUI

@main
struct LanguageIOSApp: App {
    private let environment: AppEnvironment = {
        // UI tests launch with a fresh in-memory environment so each run starts at onboarding.
        if ProcessInfo.processInfo.arguments.contains("--uitest-reset") {
            return .preview()
        }
        return .live()
    }()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}
