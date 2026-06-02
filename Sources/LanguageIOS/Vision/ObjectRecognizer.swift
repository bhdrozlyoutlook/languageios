import Foundation

/// A recognized object turned into a learnable word.
public struct ObjectRecognition: Equatable {
    public let word: String      // object name in the target language
    public let native: String    // Turkish translation
    public let english: String   // English name (used for TTS / collection key)

    public init(word: String, native: String, english: String) {
        self.word = word
        self.native = native
        self.english = english
    }
}

/// Recognizes the main object in a captured image and returns its word in the target
/// language + Turkish translation. The default is on-device (Apple Vision + a small
/// dictionary); `GeminiObjectRecognizer` swaps in once a key is configured.
public protocol ObjectRecognizing: AnyObject {
    func recognize(_ imageData: Data, target: TargetLanguage, native: TargetLanguage) async -> ObjectRecognition?
}

/// Defers recognizer construction until the user actually opens camera/object capture.
/// This keeps launch from paying Vision/Gemini setup costs before the first screen.
public actor LazyObjectRecognizer: ObjectRecognizing {
    private let makeRecognizer: @Sendable () -> ObjectRecognizing
    private var cached: ObjectRecognizing?

    public init(_ makeRecognizer: @escaping @Sendable () -> ObjectRecognizing) {
        self.makeRecognizer = makeRecognizer
    }

    public func recognize(_ imageData: Data, target: TargetLanguage, native: TargetLanguage) async -> ObjectRecognition? {
        let recognizer: ObjectRecognizing
        if let cached {
            recognizer = cached
        } else {
            recognizer = makeRecognizer()
            cached = recognizer
        }
        return await recognizer.recognize(imageData, target: target, native: native)
    }
}

/// On-device recognizer: Apple's Vision classifier + the built-in English→Turkish
/// vocabulary. Target-language words are limited to English (the dictionary's language),
/// so it doubles as the offline fallback for `GeminiObjectRecognizer`.
public final class OnDeviceObjectRecognizer: ObjectRecognizing {
    private let classifier: ImageClassifying

    public init(classifier: ImageClassifying = VisionImageClassifier()) {
        self.classifier = classifier
    }

    public func recognize(_ imageData: Data, target: TargetLanguage, native: TargetLanguage) async -> ObjectRecognition? {
        let labels = await classifier.classify(imageData)
        guard let best = ObjectVocabulary.bestMatch(in: labels) else { return nil }
        return ObjectRecognition(word: best.english, native: best.turkish, english: best.english)
    }
}

/// Keeps common English object capture instant by trying the on-device classifier before
/// the network recognizer. Non-English targets still prefer the remote recognizer so the
/// displayed word can be in the selected learning language.
public final class FastObjectRecognizer: ObjectRecognizing {
    private let local: ObjectRecognizing
    private let remote: ObjectRecognizing?

    public init(local: ObjectRecognizing = OnDeviceObjectRecognizer(), remote: ObjectRecognizing?) {
        self.local = local
        self.remote = remote
    }

    public func recognize(_ imageData: Data, target: TargetLanguage, native: TargetLanguage) async -> ObjectRecognition? {
        if target.usesEnglishObjectVocabulary, let localResult = await local.recognize(imageData, target: target, native: native) {
            return localResult
        }
        if let remoteResult = await remote?.recognize(imageData, target: target, native: native) {
            return remoteResult
        }
        return await local.recognize(imageData, target: target, native: native)
    }
}

/// Gemini-backed recognizer: sends the image to a multimodal model and asks for the object
/// in the target language + Turkish gloss. Falls back to `fallback` (on-device) on any
/// network/parse error so capture keeps working offline.
public final class GeminiObjectRecognizer: ObjectRecognizing {
    private let client: GeminiClient
    private let fallback: ObjectRecognizing?

    public init(client: GeminiClient, fallback: ObjectRecognizing? = OnDeviceObjectRecognizer()) {
        self.client = client
        self.fallback = fallback
    }

    public convenience init(apiKey: String, fallback: ObjectRecognizing? = OnDeviceObjectRecognizer()) {
        self.init(client: GeminiClient(apiKey: apiKey), fallback: fallback)
    }

    public func recognize(_ imageData: Data, target: TargetLanguage, native: TargetLanguage) async -> ObjectRecognition? {
        let prompt = Self.prompt(target: target, native: native)
        do {
            let text = try await client.generate(prompt: prompt, imageData: imageData)
            if let recognition = Self.parse(text) { return recognition }
            return await fallback?.recognize(imageData, target: target, native: native)
        } catch {
            return await fallback?.recognize(imageData, target: target, native: native)
        }
    }

    static func prompt(target: TargetLanguage, native: TargetLanguage) -> String {
        """
        Identify the single main physical object in this photo. It may have been cut out \
        and placed on a plain white background — if so, name that object. Otherwise pick the \
        most prominent object near the centre and ignore the background and surroundings. \
        Teach it to a \(native.englishName) speaker learning \(target.englishName).
        Respond ONLY with a JSON object, no markdown, using lowercase singular nouns:
        {"word": "<object's name in \(target.englishName)>", \
        "english": "<object's name in English>", \
        "native": "<object's name in \(native.englishName)>"}
        If there is no clear object, respond {"word": ""}.
        """
    }

    static func parse(_ text: String) -> ObjectRecognition? {
        // Models occasionally wrap JSON in ```json fences — strip them.
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let word = (obj["word"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !word.isEmpty else {
            return nil
        }
        let english = (obj["english"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let native = (obj["native"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ObjectRecognition(
            word: word,
            native: native?.isEmpty == false ? native! : word,
            english: english?.isEmpty == false ? english! : word
        )
    }
}

extension TargetLanguage {
    /// English-language name of the language for model prompts. Distinguishes American vs
    /// British English so recognized words use the right regional vocabulary (e.g.
    /// "elevator" vs "lift", "trunk" vs "boot").
    var englishName: String {
        switch self {
        case .englishUS: "American English"
        case .englishUK: "British English"
        case .turkish: "Turkish"
        case .german: "German"
        case .spanish: "Spanish"
        case .french: "French"
        }
    }

    fileprivate var usesEnglishObjectVocabulary: Bool {
        self == .englishUS || self == .englishUK
    }
}
