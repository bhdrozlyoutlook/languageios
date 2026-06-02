import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Prepares a captured photo for recognition: bakes in EXIF orientation and downscales it.
/// Camera captures arrive as multi-megapixel JPEGs tagged `.right`/`.left` (portrait); the
/// Vision subject-mask pipeline reads raw pixels via ImageIO and ignores that tag (cutouts
/// came out rotated 90°), and shipping the full-resolution image to Gemini made scanning
/// slow. One upright + downscaled JPEG fixes both: faster upload, faster on-device mask,
/// and correct orientation everywhere downstream.
public enum ImageNormalizer {
    /// Upright + downscaled (longest side ≤ `maxDimension`) JPEG, aspect preserved.
    public static func prepared(_ data: Data, maxDimension: CGFloat = 1024) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let longest = max(image.size.width, image.size.height)
        let factor = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: image.size.width * factor, height: image.size.height * factor)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1          // target is already in pixels
        format.opaque = true      // input photo has no alpha; smaller JPEG
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let redrawn = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target)) // draw() respects orientation
        }
        return redrawn.jpegData(compressionQuality: 0.8) ?? data
        #else
        return data
        #endif
    }

    /// Flattens a (possibly transparent) cutout PNG onto an opaque white background as JPEG.
    /// Sent to Gemini so it sees only the lifted object — no background to be distracted by,
    /// which is what makes recognition match the framed object instead of the scene.
    public static func onWhite(_ data: Data) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else { return data }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let flattened = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: image.size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return flattened.jpegData(compressionQuality: 0.85) ?? data
        #else
        return data
        #endif
    }
}
