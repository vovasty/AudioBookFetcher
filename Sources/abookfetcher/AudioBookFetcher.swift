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

@main
struct ABookFetcher: AsyncParsableCommand {
    enum Error: Swift.Error {
        case invalidURL
    }

    @Argument(help: "An akniga.org book url.")
    var url: String

    @Argument(help: "An output path. You can use patterns @author and @title")
    var path: String

    mutating func run() async throws {
        guard let url = URL(string: url) else { throw Error.invalidURL }
        // https://stackoverflow.com/a/45714258
        signal(SIGINT, SIG_IGN)
        let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        sigintSrc.setEventHandler {
            Foundation.exit(1)
        }
        sigintSrc.resume()

        let loader = AKnigaLoader()
        let fetcher = Fetcher(loader: loader)
        try await fetcher.load(url: url, output: path)
    }
}
