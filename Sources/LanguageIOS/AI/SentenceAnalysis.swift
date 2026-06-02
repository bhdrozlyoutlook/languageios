import Foundation

/// Result of analyzing a learner's sentence.
public struct SentenceAnalysis: Equatable {
    public let original: String
    public let corrected: String
    public let isCorrect: Bool
    public let notes: [String]

    public init(original: String, corrected: String, isCorrect: Bool, notes: [String]) {
        self.original = original
        self.corrected = corrected
        self.isCorrect = isCorrect
        self.notes = notes
    }
}

/// Analyzes a sentence and returns corrections + short notes. The default is an on-device
/// heuristic stub; a real LLM adapter (OpenAI/Gemini) conforms to this and is swapped in
/// once an API key is available — no UI/call-site changes.
public protocol SentenceAnalyzing: AnyObject {
    /// `native` is the learner's own language — corrections are explained in it.
    func analyze(_ sentence: String, language: TargetLanguage, native: TargetLanguage) async -> SentenceAnalysis
}

public extension SentenceAnalyzing {
    func analyze(_ sentence: String, language: TargetLanguage) async -> SentenceAnalysis {
        await analyze(sentence, language: language, native: .turkish)
    }
}

/// Lightweight, deterministic stub: trims, capitalizes the first letter, and ensures
/// sentence-ending punctuation, noting what it changed. Placeholder until a real model
/// is wired in.
public final class HeuristicSentenceAnalyzer: SentenceAnalyzing {
    public init() {}

    public func analyze(_ sentence: String, language: TargetLanguage, native: TargetLanguage) async -> SentenceAnalysis {
        let original = sentence
        var corrected = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        var notes: [String] = []

        guard !corrected.isEmpty else {
            return SentenceAnalysis(original: original, corrected: original, isCorrect: true, notes: [])
        }

        if let first = corrected.first, first.isLowercase {
            corrected.replaceSubrange(corrected.startIndex...corrected.startIndex, with: String(first).uppercased())
            notes.append(String(localized: "Cümle büyük harfle başlamalı."))
        }

        if let last = corrected.last, !".!?".contains(last) {
            corrected.append(".")
            notes.append(String(localized: "Cümle sonuna noktalama ekledim."))
        }

        let isCorrect = corrected == original
        if isCorrect {
            notes.append(String(localized: "Cümlen iyi görünüyor. 👍"))
        }
        return SentenceAnalysis(original: original, corrected: corrected, isCorrect: isCorrect, notes: notes)
    }
}
