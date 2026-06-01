import Foundation

/// One vocabulary pair: a word/phrase in the language being learned plus its native gloss.
/// Content is authored as `target` ↔ Turkish `native`.
public struct VocabularyItem: Codable, Hashable, Identifiable {
    public let id: String
    public let target: String
    public let native: String
    public let example: String?

    public init(id: String, target: String, native: String, example: String? = nil) {
        self.id = id
        self.target = target
        self.native = native
        self.example = example
    }
}

public enum ExerciseKind: String {
    case flashcard
    case multipleChoice
    case matching
    case typeAnswer
    case listenSelect
}

/// A single step in a lesson. Flashcards introduce a word; the rest are graded.
public enum Exercise: Equatable {
    case flashcard(VocabularyItem)
    case multipleChoice(prompt: VocabularyItem, options: [String], correct: String)
    case matching([VocabularyItem])
    case typeAnswer(VocabularyItem)
    case listenSelect(prompt: VocabularyItem, options: [String], correct: String)

    public var kind: ExerciseKind {
        switch self {
        case .flashcard: .flashcard
        case .multipleChoice: .multipleChoice
        case .matching: .matching
        case .typeAnswer: .typeAnswer
        case .listenSelect: .listenSelect
        }
    }

    /// Flashcards are informational; everything else costs a heart when wrong.
    public var isGraded: Bool {
        kind != .flashcard
    }

    /// The expected answer for single-answer exercises (nil for flashcard/matching).
    public var correctAnswer: String? {
        switch self {
        case .multipleChoice(_, _, let correct): correct
        case .listenSelect(_, _, let correct): correct
        case .typeAnswer(let item): item.target
        case .flashcard, .matching: nil
        }
    }

    /// Forgiving comparison: case- and diacritic-insensitive, trimmed.
    public static func answersMatch(_ lhs: String, _ rhs: String) -> Bool {
        func normalize(_ text: String) -> String {
            text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalize(lhs) == normalize(rhs)
    }
}

/// A full lesson behind one map stop: the vocabulary plus the ordered exercise sequence.
public struct Lesson: Equatable {
    public let stopId: String
    public let language: TargetLanguage
    public let items: [VocabularyItem]
    public let exercises: [Exercise]

    public init(stopId: String, language: TargetLanguage, items: [VocabularyItem], exercises: [Exercise]) {
        self.stopId = stopId
        self.language = language
        self.items = items
        self.exercises = exercises
    }

    public var gradedCount: Int { exercises.filter(\.isGraded).count }
}
