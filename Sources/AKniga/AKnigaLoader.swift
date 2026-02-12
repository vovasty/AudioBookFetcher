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
    public enum AKnigaLoaderError: Swift.Error {
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

        guard let bookDataResponse = try await webView.webView.evaluateJavaScript("JSON.stringify(bookData)") as? String else {
            throw AKnigaLoaderError.noData
        }

        logger.info("Getting html")
        guard let html = try await webView.webView.evaluateJavaScript("document.documentElement.outerHTML.toString()") as? String else {
            throw AKnigaLoaderError.noHTML
        }

        var m3u8Url: URL?
        var maxRetries = 3
        logger.info("Getting m3u8 url")
        while true {
            do {
                m3u8Url = try await Waiter.wait(for: .seconds(30)) {
                    for try await m3u8 in m3u8UrlSubject.values {
                        guard let m3u8 else { continue }
                        return m3u8
                    }
                    return nil
                }
                break
            } catch let error as Waiter.TimeoutError {
                maxRetries -= 1
                guard maxRetries != 0 else { throw error }
                logger.info("Retrying m3u8 url...")
                webView.webView.reload()
            }
        }

        guard let m3u8Url else {
            throw AKnigaLoaderError.noM3u8Url
        }

        return try AudioBook(bookUrl: url, html: html, bookDataResponse: bookDataResponse, m3u8URL: m3u8Url)
    }
}
