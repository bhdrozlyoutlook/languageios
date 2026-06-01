import SwiftUI

// MARK: - Flashcard

/// Introduces a new word (not graded). Speaks the target word and shows its translation.
struct FlashcardExerciseView: View {
    let item: VocabularyItem
    let language: TargetLanguage
    let speech: SpeechService
    let onResult: (Bool) -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Yeni kelime")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.55))

            Text(item.target)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(OnboardingTheme.ink)
                .multilineTextAlignment(.center)

            speakButton(item.target, size: .title)

            Text(item.native)
                .font(.title2)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.7))

            if let example = item.example {
                Text(example)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(OnboardingTheme.ink.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Spacer()
            LessonActionButton(title: "Anladım", tint: OnboardingTheme.teal) { onResult(true) }
        }
        .frame(maxWidth: .infinity)
        .onAppear { speech.speak(item.target, language: language) }
    }

    private func speakButton(_ text: String, size: Font) -> some View {
        Button { speech.speak(text, language: language) } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(size)
                .foregroundStyle(OnboardingTheme.teal)
        }
        .accessibilityLabel("Seslendir")
    }
}

// MARK: - Choice (multiple choice + listen-and-select)

struct ChoiceExerciseView: View {
    let prompt: VocabularyItem
    let options: [String]
    let correct: String
    let isAudioPrompt: Bool
    let language: TargetLanguage
    let speech: SpeechService
    let onResult: (Bool) -> Void

    @State private var shuffled: [String] = []
    @State private var selected: String?
    @State private var checked = false

    private var isCorrect: Bool { selected == correct }

    var body: some View {
        VStack(spacing: 18) {
            promptView

            VStack(spacing: 10) {
                ForEach(shuffled, id: \.self) { option in
                    OptionRow(text: option, state: state(for: option)) {
                        if !checked { selected = option }
                    }
                }
            }

            Spacer()

            CheckFooter(
                checked: checked,
                isCorrect: isCorrect,
                canCheck: selected != nil,
                onCheck: { checked = true },
                onContinue: { onResult(isCorrect) }
            )
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            shuffled = options.shuffled()
            if isAudioPrompt { speech.speak(prompt.target, language: language) }
        }
    }

    @ViewBuilder
    private var promptView: some View {
        VStack(spacing: 12) {
            Text(isAudioPrompt ? "Dinle ve seç" : "Bu kelimenin çevirisi?")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.55))

            if isAudioPrompt {
                Button { speech.speak(prompt.target, language: language) } label: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(OnboardingTheme.teal)
                        .frame(width: 96, height: 96)
                        .background(Circle().fill(OnboardingTheme.teal.opacity(0.15)))
                }
                .accessibilityLabel("Tekrar dinle")
            } else {
                HStack(spacing: 10) {
                    Text(prompt.target)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(OnboardingTheme.ink)
                    Button { speech.speak(prompt.target, language: language) } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.title3)
                            .foregroundStyle(OnboardingTheme.teal)
                    }
                    .accessibilityLabel("Seslendir")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func state(for option: String) -> OptionState {
        if checked {
            if option == correct { return .correct }
            if option == selected { return .wrong }
            return .idle
        }
        return option == selected ? .selected : .idle
    }
}

// MARK: - Type the answer

struct TypeAnswerExerciseView: View {
    let item: VocabularyItem
    let language: TargetLanguage
    let speech: SpeechService
    let onResult: (Bool) -> Void

    @State private var text = ""
    @State private var checked = false

    private var isCorrect: Bool { Exercise.answersMatch(text, item.target) }
    private var canCheck: Bool { !text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(spacing: 18) {
            Text("Bunu hedef dilde yaz")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.55))
                .padding(.top, 8)

            Text(item.native)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(OnboardingTheme.ink)

            TextField("Cevabını yaz", text: $text)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .font(.title3)
                .disabled(checked)

            if checked, !isCorrect {
                Text("Doğru cevap: \(item.target)")
                    .font(.subheadline.bold())
                    .foregroundStyle(OnboardingTheme.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()

            CheckFooter(
                checked: checked,
                isCorrect: isCorrect,
                canCheck: canCheck,
                onCheck: {
                    checked = true
                    speech.speak(item.target, language: language)
                },
                onContinue: { onResult(isCorrect) }
            )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Matching

struct MatchingExerciseView: View {
    let items: [VocabularyItem]
    let onResult: (Bool) -> Void

    @State private var leftOrder: [VocabularyItem] = []
    @State private var rightOrder: [VocabularyItem] = []
    @State private var selectedLeft: String?
    @State private var selectedRight: String?
    @State private var matched: Set<String> = []
    @State private var mistakes = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Kelimeleri eşleştir")
                .font(.subheadline)
                .foregroundStyle(OnboardingTheme.ink.opacity(0.55))
                .padding(.top, 8)

            HStack(alignment: .top, spacing: 12) {
                column(leftOrder, isLeft: true)
                column(rightOrder, isLeft: false)
            }

            Spacer()

            if matched.count == items.count {
                LessonActionButton(title: "Devam", tint: OnboardingTheme.teal) {
                    onResult(mistakes == 0)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            leftOrder = items.shuffled()
            rightOrder = items.shuffled()
        }
    }

    private func column(_ list: [VocabularyItem], isLeft: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(list) { item in
                chip(item, isLeft: isLeft)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func chip(_ item: VocabularyItem, isLeft: Bool) -> some View {
        let isMatched = matched.contains(item.id)
        let isSelected = (isLeft ? selectedLeft : selectedRight) == item.id
        return Button { tap(item.id, isLeft: isLeft) } label: {
            Text(isLeft ? item.target : item.native)
                .font(.callout.weight(.semibold))
                .foregroundStyle(isMatched ? OnboardingTheme.ink.opacity(0.35) : OnboardingTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isMatched ? OnboardingTheme.teal.opacity(0.18) : (isSelected ? OnboardingTheme.teal.opacity(0.3) : OnboardingTheme.paper))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? OnboardingTheme.ink : OnboardingTheme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
    }

    private func tap(_ id: String, isLeft: Bool) {
        if isLeft { selectedLeft = id } else { selectedRight = id }
        guard let left = selectedLeft, let right = selectedRight else { return }
        if left == right {
            matched.insert(left)
        } else {
            mistakes += 1
        }
        selectedLeft = nil
        selectedRight = nil
    }
}

// MARK: - Option row

enum OptionState {
    case idle, selected, correct, wrong
}

struct OptionRow: View {
    let text: String
    let state: OptionState
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .font(.headline)
                    .foregroundStyle(foreground)
                Spacer()
                if let icon {
                    Image(systemName: icon).foregroundStyle(foreground)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var icon: String? {
        switch state {
        case .correct: "checkmark.circle.fill"
        case .wrong: "xmark.circle.fill"
        case .idle, .selected: nil
        }
    }

    private var foreground: Color {
        switch state {
        case .correct: .green
        case .wrong: OnboardingTheme.coral
        case .selected: OnboardingTheme.ink
        case .idle: OnboardingTheme.ink
        }
    }

    private var background: Color {
        switch state {
        case .correct: Color.green.opacity(0.12)
        case .wrong: OnboardingTheme.coral.opacity(0.12)
        case .selected: OnboardingTheme.teal.opacity(0.18)
        case .idle: OnboardingTheme.paper
        }
    }

    private var border: Color {
        switch state {
        case .correct: .green
        case .wrong: OnboardingTheme.coral
        case .selected: OnboardingTheme.ink
        case .idle: OnboardingTheme.cardBorder
        }
    }
}
