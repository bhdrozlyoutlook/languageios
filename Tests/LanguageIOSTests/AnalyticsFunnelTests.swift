import XCTest
@testable import LanguageIOS

final class AnalyticsFunnelTests: XCTestCase {

    func testCompletingOnboardingEmitsCompletedEventWithParams() {
        let spy = SpyAnalyticsService()
        let store = AppStore(environment: makeTestEnvironment(analytics: spy))

        let profile = OnboardingProfile(
            targetLanguage: .german,
            ageRange: .adult,
            learningPurposes: [.travel, .work],
            learningStyles: [.aiExplanations],
            dailyGoal: .fifteenMinutes
        )
        store.completeOnboarding(with: profile)

        let event = spy.events(named: "onboarding_completed").first
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.params["language"], "german")
        XCTAssertEqual(event?.params["age"], "adult")
        XCTAssertEqual(event?.params["daily_goal"], "15")
        XCTAssertEqual(event?.params["purpose_count"], "2")
        XCTAssertEqual(event?.params["style_count"], "1")
    }

    func testCompletingStopsEmitsStopAndJourneyFinishedEvents() {
        let spy = SpyAnalyticsService()
        let store = AppStore(environment: makeTestEnvironment(analytics: spy))

        store.completeCurrentStop(for: .french, total: 2)
        store.completeCurrentStop(for: .french, total: 2)

        let stops = spy.events(named: "learning_path_stop_completed")
        XCTAssertEqual(stops.count, 2)
        XCTAssertEqual(stops.first?.params["index"], "0")
        XCTAssertEqual(stops.last?.params["index"], "1")
        XCTAssertEqual(spy.events(named: "learning_path_journey_finished").count, 1)
    }

    func testResetsEmitTheirEvents() {
        let spy = SpyAnalyticsService()
        let store = AppStore(environment: makeTestEnvironment(analytics: spy))

        store.resetProgress(for: .spanish)
        store.resetAll()

        XCTAssertTrue(spy.names.contains("learning_path_progress_reset"))
        XCTAssertTrue(spy.names.contains("app_reset"))
    }

    func testOnboardingFunnelEventNamesAndStepIdentifiers() {
        XCTAssertEqual(OnboardingFunnel.stepViewed(.targetLanguage).name, "onboarding_step_viewed")
        XCTAssertEqual(OnboardingFunnel.stepViewed(.targetLanguage).params["step"], "target_language")
        XCTAssertEqual(OnboardingFunnel.authChosen(provider: "apple").params["provider"], "apple")
        XCTAssertEqual(OnboardingFunnel.flowReset().name, "onboarding_flow_reset")
    }
}
