import Combine
import Foundation

public protocol BookChapter: Codable {
    var name: String? { get }
    var start: Int? { get }
}

public protocol AudioBook: Codable {
    associatedtype ChapterType: BookChapter
    var name: String? { get }
    var author: String? { get }
    var description: String? { get }
    var chapters: [ChapterType] { get }

    func coverRequest() -> URLRequest?
    func request(chapter: ChapterType) -> URLRequest?
}

public protocol AudioBookLoader {
    associatedtype ChapterType: BookChapter
    func load(url: URL) -> AnyPublisher<AnyAudioBook<ChapterType>, Error>
}

open class AnyAudioBook<T: BookChapter>: AudioBook {
    public let name: String?
    public let author: String?
    public let description: String?
    public let chapters: [T]

    public init(name: String?, author: String?, description: String?, chapters: [T]) {
        self.name = name
        self.author = author
        self.description = description
        self.chapters = chapters
    }

    open func coverRequest() -> URLRequest? {
        fatalError("not implemented")
    }

    open func request(chapter _: T) -> URLRequest? {
        fatalError("not implemented")
    }
}

public class AudioBookFetcher {
    public typealias ResultType = Result<Void, Error>
    public typealias HandlerType = (Result<Void, Error>) -> Void
    enum AudioBookFetcherError: Error {
        case noCover
    }

    public enum FileType {
        case cover
        case chapter(String)
        case skippedCover(Error)
        case skippedChapter(String, Error)
    }

    private var audioRequests: AnyCancellable?

    public init() {}

    private func createFolders<T>(book: AnyAudioBook<T>, to path: String) throws -> URL {
        let basePath = URL(fileURLWithPath: path, isDirectory: true)
        let bookPath = URL(fileURLWithPath: "\(book.author!)/\(book.name!)", isDirectory: true, relativeTo: basePath)

        try FileManager.default.createDirectory(at: bookPath, withIntermediateDirectories: true, attributes: nil)
        return bookPath
    }

    private func writeDescription<T>(book: AnyAudioBook<T>, path: URL) throws {
        guard let description = book.description else { return }
        try description.data(using: .utf8)?.write(to: path)
    }

    private func writeChapters<T>(book: AnyAudioBook<T>, path: URL) throws {
        let arr: [(Int, String)] = book.chapters.map { $0.start == nil ? nil : ($0.start!, $0.name!) }.compactMap { $0 }
        guard arr.count == book.chapters.count else { return }
        let chapters = arr.map { (t: (Int, String)) -> String in
            let hours = t.0 / 3600
            let remainder = t.0 % 3600
            let minutes = remainder / 60
            let seconds = remainder % 60
            let microseconds = 0

            return String(format: "%2d:%2d:%2d.%3d %@", hours, minutes, seconds, microseconds, t.1)
        }
        let result = chapters.joined(separator: "\n")
        try result.data(using: .utf8)?.write(to: path)
    }

    private func writeCover<T>(book: AnyAudioBook<T>, path: URL) -> AnyPublisher<FileType, Error> {
        guard let request = book.coverRequest() else {
            return Just(FileType.skippedCover(AudioBookFetcherError.noCover)).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        return Downloader
            .downloadCover(request: request, destination: path)
            .map { _ in FileType.cover }
            .tryCatch { error -> Just<FileType> in
                if case DownloadAgent.Error.fileExists = error {
                    return Just(FileType.skippedCover(error))
                }
                throw error
            }
            .eraseToAnyPublisher()
    }

    private func writeAudio<T>(book: AnyAudioBook<T>, path: URL) -> AnyPublisher<FileType, Error> {
        let audioRequests = book.chapters.enumerated().compactMap { index, chapter -> (request: URLRequest, destination: URL, chapter: T)? in
            guard let request = book.request(chapter: chapter) else { return nil }

            let fileName = String(format: "%03d-%@", index, chapter.name!)
            let destination = URL(fileURLWithPath: "\(fileName).mp3", isDirectory: false, relativeTo: path)
            return (request: request, destination: destination, chapter: chapter)
        }

        let audios = audioRequests.map { audioRequest -> AnyPublisher<FileType, Error> in
            Downloader
                .downloadAudio(request: audioRequest.request, destination: audioRequest.destination)
                .map { _ in FileType.chapter(audioRequest.chapter.name ?? "Unknown") }
                .tryCatch { error -> Just<FileType> in
                    if case DownloadAgent.Error.fileExists = error {
                        return Just(FileType.skippedChapter(audioRequest.chapter.name ?? "Unknown", error))
                    }
                    throw error
                }
                .eraseToAnyPublisher()
        }
        return audios.serialize()!
    }

    public func callAsFunction<T>(book: AnyAudioBook<T>, to path: String) -> AnyPublisher<FileType, Error> {
        let bookPath: URL
        do {
            bookPath = try createFolders(book: book, to: path)
            let descriptionPath = URL(fileURLWithPath: "description.txt", isDirectory: false, relativeTo: bookPath)
            try writeDescription(book: book, path: descriptionPath)
            let chaptersPath = URL(fileURLWithPath: "chapters.txt", isDirectory: false, relativeTo: bookPath)
            try writeChapters(book: book, path: chaptersPath)
        } catch {
            return Fail<FileType, Error>(error: error).eraseToAnyPublisher()
        }

        let coverPath = URL(fileURLWithPath: "cover.jpg", isDirectory: false, relativeTo: bookPath)
        let coverRequest = writeCover(book: book, path: coverPath)
        let audioRequest = writeAudio(book: book, path: bookPath)

        let result = Publishers.Merge(coverRequest, audioRequest)
        return result.eraseToAnyPublisher()
    }
}
