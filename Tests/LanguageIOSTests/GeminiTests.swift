import XCTest
@testable import LanguageIOS

final class GeminiTests: XCTestCase {

    // MARK: GeminiClient response parsing

    func testExtractTextPullsCandidateText() throws {
        let json = """
        {"candidates":[{"content":{"parts":[{"text":"{\\"word\\":\\"cup\\"}"}]}}]}
        """.data(using: .utf8)!
        let text = try GeminiClient.extractText(from: json)
        XCTAssertEqual(text, "{\"word\":\"cup\"}")
    }

    func testExtractTextThrowsOnEmptyCandidates() {
        let json = #"{"candidates":[]}"#.data(using: .utf8)!
        XCTAssertThrowsError(try GeminiClient.extractText(from: json))
    }

    func testGenerateThrowsWithoutKey() async {
        let client = GeminiClient(apiKey: "")
        do {
            _ = try await client.generate(prompt: "hi")
            XCTFail("expected missingKey")
        } catch {
            XCTAssertEqual(error as? GeminiClient.GeminiError, .missingKey)
        }
    }

    // MARK: Object recognizer parsing

    func testObjectRecognizerParsesPlainJSON() {
        let result = GeminiObjectRecognizer.parse(#"{"word":"Tasse","english":"cup","native":"fincan"}"#)
        XCTAssertEqual(result, ObjectRecognition(word: "Tasse", native: "fincan", english: "cup"))
    }

    func testObjectRecognizerStripsMarkdownFences() {
        let fenced = "```json\n{\"word\":\"book\",\"english\":\"book\",\"native\":\"kitap\"}\n```"
        XCTAssertEqual(GeminiObjectRecognizer.parse(fenced)?.word, "book")
    }

    func testObjectRecognizerReturnsNilForEmptyWord() {
        XCTAssertNil(GeminiObjectRecognizer.parse(#"{"word":""}"#))
        XCTAssertNil(GeminiObjectRecognizer.parse("not json"))
    }

    func testObjectRecognizerFallsBackToNativeAndEnglishWhenMissing() {
        let result = GeminiObjectRecognizer.parse(#"{"word":"chien"}"#)
        XCTAssertEqual(result?.native, "chien")
        XCTAssertEqual(result?.english, "chien")
    }

    // MARK: On-device recognizer + Gemini fallback path

    func testOnDeviceRecognizerUsesVocabulary() async {
        let stub = StubImageClassifier(result: [ObjectLabel(identifier: "dog", confidence: 0.9)])
        let recognizer = OnDeviceObjectRecognizer(classifier: stub)
        let result = await recognizer.recognize(Data(), target: .englishUS, native: .turkish)
        XCTAssertEqual(result?.word, "dog")
        XCTAssertEqual(result?.native, "köpek")
    }

    func testGeminiRecognizerFallsBackWhenKeyMissing() async {
        let stub = StubImageClassifier(result: [ObjectLabel(identifier: "cat", confidence: 0.9)])
        let recognizer = GeminiObjectRecognizer(apiKey: "", fallback: OnDeviceObjectRecognizer(classifier: stub))
        let result = await recognizer.recognize(Data(), target: .englishUS, native: .turkish)
        XCTAssertEqual(result?.word, "cat") // Gemini threw missingKey -> on-device fallback
    }

    // MARK: Sentence analyzer parsing + fallback

    func testSentenceAnalyzerParsesJSON() {
        let analysis = GeminiSentenceAnalyzer.parse(
            #"{"corrected":"I am happy.","isCorrect":false,"notes":["Özne eklendi."]}"#,
            original: "i am happy"
        )
        XCTAssertEqual(analysis?.corrected, "I am happy.")
        XCTAssertEqual(analysis?.isCorrect, false)
        XCTAssertEqual(analysis?.notes, ["Özne eklendi."])
    }

    func testSentenceAnalyzerFallsBackWhenKeyMissing() async {
        let analyzer = GeminiSentenceAnalyzer(apiKey: "")
        let result = await analyzer.analyze("hello world", language: .englishUS)
        XCTAssertEqual(result.corrected, "Hello world.") // heuristic fallback ran
    }

    // MARK: Secrets + language helpers

    func testSecretsAreEmptyWithoutConfiguration() {
        // No Secrets.plist in the test bundle and no env override expected in CI.
        XCTAssertTrue(Secrets.value(for: "DEFINITELY_UNSET_KEY_XYZ").isEmpty)
    }

    func testTargetLanguageEnglishNames() {
        XCTAssertEqual(TargetLanguage.german.englishName, "German")
        XCTAssertEqual(TargetLanguage.englishUK.englishName, "English")
        XCTAssertEqual(TargetLanguage.french.englishName, "French")
    }
}
