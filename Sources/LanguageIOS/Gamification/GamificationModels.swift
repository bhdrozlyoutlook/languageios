import Foundation

/// Persistent gamification state: XP, daily streak, per-stop best stars, and a global
/// hearts pool that depletes on lesson failure and refills over time. All time-dependent
/// logic takes an explicit `now` so it is deterministic and testable.
public struct GamificationState: Codable, Equatable {
    public var xp: Int
    public var streak: Int
    public var lastActiveDate: Date?
    public var starsByStop: [String: Int]
    public var hearts: Int
    /// Anchor for refill timing; `nil` means the pool is full (no timer running).
    public var heartsUpdatedAt: Date?

    public static let maxHearts = 5
    public static let heartRefillInterval: TimeInterval = 20 * 60 // 20 minutes

    public init(
        xp: Int = 0,
        streak: Int = 0,
        lastActiveDate: Date? = nil,
        starsByStop: [String: Int] = [:],
        hearts: Int = GamificationState.maxHearts,
        heartsUpdatedAt: Date? = nil
    ) {
        self.xp = xp
        self.streak = streak
        self.lastActiveDate = lastActiveDate
        self.starsByStop = starsByStop
        self.hearts = hearts
        self.heartsUpdatedAt = heartsUpdatedAt
    }

    /// XP awarded for passing a lesson with the given stars.
    public static func xpForPass(stars: Int) -> Int {
        10 + 5 * max(0, stars)
    }

    public func stars(for stopId: String) -> Int {
        starsByStop[stopId] ?? 0
    }

    // MARK: Hearts

    /// Hearts available right now, accounting for time-based refill.
    public func availableHearts(now: Date) -> Int {
        guard let anchor = heartsUpdatedAt else { return min(hearts, Self.maxHearts) }
        let elapsed = max(0, now.timeIntervalSince(anchor))
        let refilled = hearts + Int(elapsed / Self.heartRefillInterval)
        return min(Self.maxHearts, max(0, refilled))
    }

    /// Seconds until the next heart refills, or nil if the pool is already full.
    public func secondsUntilNextHeart(now: Date) -> TimeInterval? {
        guard let anchor = heartsUpdatedAt, availableHearts(now: now) < Self.maxHearts else { return nil }
        let elapsed = max(0, now.timeIntervalSince(anchor))
        let intoCurrent = elapsed.truncatingRemainder(dividingBy: Self.heartRefillInterval)
        return Self.heartRefillInterval - intoCurrent
    }

    /// Spends one heart (on lesson failure), reconciling refill first.
    public mutating func loseHeart(now: Date) {
        let current = availableHearts(now: now)
        hearts = max(0, current - 1)
        heartsUpdatedAt = now
    }

    // MARK: Passing a lesson

    public mutating func recordPass(stopId: String, stars: Int, now: Date, calendar: Calendar = .current) {
        starsByStop[stopId] = max(starsByStop[stopId] ?? 0, stars)
        xp += Self.xpForPass(stars: stars)
        updateStreak(now: now, calendar: calendar)
    }

    /// A practice/review session: awards XP and keeps the streak alive, but does not
    /// touch per-stop stars.
    public mutating func recordPractice(xpGain: Int, now: Date, calendar: Calendar = .current) {
        xp += max(0, xpGain)
        updateStreak(now: now, calendar: calendar)
    }

    private mutating func updateStreak(now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        guard let previous = lastActiveDate.map({ calendar.startOfDay(for: $0) }) else {
            streak = 1
            lastActiveDate = today
            return
        }
        let dayDelta = calendar.dateComponents([.day], from: previous, to: today).day ?? 0
        switch dayDelta {
        case 0:
            break // already counted today
        case 1:
            streak += 1
            lastActiveDate = today
        default:
            streak = 1
            lastActiveDate = today
        }
    }
}
