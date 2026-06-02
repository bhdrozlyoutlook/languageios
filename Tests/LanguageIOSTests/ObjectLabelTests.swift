import XCTest
@testable import LanguageIOS

final class ObjectLabelTests: XCTestCase {

    func testVocabularyDirectAndFallbackLookup() {
        XCTAssertEqual(ObjectVocabulary.translation(for: "cup"), "fincan")
        XCTAssertEqual(ObjectVocabulary.translation(for: "coffee_mug"), "kahve kupası")
        XCTAssertEqual(ObjectVocabulary.translation(for: "wooden table"), "masa") // last-word fallback
        XCTAssertEqual(ObjectVocabulary.translation(for: "sunglasses"), "güneş gözlüğü")
        XCTAssertEqual(ObjectVocabulary.translation(for: "dark_glasses"), "güneş gözlüğü")
        XCTAssertEqual(ObjectVocabulary.translation(for: "eyeglasses"), "gözlük")
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

    func testBestMatchFindsSunglassesBeforeGenericFallbacks() {
        let labels = [
            ObjectLabel(identifier: "document", confidence: 0.76),
            ObjectLabel(identifier: "screenshot", confidence: 0.76),
            ObjectLabel(identifier: "optical_equipment", confidence: 0.22),
            ObjectLabel(identifier: "sunglasses", confidence: 0.22),
            ObjectLabel(identifier: "clothing", confidence: 0.07)
        ]

        let match = ObjectVocabulary.bestMatch(in: labels)

        XCTAssertEqual(match?.english, "sunglasses")
        XCTAssertEqual(match?.turkish, "güneş gözlüğü")
    }

    func testStubClassifierReturnsConfiguredResult() async {
        let stub = StubImageClassifier(result: [ObjectLabel(identifier: "cat", confidence: 0.7)])
        let result = await stub.classify(Data())
        XCTAssertEqual(result.first?.identifier, "cat")
    }

    func testCaptureAnalysisReturnsRecognitionBeforeSlowCutoutCompletes() async {
        let recognizer = DelayedObjectRecognizer(
            result: ObjectRecognition(word: "cup", native: "fincan", english: "cup"),
            delay: .milliseconds(20)
        )
        let extractor = DelayedSubjectExtractor(result: Data([0xC]), delay: .milliseconds(500))

        let started = Date()
        let analysis = await ObjectCaptureAnalyzer.recognizeFirst(
            rawData: Data([0x1]),
            recognizer: recognizer,
            extractor: extractor,
            language: .englishUS,
            native: .turkish
        )

        XCTAssertLessThan(Date().timeIntervalSince(started), 0.25)
        XCTAssertEqual(analysis?.recognition.word, "cup")
        let cutout = await analysis?.cutout.value
        XCTAssertEqual(cutout, Data([0xC]))
    }

    func testCutoutRefinesWrongFullFrameRecognition() async {
        let recognizer = DataDrivenObjectRecognizer(results: [
            Data([0x1]): ObjectRecognition(word: "computer", native: "bilgisayar", english: "computer"),
            Data([0xC]): ObjectRecognition(word: "sunglasses", native: "güneş gözlüğü", english: "sunglasses")
        ])

        let refined = await ObjectCaptureAnalyzer.refineRecognition(
            cutout: Data([0xC]),
            original: ObjectRecognition(word: "computer", native: "bilgisayar", english: "computer"),
            recognizer: recognizer,
            language: .englishUS,
            native: .turkish
        )

        XCTAssertEqual(refined?.word, "sunglasses")
        XCTAssertEqual(refined?.native, "güneş gözlüğü")
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

    func testCaptureObjectPersistsToCollectionAndCountsTheWord() {
        let store = InMemoryKeyValueStore()
        let env = makeTestEnvironment(store: store)
        let app = AppStore(environment: env)

        app.captureObject(english: "Cup", native: "fincan", image: Data([0xA]))

        XCTAssertEqual(app.capturedWordCount, 1)
        let collection = app.capturedObjects()
        XCTAssertEqual(collection.count, 1)
        XCTAssertEqual(collection.first?.english, "Cup")
        XCTAssertEqual(collection.first?.native, "fincan")
        XCTAssertEqual(app.captureImage(forID: collection.first!.id), Data([0xA]))
    }
}

private final class DelayedObjectRecognizer: ObjectRecognizing {
    private let result: ObjectRecognition?
    private let delay: Duration
    private(set) var callCount = 0

    init(result: ObjectRecognition?, delay: Duration) {
        self.result = result
        self.delay = delay
    }

    func recognize(_ imageData: Data, target: TargetLanguage, native: TargetLanguage) async -> ObjectRecognition? {
        callCount += 1
        try? await Task.sleep(for: delay)
        return result
    }
}

private final class DelayedSubjectExtractor: SubjectExtracting {
    private let result: Data?
    private let delay: Duration

    init(result: Data?, delay: Duration) {
        self.result = result
        self.delay = delay
    }

    func extractSubject(from imageData: Data) async -> Data? {
        try? await Task.sleep(for: delay)
        return result
    }
}

private final class DataDrivenObjectRecognizer: ObjectRecognizing {
    private let results: [Data: ObjectRecognition]

    init(results: [Data: ObjectRecognition]) {
        self.results = results
    }

    func recognize(_ imageData: Data, target: TargetLanguage, native: TargetLanguage) async -> ObjectRecognition? {
        results[imageData]
    }
}
