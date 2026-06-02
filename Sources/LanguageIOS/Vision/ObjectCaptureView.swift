import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

/// Camera object-capture flow (Duolingo "Words" style): a live viewfinder with a framing
/// reticle, a colorful shutter + photo-library button, then the recognized object lifted
/// out as a cutout "sticker" with its English word, native translation and audio — confirm
/// (✓), retry (↻) or discard (✗). The live camera only runs on device; the Simulator and
/// macOS fall back to the photo library.
public struct ObjectCaptureView: View {
    private let store: AppStore
    private let recognizer: ObjectRecognizing
    private let extractor: SubjectExtracting
    private let speech: SpeechService
    private let language: TargetLanguage
    private let native: TargetLanguage
    private let onShowCollection: () -> Void
    private let onClose: () -> Void

    private enum Phase: Equatable {
        case capture
        case processing(Data)
        case result(CaptureResult)
        case noMatch(Data)
    }

    private struct CaptureResult: Equatable {
        let display: Data   // cutout if available, else the original photo
        let word: String    // object name in the target language
        let native: String  // Turkish translation
        let cutout: Data?
    }

    @State private var phase: Phase = .capture
    @State private var selectedItem: PhotosPickerItem?
    #if os(iOS)
    @StateObject private var camera = CameraModel()
    #endif

    public init(
        store: AppStore,
        recognizer: ObjectRecognizing = OnDeviceObjectRecognizer(),
        extractor: SubjectExtracting = VisionSubjectExtractor(),
        speech: SpeechService,
        language: TargetLanguage,
        native: TargetLanguage = .turkish,
        onShowCollection: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.recognizer = recognizer
        self.extractor = extractor
        self.speech = speech
        self.language = language
        self.native = native
        self.onShowCollection = onShowCollection
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            switch phase {
            case .capture:
                captureScreen
            case .processing(let data):
                processingScreen(data)
            case .result(let result):
                resultScreen(result)
            case .noMatch(let data):
                noMatchScreen(data)
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await process(data)
                }
            }
        }
    }

    // MARK: Capture (viewfinder)

    private var captureScreen: some View {
        ZStack {
            cameraSurface
            reticleOverlay
            VStack {
                captureTopBar
                Spacer()
                instruction
                captureControls
            }
        }
        #if os(iOS)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
        #endif
    }

    @ViewBuilder
    private var cameraSurface: some View {
        #if os(iOS)
        if camera.status == .ready {
            CameraPreview(session: camera.session).ignoresSafeArea()
        } else {
            unavailableSurface
        }
        #else
        unavailableSurface
        #endif
    }

    private var unavailableSurface: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.13, blue: 0.16), Color(red: 0.05, green: 0.05, blue: 0.07)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: "camera.metering.unknown")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Bu cihazda canlı kamera yok")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.8))
                Text("Galeriden bir fotoğraf seçerek deneyebilirsin.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
        }
    }

    private var reticleOverlay: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.62
            ReticleBrackets()
                .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: side, height: side)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .shadow(color: .black.opacity(0.25), radius: 4)
        }
        .allowsHitTesting(false)
    }

    private var instruction: some View {
        Text("Objeyi çerçevenin içine al")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(Capsule().fill(.black.opacity(0.42)))
            .padding(.bottom, 22)
    }

    private var captureTopBar: some View {
        HStack {
            circleButton(system: "xmark", action: onClose)
                .accessibilityLabel("Kapat")
            Spacer()
            circleButton(system: "square.grid.2x2.fill", action: onShowCollection)
                .accessibilityLabel("Kelimelerim")
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var captureControls: some View {
        HStack {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(.white.opacity(0.16)))
            }
            .accessibilityLabel("Galeriden seç")

            Spacer()

            shutterButton

            Spacer()

            // Symmetry spacer so the shutter stays centered.
            Color.clear.frame(width: 54, height: 54)
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 28)
    }

    private var shutterButton: some View {
        Button {
            #if os(iOS)
            camera.capturePhoto { data in Task { await process(data) } }
            #endif
        } label: {
            ZStack {
                Circle()
                    .fill(AngularGradient(
                        colors: [OnboardingTheme.teal, OnboardingTheme.coral, Color.yellow, OnboardingTheme.teal],
                        center: .center
                    ))
                    .frame(width: 84, height: 84)
                Circle().fill(.white).frame(width: 70, height: 70)
                Circle().fill(.white).frame(width: 62, height: 62)
                    .overlay(Circle().strokeBorder(OnboardingTheme.ink.opacity(0.12), lineWidth: 1))
            }
        }
        .accessibilityLabel("Çek")
        #if os(iOS)
        .disabled(camera.status != .ready)
        .opacity(camera.status == .ready ? 1 : 0.4)
        #else
        .disabled(true)
        .opacity(0.4)
        #endif
    }

    // MARK: Processing (animated scan over the captured photo)

    private func processingScreen(_ data: Data) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()
            #if canImport(UIKit)
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #endif
            ScanningOverlay()
            VStack {
                Spacer()
                Label("Obje taranıyor…", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .padding(.bottom, 44)
            }
        }
        .transition(.opacity)
    }

    // MARK: Result (cutout sticker + word + ✓/↻/✗)

    private func resultScreen(_ result: CaptureResult) -> some View {
        ZStack {
            OnboardingTheme.background.ignoresSafeArea()
            DottedBackground()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    circleButton(system: "xmark", tint: OnboardingTheme.ink.opacity(0.55), background: OnboardingTheme.paper, action: onClose)
                        .accessibilityLabel("Kapat")
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)

                Spacer()

                CutoutSticker(imageData: result.display, outlined: result.cutout != nil)
                    .frame(maxWidth: 280, maxHeight: 280)
                    .padding(.horizontal, 30)

                HStack(spacing: 12) {
                    Text(result.word)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(OnboardingTheme.ink)
                    Button { speech.speak(result.word, language: language) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title2)
                            .foregroundStyle(OnboardingTheme.teal)
                    }
                    .accessibilityLabel("Seslendir")
                }
                .padding(.top, 22)

                Text(result.native)
                    .font(.title3)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
                    .padding(.top, 2)

                Text("Beklediğin bu değil mi? Tekrar dene.")
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.4))
                    .padding(.top, 10)

                Spacer()

                HStack(spacing: 34) {
                    actionButton(system: "arrow.counterclockwise", tint: OnboardingTheme.ink.opacity(0.7), size: 60) {
                        retry()
                    }
                    .accessibilityLabel("Tekrar dene")

                    actionButton(system: "checkmark", tint: .white, background: OnboardingTheme.teal, size: 78) {
                        confirm(result)
                    }
                    .accessibilityLabel("Onayla")

                    actionButton(system: "xmark", tint: OnboardingTheme.coral, size: 60) {
                        retry()
                    }
                    .accessibilityLabel("İptal")
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: No match

    private func noMatchScreen(_ data: Data) -> some View {
        ZStack {
            OnboardingTheme.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                #if canImport(UIKit)
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable().scaledToFill()
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .opacity(0.85)
                }
                #endif
                Text("Bunu tanıyamadım")
                    .font(.title3.bold())
                    .foregroundStyle(OnboardingTheme.ink)
                Text("Objeyi çerçeveye ortala ve tekrar dene.")
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
                    .multilineTextAlignment(.center)
                Button(action: retry) {
                    Label("Tekrar dene", systemImage: "arrow.counterclockwise")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .frame(height: 50)
                        .background(Capsule().fill(OnboardingTheme.teal))
                }
                Spacer(); Spacer()
            }
            .padding(.horizontal, 32)
        }
    }

    // MARK: Building blocks

    private func circleButton(
        system: String,
        tint: Color = .white,
        background: Color = Color.black.opacity(0.32),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(background))
        }
    }

    private func actionButton(
        system: String,
        tint: Color,
        background: Color = OnboardingTheme.paper,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(background))
                .shadow(color: OnboardingTheme.ink.opacity(0.12), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func process(_ rawData: Data) async {
        // Upright + downscale first: fixes the 90°-rotated cutout and keeps scanning fast
        // (no multi-megapixel upload to Gemini / mask on a huge image).
        let data = ImageNormalizer.prepared(rawData)
        withAnimation(.easeInOut(duration: 0.25)) { phase = .processing(data) }

        // Lift the subject first, then recognize the background-removed cutout when we got
        // one: Gemini then sees only the framed object, not the surrounding scene (which
        // let a background/side object win). Fall back to the full frame if no cutout.
        let cutout = await extractor.extractSubject(from: data)
        let recognitionInput = cutout.map(ImageNormalizer.onWhite) ?? data
        let recognition = await recognizer.recognize(recognitionInput, target: language, native: native)
        if let recognition {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                phase = .result(CaptureResult(
                    display: cutout ?? data,
                    word: recognition.word,
                    native: recognition.native,
                    cutout: cutout
                ))
            }
            speech.speak(recognition.word, language: language)
        } else {
            phase = .noMatch(data)
        }
    }

    private func confirm(_ result: CaptureResult) {
        store.captureObject(english: result.word, native: result.native, image: result.cutout ?? result.display)
        selectedItem = nil
        onShowCollection()
    }

    private func retry() {
        selectedItem = nil
        phase = .capture
    }
}

/// Four corner brackets framing the subject — the viewfinder reticle.
private struct ReticleBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let len = min(rect.width, rect.height) * 0.22
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY + len), CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + len, y: rect.minY)),
            (CGPoint(x: rect.maxX - len, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + len)),
            (CGPoint(x: rect.maxX, y: rect.maxY - len), CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX - len, y: rect.maxY)),
            (CGPoint(x: rect.minX + len, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY - len)),
        ]
        for (start, corner, end) in corners {
            path.move(to: start)
            path.addLine(to: corner)
            path.addLine(to: end)
        }
        return path
    }
}

/// Animated "scanning" overlay shown while the captured object is being recognized: a
/// soft wash, a gently breathing reticle, and a glowing band sweeping inside the frame.
private struct ScanningOverlay: View {
    @State private var sweep: CGFloat = 0   // 0 (top) … 1 (bottom), within the reticle
    @State private var pulse = false

    private let bandHeightRatio: CGFloat = 0.4

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * 0.7
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let bandHeight = side * bandHeightRatio

            ZStack {
                Color.black.opacity(0.22).ignoresSafeArea()

                // Glowing scan band, clipped to the reticle square so it reads as contained.
                VStack {
                    LinearGradient(
                        colors: [OnboardingTheme.teal.opacity(0), OnboardingTheme.teal.opacity(0.40)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: bandHeight)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [OnboardingTheme.teal.opacity(0.2), .white, OnboardingTheme.teal.opacity(0.2)],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .frame(height: 2.5)
                            .shadow(color: .white.opacity(0.9), radius: 6)
                            .shadow(color: OnboardingTheme.teal, radius: 10)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: side, height: side, alignment: .top)
                .offset(y: (sweep - 0.5) * (side - bandHeight))
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .position(center)

                ReticleBrackets()
                    .stroke(Color.white.opacity(0.92), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: side, height: side)
                    .scaleEffect(pulse ? 1.03 : 0.98)
                    .position(center)
                    .shadow(color: .black.opacity(0.25), radius: 4)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) { sweep = 1 }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { pulse = true }
            }
        }
        .allowsHitTesting(false)
    }
}
