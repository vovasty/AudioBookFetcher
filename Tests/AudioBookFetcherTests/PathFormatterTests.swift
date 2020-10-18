@testable import AudioBookFetcher
import XCTest

private struct TestChapter: BookChapter {
    let id: Int?
    public var name: String?
    public var start: Int?
}

private final class TestAudioBook: AnyAudioBook<TestChapter> {
}


final class PathFormatterTests: XCTestCase {
    func testBasePath() {
        let book = TestAudioBook(name: "name", author: "author", description: "description", chapters: [])
        let formatter = PathFormatter(baseURL: URL(fileURLWithPath: "/"), pattern: "%a/author-%a/%n/%nname", book: book)
        XCTAssertEqual(formatter.baseURL.path, "/author/author-author/name/namename")
    }
}
