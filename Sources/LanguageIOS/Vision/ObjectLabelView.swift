import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

/// "Kamera ile objeler": pick a photo, classify the main object with Vision, and learn
/// its English word + Turkish gloss. (Photo library works in the Simulator; a live
/// camera capture path can be layered on for devices later.)
public struct ObjectLabelView: View {
    private let classifier: ImageClassifying
    private let speech: SpeechService
    private let onCapture: (String, String) -> Void
    private let onClose: () -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var isClassifying = false
    @State private var match: Match?
    @State private var noMatch = false
    @State private var captured = false

    private struct Match: Equatable { let english: String; let turkish: String }

    public init(
        classifier: ImageClassifying = VisionImageClassifier(),
        speech: SpeechService,
        onCapture: @escaping (String, String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.classifier = classifier
        self.speech = speech
        self.onCapture = onCapture
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 18) {
            topBar

            Text("Bir fotoğraf seç; içindeki objeyi tanıyıp kelimesini öğretelim.")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            imagePreview

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Fotoğraf seç", systemImage: "photo.on.rectangle.angled")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.teal))
            }
            .padding(.horizontal, 20)

            resultArea

            Spacer()
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingTheme.background.ignoresSafeArea())
        .onChange(of: selectedItem) { _, item in
            Task { await classify(item) }
        }
    }

    private var topBar: some View {
        HStack {
            Text("Objeleri öğren")
                .font(.system(size: 24, weight: .black, design: .serif))
                .foregroundStyle(OnboardingTheme.ink)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Kapat")
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var imagePreview: some View {
        #if canImport(UIKit)
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)
        } else {
            placeholderPreview
        }
        #else
        placeholderPreview
        #endif
    }

    private var placeholderPreview: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(OnboardingTheme.paper)
            .overlay(
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 52))
                    .foregroundStyle(OnboardingTheme.teal.opacity(0.4))
            )
            .frame(height: 220)
            .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var resultArea: some View {
        if isClassifying {
            ProgressView().padding(.top, 8)
        } else if let match {
            resultCard(match)
        } else if noMatch {
            Text("Bu fotoğrafta tanıdık bir obje bulamadım — başka bir tane dene.")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.coral)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private func resultCard(_ match: Match) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text(match.english)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(OnboardingTheme.ink)
                Button { speech.speak(match.english, language: .englishUS) } label: {
                    Image(systemName: "speaker.wave.2.fill").font(.title3).foregroundStyle(OnboardingTheme.teal)
                }
                .accessibilityLabel("Seslendir")
            }
            Text(match.turkish)
                .font(.title3)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.7))

            Button {
                onCapture(match.english, match.turkish)
                captured = true
            } label: {
                Label(captured ? "Eklendi ✓" : "Kelimelerime ekle", systemImage: captured ? "checkmark" : "plus")
                    .font(.subheadline.bold())
                    .foregroundStyle(captured ? .white : OnboardingTheme.ink)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(captured ? OnboardingTheme.teal : OnboardingTheme.paper))
                    .overlay(Capsule().strokeBorder(OnboardingTheme.ink.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(captured)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(OnboardingTheme.paper))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func classify(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isClassifying = true
        match = nil
        noMatch = false
        captured = false
        if let data = try? await item.loadTransferable(type: Data.self) {
            imageData = data
            let labels = await classifier.classify(data)
            if let best = ObjectVocabulary.bestMatch(in: labels) {
                match = Match(english: best.english, turkish: best.turkish)
                speech.speak(best.english, language: .englishUS)
            } else {
                noMatch = true
            }
        }
        isClassifying = false
    }
}
