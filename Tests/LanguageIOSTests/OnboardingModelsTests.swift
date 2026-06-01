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

        profile.targetLanguage = .englishUS
        XCTAssertTrue(profile.canContinue(from: .targetLanguage))
        XCTAssertFalse(profile.canContinue(from: .nativeLanguage))

        profile.nativeLanguage = .turkish
        XCTAssertTrue(profile.canContinue(from: .nativeLanguage))
        XCTAssertFalse(profile.canContinue(from: .ageRange))

        profile.ageRange = .adult
        XCTAssertTrue(profile.canContinue(from: .ageRange))
        XCTAssertFalse(profile.canContinue(from: .learningPurpose))

        profile.toggleLearningPurpose(.travel)
        XCTAssertTrue(profile.canContinue(from: .learningPurpose))
        XCTAssertFalse(profile.canContinue(from: .currentLevel))

        profile.toggleCurrentLevel(.beginner)
        XCTAssertTrue(profile.canContinue(from: .currentLevel))
        XCTAssertFalse(profile.canContinue(from: .learningStyle))

        profile.learningStyles = [.aiExplanations]
        XCTAssertTrue(profile.canContinue(from: .learningStyle))
        XCTAssertFalse(profile.canContinue(from: .dailyGoal))

        profile.dailyGoal = .tenMinutes
        XCTAssertTrue(profile.canContinue(from: .dailyGoal))
        XCTAssertFalse(profile.canContinue(from: .reminderTime))

        profile.reminderTime = .defaultReminder
        XCTAssertTrue(profile.canContinue(from: .reminderTime))
        XCTAssertTrue(profile.canContinue(from: .planSummary))
        XCTAssertTrue(profile.canContinue(from: .auth))
    }

    func testCurrentLevelToggleSupportsMultipleValues() {
        var profile = OnboardingProfile()

        profile.toggleCurrentLevel(.beginner)
        profile.toggleCurrentLevel(.listening)
        XCTAssertEqual(profile.currentLevels, [.beginner, .listening])

        profile.toggleCurrentLevel(.beginner)
        XCTAssertEqual(profile.currentLevels, [.listening])
    }

    func testPlanCardsAreDerivedFromSelectedLearningStyles() {
        let profile = OnboardingProfile(
            targetLanguage: .englishUS,
            nativeLanguage: .turkish,
            currentLevels: [.basicVocabulary, .listening],
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

    func testFlowResetReturnsToWelcomeAndClearsProfile() {
        var flow = OnboardingFlowState(
            currentStep: .planSummary,
            profile: OnboardingProfile(
                targetLanguage: .englishUK,
                nativeLanguage: .turkish,
                currentLevels: [.beginner],
                learningStyles: [.cameraObjects],
                dailyGoal: .tenMinutes
            )
        )

        flow.reset()

        XCTAssertEqual(flow.currentStep, .welcome)
        XCTAssertEqual(flow.profile, OnboardingProfile())
    }

    func testTypewriterTextRevealsCharactersByVisibleCount() {
        let typewriter = TypewriterText(fullText: "Dinleyerek öğren")

        XCTAssertEqual(typewriter.visibleText(characterCount: 0), "")
        XCTAssertEqual(typewriter.visibleText(characterCount: 1), "D")
        XCTAssertEqual(typewriter.visibleText(characterCount: 10), "Dinleyerek")
        XCTAssertEqual(typewriter.visibleText(characterCount: 99), "Dinleyerek öğren")
    }

    func testLanguageOptionsExposeFlagsAndDescriptions() {
        XCTAssertEqual(TargetLanguage.englishUK.flag, "🇬🇧")
        XCTAssertEqual(TargetLanguage.englishUS.flag, "🇺🇸")
        XCTAssertEqual(TargetLanguage.turkish.flag, "🇹🇷")
        XCTAssertEqual(TargetLanguage.german.subtitle, "Almanya")
    }

    func testLanguageOptionsExposeISOCountryCodes() {
        XCTAssertEqual(TargetLanguage.englishUK.countryCode, "GB")
        XCTAssertEqual(TargetLanguage.englishUS.countryCode, "US")
        XCTAssertEqual(TargetLanguage.turkish.countryCode, "TR")
        XCTAssertEqual(TargetLanguage.german.countryCode, "DE")
        XCTAssertEqual(TargetLanguage.spanish.countryCode, "ES")
        XCTAssertEqual(TargetLanguage.french.countryCode, "FR")
    }

    func testLevelOptionsExposeLearningRangeDescriptions() {
        XCTAssertEqual(CurrentLevel.allCases.count, 7)
        XCTAssertEqual(CurrentLevel.beginner.subtitle, "A1 • Harfler, sayılar ve ilk kelimeler")
        XCTAssertEqual(CurrentLevel.basicVocabulary.subtitle, "A2 • Selamlaşma, alışveriş ve günlük kelimeler")
        XCTAssertEqual(CurrentLevel.listening.subtitle, "B1+ • Podcast, dizi, film ve konuşmalar")
        XCTAssertEqual(CurrentLevel.reading.subtitle, "B1+ • Kitap, makale ve uzun mesajlar")
        XCTAssertEqual(CurrentLevel.speaking.subtitle, "B1-B2 • Sohbet, karşılıklı konuşma, görüş")
        XCTAssertEqual(CurrentLevel.writing.subtitle, "B1+ • E-posta, kompozisyon, mesajlaşma")
        XCTAssertEqual(CurrentLevel.advancedGrammar.subtitle, "C1-C2 • Karmaşık yapı, nüans ve ileri ifade")
    }

    func testLanguageDetectionFromLocaleIdentifier() {
        XCTAssertEqual(TargetLanguage.from(localeIdentifier: "tr"), .turkish)
        XCTAssertEqual(TargetLanguage.from(localeIdentifier: "tr-TR"), .turkish)
        XCTAssertEqual(TargetLanguage.from(localeIdentifier: "en"), .englishUS)
        XCTAssertEqual(TargetLanguage.from(localeIdentifier: "en-US"), .englishUS)
        XCTAssertEqual(TargetLanguage.from(localeIdentifier: "en-GB"), .englishUK)
        XCTAssertEqual(TargetLanguage.from(localeIdentifier: "en_au"), .englishUK)
        XCTAssertEqual(TargetLanguage.from(localeIdentifier: "de"), .german)
        XCTAssertEqual(TargetLanguage.from(localeIdentifier: "es"), .spanish)
        XCTAssertEqual(TargetLanguage.from(localeIdentifier: "fr"), .french)
        XCTAssertNil(TargetLanguage.from(localeIdentifier: "ja"))
        XCTAssertNil(TargetLanguage.from(localeIdentifier: ""))
    }

    func testOnboardingStepCountMatchesSpec() {
        XCTAssertEqual(OnboardingStep.allCases.count, 11)
        XCTAssertEqual(OnboardingStep.allCases.first, .welcome)
        XCTAssertEqual(OnboardingStep.allCases.last, .auth)
    }

    func testReminderTimeFormatsHourAndMinute() {
        XCTAssertEqual(ReminderTime(hour: 8, minute: 0).formatted, "08:00")
        XCTAssertEqual(ReminderTime(hour: 12, minute: 30).formatted, "12:30")
        XCTAssertEqual(ReminderTime.defaultReminder.formatted, "19:00")
    }

    func testReminderTimeClampsOutOfRangeValues() {
        let invalid = ReminderTime(hour: 30, minute: 99)
        XCTAssertEqual(invalid.hour, 23)
        XCTAssertEqual(invalid.minute, 59)

        let negative = ReminderTime(hour: -2, minute: -5)
        XCTAssertEqual(negative.hour, 0)
        XCTAssertEqual(negative.minute, 0)
    }

    func testReminderTimeDefaultReminderUsesSingleClockValue() {
        XCTAssertEqual(ReminderTime.defaultReminder.hour, 19)
        XCTAssertEqual(ReminderTime.defaultReminder.minute, 0)
        XCTAssertEqual(ReminderTime.defaultReminder.formatted, "19:00")
    }

    func testLearningPurposeToggleSupportsMultipleValues() {
        var profile = OnboardingProfile()

        profile.toggleLearningPurpose(.travel)
        profile.toggleLearningPurpose(.work)
        XCTAssertEqual(profile.learningPurposes, [.travel, .work])

        profile.toggleLearningPurpose(.travel)
        XCTAssertEqual(profile.learningPurposes, [.work])
    }

    func testLearningPurposeOptionsExposeDescriptions() {
        XCTAssertEqual(LearningPurpose.allCases.count, 6)
        XCTAssertEqual(LearningPurpose.travel.title, "Seyahat")
        XCTAssertEqual(LearningPurpose.work.title, "İş ve kariyer")
        XCTAssertEqual(LearningPurpose.education.title, "Eğitim ve sınav")
        XCTAssertEqual(LearningPurpose.travel.subtitle, "Yurt dışı tatil ve gezilerde rahat iletişim")
    }

    func testAgeRangeOptionsExposeDescriptions() {
        XCTAssertEqual(AgeRange.allCases.count, 7)
        XCTAssertEqual(AgeRange.allCases.first, .preschool)
        XCTAssertEqual(AgeRange.preschool.title, "Okul öncesi (3-5 yaş)")
        XCTAssertEqual(AgeRange.primary.title, "İlkokul (6-10 yaş)")
        XCTAssertEqual(AgeRange.teen.title, "13-17")
        XCTAssertEqual(AgeRange.youngAdult.title, "18-24")
        XCTAssertEqual(AgeRange.adult.title, "25-34")
        XCTAssertEqual(AgeRange.midAdult.title, "35-49")
        XCTAssertEqual(AgeRange.mature.title, "50+")
        XCTAssertEqual(AgeRange.preschool.subtitle, "Şarkı, hikaye ve görsellerle eğlenceli tanışma")
        XCTAssertEqual(AgeRange.primary.subtitle, "Okul derslerine destek, oyun temelli aktiviteler")
    }

    func testAgeRangeRelevantLevelsAreAgeAppropriate() {
        XCTAssertEqual(AgeRange.preschool.relevantLevels, [.beginner, .listening, .speaking])
        XCTAssertEqual(
            AgeRange.primary.relevantLevels,
            [.beginner, .basicVocabulary, .listening, .speaking, .reading, .writing]
        )
        XCTAssertEqual(AgeRange.teen.relevantLevels, CurrentLevel.allCases)
        XCTAssertEqual(AgeRange.adult.relevantLevels, CurrentLevel.allCases)
        XCTAssertEqual(AgeRange.mature.relevantLevels, CurrentLevel.allCases)
    }

    func testAuthProviderButtonStylesMatchPrimaryButtonLanguage() {
        XCTAssertTrue(AuthProviderButton.Style.primary.usesInkBackground)
        XCTAssertFalse(AuthProviderButton.Style.secondary.usesInkBackground)
    }
}
