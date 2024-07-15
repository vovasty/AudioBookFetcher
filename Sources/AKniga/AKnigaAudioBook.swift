//
//  AKnigaAudioBook.swift
//
//
//  Created by Vladimir Solomenchuk on 8/5/20.
//

import AudioBookFetcher
import Foundation
import SwiftSoup

typealias BookDataResponse = [String: BookData]

struct BookData: Decodable {
    public struct Item: Decodable {
        let title: String?
        var time_finish: Int
        var time_from_start: Int
    }

    let items: [Item]
    let preview: URL
    let titleonly: String
}

extension BookData.Item: BookChapter {
    var start: Int {
        time_from_start
    }

    var end: Int {
        time_finish
    }
}

struct AKnigaAudioBook: AudioBook {
    enum AKnigaAudioBookError: Swift.Error {
        case noResponse, noBookData
    }

    private let m3u8URL: URL
    let coverURL: URL
    let title: String
    let authors: [String]
    let description: String
    let chapters: [BookChapter]
    let content: AudioBookContent
    let bookUrl: URL
    let genre: [String]
    let series: BookSeries?

    init(bookUrl: URL, html: String, bookDataResponse: String, m3u8URL: URL) throws {
        guard let bookDataResponseData = bookDataResponse.data(using: .utf8) else {
            throw AKnigaAudioBookError.noResponse
        }
        let bookDataResponse = try JSONDecoder().decode(BookDataResponse.self, from: bookDataResponseData)
        guard let bookData = bookDataResponse.values.first else {
            throw AKnigaAudioBookError.noBookData
        }

        let document = try SwiftSoup.parse(html)

        if let sCoverURL = try document
            .select("img.loaded")
            .compactMap({ $0.getAttributes() })
            .map({ $0.get(key: "src") })
            .first, let url = URL(string: sCoverURL)
        {
            coverURL = url
        } else {
            coverURL = bookData.preview
        }
        title = bookData.titleonly.trimmingCharacters(in: .whitespacesAndNewlines)
        self.m3u8URL = m3u8URL
        authors = try document.select("[itemprop=\"author\"]").map { try $0.text() }
        description = try document.select("[itemprop=\"description\"]").map { try $0.text() }.joined(separator: "\n")
        chapters = bookData.items.map { chapter in
            var chapter = chapter
            chapter.time_finish *= 1000000000
            chapter.time_from_start *= 1000000000
            return chapter
        }
        content = .m3u8(m3u8URL)
        genre = try document.select("a.section__title").map { try $0.text() }
        if let seriesRaw = try document.select("a.link__series").map({ try $0.text() }).first, let result = seriesRaw.firstMatch(of: /(?<name>\w+) \((?<number>\d+)\)/) {
            series = BookSeries(
                name: String(result.name),
                number: Int(result.number) ?? 0
            )
        } else {
            series = nil
        }
        self.bookUrl = bookUrl
    }
}
