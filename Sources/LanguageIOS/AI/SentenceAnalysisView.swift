import SwiftUI

/// "AI açıklamalar": write a sentence, get corrections + short notes. Uses an injected
/// `SentenceAnalyzing` (heuristic stub today; a real LLM adapter later).
public struct SentenceAnalysisView: View {
    private let analyzer: SentenceAnalyzing
    private let speech: SpeechService
    private let language: TargetLanguage
    private let onClose: () -> Void

    @State private var input = ""
    @State private var isAnalyzing = false
    @State private var result: SentenceAnalysis?

    public init(
        analyzer: SentenceAnalyzing = HeuristicSentenceAnalyzer(),
        speech: SpeechService,
        language: TargetLanguage,
        onClose: @escaping () -> Void
    ) {
        self.analyzer = analyzer
        self.speech = speech
        self.language = language
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 16) {
            topBar

            Text("Hedef dilde bir cümle yaz; düzeltip kısa notlar verelim.")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.62))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            TextField("Cümleni yaz", text: $input, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .font(.title3)
                .padding(.horizontal, 20)

            Button {
                Task { await analyze() }
            } label: {
                Label("Analiz et", systemImage: "sparkles")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(OnboardingTheme.teal))
            }
            .buttonStyle(.plain)
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty || isAnalyzing)
            .opacity(input.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .padding(.horizontal, 20)

            if isAnalyzing {
                ProgressView().padding(.top, 6)
            } else if let result {
                resultCard(result)
            }

            Spacer()

            Text("Şimdilik temel dilbilgisi kontrolü; gelişmiş AI analiz yakında.")
                .font(.caption2)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.4))
                .padding(.bottom, 8)
        }
        .padding(.top, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingTheme.background.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Text("AI cümle analizi")
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

    private func resultCard(_ result: SentenceAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "wand.and.stars")
                    .foregroundStyle(result.isCorrect ? .green : OnboardingTheme.teal)
                Text(result.isCorrect ? "Doğru görünüyor" : "Önerilen düzeltme")
                    .font(.subheadline.bold())
                    .foregroundStyle(OnboardingTheme.ink)
                Spacer()
                Button { speech.speak(result.corrected, language: language) } label: {
                    Image(systemName: "speaker.wave.2.fill").foregroundStyle(OnboardingTheme.teal)
                }
                .accessibilityLabel("Seslendir")
            }

            Text(result.corrected)
                .font(.title3.weight(.semibold))
                .foregroundStyle(OnboardingTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(result.notes.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(OnboardingTheme.ink.opacity(0.5))
                        .padding(.top, 2)
                    Text(result.notes[index])
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(OnboardingTheme.paper))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(OnboardingTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func analyze() async {
        isAnalyzing = true
        result = nil
        result = await analyzer.analyze(input, language: language)
        isAnalyzing = false
    }
}
