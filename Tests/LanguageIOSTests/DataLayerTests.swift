import XCTest
@testable import LanguageIOS

final class DataLayerTests: XCTestCase {

    func testProfileRepositoryRoundTripsAllEightFields() throws {
        let store = InMemoryKeyValueStore()
        let repo = UserDefaultsProfileRepository(store: store, logger: NoopLogger())

        let profile = UserProfile(
            targetLanguage: .englishUS,
            nativeLanguage: .turkish,
            ageRange: .youngAdult,
            learningPurposes: [.education, .media],
            currentLevels: [.beginner, .listening],
            learningStyles: [.musicLyrics],
            dailyGoal: .thirtyMinutes,
            reminderTime: ReminderTime(hour: 8, minute: 30)
        )
        try repo.save(profile)

        XCTAssertEqual(repo.loadProfile(), profile)
    }

    func testUserProfileAdapterPreservesOnboardingData() {
        let onboarding = OnboardingProfile(
            targetLanguage: .french,
            nativeLanguage: .turkish,
            ageRange: .adult,
            learningPurposes: [.travel, .work],
            currentLevels: [.speaking],
            learningStyles: [.speakingPractice, .dailyLessons],
            dailyGoal: .tenMinutes,
            reminderTime: .defaultReminder
        )

        let snapshot = UserProfile(from: onboarding)
        XCTAssertEqual(snapshot.learningPurposes.count, 2)
        XCTAssertEqual(snapshot.asOnboardingProfile(), onboarding)
    }

    func testSettingsRepositoryPersistsAcrossInstances() throws {
        let store = InMemoryKeyValueStore()
        let repo = UserDefaultsSettingsRepository(store: store, logger: NoopLogger())
        XCTAssertFalse(repo.hasCompletedOnboarding)

        try repo.setOnboardingCompleted(true)
        try repo.setLastTargetLanguage(.german)

        let restored = UserDefaultsSettingsRepository(store: store, logger: NoopLogger())
        XCTAssertTrue(restored.hasCompletedOnboarding)
        XCTAssertEqual(restored.lastTargetLanguage, .german)
    }

    func testProgressRepositoryIsolatesLanguages() throws {
        let store = InMemoryKeyValueStore()
        let repo = UserDefaultsProgressRepository(store: store, logger: NoopLogger())

        try repo.save(LearningProgress(completedCount: 3), for: .spanish)
        XCTAssertEqual(repo.progress(for: .spanish).completedCount, 3)
        XCTAssertEqual(repo.progress(for: .german).completedCount, 0)
    }

    // MARK: Migration

    private struct LegacyState: Codable {
        var hasCompletedOnboarding: Bool
        var targetLanguageRaw: String?
        var progress: [String: LearningProgress]
    }

    func testMigrationFromLegacyV1BlobIsLossless() throws {
        let store = InMemoryKeyValueStore()
        let legacy = LegacyState(
            hasCompletedOnboarding: true,
            targetLanguageRaw: "german",
            progress: [
                "french": LearningProgress(completedCount: 2),
                "german": LearningProgress(completedCount: 1)
            ]
        )
        store.set(try JSONEncoder().encode(legacy), forKey: PersistenceSchema.legacyAppStateKey)

        StoreMigrator(store: store, logger: NoopLogger()).migrateIfNeeded()

        let settings = UserDefaultsSettingsRepository(store: store, logger: NoopLogger())
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(settings.lastTargetLanguage, .german)

        let progress = UserDefaultsProgressRepository(store: store, logger: NoopLogger())
        XCTAssertEqual(progress.progress(for: .french).completedCount, 2)
        XCTAssertEqual(progress.progress(for: .german).completedCount, 1)

        let profile = UserDefaultsProfileRepository(store: store, logger: NoopLogger())
        XCTAssertEqual(profile.loadProfile()?.targetLanguage, .german)

        // Legacy blob is preserved as a rollback safety net.
        XCTAssertNotNil(store.data(forKey: PersistenceSchema.legacyAppStateKey))
    }

    func testMigrationIsSkippedWhenV2AlreadyExists() throws {
        let store = InMemoryKeyValueStore()
        let settings = UserDefaultsSettingsRepository(store: store, logger: NoopLogger())
        try settings.setOnboardingCompleted(true)

        // A legacy blob that must be ignored because v2 already exists.
        store.set(Data("garbage".utf8), forKey: PersistenceSchema.legacyAppStateKey)
        StoreMigrator(store: store, logger: NoopLogger()).migrateIfNeeded()

        XCTAssertTrue(settings.hasCompletedOnboarding)
    }

    func testAppStoreSurfacesErrorWhenWriteFails() {
        let store = AppStore(environment: makeFailingProfileEnvironment())
        XCTAssertNil(store.lastError)

        store.completeOnboarding(with: OnboardingProfile(targetLanguage: .german))

        XCTAssertEqual(store.lastError, .persistenceWrite(key: "test"))
        store.clearError()
        XCTAssertNil(store.lastError)
    }
}
