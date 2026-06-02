import XCTest
@testable import LanguageIOS

final class SpeechTests: XCTestCase {

    func testElevenLabsSynthesizeReturnsNilWithoutKey() async {
        let service = ElevenLabsSpeechService(apiKey: "", voiceID: "voice")
        let audio = await service.synthesize("merhaba")
        XCTAssertNil(audio) // no key -> caller falls back to on-device
    }

    func testElevenLabsVoiceIDHasADefault() {
        XCTAssertFalse(Secrets.elevenLabsVoiceID.isEmpty)
    }
}
