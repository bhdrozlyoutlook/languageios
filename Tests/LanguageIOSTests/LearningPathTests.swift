import XCTest
@testable import LanguageIOS

final class LearningPathTests: XCTestCase {

    // MARK: Catalog

    func testEveryLanguageHasANonEmptyJourneyWithUniqueStops() {
        for language in TargetLanguage.allCases {
            let journey = LearningJourney.journey(for: language)
            XCTAssertEqual(journey.language, language)
            XCTAssertFalse(journey.stops.isEmpty, "\(language) should have stops")
            XCTAssertFalse(journey.title.isEmpty)

            let ids = journey.stops.map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "\(language) stop ids must be unique")
        }
    }

    func testAmericanEnglishCoversAllFiftyStates() {
        let usa = LearningJourney.journey(for: .englishUS)
        XCTAssertEqual(usa.stops.count, 50)
        XCTAssertEqual(usa.stops.first?.title, "California")
        XCTAssertEqual(usa.stops.last?.title, "Maine")
        XCTAssertEqual(Set(usa.stops.map(\.title)).count, 50, "state names must be unique")
    }

    func testStopArtworkFollowsNamingConvention() {
        let usa = LearningJourney.journey(for: .englishUS)
        let first = usa.stops[0]

        XCTAssertEqual(first.id, "englishUS_california")
        XCTAssertEqual(first.title, "California")
        XCTAssertEqual(first.artwork.baseImageName, "englishUS_california_base")
        XCTAssertEqual(first.artwork.layerImageNames.first, "englishUS_california_l1")
        XCTAssertEqual(
            first.artwork.layerImageNames,
            (1...first.artwork.layerCount).map { "englishUS_california_l\($0)" }
        )
    }

    func testEveryStopHasBetweenTwoAndFourLayers() {
        for language in TargetLanguage.allCases {
            for stop in LearningJourney.journey(for: language).stops {
                XCTAssertTrue(
                    (2...4).contains(stop.artwork.layerCount),
                    "\(stop.id) has \(stop.artwork.layerCount) layers"
                )
            }
        }
    }

    // MARK: Progress

    func testProgressStatusReflectsCompletion() {
        let progress = LearningProgress(completedCount: 2)
        XCTAssertEqual(progress.status(forIndex: 0), .completed)
        XCTAssertEqual(progress.status(forIndex: 1), .completed)
        XCTAssertEqual(progress.status(forIndex: 2), .active)
        XCTAssertEqual(progress.status(forIndex: 3), .locked)
    }

    func testCompletingCurrentStopAdvancesAndClampsToTotal() {
        var progress = LearningProgress()
        XCTAssertEqual(progress.status(forIndex: 0), .active)

        progress.completeCurrentStop(total: 3)
        XCTAssertEqual(progress.completedCount, 1)
        XCTAssertEqual(progress.status(forIndex: 0), .completed)
        XCTAssertEqual(progress.status(forIndex: 1), .active)

        progress.completeCurrentStop(total: 3)
        progress.completeCurrentStop(total: 3)
        XCTAssertEqual(progress.completedCount, 3)
        XCTAssertTrue(progress.isFinished(total: 3))

        // Cannot exceed the total.
        progress.completeCurrentStop(total: 3)
        XCTAssertEqual(progress.completedCount, 3)
    }

    func testProgressIsNotFinishedForEmptyJourney() {
        XCTAssertFalse(LearningProgress(completedCount: 0).isFinished(total: 0))
    }

    // MARK: AppStore persistence

    private func makeIsolatedDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "test.languageios.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testNewStoreStartsInOnboarding() {
        let store = AppStore(defaults: makeIsolatedDefaults())
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertNil(store.targetLanguage)
        XCTAssertEqual(store.progress(for: .german).completedCount, 0)
    }

    func testCompletingOnboardingStoresLanguageAndPersists() {
        let defaults = makeIsolatedDefaults()
        let store = AppStore(defaults: defaults)

        store.completeOnboarding(with: OnboardingProfile(targetLanguage: .german))
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertEqual(store.targetLanguage, .german)

        // A fresh store reading the same defaults restores the state.
        let restored = AppStore(defaults: defaults)
        XCTAssertTrue(restored.hasCompletedOnboarding)
        XCTAssertEqual(restored.targetLanguage, .german)
    }

    func testProgressIsPersistedPerLanguage() {
        let defaults = makeIsolatedDefaults()
        let store = AppStore(defaults: defaults)

        store.completeCurrentStop(for: .french, total: 5)
        store.completeCurrentStop(for: .french, total: 5)
        store.completeCurrentStop(for: .spanish, total: 5)

        XCTAssertEqual(store.progress(for: .french).completedCount, 2)
        XCTAssertEqual(store.progress(for: .spanish).completedCount, 1)
        XCTAssertEqual(store.progress(for: .german).completedCount, 0)

        let restored = AppStore(defaults: defaults)
        XCTAssertEqual(restored.progress(for: .french).completedCount, 2)
        XCTAssertEqual(restored.progress(for: .spanish).completedCount, 1)
    }

    func testResetProgressClearsOnlyThatLanguage() {
        let store = AppStore(defaults: makeIsolatedDefaults())
        store.completeCurrentStop(for: .french, total: 5)
        store.completeCurrentStop(for: .spanish, total: 5)

        store.resetProgress(for: .french)
        XCTAssertEqual(store.progress(for: .french).completedCount, 0)
        XCTAssertEqual(store.progress(for: .spanish).completedCount, 1)
    }

    func testResetAllReturnsToOnboarding() {
        let defaults = makeIsolatedDefaults()
        let store = AppStore(defaults: defaults)
        store.completeOnboarding(with: OnboardingProfile(targetLanguage: .german))
        store.completeCurrentStop(for: .german, total: 5)

        store.resetAll()
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertNil(store.targetLanguage)
        XCTAssertEqual(store.progress(for: .german).completedCount, 0)

        let restored = AppStore(defaults: defaults)
        XCTAssertFalse(restored.hasCompletedOnboarding)
    }
}
