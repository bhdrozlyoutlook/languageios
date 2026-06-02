import Foundation

/// Gemini-backed lyrics phrases: asks the model for common everyday phrases associated with
/// a song/artist (NOT the copyrighted lyrics themselves) plus Turkish translations and notes.
/// Falls back to the on-device starter set on any error.
public final class GeminiLyricsProvider: LyricsProviding {
    private let client: GeminiClient
    private let fallback: LyricsProviding

    public init(client: GeminiClient, fallback: LyricsProviding = StubLyricsProvider()) {
        self.client = client
        self.fallback = fallback
    }

    public convenience init(apiKey: String, model: String = "gemini-2.5-flash", fallback: LyricsProviding = StubLyricsProvider()) {
        self.init(client: GeminiClient(apiKey: apiKey, model: model), fallback: fallback)
    }

    public func phrases(title: String, artist: String, language: TargetLanguage, native: TargetLanguage) async -> LyricsAnalysis? {
        do {
            let text = try await client.generate(prompt: Self.prompt(title: title, artist: artist, language: language, native: native))
            if let phrases = Self.parse(text), !phrases.isEmpty {
                return LyricsAnalysis(title: title, artist: artist, phrases: phrases)
            }
            return await fallback.phrases(title: title, artist: artist, language: language, native: native)
        } catch {
            return await fallback.phrases(title: title, artist: artist, language: language, native: native)
        }
    }

    static func prompt(title: String, artist: String, language: TargetLanguage, native: TargetLanguage) -> String {
        let song = title.isEmpty ? "popular songs" : "the song \"\(title)\""
        let by = artist.isEmpty ? "" : " by \(artist)"
        return """
        A \(native.englishName) speaker is learning \(language.englishName). Without reproducing
        any copyrighted lyrics, list 6 short, common everyday phrases or expressions in
        \(language.englishName) of the kind that appear in \(song)\(by). For each give a brief
        \(native.englishName) translation and a one-line usage note in \(native.englishName).
        Respond ONLY with JSON, no markdown:
        {"phrases":[{"phrase":"<phrase in \(language.englishName)>","native":"<\(native.englishName)>","note":"<short note in \(native.englishName)>"}]}
        """
    }

    static func parse(_ text: String) -> [LyricPhrase]? {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawPhrases = obj["phrases"] as? [[String: Any]] else {
            return nil
        }
        let phrases: [LyricPhrase] = rawPhrases.compactMap { item in
            guard let phrase = (item["phrase"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !phrase.isEmpty else { return nil }
            let native = (item["native"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let note = (item["note"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return LyricPhrase(phrase: phrase, native: native, note: (note?.isEmpty == false) ? note : nil)
        }
        return phrases.isEmpty ? nil : phrases
    }
}
