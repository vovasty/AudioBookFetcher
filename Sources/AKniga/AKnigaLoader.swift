//
//  File.swift
//
//
//  Created by Vladimir Solomenchuk on 8/5/20.
//

import AudioBookFetcher
import Combine
import Foundation
import WebKit

private extension WKWebView {
    func evaluate(script: String, completion: @escaping (Any?, Error?) -> Void) {
        var finished = false

        evaluateJavaScript(script, completionHandler: { result, error in
            if error == nil {
                if result != nil {
                    completion(result, nil)
                }
            } else {
                completion(nil, error)
            }
            finished = true
        })

        while !finished {
            RunLoop.current.run(mode: RunLoop.Mode(rawValue: "NSDefaultRunLoopMode"), before: NSDate.distantFuture)
        }
    }
}

public class AKnigaLoader: NSObject {
    public enum Error: Swift.Error {
        case noData, noHTML, noID, unknown
    }

    private let webView = WKWebView(frame: NSMakeRect(0, 0, 0, 0))
    private var subject: PassthroughSubject<AnyAudioBook<AKnigaChapter>, Swift.Error>

    override public init() {
        subject = PassthroughSubject<AnyAudioBook<AKnigaChapter>, Swift.Error>()
        super.init()
        webView.navigationDelegate = self
    }
}

extension AKnigaLoader: WKNavigationDelegate {
    public func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        subject.send(completion: .failure(error))
    }

    public func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        subject.send(completion: .failure(error))
    }

    public func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
        logger.info("started")
    }

    public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        webView.evaluate(script: "JSON.stringify(bookData)") { [weak self] result, error in
            guard let self = self else { return }
            guard error == nil else {
                self.subject.send(completion: .failure(error ?? Error.unknown))
                return
            }

            guard let bookDataString = result as? String else {
                self.subject.send(completion: .failure(Error.noData))
                return
            }

            guard let bookData = bookDataString.data(using: .utf8) else {
                self.subject.send(completion: .failure(Error.noData))
                return
            }

            webView.evaluate(script: "document.documentElement.outerHTML.toString()") { [weak self] result, error in
                guard let self = self else { return }
                guard error == nil else {
                    self.subject.send(completion: .failure(error ?? Error.unknown))
                    return
                }

                guard let html = result as? String else {
                    self.subject.send(completion: .failure(Error.noHTML))
                    return
                }

                do {
                    let bookData = try JSONDecoder().decode(BookDataResponse.self, from: bookData)
                    guard let id = bookData.keys.first else { throw Error.noID }
                    guard let book = bookData[id] else { throw Error.noID }
                    let parser = try AKnigaAudioBook(id: id, html: html, bookData: book)
                    self.subject.send(parser)
                    self.subject.send(completion: .finished)
                } catch {
                    self.subject.send(completion: .failure(error))
                }
            }
        }
    }
}

extension AKnigaLoader: AudioBookLoader {
    public func load(url: URL) -> AnyPublisher<AnyAudioBook<AKnigaChapter>, Swift.Error> {
        let request = URLRequest(url: url)
        webView.load(request)
        return subject.eraseToAnyPublisher()
    }
}
