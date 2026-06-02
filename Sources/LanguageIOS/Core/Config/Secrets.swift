import Foundation

/// Runtime access to API keys. Resolution order, first non-empty wins:
///   1. Process environment (handy for local dev / CI: `GEMINI_API_KEY=...`)
///   2. `Secrets.plist` bundled in the app (gitignored; the real keys live only here)
/// In SwiftPM tests there is no app bundle and usually no env var, so every key reads as
/// empty — adapters then fall back to their on-device/stub implementation.
public enum Secrets {
    public static var geminiAPIKey: String { value(for: "GEMINI_API_KEY") }
    public static var elevenLabsAPIKey: String { value(for: "ELEVENLABS_API_KEY") }

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
