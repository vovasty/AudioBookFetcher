//
//  Utils.swift
//
//
//  Created by Vladimir Solomenchuk on 6/1/24.
//

import Combine
import Foundation

/// https://forums.swift.org/t/running-an-async-task-with-a-timeout/49733/21
public enum Waiter {
    public struct TimeoutError: Error {}

    public static func wait<R: Sendable, C: Clock>(
        for duration: C.Instant.Duration,
        tolerance: C.Instant.Duration? = nil,
        clock: C = .continuous,
        _ task: @escaping @Sendable () async throws -> R,
    ) async throws -> R {
        try await withThrowingTaskGroup(of: R.self) { group in
            await withUnsafeContinuation { continuation in
                group.addTask {
                    continuation.resume()
                    return try await task()
                }
            }
            group.addTask {
                await Task.yield()
                try await Task.sleep(for: duration, tolerance: tolerance, clock: clock)
                throw TimeoutError()
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
}

extension Waiter.TimeoutError: LocalizedError {
    public var errorDescription: String? {
        "Timeout"
    }
}

extension String {
    func max(_ c: Int) -> String {
        guard c < count else { return self }
        guard c > 4 else {
            return String(self[startIndex ..< index(startIndex, offsetBy: c)])
        }
        return String(self[startIndex ..< index(startIndex, offsetBy: c - 3)]) + "..."
    }
}
