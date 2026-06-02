import Foundation
@testable import LanguageIOS

/// Records every analytics call so tests can assert the funnel.
final class SpyAnalyticsService: AnalyticsService {
    private(set) var events: [AnalyticsEvent] = []
    private(set) var identifiedUserIds: [String?] = []

    func track(_ event: AnalyticsEvent) { events.append(event) }
    func identify(userId: String?) { identifiedUserIds.append(userId) }
    func setUserProperty(_ value: String?, for key: String) {}

    var names: [String] { events.map(\.name) }
    func events(named name: String) -> [AnalyticsEvent] { events.filter { $0.name == name } }
}

/// A profile repository that always fails to write — used to test error surfacing.
final class FailingProfileRepository: ProfileRepository {
    func loadProfile() -> UserProfile? { nil }
    func save(_ profile: UserProfile) throws { throw AppError.persistenceWrite(key: "test") }
    func clear() throws {}
}

/// Records notification scheduling calls so tests can assert retention behavior.
final class SpyNotificationScheduler: NotificationScheduling {
    private(set) var dailyReminders: [(time: ReminderTime, body: String)] = []
    private(set) var heartRefills: [(seconds: TimeInterval, body: String)] = []
    private(set) var heartRefillCancelCount = 0
    private(set) var dailyReminderCancelCount = 0

    func requestAuthorization() async -> Bool { true }
    func scheduleDailyReminder(at time: ReminderTime, body: String) { dailyReminders.append((time, body)) }
    func cancelDailyReminder() { dailyReminderCancelCount += 1 }
    func scheduleHeartRefill(after seconds: TimeInterval, body: String) { heartRefills.append((seconds, body)) }
    func cancelHeartRefill() { heartRefillCancelCount += 1 }
}

/// Builds an in-memory `AppEnvironment` for tests, with swappable doubles.
func makeTestEnvironment(
    analytics: AnalyticsService = NoopAnalyticsService(),
    store: KeyValueStore = InMemoryKeyValueStore(),
    notifications: NotificationScheduling = NoopNotificationScheduler()
) -> AppEnvironment {
    let logger = NoopLogger()
    return AppEnvironment(
        analytics: analytics,
        logger: logger,
        performance: NoopPerformanceTracer(),
        crashReporter: NoopCrashReporter(),
        profileRepository: UserDefaultsProfileRepository(store: store, logger: logger),
        progressRepository: UserDefaultsProgressRepository(store: store, logger: logger),
        settingsRepository: UserDefaultsSettingsRepository(store: store, logger: logger),
        gamificationRepository: UserDefaultsGamificationRepository(store: store, logger: logger),
        notifications: notifications,
        speech: NoopSpeechService(),
        captureRepository: DefaultCaptureRepository(store: store, blobs: InMemoryImageBlobStore())
    )
}

func makeFailingProfileEnvironment() -> AppEnvironment {
    let store = InMemoryKeyValueStore()
    let logger = NoopLogger()
    return AppEnvironment(
        analytics: NoopAnalyticsService(),
        logger: logger,
        performance: NoopPerformanceTracer(),
        crashReporter: NoopCrashReporter(),
        profileRepository: FailingProfileRepository(),
        progressRepository: UserDefaultsProgressRepository(store: store, logger: logger),
        settingsRepository: UserDefaultsSettingsRepository(store: store, logger: logger),
        gamificationRepository: UserDefaultsGamificationRepository(store: store, logger: logger),
        notifications: NoopNotificationScheduler(),
        speech: NoopSpeechService(),
        captureRepository: DefaultCaptureRepository(store: store, blobs: InMemoryImageBlobStore())
    )
}
