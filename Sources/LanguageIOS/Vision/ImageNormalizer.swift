import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Bakes a photo's EXIF orientation into its pixels so everything downstream sees an
/// upright image. Camera captures arrive as JPEG tagged `.right`/`.left` (portrait), but
/// the Vision subject-mask pipeline reads raw pixels via ImageIO and ignores that tag —
/// which is why cutouts came out rotated 90°. Normalizing once fixes the cutout, the
/// recognizer input, and any fallback display.
public enum ImageNormalizer {
    public static func upright(_ data: Data) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        if image.imageOrientation == .up { return data }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let redrawn = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return redrawn.pngData() ?? data
        #else
        return data
        #endif
    }
}
