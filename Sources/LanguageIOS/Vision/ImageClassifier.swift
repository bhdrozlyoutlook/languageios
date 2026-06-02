import Foundation
import ImageIO
#if canImport(Vision)
import Vision
#endif

/// A detected object label from image classification.
public struct ObjectLabel: Equatable {
    public let identifier: String   // English noun, e.g. "coffee mug"
    public let confidence: Float

    public init(identifier: String, confidence: Float) {
        self.identifier = identifier
        self.confidence = confidence
    }
}

/// Classifies an image into object labels. The default uses Apple's built-in Vision
/// classifier (no Core ML model needed); tests use a stub.
public protocol ImageClassifying: AnyObject {
    func classify(_ imageData: Data) async -> [ObjectLabel]
}

public final class VisionImageClassifier: ImageClassifying {
    private let minimumConfidence: Float

    public init(minimumConfidence: Float = 0.1) {
        self.minimumConfidence = minimumConfidence
    }

    public func classify(_ imageData: Data) async -> [ObjectLabel] {
        #if canImport(Vision)
        guard let cgImage = Self.cgImage(from: imageData) else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                let observations = (request.results as? [VNClassificationObservation]) ?? []
                let labels = observations
                    .filter { $0.confidence >= self.minimumConfidence }
                    .prefix(5)
                    .map { ObjectLabel(identifier: $0.identifier, confidence: $0.confidence) }
                continuation.resume(returning: Array(labels))
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
        #else
        return []
        #endif
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}

public final class StubImageClassifier: ImageClassifying {
    private let result: [ObjectLabel]
    public init(result: [ObjectLabel] = []) { self.result = result }
    public func classify(_ imageData: Data) async -> [ObjectLabel] { result }
}
