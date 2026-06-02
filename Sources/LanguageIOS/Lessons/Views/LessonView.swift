import SwiftUI

/// Hosts one lesson: top bar (close, hearts, progress), the current exercise, and the
/// pass/fail result. Owns the `LessonSession`; calls `onPassed` when the lesson is won.
public struct LessonView: View {
    @State private var session: LessonSession
    private let speech: SpeechService
    private let onPassed: (Int) -> Void
    private let onFailed: () -> Void
    private let onClose: () -> Void

    public init(
        lesson: Lesson,
        analytics: AnalyticsService,
        speech: SpeechService,
        onPassed: @escaping (Int) -> Void,
        onFailed: @escaping () -> Void = {},
        onWordResult: @escaping (VocabularyItem, Bool) -> Void = { _, _ in },
        onClose: @escaping () -> Void
    ) {
        _session = State(initialValue: LessonSession(lesson: lesson, analytics: analytics, onWordResult: onWordResult))
        self.speech = speech
        self.onPassed = onPassed
        self.onFailed = onFailed
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .background(OnboardingTheme.background.ignoresSafeArea())
        .onChange(of: session.status) { _, newValue in
            if newValue == .failed { onFailed() }
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Dersi kapat")

            ProgressView(value: session.progress)
                .tint(OnboardingTheme.teal)

            HStack(spacing: 3) {
                ForEach(0..<LessonSession.maxHearts, id: \.self) { index in
                    Image(systemName: index < session.hearts ? "heart.fill" : "heart")
                        .font(.subheadline)
                        .foregroundStyle(index < session.hearts ? OnboardingTheme.coral : OnboardingTheme.cardBorder)
                }
            }
            .accessibilityLabel("\(session.hearts) can")
        }
        .padding(.bottom, 10)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch session.status {
        case .inProgress:
            if let exercise = session.currentExercise {
                exerciseView(exercise)
                    .id(session.currentIndex)
            }
        case .passed:
            LessonResultView(
                passed: true,
                stars: session.stars,
                xpEarned: GamificationState.xpForPass(stars: session.stars),
                onPrimary: { onPassed(session.stars) },
                onSecondary: nil
            )
        case .failed:
            LessonResultView(
                passed: false,
                stars: 0,
                xpEarned: 0,
                onPrimary: { session.restart() },
                onSecondary: onClose
            )
        }
    }

    @ViewBuilder
    private func exerciseView(_ exercise: Exercise) -> some View {
        let language = session.lesson.language
        switch exercise {
        case .flashcard(let item):
            FlashcardExerciseView(item: item, language: language, speech: speech, onResult: handleResult)
        case .multipleChoice(let prompt, let options, let correct):
            ChoiceExerciseView(
                prompt: prompt, options: options, correct: correct, isAudioPrompt: false,
                language: language, speech: speech, onResult: handleResult
            )
        case .listenSelect(let prompt, let options, let correct):
            ChoiceExerciseView(
                prompt: prompt, options: options, correct: correct, isAudioPrompt: true,
                language: language, speech: speech, onResult: handleResult
            )
        case .typeAnswer(let item):
            TypeAnswerExerciseView(item: item, language: language, speech: speech, onResult: handleResult)
        case .matching(let items):
            MatchingExerciseView(items: items, onResult: handleResult)
        }
    }

    private func handleResult(_ correct: Bool) {
        if session.currentExercise?.isGraded == true {
            correct ? Haptics.success() : Haptics.warning()
        }
        session.submit(correct: correct)
        if session.status == .passed {
            Haptics.success()
        }
    }
}

// MARK: - Result

struct LessonResultView: View {
    let passed: Bool
    let stars: Int
    let xpEarned: Int
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text(passed ? "Tebrikler! 🎉" : "Canların bitti 💔")
                .font(.system(size: 32, weight: .black, design: .serif))
                .foregroundStyle(OnboardingTheme.ink)
                .multilineTextAlignment(.center)

            if passed {
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Image(systemName: index < stars ? "star.fill" : "star")
                            .font(.title)
                            .foregroundStyle(index < stars ? OnboardingTheme.coral : OnboardingTheme.cardBorder)
                    }
                }

                Text("+\(xpEarned) XP")
                    .font(.headline.bold())
                    .foregroundStyle(OnboardingTheme.teal)
            }

            Text(passed ? "Bu durağı tamamladın." : "Bir nefes al ve tekrar dene.")
                .font(.title3)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()

            LessonActionButton(
                title: passed ? "Devam et" : "Tekrar dene",
                tint: passed ? OnboardingTheme.teal : OnboardingTheme.ink,
                action: onPrimary
            )

            if let onSecondary {
                Button("Haritaya dön", action: onSecondary)
                    .font(.headline)
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.6))
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared controls

/// Bottom "Kontrol Et" → "Devam" button with inline correct/wrong feedback.
struct CheckFooter: View {
    let checked: Bool
    let isCorrect: Bool
    let canCheck: Bool
    let onCheck: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if checked {
                HStack(spacing: 8) {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    Text(isCorrect ? "Doğru!" : "Yanlış")
                }
                .font(.headline.bold())
                .foregroundStyle(isCorrect ? Color.green : OnboardingTheme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            LessonActionButton(
                title: checked ? "Devam" : "Kontrol Et",
                tint: checked ? (isCorrect ? .green : OnboardingTheme.coral) : OnboardingTheme.ink,
                isEnabled: checked || canCheck,
                action: checked ? onContinue : onCheck
            )
        }
    }
}

struct LessonActionButton: View {
    let title: String
    var tint: Color = OnboardingTheme.ink
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isEnabled ? tint : OnboardingTheme.disabled)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
