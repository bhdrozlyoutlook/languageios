import Foundation

/// A word the user captured with the camera: the recognized English label, its native
/// translation, the language being learned, and when it was captured. The cutout image
/// itself is stored separately (by `id`) in an `ImageBlobStore` so metadata stays small.
public struct CapturedObject: Codable, Equatable, Identifiable {
    public let id: String
    public let english: String
    public let native: String
    public let language: TargetLanguage
    public let capturedAt: Date

    public init(
        id: String,
        english: String,
        native: String,
        language: TargetLanguage,
        capturedAt: Date
    ) {
        self.id = id
        self.english = english
        self.native = native
        self.language = language
        self.capturedAt = capturedAt
    }

    /// `yyyy-MM-dd` in the current calendar — the key the collection groups by.
    public var dayKey: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let c = calendar.dateComponents([.year, .month, .day], from: capturedAt)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
