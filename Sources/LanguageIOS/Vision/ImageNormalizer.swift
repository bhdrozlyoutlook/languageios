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
    /// Upright, centre-cropped to the framing reticle, and downscaled JPEG — ready to
    /// recognize. The centre crop is what makes "what you frame = what gets analyzed":
    /// without it the full photo went to Gemini/Vision and a more prominent object off to
    /// the side (or the background) could win over the small/distant subject in the frame.
    /// `cropRatio` is the fraction of the shorter side kept as a centred square (matching
    /// the viewfinder reticle).
    public static func prepared(
        _ data: Data,
        maxDimension: CGFloat = 1024,
        cropRatio: CGFloat = 0.72
    ) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let w = image.size.width
        let h = image.size.height
        guard w > 0, h > 0 else { return data }

        let side = min(w, h) * cropRatio                 // centred square in oriented space
        let origin = CGPoint(x: (w - side) / 2, y: (h - side) / 2)
        let outputSide = min(side, maxDimension)
        let factor = outputSide / side

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1          // target is already in pixels
        format.opaque = true      // input photo has no alpha; smaller JPEG
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide), format: format)
        let redrawn = renderer.image { _ in
            // Draw the whole (orientation-corrected) image scaled, offset so the centred
            // crop region fills the square canvas; everything outside is clipped away.
            image.draw(in: CGRect(
                x: -origin.x * factor,
                y: -origin.y * factor,
                width: w * factor,
                height: h * factor
            ))
        }
        return redrawn.jpegData(compressionQuality: 0.8) ?? data
        #else
        return data
        #endif
    }
}
