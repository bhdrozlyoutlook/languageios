import Foundation

/// App-wide error type. Replaces silent `try?` swallowing in persistence with values
/// that can be logged, reported, and surfaced to the user.
public enum AppError: Error, Equatable {
    case persistenceWrite(key: String)
    case persistenceRead(key: String)
    case decoding(key: String)
    case migration(reason: String)

    /// User-facing Turkish message.
    public var userMessage: String {
        switch self {
        case .persistenceWrite, .persistenceRead, .decoding:
            "Verilerin kaydedilirken bir sorun oluştu. Lütfen tekrar dene."
        case .migration:
            "Veriler güncellenirken bir sorun oluştu."
        }
    }
}

extension AppError: Identifiable {
    public var id: String {
        switch self {
        case .persistenceWrite(let key): "write-\(key)"
        case .persistenceRead(let key): "read-\(key)"
        case .decoding(let key): "decode-\(key)"
        case .migration(let reason): "migration-\(reason)"
        }
    }
}
