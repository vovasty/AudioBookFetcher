import Combine
import Foundation
import Logging

public struct AudioBook: Sendable {
    public struct Chapter: Sendable {
        public var title: String?
        public var start: Int
        public var end: Int
        public init(title: String? = nil, start: Int, end: Int) {
            self.title = title
            self.start = start
            self.end = end
        }
    }

    public struct Series: Sendable & Hashable {
        public let name: String
        public let number: Int

        public init(name: String, number: Int) {
            self.name = name
            self.number = number
        }
    }

    public enum Content: Sendable {
        case m3u8(URL)
    }

    public var title: String
    public var authors: [String]
    public var description: String
    public var chapters: [Chapter]
    public var coverURL: URL
    public var content: Content
    public var bookUrl: URL
    public var genre: [String]
    public var series: Series?

    public init(title: String, authors: [String], description: String, chapters: [AudioBook.Chapter], coverURL: URL, content: AudioBook.Content, bookUrl: URL, genre: [String], series: AudioBook.Series?) {
        self.title = title
        self.authors = authors
        self.description = description
        self.chapters = chapters
        self.coverURL = coverURL
        self.content = content
        self.bookUrl = bookUrl
        self.genre = genre
        self.series = series
    }
}

public protocol AudioBookLoader {
    func load(url: URL) async throws -> AudioBook
}

public struct Fetcher {
    enum Failure: Error {
        case fileExists(String)
    }

    let loader: AudioBookLoader
    let handler = ProcessHandler(executableURL: URL(fileURLWithPath: "/bin/sh"), launchPath: "/usr/bin/env")
    let fm = FileManager()
    let logger = Logger(label: "net.aramzamzam.abookfetcher")
    let session = URLSession(configuration: .default)
    let tempDirectory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
    let metadataMax = 140

    public init(loader: AudioBookLoader) {
        self.loader = loader
    }

    public func load(url: URL, output: String) async throws {
        try fm.createDirectory(at: tempDirectory, withIntermediateDirectories: false)

        logger.info("fetching descriptor")
        let book = try await with(timeout: 10) {
            try await loader.load(url: url)
        }

        let output = PathFormatter(base: output, book: book).path

        guard !fm.fileExists(atPath: output.path(percentEncoded: false)) else {
            throw Failure.fileExists(output.path(percentEncoded: false))
        }

        logger.info("writing descriptor")
        let metadata = tempDirectory.appending(path: "metadata.txt")
        try writeMetadata(book: book, output: metadata)

        logger.info("fetching media")
        let media = tempDirectory.appending(path: "fetched.m4b")
        try await fetchContent(
            content: book.content,
            output: media
        )
        logger.info("fetching cover")
        let cover = tempDirectory.appending(path: "cover.png")
        try await fetchCover(
            url: book.coverURL,
            output: cover
        )

        logger.info("assembling")
        try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await assemble(
            media: media,
            cover: cover,
            metadata: metadata,
            output: output
        )
        logger.info("completed")
    }

    public func cleanup() {
        logger.debug("removing \(tempDirectory.path(percentEncoded: false))")
        try? fm.removeItem(at: tempDirectory)
    }

    private func assemble(media: URL, cover: URL, metadata: URL, output: URL) async throws {
        let cmd = [
            "ffmpeg",
            "-i",
            media.absoluteString,
            "-i",
            metadata.absoluteString,
            "-i",
            cover.absoluteString,
            "-map",
            "0",
            "-map_metadata",
            "1",
            "-map",
            "2:v",
            "-disposition:v:0",
            "attached_pic",
            "-c",
            "copy",
            "-movflags",
            "+faststart",
            output.path(percentEncoded: false),
        ]

        try await run(cmd)
    }

    private func writeMetadata(book: AudioBook, output: URL) throws {
        var buf = [
            ";FFMETADATA1",
        ]

        // https://wiki.multimedia.cx/index.php/FFmpeg_Metadata#QuickTime.2FMOV.2FMP4.2FM4A.2Fet_al.
        if let artist = book.authors.first {
            buf.append("artist=\(artist.max(metadataMax))")
        }

        buf.append("title=\(book.title.max(metadataMax))")
        buf.append("album=\(book.title.max(metadataMax))")
        buf.append("description=\(book.description.replacingOccurrences(of: "\n", with: "\\n").max(metadataMax))")
        buf.append("synopsis=\(book.description.replacingOccurrences(of: "\n", with: "\\n").max(metadataMax))")
        buf.append("comment=\(book.bookUrl.absoluteString.max(metadataMax))")
        buf.append("genre=\(book.genre.joined(separator: ";").max(metadataMax))")

        if let series = book.series {
            buf.append("grouping=\(series.name.max(metadataMax))")
            buf.append("track=\(series.number)")
        }

        for chapter in book.chapters {
            buf.append("[CHAPTER]")
            buf.append("START=\(chapter.start)")
            buf.append("END=\(chapter.end)")
            if let title = chapter.title {
                buf.append("title=\(title.max(metadataMax))")
            }
        }

        try buf
            .joined(separator: "\n")
            .write(
                to: output,
                atomically: false,
                encoding: .utf8
            )
    }

    private func run(_ cmd: [String]) async throws {
        logger.debug("running \(cmd.joined(separator: " "))")
        if logger.logLevel == .debug {
            try await handler.run(process: ProcessHandler.ProcessCommand(arguments: cmd))
        } else {
            try await handler.runSilent(process: ProcessHandler.ProcessCommand(arguments: cmd))
        }
    }

    private func fetchCover(url: URL, output: URL) async throws {
        let (tmpDownloaded, _) = try await session.download(from: url)
        logger.debug("fetching \(url)")
        let cmd = [
            "ffmpeg",
            "-i",
            tmpDownloaded.absoluteString,
            output.absoluteString,
        ]
        try await run(cmd)
        try fm.removeItem(at: tmpDownloaded)
    }

    private func fetchContent(content: AudioBook.Content, output: URL) async throws {
        switch content {
        case let .m3u8(url):
            let cmd = [
                "ffmpeg",
                "-i",
                url.absoluteString,
                "-user_agent",
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
                "-map",
                "0",
                "-c",
                "copy",
                output.absoluteString,
            ]
            try await run(cmd)
        }
    }
}

extension Fetcher.Failure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .fileExists(path):
            "File already exists: \(path)"
        }
    }
}
