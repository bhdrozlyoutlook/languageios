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
        .allowsHitTesting(false)
    }
}

/// A cutout image presented as a white "sticker": rounded card + soft shadow. Falls back
/// to a camera glyph when the cutout couldn't be produced (e.g. macOS / older OS).
struct CutoutSticker: View {
    let imageData: Data?
    var cornerRadius: CGFloat = 22

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(OnboardingTheme.paper)
                .shadow(color: OnboardingTheme.ink.opacity(0.12), radius: 10, x: 0, y: 6)
            content
                .padding(14)
        }
    }

    @ViewBuilder
    private var content: some View {
        #if canImport(UIKit)
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            placeholder
        }
        #else
        placeholder
        #endif
    }

    private var placeholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 40))
            .foregroundStyle(OnboardingTheme.teal.opacity(0.4))
    }
}
