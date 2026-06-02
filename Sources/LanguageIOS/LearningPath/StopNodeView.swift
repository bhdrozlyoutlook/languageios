import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// One destination on the map: a layered landmass plus its label and status chrome.
///
/// While the stop is `.locked` or `.active` only the base landmass shows ("sadece bir
/// kara parçası"). When it becomes `.completed`, the detail layers reveal one-by-one
/// with a spring animation — the core effect the product is built around.
struct StopNodeView: View {
    let stop: LearningStop
    let status: StopStatus
    var stars: Int = 0
    let onTap: () -> Void

    static let artSize: CGFloat = 132

    @State private var revealedLayers = 0
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 8) {
            artwork
            label
        }
        .frame(width: 168)
        .contentShape(Rectangle())
        .onTapGesture { if status == .active { onTap() } }
        .onAppear {
            // Already-completed stops (e.g. restored from disk) show fully built, no animation.
            revealedLayers = status == .completed ? stop.artwork.layerCount : 0
            if status == .active { pulse = true }
        }
        .onChange(of: status) { _, newValue in
            switch newValue {
            case .completed: animateReveal()
            default: revealedLayers = 0
            }
            pulse = newValue == .active
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stop.title), \(stop.subtitle)")
        .accessibilityValue(accessibilityStatus)
        .accessibilityAddTraits(status == .active ? .isButton : [])
    }

    // MARK: Artwork

    private var artwork: some View {
        ZStack {
            // Active stop draws attention with a soft pulsing halo.
            if status == .active {
                Circle()
                    .fill(MapTheme.paper.opacity(0.28))
                    .frame(width: Self.artSize + 26, height: Self.artSize + 26)
                    .scaleEffect(pulse ? 1.0 : 0.86)
                    .opacity(pulse ? 0.0 : 0.9)
                    .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulse)
            }

            StopArtworkView(artwork: stop.artwork, status: status, revealedLayers: revealedLayers)
                .frame(width: Self.artSize, height: Self.artSize)
                .scaleEffect(status == .locked ? 0.84 : 1.0)
                .opacity(status == .locked ? 0.62 : 1.0)

            badge
        }
        .frame(width: Self.artSize + 26, height: Self.artSize + 26)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: status)
    }

    @ViewBuilder
    private var badge: some View {
        switch status {
        case .locked:
            statusCircle(systemImage: "lock.fill", background: MapTheme.landLockedEdge)
                .offset(x: 46, y: 46)
        case .active:
            statusCircle(systemImage: "play.fill", background: MapTheme.coral)
                .offset(x: 46, y: 46)
        case .completed:
            statusCircle(systemImage: "checkmark", background: MapTheme.landCompletedEdge)
                .offset(x: 46, y: 46)
        }
    }

    private func statusCircle(systemImage: String, background: Color) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(Circle().fill(background))
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
    }

    // MARK: Label

    private var label: some View {
        VStack(spacing: 1) {
            Text(stop.title)
                .font(.headline.bold())
                .foregroundStyle(MapTheme.ink.opacity(status == .locked ? 0.5 : 1))
            Text(stop.subtitle)
                .font(.caption)
                .foregroundStyle(MapTheme.ink.opacity(status == .locked ? 0.4 : 0.66))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if status == .completed, stars > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.system(size: 9))
                            .foregroundStyle(index < stars ? MapTheme.coral : MapTheme.ink.opacity(0.2))
                    }
                }
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(MapTheme.paper.opacity(status == .locked ? 0.55 : 0.92))
        )
        .multilineTextAlignment(.center)
    }

    private var accessibilityStatus: String {
        let value: String.LocalizationValue = switch status {
        case .locked: "Kilitli"
        case .active: "Aktif, başlamak için dokun"
        case .completed: "Tamamlandı"
        }
        return String(localized: value)
    }

    private func animateReveal() {
        revealedLayers = 0
        let count = stop.artwork.layerCount
        guard count > 0 else { return }
        Task { @MainActor in
            for layer in 1...count {
                try? await Task.sleep(for: .milliseconds(230))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.62)) {
                    revealedLayers = layer
                }
            }
        }
    }
}

/// Renders the layered artwork for one stop. Picks up real PNG assets when present in
/// the bundle (named per `StopArtwork`'s convention); otherwise draws a procedural
/// placeholder so the experience is fully functional before art is delivered.
struct StopArtworkView: View {
    let artwork: StopArtwork
    let status: StopStatus
    let revealedLayers: Int

    var body: some View {
        ZStack {
            // Foam seat so the land looks like it floats on the sea.
            Ellipse()
                .fill(MapTheme.seaFoam.opacity(0.7))
                .frame(width: 118, height: 34)
                .offset(y: 52)
                .blur(radius: 1)

            baseLayer

            ForEach(0..<artwork.layerCount, id: \.self) { index in
                detailLayer(index)
                    .opacity(index < revealedLayers ? 1 : 0)
                    .scaleEffect(index < revealedLayers ? 1 : 0.55, anchor: .bottom)
            }
        }
    }

    // MARK: Base ("the landmass")

    @ViewBuilder
    private var baseLayer: some View {
        if let image = Self.bundledImage(artwork.baseImageName) {
            image.resizable().scaledToFit()
        } else {
            placeholderLandmass
        }
    }

    private var placeholderLandmass: some View {
        LandmassShape()
            .fill(landFill)
            .overlay(LandmassShape().stroke(landEdge, lineWidth: 3))
            .frame(width: 116, height: 96)
            .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
    }

    private var landFill: LinearGradient {
        let colors: [Color]
        switch status {
        case .locked: colors = [MapTheme.landLocked, MapTheme.landLocked.opacity(0.82)]
        case .active: colors = [MapTheme.landActive, MapTheme.landActive.opacity(0.82)]
        case .completed: colors = [MapTheme.landCompleted, MapTheme.landCompleted.opacity(0.82)]
        }
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    private var landEdge: Color {
        switch status {
        case .locked: MapTheme.landLockedEdge
        case .active: MapTheme.landActiveEdge
        case .completed: MapTheme.landCompletedEdge
        }
    }

    // MARK: Detail layers ("katmanlar")

    @ViewBuilder
    private func detailLayer(_ index: Int) -> some View {
        let name = artwork.layerImageNames[index]
        if let image = Self.bundledImage(name) {
            image.resizable().scaledToFit()
        } else {
            placeholderLayer(index)
        }
    }

    private static let placeholderSymbols = [
        "house.fill", "building.2.fill", "tree.fill", "building.columns.fill"
    ]
    private static let placeholderOffsets: [CGSize] = [
        CGSize(width: -26, height: 10),
        CGSize(width: 22, height: 18),
        CGSize(width: -2, height: -18),
        CGSize(width: 30, height: -6)
    ]

    private func placeholderLayer(_ index: Int) -> some View {
        let symbol = Self.placeholderSymbols[index % Self.placeholderSymbols.count]
        let offset = Self.placeholderOffsets[index % Self.placeholderOffsets.count]
        return Image(systemName: symbol)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(MapTheme.landCompletedEdge)
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            .offset(offset)
    }

    private static func bundledImage(_ name: String) -> Image? {
        #if canImport(UIKit)
        if let ui = UIImage(named: name) { return Image(uiImage: ui) }
        #endif
        return nil
    }
}

/// An organic island silhouette built from a fixed set of radii so it reads as land
/// rather than a plain circle. Deterministic (no randomness) for stable rendering.
struct LandmassShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radii: [CGFloat] = [1.0, 0.86, 0.97, 0.8, 0.93, 0.84]
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        let count = radii.count

        let points: [CGPoint] = (0..<count).map { index in
            let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
            return CGPoint(
                x: center.x + CGFloat(cos(angle)) * rx * radii[index],
                y: center.y + CGFloat(sin(angle)) * ry * radii[index]
            )
        }
        // Smooth closed curve through the anchor points using their midpoints.
        let mids: [CGPoint] = (0..<count).map { index in
            let a = points[index]
            let b = points[(index + 1) % count]
            return CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }

        var path = Path()
        path.move(to: mids[count - 1])
        for index in 0..<count {
            path.addQuadCurve(to: mids[index], control: points[index])
        }
        path.closeSubpath()
        return path
    }
}
