import Foundation
import Observation

/// Runtime state for playing one lesson, with a hearts model: 3 hearts, lose one per
/// wrong graded answer, and the lesson fails at zero. Emits analytics throughout.
@Observable
public final class LessonSession {
    public enum Status: Equatable {
        case inProgress
        case passed
        case failed
    }

    public static let maxHearts = 3

    public let lesson: Lesson
    public private(set) var currentIndex: Int = 0
    public private(set) var hearts: Int
    public private(set) var correctCount: Int = 0
    public private(set) var status: Status = .inProgress

    @ObservationIgnored private let analytics: AnalyticsService

    public init(lesson: Lesson, analytics: AnalyticsService = NoopAnalyticsService()) {
        self.lesson = lesson
        self.hearts = Self.maxHearts
        self.analytics = analytics
        analytics.track(LessonAnalytics.started(stopId: lesson.stopId, language: lesson.language))
    }

    public var currentExercise: Exercise? {
        guard currentIndex < lesson.exercises.count else { return nil }
        return lesson.exercises[currentIndex]
    }

    public var progress: Double {
        guard !lesson.exercises.isEmpty else { return 0 }
        return Double(currentIndex) / Double(lesson.exercises.count)
    }

    /// Stars earned (1–3), based on hearts remaining when the lesson is passed.
    public var stars: Int { max(1, hearts) }

    /// Records the outcome of the current exercise and advances. Flashcards pass through
    /// without grading (always "correct").
    public func submit(correct: Bool) {
        guard status == .inProgress, let exercise = currentExercise else { return }

        if exercise.isGraded {
            analytics.track(LessonAnalytics.exerciseAnswered(
                stopId: lesson.stopId, kind: exercise.kind, correct: correct
            ))
            if correct {
                correctCount += 1
            } else {
                hearts -= 1
                if hearts <= 0 {
                    status = .failed
                    analytics.track(LessonAnalytics.failed(stopId: lesson.stopId))
                    return
                }
            }
        }
        advance()
    }

    private func advance() {
        if currentIndex + 1 >= lesson.exercises.count {
            status = .passed
            analytics.track(LessonAnalytics.completed(stopId: lesson.stopId, stars: stars, hearts: hearts))
        } else {
            currentIndex += 1
        }
    }

    public func restart() {
        currentIndex = 0
        hearts = Self.maxHearts
        correctCount = 0
        status = .inProgress
        analytics.track(LessonAnalytics.started(stopId: lesson.stopId, language: lesson.language))
    }
}
