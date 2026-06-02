import SwiftUI

/// The captured-word journal: cutout stickers grouped by the day they were captured
/// ("7 Mayıs / 5 kelime"), mirroring the reference collection screen.
public struct WordCollectionView: View {
    private let store: AppStore
    private let speech: SpeechService
    private let onClose: () -> Void
    private let onCapture: () -> Void

    @State private var objects: [CapturedObject] = []

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    public init(
        store: AppStore,
        speech: SpeechService,
        onCapture: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.speech = speech
        self.onCapture = onCapture
        self.onClose = onClose
    }

    private var groups: [(day: String, items: [CapturedObject])] {
        var order: [String] = []
        var map: [String: [CapturedObject]] = [:]
        for object in objects {
            if map[object.dayKey] == nil { order.append(object.dayKey) }
            map[object.dayKey, default: []].append(object)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    public var body: some View {
        ZStack {
            OnboardingTheme.background.ignoresSafeArea()
            DottedBackground()

            VStack(spacing: 0) {
                header
                if objects.isEmpty {
                    emptyState
                } else {
                    ScrollView { content }
                }
            }
        }
        .onAppear { objects = store.capturedObjects() }
    }

    private var header: some View {
        HStack {
            Text("Kelimelerim")
                .font(.system(size: 26, weight: .black, design: .serif))
                .foregroundStyle(OnboardingTheme.ink)
            Spacer()
            Button(action: onCapture) {
                Image(systemName: "camera.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(OnboardingTheme.teal))
            }
            .accessibilityLabel("Yeni obje çek")
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Kapat")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 26) {
            ForEach(groups, id: \.day) { group in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text(Self.dayLabel(group.items.first?.capturedAt))
                            .font(.headline.bold())
                            .foregroundStyle(OnboardingTheme.ink)
                        Text("· \(group.items.count) kelime")
                            .font(.subheadline)
                            .foregroundStyle(OnboardingTheme.ink.opacity(0.5))
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(group.items) { item in
                            tile(item)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }

    private func tile(_ item: CapturedObject) -> some View {
        Button {
            speech.speak(item.english, language: .englishUS)
        } label: {
            VStack(spacing: 8) {
                CutoutSticker(imageData: store.captureImage(forID: item.id), cornerRadius: 18)
                    .frame(height: 130)
                Text(item.english)
                    .font(.subheadline.bold())
                    .foregroundStyle(OnboardingTheme.ink)
                    .lineLimit(1)
                Text(item.native)
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(OnboardingTheme.teal.opacity(0.5))
            Text("Henüz kelime yok")
                .font(.title3.bold())
                .foregroundStyle(OnboardingTheme.ink)
            Text("Etrafındaki objeleri çekerek kelime biriktir.")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
                .multilineTextAlignment(.center)
            Button(action: onCapture) {
                Label("Obje çek", systemImage: "camera.fill")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 50)
                    .background(Capsule().fill(OnboardingTheme.teal))
            }
            .padding(.top, 4)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private static func dayLabel(_ date: Date?) -> String {
        guard let date else { return "" }
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: date)
    }
}
