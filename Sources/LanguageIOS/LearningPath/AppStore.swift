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
    @ObservationIgnored private let captureRepo: CaptureRepository
    @ObservationIgnored private let entitlementRepo: EntitlementRepository
    @ObservationIgnored private let purchases: PurchaseService
    /// One owned calendar (ISO-8601, Monday weeks) threaded through every entitlement read
    /// and write so the period boundary never disagrees between them.
    @ObservationIgnored private let entitlementCalendar: Calendar

    private var progressByLanguage: [String: LearningProgress]
    private var gamification: GamificationState
    private var profile: UserProfile?
    private var entitlement: EntitlementState

    public init(environment: AppEnvironment) {
        self.profiles = environment.profileRepository
        self.progressRepo = environment.progressRepository
        self.settings = environment.settingsRepository
        self.analytics = environment.analytics
        self.logger = environment.logger
        self.crashReporter = environment.crashReporter
        self.gamificationRepo = environment.gamificationRepository
        self.notifications = environment.notifications
        self.captureRepo = environment.captureRepository
        self.entitlementRepo = environment.entitlementRepository
        self.purchases = environment.purchaseService
        self.entitlementCalendar = Calendar(identifier: .iso8601)

        self.hasCompletedOnboarding = environment.settingsRepository.hasCompletedOnboarding
        self.targetLanguage = environment.settingsRepository.lastTargetLanguage
        self.progressByLanguage = environment.progressRepository.allProgress()
        self.gamification = environment.gamificationRepository.load()
        self.profile = environment.profileRepository.loadProfile()
        self.entitlement = environment.entitlementRepository.load()
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
        self.profile = userProfile
        do {
            try profiles.save(userProfile)
            try settings.setOnboardingCompleted(true)
            try settings.setLastTargetLanguage(targetLanguage)
        } catch {
            handle(error, context: "completeOnboarding", fallbackKey: PersistenceSchema.profileKey)
        }
        // Switch the UI to the chosen native language for the rest of the app.
        AppLanguage.apply(userProfile.nativeLanguage)
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
        profile = nil
        entitlement = EntitlementState()
        do {
            try settings.setOnboardingCompleted(false)
            try settings.setLastTargetLanguage(nil)
            try progressRepo.resetAll()
            try profiles.clear()
            try gamificationRepo.clear()
            try entitlementRepo.clear()
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

    /// The captured-word collection, newest first (grouping by day happens in the view).
    public func capturedObjects() -> [CapturedObject] { captureRepo.all() }

    /// Cutout PNG for a captured object, if one was stored.
    public func captureImage(forID id: String) -> Data? { captureRepo.image(forID: id) }

    /// Persist a freshly captured object (cutout sticker + word) into the collection,
    /// and credit it toward the captured-word count/streak via the existing path.
    @discardableResult
    public func captureObject(
        english: String,
        native: String,
        image: Data?,
        now: Date = Date()
    ) -> CapturedObject {
        let object = CapturedObject(
            id: UUID().uuidString,
            english: english,
            native: native,
            language: targetLanguage ?? .englishUS,
            capturedAt: now
        )
        captureRepo.add(object, image: image)
        captureWord(english)
        return object
    }

    public func removeCapturedObject(id: String) {
        captureRepo.remove(id: id)
    }

    // MARK: Entitlement (photo-word learning quota + tokens)

    public var isPremium: Bool { entitlement.tier == .premium }
    public var tokenBalance: Int { entitlement.tokenBalance }
    /// Free analyses granted each period: 10 (premium) / 0 (freemium).
    public var photoQuotaLimit: Int { entitlement.freeQuota }

    public func photoQuotaRemaining(now: Date = Date()) -> Int {
        entitlement.freeAnalysesRemaining(now: now, calendar: entitlementCalendar)
    }

    public func canCapturePhoto(now: Date = Date()) -> Bool {
        entitlement.canStartAnalysis(now: now, calendar: entitlementCalendar)
    }

    /// "haftaki" / "aydaki" for period-aware copy.
    public func currentPeriodWord() -> String {
        let value: String.LocalizationValue = entitlement.period == .weekly ? "haftaki" : "aydaki"
        return String(localized: value)
    }

    public func tokenPackages() -> [PurchaseProductInfo] {
        PurchaseProductInfo.placeholderCatalog().filter { if case .tokens = $0.product { return true } else { return false } }
    }

    public func premiumPlans() -> [PurchaseProductInfo] {
        PurchaseProductInfo.placeholderCatalog().filter { if case .premium = $0.product { return true } else { return false } }
    }

    /// Spends one analysis right before the photo is sent to Gemini. Returns what was
    /// charged, or `nil` if nothing is available (caller must not proceed).
    @discardableResult
    public func consumePhotoQuota(now: Date = Date()) -> AnalysisCharge? {
        guard let charge = entitlement.consumeAnalysis(now: now, calendar: entitlementCalendar) else {
            return nil
        }
        persistEntitlement()
        analytics.track(EntitlementAnalytics.analysisConsumed(
            charge: charge,
            freeLeft: photoQuotaRemaining(now: now),
            tokens: entitlement.tokenBalance
        ))
        return charge
    }

    /// Returns a charged unit when the Gemini call failed or was cancelled.
    public func refundPhotoQuota(_ charge: AnalysisCharge) {
        entitlement.refundAnalysis(charge)
        persistEntitlement()
        analytics.track(EntitlementAnalytics.analysisRefunded(charge: charge))
    }

    // MARK: Purchases (local now; StoreKit later)

    public func loadProducts() async -> [PurchaseProductInfo] {
        await purchases.products()
    }

    public func purchasePremium(_ period: RenewalPeriod, now: Date = Date()) async {
        analytics.track(EntitlementAnalytics.purchaseStarted(product: PurchaseProduct.premium(period)))
        await applyOutcome(purchases.purchasePremium(period: period, now: now), now: now)
    }

    public func buyTokens(_ pack: TokenPack, now: Date = Date()) async {
        analytics.track(EntitlementAnalytics.purchaseStarted(product: PurchaseProduct.tokens(pack)))
        await applyOutcome(purchases.buyTokens(pack: pack, now: now), now: now)
    }

    public func restorePurchases(now: Date = Date()) async {
        await applyOutcome(purchases.restore(now: now), now: now)
        analytics.track(EntitlementAnalytics.restore())
    }

    /// At launch, reconcile the (local) subscription standing: drop premium if it expired,
    /// keeping the token balance intact.
    public func reconcileEntitlements(now: Date = Date()) async {
        let status = await purchases.subscriptionStatus(now: now)
        if let status, status.isActive(now: now) {
            if entitlement.tier != .premium || entitlement.period != status.period {
                entitlement.setTier(.premium, period: status.period, now: now, calendar: entitlementCalendar)
                persistEntitlement()
            }
        } else if entitlement.tier == .premium {
            entitlement.setTier(.freemium, period: entitlement.period, now: now, calendar: entitlementCalendar)
            persistEntitlement()
        }
    }

    private func applyOutcome(_ outcome: PurchaseOutcome, now: Date) async {
        guard case .success(let grants) = outcome else { return } // cancelled/pending/failed grant nothing
        for grant in grants {
            switch grant.kind {
            case .premium(let period, _):
                entitlement.setTier(.premium, period: period, now: now, calendar: entitlementCalendar)
            case .tokens(let count):
                entitlement.addTokens(count)
            }
            analytics.track(EntitlementAnalytics.purchaseSucceeded(grant: grant))
        }
        if !grants.isEmpty { persistEntitlement() }
    }

    private func persistEntitlement() {
        do {
            try entitlementRepo.save(entitlement)
        } catch {
            handle(error, context: "persistEntitlement", fallbackKey: PersistenceSchema.entitlementKey)
        }
    }

    // MARK: Account (local, offline-first)

    public var isSignedIn: Bool { settings.account != nil }
    public var displayName: String? { settings.account?.displayName }

    public func signIn(appleUserId: String, displayName: String?) {
        do {
            try settings.setAccount(Account(appleUserId: appleUserId, displayName: displayName))
        } catch {
            handle(error, context: "signIn", fallbackKey: PersistenceSchema.settingsKey)
        }
        analytics.track(AnalyticsEvent(name: "account_signed_in", params: ["provider": "apple"]))
    }

    public func signOut() {
        do {
            try settings.clearAccount()
        } catch {
            handle(error, context: "signOut", fallbackKey: PersistenceSchema.settingsKey)
        }
        analytics.track(AnalyticsEvent(name: "account_signed_out"))
    }

    // MARK: Profile & stats

    public var totalStars: Int { gamification.starsByStop.values.reduce(0, +) }
    public var completedStopCount: Int { progressByLanguage.values.reduce(0) { $0 + $1.completedCount } }
    public func userProfile() -> UserProfile? { profile }

    /// Daily goal progress: lessons/practices done today vs the onboarding target.
    public var activitiesToday: Int { gamification.activitiesToday }
    public var dailyGoalTarget: Int { profile?.dailyGoal?.targetActivities ?? 2 }
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
        profile?.reminderTime ?? .defaultReminder
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
        var updatedProfile = profile ?? UserProfile()
        updatedProfile.reminderTime = time
        profile = updatedProfile
        do {
            try profiles.save(updatedProfile)
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
        guard let reminder = profile?.reminderTime else { return }
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
