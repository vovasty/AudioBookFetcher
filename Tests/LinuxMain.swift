import XCTest

import AudioBookFetcherTests

var tests = [XCTestCaseEntry]()
tests += AudioBookFetcherTests.allTests()
tests += AKnigaTests.allTests()
XCTMain(tests)
