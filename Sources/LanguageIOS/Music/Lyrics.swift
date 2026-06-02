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

/// Display-only metadata for the Apple Music-style learning player.
public struct LyricsNowPlayingDisplay: Equatable {
    public let title: String
    public let artist: String
    public let queueCountText: String
    public let progressFraction: Double

    public init(title: String, artist: String, selectedIndex: Int, phraseCount: Int) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let count = max(phraseCount, 0)

        self.title = trimmedTitle.isEmpty ? "Şarkı seç" : trimmedTitle
        self.artist = trimmedArtist.isEmpty ? "Sanatçı ekle" : trimmedArtist
        self.queueCountText = "\(count) kalıp"

        guard count > 0 else {
            self.progressFraction = 0
            return
        }

        let clampedIndex = min(max(selectedIndex, 0), count - 1)
        self.progressFraction = Double(clampedIndex + 1) / Double(count)
    }
}

/// Simulated synced-lyrics timing for learnable phrases. It does not represent a real song
/// timeline; it gives the Now Playing UI a karaoke-like flow without copyrighted lyrics.
public struct LyricsKaraokeTimeline: Equatable {
    public let phraseCount: Int
    public let phraseDuration: TimeInterval

    public var totalDuration: TimeInterval {
        TimeInterval(phraseCount) * phraseDuration
    }

    public init(phraseCount: Int, phraseDuration: TimeInterval = 3.2) {
        self.phraseCount = max(phraseCount, 0)
        self.phraseDuration = max(phraseDuration, 0.5)
    }

    public func index(at elapsed: TimeInterval) -> Int? {
        guard phraseCount > 0 else { return nil }
        let clampedElapsed = min(max(elapsed, 0), max(totalDuration - 0.001, 0))
        let rawIndex = Int(clampedElapsed / phraseDuration)
        return min(max(rawIndex, 0), phraseCount - 1)
    }

    public func progressFraction(at elapsed: TimeInterval) -> Double {
        guard totalDuration > 0 else { return 0 }
        return min(max(elapsed / totalDuration, 0), 1)
    }

    public func isFinished(at elapsed: TimeInterval) -> Bool {
        phraseCount == 0 || elapsed >= totalDuration
    }

    public func elapsedForPhrase(at index: Int) -> TimeInterval {
        guard phraseCount > 0 else { return 0 }
        let clampedIndex = min(max(index, 0), phraseCount - 1)
        return TimeInterval(clampedIndex) * phraseDuration
    }
}

/// Turns a song into a handful of common everyday phrases to learn. The default is a small
/// on-device curated set; `GeminiLyricsProvider` swaps in for richer, song-aware results.
/// (We teach common phrases, not copyrighted lyrics.)
public protocol LyricsProviding: AnyObject {
    /// `native` is the learner's own language — phrase translations come back in it.
    func phrases(title: String, artist: String, language: TargetLanguage, native: TargetLanguage) async -> LyricsAnalysis?
}

public extension LyricsProviding {
    func phrases(title: String, artist: String, language: TargetLanguage) async -> LyricsAnalysis? {
        await phrases(title: title, artist: artist, language: language, native: .turkish)
    }
}

/// Deterministic offline fallback: a few common everyday phrases per language. Works before
/// any network/LLM is wired and as the fallback for `GeminiLyricsProvider`.
public final class StubLyricsProvider: LyricsProviding {
    public init() {}

    public func phrases(title: String, artist: String, language: TargetLanguage, native: TargetLanguage) async -> LyricsAnalysis? {
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
