import Foundation
import ImageIO
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreImage)
import CoreImage
#endif
#if canImport(CoreVideo)
import CoreVideo
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
            guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
            // Use only ONE subject — the instance nearest the centre (where the user framed
            // it). Masking `allInstances` would crop to the bounding box of every subject and
            // drag the background between them into the cutout (the "obje dışındaki alanları
            // da ekliyor" bug).
            let instances = Self.centralInstance(observation, handler: handler)
            let masked = try observation.generateMaskedImage(
                ofInstances: instances,
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

    #if canImport(Vision) && canImport(CoreImage)
    /// Picks the single instance whose mask is closest to the image centre (small area
    /// bonus so a tiny speck never beats the framed object).
    @available(iOS 17.0, macOS 14.0, *)
    private static func centralInstance(
        _ observation: VNInstanceMaskObservation,
        handler: VNImageRequestHandler
    ) -> IndexSet {
        let instances = observation.allInstances
        guard instances.count > 1 else { return instances }

        var best = instances.first!
        var bestScore = Double.infinity   // lower = better (distance to centre)
        for index in instances {
            guard let mask = try? observation.generateScaledMaskForImage(
                forInstances: IndexSet(integer: index),
                from: handler
            ), let m = Self.metrics(of: mask) else { continue }
            let score = m.distanceToCentre - min(m.area, 0.25) * 0.5
            if score < bestScore {
                bestScore = score
                best = index
            }
        }
        return IndexSet(integer: best)
    }

    /// Centroid distance-to-centre (0…~0.7) and area fraction (0…1) of a single-channel
    /// mask. Sampled every 2px for speed.
    private static func metrics(of pixelBuffer: CVPixelBuffer) -> (distanceToCentre: Double, area: Double)? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0, let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let isFloat = CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_OneComponent32Float
        let step = 2

        var sumX = 0.0, sumY = 0.0, count = 0.0, sampled = 0.0
        var y = 0
        while y < height {
            let row = base.advanced(by: y * bytesPerRow)
            var x = 0
            while x < width {
                let value: Double
                if isFloat {
                    value = Double(row.advanced(by: x * 4).assumingMemoryBound(to: Float.self).pointee)
                } else {
                    value = Double(row.advanced(by: x).assumingMemoryBound(to: UInt8.self).pointee) / 255.0
                }
                if value > 0.5 { sumX += Double(x); sumY += Double(y); count += 1 }
                sampled += 1
                x += step
            }
            y += step
        }
        guard count > 0 else { return nil }
        let cx = sumX / count / Double(width)
        let cy = sumY / count / Double(height)
        let distance = ((cx - 0.5) * (cx - 0.5) + (cy - 0.5) * (cy - 0.5)).squareRoot()
        return (distance, count / sampled)
    }
    #endif

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
