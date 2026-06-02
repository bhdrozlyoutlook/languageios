import XCTest
@testable import LanguageIOS

final class AppLaunchTests: XCTestCase {
    func testRootViewDoesNotInstallASplashOverlay() throws {
        let rootViewSource = try sourceText(at: "Sources/LanguageIOS/RootView.swift")

        XCTAssertFalse(rootViewSource.contains("SplashView"))
        XCTAssertFalse(rootViewSource.contains("showSplash"))
        XCTAssertFalse(rootViewSource.contains("LaunchSplashPolicy"))
    }

    func testProjectConfigUsesBrandedLaunchScreen() throws {
        let projectSpec = try sourceText(at: "project.yml")

        XCTAssertTrue(projectSpec.contains("UIImageName: LaunchLogo"))
        XCTAssertTrue(projectSpec.contains("UIColorName: LaunchBackground"))
    }

    func testEnvironmentDoesNotEagerlyBuildCameraRecognizerOnLaunch() throws {
        let environmentSource = try sourceText(at: "Sources/LanguageIOS/App/AppEnvironment.swift")

        XCTAssertFalse(environmentSource.contains("objectRecognizer: ObjectRecognizing = OnDeviceObjectRecognizer()"))
        XCTAssertTrue(environmentSource.contains("objectRecognizer: ObjectRecognizing = LazyObjectRecognizer"))
        XCTAssertTrue(environmentSource.contains("private static func makeObjectRecognizer() -> ObjectRecognizing {\n        LazyObjectRecognizer"))
    }

    func testLiveObjectRecognizerIsGeminiOnly() throws {
        let environmentSource = try sourceText(at: "Sources/LanguageIOS/App/AppEnvironment.swift")

        XCTAssertFalse(environmentSource.contains("return OnDeviceObjectRecognizer()"))
        XCTAssertFalse(environmentSource.contains("fallback: OnDeviceObjectRecognizer"))
        XCTAssertTrue(environmentSource.contains("GeminiObjectRecognizer(apiKey: Secrets.geminiAPIKey"))
    }

    func testPlanSummaryAnimationDoesNotActLikeAStartupLoadingScreen() throws {
        let onboardingSource = try sourceText(at: "Sources/LanguageIOS/Onboarding/OnboardingView.swift")

        XCTAssertFalse(onboardingSource.contains("typingSpeed: 0.04"))
        XCTAssertFalse(onboardingSource.contains("holdDuration: 0.6"))
        XCTAssertFalse(onboardingSource.contains(".milliseconds(280)"))
        XCTAssertFalse(onboardingSource.contains("charDelay: 0.015"))
    }

    func testProfileDerivedLaunchStatsUseInitialProfileSnapshot() {
        let profileRepository = CountingProfileRepository(
            profile: UserProfile(
                dailyGoal: .thirtyMinutes,
                reminderTime: ReminderTime(hour: 8, minute: 15)
            )
        )
        let store = AppStore(environment: makeProfileCountingEnvironment(profileRepository))

        XCTAssertEqual(profileRepository.loadCount, 1)
        XCTAssertEqual(store.dailyGoalTarget, DailyGoal.thirtyMinutes.targetActivities)
        XCTAssertEqual(store.reminderTime(), ReminderTime(hour: 8, minute: 15))
        XCTAssertEqual(store.userProfile()?.dailyGoal, .thirtyMinutes)
        XCTAssertEqual(profileRepository.loadCount, 1)
    }
}

private func sourceText(at relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}

private final class CountingProfileRepository: ProfileRepository {
    private var profile: UserProfile?
    private(set) var loadCount = 0

    init(profile: UserProfile?) {
        self.profile = profile
    }

    func loadProfile() -> UserProfile? {
        loadCount += 1
        return profile
    }

    func save(_ profile: UserProfile) throws {
        self.profile = profile
    }

    func clear() throws {
        profile = nil
    }
}

private func makeProfileCountingEnvironment(_ profiles: ProfileRepository) -> AppEnvironment {
    let store = InMemoryKeyValueStore()
    let logger = NoopLogger()
    return AppEnvironment(
        analytics: NoopAnalyticsService(),
        logger: logger,
        performance: NoopPerformanceTracer(),
        crashReporter: NoopCrashReporter(),
        profileRepository: profiles,
        progressRepository: UserDefaultsProgressRepository(store: store, logger: logger),
        settingsRepository: UserDefaultsSettingsRepository(store: store, logger: logger),
        gamificationRepository: UserDefaultsGamificationRepository(store: store, logger: logger),
        notifications: NoopNotificationScheduler(),
        speech: NoopSpeechService(),
        captureRepository: DefaultCaptureRepository(store: store, blobs: InMemoryImageBlobStore()),
        entitlementRepository: UserDefaultsEntitlementRepository(store: store, logger: logger)
    )
}
