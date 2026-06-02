import XCTest
@testable import LanguageIOS

final class LessonEngineTests: XCTestCase {

    private func californiaLesson() -> Lesson {
        let stop = LearningJourney.journey(for: .englishUS).stops[0]
        return LessonBuilder.build(for: stop, language: .englishUS)
    }

    // MARK: Builder

    func testBuildsAFlashcardForEveryItemPlusGradedExercises() {
        let lesson = californiaLesson()
        XCTAssertFalse(lesson.items.isEmpty)
        let flashcards = lesson.exercises.filter { $0.kind == .flashcard }
        XCTAssertEqual(flashcards.count, lesson.items.count)
        XCTAssertGreaterThan(lesson.gradedCount, 0)
    }

    func testChoiceExercisesContainCorrectAnswerAndUniqueOptions() {
        let lesson = californiaLesson()
        for exercise in lesson.exercises {
            switch exercise {
            case let .multipleChoice(_, options, correct), let .listenSelect(_, options, correct):
                XCTAssertTrue(options.contains(correct))
                XCTAssertGreaterThanOrEqual(options.count, 2)
                XCTAssertLessThanOrEqual(options.count, LessonBuilder.optionCount)
                XCTAssertEqual(Set(options).count, options.count)
            default:
                break
            }
        }
    }

    func testTypeAnswerExpectsTargetAndMatchesForgivingly() {
        let item = VocabularyItem(id: "x", target: "hello", native: "merhaba")
        XCTAssertEqual(Exercise.typeAnswer(item).correctAnswer, "hello")
        XCTAssertTrue(Exercise.answersMatch("  Hello ", "hello"))
        XCTAssertTrue(Exercise.answersMatch("café", "cafe"))
        XCTAssertFalse(Exercise.answersMatch("dog", "cat"))
    }

    func testLessonEndsWithAMatchingRound() {
        let lesson = californiaLesson()
        let matching = lesson.exercises.first { if case .matching = $0 { return true } else { return false } }
        XCTAssertNotNil(matching)
        if case let .matching(group)? = matching {
            XCTAssertTrue((2...LessonBuilder.optionCount).contains(group.count))
        }
    }

    // MARK: Content coverage

    func testEveryUSStopProducesAPlayableLesson() {
        for stop in LearningJourney.journey(for: .englishUS).stops {
            let lesson = LessonBuilder.build(for: stop, language: .englishUS)
            XCTAssertFalse(lesson.items.isEmpty, "\(stop.id)")
            XCTAssertFalse(lesson.exercises.isEmpty, "\(stop.id)")
            XCTAssertGreaterThan(lesson.gradedCount, 0, "\(stop.id)")
        }
    }

    func testEveryLanguageHasAStarterBank() {
        for language in TargetLanguage.allCases {
            let bank = LessonContent.starterBank(for: language)
            XCTAssertGreaterThanOrEqual(bank.count, 4, "\(language)")
            XCTAssertEqual(Set(bank.map(\.id)).count, bank.count, "\(language)")
        }
    }

    func testAuthoredStopsUseAuthoredContent() {
        let lesson = californiaLesson()
        XCTAssertTrue(lesson.items.contains { $0.target == "hello" && $0.native == "merhaba" })
    }

    func testUnauthoredStopFallsBackToLanguageBank() {
        // A later German stop has no authored content → uses the starter bank.
        let stop = LearningJourney.journey(for: .german).stops[5]
        let lesson = LessonBuilder.build(for: stop, language: .german)
        XCTAssertTrue(lesson.items.contains { $0.id == "de_starter_0" })
    }

    func testExpandedAuthoredStopsAreAvailable() {
        XCTAssertEqual(
            LessonContent.items(forStopId: "englishUS_arizona", language: .englishUS).first?.target,
            "left"
        )
        XCTAssertTrue(
            LessonContent.items(forStopId: "german_berlin", language: .german).contains { $0.target == "was" }
        )
        XCTAssertTrue(
            LessonContent.items(forStopId: "french_marseille", language: .french).contains { $0.target == "quoi" }
        )
    }

    func testAuthoredContentCoversEveryLanguageFirstStop() {
        let firstWords: [TargetLanguage: String] = [
            .englishUS: "hello", .englishUK: "hello", .german: "hallo",
            .spanish: "hola", .french: "bonjour", .turkish: "merhaba"
        ]
        for (language, word) in firstWords {
            let stop = LearningJourney.journey(for: language).stops[0]
            let lesson = LessonBuilder.build(for: stop, language: language)
            XCTAssertTrue(
                lesson.items.contains { $0.target == word },
                "\(language) first stop should use authored content containing '\(word)'"
            )
        }
    }
}
