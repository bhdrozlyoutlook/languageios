import XCTest
@testable import LanguageIOS

final class SentenceAnalysisTests: XCTestCase {

    func testCapitalizesAndAddsPunctuation() async {
        let analyzer = HeuristicSentenceAnalyzer()
        let result = await analyzer.analyze("hello world", language: .englishUS)
        XCTAssertEqual(result.corrected, "Hello world.")
        XCTAssertFalse(result.isCorrect)
        XCTAssertFalse(result.notes.isEmpty)
    }

    func testAlreadyCorrectSentenceIsUnchanged() async {
        let analyzer = HeuristicSentenceAnalyzer()
        let result = await analyzer.analyze("Hello world.", language: .englishUS)
        XCTAssertEqual(result.corrected, "Hello world.")
        XCTAssertTrue(result.isCorrect)
    }

    func testEmptyInputIsHandled() async {
        let analyzer = HeuristicSentenceAnalyzer()
        let result = await analyzer.analyze("   ", language: .englishUS)
        XCTAssertTrue(result.isCorrect)
        XCTAssertTrue(result.notes.isEmpty)
    }
}
