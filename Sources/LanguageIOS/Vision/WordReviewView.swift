import SwiftUI

/// Orders captured words for review: the ones the user previously missed come first, then
/// the rest (newest first, the storage order). Pure + testable.
enum ReviewQueue {
    static func build(objects: [CapturedObject], missed: Set<String>) -> [CapturedObject] {
        let missedFirst = objects.filter { missed.contains($0.english) }
        let rest = objects.filter { !missed.contains($0.english) }
        return missedFirst + rest
    }
}

/// Flashcard review over the captured-word collection: see the cutout sticker, recall the
/// word, reveal it (with translation + audio), then mark "knew it" / "review again" — which
/// feeds the spaced-repetition `missedWordIds`.
public struct WordReviewView: View {
    private let store: AppStore
    private let speech: SpeechService
    private let onClose: () -> Void

    @State private var queue: [CapturedObject] = []
    @State private var index = 0
    @State private var revealed = false
    @State private var reviewedCount = 0

    public init(store: AppStore, speech: SpeechService, onClose: @escaping () -> Void) {
        self.store = store
        self.speech = speech
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            OnboardingTheme.background.ignoresSafeArea()
            DottedBackground()
            VStack(spacing: 0) {
                header
                if queue.isEmpty {
                    emptyState
                } else if index >= queue.count {
                    finishedState
                } else {
                    card(queue[index])
                    actions
                }
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            queue = ReviewQueue.build(objects: store.capturedObjects(), missed: store.missedWordIds)
        }
    }

    private var header: some View {
        HStack {
            Text("Kelime tekrarı")
                .font(.system(size: 24, weight: .black, design: .serif))
                .foregroundStyle(OnboardingTheme.ink)
            Spacer()
            if !queue.isEmpty && index < queue.count {
                Text("\(index + 1)/\(queue.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.5))
            }
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

    private func card(_ object: CapturedObject) -> some View {
        VStack(spacing: 18) {
            CutoutSticker(imageData: store.captureImage(forID: object.id))
                .frame(maxWidth: 240, maxHeight: 240)
                .padding(.top, 10)

            if revealed {
                HStack(spacing: 12) {
                    Text(object.english)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(OnboardingTheme.ink)
                    Button { speech.speak(object.english, language: object.language) } label: {
                        Image(systemName: "speaker.wave.2.fill").font(.title3).foregroundStyle(OnboardingTheme.teal)
                    }
                    .accessibilityLabel("Seslendir")
                }
                Text(object.native)
                    .font(.title3)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
            } else {
                Button { revealed = true } label: {
                    Label("Dokun ve hatırla", systemImage: "eye")
                        .font(.headline.bold())
                        .foregroundStyle(OnboardingTheme.ink)
                        .padding(.horizontal, 22).frame(height: 50)
                        .background(Capsule().fill(OnboardingTheme.paper))
                        .overlay(Capsule().strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var actions: some View {
        if revealed {
            HStack(spacing: 14) {
                Button { grade(correct: false) } label: {
                    Label("Tekrar", systemImage: "arrow.counterclockwise")
                        .font(.headline.bold()).foregroundStyle(OnboardingTheme.coral)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.paper))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(OnboardingTheme.coral.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)

                Button { grade(correct: true) } label: {
                    Label("Biliyorum", systemImage: "checkmark")
                        .font(.headline.bold()).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.teal))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.play")
                .font(.system(size: 50)).foregroundStyle(OnboardingTheme.teal.opacity(0.5))
            Text("Tekrar edecek kelime yok")
                .font(.title3.bold()).foregroundStyle(OnboardingTheme.ink)
            Text("Önce kamerayla obje çekerek kelime biriktir.")
                .font(.subheadline).foregroundStyle(OnboardingTheme.ink.opacity(0.6))
                .multilineTextAlignment(.center)
            Spacer(); Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var finishedState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56)).foregroundStyle(OnboardingTheme.teal)
            Text("Tekrar bitti 🎉")
                .font(.title2.bold()).foregroundStyle(OnboardingTheme.ink)
            Text("\(reviewedCount) kelime tekrar edildi.")
                .font(.subheadline).foregroundStyle(OnboardingTheme.ink.opacity(0.6))
            Button(action: onClose) {
                Text("Bitir").font(.headline.bold()).foregroundStyle(.white)
                    .padding(.horizontal, 30).frame(height: 50)
                    .background(Capsule().fill(OnboardingTheme.teal))
            }
            .padding(.top, 4)
            Spacer(); Spacer()
        }
    }

    private func grade(correct: Bool) {
        let object = queue[index]
        store.recordWordResult(wordId: object.english, correct: correct)
        reviewedCount += 1
        revealed = false
        withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
    }
}
