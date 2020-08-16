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

    @Argument(help: "an akniga.org book url.")
    var url: String

    @Argument(help: "output path.")
    var path: String

    mutating func run() throws {
        guard let url = URL(string: url) else { throw Error.invalidURL }

        let path = self.path

        let baseURL = URL(fileURLWithPath: path, isDirectory: true)
        let serializer = AudioBookSerializer(baseURL: baseURL)
        let fetcher = AudioBookFetcher()
        let publisher: AnyPublisher<AudioBookFetcher.FileType, Swift.Error>
        let loader: AKnigaLoader?
        do {
            let book = try serializer.load(url: url, type: AKnigaAudioBook.self)
            publisher = fetcher(book: book, to: path).eraseToAnyPublisher()
            logger.info("loaded metadata")
            loader = nil
        } catch {
            logger.info("fetching metadata")
            loader = AKnigaLoader()
            publisher = loader!.load(url: url).flatMap { book -> AnyPublisher<AudioBookFetcher.FileType, Swift.Error> in
                try? serializer.save(book: book, url: url)
                return fetcher(book: book, to: path)
            }.eraseToAnyPublisher()
        }

        let cancel = publisher
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
        CFRunLoopRun()
    }
}

Repeat.main()
