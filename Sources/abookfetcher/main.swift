//
//  main.swift
//
//
//  Created by Vladimir Solomenchuk on 8/5/20.
//

import AKniga
import ArgumentParser
import AudioBookFetcher
import Combine
import Foundation

private func stopRunLoop() {
    DispatchQueue.main.async {
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
}

struct Repeat: ParsableCommand {
    enum Error: Swift.Error {
        case invalidURL
    }

    @Argument(help: "An akniga.org book url.")
    var url: String

    @Argument(help: "An output path.")
    var path: String

    @Option(help: "A path pattern. \n%a - a book author\n%n - a book name.")
    var pattern: String = "%a/%n/%n"

    enum CodingKeys: String, CodingKey {
        case path, url, pattern
    }

    private var store = Set<AnyCancellable>()
    private var loader: AKnigaLoader?
    
    mutating func run() throws {
        guard let url = URL(string: url) else { throw Error.invalidURL }

        let path = self.path
        let pattern = self.pattern

        let baseURL = URL(fileURLWithPath: path, isDirectory: true)
        let serializer = AudioBookSerializer(baseURL: baseURL)
        let fetcher = AudioBookFetcher()
        let publisher: AnyPublisher<AudioBookFetcher.FileType, Swift.Error>
        do {
            let book = try serializer.load(url: url, type: AKnigaAudioBook.self)
            let pathFormatter = PathFormatter(baseURL: URL(fileURLWithPath: path), pattern: pattern, book: book)
            publisher = fetcher(book: book, to: pathFormatter.bookURL)
            logger.info("loaded metadata")
            loader = nil
        } catch {
            logger.info("fetching metadata")
            loader = AKnigaLoader()
            publisher = loader!.load(url: url).flatMap { book -> AnyPublisher<AudioBookFetcher.FileType, Swift.Error> in
                try? serializer.save(book: book, url: url)
                let pathFormatter = PathFormatter(baseURL: URL(fileURLWithPath: path), pattern: pattern, book: book)
                return fetcher(book: book, to: pathFormatter.bookURL)
            }.eraseToAnyPublisher()
        }

        publisher
            .sink { completion in
                switch completion {
                case let .failure(error):
                    logger.error(error)
                case .finished:
                    logger.info("finished")
                }
                stopRunLoop()
            } receiveValue: { info in
                switch info {
                case let .chapter(name):
                    logger.info("received chapter \(name)")
                case .cover:
                    logger.info("received cover")
                case let .skippedChapter(name, error):
                    logger.info("skipped chapter \(name): \(error.localizedDescription)")
                case let .skippedCover(error):
                    logger.info("skipped cover: \(error.localizedDescription)")
                }
            }
            .store(in: &store)
        CFRunLoopRun()
    }
}

Repeat.main()
