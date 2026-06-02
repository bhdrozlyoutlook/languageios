import SwiftUI

/// "Şarkıdan öğren": type a song + artist, get a handful of common phrases in the target
/// language with native translations + audio. Uses an injected `LyricsProviding` (on-device
/// starter set today; Gemini when a key is set). We teach common phrases, not lyrics.
public struct LyricsView: View {
    private let provider: LyricsProviding
    private let speech: SpeechService
    private let language: TargetLanguage
    private let native: TargetLanguage
    private let onClose: () -> Void

    @State private var title = ""
    @State private var artist = ""
    @State private var isLoading = false
    @State private var analysis: LyricsAnalysis?
    @State private var selectedPhraseIndex = 0

    public init(
        provider: LyricsProviding = StubLyricsProvider(),
        speech: SpeechService,
        language: TargetLanguage,
        native: TargetLanguage = .turkish,
        onClose: @escaping () -> Void
    ) {
        self.provider = provider
        self.speech = speech
        self.language = language
        self.native = native
        self.onClose = onClose
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                LyricsPlayerTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        topBar
                        artwork(size: min(geometry.size.width - 72, 312))
                        metadata
                        progressStrip
                        transportControls
                        inputPanel
                        contentState
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var display: LyricsNowPlayingDisplay {
        LyricsNowPlayingDisplay(
            title: analysis?.title ?? title,
            artist: analysis?.artist ?? artist,
            selectedIndex: selectedPhraseIndex,
            phraseCount: phrases.count
        )
    }

    private var phrases: [LyricPhrase] {
        analysis?.phrases ?? []
    }

    private var selectedPhrase: LyricPhrase? {
        guard !phrases.isEmpty else { return nil }
        return phrases[min(max(selectedPhraseIndex, 0), phrases.count - 1)]
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.white.opacity(0.12)))
            }
            .accessibilityLabel("Kapat")

            Spacer()

            VStack(spacing: 2) {
                Text("Şarkıyla öğren")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text("Şimdi Öğreniliyor")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(LyricsPlayerTheme.accent)
            }
            .textCase(.uppercase)
            .tracking(0.6)

            Spacer()

            Image(systemName: "ellipsis.circle.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 38, height: 38)
                .accessibilityHidden(true)
        }
    }

    private func artwork(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            LyricsPlayerTheme.artworkHot,
                            LyricsPlayerTheme.accent,
                            LyricsPlayerTheme.artworkDeep
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: size * 0.64, height: size * 0.64)
                .blur(radius: 12)
                .offset(x: -size * 0.16, y: -size * 0.18)

            VStack(spacing: 14) {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.18, weight: .black))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.24), radius: 14, y: 8)

                Text(language.englishName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.black.opacity(0.18)))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: LyricsPlayerTheme.accent.opacity(0.38), radius: 34, y: 24)
        .shadow(color: .black.opacity(0.42), radius: 18, y: 10)
        .accessibilityHidden(true)
    }

    private var metadata: some View {
        VStack(spacing: 7) {
            Text(display.title)
                .font(.system(size: 29, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(display.artist)
                .font(.headline.weight(.semibold))
                .foregroundStyle(LyricsPlayerTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(display.queueCountText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.46))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var progressStrip: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.16))
                    Capsule()
                        .fill(.white.opacity(0.92))
                        .frame(width: geo.size.width * display.progressFraction)
                        .animation(.easeInOut(duration: 0.2), value: display.progressFraction)
                }
            }
            .frame(height: 5)

            HStack {
                Text(phrases.isEmpty ? "0" : "\(min(selectedPhraseIndex + 1, phrases.count))")
                Spacer()
                Text("\(phrases.count)")
            }
            .font(.caption2.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var transportControls: some View {
        HStack(spacing: 30) {
            transportButton(systemName: "backward.fill", size: 28, isEnabled: selectedPhraseIndex > 0) {
                selectedPhraseIndex = max(selectedPhraseIndex - 1, 0)
            }

            Button {
                speakSelectedPhrase()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(LyricsPlayerTheme.playerBlack)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(.white))
            }
            .buttonStyle(.plain)
            .disabled(selectedPhrase == nil)
            .opacity(selectedPhrase == nil ? 0.36 : 1)
            .accessibilityLabel("Seçili kalıbı seslendir")

            transportButton(systemName: "forward.fill", size: 28, isEnabled: selectedPhraseIndex < phrases.count - 1) {
                selectedPhraseIndex = min(selectedPhraseIndex + 1, max(phrases.count - 1, 0))
            }
        }
    }

    private func transportButton(systemName: String, size: CGFloat, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .black))
                .foregroundStyle(.white.opacity(isEnabled ? 0.9 : 0.28))
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityHidden(!isEnabled)
    }

    private var inputPanel: some View {
        VStack(spacing: 10) {
            appleMusicField("Şarkı adı", text: $title)
            appleMusicField("Sanatçı", text: $artist)

            Button {
                Task { await load() }
            } label: {
                Label(isLoading ? "Analiz ediliyor" : "Şarkıdan öğren", systemImage: "waveform")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(LyricsPlayerTheme.accent)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .opacity(isLoading ? 0.72 : 1)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.09))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func appleMusicField(_ prompt: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(prompt).foregroundStyle(.white.opacity(0.42)))
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.black.opacity(0.26))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var contentState: some View {
        if isLoading {
            loadingPanel
        } else if let analysis {
            phraseQueue(analysis)
        } else {
            emptyPanel
        }
    }

    private var loadingPanel: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.12)
            Text("Şarkı analiz ediliyor")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(queueBackground)
    }

    private var emptyPanel: some View {
        VStack(spacing: 10) {
            Image(systemName: "quote.bubble.fill")
                .font(.title2)
                .foregroundStyle(LyricsPlayerTheme.accent)
            Text("Henüz kalıp yok")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
            Text("Şarkı sözleri gösterilmez; günlük kalıplar öğretilir.")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 18)
        .background(queueBackground)
    }

    private func phraseQueue(_ analysis: LyricsAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Öğrenme kuyruğu", systemImage: "text.quote")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(analysis.phrases.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.48))
            }

            ForEach(Array(analysis.phrases.enumerated()), id: \.element.id) { index, phrase in
                phraseRow(phrase, index: index)
            }
        }
        .padding(14)
        .background(queueBackground)
    }

    private func phraseRow(_ phrase: LyricPhrase, index: Int) -> some View {
        let isSelected = index == selectedPhraseIndex

        return HStack(spacing: 12) {
            Button {
                selectedPhraseIndex = index
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(phrase.phrase)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(phrase.native)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))

                    if let note = phrase.note {
                        Text(note)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white.opacity(0.44))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(phrase.phrase), \(phrase.native)")

            Button {
                selectedPhraseIndex = index
                speech.speak(phrase.phrase, language: language)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isSelected ? LyricsPlayerTheme.playerBlack : .white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(isSelected ? .white : .white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Seslendir")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? .white.opacity(0.17) : .white.opacity(0.075))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isSelected ? .white.opacity(0.2) : .white.opacity(0.06), lineWidth: 1)
        }
    }

    private var queueBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.black.opacity(0.22))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.07), lineWidth: 1)
            }
    }

    private func speakSelectedPhrase() {
        guard let selectedPhrase else { return }
        speech.speak(selectedPhrase.phrase, language: language)
    }

    private func load() async {
        isLoading = true
        analysis = nil
        selectedPhraseIndex = 0
        analysis = await provider.phrases(title: title, artist: artist, language: language, native: native)
        selectedPhraseIndex = 0
        isLoading = false
    }
}

private enum LyricsPlayerTheme {
    static let playerBlack = Color(red: 0.03, green: 0.03, blue: 0.035)
    static let accent = Color(red: 1.0, green: 0.18, blue: 0.34)
    static let artworkHot = Color(red: 1.0, green: 0.56, blue: 0.62)
    static let artworkDeep = Color(red: 0.12, green: 0.03, blue: 0.05)

    static let background = LinearGradient(
        colors: [
            Color(red: 0.36, green: 0.08, blue: 0.12),
            Color(red: 0.10, green: 0.05, blue: 0.07),
            playerBlack
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
