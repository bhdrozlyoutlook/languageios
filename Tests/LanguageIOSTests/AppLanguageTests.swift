import XCTest
@testable import LanguageIOS

final class AppLanguageTests: XCTestCase {

    func testLocaleCodeMapsEachTargetLanguage() {
        XCTAssertEqual(TargetLanguage.turkish.localeCode, "tr")
        XCTAssertEqual(TargetLanguage.englishUS.localeCode, "en")
        XCTAssertEqual(TargetLanguage.englishUK.localeCode, "en")
        XCTAssertEqual(TargetLanguage.german.localeCode, "de")
        XCTAssertEqual(TargetLanguage.spanish.localeCode, "es")
        XCTAssertEqual(TargetLanguage.french.localeCode, "fr")
    }

    func testApplyWithNilIsNoOp() {
        // Should not crash / change state when there's no chosen native language.
        AppLanguage.apply(nil)
    }
}
