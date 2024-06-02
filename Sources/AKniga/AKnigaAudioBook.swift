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
        let time_finish: Int
        let time_from_start: Int
    }

    let items: [Item]
    let preview: URL
    let title: String
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
        title = try document.select("[itemprop=\"name\"]").map { try $0.text() }.joined()
        self.m3u8URL = m3u8URL
        authors = try document.select("[itemprop=\"author\"]").map { try $0.text() }
        description = try document.select("[itemprop=\"description\"]").map { try $0.text() }.joined(separator: "\n")
        chapters = bookData.items
        content = .m3u8(m3u8URL)
        self.bookUrl = bookUrl
    }
}
