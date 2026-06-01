# Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first SwiftUI onboarding module: seven screens, local answer state, a derived personal plan summary, and final auth choice entry points.

**Architecture:** Start with a Swift Package so the onboarding model and SwiftUI views can compile and be tested in this empty workspace. Keep onboarding state local in `OnboardingView`, put pure derivation logic in value models, and isolate reusable UI into small SwiftUI components.

**Tech Stack:** Swift 5.9+, Swift Package Manager, SwiftUI, XCTest.

---

## File Structure

- `Package.swift`: declares the `LanguageIOS` library and `LanguageIOSTests`.
- `Sources/LanguageIOS/Onboarding/OnboardingModels.swift`: enums and value models for onboarding answers and plan cards.
- `Sources/LanguageIOS/Onboarding/OnboardingView.swift`: seven-step SwiftUI onboarding flow.
- `Sources/LanguageIOS/Onboarding/OnboardingComponents.swift`: progress indicator, option card, primary button, and auth button.
- `Tests/LanguageIOSTests/OnboardingModelsTests.swift`: tests for validation, selection, and personal plan derivation.

## Tasks

### Task 1: Package Scaffold

**Files:**
- Create: `Package.swift`
- Create: `Sources/LanguageIOS/Onboarding/OnboardingModels.swift`
- Test: `Tests/LanguageIOSTests/OnboardingModelsTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Tests/LanguageIOSTests/OnboardingModelsTests.swift`:

```swift
import XCTest
@testable import LanguageIOS

final class OnboardingModelsTests: XCTestCase {
    func testLearningStyleSelectionSupportsMultipleValues() {
        var profile = OnboardingProfile()

        profile.toggleLearningStyle(.cameraObjects)
        profile.toggleLearningStyle(.musicLyrics)

        XCTAssertEqual(profile.learningStyles, [.cameraObjects, .musicLyrics])
    }

    func testLearningStyleToggleRemovesExistingValue() {
        var profile = OnboardingProfile(learningStyles: [.cameraObjects, .musicLyrics])

        profile.toggleLearningStyle(.cameraObjects)

        XCTAssertEqual(profile.learningStyles, [.musicLyrics])
    }

    func testRequiredAnswersAreValidatedPerStep() {
        var profile = OnboardingProfile()

        XCTAssertTrue(profile.canContinue(from: .welcome))
        XCTAssertFalse(profile.canContinue(from: .targetLanguage))

        profile.targetLanguage = .english
        XCTAssertTrue(profile.canContinue(from: .targetLanguage))
        XCTAssertFalse(profile.canContinue(from: .currentLevel))

        profile.currentLevel = .beginner
        XCTAssertTrue(profile.canContinue(from: .currentLevel))
        XCTAssertFalse(profile.canContinue(from: .learningStyle))

        profile.learningStyles = [.aiExplanations]
        XCTAssertTrue(profile.canContinue(from: .learningStyle))
        XCTAssertFalse(profile.canContinue(from: .dailyGoal))

        profile.dailyGoal = .tenMinutes
        XCTAssertTrue(profile.canContinue(from: .dailyGoal))
        XCTAssertTrue(profile.canContinue(from: .planSummary))
        XCTAssertTrue(profile.canContinue(from: .auth))
    }

    func testPlanCardsAreDerivedFromSelectedLearningStyles() {
        let profile = OnboardingProfile(
            targetLanguage: .english,
            currentLevel: .basic,
            learningStyles: [.cameraObjects, .musicLyrics, .speakingPractice],
            dailyGoal: .fifteenMinutes
        )

        let titles = profile.planCards.map(\.title)

        XCTAssertEqual(titles, [
            "Gerçek dünyadan kelime yakalama",
            "Şarkı sözleriyle kalıp öğrenme",
            "Native telaffuz ve sesli tekrar",
            "15 dakikalık günlük ritim"
        ])
    }
}
```

- [ ] **Step 2: Run tests to verify failure**

Run: `swift test`

Expected: FAIL because `Package.swift` and `LanguageIOS` do not exist yet.

- [ ] **Step 3: Add package and model implementation**

Create `Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LanguageIOS",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "LanguageIOS", targets: ["LanguageIOS"])
    ],
    targets: [
        .target(name: "LanguageIOS"),
        .testTarget(name: "LanguageIOSTests", dependencies: ["LanguageIOS"])
    ]
)
```

Create `Sources/LanguageIOS/Onboarding/OnboardingModels.swift`:

```swift
import Foundation

public enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case targetLanguage
    case currentLevel
    case learningStyle
    case dailyGoal
    case planSummary
    case auth

    public var id: Int { rawValue }
    public var isLast: Bool { self == Self.allCases.last }
}

public enum TargetLanguage: String, CaseIterable, Identifiable {
    case english
    case turkish
    case german
    case spanish
    case french

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .english: "İngilizce"
        case .turkish: "Türkçe"
        case .german: "Almanca"
        case .spanish: "İspanyolca"
        case .french: "Fransızca"
        }
    }
}

public enum CurrentLevel: String, CaseIterable, Identifiable {
    case beginner
    case basic
    case speaking
    case advanced

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .beginner: "Yeni başlıyorum"
        case .basic: "Temel biliyorum"
        case .speaking: "Konuşmak istiyorum"
        case .advanced: "İleri seviye"
        }
    }
}

public enum LearningStyle: String, CaseIterable, Identifiable {
    case cameraObjects
    case musicLyrics
    case speakingPractice
    case dailyLessons
    case aiExplanations

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cameraObjects: "Kamera ile objeler"
        case .musicLyrics: "Müzik ve şarkı sözleri"
        case .speakingPractice: "Konuşma pratiği"
        case .dailyLessons: "Kısa günlük dersler"
        case .aiExplanations: "AI açıklamalar"
        }
    }
}

public enum DailyGoal: Int, CaseIterable, Identifiable {
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30

    public var id: Int { rawValue }
    public var title: String { "\(rawValue) dakika" }
}

public struct PlanCard: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
}

public struct OnboardingProfile: Equatable {
    public var targetLanguage: TargetLanguage?
    public var currentLevel: CurrentLevel?
    public var learningStyles: Set<LearningStyle>
    public var dailyGoal: DailyGoal?

    public init(
        targetLanguage: TargetLanguage? = nil,
        currentLevel: CurrentLevel? = nil,
        learningStyles: Set<LearningStyle> = [],
        dailyGoal: DailyGoal? = nil
    ) {
        self.targetLanguage = targetLanguage
        self.currentLevel = currentLevel
        self.learningStyles = learningStyles
        self.dailyGoal = dailyGoal
    }

    public mutating func toggleLearningStyle(_ style: LearningStyle) {
        if learningStyles.contains(style) {
            learningStyles.remove(style)
        } else {
            learningStyles.insert(style)
        }
    }

    public func canContinue(from step: OnboardingStep) -> Bool {
        switch step {
        case .welcome, .planSummary, .auth:
            true
        case .targetLanguage:
            targetLanguage != nil
        case .currentLevel:
            currentLevel != nil
        case .learningStyle:
            !learningStyles.isEmpty
        case .dailyGoal:
            dailyGoal != nil
        }
    }

    public var planCards: [PlanCard] {
        var cards: [PlanCard] = []

        if learningStyles.contains(.cameraObjects) {
            cards.append(.init(
                id: "camera",
                title: "Gerçek dünyadan kelime yakalama",
                detail: "Kamerayla gördüğün objeleri etiketleyip tekrar listene ekle."
            ))
        }

        if learningStyles.contains(.musicLyrics) {
            cards.append(.init(
                id: "music",
                title: "Şarkı sözleriyle kalıp öğrenme",
                detail: "Dinlediğin müziklerdeki kelimeleri Türkçe ve hedef dil arasında keşfet."
            ))
        }

        if learningStyles.contains(.speakingPractice) {
            cards.append(.init(
                id: "voice",
                title: "Native telaffuz ve sesli tekrar",
                detail: "Doğal sesleri dinleyip kendi konuşmanı pratik et."
            ))
        }

        if learningStyles.contains(.aiExplanations) {
            cards.append(.init(
                id: "ai",
                title: "AI ile hata analizi",
                detail: "Cümlelerini analiz ettir, hatalarını kısa açıklamalarla öğren."
            ))
        }

        if learningStyles.contains(.dailyLessons) || cards.isEmpty {
            cards.append(.init(
                id: "lessons",
                title: "Kısa günlük dersler",
                detail: "Her gün küçük ve tamamlanabilir pratiklerle ritim kur."
            ))
        }

        if let dailyGoal {
            cards.append(.init(
                id: "goal",
                title: "\(dailyGoal.rawValue) dakikalık günlük ritim",
                detail: "Planın günlük hedefini koruyacak şekilde ayarlanır."
            ))
        }

        return cards
    }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `swift test`

Expected: PASS, all onboarding model tests pass.

### Task 2: SwiftUI Components

**Files:**
- Create: `Sources/LanguageIOS/Onboarding/OnboardingComponents.swift`

- [ ] **Step 1: Add reusable SwiftUI components**

Create `Sources/LanguageIOS/Onboarding/OnboardingComponents.swift`:

```swift
import SwiftUI

struct OnboardingProgressView: View {
    let currentIndex: Int
    let totalCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalCount, id: \.self) { index in
                Capsule()
                    .fill(index <= currentIndex ? Color.accentColor : Color.secondary.opacity(0.2))
                    .frame(height: 5)
            }
        }
        .accessibilityLabel("Onboarding progress")
        .accessibilityValue("\(currentIndex + 1) of \(totalCount)")
    }
}

struct OnboardingOptionCard: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}

struct AuthProviderButton: View {
    let systemImage: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .frame(width: 24)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}
```

- [ ] **Step 2: Build package**

Run: `swift build`

Expected: PASS.

### Task 3: Seven-Step Onboarding View

**Files:**
- Create: `Sources/LanguageIOS/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Add the onboarding root view**

Create `Sources/LanguageIOS/Onboarding/OnboardingView.swift`:

```swift
import SwiftUI

public struct OnboardingView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @State private var profile = OnboardingProfile()
    @State private var authMessage: String?

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            OnboardingProgressView(
                currentIndex: currentStep.rawValue,
                totalCount: OnboardingStep.allCases.count
            )

            currentContent
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if currentStep != .auth {
                OnboardingPrimaryButton(
                    title: currentStep == .planSummary ? "Planımı kaydet" : "Devam et",
                    isEnabled: profile.canContinue(from: currentStep),
                    action: advance
                )
            }
        }
        .padding(20)
        .animation(.easeInOut(duration: 0.2), value: currentStep)
    }

    @ViewBuilder
    private var currentContent: some View {
        switch currentStep {
        case .welcome:
            WelcomeStepView()
        case .targetLanguage:
            SingleSelectionStepView(
                title: "Hangi dili öğrenmek istiyorsun?",
                options: TargetLanguage.allCases,
                selected: profile.targetLanguage,
                titleProvider: \.title
            ) { profile.targetLanguage = $0 }
        case .currentLevel:
            SingleSelectionStepView(
                title: "Şu an seviyen nasıl?",
                options: CurrentLevel.allCases,
                selected: profile.currentLevel,
                titleProvider: \.title
            ) { profile.currentLevel = $0 }
        case .learningStyle:
            LearningStyleStepView(profile: $profile)
        case .dailyGoal:
            SingleSelectionStepView(
                title: "Günde ne kadar çalışmak istersin?",
                options: DailyGoal.allCases,
                selected: profile.dailyGoal,
                titleProvider: \.title
            ) { profile.dailyGoal = $0 }
        case .planSummary:
            PersonalPlanSummaryView(profile: profile)
        case .auth:
            AuthChoiceView(message: $authMessage)
        }
    }

    private func advance() {
        guard profile.canContinue(from: currentStep),
              let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1)
        else { return }

        currentStep = nextStep
    }
}

private struct WelcomeStepView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 24)

            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.tint)

            Text("Dil öğrenmeyi hayatına taşı")
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)

            Text("Gördüğün objelerden, dinlediğin şarkılardan ve konuşma pratiğinden sana özel dersler oluştur.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SingleSelectionStepView<Option>: View where Option: Identifiable & Equatable {
    let title: String
    let options: [Option]
    let selected: Option?
    let titleProvider: KeyPath<Option, String>
    let select: (Option) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                ForEach(options) { option in
                    OnboardingOptionCard(
                        title: option[keyPath: titleProvider],
                        subtitle: nil,
                        isSelected: selected == option
                    ) {
                        select(option)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LearningStyleStepView: View {
    @Binding var profile: OnboardingProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("En çok nasıl öğrenmek istersin?")
                .font(.title.bold())
                .fixedSize(horizontal: false, vertical: true)

            Text("Birden fazla seçim yapabilirsin.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(LearningStyle.allCases) { style in
                    OnboardingOptionCard(
                        title: style.title,
                        subtitle: nil,
                        isSelected: profile.learningStyles.contains(style)
                    ) {
                        profile.toggleLearningStyle(style)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PersonalPlanSummaryView: View {
    let profile: OnboardingProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Planın hazır")
                    .font(.title.bold())

                Text("Seçimlerine göre ilk öğrenme planını hazırladık.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(profile.planCards) { card in
                    OnboardingOptionCard(
                        title: card.title,
                        subtitle: card.detail,
                        isSelected: true,
                        action: {}
                    )
                    .allowsHitTesting(false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AuthChoiceView: View {
    @Binding var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Planını kaydet")
                .font(.title.bold())

            Text("Hesabınla ilerlemen, etiketlerin ve öğrenme geçmişin saklanır.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                AuthProviderButton(systemImage: "apple.logo", title: "Apple ile devam et") {
                    message = "Apple giriş bağlantısı sonraki modülde eklenecek."
                }

                AuthProviderButton(systemImage: "g.circle", title: "Google ile devam et") {
                    message = "Google giriş bağlantısı sonraki modülde eklenecek."
                }

                AuthProviderButton(systemImage: "envelope", title: "E-posta ile devam et") {
                    message = "E-posta girişi sonraki modülde eklenecek."
                }
            }

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Zaten hesabım var") {
                message = "Giriş ekranı sonraki modülde eklenecek."
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OnboardingView()
}
```

- [ ] **Step 2: Build package**

Run: `swift build`

Expected: PASS.

### Task 4: Final Verification

**Files:**
- Modify only if verification finds compile or test failures.

- [ ] **Step 1: Run full test suite**

Run: `swift test`

Expected: PASS.

- [ ] **Step 2: Run full build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 3: Record git status**

Run: `git status --short`

Expected: If the workspace is not a git repo, record that commit is unavailable. If a repo exists later, commit with:

```bash
git add Package.swift Sources Tests docs
git commit -m "feat: add onboarding flow"
```
