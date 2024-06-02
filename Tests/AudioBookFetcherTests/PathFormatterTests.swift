@testable import AudioBookFetcher
import XCTest

private struct TestAudioBook: AudioBook {
    var title: String
    var authors: [String]
    var description: String
    var chapters: [any AudioBookFetcher.BookChapter]
    var coverURL: URL
    var content: AudioBookFetcher.AudioBookContent
    var bookUrl: URL
}

final class PathFormatterTests: XCTestCase {
    func testBasePath() {
        let book = TestAudioBook(title: "title", authors: ["author1", "author2"], description: "description", chapters: [], coverURL: URL(fileURLWithPath: ""), content: .m3u8(URL(fileURLWithPath: "")), bookUrl: URL(fileURLWithPath: ""))
        let formatter = PathFormatter(base: "/hello/a-@author/@author/t-@title/@title", book: book)
        XCTAssertEqual(formatter.path.path, "/hello/a-author1/author1/t-title/title")
    }
}
