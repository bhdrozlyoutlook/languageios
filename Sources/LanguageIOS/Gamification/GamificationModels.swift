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
    /// Word ids the user got wrong; review prioritizes these (spaced repetition).
    public var missedWordIds: Set<String>
    /// Lessons/practices completed today, toward the daily goal. Resets each new day.
    public var activitiesToday: Int

    public static let maxHearts = 5
    public static let heartRefillInterval: TimeInterval = 20 * 60 // 20 minutes

    public init(
        xp: Int = 0,
        streak: Int = 0,
        lastActiveDate: Date? = nil,
        starsByStop: [String: Int] = [:],
        hearts: Int = GamificationState.maxHearts,
        heartsUpdatedAt: Date? = nil,
        missedWordIds: Set<String> = [],
        activitiesToday: Int = 0
    ) {
        self.xp = xp
        self.streak = streak
        self.lastActiveDate = lastActiveDate
        self.starsByStop = starsByStop
        self.hearts = hearts
        self.heartsUpdatedAt = heartsUpdatedAt
        self.missedWordIds = missedWordIds
        self.activitiesToday = activitiesToday
    }

    // Backward-compatible decoding: `missedWordIds` is optional in stored data so older
    // saved state keeps loading (other fields predate this and are always present).
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        xp = try container.decode(Int.self, forKey: .xp)
        streak = try container.decode(Int.self, forKey: .streak)
        lastActiveDate = try container.decodeIfPresent(Date.self, forKey: .lastActiveDate)
        starsByStop = try container.decode([String: Int].self, forKey: .starsByStop)
        hearts = try container.decode(Int.self, forKey: .hearts)
        heartsUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .heartsUpdatedAt)
        missedWordIds = try container.decodeIfPresent(Set<String>.self, forKey: .missedWordIds) ?? []
        activitiesToday = try container.decodeIfPresent(Int.self, forKey: .activitiesToday) ?? 0
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
        registerDailyActivity(now: now, calendar: calendar)
    }

    /// A practice/review session: awards XP and keeps the streak alive, but does not
    /// touch per-stop stars.
    public mutating func recordPractice(xpGain: Int, now: Date, calendar: Calendar = .current) {
        xp += max(0, xpGain)
        registerDailyActivity(now: now, calendar: calendar)
    }

    // MARK: Spaced repetition

    public mutating func recordWordResult(wordId: String, correct: Bool) {
        if correct {
            missedWordIds.remove(wordId)
        } else {
            missedWordIds.insert(wordId)
        }
    }

    public func needsReview(_ wordId: String) -> Bool {
        missedWordIds.contains(wordId)
    }

    /// Updates streak and the daily activity counter for one completed lesson/practice.
    private mutating func registerDailyActivity(now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        let previous = lastActiveDate.map { calendar.startOfDay(for: $0) }

        if previous != today {
            // First activity of a new day: roll the streak and reset today's counter.
            if let previous {
                let dayDelta = calendar.dateComponents([.day], from: previous, to: today).day ?? 0
                streak = (dayDelta == 1) ? streak + 1 : 1
            } else {
                streak = 1
            }
            activitiesToday = 0
            lastActiveDate = today
        }
        activitiesToday += 1
    }
}
