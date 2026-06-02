import XCTest
@testable import LanguageIOS

final class ReviewQueueTests: XCTestCase {

    private func object(_ english: String) -> CapturedObject {
        CapturedObject(id: english, english: english, native: "x", language: .englishUS, capturedAt: Date(timeIntervalSince1970: 0))
    }

    func testMissedWordsComeFirstPreservingOrderWithinGroups() {
        let objects = [object("cup"), object("lamp"), object("book"), object("clock")]
        let queue = ReviewQueue.build(objects: objects, missed: ["book", "cup"])
        XCTAssertEqual(queue.map(\.english), ["cup", "book", "lamp", "clock"])
    }

    func testNoMissedKeepsStorageOrder() {
        let objects = [object("cup"), object("lamp")]
        XCTAssertEqual(ReviewQueue.build(objects: objects, missed: []).map(\.english), ["cup", "lamp"])
    }

    func testEmptyObjectsYieldsEmptyQueue() {
        XCTAssertTrue(ReviewQueue.build(objects: [], missed: ["cup"]).isEmpty)
    }
}
