//
//  UtilTests.swift
//
//
//  Created by Vladimir Solomenchuk on 6/1/24.
//

@testable import AudioBookFetcher
import XCTest

final class UtilTests: XCTestCase {
    func testStringMax() {
        XCTAssertEqual("0123456789".max(6), "012...")
        XCTAssertEqual("012345".max(6), "012345")
        XCTAssertEqual("012345".max(3), "012")
        XCTAssertEqual("012".max(2), "01")
        XCTAssertEqual("01".max(6), "01")
    }
}
