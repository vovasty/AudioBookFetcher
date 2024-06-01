import Combine
import Foundation
import Logging

public protocol BookChapter {
    var title: String? { get }
    var start: Int { get }
    var end: Int { get }
}

public protocol AudioBook {
    var title: String { get }
    var authors: [String] { get }
    var description: String { get }
    var chapters: [BookChapter] { get }
    var coverURL: URL { get }
    var content: AudioBookContent { get }
}

public enum AudioBookContent {
    case m3u8(URL)
}

public protocol AudioBookLoader {
    func load(url: URL) async throws -> AudioBook
}

public struct Fetcher {
    let loader: AudioBookLoader
    let handler = ProcessHandler(executableURL: URL(fileURLWithPath: "/bin/sh"), launchPath: "/usr/bin/env")
    let fm = FileManager()
    let logger = Logger(label: "net.aramzamzam.abookfetcher")
    let session = URLSession(configuration: .default)

    public init(loader: AudioBookLoader) {
        self.loader = loader
    }

    public func load(url: URL, output: String) async throws {
        let tempDirectory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)
        try fm.createDirectory(at: tempDirectory, withIntermediateDirectories: false)

        logger.info("fetching descriptor")
        let book = try await loader.load(url: url)
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
        logger.info("writing descriptor")
        let metadata = tempDirectory.appending(path: "metadata.txt")
        try writeMetadata(book: book, output: metadata)

        logger.info("assembling")
        let output = PathFormatter(base: output, book: book).path
        try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await assemble(
            media: media,
            cover: cover,
            metadata: metadata,
            output: output
        )
        logger.info("completed")
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

        logger.debug("running \(cmd.joined(separator: " "))")
        try await handler.run(process: ProcessHandler.ProcessCommand(arguments: cmd))
    }

    private func writeMetadata(book: AudioBook, output: URL) throws {
        var buf = [
            ";FFMETADATA1",
        ]

        if let artist = book.authors.first {
            buf.append("artist=\(artist)")
        }

        buf.append("title=\(book.title)")

        for chapter in book.chapters {
            buf.append("[CHAPTER]")
            buf.append("TIMEBASE=1/1000")
            buf.append("START=\(chapter.start)")
            buf.append("END=\(chapter.end)")
            if let title = chapter.title {
                buf.append("title=\(title)")
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

    private func fetchCover(url: URL, output: URL) async throws {
        let (tmpDownloaded, _) = try await session.download(from: url)
        logger.debug("fetching \(url)")
        let cmd = [
            "ffmpeg",
            "-i",
            tmpDownloaded.absoluteString,
            output.absoluteString,
        ]
        logger.debug("running \(cmd.joined(separator: " "))")
        try await handler.run(process: ProcessHandler.ProcessCommand(arguments: cmd))
        try fm.removeItem(at: tmpDownloaded)
    }

    private func fetchContent(content: AudioBookContent, output: URL) async throws {
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
            logger.debug("running \(cmd.joined(separator: " "))")
            try await handler.run(process: ProcessHandler.ProcessCommand(arguments: cmd))
        }
    }
}
