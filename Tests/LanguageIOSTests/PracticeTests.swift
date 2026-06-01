import XCTest
@testable import LanguageIOS

final class PracticeTests: XCTestCase {

    func testReviewBuildsLessonFromCompletedStops() throws {
        let stops = Array(LearningJourney.journey(for: .englishUS).stops.prefix(2)) // california, oregon
        let lesson = try XCTUnwrap(LessonBuilder.review(language: .englishUS, completedStops: stops))

        XCTAssertEqual(lesson.stopId, "review_englishUS")
        XCTAssertTrue((2...6).contains(lesson.items.count))
        XCTAssertFalse(lesson.exercises.isEmpty)

        let allowed = Set(stops.flatMap {
            LessonContent.items(forStopId: $0.id, language: .englishUS).map(\.id)
        })
        XCTAssertTrue(lesson.items.allSatisfy { allowed.contains($0.id) })
    }

    func testReviewReturnsNilWithoutCompletedStops() {
        XCTAssertNil(LessonBuilder.review(language: .englishUS, completedStops: []))
    }

    func testRecordPracticeAddsXpExtendsStreakAndLeavesStarsUntouched() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        var state = GamificationState()
        state.recordPractice(xpGain: 15, now: now)
        XCTAssertEqual(state.xp, 15)
        XCTAssertEqual(state.streak, 1)
        XCTAssertTrue(state.starsByStop.isEmpty)
    }

    func testStorePracticeAwardsXpAndEmitsAnalytics() {
        let spy = SpyAnalyticsService()
        let app = AppStore(environment: makeTestEnvironment(analytics: spy))
        app.recordPracticeCompleted(stars: 3) // 5 + 5*3 = 20
        XCTAssertEqual(app.xp, 20)
        XCTAssertTrue(spy.names.contains("xp_earned"))
    }

    func testPracticeDoesNotConsumeHearts() {
        let app = AppStore(environment: makeTestEnvironment())
        XCTAssertEqual(app.availableHearts(), GamificationState.maxHearts)
        app.recordPracticeCompleted(stars: 2)
        XCTAssertEqual(app.availableHearts(), GamificationState.maxHearts)
    }
}
