import XCTest
@testable import LanguageIOS

final class GamificationTests: XCTestCase {

    private let day0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // MARK: XP & stars

    func testXpForPassFormula() {
        XCTAssertEqual(GamificationState.xpForPass(stars: 3), 25)
        XCTAssertEqual(GamificationState.xpForPass(stars: 1), 15)
    }

    func testRecordPassAddsXpAndKeepsBestStars() {
        var state = GamificationState()
        state.recordPass(stopId: "a", stars: 2, now: day0, calendar: utc)
        XCTAssertEqual(state.xp, 20)
        XCTAssertEqual(state.stars(for: "a"), 2)

        state.recordPass(stopId: "a", stars: 1, now: day0, calendar: utc)
        XCTAssertEqual(state.stars(for: "a"), 2, "keeps best stars")
        XCTAssertEqual(state.xp, 35, "xp still accrues on replay")
    }

    // MARK: Streak

    func testStreakStartsAtOne() {
        var state = GamificationState()
        state.recordPass(stopId: "a", stars: 1, now: day0, calendar: utc)
        XCTAssertEqual(state.streak, 1)
    }

    func testStreakSameDayDoesNotIncrement() {
        var state = GamificationState()
        state.recordPass(stopId: "a", stars: 1, now: day0, calendar: utc)
        state.recordPass(stopId: "b", stars: 1, now: day0.addingTimeInterval(3600), calendar: utc)
        XCTAssertEqual(state.streak, 1)
    }

    func testStreakConsecutiveDayIncrements() {
        var state = GamificationState()
        state.recordPass(stopId: "a", stars: 1, now: day0, calendar: utc)
        state.recordPass(stopId: "b", stars: 1, now: day0.addingTimeInterval(86400), calendar: utc)
        XCTAssertEqual(state.streak, 2)
    }

    func testStreakGapResetsToOne() {
        var state = GamificationState()
        state.recordPass(stopId: "a", stars: 1, now: day0, calendar: utc)
        state.recordPass(stopId: "b", stars: 1, now: day0.addingTimeInterval(3 * 86400), calendar: utc)
        XCTAssertEqual(state.streak, 1)
    }

    // MARK: Hearts

    func testHeartsStartFull() {
        XCTAssertEqual(GamificationState().availableHearts(now: day0), GamificationState.maxHearts)
    }

    func testLoseHeartDecrementsThenRefillsOverTime() {
        var state = GamificationState()
        state.loseHeart(now: day0)
        XCTAssertEqual(state.availableHearts(now: day0), GamificationState.maxHearts - 1)

        let later = day0.addingTimeInterval(GamificationState.heartRefillInterval + 1)
        XCTAssertEqual(state.availableHearts(now: later), GamificationState.maxHearts)
    }

    func testHeartsClampAtZero() {
        var state = GamificationState()
        for _ in 0..<(GamificationState.maxHearts + 2) {
            state.loseHeart(now: day0)
        }
        XCTAssertEqual(state.availableHearts(now: day0), 0)
    }

    func testSecondsUntilNextHeart() {
        var state = GamificationState()
        XCTAssertNil(state.secondsUntilNextHeart(now: day0), "full pool has no timer")
        state.loseHeart(now: day0)
        let seconds = try? XCTUnwrap(state.secondsUntilNextHeart(now: day0))
        XCTAssertEqual(seconds ?? 0, GamificationState.heartRefillInterval, accuracy: 1)
    }

    // MARK: Repository

    func testRepositoryRoundTrip() throws {
        let store = InMemoryKeyValueStore()
        let repo = UserDefaultsGamificationRepository(store: store, logger: NoopLogger())
        var state = GamificationState()
        state.recordPass(stopId: "x", stars: 3, now: day0, calendar: utc)
        state.loseHeart(now: day0)
        try repo.save(state)
        XCTAssertEqual(repo.load(), state)
    }

    func testRepositoryDefaultsWhenEmpty() {
        let repo = UserDefaultsGamificationRepository(store: InMemoryKeyValueStore(), logger: NoopLogger())
        XCTAssertEqual(repo.load(), GamificationState())
    }

    // MARK: AppStore integration

    func testStorePassUpdatesXpStarsStreakAndPersists() {
        let store = InMemoryKeyValueStore()
        let app = AppStore(environment: makeTestEnvironment(store: store))
        app.recordLessonPassed(stopId: "englishUS_california", stars: 3)

        XCTAssertEqual(app.xp, 25)
        XCTAssertEqual(app.stars(forStop: "englishUS_california"), 3)
        XCTAssertEqual(app.streak, 1)

        let restored = AppStore(environment: makeTestEnvironment(store: store))
        XCTAssertEqual(restored.xp, 25)
        XCTAssertEqual(restored.stars(forStop: "englishUS_california"), 3)
    }

    func testStoreFailDecrementsHearts() {
        let app = AppStore(environment: makeTestEnvironment())
        XCTAssertEqual(app.availableHearts(), GamificationState.maxHearts)
        app.recordLessonFailed()
        XCTAssertEqual(app.availableHearts(), GamificationState.maxHearts - 1)
        XCTAssertTrue(app.canStartLesson())
    }

    func testStoreEmitsGamificationAnalytics() {
        let spy = SpyAnalyticsService()
        let app = AppStore(environment: makeTestEnvironment(analytics: spy))
        app.recordLessonPassed(stopId: "a", stars: 2)
        XCTAssertTrue(spy.names.contains("xp_earned"))
        XCTAssertTrue(spy.names.contains("streak_extended"))
    }

    func testResetAllClearsGamification() {
        let store = InMemoryKeyValueStore()
        let app = AppStore(environment: makeTestEnvironment(store: store))
        app.recordLessonPassed(stopId: "a", stars: 3)
        app.resetAll()
        XCTAssertEqual(app.xp, 0)
        XCTAssertEqual(app.streak, 0)
        XCTAssertEqual(app.stars(forStop: "a"), 0)
    }
}
