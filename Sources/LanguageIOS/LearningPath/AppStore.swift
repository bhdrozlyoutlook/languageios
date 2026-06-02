import Foundation
import Observation

/// View-facing app state. Stays the single `@Observable` source of truth, but persistence
/// now goes through injected repositories (so backend/sync can slot in later) and every
/// state change emits analytics + crash breadcrumbs. Public API is unchanged.
@Observable
public final class AppStore {
    public private(set) var hasCompletedOnboarding: Bool
    public private(set) var targetLanguage: TargetLanguage?
    public private(set) var lastError: AppError?

    @ObservationIgnored private let profiles: ProfileRepository
    @ObservationIgnored private let progressRepo: ProgressRepository
    @ObservationIgnored private let settings: SettingsRepository
    @ObservationIgnored private let analytics: AnalyticsService
    @ObservationIgnored private let logger: AppLogging
    @ObservationIgnored private let crashReporter: CrashReporter
    @ObservationIgnored private let gamificationRepo: GamificationRepository
    @ObservationIgnored private let notifications: NotificationScheduling

    private var progressByLanguage: [String: LearningProgress]
    private var gamification: GamificationState

    public init(environment: AppEnvironment) {
        self.profiles = environment.profileRepository
        self.progressRepo = environment.progressRepository
        self.settings = environment.settingsRepository
        self.analytics = environment.analytics
        self.logger = environment.logger
        self.crashReporter = environment.crashReporter
        self.gamificationRepo = environment.gamificationRepository
        self.notifications = environment.notifications

        self.hasCompletedOnboarding = environment.settingsRepository.hasCompletedOnboarding
        self.targetLanguage = environment.settingsRepository.lastTargetLanguage
        self.progressByLanguage = environment.progressRepository.allProgress()
        self.gamification = environment.gamificationRepository.load()
    }

    /// Convenience back-compat initializer: builds a live environment over the given
    /// defaults. Keeps existing tests and `#Preview`s working unchanged.
    public convenience init(defaults: UserDefaults = .standard) {
        self.init(environment: .live(defaults: defaults))
    }

    // MARK: Reads

    public func progress(for language: TargetLanguage) -> LearningProgress {
        progressByLanguage[language.rawValue] ?? LearningProgress()
    }

    // MARK: Mutations

    public func completeOnboarding(with profile: OnboardingProfile) {
        hasCompletedOnboarding = true
        targetLanguage = profile.targetLanguage ?? targetLanguage
        let userProfile = UserProfile(from: profile)
        do {
            try profiles.save(userProfile)
            try settings.setOnboardingCompleted(true)
            try settings.setLastTargetLanguage(targetLanguage)
        } catch {
            handle(error, context: "completeOnboarding", fallbackKey: PersistenceSchema.profileKey)
        }
        crashReporter.recordBreadcrumb("onboarding completed", category: .onboarding)
        analytics.track(OnboardingFunnel.completed(userProfile))
    }

    public func completeCurrentStop(for language: TargetLanguage, total: Int) {
        var current = progress(for: language)
        let completedIndex = current.completedCount
        current.completeCurrentStop(total: total)
        progressByLanguage[language.rawValue] = current
        do {
            try progressRepo.save(current, for: language)
        } catch {
            handle(error, context: "completeCurrentStop", fallbackKey: PersistenceSchema.progressKey)
        }
        crashReporter.recordBreadcrumb("stop \(completedIndex) completed (\(language.rawValue))", category: .map)
        analytics.track(LearningPathAnalytics.stopCompleted(language: language, index: completedIndex, total: total))
        if current.isFinished(total: total) {
            analytics.track(LearningPathAnalytics.journeyFinished(language: language, total: total))
        }
    }

    public func resetProgress(for language: TargetLanguage) {
        progressByLanguage[language.rawValue] = LearningProgress()
        do {
            try progressRepo.reset(for: language)
        } catch {
            handle(error, context: "resetProgress", fallbackKey: PersistenceSchema.progressKey)
        }
        analytics.track(LearningPathAnalytics.progressReset(language: language))
    }

    public func resetAll() {
        hasCompletedOnboarding = false
        targetLanguage = nil
        progressByLanguage = [:]
        gamification = GamificationState()
        do {
            try settings.setOnboardingCompleted(false)
            try settings.setLastTargetLanguage(nil)
            try progressRepo.resetAll()
            try profiles.clear()
            try gamificationRepo.clear()
        } catch {
            handle(error, context: "resetAll", fallbackKey: PersistenceSchema.settingsKey)
        }
        analytics.track(LearningPathAnalytics.appReset())
    }

    // MARK: Gamification

    public var xp: Int { gamification.xp }
    public var streak: Int { gamification.streak }
    public var maxHearts: Int { GamificationState.maxHearts }

    public func availableHearts() -> Int { gamification.availableHearts(now: Date()) }
    public func secondsUntilNextHeart() -> TimeInterval? { gamification.secondsUntilNextHeart(now: Date()) }
    public func stars(forStop stopId: String) -> Int { gamification.stars(for: stopId) }
    public func canStartLesson() -> Bool { availableHearts() > 0 }

    /// Word ids the user has missed; review prioritizes these.
    public var missedWordIds: Set<String> { gamification.missedWordIds }

    public func recordWordResult(wordId: String, correct: Bool) {
        gamification.recordWordResult(wordId: wordId, correct: correct)
        persistGamification()
    }

    /// Words captured via object labeling.
    public var capturedWordCount: Int { gamification.capturedWords.count }

    public func captureWord(_ english: String) {
        gamification.capturedWords.insert(english)
        persistGamification()
        analytics.track(AnalyticsEvent(name: "object_word_captured", params: ["word": english]))
    }

    // MARK: Profile & stats

    public var totalStars: Int { gamification.starsByStop.values.reduce(0, +) }
    public var completedStopCount: Int { progressByLanguage.values.reduce(0) { $0 + $1.completedCount } }
    public func userProfile() -> UserProfile? { profiles.loadProfile() }

    /// Daily goal progress: lessons/practices done today vs the onboarding target.
    public var activitiesToday: Int { gamification.activitiesToday }
    public var dailyGoalTarget: Int { profiles.loadProfile()?.dailyGoal?.targetActivities ?? 2 }
    public var dailyGoalReached: Bool { activitiesToday >= dailyGoalTarget }

    public func completedStopCount(for language: TargetLanguage) -> Int {
        progress(for: language).completedCount
    }

    /// Records a finished practice/review session: awards XP and extends the streak.
    /// Unlike a lesson, it has no heart cost and no stop completion.
    public func recordPracticeCompleted(stars: Int) {
        let xpGain = 5 + 5 * max(0, stars)
        let previousStreak = gamification.streak
        gamification.recordPractice(xpGain: xpGain, now: Date())
        persistGamification()
        analytics.track(GamificationAnalytics.xpEarned(amount: xpGain, total: gamification.xp))
        if gamification.streak > previousStreak {
            analytics.track(GamificationAnalytics.streakExtended(days: gamification.streak))
        }
        notifications.cancelHeartRefill()
        rescheduleStreakReminder()
    }

    /// Switches the active learning language; the home map re-renders for it.
    public func setTargetLanguage(_ language: TargetLanguage) {
        guard language != targetLanguage else { return }
        targetLanguage = language
        do {
            try settings.setLastTargetLanguage(language)
        } catch {
            handle(error, context: "setTargetLanguage", fallbackKey: PersistenceSchema.settingsKey)
        }
    }

    // MARK: Reminder settings

    public var dailyReminderEnabled: Bool { settings.dailyReminderEnabled }

    public func reminderTime() -> ReminderTime {
        profiles.loadProfile()?.reminderTime ?? .defaultReminder
    }

    public func setDailyReminderEnabled(_ enabled: Bool) {
        do {
            try settings.setDailyReminderEnabled(enabled)
        } catch {
            handle(error, context: "setDailyReminderEnabled", fallbackKey: PersistenceSchema.settingsKey)
        }
        if enabled {
            Task { _ = await notifications.requestAuthorization() }
            rescheduleStreakReminder()
        } else {
            notifications.cancelDailyReminder()
        }
    }

    public func setReminderTime(_ time: ReminderTime) {
        var profile = profiles.loadProfile() ?? UserProfile()
        profile.reminderTime = time
        do {
            try profiles.save(profile)
        } catch {
            handle(error, context: "setReminderTime", fallbackKey: PersistenceSchema.profileKey)
        }
        if settings.dailyReminderEnabled {
            rescheduleStreakReminder()
        }
    }

    public func recordLessonPassed(stopId: String, stars: Int) {
        let previousStreak = gamification.streak
        gamification.recordPass(stopId: stopId, stars: stars, now: Date())
        persistGamification()
        analytics.track(GamificationAnalytics.xpEarned(
            amount: GamificationState.xpForPass(stars: stars), total: gamification.xp
        ))
        if gamification.streak > previousStreak {
            analytics.track(GamificationAnalytics.streakExtended(days: gamification.streak))
        }
        notifications.cancelHeartRefill()
        rescheduleStreakReminder()
    }

    public func recordLessonFailed() {
        gamification.loseHeart(now: Date())
        persistGamification()
        if availableHearts() == 0 {
            analytics.track(GamificationAnalytics.heartsDepleted())
            if let seconds = gamification.secondsUntilNextHeart(now: Date()) {
                notifications.scheduleHeartRefill(
                    after: seconds,
                    body: "Canların yenilendi, öğrenmeye kaldığın yerden devam et!"
                )
            }
        }
    }

    private func rescheduleStreakReminder() {
        guard let reminder = profiles.loadProfile()?.reminderTime else { return }
        notifications.scheduleDailyReminder(at: reminder, body: streakReminderBody(streak: gamification.streak))
    }

    private func streakReminderBody(streak: Int) -> String {
        if streak >= 2 {
            return "🔥 \(streak) günlük serini koru — bugünkü dersin hazır!"
        }
        return "Bugünkü dersinle serini başlat 💪"
    }

    private func persistGamification() {
        do {
            try gamificationRepo.save(gamification)
        } catch {
            handle(error, context: "persistGamification", fallbackKey: PersistenceSchema.gamificationKey)
        }
    }

    public func clearError() {
        lastError = nil
    }

    // MARK: Errors

    private func handle(_ error: Error, context: String, fallbackKey: String) {
        let appError = (error as? AppError) ?? .persistenceWrite(key: fallbackKey)
        lastError = appError
        logger.error("\(context) failed: \(appError)", category: .persistence)
        crashReporter.recordBreadcrumb("error in \(context): \(appError.id)", category: .persistence)
    }
}
