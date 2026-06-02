import Foundation

/// Injectable seam over local notifications so call sites don't depend on the static
/// `NotificationManager` directly (and so tests can use a no-op).
public protocol NotificationScheduling: AnyObject {
    func requestAuthorization() async -> Bool
    func scheduleDailyReminder(at time: ReminderTime, body: String)
    func cancelDailyReminder()
    func scheduleHeartRefill(after seconds: TimeInterval, body: String)
    func cancelHeartRefill()
}

public final class SystemNotificationScheduler: NotificationScheduling {
    public init() {}

    public func requestAuthorization() async -> Bool {
        await NotificationManager.requestAuthorization()
    }

    public func scheduleDailyReminder(at time: ReminderTime, body: String) {
        NotificationManager.scheduleDailyReminder(at: time, body: body)
    }

    public func cancelDailyReminder() {
        NotificationManager.cancelDailyReminder()
    }

    public func scheduleHeartRefill(after seconds: TimeInterval, body: String) {
        NotificationManager.scheduleHeartRefill(after: seconds, body: body)
    }

    public func cancelHeartRefill() {
        NotificationManager.cancelHeartRefill()
    }
}

public final class NoopNotificationScheduler: NotificationScheduling {
    public init() {}
    public func requestAuthorization() async -> Bool { false }
    public func scheduleDailyReminder(at time: ReminderTime, body: String) {}
    public func cancelDailyReminder() {}
    public func scheduleHeartRefill(after seconds: TimeInterval, body: String) {}
    public func cancelHeartRefill() {}
}
