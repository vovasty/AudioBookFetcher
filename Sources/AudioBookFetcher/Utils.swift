//
//  Utils.swift
//
//
//  Created by Vladimir Solomenchuk on 6/1/24.
//

import Combine
import Foundation

enum UtilError {
    case timeout
}

func with<T>(timeout: Double, closure: @escaping () async throws -> T) async throws -> T {
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
            throw UtilError.timeout
        }

        return value
    } catch {
        task.cancel()
        throw error
    }
}

extension UtilError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .timeout:
            "Timeout"
        }
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
