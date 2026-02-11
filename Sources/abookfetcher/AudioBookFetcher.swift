//
//  AudioBookFetcher.swift
//
//
//  Created by Vladimir Solomenchuk on 8/5/20.
//

import AKniga
import ArgumentParser
import AudioBookFetcher
import Foundation
import Logging

@main
struct ABookFetcher: AsyncParsableCommand {
    enum Error: Swift.Error {
        case invalidURL
    }

    @Argument(help: "An akniga.org book url.")
    var url: String

    @Argument(help: "An output path. You can use patterns @author and @title, e.g. path/@author/book-@title.m4b")
    var path: String

    @Flag(help: "verbse output")
    var verbose = false

    @Option(help: "network timeout")
    var timeout: TimeInterval = 120

    enum CodingKeys: String, CodingKey {
        case url, path, verbose, timeout
    }

    var sigintSrc: DispatchSourceSignal?

    mutating func run() async throws {
        guard let url = URL(string: url) else { throw Error.invalidURL }
        sigintSrc = setupSignalHandler()
        setupLogger(verbose ? .debug : .info)
        let fetcher = Fetcher(loader: AKnigaLoader())
        do {
            try await fetcher.load(url: url, output: path, timeout: timeout)
            fetcher.cleanup()
        } catch {
            fetcher.cleanup()
            throw error
        }
    }

    private func setupLogger(_ level: Logger.Level) {
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = level
            return handler
        }
    }

    private mutating func setupSignalHandler() -> DispatchSourceSignal {
        // https://stackoverflow.com/a/45714258
        signal(SIGINT, SIG_IGN)
        let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigintSrc.setEventHandler {
            Foundation.exit(1)
        }
        sigintSrc.resume()
        return sigintSrc
    }
}
