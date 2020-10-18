//
//  PathFormatter.swift
//  
//
//  Created by Vladimir Solomenchuk on 10/18/20.
//

import Foundation

public struct PathFormatter<T: BookChapter> {
    public let baseURL: URL
    public let pattern: String
    public let book: AnyAudioBook<T>
    
    public init(baseURL: URL, pattern: String, book: AnyAudioBook<T>) {
        self.baseURL = baseURL
        self.book = book
        self.pattern = pattern
    }
    
    public var bookURL: URL {
        let dict = [
            "%a": book.author ?? "",
            "%n": book.name ?? ""
        ]
        
        let path = dict.reduce(pattern) {
            $0.replacingOccurrences(of: $1.key, with: $1.value)
        }
        
        return baseURL.appendingPathComponent(path, isDirectory: true)
    }
}
