@testable import AudioBookFetcher
import XCTest

final class PathFormatterTests: XCTestCase {
    func testBasePath() {
        let book = AudioBook(title: "title", authors: ["author1", "author2"], description: "description", chapters: [], coverURL: URL(fileURLWithPath: ""), content: .m3u8(URL(fileURLWithPath: "")), bookUrl: URL(fileURLWithPath: ""), genre: [], series: nil, performers: [])
        let formatter = PathFormatter(base: "/hello/a-@author/@author/t-@title/@title", book: book)
        XCTAssertEqual(formatter.path.path, "/hello/a-author1/author1/t-title/title")
    }
}
