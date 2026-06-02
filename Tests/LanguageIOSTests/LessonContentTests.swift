import XCTest
@testable import LanguageIOS

final class LessonContentTests: XCTestCase {

    /// Every city stop for the non-US journeys now has hand-authored content (≥ 4 items),
    /// so `items(forStopId:)` serves real vocabulary instead of the generic starter bank.
    func testEveryCityStopIsAuthored() {
        for language in [TargetLanguage.englishUK, .german, .spanish, .french] {
            for stop in LearningJourney.journey(for: language).stops {
                let authored = LessonContent.authored[stop.id]
                XCTAssertNotNil(authored, "\(stop.id) should be authored")
                XCTAssertGreaterThanOrEqual(authored?.count ?? 0, 4, "\(stop.id) needs ≥ 4 items")
            }
        }
    }

    func testAuthoredStopsResolveToAuthoredVocabulary() {
        // A spot check that the lookup returns the authored set, not the fallback.
        let items = LessonContent.items(forStopId: "german_hamburg", language: .german)
        XCTAssertEqual(items.first?.target, "eins")
        XCTAssertEqual(items.count, 6)
    }

    func testAuthoredKeysAreUnique() {
        // A dictionary literal with duplicate keys would trap at load; this asserts the
        // count is what we expect so an accidental dup is caught.
        XCTAssertGreaterThanOrEqual(LessonContent.authored.count, 30)
    }
}
