import Foundation

/// A learnable phrase pulled from a song: the expression in the target language + its
/// Turkish gloss and a short usage note.
public struct LyricPhrase: Equatable, Identifiable {
    public let phrase: String   // target language
    public let native: String   // Turkish translation
    public let note: String?    // optional one-line usage note (Turkish)

    public var id: String { phrase }

    public init(phrase: String, native: String, note: String? = nil) {
        self.phrase = phrase
        self.native = native
        self.note = note
    }
}

/// The phrases extracted for a song/artist.
public struct LyricsAnalysis: Equatable {
    public let title: String
    public let artist: String
    public let phrases: [LyricPhrase]

    public init(title: String, artist: String, phrases: [LyricPhrase]) {
        self.title = title
        self.artist = artist
        self.phrases = phrases
    }
}

/// Turns a song into a handful of common everyday phrases to learn. The default is a small
/// on-device curated set; `GeminiLyricsProvider` swaps in for richer, song-aware results.
/// (We teach common phrases, not copyrighted lyrics.)
public protocol LyricsProviding: AnyObject {
    func phrases(title: String, artist: String, language: TargetLanguage) async -> LyricsAnalysis?
}

/// Deterministic offline fallback: a few common everyday phrases per language. Works before
/// any network/LLM is wired and as the fallback for `GeminiLyricsProvider`.
public final class StubLyricsProvider: LyricsProviding {
    public init() {}

    public func phrases(title: String, artist: String, language: TargetLanguage) async -> LyricsAnalysis? {
        let phrases = Self.starter(for: language)
        guard !phrases.isEmpty else { return nil }
        return LyricsAnalysis(
            title: title.isEmpty ? String(localized: "Şarkı") : title,
            artist: artist,
            phrases: phrases
        )
    }

    private static func starter(for language: TargetLanguage) -> [LyricPhrase] {
        switch language {
        case .englishUS, .englishUK:
            return [
                LyricPhrase(phrase: "I miss you", native: "Seni özlüyorum"),
                LyricPhrase(phrase: "hold me tight", native: "bana sıkıca sarıl"),
                LyricPhrase(phrase: "let it go", native: "bırak gitsin"),
                LyricPhrase(phrase: "all night long", native: "bütün gece boyunca"),
                LyricPhrase(phrase: "you and me", native: "sen ve ben"),
            ]
        case .german:
            return [
                LyricPhrase(phrase: "ich liebe dich", native: "seni seviyorum"),
                LyricPhrase(phrase: "für immer", native: "sonsuza dek"),
                LyricPhrase(phrase: "bleib bei mir", native: "yanımda kal"),
                LyricPhrase(phrase: "die ganze Nacht", native: "bütün gece"),
            ]
        case .spanish:
            return [
                LyricPhrase(phrase: "te quiero", native: "seni seviyorum"),
                LyricPhrase(phrase: "bésame", native: "öp beni"),
                LyricPhrase(phrase: "poco a poco", native: "azar azar"),
                LyricPhrase(phrase: "toda la noche", native: "bütün gece"),
            ]
        case .french:
            return [
                LyricPhrase(phrase: "je t'aime", native: "seni seviyorum"),
                LyricPhrase(phrase: "reste avec moi", native: "benimle kal"),
                LyricPhrase(phrase: "pour toujours", native: "sonsuza dek"),
                LyricPhrase(phrase: "toute la nuit", native: "bütün gece"),
            ]
        case .turkish:
            return [
                LyricPhrase(phrase: "seni seviyorum", native: "I love you"),
                LyricPhrase(phrase: "bana sarıl", native: "hold me"),
                LyricPhrase(phrase: "bütün gece", native: "all night"),
            ]
        }
    }
}
