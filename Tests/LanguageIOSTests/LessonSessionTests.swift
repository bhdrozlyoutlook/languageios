import XCTest
@testable import LanguageIOS

final class LessonSessionTests: XCTestCase {

    /// A lesson of `graded` multiple-choice exercises (no flashcards) for precise control.
    private func makeLesson(graded: Int) -> Lesson {
        let items = (0..<4).map { VocabularyItem(id: "\($0)", target: "t\($0)", native: "n\($0)") }
        let exercises: [Exercise] = (0..<graded).map { index in
            let item = items[index % items.count]
            return .multipleChoice(prompt: item, options: [item.native, "x"], correct: item.native)
        }
        return Lesson(stopId: "s", language: .englishUS, items: items, exercises: exercises)
    }

    func testCorrectAnswersAdvanceToPassed() {
        let session = LessonSession(lesson: makeLesson(graded: 3))
        session.submit(correct: true)
        session.submit(correct: true)
        XCTAssertEqual(session.status, .inProgress)
        session.submit(correct: true)
        XCTAssertEqual(session.status, .passed)
        XCTAssertEqual(session.correctCount, 3)
        XCTAssertEqual(session.stars, 3)
    }

    func testWrongAnswersLoseHeartsAndFailAtZero() {
        let session = LessonSession(lesson: makeLesson(graded: 5))
        session.submit(correct: false)
        XCTAssertEqual(session.hearts, 2)
        session.submit(correct: false)
        XCTAssertEqual(session.hearts, 1)
        session.submit(correct: false)
        XCTAssertEqual(session.hearts, 0)
        XCTAssertEqual(session.status, .failed)
    }

    func testFailedSessionIgnoresFurtherSubmits() {
        let session = LessonSession(lesson: makeLesson(graded: 5))
        session.submit(correct: false)
        session.submit(correct: false)
        session.submit(correct: false) // fails here
        let indexAtFail = session.currentIndex
        session.submit(correct: true)
        XCTAssertEqual(session.status, .failed)
        XCTAssertEqual(session.currentIndex, indexAtFail)
    }

    func testRestartResetsState() {
        let session = LessonSession(lesson: makeLesson(graded: 3))
        session.submit(correct: false)
        session.restart()
        XCTAssertEqual(session.hearts, LessonSession.maxHearts)
        XCTAssertEqual(session.currentIndex, 0)
        XCTAssertEqual(session.status, .inProgress)
        XCTAssertEqual(session.correctCount, 0)
    }

    func testFlashcardsPassThroughWithoutCostingHearts() {
        let item = VocabularyItem(id: "1", target: "hi", native: "selam")
        let lesson = Lesson(
            stopId: "s",
            language: .englishUS,
            items: [item],
            exercises: [
                .flashcard(item),
                .multipleChoice(prompt: item, options: [item.native, "x"], correct: item.native)
            ]
        )
        let session = LessonSession(lesson: lesson)
        session.submit(correct: true) // flashcard -> not graded
        XCTAssertEqual(session.currentIndex, 1)
        XCTAssertEqual(session.hearts, LessonSession.maxHearts)
        session.submit(correct: false) // last exercise wrong -> heart lost, then passes
        XCTAssertEqual(session.hearts, 2)
        XCTAssertEqual(session.status, .passed)
    }

    func testEmitsStartedAnsweredAndCompletedEvents() {
        let spy = SpyAnalyticsService()
        let session = LessonSession(lesson: makeLesson(graded: 2), analytics: spy)
        session.submit(correct: true)
        session.submit(correct: true)
        XCTAssertTrue(spy.names.contains("lesson_started"))
        XCTAssertTrue(spy.names.contains("lesson_completed"))
        XCTAssertEqual(spy.events(named: "lesson_exercise_answered").count, 2)
    }
}
