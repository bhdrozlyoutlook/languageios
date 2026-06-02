import Foundation

/// Thin client over the Gemini `generateContent` REST endpoint. Supports text-only and
/// multimodal (image + text) prompts and asks the model to reply as JSON. Provider details
/// stay here so adapters (`GeminiObjectRecognizer`, `GeminiSentenceAnalyzer`) only deal in
/// domain types. The API key is injected — never hardcoded.
public final class GeminiClient {
    public enum GeminiError: Error, Equatable {
        case missingKey
        case requestFailed(status: Int)
        case emptyResponse
        case decoding
    }

    private let apiKey: String
    private let model: String
    private let session: URLSession
    private let endpoint: String

    public init(
        apiKey: String,
        model: String = "gemini-2.0-flash",
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        self.endpoint = "https://generativelanguage.googleapis.com/v1beta/models"
    }

    public var hasKey: Bool { !apiKey.isEmpty }

    /// Sends an optional inline image plus a text prompt and returns the model's raw text
    /// (which our prompts constrain to a JSON object).
    public func generate(prompt: String, imageData: Data? = nil, mimeType: String = "image/jpeg") async throws -> String {
        guard !apiKey.isEmpty else { throw GeminiError.missingKey }
        guard let url = URL(string: "\(endpoint)/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError.requestFailed(status: -1)
        }

        var parts: [[String: Any]] = [["text": prompt]]
        if let imageData {
            parts.append([
                "inline_data": [
                    "mime_type": mimeType,
                    "data": imageData.base64EncodedString(),
                ]
            ])
        }
        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": ["response_mime_type": "application/json", "temperature": 0.2],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GeminiError.requestFailed(status: http.statusCode)
        }
        return try Self.extractText(from: data)
    }

    /// Pulls the first candidate's concatenated text out of a Gemini response payload.
    static func extractText(from data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiError.decoding
        }
        guard let candidates = root["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw GeminiError.emptyResponse
        }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        if text.isEmpty { throw GeminiError.emptyResponse }
        return text
    }
}
