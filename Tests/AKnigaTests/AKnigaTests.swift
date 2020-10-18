@testable import AKniga
import XCTest

final class AKnigaTests: XCTestCase {
    func testParse() throws {
        guard let htmlURL: URL = Bundle.module.url(forResource: "Resources/test-book", withExtension: "html") else { XCTFail(); return }
        guard let jsonURL: URL = Bundle.module.url(forResource: "Resources/test-book", withExtension: "json") else { XCTFail(); return }
        let htmlData = try Data(contentsOf: htmlURL)
        let jsonDdata = try Data(contentsOf: jsonURL)
        guard let string = String(data: htmlData, encoding: .utf8) else { XCTFail(); return }
        let bookDataResponse = try JSONDecoder().decode(BookDataResponse.self, from: jsonDdata)
        guard let id = bookDataResponse.keys.first else { XCTFail(); return }
        guard let bookData = bookDataResponse[id] else { XCTFail(); return }
        let parsed = try AKnigaAudioBook(id: id, html: string, bookData: bookData)
        XCTAssertEqual(parsed.author, "Кук Глен")
        XCTAssertEqual(parsed.name, "Суровые времена")
        XCTAssertEqual(parsed.description, "Описание Ничто не может противостоять мощи Повелителей Теней. Почти весь мир уже покорен ими, и лишь Таглиос, столетия не знавший войны, еще не захвачен. Та, что некогда, в другие времена и в другой стране, носила имя Буреносец, а теперь именует себя Грозотень, властительница ветров и громов, вместе с Черным Отрядом противостоит наступающему мраку... Но Отряд расколот. И никто не сможет предсказать, по силам ли окажется его бойцам, его ветеранам и его новобранцам, то испытание, что определено им судьбой…")
        XCTAssertEqual(parsed.coverRequest()?.url?.absoluteString, "https://akniga.org/uploads/media/topic/2020/08/05/10/preview/9062362c3c6eb74c1938_400x.jpg")

        XCTAssertEqual(parsed.chapters.count, 12)

        if let chapter = parsed.chapters.first {
            XCTAssertEqual(parsed.request(chapter: chapter)?.url?.absoluteString, "https://m17.akniga.club/b/57357/TJ3-dpYYUfFen7fZ8uK41g,,/01.%20%D0%9A%D1%83%D0%BA%20%D0%93%D0%BB%D0%B5%D0%BD%20-%20%D0%A1%D1%83%D1%80%D0%BE%D0%B2%D1%8B%D0%B5%20%D0%B2%D1%80%D0%B5%D0%BC%D0%B5%D0%BD%D0%B0.mp3")
        }
    }

    func testLoad() {
        let expectation = XCTestExpectation(description: "loader")
        let loader = AKnigaLoader()
        _ = loader.load(url: URL(string: "https://akniga.org/kuk-glen-surovye-vremena")!)
            .breakpoint()
            .sink(receiveCompletion: { result in
                switch result {
                case let .failure(error):
                    print(error)
                    XCTFail()
                case .finished:
                    break
                }
                expectation.fulfill()
            }, receiveValue: { _ in
            })
        wait(for: [expectation], timeout: 120.0)
    }

    static var allTests = [
        ("testLoad", testLoad),
    ]
}
