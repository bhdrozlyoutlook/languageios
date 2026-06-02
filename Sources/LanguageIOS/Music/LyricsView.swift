import SwiftUI

/// "Şarkıdan öğren": type a song + artist, get a handful of common phrases in the target
/// language with Turkish translations + audio. Uses an injected `LyricsProviding` (on-device
/// starter set today; Gemini when a key is set). Optionally saves a phrase to the collection.
public struct LyricsView: View {
    private let provider: LyricsProviding
    private let speech: SpeechService
    private let language: TargetLanguage
    private let onClose: () -> Void

    @State private var title = ""
    @State private var artist = ""
    @State private var isLoading = false
    @State private var analysis: LyricsAnalysis?

    public init(
        provider: LyricsProviding = StubLyricsProvider(),
        speech: SpeechService,
        language: TargetLanguage,
        onClose: @escaping () -> Void
    ) {
        self.provider = provider
        self.speech = speech
        self.language = language
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 14) {
            topBar

            Text("Bir şarkı + sanatçı yaz; sözlerinden sık geçen kalıpları Türkçesiyle öğren.")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            TextField("Şarkı adı", text: $title)
                .textFieldStyle(.roundedBorder).font(.title3).padding(.horizontal, 20)
            TextField("Sanatçı", text: $artist)
                .textFieldStyle(.roundedBorder).font(.title3).padding(.horizontal, 20)

            Button {
                Task { await load() }
            } label: {
                Label("Şarkıdan öğren", systemImage: "music.note")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.teal))
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .padding(.horizontal, 20)

            if isLoading {
                ProgressView().padding(.top, 6)
            } else if let analysis {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(analysis.phrases) { phrase in
                            phraseCard(phrase)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }

            Spacer(minLength: 0)

            Text("Telif sebebiyle şarkı sözleri değil, sık kullanılan kalıplar öğretilir.")
                .font(.caption2)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingTheme.background.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Text("Şarkıyla öğren")
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

    private func phraseCard(_ phrase: LyricPhrase) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(phrase.phrase)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(OnboardingTheme.ink)
                Spacer()
                Button { speech.speak(phrase.phrase, language: language) } label: {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(OnboardingTheme.teal)
                }
                .accessibilityLabel("Seslendir")
            }
            Text(phrase.native)
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.7))
            if let note = phrase.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.paper))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1))
    }

    private func load() async {
        isLoading = true
        analysis = nil
        analysis = await provider.phrases(title: title, artist: artist, language: language)
        isLoading = false
    }
}
