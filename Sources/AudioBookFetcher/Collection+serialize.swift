//
//  Collection+serialize.swift
//
//
//  Created by Vladimir Solomenchuk on 8/14/20.
//

import Combine
import Foundation

extension Collection where Element: Publisher {
    func serialize() -> AnyPublisher<Element.Output, Element.Failure>? {
        guard let start = first else { return nil }
        return dropFirst().reduce(start.eraseToAnyPublisher()) {
            $0.append($1).eraseToAnyPublisher()
        }
    }
}
