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
    public let captureRepository: CaptureRepository
    public let entitlementRepository: EntitlementRepository
    public let purchaseService: PurchaseService
    public let objectRecognizer: ObjectRecognizing
    public let sentenceAnalyzer: SentenceAnalyzing

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
        speech: SpeechService,
        captureRepository: CaptureRepository,
        entitlementRepository: EntitlementRepository,
        purchaseService: PurchaseService = NoopPurchaseService(),
        objectRecognizer: ObjectRecognizing = LazyObjectRecognizer { GeminiObjectRecognizer(apiKey: "") },
        sentenceAnalyzer: SentenceAnalyzing = HeuristicSentenceAnalyzer()
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
        self.captureRepository = captureRepository
        self.entitlementRepository = entitlementRepository
        self.purchaseService = purchaseService
        self.objectRecognizer = objectRecognizer
        self.sentenceAnalyzer = sentenceAnalyzer
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
        // MetricKit is started off the launch critical path — see startDeferredServices().

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
            speech: speech,
            captureRepository: DefaultCaptureRepository(
                store: store,
                blobs: FileImageBlobStore() ?? InMemoryImageBlobStore(),
                logger: logger
            ),
            entitlementRepository: UserDefaultsEntitlementRepository(store: store, logger: logger),
            purchaseService: makePurchaseService(store: store, logger: logger),
            objectRecognizer: makeObjectRecognizer(),
            sentenceAnalyzer: makeSentenceAnalyzer()
        )
    }

    /// Background services that don't need to block the first frame. Call once after launch
    /// (from RootView's `.task`).
    func startDeferredServices() {
        #if canImport(MetricKit) && os(iOS)
        MetricKitReporter.start(logger: logger, crashReporter: crashReporter)
        #endif
    }

    /// Local purchases now (no payment); flips to `StoreKit2PurchaseService` behind a build
    /// flag once App Store Connect product IDs exist — the only line that changes.
    private static func makePurchaseService(store: KeyValueStore, logger: AppLogging) -> PurchaseService {
        let calendar = Calendar(identifier: .iso8601)
        #if canImport(RevenueCat)
        let revenueCatKey = Secrets.revenueCatAPIKey
        if !revenueCatKey.isEmpty {
            return RevenueCatPurchaseService(apiKey: revenueCatKey, calendar: calendar)
        }
        #endif
        return LocalPurchaseService(store: store, logger: logger, calendar: calendar)
    }

    /// Uses Gemini for object identification. Missing keys or network failures return no
    /// match; object names never fall back to Apple's on-device Vision classifier.
    private static func makeObjectRecognizer() -> ObjectRecognizing {
        LazyObjectRecognizer {
            GeminiObjectRecognizer(apiKey: Secrets.geminiAPIKey, model: Secrets.geminiModel)
        }
    }

    private static func makeSentenceAnalyzer() -> SentenceAnalyzing {
        let key = Secrets.geminiAPIKey
        return key.isEmpty ? HeuristicSentenceAnalyzer() : GeminiSentenceAnalyzer(apiKey: key, model: Secrets.geminiModel)
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
            speech: NoopSpeechService(),
            captureRepository: DefaultCaptureRepository(store: store, blobs: InMemoryImageBlobStore()),
            entitlementRepository: UserDefaultsEntitlementRepository(store: store, logger: logger),
            purchaseService: NoopPurchaseService()
        )
    }
}
