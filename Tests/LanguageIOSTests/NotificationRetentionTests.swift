import XCTest
@testable import LanguageIOS

final class NotificationRetentionTests: XCTestCase {

    func testDepletingHeartsSchedulesARefillNotification() {
        let spy = SpyNotificationScheduler()
        let app = AppStore(environment: makeTestEnvironment(notifications: spy))

        for _ in 0..<GamificationState.maxHearts {
            app.recordLessonFailed()
        }

        XCTAssertEqual(app.availableHearts(), 0)
        XCTAssertFalse(spy.heartRefills.isEmpty, "a refill notification should be scheduled")
        XCTAssertGreaterThan(spy.heartRefills.last?.seconds ?? 0, 0)
    }

    func testPassingCancelsRefillAndSchedulesStreakReminder() {
        let store = InMemoryKeyValueStore()
        let spy = SpyNotificationScheduler()
        let app = AppStore(environment: makeTestEnvironment(store: store, notifications: spy))
        app.completeOnboarding(with: OnboardingProfile(
            targetLanguage: .englishUS,
            reminderTime: ReminderTime(hour: 19, minute: 0)
        ))

        app.recordLessonPassed(stopId: "englishUS_california", stars: 3)

        XCTAssertGreaterThanOrEqual(spy.heartRefillCancelCount, 1)
        XCTAssertFalse(spy.dailyReminders.isEmpty)
        XCTAssertEqual(spy.dailyReminders.last?.time, ReminderTime(hour: 19, minute: 0))
    }

    func testStreakReminderBodyIsNonEmptyAndStreakThemed() {
        let store = InMemoryKeyValueStore()
        let spy = SpyNotificationScheduler()
        let app = AppStore(environment: makeTestEnvironment(store: store, notifications: spy))
        app.completeOnboarding(with: OnboardingProfile(targetLanguage: .englishUS, reminderTime: .defaultReminder))

        app.recordLessonPassed(stopId: "a", stars: 1)

        let body = spy.dailyReminders.last?.body ?? ""
        XCTAssertFalse(body.isEmpty)
        XCTAssertTrue(body.lowercased().contains("seri"), "reminder should reference the streak (\(body))")
    }

    func testNoStreakReminderWithoutAReminderTime() {
        let spy = SpyNotificationScheduler()
        let app = AppStore(environment: makeTestEnvironment(notifications: spy))
        // No profile / reminder time saved.
        app.recordLessonPassed(stopId: "a", stars: 1)
        XCTAssertTrue(spy.dailyReminders.isEmpty)
    }

    func testDisablingDailyReminderCancelsItAndPersists() {
        let store = InMemoryKeyValueStore()
        let spy = SpyNotificationScheduler()
        let app = AppStore(environment: makeTestEnvironment(store: store, notifications: spy))
        XCTAssertTrue(app.dailyReminderEnabled)

        app.setDailyReminderEnabled(false)
        XCTAssertFalse(app.dailyReminderEnabled)
        XCTAssertGreaterThanOrEqual(spy.dailyReminderCancelCount, 1)

        let restored = AppStore(environment: makeTestEnvironment(store: store, notifications: SpyNotificationScheduler()))
        XCTAssertFalse(restored.dailyReminderEnabled)
    }

    func testSettingReminderTimePersistsAndReschedules() {
        let store = InMemoryKeyValueStore()
        let spy = SpyNotificationScheduler()
        let app = AppStore(environment: makeTestEnvironment(store: store, notifications: spy))

        app.setReminderTime(ReminderTime(hour: 8, minute: 15))

        XCTAssertEqual(app.reminderTime(), ReminderTime(hour: 8, minute: 15))
        XCTAssertEqual(spy.dailyReminders.last?.time, ReminderTime(hour: 8, minute: 15))

        let restored = AppStore(environment: makeTestEnvironment(store: store, notifications: SpyNotificationScheduler()))
        XCTAssertEqual(restored.reminderTime(), ReminderTime(hour: 8, minute: 15))
    }
}
