//
//  WebViewSniffer.swift
//
//
//  Created by Vladimir Solomenchuk on 5/31/24.
//

import Foundation
import SSWKURL
import WebKit

public extension WKWebViewConfiguration {
    static func interceptable(_ closure: @escaping (URLRequest) -> Void) -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        let handler = URLInterceptor.sharedInstance()
        URLInterceptor.handler = closure
        handler?.protocolClass = SSWKURLProtocol.self
        config.setURLSchemeHandler(handler, forURLScheme: "http")
        config.setURLSchemeHandler(handler, forURLScheme: "https")
        return config
    }
}

private class URLInterceptor: SSWKURLHandler {
    static var handler: (URLRequest) -> Void = { _ in }

    override func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        Self.handler(urlSchemeTask.request)
        super.webView(webView, start: urlSchemeTask)
    }
}
