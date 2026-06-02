import XCTest
@testable import LanguageIOS

final class SpacedRepetitionTests: XCTestCase {

    func testRecordWordResultTracksAndClearsMissedWords() {
        var state = GamificationState()
        state.recordWordResult(wordId: "w1", correct: false)
        XCTAssertTrue(state.needsReview("w1"))

        state.recordWordResult(wordId: "w1", correct: true)
        XCTAssertFalse(state.needsReview("w1"))
    }

    func testLegacyGamificationStateDecodesWithoutMissedWords() throws {
        // JSON that predates the missedWordIds field.
        let json = Data(#"{"xp":50,"streak":3,"starsByStop":{"a":2},"hearts":5}"#.utf8)
        let state = try JSONDecoder().decode(GamificationState.self, from: json)
        XCTAssertEqual(state.xp, 50)
        XCTAssertEqual(state.streak, 3)
        XCTAssertEqual(state.stars(for: "a"), 2)
        XCTAssertTrue(state.missedWordIds.isEmpty)
    }

    func testSessionReportsMissedWordOnWrongGradedAnswer() {
        let item = VocabularyItem(id: "w1", target: "t", native: "n")
        let lesson = Lesson(
            stopId: "s", language: .englishUS, items: [item],
            exercises: [.multipleChoice(prompt: item, options: [item.native, "x"], correct: item.native)]
        )
        var reported: [(id: String, correct: Bool)] = []
        let session = LessonSession(lesson: lesson, onWordResult: { reported.append(($0.id, $1)) })

        session.submit(correct: false)

        XCTAssertEqual(reported.count, 1)
        XCTAssertEqual(reported.first?.id, "w1")
        XCTAssertEqual(reported.first?.correct, false)
    }

    func testReviewPrioritizesMissedWords() throws {
        let stops = Array(LearningJourney.journey(for: .englishUS).stops.prefix(2))
        let allItems = stops.flatMap { LessonContent.items(forStopId: $0.id, language: .englishUS) }
        let target = try XCTUnwrap(allItems.last).id

        let lesson = try XCTUnwrap(
            LessonBuilder.review(language: .englishUS, completedStops: stops, prioritized: [target], limit: 3)
        )
        XCTAssertTrue(
            lesson.items.contains { $0.id == target },
            "a prioritized word should be included even with a small limit"
        )
    }

    func testStoreRecordWordResultPersists() {
        let store = InMemoryKeyValueStore()
        let app = AppStore(environment: makeTestEnvironment(store: store))
        app.recordWordResult(wordId: "w9", correct: false)
        XCTAssertTrue(app.missedWordIds.contains("w9"))

        let restored = AppStore(environment: makeTestEnvironment(store: store))
        XCTAssertTrue(restored.missedWordIds.contains("w9"))
    }
}
