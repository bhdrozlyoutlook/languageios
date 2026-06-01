import Foundation
#if canImport(AVFAudio)
import AVFAudio
#endif

/// Text-to-speech seam for pronouncing target-language words. Default impl uses
/// `AVSpeechSynthesizer`; tests/previews use the no-op.
public protocol SpeechService: AnyObject {
    func speak(_ text: String, language: TargetLanguage)
    func stop()
}

public final class NoopSpeechService: SpeechService {
    public init() {}
    public func speak(_ text: String, language: TargetLanguage) {}
    public func stop() {}
}

#if canImport(AVFAudio)
public final class AVSpeechService: SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public func speak(_ text: String, language: TargetLanguage) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: Self.bcp47(for: language))
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    private static func bcp47(for language: TargetLanguage) -> String {
        switch language {
        case .englishUS: "en-US"
        case .englishUK: "en-GB"
        case .german: "de-DE"
        case .spanish: "es-ES"
        case .french: "fr-FR"
        case .turkish: "tr-TR"
        }
    }
}
#endif
