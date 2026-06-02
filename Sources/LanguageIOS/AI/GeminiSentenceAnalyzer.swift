import Foundation

/// LLM-backed `SentenceAnalyzing` using Gemini. Asks the model to correct a learner's
/// sentence and explain the changes in Turkish. Falls back to the on-device heuristic on
/// any network/parse error so the feature still works offline.
public final class GeminiSentenceAnalyzer: SentenceAnalyzing {
    private let client: GeminiClient
    private let fallback: SentenceAnalyzing

    public init(client: GeminiClient, fallback: SentenceAnalyzing = HeuristicSentenceAnalyzer()) {
        self.client = client
        self.fallback = fallback
    }

    public convenience init(apiKey: String, model: String = "gemini-2.5-flash", fallback: SentenceAnalyzing = HeuristicSentenceAnalyzer()) {
        self.init(client: GeminiClient(apiKey: apiKey, model: model), fallback: fallback)
    }

    public func analyze(_ sentence: String, language: TargetLanguage, native: TargetLanguage) async -> SentenceAnalysis {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SentenceAnalysis(original: sentence, corrected: sentence, isCorrect: true, notes: [])
        }
        do {
            let text = try await client.generate(prompt: Self.prompt(sentence: trimmed, language: language, native: native))
            if let analysis = Self.parse(text, original: sentence) { return analysis }
            return await fallback.analyze(sentence, language: language, native: native)
        } catch {
            return await fallback.analyze(sentence, language: language, native: native)
        }
    }

    static func prompt(sentence: String, language: TargetLanguage, native: TargetLanguage) -> String {
        """
        A \(native.englishName) speaker is learning \(language.englishName). Correct their \
        sentence and briefly explain each fix in \(native.englishName).
        Sentence: "\(sentence)"
        Respond ONLY with JSON, no markdown:
        {"corrected": "<corrected sentence>", "isCorrect": <true if no change needed>, \
        "notes": ["<short explanation in \(native.englishName)>", ...]}
        """
    }

    static func parse(_ text: String, original: String) -> SentenceAnalysis? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let corrected = obj["corrected"] as? String else {
            return nil
        }
        let isCorrect = (obj["isCorrect"] as? Bool) ?? (corrected == original)
        let notes = (obj["notes"] as? [String]) ?? []
        return SentenceAnalysis(original: original, corrected: corrected, isCorrect: isCorrect, notes: notes)
    }
}
