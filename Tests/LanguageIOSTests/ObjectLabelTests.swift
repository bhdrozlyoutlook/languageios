import XCTest
@testable import LanguageIOS

final class ObjectLabelTests: XCTestCase {

    func testVocabularyDirectAndFallbackLookup() {
        XCTAssertEqual(ObjectVocabulary.translation(for: "cup"), "fincan")
        XCTAssertEqual(ObjectVocabulary.translation(for: "coffee_mug"), "kahve kupası")
        XCTAssertEqual(ObjectVocabulary.translation(for: "wooden table"), "masa") // last-word fallback
        XCTAssertNil(ObjectVocabulary.translation(for: "xyzzy"))
    }

    func testBestMatchPicksFirstTranslatableLabel() {
        let labels = [
            ObjectLabel(identifier: "unknownthing", confidence: 0.9),
            ObjectLabel(identifier: "dog", confidence: 0.8)
        ]
        let match = ObjectVocabulary.bestMatch(in: labels)
        XCTAssertEqual(match?.english, "dog")
        XCTAssertEqual(match?.turkish, "köpek")
    }

    func testBestMatchIsNilWhenNoneTranslatable() {
        XCTAssertNil(ObjectVocabulary.bestMatch(in: [ObjectLabel(identifier: "qwerty", confidence: 0.9)]))
    }

    func testStubClassifierReturnsConfiguredResult() async {
        let stub = StubImageClassifier(result: [ObjectLabel(identifier: "cat", confidence: 0.7)])
        let result = await stub.classify(Data())
        XCTAssertEqual(result.first?.identifier, "cat")
    }

    func testCaptureWordDeduplicatesAndPersists() {
        let store = InMemoryKeyValueStore()
        let app = AppStore(environment: makeTestEnvironment(store: store))
        app.captureWord("dog")
        app.captureWord("dog")
        app.captureWord("cat")
        XCTAssertEqual(app.capturedWordCount, 2)

        let restored = AppStore(environment: makeTestEnvironment(store: store))
        XCTAssertEqual(restored.capturedWordCount, 2)
    }
}
