import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Natural-voice TTS via ElevenLabs. Streams the synthesized audio and plays it; on a
/// missing key, network error, or non-iOS platform it falls back to the on-device
/// `AVSpeechService`, so speaking always works. Activated from `AppEnvironment.live()` when
/// `ELEVENLABS_API_KEY` is set.
public final class ElevenLabsSpeechService: SpeechService {
    private let apiKey: String
    private let voiceID: String
    private let modelID: String
    private let session: URLSession
    private let fallback: SpeechService

    private var currentTask: Task<Void, Never>?
    #if canImport(AVFoundation)
    private var player: AVAudioPlayer?
    #endif

    public init(
        apiKey: String,
        voiceID: String,
        modelID: String = "eleven_multilingual_v2",
        session: URLSession = .shared,
        fallback: SpeechService = NoopSpeechService()
    ) {
        self.apiKey = apiKey
        self.voiceID = voiceID
        self.modelID = modelID
        self.session = session
        self.fallback = fallback
    }

    public func speak(_ text: String, language: TargetLanguage) {
        stop()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        currentTask = Task { [weak self] in
            guard let self else { return }
            if let data = await self.synthesize(trimmed), !Task.isCancelled {
                await MainActor.run { self.play(data, fallbackText: trimmed, language: language) }
            } else if !Task.isCancelled {
                await MainActor.run { self.fallback.speak(trimmed, language: language) }
            }
        }
    }

    public func stop() {
        currentTask?.cancel()
        currentTask = nil
        fallback.stop()
        #if canImport(AVFoundation)
        player?.stop()
        player = nil
        #endif
    }

    /// Returns MP3 audio for the text, or nil on any failure (caller falls back).
    func synthesize(_ text: String) async -> Data? {
        guard !apiKey.isEmpty,
              let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceID)") else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        let body: [String: Any] = [
            "text": text,
            "model_id": modelID,
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.75],
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              !data.isEmpty else {
            return nil
        }
        return data
    }

    private func play(_ data: Data, fallbackText: String, language: TargetLanguage) {
        #if canImport(AVFoundation)
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            let player = try AVAudioPlayer(data: data)
            self.player = player
            player.play()
        } catch {
            fallback.speak(fallbackText, language: language)
        }
        #else
        fallback.speak(fallbackText, language: language)
        #endif
    }
}
