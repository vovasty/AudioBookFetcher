//
//  PathFormatter.swift
//
//
//  Created by Vladimir Solomenchuk on 10/18/20.
//

import Foundation

struct PathFormatter {
    let base: String
    let book: AudioBook

    init(base: String, book: AudioBook) {
        self.base = base
        self.book = book
    }

    var path: URL {
        let dict = [
            "@author": book.authors.first ?? "Unknown author",
            "@title": book.title,
        ]

        let path = dict.reduce(base) {
            $0.replacingOccurrences(of: $1.key, with: $1.value)
        }

        return URL(fileURLWithPath: path)
    }
}
