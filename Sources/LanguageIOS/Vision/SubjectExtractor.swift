import Foundation
import ImageIO
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreImage)
import CoreImage
#endif

/// Lifts the main subject out of a photo, returning a PNG with a transparent background
/// (the "sticker" look), cropped to the subject. Default uses Vision's foreground-instance
/// mask (iOS 17+); tests use a stub.
public protocol SubjectExtracting: AnyObject {
    func extractSubject(from imageData: Data) async -> Data?
}

public final class VisionSubjectExtractor: SubjectExtracting {
    public init() {}

    public func extractSubject(from imageData: Data) async -> Data? {
        #if canImport(Vision) && canImport(CoreImage)
        guard #available(iOS 17.0, macOS 14.0, *), let cgImage = Self.cgImage(from: imageData) else {
            return nil
        }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        do {
            try handler.perform([request])
            guard let observation = request.results?.first else { return nil }
            let masked = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            let ciImage = CIImage(cvPixelBuffer: masked)
            let context = CIContext()
            guard let output = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return Self.png(from: output)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    private static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private static func png(from cgImage: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}

/// Returns the original image unchanged — used as a fallback and in tests.
public final class PassthroughSubjectExtractor: SubjectExtracting {
    public init() {}
    public func extractSubject(from imageData: Data) async -> Data? { imageData }
}
