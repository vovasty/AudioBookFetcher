//
//  WebViewTests.swift
//
//
//  Created by Vladimir Solomenchuk on 5/31/24.
//

import WebKit
import WebViewSniffer
import XCTest

final class WebViewTests: XCTestCase {
    func testWebView() throws {
        let e = expectation(description: "wait")

        let config = WKWebViewConfiguration.interceptable { response in
            guard response.url != nil else { return }
            e.fulfill()
        }

        config.processPool = WKProcessPool()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: config)
        try webView.load(URLRequest(url: XCTUnwrap(URL(string: "https://google.com"))))

        waitForExpectations(timeout: 10)
    }
}
