import Foundation

/// Turns a map stop into a playable `Lesson`. Deterministic (no randomness) so the
/// output is testable; views shuffle option positions at display time.
enum LessonBuilder {
    static let optionCount = 4

    static func build(for stop: LearningStop, language: TargetLanguage) -> Lesson {
        let items = LessonContent.items(forStopId: stop.id, language: language)
        return Lesson(
            stopId: stop.id,
            language: language,
            items: items,
            exercises: makeExercises(items)
        )
    }

    static func makeExercises(_ items: [VocabularyItem]) -> [Exercise] {
        guard !items.isEmpty else { return [] }

        var exercises: [Exercise] = []

        // 1) Introduce every word with a flashcard.
        for item in items {
            exercises.append(.flashcard(item))
        }

        // 2) Grade each word once, rotating through the three single-answer types.
        for (index, item) in items.enumerated() {
            let others = items.filter { $0.id != item.id }
            switch index % 3 {
            case 0:
                exercises.append(.multipleChoice(
                    prompt: item,
                    options: options(correct: item.native, from: others.map(\.native)),
                    correct: item.native
                ))
            case 1:
                exercises.append(.typeAnswer(item))
            default:
                exercises.append(.listenSelect(
                    prompt: item,
                    options: options(correct: item.target, from: others.map(\.target)),
                    correct: item.target
                ))
            }
        }

        // 3) Finish with one matching round over the first few words.
        if items.count >= 2 {
            exercises.append(.matching(Array(items.prefix(optionCount))))
        }

        return exercises
    }

    /// Correct answer first (deterministic), followed by distinct distractors.
    private static func options(correct: String, from pool: [String]) -> [String] {
        var result = [correct]
        for candidate in pool where result.count < optionCount {
            if !result.contains(candidate) {
                result.append(candidate)
            }
        }
        return result
    }
}
