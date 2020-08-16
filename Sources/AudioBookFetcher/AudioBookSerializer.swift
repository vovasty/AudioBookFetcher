//
//  AudioBookSerializer.swift
//
//
//  Created by Vladimir Solomenchuk on 8/14/20.
//

import CryptoKit
import Foundation

extension URL {
    func getSHA256() -> String? {
        guard let data = absoluteString.data(using: .utf8) else {
            return nil
        }
        return SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
    }
}

public struct AudioBookSerializer {
    enum AudioBookSerializer: Error {
        case noHash
    }

    let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func save<T>(book: AnyAudioBook<T>, url: URL) throws {
        let data = try JSONEncoder().encode(book)
        let destination = try getPath(url: url)
        try data.write(to: destination)
    }

    public func load<T>(url: URL, type: AnyAudioBook<T>.Type) throws -> AnyAudioBook<T> {
        let destination = try getPath(url: url)
        let data = try Data(contentsOf: destination)
        return try JSONDecoder().decode(type, from: data)
    }

    private func getPath(url: URL) throws -> URL {
        guard let name = url.getSHA256() else { throw AudioBookSerializer.noHash }
        return URL(fileURLWithPath: name, isDirectory: false, relativeTo: baseURL)
    }
}
