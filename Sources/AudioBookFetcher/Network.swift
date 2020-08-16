//
//  Network.swift
//
//
//  Created by Vladimir Solomenchuk on 8/6/20.
//

import Combine
import Foundation

struct DownloadAgent {
    enum Error: Swift.Error {
        case invalidStatusCode(Int)
        case fileExists(URL)
    }

    func run(_ request: URLRequest, destination: URL) -> AnyPublisher<URLResponse, Swift.Error> {
        guard !((try? destination.checkResourceIsReachable()) ?? false) else {
            return Fail<URLResponse, Swift.Error>(error: Error.fileExists(destination))
                .eraseToAnyPublisher()
        }

        return URLSession.shared
            .downloadTaskPublisher(for: request)
            .tryMap {
                guard let http = $0.response as? HTTPURLResponse else { throw Error.invalidStatusCode(-1) }
                guard (200 ... 299).contains(http.statusCode) else { throw Error.invalidStatusCode(http.statusCode) }

                let fm = FileManager.default
                try fm.moveItem(at: $0.url, to: destination)

                return $0.response
            }
            .receive(on: DispatchQueue.global(qos: .background))
            .eraseToAnyPublisher()
    }
}

enum Downloader {
    static let agent = DownloadAgent()
}

extension Downloader {
    static func downloadCover(request: URLRequest, destination: URL) -> AnyPublisher<URLResponse, Error> {
        return agent.run(request, destination: destination)
            .eraseToAnyPublisher()
    }

    static func downloadAudio(request: URLRequest, destination: URL) -> AnyPublisher<URLResponse, Error> {
        return agent.run(request, destination: destination)
            .eraseToAnyPublisher()
    }
}

extension DownloadAgent.Error: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .fileExists(url):
            return "File already exists \(url.path)"
        case let .invalidStatusCode(code):
            return "Wrong server response \(code)"
        }
    }
}
