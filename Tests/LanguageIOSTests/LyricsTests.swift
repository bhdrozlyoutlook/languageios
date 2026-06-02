import XCTest
@testable import LanguageIOS

final class LyricsTests: XCTestCase {

    func testStubProviderReturnsPhrasesForEachLanguage() async {
        let provider = StubLyricsProvider()
        for language in TargetLanguage.allCases {
            let analysis = await provider.phrases(title: "Test", artist: "X", language: language)
            XCTAssertNotNil(analysis, "\(language) should have starter phrases")
            XCTAssertFalse(analysis?.phrases.isEmpty ?? true)
        }
    }

    func testStubProviderDefaultsBlankTitle() async {
        let analysis = await StubLyricsProvider().phrases(title: "", artist: "", language: .englishUS)
        XCTAssertEqual(analysis?.title, "Şarkı") // falls back to a Turkish default (test bundle)
    }

    func testGeminiLyricsParsesJSON() {
        let phrases = GeminiLyricsProvider.parse(#"{"phrases":[{"phrase":"hold me","native":"bana sarıl","note":"sevgi"},{"phrase":"let it go","native":"bırak gitsin"}]}"#)
        XCTAssertEqual(phrases?.count, 2)
        XCTAssertEqual(phrases?.first?.phrase, "hold me")
        XCTAssertEqual(phrases?.first?.native, "bana sarıl")
        XCTAssertEqual(phrases?.first?.note, "sevgi")
        XCTAssertNil(phrases?.last?.note)
    }

    func testGeminiLyricsParseRejectsEmptyOrInvalid() {
        XCTAssertNil(GeminiLyricsProvider.parse("not json"))
        XCTAssertNil(GeminiLyricsProvider.parse(#"{"phrases":[]}"#))
        XCTAssertNil(GeminiLyricsProvider.parse(#"{"phrases":[{"phrase":""}]}"#))
    }

    func testGeminiLyricsFallsBackWhenKeyMissing() async {
        let provider = GeminiLyricsProvider(apiKey: "") // generate() throws missingKey -> stub fallback
        let analysis = await provider.phrases(title: "Song", artist: "Y", language: .french)
        XCTAssertNotNil(analysis)
        XCTAssertFalse(analysis?.phrases.isEmpty ?? true)
    }
}
