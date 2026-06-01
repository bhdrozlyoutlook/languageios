import Foundation

/// Persistence-facing snapshot of everything onboarding collects. Decoupled from the
/// UI working model (`OnboardingProfile`, which uses `Set`s) so the storage schema can
/// evolve independently. Sets become sorted arrays for stable, Codable-friendly storage.
public struct UserProfile: Codable, Equatable {
    public var targetLanguage: TargetLanguage?
    public var nativeLanguage: TargetLanguage?
    public var ageRange: AgeRange?
    public var learningPurposes: [LearningPurpose]
    public var currentLevels: [CurrentLevel]
    public var learningStyles: [LearningStyle]
    public var dailyGoal: DailyGoal?
    public var reminderTime: ReminderTime?

    public init(
        targetLanguage: TargetLanguage? = nil,
        nativeLanguage: TargetLanguage? = nil,
        ageRange: AgeRange? = nil,
        learningPurposes: [LearningPurpose] = [],
        currentLevels: [CurrentLevel] = [],
        learningStyles: [LearningStyle] = [],
        dailyGoal: DailyGoal? = nil,
        reminderTime: ReminderTime? = nil
    ) {
        self.targetLanguage = targetLanguage
        self.nativeLanguage = nativeLanguage
        self.ageRange = ageRange
        self.learningPurposes = learningPurposes
        self.currentLevels = currentLevels
        self.learningStyles = learningStyles
        self.dailyGoal = dailyGoal
        self.reminderTime = reminderTime
    }

    /// Adapts the UI working model into the storage model (Set → sorted Array).
    public init(from profile: OnboardingProfile) {
        self.init(
            targetLanguage: profile.targetLanguage,
            nativeLanguage: profile.nativeLanguage,
            ageRange: profile.ageRange,
            learningPurposes: profile.learningPurposes.sorted { $0.rawValue < $1.rawValue },
            currentLevels: profile.currentLevels.sorted { $0.rawValue < $1.rawValue },
            learningStyles: profile.learningStyles.sorted { $0.rawValue < $1.rawValue },
            dailyGoal: profile.dailyGoal,
            reminderTime: profile.reminderTime
        )
    }

    /// Adapts back to the UI working model (Array → Set).
    public func asOnboardingProfile() -> OnboardingProfile {
        OnboardingProfile(
            targetLanguage: targetLanguage,
            nativeLanguage: nativeLanguage,
            ageRange: ageRange,
            learningPurposes: Set(learningPurposes),
            currentLevels: Set(currentLevels),
            learningStyles: Set(learningStyles),
            dailyGoal: dailyGoal,
            reminderTime: reminderTime
        )
    }
}
