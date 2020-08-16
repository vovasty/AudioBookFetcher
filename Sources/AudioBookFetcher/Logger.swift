//
//  File.swift
//
//
//  Created by Vladimir Solomenchuk on 8/5/20.
//

import Foundation

public struct Logger {
    public func error(_ error: Error) {
        print("Error:", error.localizedDescription)
    }

    public func info(_ info: String) {
        print(info)
    }
}

public let logger = Logger()
