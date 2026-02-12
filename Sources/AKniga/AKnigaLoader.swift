//
//  AKnigaLoader.swift
//
//
//  Created by Vladimir Solomenchuk on 8/5/20.
//

import AudioBookFetcher
@preconcurrency import Combine
import Foundation
import Logging
import WebKit
import WebViewSniffer

private final class WebView: NSObject, WKNavigationDelegate {
    private let subject = CurrentValueSubject<Bool, Error>(false)
    let webView: WKWebView

    init(config: WKWebViewConfiguration) {
        webView = WKWebView(frame: .zero, configuration: config)
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        super.init()
        webView.navigationDelegate = self
    }

    func load(_ url: URL) async throws {
        webView.load(URLRequest(url: url))
        for try await finished in subject.values {
            guard finished else { continue }
            break
        }
    }

    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        subject.send(completion: .finished)
    }

    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        subject.send(completion: .failure(error))
    }

    func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        subject.send(completion: .failure(error))
    }
}

public struct AKnigaLoader: AudioBookLoader {
    public enum Failure: Swift.Error {
        case noData, noHTML, noM3u8Url
    }

    private let logger = Logger(label: "net.aramzamzam.abookfetcher")

    public init() {}

    @MainActor
    public func load(url: URL) async throws -> AudioBookFetcher.AudioBook {
        let m3u8UrlSubject = CurrentValueSubject<URL?, Never>(nil)
        let config = WKWebViewConfiguration.interceptable { response in
            guard let url = response.url else { return }
            logger.debug("got \(url)")
            guard url.pathExtension == "m3u8" else { return }
            m3u8UrlSubject.send(url)
        }

        let webView = WebView(config: config)

        logger.info("Loading \(url)")

        try await webView.load(url)

        logger.info("Getting m3u8 url")

        let m3u8Url = try await Waiter.loop(3, errors: [Waiter.TimeoutError.self]) { @MainActor counter in
            if counter > 0 {
                logger.info("Retrying m3u8 url...")
                webView.webView.reload()
            }
            return try await Waiter.wait(for: .seconds(30)) {
                for try await m3u8 in m3u8UrlSubject.values {
                    guard let m3u8 else { continue }
                    return m3u8
                }
                throw Failure.noM3u8Url
            }
        }

        logger.info("Getting bookData")
        let bookDataResponse = try await Waiter.loop(3, errors: [Failure.self]) { @MainActor counter in
            if counter > 0 {
                logger.info("Retrying bookData...")
                try await Task.sleep(for: .seconds(1))
            }
            guard let bookDataResponse = try await webView.webView.evaluateJavaScript("JSON.stringify(bookData)") as? String else {
                throw Failure.noData
            }

            guard bookDataResponse.count > 100 else {
                throw Failure.noData
            }

            return bookDataResponse
        }

        logger.info("Getting html")
        guard let html = try await webView.webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") as? String else {
            throw Failure.noHTML
        }

        return try AudioBook(bookUrl: url, html: html, bookDataResponse: bookDataResponse, m3u8URL: m3u8Url)
    }
}
