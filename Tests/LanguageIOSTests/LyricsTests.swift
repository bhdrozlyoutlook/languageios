import XCTest
@testable import LanguageIOS

final class LyricsTests: XCTestCase {

    func testNowPlayingDisplayUsesPlaceholdersAndEmptyProgress() {
        let display = LyricsNowPlayingDisplay(title: "  ", artist: "", selectedIndex: 2, phraseCount: 0)

        XCTAssertEqual(display.title, "Şarkı seç")
        XCTAssertEqual(display.artist, "Sanatçı ekle")
        XCTAssertEqual(display.queueCountText, "0 kalıp")
        XCTAssertEqual(display.progressFraction, 0)
    }

    func testNowPlayingDisplayTrimsMetadataAndClampsProgress() {
        let first = LyricsNowPlayingDisplay(title: "  APT.  ", artist: "  ROSÉ  ", selectedIndex: 0, phraseCount: 4)
        let last = LyricsNowPlayingDisplay(title: "APT.", artist: "ROSÉ", selectedIndex: 99, phraseCount: 4)

        XCTAssertEqual(first.title, "APT.")
        XCTAssertEqual(first.artist, "ROSÉ")
        XCTAssertEqual(first.queueCountText, "4 kalıp")
        XCTAssertEqual(first.progressFraction, 0.25)
        XCTAssertEqual(last.progressFraction, 1)
    }

    func testKaraokeTimelineIsEmptyWithoutPhrases() {
        let timeline = LyricsKaraokeTimeline(phraseCount: 0, phraseDuration: 2)

        XCTAssertEqual(timeline.totalDuration, 0)
        XCTAssertNil(timeline.index(at: 4))
        XCTAssertEqual(timeline.progressFraction(at: 4), 0)
        XCTAssertTrue(timeline.isFinished(at: 0))
        XCTAssertEqual(timeline.elapsedForPhrase(at: 3), 0)
    }

    func testKaraokeTimelineMapsElapsedTimeToPhraseAndProgress() {
        let timeline = LyricsKaraokeTimeline(phraseCount: 4, phraseDuration: 2)

        XCTAssertEqual(timeline.totalDuration, 8)
        XCTAssertEqual(timeline.index(at: -1), 0)
        XCTAssertEqual(timeline.index(at: 0), 0)
        XCTAssertEqual(timeline.index(at: 1.9), 0)
        XCTAssertEqual(timeline.index(at: 2), 1)
        XCTAssertEqual(timeline.index(at: 7.9), 3)
        XCTAssertEqual(timeline.index(at: 99), 3)
        XCTAssertEqual(timeline.progressFraction(at: -5), 0)
        XCTAssertEqual(timeline.progressFraction(at: 4), 0.5)
        XCTAssertEqual(timeline.progressFraction(at: 99), 1)
        XCTAssertFalse(timeline.isFinished(at: 7.9))
        XCTAssertTrue(timeline.isFinished(at: 8))
    }

    func testKaraokeTimelineSeeksToPhraseBoundaries() {
        let timeline = LyricsKaraokeTimeline(phraseCount: 4, phraseDuration: 2)

        XCTAssertEqual(timeline.elapsedForPhrase(at: -3), 0)
        XCTAssertEqual(timeline.elapsedForPhrase(at: 0), 0)
        XCTAssertEqual(timeline.elapsedForPhrase(at: 2), 4)
        XCTAssertEqual(timeline.elapsedForPhrase(at: 99), 6)
    }

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
