import SwiftUI

private struct AppEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppEnvironment = .preview()
}

public extension EnvironmentValues {
    /// The app's service container. Set once by `RootView`; read by views via
    /// `@Environment(\.appEnvironment)`. Defaults to `.preview()` so `#Preview` works.
    var appEnvironment: AppEnvironment {
        get { self[AppEnvironmentKey.self] }
        set { self[AppEnvironmentKey.self] = newValue }
    }
}
