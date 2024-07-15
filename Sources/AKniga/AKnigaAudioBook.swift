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

extension AudioBook {
    enum AKnigaAudioBookError: Swift.Error {
        case noResponse, noBookData
    }

    init(bookUrl: URL, html: String, bookDataResponse: String, m3u8URL: URL) throws {
        guard let bookDataResponseData = bookDataResponse.data(using: .utf8) else {
            throw AKnigaAudioBookError.noResponse
        }
        let bookDataResponse = try JSONDecoder().decode(BookDataResponse.self, from: bookDataResponseData)
        guard let bookData = bookDataResponse.values.first else {
            throw AKnigaAudioBookError.noBookData
        }

        let document = try SwiftSoup.parse(html)

        let coverURL = if let sCoverURL = try document
            .select("img.loaded")
            .compactMap({ $0.getAttributes() })
            .map({ $0.get(key: "src") })
            .first, let url = URL(string: sCoverURL)
        {
            url
        } else {
            bookData.preview
        }

        let title = bookData.titleonly.trimmingCharacters(in: .whitespacesAndNewlines)
        let authors = try document.select("[itemprop=\"author\"]").map { try $0.text() }
        let description = try document.select("[itemprop=\"description\"]").map { try $0.text() }.joined(separator: "\n")
        let chapters = bookData.items.map {
            Chapter(
                title: $0.title,
                start: $0.time_finish * 1_000_000_000,
                end: $0.time_from_start * 1_000_000_000
            )
        }
        let content = Content.m3u8(m3u8URL)
        let genre = try document.select("a.section__title").map { try $0.text() }
        let series: Series? = if let seriesRaw = try document.select("a.link__series").map({ try $0.text() }).first, let result = seriesRaw.firstMatch(of: /(?<name>\w+) \((?<number>\d+)\)/) {
            Series(
                name: String(result.name),
                number: Int(result.number) ?? 0
            )
        } else {
            nil
        }

        self.init(
            title: title,
            authors: authors,
            description: description,
            chapters: chapters,
            coverURL: coverURL,
            content: content,
            bookUrl: bookUrl,
            genre: genre,
            series: series
        )
    }
}
