@testable import AKniga
import XCTest

final class AKnigaTests: XCTestCase {
    func testParse() throws {
        guard let htmlURL: URL = Bundle.module.url(forResource: "Resources/test-book", withExtension: "html") else { XCTFail(); return }
        guard let jsonURL: URL = Bundle.module.url(forResource: "Resources/test-book", withExtension: "json") else { XCTFail(); return }
        let htmlData = try Data(contentsOf: htmlURL)
        let jsonDdata = try Data(contentsOf: jsonURL)
        let html = try XCTUnwrap(String(data: htmlData, encoding: .utf8))
        let bookDataResponse = try XCTUnwrap(String(data: jsonDdata, encoding: .utf8))
        let parsed = try AKnigaAudioBook(html: html, bookDataResponse: bookDataResponse, m3u8URL: URL(fileURLWithPath: "file://test"))
        XCTAssertEqual(parsed.title, "Глубина. Погружение 56-е")
        XCTAssertFalse(parsed.authors.isEmpty)
        XCTAssertFalse(parsed.description.isEmpty)
        XCTAssertFalse(parsed.chapters.isEmpty)
        XCTAssertEqual(parsed.coverURL, URL(string: "https://akniga.org/uploads/media/topic/2024/05/31/08/preview/fe35b1daf43cc19fae7c_400x.jpg"))
    }

    func testLoad() {
        let e = expectation(description: "loader")
        let loader = AKnigaLoader()
        Task {
            do {
                _ = try await loader.load(url: URL(string: "https://akniga.org/shekli-robert-zachem")!)
            } catch {
                XCTFail()
            }
            e.fulfill()
        }
        wait(for: [e], timeout: 30.0)
    }

    static var allTests = [
        ("testLoad", testLoad),
    ]
}
