//
//  File.swift
//
//
//  Created by Vladimir Solomenchuk on 8/5/20.
//

import AudioBookFetcher
import Combine
import Foundation
import SwiftSoup
import WebKit

private enum ItemCaptions: String {
    case description, name, author
}

public typealias BookDataResponse = [String: BookData]

public struct BookData: Decodable {
    public struct Item: Decodable {
        public let file: Int
        public let title: String
        public let time: Int
    }

    public let items: [Item]
    public let srv: URL
    public let key: String
    public let title: String
}

private func parseItemCaption(element: Element) -> (name: ItemCaptions, value: String?)? {
    guard let itemprop = try? element.attr("itemprop") else { return nil }
    guard let name = ItemCaptions(rawValue: itemprop) else { return nil }
    let value = try? element.text()
    return (name, value)
}

private func parseItemCaptions(document: Document) throws -> [ItemCaptions: String] {
    let captionElements = try document.select("div [itemprop]")

    let dict = captionElements
        .compactMap { parseItemCaption(element: $0) }
        .reduce([ItemCaptions: String]()) {
            var res = $0
            res[$1.name] = $1.value
            return res
        }
    return dict
}

private func parseCoverImageURL(document: Document) -> URL? {
    guard let metas = try? document.select("meta") else { return nil }
    let coverMeta = try? metas.first { try $0.attr("property") == "og:image" }
    guard let content = try? coverMeta?.attr("content") else { return nil }
    return URL(string: content)
}

public struct AKnigaChapter: BookChapter {
    let id: Int?
    public var name: String?
    public var start: Int?
}

public final class AKnigaAudioBook: AnyAudioBook<AKnigaChapter> {
    enum Error: Swift.Error {
        case noServer, noKey, noTitle
    }

    private let coverURL: URL?
    private let id: String
    private let server: URL
    private let key: String
    private let title: String

    enum CodingKeys: String, CodingKey {
        case id, server, key, coverURL, title
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        coverURL = try container.decode(URL.self, forKey: .coverURL)
        id = try container.decode(String.self, forKey: .id)
        server = try container.decode(URL.self, forKey: .server)
        key = try container.decode(String.self, forKey: .key)
        title = try container.decode(String.self, forKey: .title)
        try super.init(from: decoder)
    }

    override public func encode(to encoder: Encoder) throws {
        try super.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(coverURL, forKey: .coverURL)
        try container.encode(id, forKey: .id)
        try container.encode(server, forKey: .server)
        try container.encode(key, forKey: .key)
        try container.encode(title, forKey: .title)
    }

    public init(id: String, html: String, bookData: BookData) throws {
        let document = try SwiftSoup.parse(html)
        self.id = id
        var start = 0
        var ids = Set<Int>()

        let chapters = bookData.items.map { (item: BookData.Item) -> AKnigaChapter in
            let chapter = AKnigaChapter(id: ids.contains(item.file) ? nil : item.file,
                                        name: item.title,
                                        start: start)
            start = item.time
            ids.insert(item.file)
            return chapter
        }
        coverURL = parseCoverImageURL(document: document)
        server = bookData.srv
        key = bookData.key
        title = bookData.title

        let dict = try parseItemCaptions(document: document)
        super.init(name: dict[.name], author: dict[.author], description: dict[.description], chapters: chapters)
    }

    override public func coverRequest() -> URLRequest? {
        guard let coverURL = coverURL else { return nil }
        return URLRequest(url: coverURL)
    }

    override public func request(chapter: AKnigaChapter) -> URLRequest? {
        guard let id = chapter.id else { return nil }
        let n = id < 10 ? "0\(id)" : String(id)
        let constructed = "/b/\(self.id)/\(key)/\(n). \(title).mp3"
        guard let encoded = constructed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        guard let url = URL(string: encoded, relativeTo: server) else { return nil }
        return URLRequest(url: url)
    }
}
