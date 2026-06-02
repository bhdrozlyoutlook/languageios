import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Light dotted backdrop used behind cutout stickers (the result screen and collection).
struct DottedBackground: View {
    var dot: Color = OnboardingTheme.ink.opacity(0.08)
    var spacing: CGFloat = 22

    var body: some View {
        Canvas { context, size in
            let radius: CGFloat = 1.6
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(dot))
                    x += spacing
                }
                y += spacing
            }
        }
        // Static dot field — rasterize once instead of recomputing on every redraw.
        .drawingGroup()
        .allowsHitTesting(false)
    }
}

/// A cutout image presented as a white "sticker": rounded card + soft shadow. Falls back
/// to a camera glyph when the cutout couldn't be produced (e.g. macOS / older OS).
struct CutoutSticker: View {
    let imageData: Data?
    var cornerRadius: CGFloat = 22
    /// When the image is a true background-removed cutout, trace a white silhouette
    /// outline (the "sticker" look). Off for full-photo fallbacks, where an outline would
    /// just box the whole rectangle.
    var outlined: Bool = true

    #if canImport(UIKit)
    @State private var decoded: UIImage?
    #endif

    var body: some View {
        #if canImport(UIKit)
        Group {
            if let decoded {
                sticker(UIImage: decoded)
            } else {
                placeholderCard
            }
        }
        // Decode once, off the main thread — re-runs only when the data changes. Keeps
        // grid scrolling smooth instead of re-decoding every body evaluation.
        .task(id: imageData) { decoded = await Self.decode(imageData) }
        #else
        placeholderCard
        #endif
    }

    #if canImport(UIKit)
    private static func decode(_ data: Data?) async -> UIImage? {
        guard let data else { return nil }
        return await Task.detached(priority: .userInitiated) {
            UIImage(data: data)?.preparingForDisplay()
        }.value
    }

    private func sticker(UIImage image: UIImage) -> some View {
        // `renderingMode` is an Image-only modifier, so build the white silhouette from the
        // Image before .resizable()/.scaledToFit() turn it into an opaque `some View`.
        let silhouette = Image(uiImage: image)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
        return ZStack {
            if outlined {
                // White outline: the silhouette redrawn in 8 directions behind the cutout.
                ForEach(Self.outlineOffsets, id: \.self) { offset in
                    silhouette.offset(x: offset.width, y: offset.height)
                }
            }
            Image(uiImage: image).resizable().scaledToFit()
        }
        .shadow(color: OnboardingTheme.ink.opacity(0.22), radius: 9, x: 0, y: 6)
        .padding(10)
    }
    #endif

    private static let outlineOffsets: [CGSize] = {
        let r: CGFloat = 4
        return (0..<8).map { i in
            let a = Double(i) / 8 * 2 * .pi
            return CGSize(width: CGFloat(cos(a)) * r, height: CGFloat(sin(a)) * r)
        }
    }()

    private var placeholderCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(OnboardingTheme.paper)
                .shadow(color: OnboardingTheme.ink.opacity(0.12), radius: 10, x: 0, y: 6)
            Image(systemName: "photo")
                .font(.system(size: 40))
                .foregroundStyle(OnboardingTheme.teal.opacity(0.4))
        }
    }
}
