import Foundation

/// Runtime access to API keys. Resolution order, first non-empty wins:
///   1. Process environment (handy for local dev / CI: `GEMINI_API_KEY=...`)
///   2. `Secrets.plist` bundled in the app (gitignored; the real keys live only here)
/// In SwiftPM tests there is no app bundle and usually no env var, so every key reads as
/// empty. Object recognition then returns no match instead of using a Vision fallback.
public enum Secrets {
    public static var geminiAPIKey: String { value(for: "GEMINI_API_KEY") }
    public static var elevenLabsAPIKey: String { value(for: "ELEVENLABS_API_KEY") }
    /// ElevenLabs voice id (override via `ELEVENLABS_VOICE_ID`). Defaults to a public
    /// multilingual voice (Rachel).
    public static var elevenLabsVoiceID: String {
        let id = value(for: "ELEVENLABS_VOICE_ID")
        return id.isEmpty ? "21m00Tcm4TlvDq8ikWAM" : id
    }
    /// RevenueCat public SDK key. When set (and the RevenueCat SPM package is added), the
    /// purchase seam uses RevenueCat instead of the local fake.
    public static var revenueCatAPIKey: String { value(for: "REVENUECAT_API_KEY") }

    /// Override the Gemini model from Secrets.plist (`GEMINI_MODEL`) without a code change —
    /// model availability/quota shifts (e.g. gemini-1.5-flash was retired, 2.0-flash has no
    /// free-tier quota). Defaults to gemini-2.5-flash.
    public static var geminiModel: String {
        let model = value(for: "GEMINI_MODEL")
        return model.isEmpty ? "gemini-2.5-flash" : model
    }

    public static func value(for key: String) -> String {
        if let env = ProcessInfo.processInfo.environment[key], !env.isEmpty {
            return env
        }
        if let bundled = plist[key], !bundled.isEmpty {
            return bundled
        }
        return ""
    }

    private static let plist: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else { return [:] }
        return dict
    }()
}
