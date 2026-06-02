import XCTest
@testable import LanguageIOS

final class CaptureRepositoryTests: XCTestCase {

    private func makeRepo() -> (DefaultCaptureRepository, InMemoryImageBlobStore) {
        let blobs = InMemoryImageBlobStore()
        return (DefaultCaptureRepository(store: InMemoryKeyValueStore(), blobs: blobs), blobs)
    }

    private func object(_ id: String, _ english: String = "Cup", at date: Date = Date(timeIntervalSince1970: 0)) -> CapturedObject {
        CapturedObject(id: id, english: english, native: "fincan", language: .englishUS, capturedAt: date)
    }

    func testAddStoresMetadataAndImageNewestFirst() {
        let (repo, _) = makeRepo()
        repo.add(object("a", "Cup"), image: Data([0x1]))
        repo.add(object("b", "Lamp"), image: Data([0x2]))

        let all = repo.all()
        XCTAssertEqual(all.map(\.id), ["b", "a"]) // newest first
        XCTAssertEqual(repo.image(forID: "a"), Data([0x1]))
        XCTAssertEqual(repo.image(forID: "b"), Data([0x2]))
    }

    func testAddWithSameIdReplaces() {
        let (repo, _) = makeRepo()
        repo.add(object("a", "Cup"), image: nil)
        repo.add(object("a", "Mug"), image: nil)
        XCTAssertEqual(repo.all().count, 1)
        XCTAssertEqual(repo.all().first?.english, "Mug")
    }

    func testRemoveDropsMetadataAndImage() {
        let (repo, _) = makeRepo()
        repo.add(object("a"), image: Data([0x1]))
        repo.remove(id: "a")
        XCTAssertTrue(repo.all().isEmpty)
        XCTAssertNil(repo.image(forID: "a"))
    }

    func testClearEmptiesEverything() {
        let (repo, _) = makeRepo()
        repo.add(object("a"), image: Data([0x1]))
        repo.add(object("b"), image: Data([0x2]))
        repo.clear()
        XCTAssertTrue(repo.all().isEmpty)
        XCTAssertNil(repo.image(forID: "a"))
    }

    func testPersistsAcrossInstancesViaSharedStore() {
        let store = InMemoryKeyValueStore()
        let blobs = InMemoryImageBlobStore()
        DefaultCaptureRepository(store: store, blobs: blobs).add(object("a", "Cup"), image: Data([0x9]))

        let reopened = DefaultCaptureRepository(store: store, blobs: blobs)
        XCTAssertEqual(reopened.all().first?.english, "Cup")
        XCTAssertEqual(reopened.image(forID: "a"), Data([0x9]))
    }

    func testDayKeyGroupsByCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let morning = calendar.date(from: DateComponents(year: 2024, month: 5, day: 7, hour: 9))!
        let evening = calendar.date(from: DateComponents(year: 2024, month: 5, day: 7, hour: 22))!
        XCTAssertEqual(object("a", at: morning).dayKey, object("b", at: evening).dayKey)
        XCTAssertEqual(object("a", at: morning).dayKey, "2024-05-07")
    }

    func testPassthroughSubjectExtractorReturnsInput() async {
        let data = Data([0x1, 0x2, 0x3])
        let result = await PassthroughSubjectExtractor().extractSubject(from: data)
        XCTAssertEqual(result, data)
    }

    func testImageNormalizerReturnsInputForNonImageData() {
        // Non-decodable bytes can't be oriented, so they pass through untouched.
        let junk = Data([0x00, 0x11, 0x22, 0x33])
        XCTAssertEqual(ImageNormalizer.upright(junk), junk)
    }
}
