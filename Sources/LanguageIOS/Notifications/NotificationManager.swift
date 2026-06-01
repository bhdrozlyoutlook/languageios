import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

public enum NotificationManager {
    public static let dailyReminderIdentifier = "language-ios.daily-lesson-reminder"
    public static let heartRefillIdentifier = "language-ios.heart-refill"

    @discardableResult
    public static func requestAuthorization() async -> Bool {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public static func scheduleDailyReminder(at time: ReminderTime, body: String) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Ders zamanı"
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = time.hour
        dateComponents.minute = time.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
        #endif
    }

    public static func cancelDailyReminder() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
        #endif
    }

    /// One-off notification fired when the next heart refills.
    public static func scheduleHeartRefill(after seconds: TimeInterval, body: String) {
        #if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [heartRefillIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Canların yenilendi ❤️"
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: heartRefillIdentifier,
            content: content,
            trigger: trigger
        )
        center.add(request)
        #endif
    }

    public static func cancelHeartRefill() {
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [heartRefillIdentifier])
        #endif
    }
}
