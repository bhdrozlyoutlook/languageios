import Foundation

/// The composition root: one value object holding every app service/repository. Created
/// once at launch (`AppEnvironment.live()`), injected into `AppStore` and the SwiftUI
/// tree. Swap any service for a third-party adapter here without touching call sites.
public struct AppEnvironment {
    public let analytics: AnalyticsService
    public let logger: AppLogging
    public let performance: PerformanceTracer
    public let crashReporter: CrashReporter
    public let profileRepository: ProfileRepository
    public let progressRepository: ProgressRepository
    public let settingsRepository: SettingsRepository
    public let gamificationRepository: GamificationRepository
    public let notifications: NotificationScheduling
    public let speech: SpeechService

    public init(
        analytics: AnalyticsService,
        logger: AppLogging,
        performance: PerformanceTracer,
        crashReporter: CrashReporter,
        profileRepository: ProfileRepository,
        progressRepository: ProgressRepository,
        settingsRepository: SettingsRepository,
        gamificationRepository: GamificationRepository,
        notifications: NotificationScheduling,
        speech: SpeechService
    ) {
        self.analytics = analytics
        self.logger = logger
        self.performance = performance
        self.crashReporter = crashReporter
        self.profileRepository = profileRepository
        self.progressRepository = progressRepository
        self.settingsRepository = settingsRepository
        self.gamificationRepository = gamificationRepository
        self.notifications = notifications
        self.speech = speech
    }
}

public extension AppEnvironment {
    /// Production composition root. One `UserDefaults`-backed store feeds all repos;
    /// legacy data is migrated once here before anything reads it.
    static func live(defaults: UserDefaults = .standard) -> AppEnvironment {
        let store = UserDefaultsKeyValueStore(defaults: defaults)
        let logger = OSLogLogger()
        StoreMigrator(store: store, logger: logger).migrateIfNeeded()

        let performance: PerformanceTracer
        #if canImport(os)
        performance = SignpostPerformanceTracer()
        #else
        performance = NoopPerformanceTracer()
        #endif

        let crashReporter = BreadcrumbCrashReporter(store: store, logger: logger)
        #if canImport(MetricKit) && os(iOS)
        MetricKitReporter.start(logger: logger, crashReporter: crashReporter)
        #endif

        let speech: SpeechService
        #if canImport(AVFAudio)
        speech = AVSpeechService()
        #else
        speech = NoopSpeechService()
        #endif

        return AppEnvironment(
            analytics: MultiplexAnalyticsService([ConsoleAnalyticsService(logger: logger)]),
            logger: logger,
            performance: performance,
            crashReporter: crashReporter,
            profileRepository: UserDefaultsProfileRepository(store: store, logger: logger),
            progressRepository: UserDefaultsProgressRepository(store: store, logger: logger),
            settingsRepository: UserDefaultsSettingsRepository(store: store, logger: logger),
            gamificationRepository: UserDefaultsGamificationRepository(store: store, logger: logger),
            notifications: SystemNotificationScheduler(),
            speech: speech
        )
    }

    /// All no-op / in-memory — for `#Preview` and tests that don't assert side effects.
    static func preview() -> AppEnvironment {
        let store = InMemoryKeyValueStore()
        let logger = NoopLogger()
        return AppEnvironment(
            analytics: NoopAnalyticsService(),
            logger: logger,
            performance: NoopPerformanceTracer(),
            crashReporter: NoopCrashReporter(),
            profileRepository: UserDefaultsProfileRepository(store: store, logger: logger),
            progressRepository: UserDefaultsProgressRepository(store: store, logger: logger),
            settingsRepository: UserDefaultsSettingsRepository(store: store, logger: logger),
            gamificationRepository: UserDefaultsGamificationRepository(store: store, logger: logger),
            notifications: NoopNotificationScheduler(),
            speech: NoopSpeechService()
        )
    }
}
