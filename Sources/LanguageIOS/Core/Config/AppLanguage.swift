import Foundation
import ObjectiveC

/// Switches the app's UI language at runtime to the learner's native language (chosen in
/// onboarding), so all `String(localized:)` / `Text` lookups resolve against that language's
/// `.lproj` instead of always the Turkish base. Missing keys/languages fall back to the base.
public enum AppLanguage {
    /// Applies the native language's localization. No-op when nil or already correct.
    public static func apply(_ nativeLanguage: TargetLanguage?) {
        guard let code = nativeLanguage?.localeCode else { return }
        Bundle.setLanguage(code)
    }
}

public extension TargetLanguage {
    /// ISO code of the matching `.lproj` (both English variants share `en`).
    var localeCode: String {
        switch self {
        case .turkish: "tr"
        case .englishUS, .englishUK: "en"
        case .german: "de"
        case .spanish: "es"
        case .french: "fr"
        }
    }
}

// MARK: - Runtime bundle language override

private var languageBundleKey: UInt8 = 0

/// A `Bundle` subclass that redirects localized-string lookups to a chosen `.lproj`.
private final class AnyLanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = objc_getAssociatedObject(self, &languageBundleKey) as? String,
              let bundle = Bundle(path: path) else {
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return bundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// Points `Bundle.main` at the given language's `.lproj` for all future lookups. If that
    /// `.lproj` doesn't exist yet, lookups fall through to the base localization.
    static func setLanguage(_ code: String) {
        object_setClass(Bundle.main, AnyLanguageBundle.self)
        let path = Bundle.main.path(forResource: code, ofType: "lproj")
        objc_setAssociatedObject(Bundle.main, &languageBundleKey, path, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
