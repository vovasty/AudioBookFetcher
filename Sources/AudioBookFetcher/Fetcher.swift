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
    var performers: [String] { get }
}

public enum AudioBookContent {
    case m3u8(URL)
}

public protocol AudioBookLoader {
    func load(url: URL) async throws -> AudioBook
}

public struct Fetcher {
    enum Failure: Error {
        case fileExists(String), timeout
    }

    let loader: AudioBookLoader
    let handler = ProcessHandler(executableURL: URL(fileURLWithPath: "/bin/sh"), launchPath: "/usr/bin/env")
    let fm = FileManager()
    let logger = Logger(label: "net.aramzamzam.abookfetcher")
    let session = URLSession(configuration: .default)
    let tempDirectory = URL(filePath: NSTemporaryDirectory()).appending(path: UUID().uuidString)

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

        if let artist = book.authors.first {
            buf.append("artist=\(artist)")
        }

        buf.append("title=\(book.title)")
        buf.append("album=\(book.title)")

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
            try await run(cmd)
        }
    }

    private func with<T>(timeout: Double, closure: @escaping () async throws -> T) async throws -> T {
        let subject = PassthroughSubject<T, Error>()

        let task = Task {
            let value = try await closure()
            subject.send(value)
        }

        do {
            let value = try await subject
                .timeout(.seconds(timeout), scheduler: DispatchQueue.main)
                .values
                .first { _ in true }

            guard let value else {
                throw Failure.timeout
            }

            return value
        } catch {
            task.cancel()
            throw error
        }
    }
}

extension Fetcher.Failure: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .fileExists(path):
            "File already exists: \(path)"
        case .timeout:
            "Timeout"
        }
    }
}
